local lspconfig_defaults = require("lspconfig").util.default_config
lspconfig_defaults.capabilities = vim.tbl_deep_extend(
  "force",
  lspconfig_defaults.capabilities,
  require("cmp_nvim_lsp").default_capabilities()
)

-- Uncomment for debug and use LspLog
-- vim.lsp.set_log_level("debug")

-- local prev_win_id = nil

-- Function to go to definition in a vsplit, close right-hand splits, and resize
-- windows
--- @param f fun(): fun(): nil
function GoToDefinitionVsplitAndManageWindows(f)
  -- return function()
  --   require("plugins_local.rabbithole").OpenWindow(f)
  -- end
  return f
end

---@param client vim.lsp.Client
---@param bufnr number
---@return nil
local on_attach_func = function(client, bufnr)
  client.flags.debounce_text_changes = 2000 -- ms

  vim.diagnostic.config({
    underline = true,
    update_in_insert = false,
    virtual_text = true,
    float = true,
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = "",
        [vim.diagnostic.severity.WARN] = "",
        [vim.diagnostic.severity.HINT] = "",
        [vim.diagnostic.severity.INFO] = "",
      },
    },
  })

  -- Disable formatting for tsserver and enable eslint. Tsserver formatting
  -- doesn't work well
  if client.name == "tsserver" then
    client.server_capabilities.documentFormattingProvider = nil
  end

  vim.keymap.set("n", "K", function()
    vim.lsp.buf.hover({ border = "single" })
  end, { buffer = bufnr, noremap = true, desc = "Show Definition" })
  vim.keymap.set("i", "<C-s>", function()
    vim.lsp.buf.signature_help({ border = "single" })
  end, { buffer = bufnr, noremap = true, desc = "Show Signature" })

  -- Format the buffer using gq using ls (use gw to wrap to line length)
  vim.keymap.set({ "n", "x" }, "gq", function()
    vim.lsp.buf.format({ async = true })
  end, { buffer = bufnr, noremap = true, desc = "Format Selection" })

  vim.keymap.set(
    "n",
    "gD",
    GoToDefinitionVsplitAndManageWindows(vim.lsp.buf.declaration),
    { buffer = bufnr, noremap = true, desc = "Go to Declaration" }
  )
  vim.keymap.set(
    "n",
    "<space>wa",
    vim.lsp.buf.add_workspace_folder,
    { buffer = bufnr, noremap = true, desc = "Add Workspace Folder" }
  )
  vim.keymap.set(
    "n",
    "<space>wr",
    vim.lsp.buf.remove_workspace_folder,
    { buffer = bufnr, noremap = true, desc = "Remove Workspace Folder" }
  )
  vim.keymap.set("n", "<space>wl", function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, { buffer = bufnr, noremap = true, desc = "List Workspace Folders" })
  vim.keymap.set(
    "n",
    "<space>rn",
    vim.lsp.buf.rename,
    { buffer = bufnr, noremap = true, desc = "Rename Symbol Under Cursor" }
  )
  vim.keymap.set({ "n", "x" }, "<space>f", function()
    vim.lsp.buf.format({ async = true })
  end, { buffer = bufnr, noremap = true, desc = "Format Document" })

  local function _lsp_workplace_symbols_under_cursor()
    return require("telescope.builtin").lsp_workspace_symbols({
      query = vim.call("expand", "<cword>"),
    })
  end

  vim.keymap.set(
    "n",
    "gf",
    _lsp_workplace_symbols_under_cursor,
    { buffer = bufnr, noremap = true, desc = "Find Symbol Under Cursor" }
  )
  vim.keymap.set(
    "n",
    "gr",
    GoToDefinitionVsplitAndManageWindows(
      require("telescope.builtin").lsp_references
    ),
    { buffer = bufnr, noremap = true, desc = "Find References" }
  )
  vim.keymap.set(
    "n",
    "gi",
    GoToDefinitionVsplitAndManageWindows(
      require("telescope.builtin").lsp_implementations
    ),
    { buffer = bufnr, noremap = true, desc = "Find Implementations" }
  )
  vim.keymap.set(
    "n",
    "gd",
    GoToDefinitionVsplitAndManageWindows(
      require("telescope.builtin").lsp_definitions
    ),
    { buffer = bufnr, noremap = true, desc = "Find Definitions" }
  )
  vim.keymap.set(
    "n",
    "<space>D",
    GoToDefinitionVsplitAndManageWindows(
      require("telescope.builtin").lsp_type_definitions
    ),
    { buffer = bufnr, noremap = true, desc = "Go to Type Definition" }
  )
  vim.keymap.set("n", "[d", function()
    vim.diagnostic.goto_prev({ float = true })
  end, { buffer = bufnr, noremap = true, desc = "Go to Prev Diagnostic" })
  vim.keymap.set("n", "]d", function()
    vim.diagnostic.goto_next({ float = true })
  end, { buffer = bufnr, noremap = true, desc = "Go to Next Diagnostic" })
  vim.keymap.set(
    {
      "n",
      "v",
    },
    "<leader>ca",
    "<cmd>Lspsaga code_action<CR>",
    { buffer = bufnr, noremap = true, desc = "Code Action" }
  )
  vim.keymap.set(
    "n",
    "gp",
    "<cmd>Lspsaga peek_definition<CR>",
    { buffer = bufnr, noremap = true, desc = "Peek Definition" }
  )
  -- FIXME: overwrites gt (next tab)
  vim.keymap.set(
    "n",
    "gtp",
    "<cmd>Lspsaga peek_type_definition<CR>",
    { buffer = bufnr, noremap = true, desc = "Peek Type Definition" }
  )
  vim.keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>", {
    buffer = bufnr,
    noremap = true,
    desc = "Hover Doc (press twice to scroll)",
  })

  vim.keymap.set(
    "n",
    "<leader>o",
    "<cmd>Lspsaga outline<CR>",
    { buffer = bufnr, noremap = true, desc = "Symbols Outline (Lspsaga)" }
  )
  vim.keymap.set(
    "n",
    "<Leader>ci",
    "<cmd>Lspsaga incoming_calls<CR>",
    { buffer = bufnr, noremap = true, desc = "Incoming Calls" }
  )
  vim.keymap.set(
    "n",
    "<Leader>co",
    "<cmd>Lspsaga outgoing_calls<CR>",
    { buffer = bufnr, noremap = true, desc = "Outgouing Calls" }
  )

  vim.keymap.set(
    "n",
    "]d",
    function()
      vim.diagnostic.jump({
        count = 1,
        float = { border = "single", source = true },
      })
    end,
    { buffer = bufnr, noremap = true, desc = "Jump to the Next Diagnostics" }
  )

  vim.keymap.set("n", "[d", function()
    vim.diagnostic.jump({
      count = -1,
      float = { border = "single", source = true },
    })
  end, {
    buffer = bufnr,
    noremap = true,
    desc = "Jump to the Previous Diagnostics",
  })

  vim.keymap.set("n", "<Leader>ih", function()
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
  end, { buffer = bufnr, noremap = true, desc = "Toggle inlay hints" })
  -- require('symbols-outline').open_outline()
end

require("lspconfig").yamlls.setup({
  on_attach = on_attach_func,
  settings = {
    yaml = {},
  },
})

require("lspconfig").jsonls.setup({
  on_attach = on_attach_func,
})

require("lspconfig").bashls.setup({
  useLibraryCodeForTypes = false,
  on_attach = on_attach_func,
  filetypes = { "sh", "zsh", "bash" },
})

---@param workspace string
---@return string
local function get_python_path(workspace)
  -- Use the `.venv/bin/python` in the current workspace if it exists, otherwise
  -- fallback to system Python
  local venv_path = workspace .. "/.venv/bin/python"
  if vim.fn.executable(venv_path) == 1 then
    return venv_path
  end
  return vim.fn.exepath("python3") or vim.fn.exepath("python") or "python"
end

require("lspconfig").pyright.setup({
  on_attach = on_attach_func,
  -- cmd = {
  --   "pyright-langserver",
  --   "--stdio",
  --   "--log-level",
  --   "debug",
  --   "--log-file",
  --   "/tmp/pyright.log",
  -- },
  -- cmd = { "./log.sh" },
  settings = {
    python = {
      pythonPath = get_python_path(vim.fn.getcwd()),
      analysis = {
        autoSearchPaths = true,
        typeCheckingMode = "standard",
        verboseOutput = true,
        logLevel = "Trace",
        extraPaths = {
          "plz-out/gen",
          "plz-out/python/venv",
        },
      },
    },
  },
})

-- TODO: I'm just lucky it runs before other commands. But may actually conflict
-- with them
-- local group = vim.api.nvim_create_augroup("PythonFormat", { clear = true })
-- vim.api.nvim_create_autocmd("BufWritePost", {
--   pattern = "*.py",
--   command = "silent !black %",
--   group = group,
-- })
-- vim.api.nvim_create_autocmd("BufWritePost", {
--   pattern = "*.py",
--   command = "silent !isort %",
--   group = group,
-- })

-- require 'lspconfig'.jedi_language_server.setup {
-- }
-- require 'lspconfig'.pylsp.setup {
--   settings = {
--     pylsp = {
--       plugins = {
--       }
--     }
--   }
-- }
-- require 'lspconfig'.pyre.setup {
--   cmd = { "pyre", "persistent" },
-- }

-- if not vim.b.large_buf then
--   require 'lspconfig'.pylyzer.setup {
--     cmd = { "pylyzer", "--server", "--verbose", "2" },
--     root_dir = require("lspconfig/util").root_pattern(".git"),
--     settings = {
--       python = {
--         diagnostics = false,
--         inlayHints = true,
--         smartCompletion = true
--       }
--     }
--   }
-- end

require("lspconfig").lua_ls.setup({
  on_attach = on_attach_func,
  on_init = function(client)
    if client.workspace_folders then
      local path = client.workspace_folders[1].name
      if
        path ~= vim.fn.stdpath("config")
        and (
          vim.uv.fs_stat(path .. "/.luarc.json")
          or vim.uv.fs_stat(path .. "/.luarc.jsonc")
        )
      then
        return
      end
    end

    client.config.settings.Lua =
      vim.tbl_deep_extend("force", client.config.settings.Lua, {
        runtime = {
          -- Tell the language server which version of Lua you're using
          -- (most likely LuaJIT in the case of Neovim)
          version = "LuaJIT",
        },
        -- Make the server aware of Neovim runtime files
        workspace = {
          checkThirdParty = false,
          -- library = {
          --   vim.env.VIMRUNTIME
          --   -- Depending on the usage, you might want to add additional paths
          --   -- here.
          --   -- "${3rd}/luv/library"
          --   -- "${3rd}/busted/library",
          -- }
          -- or pull in all of 'runtimepath'. NOTE: this is a lot slower and
          -- will cause issues when working on your own configuration
          -- (see https://github.com/neovim/nvim-lspconfig/issues/3189)
          library = vim.api.nvim_get_runtime_file("", true),
        },
        diagnostics = {
          -- Get the language server to recognize the `vim` global
          globals = { "describe", "it", "vim", "setup", "teardown" },
        },
      })
  end,
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most
        -- likely LuaJIT in the case of Neovim)
        version = "LuaJIT",
      },
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = { "describe", "it", "vim", "setup", "teardown" },
      },
      workspace = {
        checkThirdParty = false,
        library = {
          vim.env.VIMRUNTIME,
          -- Depending on the usage, you might want to add additional paths
          -- here.
          -- "${3rd}/luv/library"
          -- "${3rd}/busted/library",
        },
        -- or pull in all of 'runtimepath'. NOTE: this is a lot slower and will
        -- cause issues when working on your own configuration
        -- (see https://github.com/neovim/nvim-lspconfig/issues/3189)
        -- library = vim.api.nvim_get_runtime_file("", true)
      },
      -- Do not send telemetry data containing a randomized but unique
      -- identifier
      telemetry = {
        enable = false,
      },
      format = {
        enable = true,
        defaultConfig = {
          indent_style = "space",
          indent_size = "2",
        },
      },
      hint = {
        enable = true,
      },
    },
  },
})

-- Settings values:
-- https://github.com/golang/tools/blob/master/gopls/doc/settings.md
require("lspconfig").gopls.setup({
  on_attach = on_attach_func,
  -- For debug run `gopls -listen="unix;/tmp/gopls-daemon-socket" -logfile=auto
  -- -rpc.trace` and uncomment below
  -- cmd = {
  --   "gopls",
  --   "-debug=:0",
  --   "-remote=unix;/tmp/gopls-daemon-socket",
  --   "-logfile=auto",
  --   "-rpc.trace",
  -- },
  cmd = { "gopls" },
  -- Must be set explicitly. Otherwise breaks on :LspRestart
  single_file = false,
  ---@param startpath string
  root_dir = function(startpath)
    if string.find(startpath, "plz%-out") then
      -- Separate branch, because otherwise it defaults to the repo root and
      -- becomes too slow
      return require("lspconfig/util").root_pattern("go.mod", "go.work")(
        startpath
      )
    else
      return require("lspconfig/util").root_pattern(
        -- Order here matters
        "BUILD",
        "go.work",
        "go.mod",
        ".git"
      )(startpath)
    end
  end,
  settings = {
    gopls = {
      staticcheck = true,
      gofumpt = true,
      diagnosticsDelay = "2s",
      diagnosticsTrigger = "Edit", -- Save or Edit
      directoryFilters = { "-plz-out" },
      -- Breaks treesitter defined highlight overwrites (such as SQL within a
      -- string)
      semanticTokens = true,
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        compositeLiteralTypes = true,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
      codelenses = {
        -- show the `go generate` lens.
        generate = true,
        -- Show a code lens toggling the display of gc's choices.
        gc_details = true,
        test = true,
        tidy = true,
        vendor = true,
        regenerate_cgo = true,
        upgrade_dependency = true,
      },
      analyses = {
        unusedparams = true,
        unusedwrite = true,
        unusedvariable = true,
        shadow = true,
        nilness = true,
        useany = true,
      },
    },
  },
  capabilities = require("cmp_nvim_lsp").default_capabilities(),
})

-- To make it work with arduino:
-- ```
-- arduino-cli config init
-- arduino-cli sketch new test
-- arduino-cli board attach -p /dev/ttyACM0 -b arduino:avr:uno test.ino
-- ```
--
-- Then createa a `.clangd` file in the project dir
-- TODO: add example
require("lspconfig").clangd.setup({
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
  on_attach = on_attach_func,
  cmd = {
    "clangd",
    "--completion-style=detailed",
    "--clang-tidy",
    "--pch-storage=memory",
    -- https://github.com/jose-elias-alvarez/null-ls.nvim/issues/428
    "--offset-encoding=utf-16",
    "--background-index",
    "--header-insertion-decorators",
  },
  root_dir = require("lspconfig/util").root_pattern(
    ".clangd",
    ".clang-tidy",
    ".clang-format",
    "compile_commands.json",
    "compile_flags.txt",
    "configure.ac",
    ".git",
    "library.properties"
  ),
})

-- JavaScript/TypeScript
require("lspconfig").ts_ls.setup({
  on_attach = on_attach_func,
})

-- `npm init @eslint/config` to make this work
require("lspconfig").eslint.setup({
  on_attach = on_attach_func,
})
require("lspconfig").biome.setup({
  on_attach = on_attach_func,
})
-- `npm install --save-dev flow-bin && npm run flow init`
-- require("lspconfig").flow.setup({})
require("lspconfig").quick_lint_js.setup({
  on_attach = on_attach_func,
})

-- Proto files
require("lspconfig").buf_ls.setup({
  on_attach = on_attach_func,
})

-- nixos configs
require("lspconfig").nixd.setup({
  on_attach = on_attach_func,
})

-- php
require("lspconfig").phpactor.setup({
  on_attach = on_attach_func,
})

local luacheck = {
  lintCommand = "luacheck --formatter plain --codes --no-color -",
  lintStdin = true,
  lintFormats = {
    "%f:%l:%c: %m",
  },
  lintIgnoreExitCode = true,
}

require("lspconfig").efm.setup({
  on_attach = on_attach_func,
  init_options = { documentFormatting = true }, -- Enable if you want formatting
  filetypes = { "lua" },
  settings = {
    rootMarkers = { ".git/" },
    languages = {
      lua = { luacheck }, -- Both linters will run
    },
  },
})

vim.api.nvim_create_user_command("Tabby", function(_)
  require("tabby_lspconfig").setup()
  require("lspconfig").tabby.setup({})
end, {
  nargs = "*", -- Accept any number of arguments
  desc = "Start Tabby",
  -- bang = true,  -- Allow ! after command (MyCommand!)
  -- complete = 'file',  -- Tab completion for files
})

return {
  on_attach_func = on_attach_func,
}
