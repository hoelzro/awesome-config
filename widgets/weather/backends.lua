local cqueues      = require 'cqueues'
local http_request = require 'http.request'
local json         = require 'dkjson'
local uri_pattern  = require('lpeg_patterns.uri').uri

local calculate_sunrise_sunset = require 'widgets.weather.sunset'

local backends = {}

local canned_darksky_backend = {}
backends.canned_darksky_data = canned_darksky_backend

function canned_darksky_backend:new(filename)
  local f = assert(io.open(filename, 'r'))
  local contents = f:read '*a'
  f:close()

  local data = assert(json.decode(contents))

  return setmetatable({
    data = data,
  }, {__index = canned_darksky_backend})
end

function canned_darksky_backend:detect()
  return true
end

function canned_darksky_backend:state()
  cqueues.sleep(1)

  return {
    sunrise_time        = self.data.daily.data[1].sunriseTime,
    sunset_time         = self.data.daily.data[1].sunsetTime,
    temperature_celsius = self.data.currently.temperature,
    icon                = self.data.currently.icon,
  }
end

local darksky_backend = {}
backends.darksky = darksky_backend

function darksky_backend:new(config)
  return setmetatable(config, {__index = darksky_backend})
end

function darksky_backend:detect()
  return self.api_key and self.latitude and self.longitude
end

function darksky_backend:state()
  local url = string.format('https://api.darksky.net/forecast/%s/%s,%s?units=si',
    self.api_key,
    self.latitude,
    self.longitude)

  local headers, stream = http_request.new_from_uri(url):go(10)
  if not headers then
    return nil, stream
  end

  local body, err = stream:get_body_as_string()
  if not body then
    return nil, err
  end

  local res, _, err = json.decode(body)
  if not res then
    return nil, err
  end

  return {
    sunrise_time        = res.daily.data[1].sunriseTime,
    sunset_time         = res.daily.data[1].sunsetTime,
    temperature_celsius = res.currently.temperature,
    icon                = res.currently.icon,
  }
end

local WEATHER_GOV_ICON_MAP = {
  bkn = 'cloudy',
  blizzard = 'snow',
  cold = 'clear-day',
  dust = 'cloudy',
  few = 'partly-cloudy-day',
  fog = 'fog',
  fzra = 'rain',
  haze = 'fog',
  hot = 'clear-day',
  ovc = 'cloudy',
  rain = 'rain',
  rain_fzra = 'rain',
  rain_showers = 'rain',
  rain_showers_hi = 'rain',
  rain_sleet = 'rain',
  rain_snow = 'snow',
  sct = 'cloudy',
  skc = 'clear-day',
  sleet = 'snow',

  smoke = 'fog',

  snow = 'snow',
  snow_fzra = 'snow',
  snow_sleet = 'snow',

  tsra = 'cloudy',
  tsra_hi = 'cloudy',
  tsra_sct = 'cloudy',

  wind_bkn = 'wind',
  wind_few = 'wind',
  wind_ovc = 'wind',
  wind_sct = 'wind',
  wind_skc = 'wind',

  hurricane      = 'wind',
  tornado        = 'wind',
  tropical_storm = 'wind',
}

local weather_gov_backend = {}
backends.weather_gov = weather_gov_backend

function weather_gov_backend:new(config)
  return setmetatable(config, {__index = weather_gov_backend})
end

function weather_gov_backend:detect()
  return self.station
end

function weather_gov_backend:state()
  local url = string.format('https://api.weather.gov/stations/%s/observations/latest?require_qc=true', self.station)
  local res = assert(self:_http_request(url))

  local temperature_celsius = res.properties.temperature.value
  assert(res.properties.temperature.unitCode == 'wmoUnit:degC', tostring(res.properties.temperature.unitCode))

  -- XXX hardcoded TZ offset
  local sunrise_time, sunset_time = calculate_sunrise_sunset(res.geometry.coordinates[2], res.geometry.coordinates[1], -6)

  local icon_uri = uri_pattern:match(res.properties.icon)
  local icon = string.match(icon_uri.path, '.*/(.*)')

  return {
    sunrise_time        = sunrise_time,
    sunset_time         = sunset_time,
    temperature_celsius = temperature_celsius,
    icon                = WEATHER_GOV_ICON_MAP[icon] or 'clear-day',
  }
end

function weather_gov_backend:_http_request(url)
  local headers, stream = http_request.new_from_uri(url):go(10)
  if not headers then
    return nil, stream
  end

  local body, err = stream:get_body_as_string()
  if not body then
    return nil, err
  end

  local res, _, err = json.decode(body)
  if not res then
    return nil, err
  end

  return res
end

local canned_weather_gov_backend = setmetatable({}, {__index = weather_gov_backend})
backends.canned_weather_gov_data = canned_weather_gov_backend

function canned_weather_gov_backend:new(filename)
  local f = assert(io.open(filename, 'r'))
  local contents = f:read '*a'
  f:close()

  local observation_data = assert(json.decode(contents))

  return setmetatable({observations = observation_data}, {__index = canned_weather_gov_backend})
end

function canned_weather_gov_backend:detect()
  return true
end

function canned_weather_gov_backend:_http_request(url)
  cqueues.sleep(1)

  if string.sub(url, 1, #'https://api.weather.gov/stations/') == 'https://api.weather.gov/stations/' then
    return self.observations
  end

  error('unrecognized URL: ' .. url)
end

return backends
