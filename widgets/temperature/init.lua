local awful = require 'awful'
local wibox = require 'wibox'
local timer = require 'gears.timer'

local backends = require 'widgets.temperature.backends'
local render = require 'widgets.temperature.render'
local make_renderer = require 'widgets.renderer'

local backend = backends.sysfs:new()
assert(backend:detect())

local log = print

local widgets = setmetatable({}, {__mode = 'k'})

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
    return true
  end

  timer.weak_start_new(5, refresh)
  refresh()

  w:buttons(awful.util.table.join(
    awful.button({}, 1, refresh)))

  widgets[w] = refresh

  return w
end

return make_widget
