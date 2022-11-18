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

local function make_widget()
  local w = wibox.widget {
    text = 'Weather Info',
    widget = wibox.widget.textbox,
  }

  local previously_fetched_state

  local function refresh()
    local refresh_time = os.time()
    donut.run(function()
      return assert(backend:state())
    end, function(ok, state_or_err)
      if ok then
        local state = state_or_err
        state.last_refresh_time = refresh_time
        previously_fetched_state = state
        local r = make_renderer()
        render_widget(r, state)
        w:set_markup(r:markup())
      else
        -- XXX test error scenario, and render or show error on hover or whatever
      end
    end)
  end

  -- XXX properly handle GC stuff
  timer {
    timeout = 15 * 60,
    autostart = true,
    call_now  = true,

    callback = refresh,
  }

  w:buttons(awful.util.table.join(
    awful.button({}, 1, refresh)))

  -- XXX use a popup instead?
  local notification

  w:connect_signal('mouse::enter', function()
    if not previously_fetched_state then
      return
    end

    local r = make_renderer()
    render_popup(r, previously_fetched_state)
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

  return w
end

return make_widget
