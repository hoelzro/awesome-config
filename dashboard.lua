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

-- XXX temporarily assigned to global for iteration without restarting
dashboard = awful.popup {
  widget = {
    {
      text = 'eridanus Dashboard',
      widget = wibox.widget.textbox,
    },

    {
      {
        id     = 'public_ip_info',
        widget = wibox.widget.textbox,
      },

      layout = wibox.layout.flex.vertical,
    },

    layout         = wibox.layout.flex.vertical,
    spacing        = 5,
    spacing_widget = wibox.widget.separator,
  },

  ontop     = true,
  placement = awful.placement.centered,
  visible   = false,
}

old_widgets[dashboard] = true
log('# old widgets: %d', key_count(old_widgets))

dashboard:connect_signal('property::visible', function(self)
  if not self.visible then
    return
  end

  local public_ip_info_widget = dashboard.widget:get_children_by_id('public_ip_info')[1]
  -- XXX prevent duplicate requests when things are in flight, etc etc
  public_ip_info_widget.markup = 'Public IP: &lt;refreshing&gt;'
  awful.spawn.easy_async_with_shell([[curl -s ipinfo.io | jq -r '.ip + " " + .city + ", " + .region']], function(stdout)
    stdout = string.gsub(stdout, '^%s+|%s+$', '')
    public_ip_info_widget.markup = 'Public IP: ' .. stdout
  end)
end)

return dashboard
