-- lsp-zero automates lspconfig configuration
-- lsp-zero doc: https://github.com/VonHeikemen/lsp-zero.nvim/blob/ea4c9511c94df9596c450036502b7ff43d40f816/doc/md/lsp.md
local lsp = require('lsp-zero').preset({
  name = 'minimal',
  set_lsp_keymaps = false,
  manage_nvim_cmp = true,
  suggest_lsp_servers = false,
})

lsp.extend_lspconfig()

-- lsp.nvim_workspace()

local on_attach_func = function(_, bufnr)
  vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
    vim.lsp.diagnostic.on_publish_diagnostics, {
      underline = true,
      update_in_insert = false,
      signs = true,
      virtual_text = true,
    }
  )

  local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
  for type, icon in pairs(signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
  end

  require "lsp_signature".on_attach({
    bind = true, -- This is mandatory, otherwise border config won't get registered.
    handler_opts = {
      border = "rounded"
    }
  }, bufnr)

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
    vim.lsp.buf.declaration,
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
    require("telescope.builtin").lsp_references,
    { buffer = bufnr, noremap = true, desc = "Find References" }
  )
  vim.keymap.set(
    'n',
    'gi',
    require("telescope.builtin").lsp_implementations,
    { buffer = bufnr, noremap = true, desc = "Find Implementations" }
  )
  vim.keymap.set(
    'n',
    'gd',
    require("telescope.builtin").lsp_definitions,
    { buffer = bufnr, noremap = true, desc = "Find Definitions" }
  )
  vim.keymap.set(
    'n',
    '<space>D',
    require("telescope.builtin").lsp_type_definitions,
    { buffer = bufnr, noremap = true, desc = "Go to Type Definition" }
  )
  vim.keymap.set(
    {
      "n",
      "v"
    },
    "<space>ca", "<cmd>Lspsaga code_action<CR>",
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

lsp.on_attach(on_attach_func)

require('lspconfig').yamlls.setup(
  {
    settings = {
      yaml = {
      }
    },
  }
)

require('lspconfig').jsonls.setup(
  {
  }
)

require('lspconfig').bashls.setup(
  {
  }
)

require("lspconfig").pyright.setup(
  {
    settings = {
      python = {
        analysis = {
          extraPaths = {
            "plz-out/gen", -- For please build system
          },
          typeCheckingMode = "off",
          autoSearchPaths = false,
          useLibraryCodeForTypes = false,
          diagnosticMode = "openFilesOnly",
        },
      },
    },
  }
)
-- require 'lspconfig'.jedi_language_server.setup {
-- }
require 'lspconfig'.pylsp.setup {
  settings = {
    pylsp = {
      plugins = {
      }
    }
  }
}
require 'lspconfig'.pyre.setup {
  cmd = { "pyre", "persistent" },
}

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
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
        version = 'LuaJIT',
      },
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = { 'vim' },
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = vim.api.nvim_get_runtime_file("", true),
      },
      -- Do not send telemetry data containing a randomized but unique identifier
      telemetry = {
        enable = false,
      },
    },
  },
}

-- Settings values: https://github.com/golang/tools/blob/master/gopls/doc/settings.md
require 'lspconfig'.gopls.setup {
  cmd = { "gopls" },
  root_dir = require("lspconfig/util").root_pattern("go.work", "go.mod", ".git", "BUILD"),
  settings = {
    gopls = {
      staticcheck = true,
      gofumpt = true,
      diagnosticsDelay = "2s",
      directoryFilters = { "-plz-out" },
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
    settings = {
      ["rust-analyzer"] = {
      }
    }
  }
)

-- JavaScript/TypeScript
require("lspconfig").tsserver.setup({})

-- `npm init @eslint/config` to make this work
require("lspconfig").eslint.setup({})
require("lspconfig").biome.setup({})
-- `npm install --save-dev flow-bin && npm run flow init`
-- require("lspconfig").flow.setup({})
require("lspconfig").quick_lint_js.setup({})

-- Proto files
require("lspconfig").bufls.setup({})

-- lsp.ensure_installed({
--   'gopls',
--   'clangd',
--   'rust_analyzer'
-- })

-- TODO: pylsp installation doesn't work from within existing virtualenv
lsp.format_on_save({
  servers = {
    ['lua_ls'] = { 'lua' },
    ['rust_analyzer'] = { 'rust' },
  }
})


local lsp = require('lsp-zero').preset({
  float_border = 'none',
  configure_diagnostics = false,
})
-- lsp.skip_server_setup({ 'pyre', 'pylsp' })
lsp.setup()
