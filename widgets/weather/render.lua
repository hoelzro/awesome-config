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

local function render_widget(r, state, err)
  if state then
    local icon = icons[state.icon] or ''

    r:printf(icon)
    r:print ' '
    r:printf('%.1f °%s', state.temperature_celsius, 'C')
  else
    r:print 'unable to retrieve forecast @_@'
  end
end

local function render_popup(r, previous_refresh_time, state, err)
  if previous_refresh_time then
    r:printf('Last refresh time: %s', os.date('%F %T', previous_refresh_time))
    r:print '\n'
  end

  if state then
    r:printf('Sunrise:           %s', os.date('%T', state.sunrise_time))
    r:print '\n'
    r:printf('Sunset:            %s', os.date('%T', state.sunset_time))
  else
    r:printf('Error:             %s', err)
  end
end

return {
  widget = render_widget,
  popup  = render_popup,
}
