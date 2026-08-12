local awful     = require 'awful'
local beautiful = require 'beautiful'
local gears     = require 'gears'
beautiful.init '/usr/share/awesome/themes/default/theme.lua'

awful.screen.connect_for_each_screen(function(s)
  local wallpaper_path = '/usr/share/backgrounds/archlinux/simple.png'
  if gears.filesystem.file_readable '/home/rob/.config/awesome/wallpaper.png' then
    wallpaper_path = '/home/rob/.config/awesome/wallpaper.png'
  end

  pcall(gears.wallpaper.maximized, wallpaper_path, s, true)
end)
