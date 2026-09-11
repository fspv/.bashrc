use common::Result;
use git::{AuthorName, BranchName};
use jj::{BookmarkName, git_export, git_push};

use crate::pr_sync::{Action, Forge, PlanEntry, PrState, PullRequest};

pub struct Origin;

impl Forge for Origin {
    const NAME: &'static str = "Origin";

    fn current_user(&self) -> Result<Option<AuthorName>> {
        Ok(None)
    }

    fn prs_for_branches(
        &self,
        branches: &[BranchName],
        _current_user: Option<&AuthorName>,
    ) -> Result<Vec<Option<PullRequest>>> {
        Ok(::origin::prs_for_branches(branches)?
            .into_iter()
            .map(|request| request.map(PullRequest::from))
            .collect())
    }

    fn apply(&self, plan: &[PlanEntry], _trunk: &BranchName, ready: bool) -> Result<()> {
        let push: Vec<BookmarkName> = plan
            .iter()
            .filter(|entry| entry.action != Action::Skip)
            .map(|entry| entry.bookmark.clone())
            .collect();
        if !push.is_empty() {
            git_push(&push)?;
            git_export()?;
        }

        for entry in plan {
            match (&entry.action, &entry.pr) {
                (Action::Create, _) => ::origin::create_pr(
                    &BranchName::new(entry.bookmark.as_str()),
                    &entry.parent,
                    ready,
                )?,
                (Action::Update, Some(request)) => {
                    ::origin::set_pr_base(request.number, &entry.parent)?;
                }
                (Action::Noop, Some(request))
                    if ::origin::head_commit(request.number)? != entry.commit =>
                {
                    ::origin::refresh_pr(request.number)?;
                }
                _ => {}
            }
        }
        Ok(())
    }
}

impl From<::origin::PullRequest> for PullRequest {
    fn from(request: ::origin::PullRequest) -> Self {
        Self {
            number: request.number,
            state: match request.state {
                ::origin::PrState::Open => PrState::Open,
                ::origin::PrState::Draft => PrState::Draft,
                ::origin::PrState::Closed => PrState::Closed,
                ::origin::PrState::Merged => PrState::Merged,
            },
            base: request.base,
            author: None,
            owned_by_current_user: request.owned_by_current_user,
        }
    }
}
