use std::fmt::Write as _;

use common::{run_output, Error, Result};

use crate::cache::Comment;

/// Ask the agent for comments on `text`. The command template is a shell
/// snippet where `%s` is replaced with the (double-quote escaped) prompt.
pub fn generate_comments(
    agent_cmd_template: &str,
    relative_path: &str,
    text: &str,
) -> Result<Vec<Comment>> {
    let prompt = build_prompt(relative_path, text);
    let command = agent_cmd_template.replace("%s", &escape_for_double_quotes(&prompt));
    let output = run_output("sh", &["-c", &command])?;
    parse_comments(&output)
}

fn build_prompt(relative_path: &str, text: &str) -> String {
    let mut numbered = String::new();
    for (index, line) in text.lines().enumerate() {
        let _ = writeln!(numbered, "{}: {line}", index + 1);
    }
    format!(
        "You are annotating source code with explanatory comments shown as an editor overlay.\n\
         File: {relative_path}\n\
         Below is the file content, each line prefixed with its 1-based line number.\n\
         Reply with ONLY a JSON array (no markdown fences, no prose) of objects like:\n\
         [{{\"line\": 3, \"comment\": \"walks the tree depth-first collecting leaf names\"}}]\n\
         Rules:\n\
         - Comment EVERY function, method, and type definition: one sentence saying what\n\
           it does and why it exists, placed on the line where its name is declared.\n\
         - Inside bodies, also comment the non-obvious parts: tricky logic, invariants,\n\
           concurrency, error handling, side effects.\n\
         - Keep each comment under 100 characters.\n\
         - Do not restate what the code literally says.\n\
         \n\
         {numbered}"
    )
}

fn escape_for_double_quotes(text: &str) -> String {
    let mut escaped = String::with_capacity(text.len());
    for character in text.chars() {
        if matches!(character, '\\' | '"' | '$' | '`') {
            escaped.push('\\');
        }
        escaped.push(character);
    }
    escaped
}

/// Extract the outermost JSON array from the agent output, tolerating
/// surrounding prose or markdown fences.
fn parse_comments(output: &str) -> Result<Vec<Comment>> {
    let start = output
        .find('[')
        .ok_or_else(|| Error::Parse(format!("no JSON array in agent output: {output}")))?;
    let end = output
        .rfind(']')
        .filter(|&end| end > start)
        .ok_or_else(|| Error::Parse(format!("unterminated JSON array in agent output: {output}")))?;
    serde_json::from_str(&output[start..=end]).map_err(|source| Error::Parse(source.to_string()))
}
