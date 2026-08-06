use std::fmt;
use std::path::PathBuf;
use std::process::Command;

use serde::{Deserialize, Serialize};
use thiserror::Error;
use tracing::Level;

pub mod files;

/// Errors shared across the tool crates.
#[derive(Debug, Error)]
pub enum Error {
    #[error("failed to spawn `{program}`: {source}")]
    Spawn {
        program: String,
        #[source]
        source: std::io::Error,
    },
    #[error("`{program}` failed (exit {code}): {stderr}")]
    Failed {
        program: String,
        code: String,
        stderr: String,
    },
    #[error(transparent)]
    Io(#[from] std::io::Error),
    #[error("could not {operation} `{path}`: {source}")]
    File {
        operation: &'static str,
        path: PathBuf,
        #[source]
        source: std::io::Error,
    },
    #[error("could not parse output: {0}")]
    Parse(String),
    #[error("{0}")]
    State(String),
}

pub type Result<T> = std::result::Result<T, Error>;

/// Sends log records to stderr. Commands are recorded at `DEBUG`, so a tool that
/// runs unattended stays quiet at `INFO`.
pub fn log_to_stderr(level: Level) {
    tracing_subscriber::fmt()
        .with_max_level(level)
        .with_writer(std::io::stderr)
        .without_time()
        .with_target(false)
        .init();
}

/// The version string a tool reports for itself.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ToolVersion(String);

impl ToolVersion {
    pub fn new(version: impl Into<String>) -> Self {
        Self(version.into())
    }
}

impl fmt::Display for ToolVersion {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Hostname(String);

impl Hostname {
    /// # Errors
    /// Returns [`Error::Parse`] if the kernel reports a name that is not utf-8.
    pub fn of_this_machine() -> Result<Self> {
        let name = rustix::system::uname();
        name.nodename()
            .to_str()
            .map(|nodename| Self(nodename.to_string()))
            .map_err(|_| Error::Parse("the hostname is not utf-8".to_string()))
    }
}

impl fmt::Display for Hostname {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

/// Renders a byte count the way `ls -h` does, as in `4.9 GiB`.
#[must_use]
pub fn format_bytes_in_binary_units(count: u64) -> String {
    let units = ["B", "KiB", "MiB", "GiB", "TiB"];
    let mut tenths = u128::from(count) * 10;
    let mut unit = 0;
    while tenths >= 10 * 1024 && unit + 1 < units.len() {
        tenths /= 1024;
        unit += 1;
    }
    format!("{}.{} {}", tenths / 10, tenths % 10, units[unit])
}

fn log_command(program: &str, args: &[&str]) {
    tracing::debug!("+ {program} {}", args.join(" "));
}

/// Run a command, capturing and returning its trimmed stdout.
///
/// # Errors
/// Returns [`Error::Spawn`] if the process cannot be started, or [`Error::Failed`]
/// (with the captured stderr) if it exits with a non-zero status.
pub fn run_output(program: &str, args: &[&str]) -> Result<String> {
    run_output_env(program, args, &[])
}

/// Like [`run_output`], but sets the given environment variables on the child,
/// overriding any inherited values.
///
/// # Errors
/// Returns [`Error::Spawn`] if the process cannot be started, or [`Error::Failed`]
/// (with the captured stderr) if it exits with a non-zero status.
pub fn run_output_env(program: &str, args: &[&str], env: &[(&str, &str)]) -> Result<String> {
    log_command(program, args);
    let mut command = Command::new(program);
    command.args(args);
    for (key, value) in env {
        command.env(key, value);
    }
    let output = command.output().map_err(|source| Error::Spawn {
        program: program.to_string(),
        source,
    })?;
    if !output.status.success() {
        return Err(Error::Failed {
            program: program.to_string(),
            code: exit_label(output.status.code()),
            stderr: String::from_utf8_lossy(&output.stderr).trim().to_string(),
        });
    }
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

/// Run a command with inherited stdio (its output streams to the terminal),
/// returning its exit code.
///
/// # Errors
/// Returns [`Error::Spawn`] if the process cannot be started.
pub fn run_streaming(program: &str, args: &[&str]) -> Result<i32> {
    log_command(program, args);
    let status = Command::new(program)
        .args(args)
        .status()
        .map_err(|source| Error::Spawn {
            program: program.to_string(),
            source,
        })?;
    Ok(status.code().unwrap_or(1))
}

/// Run a command with inherited stdio and require a successful exit.
///
/// # Errors
/// Returns [`Error::Spawn`] if the process cannot be started, or [`Error::Failed`]
/// if it exits with a non-zero status.
pub fn run_streaming_checked(program: &str, args: &[&str]) -> Result<()> {
    let code = run_streaming(program, args)?;
    if code != 0 {
        return Err(Error::Failed {
            program: program.to_string(),
            code: code.to_string(),
            stderr: String::new(),
        });
    }
    Ok(())
}

fn exit_label(code: Option<i32>) -> String {
    code.map_or_else(|| "signal".to_string(), |c| c.to_string())
}
