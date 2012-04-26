local rmatch  = require('rex_pcre').match
local popen   = io.popen
local execute = os.execute
local format  = string.format
local volume  = {}

local sinkpattern   = 'Sink\\s*#(\\d+)'
local mutepattern   = 'Mute:\\s*(yes|no)'
local volumepattern = 'Volume:\\s*0:\\s*(\\d+)%'

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
  local sinks  = slurpcommand('pactl list sinks')
  local sinkno = rmatch(sinks, sinkpattern)
  local state  = rmatch(sinks, mutepattern)
  local volume = rmatch(sinks, volumepattern)

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
