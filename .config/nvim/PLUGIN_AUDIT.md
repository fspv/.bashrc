# Neovim plugin audit

Audit of every active plugin in `.config/nvim/lua/config.lua` (`lazy.setup`). Dates reflect upstream state as of 2026-10-18. Config requires nvim >= 0.12 and uses lazy.nvim; plugins are pinned through nixpkgs in `flake.nix` (except `please.nvim` and `vim-quickui`, which are direct flake inputs). Disabled specs (`vim-dispatch`, `vim-go`) and the user's own `sourcegraph.nvim` are excluded.

## Bottom line

The config is in excellent shape and already ahead of most of the "known replacement" curve: `blink.cmp` (not nvim-cmp), `flash.nvim` (not easymotion), native undotree, native document-highlight (not vim-illuminate), built-in `gc`/`gcc` (no vim-commentary), native `vim.lsp.config`/`vim.lsp.enable` (not the deprecated `require('lspconfig')` framework), `gitsigns` `current_line_blame` (no separate blame plugin), and the treesitter archive already worked around (parsers come pre-built from nix, `-textobjects` is the entry point, incremental selection reimplemented natively).

No CVEs or supply-chain incidents were found for any plugin. Nothing is a clear-cut, safe, mechanical fix, so no PR was opened — every remaining item is either a still-working plugin whose replacement is a UX/preference call, a deliberate choice the user already made, or a transitive dependency that can't be dropped yet. The items below are decisions for you to make, not defects. I can implement any of them on request.

## Verdicts

### WARN — watch / your call (8)

- **bufferline.nvim** — stale: last commit 2025-01-14 (~21 months). Still loads and works on nvim 0.12; current breakage is deprecation warnings only (`vim.F.if_nil`, issue #1054), with the deprecated API slated for removal around nvim 0.15. The existing TODO at `config.lua:447` is accurate. If you want to move: **mini.tabline** is the natural fit (same `mini.nvim` family you already vendor for icons/pairs, zero extra deps, very active), **barbar.nvim** is the closest feature-parity alternative, or go tab-less with a native `tabline`. A swap touches `config.lua` (the setup block + the `gt`/`gT` keymaps) and `flake.nix` (the nixpkgs linkFarm entry), and would need a smoke-test rebuild. Not urgent.
- **indent-blankline.nvim (ibl)** — stale: last commit 2026-02-17 (~8 months), but not broken and config correctly uses the v3 `ibl` API. No native indent-guide feature in 0.12. More actively maintained alternatives: `snacks.nvim` indent module or `blink.indent`. Low urgency; a preference, not a forcing function.
- **sqlite.lua** — the priority security/maintenance item. Last commit 2025-03-14, effectively unmaintained, single maintainer with no datable 2026 activity, no community fork has taken over. No CVE, but it is a LuaJIT **FFI binding into the system `libsqlite3`** running in-process in your editor: FFI bypasses Lua's memory safety, so an unfixed pointer/lifetime/ABI bug surfaces as a segfault or memory corruption, not a catchable error. The system `libsqlite3` itself is OS-patched; the concern is the unmaintained binding layer. It is reachable **only** via `smart-open.nvim`. The config comment at `config.lua:696` already acknowledges this ("revisit if it breaks").
- **smart-open.nvim** — the sole carrier of `sqlite.lua`. Itself reasonably maintained (last commit 2025-11-16, beta). The cleanest way to retire `sqlite.lua` is to drop smart-open, but note the config comment: it was vendored specifically for **git-worktree frecency scoping** (treating sibling worktrees as one frecency scope), which other pickers don't provide. `telescope-frecency` v2 dropped its sqlite.lua dependency (plain binary backend now) and `snacks.picker` has built-in frecency, but neither is confirmed to replicate the worktree behavior — so this is a functionality trade-off only you can judge, not a drop-in swap.
- **plenary.nvim** — upstream README carries an "officially archived soon" notice: critical bugs only until 2026-06-30 (now passed), no new features. Functionally frozen. It cannot be removed yet — it is a transitive dependency of `telescope.nvim` and `neo-tree.nvim`. The config already tracks this with TODOs at `config.lua:322` and `config.lua:424` (drop when neo-tree v4 and telescope drop plenary). Native replacements for direct use elsewhere: `vim.system`, `vim.iter`, `vim.uv`, `vim.fs`.
- **diffview-plus.nvim** — very active (last commit 2026-10-14) and the fork the Neogit community points to now that the original `sindrets/diffview.nvim` is abandoned (last commit 2024-06). Correct choice. The only caveat is that it's a single-maintainer personal-account fork — pin to a tag/commit (nixpkgs already hash-pins it) and watch bus-factor.
- **please.nvim** — active (last commit 2026-08-29), the only plugin for the Please build system, so keep. Two things to note: it's pulled **directly from GitHub** as a flake input (not via nixpkgs' review layer), so a hijacked upstream flows in on the next `nix flake update` — the flake.lock commit pin is your mitigation, so review the diff on each bump. Also its license changed BSD→GPL-3 on 2026-08-19.
- **vim-quickui** — maintained but aging pure-vimscript (last commit 2026-06-30), direct flake input. No single actively-maintained Lua drop-in exists for its menubar/listbox/inputbox combo (dressing.nvim is archived; snacks/noice need nui). Keep unless you want to port the menus to a Lua stack.

### KEEP — actively maintained, no action (remaining plugins)

- **gruvbox.nvim** (2026-04-15), **mini.icons** / **mini.pairs** (2026-10-16; note `mini.nvim` moved org `echasnovski` → `nvim-mini` — harmless here since both are vendored via `dir=`, worth a periodic re-sync of the vendored copies).
- **nvim-treesitter-textobjects** (2026-09-03) — the active treesitter entry point; the archived `nvim-treesitter` parser-manager (archived 2026-04-03) is not depended on, since parsers come pre-built from nix.
- **friendly-snippets** (2026-09-11) — data-only (VSCode-format JSON, not executable Lua), low supply-chain risk.
- **blink.cmp** (2026-10-17). Note: a breaking V2 is in development; the version here is nixpkgs-pinned, so the upstream "pin `version = 1.*`" advice is already handled by the flake lock. Its prebuilt Rust fuzzy-matcher is likewise provided through nixpkgs, not downloaded at runtime.
- **nvim-lspconfig** — active; already consumed via the native `vim.lsp.config`/`vim.lsp.enable` API (not the deprecated framework), which is the recommended late-2026 path.
- **conform.nvim** (2026-08-11), **flash.nvim** (2026-08-22), **treesj** (2026-09-23), **vim-matchup** (2026-09-05) — the native Lua matchparen rewrite (neovim#31861) is still WIP, so vim-matchup is still needed.
- **ctrlp.vim** (2026-07-25) — kept intentionally for buffer switching; the `ctrlpvim` community fork still gets occasional fixes, so the usual "abandoned vimscript finder" concern doesn't really apply.
- **vim-fugitive** (2026-03-07), **gitsigns.nvim** (2026-10-13), **neogit** (2026-10-14).
- **neo-tree.nvim** (active, tracks 0.12), **nui.nvim** (2026-08-20), **lualine.nvim** (2026-05-31), **statuscol.nvim** (2026-07-09), **dropbar.nvim** (2026-09-25), **which-key.nvim** (2026-10-28), **trouble.nvim** (2026-10-31).
- **telescope.nvim** (2026-08-17), **telescope-fzf-native.nvim** (2026-05-06), **telescope-live-grep-args.nvim** (2026-04-08) — telescope's momentum has shifted toward fzf-lua / snacks.picker, but it is still receiving real fixes, not abandoned.
- **rainbow-delimiters.nvim** (2026-10-05, primary repo on GitLab), **auto-session** (2026-09-08).
- **go.nvim** (2026-10-18) + **guihua.lua** (2026-07-03), **rustaceanvim** (2026-08-21) — the confirmed current Rust standard (rust-tools.nvim archived 2024, points here).

### REPLACE / REMOVE

- No clear-cut REMOVE. The only REPLACE candidate is **bufferline.nvim → mini.tabline** (see WARN), and it's a preference since bufferline still works.

## Redundancy

- **vim-fugitive vs neogit** — high overlap (both are full interactive git UIs). Both are healthy, so running both is a deliberate preference (fugitive's `:Git <cmd>` ergonomics alongside Neogit's magit buffer), not a maintenance problem. Consolidate only if you want to.
- **diffview-plus vs neogit** — complementary, not redundant: diffview-plus is Neogit's diff backend and also your standalone "View PRs" tool.
- **gitsigns vs fugitive/neogit** — only the blame feature overlaps; the gutter sign column is unique to gitsigns.

## If you want changes

Say the word and I'll implement any of these (each would update `config.lua` + `flake.nix` as needed and be validated against `smoke_test.lua`):

1. Replace `bufferline.nvim` with `mini.tabline` (preserving the `gt`/`gT` cycle keymaps).
2. Replace `indent-blankline.nvim` with `snacks.nvim` indent or `blink.indent`.
3. Retire `sqlite.lua` by moving `smart-open.nvim` → `telescope-frecency` v2 — only if you accept losing the git-worktree frecency scoping.
