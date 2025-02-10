local format   = string.format
local tjoin    = table.concat
local tsort    = table.sort
local tostring = tostring
local type     = type
local floor    = math.floor
local pairs    = pairs
local ipairs   = ipairs
local error    = error

pcall(require, 'luarocks.require')
local ok, term = pcall(require, 'term')
if not ok then
  term = nil
end

local pretty = {}

local keywords = {
  ['and']      = true,
  ['break']    = true,
  ['do']       = true,
  ['else']     = true,
  ['elseif']   = true,
  ['end']      = true,
  ['false']    = true,
  ['for']      = true,
  ['function'] = true,
  ['if']       = true,
  ['in']       = true,
  ['local']    = true,
  ['nil']      = true,
  ['not']      = true,
  ['or']       = true,
  ['repeat']   = true,
  ['return']   = true,
  ['then']     = true,
  ['true']     = true,
  ['until']    = true,
  ['while']    = true,
}

local function isinteger(n)
  return type(n) == 'number' and floor(n) == n
end

local function isident(s)
  return type(s) == 'string' and not keywords[s] and s:match('^[a-zA-Z_][a-zA-Z0-9_]*$')
end

local function sortedpairs(t)
  local keys = {}

  for k in pairs(t) do
    keys[#keys + 1] = k
  end
  tsort(keys, function(a, b)
    local type_a = type(a)
    local type_b = type(b)

    if type_a == type_b then
      return a < b
    else
      return type_a < type_b
    end
  end)

  local index = 1
  return function()
    if keys[index] == nil then
      return nil
    else
      local key   = keys[index]
      local value = t[key]
      index       = index + 1

      return key, value
    end
  end, keys
end

local function compose(f, g)
  return function(...)
    return f(g(...))
  end
end

local function find_longstring_nest_level(s)
  local level = 0

  while s:find(']' .. string.rep('=', level) .. ']', 1, true) do
    level = level + 1
  end

  return level
end

local emptycolormap = setmetatable({}, { __index = function()
  return function(s)
    return s
  end
end})

local colormap = emptycolormap

if term then
  colormap = {
    ['nil']     = term.colors.blue,
    string      = term.colors.yellow,
    punctuation = compose(term.colors.green, term.colors.bright),
    ident       = term.colors.red,
    boolean     = term.colors.green,
    number      = term.colors.cyan,
    path        = term.colors.white,
  }
end

local function _dump(config, seen, path, v, stream, indent)
  local t = type(v)

  local colormap = config.color and colormap or emptycolormap

  if t == 'nil' or t == 'boolean' or t == 'number' then
    stream:write(colormap[t](tostring(v)))
  elseif t == 'string' then
    if v:match '\n' then
      local level = find_longstring_nest_level(v)
      stream:write(colormap.string('[' .. string.rep('=', level) .. '[' .. v .. ']' .. string.rep('=', level) .. ']'))
    else
      stream:write(colormap.string(format('%q', v)))
    end
  elseif t == 'table' then
    if seen[v] then
      stream:write(colormap.path(seen[v]))
      return
    end

    seen[v] = path

    local lastintkey = 0

    stream:write(colormap.punctuation '{\n')
    for i, v in ipairs(v) do
      for j = 1, indent do
        stream:write '  '
      end
      _dump(config, seen, path .. '[' .. tostring(i) .. ']', v, stream, indent + 1)
      stream:write(colormap.punctuation ',\n')
      lastintkey = i
    end

    local iterator = config.sorted and sortedpairs or pairs

    for k, v in iterator(v) do
      if not (isinteger(k) and k <= lastintkey and k > 0) then
        for j = 1, indent do
          stream:write '  '
        end

        if isident(k) then
          stream:write(colormap.ident(k))
        else
          stream:write(colormap.punctuation '[')
          _dump(config, seen, path .. '.' .. tostring(k), k, stream, indent + 1)
          stream:write(colormap.punctuation ']')
        end
        stream:write(colormap.punctuation ' = ')
        _dump(config, seen, path .. '.' .. tostring(k), v, stream, indent + 1)
        stream:write(colormap.punctuation ',\n')
      end
    end

    for j = 1, indent - 1 do
      stream:write '  '
    end

    stream:write(colormap.punctuation '}')
  else
    error(format('Cannot print type \'%s\'', t))
  end
end

-- XXX coloured, colored, sorted
local function normalize_config(config)
  config = config or {}

  if config.colour ~= nil then
    config.color  = config.colour
    config.colour = nil
  end

  return config
end

local table_stream_mt = {}
table_stream_mt.__index = table_stream_mt

function table_stream_mt:__tostring()
  return tjoin(self, '')
end

function table_stream_mt:write(value)
  self[#self + 1] = value
end

function pretty.dump(value, config)
  local stream = setmetatable({}, table_stream_mt)
  _dump(normalize_config(config), {}, '<topvalue>', value, stream, 1)
  return tostring(stream)
end

function pretty.print(value, config)
  config        = normalize_config(config)
  local handle  = config.handle or io.stderr
  config.handle = nil

  if config.color == nil and term and term.isatty(handle) then
    config.color = true
  end

  _dump(config, {}, '<topvalue>', value, handle, 1)
  handle:write '\n'
end

-- XXX indentation string (tab, spaces, # spaces, etc)
-- XXX when/whether to use newlines
-- XXX maximum depth into structure
-- XXX show metatables, function environments, etc

return pretty
