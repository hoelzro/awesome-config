local merge_tables = require 'awful.util'.table.join
local naughty = require 'naughty'
local naughty_defaults = {
  opacity         = 0.75,
  rounded_corners = true,
  screen          = preferred_screen,
}

naughty.config.presets.normal   = merge_tables(naughty.config.presets.normal, naughty_defaults)
naughty.config.presets.low      = merge_tables(naughty.config.presets.low, naughty_defaults)
naughty.config.presets.critical = merge_tables(naughty.config.presets.critical, naughty_defaults)
naughty.config.opacity          = naughty_defaults.opacity
naughty.config.rounded_corners  = naughty_defaults.rounded_corners
naughty.config.screen           = naughty_defaults.screen
naughty.config.mapping          = {
    {{urgency = '\0'}, naughty.config.presets.low},
    {{urgency = '\1'}, naughty.config.presets.normal},
    {{urgency = '\2'}, naughty.config.presets.critical}
}
