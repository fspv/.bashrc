mod github;
mod origin;
mod pr_sync;

use std::collections::HashSet;
use std::process::exit;

use clap::{Parser, Subcommand};
use common::Result;
use git::Provider;
use jj::{BookmarkName, git_fetch, git_track, local_bookmarks, untracked_origin_bookmarks};
use pr_sync::PrSyncArgs;

#[derive(Parser)]
#[command(name = "jj-tools", about = "Tools for managing jj stacks")]
struct Cli {
    #[command(subcommand)]
    tool: Tool,
}

#[derive(Subcommand)]
enum Tool {
    #[command(about = "Sync a jj bookmark DAG as base-pointer PRs (trees supported).")]
    PrSync(PrSyncArgs),
    /// Fetch the origin branches matching your local bookmarks and track them.
    FetchAndTrack,
}

fn main() {
    common::log_to_stderr(tracing::Level::DEBUG);
    let result = match Cli::parse().tool {
        Tool::PrSync(args) => pr_sync(args),
        Tool::FetchAndTrack => fetch_and_track(),
    };
    match result {
        Ok(code) => exit(code),
        Err(err) => {
            eprintln!("jj-tools: {err}");
            exit(1);
        }
    }
}

fn pr_sync(args: PrSyncArgs) -> Result<i32> {
    let remote = git::Repo::in_worktree(&jj::colocated_repo_root()?).remote_url("origin")?;
    match Provider::from_remote(&remote)? {
        Provider::GitHub => pr_sync::run(args, &github::GitHub),
        Provider::Origin => pr_sync::run(args, &origin::Origin),
    }
}

fn fetch_and_track() -> Result<i32> {
    let bookmarks = local_bookmarks()?;
    if bookmarks.is_empty() {
        println!("No local bookmarks to fetch.");
        return Ok(0);
    }
    git_fetch(&bookmarks)?;
    let local: HashSet<&str> = bookmarks.iter().map(BookmarkName::as_str).collect();
    let to_track: Vec<BookmarkName> = untracked_origin_bookmarks()?
        .into_iter()
        .filter(|bookmark| local.contains(bookmark.as_str()))
        .collect();
    git_track(&to_track)?;
    Ok(0)
}
