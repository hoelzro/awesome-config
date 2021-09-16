local awful   = require 'awful'
local donut   = require 'donut'
local naughty = require 'naughty'

local MAX_VOLUME = 65536

local audio = {}

local volume_icon_base = '/usr/share/icons/gnome/24x24/status/'

local do_volume_notification
do
  local notification

  --[[local]] function do_volume_notification(args)
    if notification and notification.box.visible then
      args.replaces_id = notification.id
    end

    if args.icon then
      args.icon = volume_icon_base .. args.icon
    end

    notification = naughty.notify(args)
  end
end

local latest_proxy

local function on_volume_change(_, _, _, _, _, params)
  local volume = params[1][1]
  do_volume_notification {
    title   = 'Volume Changed',
    text    = string.format('%.0f%%', 100 * volume / MAX_VOLUME),
    icon    = 'stock_volume-max.png',
    opacity = volume / MAX_VOLUME,
  }
end

local function on_mute_change(_, _, _, _, _, params)
  local is_muted = params[1]
  if is_muted then
    do_volume_notification {
      title = 'Volume Changed',
      text  = 'Muted',
      icon  = 'stock_volume-mute.png'
    }
  else
    do_volume_notification {
      title = 'Volume Changed',
      text  = 'Unmuted',
      icon  = 'stock_volume-max.png'
    }
  end
end

local pulse_bus

donut.run(function()
  local session_bus = assert(donut.get_session_bus())
  local pulse_lookup = session_bus:proxy('org.PulseAudio1', '/org/pulseaudio/server_lookup1')
  local pulse_bus_address = assert(pulse_lookup:Get('org.PulseAudio.ServerLookup1', 'Address'))
  pulse_bus = assert(donut.get_bus(pulse_bus_address))

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

    -- XXX these are always run on the main coroutine, it seems - should I make
    --     that not the case in donut.dbus? would that affect usage of naughty above?
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

-- XXX get rid of this when you can
local lgi = require 'lgi'
local glib = lgi.require 'GLib'

function audio.louder(delta)
  if not pulse_bus then
    return
  end

  donut.run(function()
    -- XXX keep the proxy around and refresh it based on signals?
    local pulse_core = assert(pulse_bus:proxy('org.PulseAudio.Core1', '/org/pulseaudio/core1'))
    local default_sink = assert(pulse_core:Get('org.PulseAudio.Core1', 'FallbackSink'))
    local sink_proxy = assert(pulse_bus:proxy('org.PulseAudio.Core1.Device', default_sink))

    local current_volume = assert(sink_proxy:Get('org.PulseAudio.Core1.Device', 'Volume'))[1]
    local base_volume = assert(sink_proxy:Get('org.PulseAudio.Core1.Device', 'BaseVolume')) -- XXX cache this?

    -- XXX step size?
    current_volume = current_volume + (base_volume * delta / 100)
    current_volume = math.min(base_volume, math.max(0, current_volume))

    local v = glib.Variant('au', { current_volume, current_volume }) -- XXX this sucks, but it'll do for now
    assert(sink_proxy:Set('org.PulseAudio.Core1.Device', 'Volume', v))
  end, function(ok, err)
    if not ok then
      print(string.format('failed to change volume: %s', err))
    end
  end)

end

function audio.quieter(delta)
  return audio.louder(-1 * delta)
end

function audio.togglemute()
  if not pulse_bus then
    return
  end

  donut.run(function()
    -- XXX keep the proxy around and refresh it based on signals?
    local pulse_core = assert(pulse_bus:proxy('org.PulseAudio.Core1', '/org/pulseaudio/core1'))
    local default_sink = assert(pulse_core:Get('org.PulseAudio.Core1', 'FallbackSink'))
    local sink_proxy = assert(pulse_bus:proxy('org.PulseAudio.Core1.Device', default_sink))

    local is_muted, err = sink_proxy:Get('org.PulseAudio.Core1.Device', 'Mute')
    if is_muted == nil then
      error(err)
    end

    assert(sink_proxy:Set('org.PulseAudio.Core1.Device', 'Mute', glib.Variant('b', not is_muted)))
  end, function(ok, err)
    if not ok then
      print(string.format('failed to toggle mute: %s', err))
    end
  end)
end

return audio
