local join   = awful.util.table.join
local concat = table.concat

local _M = {}

local function startkeygrabber(chords)
  return function()
    local current = chords

    keygrabber.run(function(_, key, evtype)
      -- we only care about key presses
      if evtype ~= 'press' then
        return true
      end

      current = current[key]

      -- invalid binding; stop the grabbing
      if not current then
        return false
      end

      if type(current) == 'function' then
        keygrabber.stop() -- we stop early in case others want to grab the keyboard
        current()
        return true -- make sure we don't clean up the keygrabber others may
                    -- have installed
      end

      return true
    end)
  end
end

function _M.chord(chords)
  local keys = {}

  for k, v in pairs(chords) do
    if type(k) == 'table' then
      local key = k[#k]
      k[#k]     = nil
      keys = join(keys,
        awful.key(k, key, startkeygrabber(v)))
    end
  end

  return keys
end

--[[

Example:

keychords.chord {
    { modkey, 'w' } = {
        h = function() ... end,
        j = function() ... end,
        k = function() ... end,
        l = function() ... end,
    },
}

]]

return _M
