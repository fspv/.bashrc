local cur_dir = function(state)
  -- TODO: return type string
  local p = state.tree:get_node().path
  print(p) -- show in command line
  return p
end

---Returns true if path is a directory
---@param path string
---@return boolean
local function is_dir(path)
  local f = io.open(path, "r")
  if f == nil then
    return false
  end

  local ok, err, code = f:read(1)
  f:close()
  return code == 21
end

local function getPath(str)
  local p = str:match("(.*[/\\])")
  if string.sub(p, -1, -1) == "/" then
    p = string.sub(p, 1, -2)
  end
  return p
end

require("neo-tree").setup(
  {
    use_popups_for_input = false, -- not floats for input
    hide_dotfiles = false,
    enable_cursor_hijack = false,
    commands = {
      grep = function(state)
        local path = cur_dir(state)
        -- if not is_dir(path) then
        --   path = getPath(path)
        -- end
        require("telescope").extensions.live_grep_args.live_grep_args(
          {
            cwd = cur_dir(state),
            prompt_title = string.format('LiveGrep in [%s]', path),

          }
        )
      end,
    },
    window = {
      auto_expand_width = false,
      --c(d), z(p)
      mappings = {
        ["f"] = "grep",
      },
    },
    source_selector = {
      winbar = true,
      statusline = false,
      tabs_layout = "equal",
      sources = {
        {
          source = "filesystem",
          display_name = " 󰉓 Files "
        },
        {
          source = "git_status",
          display_name = " 󰊢 Git "
        },
      }
    },
    sources = { "filesystem", "git_status" },
    default_component_configs = {
      indent = {
        with_expanders = true,
        expander_collapsed = "",
        expander_expanded = "",
        expander_highlight = "NeoTreeExpander",
      },
    },
    filesystem = {
      follow_current_file = {
        enabled = true,
        leave_dirs_open = true,
      },
      filtered_items = {
        visible = false,
        hide_dotfiles = false,
        hide_gitignored = true,
      },
      last_modified = {
        enabled = false,
      },
      created = {
        enabled = false,
      },
      file_size = {
        enabled = false,
      },
      type = {
        enabled = false,
      },
    },
    buffers = {
      follow_current_file = {
        enabled = false,
        leave_dirs_open = true,
      },
    },
  }
)

vim.keymap.set("n", "<Leader>nn", "<cmd>Neotree<CR>", { noremap = true, desc = "Neo Tree" })

-- TODO: decide what to do with netrw (which is also configured in nvimtree)
-- https://github.com/nvim-neo-tree/neo-tree.nvim/blob/main/doc/neo-tree.txt#L934
