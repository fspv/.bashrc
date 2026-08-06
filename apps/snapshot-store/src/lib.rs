//! A store of point-in-time generations on durable storage.
//!
//! A generation is only ever published by renaming a fully written staging
//! directory into place and then atomically re-pointing `current` at it, so an
//! interrupted run can never damage the last good generation.

use std::fmt;
use std::path::{Path, PathBuf};
use std::str::FromStr;

use chrono::{DateTime, SecondsFormat, SubsecRound as _, Utc};
use common::files;
use common::{Error, Hostname, Result};
use serde::{Deserialize, Serialize};

pub mod retention;

pub use retention::Retention;

const CURRENT_LINK: &str = "current";
const LOCK_FILE: &str = ".lock";
const STAGING_PREFIX: &str = ".incomplete-";

/// The directory a store lives in.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StoreRoot(PathBuf);

impl StoreRoot {
    #[must_use]
    pub fn as_path(&self) -> &Path {
        &self.0
    }
}

impl From<PathBuf> for StoreRoot {
    fn from(path: PathBuf) -> Self {
        Self(path)
    }
}

impl FromStr for StoreRoot {
    type Err = Error;

    fn from_str(path: &str) -> Result<Self> {
        Ok(Self(PathBuf::from(path)))
    }
}

impl fmt::Display for StoreRoot {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.0.display().fmt(f)
    }
}

/// Identifies a generation by the second at which it was started. Its `Display`
/// form is an RFC 3339 timestamp, which is also the directory name and sorts
/// chronologically.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(try_from = "String", into = "String")]
pub struct GenerationId(DateTime<Utc>);

impl GenerationId {
    #[must_use]
    pub fn at(moment: DateTime<Utc>) -> Self {
        Self(moment.trunc_subsecs(0))
    }

    #[must_use]
    pub fn now() -> Self {
        Self::at(Utc::now())
    }

    #[must_use]
    pub const fn moment(&self) -> DateTime<Utc> {
        self.0
    }
}

impl fmt::Display for GenerationId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0.to_rfc3339_opts(SecondsFormat::Secs, true))
    }
}

impl FromStr for GenerationId {
    type Err = Error;

    fn from_str(text: &str) -> Result<Self> {
        DateTime::parse_from_rfc3339(text)
            .map(|moment| Self::at(moment.with_timezone(&Utc)))
            .map_err(|_| Error::Parse(format!("`{text}` is not a generation id")))
    }
}

impl TryFrom<String> for GenerationId {
    type Error = Error;

    fn try_from(text: String) -> Result<Self> {
        text.parse()
    }
}

impl From<GenerationId> for String {
    fn from(id: GenerationId) -> Self {
        id.to_string()
    }
}

/// A published generation.
#[derive(Debug, Clone)]
pub struct Generation {
    id: GenerationId,
    path: PathBuf,
}

impl Generation {
    #[must_use]
    pub const fn id(&self) -> GenerationId {
        self.id
    }

    #[must_use]
    pub fn path(&self) -> &Path {
        &self.path
    }
}

/// A generation being written.
///
/// It becomes visible only through [`Staging::publish`]; if the run dies first
/// the directory is left behind for inspection, and the store keeps serving the
/// previous generation.
#[derive(Debug)]
pub struct Staging {
    id: GenerationId,
    path: PathBuf,
    store: PathBuf,
}

impl Staging {
    #[must_use]
    pub const fn id(&self) -> GenerationId {
        self.id
    }

    #[must_use]
    pub fn path(&self) -> &Path {
        &self.path
    }

    /// Renames the staging directory into place and re-points `current` at it.
    ///
    /// # Errors
    /// Returns [`Error::File`] if either rename fails.
    pub fn publish(self) -> Result<Generation> {
        let published = self.store.join(self.id.to_string());
        files::rename(&self.path, &published)?;

        let pending = self.store.join(format!(".{CURRENT_LINK}-pending"));
        files::create_symlink_replacing_existing(Path::new(&self.id.to_string()), &pending)?;
        files::rename(&pending, &self.store.join(CURRENT_LINK))?;

        Ok(Generation {
            id: self.id,
            path: published,
        })
    }
}

/// Whoever holds the store lock, so a refusal names the process to look at.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Holder {
    pub host: Hostname,
    pub pid: u32,
    pub since: DateTime<Utc>,
}

impl fmt::Display for Holder {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{} pid {} since {}",
            self.host,
            self.pid,
            self.since.to_rfc3339_opts(SecondsFormat::Secs, true)
        )
    }
}

/// Exclusive access to a store, released on drop.
///
/// A process that dies without dropping it leaves the lock behind on purpose:
/// the next run then fails loudly instead of writing alongside a run whose state
/// is unknown.
#[derive(Debug)]
pub struct Lock {
    path: PathBuf,
}

impl Drop for Lock {
    fn drop(&mut self) {
        if let Err(error) = std::fs::remove_file(&self.path) {
            tracing::warn!("failed to release {}: {error}", self.path.display());
        }
    }
}

#[derive(Debug, Clone)]
pub struct Store {
    root: StoreRoot,
}

impl Store {
    /// # Errors
    /// Returns [`Error::State`] if the root is not an existing directory.
    pub fn open(root: StoreRoot) -> Result<Self> {
        if root.as_path().is_dir() {
            Ok(Self { root })
        } else {
            Err(Error::State(format!(
                "`{root}` is not a directory; create it to initialise the store"
            )))
        }
    }

    #[must_use]
    pub const fn root(&self) -> &StoreRoot {
        &self.root
    }

    /// Published generations, oldest first.
    ///
    /// # Errors
    /// Returns [`Error::File`] if the store cannot be listed.
    pub fn generations(&self) -> Result<Vec<Generation>> {
        let mut generations: Vec<Generation> = self
            .entry_names()?
            .iter()
            .filter_map(|name| name.parse::<GenerationId>().ok())
            .map(|id| self.generation_at(id))
            .collect();
        generations.sort_by_key(Generation::id);
        Ok(generations)
    }

    /// Staging directories left behind by runs that did not finish.
    ///
    /// # Errors
    /// Returns [`Error::File`] if the store cannot be listed.
    pub fn unfinished_staging_directories(&self) -> Result<Vec<PathBuf>> {
        Ok(self
            .entry_names()?
            .iter()
            .filter(|name| name.starts_with(STAGING_PREFIX))
            .map(|name| self.root.as_path().join(name))
            .collect())
    }

    /// # Errors
    /// Returns [`Error::File`] if `current` exists but cannot be read, or
    /// [`Error::Parse`] if it does not name a generation.
    pub fn current_generation(&self) -> Result<Option<Generation>> {
        let link = self.root.as_path().join(CURRENT_LINK);
        if files::read_metadata_without_following_symlinks(&link).is_err() {
            return Ok(None);
        }
        let target = files::read_symlink_target(&link)?;
        let name = target
            .to_str()
            .ok_or_else(|| Error::Parse(format!("`{}` is not utf-8", target.display())))?;
        self.find_generation(name.parse()?).map(Some)
    }

    /// # Errors
    /// Returns [`Error::State`] if the generation is not in the store.
    pub fn find_generation(&self, id: GenerationId) -> Result<Generation> {
        let generation = self.generation_at(id);
        if generation.path.is_dir() {
            Ok(generation)
        } else {
            Err(Error::State(format!(
                "generation {id} is not in {}",
                self.root
            )))
        }
    }

    /// # Errors
    /// Returns [`Error::State`] naming the [`Holder`] if the store is already
    /// locked, including by a run that crashed.
    pub fn lock(&self) -> Result<Lock> {
        let path = self.root.as_path().join(LOCK_FILE);
        let holder = Holder {
            host: Hostname::of_this_machine()?,
            pid: std::process::id(),
            since: Utc::now(),
        };
        let recorded = toml::to_string(&holder)
            .map_err(|error| Error::State(format!("cannot record the lock holder: {error}")))?;
        if files::write_file_if_absent(&path, recorded.as_bytes())? {
            return Ok(Lock { path });
        }
        let current = self.lock_holder()?.map_or_else(
            || "a run that has just released it".to_string(),
            |holder| holder.to_string(),
        );
        Err(Error::State(format!(
            "store is locked by {current}: run `snapshot-store unlock` once that run is known to be gone"
        )))
    }

    /// # Errors
    /// Returns an error if the lock file exists but cannot be read.
    pub fn lock_holder(&self) -> Result<Option<Holder>> {
        let path = self.root.as_path().join(LOCK_FILE);
        if files::read_metadata_without_following_symlinks(&path).is_err() {
            return Ok(None);
        }
        let recorded = files::read_file_text(&path)?;
        toml::from_str(&recorded)
            .map(Some)
            .map_err(|error| Error::Parse(format!("cannot read {}: {error}", path.display())))
    }

    /// Removes the lock file, for one left behind by a run that died.
    ///
    /// # Errors
    /// Returns [`Error::File`] if the lock file cannot be removed.
    pub fn discard_lock(&self) -> Result<()> {
        files::remove_file_or_directory_if_present(&self.root.as_path().join(LOCK_FILE))
    }

    /// Generations are identified to the second, so at most one can be taken per
    /// second.
    ///
    /// # Errors
    /// Returns [`Error::State`] if `id` is already published, or [`Error::File`]
    /// if a staging directory for it exists or cannot be created.
    pub fn stage(&self, id: GenerationId) -> Result<Staging> {
        if self.generation_at(id).path.exists() {
            return Err(Error::State(format!(
                "generation {id} is already in {}",
                self.root
            )));
        }
        let path = self.root.as_path().join(format!("{STAGING_PREFIX}{id}"));
        std::fs::create_dir(&path).map_err(|source| Error::File {
            operation: "create",
            path: path.clone(),
            source,
        })?;
        Ok(Staging {
            id,
            path,
            store: self.root.as_path().to_path_buf(),
        })
    }

    /// Removes the generations `retention` does not keep, never the current one.
    ///
    /// # Errors
    /// Returns [`Error::File`] if a generation cannot be removed.
    pub fn prune(&self, retention: &Retention, now: DateTime<Utc>) -> Result<Vec<GenerationId>> {
        let published: Vec<GenerationId> = self.generations()?.iter().map(Generation::id).collect();
        let current = self.current_generation()?.as_ref().map(Generation::id);
        let mut removed = Vec::new();
        for id in retention.expired(&published, now) {
            if Some(id) == current {
                continue;
            }
            files::remove_directory_if_present(&self.generation_at(id).path)?;
            removed.push(id);
        }
        Ok(removed)
    }

    fn generation_at(&self, id: GenerationId) -> Generation {
        Generation {
            id,
            path: self.root.as_path().join(id.to_string()),
        }
    }

    fn entry_names(&self) -> Result<Vec<String>> {
        Ok(files::list_directory(self.root.as_path())?
            .iter()
            .filter_map(|name| name.to_str().map(str::to_string))
            .collect())
    }
}

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::panic)]
mod tests {
    use chrono::{DateTime, TimeDelta, Utc};

    use super::{GenerationId, Store, StoreRoot};

    fn store() -> (tempfile::TempDir, Store) {
        let root = tempfile::tempdir().unwrap();
        let store = Store::open(StoreRoot::from(root.path().to_path_buf())).unwrap();
        (root, store)
    }

    fn fixed_now() -> DateTime<Utc> {
        DateTime::from_timestamp(1_800_000_000, 0).unwrap()
    }

    #[test]
    fn generation_ids_round_trip_through_their_directory_name() {
        let id = GenerationId::at(fixed_now());
        assert_eq!(id.to_string(), "2027-01-15T08:00:00Z");
        assert_eq!(id.to_string().parse::<GenerationId>().unwrap(), id);
        assert_eq!(
            "2027-01-15T08:00:00.5Z".parse::<GenerationId>().unwrap(),
            id,
            "parsing truncates to the second, as directory names do"
        );
    }

    #[test]
    fn publishing_moves_the_staging_directory_and_advances_current() {
        let (_root, store) = store();
        let id = GenerationId::now();
        let staging = store.stage(id).unwrap();
        std::fs::write(staging.path().join("manifest.toml"), "generation = 1").unwrap();

        let generation = staging.publish().unwrap();

        assert_eq!(generation.id(), id);
        assert_eq!(store.current_generation().unwrap().unwrap().id(), id);
        assert!(store.unfinished_staging_directories().unwrap().is_empty());
        assert!(generation.path().join("manifest.toml").is_file());
    }

    #[test]
    fn an_unpublished_generation_is_invisible_and_leaves_current_alone() {
        let (_root, store) = store();
        let published = store.stage(GenerationId::now()).unwrap().publish().unwrap();

        let abandoned = store
            .stage(GenerationId::at(Utc::now() + TimeDelta::seconds(30)))
            .unwrap();
        std::fs::write(abandoned.path().join("half-written"), "...").unwrap();
        drop(abandoned);

        assert_eq!(
            store.current_generation().unwrap().unwrap().id(),
            published.id()
        );
        assert_eq!(store.generations().unwrap().len(), 1);
        assert_eq!(store.unfinished_staging_directories().unwrap().len(), 1);
    }

    #[test]
    fn a_second_lock_is_refused_and_names_the_holder() {
        let (_root, store) = store();
        let held = store.lock().unwrap();

        let refused = store.lock().unwrap_err().to_string();
        assert!(refused.contains("locked by"));
        assert!(refused.contains(&std::process::id().to_string()));
        assert_eq!(
            store.lock_holder().unwrap().unwrap().pid,
            std::process::id()
        );

        drop(held);
        assert!(store.lock_holder().unwrap().is_none());
        assert!(store.lock().is_ok());
    }

    #[test]
    fn discarding_the_lock_lets_the_next_run_proceed() {
        let (_root, store) = store();
        std::mem::forget(store.lock().unwrap());

        store.discard_lock().unwrap();

        assert!(store.lock_holder().unwrap().is_none());
    }

    #[test]
    fn pruning_keeps_the_current_generation_even_when_it_has_expired() {
        let (_root, store) = store();
        let now = fixed_now();
        let newest = GenerationId::at(now - TimeDelta::days(400));
        let middle = GenerationId::at(now - TimeDelta::days(401));
        let oldest = GenerationId::at(now - TimeDelta::days(402));
        store.stage(newest).unwrap().publish().unwrap();
        store.stage(middle).unwrap().publish().unwrap();
        store.stage(oldest).unwrap().publish().unwrap();

        let removed = store.prune(&super::Retention::default(), now).unwrap();

        assert_eq!(removed, vec![middle]);
        assert_eq!(store.current_generation().unwrap().unwrap().id(), oldest);
        assert_eq!(store.generations().unwrap().len(), 2);
    }
}
