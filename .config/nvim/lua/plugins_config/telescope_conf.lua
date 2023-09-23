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

vim.keymap.set("n", "ts/", require("telescope.builtin").lsp_document_symbols, {})
vim.keymap.set("n", "tf/", require("telescope.builtin").git_files, {})
vim.keymap.set("n", "tc/", require("telescope").extensions.live_grep_args.live_grep_args, {})
vim.keymap.set("n", "tr/", require("telescope.builtin").resume, {})
vim.keymap.set("n", "tt/", require("telescope.builtin").pickers, {})
