vim.g.lightline = {
  enable = { statusline = 1, tabline = 0 },
  active = {
    left = {
      { 'mode',      'paste' },
      { 'gitbranch', 'readonly', 'relativepath', 'modified' },
    }
  },
  component_function = {
    gitbranch = 'FugitiveHead',
    filetype = 'LightlineFiletype',
    fileformat = 'LightlineFileformat',
  },
}

-- TODO: port to lua
vim.cmd(
  [[
    function! LightlineFiletype()
      return winwidth(0) > 70 ? (strlen(&filetype) ? &filetype . ' ' . WebDevIconsGetFileTypeSymbol() : 'no ft') : ''
    endfunction

    function! LightlineFileformat()
      return winwidth(0) > 70 ? (&fileformat . ' ' . WebDevIconsGetFileFormatSymbol()) : ''
    endfunction

  ]]
)

-- autocmd WinEnter,WinLeave * call lightline#update()
