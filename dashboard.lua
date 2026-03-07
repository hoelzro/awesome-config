local awful = require 'awful'
local wibox = require 'wibox'
local utils = require 'dashboard.utils'

if dashboard then
  dashboard.visible = false
end

local hostname = '<unknown>'
local pipe = io.popen 'hostname'
if pipe then
  hostname = pipe:read '*a'
  hostname = string.gsub(hostname, '%s+$', '')
  pipe:close()
end

local config = require 'dashboard.config'

local confdir = require('gears.filesystem').get_configuration_dir()
local section_dir = confdir .. 'dashboard/'

-- Sections loaded via require (cached) instead of dofile to avoid resource leaks.
-- textclock widgets create GLib timers that would accumulate if recreated on every show.
local cached_sections = { 'clocks' }
local section_cache = {}
for _, name in ipairs(cached_sections) do
  section_cache[name] = require('dashboard.' .. name)
end

local function load_section(name)
  if section_cache[name] then
    return true, section_cache[name]
  end
  return pcall(dofile, section_dir .. name .. '.lua')
end

dashboard = awful.popup {
  widget    = wibox.widget { layout = wibox.layout.fixed.vertical },
  ontop     = true,
  layout    = wibox.layout.fixed.vertical,
  placement = awful.placement.centered,
  visible   = false,
}

dashboard:connect_signal('property::visible', function(self)
  if not self.visible then return end

  local children = {
    wibox.widget(utils.textbox { markup = '<b>' .. hostname .. ' dashboard</b>' }),
  }
  local refreshers = {}

  for _, name in ipairs(config.sections) do
    local ok, section = load_section(name)
    if ok and section and section.widget then
      children[#children + 1] = section.widget
      if section.refresh then
        refreshers[#refreshers + 1] = section.refresh
      end
    elseif not ok then
      children[#children + 1] = wibox.widget(utils.textbox {
        markup = '<i>Error loading ' .. name .. ': ' .. tostring(section) .. '</i>',
      })
    end
  end

  children.spacing_widget = wibox.widget.separator
  children.spacing        = 5
  children.layout         = wibox.layout.fixed.vertical
  self.widget = wibox.widget(children)

  for _, refresh in ipairs(refreshers) do
    refresh()
  end
end)

dashboard:connect_signal('button::release', function(self)
  if not self.visible then return end
  self.visible = false
end)

return dashboard
