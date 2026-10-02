//! A typed async wrapper over the `podman` and `podman-compose` CLIs, run as an
//! unprivileged user through `su-exec`.

use std::fmt;
use std::path::Path;
use std::process::Stdio;
use std::time::Duration;

use common::{Error, Result, run_output, run_streaming, run_streaming_checked};
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct ContainerName(String);

impl fmt::Display for ContainerName {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

#[derive(Debug, Clone)]
pub struct Podman {
    user: String,
}

impl Podman {
    #[must_use]
    pub fn as_user(user: impl Into<String>) -> Self {
        Self { user: user.into() }
    }

    /// # Errors
    /// Returns [`Error::Failed`] if `podman-compose` exits with a non-zero status.
    pub async fn compose_up_detached(&self) -> Result<()> {
        self.compose(&["up", "-d"]).await
    }

    /// # Errors
    /// Returns [`Error::Failed`] if `podman-compose` exits with a non-zero status.
    pub async fn compose_down(&self) -> Result<()> {
        self.compose(&["down"]).await
    }

    /// # Errors
    /// Returns [`Error::Failed`] if the prune exits with a non-zero status.
    pub async fn prune_images_and_volumes(&self) -> Result<()> {
        self.podman_streaming(&["system", "prune", "-a", "--volumes", "-f"])
            .await
    }

    /// # Errors
    /// Returns [`Error::Failed`] if the prune exits with a non-zero status.
    pub async fn prune_build_cache(&self) -> Result<()> {
        self.podman_streaming(&["builder", "prune", "-a", "-f"])
            .await
    }

    /// # Errors
    /// Returns [`Error::Failed`] if the prune exits with a non-zero status.
    pub async fn prune_pods(&self) -> Result<()> {
        self.podman_streaming(&["pod", "prune", "-f"]).await
    }

    /// Serves the podman API on `socket` until the service exits, returning its
    /// exit code.
    ///
    /// # Errors
    /// Returns [`Error::Spawn`] if the service cannot be started.
    pub async fn serve_api(&self, socket: &Path) -> Result<i32> {
        let url = format!("unix://{}", socket.display());
        run_streaming(
            "su-exec",
            &[&self.user, "podman", "system", "service", "--time=0", &url],
        )
        .await
    }

    /// # Errors
    /// Returns [`Error::Failed`] if the API on `socket` does not answer.
    pub async fn probe_api(&self, socket: &Path) -> Result<()> {
        let url = format!("unix://{}", socket.display());
        self.podman_output(&["--remote", "--url", &url, "version"])
            .await
            .map(drop)
    }

    /// # Errors
    /// Returns [`Error::Failed`] if `podman ps` exits with a non-zero status.
    pub async fn running_containers(&self) -> Result<Vec<ContainerName>> {
        let output = self
            .podman_output(&["ps", "--format", "{{.Names}}"])
            .await?;
        Ok(output
            .lines()
            .map(str::trim)
            .filter(|line| !line.is_empty())
            .map(|line| ContainerName(line.to_string()))
            .collect())
    }

    /// The interval of the healthcheck declared on `container`, or `None` when it
    /// declares none.
    ///
    /// # Errors
    /// Returns [`Error::Failed`] if the inspect fails, or [`Error::Parse`] if the
    /// interval is not a positive number of nanoseconds.
    pub async fn healthcheck_interval(
        &self,
        container: &ContainerName,
    ) -> Result<Option<Duration>> {
        let template = r#"{{if .Config.Healthcheck}}{{printf "%d" .Config.Healthcheck.Interval}}{{else}}none{{end}}"#;
        let output = self
            .podman_output(&["container", "inspect", "--format", template, &container.0])
            .await?;
        if output == "none" || output.is_empty() {
            return Ok(None);
        }
        let nanoseconds: u64 = output
            .parse()
            .map_err(|_| Error::Parse(format!("healthcheck interval {output:?}")))?;
        if nanoseconds == 0 {
            return Err(Error::Parse("zero healthcheck interval".to_string()));
        }
        Ok(Some(Duration::from_nanos(nanoseconds)))
    }

    /// # Errors
    /// Returns [`Error::Failed`] with the healthcheck's exit code if the container
    /// is unhealthy.
    pub async fn run_healthcheck(&self, container: &ContainerName) -> Result<()> {
        self.podman_output(&["healthcheck", "run", &container.0])
            .await
            .map(drop)
    }

    /// Waits for the first container to die and returns its name, or `None` if
    /// the event stream ends first.
    ///
    /// # Errors
    /// Returns [`Error::Spawn`] if `podman events` cannot be started, or
    /// [`Error::Io`] if its output cannot be read.
    pub async fn first_container_death(&self) -> Result<Option<ContainerName>> {
        let mut child = Command::new("su-exec")
            .args([
                &self.user,
                "podman",
                "events",
                "--filter",
                "type=container",
                "--filter",
                "event=died",
                "--format",
                "{{.Name}}",
            ])
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .kill_on_drop(true)
            .spawn()
            .map_err(|source| Error::Spawn {
                program: "podman events".to_string(),
                source,
            })?;
        let Some(stdout) = child.stdout.take() else {
            return Ok(None);
        };
        let name = BufReader::new(stdout).lines().next_line().await?;
        let _ = child.start_kill();
        let _ = child.wait().await;
        Ok(name.map(ContainerName))
    }

    async fn compose(&self, args: &[&str]) -> Result<()> {
        run_streaming_checked(
            "su-exec",
            &[&[self.user.as_str(), "podman-compose"], args].concat(),
        )
        .await
    }

    async fn podman_streaming(&self, args: &[&str]) -> Result<()> {
        run_streaming_checked("su-exec", &[&[self.user.as_str(), "podman"], args].concat()).await
    }

    async fn podman_output(&self, args: &[&str]) -> Result<String> {
        run_output("su-exec", &[&[self.user.as_str(), "podman"], args].concat()).await
    }
}
