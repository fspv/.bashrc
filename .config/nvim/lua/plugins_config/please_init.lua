vim.keymap.set("n", "<leader>pj", function()
  require("please").jump_to_target()
end, { desc = "Please Jump to Target" })
vim.keymap.set("n", "<leader>pb", function()
  require("please").build()
end, { desc = "Please Build" })
vim.keymap.set("n", "<leader>pt", function()
  require("please").test()
end, { desc = "Please Test" })
vim.keymap.set("n", "<leader>pct", function()
  require("please").test({ under_cursor = true })
end, { desc = "Please Test Under Cursor" })
vim.keymap.set("n", "<leader>pr", function()
  require("please").run()
end, { desc = "Please Run" })
vim.keymap.set("n", "<leader>py", function()
  require("please").yank()
end, { desc = "Please Yank" })
vim.keymap.set("n", "<leader>pd", function()
  require("please").debug()
end, { desc = "Please Debug" })
vim.keymap.set("n", "<leader>pa", function()
  require("please").action_history()
end, { desc = "Please Action History" })
vim.keymap.set("n", "<leader>pp", function()
  require("please").maximise_popup()
end, { desc = "Please Restore Window" })

-- TODO: port to lua
vim.cmd([[
    if executable('plz')
        function DetectPlz()
            if filereadable(FindRootDirectory() . '/.plzconfig')
                au BufRead,BufNewFile BUILD,*.build_def set filetype=please
                au BufRead,BufNewFile BUILD,*.build_def,*.build_defs set syntax=python
            endif
        endfunction
        autocmd VimEnter *.go call DetectPlz()
    endif
  ]])

-- Run puku (auto dependencies resolver) on go files automatically
vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("RunPukuForGoFiles", { clear = true }),
  pattern = { "*.go" },
  desc = "Run puku on saved file",
  callback = function(args)
    if
      #vim.fs.find(
        ".plzconfig",
        { upward = true, path = vim.api.nvim_buf_get_name(args.buf) }
      ) < 1
    then
      return
    end
    if vim.fn.executable("plz") == 0 then
      return
    end
    local function on_event(_, data)
      local msg = table.concat(data, "\n")
      msg = vim.trim(msg)
      msg = msg:gsub("\t", string.rep(" ", 4))
      if msg ~= "" then
        vim.notify("puku: " .. msg, vim.log.levels.INFO)
      end
    end
    vim.fn.jobstart({ "plz", "puku", "fmt", args.file }, {
      on_stdout = on_event,
      on_stderr = on_event,
      stdout_buffered = true,
      stderr_buffered = true,
    })
  end,
})
