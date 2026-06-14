use std::fmt;
use std::fs;
use std::path::{Path, PathBuf};
use std::str::FromStr;

use common::{run_output, run_streaming, run_streaming_checked, Error, Result};

/// A jj change id: the stable identifier of a change across rewrites.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ChangeId(String);

impl ChangeId {
    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl FromStr for ChangeId {
    type Err = std::convert::Infallible;
    fn from_str(s: &str) -> std::result::Result<Self, Self::Err> {
        Ok(Self(s.to_string()))
    }
}

impl fmt::Display for ChangeId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

/// A local bookmark (branch) name.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BookmarkName(String);

impl BookmarkName {
    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for BookmarkName {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

/// A jj revset expression (e.g. `trunk()`, `@`, `ci | exclude`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Revset(String);

impl Revset {
    #[must_use]
    pub fn new(expr: impl Into<String>) -> Self {
        Self(expr.into())
    }
    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

const BOOKMARK_NAMES: &str = "local_bookmarks.map(|b| b.name()).join(\" \")";

fn names(output: &str) -> Vec<BookmarkName> {
    output
        .split_whitespace()
        .map(|name| BookmarkName(name.to_string()))
        .collect()
}

fn bookmark_list(extra_args: &[&str], template: &str) -> Result<Vec<BookmarkName>> {
    let mut args = vec!["--ignore-working-copy", "bookmark", "list"];
    args.extend_from_slice(extra_args);
    args.extend_from_slice(&["-T", template]);
    let output = run_output("jj", &args)?;
    Ok(output
        .lines()
        .filter(|line| !line.is_empty())
        .map(|line| BookmarkName(line.to_string()))
        .collect())
}

/// Local bookmarks pointing at the given change, in jj template order.
///
/// # Errors
/// Returns an error if the `jj` command fails.
pub fn bookmarks(change_id: &ChangeId) -> Result<Vec<BookmarkName>> {
    let output = run_output(
        "jj",
        &[
            "--ignore-working-copy",
            "log",
            "--no-graph",
            "-r",
            change_id.as_str(),
            "-T",
            BOOKMARK_NAMES,
        ],
    )?;
    Ok(names(&output))
}

/// Local bookmarks in `trunk..tips`, ordered bottom (near trunk) to top, deduped.
///
/// # Errors
/// Returns an error if the `jj` command fails.
pub fn bookmarks_in_range(trunk: &Revset, tips: &Revset) -> Result<Vec<BookmarkName>> {
    let revset = format!("({})..({}) & bookmarks()", trunk.as_str(), tips.as_str());
    let output = run_output(
        "jj",
        &[
            "--ignore-working-copy",
            "log",
            "--no-graph",
            "--reversed",
            "-r",
            &revset,
            "-T",
            "local_bookmarks.map(|b| b.name()).join(\" \") ++ \"\\n\"",
        ],
    )?;
    let mut ordered: Vec<BookmarkName> = Vec::new();
    for name in output.split_whitespace() {
        if !ordered.iter().any(|b| b.as_str() == name) {
            ordered.push(BookmarkName(name.to_string()));
        }
    }
    Ok(ordered)
}

/// The nearest bookmarked ancestor of `bookmark` above `trunk`, if any.
///
/// # Errors
/// Returns an error if the `jj` command fails.
pub fn parent_bookmark(trunk: &Revset, bookmark: &BookmarkName) -> Result<Option<BookmarkName>> {
    let revset = format!(
        "heads((({})..{} ~ {}) & bookmarks())",
        trunk.as_str(),
        bookmark.as_str(),
        bookmark.as_str()
    );
    let output = run_output(
        "jj",
        &[
            "--ignore-working-copy",
            "log",
            "--no-graph",
            "-r",
            &revset,
            "-T",
            BOOKMARK_NAMES,
        ],
    )?;
    Ok(names(&output).into_iter().next())
}

/// The change id of the working-copy commit.
///
/// # Errors
/// Returns an error if the `jj` command fails.
pub fn working_copy_change() -> Result<ChangeId> {
    let id = run_output(
        "jj",
        &["--ignore-working-copy", "log", "--no-graph", "-r", "@", "-T", "change_id"],
    )?;
    Ok(ChangeId(id))
}

/// Revset matching every leaf of the stack the `anchor` commit is on.
#[must_use]
pub fn current_stack_tips(trunk: &Revset, anchor: &str) -> Revset {
    Revset(format!(
        "heads(roots(({})..{}):: & mutable())",
        trunk.as_str(),
        anchor
    ))
}

/// Bookmarks that point at more than one commit (divergent / conflicted).
///
/// # Errors
/// Returns an error if the `jj` command fails.
pub fn conflicted_bookmarks() -> Result<Vec<BookmarkName>> {
    bookmark_list(&[], "if(conflict, name ++ \"\\n\", \"\")")
}

/// Local bookmarks whose `@origin` remote exists but is not tracked.
///
/// # Errors
/// Returns an error if the `jj` command fails.
pub fn untracked_origin_bookmarks() -> Result<Vec<BookmarkName>> {
    bookmark_list(
        &["--all-remotes"],
        "if(remote == \"origin\" && !tracked, name ++ \"\\n\", \"\")",
    )
}

/// Push the given bookmarks to origin (force-updates rewrites).
///
/// # Errors
/// Returns an error if the `jj git push` command fails.
pub fn git_push(bookmarks: &[BookmarkName]) -> Result<()> {
    let mut args: Vec<String> = vec![
        "--no-pager".into(),
        "--ignore-working-copy".into(),
        "git".into(),
        "push".into(),
    ];
    for bookmark in bookmarks {
        args.push("--bookmark".into());
        args.push(bookmark.as_str().to_string());
    }
    let arg_refs: Vec<&str> = args.iter().map(String::as_str).collect();
    run_streaming_checked("jj", &arg_refs)
}

/// Export jj bookmarks to the colocated git refs (works on a stale workspace).
///
/// # Errors
/// Returns an error if the `jj git export` command fails.
pub fn git_export() -> Result<()> {
    run_streaming_checked("jj", &["--no-pager", "--ignore-working-copy", "git", "export"])
}

/// The main (colocated) workspace root, which holds `.git`. Works from any workspace.
///
/// # Errors
/// Returns an error if `jj workspace root` fails, the `.jj/repo` pointer cannot be
/// read, or the resolved path has an unexpected shape.
pub fn colocated_repo_root() -> Result<PathBuf> {
    let workspace_root = PathBuf::from(run_output("jj", &["workspace", "root"])?);
    let repo_pointer = workspace_root.join(".jj").join("repo");
    if repo_pointer.is_dir() {
        return Ok(workspace_root);
    }
    let content = fs::read_to_string(&repo_pointer)?;
    let target = workspace_root.join(".jj").join(content.trim());
    let target = target.canonicalize().unwrap_or(target);
    target
        .parent()
        .and_then(Path::parent)
        .map(Path::to_path_buf)
        .ok_or_else(|| Error::Parse(format!("unexpected .jj/repo target: {}", target.display())))
}

/// Run `jj show` for a change with inherited stdio; returns the exit code.
///
/// # Errors
/// Returns an error if `jj show` cannot be started.
pub fn show(change_id: &ChangeId) -> Result<i32> {
    run_streaming(
        "jj",
        &["show", "--color", "always", "-r", change_id.as_str()],
    )
}
