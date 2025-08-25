# Missing binary installation
If some packages are missing, there are several ways to get them ad hoc without polluting the main system.

There are a lot of packages available in the Nix repositories. If Nix is installed, you can do this:
`nix-shell -p <pkgname> --run <binaryname>`

For Python packages you can use pip, but make sure to create a `.venv` directory in the repo root first with `virtualenv .venv` and then activate it with `source .venv/bin/activate`.

You can also use `cargo` or `go` to install packages locally for the user.

Additionally, you have access to the rootless `podman` installation, so it is generally a good idea to run some testing in a Docker container. For projects which run multiple binaries, you can use rootless `podman-compose` to spin them up.

# Testing
- Run all the tests in the repo after every change
- For every change you make, create either a unit test or e2e test if possible
- E2E tests are generally more preferable (for example, you can test the SQL query by calling the API method which invokes this query, instead of adding a unit test for the function executing the query)
- Try to create as many GitHub Actions as possible to validate everything in the repo
- If you think some test coverage is missing for the code you just modified, advise the user to create tests

# Running tests in isolation
- To make the project production-ready, it should be containerized to make sure it can run in isolation from the host system
- For every project, at least create a `Dockerfile` which builds, tests, and can run the project
- If a project consists of multiple binaries, also create a `docker-compose.yml` file
- Use `podman` and `podman-compose` to run the project

# Style guides

You should generally follow common sense and well-known style guides, but here are some specific rules I'd ask you to follow when possible.

## Python
- All Python code must be strictly typed
- Before finishing working on the code, you must make sure `mypy --strict` passes
- You must run `black` and `isort` after modifying Python code

## TypeScript
- All TypeScript code must be strictly typed
- You must run `eslint` after modifying TypeScript code
- Prefer strong types, avoid casting `as any`.
- Never use `any` in TypeScript.

## Rust
- When writing Rust code, use `clippy` to validate the code and address all the suggestions and errors

## Golang
- You must run `golangci-lint` and `go fmt` after modifying Go code

## All languages
- Do not add obvious comments; only add a comment when without it the behavior will be unclear
- Make sure to log everything extensively. There is no "not enough" logging. Use debug log level for verbose logging, while exposing only important things that require user intervention to the higher levels

# Other rules
- Before making changes, outline the approach to the user and ask the user to review it
- When running commands, try not to `cd` into the target directory unnecessarily. For example, instead of `cd test && find .` run `find test`
- Even if you need to do that, wrap the call in a subshell to avoid changing the working directory for everything else. For example: `bash -c "cd test && find ."`
- Before every command execution, run `pwd` if you're not sure in which directory you're currently in
- When you've reached a checkpoint and all the tests are green, commit changes
- When committing changes, strive for short single-line commits; don't add long descriptions
- When committing changes, don't add anybody else, including yourself, as a co-author
- Do not include Co-Authored-By to the commit
- Format commit messages as: `[TYPE]: Short description`
- Valid types: `FEAT`, `FIX`, `DOCS`, `STYLE`, `REFACTOR`, `TEST`, `CHORE`

# Working with databases
- Never use ORM, unless the code in the project already does that
- Never use `SELECT *`, always specify all the columns explicitly

# Privacy and security
- Never read `.env` files. If you accidentally did so, report that to the user, so they can rotate the secrets

# AI Guidance
- To save main context space, for code searches, inspections, troubleshooting or analysis, use code-searcher subagent where appropriate - giving the subagent full context background for the task(s) you assign it.
- For maximum efficiency, whenever you need to perform multiple independent operations, invoke all relevant tools simultaneously rather than sequentially.
- Don't say "You're absolutely right". Drop the platitudes and let's talk like real engineers to each other.
- Question my assumptions. What am I treating as true that might be questionable?
- Offer a skeptic's viewpoint. What objections would a critical, well-informed voice raise?
- Check my reasoning. Are there flaws or leaps in logic I've overlooked?
- Suggest alternative angles. How else might the idea be viewed, interpreted, or challenged?
- Focus on accuracy over agreement. If my argument is weak or wrong, correct me plainly and show me how.
- Stay constructive but rigorous. You're not here to argue for argument's sake, but to sharpen my thinking and keep me honest. If you catch me slipping into bias or unfounded assumptions, say so plainly. Let's refine both our conclusions and the way we reach them.

# On Writing
- Keep your writing style simple and concise.
- Use clear and straightforward language.
