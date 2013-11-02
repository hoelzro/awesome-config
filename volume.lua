local rmatch   = require('rex_pcre').match
local popen    = io.popen
local execute  = os.execute
local format   = string.format
local gmatch   = string.gmatch
local tonumber = tonumber
local volume   = {}

local sinkpattern   = [[Sink\s*#(\d+)]]
local mutepattern   = [[Mute:\s*(yes|no)]]
local volumepattern = [[Volume:\s*front-left:\s*\d+\s*/\s*(\d+)%]]

volume.sinkno = 1

local function slurpcommand(cmd)
  local pipe, error = popen(cmd, 'r')
  if not pipe then
    return pipe, error
  end
  local contents = pipe:read '*a'
  pipe:close()
  return contents
end

local function getstate()
  local sinks = slurpcommand('pactl list sinks')

  local sinkno = volume.sinkno
  local parsing_sink
  local state
  local volume

  for line in gmatch(sinks, '[^\n]+') do
    local currentsink = rmatch(line, sinkpattern)

    if currentsink then
      parsing_sink = tonumber(currentsink) == sinkno
    elseif parsing_sink then
      local line_state  = rmatch(line, mutepattern)
      local line_volume = rmatch(line, volumepattern)

      if line_state then
        state = line_state
      end
      if line_volume then
        volume = line_volume
      end
    end
  end

  return sinkno, volume, state ~= 'no'
end

function volume.get()
  local _, volume = getstate()
  return volume
end

function volume.ismute()
  local _, _, mute = getstate()
  return mute
end

function volume.toggle()
  local sinkno, _, mute = getstate()

  execute(format('pactl set-sink-mute %d %d', sinkno, (mute and 0 or 1)))
  return not mute
end

function volume.increment()
  local sinkno, volume = getstate()
  volume = volume + 5
  if volume > 100 then
    volume = 100
  end
  execute(format('pactl set-sink-volume %d %d%%', sinkno, volume))
  return volume
end

function volume.decrement()
  local sinkno, volume = getstate()
  volume = volume - 5
  if volume < 0 then
    volume = 0
  end
  execute(format('pactl set-sink-volume %d %d%%', sinkno, volume))
  return volume
end

return volume
