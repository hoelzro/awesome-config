local success, json = pcall(require, "cjson")
if not success then
  json = require("json")
end

local window_buffer = {}
local window_buffer_size = 0
local window_buffer_max = 100

local flush_window_buffer = function()
        for i, v in pairs(window_buffer) do
                print(json.encode(v))
        end
        window_buffer = {}
        window_buffer_size = 0
end

local function record(c)
  local t = {
     ["message"] = "rule evaluation",
     ["when"] = os.date("%Y-%m-%dT%H:%M:%S"),
     ["name"] = c.name,
     ["type"] = c.type,
     ["class"] = c.class,
     ["instance"] = c.instance,
     ["role"] = c.role,
  }
  table.insert(window_buffer, t)
  window_buffer_size = window_buffer_size + 1
  if window_buffer_size > window_buffer_max then
        for i = 1, window_buffer_size - window_buffer_max, 1 do
                table.remove(window_buffer, 1)
        end
  end
end

return {
  flush_window_buffer = flush_window_buffer,
  record              = record,
}
