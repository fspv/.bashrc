mod agent;
mod cache;
mod rpc;

use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::mpsc::{channel, Sender};
use std::sync::{Arc, Mutex, PoisonError};
use std::thread;

use clap::Parser;
use common::Result;
use serde_json::{json, Value};

#[derive(Parser)]
#[command(
    name = "comment-lsp",
    about = "LSP server that annotates code with agent-written comments shown as inlay hints"
)]
struct Cli {
    /// Shell command template used to run the agent; `%s` is replaced with the prompt.
    #[arg(long, env = "COMMENT_LSP_AGENT_CMD")]
    agent_cmd: String,
    /// Directory for cached comments (default: $XDG_CACHE_HOME/comment-lsp).
    #[arg(long)]
    cache_dir: Option<PathBuf>,
}

struct Server {
    agent_cmd: String,
    cache_root: PathBuf,
    project_root: PathBuf,
    documents: HashMap<String, String>,
    in_flight: Arc<Mutex<HashSet<PathBuf>>>,
    outgoing: Sender<Value>,
    next_request_id: AtomicI64,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let cache_root = match cli.cache_dir {
        Some(cache_dir) => cache_dir,
        None => cache::default_root()?,
    };
    let (outgoing, outgoing_receiver) = channel::<Value>();
    thread::spawn(move || {
        let mut writer = std::io::stdout().lock();
        while let Ok(message) = outgoing_receiver.recv() {
            if rpc::write_message(&mut writer, &message).is_err() {
                return;
            }
        }
    });
    let mut server = Server {
        agent_cmd: cli.agent_cmd,
        cache_root,
        project_root: std::env::current_dir()?,
        documents: HashMap::new(),
        in_flight: Arc::new(Mutex::new(HashSet::new())),
        outgoing,
        next_request_id: AtomicI64::new(1),
    };
    let mut reader = std::io::stdin().lock();
    while let Some(message) = rpc::read_message(&mut reader)? {
        if server.handle(&message) == Handled::Exit {
            break;
        }
    }
    Ok(())
}

#[derive(PartialEq, Eq)]
enum Handled {
    Continue,
    Exit,
}

impl Server {
    fn handle(&mut self, message: &Value) -> Handled {
        let Some(method) = message.get("method").and_then(Value::as_str) else {
            return Handled::Continue; // A response to our refresh request.
        };
        let id = message.get("id");
        let params = message.get("params").cloned().unwrap_or(Value::Null);
        match method {
            "initialize" => self.initialize(id, &params),
            "textDocument/didOpen" => self.did_open(&params),
            "textDocument/didChange" => self.did_change(&params),
            "textDocument/inlayHint" => self.inlay_hint(id, &params),
            "workspace/executeCommand" => self.execute_command(id, &params),
            "shutdown" => self.respond(id, &Value::Null),
            "exit" => return Handled::Exit,
            _ => {
                if id.is_some() {
                    self.respond_error(id, -32601, &format!("method not found: {method}"));
                }
            }
        }
        Handled::Continue
    }

    fn initialize(&mut self, id: Option<&Value>, params: &Value) {
        if let Some(root_path) = params
            .get("rootUri")
            .and_then(Value::as_str)
            .and_then(uri_to_path)
        {
            self.project_root = root_path;
        }
        self.respond(
            id,
            &json!({
                "capabilities": {
                    "textDocumentSync": 1,
                    "inlayHintProvider": true,
                    "executeCommandProvider": {
                        "commands": ["commentLsp.generate", "commentLsp.regenerate"],
                    },
                },
                "serverInfo": {"name": "comment-lsp"},
            }),
        );
    }

    fn did_open(&mut self, params: &Value) {
        let Some(uri) = params.pointer("/textDocument/uri").and_then(Value::as_str) else {
            return;
        };
        let Some(text) = params.pointer("/textDocument/text").and_then(Value::as_str) else {
            return;
        };
        self.documents.insert(uri.to_string(), text.to_string());
    }

    fn did_change(&mut self, params: &Value) {
        let Some(uri) = params.pointer("/textDocument/uri").and_then(Value::as_str) else {
            return;
        };
        // Sync kind is Full, so the last change carries the whole document.
        let Some(text) = params.pointer("/contentChanges/0/text").and_then(Value::as_str) else {
            return;
        };
        self.documents.insert(uri.to_string(), text.to_string());
    }

    fn inlay_hint(&self, id: Option<&Value>, params: &Value) {
        let Some(uri) = params.pointer("/textDocument/uri").and_then(Value::as_str) else {
            return self.respond(id, &Value::Null);
        };
        let (Some(text), Some(relative_path)) =
            (self.documents.get(uri), self.relative_path(uri))
        else {
            return self.respond(id, &Value::Null);
        };
        let hash = cache::content_hash(text);
        let cache_path = cache::comment_file(&self.cache_root, &relative_path, &hash);
        let Some(comments) = cache::load(&cache_path) else {
            return self.respond(id, &Value::Null);
        };
        let first_line = params
            .pointer("/range/start/line")
            .and_then(Value::as_u64)
            .unwrap_or(0);
        let last_line = params
            .pointer("/range/end/line")
            .and_then(Value::as_u64)
            .unwrap_or(u64::MAX);
        let lines: Vec<&str> = text.lines().collect();
        let hints: Vec<Value> = comments
            .iter()
            .filter_map(|comment| {
                let line_index = comment.line.checked_sub(1)?;
                let line_number = u64::try_from(line_index).ok()?;
                if line_number < first_line || line_number > last_line {
                    return None;
                }
                let line_text = lines.get(line_index)?;
                Some(json!({
                    "position": {
                        "line": line_number,
                        "character": line_text.encode_utf16().count(),
                    },
                    "label": format!("// {}", comment.comment),
                    "paddingLeft": true,
                }))
            })
            .collect();
        self.respond(id, &Value::Array(hints));
    }

    /// Generation runs only on client demand (for buffers the user can see):
    /// `generate` respects the cache, `regenerate` drops it first.
    fn execute_command(&self, id: Option<&Value>, params: &Value) {
        let command = params.get("command").and_then(Value::as_str);
        if command != Some("commentLsp.generate") && command != Some("commentLsp.regenerate") {
            return self.respond_error(
                id,
                -32602,
                &format!("unknown command: {command:?}"),
            );
        }
        if let Some(uri) = params.pointer("/arguments/0").and_then(Value::as_str) {
            if command == Some("commentLsp.regenerate")
                && let Some(relative_path) = self.relative_path(uri)
            {
                let _ = std::fs::remove_dir_all(self.cache_root.join(relative_path));
            }
            self.schedule_generation(uri);
        }
        self.respond(id, &Value::Null);
    }

    fn schedule_generation(&self, uri: &str) {
        let (Some(text), Some(relative_path)) =
            (self.documents.get(uri), self.relative_path(uri))
        else {
            return;
        };
        let hash = cache::content_hash(text);
        let cache_path = cache::comment_file(&self.cache_root, &relative_path, &hash);
        if cache_path.exists() {
            return;
        }
        {
            let mut in_flight = self
                .in_flight
                .lock()
                .unwrap_or_else(PoisonError::into_inner);
            if !in_flight.insert(cache_path.clone()) {
                return;
            }
        }
        let agent_cmd = self.agent_cmd.clone();
        let relative_path_text = relative_path.to_string_lossy().into_owned();
        let text = text.clone();
        let in_flight = Arc::clone(&self.in_flight);
        let outgoing = self.outgoing.clone();
        let refresh_id = self.next_request_id.fetch_add(1, Ordering::Relaxed);
        thread::spawn(move || {
            let generated = agent::generate_comments(&agent_cmd, &relative_path_text, &text)
                .and_then(|comments| cache::store(&cache_path, &comments));
            in_flight
                .lock()
                .unwrap_or_else(PoisonError::into_inner)
                .remove(&cache_path);
            let message = match generated {
                Ok(()) => json!({
                    "jsonrpc": "2.0",
                    "id": refresh_id,
                    "method": "workspace/inlayHint/refresh",
                    "params": null,
                }),
                Err(error) => json!({
                    "jsonrpc": "2.0",
                    "method": "window/logMessage",
                    "params": {"type": 1, "message": format!("comment-lsp agent failed: {error}")},
                }),
            };
            let _ = outgoing.send(message);
        });
    }

    fn relative_path(&self, uri: &str) -> Option<PathBuf> {
        let path = uri_to_path(uri)?;
        path.strip_prefix(&self.project_root)
            .ok()
            .map(Path::to_path_buf)
    }

    fn respond(&self, id: Option<&Value>, result: &Value) {
        let Some(id) = id else { return };
        let _ = self
            .outgoing
            .send(json!({"jsonrpc": "2.0", "id": id, "result": result}));
    }

    fn respond_error(&self, id: Option<&Value>, code: i64, message: &str) {
        let Some(id) = id else { return };
        let _ = self.outgoing.send(json!({
            "jsonrpc": "2.0",
            "id": id,
            "error": {"code": code, "message": message},
        }));
    }
}

fn uri_to_path(uri: &str) -> Option<PathBuf> {
    Some(PathBuf::from(uri.strip_prefix("file://")?))
}
