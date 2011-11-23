--[[
- Expose?
- List keybindings?
]]

modkey           = "Mod1"
terminal         = "xterm"
editor           = os.getenv("EDITOR") or "vim"
editor_cmd       = terminal .. " -e " .. editor
preferred_screen = screen.count()

do
  local maxindex

  for i = 1, screen.count() do
    local s = screen[i]
    if not maxindex or s.geometry.x > screen[maxindex].geometry.x then
      maxindex = i
    end
  end

  preferred_screen = maxindex
end

require 'local-loader'

require 'awful.autofocus'
require 'naughty'

require 'naughty-screen'
require 'startup-programs'
require 'theme'
require 'tags'
require 'widgets'
require 'mousebindings'
require 'keybindings'
require 'clientrules'

-- don't consider scripts in my private
-- files for tab completion
local posix = require 'posix'
local home  = os.getenv 'HOME'
local path  = os.getenv 'PATH'
local paths = {}

local is_blacklisted = {
  [ home .. '/bin' ]                 = true,
  [ home .. '/useful-perl/scripts' ] = true,
}

for p in string.gmatch(path, '[^:]+') do
  if not is_blacklisted[p] then
    paths[#paths + 1] = p
  end
end

posix.setenv('PATH', table.concat(paths, ':'))

-- shortcut for naughty.notify
function alert(msg)
  naughty.notify {
    title = 'Alert!',
    text  = tostring(msg),
  }
end
