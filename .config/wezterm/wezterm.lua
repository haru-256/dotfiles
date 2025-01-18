-- Pull in the wezterm API
local wezterm = require "wezterm"

-- This will hold the configuration.
local config = wezterm.config_builder()

-- Spawn a fish shell in login mode
config.default_prog = { '/opt/homebrew/bin/fish', '-l' }

-- This is where you actually apply your config choices

-- For example, changing the color scheme:
config.color_scheme_dirs = { "~/.config/wezterm/colors" }
config.color_scheme = "Dracula (Official)"

-- the font
-- config.font = wezterm.font("Inconsolata Nerd Font")
-- config.font_size = 17.0
config.font = wezterm.font("HackGen35 Console NF")
config.font_size = 15.0
-- config.font = wezterm.font("Hack Nerd Font")
-- config.font_size = 15.0

-- the window size
config.initial_rows = 30
config.initial_cols = 100

-- the opacity of the window
config.window_background_opacity = 0.85

-- and finally, return the configuration to wezterm
return config
