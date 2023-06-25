local awful = require 'awful'
local wibox = require 'wibox'

local backends = require 'widgets.music.backends'

local log = print

local ICONS = {
  playing = '⏵',
  paused  = '⏸',
  stopped = '⏹',
}

local function method(obj, name)
  return function(...)
    return obj[name](obj, ...)
  end
end

local backend = backends.mpris:new()

-- we need to track strong references to the backend callbacks via
-- this, since the callbacks are only weakly connected to the backend
local widgets = setmetatable({}, {__mode = 'k'})

local function make_widget()
  local icon_widget = wibox.widget { widget = wibox.widget.textbox }
  local song_widget = wibox.widget { widget = wibox.widget.textbox }
  local marquee_widget = wibox.widget {
    song_widget,

    layout      = wibox.container.scroll.horizontal,
    max_size    = 300, -- XXX use fontmetrics to calculate size?
    extra_space = 3, -- XXX use fontmetrics to calculate spacing?
    fps         = 1,
  }

  -- XXX lay out declaratively and then populate locals by looking them up?
  local top_widget = wibox.widget {
    icon_widget,
    marquee_widget,

    spacing = 3, -- XXX use fontmetrics to calculate spacing?
    layout = wibox.layout.fixed.horizontal,
  }

  local player_states = {}

  local function refresh()
    local current_playing
    local latest_paused

    for _, player in pairs(player_states) do
      if player.playback_state == 'playing' then
        current_playing = player
      elseif player.playback_state == 'paused' and (not latest_paused or latest_paused.last_update < player.last_update) then
        latest_paused = player
      end
    end

    local player = current_playing or latest_paused

    if player then
      icon_widget:set_markup('<b>' .. ICONS[player.playback_state] .. '</b>')
      if player.current_track.artist ~= '' then
        song_widget:set_text(string.format('%s - %s',
          player.current_track.artist or '',
          player.current_track.title or ''))
      else
        song_widget:set_text(player.current_track.title)
      end
    else
      icon_widget:set_markup('<b>' .. ICONS.stopped .. '</b>')
      song_widget:set_text 'Music Stopped'
    end
  end

  local function handle_trackchange(_, trackinfo, signal_metadata)
    local sender = signal_metadata.sender
    player_states[sender] = player_states[sender] or {
      playback_state = 'stopped',
      current_track  = {},
    }

    player_states[sender].last_update = os.time()
    player_states[sender].current_track = trackinfo

    refresh()
  end

  local function handle_playbackstatus(_, status, signal_metadata)
    local sender = signal_metadata.sender
    player_states[sender] = player_states[sender] or {
      playback_state = 'stopped',
      current_track  = {},
    }

    player_states[sender].last_update = os.time()
    player_states[sender].playback_state = status
    refresh()
  end

  refresh()

  -- XXX delegate to caller?
  top_widget:buttons(awful.util.table.join(
    awful.button({}, 1, method(backend, 'playpause')),
    awful.button({}, 4, method(backend, 'next_track')),
    awful.button({}, 5, method(backend, 'previous_track'))))

  backend:weak_connect_signal('trackchange', handle_trackchange)
  backend:weak_connect_signal('playbackstatus', handle_playbackstatus)

  widgets[top_widget] = {
    handle_trackchange,
    handle_playbackstatus,
  }

  return top_widget
end

-- TODO:
--   initial toggle play/pause doesn't populate metadata (this was/is an existing issue, though)

-- XXX fetch MPRIS state on startup

return make_widget
