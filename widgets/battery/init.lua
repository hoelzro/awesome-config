local sformat = string.format

local awful = require 'awful'
local wibox = require 'wibox'
local timer = require 'gears.timer'

local backends = require 'widgets.battery.backends'
local render = require 'widgets.battery.render'
local make_renderer = require 'widgets.renderer'

local backend = backends.acpi:new()
local has_battery = backend:detect()

local widgets = setmetatable({}, {__mode = 'k'})

local function make_widget()
  if not has_battery then
    return
  end

  local w = wibox.widget {
    text = 'Battery Info',
    widget = wibox.widget.textbox,
  }

  local reverse_color
  local prev_render
  local function blink_callback()
    local markup = prev_render:markup()
    if reverse_color then
      w:set_markup(sformat('<span background="red">%s</span>', markup))
    else
      w:set_markup(markup)
    end

    reverse_color = not reverse_color

    return true
  end
  local blink_timer = timer.weak_start_new(1, blink_callback)
  blink_timer:stop()

  local function refresh()
    local state = backend:state()
    local r = make_renderer()
    render(r, state)

    if r.is_blinking and not blink_timer.started then
      blink_timer:start()
    elseif blink_timer.started and not r.is_blinking then
      blink_timer:stop()
    end

    w:set_markup(r:markup())
    prev_render = r

    return true
  end

  timer.weak_start_new(60, refresh)
  refresh()

  backend:weak_connect_signal('battery', refresh)

  w:buttons(awful.util.table.join(
    awful.button({}, 1, refresh)))

  widgets[w] = {
    refresh,
    blink_callback,
  }

  return w
end

return make_widget
