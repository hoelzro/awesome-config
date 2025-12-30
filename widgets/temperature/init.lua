local awful = require 'awful'
local wibox = require 'wibox'
local timer = require 'gears.timer'

local backends = require 'widgets.temperature.backends'
local render = require 'widgets.temperature.render'
local make_renderer = require 'widgets.renderer'

local ERROR_THRESHOLD = 10

local backend = backends.sysfs:new()
assert(backend:detect())

local log = print

local widgets = setmetatable({}, {__mode = 'k'})

local function make_widget()
  local w = wibox.widget {
    text = 'Temperature Info',
    widget = wibox.widget.textbox,
  }

  local error_count = 0

  local refresh_timer

  local function refresh()
    local state, err = backend:state()

    error_count = state and 0 or error_count + 1

    local new_timeout
    if state or error_count > ERROR_THRESHOLD then
      new_timeout = 5
    else
      -- XXX should I show "updating" when in this state?
      new_timeout = 1
    end

    if refresh_timer.timeout ~= new_timeout then
      refresh_timer.timeout = new_timeout
      refresh_timer:again()
    end

    if state then
      local r = make_renderer()
      render(r, state)
      w:set_markup(r:markup())
    elseif error_count > ERROR_THRESHOLD then
      w:set_text('Unable to get temperature state: ' .. tostring(err))
    end

    return true
  end

  refresh_timer = timer.weak_start_new(5, refresh)
  refresh()

  w:buttons(awful.util.table.join(
    awful.button({}, 1, refresh)))

  widgets[w] = refresh

  return w
end

return make_widget
