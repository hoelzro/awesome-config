local beautiful = require 'beautiful'
local gears     = require 'gears'
local home      = os.getenv 'HOME'
beautiful.init(home .. '/.config/awesome/themes/sky/theme.lua')

for s = 1, screen.count() do
  gears.wallpaper.maximized(beautiful.wallpaper, s, true)
end
