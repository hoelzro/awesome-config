local function tuck_in(f, ...)
  local co = coroutine.create(f)

  local function again(...)
    local ok, sleep_amount = coroutine.resume(co, ...)

    if ok and coroutine.status(co) == 'suspended' then
      local t = timer {
        timeout = sleep_amount,
      }

      t:connect_signal('timeout',  function()
        t:stop()
        t = nil
        return again()
      end)

      t:start()
    end
  end

  again(...)
end

local function sleep(amount)
  coroutine.yield(amount)
end

return {
  tuck_in = tuck_in,
  sleep   = sleep,
}

--[[

Example usage:

local sleep_dealer = require 'sleep-dealer'
local tuck_in      = sleep_dealer.tuck_in
local sleep        = sleep_dealer.sleep

tuck_in(function()
  for i = 1, 5 do
    sleep(1) -- sleeps for a second
    -- do something
  end
end)

Some functions may not work with this because of odd
interaction with Lua's coroutines (ex. naughty.notify);
use with caution!

--]]
