//! A typed wrapper over the `git` CLI, scoped to a specific repository.

use std::fmt;
use std::path::{Path, PathBuf};
use std::str::FromStr;

use common::{Error, Result, ToolVersion, run_output};
use serde::{Deserialize, Serialize};

/// Where git keeps its state in a checkout.
#[derive(Debug, Clone)]
pub struct GitDirectory(PathBuf);

impl GitDirectory {
    #[must_use]
    pub fn in_checkout(root: &Path) -> Self {
        Self(root.join(".git"))
    }

    #[must_use]
    pub fn path(&self) -> &Path {
        &self.0
    }

    #[must_use]
    pub fn objects(&self) -> PathBuf {
        self.0.join("objects")
    }

    #[must_use]
    pub fn packs(&self) -> PathBuf {
        self.objects().join("pack")
    }

    #[must_use]
    pub fn reflogs(&self) -> PathBuf {
        self.0.join("logs")
    }

    #[must_use]
    pub fn submodules(&self) -> PathBuf {
        self.0.join("modules")
    }

    #[must_use]
    pub fn local_excludes(&self) -> PathBuf {
        self.0.join("info")
    }

    #[must_use]
    pub fn config(&self) -> PathBuf {
        self.0.join("config")
    }

    #[must_use]
    pub fn packed_refs(&self) -> PathBuf {
        self.0.join("packed-refs")
    }

    #[must_use]
    pub fn loose_refs(&self) -> PathBuf {
        self.0.join("refs")
    }

    #[must_use]
    pub fn head(&self) -> PathBuf {
        self.0.join("HEAD")
    }
}

/// The hash of a git object.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
pub struct ObjectId(String);

impl ObjectId {
    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl FromStr for ObjectId {
    type Err = Error;

    fn from_str(text: &str) -> Result<Self> {
        let hex = text.trim();
        if hex.len() >= 40 && hex.chars().all(|c| c.is_ascii_hexdigit()) {
            Ok(Self(hex.to_string()))
        } else {
            Err(Error::Parse(format!("`{hex}` is not an object id")))
        }
    }
}

impl fmt::Display for ObjectId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

/// A fully qualified ref name, such as `refs/heads/main`.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub struct RefName(String);

impl RefName {
    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl FromStr for RefName {
    type Err = Error;

    fn from_str(text: &str) -> Result<Self> {
        let name = text.trim();
        if name.starts_with("refs/") && !name.contains(char::is_whitespace) {
            Ok(Self(name.to_string()))
        } else {
            Err(Error::Parse(format!(
                "`{name}` is not a qualified ref name"
            )))
        }
    }
}

impl fmt::Display for RefName {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub struct Ref {
    pub name: RefName,
    pub target: ObjectId,
}

/// Where `HEAD` points: at a branch, or straight at a commit.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Head {
    Branch(RefName),
    Detached(ObjectId),
}

impl Head {
    /// The `HEAD` file contents denoting this position.
    #[must_use]
    pub fn file_contents(&self) -> String {
        match self {
            Self::Branch(name) => format!("ref: {name}\n"),
            Self::Detached(commit) => format!("{commit}\n"),
        }
    }
}

impl fmt::Display for Head {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Branch(name) => write!(f, "{name}"),
            Self::Detached(commit) => write!(f, "{commit} (detached)"),
        }
    }
}

/// How git is pointed at the repository it should act on.
#[derive(Debug, Clone)]
enum Location {
    Worktree(PathBuf),
    GitDir(PathBuf),
}

#[derive(Debug, Clone)]
pub struct Repo {
    location: Location,
}

impl Repo {
    /// A repository addressed through its working copy, so worktree-aware
    /// commands (`reset`, `restore`) operate on the checked-out files.
    #[must_use]
    pub fn in_worktree(root: &Path) -> Self {
        Self {
            location: Location::Worktree(root.to_path_buf()),
        }
    }

    /// A repository addressed through its git directory alone, which is how a
    /// mirrored copy with no working copy is inspected.
    #[must_use]
    pub fn in_git_directory(path: &Path) -> Self {
        Self {
            location: Location::GitDir(path.to_path_buf()),
        }
    }

    fn git(&self, arguments: &[&str]) -> Result<String> {
        let all = self.arguments_addressing_this_repo(arguments)?;
        run_output(
            "git",
            &all.iter().map(String::as_str).collect::<Vec<&str>>(),
        )
    }

    fn arguments_addressing_this_repo(&self, arguments: &[&str]) -> Result<Vec<String>> {
        let mut all = match &self.location {
            Location::Worktree(root) => vec!["-C".to_string(), require_utf8_path(root)?],
            Location::GitDir(path) => vec![format!("--git-dir={}", require_utf8_path(path)?)],
        };
        all.extend(arguments.iter().map(|argument| (*argument).to_string()));
        Ok(all)
    }

    /// Every ref in the repository, loose and packed alike, sorted by name.
    ///
    /// # Errors
    /// Returns an error if `git for-each-ref` fails or emits an unreadable line.
    pub fn refs(&self) -> Result<Vec<Ref>> {
        let listing = self.git(&["for-each-ref", "--format=%(objectname) %(refname)"])?;
        let mut refs = listing
            .lines()
            .filter(|line| !line.is_empty())
            .map(|line| {
                let (target, name) = line
                    .split_once(' ')
                    .ok_or_else(|| Error::Parse(format!("unexpected for-each-ref line: {line}")))?;
                Ok(Ref {
                    name: name.parse()?,
                    target: target.parse()?,
                })
            })
            .collect::<Result<Vec<Ref>>>()?;
        refs.sort();
        Ok(refs)
    }

    /// # Errors
    /// Returns an error if `HEAD` cannot be resolved.
    pub fn head(&self) -> Result<Head> {
        match self.git(&["symbolic-ref", "--quiet", "HEAD"]) {
            Ok(name) => Ok(Head::Branch(name.parse()?)),
            Err(_) => Ok(Head::Detached(self.resolve("HEAD")?)),
        }
    }

    /// # Errors
    /// Returns an error if `revision` does not resolve to an object.
    pub fn resolve(&self, revision: &str) -> Result<ObjectId> {
        self.git(&["rev-parse", "--verify", revision])?.parse()
    }

    /// Walks every object reachable from `heads` but not from `excluded`,
    /// failing if any of them is absent from the object store.
    ///
    /// # Errors
    /// Returns an error if an object is missing or `git rev-list` fails.
    pub fn count_objects_reachable_from(
        &self,
        heads: &[ObjectId],
        excluded: &[ObjectId],
    ) -> Result<usize> {
        if heads.is_empty() {
            return Ok(0);
        }
        let mut arguments = vec!["rev-list".to_string(), "--objects".to_string()];
        arguments.extend(heads.iter().map(ObjectId::to_string));
        arguments.push("--not".to_string());
        arguments.extend(excluded.iter().map(ObjectId::to_string));
        let borrowed: Vec<&str> = arguments.iter().map(String::as_str).collect();
        Ok(self.git(&borrowed)?.lines().count())
    }

    /// Points the index and working copy at `commit`, leaving `HEAD` for
    /// [`Repo::set_head`] to place.
    ///
    /// # Errors
    /// Returns an error if `git reset` fails.
    pub fn reset_hard(&self, commit: &ObjectId) -> Result<()> {
        self.git(&["reset", "--hard", commit.as_str()]).map(drop)
    }

    /// # Errors
    /// Returns an error if the ref update fails.
    pub fn set_head(&self, head: &Head) -> Result<()> {
        match head {
            Head::Branch(name) => self.git(&["symbolic-ref", "HEAD", name.as_str()]),
            Head::Detached(commit) => {
                self.git(&["update-ref", "--no-deref", "HEAD", commit.as_str()])
            }
        }?;
        Ok(())
    }

    /// # Errors
    /// Returns an error if `git status` fails.
    pub fn is_worktree_clean(&self) -> Result<bool> {
        Ok(self.git(&["status", "--porcelain"])?.is_empty())
    }
}

fn require_utf8_path(path: &Path) -> Result<String> {
    path.to_str()
        .map(str::to_string)
        .ok_or_else(|| Error::Parse(format!("path is not utf-8: {}", path.display())))
}

/// # Errors
/// Returns an error if `git --version` fails.
pub fn version() -> Result<ToolVersion> {
    Ok(ToolVersion::new(run_output("git", &["--version"])?))
}
