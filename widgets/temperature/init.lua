local awful = require 'awful'
local wibox = require 'wibox'
local timer = require 'gears.timer'

local backends = require 'widgets.temperature.backends'
local render = require 'widgets.temperature.render'
local make_renderer = require 'widgets.renderer'

local backend = backends.filesystem:new {
  -- XXX hardcoded!
  -- Look for /sys/class/thermal/thermal_zone*/type == acpitz
  -- Look for /sys/class/hwmon/hwmon*/name == k10temp
  target = '/sys/class/thermal/thermal_zone0/temp',
}

local log = print

local function make_widget()
  local w = wibox.widget {
    text = 'Temperature Info',
    widget = wibox.widget.textbox,
  }

  local function refresh()
    local state = backend:state()
    local r = make_renderer()
    render(r, state)
    w:set_markup(r:markup())
  end

  timer {
    timeout   = 5,
    autostart = true,
    call_now  = true,

    callback = refresh,
  }

  w:buttons(awful.util.table.join(
    awful.button({}, 1, refresh)))

  return w
end

return make_widget
