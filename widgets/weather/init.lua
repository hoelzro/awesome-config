local awful = require 'awful'
local wibox = require 'wibox'
local timer = require 'gears.timer'

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

  local function refresh()
    local refresh_time = os.time()
    donut.run(function()
      return assert(backend:state())
    end, function(ok, state_or_err)
      if ok then
        local state = state_or_err
        state.last_refresh_time = refresh_time
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

  -- XXX set up hover widget

  return w
end

return make_widget
