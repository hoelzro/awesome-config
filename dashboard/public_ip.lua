local awful = require 'awful'
local wibox = require 'wibox'
local utils = require 'dashboard.utils'

local value = wibox.widget(utils.textbox {})

local widget = wibox.widget {
  utils.textbox { text = 'Public IP:' },
  value,
  layout          = wibox.layout.grid,
  forced_num_cols = 2,
}

local function refresh()
  value.text = 'Loading...'
  awful.spawn.easy_async_with_shell(
    [[curl -m 10 -s ipinfo.io | jq -r '.ip + " " + .city + ", " + .region']],
    function(stdout)
      value.text = string.gsub(stdout, '%s+$', '')
    end
  )
end

return {
  widget  = widget,
  refresh = refresh,
}
