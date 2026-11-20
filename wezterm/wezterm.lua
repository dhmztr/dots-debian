-- WezTerm - same look as the NixOS ghostty setup, with a static palette
-- instead of wallust. Change the colours here AND in
-- ~/.cache/wal/colors-wal.vim (nvim) to keep both in sync (see README "Kolory").
-- WezTerm reloads this file on save.
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.font = wezterm.font 'Iosevka Nerd Font'
config.font_size = 12

config.window_background_opacity = 0.9 -- only with a compositor (picom)
-- no title bar and no tab bar at the top (ghostty had neither)
config.window_decorations = 'NONE'
config.enable_tab_bar = false
config.window_padding = { left = 2, right = 2, top = 2, bottom = 2 } -- ghostty default
config.adjust_window_size_when_changing_font_size = false
config.window_close_confirmation = 'NeverPrompt'
config.audible_bell = 'Disabled'
config.check_for_updates = false

config.default_cursor_style = 'SteadyBlock'

-- render colours exactly like ghostty: bold text keeps its colour (ghostty
-- bold-is-bright = false), inactive panes are not dimmed or desaturated
config.bold_brightens_ansi_colors = 'No'
config.inactive_pane_hsb = { hue = 1.0, saturation = 1.0, brightness = 1.0 }
config.foreground_text_hsb = { hue = 1.0, saturation = 1.0, brightness = 1.0 }

-- palette (Rosé Pine, from wallust on the NixOS setup)
config.colors = {
  background = '#191724',
  foreground = '#e0def4',
  cursor_bg = '#e0def4',
  cursor_fg = '#191724',
  cursor_border = '#e0def4',
  -- ghostty's default selection: foreground/background swapped
  selection_fg = '#191724',
  selection_bg = '#e0def4',
  scrollbar_thumb = '#26233a',
  split = '#6e6a86',
  ansi = {
    '#26233a', '#eb6f92', '#9ccfd8', '#f6c177',
    '#3986a6', '#c4a7e7', '#ebbcba', '#e0def4',
  },
  brights = {
    '#6e6a86', '#eb6f92', '#9ccfd8', '#f6c177',
    '#3986a6', '#c4a7e7', '#ebbcba', '#e0def4',
  },
}

-- file:line[:col] in compiler / test / grep output (src/main.rs:42:7,
-- ./foo.cc:10, /abs/path.py:3) becomes a link: ctrl+click opens it in nvim
-- in a new tab, at that line, relative to the pane's directory.
-- (ctrl+shift+space = quick select: copy hashes, paths, URLs by letter)
config.hyperlink_rules = wezterm.default_hyperlink_rules()
table.insert(config.hyperlink_rules, {
  regex = [[((?:/|\.\.?/)?(?:[\w.+-]+/)*[\w.+-]+\.(?:rs|c|cc|cpp|cxx|h|hh|hpp|m|mm|py|lua|js|jsx|ts|tsx|go|java|kt|hs|qml|toml|json|ya?ml|md|sh|fish|gn|gni|cmake|txt)):(\d+)(?::(\d+))?]],
  format = 'editor://$1:$2:$3',
})

wezterm.on('open-uri', function(window, pane, uri)
  local file, line, col = uri:match '^editor://(.-):(%d+):?(%d*)$'
  if not file then
    return -- not ours: default handling (browser for URLs)
  end
  if not file:match '^/' then
    local cwd = pane:get_current_working_dir()
    local dir = cwd and (cwd.file_path or tostring(cwd):gsub('^file://[^/]*', ''))
    if dir then
      file = dir .. '/' .. file
    end
  end
  window:perform_action(
    wezterm.action.SpawnCommandInNewTab {
      args = { 'nvim', '+call cursor(' .. line .. ',' .. (col ~= '' and col or '1') .. ')', file },
    },
    pane
  )
  return false
end)

return config
