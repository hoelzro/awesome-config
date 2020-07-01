local awful = require 'awful'

local audio = {}

local latest_address

dbus.connect_signal('org.freedesktop.DBus.Properties', function(metadata, name)
  if name ~= 'org.mpris.MediaPlayer2.Player' then
    return
  end

  latest_address = metadata.sender
end)

local function run_on_latest(cmd)
  if not latest_address then
    return
  end

  awful.spawn(string.format('dbus-send --type=method_call --dest="%s" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.%s',
    latest_address, cmd))
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
