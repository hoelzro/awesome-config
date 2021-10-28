local awful     = require 'awful'
local beautiful = require 'beautiful'
local gears     = require 'gears'
beautiful.init '/usr/share/awesome/themes/default/theme.lua'

awful.screen.connect_for_each_screen(function(s)
  pcall(gears.wallpaper.maximized, '/usr/share/backgrounds/archlinux/simple.png', s, true)
end)
