-- Added 'A' option to prvent swp file messages, I never acted on them anyway
vim.opt.shortmess = "ltToOCFA"

-- Disable CPU heavy features for large buffers and set `vim.b.large_buf`
-- variable to `true`
vim.api.nvim_create_autocmd({ "BufReadPre" }, {
  callback = function()
    local ok, stats = pcall(
      vim.uv.fs_stat,
      vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
    )
    if ok and stats and (stats.size > 204800) then
      vim.b.large_buf = true
      vim.cmd("syntax off")
      -- vim.cmd("IlluminatePauseBuf")     -- disable vim-illuminate
      -- vim.cmd("IndentBlanklineDisable") -- disable indent-blankline.nvim
      vim.opt_local.foldmethod = "manual"
      vim.opt_local.spell = false
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
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "i", false)
    end
  end,
})


-- Install Lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup(
  {
    -- Colors!
    {
      'ellisonleao/gruvbox.nvim',
      lazy = false,
      priority = 1000,
      setup = true,
      config = function()
        require("plugins_config/gruvbox_conf")
      end,
    },
    -- Icons
    {
      'nvim-tree/nvim-web-devicons',
      lazy = false,
      priority = 999,
    },
    {
      'ryanoasis/vim-devicons',
      lazy = false,
      priority = 999,
      dependencies = {
        'ctrlpvim/ctrlp.vim',
      },
    },

    -- Syntax highlighting and code navidation
    {
      "nvim-treesitter/nvim-treesitter-textobjects",
    },
    {
      'nvim-treesitter/nvim-treesitter',
      version = false, -- last release is way too old and doesn't work on Windows
      lazy = false,
      build = ':TSUpdate',
      dependencies = {
        "nvim-treesitter/nvim-treesitter-textobjects",
      },
      init = function(plugin)
        -- PERF: add nvim-treesitter queries to the rtp and it's custom query predicates early
        -- This is needed because a bunch of plugins no longer `require("nvim-treesitter")`, which
        -- no longer trigger the **nvim-treesitter** module to be loaded in time.
        -- Luckily, the only things that those plugins need are the custom queries, which we make available
        -- during startup.
        require("lazy.core.loader").add_to_rtp(plugin)
        require("nvim-treesitter.query_predicates")
      end,
      keys = {
        { "<c-space>", desc = "Increment Selection" },
        { "<bs>",      desc = "Decrement Selection", mode = "x" },
      },
      ---@param opts TSConfig
      config = function(_, opts)
        require("plugins_config/treesitter_conf")
      end,
      cmd = { "TSUpdateSync", "TSUpdate", "TSInstall" },
    },
    -- Universally good defaults
    {
      'tpope/vim-sensible',
    },
    -- Use ctrl-a and ctrl-x to increment/decrement times/dates
    {
      'tpope/vim-speeddating',
    },
    -- Omit the final newline of a file if it wasn't present when we opened it
    {
      'vim-scripts/PreserveNoEOL',
    },
    -- Updated Python syntax highlighting
    {
      'vim-python/python-syntax',
      ft = 'python',
    },
    -- Better C++ syntax highlight
    {
      'octol/vim-cpp-enhanced-highlight',
      ft = 'cpp',
    },
    -- Arcanist diff highlight
    {
      'solarnz/arcanist.vim',
      ft = 'arcanistdiff',
      init = function()
        require("plugins_config/arcanist_init")
      end,
    },

    -- # Completion

    -- Completion icons
    {
      'onsails/lspkind.nvim',
    },
    -- Show function signature when you type
    {
      'ray-x/lsp_signature.nvim',
      event = "VeryLazy",
      opts = {
        noice = true,
      },
      ft = { "go", "rust", "cpp", "typescript", "javascript" },
      config = function(_, opts) require 'lsp_signature'.setup(opts) end
    },
    -- Snippets collection for a set of different programming languages
    {
      'rafamadriz/friendly-snippets',
      dependencies = {
        'hrsh7th/cmp-vsnip',
        --'fatih/vim-go',
        "ray-x/go.nvim",
      }
    },
    -- VSCode(LSP)'s snippet feature
    {
      'hrsh7th/vim-vsnip',
      dependencies = {
        'rafamadriz/friendly-snippets',
        'golang/vscode-go',
      }
    },
    -- Snippet completion and expansion integration
    {
      'hrsh7th/vim-vsnip-integ',
      init = function()
        require("plugins_config/vsnip_conf")
      end,
      dependencies = {
        'hrsh7th/vim-vsnip',
      }
    },
    -- Completion engine
    {
      'hrsh7th/nvim-cmp',
      event = "InsertEnter",
      config = function()
        require("plugins_config/cmp_conf")
      end,
      dependencies = {
        'hrsh7th/cmp-nvim-lsp',
        'hrsh7th/cmp-path',
        'hrsh7th/cmp-cmdline',
        'hrsh7th/cmp-buffer',
        'hrsh7th/cmp-vsnip',
        "saadparwaiz1/cmp_luasnip",
        'onsails/lspkind.nvim',
      }
    },
    -- Source for vsnip
    {
      'hrsh7th/cmp-vsnip',
      lazy = false,
      -- https://github.com/hrsh7th/cmp-vsnip/issues/5
      commit = "1ae05c6",
      dependencies = {
        'hrsh7th/vim-vsnip-integ',
      },
    },
    -- Luasnip
    {
      "L3MON4D3/LuaSnip",
      config = function()
        require('luasnip.loaders.from_vscode').lazy_load()
      end,
      dependencies = {
        'rafamadriz/friendly-snippets',
        'hrsh7th/nvim-cmp',
        'golang/vscode-go',
      }
    },
    -- Source for luasnip
    {
      "saadparwaiz1/cmp_luasnip",
      lazy = false,
      dependencies = {
        "L3MON4D3/LuaSnip",
      }
    },
    {
      'hrsh7th/cmp-nvim-lsp',
      dependencies = {
      },
    },
    -- Source for buffer words
    {
      'hrsh7th/cmp-buffer',
      dependencies = {
      },
    },
    -- Source for filesystem paths
    {
      'hrsh7th/cmp-path',
      dependencies = {
      },
    },
    -- Source for vim cmdline
    {
      'hrsh7th/cmp-cmdline',
      dependencies = {
      },
    },

    -- LSP

    -- Yet another package manager
    {
      'williamboman/mason.nvim',
      lazy = true,
      build = ':MasonUpdate',
      cmd = 'Mason',
      config = function()
        require("mason").setup()
      end,
    },
    -- Automatically install LSP
    {
      'williamboman/mason-lspconfig.nvim',
      lazy = true,
      config = function()
        require("plugins_config/mason_lspconfig_conf")
      end,
      dependencies = {
        'williamboman/mason.nvim',
      },
    },
    -- More convenient lsp
    {
      'glepnir/lspsaga.nvim',
      lazy = true,
      config = function()
        require("plugins_config/lspsaga_conf")
      end,
      dependencies = {
      }
    },
    -- Boilerplate configuration for lspconfig
    {
      'VonHeikemen/lsp-zero.nvim',
      lazy = true,
      config = function()
        -- Empty, loaded together with nvim-lspconfig
      end,
      dependencies = {
      },
    },
    -- Main LSP plugin
    {
      'neovim/nvim-lspconfig',
      lazy = true,
      cmd = 'LspInfo',
      event = { 'BufReadPre', 'BufNewFile', 'LspAttach' },
      config = function()
        require("plugins_config/lsp_conf")
      end,
      dependencies = {
        'nvim-tree/nvim-web-devicons',
        'williamboman/mason-lspconfig.nvim',
        'glepnir/lspsaga.nvim',
        'hrsh7th/cmp-nvim-lsp',
        'VonHeikemen/lsp-zero.nvim',
      },
    },
    -- Highlight other uses of symbol under cursor
    {
      'RRethy/vim-illuminate',
      event = "BufReadPost",
      config = function()
        -- change the highlight style
        vim.api.nvim_set_hl(0, "IlluminatedWordText", { link = "Visual" })
        vim.api.nvim_set_hl(0, "IlluminatedWordRead", { link = "Visual" })
        vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { link = "Visual" })

        --- auto update the highlight style on colorscheme change
        vim.api.nvim_create_autocmd({ "ColorScheme" }, {
          pattern = { "*" },
          callback = function(ev)
            vim.api.nvim_set_hl(0, "IlluminatedWordText", { link = "Visual" })
            vim.api.nvim_set_hl(0, "IlluminatedWordRead", { link = "Visual" })
            vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { link = "Visual" })
          end
        })
      end,
      dependencies = {
        'neovim/nvim-lspconfig',
      },
    },
    -- Format on save
    -- {
    --   'mhartington/formatter.nvim',
    --   config = function()
    --     require("plugins_config/formatter_conf")
    --   end,
    -- },
    -- Automatically detect project root
    {
      'airblade/vim-rooter',
      lazy = false,
      config = function()
        require("plugins_config/vim_rooter_conf")
      end,
    },
    -- fuzzy search
    {
      'junegunn/fzf',
      -- fzf is already installed, no build needed
    },
    {
      'junegunn/fzf.vim',
      config = function()
        require("plugins_config/fzf_conf")
      end,
      dependencies = {
        'junegunn/fzf',
      },
    },
    -- Highlight trailing whitespace
    {
      'ntpeters/vim-better-whitespace',
      event = "BufReadPost",
    },
    -- Auto-complete matching quotes, brackets, etc
    {
      'windwp/nvim-autopairs',
      event = "InsertEnter",
      config = true
    },
    -- {
    --   'nvim-tree/nvim-tree.lua',
    --   cmd = { 'NvimTreeOpen', 'NvimTreeToggle' },
    --   config = function()
    --     require("plugins_config/nvimtree_conf")
    --   end,
    -- },
    -- Faster navigation
    {
      'easymotion/vim-easymotion',
      lazy = false,
    },
    -- Async builds
    {
      'tpope/vim-dispatch',
      enabled = false,
    },
    -- fuzzy file, buffer, mru, tag, ... finder
    {
      'ctrlpvim/ctrlp.vim',
      init = function()
        require("plugins_config/ctrlp_conf")
      end,
    },
    -- HG plugin
    {
      'ludovicchabant/vim-lawrencium',
    },
    -- Git plugin
    {
      'tpope/vim-fugitive',
      cmd = { "G", "Gdiffsplit" },
    },
    -- Git blame virtualtext plugin
    {
      'f-person/git-blame.nvim',
      init = function()
        vim.g.gitblame_date_format = "%Y-%m-%d"
        vim.g.gitblame_highlight_group = "NonText"
      end,
    },
    {
      'lewis6991/gitsigns.nvim',
      config = function()
        require("plugins_config/gitsigns_conf")
      end,
    },
    -- View PRs
    {
      'sindrets/diffview.nvim',
    },
    -- More fancy git stuff
    {
      "NeogitOrg/neogit",
      dependencies = {
        "nvim-lua/plenary.nvim",
        "sindrets/diffview.nvim",
        "nvim-telescope/telescope.nvim",
      },
      config = true
    },
    -- Show modifications in sign column
    -- {
    --   'mhinz/vim-signify',
    -- },
    -- Solidity smart contracts plugin
    {
      'tomlion/vim-solidity',
      ft = 'solidity',
    },
    -- File tree (also support symbols)
    {
      'nvim-neo-tree/neo-tree.nvim',
      cmd = 'Neotree',
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
      }
    },
    -- UI components library
    {
      'MunifTanjim/nui.nvim',
      lazy = true,
    },
    -- Many go utils
    {
      'fatih/vim-go',
      lazy = false,
      enabled = false,
      ft = "go",
      build = ':GoUpdateBinaries',
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
        require("go").setup(
          {
            diagnostic = false,
            lsp_codelens = false,
            lsp_inlay_hints = {
              enable = false,
            },
            luasnip = true,
          }
        )
      end,
      event = { "CmdlineEnter" },
      ft = { "go", 'gomod' },
      build = ':lua require("go.install").update_all_sync()' -- if you need to install/update all binaries
    },
    {
      'golang/vscode-go',
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
      end
    },
    -- sudo snap install rustup --classic,
    -- sudo snap install rust-analyzer --beta,
    {
      'rust-lang/rust.vim',
      ft = "rust",
    },
    {
      'simrat39/rust-tools.nvim',
      ft = "rust",
    },
    {
      'nvim-lua/plenary.nvim',
      lazy = true,
    },
    {
      'mfussenegger/nvim-dap',
      lazy = true,
    },
    {
      'marcuscaisey/please.nvim',
      lazy = true,
      init = function(self)
        require("plugins_config/please_init")
      end,
      cmd = 'Please',
    },
    -- {
    --   'kosayoda/nvim-lightbulb',
    --   config = function()
    --     require("plugins_config/lightbulb_conf")
    --   end,
    -- },
    {
      'weilbith/nvim-code-action-menu',
    },
    -- Menubar
    {
      'skywind3000/vim-quickui',
      lazy = false,
      config = function()
        require("plugins_config/quickui_conf")
      end,
    },
    -- Barbar
    {
      'romgrk/barbar.nvim',
      lazy = false,
      init = function()
        vim.g.barbar_auto_setup = false
        vim.keymap.set('n', 'gT', '<Cmd>BufferPrevious<CR>', { noremap = true, silent = true, desc = "Prev Tab" })
        vim.keymap.set('n', 'gt', '<Cmd>BufferNext<CR>', { noremap = true, silent = true, desc = "Next Tab" })

        -- Better highlight active tab
        vim.cmd(
          [[
            hi BufferCurrent guibg=Green
            hi BufferCurrentSign guibg=Green
          ]]
        )
      end,
      opts = {
        exclude_ft = { "pb.go" },
        maximum_length = 60,
        icons = {
          diagnostics = {
            enabled = true
          }
        }

      },
      dependencies = {
        'nvim-tree/nvim-web-devicons',
        'ryanoasis/vim-devicons',
      }
    },
    -- Comment code with gc
    {
      'tpope/vim-commentary',
    },
    {
      'fspv/sourcegraph.nvim',
      dependencies = {
        'nvim-lua/plenary.nvim',
      }
    },
    -- Status Line
    {
      'itchyny/lightline.vim',
      enabled = false,
      config = function()
        require("plugins_config/lightline_conf")
      end,
    },
    -- Status Line
    {
      'nvim-lualine/lualine.nvim',
      config = function()
        require("plugins_config/lualine_conf")
      end,
      dependencies = {
        'Bekaboo/dropbar.nvim',
        'arkav/lualine-lsp-progress',
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
              sign = { namespace = { "diagnostic" }, maxwidth = 2, auto = true },
              click = "v:lua.ScSa"
            },
            {
              text = { builtin.lnumfunc },
              click = "v:lua.ScLa",
            },
            {
              sign = { name = { ".*" }, maxwidth = 2, colwidth = 1, auto = true, wrap = true },
              click = "v:lua.ScSa"
            },
            {
              sign = { namespace = { "gitsigns" }, name = { ".*" }, maxwidth = 1, colwidth = 2, auto = false },
              click = "v:lua.ScSa",
            },
          }
        })
      end,
      dependencies = {
        "mfussenegger/nvim-dap",
        "lewis6991/gitsigns.nvim",
      }
    },
    -- Winbar dropdown
    {
      'Bekaboo/dropbar.nvim',
      dependencies = {
        'nvim-telescope/telescope-fzf-native.nvim',
        'nvim-tree/nvim-web-devicons',
      }
    },
    -- Alternative to fzf
    {
      'nvim-telescope/telescope.nvim',
      -- Go to definition is broken: https://github.com/nvim-telescope/telescope.nvim/issues/2690
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
        'nvim-telescope/telescope-live-grep-args.nvim',
        'nvim-telescope/telescope-smart-history.nvim'
      },
    },
    -- Fzf interface for telescope
    {
      'nvim-telescope/telescope-fzf-native.nvim',
      build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release',
    },
    -- Live grep with args
    {
      'nvim-telescope/telescope-live-grep-args.nvim',
    },
    {
      "nvim-telescope/telescope-file-browser.nvim",
      dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" }
    },
    -- Identation indication
    {
      "HiPhish/rainbow-delimiters.nvim",
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
      'andymass/vim-matchup',
      event = "BufReadPost",
      init = function()
        require("plugins_config/matchup_conf")
      end,
    },
    -- Debug
    {
      'stevearc/profile.nvim',
    },
    -- Show diagnostics window
    {
      'folke/trouble.nvim',
      cmd = { "Trouble", "TroubleToggle" },
      config = function()
        require("plugins_config/trouble_conf")
      end,
    },
    -- Tag bar
    -- {
    --   'simrat39/symbols-outline.nvim',
    --   config = function()
    --     require("plugins_config/symbols_outline_conf")
    --   end,
    -- },
    -- Show command help as you enter it
    {
      'folke/which-key.nvim',
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
      'voldikss/vim-floaterm',
      keys = {
        { "<leader>ft" },
      },
      init = function()
        require("plugins_config/floaterm_conf")
      end,
    },
    -- {
    --   "godlygeek/tabular",
    --   ft = "markdown",
    -- },
    {
      "preservim/vim-markdown",
      ft = "markdown",
    },
    -- Some fancy stuff
    {
      'ojroques/nvim-bufdel',

    },
    -- Modern folds
    -- TODO: Fix error https://github.com/kevinhwang91/nvim-ufo/blob/main/lua/ufo/decorator.lua#L145
    -- {
    --   'kevinhwang91/nvim-ufo',
    --   config = function()
    --     vim.o.foldcolumn = '0' -- '0' is not bad
    --     vim.o.foldlevel = 99   -- Using ufo provider need a large value, feel free to decrease the value
    --     vim.o.foldlevelstart = 99
    --     vim.o.foldenable = true

    --     -- Using ufo provider need remap `zR` and `zM`. If Neovim is 0.6.1, remap yourself
    --     vim.keymap.set('n', 'zR', require('ufo').openAllFolds)
    --     vim.keymap.set('n', 'zM', require('ufo').closeAllFolds)

    --     require('ufo').setup({
    --       provider_selector = function(bufnr, filetype, buftype)
    --         return { 'treesitter', 'indent' }
    --       end
    --     })
    --   end,
    --   dependencies = {
    --     'kevinhwang91/promise-async',
    --     'neovim/nvim-lspconfig',
    --   }
    -- },
    {
      "folke/noice.nvim",
      enabled = false,
      event = "VeryLazy",
      opts = {
        cmdline = {
          enabled = true,
          view = "cmdline",
        },
        lsp = {
          -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true,
          },
        },
        -- you can enable a preset for easier configuration
        presets = {
          bottom_search = true,         -- use a classic bottom cmdline for search
          command_palette = true,       -- position the cmdline and popupmenu together
          long_message_to_split = true, -- long messages will be sent to a split
          inc_rename = false,           -- enables an input dialog for inc-rename.nvim
          lsp_doc_border = false,       -- add a border to hover docs and signature help
        },
        signature = {
          enabled = true,
        }
      },
      dependencies = {
        -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
        "MunifTanjim/nui.nvim",
        -- OPTIONAL:
        --   `nvim-notify` is only needed, if you want to use the notification view.
        --   If not available, we use `mini` as the fallback
        "rcarriga/nvim-notify",
      }
    },
    -- Github Copilot
    {
      "github/copilot.vim",
      cmd = "Copilot",
    },
    {
      'TabbyML/vim-tabby',
    },
    -- Automatically format oneliners into multi-line code
    {
      "AndrewRadev/splitjoin.vim",
      keys = {
        { "gS", "gJ" },
      },
    },
    -- Treesitter based argwrap
    {
      "AckslD/nvim-trevJ.lua",
      init = function()
        vim.keymap.set(
          'n', '<leader>w', function()
            require('trevj').format_at_cursor()
          end,
          { desc = "Wrap arguments into multiple lines" }
        )
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
      'rmagatti/auto-session',
      init = function(self)
        vim.o.sessionoptions = "blank,buffers,curdir,help,tabpages,winsize,winpos,terminal,localoptions"
        vim.g.auto_session_pre_save_cmds = {
          "tabdo Neotree close",
          "tabdo UndotreeHide",
          "tabdo DiffviewClose",
          "tabdo Trouble diagnostics close",
        }
      end,
      config = function(self, opts)
        -- TODO: just a hack to make statuscol load before auto-session, to
        -- make sure the `statuscol` (`stc`) option is set for auto-loaded
        -- windows
        require("statuscol")
        require("auto-session").setup(
          {
            log_level = "error",
            -- TODO: not sure if this works
            silent_restore = false,
            auto_session_suppress_dirs = {},
            auto_session_use_git_branch = true,
            auto_restore_lazy_delay_enabled = true,
          }
        )
      end,
      dependencies = {
        -- Otherwise will not enable a correct statuscolumn
        "luukvbaal/statuscol.nvim",
      }
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
      init = function(self)
        vim.g.arduino_dir = "/snap/arduino/current"
      end,
      ft = { "arduino" },
    },
  }
)

-- TODO: assign this to some config module
vim.cmd("set completeopt=menu,menuone,noselect")

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
    vim.ui.input({ prompt = "Save profile to:", completion = "file", default = "profile.json" }, function(filename)
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
