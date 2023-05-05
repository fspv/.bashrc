-- lsp-zero automates lspconfig configuration
-- lsp-zero doc: https://github.com/VonHeikemen/lsp-zero.nvim/blob/ea4c9511c94df9596c450036502b7ff43d40f816/doc/md/lsp.md
local lsp = require('lsp-zero').preset({
    name = 'minimal',
    set_lsp_keymaps = true,
    manage_nvim_cmp = true,
    suggest_lsp_servers = false,
})

lsp.nvim_workspace()

lsp.on_attach(function(_, bufnr)
    local opts = { buffer = bufnr }
    lsp.default_keymaps({ buffer = bufnr, preserve_mappings = false })

    -- Format the buffer using gq using ls (use gw to wrap to line length)
    vim.keymap.set({ 'n', 'x' }, 'gq', function()
        vim.lsp.buf.format({ async = false, timeout_ms = 10000 })
    end)

    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', '<c-k>', vim.lsp.buf.hover, { buffer = bufnr })
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
    vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
    vim.keymap.set('n', '<space>wl', function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, opts)
    vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
    vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    vim.keymap.set('n', '<space>f', function()
        vim.lsp.buf.format { async = true }
    end, opts)


    -- Definition highlight on cover
    vim.api.nvim_create_autocmd(
        "CursorHold",
        {
            pattern = { "*" },
            callback = function()
                -- local mode = vim.api.nvim_get_mode().mode

                -- if mode == "n" then
                --     -- Disable focus on hover
                --     vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
                --         vim.lsp.handlers.hover, { focusable = false }
                --     )
                --     -- Hover
                --     vim.lsp.buf.hover()
                --     -- Enable focus again (in case I need to focus manually)
                --     vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
                --         vim.lsp.handlers.hover, {}
                --     )
                -- end
            end
        }
    )
end)

require("lspconfig").pylsp.setup {
    settings = {
        pylsp = {
            configurationSources = { "flake8" },
            plugins = {
                flake8 = { enabled = true },
                pycodestyle = { enabled = false },
                mccabe = { enabled = false
                },
                pyflakes = {
                    enabled = false
                },
                pydocstyle = {
                    enabled = false
                }
            }
        }
    },
}

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
            diagnosticsDelay = "2s",
            directoryFilters = { "-plz-out" },
            completionBudget = "1s",
        },
    },
}

lsp.ensure_installed({
    'gopls',
    'clangd',
    'rust_analyzer'
})

-- TODO: pylsp installation doesn't work from within existing virtualenv
lsp.format_on_save({
    servers = {
        ['lua_ls'] = { 'lua' },
        ['rust_analyzer'] = { 'rust' },
    }
})

lsp.setup()
