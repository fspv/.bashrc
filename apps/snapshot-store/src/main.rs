use std::process::exit;

use clap::{Parser, Subcommand};
use common::Result;
use snapshot_store::{Generation, Store, StoreRoot};
use tracing::Level;

#[derive(Parser)]
#[command(
    name = "snapshot-store",
    about = "Inspect a store of snapshot generations"
)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Show the generations the store holds.
    Generations {
        #[arg(long)]
        store: StoreRoot,
    },
    /// Report the holder of a lock left behind by a run that died, and remove it.
    Unlock {
        #[arg(long)]
        store: StoreRoot,
    },
}

fn main() {
    common::log_to_stderr(Level::INFO);
    if let Err(error) = run(Cli::parse().command) {
        eprintln!("snapshot-store: {error}");
        exit(1);
    }
}

fn run(command: Command) -> Result<()> {
    match command {
        Command::Generations { store } => print_generations(&Store::open(store)?),
        Command::Unlock { store } => discard_lock(&Store::open(store)?),
    }
}

fn print_generations(store: &Store) -> Result<()> {
    let current = store.current_generation()?.as_ref().map(Generation::id);
    for generation in store.generations()? {
        let marker = if Some(generation.id()) == current {
            " <- current"
        } else {
            ""
        };
        println!("{}{marker}", generation.id());
    }
    for unfinished in store.unfinished_staging_directories()? {
        println!(
            "{} (unfinished run, left for inspection)",
            unfinished.display()
        );
    }
    Ok(())
}

fn discard_lock(store: &Store) -> Result<()> {
    match store.lock_holder()? {
        None => println!("{} is not locked", store.root()),
        Some(holder) => {
            println!("held by {holder}");
            store.discard_lock()?;
            println!("released the lock on {}", store.root());
        }
    }
    Ok(())
}
