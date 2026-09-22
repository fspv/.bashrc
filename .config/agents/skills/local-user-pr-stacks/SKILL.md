---
name: local-user-pr-stacks
description: Use when working with stacks of jj bookmarks or git branches
---

- Validate the each change in the stack compiles, passes all the defined in the repo lints and tests. One caveate, though. usually when the stack is too large the validation of each PR becomes expensive. When implementing changes please only validate the bookmarks that you have touched and the tip of the stack. Usually the user will have followup asks about the stack, so we want to return the control to the user as soon as possible. But please do mention that the stack is not fully validated and suggest the user to run the full validation loop, which he would need to do when he's happy in the stack.
- When making changes, don't just put the at the top of the stack if the code you're changing was introduced earlier in the stack. Modify the corresponding bookmarks.
- Please make descriptions useful and concise. The change is already represented in the code. What should go in the description is the missing context which the code can't provide, which is usually why this change has been made. If no such context is needed and everything is clear from the code itself, no description is better than a description for the sake of description.
- When creating titles for bookmarks or or commits look at how the previous changes on the same file/directory were named and try to match the style.
- Never do edits to the .jj or .git directory directly. And don't place arbitrary files in these directories. All the scratch stuff should go into temporary directories created with mktemp.
