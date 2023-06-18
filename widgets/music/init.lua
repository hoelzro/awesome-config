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
    max_size    = 75,
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

  local playback_state = 'playing'
  local current_track = {}

  local function refresh()
    icon_widget:set_markup('<b>' .. ICONS[playback_state] .. '</b>')
    song_widget:set_text(string.format('%s - %s',
      current_track.artist or '',
      current_track.title or ''))
  end

  local function handle_trackchange(_, trackinfo)
    current_track = trackinfo
    refresh()
  end

  local function handle_playbackstatus(_, status)
    playback_state = status
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
