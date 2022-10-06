local success, json = pcall(require, 'cjson')
if not success then
  json = require 'json'
end

local window_buffer      = {}
local window_buffer_max  = 100

local function flush_window_buffer()
  for _, v in pairs(window_buffer) do
    print(json.encode(v))
  end

  window_buffer = {}
end

local function record(c)
  local t = {
    message  = 'rule evaluation',
    when     = os.date '%Y-%m-%dT%H:%M:%S',
    name     = c.name,
    type     = c.type,
    class    = c.class,
    instance = c.instance,
    role     = c.role,
  }
  window_buffer[#window_buffer+1] = t
  while #window_buffer > window_buffer_max do
    table.remove(window_buffer, 1)
  end
end

return {
  flush_window_buffer = flush_window_buffer,
  record              = record,
}
