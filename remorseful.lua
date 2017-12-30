-- usage:
--   - embed the widget somewhere: `wibox:add(remorseful.widget)`
--   - set time limit: `remorseful.time_limit = 10`
--   - set text to be displayed: `remorseful.text = 'Press Alt-Shift-u to cancel'`
--   - invoke an action that you can cancel:
--   ```
--   remorseful {
--     cancel = function()
--       c.hidden = false
--     end,
--     commit = function()
--       c:kill()
--     end,
--     start = function()
--       c.hidden = true
--     end,
--   }
--   ```
--   - all other buttons/keys to cancel: `key(..., remorseful.cancel)`

local awful   = require 'awful'
local gears   = require 'gears'
local naughty = require 'naughty'
local wibox   = require 'wibox'

local WIDTH = 200
local TIME_STEP = 0.1

local remorseful = {}
local remorseful_mt = {}

local text_widget = wibox.widget {
  text = '',
  widget = wibox.widget.textbox,
}

local pbar_widget = wibox.widget {
  max_value = 1,
  value = 0,
  forced_width = 0, -- XXX configurable
  widget = wibox.widget.progressbar,
}

local top_widget = wibox.widget {
  pbar_widget,
  text_widget,

  layout = wibox.layout.stack,
}

local timer
local value
local cancel_fn = function() end

remorseful.widget = top_widget
remorseful.time_limit = 5

function remorseful_mt:__call(args)
  if timer then
    naughty.notify {
      text = 'Remorseful action already active!',
      preset = naughty.config.presets.critical,
    }
    return
  end

  if args.start then
    args.start()
  end

  if remorseful.text then
    text_widget.text = remorseful.text
  else
    text_widget.text = ''
  end

  top_widget.forced_width = WIDTH -- XXX configurable
  pbar_widget:set_value(0)
  value = 0

  timer = gears.timer.start_new(TIME_STEP, function()
    value = value + TIME_STEP
    pbar_widget:set_value(value / remorseful.time_limit)
    if value >= remorseful.time_limit then
      top_widget.forced_width = 0
      timer = nil
      cancel_fn = function() end
      pcall(args.commit)
      return false
    else
      return true
    end
  end)

  cancel_fn = args.cancel
end

function remorseful.cancel()
  top_widget.forced_width = 0

  if timer then
    timer:stop()
    timer = nil
  end
  pcall(cancel_fn)
  cancel_fn = function() end
end

top_widget:buttons(awful.util.table.join(
  awful.button({}, 1, remorseful.cancel)
))

return setmetatable(remorseful, remorseful_mt)
