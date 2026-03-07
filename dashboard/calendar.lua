local wibox = require 'wibox'
local utils = require 'dashboard.utils'

local grid = wibox.widget {
  spacing         = 5,
  forced_num_cols = 2,
  layout          = wibox.layout.grid,
}

local widget = wibox.widget {
  utils.textbox { markup = '<b>Calendar:</b>' },
  grid,
  layout = wibox.layout.fixed.vertical,
}

local function refresh()
  grid:reset()

  local f = io.open('/home/rob/.cache/cal', 'r')
  if not f then return end

  for line in f:lines() do
    local fields = {}
    for field in string.gmatch(line, '[^\t]+') do
      fields[#fields + 1] = field
    end

    local start_time = fields[2]
    local end_time = fields[4]
    local event = fields[5]

    local function decorate(s)
      return s
    end

    local now = os.date '%H:%M'

    if now >= start_time and now <= end_time then
      function decorate(s)
        return '<b>' .. s .. '</b>'
      end
    elseif now >= end_time then
      function decorate(s)
        return '<s>' .. s .. '</s>'
      end
    end

    grid:add(wibox.widget(utils.textbox {
      markup = decorate(string.format('%s - %s', start_time, end_time)),
    }))
    grid:add(wibox.widget(utils.textbox {
      markup = decorate(event),
    }))
  end

  f:close()
end

return {
  widget  = widget,
  refresh = refresh,
}
