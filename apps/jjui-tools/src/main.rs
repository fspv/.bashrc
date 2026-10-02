use std::collections::HashSet;
use std::fmt::Write as _;
use std::fs::{self, File, TryLockError};
use std::hash::{DefaultHasher, Hash, Hasher};
use std::io::{ErrorKind, Read as _};
use std::num::NonZeroU64;
use std::path::{Path, PathBuf};
use std::process::exit;
use std::sync::{Mutex, PoisonError};
use std::time::{Duration, SystemTime};

use clap::{Parser, Subcommand};
use common::{Result, run_output_sync};
use git::{AuthorName, BranchName, Provider, PullRequestNumber};
use jj::{ChangeId, Revset, StackGraph, bookmarks, colocated_repo_root, current_stack_tips, show};

const CACHE_TTL: Duration = Duration::from_secs(5);

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
    #[command(name = "pr-prefetch", hide = true)]
    Prefetch { change_id: ChangeId },
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
        Tool::Prefetch { change_id } => prefetch_pr_headers(&change_id).map(|()| 0),
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
    let result = run_output_sync("git", &["remote", "get-url", "origin"])
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

enum PullRequest {
    GitHub(github::PullRequest),
    Origin(origin::PullRequest),
}

enum PendingRequest {
    GitHub(Option<github::PullRequest>),
    Origin,
}

fn render_pr_header(request: Option<PullRequest>) -> Result<String> {
    let Some(request) = request else {
        return Ok(String::new());
    };
    let (status, author_prefix, threads): (_, _, Vec<UnresolvedThread>) = match request {
        PullRequest::GitHub(pr) => {
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
            (pr.to_string(), "@", threads)
        }
        PullRequest::Origin(pr) => {
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
            (pr.to_string(), "", threads)
        }
    };
    let mut header = format!("\x1b[1;36mPR {status}\x1b[0m");
    if !threads.is_empty() {
        let _ = write!(header, "\n\x1b[1;33m{} unresolved:\x1b[0m", threads.len());
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

fn cache_path(remote: &str, branch: &BranchName) -> PathBuf {
    let mut hasher = DefaultHasher::new();
    (remote, branch.as_str()).hash(&mut hasher);
    cache_dir().join(format!("pr-{:016x}", hasher.finish()))
}

struct CachedHeader {
    content: String,
    age: Duration,
}

fn cached_pr_header(branch: &BranchName) -> Result<Option<CachedHeader>> {
    with_provider(|_, remote| {
        let mut file = match File::open(cache_path(remote, branch)) {
            Ok(file) => file,
            Err(error) if error.kind() == ErrorKind::NotFound => return Ok(None),
            Err(error) => return Err(error.into()),
        };
        let age = SystemTime::now()
            .duration_since(file.metadata()?.modified()?)
            .unwrap_or_default();
        let mut content = String::new();
        file.read_to_string(&mut content)?;
        Ok(Some(CachedHeader { content, age }))
    })
}

struct RefreshEntry {
    branch: BranchName,
    path: PathBuf,
    _lock: File,
}

impl RefreshEntry {
    fn acquire(remote: &str, branch: BranchName) -> Result<Option<Self>> {
        let path = cache_path(remote, &branch);
        if is_fresh(&path, CACHE_TTL) {
            return Ok(None);
        }
        let lock = File::options()
            .create(true)
            .truncate(false)
            .write(true)
            .open(path.with_extension("lock"))?;
        match lock.try_lock() {
            Ok(()) => {}
            Err(TryLockError::WouldBlock) => return Ok(None),
            Err(TryLockError::Error(error)) => return Err(error.into()),
        }
        if is_fresh(&path, CACHE_TTL) {
            return Ok(None);
        }
        Ok(Some(Self {
            branch,
            path,
            _lock: lock,
        }))
    }

    fn publish(&self, header: &str) -> Result<()> {
        let temporary = self
            .path
            .with_extension(format!("{}.tmp", std::process::id()));
        fs::write(&temporary, header)?;
        fs::rename(temporary, &self.path)?;
        Ok(())
    }
}

fn prefetch_pr_headers(change_id: &ChangeId) -> Result<()> {
    let mut branches: Vec<BranchName> = bookmarks(change_id)?
        .into_iter()
        .map(|bookmark| BranchName::new(bookmark.as_str()))
        .collect();
    let trunk = Revset::new("trunk()");
    match StackGraph::load(&trunk, &current_stack_tips(&trunk, change_id.as_str())) {
        Ok(stack) => branches.extend(
            stack
                .bookmarks()
                .into_iter()
                .map(|bookmark| BranchName::new(bookmark.name.as_str())),
        ),
        Err(error) => eprintln!("jjui-tools: stack prefetch unavailable: {error}"),
    }
    let mut seen = HashSet::new();
    branches.retain(|branch| seen.insert(branch.as_str().to_string()));
    if branches.is_empty() {
        return Ok(());
    }
    with_provider(|provider, remote| {
        fs::create_dir_all(cache_dir())?;
        let entries: Vec<RefreshEntry> = branches
            .into_iter()
            .filter_map(|branch| RefreshEntry::acquire(remote, branch).transpose())
            .collect::<Result<_>>()?;
        if entries.is_empty() {
            return Ok(());
        }
        let branches: Vec<BranchName> = entries.iter().map(|entry| entry.branch.clone()).collect();
        let requests: Vec<PendingRequest> = match provider {
            Provider::GitHub => github::prs_for_branches(&branches)?
                .into_iter()
                .map(PendingRequest::GitHub)
                .collect(),
            Provider::Origin => branches.iter().map(|_| PendingRequest::Origin).collect(),
        };
        let mut results: Vec<Result<()>> = entries.iter().map(|_| Ok(())).collect();
        let pending = Mutex::new(entries.into_iter().zip(requests).zip(&mut results));
        std::thread::scope(|scope| {
            for _ in 0..branches.len().min(4) {
                scope.spawn(|| {
                    loop {
                        let next = pending
                            .lock()
                            .unwrap_or_else(PoisonError::into_inner)
                            .next();
                        let Some(((entry, request), result)) = next else {
                            break;
                        };
                        let request = match request {
                            PendingRequest::GitHub(request) => Ok(request.map(PullRequest::GitHub)),
                            PendingRequest::Origin => origin::pr_for_branch(&entry.branch)
                                .map(|request| request.map(PullRequest::Origin)),
                        };
                        *result = request
                            .and_then(render_pr_header)
                            .and_then(|header| entry.publish(&header));
                    }
                });
            }
        });
        results.into_iter().collect()
    })
}

fn pr_preview(change_id: &ChangeId) -> Result<i32> {
    if let Some(bookmark) = bookmarks(change_id)?.into_iter().next() {
        match cached_pr_header(&BranchName::new(bookmark.as_str())) {
            Ok(Some(header)) => {
                if header.content.trim().is_empty() {
                    println!("\x1b[2mno PR for {bookmark}\x1b[0m");
                } else {
                    println!("{}", header.content.trim());
                }
                if header.age > Duration::from_secs(20) {
                    println!("\x1b[2m({} seconds stale)\x1b[0m", header.age.as_secs());
                }
            }
            Ok(None) => println!("\x1b[2mPR information loading for {bookmark}…\x1b[0m"),
            Err(err) => println!("\x1b[2mPR lookup failed: {err}\x1b[0m"),
        }
        println!("\x1b[2m{}\x1b[0m", "─".repeat(60));
    }
    show(change_id)
}
