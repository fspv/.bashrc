use std::process::Command;

use thiserror::Error;

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
    #[error("could not parse output: {0}")]
    Parse(String),
}

pub type Result<T> = std::result::Result<T, Error>;

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
