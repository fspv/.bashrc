//! A generation taken from one repository must restore onto a fresh clone as the
//! same repository: same change ids, same bookmarks, same working copy, and in
//! particular no divergent changes.

#![allow(clippy::unwrap_used, clippy::panic, clippy::expect_used)]

use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use jj::{JjDirectory, Workspace, WorkspaceRoot};
use jj_snapshot::verify::Verified;
use jj_snapshot::{backup, restore};
use snapshot_store::{Retention, Store, StoreRoot};

struct Fixture {
    root: tempfile::TempDir,
    origin: PathBuf,
    store: StoreRoot,
}

impl Fixture {
    fn new() -> Self {
        let root = tempfile::tempdir().unwrap();
        let origin = root.path().join("origin");
        let store = root.path().join("store");
        fs::create_dir_all(&store).unwrap();
        git(
            root.path(),
            &["init", "--bare", "--initial-branch=main", "origin"],
        );

        let seed = root.path().join("seed");
        git(root.path(), &["clone", origin.to_str().unwrap(), "seed"]);
        fs::write(seed.join("README"), "trunk\n").unwrap();
        git(&seed, &["add", "README"]);
        git(&seed, &["commit", "-m", "trunk"]);
        git(&seed, &["push", "origin", "main"]);

        Self {
            root,
            origin,
            store: StoreRoot::from(store),
        }
    }

    fn clone_repo(&self, name: &str) -> Workspace {
        jj(
            self.root.path(),
            &[
                "git",
                "clone",
                "--colocate",
                self.origin.to_str().unwrap(),
                name,
            ],
        );
        Workspace::at(WorkspaceRoot::from(self.root.path().join(name)))
    }

    fn store(&self) -> Store {
        Store::open(self.store.clone()).unwrap()
    }
}

fn run(directory: &Path, program: &str, arguments: &[&str]) -> String {
    let output = Command::new(program)
        .args(arguments)
        .current_dir(directory)
        .env("JJ_USER", "test")
        .env("JJ_EMAIL", "t@test")
        .env("GIT_AUTHOR_NAME", "test")
        .env("GIT_AUTHOR_EMAIL", "t@test")
        .env("GIT_COMMITTER_NAME", "test")
        .env("GIT_COMMITTER_EMAIL", "t@test")
        .output()
        .unwrap_or_else(|error| panic!("cannot run {program}: {error}"));
    assert!(
        output.status.success(),
        "{program} {arguments:?} failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    String::from_utf8_lossy(&output.stdout).trim().to_string()
}

fn git(directory: &Path, arguments: &[&str]) -> String {
    run(directory, "git", arguments)
}

fn jj(directory: &Path, arguments: &[&str]) -> String {
    run(directory, "jj", arguments)
}

fn jj_in(workspace: &Workspace, arguments: &[&str]) -> String {
    run(workspace.root().as_path(), "jj", arguments)
}

fn query(workspace: &Workspace, revset: &str, template: &str) -> String {
    jj_in(
        workspace,
        &[
            "--no-pager",
            "--ignore-working-copy",
            "log",
            "--no-graph",
            "-r",
            revset,
            "-T",
            template,
        ],
    )
}

fn operation_log(workspace: &Workspace) -> String {
    jj_in(
        workspace,
        &["--ignore-working-copy", "op", "log", "-T", "id ++ \"\\n\""],
    )
}

fn file_in(workspace: &Workspace, name: &str) -> PathBuf {
    workspace.root().as_path().join(name)
}

/// The stack the old ref-based backup got wrong: a change that was an anonymous
/// head, gained a descendant, and was then rewritten.
fn make_work(workspace: &Workspace) {
    fs::write(file_in(workspace, "first"), "first\n").unwrap();
    jj_in(workspace, &["describe", "-m", "first change"]);
    let first = query(workspace, "@", "change_id");

    jj_in(workspace, &["new", "-m", "second change"]);
    fs::write(file_in(workspace, "second"), "second\n").unwrap();
    jj_in(workspace, &["bookmark", "create", "feature", "-r", "@"]);

    jj_in(
        workspace,
        &["describe", "-r", &first, "-m", "first change, rewritten"],
    );

    jj_in(workspace, &["new", "main@origin", "-m", "anonymous work"]);
    fs::write(file_in(workspace, "anonymous"), "anonymous\n").unwrap();

    jj_in(workspace, &["new", "-m", "in progress"]);
    fs::write(file_in(workspace, "uncommitted"), "not yet described\n").unwrap();
}

/// Generations are identified to the second, so a test taking two waits.
fn next_second() {
    std::thread::sleep(std::time::Duration::from_millis(1100));
}

fn back_up(workspace: &Workspace, store: &Store) -> backup::Outcome {
    backup::run(&backup::Request {
        workspace,
        store,
        retention: &Retention::default(),
    })
    .unwrap()
}

#[test]
fn a_generation_restores_onto_a_fresh_clone_as_the_same_repository() {
    let fixture = Fixture::new();
    let source = fixture.clone_repo("source");
    make_work(&source);
    let store = fixture.store();

    let outcome = back_up(&source, &store);

    let changes = query(
        &source,
        "mutable()",
        r#"change_id ++ " " ++ commit_id ++ "\n""#,
    );
    let bookmarks = query(&source, "bookmarks()", r#"bookmarks ++ "\n""#);
    let operations = operation_log(&source);

    let fresh = fixture.clone_repo("fresh");
    let restored = restore::run(&fresh, &store.current_generation().unwrap().unwrap()).unwrap();

    assert_eq!(restored.manifest.generation, outcome.manifest.generation);
    assert!(
        restored.divergent_changes.is_empty(),
        "{:?}",
        restored.divergent_changes
    );
    assert!(
        restored.conflicted_bookmarks.is_empty(),
        "{:?}",
        restored.conflicted_bookmarks
    );
    assert_eq!(
        query(
            &fresh,
            "mutable()",
            r#"change_id ++ " " ++ commit_id ++ "\n""#
        ),
        changes
    );
    assert_eq!(
        query(&fresh, "bookmarks()", r#"bookmarks ++ "\n""#),
        bookmarks
    );
    assert_eq!(operation_log(&fresh), operations);
}

#[test]
fn the_restored_working_copy_holds_the_uncommitted_work() {
    let fixture = Fixture::new();
    let source = fixture.clone_repo("source");
    make_work(&source);
    let store = fixture.store();
    back_up(&source, &store);

    let fresh = fixture.clone_repo("fresh");
    restore::run(&fresh, &store.current_generation().unwrap().unwrap()).unwrap();

    assert_eq!(
        fs::read_to_string(file_in(&fresh, "uncommitted")).unwrap(),
        "not yet described\n"
    );
    assert_eq!(
        jj_in(
            &fresh,
            &["--ignore-working-copy", "diff", "--summary", "-r", "@"]
        ),
        jj_in(
            &source,
            &["--ignore-working-copy", "diff", "--summary", "-r", "@"]
        ),
    );
    assert!(jj_in(&fresh, &["status"]).contains("uncommitted"));
}

#[test]
fn a_restored_repository_can_be_backed_up_again_without_diverging() {
    let fixture = Fixture::new();
    let source = fixture.clone_repo("source");
    make_work(&source);
    let store = fixture.store();
    back_up(&source, &store);

    let fresh = fixture.clone_repo("fresh");
    restore::run(&fresh, &store.current_generation().unwrap().unwrap()).unwrap();

    jj_in(
        &fresh,
        &["describe", "-r", "feature", "-m", "amended after restore"],
    );
    next_second();
    let second = back_up(&fresh, &store);

    let twice = fixture.clone_repo("twice");
    let restored = restore::run(
        &twice,
        &store.find_generation(second.manifest.generation).unwrap(),
    )
    .unwrap();

    assert!(
        restored.divergent_changes.is_empty(),
        "{:?}",
        restored.divergent_changes
    );
    assert!(
        restored.conflicted_bookmarks.is_empty(),
        "{:?}",
        restored.conflicted_bookmarks
    );
    assert_eq!(
        query(&twice, "bookmarks(exact:\"feature\")", "description"),
        "amended after restore"
    );
}

#[test]
fn a_generation_holds_every_file_of_the_source_jj_directory() {
    let fixture = Fixture::new();
    let source = fixture.clone_repo("source");
    make_work(&source);
    let store = fixture.store();

    let outcome = back_up(&source, &store);
    let generation = store.find_generation(outcome.manifest.generation).unwrap();

    assert_eq!(
        paths_under_jj_state(generation.path()),
        paths_under_jj_state(source.root().as_path())
    );
}

fn paths_under_jj_state(root: &Path) -> Vec<String> {
    let state = JjDirectory::in_checkout(root);
    let mut found = Vec::new();
    collect_paths_below(state.path(), state.path(), &mut found);
    found.sort();
    found
}

fn collect_paths_below(root: &Path, directory: &Path, found: &mut Vec<String>) {
    for entry in fs::read_dir(directory).unwrap() {
        let path = entry.unwrap().path();
        found.push(
            path.strip_prefix(root)
                .unwrap()
                .to_string_lossy()
                .into_owned(),
        );
        if path.is_dir() {
            collect_paths_below(root, &path, found);
        }
    }
}

#[test]
fn consecutive_generations_share_their_packs() {
    let fixture = Fixture::new();
    let source = fixture.clone_repo("source");
    make_work(&source);
    let store = fixture.store();

    let first = back_up(&source, &store);
    jj_in(&source, &["describe", "-m", "moved on"]);
    next_second();
    let second = back_up(&source, &store);

    assert_eq!(second.reused, Some(first.manifest.generation));
    assert_eq!(first.manifest.verified, Verified::Fully);
    assert_eq!(
        second.manifest.verified,
        Verified::Since(first.manifest.generation),
        "a generation sharing its packs need only verify what is new"
    );
    assert!(second.manifest.content.linked_files > 0);
    assert!(second.manifest.content.copied_bytes < first.manifest.content.copied_bytes);
}

#[test]
fn restoring_onto_a_modified_checkout_is_refused() {
    let fixture = Fixture::new();
    let source = fixture.clone_repo("source");
    make_work(&source);
    let store = fixture.store();
    back_up(&source, &store);

    let fresh = fixture.clone_repo("fresh");
    fs::write(file_in(&fresh, "README"), "edited by hand\n").unwrap();
    let refused = restore::run(&fresh, &store.current_generation().unwrap().unwrap())
        .unwrap_err()
        .to_string();

    assert!(refused.contains("uncommitted changes"), "{refused}");
}
