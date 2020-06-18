local beautiful = require 'beautiful'
local gears     = require 'gears'
local home      = os.getenv 'HOME'
beautiful.init '/usr/share/awesome/themes/default/theme.lua'

pcall(gears.wallpaper.maximized, '/usr/share/backgrounds/archlinux/archlinux-simplyblack.png', nil, true)
