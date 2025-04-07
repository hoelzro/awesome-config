local ceil  = math.ceil
local floor = math.floor

-- trigonometric functions that work in terms of degrees
local function sin(degrees)
  return math.sin(math.rad(degrees))
end

local function asin(x)
  return math.deg(math.asin(x))
end

local function cos(degrees)
  return math.cos(math.rad(degrees))
end

local function acos(x)
  return math.deg(math.acos(x))
end

-- from https://en.wikipedia.org/wiki/Julian_day#Converting_Gregorian_calendar_date_to_Julian_Day_Number
local function julian_date(t)
  local year, month, day = t.year, t.month, t.day
  return (1461 * (year + 4800 + (month - 14)/12))/4 + (367 * (month - 2 - 12 * ((month - 14)/12)))/12 - (3 * ((year + 4900 + (month - 14)/12)/100))/4 + day - 32075
end

local function calculate_sunrise_sunset(lat, lon, tz_offset, t)
  if not t then
    t = os.date '*t'
  end

  local n = ceil(julian_date(t) - 2451545 + 0.0008)

  local mean_solar_time = n - lon / 360
  local solar_mean_anomaly = (357.5291 + 0.98560028 * mean_solar_time) % 360 -- XXX are you sure % 360 does the trick here?
  local equation_of_center = 1.9148 * sin(solar_mean_anomaly) + 0.02 * sin(2 * solar_mean_anomaly) + 0.0003 * sin(3 * solar_mean_anomaly)
  local ecliptic_longitude = (solar_mean_anomaly + equation_of_center + 180 + 102.9372) % 360 -- XXX are you sure % 360 does the trick here?
  local solar_transit = 2451545 + mean_solar_time + 0.0053 * sin(solar_mean_anomaly) - 0.0069 * sin(2 * ecliptic_longitude)
  local sun_declination = asin(sin(ecliptic_longitude) * sin(23.44))
  -- -0.83 is the "official" sunrise/sunset, rather than civil twilight or w/e
  local hour_angle = acos((sin(-0.83) - sin(lat) * sin(sun_declination)) / (cos(lat) * cos(sun_declination)))

  local sunrise = solar_transit - hour_angle / 360
  sunrise = sunrise - floor(sunrise)
  sunrise = sunrise * 86400
  sunrise = sunrise - tz_offset * 3600
  if t.isdst then
    sunrise = sunrise + 3600
  end

  sunrise = floor(sunrise + os.time {
    year  = t.year,
    month = t.month,
    day   = t.day,
    hour  = 0,
    isdst = t.isdst,
  })

  local sunset  = solar_transit + hour_angle / 360
  sunset = sunset - floor(sunset)
  sunset = sunset * 86400
  sunset = sunset - tz_offset * 3600
  if t.isdst then
    sunset = sunset + 3600
  end

  sunset = floor(sunset + os.time {
    year  = t.year,
    month = t.month,
    day   = t.day,
    hour  = 0,
    isdst = t.isdst,
  })

  return sunrise, sunset
end

return calculate_sunrise_sunset
