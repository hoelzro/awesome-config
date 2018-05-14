local util = require 'awful.util'
local merge_tables = util.table.join
local naughty = require 'naughty'
local naughty_dbus = require 'naughty.dbus'
local naughty_defaults = {
  opacity         = 0.75,
  rounded_corners = true,
  screen          = preferred_screen,
}

naughty.config.presets.normal           = merge_tables(naughty.config.presets.normal, naughty_defaults)
naughty.config.presets.low              = merge_tables(naughty.config.presets.low, naughty_defaults)
naughty.config.presets.critical         = merge_tables(naughty.config.presets.critical, naughty_defaults)
naughty.config.defaults.opacity         = naughty_defaults.opacity
naughty.config.defaults.rounded_corners = naughty_defaults.rounded_corners
naughty.config.defaults.screen          = naughty_defaults.screen

naughty_dbus.config.mapping = {
    {{urgency = '\0'}, naughty.config.presets.low},
    {{urgency = '\1'}, naughty.config.presets.normal},
    {{urgency = '\2'}, naughty.config.presets.critical}
}

local gfs = require 'gears.filesystem'
local surface = require 'gears.surface'
local cairo = require('lgi').cairo

function naughty.config.notify_callback(args)
  if type(args.icon) == 'string' then
    local icon = args.icon
    if string.sub(icon, 1, 7) == 'file://' then
      icon = string.sub(icon, 8)
      icon = string.gsub(icon, "%%(%x%x)", function(x) return string.char(tonumber(x, 16)) end)
    end
    if not gfs.file_readable(icon) then
      icon = util.geticonpath(icon, naughty.config.icon_formats, naughty.config.icon_dirs, icon_size) or icon
    end
    icon = surface.load_uncached(icon)
    args.icon = icon
  end

  if args.icon then
    local icon = args.icon

    local icon_size = 128

    if icon:get_width() > icon_size or icon:get_height() > icon_size then
      local scaled = cairo.ImageSurface(cairo.Format.ARGB32, icon_size, icon_size)
      local cr = cairo.Context(scaled)
      cr:scale(icon_size / icon:get_height(), icon_size / icon:get_width())
      cr:set_source_surface(icon, 0, 0)
      cr:paint()
      args.icon = scaled
    end
  end

  return args
end
