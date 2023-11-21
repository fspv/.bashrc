local cur_dir = function(state)
  -- TODO: return type string
  local p = state.tree:get_node().path
  print(p) -- show in command line
  return p
end

local function is_dir(path)
  local f = io.open(path, "r")
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
      --c(d), z(p)
      mappings = {
        ["g"] = "grep",
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
          source = "buffers",
          display_name = " 󰈚 Buffers "
        },
        {
          source = "git_status",
          display_name = " 󰊢 Git "
        },
        {
          source = "document_symbols",
          display_name = " 󰡱 Symbols "
        },
      }
    },
    sources = { "filesystem", "buffers", "git_status", "document_symbols" },
    filesystem = {
      follow_current_file = {
        enabled = true,
        leave_dirs_open = false,
      },
    },
    buffers = {
      follow_current_file = {
        enabled = true,
        leave_dirs_open = false,
      },
    },
  }
)

vim.keymap.set("n", "<Leader>nn", "<cmd>Neotree<CR>", { noremap = true, desc = "Neo Tree" })

-- TODO: decide what to do with netrw (which is also configured in nvimtree)
-- https://github.com/nvim-neo-tree/neo-tree.nvim/blob/main/doc/neo-tree.txt#L934
