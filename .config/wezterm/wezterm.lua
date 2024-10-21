local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.keys = {
  {
    key = 't',
    mods = 'CTRL',
    action = wezterm.action.SpawnTab 'CurrentPaneDomain',
  },
    {key="c", mods="CMD", action=wezterm.action{CopyTo="Clipboard"}},
    {key="x", mods="CMD", action=wezterm.action{CopyTo="Clipboard"}},
    {key="v", mods="CMD", action=wezterm.action{PasteFrom="Clipboard"}},
}

config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CMD',
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
}

config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}

return config
