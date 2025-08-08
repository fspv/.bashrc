-- Inspired by https://news.ycombinator.com/item?id=41738502

---@class WindowList
---@field window_map table<number, ListNode>  -- Map of window IDs to list nodes
local WindowList = {
  window_map = {}, -- Hashmap to map window IDs to list nodes
}

---@class ListNode
---@field value number|nil       -- Window ID
---@field next ListNode|nil       -- Next node in the list
---@field prev ListNode|nil       -- Previous node in the list
local ListNode = {}
ListNode.__index = ListNode

---@param value number|nil
---@return ListNode
function ListNode:new(value)
  ---@type ListNode
  local node = {
    value = value, -- Value
    next = nil, -- Next node in the list
    prev = nil, -- Previous node in the list
  }
  setmetatable(node, ListNode)
  return node
end

---@param win_id number
local function close_window(win_id)
  if vim.api.nvim_win_is_valid(win_id) then
    vim.api.nvim_win_close(win_id, true)
  end
  WindowList.window_map[win_id] = nil
end

---@param node ListNode
local function remove_node(node)
  local prev_node = node.prev
  local next_node = node.next

  if prev_node then
    prev_node.next = next_node
  end
  if next_node then
    next_node.prev = prev_node
  end

  -- TODO: move this to a custom destructor to make linked list implementation
  -- independent of windows
  close_window(node.value)
end

---@param node ListNode
local function remove_after(node)
  while node and node.next do
    remove_node(node.next)
  end
end

---@param cur_node ListNode
---@param new_node ListNode
local function add_node(cur_node, new_node)
  new_node.prev = cur_node
  new_node.next = cur_node.next
  if cur_node.next then
    cur_node.next.prev = new_node
  end
  cur_node.next = new_node

  WindowList.window_map[new_node.value] = new_node
end

-- Function to get all windows in double linked list
---@param node ListNode|nil
---@return number[] windows
local function get_all_values(node)
  local windows = {}
  local start_node = node
  while node do
    if node.value then
      table.insert(windows, node.value)
    end
    node = node.next
  end
  node = start_node
  while node do
    if node.value then
      table.insert(windows, node.value)
    end
    node = node.prev
  end
  return windows
end

-- Function to get the window ID matching wildcard (if exists)
---@param wildcard string
---@return integer | nil
local function get_window_id_matching_wildcard(wildcard)
  -- Get a list of all windows in the current tabpage
  local windows = vim.api.nvim_tabpage_list_wins(0)

  for _, win_id in ipairs(windows) do
    -- Get the buffer associated with the window
    local buf_id = vim.api.nvim_win_get_buf(win_id)

    -- Get the name of the buffer
    local buf_name = vim.api.nvim_buf_get_name(buf_id)

    -- Check if the buffer name contains "neo-tree"
    if string.match(buf_name, wildcard) then
      return win_id
    end
  end

  return nil
end

-- Function to open a new window and manage the list structure
--- @param f fun(): fun(): nil
---@return nil
function OpenWindow(f)
  local prev_win_id = vim.api.nvim_get_current_win()

  if not WindowList.window_map[prev_win_id] then
    local new_root_node = ListNode:new(prev_win_id)
    WindowList.window_map[prev_win_id] = new_root_node
  end

  local node = WindowList.window_map[prev_win_id]
  remove_after(node)

  vim.api.nvim_command("set splitright")
  vim.api.nvim_command("vsplit")
  vim.api.nvim_command("wincmd l")
  f()

  local new_win_id = vim.api.nvim_get_current_win()
  add_node(WindowList.window_map[prev_win_id], ListNode:new(new_win_id))

  ResizeWindows(prev_win_id, new_win_id)
end

-- Function to resize windows based on list relationships
---@param prev_win_id number
---@param cur_win_id number
---@return nil
function ResizeWindows(prev_win_id, cur_win_id)
  if prev_win_id == cur_win_id then
    return
  end

  local prev_node = WindowList.window_map[prev_win_id]
  local cur_node = WindowList.window_map[cur_win_id]

  if not prev_node or not cur_node then
    return
  end

  local neotree_window = get_window_id_matching_wildcard("neo%-tree")
  local windows_to_exclude = { neotree_window }
  local total_width =
    vim.api.nvim_get_option_value("columns", { scope = "global" })

  for _, window_to_exclude in ipairs(windows_to_exclude) do
    total_width = total_width - vim.api.nvim_win_get_width(window_to_exclude)
  end

  local windows_to_resize = get_all_values(cur_node)

  local remaining_width = total_width - (#windows_to_resize * 1)
  local half_width = math.floor(remaining_width / 2)

  -- Shrink all the windows except for the previous and the current one
  for _, win_id in ipairs(windows_to_resize) do
    if win_id ~= prev_win_id and win_id ~= cur_win_id then
      if vim.api.nvim_win_is_valid(win_id) then
        vim.api.nvim_win_set_width(win_id, 1)
      end
    end
  end

  -- Maximise the prevoious and the current window
  if vim.api.nvim_win_is_valid(prev_win_id) then
    vim.api.nvim_win_set_width(prev_win_id, half_width)
  end
  if vim.api.nvim_win_is_valid(cur_win_id) then
    vim.api.nvim_win_set_width(cur_win_id, half_width)
  end
end

-- Track the previous window
local prev_win_id = nil

-- Autocommand to track window changes and trigger ResizeWindows
vim.api.nvim_create_autocmd({ "WinEnter" }, {
  callback = function()
    local cur_win_id = vim.api.nvim_get_current_win()

    if prev_win_id then
      ResizeWindows(prev_win_id, cur_win_id)
    end

    prev_win_id = cur_win_id
  end,
})

return {
  ResizeWindows = ResizeWindows,
  OpenWindow = OpenWindow,
}
