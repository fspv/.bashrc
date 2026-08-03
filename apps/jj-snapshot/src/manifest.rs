//! What a generation records about itself.

use chrono::{DateTime, Utc};
use common::files;
use std::path::{Path, PathBuf};

use common::files::CopyReport;
use common::{Error, Hostname, Result, ToolVersion};
use git::{Head, ObjectId};
use jj::{Bookmark, OperationId, WorkingCopy, WorkspaceRoot};
use serde::{Deserialize, Serialize};
use snapshot_store::GenerationId;

use crate::verify::Verified;

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct CopiedContent {
    pub linked_files: usize,
    pub copied_files: usize,
    pub linked_bytes: u64,
    pub copied_bytes: u64,
}

impl From<CopyReport> for CopiedContent {
    fn from(report: CopyReport) -> Self {
        Self {
            linked_files: report.linked_files,
            copied_files: report.copied_files,
            linked_bytes: report.linked_bytes,
            copied_bytes: report.copied_bytes,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Manifest {
    pub generation: GenerationId,
    pub jj_snapshot_version: ToolVersion,
    pub jj_version: ToolVersion,
    pub git_version: ToolVersion,
    pub source: WorkspaceRoot,
    pub host: Hostname,
    pub started: DateTime<Utc>,
    pub finished: DateTime<Utc>,
    pub trunk: ObjectId,
    pub ref_count: usize,
    pub verified_object_count: usize,
    pub operation_heads: Vec<OperationId>,
    pub mutable_heads: Vec<ObjectId>,
    pub verified: Verified,
    pub head: Head,
    pub working_copy: WorkingCopy,
    pub content: CopiedContent,
    pub bookmarks: Vec<Bookmark>,
}

impl Manifest {
    /// # Errors
    /// Returns an error if the manifest cannot be serialised or written.
    pub fn write(&self, generation: &Path) -> Result<()> {
        let recorded = toml::to_string_pretty(self)
            .map_err(|error| Error::State(format!("cannot serialise the manifest: {error}")))?;
        files::write_file_creating_parents(&manifest_path(generation), recorded.as_bytes())
    }

    /// # Errors
    /// Returns an error if the manifest is missing or unreadable.
    pub fn read(generation: &Path) -> Result<Self> {
        let path = manifest_path(generation);
        toml::from_str(&files::read_file_text(&path)?)
            .map_err(|error| Error::Parse(format!("cannot read {}: {error}", path.display())))
    }
}

fn manifest_path(generation: &Path) -> PathBuf {
    generation.join("manifest.toml")
}
