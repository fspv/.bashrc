require("mason-lspconfig").setup({
  automatic_installation = { exclude = { "gopls", "pyright", "basedpyright" } },
})
