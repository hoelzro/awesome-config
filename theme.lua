local beautiful = require 'beautiful'
local gears     = require 'gears'
local home      = os.getenv 'HOME'
beautiful.init '/usr/share/awesome/themes/default/theme.lua'

for s = 1, screen.count() do
  pcall(gears.wallpaper.maximized, '/usr/share/archlinux/wallpaper/archlinux-simplyblack.png', s, true)
end
