-- lsp-zero automates lspconfig configuration
-- lsp-zero doc: https://github.com/VonHeikemen/lsp-zero.nvim/blob/ea4c9511c94df9596c450036502b7ff43d40f816/doc/md/lsp.md
local lsp = require('lsp-zero').preset({
    name = 'minimal',
    set_lsp_keymaps = false,
    manage_nvim_cmp = true,
    suggest_lsp_servers = false,
})

lsp.nvim_workspace()


lsp.on_attach(function(_, bufnr)
    local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
    for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
    end

    local opts = { buffer = bufnr }
    lsp.default_keymaps({ buffer = bufnr, preserve_mappings = false })

    -- Format the buffer using gq using ls (use gw to wrap to line length)
    vim.keymap.set({ 'n', 'x' }, 'gq', function()
        vim.lsp.buf.format({ async = false, timeout_ms = 10000 })
    end)

    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
    vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
    vim.keymap.set('n', '<space>wl', function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, opts)
    vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', '<space>f', function()
        vim.lsp.buf.format { async = true }
    end, opts)

    local function find_symbols()
        return require("telescope.builtin").lsp_workspace_symbols({ query = vim.call('expand', '<cword>') })
    end

    vim.keymap.set("n", "gf", find_symbols, opts)
    vim.keymap.set('n', 'gr', require("telescope.builtin").lsp_references, opts)
    vim.keymap.set('n', 'gi', require("telescope.builtin").lsp_implementations, opts)
    vim.keymap.set('n', 'gd', require("telescope.builtin").lsp_definitions, opts)
    vim.keymap.set('n', '<space>D', require("telescope.builtin").lsp_type_definitions, opts)

    vim.keymap.set({ "n", "v" }, "<leader>ca", "<cmd>Lspsaga code_action<CR>", opts)
    vim.keymap.set("n", "gp", "<cmd>Lspsaga peek_definition<CR>", opts)
    vim.keymap.set("n", "gtp", "<cmd>Lspsaga peek_type_definition<CR>", opts)
    vim.keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>", opts)

    require('symbols-outline').open_outline()
end)

require("lspconfig").pyright.setup(
    {
        settings = {
            analysis = {
                extraPaths = {
                    "plz-out/gen", -- For please build system
                },
            },
        },
    }
)

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


lsp.skip_server_setup({ 'pyre', 'pylsp' })
lsp.setup()
