-- `#is?` / `#is-not?` predicates, used by grammar-provided highlight queries
-- to skip patterns for names bound in the local scope. Neovim has no built-in
-- handler for them, so they are answered here from the language's locals
-- query, the way nvim-treesitter used to.
--
-- Both call shapes are supported:
--   ((identifier) @variable.builtin (#is-not? local))
--   ((identifier) @variable.parameter (#is? @variable.parameter parameter))
local M = {}

---@class LocalDefinition
---@field kind string
---@field scope TSNode

---@class DefinitionsCacheEntry
---@field tick integer
---@field trees table<string, table<string, LocalDefinition[]>>

---@type table<integer, DefinitionsCacheEntry>
local definitions_cache = {}

---@param root TSNode
---@param language string
---@param source integer
---@return table<string, LocalDefinition[]>
local function collect_definitions(root, language, source)
  local query = vim.treesitter.query.get(language, "locals")
  if not query then
    return {}
  end

  local scope_ids = {}
  local captured_definitions = {}

  for id, node in query:iter_captures(root, source) do
    local capture = query.captures[id] --[[@as string]]
    -- Some grammars still ship the pre-`local.` capture names, e.g. `@scope`
    -- and `@definition.parameter`.
    local kind = capture:match("^local%.definition%.?(.*)$")
      or capture:match("^definition%.?(.*)$")
    if capture == "local.scope" or capture == "scope" then
      scope_ids[node:id()] = true
    elseif kind then
      table.insert(captured_definitions, {
        node = node,
        kind = kind ~= "" and kind or "local",
      })
    end
  end

  ---@type table<string, LocalDefinition[]>
  local definitions = {}
  for _, definition in ipairs(captured_definitions) do
    local scope = definition.node
    while scope:parent() and not scope_ids[scope:id()] do
      scope = scope:parent()
    end
    local name = vim.treesitter.get_node_text(definition.node, source)
    definitions[name] = definitions[name] or {}
    table.insert(definitions[name], { kind = definition.kind, scope = scope })
  end
  return definitions
end

---@param root TSNode
---@param language string
---@param source integer
---@return table<string, LocalDefinition[]>
local function cached_definitions(root, language, source)
  local tick = vim.api.nvim_buf_get_changedtick(source)
  local cached = definitions_cache[source]
  if not cached or cached.tick ~= tick then
    cached = { tick = tick, trees = {} }
    definitions_cache[source] = cached
  end

  local key = root:id() .. language
  if not cached.trees[key] then
    cached.trees[key] = collect_definitions(root, language, source)
  end
  return cached.trees[key]
end

-- Kind of the innermost definition of the node's name visible from the node.
---@param node TSNode
---@param source integer
---@return string|nil
local function visible_definition_kind(node, source)
  local range = { node:range() }
  local parser = assert(vim.treesitter.get_parser(source))
  local language = parser:language_for_range(range):lang()
  local definitions = cached_definitions(node:tree():root(), language, source)
  local name = vim.treesitter.get_node_text(node, source)

  local kind = nil
  local innermost_scope_start = -1
  for _, definition in ipairs(definitions[name] or {}) do
    local _, _, scope_start = definition.scope:start()
    if
      scope_start > innermost_scope_start
      and vim.treesitter.node_contains(definition.scope, range)
    then
      kind = definition.kind
      innermost_scope_start = scope_start
    end
  end
  return kind
end

-- Nil when the referenced capture took part in no node of this match, in which
-- case the predicate has nothing to say and the pattern applies.
---@param captures table<integer, TSNode[]>
---@param predicate (string|integer)[]
---@return TSNode|nil
local function predicate_node(captures, predicate)
  for index = 2, #predicate do
    local capture_id = predicate[index]
    if type(capture_id) == "number" then
      return (captures[capture_id] or {})[1]
    end
  end

  -- No explicit capture: the predicate applies to the pattern's own capture.
  local capture_ids = vim.tbl_keys(captures)
  table.sort(capture_ids)
  return captures[capture_ids[1]][1]
end

---@param predicate (string|integer)[]
---@return string
local function requested_kind(predicate)
  for index = 2, #predicate do
    local kind = predicate[index]
    if type(kind) == "string" then
      return kind
    end
  end
  error("#is?/#is-not? requires a definition kind argument")
end

---@param captures table<integer, TSNode[]>
---@param source integer
---@param predicate (string|integer)[]
---@return boolean|nil
local function is_local_definition(captures, source, predicate)
  local node = predicate_node(captures, predicate)
  if not node then
    return nil
  end

  local kind = visible_definition_kind(node, source)
  if not kind then
    return false
  end
  -- Kinds are spelled both bare (`parameter`) and prefixed
  -- (`local.parameter`) across grammars.
  local wanted = requested_kind(predicate)
  return wanted == "local" or wanted == kind or wanted == "local." .. kind
end

---@return nil
function M.setup()
  -- Cached scope nodes keep the buffer's syntax trees alive.
  vim.api.nvim_create_autocmd("BufDelete", {
    group = vim.api.nvim_create_augroup("treesitter_locals_predicates", {}),
    callback = function(args)
      definitions_cache[args.buf] = nil
    end,
  })

  vim.treesitter.query.add_predicate(
    "is?",
    function(captures, _pattern, source, predicate)
      local matched =
        is_local_definition(captures, source --[[@as integer]], predicate)
      return matched == nil or matched
    end,
    { force = true }
  )

  vim.treesitter.query.add_predicate(
    "is-not?",
    function(captures, _pattern, source, predicate)
      local matched =
        is_local_definition(captures, source --[[@as integer]], predicate)
      return matched == nil or not matched
    end,
    { force = true }
  )
end

return M
