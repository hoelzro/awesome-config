local cqueues      = require 'cqueues'
local http_request = require 'http.request'
local json         = require 'dkjson'

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

return backends
