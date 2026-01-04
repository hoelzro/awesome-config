-- Mock battery backend for testing
--
-- Usage from awesome-client:
--   local mock = require 'widgets.battery.mock'
--   mock:plug_in()       -- Start charging (with transient "not charging" state)
--   mock:unplug()        -- Start discharging
--   mock:set_rate(0.1)   -- Charge/discharge in 10 seconds
--   mock:set_charge(0.5) -- Set charge to 50%
--   mock:set_transient_duration(3) -- Set "not charging" duration to 3 seconds
--
-- The mock backend simulates real hardware behavior where plugging in
-- initially reports "Not charging" for a few seconds before switching
-- to "Charging". This allows testing the transient state handling.

local backends = require 'widgets.battery.backends'

local mock_instance

local M = {}

function M.get()
  if not mock_instance then
    mock_instance = backends.mock:new()
    mock_instance:detect()
  end
  return mock_instance
end

function M:plug_in()
  return M.get():plug_in()
end

function M:unplug()
  return M.get():unplug()
end

function M:set_rate(rate)
  return M.get():set_rate(rate)
end

function M:set_charge(charge)
  return M.get():set_charge(charge)
end

function M:get_charge()
  return M.get():get_charge()
end

function M:state()
  return M.get():state()
end

function M:set_transient_duration(duration)
  return M.get():set_transient_duration(duration)
end

return M
