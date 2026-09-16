# Testing

- Do not create new test suites. Only extend existing test suites.
- Do not write Bash or other shell scripts in tests, including generated fixture scripts. A single simple shell-command invocation is allowed. Pipes, conditionals, loops, command chaining, and background orchestration are not allowed.
