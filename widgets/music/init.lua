local awful = require 'awful'
local wibox = require 'wibox'

local donut = require 'donut'
local timer = require 'gears.timer'

local backends = require 'widgets.music.backends'

local unpack = unpack or table.unpack

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

  -- XXX should this bundle with last_update?
  local prev_position_update
  local position_timer

  local player_states = {}

  local function init_player_state(client_addr)
    local client = backend:client(client_addr)

    return {
      playback_state = client:status(),
      current_track  = client:trackinfo(),
      position       = client:position(),
    }
  end

  local function refresh()
    local current_playing
    local latest_paused

    for _, player in pairs(player_states) do
      if player.playback_state == 'playing' and (not current_playing or current_playing.last_update < player.last_update) then
        current_playing = player
      elseif player.playback_state == 'paused' and (not latest_paused or latest_paused.last_update < player.last_update) then
        latest_paused = player
      end
    end

    local player = current_playing or latest_paused

    if player then
      if player.playback_state == 'playing' and not position_timer.started then
        prev_position_update = math.floor(os.time() * 1000000)
        position_timer:again()
      elseif player.playback_state ~= 'playing' and position_timer.started then
        position_timer:stop()
      end

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

  local function donut_wrapper(f)
    return function(...)
      local arg_count = select('#', ...)
      local args = {...}
      donut.run(function()
        f(unpack(args, 1, arg_count))
      end, function(ok, err)
        if not ok then
          log(err)
        end
      end)
    end
  end

  local handle_trackchange = donut_wrapper(function(_, trackinfo, signal_metadata)
    local sender = signal_metadata.sender

    if not player_states[sender] then
      player_states[sender] = init_player_state(sender)
    end

    player_states[sender].last_update = os.time()
    player_states[sender].current_track = trackinfo
    prev_position_update = math.floor(os.time() * 1000000)
    player_states[sender].position = 0

    refresh()
  end)

  local handle_playbackstatus = donut_wrapper(function(_, status, signal_metadata)
    local sender = signal_metadata.sender

    if not player_states[sender] then
      player_states[sender] = init_player_state(sender)
    end

    player_states[sender].last_update = os.time()
    player_states[sender].playback_state = status
    prev_position_update = math.floor(os.time() * 1000000)
    refresh()
  end)

  local handle_seeked = donut_wrapper(function(_, position, signal_metadata)
    local sender = signal_metadata.sender

    if not player_states[sender] then
      player_states[sender] = init_player_state(sender)
    end

    player_states[sender].last_update = os.time()
    player_states[sender].position = position
    prev_position_update = math.floor(os.time() * 1000000)

    refresh()
  end)

  local function handle_gone(_, sender)
    player_states[sender] = nil
  end

  local function position_timer_callback()
    local now = math.floor(os.time() * 1000000)
    local dt = now - prev_position_update
    prev_position_update = now

    local current_playing

    for _, player in pairs(player_states) do
      if player.playback_state == 'playing' and (not current_playing or current_playing.last_update < player.last_update) then
        current_playing = player
      end
    end

    if current_playing then
      current_playing.position = current_playing.position + dt
      refresh()
    end

    return true
  end

  --[[local]] position_timer = timer.weak_start_new(1, position_timer_callback)
  position_timer:stop()

  refresh()

  -- XXX delegate to caller?
  top_widget:buttons(awful.util.table.join(
    awful.button({}, 1, method(backend, 'playpause')),
    awful.button({}, 4, method(backend, 'next_track')),
    awful.button({}, 5, method(backend, 'previous_track'))))

  backend:weak_connect_signal('trackchange', handle_trackchange)
  backend:weak_connect_signal('playbackstatus', handle_playbackstatus)
  backend:weak_connect_signal('seeked', handle_seeked)
  backend:weak_connect_signal('gone', handle_gone)

  widgets[top_widget] = {
    handle_trackchange,
    handle_playbackstatus,
    handle_seeked,
    handle_gone,
    position_timer_callback,
  }

  return top_widget
end

-- TODO:
--   initial toggle play/pause doesn't populate metadata (this was/is an existing issue, though)

-- XXX fetch MPRIS state on startup

return make_widget
