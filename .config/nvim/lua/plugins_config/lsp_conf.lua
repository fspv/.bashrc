-- lsp-zero automates lspconfig configuration
-- lsp-zero doc: https://github.com/VonHeikemen/lsp-zero.nvim/blob/ea4c9511c94df9596c450036502b7ff43d40f816/doc/md/lsp.md
local lsp = require('lsp-zero').preset({
  name = 'minimal',
  set_lsp_keymaps = false,
  manage_nvim_cmp = true,
  suggest_lsp_servers = false,
  float_border = 'none',
  configure_diagnostics = false,
})

lsp.extend_lspconfig()

local prev_win_id = nil

vim.api.nvim_create_autocmd("WinEnter", {
  callback = function()
    local curr_win_id = vim.api.nvim_get_current_win()

    if prev_win_id then
      -- Call ResizeWindows with previous and current window
      require("plugins_local.rabbithole").ResizeWindows(prev_win_id, curr_win_id)
    end

    -- Update the previous window to be the current one for the next switch
    prev_win_id = curr_win_id
  end,
  pattern = { "*.go", "*.py", "*.js", "*.ts", "*.rs", "*.lua" }
})

-- Function to go to definition in a vsplit, close right-hand splits, and resize windows
--- @param f fun(): fun(): nil
function GoToDefinitionVsplitAndManageWindows(f)
  return function()
    require("plugins_local.rabbithole").OpenWindow(f)
  end
end

-- lsp.nvim_workspace()

---@param client vim.lsp.Client
---@param bufnr number
---@return nil
local on_attach_func = function(client, bufnr)
  if client.supports_method("textDocument/publishDiagnostics") then
    ---@type vim.diagnostic.Opts
    local diagnostics_opts = {
      underline = true,
      update_in_insert = false,
      virtual_text = false,
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = '',
          [vim.diagnostic.severity.WARN] = '',
          [vim.diagnostic.severity.HINT] = '',
          [vim.diagnostic.severity.INFO] = '',
        },
      },
    }

    -- By default neovim seems to be publishing all the diagnostics for all the
    -- files in the project into every buffer. If you have big enough project -
    -- good luck. This instead makes it publish only the diagnostics related to
    -- the current buffer
    ---@param _ lsp.ResponseError?
    ---@param result lsp.PublishDiagnosticsParams
    ---@param ctx lsp.HandlerContext
    ---@param config? vim.diagnostic.Opts Configuration table (see |vim.diagnostic.config()|).
    local function publish_diagnostics_current_buffer_filter(_, result, ctx, config)
      -- if not vim.api.nvim_buf_is_valid(bufnr) then
      --   return
      -- end

      -- if result.uri ~= vim.uri_from_bufnr(bufnr) then
      --   return
      -- end

      -- Call the original handler with the filtered diagnostics
      return vim.lsp.diagnostic.on_publish_diagnostics(nil, result, ctx, config)
    end
    vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
      publish_diagnostics_current_buffer_filter, diagnostics_opts
    )

    -- In insert mode avoid updating diagnostics too often as you type
    client.flags.debounce_text_changes = 2000 -- ms
  end

  -- Disable formatting for tsserver and enable eslint. Tsserver formatting
  -- doesn't work well
  if client.name == "tsserver" then
    client.server_capabilities.documentFormattingProvider = nil
  end

  -- This is needed to avoid creating an extra command every time LSP reconnects to the buffer
  local augroup = vim.api.nvim_create_augroup("XXXLspCustomCommands", { clear = true })
  if client.name == "eslint" then
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = bufnr,
      group = augroup,
      desc = "Format javascript/typescript",
      command = "EslintFixAll",
    })
  end

  -- For some reason gopls lsp doesn't do autoformat automatically
  -- if client.name == "gopls" then
  --   vim.api.nvim_create_autocmd(
  --     'BufWritePre',
  --     {
  --       buffer = bufnr,
  --       group = augroup,
  --       -- When file is re-read on_attach is called again
  --       once = true,
  --       desc = "Go sort import and format (if no non-default formatter available)",
  --       callback = function(args)
  --         print("running organize imports lsp code action")
  --         vim.lsp.buf.code_action({
  --           context = {
  --             -- idk, what's this, but this is required
  --             diagnostics = {},
  --             only = { 'source.organizeImports' },
  --           },
  --           apply = true,
  --         })
  --         -- TODO: prints "No code actions available" when nothing to do
  --         if #vim.fs.find('.arcconfig', { upward = true, path = vim.api.nvim_buf_get_name(args.buf) }) < 1
  --             and #vim.fs.find('.golangci.yml', { upward = true, path = vim.api.nvim_buf_get_name(args.buf) }) < 1 then
  --           print("running lsp format")
  --           vim.lsp.buf.format({ async = false, bufnr = args.buf })
  --         end
  --       end,
  --     }
  --   )
  -- end

  -- if client.supports_method("textDocument/documentHighlight") then
  --   -- Highlight all occurences of the symbol under cursor
  --   vim.cmd(
  --     [[
  --       :hi LspReferenceRead cterm=bold ctermbg=red guibg=Yellow guifg=Black
  --       :hi LspReferenceText cterm=bold ctermbg=red guibg=Yellow guifg=Black
  --       :hi LspReferenceWrite cterm=bold ctermbg=red guibg=Yellow guifg=Black
  --     ]]
  --   )

  --   vim.api.nvim_create_augroup("lsp_document_highlight", { clear = true })
  --   vim.api.nvim_clear_autocmds { buffer = bufnr, group = "lsp_document_highlight" }
  --   vim.api.nvim_create_autocmd("CursorHold", {
  --     callback = vim.lsp.buf.document_highlight,
  --     buffer = bufnr,
  --     group = "lsp_document_highlight",
  --     desc = "Document Highlight",
  --   })
  --   vim.api.nvim_create_autocmd("CursorMoved", {
  --     callback = vim.lsp.buf.clear_references,
  --     buffer = bufnr,
  --     group = "lsp_document_highlight",
  --     desc = "Clear All the References",
  --   })
  -- end

  -- require "lsp_signature".on_attach({
  --   bind = true, -- This is mandatory, otherwise border config won't get registered.
  --   handler_opts = {
  --     border = "rounded"
  --   }
  -- }, bufnr)

  lsp.default_keymaps({ buffer = bufnr, preserve_mappings = false })

  -- Format the buffer using gq using ls (use gw to wrap to line length)
  vim.keymap.set(
    { 'n', 'x' },
    'gq',
    function()
      vim.lsp.buf.format({ async = true })
    end,
    { buffer = bufnr, noremap = true, desc = "Format Selection" }
  )

  vim.keymap.set(
    'n',
    'gD',
    GoToDefinitionVsplitAndManageWindows(vim.lsp.buf.declaration),
    { buffer = bufnr, noremap = true, desc = "Go to Declaration" }
  )
  vim.keymap.set(
    'n',
    '<space>wa',
    vim.lsp.buf.add_workspace_folder,
    { buffer = bufnr, noremap = true, desc = "Add Workspace Folder" }
  )
  vim.keymap.set(
    'n',
    '<space>wr',
    vim.lsp.buf.remove_workspace_folder,
    { buffer = bufnr, noremap = true, desc = "Remove Workspace Folder" }
  )
  vim.keymap.set(
    'n',
    '<space>wl',
    function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end,
    { buffer = bufnr, noremap = true, desc = "List Workspace Folders" }
  )
  vim.keymap.set(
    'n',
    '<space>rn',
    vim.lsp.buf.rename,
    { buffer = bufnr, noremap = true, desc = "Rename Symbol Under Cursor" }
  )
  vim.keymap.set(
    { 'n', 'x' },
    '<space>f',
    function()
      vim.lsp.buf.format { async = true }
    end,
    { buffer = bufnr, noremap = true, desc = "Format Document" }
  )

  local function _lsp_workplace_symbols_under_cursor()
    return require("telescope.builtin").lsp_workspace_symbols(
      {
        query = vim.call('expand', '<cword>')
      }
    )
  end

  vim.keymap.set(
    "n",
    "gf",
    _lsp_workplace_symbols_under_cursor,
    { buffer = bufnr, noremap = true, desc = "Find Symbol Under Cursor" }
  )
  vim.keymap.set(
    'n',
    'gr',
    GoToDefinitionVsplitAndManageWindows(require("telescope.builtin").lsp_references),
    { buffer = bufnr, noremap = true, desc = "Find References" }
  )
  vim.keymap.set(
    'n',
    'gi',
    GoToDefinitionVsplitAndManageWindows(require("telescope.builtin").lsp_implementations),
    { buffer = bufnr, noremap = true, desc = "Find Implementations" }
  )
  vim.keymap.set(
    'n',
    'gd',
    GoToDefinitionVsplitAndManageWindows(require("telescope.builtin").lsp_definitions),
    { buffer = bufnr, noremap = true, desc = "Find Definitions" }
  )
  vim.keymap.set(
    'n',
    '<space>D',
    GoToDefinitionVsplitAndManageWindows(require("telescope.builtin").lsp_type_definitions),
    { buffer = bufnr, noremap = true, desc = "Go to Type Definition" }
  )
  vim.keymap.set(
    {
      "n",
      "v"
    },
    "<leader>ca", "<cmd>Lspsaga code_action<CR>",
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
  vim.keymap.set(
    "n",
    "K",
    "<cmd>Lspsaga hover_doc<CR>",
    { buffer = bufnr, noremap = true, desc = "Hover Doc (press twice to scroll)" }
  )

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
  -- require('symbols-outline').open_outline()
end

require('lspconfig').yamlls.setup(
  {
    on_attach = on_attach_func,
    settings = {
      yaml = {
      }
    },
  }
)

require('lspconfig').jsonls.setup(
  {
    on_attach = on_attach_func,
  }
)

require('lspconfig').bashls.setup(
  {
    useLibraryCodeForTypes = false,
    on_attach = on_attach_func,
    filetypes = { 'sh', 'zsh', },
  }
)

require("lspconfig").pyright.setup(
  {
    on_attach = on_attach_func,
    -- cmd = { "pyright-langserver", "--stdio", "--log-level", "debug", "--log-file", "/tmp/pyright.log" },
    -- cmd = { "./log.sh" },
    settings = {
      python = {
        analysis = {
          autoSearchPaths = true,
          typeCheckingMode = "standard",
          verboseOutput = true,
          logLevel = "Trace",
          extraPaths = {
            'plz-out/gen',
            'plz-out/python/venv',
          },
        },
      }
    },
  }
)

-- TODO: I'm just lucky it runs before other commands. But may actually conflict with them
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

require 'lspconfig'.lua_ls.setup {
  on_attach = on_attach_func,
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
        version = 'LuaJIT',
      },
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = { "describe", "it", "vim", "setup", "teardown" },
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = vim.api.nvim_get_runtime_file("", true),
        checkThirdParty = false,
      },
      -- Do not send telemetry data containing a randomized but unique identifier
      telemetry = {
        enable = false,
      },
      format = {
        enable = true,
        defaultConfig = {
          indent_style = "space",
          indent_size = "2",
        }
      },
      hint = {
        enable = true,
      },
    },
  },
}

-- Settings values: https://github.com/golang/tools/blob/master/gopls/doc/settings.md
require 'lspconfig'.gopls.setup {
  on_attach = on_attach_func,
  -- For debug run `gopls -listen="unix;/tmp/gopls-daemon-socket" -logfile=auto -rpc.trace` and uncomment below
  -- cmd = { "gopls", "-debug=:0", "-remote=unix;/tmp/gopls-daemon-socket", "-logfile=auto", "-rpc.trace", },
  cmd = { "gopls" },
  -- Must be set explicitly. Otherwise breaks on :LspRestart
  single_file = false,
  ---@param startpath string
  root_dir = function(startpath)
    if string.find(startpath, 'plz%-out') then
      -- Separate branch, because otherwise it defaults to the repo root and becomes too slow
      return require("lspconfig/util").root_pattern(
        "go.mod",
        "go.work"
      )(startpath)
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
      -- Breaks treesitter defined highlight overwrites (such as SQL within a string)
      semanticTokens = false,
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
        generate = true,   -- show the `go generate` lens.
        gc_details = true, -- Show a code lens toggling the display of gc's choices.
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
      }
    },
  },
  capabilities = require('cmp_nvim_lsp').default_capabilities(),
}

require("lspconfig").rust_analyzer.setup(
  {
    on_attach = on_attach_func,
    settings = {
      ["rust-analyzer"] = {
      }
    }
  }
)

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
  filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
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
require("lspconfig").tsserver.setup({
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
require("lspconfig").bufls.setup({
  on_attach = on_attach_func,
})

-- nixos configs
require("lspconfig").nixd.setup({
  on_attach = on_attach_func,
})

require("lspconfig").java_language_server.setup({
  on_attach = on_attach_func,
})

-- Spellcheck in tex, md and comments
-- require("lspconfig").ltex.setup({
--   filetypes = {
--     'md',
--     'go',
--     'python',
--     'rust',
--     'sh',
--     'lua',
--     'javascript',
--     'typescript'
--   },
--   on_attach = on_attach_func,
-- })

-- TODO: pylsp installation doesn't work from within existing virtualenv
lsp.format_on_save({
  servers = {
    ['lua_ls'] = { 'lua' },
    ['rust_analyzer'] = { 'rust' },
  }
})

-- lsp.skip_server_setup({ 'pyre', 'pylsp' })
lsp.setup()
