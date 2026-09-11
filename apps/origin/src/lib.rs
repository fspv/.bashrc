use std::fmt;
use std::num::NonZeroU64;
use std::path::PathBuf;

use common::{Error, Result, run_output_env, run_streaming_checked};
use git::{AuthorName, BranchName, ObjectId, PullRequestNumber};
use serde::Deserialize;
use url::Url;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum PrState {
    Open,
    Draft,
    Closed,
    Merged,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PullRequest {
    pub number: PullRequestNumber,
    pub state: PrState,
    pub url: Url,
    pub base: BranchName,
    pub owned_by_current_user: bool,
}

impl fmt::Display for PrState {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::Open => "OPEN",
            Self::Draft => "DRAFT",
            Self::Closed => "CLOSED",
            Self::Merged => "MERGED",
        })
    }
}

impl fmt::Display for PullRequest {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "#{}  {}  {}", self.number, self.state, self.url)
    }
}

#[derive(Deserialize)]
struct RawPullRequest {
    number: PullRequestNumber,
    status: PrState,
    url: Url,
    #[serde(rename = "baseRef")]
    base_ref: BranchName,
}

#[derive(Deserialize)]
struct NumberResponse {
    number: PullRequestNumber,
}

impl RawPullRequest {
    fn into_pull_request(self, owned: &[NumberResponse]) -> PullRequest {
        PullRequest {
            number: self.number,
            state: self.status,
            url: self.url,
            base: BranchName::new(
                self.base_ref
                    .as_str()
                    .strip_prefix("refs/heads/")
                    .unwrap_or(self.base_ref.as_str()),
            ),
            owned_by_current_user: owned.iter().any(|entry| entry.number == self.number),
        }
    }
}

/// # Errors
/// Returns an error if `origin pr list` fails or its JSON cannot be parsed.
pub fn pr_for_branch(branch: &BranchName) -> Result<Option<PullRequest>> {
    let json = list_for_branch(branch, false, "number,status,baseRef,url")?;
    let requests: Vec<RawPullRequest> =
        serde_json::from_str(&json).map_err(|error| Error::Parse(error.to_string()))?;
    let Some(request) = requests.into_iter().next() else {
        return Ok(None);
    };
    let json = list_for_branch(branch, true, "number")?;
    let owned: Vec<NumberResponse> =
        serde_json::from_str(&json).map_err(|error| Error::Parse(error.to_string()))?;
    Ok(Some(request.into_pull_request(&owned)))
}

/// # Errors
/// Returns an error if any branch's pull request lookup fails.
pub fn prs_for_branches(branches: &[BranchName]) -> Result<Vec<Option<PullRequest>>> {
    branches.iter().map(pr_for_branch).collect()
}

fn list_for_branch(branch: &BranchName, mine: bool, fields: &str) -> Result<String> {
    let mut arguments = vec![
        "pr",
        "list",
        "--head",
        branch.as_str(),
        "--state",
        "all",
        "--limit",
        "1",
        "--json",
        fields,
    ];
    if mine {
        arguments.push("--mine");
    }
    run_output_env(
        "origin",
        &arguments,
        &[("CLICOLOR_FORCE", "0"), ("NO_COLOR", "1")],
    )
}

/// # Errors
/// Returns an error if `origin pr create` fails.
pub fn create_pr(head: &BranchName, base: &BranchName, ready: bool) -> Result<()> {
    run_streaming_checked(
        "origin",
        &[
            "pr",
            "create",
            "--head",
            head.as_str(),
            "--base",
            base.as_str(),
            "--fill",
            "--status",
            if ready { "open" } else { "draft" },
        ],
    )
}

/// # Errors
/// Returns an error if `origin pr edit` fails.
pub fn set_pr_base(number: PullRequestNumber, base: &BranchName) -> Result<()> {
    run_streaming_checked(
        "origin",
        &["pr", "edit", &number.to_string(), "--base", base.as_str()],
    )
}

#[derive(Deserialize)]
struct HeadBranch {
    #[serde(rename = "headRef")]
    name: BranchName,
}

/// # Errors
/// Returns an error if `origin pr view` fails or its JSON cannot be parsed.
pub fn pr_head(number: PullRequestNumber) -> Result<BranchName> {
    let json = run_output_env(
        "origin",
        &["pr", "view", &number.to_string(), "--json", "headRef"],
        &[("CLICOLOR_FORCE", "0"), ("NO_COLOR", "1")],
    )?;
    let head: HeadBranch =
        serde_json::from_str(&json).map_err(|error| Error::Parse(error.to_string()))?;
    Ok(BranchName::new(
        head.name
            .as_str()
            .strip_prefix("refs/heads/")
            .unwrap_or(head.name.as_str()),
    ))
}

pub struct UnresolvedThread {
    pub path: PathBuf,
    pub line: Option<NonZeroU64>,
    pub author: AuthorName,
    pub body: String,
}

#[derive(Deserialize)]
struct Thread {
    path: Option<PathBuf>,
    #[serde(rename = "startLine")]
    line: Option<NonZeroU64>,
    comments: Vec<Comment>,
}

#[derive(Deserialize)]
struct Comment {
    author: Option<RawAuthor>,
    body: String,
}

#[derive(Deserialize)]
struct RawAuthor {
    #[serde(rename = "displayName")]
    name: AuthorName,
}

/// # Errors
/// Returns an error if `origin pr thread list` fails or its JSON cannot be parsed.
pub fn unresolved_threads(number: PullRequestNumber) -> Result<Vec<UnresolvedThread>> {
    let json = run_output_env(
        "origin",
        &[
            "pr",
            "thread",
            "list",
            &number.to_string(),
            "--unresolved",
            "--json",
            "path,startLine,comments",
        ],
        &[("CLICOLOR_FORCE", "0"), ("NO_COLOR", "1")],
    )?;
    let threads: Vec<Thread> =
        serde_json::from_str(&json).map_err(|error| Error::Parse(error.to_string()))?;
    Ok(threads
        .into_iter()
        .filter_map(|thread| {
            let path = thread.path?;
            thread
                .comments
                .into_iter()
                .next()
                .map(|comment| UnresolvedThread {
                    path,
                    line: thread.line,
                    author: comment
                        .author
                        .map_or_else(|| AuthorName::new("deleted user"), |author| author.name),
                    body: comment.body,
                })
        })
        .collect())
}

#[derive(Deserialize)]
struct HeadCommit {
    #[serde(rename = "headSha")]
    head_sha: ObjectId,
}

/// # Errors
/// Returns an error if `origin pr view` fails or its JSON cannot be parsed.
pub fn head_commit(number: PullRequestNumber) -> Result<ObjectId> {
    let json = run_output_env(
        "origin",
        &["pr", "view", &number.to_string(), "--json", "headSha"],
        &[("CLICOLOR_FORCE", "0"), ("NO_COLOR", "1")],
    )?;
    let response: HeadCommit =
        serde_json::from_str(&json).map_err(|error| Error::Parse(error.to_string()))?;
    Ok(response.head_sha)
}

/// # Errors
/// Returns an error if `origin pr refresh` fails.
pub fn refresh_pr(number: PullRequestNumber) -> Result<()> {
    run_streaming_checked("origin", &["pr", "refresh", &number.to_string()])
}

#[cfg(test)]
mod tests {
    use super::{NumberResponse, PrState, PullRequestNumber, RawPullRequest};

    #[test]
    fn parses_list_and_normalizes_qualified_base() -> serde_json::Result<()> {
        let request: RawPullRequest = serde_json::from_str(
            r#"{"number":42,"status":"draft","baseRef":"refs/heads/feature/base","url":"https://origin.example/pull/42"}"#,
        )?;
        let request = request.into_pull_request(&[NumberResponse {
            number: PullRequestNumber::new(42),
        }]);
        assert_eq!(request.number, PullRequestNumber::new(42));
        assert_eq!(request.url.as_str(), "https://origin.example/pull/42");
        assert_eq!(request.state, PrState::Draft);
        assert_eq!(request.base.as_str(), "feature/base");
        assert!(request.owned_by_current_user);
        Ok(())
    }

    #[test]
    fn older_owned_request_does_not_make_latest_owned() -> serde_json::Result<()> {
        let request: RawPullRequest = serde_json::from_str(
            r#"{"number":43,"status":"open","baseRef":"main","url":"https://origin.example/pull/43"}"#,
        )?;
        let request = request.into_pull_request(&[NumberResponse {
            number: PullRequestNumber::new(42),
        }]);
        assert!(!request.owned_by_current_user);
        assert_eq!(request.base.as_str(), "main");
        Ok(())
    }

    #[test]
    fn parses_terminal_states() -> serde_json::Result<()> {
        assert_eq!(
            serde_json::from_str::<PrState>(r#""closed""#)?,
            PrState::Closed
        );
        assert_eq!(
            serde_json::from_str::<PrState>(r#""merged""#)?,
            PrState::Merged
        );
        Ok(())
    }

    #[test]
    fn rejects_unrecognized_state() {
        assert!(serde_json::from_str::<PrState>(r#""unspecified""#).is_err());
    }
}
