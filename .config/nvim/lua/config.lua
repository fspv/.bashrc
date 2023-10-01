---Check if such s plug loaded via vim plug
---@param plug_name string
---@return boolean
local has_plug = function(plug_name)
  local result = false
  local plugs = {}

  if vim.g.plugs ~= nil
  then
    plugs = vim.g.plugs
  end

  for key, value in pairs(plugs) do
    result = result or (key == plug_name)
  end

  if result
  then
    -- Debug
    -- vim.print("Plugin " .. plug_name .. " exists")
  else
    vim.print("Plugin " .. plug_name .. " doesn't exist, run :PlugInstall")
  end

  return result
end

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
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
    },

    -- Syntax highlighting and code navidation
    {
      'nvim-treesitter/nvim-treesitter',
      lazy = true,
      build = ':TSInstall all',
      cmd = { "TSUpdateSync" },
      config = function()
        require("plugins_config/treesitter_conf")
      end,
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
      ft = 'arcanist',
      config = function()
        require("plugins_config/arcanist_conf")
      end,
    },

    -- # Completion

    -- Completion icons
    {
      'onsails/lspkind.nvim',
      lazy = true,
    },
    -- Show function signature when you type
    {
      'ray-x/lsp_signature.nvim',
      lazy = true,
    },
    {
      'hrsh7th/cmp-nvim-lsp',
      lazy = true,
    },
    -- Source for buffer words
    {
      'hrsh7th/cmp-buffer',
      lazy = false,
    },
    -- Source for filesystem paths
    {
      'hrsh7th/cmp-path',
      lazy = false,
    },
    -- Source for vim cmdline
    {
      'hrsh7th/cmp-cmdline',
      lazy = false,
    },
    -- VSCode(LSP)'s snippet feature
    {
      'hrsh7th/vim-vsnip',
      lazy = true,
      config = function()
        require("plugins_config/vsnip_conf")
      end,
    },
    -- Snippet completion and expansion integration
    {
      'hrsh7th/vim-vsnip-integ',
      lazy = true,
    },
    -- Snippets collection for a set of different programming languages
    {
      'rafamadriz/friendly-snippets',
      lazy = true,
    },
    -- Source for vsnip
    {
      'hrsh7th/cmp-vsnip',
      lazy = true,
      dependencies = {
        'hrsh7th/vim-vsnip',
        'hrsh7th/vim-vsnip-integ',
        'rafamadriz/friendly-snippets',
      },
    },
    -- Completion engine
    {
      'hrsh7th/nvim-cmp',
      lazy = true,
      event = 'InsertEnter',
      config = function()
        require("plugins_config/cmp_conf")
      end,
      dependencies = {
        'hrsh7th/cmp-nvim-lsp',
        'hrsh7th/cmp-buffer',
        'hrsh7th/cmp-path',
        'hrsh7th/cmp-cmdline',
        'hrsh7th/cmp-vsnip',
        'ray-x/lsp_signature.nvim',
        'onsails/lspkind.nvim',
      }
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
        'neovim/nvim-lspconfig',
      },
    },
    -- Main LSP plugin
    {
      'neovim/nvim-lspconfig',
      lazy = true,
      cmd = 'LspInfo',
      event = { 'BufReadPre', 'BufNewFile' },
      config = function()
        require("plugins_config/lsp_conf")
      end,
      dependencies = {
        'nvim-treesitter/nvim-treesitter',
        'nvim-tree/nvim-web-devicons',
        'williamboman/mason-lspconfig.nvim',
        'hrsh7th/cmp-nvim-lsp',
        'VonHeikemen/lsp-zero.nvim',
        'glepnir/lspsaga.nvim',
      },
    },
    -- Highlight other uses of symbol under cursor
    {
      'RRethy/vim-illuminate',
      lazy = false,
      dependencies = {
        'neovim/nvim-lspconfig',
      },
    },
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
      build = 'fzf#install()',
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
      lazy = false,
    },
    -- Auto-complete matching quotes, brackets, etc
    {
      'raimondi/delimitMate',
      lazy = false,
    },
    {
      'nvim-tree/nvim-tree.lua',
      cmd = 'NvimTreeOpen',
      config = function()
        require("plugins_config/nvimtree_conf")
      end,
    },
    -- Faster navigation
    {
      'easymotion/vim-easymotion',
      lazy = false,
    },
    -- Highlight incremental search
    {
      'haya14busa/incsearch.vim',
      lazy = false,
    },
    -- Highlight incremental search
    {
      'haya14busa/incsearch-fuzzy.vim',
      lazy = false,
    },
    -- Easymotion integration for for incremental fuzzy search
    {
      'haya14busa/incsearch-easymotion.vim',
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
      cmd = 'CtrlP',
      keys = {
        { "<C-P>" },
      },
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
    },
    -- Show modifications in sign column
    {
      'mhinz/vim-signify',
      lazy = false,
    },
    -- Solidity smart contracts plugin
    {
      'tomlion/vim-solidity',
      ft = 'solidity',
    },
    -- File tree (also support symbols)
    {
      'nvim-neo-tree/neo-tree.nvim',
      cmd = 'NeoTree',
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
    {
      'fatih/vim-go',
      ft = "go",
      build = ':GoUpdateBinaries',
      config = function()
        require("plugins_config/vim_go_conf")
      end,
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
      config = function()
        require("plugins_config/please_conf")
      end,
      cmd = 'Please',
      keys = {
        "<leader>pj",
        "<leader>pb",
        "<leader>pt",
        "<leader>pct",
        "<leader>plt",
        "<leader>pft",
        "<leader>pr",
        "<leader>py",
        "<leader>pd",
        "<leader>pa",
        "<leader>pp",
      },
    },
    {
      'kosayoda/nvim-lightbulb',
      config = function()
        require("plugins_config/lightbulb_conf")
      end,
    },
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
      config = function()
        require("plugins_config/barbar_conf")
      end,
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
    },
    -- Alternative to fzf
    {
      'nvim-telescope/telescope.nvim',
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
        'nvim-telescope/telescope-live-grep-args.nvim'
      },
    },
    -- Live grep with args
    {
      'nvim-telescope/telescope-live-grep-args.nvim',
    },
    -- Identation indication for spaces
    {
      'Yggdroot/indentLine',
    },
    -- Matching parentheses improvement
    {
      'andymass/vim-matchup',
      config = function()
        require("plugins_config/matchup_conf")
      end,
    },
    {
      'stevearc/profile.nvim',
    },
    -- Show diagnostics window
    {
      'folke/trouble.nvim',
      config = function()
        require("plugins_config/trouble_conf")
      end,
    },
    -- Tag bar
    {
      'simrat39/symbols-outline.nvim',
      config = function()
        require("plugins_config/symbols_outline_conf")
      end,
    },
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
  vim.keymap.set("", "<leader>xx", toggle_profile)
  require("profile").instrument_autocmds()
  if should_profile:lower():match("^start") then
    require("profile").start("*")
  else
    require("profile").instrument("*")
  end
end
