use std::process::exit;

use clap::{Args, Parser, Subcommand};
use common::{Error, Result, format_bytes_in_binary_units};
use jj::{Workspace, WorkspaceRoot};
use jj_snapshot::manifest::Manifest;
use jj_snapshot::verify::{self, Expectation, Verified};
use jj_snapshot::{backup, restore};
use snapshot_store::{Generation, GenerationId, Retention, Store, StoreRoot};
use tracing::Level;

#[derive(Parser)]
#[command(
    name = "jj-snapshot",
    about = "Generation-rotated backups of a jj repository's state"
)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Copy the repository's current state into a new generation.
    Backup(RepositoryArgs),
    /// Put a generation's state onto a fresh checkout.
    Restore(RestoreArgs),
    /// Show what the generations in a store hold.
    List(StoreArgs),
    /// Walk everything a generation names, rather than only what was new.
    Verify(GenerationArgs),
}

#[derive(Args)]
struct StoreArgs {
    /// Directory holding the generations, on durable storage.
    #[arg(long)]
    store: StoreRoot,
}

#[derive(Args)]
struct RepositoryArgs {
    #[command(flatten)]
    store: StoreArgs,
    /// The jj workspace to back up.
    #[arg(long)]
    repo: WorkspaceRoot,
}

#[derive(Args)]
struct GenerationArgs {
    #[command(flatten)]
    store: StoreArgs,
    /// Which generation to use, as an RFC 3339 timestamp. Defaults to the current one.
    #[arg(long)]
    generation: Option<GenerationId>,
}

#[derive(Args)]
struct RestoreArgs {
    #[command(flatten)]
    generation: GenerationArgs,
    /// The checkout to restore onto.
    #[arg(long)]
    repo: WorkspaceRoot,
}

fn main() {
    common::log_to_stderr(Level::INFO);
    if let Err(error) = run(Cli::parse().command) {
        eprintln!("jj-snapshot: {error}");
        exit(1);
    }
}

fn run(command: Command) -> Result<()> {
    match command {
        Command::Backup(args) => back_up_repository(args),
        Command::Restore(args) => restore_generation(args),
        Command::List(args) => print_generation_summaries(&Store::open(args.store)?),
        Command::Verify(args) => verify_generation(args),
    }
}

fn back_up_repository(args: RepositoryArgs) -> Result<()> {
    let store = Store::open(args.store.store)?;
    let outcome = backup::run(&backup::Request {
        workspace: &Workspace::at(args.repo),
        store: &store,
        retention: &Retention::default(),
    })?;
    let manifest = &outcome.manifest;
    println!(
        "{}: {} refs, @ {}, {}",
        manifest.generation,
        manifest.ref_count,
        manifest.working_copy.change,
        describe_verification_scope(&manifest.verified, manifest.verified_object_count),
    );
    println!(
        "  copied {} in {} files, linked {} in {} files",
        format_bytes_in_binary_units(manifest.content.copied_bytes),
        manifest.content.copied_files,
        format_bytes_in_binary_units(manifest.content.linked_bytes),
        manifest.content.linked_files,
    );
    if !outcome.pruned.is_empty() {
        println!("  pruned {} expired generations", outcome.pruned.len());
    }
    Ok(())
}

fn restore_generation(args: RestoreArgs) -> Result<()> {
    let store = Store::open(args.generation.store.store)?;
    let generation = requested_or_current_generation(&store, args.generation.generation)?;
    let restored = restore::run(&Workspace::at(args.repo), &generation)?;
    let manifest = &restored.manifest;
    println!(
        "restored {} taken on {} at {}",
        manifest.generation, manifest.host, manifest.started,
    );
    println!(
        "  @ {} at commit {}, HEAD {}, {} bookmarks",
        manifest.working_copy.change,
        manifest.working_copy.commit,
        manifest.head,
        manifest.bookmarks.len(),
    );
    println!(
        "  {} divergent changes, {} conflicted bookmarks",
        restored.divergent_changes.len(),
        restored.conflicted_bookmarks.len(),
    );
    println!("Run `jj git fetch` to bring the immutable history up to date.");
    Ok(())
}

fn verify_generation(args: GenerationArgs) -> Result<()> {
    let store = Store::open(args.store.store)?;
    let generation = requested_or_current_generation(&store, args.generation)?;
    let manifest = Manifest::read(generation.path())?;
    let checked = verify::generation(
        generation.path(),
        &Expectation::covering_everything_ahead_of_trunk(&manifest),
    )?;
    println!(
        "{}: {} operations, {} objects ahead of trunk",
        manifest.generation,
        manifest.operation_heads.len(),
        checked.object_count,
    );
    Ok(())
}

fn print_generation_summaries(store: &Store) -> Result<()> {
    let current = store.current_generation()?.as_ref().map(Generation::id);
    for generation in store.generations()? {
        let manifest = Manifest::read(generation.path())?;
        let marker = if Some(generation.id()) == current {
            " <- current"
        } else {
            ""
        };
        println!(
            "{}  @ {}  {} bookmarks  {} copied{marker}",
            generation.id(),
            manifest.working_copy.change,
            manifest.bookmarks.len(),
            format_bytes_in_binary_units(manifest.content.copied_bytes),
        );
    }
    for unfinished in store.unfinished_staging_directories()? {
        println!(
            "{} (unfinished run, left for inspection)",
            unfinished.display()
        );
    }
    Ok(())
}

fn requested_or_current_generation(
    store: &Store,
    requested: Option<GenerationId>,
) -> Result<Generation> {
    match requested {
        Some(id) => store.find_generation(id),
        None => store
            .current_generation()?
            .ok_or_else(|| Error::State(format!("{} holds no generations", store.root()))),
    }
}

fn describe_verification_scope(verified: &Verified, object_count: usize) -> String {
    match verified {
        Verified::Fully => format!("verified {object_count} objects ahead of trunk"),
        Verified::Since(generation) => {
            format!("verified {object_count} objects new since {generation}")
        }
    }
}
