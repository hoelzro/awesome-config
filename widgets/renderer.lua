local sformat = string.format
local tconcat = table.concat

local escape
local has_awful_util, awful_util = pcall(require, 'awful.util')
if has_awful_util then
  escape = awful_util.escape
else
  escape = function(s) return s end
end

local renderer_methods = {}

function renderer_methods:push_fg_color(color)
  assert(not self.closed, "pop_blink must be the last call to a renderer")

  self.chunks[#self.chunks + 1] = sformat('<span foreground="%s">', color)
end

function renderer_methods:pop_fg_color()
  assert(not self.closed, "pop_blink must be the last call to a renderer")

  self.chunks[#self.chunks + 1] = '</span>'
end

function renderer_methods:push_blink()
  assert(#self.chunks == 0, "push_blink must be the first call to a renderer")
  self.is_blinking = true
end

function renderer_methods:pop_blink()
  self.closed = true
end

function renderer_methods:print(...)
  assert(not self.closed, "pop_blink must be the last call to a renderer")

  local narg = select('#', ...)
  for i = 1, narg do
    self.chunks[#self.chunks + 1] = escape(tostring(select(i, ...)))
  end
end

function renderer_methods:printf(format, ...)
  self:print(sformat(format, ...))
end

function renderer_methods:markup()
  return tconcat(self.chunks)
end

local function make_renderer()
  return setmetatable({
    chunks = {},
  }, {__index = renderer_methods})
end

return make_renderer
