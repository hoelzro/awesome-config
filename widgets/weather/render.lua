-- XXX currently hardcoded for DarkSky icons
local icons = {
  ['clear-day']           = '☼',
  ['clear-night']         = '🌙',
  ['partly-cloudy-day']   = '⛅',
  ['partly-cloudy-night'] = '⛅',
  cloudy                  = '☁',
  rain                    = '🌧',
  sleet                   = '',
  snow                    = '❄',
  wind                    = '',
  fog                     = '🌁',
}

local function render_widget(r, state)
  local icon = icons[state.icon] or ''

  r:printf(icon)
  r:print ' '
  r:printf('%.1f °%s', state.temperature_celsius, 'C')
end

local function render_popup(r, state)
  r:printf('Last refresh time: %s', os.date('%F %T', state.last_refresh_time))
  r:print '\n'
  r:printf('Sunrise:           %s', os.date('%T', state.sunrise_time))
  r:print '\n'
  r:printf('Sunset:            %s', os.date('%T', state.sunset_time))
end

return {
  widget = render_widget,
  popup  = render_popup,
}
