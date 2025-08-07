local highlight = {
  "RainbowGrey",
  "RainbowOrange",
  "RainbowGreen",
  "RainbowRed",
  "RainbowBlue",
  "RainbowYellow",
  "RainbowPink",
  "RainbowLightBlue",
}

local hooks = require("ibl.hooks")
-- create the highlight groups in the highlight setup hook, so they are reset
-- every time the colorscheme changes
hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
  vim.api.nvim_set_hl(0, "RainbowGrey", { fg = "#777777" })
  vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#D55E00" })
  vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#F0E442" })
  vim.api.nvim_set_hl(0, "RainbowLightBlue", { fg = "#56B4E9" })
  vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#0072B2" })
  vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#E69F00" })
  vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#009E73" })
  vim.api.nvim_set_hl(0, "RainbowPink", { fg = "#CC79A7" })
end)

vim.g.rainbow_delimiters = { highlight = highlight }

require("ibl").setup({
  scope = {
    highlight = highlight,
    char = "▍",
  },
  indent = {
    -- highlight = highlight,
    char = "╎",
  },
})

hooks.register(
  hooks.type.SCOPE_HIGHLIGHT,
  hooks.builtin.scope_highlight_from_extmark
)
