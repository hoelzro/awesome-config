local format   = string.format
local tjoin    = table.concat
local tostring = tostring
local type     = type
local floor    = math.floor
local pairs    = pairs
local ipairs   = ipairs
local error    = error

module 'pretty'

local keywords = {
  ['and'] = true,
  ['break'] = true,
  ['do'] = true,
  ['else'] = true,
  ['elseif'] = true,
  ['end'] = true,
  ['false'] = true,
  ['for'] = true,
  ['function'] = true,
  ['if'] = true,
  ['in'] = true,
  ['local'] = true,
  ['nil'] = true,
  ['not'] = true,
  ['or'] = true,
  ['repeat'] = true,
  ['return'] = true,
  ['then'] = true,
  ['true'] = true,
  ['until'] = true,
  ['while'] = true,
}

local function isinteger(n)
  return type(n) == 'number' and floor(n) == n
end

local function isident(s)
  return type(s) == 'string' and not keywords[s] and s:match('^[a-zA-Z_][a-zA-Z0-9_]*$')
end

local function helper(v, chunks, indent)
  local t = type(v)

  if t == 'nil' or t == 'boolean' or t == 'number' then
    chunks[#chunks + 1] = tostring(v)
  elseif t == 'string' then
    chunks[#chunks + 1] = format('%q', v)
  elseif t == 'table' then
    local lastintkey = 0

    chunks[#chunks + 1] = '{\n'
    for i, v in ipairs(v) do
      for j = 1, indent do
        chunks[#chunks + 1] = '  '
      end
      helper(v, chunks, indent + 1)
      chunks[#chunks + 1] = ',\n'
      lastintkey = i
    end

    for k, v in pairs(v) do
      if not (isinteger(k) and k <= lastintkey and k > 0) then
        for j = 1, indent do
          chunks[#chunks + 1] = '  '
        end

        if isident(k) then
          chunks[#chunks + 1] = k
        else
          chunks[#chunks + 1] = '['
          helper(k, chunks, indent + 1)
          chunks[#chunks + 1] = ']'
        end
        chunks[#chunks + 1] = ' = '
        helper(k, chunks, indent + 1)
        chunks[#chunks + 1] = ',\n'
      end
    end

    for j = 1, indent - 1 do
      chunks[#chunks + 1] = '  '
    end

    chunks[#chunks + 1] = '}'
  else
    error(format('Cannot print type \'%s\'', t))
  end
end

-- Data::Dumper-like options
-- persist multi-line strings with [[ ]]?
function print(v, chunks, indent)
  local chunks = {}

  helper(v, chunks, 1)
  return tjoin(chunks, '')
end
