use std::collections::HashMap;
use std::fmt;

use common::{Error, Result, run_output_env, run_streaming_checked};
use serde::Deserialize;

// gh honours CLICOLOR_FORCE even for `--json` output, which would break JSON
// parsing. Setting CLICOLOR_FORCE=0 forces plain output.
const PLAIN_OUTPUT: &[(&str, &str)] = &[("CLICOLOR_FORCE", "0"), ("NO_COLOR", "1")];

/// A git branch name used as a pull request's head or base ref.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BranchName(String);

impl BranchName {
    #[must_use]
    pub fn new(name: impl Into<String>) -> Self {
        Self(name.into())
    }
    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for BranchName {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

/// State of a pull request, with draft modeled explicitly.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PrState {
    Open,
    Draft,
    Closed,
    Merged,
}

impl fmt::Display for PrState {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(match self {
            Self::Open => "OPEN",
            Self::Draft => "DRAFT",
            Self::Closed => "CLOSED",
            Self::Merged => "MERGED",
        })
    }
}

/// The aggregate review decision GitHub reports for a pull request.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReviewDecision {
    Approved,
    ChangesRequested,
    ReviewRequired,
}

impl fmt::Display for ReviewDecision {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(match self {
            Self::Approved => "APPROVED",
            Self::ChangesRequested => "CHANGES_REQUESTED",
            Self::ReviewRequired => "REVIEW_REQUIRED",
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PullRequest {
    pub number: u64,
    pub state: PrState,
    pub url: String,
    pub base: BranchName,
    pub author: String,
    /// `None` when the repo requires no review and none was given.
    pub review_decision: Option<ReviewDecision>,
}

impl fmt::Display for PullRequest {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "#{}  {}", self.number, self.state)?;
        if let Some(decision) = self.review_decision {
            write!(f, "  {decision}")?;
        }
        write!(f, "  {}", self.url)
    }
}

#[derive(Deserialize)]
struct Author {
    login: String,
}

#[derive(Deserialize)]
struct RawPullRequest {
    number: u64,
    state: String,
    #[serde(rename = "isDraft")]
    is_draft: bool,
    url: String,
    #[serde(rename = "baseRefName")]
    base_ref_name: String,
    /// `None` for pull requests whose author account was deleted.
    author: Option<Author>,
    #[serde(rename = "reviewDecision")]
    review_decision: Option<String>,
}

impl From<RawPullRequest> for PullRequest {
    fn from(raw: RawPullRequest) -> Self {
        let state = if raw.is_draft && raw.state == "OPEN" {
            PrState::Draft
        } else {
            match raw.state.as_str() {
                "MERGED" => PrState::Merged,
                "CLOSED" => PrState::Closed,
                _ => PrState::Open,
            }
        };
        let review_decision = match raw.review_decision.as_deref() {
            Some("APPROVED") => Some(ReviewDecision::Approved),
            Some("CHANGES_REQUESTED") => Some(ReviewDecision::ChangesRequested),
            Some("REVIEW_REQUIRED") => Some(ReviewDecision::ReviewRequired),
            _ => None,
        };
        Self {
            number: raw.number,
            state,
            url: raw.url,
            base: BranchName(raw.base_ref_name),
            author: raw.author.map_or_else(|| "ghost".to_string(), |a| a.login),
            review_decision,
        }
    }
}

/// The most recent pull request (any state) whose head is `branch`, if any.
///
/// # Errors
/// Returns an error if the `gh` command fails or its JSON cannot be parsed.
pub fn pr_for_branch(branch: &BranchName) -> Result<Option<PullRequest>> {
    let json = run_output_env(
        "gh",
        &[
            "pr",
            "list",
            "--head",
            branch.as_str(),
            "--state",
            "all",
            "--json",
            "number,state,isDraft,url,baseRefName,author,reviewDecision",
        ],
        PLAIN_OUTPUT,
    )?;
    let raws: Vec<RawPullRequest> =
        serde_json::from_str(&json).map_err(|e| Error::Parse(e.to_string()))?;
    Ok(raws.into_iter().next().map(PullRequest::from))
}

#[derive(Deserialize)]
struct BranchPullRequestsResponse {
    data: BranchPullRequestsData,
}

#[derive(Deserialize)]
struct BranchPullRequestsData {
    repository: HashMap<String, RawPullRequestNodes>,
}

#[derive(Deserialize)]
struct RawPullRequestNodes {
    nodes: Vec<RawPullRequest>,
}

/// The most recent pull request (any state) whose head is each branch, in
/// input order, fetched with a single GraphQL request.
///
/// # Errors
/// Returns an error if the `gh api graphql` command fails or its JSON cannot
/// be parsed.
pub fn prs_for_branches(branches: &[BranchName]) -> Result<Vec<Option<PullRequest>>> {
    let indices = 0..branches.len();
    let variables: Vec<String> = indices
        .clone()
        .map(|index| format!(", $branch{index}: String!"))
        .collect();
    let fields: Vec<String> = indices
        .clone()
        .map(|index| {
            format!(
                "branch{index}: pullRequests(headRefName: $branch{index}, first: 1, \
                 orderBy: {{field: CREATED_AT, direction: DESC}}) {{ nodes {{ \
                 number state isDraft url baseRefName author {{ login }} reviewDecision }} }}"
            )
        })
        .collect();
    let query = format!(
        "query=query($owner: String!, $repo: String!{}) {{ \
         repository(owner: $owner, name: $repo) {{\n{}\n}} }}",
        variables.concat(),
        fields.join("\n")
    );
    let branch_args: Vec<String> = branches
        .iter()
        .enumerate()
        .map(|(index, branch)| format!("branch{index}={}", branch.as_str()))
        .collect();
    let mut args = vec!["api", "graphql", "-F", "owner={owner}", "-F", "repo={repo}"];
    for branch_arg in &branch_args {
        args.extend_from_slice(&["-f", branch_arg]);
    }
    args.extend_from_slice(&["-f", &query]);
    let json = run_output_env("gh", &args, PLAIN_OUTPUT)?;
    let mut response: BranchPullRequestsResponse =
        serde_json::from_str(&json).map_err(|e| Error::Parse(e.to_string()))?;
    indices
        .map(|index| {
            let alias = format!("branch{index}");
            let nodes =
                response.data.repository.remove(&alias).ok_or_else(|| {
                    Error::Parse(format!("missing `{alias}` in GraphQL response"))
                })?;
            Ok(nodes.nodes.into_iter().next().map(PullRequest::from))
        })
        .collect()
}

/// An unresolved review thread on a pull request, summarized by its first comment.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UnresolvedThread {
    pub path: String,
    /// `None` for outdated threads whose line no longer exists.
    pub line: Option<u64>,
    pub author: String,
    pub body: String,
}

const REVIEW_THREADS_QUERY: &str = "\
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        nodes {
          isResolved
          path
          line
          comments(first: 1) { nodes { author { login } body } }
        }
      }
    }
  }
}";

#[derive(Deserialize)]
struct ThreadsResponse {
    data: ThreadsData,
}

#[derive(Deserialize)]
struct ThreadsData {
    repository: ThreadsRepository,
}

#[derive(Deserialize)]
struct ThreadsRepository {
    #[serde(rename = "pullRequest")]
    pull_request: ThreadsPullRequest,
}

#[derive(Deserialize)]
struct ThreadsPullRequest {
    #[serde(rename = "reviewThreads")]
    review_threads: RawThreadNodes,
}

#[derive(Deserialize)]
struct RawThreadNodes {
    nodes: Vec<RawThread>,
}

#[derive(Deserialize)]
struct RawThread {
    #[serde(rename = "isResolved")]
    is_resolved: bool,
    path: String,
    line: Option<u64>,
    comments: RawCommentNodes,
}

#[derive(Deserialize)]
struct RawCommentNodes {
    nodes: Vec<RawComment>,
}

#[derive(Deserialize)]
struct RawComment {
    /// `None` for comments whose author account was deleted.
    author: Option<Author>,
    body: String,
}

/// The unresolved review threads of PR `number` in the current repo.
///
/// # Errors
/// Returns an error if the `gh api graphql` command fails or its JSON cannot
/// be parsed.
pub fn unresolved_threads(number: u64) -> Result<Vec<UnresolvedThread>> {
    let query_arg = format!("query={REVIEW_THREADS_QUERY}");
    let number_arg = format!("number={number}");
    let json = run_output_env(
        "gh",
        &[
            "api",
            "graphql",
            "-F",
            "owner={owner}",
            "-F",
            "repo={repo}",
            "-F",
            &number_arg,
            "-f",
            &query_arg,
        ],
        PLAIN_OUTPUT,
    )?;
    let response: ThreadsResponse =
        serde_json::from_str(&json).map_err(|e| Error::Parse(e.to_string()))?;
    let threads = response
        .data
        .repository
        .pull_request
        .review_threads
        .nodes
        .into_iter()
        .filter(|thread| !thread.is_resolved)
        .filter_map(|thread| {
            thread
                .comments
                .nodes
                .into_iter()
                .next()
                .map(|comment| UnresolvedThread {
                    path: thread.path,
                    line: thread.line,
                    author: comment
                        .author
                        .map_or_else(|| "ghost".to_string(), |a| a.login),
                    body: comment.body,
                })
        })
        .collect();
    Ok(threads)
}

/// The login of the authenticated GitHub user.
///
/// # Errors
/// Returns an error if the `gh api user` command fails.
pub fn current_user() -> Result<String> {
    run_output_env("gh", &["api", "user", "--jq", ".login"], PLAIN_OUTPUT)
}

/// Create a PR for `head` based on `base`, drafted unless `ready`.
///
/// # Errors
/// Returns an error if the `gh pr create` command fails.
pub fn create_pr(head: &BranchName, base: &BranchName, ready: bool) -> Result<()> {
    let mut args = vec![
        "pr",
        "create",
        "--head",
        head.as_str(),
        "--base",
        base.as_str(),
        "--fill",
    ];
    if !ready {
        args.push("--draft");
    }
    run_streaming_checked("gh", &args)
}

/// Retarget an existing PR's base branch.
///
/// # Errors
/// Returns an error if the `gh pr edit` command fails.
pub fn set_pr_base(number: u64, base: &BranchName) -> Result<()> {
    let number = number.to_string();
    run_streaming_checked("gh", &["pr", "edit", &number, "--base", base.as_str()])
}
