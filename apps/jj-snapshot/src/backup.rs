//! Writing a new generation.

use std::path::Path;

use chrono::Utc;
use common::files::{self, CopyReport};
use common::{Error, Hostname, Result, ToolVersion};
use git::{GitDirectory, ObjectId, Repo};
use jj::{JjDirectory, Revset, Workspace};
use snapshot_store::{Generation, GenerationId, Retention, Store};

use crate::manifest::Manifest;
use crate::pointers::Pointers;
use crate::verify::{self, Expectation, Verified};

#[derive(Debug, Clone)]
pub struct Outcome {
    pub manifest: Manifest,
    pub reused: Option<GenerationId>,
    pub pruned: Vec<GenerationId>,
}

#[derive(Debug, Clone, Copy)]
pub struct Request<'a> {
    pub workspace: &'a Workspace,
    pub store: &'a Store,
    pub retention: &'a Retention,
}

/// Copies the repository's state into a new generation and publishes it once it
/// verifies.
///
/// jj records the working copy in `@` first, so that edits made since the last jj
/// command are part of the generation rather than left behind. Every jj read after
/// that is pinned to the operation head read with the pointers, so the manifest
/// describes one moment even if jj runs concurrently.
///
/// # Errors
/// Returns an error if the store is locked, the repository cannot be inspected,
/// the copy fails, or the finished generation does not verify.
pub fn run(request: &Request) -> Result<Outcome> {
    let Request {
        workspace,
        store,
        retention,
    } = *request;
    let _lock = store.lock()?;
    let started = Utc::now();
    workspace.snapshot_working_copy()?;

    let repo = Repo::in_worktree(workspace.root().as_path());
    let pointers = Pointers::read(workspace, &repo)?;
    let [operation] = pointers.operation_heads.as_slice() else {
        return Err(Error::State(format!(
            "the operation log has {} heads: the repository is being changed concurrently; retry once it settles",
            pointers.operation_heads.len()
        )));
    };
    let workspace = &workspace.pinned_at(operation.clone());
    let trunk = workspace.trunk()?;
    let mutable_heads = workspace.mutable_heads()?;
    let working_copy = workspace.working_copy()?;
    let bookmarks = workspace.bookmarks(&Revset::new("bookmarks() ~ ::trunk()"))?;

    let previous = store.current_generation()?;
    let staging = store.stage(GenerationId::at(started))?;
    let copied = copy_repository_state(
        workspace.root().as_path(),
        staging.path(),
        previous.as_ref(),
    )?;
    pointers.write(staging.path())?;

    let checked = verify::generation(
        staging.path(),
        &Expectation {
            operation_heads: pointers.operation_heads.clone(),
            mutable_heads: mutable_heads.clone(),
            known_present: [vec![trunk.clone()], copied.proven.heads].concat(),
            scope: copied.proven.scope,
        },
    )?;

    let manifest = Manifest {
        generation: staging.id(),
        jj_snapshot_version: ToolVersion::new(env!("CARGO_PKG_VERSION")),
        jj_version: jj::version()?,
        git_version: git::version()?,
        source: workspace.root().clone(),
        host: Hostname::of_this_machine()?,
        started,
        finished: Utc::now(),
        trunk,
        ref_count: pointers.refs.len(),
        verified_object_count: checked.object_count,
        operation_heads: pointers.operation_heads,
        mutable_heads,
        verified: checked.scope,
        head: pointers.head,
        working_copy,
        content: copied.report.into(),
        bookmarks,
    };
    manifest.write(staging.path())?;
    staging.publish()?;

    Ok(Outcome {
        manifest,
        reused: previous.as_ref().map(Generation::id),
        pruned: store.prune(retention, Utc::now())?,
    })
}

struct CopiedState {
    report: CopyReport,
    proven: AlreadyProven,
}

/// What a previous generation lets this one take as read, because every object
/// file it holds is still in the repository unchanged, and so landed in this
/// generation's copy too.
struct AlreadyProven {
    heads: Vec<ObjectId>,
    scope: Verified,
}

impl AlreadyProven {
    const fn nothing() -> Self {
        Self {
            heads: Vec::new(),
            scope: Verified::Fully,
        }
    }

    /// A generation whose manifest cannot be read — written by an older tool, say
    /// — proves nothing, and this generation verifies in full rather than
    /// refusing to run.
    fn by(generation: &Generation) -> Self {
        match Manifest::read(generation.path()) {
            Ok(manifest) => Self {
                heads: manifest.mutable_heads,
                scope: Verified::Since(generation.id()),
            },
            Err(error) => {
                tracing::warn!(
                    "verifying in full: cannot read the manifest of {}: {error}",
                    generation.id()
                );
                Self::nothing()
            }
        }
    }
}

/// jj's state directory is taken as it stands, so a jj release that adds a file to
/// it needs no change here. Of git, only the object store and the state a person
/// accumulates is worth keeping: `.git/index` is rebuilt by a restore, and
/// `.git/lfs` holds blobs that live on the remote — jj does not run git's LFS
/// filters, so its commits contain the real file contents anyway.
fn copy_repository_state(
    checkout: &Path,
    generation: &Path,
    previous: Option<&Generation>,
) -> Result<CopiedState> {
    let source_git = GitDirectory::in_checkout(checkout);
    let source_jj = JjDirectory::in_checkout(checkout);
    let staged_git = GitDirectory::in_checkout(generation);
    let staged_jj = JjDirectory::in_checkout(generation);

    let previous_git = previous.map(|it| GitDirectory::in_checkout(it.path()));
    let previous_jj = previous.map(|it| JjDirectory::in_checkout(it.path()));
    let previous_objects = previous_git.as_ref().map(GitDirectory::objects);
    let previous_reflogs = previous_git.as_ref().map(GitDirectory::reflogs);
    let previous_submodules = previous_git.as_ref().map(GitDirectory::submodules);
    let previous_excludes = previous_git.as_ref().map(GitDirectory::local_excludes);
    let previous_config = previous_git.as_ref().map(GitDirectory::config);

    let mut report = CopyReport::default();
    report += files::copy_tree(
        source_jj.path(),
        staged_jj.path(),
        previous_jj.as_ref().map(JjDirectory::path),
    )?;
    report += files::copy_tree(
        &source_git.objects(),
        &staged_git.objects(),
        previous_objects.as_deref(),
    )?;
    report += files::copy_tree_if_present(
        &source_git.reflogs(),
        &staged_git.reflogs(),
        previous_reflogs.as_deref(),
    )?;
    report += files::copy_tree_if_present(
        &source_git.submodules(),
        &staged_git.submodules(),
        previous_submodules.as_deref(),
    )?;
    report += files::copy_tree_if_present(
        &source_git.local_excludes(),
        &staged_git.local_excludes(),
        previous_excludes.as_deref(),
    )?;
    report += files::copy_tree_if_present(
        &source_git.config(),
        &staged_git.config(),
        previous_config.as_deref(),
    )?;

    let proven = match (previous, previous_git.as_ref()) {
        (Some(generation), Some(reused))
            if files::all_files_are_still_present_in(&reused.objects(), &source_git.objects())? =>
        {
            AlreadyProven::by(generation)
        }
        _ => AlreadyProven::nothing(),
    };
    Ok(CopiedState { report, proven })
}
