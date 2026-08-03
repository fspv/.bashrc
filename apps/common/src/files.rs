//! Filesystem operations that report which path failed, and say in their name how
//! they differ from their `std::fs` counterparts.

use std::collections::HashMap;
use std::ffi::OsString;
use std::fs::{self, Metadata};
use std::os::unix::fs::MetadataExt as _;
use std::path::{Path, PathBuf};

use rustix::fs::{AtFlags, CWD, Timespec, Timestamps, utimensat};

use crate::{Error, Result};

/// Attaches the operation and path to an [`std::io::Error`], which on its own
/// says only what went wrong and never where.
trait PathContext<T> {
    fn add_path(self, operation: &'static str, path: &Path) -> Result<T>;
}

impl<T> PathContext<T> for std::io::Result<T> {
    fn add_path(self, operation: &'static str, path: &Path) -> Result<T> {
        self.map_err(|source| Error::File {
            operation,
            path: path.to_path_buf(),
            source,
        })
    }
}

/// # Errors
/// Returns [`Error::File`] if the path cannot be read.
pub fn read_metadata_without_following_symlinks(path: &Path) -> Result<Metadata> {
    fs::symlink_metadata(path).add_path("stat", path)
}

/// The names directly inside `path`, in the order the filesystem reports them.
///
/// # Errors
/// Returns [`Error::File`] if the directory cannot be read.
pub fn list_directory(path: &Path) -> Result<Vec<OsString>> {
    let mut names = Vec::new();
    for entry in fs::read_dir(path).add_path("list", path)? {
        names.push(entry.add_path("list", path)?.file_name());
    }
    Ok(names)
}

/// # Errors
/// Returns [`Error::File`] if the file cannot be read.
pub fn read_file_bytes(path: &Path) -> Result<Vec<u8>> {
    fs::read(path).add_path("read", path)
}

/// # Errors
/// Returns [`Error::File`] if the file cannot be read or is not utf-8.
pub fn read_file_text(path: &Path) -> Result<String> {
    fs::read_to_string(path).add_path("read", path)
}

/// # Errors
/// Returns [`Error::File`] if the file or its parent directories cannot be written.
pub fn write_file_creating_parents(path: &Path, contents: &[u8]) -> Result<()> {
    if let Some(parent) = path.parent() {
        create_directory_and_parents(parent)?;
    }
    fs::write(path, contents).add_path("write", path)
}

/// Succeeds if the directory is already there.
///
/// # Errors
/// Returns [`Error::File`] if the directory cannot be created.
pub fn create_directory_and_parents(path: &Path) -> Result<()> {
    fs::create_dir_all(path).add_path("create", path)
}

/// # Errors
/// Returns [`Error::File`] if the directory exists but cannot be removed.
pub fn remove_directory_if_present(path: &Path) -> Result<()> {
    if path.is_dir() {
        return fs::remove_dir_all(path).add_path("remove", path);
    }
    Ok(())
}

/// # Errors
/// Returns [`Error::File`] if the path exists but cannot be removed.
pub fn remove_file_or_directory_if_present(path: &Path) -> Result<()> {
    if path.is_dir() {
        return fs::remove_dir_all(path).add_path("remove", path);
    }
    if fs::symlink_metadata(path).is_ok() {
        return fs::remove_file(path).add_path("remove", path);
    }
    Ok(())
}

/// # Errors
/// Returns [`Error::File`] if the rename fails.
pub fn rename(from: &Path, to: &Path) -> Result<()> {
    fs::rename(from, to).add_path("rename", from)
}

/// Copies contents, permissions and modification time, so a later comparison can
/// tell that the two are the same file.
///
/// # Errors
/// Returns [`Error::File`] if the copy fails.
pub fn copy_file_preserving_modification_time(source: &Path, destination: &Path) -> Result<()> {
    fs::copy(source, destination).add_path("copy", source)?;
    let metadata = read_metadata_without_following_symlinks(source)?;
    let modified = Timespec {
        tv_sec: metadata.mtime(),
        tv_nsec: metadata.mtime_nsec(),
    };
    let times = Timestamps {
        last_access: modified,
        last_modification: modified,
    };
    utimensat(CWD, destination, &times, AtFlags::empty()).map_err(|errno| Error::File {
        operation: "set the modification time of",
        path: destination.to_path_buf(),
        source: errno.into(),
    })
}

/// # Errors
/// Returns [`Error::File`] if the link cannot be created.
pub fn create_hard_link_replacing_existing(existing: &Path, link: &Path) -> Result<()> {
    replacing_existing(link, || fs::hard_link(existing, link)).add_path("hardlink", link)
}

/// # Errors
/// Returns [`Error::File`] if the link cannot be created.
pub fn create_symlink_replacing_existing(target: &Path, link: &Path) -> Result<()> {
    replacing_existing(link, || std::os::unix::fs::symlink(target, link)).add_path("symlink", link)
}

/// # Errors
/// Returns [`Error::File`] if the link cannot be read.
pub fn read_symlink_target(link: &Path) -> Result<PathBuf> {
    fs::read_link(link).add_path("read the target of", link)
}

/// Creating a link fails when the path is taken, which happens when placing over
/// an existing tree. Retrying costs a syscall only in that case, whereas checking
/// beforehand would cost one every time.
fn replacing_existing(
    link: &Path,
    create: impl Fn() -> std::io::Result<()>,
) -> std::io::Result<()> {
    match create() {
        Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => {
            fs::remove_file(link)?;
            create()
        }
        result => result,
    }
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct CopyReport {
    pub linked_files: usize,
    pub copied_files: usize,
    pub linked_bytes: u64,
    pub copied_bytes: u64,
}

impl std::ops::AddAssign for CopyReport {
    fn add_assign(&mut self, other: Self) {
        self.linked_files += other.linked_files;
        self.copied_files += other.copied_files;
        self.linked_bytes += other.linked_bytes;
        self.copied_bytes += other.copied_bytes;
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
struct Timestamp {
    seconds: i64,
    nanoseconds: i64,
}

/// What makes two entries interchangeable, so one can stand in for the other as a
/// hardlink.
#[derive(Debug, Clone, Copy)]
struct Signature {
    directory: bool,
    symlink: bool,
    length: u64,
    modified: Timestamp,
    changed: Timestamp,
}

impl Signature {
    fn of(metadata: &Metadata) -> Self {
        Self {
            directory: metadata.is_dir(),
            symlink: metadata.is_symlink(),
            length: metadata.len(),
            modified: Timestamp {
                seconds: metadata.mtime(),
                nanoseconds: metadata.mtime_nsec(),
            },
            changed: Timestamp {
                seconds: metadata.ctime(),
                nanoseconds: metadata.ctime_nsec(),
            },
        }
    }

    fn of_path(path: &Path) -> Result<Self> {
        Ok(Self::of(&read_metadata_without_following_symlinks(path)?))
    }

    fn is_indistinguishable_from(&self, other: &Self) -> bool {
        self.directory == other.directory
            && self.symlink == other.symlink
            && self.length == other.length
            && self.modified == other.modified
    }
}

fn is_unchanged_copy(
    source: &Path,
    source_signature: Signature,
    candidate: &Path,
    candidate_signature: Option<Signature>,
) -> Result<bool> {
    let Some(existing) = candidate_signature else {
        return Ok(false);
    };
    if !existing.is_indistinguishable_from(&source_signature) {
        return Ok(false);
    }
    if source_signature.modified < existing.changed {
        return Ok(true);
    }
    if source_signature.symlink {
        return Ok(read_symlink_target(source)? == read_symlink_target(candidate)?);
    }
    Ok(read_file_bytes(source)? == read_file_bytes(candidate)?)
}

/// Copies `source` and everything below it to `destination`, hardlinking any entry
/// that `reuse` holds unchanged rather than copying it. Absent reuse, or an entry
/// missing from it, means a plain copy.
///
/// Directories are walked in lockstep, so deciding what can be reused costs one
/// directory read per directory rather than one lookup per file — on a network
/// filesystem that is the difference between seconds and minutes.
///
/// # Errors
/// Returns [`Error::File`] if an entry cannot be read or written.
pub fn copy_tree(source: &Path, destination: &Path, reuse: Option<&Path>) -> Result<CopyReport> {
    if let Some(parent) = destination.parent() {
        create_directory_and_parents(parent)?;
    }
    let mut report = CopyReport::default();
    let signature = Signature::of_path(source)?;
    if signature.directory {
        copy_directory(source, destination, reuse, &mut report)?;
    } else {
        copy_file(source, destination, reuse, signature, &mut report)?;
    }
    Ok(report)
}

/// Copies `source` only if it is there, for state a repository accumulates but
/// need not have.
///
/// # Errors
/// Returns [`Error::File`] if an entry cannot be read or written.
pub fn copy_tree_if_present(
    source: &Path,
    destination: &Path,
    reuse: Option<&Path>,
) -> Result<CopyReport> {
    if fs::symlink_metadata(source).is_err() {
        return Ok(CopyReport::default());
    }
    copy_tree(source, destination, reuse)
}

/// Whether `candidate` holds an unchanged copy of every file in `source`, so
/// copying `source` would share all of them instead of writing any anew.
///
/// # Errors
/// Returns [`Error::File`] if `source` cannot be read.
pub fn all_files_are_unchanged_in(source: &Path, candidate: &Path) -> Result<bool> {
    let reusable = signatures_by_name(candidate)?;
    for name in list_directory(source)? {
        let entry = source.join(&name);
        let existing = candidate.join(&name);
        let signature = Signature::of_path(&entry)?;
        if signature.directory {
            if !all_files_are_unchanged_in(&entry, &existing)? {
                return Ok(false);
            }
        } else if !is_unchanged_copy(&entry, signature, &existing, reusable.get(&name).copied())? {
            return Ok(false);
        }
    }
    Ok(true)
}

fn copy_directory(
    source: &Path,
    destination: &Path,
    reuse: Option<&Path>,
    report: &mut CopyReport,
) -> Result<()> {
    create_directory_and_parents(destination)?;
    let reusable = match reuse {
        Some(path) => signatures_by_name(path)?,
        None => HashMap::new(),
    };
    for name in list_directory(source)? {
        let entry = source.join(&name);
        let signature = Signature::of_path(&entry)?;
        let placed = destination.join(&name);
        let candidate = reuse.map(|path| path.join(&name));
        if signature.directory {
            copy_directory(&entry, &placed, candidate.as_deref(), report)?;
            continue;
        }
        let identical = match candidate {
            Some(existing) => {
                is_unchanged_copy(&entry, signature, &existing, reusable.get(&name).copied())?
                    .then_some(existing)
            }
            None => None,
        };
        match identical {
            Some(existing) => {
                create_hard_link_replacing_existing(&existing, &placed)?;
                report.linked_files += 1;
                report.linked_bytes += signature.length;
            }
            None => copy_file(&entry, &placed, None, signature, report)?,
        }
    }
    Ok(())
}

fn copy_file(
    source: &Path,
    destination: &Path,
    reuse: Option<&Path>,
    signature: Signature,
    report: &mut CopyReport,
) -> Result<()> {
    let identical = match reuse {
        Some(path) => {
            is_unchanged_copy(source, signature, path, Signature::of_path(path).ok())?
                .then_some(path)
        }
        None => None,
    };
    if let Some(existing) = identical {
        create_hard_link_replacing_existing(existing, destination)?;
        report.linked_files += 1;
        report.linked_bytes += signature.length;
        return Ok(());
    }
    if signature.symlink {
        create_symlink_replacing_existing(&read_symlink_target(source)?, destination)?;
    } else {
        copy_file_preserving_modification_time(source, destination)?;
    }
    report.copied_files += 1;
    report.copied_bytes += signature.length;
    Ok(())
}

/// A directory that is not there simply offers nothing to reuse.
fn signatures_by_name(directory: &Path) -> Result<HashMap<OsString, Signature>> {
    if !directory.is_dir() {
        return Ok(HashMap::new());
    }
    let mut signatures = HashMap::new();
    for name in list_directory(directory)? {
        signatures.insert(name.clone(), Signature::of_path(&directory.join(&name))?);
    }
    Ok(signatures)
}

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::panic)]
mod tests {
    use std::fs;
    use std::os::unix::fs::MetadataExt as _;
    use std::path::Path;

    use super::{CopyReport, all_files_are_unchanged_in, copy_tree, copy_tree_if_present};

    fn write(path: &Path, contents: &str) {
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        fs::write(path, contents).unwrap();
    }

    fn inode(path: &Path) -> u64 {
        fs::metadata(path).unwrap().ino()
    }

    #[test]
    fn copies_a_tree_and_preserves_modification_times() {
        let root = tempfile::tempdir().unwrap();
        write(&root.path().join("source/pack/one"), "first");
        write(&root.path().join("source/loose"), "second");

        let report = copy_tree(
            &root.path().join("source"),
            &root.path().join("destination"),
            None,
        )
        .unwrap();

        assert_eq!(report.copied_files, 2);
        assert_eq!(report.linked_files, 0);
        for name in ["pack/one", "loose"] {
            let original = fs::metadata(root.path().join("source").join(name)).unwrap();
            let placed = fs::metadata(root.path().join("destination").join(name)).unwrap();
            assert_eq!(original.modified().unwrap(), placed.modified().unwrap());
        }
    }

    #[test]
    fn hardlinks_unchanged_entries_and_copies_the_rest() {
        let root = tempfile::tempdir().unwrap();
        let source = root.path().join("source");
        write(&source.join("pack/one"), "first");
        write(&source.join("refs/main"), "old");
        let first = root.path().join("first");
        copy_tree(&source, &first, None).unwrap();

        write(&source.join("refs/main"), "new");
        let second = root.path().join("second");
        let report = copy_tree(&source, &second, Some(&first)).unwrap();

        assert_eq!((report.linked_files, report.copied_files), (1, 1));
        assert_eq!(
            inode(&first.join("pack/one")),
            inode(&second.join("pack/one"))
        );
        assert_ne!(
            inode(&first.join("refs/main")),
            inode(&second.join("refs/main"))
        );
        assert_eq!(fs::read_to_string(second.join("refs/main")).unwrap(), "new");
    }

    #[test]
    fn a_rewritten_file_of_equal_size_is_not_reused() {
        let root = tempfile::tempdir().unwrap();
        let source = root.path().join("state");
        write(&source, "aaa");
        let first = root.path().join("first");
        copy_tree(&source, &first, None).unwrap();

        write(&source, "bbb");
        let second = root.path().join("second");
        let report = copy_tree(&source, &second, Some(&first)).unwrap();

        assert_eq!(
            report,
            CopyReport {
                copied_files: 1,
                copied_bytes: 3,
                ..CopyReport::default()
            }
        );
        assert_eq!(fs::read_to_string(second).unwrap(), "bbb");
    }

    #[test]
    fn copies_what_the_reuse_tree_does_not_have() {
        let root = tempfile::tempdir().unwrap();
        write(&root.path().join("source/one"), "contents");

        let report = copy_tree(
            &root.path().join("source"),
            &root.path().join("destination"),
            Some(&root.path().join("absent")),
        )
        .unwrap();

        assert_eq!((report.linked_files, report.copied_files), (0, 1));
    }

    #[test]
    fn skips_a_tree_that_is_not_there() {
        let root = tempfile::tempdir().unwrap();

        let report = copy_tree_if_present(
            &root.path().join("absent"),
            &root.path().join("destination"),
            None,
        )
        .unwrap();

        assert_eq!(report, CopyReport::default());
        assert!(!root.path().join("destination").exists());
    }

    #[test]
    fn keeps_symlinks_as_symlinks() {
        let root = tempfile::tempdir().unwrap();
        write(&root.path().join("source/target"), "contents");
        std::os::unix::fs::symlink("target", root.path().join("source/link")).unwrap();

        copy_tree(
            &root.path().join("source"),
            &root.path().join("destination"),
            None,
        )
        .unwrap();

        assert_eq!(
            fs::read_link(root.path().join("destination/link")).unwrap(),
            Path::new("target")
        );
    }

    #[test]
    fn preserves_empty_directories() {
        let root = tempfile::tempdir().unwrap();
        fs::create_dir_all(root.path().join("source/op_heads/heads")).unwrap();

        copy_tree(
            &root.path().join("source"),
            &root.path().join("destination"),
            None,
        )
        .unwrap();

        assert!(root.path().join("destination/op_heads/heads").is_dir());
    }

    #[test]
    fn reports_whether_every_file_is_unchanged_elsewhere() {
        let root = tempfile::tempdir().unwrap();
        let source = root.path().join("source");
        write(&source.join("one.pack"), "contents");
        let copy = root.path().join("copy");
        copy_tree(&source, &copy, None).unwrap();

        assert!(all_files_are_unchanged_in(&source, &copy).unwrap());

        write(&source.join("two.pack"), "added later");
        assert!(!all_files_are_unchanged_in(&source, &copy).unwrap());
    }
}
