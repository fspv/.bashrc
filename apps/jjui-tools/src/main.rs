use std::fmt::Write as _;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::exit;
use std::time::{Duration, SystemTime};

use clap::{Parser, Subcommand};
use common::Result;
use github::{pr_for_branch, unresolved_threads, BranchName, PrState};
use jj::{bookmarks, show, ChangeId};

#[expect(
    clippy::duration_suboptimal_units,
    reason = "Duration::from_mins is unstable on stable Rust"
)]
const CACHE_TTL: Duration = Duration::from_secs(60);

#[derive(Parser)]
#[command(name = "jjui-tools", about = "Helper commands for jjui")]
struct Cli {
    #[command(subcommand)]
    tool: Tool,
}

#[derive(Subcommand)]
enum Tool {
    /// Print a commit's GitHub PR status, then its `jj show` diff.
    PrPreview {
        /// Change id of the commit to preview.
        change_id: ChangeId,
    },
}

fn main() {
    let result = match Cli::parse().tool {
        Tool::PrPreview { change_id } => pr_preview(&change_id),
    };
    match result {
        Ok(code) => exit(code),
        Err(err) => {
            eprintln!("jjui-tools: {err}");
            exit(1);
        }
    }
}

fn cache_dir() -> PathBuf {
    std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join(".cache")))
        .unwrap_or_else(std::env::temp_dir)
        .join("jjui-tools")
}

fn is_fresh(path: &Path, ttl: Duration) -> bool {
    let Ok(modified) = fs::metadata(path).and_then(|m| m.modified()) else {
        return false;
    };
    SystemTime::now()
        .duration_since(modified)
        .is_ok_and(|age| age < ttl)
}

/// The rendered PR header (status line plus unresolved review comments) for a
/// branch. Only open/draft PRs pay for the extra unresolved-threads lookup.
fn render_pr_header(branch: &BranchName) -> Result<String> {
    let Some(pr) = pr_for_branch(branch)? else {
        return Ok(String::new());
    };
    let mut header = format!("\x1b[1;36mPR {pr}\x1b[0m");
    if matches!(pr.state, PrState::Open | PrState::Draft) {
        let threads = unresolved_threads(pr.number)?;
        if !threads.is_empty() {
            let _ = write!(header, "\n\x1b[1;33m{} unresolved:\x1b[0m", threads.len());
            for thread in threads {
                let location = thread
                    .line
                    .map_or_else(|| thread.path.clone(), |line| format!("{}:{line}", thread.path));
                let snippet: String =
                    thread.body.lines().next().unwrap_or_default().chars().take(80).collect();
                let _ = write!(
                    header,
                    "\n  \x1b[33m{location}\x1b[0m \x1b[2m@{}:\x1b[0m {snippet}",
                    thread.author
                );
            }
        }
    }
    Ok(header)
}

/// The rendered PR header for a branch, cached briefly. Empty means "no PR"
/// (also cached, so PR-less commits don't re-hit GitHub on every navigation).
/// The cache itself is best-effort; only the GitHub lookup propagates errors.
fn cached_pr_header(branch: &BranchName) -> Result<String> {
    let path = cache_dir().join(format!("pr-{}", branch.as_str().replace('/', "_")));
    if !is_fresh(&path, CACHE_TTL) {
        let header = render_pr_header(branch)?;
        let _ = fs::create_dir_all(cache_dir());
        let _ = fs::write(&path, header);
    }
    Ok(fs::read_to_string(&path).unwrap_or_default().trim().to_string())
}

fn pr_preview(change_id: &ChangeId) -> Result<i32> {
    if let Some(bookmark) = bookmarks(change_id)?.into_iter().next() {
        match cached_pr_header(&BranchName::new(bookmark.as_str())) {
            Ok(header) if !header.is_empty() => println!("{header}"),
            Ok(_) => println!("\x1b[2mno PR for {bookmark}\x1b[0m"),
            // The diff is the point of the preview, so degrade gracefully if the
            // PR lookup fails rather than aborting.
            Err(err) => println!("\x1b[2mPR lookup failed: {err}\x1b[0m"),
        }
        println!("\x1b[2m{}\x1b[0m", "─".repeat(60));
    }
    show(change_id)
}
