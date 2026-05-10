# Neovim Plugin Audit — May 2026

Audit of all active plugins in `.config/nvim/lua/config.lua`.
Skipped: disabled plugins (`enabled = false`), `fspv/sourcegraph.nvim` (user's own).

---

## REMOVE

### `RRethy/vim-illuminate` — Unmaintained, native replacement available

**Status**: Maintainer inactive since mid-2023. No meaningful updates in ~3 years.

**Native replacement** (add to `on_attach` in `lsp_conf.lua`):
```lua
if client.supports_method("textDocument/documentHighlight") then
  local group = vim.api.nvim_create_augroup("lsp_document_highlight", { clear = true })
  vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
    group = group, buffer = bufnr,
    callback = vim.lsp.buf.document_highlight,
  })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group, buffer = bufnr,
    callback = vim.lsp.buf.clear_references,
  })
end
```

**Highlight groups**: Replace `IlluminatedWord{Text,Read,Write}` with
`LspReferenceText`, `LspReferenceRead`, `LspReferenceWrite` (link to `Visual`).
Remove the `ColorScheme` autocmd from `config.lua:256-263`.

**Caveat**: Loses treesitter/regex fallback highlighting for non-LSP buffers.
If you edit files without LSP (plain text, config files), you'll lose symbol
highlighting there. For most programming workflows, LSP coverage is sufficient.

### `stevearc/profile.nvim` → `folke/snacks.nvim` profiler

**Status**: Last commit March 2025. The plugin's own README calls it "a gigantic
hack that works by monkey patching all your lua functions."

**Replacement**: `snacks.nvim` profiler module was explicitly designed as a
successor, combining profile.nvim's instrumentation with a better UI.

**Migration**: Replace the `toggle_profile` function at the bottom of `config.lua`
with `Snacks.profiler.toggle()`. This requires adding `snacks.nvim` if not already
present.

---

## REPLACE

### `nvim-tree/nvim-web-devicons` → `echasnovski/mini.icons`

**Reason**: `mini.icons` has better caching/performance, supports ASCII fallback,
uses `vim.filetype.match()` for wider coverage. LazyVim has already switched to
mini.icons as default.

**Migration**: Add `mini.icons` plugin, call `MiniIcons.mock_nvim_web_devicons()`
in its setup to maintain compatibility with all plugins that depend on devicons
(neo-tree, telescope, bufferline, lualine, dropbar). Then remove
`nvim-tree/nvim-web-devicons`.

### `nvim-telescope/telescope-file-browser.nvim` → Already have `neo-tree.nvim`

**Reason**: `neo-tree.nvim` already provides a full file browser with grep and
file finding integration (configured in `neotree_conf.lua`). The telescope file
browser extension adds a second file browsing interface. Last commit August 2025.

**If removing**: Delete `fb/` keybinding from `telescope_conf.lua:379-383` and
the `file_browser` extension setup/load calls.

**Mitigating factor**: If you actively use `fb/` keybinding, keep it.

---

## WARN — Urgent

### `nvim-lua/plenary.nvim` — ARCHIVING JUNE 30, 2026

**Status**: Deprecation notice posted. Critical bugs may still be fixed until
June 30, 2026, after which the repo will be archived.

**Native replacements available**:
- `plenary.job` → `vim.system` (neovim 0.10+)
- `plenary.scandir` → `vim.fs.dir` (neovim 0.9+)
- `plenary.iterators` / `plenary.functional` → `vim.iter` (neovim 0.10+)
- `plenary.path` → `vim.fs` (partial)
- No native replacement yet for: `plenary.async`, `plenary.curl`, `plenary.test_harness`

**Your plugins that depend on plenary**:
- `neogit` — check if they've dropped the dependency
- `neo-tree.nvim` — check migration status
- `telescope.nvim` — check migration status
- `codecompanion.nvim` — check migration status
- `smart-open.nvim` (vendored) — will need manual update
- `diffview.nvim` — check migration status
- `fspv/sourcegraph.nvim` (your own) — will need migration

**Action**: Audit each dependent plugin's migration plan before June 30. Most
popular plugins should be dropping their plenary dependency by then. Your own
`sourcegraph.nvim` will need manual migration.

---

## WARN — Monitor

### `saghen/blink.cmp` — Supply chain concern (prebuilt binaries)

**Status**: Very actively maintained, best-in-class completion. Downloads
prebuilt Rust binaries for its fuzzy matcher.

**Mitigation**: Build from source with `build = 'cargo build --release'` in the
lazy spec, or rely on the pure Lua fallback (automatic if binary unavailable).

### `kkharji/sqlite.lua` — Semi-maintained, native code

**Status**: Last commit March 2025. Uses FFI to load system `libsqlite3.so`.
The `vim.g.sqlite_clib_path` option could theoretically be abused to load a
rogue shared library.

**Dependency**: Required by vendored `smart-open.nvim`.

**Alternative**: If `snacks.nvim` picker's smart file finding meets your needs,
it would eliminate both smart-open.nvim and sqlite.lua.

### `neovim/nvim-lspconfig` — Mostly redundant, still useful

**Status**: Actively maintained (v2.8.0, Apr 2026). The config already uses
native `vim.lsp.config()` and `vim.lsp.enable()`. Only remaining uses:

1. `require("lspconfig.util").default_config` → `vim.lsp.config('*', {...})`
2. `require("lspconfig/util").root_pattern(...)` → `vim.fs.root(0, {...})`

**Recommendation**: Keep for now — it saves boilerplate for 100+ server configs.
Migrate the remaining `root_pattern()` calls incrementally.

### `skywind3000/vim-quickui` — Dead menu entries

**Status**: Last commit May 2026, actively maintained. VimScript.

**Problem**: The "Fuzzy search" menu in `quickui_conf.lua` contains ~20 dead
entries referencing fzf.vim commands (`:GFiles`, `:Commits`, `:Buffers`, `:Rg`,
etc.) that are not installed. These menu entries fail when selected.

**Action**: Remove the dead fzf.vim menu entries. Consider replacing the whole
plugin with a Lua-based menu using `nui.nvim` or `vim.ui.select`.

### `akinsho/bufferline.nvim` — 16 months stale

**Status**: Last commit January 2025 (v4.9.1). Open issues accumulating.

**Alternatives**: `barbar.nvim`, `mini.tabline`, or go tab-less.

### `luukvbaal/statuscol.nvim` — Diminishing value

**Status**: Last commit June 2025. Neovim 0.11+ `statuscolumn` improvements
make much of this plugin redundant natively. Still adds click handlers.

**Action**: Consider migrating to native `vim.o.statuscolumn`.

### `MunifTanjim/nui.nvim` — Slowing down

**Status**: Last commit June 2025 (~11 months ago). Still functional, used by
neo-tree. The ecosystem trend is toward `snacks.nvim` for UI components.

**Action**: Keep as neo-tree dependency. Monitor.

### `ctrlpvim/ctrlp.vim` — Legacy VimScript

**Status**: Sporadic commits, no feature development. Works fine for buffer
switching (`CtrlPBuffer`). Intentionally kept per user preference.

### `ray-x/go.nvim` + `ray-x/guihua.lua` — Heavy for limited use

**Status**: Active (latest release v0.11, Apr 2026). **Master branch now
requires neovim 0.12+.** The config has most features disabled and includes
a TODO comment "not sure if this actually does anything."

**Action**: Verify you're on a compatible branch/version. If you only use
`:GoTest` / `:GoAddTag` occasionally, consider removing in favor of plain
gopls + shell commands.

### `stevearc/vim-arduino` — 2.5 years stale

**Status**: Last commit October 2023. Wraps `arduino-cli`; core functionality
is stable. No alternative exists.

**Action**: Keep if it works; replace with custom Lua wrapper if it breaks.

### `dlyongemallo/diffview.nvim` — Fork status

**Status**: This is the actively maintained fork (v0.32, May 2026). The original
`sindrets/diffview.nvim` has not received commits since June 2024. The user's
choice to switch to this fork was correct.

**Note**: Neovim 0.12 introduced a built-in `:DiffTool` (`:packadd nvim.difftool`)
for basic directory diffs, but it does not replace diffview for git-aware workflows.

**Action**: Keep. The fork is healthy.

---

## KEEP

Actively maintained, no native replacement, no better alternative:

| Plugin | Notes |
|--------|-------|
| `ellisonleao/gruvbox.nvim` | Active, popular colorscheme |
| `nvim-treesitter/nvim-treesitter-textobjects` | Active (main branch), standalone after nvim-treesitter archival |
| `rafamadriz/friendly-snippets` | Active, data-only (JSON snippets), low attack surface |
| `stevearc/conform.nvim` | Active, best-in-class formatter |
| `windwp/nvim-autopairs` | Active, no native replacement. `mini.pairs` is a lighter fallback |
| `folke/flash.nvim` | Active, best-in-class navigation |
| `tpope/vim-fugitive` | Mature, stable, gold standard for git |
| `lewis6991/gitsigns.nvim` | Very active (v2.1.0, Mar 2026), essential |
| `NeogitOrg/neogit` | Active (v2.0.0), best magit-like experience |
| `nvim-neo-tree/neo-tree.nvim` | Very active (v3.40.0, Mar 2026) |
| `mrcjkb/rustaceanvim` | Very active (248 releases), definitive Rust plugin |
| `mfussenegger/nvim-dap` | Active, standard debug adapter, no alternative |
| `marcuscaisey/please.nvim` | Active (v1.1.2, May 2026), niche but maintained |
| `nvim-lualine/lualine.nvim` | Active (Apr 2026) |
| `Bekaboo/dropbar.nvim` | Active (Apr 2026), best-in-class winbar |
| `nvim-telescope/telescope.nvim` | Active (May 2026), ecosystem standard |
| `nvim-telescope/telescope-fzf-native.nvim` | Active (May 2026) |
| `nvim-telescope/telescope-live-grep-args.nvim` | Active (Apr 2026), heavily used in config |
| `HiPhish/rainbow-delimiters.nvim` | Active (Apr 2026), integrated with indent-blankline |
| `lukas-reineke/indent-blankline.nvim` | Active (Feb 2026) |
| `andymass/vim-matchup` | Active (Apr 2026), unique treesitter-aware `%` |
| `folke/trouble.nvim` | Active (Oct 2025), best diagnostics viewer |
| `folke/which-key.nvim` | Active (Oct 2025), standard keybinding help |
| `olimorris/codecompanion.nvim` | Very active (May 2026), multi-provider AI |
| `Wansmer/treesj` | Active (Apr 2026), treesitter-based split/join |
| `chrisgrieser/nvim-early-retirement` | Active (Apr 2026), zero open issues |
| `rmagatti/auto-session` | Active (May 2026) |
| `mbbill/undotree` | Stable (Mar 2026) |
| `danielfalk/smart-open.nvim` | Vendored, unique git-worktree frecency |

---

## Additional findings

### Bug: Missing `code_action_preview` module

`lsp_conf.lua:163` references `require("plugins_config.code_action_preview").code_action()`
but this file does not exist. The `<leader>ca` keybinding will error when pressed.

**Fix**: Either create the module or replace with `vim.lsp.buf.code_action()`.

### Version check outdated

`config.lua:4` checks for `nvim-0.10` but the config uses `vim.lsp.config()`
and `vim.lsp.enable()` which require nvim 0.11+. Update to `nvim-0.11`.

### Telescope ecosystem at inflection point

LazyVim switched its default fuzzy finder from telescope to fzf-lua. Telescope
is still maintained but losing mindshare. A future fzf-lua migration would
eliminate 3 telescope extensions but requires significant work due to deep
telescope API usage in `lsp_conf.lua`, `telescope_conf.lua`, `neotree_conf.lua`,
and extensions (smart-open, sourcegraph).
