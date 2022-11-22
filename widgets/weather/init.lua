local awful   = require 'awful'
local naughty = require 'naughty'
local wibox   = require 'wibox'
local timer   = require 'gears.timer'

local cqueues = require 'cqueues'
local donut   = require 'donut'

local backends      = require 'widgets.weather.backends'
local render        = require 'widgets.weather.render'
local make_renderer = require 'widgets.renderer'

local render_widget = render.widget
local render_popup  = render.popup

local config = require 'widgets.config'
local backend = backends.darksky:new(config.weather)
assert(backend:detect(), 'weather widget configuration required')

local log = print

local function with_retries(inner, num_retries)
  local retryer = {}
  function retryer:state()
    local final_error

    for i = 1, num_retries do
      local state, err = inner:state()
      if state then
        return state
      end

      final_error = err

      local backoff = 5 * 2 ^ (i - 1)
      cqueues.sleep(backoff)
    end

    return nil, final_error
  end
  return setmetatable(retryer, {__index = inner})
end

backend = with_retries(backend, 5)

local widgets = setmetatable({}, {__mode = 'k'})

local function make_widget()
  local w = wibox.widget {
    text = 'Weather Info',
    widget = wibox.widget.textbox,
  }

  local request_in_flight
  local previous_refresh_time
  local previously_fetched_state
  local previous_fetch_error

  local function refresh()
    if request_in_flight then
      return
    end

    local refresh_time = os.time()
    request_in_flight = refresh_time
    donut.run(function()
      return assert(backend:state())
    end, function(ok, state_or_err)
      previous_refresh_time = refresh_time
      request_in_flight     = nil

      if ok then
        previously_fetched_state, previous_fetch_error = state_or_err, nil
      else
        previously_fetched_state, previous_fetch_error = nil, state_or_err
      end

      local r = make_renderer()
      render_widget(r, previously_fetched_state, previous_fetch_error)
      w:set_markup(r:markup())
    end)

    return true
  end

  timer.weak_start_new(15 * 60, refresh)
  refresh()

  w:buttons(awful.util.table.join(
    awful.button({}, 1, refresh)))

  -- XXX use a popup instead?
  local notification -- XXX having this dangling could be bad across restarts?

  w:connect_signal('mouse::enter', function()
    local r = make_renderer()
    render_popup(r, previous_refresh_time, request_in_flight, previously_fetched_state, previous_fetch_error)
    notification = naughty.notify {
      title = 'Weather',
      text  = r:markup(),

      replaces_id = (notification and notification.box.visible) and notification.id or nil,
    }
  end)

  w:connect_signal('mouse::leave', function()
    if notification then
      naughty.destroy(notification, naughty.notificationClosedReason.dismissedByCommand)
      notification = nil
    end
  end)

  widgets[w] = refresh

  return w
end

return make_widget
