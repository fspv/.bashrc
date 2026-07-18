use std::io::{BufRead, Write};

use common::{Error, Result};
use serde_json::Value;

/// Read one `Content-Length`-framed JSON-RPC message. `None` means EOF.
pub fn read_message(reader: &mut impl BufRead) -> Result<Option<Value>> {
    let mut content_length = None;
    loop {
        let mut line = String::new();
        if reader.read_line(&mut line)? == 0 {
            return Ok(None);
        }
        let line = line.trim_end();
        if line.is_empty() {
            break;
        }
        if let Some(raw_length) = line.strip_prefix("Content-Length:") {
            let parsed = raw_length
                .trim()
                .parse()
                .map_err(|_| Error::Parse(format!("bad Content-Length: {raw_length}")))?;
            content_length = Some(parsed);
        }
    }
    let length = content_length.ok_or_else(|| Error::Parse("missing Content-Length".into()))?;
    let mut body = vec![0; length];
    reader.read_exact(&mut body)?;
    let message = serde_json::from_slice(&body).map_err(|source| Error::Parse(source.to_string()))?;
    Ok(Some(message))
}

pub fn write_message(writer: &mut impl Write, message: &Value) -> Result<()> {
    let body = message.to_string();
    write!(writer, "Content-Length: {}\r\n\r\n{body}", body.len())?;
    writer.flush()?;
    Ok(())
}
