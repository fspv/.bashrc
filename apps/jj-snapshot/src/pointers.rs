//! The mutable state that names a repository's content, and why reading it first
//! is what makes a generation consistent.
//!
//! Both git and jj keep immutable content named by a few mutable pointers, and
//! both write content before the pointer that names it. So everything the
//! pointers reach at the moment they are read already exists, and a copy that
//! starts afterwards is bound to include it — extra content copied along the way
//! is harmless. That is the whole ordering rule: read the pointers, copy the
//! content, then write the pointers that were read.

use std::fmt::Write as _;
use std::path::Path;

use common::files;
use common::{Error, Result};
use git::{GitDirectory, Head, Ref, Repo};
use jj::{JjDirectory, OperationId, Workspace};

#[derive(Debug, Clone)]
pub struct Pointers {
    pub refs: Vec<Ref>,
    pub head: Head,
    pub operation_heads: Vec<OperationId>,
    pub working_copy_checkout: Vec<u8>,
}

impl Pointers {
    /// # Errors
    /// Returns an error if git or jj cannot report their pointers.
    pub fn read(workspace: &Workspace, repo: &Repo) -> Result<Self> {
        let jj_state = JjDirectory::in_checkout(workspace.root().as_path());
        Ok(Self {
            refs: repo.refs()?,
            head: repo.head()?,
            operation_heads: workspace.op_heads()?,
            working_copy_checkout: files::read_file_bytes(&jj_state.working_copy_checkout())?,
        })
    }

    /// Overwrites whatever the content copy left behind, so a generation names
    /// exactly the operations and refs that were read at the start.
    ///
    /// Every ref goes into a single `packed-refs`, which is both what git reads
    /// and the only ref state a restore has to replace.
    ///
    /// # Errors
    /// Returns [`Error::File`] if a pointer cannot be written.
    pub fn write(&self, generation: &Path) -> Result<()> {
        let git = GitDirectory::in_checkout(generation);
        let jj_state = JjDirectory::in_checkout(generation);

        files::remove_directory_if_present(&git.loose_refs())?;
        files::create_directory_and_parents(&git.loose_refs())?;
        files::write_file_creating_parents(&git.packed_refs(), self.packed_refs()?.as_bytes())?;
        files::write_file_creating_parents(&git.head(), self.head.file_contents().as_bytes())?;

        files::remove_directory_if_present(&jj_state.operation_heads())?;
        files::create_directory_and_parents(&jj_state.operation_heads())?;
        for operation in &self.operation_heads {
            let recorded = jj_state.operation_heads().join(operation.to_string());
            files::write_file_creating_parents(&recorded, &[])?;
        }
        files::write_file_creating_parents(
            &jj_state.working_copy_checkout(),
            &self.working_copy_checkout,
        )
    }

    fn packed_refs(&self) -> Result<String> {
        let mut listing = String::new();
        for reference in &self.refs {
            writeln!(listing, "{} {}", reference.target, reference.name)
                .map_err(|error| Error::State(format!("cannot format refs: {error}")))?;
        }
        Ok(listing)
    }
}
