local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.keys = {
  {
    key = "t",
    mods = "CTRL",
    action = wezterm.action.SpawnTab("CurrentPaneDomain"),
  },
  { key = "c", mods = "CMD", action = wezterm.action({ CopyTo = "Clipboard" }) },
  { key = "x", mods = "CMD", action = wezterm.action({ CopyTo = "Clipboard" }) },
  { key = "v", mods = "CMD", action = wezterm.action({ PasteFrom = "Clipboard" }) },
  { key = "c", mods = "SHIFT|CTRL", action = wezterm.action({ CopyTo = "Clipboard" }) },
  { key = "x", mods = "SHIFT|CTRL", action = wezterm.action({ CopyTo = "Clipboard" }) },
  { key = "v", mods = "SHIFT|CTRL", action = wezterm.action({ PasteFrom = "Clipboard" }) },
}

config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = "Left" } },
    mods = "SHIFT",
    action = wezterm.action.Nop,
  },
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "SHIFT",
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
  {
    event = { Down = { streak = 1, button = "Left" } },
    mods = "CTRL",
    action = wezterm.action.Nop,
  },
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "CTRL",
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
  {
    event = { Down = { streak = 1, button = "Left" } },
    mods = "CMD",
    action = wezterm.action.Nop,
  },
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "CMD",
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "NONE",
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
  {
    event = { Down = { streak = 1, button = "Middle" } },
    mods = "NONE",
    action = wezterm.action.PasteFrom("PrimarySelection"),
  },
}

config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}

config.hide_mouse_cursor_when_typing = false

config.warn_about_missing_glyphs = false

config.enable_kitty_keyboard = true

config.scrollback_lines = 10000
config.enable_scroll_bar = true

return config
