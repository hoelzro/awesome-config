local awful = require 'awful'
local wibox = require 'wibox'

local function key_count(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end

local function log(fmt, ...)
  print(string.format(fmt, ...))
end

if not old_widgets then
  old_widgets = setmetatable({}, {__mode = 'k'})
end

if dashboard then
  dashboard.visible = false
end

local font = 'Monospace 14'

local function textbox(opts)
  opts.widget = wibox.widget.textbox
  opts.font = opts.font or font

  return opts
end

local hostname = '<unknown>'
local pipe = io.popen 'hostname'
if pipe then
  hostname = pipe:read '*a'
  hostname = string.gsub(hostname, '%s+$', '')
  pipe:close()
end

local config = dashboard_config or {}

-- XXX temporarily assigned to global for iteration without restarting
dashboard = awful.popup {
  widget = {
    textbox {
      markup = '<b>' .. hostname .. ' dashboard</b>',
    },

    {
      textbox {
        text = 'WiFi Info:',
      },

      textbox {
        id = 'wifi_info',
      },

      textbox {
        text = 'Public IP:',
      },

      textbox {
        id = 'public_ip_info',
      },

      textbox {
        markup = '<b>UTC</b>:',
      },

      {
        font     = font,
        format   = '%H:%M',
        timezone = 'Z',
        refresh  = 60,
        widget   = wibox.widget.textclock,
      },

      textbox {
        markup = '<b>PST</b>:',
      },

      {
        font     = font,
        format   = '%H:%M',
        timezone = 'America/Los_Angeles',
        refresh  = 60,
        widget   = wibox.widget.textclock,
      },

      layout          = wibox.layout.grid,
      forced_num_cols = 2,
    },

    {
      textbox {
        markup = '<b>Calendar:</b>',
      },

      {
        id              = 'cal_info',
        spacing         = 5,
        forced_num_cols = 2,
        layout          = wibox.layout.grid,
      },

      layout = wibox.layout.fixed.vertical,
    },

    {
      textbox {
        markup = '<b>Tasks:</b>',
      },

      {
        id              = 'tasks_info',
        spacing         = 5,
        forced_num_cols = 1,
        layout          = wibox.layout.grid,
      },

      layout = wibox.layout.fixed.vertical,
    },

    spacing_widget = wibox.widget.separator,
    spacing        = 5,
    layout         = wibox.layout.fixed.vertical,
  },

  ontop     = true,
  layout    = wibox.layout.fixed.vertical,
  placement = awful.placement.centered,
  visible   = false,
}

dashboard:connect_signal('property::visible', function(self)
  if not self.visible then
    return
  end

  local wifi_widget = dashboard.widget:get_children_by_id('wifi_info')[1]
  local public_ip_widget = dashboard.widget:get_children_by_id('public_ip_info')[1]
  local calendar_widget = dashboard.widget:get_children_by_id('cal_info')[1]
  local tasks_widget = dashboard.widget:get_children_by_id('tasks_info')[1]

  if config.wifi_info ~= false then
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
        wifi_widget.text = info.ssid .. ' (' .. info.ap_addr .. ')'
      end
    end

    wifi_widget.text = 'Loading...'

    awful.spawn.with_line_callback({'iw', 'dev', 'wlan0', 'link'}, callbacks)
  end

  if config.public_ip_info ~= false then
    public_ip_widget.text = 'Loading...'
    awful.spawn.easy_async_with_shell([[curl -s ipinfo.io | jq -r '.ip + " " + .city + ", " + .region']], function(stdout)
      public_ip_widget.text = string.gsub(stdout, '%s+$', '')
    end)
  end

  calendar_widget:reset()
  local f = io.open('/home/rob/.cache/cal', 'r')
  if f then
    for line in f:lines() do
      local fields = {}
      for field in string.gmatch(line, '[^\t]+') do
        fields[#fields + 1] = field
      end
      local start_time = fields[2]
      local end_time = fields[4]
      local event = fields[5]
      -- XXX detect all-day events

      local function decorate(s)
        return s
      end

      local now = os.date '%H:%M'

      if now >= start_time and now <= end_time then
        --[[local]] function decorate(s)
          return '<b>' .. s .. '</b>'
        end
      elseif now >= end_time then
        --[[local]] function decorate(s)
          return '<s>' .. s .. '</s>'
        end
      end

      calendar_widget:add(wibox.widget(textbox {
        markup = decorate(string.format('%s - %s', start_time, end_time)),
      }))
      calendar_widget:add(wibox.widget(textbox {
        text = event,
      }))
    end
    f:close()
  end

  tasks_widget:reset()
  f = io.open('/home/rob/.cache/todoist', 'r')
  if f then
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
        --[[local]] function decorate(s)
          return '<s>' .. s .. '</s>'
        end
      end

      tasks_widget:add(wibox.widget(textbox {
        markup = decorate(task),
      }))
    end
  end
end)

dashboard:connect_signal('button::release', function(self)
  if not self.visible then
    return
  end
  self.visible = false
end)

return dashboard
