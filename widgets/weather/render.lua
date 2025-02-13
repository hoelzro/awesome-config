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

local function render_popup(r, previous_refresh_time, request_in_flight, state, err)
  if state and state.station_details then
    r:printf(state.station_details .. '\n')
  end

  if previous_refresh_time then
    r:printf('Last refresh time: %s', os.date('%F %T', previous_refresh_time))
    r:print '\n'
  end

  if request_in_flight then
    r:printf('Retrieving status since %s', os.date('%F %T', request_in_flight))
    r:print '\n'
  end

  if state then
    r:table {
      {'Sunrise:', os.date('%T', state.sunrise_time)},
      {'Sunset:', os.date('%T', state.sunset_time)},
      {'Humidity:', state.humidity_percent and string.format('%.0f%%', state.humidity_percent) or '(unknown)'},
    }
  else
    r:printf('Error:             %s', err)
  end
end

return {
  widget = render_widget,
  popup  = render_popup,
}
