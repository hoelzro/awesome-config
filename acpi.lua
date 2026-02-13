local spawn = require 'awful.spawn'
local timer = require 'gears.timer'
local naughty = require 'naughty'

local acpi = {}

local log = print

local signal_object = require('gears.object')()
local consecutive_failures = 0
local last_spawn_time = 0
local started = false

local respawn_timer

local function spawn_acpi_listen()
  local spawn_err = spawn.with_line_callback('acpi_listen', {
    stdout = function(line)
      if string.sub(line, 1, #'battery') == 'battery' then
        signal_object:emit_signal 'battery'
      end
    end,

    exit = function(reason, exit_code)
      log(string.format('acpi_listen exited due to %s (exit code = %d)', reason, exit_code))
      if os.time() - last_spawn_time >= 60 then
        consecutive_failures = 0
      else
        consecutive_failures = consecutive_failures + 1
        if consecutive_failures == 3 then
          naughty.notify {
            title   = 'acpi_listen',
            text    = 'acpi_listen failed to restart',
            timeout = 0,
            preset  = naughty.config.presets.critical,
          }
        end
      end
      respawn_timer:again()
    end,
  })

  if type(spawn_err) == 'string' then
    log('failed to spawn acpi_listen: ' .. spawn_err)
    consecutive_failures = consecutive_failures + 1
    if consecutive_failures == 3 then
      naughty.notify {
        title   = 'acpi_listen',
        text    = 'acpi_listen failed to restart',
        timeout = 0,
        preset  = naughty.config.presets.critical,
      }
    end
    -- timer keeps running, will retry in 60s
  else
    last_spawn_time = os.time()
    respawn_timer:stop()
  end
end

respawn_timer = timer {
  timeout   = 60,
  autostart = false,
  callback  = spawn_acpi_listen,
}

function acpi.weak_connect_signal(...)
  if not started then
    started = true
    respawn_timer:start()
    spawn_acpi_listen()
  end
  return signal_object:weak_connect_signal(...)
end

return acpi
