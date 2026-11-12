-- WezTerm - same look as the NixOS ghostty setup, with a static palette
-- instead of wallust. Change the colours here AND in
-- ~/.cache/wal/colors-wal.vim (nvim) to keep both in sync (see README "Kolory").
-- WezTerm reloads this file on save.
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.font = wezterm.font 'Maple Mono NF Patched'
config.font_size = 12
-- tighter letters: 0.9 of the font's advance; 0.85 starts to glue `mm`/`ww`
config.cell_width = 0.9

config.window_background_opacity = 0.9 -- only with a compositor (picom)
config.window_decorations = 'NONE'
config.window_padding = { left = 4, right = 4, top = 4, bottom = 4 }
config.hide_tab_bar_if_only_one_tab = true
config.adjust_window_size_when_changing_font_size = false
config.window_close_confirmation = 'NeverPrompt'
config.audible_bell = 'Disabled'
config.check_for_updates = false

config.default_cursor_style = 'SteadyBlock'

-- palette (Rosé Pine, from wallust on the NixOS setup)
config.colors = {
  background = '#191724',
  foreground = '#e0def4',
  cursor_bg = '#e0def4',
  cursor_fg = '#191724',
  cursor_border = '#e0def4',
  ansi = {
    '#26233a', '#eb6f92', '#9ccfd8', '#f6c177',
    '#3986a6', '#c4a7e7', '#ebbcba', '#e0def4',
  },
  brights = {
    '#6e6a86', '#eb6f92', '#9ccfd8', '#f6c177',
    '#3986a6', '#c4a7e7', '#ebbcba', '#e0def4',
  },
}

return config
