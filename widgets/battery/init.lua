local sformat = string.format

local awful = require 'awful'
local wibox = require 'wibox'
local timer = require 'gears.timer'

local backends = require 'widgets.battery.backends'
local render = require 'widgets.battery.render'
local make_renderer = require 'widgets.renderer'

local NOT_CHARGING_THRESHOLD = 3

local widgets = setmetatable({}, {__mode = 'k'})

local default_backend = backends.power_supply:new()

local function make_widget(options)
  local backend = options and options.backend or default_backend
  local has_battery = backend:detect()

  if not has_battery then
    return
  end

  local w = wibox.widget {
    text = 'Battery Info',
    widget = wibox.widget.textbox,
  }

  local reverse_color
  local prev_render
  local not_charging_count = 0
  local last_state
  local refresh_timer

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
    local saw_not_charging = false
    for i = 1, #state do
      if string.lower(state[i].status) == 'not charging' then
        saw_not_charging = true
        break
      end
    end

    if saw_not_charging then
      not_charging_count = not_charging_count + 1
    else
      not_charging_count = 0
    end

    local new_timeout
    if saw_not_charging and not_charging_count <= NOT_CHARGING_THRESHOLD then
      new_timeout = 1
    else
      new_timeout = 60
    end

    if refresh_timer.timeout ~= new_timeout then
      refresh_timer.timeout = new_timeout
      refresh_timer:again()
    end

    local render_state = state
    if saw_not_charging and last_state and not_charging_count <= NOT_CHARGING_THRESHOLD then
      render_state = last_state
    else
      last_state = state
    end

    local r = make_renderer()
    render(r, render_state)

    if r.is_blinking and not blink_timer.started then
      blink_timer:start()
    elseif blink_timer.started and not r.is_blinking then
      blink_timer:stop()
    end

    w:set_markup(r:markup())
    prev_render = r

    return true
  end

  refresh_timer = timer.weak_start_new(60, refresh)
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
