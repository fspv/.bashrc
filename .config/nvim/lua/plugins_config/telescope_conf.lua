---Append a suffix string to the current Telescope prompt
---@param suffix string
---@return function
local _append_to_telescope_prompt = function(suffix)
  ---@param prompt_bufnr any
  return function(prompt_bufnr)
    local action_state = require("telescope.actions.state")
    local picker = action_state.get_current_picker(prompt_bufnr)
    local prompt = picker:_get_prompt()
    picker:set_prompt(prompt .. suffix)
  end
end

require("telescope").setup(
  {
    defaults = {
      layout_strategy = "vertical",
      path_display = { "truncate" },
      dynamic_preview_title = true,
      fname_width = 90,
      layout_config = {
        mirror = true,
        preview_cutoff = 10,
        vertical = {
          width = 0.9,
          height = 0.9
        },
      },
      history = {
        path = '~/.local/share/nvim/telescope_history.sqlite3',
        limit = 100,
      },
      -- open files in the first window that is an actual file.
      -- use the current window if no other window is available.
      get_selection_window = function()
        local wins = vim.api.nvim_list_wins()
        table.insert(wins, 1, vim.api.nvim_get_current_win())
        for _, win in ipairs(wins) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].buftype == "" then
            return win
          end
        end
        return 0
      end,
    },
    pickers = {
      lsp_references = { fname_width = 120 },
      lsp_implementations = { fname_width = 120 },
      lsp_definitions = { fname_width = 120 },
      lsp_type_definitions = { fname_width = 120 },
    },
    extensions = {
      live_grep_args = {
        auto_quoting = true,
        mappings = {
          i = {
            ["<C-a>"] = require("telescope-live-grep-args.actions").quote_prompt(),
            ["<C-i>"] = _append_to_telescope_prompt("--iglob !**{test,e2e,sat,experimental,fake,mock}* --iglob "),
          },
          n = {
            ["<C-Down>"] = require('telescope.actions').cycle_history_next,
            ["<C-Up>"] = require('telescope.actions').cycle_history_prev,
          },
        },
      },
      file_browser = {
        theme = "ivy",
        -- disables netrw and use telescope-file-browser in its place
        hijack_netrw = true,
        mappings = {
          ["i"] = {
            -- your custom insert mode mappings
          },
          ["n"] = {
            -- your custom normal mode mappings
          },
        },
      },
    }
  }
)

-- To get extension loaded and working with telescope, you need to call
-- load_extension, somewhere after setup function:
require("telescope").load_extension("fzf")
require("telescope").load_extension("sourcegraph")
require("telescope").load_extension("live_grep_args")
require("telescope").load_extension("file_browser")
require('telescope').load_extension("smart_history")

vim.keymap.set(
  "n",
  "z/",
  require("telescope.builtin").current_buffer_fuzzy_find,
  { desc = "Fuzzy Buffer Content Search" }
)
vim.keymap.set(
  "n",
  "f",
  require("telescope-live-grep-args.shortcuts").grep_word_under_cursor,
  {
    desc = "Search Word Under cursor",
  }
)
vim.keymap.set(
  "v",
  "f",
  require("telescope-live-grep-args.shortcuts").grep_visual_selection,
  { desc = "Search Visual Selection" }
)
vim.keymap.set(
  "n",
  "fs/",
  require("telescope.builtin").lsp_document_symbols,
  { desc = "Search Document Symbols" }
)
vim.keymap.set(
  "n",
  "ff/",
  require("telescope.builtin").git_files,
  { desc = "Search Git Files" }
)
vim.keymap.set(
  "n",
  "fc/",
  require("telescope").extensions.live_grep_args.live_grep_args,
  { desc = "Live Grep (with args)" }
)
vim.keymap.set(
  "n",
  "fr/",
  require("telescope.builtin").resume,
  { desc = "Resume the previous search" }
)
vim.keymap.set(
  "n",
  "ft/",
  require("telescope.builtin").pickers,
  { desc = "Search Open Telescope Pickers" }
)
vim.keymap.set(
  "n",
  "fo/",
  function() require("telescope.builtin").live_grep({ grep_open_files = true }) end,
  { desc = "Search Open Files" }
)
vim.keymap.set(
  "n",
  "<C-e>",
  require("telescope").extensions.smart_open.smart_open,
  { desc = "Smart Open" }
)
