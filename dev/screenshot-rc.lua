-- Screenshot wrapper rc. Installs minimal stubs/canned data so the
-- real rc.lua runs end-to-end inside Xvfb (no network, no hwmon),
-- then defers to the real rc.lua.
--
-- To stub a new backend, follow the patterns below: pre-load the
-- backends module, then monkey-patch its constructor or relevant
-- methods before dofile().

local CONFIG_DIR = '/home/rob/.config/awesome'

package.path = CONFIG_DIR .. '/?.lua;' .. CONFIG_DIR .. '/?/init.lua;' .. package.path

-- Weather: no internet in sandbox -> serve from canned fixtures.
do
  local backends = require 'widgets.weather.backends'
  local canned = backends.canned_weather_gov_data:new(CONFIG_DIR .. '/dev/testdata/canned-weather-gov-observations.json')
  backends.weather_gov.new = function() return canned end
end

-- Temperature: most sandboxes lack populated /sys/class/hwmon.
do
  local backends = require 'widgets.temperature.backends'
  local stub = setmetatable({}, {__index = backends.sysfs})
  function stub:detect() return true end
  function stub:state() return 42.5 end
  backends.sysfs.new = function() return stub end
end

dofile(CONFIG_DIR .. '/rc.lua')
