use std::fmt::Write as _;
use std::fs;
use std::hash::{DefaultHasher, Hash, Hasher};
use std::num::NonZeroU64;
use std::path::{Path, PathBuf};
use std::process::exit;
use std::time::{Duration, SystemTime};

use clap::{Parser, Subcommand};
use common::{Result, run_output};
use git::{AuthorName, BranchName, Provider, PullRequestNumber};
use jj::{ChangeId, bookmarks, colocated_repo_root, show};

const CACHE_TTL: Duration = Duration::from_secs(60);

#[derive(Parser)]
#[command(name = "jjui-tools", about = "Helper commands for jjui")]
struct Cli {
    #[command(subcommand)]
    tool: Tool,
}

#[derive(Subcommand)]
enum Tool {
    #[command(about = "Print a commit's PR status, then its jj show diff")]
    PrPreview {
        #[arg(help = "Change id of the commit to preview")]
        change_id: ChangeId,
    },
    #[command(about = "Print a pull request's head branch")]
    PrHead { number: PullRequestNumber },
}

struct UnresolvedThread {
    path: PathBuf,
    line: Option<NonZeroU64>,
    author: AuthorName,
    body: String,
}

fn main() {
    common::log_to_stderr(tracing::Level::DEBUG);
    let result = match Cli::parse().tool {
        Tool::PrPreview { change_id } => pr_preview(&change_id),
        Tool::PrHead { number } => with_provider(|provider, _| {
            let branch = match provider {
                Provider::GitHub => github::pr_head(number)?,
                Provider::Origin => origin::pr_head(number)?,
            };
            println!("{branch}");
            Ok(0)
        }),
    };
    match result {
        Ok(code) => exit(code),
        Err(err) => {
            eprintln!("jjui-tools: {err}");
            exit(1);
        }
    }
}

fn with_provider<T>(lookup: impl FnOnce(Provider, &str) -> Result<T>) -> Result<T> {
    let workspace = std::env::current_dir()?;
    std::env::set_current_dir(colocated_repo_root()?)?;
    let result = run_output("git", &["remote", "get-url", "origin"])
        .and_then(|remote| lookup(Provider::from_remote(&remote)?, &remote));
    std::env::set_current_dir(workspace)?;
    result
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

fn render_pr_header(provider: Provider, branch: &BranchName) -> Result<String> {
    let (status, threads): (_, Vec<UnresolvedThread>) = match provider {
        Provider::GitHub => {
            let Some(pr) = github::pr_for_branch(branch)? else {
                return Ok(String::new());
            };
            let threads = if matches!(pr.state, github::PrState::Open | github::PrState::Draft) {
                github::unresolved_threads(pr.number)?
                    .into_iter()
                    .map(|thread| UnresolvedThread {
                        path: thread.path,
                        line: thread.line,
                        author: thread.author,
                        body: thread.body,
                    })
                    .collect()
            } else {
                Vec::new()
            };
            (pr.to_string(), threads)
        }
        Provider::Origin => {
            let Some(pr) = origin::pr_for_branch(branch)? else {
                return Ok(String::new());
            };
            let threads = if matches!(pr.state, origin::PrState::Open | origin::PrState::Draft) {
                origin::unresolved_threads(pr.number)?
                    .into_iter()
                    .map(|thread| UnresolvedThread {
                        path: thread.path,
                        line: thread.line,
                        author: thread.author,
                        body: thread.body,
                    })
                    .collect()
            } else {
                Vec::new()
            };
            (pr.to_string(), threads)
        }
    };
    let mut header = format!("\x1b[1;36mPR {status}\x1b[0m");
    if !threads.is_empty() {
        let _ = write!(header, "\n\x1b[1;33m{} unresolved:\x1b[0m", threads.len());
        let author_prefix = match provider {
            Provider::GitHub => "@",
            Provider::Origin => "",
        };
        for thread in threads {
            let mut location = thread.path.display().to_string();
            if let Some(line) = thread.line {
                let _ = write!(location, ":{line}");
            }
            let snippet: String = thread
                .body
                .lines()
                .next()
                .unwrap_or_default()
                .chars()
                .take(80)
                .collect();
            let _ = write!(
                header,
                "\n  \x1b[33m{location}\x1b[0m \x1b[2m{author_prefix}{}:\x1b[0m {snippet}",
                thread.author
            );
        }
    }
    Ok(header)
}

fn cached_pr_header(branch: &BranchName) -> Result<String> {
    with_provider(|provider, remote| {
        let mut hasher = DefaultHasher::new();
        (remote, branch.as_str()).hash(&mut hasher);
        let path = cache_dir().join(format!("pr-{:016x}", hasher.finish()));
        if is_fresh(&path, CACHE_TTL)
            && let Ok(header) = fs::read_to_string(&path)
        {
            return Ok(header.trim().to_string());
        }
        let header = render_pr_header(provider, branch)?;
        let _ = fs::create_dir_all(cache_dir());
        let _ = fs::write(&path, &header);
        Ok(header)
    })
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
