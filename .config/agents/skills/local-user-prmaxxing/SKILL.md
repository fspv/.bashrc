---
name: local-user-prmaxxing
description: Use when the user asks to split a git branch or jj bookmark into multiple branches/bookmarks
---

We want to keep PRs as small as possible. The term PR is used interchangeably with git branches and jj bookmarks, when I say PR, it mean local change, not a remote PR.

One atomic change per bookmark. Every commit must compile and pass tests on its own. No broken intermediate states.

When I say minimal, I mean it. We should narrow down each change to one small thing, ideally a few lines of code, which implements a specific feature/behaviour/test/whatever. If the change can be split into multiple PRs we should absolutely do that.

Examples:

- When we create a new app, we can split scaffolding such as create an empty create or package into a separate PR.
- When we change some behaviour and there is no test for it, we can add test first and leave a TODO to fix this behaviour later and then implement a fix and remove a TODO in the next PR.
- When we are implementing new functionality we can add specific journeys separately. If they're not used yet, we can mark them explicitly as unused so the linter doesn't complain. In rust we can do with with `#[expect(dead_code)]` or `#[cfg_attr(not(test), expect(dead_code))]` for tests.
- When the functionality we're implementing is complex, we can first implement a happy path, leave TODOs about the edge cases and then add PRs for them, one per edge case.

On the validation, usually when the stack is too large the validation of each PR becomes expensive. When implementing changes please only validate the bookmarks that you have touched and the tip of the stack. Usually the user will have followup asks about the stack, so we want to return the control to the user as soon as possible. But please do mention that the stack is not fully validated and suggest the user to run the full validation loop, which he would need to do when he's happy in the stack.
