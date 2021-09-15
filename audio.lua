local awful = require 'awful'
local donut = require 'donut'

local MAX_VOLUME = 65536

local audio = {}

local latest_proxy

local function on_volume_change(_, _, _, _, _, params)
  local volume = params[1][1]
  print(string.format('volume: %.0f%%', 100 * volume / MAX_VOLUME))
end

local function on_mute_change(_, _, _, _, _, params)
  local is_muted = params[1]
  print('muted?', is_muted)
end

donut.run(function()
  local session_bus = assert(donut.get_session_bus())
  local pulse_lookup = session_bus:proxy('org.PulseAudio1', '/org/pulseaudio/server_lookup1')
  local pulse_bus_address = assert(pulse_lookup:Get('org.PulseAudio.ServerLookup1', 'Address'))
  local pulse_bus = assert(donut.get_bus(pulse_bus_address))

  local pulse_core = pulse_bus:proxy('org.PulseAudio.Core1', '/org/pulseaudio/core1')
  assert(pulse_core:ListenForSignal('org.PulseAudio.Core1.Device.VolumeUpdated', {}))
  assert(pulse_core:ListenForSignal('org.PulseAudio.Core1.Device.MuteUpdated', {}))

  pulse_bus:subscribe {
    interface = 'org.PulseAudio.Core1.Device',
    member    = 'VolumeUpdated',
    callback  = on_volume_change,
  }

  pulse_bus:subscribe {
    interface = 'org.PulseAudio.Core1.Device',
    member    = 'MuteUpdated',
    callback  = on_mute_change,
  }

  session_bus:subscribe {
    object_path = '/org/mpris/MediaPlayer2',
    interface   = 'org.freedesktop.DBus.Properties',
    member      = 'PropertiesChanged',

    -- XXX these are always run on the main coroutine, it seems - should I make that not the case?
    callback = function(_, sender)
      donut.run(function()
        -- XXX detecting the latest_proxy getting off the bus would be nice!
        latest_proxy = session_bus:proxy(sender, '/org/mpris/MediaPlayer2')
      end, function() end)
    end,
  }

  -- XXX detect who, if anyone, is currently playing?
end, function(ok, err)
  if not ok then
    print('failed to initialize audio stuff:', err)
  end
end)

local function run_on_latest(cmd)
  if not latest_proxy then
    return
  end

  donut.run(function()
    assert(latest_proxy[cmd](latest_proxy))
  end, function(ok, err)
    if not ok then
      print(string.format('failed to run MPRIS command %q: %s'), cmd, err)
    end
  end)
end

function audio.next()
  run_on_latest 'Next'
end

function audio.previous()
  run_on_latest 'Previous'
end

function audio.toggle()
  run_on_latest 'PlayPause'
end

function audio.stop()
  run_on_latest 'Stop'
end

return audio
