use std::fs;
use std::path::{Path, PathBuf};
use std::process::exit;
use std::time::{Duration, SystemTime};

use clap::{Parser, Subcommand};
use common::Result;
use github::{pr_for_branch, BranchName};
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

/// The rendered PR status line for a branch, cached briefly. Empty means "no PR"
/// (also cached, so PR-less commits don't re-hit GitHub on every navigation).
/// The cache itself is best-effort; only the GitHub lookup propagates errors.
fn cached_pr_line(branch: &BranchName) -> Result<String> {
    let path = cache_dir().join(format!("pr-{}", branch.as_str().replace('/', "_")));
    if !is_fresh(&path, CACHE_TTL) {
        let line = pr_for_branch(branch)?
            .map(|pr| pr.to_string())
            .unwrap_or_default();
        let _ = fs::create_dir_all(cache_dir());
        let _ = fs::write(&path, line);
    }
    Ok(fs::read_to_string(&path).unwrap_or_default().trim().to_string())
}

fn pr_preview(change_id: &ChangeId) -> Result<i32> {
    if let Some(bookmark) = bookmarks(change_id)?.into_iter().next() {
        match cached_pr_line(&BranchName::new(bookmark.as_str())) {
            Ok(line) if !line.is_empty() => println!("\x1b[1;36mPR {line}\x1b[0m"),
            Ok(_) => println!("\x1b[2mno PR for {bookmark}\x1b[0m"),
            // The diff is the point of the preview, so degrade gracefully if the
            // PR lookup fails rather than aborting.
            Err(err) => println!("\x1b[2mPR lookup failed: {err}\x1b[0m"),
        }
        println!("\x1b[2m{}\x1b[0m", "─".repeat(60));
    }
    show(change_id)
}
