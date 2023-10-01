-- TODO: port to lua
vim.cmd(
  [[
    " clear all the menus
    call quickui#menu#reset()

    call quickui#menu#install(
    \    '&Vim',
    \    [
    \       ["&Reload config", "source $MYVIMRC"],
    \       ["&Health", "checkhealth"],
    \       ["&LSP capabilities", "lua =vim.lsp.get_active_clients()[1].server_capabilities"],
    \       ["&LSP Info", "LspInfo"],
    \       ["&Error log", "messages"],
    \    ]
    \)

    if executable('plz')
        call quickui#menu#install(
        \    '&Please',
        \    [
        \       ["&Show window\t<leader>pp", "lua require('please.runners.popup').restore()"],
        \       ["&Build\t<leader>pb", "lua require('please').build()"],
        \       ["&Test\t<leader>pt", "lua require('please').test()"],
        \       ["&Jump to target\t<leader>pj", "lua require('please').jump_to_target()"],
        \       ["&Test under cursor\t<leader>pct", "lua require('please').test({ under_cursor = true })"],
        \       ["&List tests\t<leader>plt", "lua require('please').test({ list = true })"],
        \       ["&List failed tests\t<leader>plt", "lua require('please').test({ failed = true })"],
        \       ["&Run\t<leader>pr", "lua require('please').run())"],
        \       ["&Yank\t<leader>py", "lua require('please').yank())"],
        \       ["&Debug\t<leader>pd", "lua require('please').debug()"],
        \       ["&Action history\t<leader>pa", "lua require('please').action_history())"],
        \    ]
        \)
    endif

    call quickui#menu#install(
    \    '&Signify',
    \    [
    \       ["Diff", "SignifyDiff"],
    \       ["Diff!", "SignifyDiff!"],
    \       ["Fold", "SignifyFold"],
    \       ["Fold!", "SignifyFold!"],
    \       ["List", "SignifyList"],
    \       ["Enable", "SignifyEnable"],
    \       ["Enable All", "SignifyEnableAll"],
    \       ["Disable", "SignifyDisable"],
    \       ["Disable All", "SignifyDisableAll"],
    \       ["Toggle", "SignifyToggle"],
    \       ["Toggle Highlight", "SignifyToggleHighlight"],
    \       ["Refresh", "SignifyRefresh"],
    \       ["Debug", "SignifyDebug"],
    \    ]
    \)

    call quickui#menu#install(
    \    '&Fuzzy search',
    \    [
    \       ["&Files\tff/", "ProjectFiles"],
    \       ["&File content\tfc/", "ProjectRg"],
    \       ["&Git files\t:GFiles", "GFiles"],
    \       ["&Git staged files\t:GFiles?", "GFiles?"],
    \       ["&Git commits\t:Commits [LOG_OPTS]", "Commits"],
    \       ["&Git commits (current buffer)\t:BCommits [LOG_OPTS]", "BCommits"],
    \       ["&Buffers\tBuffers:", "Buffers"],
    \       ["&Lines (all buffers)\t:Lines", "Lines"],
    \       ["&Lines (current buffer)\t:BLines", "BLines"],
    \       ["&Tags (project)\t:Tags", "Tags"],
    \       ["&Tags (current buffer)\t:BTags", "BTags"],
    \       ["&Colors\t:Colors", "Colors"],
    \       ["&Marks\t:Marks", "Marks"],
    \       ["&Windows\t:Windows", "Windows"],
    \       ["&Snippets\t:Snippets", "Snippets"],
    \       ["&Commands\t:Commands", "Commands"],
    \       ["&Maps\t:Maps", "Maps"],
    \       ["&Help tags\t:Helptags", "Helptags"],
    \       ["&File types\t:Filetypes", "Filetypes"],
    \       ["&Command history\t:History:", "History:"],
    \       ["&Old files and open buffers history\t:History", "History"],
    \       ["&Ripgrep\t:Rg [PATTERN]", "Rg"],
    \       ["&Locate\t:Locate [PATTERN]", "Locate"],
    \    ]
    \)

    call quickui#menu#install('Help (&?)', [
        \ ["&Index", 'tab help index', ''],
        \ ['Ti&ps', 'tab help tips', ''],
        \ ['--',''],
        \ ["&Tutorial", 'tab help tutor', ''],
        \ ['&Quick Reference', 'tab help quickref', ''],
        \ ['&Summary', 'tab help summary', ''],
        \ ['--',''],
        \ ['&Vim Script', 'tab help eval', ''],
        \ ['&Function List', 'tab help function-list', ''],
        \ ], 10000)

    noremap <leader>c :call quickui#context#open(
    \    [
    \       ["&Display hover\tK", "lua vim.lsp.buf.hover()"],
    \       ["&Jump to definition\tgd", "lua vim.lsp.buf.definition()"],
    \       ["&Jump to declaration\tgD", "lua vim.lsp.buf.declaration()"],
    \       ["&List implementations\tgi", "lua vim.lsp.buf.implementation()"],
    \       ["&Jumps to the definition of the type\tgo", "lua vim.lsp.buf.references()"],
    \       ["&Display signature\tgo", "lua vim.lsp.buf.signature_help()"],
    \       ["&Rename all references\t<F2>", "lua vim.lsp.buf.rename()"],
    \       ["&Format\t<F3>", "lua vim.lsp.buf.format()"],
    \       ["&Code action\t<F4>", "lua vim.lsp.buf.code_action()"],
    \       ["&Show diagnostics\tgl", "lua vim.diagnostic.open_float()"],
    \       ["&Previous diagnostics\t[d", "lua vim.diagnostic.goto_prev()"],
    \       ["&Next diagnostics\t]d", "lua vim.diagnostic.goto_next()"],
    \       ["Hunk Diff", "SignifyHunkDiff"],
    \       ["Hunk Undo", "SignifyHunkUndo"],
    \    ],
    \    {'index':g:quickui#context#cursor}
    \)<CR>

    noremap <leader>m :call quickui#menu#open()<CR>
]]
)
