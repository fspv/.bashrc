-- TODO: replace vim-quickui with vim.ui.select based menu
vim.cmd([[
    " clear all the menus
    call quickui#menu#reset()

    call quickui#menu#install(
    \    '&Vim',
    \    [
    \       ["&Reload config", "source $MYVIMRC"],
    \       ["&Health", "checkhealth"],
    \       ["&LSP capabilities",
    \        "lua =vim.lsp.get_active_clients()[1].server_capabilities"],
    \       ["&LSP Info", "LspInfo"],
    \       ["&Error log", "messages"],
    \    ]
    \)

    if executable('plz')
        call quickui#menu#install(
        \    '&Please',
        \    [
        \       ["&Show window\t<leader>pp",
        \        "lua require('please.runners.popup').restore()"],
        \       ["&Build\t<leader>pb", "lua require('please').build()"],
        \       ["&Test\t<leader>pt", "lua require('please').test()"],
        \       ["&Jump to target\t<leader>pj",
        \        "lua require('please').jump_to_target()"],
        \       ["&Test under cursor\t<leader>pct",
        \        "lua require('please').test({ under_cursor = true })"],
        \       ["&List tests\t<leader>plt",
        \        "lua require('please').test({ list = true })"],
        \       ["&List failed tests\t<leader>plt",
        \        "lua require('please').test({ failed = true })"],
        \       ["&Run\t<leader>pr", "lua require('please').run())"],
        \       ["&Yank\t<leader>py", "lua require('please').yank())"],
        \       ["&Debug\t<leader>pd", "lua require('please').debug()"],
        \       ["&Action history\t<leader>pa",
        \        "lua require('please').action_history())"],
        \    ]
        \)
    endif

    call quickui#menu#install(
    \    '&Git Signs',
    \    [
    \       ["Diff", "Gitsigns diffthis"],
    \       ["Diff ~", "lua require('gitsigns').diffthis('~')"],
    \       ["Toggle Signs", "Gitsigns toggle_signs"],
    \       ["Toggle Line Highlight", "Gitsigns toggle_linehl"],
    \       ["Toggle Word Diff", "Gitsigns toggle_word_diff"],
    \       ["Toggle Deleted", "Gitsigns toggle_deleted"],
    \       ["Toggle Current Line Blame", "Gitsigns toggle_current_line_blame"],
    \       ["Stage Buffer", "Gitsigns stage_buffer"],
    \       ["Reset Buffer", "Gitsigns reset_buffer"],
    \       ["Refresh", "Gitsigns refresh"],
    \    ]
    \)

    call quickui#menu#install(
    \    '&Fuzzy search',
    \    [
    \       ["&Git files\tff/", "Telescope git_files"],
    \       ["&Live grep\tfc/", "Telescope live_grep"],
    \       ["&Buffers", "Telescope buffers"],
    \       ["&Document symbols\tfs/", "Telescope lsp_document_symbols"],
    \       ["&Resume\tfr/", "Telescope resume"],
    \       ["&Help tags", "Telescope help_tags"],
    \       ["&Commands", "Telescope commands"],
    \       ["&Marks", "Telescope marks"],
    \       ["&Keymaps", "Telescope keymaps"],
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
    \       ["&Jumps to the definition of the type\tgo",
    \        "lua vim.lsp.buf.references()"],
    \       ["&Display signature\tgo", "lua vim.lsp.buf.signature_help()"],
    \       ["&Rename all references\t<F2>", "lua vim.lsp.buf.rename()"],
    \       ["&Format\t<F3>", "lua vim.lsp.buf.format()"],
    \       ["&Code action\t<F4>", "lua vim.lsp.buf.code_action()"],
    \       ["&Show diagnostics\tgl", "lua vim.diagnostic.open_float()"],
    \       ["&Previous diagnostics\t[d", "lua vim.diagnostic.goto_prev()"],
    \       ["&Next diagnostics\t]d", "lua vim.diagnostic.goto_next()"],
    \       ["Hunk Preview", "Gitsigns preview_hunk"],
    \       ["Hunk Reset", "Gitsigns reset_hunk"],
    \    ],
    \    {'index':g:quickui#context#cursor}
    \)<CR>

    noremap <leader>m :call quickui#menu#open()<CR>
]])
