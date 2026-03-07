local wibox = require 'wibox'
local utils = require 'dashboard.utils'

local grid = wibox.widget {
  spacing         = 5,
  forced_num_cols = 1,
  layout          = wibox.layout.grid,
}

local widget = wibox.widget {
  utils.textbox { markup = '<b>Tasks:</b>' },
  grid,
  layout = wibox.layout.fixed.vertical,
}

local function refresh()
  grid:reset()

  local f = io.open('/home/rob/.cache/todoist', 'r')
  if not f then return end

  for line in f:lines() do
    local fields = {}
    for field in string.gmatch(line, '[^\t]+') do
      fields[#fields + 1] = field
    end

    local completed = fields[1] == 'true'
    local task = fields[2]

    local function decorate(s)
      return s
    end

    if completed then
      function decorate(s)
        return '<s>' .. s .. '</s>'
      end
    end

    grid:add(wibox.widget(utils.textbox {
      markup = decorate(task),
    }))
  end

  f:close()
end

return {
  widget  = widget,
  refresh = refresh,
}
