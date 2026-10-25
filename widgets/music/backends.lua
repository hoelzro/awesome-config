local donut = require 'donut'

local log = print

local backends = {}

-- {{{ MPRIS backend
backends.mpris = {}

function backends.mpris:new()
  return setmetatable({}, {__index = self})
end

function backends.mpris:playpause()
  return require('audio').toggle()
end

function backends.mpris:next_track()
  return require('audio').next()
end

function backends.mpris:previous_track()
  return require('audio').previous()
end

local function extract_trackinfo(metadata)
  local trackinfo = {}

  if metadata['xesam:album'] then
    -- XXX handle empty string
    trackinfo.album = metadata['xesam:album']
  end

  if metadata['xesam:artist'] then
    -- XXX handle empty string
    trackinfo.artist = metadata['xesam:artist'][1]
  end

  if metadata['xesam:title'] then
    -- XXX handle empty string
    trackinfo.title = metadata['xesam:title']
  end

  if metadata['mpris:length'] then
    trackinfo.duration = metadata['mpris:length']
  end

  return trackinfo
end

-- trackchange callbacks are wrapped for a little extra processing, but since I'm using
-- weak_connect_signal the wrapper function doesn't end up with any strong references,
-- causing the GC to come for it.  This table here (which stores original callback → wrapper)
-- allows us to keep a strong reference to the wrapper via the table value, tied to a weak
-- reference to the original callback via the table key, so that when the last strong reference
-- to the *original* callback disappears, it - along with the wrapper function - are eligible
-- for collection
local trackchange_callback_wrappers = setmetatable({}, {__mode = 'k'})

function backends.mpris:weak_connect_signal(signal, callback)
  if signal == 'trackchange' then
    if not trackchange_callback_wrappers[callback] then
      local orig_callback = callback

      function callback(obj, metadata, ...)
        return orig_callback(obj, extract_trackinfo(metadata), ...)
      end

      trackchange_callback_wrappers[orig_callback] = callback
    end
  end

  return require('audio').weak_connect_signal(signal, callback)
end

function backends.mpris:client(addr)
  local session_bus = assert(donut.get_session_bus())
  local proxy = assert(session_bus:proxy(addr, '/org/mpris/MediaPlayer2'))

  local client = {}

  function client:status()
    return string.lower(proxy:Get('org.mpris.MediaPlayer2.Player', 'PlaybackStatus'))
  end

  function client:trackinfo()
    return extract_trackinfo(proxy:Get('org.mpris.MediaPlayer2.Player', 'Metadata'))
  end

  return client
end
-- }}}

-- {{{ tail -f backend
backends.tail_f = {}

local tail_f_methods = {}

function backends.tail_f:new(filename)
  local json  = require 'dkjson'
  local spawn = require 'awful.spawn'

  local object = require 'gears.object'

  local backend = object()
  for name, method in pairs(tail_f_methods) do
    backend[name] = method
  end

  local spawn_err = spawn.with_line_callback('tail -f ' .. filename, {
    stdout = function(line)
      local payload = json.decode(line)

      if payload.path ~= '/org/mpris/MediaPlayer2' then
        return
      end

      if payload.interface ~= 'org.freedesktop.DBus.Properties' then
        return
      end

      if payload.member ~= 'PropertiesChanged' then
        return
      end

      local changes = payload.args[2]

      if changes.PlaybackStatus then
        backend:emit_signal('playbackstatus', string.lower(changes.PlaybackStatus))
      end

      if changes.Metadata then
        backend:emit_signal('trackchange', extract_trackinfo(changes.Metadata))
      end
    end,

    exit = function(reason, exit_code)
      log(string.format('tail -f exited due to %s (exit code = %d)', reason, exit_code))
    end,
  })

  if type(spawn_err) == 'string' then
    log('failed to spawn tail -f: ' .. spawn_err)
  end

  return backend
end

function tail_f_methods:client()
  local client = {}

  function client:status()
    error 'NYI'
  end

  function client:trackinfo()
    error 'NYI'
  end

  return client
end

function tail_f_methods:playpause()
  print 'would toggle play/pause state'
end

function tail_f_methods:next_track()
  print 'would go to next track'
end

function tail_f_methods:previous_track()
  print 'would go to previous track'
end
-- }}}

return backends

-- vim:ft=lua:ts=2:sw=2:sts=2:tw=100:et:fdm=marker
