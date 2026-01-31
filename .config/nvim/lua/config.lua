-- Added 'A' option to prvent swp file messages, I never acted on them anyway
vim.o.shortmess = "ltToOCFA"

if vim.fn.has("nvim-0.10") == 0 then
  print("nvim-0.10 is required to use plugins")
  return
end

if vim.fn.executable("node") == 0 then
  print("node is required to use plugins")
  return
end

if vim.fn.executable("make") == 0 then
  print("make is required to use plugins")
  return
end

if vim.fn.executable("cmake") == 0 then
  print("cmake is required to use plugins")
  return
end

if os.getenv("BWRAPPED") ~= "1" then
  print("BWRAPPED is required to use plugins")
  return
end

local lazypath = os.getenv("NEOVIM_LAZY_PATH")
if lazypath then
  vim.opt.rtp:prepend(lazypath)
else
  print("NEOVIM_LAZY_PATH is required to use plugins")
  return
end

-- Disable the default MenuPopup autocmd that expects specific menu items
-- like "Go to definition"
vim.api.nvim_clear_autocmds({ group = "nvim.popupmenu" })

vim.cmd([[
  aunmenu PopUp
  nmenu PopUp.LSP\ Definition gd
  nmenu PopUp.LSP\ Type\ Definition <space>D
  nmenu PopUp.LSP\ Peek\ Definition gp
  nmenu PopUp.LSP\ Peek\ Type\ Definition gtp
  nmenu PopUp.LSP\ Declaration gD
  nmenu PopUp.LSP\ Rename <space>rn
  nmenu PopUp.LSP\ References gr
  nmenu PopUp.LSP\ Implementation gi
  nmenu PopUp.LSP\ Find\ Symbol gf
  nmenu PopUp.LSP\ Code\ Action <leader>ca
  nmenu PopUp.LSP\ Incoming\ Calls <leader>ci
  nmenu PopUp.LSP\ Outgoing\ Calls <leader>co
]])

-- Remove old log file
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local log_path = vim.lsp.get_log_path()

    -- Check if log file exists and remove it
    local file = io.open(log_path, "r")
    if file then
      file:close()
      os.remove(log_path)

      -- Create new empty log file
      file = io.open(log_path, "w")
      if file then
        file:close()
      end
    end
  end,
  group = vim.api.nvim_create_augroup("LspLogCleanup", { clear = true }),
})

-- Disable CPU heavy features for large buffers and set `vim.b.large_buf`
-- variable to `true`
vim.api.nvim_create_autocmd({ "BufReadPre" }, {
  callback = function()
    local ok, stats = pcall(
      vim.uv.fs_stat,
      vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
    )
    if ok and stats and (stats.size > 20480000) then
      vim.b.large_buf = true
      vim.cmd("syntax off")
      -- vim.cmd("IlluminatePauseBuf")     -- disable vim-illuminate
      -- vim.cmd("IndentBlanklineDisable") -- disable indent-blankline.nvim
      vim.bo.foldmethod = "manual"
      vim.bo.spell = false
    else
      vim.b.large_buf = false
    end
  end,
  group = vim.api.nvim_create_augroup("buf_large", { clear = true }),
  pattern = "*",
})

-- Fix Telescope insert mode on enter file
vim.api.nvim_create_autocmd("WinLeave", {
  callback = function()
    if vim.bo.ft == "TelescopePrompt" and vim.fn.mode() == "i" then
      vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
        "i",
        false
      )
    end
  end,
})

require("lazy").setup({
  -- Colors!
  {
    "ellisonleao/gruvbox.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("plugins_config/gruvbox_conf")
    end,
  },
  -- Icons
  {
    "nvim-tree/nvim-web-devicons",
    lazy = false,
    priority = 999,
  },
  {
    "ryanoasis/vim-devicons",
    lazy = false,
    priority = 999,
    dependencies = {
      "ctrlpvim/ctrlp.vim",
    },
  },

  -- Syntax highlighting and code navidation
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    init = function()
      -- Disable entire built-in ftplugin mappings to avoid conflicts.
      -- See https://github.com/neovim/neovim/tree/master/runtime/ftplugin
      -- for built-in ftplugins.
      vim.g.no_plugin_maps = true

      -- Or, disable per filetype (add as you like)
      -- vim.g.no_python_maps = true
      -- vim.g.no_ruby_maps = true
      -- vim.g.no_rust_maps = true
      -- vim.g.no_go_maps = true
    end,
    config = function()
      -- put your config here
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    version = false, -- last release is way too old and doesn't work on Windows
    lazy = false,
    build = ":TSUpdate",
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
    },
    init = function(plugin)
      -- PERF: add nvim-treesitter queries to the rtp and it's custom query
      -- predicates early This is needed because a bunch of plugins no longer
      -- `require("nvim-treesitter")`, which no longer trigger the
      -- **nvim-treesitter** module to be loaded in time.
      -- Luckily, the only things that those plugins need are the custom
      -- queries, which we make available during startup.
      require("lazy.core.loader").add_to_rtp(plugin)
    end,
    keys = {
      { "<c-space>", desc = "Increment Selection" },
      { "<bs>", desc = "Decrement Selection", mode = "x" },
    },
    ---@param opts TSConfig
    config = function(_, opts) -- luacheck: no unused args
      require("plugins_config/treesitter_conf")
    end,
    cmd = { "TSUpdateSync", "TSUpdate", "TSInstall" },
  },
  -- Omit the final newline of a file if it wasn't present when we opened it
  {
    "vim-scripts/PreserveNoEOL",
  },

  -- # Completion

  -- Completion icons
  {
    "onsails/lspkind.nvim",
  },
  -- Show function signature when you type
  {
    "ray-x/lsp_signature.nvim",
    event = "VeryLazy",
    opts = {
      ignore_error = function(err, ctx, config) -- luacheck: no unused args
        -- Disable this if you experience issues with the plugin
        return true
      end,
    },
    ft = { "go", "rust", "cpp", "typescript", "javascript" },
    config = function(_, opts)
      require("lsp_signature").setup(opts)
    end,
  },
  -- Snippets collection for a set of different programming languages
  {
    "rafamadriz/friendly-snippets",
    dependencies = {
      "hrsh7th/cmp-vsnip",
      --'fatih/vim-go',
      "ray-x/go.nvim",
    },
  },
  -- VSCode(LSP)'s snippet feature
  {
    "hrsh7th/vim-vsnip",
    dependencies = {
      "rafamadriz/friendly-snippets",
      "golang/vscode-go",
    },
  },
  -- Snippet completion and expansion integration
  {
    "hrsh7th/vim-vsnip-integ",
    dependencies = {
      "hrsh7th/vim-vsnip",
    },
  },
  -- Completion engine
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    config = function()
      require("plugins_config/cmp_conf")
    end,
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-vsnip",
      "saadparwaiz1/cmp_luasnip",
      "onsails/lspkind.nvim",
    },
  },
  -- Source for vsnip
  {
    "hrsh7th/cmp-vsnip",
    lazy = false,
    -- https://github.com/hrsh7th/cmp-vsnip/issues/5
    commit = "1ae05c6",
    dependencies = {
      "hrsh7th/vim-vsnip-integ",
    },
  },
  -- Luasnip
  {
    "L3MON4D3/LuaSnip",
    config = function()
      require("luasnip.loaders.from_vscode").lazy_load()
    end,
    dependencies = {
      "rafamadriz/friendly-snippets",
      "hrsh7th/nvim-cmp",
      "golang/vscode-go",
    },
  },
  -- Source for luasnip
  {
    "saadparwaiz1/cmp_luasnip",
    lazy = false,
    dependencies = {
      "L3MON4D3/LuaSnip",
    },
  },
  {
    "hrsh7th/cmp-nvim-lsp",
    dependencies = {},
  },
  -- Source for buffer words
  {
    "hrsh7th/cmp-buffer",
    dependencies = {},
  },
  -- Source for filesystem paths
  {
    "hrsh7th/cmp-path",
    dependencies = {},
  },
  -- Source for vim cmdline
  {
    "hrsh7th/cmp-cmdline",
    dependencies = {},
  },

  -- LSP

  -- More convenient lsp
  -- {
  --   "glepnir/lspsaga.nvim",
  --   lazy = true,
  --   config = function()
  --     require("plugins_config/lspsaga_conf")
  --   end,
  --   dependencies = {},
  -- },
  -- Main LSP plugin
  {
    "neovim/nvim-lspconfig",
    lazy = true,
    cmd = "LspInfo",
    event = { "BufReadPre", "BufNewFile", "LspAttach" },
    config = function()
      require("plugins_config/lsp_conf")
    end,
    dependencies = {
      "nvim-tree/nvim-web-devicons",
      "williamboman/mason-lspconfig.nvim",
      -- "glepnir/lspsaga.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
  },
  -- Format on save
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>f",
        function()
          require("conform").format({ async = true, lsp_fallback = true })
        end,
        mode = "",
        desc = "Format buffer",
      },
    },
    config = function()
      local conform = require("conform")

      conform.setup({
        formatters_by_ft = {
          lua = { "stylua" },
        },
        -- Optional: customize formatter options
        formatters = {
          stylua = {
            -- You can pass additional options to stylua here
            prepend_args = {
              "--indent-type",
              "Spaces",
              "--indent-width",
              "2",
            },
          },
        },
      })

      -- Format on save autocmd
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = "*",
        callback = function(args)
          require("conform").format({ bufnr = args.buf })
        end,
      })
    end,
  },
  -- Highlight other uses of symbol under cursor
  {
    "RRethy/vim-illuminate",
    event = "BufReadPost",
    config = function()
      -- change the highlight style
      vim.api.nvim_set_hl(0, "IlluminatedWordText", { link = "Visual" })
      vim.api.nvim_set_hl(0, "IlluminatedWordRead", { link = "Visual" })
      vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { link = "Visual" })

      --- auto update the highlight style on colorscheme change
      vim.api.nvim_create_autocmd({ "ColorScheme" }, {
        pattern = { "*" },
        callback = function(ev) -- luacheck: no unused args
          vim.api.nvim_set_hl(0, "IlluminatedWordText", { link = "Visual" })
          vim.api.nvim_set_hl(0, "IlluminatedWordRead", { link = "Visual" })
          vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { link = "Visual" })
        end,
      })
    end,
    dependencies = {
      "neovim/nvim-lspconfig",
    },
  },
  -- Automatically detect project root
  {
    "airblade/vim-rooter",
    lazy = false,
    config = function()
      require("plugins_config/vim_rooter_conf")
    end,
  },
  -- fuzzy search
  {
    "junegunn/fzf",
    -- fzf is already installed, no build needed
  },
  -- Highlight trailing whitespace
  {
    "ntpeters/vim-better-whitespace",
    event = "BufReadPost",
  },
  -- Auto-complete matching quotes, brackets, etc
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = true,
  },
  -- Faster navigation
  {
    "easymotion/vim-easymotion",
    lazy = false,
  },
  -- Async builds
  {
    "tpope/vim-dispatch",
    enabled = false,
  },
  -- fuzzy file, buffer, mru, tag, ... finder
  {
    "ctrlpvim/ctrlp.vim",
    init = function()
      require("plugins_config/ctrlp_conf")
    end,
  },
  -- HG plugin
  {
    "ludovicchabant/vim-lawrencium",
  },
  -- Git plugin
  {
    "tpope/vim-fugitive",
    cmd = { "G", "Gdiffsplit" },
  },
  -- Git blame virtualtext plugin
  {
    "f-person/git-blame.nvim",
    init = function()
      vim.g.gitblame_date_format = "%Y-%m-%d"
      vim.g.gitblame_highlight_group = "NonText"
    end,
  },
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("plugins_config/gitsigns_conf")
    end,
  },
  -- View PRs
  {
    "sindrets/diffview.nvim",
  },
  -- More fancy git stuff
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = true,
  },
  -- File tree (also support symbols)
  {
    "nvim-neo-tree/neo-tree.nvim",
    cmd = "Neotree",
    branch = "v3.x",
    keys = {
      { "<leader>nn" },
    },
    config = function()
      require("plugins_config/neotree_conf")
    end,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
  },
  -- UI components library
  {
    "MunifTanjim/nui.nvim",
    lazy = true,
  },
  -- Many go utils
  {
    "fatih/vim-go",
    lazy = false,
    enabled = false,
    ft = "go",
    build = ":GoUpdateBinaries",
    init = function()
      vim.cmd([[
          let g:go_def_mapping_enabled = 0
          let g:go_term_enabled = 1
          let g:go_diagnostics_enabled = 0
          let g:go_code_completion_enabled = 0
          let g:go_fmt_autosave = 0
          let g:go_mod_fmt_autosave = 0
          let g:go_doc_keywordprg_enabled = 0
          let g:go_gopls_enabled = 0
          let g:go_diagnostics_enabled = 0
        ]])
    end,
    config = function()
      require("plugins_config/vim_go_conf")
    end,
  },
  {
    "ray-x/go.nvim",
    dependencies = { -- optional packages
      "ray-x/guihua.lua",
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      -- TODO: not sure if this actually does anything
      require("go").setup({
        diagnostic = false,
        lsp_codelens = false,
        lsp_keymaps = false,
        lsp_inlay_hints = {
          enable = false,
        },
        luasnip = true,
      })
    end,
    event = { "CmdlineEnter" },
    ft = { "go", "gomod" },
    -- if you need to install/update all binaries
    build = ':lua require("go.install").update_all_sync()',
  },
  {
    "golang/vscode-go",
    ft = "go",
    build = function(plugin)
      -- Pop top level `.source.go` key from the vscode json. It is not
      -- compatible with both vsnip and luasnip
      vim.print("Got plugin path " .. plugin.dir)
      local snippets_path = plugin.dir .. "/extension/snippets/go.json"

      vim.print("Got file path " .. snippets_path)
      local snippet_file = io.open(snippets_path, "r")

      vim.print("Reading " .. snippets_path)
      ---@diagnostic disable-next-line: need-check-nil
      local initial_json = snippet_file:read("*a")
      ---@diagnostic disable-next-line: need-check-nil
      snippet_file:close()

      vim.print("Decoding " .. snippets_path)
      local decoded_json = vim.json.decode(initial_json)

      if decoded_json[".source.go"] == nil then
        return
      end

      vim.print("Encoding " .. snippets_path)
      local fixed_json = vim.json.encode(decoded_json[".source.go"])

      vim.print("Writing " .. snippets_path)
      snippet_file = io.open(snippets_path, "w+")
      ---@diagnostic disable-next-line: need-check-nil
      snippet_file:write(fixed_json)
      ---@diagnostic disable-next-line: need-check-nil
      snippet_file:close()

      vim.print("Written " .. snippets_path)
    end,
  },
  -- sudo snap install rustup --classic,
  -- sudo snap install rust-analyzer --beta,
  {
    "mrcjkb/rustaceanvim",
    version = "^5",
    init = function()
      -- Check if lspmux is available and running
      local function is_lspmux_available()
        -- Check if lspmux binary exists in PATH
        if vim.fn.executable("lspmux") ~= 1 then
          return false
        end
        -- Check if lspmux is running
        local handle = io.popen("pgrep lspmux 2>/dev/null")
        if handle then
          local result = handle:read("*a")
          handle:close()
          return result ~= nil and result ~= ""
        end
        return false
      end

      local use_lspmux = is_lspmux_available()

      if not use_lspmux then
        vim.notify(
          "lspmux not found or not running, falling back to rust-analyzer",
          vim.log.levels.WARN
        )
      end

      vim.g.rustaceanvim = {
        server = {
          cmd = use_lspmux and function()
            return vim.lsp.rpc.connect("127.0.0.1", 27631)
          end or nil,
          ---@param client vim.lsp.Client
          ---@param bufnr number
          ---@return nil
          on_attach = function(client, bufnr)
            -- this is needed because the plugin initializes lsp on its own
            require("plugins_config/lsp_conf").on_attach_func(client, bufnr)

            if client.supports_method("textDocument/formatting") then
              vim.api.nvim_create_autocmd("BufWritePre", {
                buffer = bufnr,
                callback = function()
                  vim.lsp.buf.format({ bufnr = bufnr })
                end,
              })
            end
          end,
          default_settings = {
            ["rust-analyzer"] = vim.tbl_deep_extend("force", use_lspmux and {
              lspMux = {
                version = "1",
                method = "connect",
                server = "rust-analyzer",
              },
            } or {}, {
              checkOnSave = false,
              cargo = {
                buildScripts = {
                  enable = true,
                  rebuildOnSave = false,
                },
              },
            }),
          },
        },
      }
    end,
    lazy = false, -- This plugin is already lazy
  },
  {
    "nvim-lua/plenary.nvim",
    lazy = true,
  },
  {
    "mfussenegger/nvim-dap",
    lazy = true,
  },
  {
    "marcuscaisey/please.nvim",
    lazy = true,
    init = function(self) -- luacheck: no unused args
      require("plugins_config/please_init")
    end,
    cmd = "Please",
  },
  -- Menubar
  {
    "skywind3000/vim-quickui",
    lazy = false,
    config = function()
      require("plugins_config/quickui_conf")
    end,
  },
  -- Barbar
  {
    "romgrk/barbar.nvim",
    lazy = false,
    init = function()
      vim.g.barbar_auto_setup = false
      vim.keymap.set(
        "n",
        "gT",
        "<Cmd>BufferPrevious<CR>",
        { noremap = true, silent = true, desc = "Prev Tab" }
      )
      vim.keymap.set(
        "n",
        "gt",
        "<Cmd>BufferNext<CR>",
        { noremap = true, silent = true, desc = "Next Tab" }
      )

      -- Better highlight active tab
      vim.cmd([[
            hi BufferCurrent guibg=Green
            hi BufferCurrentSign guibg=Green
          ]])
    end,
    opts = {
      exclude_ft = { "pb.go" },
      maximum_length = 60,
      icons = {
        diagnostics = {
          enabled = true,
        },
      },
    },
    dependencies = {
      "nvim-tree/nvim-web-devicons",
      "ryanoasis/vim-devicons",
    },
  },
  -- Comment code with gc
  {
    "tpope/vim-commentary",
  },
  {
    "fspv/sourcegraph.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
  },
  -- Status Line
  {
    "nvim-lualine/lualine.nvim",
    config = function()
      require("plugins_config/lualine_conf")
    end,
    dependencies = {
      "Bekaboo/dropbar.nvim",
      "arkav/lualine-lsp-progress",
    },
  },
  -- Sign column with folds etc
  -- `set stc` should be not empty
  {
    "luukvbaal/statuscol.nvim",
    config = function()
      vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]
      local builtin = require("statuscol.builtin")
      require("statuscol").setup({
        setopt = true,
        ft_ignore = { "neo-tree" },
        segments = {
          {
            text = { builtin.foldfunc },
            click = "v:lua.ScFa",
          },
          {
            sign = {
              namespace = { "diagnostic" },
              maxwidth = 2,
              auto = true,
            },
            click = "v:lua.ScSa",
          },
          {
            text = { builtin.lnumfunc },
            click = "v:lua.ScLa",
          },
          {
            sign = {
              name = { ".*" },
              maxwidth = 2,
              colwidth = 1,
              auto = true,
              wrap = true,
            },
            click = "v:lua.ScSa",
          },
          {
            sign = {
              namespace = { "gitsigns" },
              name = { ".*" },
              maxwidth = 1,
              colwidth = 2,
              auto = false,
            },
            click = "v:lua.ScSa",
          },
        },
      })
    end,
    dependencies = {
      "mfussenegger/nvim-dap",
      "lewis6991/gitsigns.nvim",
    },
  },
  -- Winbar dropdown
  {
    "Bekaboo/dropbar.nvim",
    dependencies = {
      "nvim-telescope/telescope-fzf-native.nvim",
      "nvim-tree/nvim-web-devicons",
    },
  },
  -- Alternative to fzf
  {
    "nvim-telescope/telescope.nvim",
    -- Go to definition is broken:
    -- https://github.com/nvim-telescope/telescope.nvim/issues/2690
    -- commit = "443e5a6802849f9e4611a2d91db01b8a37350524",
    config = function()
      require("plugins_config/telescope_conf")
    end,
    cmd = "Telescope",
    keys = {
      "ts/",
      "tf/",
      "tc/",
      "tr/",
      "tt/",
    },
    dependencies = {
      "nvim-telescope/telescope-live-grep-args.nvim",
      "nvim-telescope/telescope-smart-history.nvim",
    },
  },
  -- Fzf interface for telescope
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    -- luacheck: ignore
    build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release",
  },
  -- Live grep with args
  {
    "nvim-telescope/telescope-live-grep-args.nvim",
  },
  {
    "nvim-telescope/telescope-file-browser.nvim",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
    },
  },
  -- Identation indication
  {
    "HiPhish/rainbow-delimiters.nvim",
    submodules = false,
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    lazy = false,
    dependencies = {
      "HiPhish/rainbow-delimiters.nvim",
    },
    config = function()
      require("plugins_config/indent_blankline_conf")
    end,
  },
  -- Matching parentheses improvement
  {
    "andymass/vim-matchup",
    event = "BufReadPost",
    init = function()
      require("plugins_config/matchup_conf")
    end,
  },
  -- Debug
  {
    "stevearc/profile.nvim",
  },
  -- Show diagnostics window
  {
    "folke/trouble.nvim",
    cmd = { "Trouble", "TroubleToggle" },
    config = function()
      require("plugins_config/trouble_conf")
    end,
  },
  -- Show command help as you enter it
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
    end,
    config = function()
      require("plugins_config/which_key_conf")
    end,
  },
  -- Floating terminal
  {
    "voldikss/vim-floaterm",
    keys = {
      { "<leader>ft" },
    },
    init = function()
      require("plugins_config/floaterm_conf")
    end,
  },
  {
    "preservim/vim-markdown",
    ft = "markdown",
  },
  -- Some fancy stuff
  {
    "ojroques/nvim-bufdel",
  },
  -- Github Copilot
  -- {
  --   "github/copilot.vim",
  --   cmd = "Copilot",
  -- },
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("codecompanion").setup({
        display = {
          chat = {
            show_settings = true,
            window = {
              position = "right",
            },
          },
        },
        strategies = {
          chat = {
            adapter = "ollama",
            model = "gemma3:4b",
            slash_commands = {
              ["file"] = {
                callback = "strategies.chat.slash_commands.file",
                description = "Select a file",
                opts = {
                  provider = "telescope", -- Other options include 'default', 'mini_pick', 'fzf_lua'
                  contains_code = true,
                },
              },
              ["buffer"] = {
                callback = "strategies.chat.slash_commands.buffer",
                description = "Select a buffer",
                opts = {
                  provider = "telescope", -- Other options include 'default', 'mini_pick', 'fzf_lua'
                  contains_code = true,
                },
              },
              ["symbols"] = {
                callback = "strategies.chat.slash_commands.symbols",
                description = "Select symbols from a file",
                opts = {
                  provider = "telescope", -- Other options include 'default', 'mini_pick', 'fzf_lua'
                  contains_code = true,
                },
              },
            },
          },
          inline = {
            adapter = "ollama",
            model = "gemma3:4b",
            keymaps = {
              accept_change = {
                modes = { n = "ga" },
                description = "Accept the suggested change",
              },
              reject_change = {
                modes = { n = "gr" },
                description = "Reject the suggested change",
              },
            },
          },
        },
        adapters = {
          llama3 = function()
            return require("codecompanion.adapters").extend("ollama", {
              name = "ollama", -- Give this adapter a different name to differentiate it from the default ollama adapter
              schema = {
                model = {
                  default = "gemma3:4b",
                },
                num_ctx = {
                  default = 10000,
                },
                num_predict = {
                  default = -1,
                },
              },
            })
          end,
        },
      })
    end,
  },
  -- Treesitter based argwrap
  {
    "AckslD/nvim-trevJ.lua",
    init = function()
      vim.keymap.set("n", "<leader>w", function()
        require("trevj").format_at_cursor()
      end, { desc = "Wrap arguments into multiple lines" })
    end,
  },
  -- Automatically close old buffers
  {
    "chrisgrieser/nvim-early-retirement",
    config = true,
    event = "VeryLazy",
  },
  -- Automatically saves session by cwd
  {
    "rmagatti/auto-session",
    init = function(self) -- luacheck: no unused args
      vim.o.sessionoptions = "blank,buffers,curdir,help,tabpages,winsize,winpos," -- luacheck: ignore line-too-long
        .. "terminal,localoptions"
      vim.g.auto_session_pre_save_cmds = {
        "tabdo Neotree close",
        "tabdo UndotreeHide",
        "tabdo DiffviewClose",
        "tabdo Trouble diagnostics close",
      }
    end,
    config = function(self, opts) -- luacheck: no unused args
      -- TODO: just a hack to make statuscol load before auto-session, to
      -- make sure the `statuscol` (`stc`) option is set for auto-loaded
      -- windows
      require("statuscol")
      require("auto-session").setup({
        log_level = "error",
        -- TODO: not sure if this works
        silent_restore = false,
        auto_session_suppress_dirs = {},
        auto_session_use_git_branch = true,
        auto_restore_lazy_delay_enabled = true,
      })
    end,
    dependencies = {
      -- Otherwise will not enable a correct statuscolumn
      "luukvbaal/statuscol.nvim",
    },
  },
  -- Visualise undo tree
  {
    "mbbill/undotree",
  },
  {
    "danielfalk/smart-open.nvim",
    branch = "0.2.x",
    config = function()
      require("telescope").load_extension("smart_open")
    end,
    dependencies = {
      "kkharji/sqlite.lua",
      -- Only required if using match_algorithm fzf
      { "nvim-telescope/telescope-fzf-native.nvim" },
      -- Optional. If installed, native fzy will be used when match_algorithm is fzy
      { "nvim-telescope/telescope-fzy-native.nvim" },
    },
  },
  -- Arduino utils
  {
    "stevearc/vim-arduino",
    init = function(self) -- luacheck: no unused args
      vim.g.arduino_dir = "/snap/arduino/current"
    end,
    ft = { "arduino" },
  },
})

-- TODO: assign this to some config module
vim.cmd("set completeopt=menu,menuone,noselect")
-- have a global statusline at the bottom instead of one for each window
vim.cmd("set laststatus=3")

vim.g.clipboard = {
  name = "OSC 52",
  copy = {
    ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
    ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
  },
  paste = {
    ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
    ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
  },
}

-- vim.api.nvim_set_hl(0, "Normal", { bg = "#282828", fg = "#ebdbb2", })
-- vim.api.nvim_set_hl(0, "NormalNC", { bg = "#383838", fg = "#ebdbb2", })

-- Load local manual configuration if exists
pcall(require, "plugins_config_manual/config") -- Best effort

-- Enable profiler
-- * Must enable and disable (toggle) it manually
-- * Writes the profile into `~/profile.json`
-- * Profile can be opened with `chrome://tracing/`
-- * Profile gets very large quite soon, so don't run it for too long
local should_profile = os.getenv("NVIM_PROFILE")

local function toggle_profile()
  local prof = require("profile")
  if prof.is_recording() then
    prof.stop()
    vim.ui.input({
      prompt = "Save profile to:",
      completion = "file",
      default = "profile.json",
    }, function(filename)
      if filename then
        prof.export(filename)
        vim.notify(string.format("Wrote %s", filename))
      end
    end)
  else
    prof.start("*")
  end
end

if should_profile then
  vim.keymap.set("", "<leader>xx", toggle_profile, { desc = "Toggle Profile" })
  require("profile").instrument_autocmds()
  if should_profile:lower():match("^start") then
    require("profile").start("*")
  else
    require("profile").instrument("*")
  end
end
