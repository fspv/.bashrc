use std::fs;
use std::path::{Path, PathBuf};

use common::{Error, Result};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

/// One agent-written comment attached to a 1-based source line.
#[derive(Clone, Serialize, Deserialize)]
pub struct Comment {
    pub line: usize,
    pub comment: String,
}

pub fn default_root() -> Result<PathBuf> {
    if let Some(xdg_cache_home) = std::env::var_os("XDG_CACHE_HOME") {
        return Ok(PathBuf::from(xdg_cache_home).join("comment-lsp"));
    }
    let home = std::env::var_os("HOME").ok_or_else(|| Error::Parse("HOME is not set".into()))?;
    Ok(PathBuf::from(home).join(".cache").join("comment-lsp"))
}

pub fn content_hash(text: &str) -> String {
    let digest = Sha256::digest(text.as_bytes());
    format!("{digest:x}")
}

/// Cache entries mirror the project tree: `<root>/<relative path>/<hash>.json`.
pub fn comment_file(cache_root: &Path, relative_path: &Path, hash: &str) -> PathBuf {
    cache_root.join(relative_path).join(format!("{hash}.json"))
}

pub fn load(path: &Path) -> Option<Vec<Comment>> {
    let raw = fs::read_to_string(path).ok()?;
    serde_json::from_str(&raw).ok()
}

pub fn store(path: &Path, comments: &[Comment]) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let raw =
        serde_json::to_string_pretty(comments).map_err(|source| Error::Parse(source.to_string()))?;
    fs::write(path, raw)?;
    Ok(())
}
