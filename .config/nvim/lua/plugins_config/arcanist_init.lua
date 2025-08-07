---@param message string
---@return string?
local function format_message(message)
	message = message or ""
	message = vim.trim(message)
	message = message:gsub("\t", string.rep(" ", 4))
	return message
end

-- Add an automatic linter for arcanist https://github.com/phacility/arcanist
-- vim.api.nvim_create_autocmd(
--   'BufWritePost',
--   {
--     group = vim.api.nvim_create_augroup('RunArcLint', { clear = true }),
--     pattern = { "*.go", "*.py", "BUILD", "*.build_def", "*.build_defs" },
--     desc = 'Run arc lint on saved file',
--     callback = function(args)
--       if #vim.fs.find('.arcconfig', { upward = true, path = vim.api.nvim_buf_get_name(args.buf) }) < 1 then
--         return
--       end
--       if vim.fn.executable('arc') < 1 then
--         return
--       end
--       local command = { 'arc', 'lint', '--apply-patches' }
--       vim.system(
--         command,
--         {},
--         function(out)
--           if out.code == 0 then
--             vim.schedule(
--               function()
--                 vim.notify('command finished: ' .. table.concat(command, ' '), vim.log.levels.INFO)
--                 if vim.api.nvim_buf_get_name(0):sub(- #args.file) == args.file then
--                   local buf = vim.bo[vim.api.nvim_win_get_buf(0)]
--                   if not buf.readonly and not buf.modified then
--                     vim.cmd("edit")
--                   end
--                 end
--               end
--             )
--           else
--             vim.schedule(
--               function()
--                 vim.notify('command failed: ' .. table.concat(command, ' '), vim.log.levels.ERROR)
--                 if vim.api.nvim_buf_get_name(0):sub(- #args.file) == args.file then
--                   local buf = vim.bo[vim.api.nvim_win_get_buf(0)]
--                   if not buf.readonly and not buf.modified then
--                     vim.cmd("edit")
--                   end
--                 end
--               end
--             )
--           end

--           local stdout = format_message(out.stdout)
--           if stdout ~= '' then
--             vim.schedule(
--               function()
--                 vim.notify('arc: ' .. stdout, vim.log.levels.INFO)
--               end
--             )
--           end

--           local stderr = format_message(out.stderr)
--           if stderr ~= '' then
--             vim.schedule(
--               function()
--                 vim.notify('arc: ' .. stderr, vim.log.levels.ERROR)
--               end
--             )
--           end
--         end
--       )
--     end,
--   }
-- )
