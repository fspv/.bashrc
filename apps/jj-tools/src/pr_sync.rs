use std::collections::HashSet;
use std::io::{self, Write};
use std::path::Path;

use clap::Args;
use common::Result;
use git::{AuthorName, BranchName, ObjectId, PullRequestId, PullRequestNumber, StackLink};
use jj::{
    Bookmark, BookmarkName, Revset, StackGraph, colocated_repo_root, conflicted_bookmarks,
    untracked_origin_bookmarks, working_copy_change,
};

#[derive(Args)]
pub struct PrSyncArgs {
    #[arg(
        help = "Revset of stack leaves (default: @ and its ancestors toward trunk, excluding descendants)"
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
    const LINKS_STACKED_PRS: bool;

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
    pub id: Option<PullRequestId>,
    pub state: PrState,
    pub base: BranchName,
    pub stack_parent: Option<PullRequestId>,
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
    pub stack_link: StackLink,
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

    let tips = args.tips.unwrap_or_else(|| Revset::new(anchor.as_str()));

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
    print_plan(me, &plan, &repo_root);

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

/// Bookmarks that would be pushed as a pull request containing no changes.
fn bookmarks_with_an_empty_diff(plan: &[PlanEntry]) -> Vec<&BookmarkName> {
    plan.iter()
        .filter(|entry| matches!(entry.action, Action::Create | Action::Update) && entry.empty)
        .map(|entry| &entry.bookmark)
        .collect()
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

fn build_plan<F: Forge>(
    graph: &StackGraph,
    base: &BranchName,
    me: Option<&AuthorName>,
    forge: &F,
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
    let stack_ids = active_pull_request_ids(&prs);
    let mut plan: Vec<PlanEntry> = Vec::new();
    for (bookmark, pr) in bookmarks.into_iter().zip(prs) {
        let parent_mark = graph.parent_bookmark(&bookmark);
        let parent = parent_mark.as_ref().map_or_else(
            || base.clone(),
            |parent| BranchName::new(parent.name.as_str()),
        );
        let empty = graph.is_diff_empty(parent_mark.as_ref(), &bookmark);
        let parent_entry = parent_mark
            .as_ref()
            .and_then(|parent| plan.iter().find(|entry| entry.bookmark == parent.name));
        let desired_stack_parent = parent_entry.map_or(DesiredStackParent::None, |parent_entry| {
            desired_stack_parent::<F>(parent_entry.action, parent_entry.pr.as_ref())
        });
        let stack_link_outdated = stack_link_outdated(
            pr.as_ref().and_then(|pr| pr.stack_parent.as_ref()),
            &desired_stack_parent,
            &stack_ids,
        );
        let stack_link = desired_stack_link(&desired_stack_parent, &parent, stack_link_outdated);
        let action = plan_action(pr.as_ref(), &parent, stack_link_outdated);
        plan.push(PlanEntry {
            bookmark: bookmark.name,
            commit: bookmark.target,
            parent,
            stack_link,
            pr,
            action,
            empty,
        });
    }
    Ok(plan)
}

fn active_pull_request_ids(pull_requests: &[Option<PullRequest>]) -> Vec<PullRequestId> {
    pull_requests
        .iter()
        .flatten()
        .filter(|pull_request| matches!(pull_request.state, PrState::Open | PrState::Draft))
        .filter_map(|pull_request| pull_request.id.clone())
        .collect()
}

enum DesiredStackParent<'a> {
    None,
    Existing(&'a PullRequest),
    BeingCreated,
}

fn desired_stack_parent<F: Forge>(
    parent_action: Action,
    parent_request: Option<&PullRequest>,
) -> DesiredStackParent<'_> {
    if !F::LINKS_STACKED_PRS || parent_action == Action::Skip {
        return DesiredStackParent::None;
    }
    parent_request.map_or(
        DesiredStackParent::BeingCreated,
        DesiredStackParent::Existing,
    )
}

fn stack_link_outdated(
    current: Option<&PullRequestId>,
    desired: &DesiredStackParent,
    stack_ids: &[PullRequestId],
) -> bool {
    match desired {
        DesiredStackParent::Existing(parent_request) => current != parent_request.id.as_ref(),
        DesiredStackParent::BeingCreated => true,
        DesiredStackParent::None => current.is_some_and(|id| stack_ids.contains(id)),
    }
}

fn desired_stack_link(
    desired: &DesiredStackParent,
    parent: &BranchName,
    stack_link_outdated: bool,
) -> StackLink {
    if !stack_link_outdated {
        return StackLink::Unchanged;
    }
    match desired {
        DesiredStackParent::Existing(parent_request) => {
            StackLink::LinkToPullRequest(parent_request.number)
        }
        DesiredStackParent::BeingCreated => StackLink::LinkToBranch(parent.clone()),
        DesiredStackParent::None => StackLink::Clear,
    }
}

fn plan_action(
    pull_request: Option<&PullRequest>,
    parent: &BranchName,
    stack_link_outdated: bool,
) -> Action {
    match pull_request {
        None => Action::Create,
        Some(pull_request) if !pull_request.owned_by_current_user => Action::Skip,
        Some(pull_request) if matches!(pull_request.state, PrState::Merged | PrState::Closed) => {
            Action::Skip
        }
        Some(pull_request) if pull_request.base != *parent || stack_link_outdated => Action::Update,
        Some(_) => Action::Noop,
    }
}

fn describe_stack_link(stack_link: &StackLink) -> Option<String> {
    match stack_link {
        StackLink::Unchanged => None,
        StackLink::Clear => Some("unstacked".to_string()),
        StackLink::LinkToPullRequest(number) => Some(format!("stacked on #{number}")),
        StackLink::LinkToBranch(branch) => Some(format!("stacked on {branch}")),
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
                let stacked = describe_stack_link(&entry.stack_link)
                    .map_or_else(String::new, |link| format!(", {link}"));
                println!(
                    "  CREATE  {}  (base {}{stacked})",
                    entry.bookmark, entry.parent
                );
            }
            (Action::Update, Some(pr)) => {
                let mut changes: Vec<String> = Vec::new();
                if pr.base != entry.parent {
                    changes.push(format!("base {} -> {}", pr.base, entry.parent));
                }
                changes.extend(describe_stack_link(&entry.stack_link));
                println!(
                    "  UPDATE  #{} {}  ({})",
                    pr.number,
                    entry.bookmark,
                    changes.join(", ")
                );
            }
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
    use super::{
        Action, DesiredStackParent, PrState, PullRequest, active_pull_request_ids,
        desired_stack_link, desired_stack_parent, plan_action, stack_link_outdated,
    };
    use crate::origin::Origin;
    use git::{BranchName, PullRequestId, PullRequestNumber, StackLink};

    #[test]
    fn missing_pull_requests_are_created() {
        assert_eq!(
            plan_action(None, &BranchName::new("main"), false),
            Action::Create
        );
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
            id: None,
            state,
            base: parent.clone(),
            stack_parent: None,
            author: None,
            owned_by_current_user,
        };
        assert_eq!(
            plan_action(Some(&pull_request), &parent, false),
            matching_base
        );
        pull_request.base = BranchName::new("old-base");
        assert_eq!(
            plan_action(Some(&pull_request), &parent, false),
            changed_base
        );
    }

    fn owned_open_pull_request(
        number: u64,
        id: &str,
        stack_parent: Option<PullRequestId>,
    ) -> PullRequest {
        PullRequest {
            number: PullRequestNumber::new(number),
            id: Some(PullRequestId::new(id)),
            state: PrState::Open,
            base: BranchName::new("main"),
            stack_parent,
            author: None,
            owned_by_current_user: true,
        }
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

    #[test]
    fn a_link_matching_the_parent_pull_request_stays_noop() {
        let parent = owned_open_pull_request(1, "change-1", None);
        let child = owned_open_pull_request(2, "change-2", Some(PullRequestId::new("change-1")));
        let outdated = stack_link_outdated(
            child.stack_parent.as_ref(),
            &DesiredStackParent::Existing(&parent),
            &[
                PullRequestId::new("change-1"),
                PullRequestId::new("change-2"),
            ],
        );
        assert_eq!(
            plan_action(Some(&child), &BranchName::new("main"), outdated),
            Action::Noop
        );
    }

    #[test]
    fn a_link_pointing_at_another_pull_request_is_updated() {
        let parent = owned_open_pull_request(1, "change-1", None);
        let child = owned_open_pull_request(2, "change-2", Some(PullRequestId::new("change-9")));
        let outdated = stack_link_outdated(
            child.stack_parent.as_ref(),
            &DesiredStackParent::Existing(&parent),
            &[
                PullRequestId::new("change-1"),
                PullRequestId::new("change-2"),
            ],
        );
        assert_eq!(
            plan_action(Some(&child), &BranchName::new("main"), outdated),
            Action::Update
        );
    }

    #[test]
    fn a_missing_link_to_the_parent_pull_request_is_updated() {
        let parent = owned_open_pull_request(1, "change-1", None);
        let child = owned_open_pull_request(2, "change-2", None);
        let outdated = stack_link_outdated(
            child.stack_parent.as_ref(),
            &DesiredStackParent::Existing(&parent),
            &[
                PullRequestId::new("change-1"),
                PullRequestId::new("change-2"),
            ],
        );
        assert_eq!(
            plan_action(Some(&child), &BranchName::new("main"), outdated),
            Action::Update
        );
    }

    #[test]
    fn an_existing_parent_is_linked_by_its_number() {
        let parent = owned_open_pull_request(1, "change-1", None);
        assert_eq!(
            desired_stack_link(
                &DesiredStackParent::Existing(&parent),
                &BranchName::new("parent-branch"),
                true
            ),
            StackLink::LinkToPullRequest(PullRequestNumber::new(1))
        );
    }

    #[test]
    fn a_parent_created_in_this_run_is_linked_by_its_branch() {
        assert_eq!(
            desired_stack_link(
                &DesiredStackParent::BeingCreated,
                &BranchName::new("parent-branch"),
                true
            ),
            StackLink::LinkToBranch(BranchName::new("parent-branch"))
        );
    }

    #[test]
    fn a_parent_created_in_this_run_updates_the_child() {
        let child = owned_open_pull_request(2, "change-2", None);
        let outdated = stack_link_outdated(
            child.stack_parent.as_ref(),
            &DesiredStackParent::BeingCreated,
            &[PullRequestId::new("change-2")],
        );
        assert_eq!(
            plan_action(Some(&child), &BranchName::new("main"), outdated),
            Action::Update
        );
    }

    #[test]
    fn a_skipped_parent_leaves_the_child_unlinked() {
        let parent = owned_open_pull_request(1, "change-1", None);
        assert!(matches!(
            desired_stack_parent::<Origin>(Action::Skip, Some(&parent)),
            DesiredStackParent::None
        ));
    }

    #[test]
    fn a_root_linked_inside_the_stack_is_unlinked() {
        let root = owned_open_pull_request(2, "change-2", Some(PullRequestId::new("change-1")));
        let outdated = stack_link_outdated(
            root.stack_parent.as_ref(),
            &DesiredStackParent::None,
            &[
                PullRequestId::new("change-1"),
                PullRequestId::new("change-2"),
            ],
        );
        assert_eq!(
            desired_stack_link(
                &DesiredStackParent::None,
                &BranchName::new("main"),
                outdated
            ),
            StackLink::Clear
        );
    }

    #[test]
    fn a_root_linked_outside_the_stack_stays_noop() {
        let root =
            owned_open_pull_request(2, "change-2", Some(PullRequestId::new("change-elsewhere")));
        let outdated = stack_link_outdated(
            root.stack_parent.as_ref(),
            &DesiredStackParent::None,
            &[PullRequestId::new("change-2")],
        );
        assert_eq!(
            plan_action(Some(&root), &BranchName::new("main"), outdated),
            Action::Noop
        );
    }

    #[test]
    fn a_root_linked_outside_the_stack_keeps_its_link_when_its_base_changes() {
        let root =
            owned_open_pull_request(2, "change-2", Some(PullRequestId::new("change-elsewhere")));
        let outdated = stack_link_outdated(
            root.stack_parent.as_ref(),
            &DesiredStackParent::None,
            &[PullRequestId::new("change-2")],
        );
        assert_eq!(
            plan_action(Some(&root), &BranchName::new("new-base"), outdated),
            Action::Update
        );
        assert_eq!(
            desired_stack_link(
                &DesiredStackParent::None,
                &BranchName::new("new-base"),
                outdated
            ),
            StackLink::Unchanged
        );
    }

    #[test]
    fn a_link_to_a_merged_parent_in_the_stack_is_left_alone() {
        let merged_parent = PullRequest {
            state: PrState::Merged,
            ..owned_open_pull_request(1, "change-1", None)
        };
        let child = owned_open_pull_request(2, "change-2", Some(PullRequestId::new("change-1")));
        let stack_ids = active_pull_request_ids(&[Some(merged_parent), Some(child)]);
        assert!(!stack_link_outdated(
            Some(&PullRequestId::new("change-1")),
            &DesiredStackParent::None,
            &stack_ids
        ));
    }
}
