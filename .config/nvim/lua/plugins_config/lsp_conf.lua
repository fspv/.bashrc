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
    lsp.default_keymaps({ buffer = bufnr })

    -- Format the buffer using gq using ls (use gw to wrap to line length)
    vim.keymap.set({ 'n', 'x' }, 'gq', function()
        vim.lsp.buf.format({ async = false, timeout_ms = 10000 })
    end)

    -- Definition highlight on cover
    vim.api.nvim_create_autocmd(
        "CursorHold",
        {
            pattern = { "*" },
            callback = function()
                if not require("cmp").visible() then
                    -- Disable focus on hover
                    vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
                        vim.lsp.handlers.hover, { focusable = false }
                    )
                    -- Hover
                    vim.lsp.buf.hover()
                    -- Enable focus again (in case I need to focus manually)
                    vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
                        vim.lsp.handlers.hover, {}
                    )
                end
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
