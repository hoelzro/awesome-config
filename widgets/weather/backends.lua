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
  local api_endpoint = string.match(self.api_endpoint or 'https://api.weather.gov', '(.*[^/])/?$')

  if not self._station_name then
    local url = string.format('%s/stations/%s', api_endpoint, self.station)
    local res = assert(self:_http_request(url))
    self._station_name = res.properties.name
  end

  local url = string.format('%s/stations/%s/observations/latest?require_qc=true', api_endpoint, self.station)
  local res = assert(self:_http_request(url))

  local temperature_celsius = res.properties.temperature.value
  assert(res.properties.temperature.unitCode == 'wmoUnit:degC', tostring(res.properties.temperature.unitCode))

  local tz_offset = tonumber(string.match(os.date '%z', '^([+-]?%d%d)00$'))
  local sunrise_time, sunset_time = calculate_sunrise_sunset(res.geometry.coordinates[2], res.geometry.coordinates[1], tz_offset)

  local icon = 'unknown'
  if res.properties.icon then
    local icon_uri = uri_pattern:match(res.properties.icon)
    icon = string.match(icon_uri.path, '.*/(.*)')
  end

  local humidity = res.properties.relativeHumidity.value
  assert(res.properties.relativeHumidity.unitCode == 'wmoUnit:percent')

  local station_details = string.format('%s (%s)', self.station, self._station_name)

  return {
    station_details     = station_details,
    sunrise_time        = sunrise_time,
    sunset_time         = sunset_time,
    temperature_celsius = temperature_celsius,
    humidity_percent    = humidity,
    icon                = WEATHER_GOV_ICON_MAP[icon] or 'clear-day',
  }
end

local MAX_TRIES = 4
local TIMEOUT = 2

local function startswith(s, prefix)
  return string.sub(s, 1, #prefix) == prefix
end

local function endswith(s, suffix)
  return string.sub(s, -1 * #suffix) == suffix
end

local function is_retryable(err)
  if endswith(err, 'Connection timed out') then
    return true
  end

  if startswith(err, 'got HTTP response 5') then
    return true
  end

  return false
end

local function _make_single_request(url)
  local headers, stream = http_request.new_from_uri(url):go(TIMEOUT)
  if not headers then
    if not is_retryable(stream) then
      stream = 'unable to make request: ' .. tostring(stream)
    end
    return nil, stream
  end

  local status_code = headers:get ':status'

  local body, err = stream:get_body_as_string()
  if not body then
    if not is_retryable(err) then
      err = 'unable to read body: ' .. tostring(err)
    end
    return nil, err
  end

  local res, _, err = json.decode(body)
  if not res then
    if status_code == '200' then
      return nil, 'unable to parse JSON for 200 response: ' .. tostring(err)
    else
      return nil, string.format('got HTTP response %s%s', status_code, tostring(body))
    end
  end

  if status_code ~= '200' then
    return nil, string.format('got HTTP response %s (%s)', status_code, tostring(res.title))
  end

  return res
end

function weather_gov_backend:_http_request(url)
  for try_num = 1, MAX_TRIES do
    local res, err = _make_single_request(url)

    if res then
      return res
    elseif is_retryable(err) then
      local sleep_time = 2 ^ (try_num - 1)
      cqueues.sleep(sleep_time)
    else
      return nil, err
    end
  end

  return nil, 'max retries exceeded'
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
