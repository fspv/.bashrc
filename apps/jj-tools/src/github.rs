use std::thread::sleep;
use std::time::Duration;

use common::Result;
use git::{AuthorName, BranchName};
use jj::{BookmarkName, git_export, git_push};

use crate::pr_sync::{Action, Forge, PlanEntry, PrState, PullRequest};

pub struct GitHub;

impl Forge for GitHub {
    const NAME: &'static str = "GitHub";
    const LINKS_STACKED_PRS: bool = false;

    fn current_user(&self) -> Result<Option<AuthorName>> {
        ::github::current_user().map(Some)
    }

    fn prs_for_branches(
        &self,
        branches: &[BranchName],
        current_user: Option<&AuthorName>,
    ) -> Result<Vec<Option<PullRequest>>> {
        Ok(::github::prs_for_branches(branches)?
            .into_iter()
            .map(|pull_request| {
                pull_request.map(|pull_request| adapt_pull_request(pull_request, current_user))
            })
            .collect())
    }

    fn apply(&self, plan: &[PlanEntry], trunk: &BranchName, ready: bool) -> Result<()> {
        for entry in plan {
            if let (Action::Update, Some(pr)) = (&entry.action, &entry.pr) {
                ::github::set_pr_base(pr.number, trunk)?;
            }
        }

        let push: Vec<BookmarkName> = plan
            .iter()
            .filter(|entry| entry.action != Action::Skip)
            .map(|entry| entry.bookmark.clone())
            .collect();
        for (index, bookmark) in push.iter().enumerate() {
            if index > 0 {
                println!(
                    "Sleeping 15s before the next push to avoid {} rate limits...",
                    Self::NAME
                );
                sleep(Duration::from_secs(15));
            }
            git_push(std::slice::from_ref(bookmark))?;
        }
        if !push.is_empty() {
            git_export()?;
        }

        for entry in plan {
            match (&entry.action, &entry.pr) {
                (Action::Update, Some(pr)) => ::github::set_pr_base(pr.number, &entry.parent)?,
                (Action::Create, _) => {
                    ::github::create_pr(
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
}

fn adapt_pull_request(
    pull_request: ::github::PullRequest,
    current_user: Option<&AuthorName>,
) -> PullRequest {
    PullRequest {
        number: pull_request.number,
        id: None,
        state: match pull_request.state {
            ::github::PrState::Open => PrState::Open,
            ::github::PrState::Draft => PrState::Draft,
            ::github::PrState::Closed => PrState::Closed,
            ::github::PrState::Merged => PrState::Merged,
        },
        base: pull_request.base,
        stack_parent: None,
        owned_by_current_user: current_user == Some(&pull_request.author),
        author: Some(pull_request.author),
    }
}
