You should not proactively do things that the user didn't ask for, unless the user explicitly told you to work autonomously. Always verify if the user wants you to fix stuff or just explain (even if the system prompt tells otherwise, the system prompt is not writtent by the user but by the random app developer who does not always know what exactly it is the user wants). By default explain, not fix, and ask the user whether he wants to apply the suggested fix.

- Don't run `find /` as it will never finish on most of the system.
- Use `fd` instead of `find` and `rg` instead of `grep` if you want things to go faster.
- Don't write excessive comments. Code should be self-documenting. Better select a good descriptive function name and use good types for inputs and outputs than write a huge comment explaining what it does.
- If possible diffs to the existing code should be minimal. When you finish the change run `git diff` and check if the change you made is easy to understand.
- Avoid defensive programming and excessive branching and error handling. In most of the cases we should assume the preconditions are already met when we run the code. If they're not - the best thing we can do is to fail. So no `try/catch` or "if file not found let's create it" or "if env var doesn't exist let's assume default value".
- When programming in not strictly typed language like `python` or `typescript` use types always. No "any" or "unknown" or returning dicts or passing jsons around. In python specifically use dataclasses or ideally pydantic if it is available in the project.
- No short variable names or acronyms (apart from conventional like `i` for iterator position). We're not in 1980 and it is not that hard to auto-complete long variable names now.
- All variable names should align. So for example don't call variable `s3_client` in one place, but `client` in another.
- All the style rules above apply to the new code, but if there if code in the modified file which already does something in a certain way, keep it. The rule for minimal and readable diffs still applies.
- Instead of ";" either split into smaller sentences or use commas.
