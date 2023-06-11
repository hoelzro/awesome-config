local backends = require 'widgets.weather.backends'
local render = require 'widgets.weather.render'
local make_renderer = require 'widgets.renderer'

local render_widget = render.widget
local render_popup = render.popup

local backend = backends.canned_weather_gov_data:new '/tmp/canned-weather-gov-observations.json'
assert(backend:detect())

local state = assert(backend:state())

do
  local r = make_renderer()
  render_widget(r, state)
  print('Widget:\n' .. r:markup())
end

do
  local r = make_renderer()
  render_popup(r, nil, nil, state)
  print('Popup:\n' .. r:markup())
end
