use std::collections::HashSet;
use std::io::{self, Write};
use std::path::Path;
use std::process::exit;
use std::thread::sleep;
use std::time::Duration;

use clap::{Args, Parser, Subcommand};
use common::Result;
use git::ObjectId;
use github::{
    BranchName, PrState, PullRequest, create_pr, current_user, prs_for_branches, set_pr_base,
};
use jj::{
    Bookmark, BookmarkName, ChangeId, Revset, StackGraph, colocated_repo_root,
    conflicted_bookmarks, current_stack_tips, git_export, git_fetch, git_push, git_track,
    local_bookmarks, untracked_origin_bookmarks, working_copy_change,
};

#[derive(Parser)]
#[command(name = "jj-tools", about = "Tools for managing jj stacks on GitHub")]
struct Cli {
    #[command(subcommand)]
    tool: Tool,
}

#[derive(Subcommand)]
enum Tool {
    /// Sync a jj bookmark DAG to GitHub as base-pointer PRs (trees supported).
    PrSync(PrSyncArgs),
    /// Fetch the origin branches matching your local bookmarks and track them.
    FetchAndTrack,
}

#[derive(Args)]
struct PrSyncArgs {
    /// Revset of stack leaves (default: ascendants of @; if the full tree differs
    /// from GitHub, requires confirming a full-tree submit or aborts).
    tips: Option<String>,
    /// GitHub base branch for stack roots.
    #[arg(long, default_value = "main")]
    base: String,
    /// jj revset for trunk.
    #[arg(long, default_value = "trunk()")]
    trunk: String,
    /// Create PRs ready for review instead of draft.
    #[arg(long)]
    ready: bool,
    /// Show the plan and change nothing.
    #[arg(long)]
    dry_run: bool,
    /// Apply without the confirmation prompt.
    #[arg(short = 'y', long)]
    yes: bool,
    /// Refuse to create more than this many new PRs at once.
    #[arg(long, default_value_t = 5)]
    max_new_prs: usize,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Action {
    Create,
    Update,
    Noop,
    Skip,
}

struct PlanEntry {
    bookmark: BookmarkName,
    commit: ObjectId,
    parent: BranchName,
    pr: Option<PullRequest>,
    action: Action,
    empty: bool,
}

fn main() {
    common::log_to_stderr(tracing::Level::DEBUG);
    let result = match Cli::parse().tool {
        Tool::PrSync(args) => pr_sync(args),
        Tool::FetchAndTrack => fetch_and_track(),
    };
    match result {
        Ok(code) => exit(code),
        Err(err) => {
            eprintln!("jj-tools: {err}");
            exit(1);
        }
    }
}

fn fetch_and_track() -> Result<i32> {
    let bookmarks = local_bookmarks()?;
    if bookmarks.is_empty() {
        println!("No local bookmarks to fetch.");
        return Ok(0);
    }
    git_fetch(&bookmarks)?;
    let local: HashSet<&str> = bookmarks.iter().map(BookmarkName::as_str).collect();
    let to_track: Vec<BookmarkName> = untracked_origin_bookmarks()?
        .into_iter()
        .filter(|bookmark| local.contains(bookmark.as_str()))
        .collect();
    git_track(&to_track)?;
    Ok(0)
}

fn pr_sync(args: PrSyncArgs) -> Result<i32> {
    let trunk = Revset::new(args.trunk);
    let base = BranchName::new(args.base);

    // Resolve @ *before* moving into the colocated repo, so it reflects the
    // workspace the user actually ran from.
    let anchor = working_copy_change()?;

    // gh (and ref export) must run in the colocated workspace; cd there once.
    let repo_root = colocated_repo_root()?;
    std::env::set_current_dir(&repo_root)?;

    let me = current_user()?;

    let Some(SyncScope {
        tips,
        plan_already_printed,
    }) = sync_scope(args.tips, &anchor, &trunk, &base, &me, &repo_root)?
    else {
        return Ok(1);
    };

    let graph = StackGraph::load(&trunk, &tips)?;
    let bookmarks = graph.bookmarks();
    if bookmarks.is_empty() {
        eprintln!(
            "No bookmarks found in {}..{}",
            trunk.as_str(),
            tips.as_str()
        );
        return Ok(1);
    }

    let blocked = blocked_bookmarks(&bookmarks)?;
    if !blocked.is_empty() {
        eprintln!(
            "Resolve these bookmarks first (conflicted or untracked @origin): {}",
            blocked
                .iter()
                .map(BookmarkName::as_str)
                .collect::<Vec<_>>()
                .join(", ")
        );
        return Ok(1);
    }

    let plan = build_plan(&graph, &base, &me)?;
    if !plan_already_printed {
        print_plan(&me, &plan, &repo_root);
    }

    let empty = bookmarks_with_an_empty_diff(&plan);
    if !empty.is_empty() {
        eprintln!(
            "These bookmarks have an empty diff against their base (would be empty PRs): {}",
            empty
                .iter()
                .map(|bookmark| bookmark.as_str())
                .collect::<Vec<_>>()
                .join(", ")
        );
        return Ok(1);
    }

    let new_prs = plan.iter().filter(|e| e.action == Action::Create).count();
    if new_prs > args.max_new_prs {
        eprintln!(
            "Would create {new_prs} new PRs, over the limit of {}. Re-run with --max-new-prs {new_prs} to allow.",
            args.max_new_prs
        );
        return Ok(1);
    }

    let duplicates = bookmarks_sharing_a_commit(&plan);
    if !duplicates.is_empty() {
        eprintln!(
            "Refusing to push: these bookmarks point at the same commit as another bookmark in \
             the stack, which would create duplicate PRs: {}",
            duplicates
                .iter()
                .map(|bookmark| bookmark.as_str())
                .collect::<Vec<_>>()
                .join(", ")
        );
        return Ok(1);
    }

    if args.dry_run {
        return Ok(0);
    }
    if !plan
        .iter()
        .any(|e| matches!(e.action, Action::Create | Action::Update | Action::Noop))
    {
        println!("Nothing to do.");
        return Ok(0);
    }
    if !args.yes && !confirm("Proceed with push + PR changes? [y/N] ")? {
        println!("Aborted.");
        return Ok(0);
    }

    apply(&plan, &base, args.ready)?;
    Ok(0)
}

struct SyncScope {
    tips: Revset,
    plan_already_printed: bool,
}

/// Which stack leaves to sync. Explicit `tips` win. Otherwise only the
/// ascendants of `anchor`, widened to the whole stack tree (after showing it and
/// asking) when that tree's PR topology differs from GitHub. `None` when the
/// user declines.
fn sync_scope(
    explicit_tips: Option<String>,
    anchor: &ChangeId,
    trunk: &Revset,
    base: &BranchName,
    me: &str,
    repo_root: &Path,
) -> Result<Option<SyncScope>> {
    if let Some(tips) = explicit_tips {
        return Ok(Some(SyncScope {
            tips: Revset::new(tips),
            plan_already_printed: false,
        }));
    }
    let full_tree_tips = current_stack_tips(trunk, anchor.as_str());
    let full_plan = build_plan(&StackGraph::load(trunk, &full_tree_tips)?, base, me)?;
    if !tree_differs_from_github(&full_plan) {
        return Ok(Some(SyncScope {
            tips: Revset::new(anchor.as_str()),
            plan_already_printed: false,
        }));
    }
    println!("Local stack tree differs from GitHub PR topology (new PRs, reordered bases, etc.).");
    print_plan(me, &full_plan, repo_root);
    if !confirm("Submit the entire related tree? [y/N] ")? {
        eprintln!("Aborted: tree differs from GitHub and full-tree submit was declined.");
        return Ok(None);
    }
    Ok(Some(SyncScope {
        tips: full_tree_tips,
        plan_already_printed: true,
    }))
}

/// Bookmarks that would be pushed as a pull request containing no changes.
fn bookmarks_with_an_empty_diff(plan: &[PlanEntry]) -> Vec<&BookmarkName> {
    plan.iter()
        .filter(|entry| matches!(entry.action, Action::Create | Action::Update) && entry.empty)
        .map(|entry| &entry.bookmark)
        .collect()
}

/// Whether the local bookmark DAG's PR topology differs from GitHub's for this stack.
///
/// Differs when a bookmark still needs a PR (new node) or an owned open PR's base
/// does not match the local parent bookmark (reorder / retarget).
fn tree_differs_from_github(plan: &[PlanEntry]) -> bool {
    plan.iter()
        .any(|entry| matches!(entry.action, Action::Create | Action::Update))
}

/// Bookmarks to be pushed that share their commit with another pushed bookmark,
/// typically after squashing one bookmark's change into another.
fn bookmarks_sharing_a_commit(plan: &[PlanEntry]) -> Vec<&BookmarkName> {
    let pushed: Vec<&PlanEntry> = plan
        .iter()
        .filter(|entry| entry.action != Action::Skip)
        .collect();
    pushed
        .iter()
        .filter(|entry| {
            pushed
                .iter()
                .any(|other| other.bookmark != entry.bookmark && other.commit == entry.commit)
        })
        .map(|entry| &entry.bookmark)
        .collect()
}

fn blocked_bookmarks(bookmarks: &[Bookmark]) -> Result<Vec<BookmarkName>> {
    let stack: HashSet<&BookmarkName> = bookmarks.iter().map(|bookmark| &bookmark.name).collect();
    let mut blocked: Vec<BookmarkName> = Vec::new();
    for bookmark in conflicted_bookmarks()?
        .into_iter()
        .chain(untracked_origin_bookmarks()?)
    {
        if stack.contains(&bookmark) && !blocked.contains(&bookmark) {
            blocked.push(bookmark);
        }
    }
    Ok(blocked)
}

fn build_plan(graph: &StackGraph, base: &BranchName, me: &str) -> Result<Vec<PlanEntry>> {
    let bookmarks = graph.bookmarks();
    let branches: Vec<BranchName> = bookmarks
        .iter()
        .map(|bookmark| BranchName::new(bookmark.name.as_str()))
        .collect();
    let prs = prs_for_branches(&branches)?;
    let plan = bookmarks
        .into_iter()
        .zip(prs)
        .map(|(bookmark, pr)| {
            let parent_mark = graph.parent_bookmark(&bookmark);
            let parent = parent_mark
                .as_ref()
                .map_or_else(|| base.clone(), |p| BranchName::new(p.name.as_str()));
            let empty = graph.is_diff_empty(parent_mark.as_ref(), &bookmark);
            let action = match &pr {
                None => Action::Create,
                Some(pr) if pr.author != me => Action::Skip,
                Some(pr) if matches!(pr.state, PrState::Merged | PrState::Closed) => Action::Skip,
                Some(pr) if pr.base != parent => Action::Update,
                Some(_) => Action::Noop,
            };
            PlanEntry {
                bookmark: bookmark.name,
                commit: bookmark.target,
                parent,
                pr,
                action,
                empty,
            }
        })
        .collect();
    Ok(plan)
}

fn print_plan(me: &str, plan: &[PlanEntry], repo_root: &Path) {
    println!("Plan (you are @{me}):");
    for entry in plan {
        match (&entry.action, &entry.pr) {
            (Action::Create, _) => {
                println!("  CREATE  {}  (base {})", entry.bookmark, entry.parent);
            }
            (Action::Update, Some(pr)) => println!(
                "  UPDATE  #{} {}  (base {} -> {})",
                pr.number, entry.bookmark, pr.base, entry.parent
            ),
            (Action::Noop, Some(pr)) => println!("  ok      #{} {}", pr.number, entry.bookmark),
            (Action::Skip, Some(pr)) => {
                let reason = match pr.state {
                    PrState::Merged => "already merged".to_string(),
                    PrState::Closed => "closed".to_string(),
                    _ => format!("owned by @{}, not you", pr.author),
                };
                println!("  SKIP    #{} {}  ({reason})", pr.number, entry.bookmark);
            }
            _ => {}
        }
    }
    println!("Repo dir: {}", repo_root.display());
}

fn apply(plan: &[PlanEntry], trunk: &BranchName, ready: bool) -> Result<()> {
    for entry in plan {
        if let (Action::Update, Some(pr)) = (&entry.action, &entry.pr) {
            set_pr_base(pr.number, trunk)?;
        }
    }

    let push: Vec<BookmarkName> = plan
        .iter()
        .filter(|e| e.action != Action::Skip)
        .map(|e| e.bookmark.clone())
        .collect();
    for (index, bookmark) in push.iter().enumerate() {
        if index > 0 {
            println!("Sleeping 15s before the next push to avoid GitHub rate limits...");
            sleep(Duration::from_secs(15));
        }
        git_push(std::slice::from_ref(bookmark))?;
    }
    if !push.is_empty() {
        git_export()?;
    }

    for entry in plan {
        match (&entry.action, &entry.pr) {
            (Action::Update, Some(pr)) => set_pr_base(pr.number, &entry.parent)?,
            (Action::Create, _) => {
                create_pr(
                    &BranchName::new(entry.bookmark.as_str()),
                    &entry.parent,
                    ready,
                )?;
            }
            _ => {}
        }
    }
    Ok(())
}

fn confirm(prompt: &str) -> Result<bool> {
    print!("{prompt}");
    io::stdout().flush()?;
    let mut answer = String::new();
    io::stdin().read_line(&mut answer)?;
    Ok(answer.trim().eq_ignore_ascii_case("y"))
}
