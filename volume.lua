local popen    = io.popen
local execute  = os.execute
local tonumber = tonumber
local volume   = {}

local function slurpcommand(cmd)
  local pipe, error = popen(cmd, 'r')
  if not pipe then
    return pipe, error
  end
  local contents = pipe:read '*a'
  pipe:close()
  return contents
end

function volume.get()
  local volume = slurpcommand 'ponymix get-volume'
  return tonumber(volume)
end

function volume.ismute()
  return execute('ponymix is-muted') == 0
end

function volume.toggle()
  execute 'ponymix toggle &>/dev/null'

  return volume.ismute()
end

function volume.increment()
  local volume = slurpcommand 'ponymix increase 5'
  return tonumber(volume)
end

function volume.decrement()
  local volume = slurpcommand 'ponymix decrease 5'
  return tonumber(volume)
end

return volume
