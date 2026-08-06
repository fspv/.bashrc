//! Putting a generation's state onto a fresh checkout.

use std::path::Path;

use common::files::{self, CopyReport};
use common::{Error, Result};
use git::{GitDirectory, Head, Repo};
use jj::{BookmarkName, ChangeId, JjDirectory, Workspace};
use snapshot_store::Generation;

use crate::manifest::Manifest;

#[derive(Debug, Clone)]
pub struct Restored {
    pub manifest: Manifest,
    pub content: CopyReport,
    pub divergent_changes: Vec<ChangeId>,
    pub conflicted_bookmarks: Vec<BookmarkName>,
}

/// Restores `generation` over the checkout at `target`, which must be a clean
/// colocated jj checkout.
///
/// The working copy is materialised with git before jj runs, because a jj command
/// would otherwise snapshot the checked-out files and record the restored work as
/// deleted.
///
/// # Errors
/// Returns [`Error::State`] if the target is not a colocated jj checkout or its
/// working copy has changes, and a filesystem or command error if any step fails.
pub fn run(target: &Workspace, generation: &Generation) -> Result<Restored> {
    let manifest = Manifest::read(generation.path())?;
    let repo = Repo::in_worktree(target.root().as_path());

    let stored_git = GitDirectory::in_checkout(generation.path());
    let stored_jj = JjDirectory::in_checkout(generation.path());
    let checkout_git = GitDirectory::in_checkout(target.root().as_path());
    let checkout_jj = JjDirectory::in_checkout(target.root().as_path());

    require_present_in_checkout(checkout_jj.path())?;
    require_present_in_checkout(checkout_git.path())?;
    require_unmodified_working_copy(&repo, target)?;

    // The checkout's own object store is added to, never deleted, so whatever it
    // already has stays available. The generation's reflogs replace same-named
    // files outright. `.git/config` describes the machine rather than the work,
    // and is left alone.
    let mut content = git::add_absent_objects(&stored_git, &checkout_git)?;
    content += files::copy_tree_if_present(&stored_git.reflogs(), &checkout_git.reflogs(), None)?;
    content +=
        files::copy_tree_if_present(&stored_git.submodules(), &checkout_git.submodules(), None)?;
    content += files::copy_tree_if_present(
        &stored_git.local_excludes(),
        &checkout_git.local_excludes(),
        None,
    )?;

    // jj's state replaces the checkout's outright, because a leftover from the
    // fresh clone — a second op head above all — would change what jj sees.
    files::remove_directory_if_present(checkout_jj.path())?;
    content += files::copy_tree(stored_jj.path(), checkout_jj.path(), None)?;

    // Every ref lives in the generation's packed-refs, so a loose ref left by the
    // fresh clone would shadow it.
    files::remove_directory_if_present(&checkout_git.loose_refs())?;
    files::create_directory_and_parents(&checkout_git.loose_refs())?;
    content += files::copy_tree(&stored_git.packed_refs(), &checkout_git.packed_refs(), None)?;

    // Detaching HEAD first keeps the reset from moving a branch the checkout
    // happened to have checked out.
    repo.set_head(&Head::Detached(manifest.working_copy.commit.clone()))?;
    repo.reset_hard(&manifest.working_copy.commit)?;
    repo.set_head(&manifest.head)?;

    Ok(Restored {
        manifest,
        content,
        divergent_changes: target.divergent_changes()?,
        conflicted_bookmarks: target.conflicted_bookmarks()?,
    })
}

fn require_present_in_checkout(path: &Path) -> Result<()> {
    if path.is_dir() {
        return Ok(());
    }
    Err(Error::State(format!(
        "`{}` is missing: restore expects a colocated jj checkout",
        path.display()
    )))
}

fn require_unmodified_working_copy(repo: &Repo, target: &Workspace) -> Result<()> {
    if repo.is_worktree_clean()? {
        return Ok(());
    }
    Err(Error::State(format!(
        "`{}` has uncommitted changes, which restoring would discard",
        target.root()
    )))
}
