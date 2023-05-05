require("lspsaga").setup({})

vim.keymap.set("n", "<leader>o", "<cmd>Lspsaga outline<CR>")
vim.keymap.set("n", "<Leader>ci", "<cmd>Lspsaga incoming_calls<CR>")
vim.keymap.set("n", "<Leader>co", "<cmd>Lspsaga outgoing_calls<CR>")
