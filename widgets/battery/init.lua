local sformat = string.format
local slower = string.lower

local awful = require 'awful'
local wibox = require 'wibox'
local timer = require 'gears.timer'

local backends = require 'widgets.battery.backends'
local render = require 'widgets.battery.render'
local make_renderer = require 'widgets.renderer'

local backend = backends.acpi:new()
local has_battery = backend:detect()

-- Number of consecutive "not charging" reads before accepting it as the real state
local NOT_CHARGING_THRESHOLD = 3

local widgets = setmetatable({}, {__mode = 'k'})

-- Check if any battery has a transient "not charging" status
local function has_not_charging_status(state)
  for i = 1, #state do
    if slower(state[i].status) == 'not charging' then
      return true
    end
  end
  return false
end

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

  local not_charging_count = 0
  local refresh_timer

  local function refresh()
    local state = backend:state()

    -- Handle transient "not charging" states
    local is_not_charging = has_not_charging_status(state)
    not_charging_count = is_not_charging and (not_charging_count + 1) or 0

    -- Adjust timer: poll faster during transient state, normal otherwise
    local new_timeout
    if is_not_charging and not_charging_count < NOT_CHARGING_THRESHOLD then
      -- Still in transient period, poll faster but don't update display
      new_timeout = 1
    else
      new_timeout = 60
    end

    if refresh_timer.timeout ~= new_timeout then
      refresh_timer.timeout = new_timeout
      refresh_timer:again()
    end

    -- Skip display update during transient "not charging" period
    if is_not_charging and not_charging_count < NOT_CHARGING_THRESHOLD then
      return true
    end

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
