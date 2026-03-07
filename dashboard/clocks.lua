local wibox = require 'wibox'
local utils = require 'dashboard.utils'

local widget = wibox.widget {
  utils.textbox { markup = '<b>UTC</b>:' },
  {
    font     = utils.font,
    format   = '%H:%M',
    timezone = 'Z',
    refresh  = 60,
    widget   = wibox.widget.textclock,
  },
  utils.textbox { markup = '<b>PST</b>:' },
  {
    font     = utils.font,
    format   = '%H:%M',
    timezone = 'America/Los_Angeles',
    refresh  = 60,
    widget   = wibox.widget.textclock,
  },
  layout          = wibox.layout.grid,
  forced_num_cols = 2,
}

return {
  widget = widget,
}
