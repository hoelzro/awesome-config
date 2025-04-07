local calculate_sunrise_sunset = require 'widgets.weather.sunset'
local assert = require 'smart_assert'

local TEST_THRESHOLD = 300

local function get_tz_offset(timezone, year, month, day)
  local p = io.popen(string.format('TZ=%s date -d "%04d-%02d-%02d" +%%z', timezone, year, month, day))
  local line, err = p:read '*l'
  p:close()
  if err then
    error(err)
  end

  return tonumber(string.match(line, '^([+-]?%d%d)00$'))
end

local function chicago_test(params)
  params.latitude  = 41.881944
  params.longitude = -87.627778
  params.timezone  = 'America/Chicago'

  return params
end

local function phoenix_test(params)
  params.latitude  = 33.448333
  params.longitude = -112.073889
  params.timezone  = 'America/Phoenix'

  return params
end

local function london_test(params)
  params.latitude  = 51.507222
  params.longitude = -0.1275
  params.timezone  = 'Europe/London'

  return params
end

local function honolulu_test(params)
  params.latitude  = 21.306944
  params.longitude = -157.858333
  params.timezone  = 'Pacific/Honolulu'

  return params
end

local function jerusalem_test(params)
  params.latitude  = 31.783333
  params.longitude = 35.216667
  params.timezone  = 'Asia/Jerusalem'

  return params
end

local tests = {
  chicago_test {
    year  = 2025,
    month = 4,
    day   = 6,

    expected_sunrise = 1743938700,
    expected_sunset  = 1743985260,
  },

  chicago_test {
    year  = 2024,
    month = 12,
    day   = 21,

    expected_sunrise = 1734786900,
    expected_sunset  = 1734819720,
  },

  phoenix_test {
    year  = 2025,
    month = 4,
    day   = 6,

    expected_sunrise = 1743944880,
    expected_sunset  = 1743990720,
  },

  phoenix_test {
    year  = 2024,
    month = 12,
    day   = 21,

    expected_sunrise = 1734791280,
    expected_sunset  = 1734827040,
  },

  london_test {
    year  = 2025,
    month = 4,
    day   = 6,

    expected_sunrise = 1743917040,
    expected_sunset  = 1743964920,
  },

  london_test {
    year  = 2024,
    month = 12,
    day   = 21,

    expected_sunrise = 1734768180,
    expected_sunset  = 1734796380,
  },

  honolulu_test {
    year  = 2025,
    month = 4,
    day   = 6,

    expected_sunrise = 1743956400,
    expected_sunset  = 1744001280,
  },

  honolulu_test {
    year  = 2024,
    month = 12,
    day   = 21,

    expected_sunrise = 1734800640,
    expected_sunset  = 1734839700,
  },

  jerusalem_test {
    year  = 2025,
    month = 4,
    day   = 6,

    expected_sunrise = 1743909660,
    expected_sunset  = 1743955320,
  },

  jerusalem_test {
    year  = 2024,
    month = 12,
    day   = 21,

    expected_sunrise = 1734755700,
    expected_sunset  = 1734791940,
  },
}

for i = 1, #tests do
  local t = tests[i]

  local tz_offset = get_tz_offset(t.timezone, t.year, t.month, t.day)

  local got_sunrise, got_sunset = calculate_sunrise_sunset(t.latitude, t.longitude, tz_offset, t)

  local sunrise_delta = math.abs(got_sunrise - t.expected_sunrise)
  local sunset_delta = math.abs(got_sunset - t.expected_sunset)

  assert(sunrise_delta < TEST_THRESHOLD, string.format('calculated sunrise (%d) was %d second(s) before actual sunrise (%d)', got_sunrise, t.expected_sunrise - got_sunrise, t.expected_sunrise))
  assert(sunset_delta < TEST_THRESHOLD)
end
