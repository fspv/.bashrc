# Flake dependency audit

Date: 2026-09-23. Scope: everything pulled in via `flake.nix`. Neovim plugins installed via lazy are out of scope.

## Bottom line

No malicious intent found. No crypto miners, no SSH/credential theft, no exfiltration, no persistence mechanisms, no obfuscated payloads in any dependency.

The finding worth your attention is structural rather than a payload: the ten third-party plugin inputs are not pinned, so this audit is a snapshot that does not carry forward.

## What could not be run

`nix develop` was not executed. Nix is not installed in this container, and the installer was blocked by the sandbox as external code execution. The audit was done against the dependency sources directly, cloned from their upstreams, rather than against a realised dev shell.

## Unpinned plugin inputs

`flake.lock` is intentionally empty, and `.github/workflows/flake-lock.yml` actively enforces that with `git show :flake.lock | jq --exit-status '.nodes == {"root":{}}'`. The header comment in `flake.nix` documents the reason: avoiding lock merge conflicts across machines.

The security consequence is that the ten `flake = false` inputs carry no rev and no hash. Every fresh evaluation resolves each one to whatever its default branch HEAD is at that moment. Four of them execute in every interactive shell: `fzf-tab`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, and `powerlevel10k` as the theme. `zsh-syntax-highlighting` in particular wraps the command line on every keystroke.

If any of those upstreams or maintainer accounts is compromised, the next `nix develop` pulls it into your shell with no diff to review and nothing in git to catch it.

`jj-with-lfs-support` is the counterexample and the pattern that would fix this: it is pinned with `&rev=0d5fca956272813aaa904cf124b316a64b5d74da`.

This is a tradeoff you chose deliberately, and it is not a mistake to point out, but the cost is that today's clean result expires the moment any of those branches moves.

## What was verified today

All ten repos are the canonical upstreams, with no typosquats: `zsh-users/zsh-autosuggestions`, `zsh-users/zsh-syntax-highlighting`, `romkatv/powerlevel10k`, `jeffreytse/zsh-vi-mode`, `wfxr/forgit`, `MichaelAquilina/zsh-you-should-use`, `Aloxaf/fzf-tab`, `b0o/tmux-autoreload`, `marcuscaisey/please.nvim`, `skywind3000/vim-quickui`.

Commit histories are maintainer-driven and unremarkable. The one thing that looked alarming at first glance, `zsh-syntax-highlighting` HEAD authored six days ago by an unfamiliar handle, resolves to two genuine documentation-only commits touching `INSTALL.md` and `tests/README.md` with no code change.

`zsh-autosuggestions` passed the strongest check available: the shipped `zsh-autosuggestions.zsh` was rebuilt from `src/` per the Makefile recipe and is byte-identical, so the classic backdoor-only-in-the-built-artifact trick is not present.

The only read of a sensitive file anywhere in the set is `$HISTFILE` in `you-should-use.plugin.zsh:32`, inside `check_alias_usage`, which is a manually invoked reporting command that prints a local count table. It is not hooked into `preexec` or `precmd`, and that plugin is not enabled here anyway.

The `zsh-vi-mode.zsh` file reads as binary to `file`, which is benign: fourteen non-printable bytes, all keybinding literals (DEL, ESC, Ctrl-A) plus one emoji in the description string.

`apps/` is clean: 135 crates, all from crates.io, zero git sources, and `deny.toml` sets `unknown-registry = "deny"` and `unknown-git = "deny"`.

## Hardening notes

### gitstatus download, already neutralised

powerlevel10k's bundled gitstatus installer fetches the daemon with `curl -kfsSL`, where `-k` disables TLS certificate verification. Separately, `gitstatus/install:333` reads `[ "$1" = 1 -a -z "$hash" -o "$hash" = "$sha256" ]`, which parses as `($1 == 1 && hash == "") || (hash == sha256)`, so on a machine with no `shasum`, `sha256sum`, or `sha256` on PATH the GitHub tarball is accepted with no integrity check at all. Unverified TLS plus no checksum means an active MITM could plant a binary that runs on every shell start.

This is long-standing upstream behaviour, not tampering, and your flake already closes it. `flake.nix:573` exports `GITSTATUS_DAEMON=${stablePkgs.gitstatus}/bin/gitstatusd`, a `/nix/store` path that is absolute and outside `${XDG_CACHE_HOME:-~/.cache}/gitstatus`. Both conditions matter: the absolute path short-circuits `gitstatus/install:156-168` before any download code is reached, and being outside the cache directory defeats the forced-redownload path gated at `gitstatus.plugin.zsh:450-451`.

Worth knowing that line is load-bearing for security, not just a build-time convenience.

### public_ip is off

The `public_ip` prompt segment would fetch `https://v4.ident.me/`. It is commented out at `.config/zsh/p10k.zsh:114`, so no such call happens.

### pleasew, inert here

`please.nvim` ships `pleasew`, which downloads the please binary from `https://get.please.build` with no checksum or signature and pipes it straight into `tar -xJp`. Nothing under `lua/` or `plugin/` references it, so using the plugin never triggers it. It only runs when building that repo itself.

### vim-quickui temp script, local only

`autoload/quickui/core.vim:836-841` writes a shell script to a fixed, predictable path and chmods it `rwxrwxrws`. On a shared multi-user machine another local user could overwrite it between write and execution. On a single-user machine this is a non-issue.

## Dead weight worth dropping

Three of the seven zsh plugins the flake fetches and symlinks into `ZSH_CUSTOM` are not in `plugins=()` in `.config/zsh/.zshrc` and are not sourced anywhere: `zsh-vi-mode`, `forgit`, and `you-should-use`.

Removing them from `flake.nix` would shrink the unpinned-input surface from ten repos to seven at no functional cost. Worth confirming you did not intend to enable them before dropping them.

## What vulnix does not cover

`.github/workflows/nix-audit.yml` already runs vulnix weekly against the realised dev shell closure, which catches known CVEs in nixpkgs-derived packages. It does not cover the ten `flake = false` inputs, because those are plain source trees linkFarmed into place rather than CVE-tracked packages. That gap is exactly what this audit covered, and it is the gap that reopens every time those branches move.
