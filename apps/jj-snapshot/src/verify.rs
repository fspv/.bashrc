//! Checking that a generation contains everything it names.
//!
//! Only what is new is walked. Everything below `trunk()` arrived with the clone,
//! and everything a previous generation already proved is shared with this one by
//! hardlink — the same inodes, not copies — so re-reading it would cost a minute
//! of network round trips to learn nothing.

use std::path::Path;

use common::{Error, Result};
use git::{GitDirectory, ObjectId, Repo};
use jj::{JjDirectory, OperationId};
use serde::{Deserialize, Serialize};
use snapshot_store::GenerationId;

use crate::manifest::Manifest;

/// How far back a generation's own check reached.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Verified {
    /// Every object ahead of `trunk()` was walked.
    Fully,
    /// Objects newer than what this generation already proved were walked; the
    /// rest is the same content, shared by hardlink.
    Since(GenerationId),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Checked {
    pub object_count: usize,
    pub scope: Verified,
}

/// The pointers a generation claims to hold content for.
#[derive(Debug, Clone)]
pub struct Expectation {
    pub operation_heads: Vec<OperationId>,
    pub mutable_heads: Vec<ObjectId>,
    /// Commits whose objects need no walking: `trunk()`, plus the heads of a
    /// generation this one shares its object store with.
    pub known_present: Vec<ObjectId>,
    pub scope: Verified,
}

impl Expectation {
    /// Everything ahead of `trunk()`, as the standalone `verify` command checks it.
    #[must_use]
    pub fn covering_everything_ahead_of_trunk(manifest: &Manifest) -> Self {
        Self {
            operation_heads: manifest.operation_heads.clone(),
            mutable_heads: manifest.mutable_heads.clone(),
            known_present: vec![manifest.trunk.clone()],
            scope: Verified::Fully,
        }
    }
}

/// # Errors
/// Returns [`Error::State`] if an operation is absent, or a git error if any
/// object that should be reachable is missing.
pub fn generation(generation: &Path, expected: &Expectation) -> Result<Checked> {
    let jj_state = JjDirectory::in_checkout(generation);
    for operation in &expected.operation_heads {
        if !jj_state.operation(operation).exists() {
            return Err(Error::State(format!(
                "{} names operation {operation} but does not contain it",
                generation.display()
            )));
        }
    }
    let object_count = Repo::in_git_directory(GitDirectory::in_checkout(generation).path())
        .count_objects_reachable_from(&expected.mutable_heads, &expected.known_present)?;
    Ok(Checked {
        object_count,
        scope: expected.scope.clone(),
    })
}
