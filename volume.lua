local rmatch  = require('rex_pcre').match
local popen   = io.popen
local execute = os.execute
local volume  = {}
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
  local state  = rmatch(sinks, mutepattern)
  local volume = rmatch(sinks, volumepattern)

  return volume, state ~= 'no'
end

function volume.get()
  local volume = getstate()
  return volume
end

function volume.ismute()
  local _, mute = getstate()
  return mute
end

function volume.toggle()
  local mute = volume.ismute()

  execute('pactl set-sink-mute 0 ' .. (mute and '0' or '1'))
  return not mute
end

function volume.increment()
  local volume = volume.get()
  volume = volume + 5
  if volume > 100 then
    volume = 100
  end
  execute('pactl set-sink-volume 0 ' .. tostring(volume) .. '%')
  return volume
end

function volume.decrement()
  local volume = volume.get()
  volume = volume - 5
  if volume < 0 then
    volume = 0
  end
  execute('pactl set-sink-volume 0 ' .. tostring(volume) .. '%')
  return volume
end

return volume
