require("telescope").load_extension("sourcegraph")
require("telescope").load_extension("live_grep_args")

local _live_grep_args_actions = require("telescope-live-grep-args.actions")

local _telescope_live_grep_called = false

local _telescope_resume = function(func)
  local _telescope_resume_wrapped = function(opts)
    local telescope = require("telescope.builtin")

    if _telescope_live_grep_called then
      telescope.resume()
    else
      func(opts)
      _telescope_live_grep_called = true
    end
  end

  return _telescope_resume_wrapped
end

require("telescope").setup(
  {
    extensions = {
      live_grep_args = {
        auto_quoting = true, -- enable/disable auto-quoting
        -- define mappings, e.g.
        mappings = {
          -- extend mappings
          i = {
            ["<C-a>"] = _live_grep_args_actions.quote_prompt(),
            ["<C-i>"] = _live_grep_args_actions.quote_prompt({ postfix = " --iglob " }),
          },
        },
        -- ... also accepts theme settings, for example:
        -- theme = "dropdown", -- use dropdown theme
        -- theme = { }, -- use own theme spec
        -- layout_config = { mirror=true }, -- mirror preview pane
      }
    }
  }
)

-- To get fzf loaded and working with telescope, you need to call
-- load_extension, somewhere after setup function:
require('telescope').load_extension("fzf")

vim.keymap.set("n", "ts/", require("telescope.builtin").lsp_document_symbols, { desc = "Search Document Symbols" })
vim.keymap.set("n", "tf/", require("telescope.builtin").git_files, { desc = "Search Git Files" })
vim.keymap.set("n", "tc/", require("telescope").extensions.live_grep_args.live_grep_args,
  { desc = "Live Grep (with args)" })
vim.keymap.set("n", "tr/", require("telescope.builtin").resume, { desc = "Resume the previous search" })
vim.keymap.set("n", "tt/", require("telescope.builtin").pickers, { desc = "Search Open Telescope Pickers" })
vim.keymap.set("n", "to/", function() require("telescope.builtin").live_grep({ grep_open_files = true }) end,
  { desc = "Search Open Files" })
