---Check if such s plug loaded via vim plug
---@param plug_name string
---@return boolean
local has_plug = function(plug_name)
  local result = false
  local plugs = {}

  if vim.g.plugs ~= nil
  then
    plugs = vim.g.plugs
  end

  for key, value in pairs(plugs) do
    result = result or (key == plug_name)
  end

  if result
  then
    -- Debug
    -- vim.print("Plugin " .. plug_name .. " exists")
  else
    vim.print("Plugin " .. plug_name .. " doesn't exist, run :PlugInstall")
  end

  return result
end

-- Load plugin configuration
if has_plug("nvim-treesitter")
then
  require("plugins_config/treesitter_conf")
end
if has_plug("lsp-zero.nvim") and has_plug("nvim-lspconfig")
then
  require("plugins_config/lsp_conf")
end
if has_plug("nvim-cmp")
then
  require("plugins_config/cmp_conf")
end
if has_plug("please.nvim")
then
  require("plugins_config/please_conf")
end
if has_plug("barbar.nvim")
then
  require("plugins_config/barbar_conf")
end
if has_plug("nvim-tree.lua")
then
  require("plugins_config/nvimtree_conf")
end
if has_plug("neo-tree.nvim")
then
  require("plugins_config/neotree_conf")
end
if has_plug("mason.nvim") and has_plug("mason-lspconfig.nvim")
then
  require("plugins_config/mason_lspconfig_conf")
end
if has_plug("lualine.nvim")
then
  require("plugins_config/lualine_conf")
end
-- if has_plug("lightline.vim")
-- then
--   require("plugins_config/lightline_conf")
-- end
if has_plug("trouble.nvim")
then
  require("plugins_config/trouble_conf")
end
if has_plug("symbols-outline.nvim")
then
  require("plugins_config/symbols_outline_conf")
end
if has_plug("lspsaga.nvim")
then
  require("plugins_config/lspsaga_conf")
end
if has_plug("telescope.nvim")
then
  require("plugins_config/telescope_conf")
end
if has_plug("vim-matchup")
then
  require("plugins_config/matchup_conf")
end
if has_plug("vim-go")
then
  require("plugins_config/vim_go_conf")
end
if has_plug("vim-rooter")
then
  require("plugins_config/vim_rooter_conf")
end
if has_plug("ctrlp.vim")
then
  require("plugins_config/ctrlp_conf")
end
if has_plug("fzf")
then
  require("plugins_config/fzf_conf")
end
if has_plug("vim-vsnip")
then
  require("plugins_config/vsnip_conf")
end
if has_plug("gruvbox")
then
  require("plugins_config/gruvbox_conf")
end
if has_plug("nvim-lightbulb")
then
  require("plugins_config/lightbulb_conf")
end
if has_plug("vim-quickui")
then
  require("plugins_config/quickui_conf")
end
if has_plug("which-key.nvim")
then
  require("plugins_config/which_key_conf")
end
require("plugins_config/arcanist_conf")
if has_plug("vim-floaterm")
then
  require("plugins_config/floaterm_conf")
end

-- TODO: assign this to some config module
vim.cmd("set completeopt=menu,menuone,noselect")

-- Load local manual configuration if exists
pcall(require, "plugins_config_manual/config") -- Best effort

require("rust-tools").setup(
  {
  }
)
