local awful = require 'awful'
local wibox = require 'wibox'
local utils = require 'dashboard.utils'

local value = wibox.widget(utils.textbox {})

local widget = wibox.widget {
  utils.textbox { text = 'WiFi Info:' },
  value,
  layout          = wibox.layout.grid,
  forced_num_cols = 2,
}

local function refresh()
  local info = {}
  local callbacks = {}

  function callbacks.stdout(line)
    local ssid = string.match(line, '^%s*SSID:%s*(.*)')
    if ssid then
      info.ssid = ssid
    end

    local ap_addr = string.match(line, '^Connected to (%x%x:%x%x:%x%x:%x%x:%x%x:%x%x)')
    if ap_addr then
      info.ap_addr = ap_addr
    end
  end

  function callbacks.output_done()
    if info.ssid and info.ap_addr then
      value.text = info.ssid .. ' (' .. info.ap_addr .. ')'
    end
  end

  value.text = 'Loading...'
  awful.spawn.with_line_callback({ 'iw', 'dev', 'wlan0', 'link' }, callbacks)
end

return {
  widget  = widget,
  refresh = refresh,
}
