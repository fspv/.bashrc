-- Add an automatic linter for arcanist https://github.com/phacility/arcanist
vim.api.nvim_create_autocmd(
  'BufWritePost',
  {
    group = vim.api.nvim_create_augroup('RunArcLint', { clear = true }),
    pattern = { "*.go", "*.py", "BUILD", "*.build_def", "*.build_defs" },
    desc = 'Run arc lint on saved file',
    callback = function(args)
      if #vim.fs.find('.arcconfig', { upward = true, path = vim.api.nvim_buf_get_name(args.buf) }) < 1 then
        return
      end
      if vim.fn.executable('arc') < 1 then
        return
      end
      local function on_event(_, data)
        local msg = table.concat(data, '\n')
        msg = vim.trim(msg)
        msg = msg:gsub('\t', string.rep(' ', 4))
        if msg ~= '' then
          vim.notify('arc: ' .. msg, vim.log.levels.INFO)
        end
        vim.cmd("edit")
      end
      vim.fn.jobstart(
        { 'arc', 'lint', '--severity', 'autofix', '--apply-patches', args.file },
        {
          on_stdout = on_event,
          on_stderr = on_event,
          stdout_buffered = true,
          stderr_buffered = true,
        }
      )
    end,
  }
)
