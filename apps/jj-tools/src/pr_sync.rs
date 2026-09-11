use std::collections::HashSet;
use std::io::{self, Write};
use std::path::Path;

use clap::Args;
use common::Result;
use git::{AuthorName, BranchName, ObjectId, PullRequestNumber};
use jj::{
    Bookmark, BookmarkName, ChangeId, Revset, StackGraph, colocated_repo_root,
    conflicted_bookmarks, current_stack_tips, untracked_origin_bookmarks, working_copy_change,
};

#[derive(Args)]
pub struct PrSyncArgs {
    #[arg(
        help = "Revset of stack leaves (default: ascendants of @; if the full tree differs from the forge, requires confirming a full-tree submit or aborts)"
    )]
    tips: Option<Revset>,
    #[arg(long, default_value = "main", help = "Base branch for stack roots")]
    base: BranchName,
    #[arg(long, default_value = "trunk()", help = "jj revset for trunk")]
    trunk: Revset,
    #[arg(long, help = "Create PRs ready for review instead of draft")]
    ready: bool,
    #[arg(long, help = "Show the plan and change nothing")]
    dry_run: bool,
    #[arg(short = 'y', long, help = "Apply without the confirmation prompt")]
    yes: bool,
    #[arg(
        long,
        default_value_t = 5,
        help = "Refuse to create more than this many new PRs at once"
    )]
    max_new_prs: usize,
}

pub trait Forge {
    const NAME: &'static str;

    fn current_user(&self) -> Result<Option<AuthorName>>;
    fn prs_for_branches(
        &self,
        branches: &[BranchName],
        current_user: Option<&AuthorName>,
    ) -> Result<Vec<Option<PullRequest>>>;
    fn apply(&self, plan: &[PlanEntry], trunk: &BranchName, ready: bool) -> Result<()>;
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PrState {
    Open,
    Draft,
    Closed,
    Merged,
}

pub struct PullRequest {
    pub number: PullRequestNumber,
    pub state: PrState,
    pub base: BranchName,
    pub author: Option<AuthorName>,
    pub owned_by_current_user: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Action {
    Create,
    Update,
    Noop,
    Skip,
}

pub struct PlanEntry {
    pub bookmark: BookmarkName,
    pub commit: ObjectId,
    pub parent: BranchName,
    pub pr: Option<PullRequest>,
    pub action: Action,
    empty: bool,
}

pub fn run(args: PrSyncArgs, forge: &impl Forge) -> Result<i32> {
    let trunk = args.trunk;
    let base = args.base;

    // Resolve @ *before* moving into the colocated repo, so it reflects the
    // workspace the user actually ran from.
    let anchor = working_copy_change()?;

    let repo_root = colocated_repo_root()?;
    std::env::set_current_dir(&repo_root)?;

    let current_user = forge.current_user()?;
    let me = current_user.as_ref();

    let Some(SyncScope {
        tips,
        plan_already_printed,
    }) = sync_scope(args.tips, &anchor, &trunk, &base, me, &repo_root, forge)?
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

    let plan = build_plan(&graph, &base, me, forge)?;
    if !plan_already_printed {
        print_plan(me, &plan, &repo_root);
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

    let new_prs = plan
        .iter()
        .filter(|entry| entry.action == Action::Create)
        .count();
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
        .any(|entry| matches!(entry.action, Action::Create | Action::Update | Action::Noop))
    {
        println!("Nothing to do.");
        return Ok(0);
    }
    if !args.yes && !confirm("Proceed with push + PR changes? [y/N] ")? {
        println!("Aborted.");
        return Ok(0);
    }

    forge.apply(&plan, &base, args.ready)?;
    Ok(0)
}

struct SyncScope {
    tips: Revset,
    plan_already_printed: bool,
}

fn sync_scope<Provider: Forge>(
    explicit_tips: Option<Revset>,
    anchor: &ChangeId,
    trunk: &Revset,
    base: &BranchName,
    me: Option<&AuthorName>,
    repo_root: &Path,
    forge: &Provider,
) -> Result<Option<SyncScope>> {
    if let Some(tips) = explicit_tips {
        return Ok(Some(SyncScope {
            tips,
            plan_already_printed: false,
        }));
    }
    let full_tree_tips = current_stack_tips(trunk, anchor.as_str());
    let full_plan = build_plan(&StackGraph::load(trunk, &full_tree_tips)?, base, me, forge)?;
    if !tree_differs_from_forge(&full_plan) {
        return Ok(Some(SyncScope {
            tips: Revset::new(anchor.as_str()),
            plan_already_printed: false,
        }));
    }
    println!(
        "Local stack tree differs from {} PR topology (new PRs, reordered bases, etc.).",
        Provider::NAME
    );
    print_plan(me, &full_plan, repo_root);
    if !confirm("Submit the entire related tree? [y/N] ")? {
        eprintln!(
            "Aborted: tree differs from {} and full-tree submit was declined.",
            Provider::NAME
        );
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

fn tree_differs_from_forge(plan: &[PlanEntry]) -> bool {
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

fn build_plan(
    graph: &StackGraph,
    base: &BranchName,
    me: Option<&AuthorName>,
    forge: &impl Forge,
) -> Result<Vec<PlanEntry>> {
    let bookmarks = graph.bookmarks();
    if bookmarks.is_empty() {
        return Ok(Vec::new());
    }
    let branches: Vec<BranchName> = bookmarks
        .iter()
        .map(|bookmark| BranchName::new(bookmark.name.as_str()))
        .collect();
    let prs = forge.prs_for_branches(&branches, me)?;
    let plan = bookmarks
        .into_iter()
        .zip(prs)
        .map(|(bookmark, pr)| {
            let parent_mark = graph.parent_bookmark(&bookmark);
            let parent = parent_mark.as_ref().map_or_else(
                || base.clone(),
                |parent| BranchName::new(parent.name.as_str()),
            );
            let empty = graph.is_diff_empty(parent_mark.as_ref(), &bookmark);
            let action = plan_action(pr.as_ref(), &parent);
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

fn plan_action(pull_request: Option<&PullRequest>, parent: &BranchName) -> Action {
    match pull_request {
        None => Action::Create,
        Some(pull_request) if !pull_request.owned_by_current_user => Action::Skip,
        Some(pull_request) if matches!(pull_request.state, PrState::Merged | PrState::Closed) => {
            Action::Skip
        }
        Some(pull_request) if pull_request.base != *parent => Action::Update,
        Some(_) => Action::Noop,
    }
}

fn print_plan(me: Option<&AuthorName>, plan: &[PlanEntry], repo_root: &Path) {
    if let Some(me) = me {
        println!("Plan (you are @{me}):");
    } else {
        println!("Plan:");
    }
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
                    _ => pr.author.as_ref().map_or_else(
                        || "owned by another user".to_string(),
                        |author| format!("owned by @{author}, not you"),
                    ),
                };
                println!("  SKIP    #{} {}  ({reason})", pr.number, entry.bookmark);
            }
            _ => {}
        }
    }
    println!("Repo dir: {}", repo_root.display());
}

fn confirm(prompt: &str) -> Result<bool> {
    print!("{prompt}");
    io::stdout().flush()?;
    let mut answer = String::new();
    io::stdin().read_line(&mut answer)?;
    Ok(answer.trim().eq_ignore_ascii_case("y"))
}

#[cfg(test)]
mod tests {
    use super::{Action, PrState, PullRequest, plan_action};
    use git::{BranchName, PullRequestNumber};

    #[test]
    fn missing_pull_requests_are_created() {
        assert_eq!(plan_action(None, &BranchName::new("main")), Action::Create);
    }

    fn check_actions(
        state: PrState,
        owned_by_current_user: bool,
        matching_base: Action,
        changed_base: Action,
    ) {
        let parent = BranchName::new("main");
        let mut pull_request = PullRequest {
            number: PullRequestNumber::new(1),
            state,
            base: parent.clone(),
            author: None,
            owned_by_current_user,
        };
        assert_eq!(plan_action(Some(&pull_request), &parent), matching_base);
        pull_request.base = BranchName::new("old-base");
        assert_eq!(plan_action(Some(&pull_request), &parent), changed_base);
    }

    #[test]
    fn owned_active_pull_requests_only_update_when_the_base_changes() {
        check_actions(PrState::Open, true, Action::Noop, Action::Update);
        check_actions(PrState::Draft, true, Action::Noop, Action::Update);
    }

    #[test]
    fn foreign_pull_requests_are_skipped_regardless_of_state_or_base() {
        check_actions(PrState::Open, false, Action::Skip, Action::Skip);
        check_actions(PrState::Draft, false, Action::Skip, Action::Skip);
        check_actions(PrState::Closed, false, Action::Skip, Action::Skip);
        check_actions(PrState::Merged, false, Action::Skip, Action::Skip);
    }

    #[test]
    fn owned_closed_and_merged_pull_requests_are_skipped() {
        check_actions(PrState::Closed, true, Action::Skip, Action::Skip);
        check_actions(PrState::Merged, true, Action::Skip, Action::Skip);
    }
}
