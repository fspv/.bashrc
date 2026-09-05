---Append a suffix string to the current Telescope prompt
---@param suffix string
---@return fun(prompt_bufnr: integer)
local _append_to_telescope_prompt = function(suffix)
  ---@param prompt_bufnr integer
  ---@return nil
  return function(prompt_bufnr)
    local action_state = require("telescope.actions.state")
    local picker = action_state.get_current_picker(prompt_bufnr)
    local prompt = picker:_get_prompt()
    picker:set_prompt(prompt .. suffix)
  end
end

--- Go one directory up in a telescope picker session.
--- This closes the current picker and reopens it with the parent
--- directory as cwd.
---@param reopen_fn fun(opts: table) Function to reopen the picker with
--- new options
---@return fun(prompt_bufnr: integer)
local function make_go_up_one_dir(reopen_fn)
  ---@param prompt_bufnr integer
  ---@return nil
  return function(prompt_bufnr)
    local action_state = require("telescope.actions.state")
    local actions = require("telescope.actions")

    local picker = action_state.get_current_picker(prompt_bufnr)
    local prompt = picker:_get_prompt()

    -- Get the current cwd from the picker
    -- (file_browser stores it in finder.cwd)
    local current_cwd = assert(
      picker.cwd or (picker.finder and picker.finder.cwd) or vim.uv.cwd()
    )

    -- Don't go above root
    if current_cwd == "/" then
      vim.notify("Already at root directory", vim.log.levels.WARN)
      return
    end

    -- Get parent directory
    local parent_dir = vim.fn.fnamemodify(current_cwd, ":h")

    -- Close current picker
    actions.close(prompt_bufnr)

    -- Reopen the picker with the parent directory and preserved prompt
    reopen_fn({
      cwd = parent_dir,
      path = parent_dir,
      default_text = prompt,
    })
  end
end

local live_grep_go_up_one_dir = make_go_up_one_dir(
  ---@param opts table
  ---@return nil
  function(opts)
    require("telescope").extensions.live_grep_args.live_grep_args(opts)
  end
)

--- A helper function to run a command and get its output as a table of lines.
--- It will return an empty table if the command fails.
---@param command string The shell command to execute.
---@return string[] A table of strings, where each string is a line of the
---command's output.
local function get_command_output(command)
  -- We use pcall to safely run the command. If it errors, we don't crash.
  local ok, result = pcall(vim.fn.systemlist, command)
  if ok and type(result) == "table" then
    return result
  else
    return {}
  end
end

--- A helper function to find the search root of the current buffer.
--- It will return the current working directory if no project marker is found.
---@return string The absolute path to the project root.
local function buffer_search_root()
  return vim.fs.root(0, {
    {
      ".git",
      "_darcs",
      ".hg",
      ".bzr",
      ".svn",
      "package.json",
      "library.properties",
      "go.mod",
      "go.work",
      "Cargo.toml",
      "BUILD.bazel",
      "BUILD",
      "MODULE.bazel",
      "WORKSPACE.bazel",
      "WORKSPACE",
    },
  }) or vim.fn.getcwd()
end

--- Gathers, de-duplicates, and displays a list of files from git, open buffers,
--- and the current directory.
---
--- The file sources are:
--- 1. New or modified files from `git ls-files`.
--- 2. Files changed since the git upstream branch.
--- 3. Files from currently open and listed buffers.
--- 4. Files in the same directory as the current buffer.
---
---@param opts? table Optional Telescope configuration to pass
---to the picker.
---@return nil
local function recent_and_modified_files(opts)
  opts = opts or {}
  opts.cwd = opts.cwd or buffer_search_root()
  local project_root = opts.cwd
  ---@type table<string, boolean>
  local file_set = {}
  local path_sep = vim.fn.has("win32") == 1 and "\\" or "/"

  -- Ensure project_root has a trailing separator for clean replacement later.
  if not project_root:find(path_sep .. "$", 1, true) then
    project_root = project_root .. path_sep
  end

  -- Helper function to add a path to the set, ensuring it's relative to the
  -- project root. This is the key to fixing the sorting issue.
  ---@param path_to_add string
  ---@return nil
  local function add_file_relative(path_to_add)
    if path_to_add and path_to_add ~= "" then
      local abs_path = vim.fn.fnamemodify(path_to_add, ":p")
      -- Make path relative by removing the project root prefix.
      local final_path = abs_path:gsub(project_root, "", 1)
      file_set[final_path] = true
    end
  end

  -- 1. Get new or modified files from `git ls-files`
  local git_status_files =
    get_command_output("git ls-files --modified --others --exclude-standard")
  for _, file in ipairs(git_status_files) do
    add_file_relative(file)
  end

  -- 2. Get files changed since the upstream branch
  local upstream_branch_list =
    get_command_output("git rev-parse --abbrev-ref --symbolic-full-name @{u}")
  if #upstream_branch_list > 0 then
    local upstream_branch = upstream_branch_list[1]
    local git_diff_files = get_command_output(
      "git diff --name-only " .. upstream_branch .. "...HEAD"
    )
    for _, file in ipairs(git_diff_files) do
      add_file_relative(file)
    end
  else
    vim.notify(
      "No upstream branch found for git diff.",
      vim.log.levels.INFO,
      { title = "Telescope" }
    )
  end

  -- 3. Get files from currently open buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.api.nvim_get_option_value("buflisted", { buf = bufnr })
      and vim.bo[bufnr].buftype == ""
    then
      local file_path = vim.api.nvim_buf_get_name(bufnr)
      add_file_relative(file_path)
    end
  end

  -- 4. Get files from the same directory as the current file
  local current_file_path = vim.api.nvim_buf_get_name(0)
  if current_file_path and current_file_path ~= "" then
    local current_dir = vim.fn.fnamemodify(current_file_path, ":p:h")
    local list_command
    if vim.fn.has("win32") == 1 then
      -- On Windows, list files only, excluding directories.
      list_command = 'dir /b /a-d "' .. current_dir .. '"'
    else
      -- On Unix-like systems, use `find` to reliably list only files in the
      -- current directory.
      list_command = 'find "'
        .. current_dir
        .. '" -maxdepth 1 -type f -printf "%f\\n"'
    end
    local files_in_dir = get_command_output(list_command)
    for _, file in ipairs(files_in_dir) do
      if file ~= "" then
        add_file_relative(current_dir .. path_sep .. file)
      end
    end
  end

  ---@type string[]
  local final_files = {}
  for file, _ in pairs(file_set) do
    table.insert(final_files, file)
  end

  -- This sort will now work correctly on a consistent list of relative paths.
  table.sort(final_files)

  -- Find the index of the currently open file to set as the default selection.
  local current_file_relative = nil
  if current_file_path and current_file_path ~= "" then
    current_file_relative =
      vim.fn.fnamemodify(current_file_path, ":p"):gsub(project_root, "", 1)
  end

  local selection_idx = 1 -- Default to the first item
  if current_file_relative then
    for i, file in ipairs(final_files) do
      if file == current_file_relative then
        selection_idx = i
        break
      end
    end
  end

  -- Now, create and launch the Telescope picker
  require("telescope.pickers")
    .new(opts, {
      prompt_title = "Recent & Modified Files",
      finder = require("telescope.finders").new_table({
        results = final_files,
        entry_maker = require("telescope.make_entry").gen_from_file(opts),
      }),
      sorter = require("telescope.sorters").get_fuzzy_file(opts),
      previewer = require("telescope.previewers").vim_buffer_cat.new(opts),
      default_selection_index = selection_idx,
      ---@param prompt_bufnr number
      ---@param map fun(mode: "i"|"n", key: string, action: function)
      attach_mappings = function(prompt_bufnr, map)
        map("i", "<c-v>", function()
          require("telescope.actions").close(prompt_bufnr)
          local entry = require("telescope.actions.state").get_selected_entry()
          if entry then
            vim.cmd("vsplit " .. vim.fn.fnameescape(entry.value))
          end
        end)
        return true
      end,
    })
    :find()
end

require("telescope").setup({
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
        height = 0.9,
      },
    },
    history = {
      limit = 100,
    },
    -- open files in the first window that is an actual file.
    -- use the current window if no other window is available.
    ---@return integer
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
          ["<C-a>"] = require("telescope-live-grep-args.actions").quote_prompt(
            -- No args
          ),
          ["<C-x>"] = _append_to_telescope_prompt(
            "--iglob !**{test,e2e,sat,experimental,fake,mock}* "
          ),
          ["<C-h>"] = live_grep_go_up_one_dir,
        },
        n = {
          ["<Down>"] = require("telescope.actions").cycle_history_next,
          ["<Up>"] = require("telescope.actions").cycle_history_prev,
          j = require("telescope.actions").cycle_history_next,
          k = require("telescope.actions").cycle_history_prev,
          ["<C-h>"] = live_grep_go_up_one_dir,
        },
      },
    },
  },
})

-- To get extension loaded and working with telescope, you need to call
-- load_extension, somewhere after setup function:
require("telescope").load_extension("fzf")
require("telescope").load_extension("live_grep_args")

vim.keymap.set(
  "n",
  "z/",
  ---@return nil
  function()
    require("telescope.builtin").current_buffer_fuzzy_find({
      default_text = vim.fn.expand("<cword>"),
    })
  end,
  { desc = "Fuzzy search word under cursor in the current buffer" }
)
vim.keymap.set(
  "n",
  "g/",
  ---@return nil
  function()
    require("telescope-live-grep-args.shortcuts").grep_word_under_cursor({
      cwd = buffer_search_root(),
    })
  end,
  { desc = "Search Word Under cursor" }
)
vim.keymap.set(
  "v",
  "g/",
  ---@return nil
  function()
    require("telescope-live-grep-args.shortcuts").grep_visual_selection({
      cwd = buffer_search_root(),
    })
  end,
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
  ---@return nil
  function()
    require("telescope.builtin").git_files({
      cwd = buffer_search_root(),
      use_git_root = false,
    })
  end,
  { desc = "Search Git Files" }
)
vim.keymap.set(
  "n",
  "fc/",
  ---@return nil
  function()
    require("telescope").extensions.live_grep_args.live_grep_args({
      cwd = buffer_search_root(),
    })
  end,
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
  ---@return nil
  function()
    require("telescope.builtin").live_grep({
      grep_open_files = true,
      cwd = buffer_search_root(),
    })
  end,
  { desc = "Search Open Files" }
)
vim.keymap.set(
  "n",
  "<C-e>",
  ---@return nil
  function()
    require("telescope").extensions.smart_open.smart_open({
      cwd = buffer_search_root(),
    })
  end,
  { desc = "Smart Open" }
)
vim.keymap.set(
  "n",
  "<leader>r",
  recent_and_modified_files,
  { desc = "Find recent & modified files" }
)
