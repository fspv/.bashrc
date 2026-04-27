-- Build a permanent GitHub blob URL for the file/lines under the cursor.
--
-- "Permanent" means the URL pins a commit SHA that is known to exist on the
-- remote: the merge-base between HEAD and the default branch of the tracking
-- remote (or `origin` as a fallback). This avoids:
--   * `master`/`main` URLs that drift over time
--   * URLs pointing to local-only commits that GitHub can't resolve

---@class GhLink
local M = {}

---Opts table neovim hands to a `nvim_create_user_command` callback. Only the
---fields we actually consume are listed.
---@class GhLink.UserCommandOpts
---@field line1 integer
---@field line2 integer

---Run a `git` subcommand inside `cwd`. Returns stdout as a list of lines, or
---nil if git exited non-zero.
---@param args string[]
---@param cwd string
---@return string[]?
local function run_git(args, cwd)
  ---@type string[]
  local cmd = { "git", "-C", cwd }
  for _, a in ipairs(args) do
    cmd[#cmd + 1] = a
  end
  local out = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return out
end

---@param path string
---@return string?
local function git_root(path)
  local dir = vim.fn.fnamemodify(path, ":h")
  local out = run_git({ "rev-parse", "--show-toplevel" }, dir)
  return out and out[1] or nil
end

---Pick the remote we should reference. Prefer the upstream of the current
---branch, then `origin`, then the first remote git knows about.
---@param root string
---@return string?
local function pick_remote(root)
  local upstream = run_git({ "rev-parse", "--abbrev-ref", "@{u}" }, root)
  if upstream and upstream[1] then
    local remote = upstream[1]:match("^([^/]+)/")
    if remote then
      return remote
    end
  end

  local remotes = run_git({ "remote" }, root) or {}
  for _, r in ipairs(remotes) do
    if r == "origin" then
      return "origin"
    end
  end
  return remotes[1]
end

---@param root string
---@param remote string
---@return string?
local function remote_url(root, remote)
  local out =
    run_git({ "config", "--get", "remote." .. remote .. ".url" }, root)
  return out and out[1] or nil
end

---Convert any git remote URL pointing at GitHub into the canonical
---`https://github.com/owner/repo` form. Handles SSH, HTTPS and host-aliased
---SSH (e.g. `git@github.com-work:owner/repo.git`).
---@param url string
---@return string?
local function parse_github(url)
  local cleaned = url:gsub("%.git/?$", ""):gsub("/$", "")
  if not cleaned:lower():find("github") then
    return nil
  end
  local owner, repo = cleaned:match("[:/]([^:/]+)/([^/]+)$")
  if not (owner and repo) then
    return nil
  end
  return string.format("https://github.com/%s/%s", owner, repo)
end

---@param root string
---@param remote string
---@return string?
local function default_branch(root, remote)
  local head = run_git(
    { "symbolic-ref", "--short", "refs/remotes/" .. remote .. "/HEAD" },
    root
  )
  if head and head[1] then
    local b = head[1]:match("^" .. vim.pesc(remote) .. "/(.+)$")
    if b then
      return b
    end
  end
  for _, b in ipairs({ "main", "master" }) do
    local ref = remote .. "/" .. b
    if run_git({ "rev-parse", "--verify", "--quiet", ref }, root) then
      return b
    end
  end
  return nil
end

---@param root string
---@param remote string
---@param branch string
---@return string?
local function permanent_sha(root, remote, branch)
  local out = run_git({ "merge-base", "HEAD", remote .. "/" .. branch }, root)
  return out and out[1] or nil
end

---@param root string
---@param file string
---@return string?
local function relative_path(root, file)
  local abs_file = vim.fn.fnamemodify(file, ":p")
  local abs_root = vim.fn.fnamemodify(root, ":p"):gsub("/$", "")
  if abs_file:sub(1, #abs_root + 1) ~= abs_root .. "/" then
    return nil
  end
  return abs_file:sub(#abs_root + 2)
end

---Percent-encode characters that aren't safe inside a URL path segment.
---Slashes are preserved so the path structure stays intact.
---@param p string
---@return string
local function url_encode_path(p)
  local encoded = p:gsub("[^%w%-%._~/]", function(c)
    return string.format("%%%02X", c:byte())
  end)
  return encoded
end

---Build the URL for the requested line range. Returns nil + error message on
---failure (no git, no github remote, no merge-base, etc.).
---@param line1 integer
---@param line2? integer nil or equal to `line1` produces a single-line link
---@return string? link
---@return string? err
function M.get_link(line1, line2)
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return nil, "no file in current buffer"
  end

  local root = git_root(file)
  if not root then
    return nil, "not in a git repository"
  end

  local remote = pick_remote(root)
  if not remote then
    return nil, "no git remote configured"
  end

  local url = remote_url(root, remote)
  if not url then
    return nil, "remote '" .. remote .. "' has no URL"
  end

  local repo = parse_github(url)
  if not repo then
    return nil, "remote '" .. remote .. "' is not a github URL: " .. url
  end

  local branch = default_branch(root, remote)
  if not branch then
    return nil,
      "could not determine default branch on '"
        .. remote
        .. "' (try `git fetch`)"
  end

  local sha = permanent_sha(root, remote, branch)
  if not sha then
    return nil, "no merge-base between HEAD and " .. remote .. "/" .. branch
  end

  local rel = relative_path(root, file)
  if not rel then
    return nil, "file is outside the git working tree"
  end

  ---@type string
  local fragment
  if line2 and line2 > line1 then
    fragment = string.format("L%d-L%d", line1, line2)
  else
    fragment = string.format("L%d", line1)
  end

  return string.format(
    "%s/blob/%s/%s#%s",
    repo,
    sha,
    url_encode_path(rel),
    fragment
  )
end

---Build the link for `[line1, line2]` and copy it into the unnamed/clipboard
---registers. Errors are reported via `vim.notify` rather than raised.
---@param line1 integer
---@param line2 integer
---@return nil
local function copy(line1, line2)
  local link, err = M.get_link(line1, line2)
  if not link then
    vim.notify("GhLink: " .. (err or "unknown error"), vim.log.levels.ERROR)
    return
  end
  vim.fn.setreg("+", link)
  vim.fn.setreg('"', link)
  vim.notify(link)
end

---@param opts GhLink.UserCommandOpts
---@return nil
local function on_gh_link(opts)
  copy(opts.line1, opts.line2)
end

---@return nil
local function on_normal_keymap()
  local l = vim.fn.line(".")
  copy(l, l)
end

---@return nil
local function on_visual_keymap()
  local s, e = vim.fn.line("v"), vim.fn.line(".")
  if s > e then
    s, e = e, s
  end
  copy(s, e)
end

---Register the `:GhLink` user command and `<leader>gy` keymaps.
---@return nil
function M.setup()
  vim.api.nvim_create_user_command("GhLink", on_gh_link, {
    range = true,
    desc = "Copy a permanent GitHub link to the current line(s)",
  })

  vim.keymap.set("n", "<leader>gy", on_normal_keymap, {
    desc = "Yank GitHub link to current line",
  })

  vim.keymap.set("x", "<leader>gy", on_visual_keymap, {
    desc = "Yank GitHub link to selected lines",
  })
end

return M
