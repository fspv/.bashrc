use std::collections::HashSet;
use std::io::{self, Write};
use std::path::Path;
use std::process::exit;

use clap::{Args, Parser, Subcommand};
use common::Result;
use github::{create_pr, current_user, pr_for_branch, set_pr_base, BranchName, PullRequest};
use jj::{
    bookmarks_in_range, colocated_repo_root, conflicted_bookmarks, current_stack_tips, git_export,
    git_push, parent_bookmark, untracked_origin_bookmarks, working_copy_change, BookmarkName,
    Revset,
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
}

#[derive(Args)]
struct PrSyncArgs {
    /// Revset of stack leaves (default: all leaves of the stack @ is on).
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
    parent: BranchName,
    pr: Option<PullRequest>,
    action: Action,
}

fn main() {
    let result = match Cli::parse().tool {
        Tool::PrSync(args) => pr_sync(args),
    };
    match result {
        Ok(code) => exit(code),
        Err(err) => {
            eprintln!("jj-tools: {err}");
            exit(1);
        }
    }
}

fn pr_sync(args: PrSyncArgs) -> Result<i32> {
    let trunk = Revset::new(args.trunk);
    let base = BranchName::new(args.base);

    // Resolve the default tips against @ *before* moving into the colocated repo,
    // so they reflect the workspace the user actually ran from.
    let tips = match args.tips {
        Some(tips) => Revset::new(tips),
        None => current_stack_tips(&trunk, working_copy_change()?.as_str()),
    };

    // gh (and ref export) must run in the colocated workspace; cd there once.
    let repo_root = colocated_repo_root()?;
    std::env::set_current_dir(&repo_root)?;

    let bookmarks = bookmarks_in_range(&trunk, &tips)?;
    if bookmarks.is_empty() {
        eprintln!("No bookmarks found in {}..{}", trunk.as_str(), tips.as_str());
        return Ok(1);
    }

    if let Some(blocked) = blocked_bookmarks(&bookmarks)? {
        eprintln!(
            "Resolve these bookmarks first (conflicted or untracked @origin): {}",
            blocked.join(", ")
        );
        return Ok(1);
    }

    let me = current_user()?;
    let plan = build_plan(&trunk, &base, &bookmarks, &me)?;
    print_plan(&me, &plan, &repo_root);

    let new_prs = plan.iter().filter(|e| e.action == Action::Create).count();
    if new_prs > args.max_new_prs {
        eprintln!(
            "Would create {new_prs} new PRs, over the limit of {}. Re-run with --max-new-prs {new_prs} to allow.",
            args.max_new_prs
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

    apply(&plan, args.ready)?;
    Ok(0)
}

fn blocked_bookmarks(bookmarks: &[BookmarkName]) -> Result<Option<Vec<String>>> {
    let stack: HashSet<&str> = bookmarks.iter().map(BookmarkName::as_str).collect();
    let mut blocked: Vec<String> = Vec::new();
    for bookmark in conflicted_bookmarks()?
        .into_iter()
        .chain(untracked_origin_bookmarks()?)
    {
        if stack.contains(bookmark.as_str()) && !blocked.iter().any(|b| b == bookmark.as_str()) {
            blocked.push(bookmark.as_str().to_string());
        }
    }
    Ok((!blocked.is_empty()).then_some(blocked))
}

fn build_plan(
    trunk: &Revset,
    base: &BranchName,
    bookmarks: &[BookmarkName],
    me: &str,
) -> Result<Vec<PlanEntry>> {
    let mut plan = Vec::with_capacity(bookmarks.len());
    for bookmark in bookmarks {
        let parent = parent_bookmark(trunk, bookmark)?
            .map_or_else(|| base.clone(), |p| BranchName::new(p.as_str()));
        let pr = pr_for_branch(&BranchName::new(bookmark.as_str()))?;
        let action = match &pr {
            None => Action::Create,
            Some(pr) if pr.author != me => Action::Skip,
            Some(pr) if pr.base != parent => Action::Update,
            Some(_) => Action::Noop,
        };
        plan.push(PlanEntry {
            bookmark: bookmark.clone(),
            parent,
            pr,
            action,
        });
    }
    Ok(plan)
}

fn print_plan(me: &str, plan: &[PlanEntry], repo_root: &Path) {
    println!("Plan (you are @{me}):");
    for entry in plan {
        match (&entry.action, &entry.pr) {
            (Action::Create, _) => println!("  CREATE  {}  (base {})", entry.bookmark, entry.parent),
            (Action::Update, Some(pr)) => println!(
                "  UPDATE  #{} {}  (base {} -> {})",
                pr.number, entry.bookmark, pr.base, entry.parent
            ),
            (Action::Noop, Some(pr)) => println!("  ok      #{} {}", pr.number, entry.bookmark),
            (Action::Skip, Some(pr)) => println!(
                "  SKIP    #{} {}  (owned by @{}, not you)",
                pr.number, entry.bookmark, pr.author
            ),
            _ => {}
        }
    }
    println!("Repo dir: {}", repo_root.display());
}

fn apply(plan: &[PlanEntry], ready: bool) -> Result<()> {
    let push: Vec<BookmarkName> = plan
        .iter()
        .filter(|e| e.action != Action::Skip)
        .map(|e| e.bookmark.clone())
        .collect();
    if !push.is_empty() {
        git_push(&push)?;
        git_export()?;
    }

    for entry in plan {
        match (&entry.action, &entry.pr) {
            (Action::Update, Some(pr)) => set_pr_base(pr.number, &entry.parent)?,
            (Action::Create, _) => {
                create_pr(&BranchName::new(entry.bookmark.as_str()), &entry.parent, ready)?;
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
