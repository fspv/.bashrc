use std::collections::{HashMap, HashSet};
use std::path::Path;
use std::time::Duration;

use common::{Error, Result, files, run_streaming_checked};
use podman::{ContainerName, Podman};
use tokio::task::JoinHandle;
use tokio::time::sleep;
use tracing::{debug, error, info, warn};
use tracing_subscriber::EnvFilter;

enum Tracked {
    Active(JoinHandle<()>),
    NoHealthcheck,
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")),
        )
        .with_target(false)
        .init();

    info!("service-runner starting");

    let podman = Podman::as_user("svc");

    prepare_runtime_dir().await?;
    chown_path("/home/svc/.local/share/containers").await?;

    info!("running initial podman-compose down to clear stale state");
    match podman.compose_down().await {
        Ok(()) => info!("initial down succeeded"),
        Err(error) => warn!(%error, "initial down failed (continuing)"),
    }

    let discovery: JoinHandle<()> = tokio::spawn(discovery_loop(podman.clone()));
    let api_socket: JoinHandle<()> = tokio::spawn(podman_api_loop(podman.clone()));

    wait_for_podman_api(&podman).await;

    info!("spawning podman events watcher for first container death");
    let events_watcher: JoinHandle<Result<Option<ContainerName>>> = tokio::spawn({
        let podman = podman.clone();
        async move { podman.first_container_death().await }
    });

    info!("starting podman-compose up -d");
    let up_succeeded = match podman.compose_up_detached().await {
        Ok(()) => {
            info!("podman-compose up -d succeeded");
            true
        }
        Err(error) => {
            warn!(%error, "podman-compose up -d failed, skipping exit watch");
            false
        }
    };

    let prune: Option<JoinHandle<()>> = if up_succeeded {
        info!("spawning post-startup podman system prune");
        Some(tokio::spawn(post_startup_prune(podman.clone())))
    } else {
        None
    };

    if up_succeeded {
        info!("waiting for first container exit");
        match events_watcher.await {
            Ok(Ok(Some(name))) => {
                info!(container = %name, "container died, proceeding to teardown");
            }
            Ok(Ok(None)) => warn!("events watcher exited without observing a death"),
            Ok(Err(error)) => error!(%error, "podman events failed"),
            Err(error) => error!(%error, "events watcher task failed"),
        }
    } else {
        events_watcher.abort();
        let _ = events_watcher.await;
    }

    let final_teardown_delay = Duration::from_secs(60);
    info!(
        delay_secs = final_teardown_delay.as_secs(),
        "waiting before final teardown"
    );
    sleep(final_teardown_delay).await;

    info!("running final podman-compose down");
    match podman.compose_down().await {
        Ok(()) => info!("final down succeeded"),
        Err(error) => error!(%error, "final down failed"),
    }

    discovery.abort();
    let _ = discovery.await;
    api_socket.abort();
    let _ = api_socket.await;
    if let Some(prune) = prune {
        if !prune.is_finished() {
            info!("prune still running at shutdown, aborting");
            prune.abort();
        }
        match prune.await {
            Ok(()) => {}
            Err(error) if error.is_cancelled() => debug!("prune task cancelled"),
            Err(error) => error!(%error, "prune task join failed"),
        }
    }

    info!("service-runner exiting with code 1");
    std::process::exit(1);
}

async fn prepare_runtime_dir() -> Result<()> {
    let runtime_dir = "/run/user/1000";
    info!(path = runtime_dir, "mkdir XDG_RUNTIME_DIR");
    files::create_directory_and_parents(Path::new(runtime_dir))?;
    chown_path(runtime_dir).await?;

    let podman_dir = format!("{runtime_dir}/podman");
    info!(path = %podman_dir, "mkdir podman api socket dir");
    files::create_directory_and_parents(Path::new(&podman_dir))?;
    chown_path(&podman_dir).await
}

async fn chown_path(path: &str) -> Result<()> {
    info!(path, "chown svc:svc");
    run_streaming_checked("chown", &["svc:svc", path]).await
}

async fn post_startup_prune(podman: Podman) {
    log_prune_result("system", podman.prune_images_and_volumes().await);
    log_prune_result("builder", podman.prune_build_cache().await);
    log_prune_result("pod", podman.prune_pods().await);
}

fn log_prune_result(kind: &str, result: Result<()>) {
    match result {
        Ok(()) => info!(kind, "prune succeeded"),
        Err(error) => warn!(kind, %error, "prune failed"),
    }
}

async fn podman_api_loop(podman: Podman) {
    info!("podman system service supervisor started");
    loop {
        info!("spawning podman system service");
        match podman
            .serve_api(Path::new("/run/user/1000/podman/podman.sock"))
            .await
        {
            Ok(exit) => warn!(exit, "podman system service exited, restarting in 5s"),
            Err(error) => error!(%error, "spawn podman system service failed"),
        }
        sleep(Duration::from_secs(5)).await;
    }
}

async fn wait_for_podman_api(podman: &Podman) {
    let socket = Path::new("/run/user/1000/podman/podman.sock");
    info!(
        socket = %socket.display(),
        "waiting for podman API to respond"
    );
    loop {
        match podman.probe_api(socket).await {
            Ok(()) => {
                info!("podman API is responding");
                return;
            }
            Err(error @ Error::Spawn { .. }) => warn!(%error, "spawn podman version probe failed"),
            Err(error) => debug!(%error, "podman version probe failed"),
        }
        sleep(Duration::from_millis(500)).await;
    }
}

async fn discovery_loop(podman: Podman) {
    let mut tasks: HashMap<ContainerName, Tracked> = HashMap::new();
    let discovery_interval = Duration::from_secs(1);
    info!(
        interval_secs = discovery_interval.as_secs(),
        "container discovery loop started"
    );
    loop {
        match podman.running_containers().await {
            Ok(names) => {
                let live: HashSet<ContainerName> = names.iter().cloned().collect();
                debug!(count = live.len(), "discovery scan");
                for name in names {
                    if tasks.contains_key(&name) {
                        continue;
                    }
                    let tracked = match podman.healthcheck_interval(&name).await {
                        Ok(Some(interval)) => {
                            info!(
                                container = %name,
                                interval_secs = interval.as_secs_f64(),
                                "container discovered, spawning healthcheck loop"
                            );
                            Tracked::Active(tokio::spawn(healthcheck_loop_for(
                                podman.clone(),
                                name.clone(),
                                interval,
                            )))
                        }
                        Ok(None) => {
                            info!(container = %name, "container discovered, no healthcheck configured");
                            Tracked::NoHealthcheck
                        }
                        Err(error) => {
                            error!(container = %name, %error, "healthcheck interval unavailable, falling back to default interval");
                            Tracked::Active(tokio::spawn(healthcheck_loop_for(
                                podman.clone(),
                                name.clone(),
                                Duration::from_secs(30),
                            )))
                        }
                    };
                    tasks.insert(name, tracked);
                }
                let gone: Vec<ContainerName> = tasks
                    .keys()
                    .filter(|name| !live.contains(*name))
                    .cloned()
                    .collect();
                for name in gone {
                    info!(container = %name, "container disappeared, stopping healthcheck loop");
                    if let Some(Tracked::Active(handle)) = tasks.remove(&name) {
                        handle.abort();
                    }
                }
            }
            Err(error) => error!(%error, "podman ps failed"),
        }
        sleep(discovery_interval).await;
    }
}

async fn healthcheck_loop_for(podman: Podman, name: ContainerName, interval: Duration) {
    info!(container = %name, interval_secs = interval.as_secs_f64(), "healthcheck loop started");
    let mut last: Option<String> = None;
    loop {
        let exit = match podman.run_healthcheck(&name).await {
            Ok(()) => "0".to_string(),
            Err(Error::Failed { code, .. }) => code,
            Err(error) => {
                error!(container = %name, %error, "spawn podman healthcheck run failed");
                sleep(interval).await;
                continue;
            }
        };
        match &last {
            None => info!(container = %name, %exit, "healthcheck initial state"),
            Some(previous) if *previous != exit => info!(
                container = %name,
                previous_exit = %previous,
                %exit,
                "healthcheck state changed"
            ),
            Some(_) => {}
        }
        last = Some(exit);
        sleep(interval).await;
    }
}
