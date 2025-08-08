vim.g.lightline = {
  enable = { statusline = 1, tabline = 0 },
  active = {
    left = {
      { "mode", "paste" },
      { "gitbranch", "readonly", "relativepath", "modified" },
    },
  },
  component_function = {
    gitbranch = "FugitiveHead",
    filetype = "LightlineFiletype",
    fileformat = "LightlineFileformat",
  },
}

-- TODO: port to lua
vim.cmd([[
    function! LightlineFiletype()
      if winwidth(0) > 70
        return strlen(&filetype)
          \ ? &filetype . ' ' . WebDevIconsGetFileTypeSymbol()
          \ : 'no ft'
      endif
      return ''
    endfunction

    function! LightlineFileformat()
      if winwidth(0) > 70
        return &fileformat . ' ' . WebDevIconsGetFileFormatSymbol()
      endif
      return ''
    endfunction

  ]])

-- autocmd WinEnter,WinLeave * call lightline#update()
