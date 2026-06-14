use std::fmt;

use common::{run_output_env, run_streaming_checked, Error, Result};
use serde::Deserialize;

// gh honours CLICOLOR_FORCE even for `--json` output, which would make it
// unparseable. Setting CLICOLOR_FORCE=0 forces plain output.
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

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PullRequest {
    pub number: u64,
    pub state: PrState,
    pub url: String,
    pub base: BranchName,
    pub author: String,
}

impl fmt::Display for PullRequest {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "#{}  {}  {}", self.number, self.state, self.url)
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
    author: Author,
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
        Self {
            number: raw.number,
            state,
            url: raw.url,
            base: BranchName(raw.base_ref_name),
            author: raw.author.login,
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
            "number,state,isDraft,url,baseRefName,author",
        ],
        PLAIN_OUTPUT,
    )?;
    let raws: Vec<RawPullRequest> =
        serde_json::from_str(&json).map_err(|e| Error::Parse(e.to_string()))?;
    Ok(raws.into_iter().next().map(PullRequest::from))
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
