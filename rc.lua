--[[
- Expose?
- List keybindings?
]]

local function splitpath(path)
  local patterns = {}
  for m in string.gmatch(path, '[^;]+') do
    patterns[#patterns + 1] = m
  end
  return patterns
end

local function filter(t, predicate)
  local filtered = {}

  for _, value in ipairs(t) do
    if predicate(value) then
      filtered[#filtered + 1] = value
    end
  end

  return filtered
end

local function remove_local_path(path)
  return not string.match(path, '^%./')
end

package.path  = table.concat(filter(splitpath(package.path), remove_local_path), ';') .. ';/home/rob/.config/awesome/lua-modules/share/lua/5.1/?.lua'
package.cpath = table.concat(filter(splitpath(package.cpath), remove_local_path), ';')
package.cpath = package.cpath .. ';/home/rob/.config/awesome/?.so;/home/rob/.config/awesome/lua-modules/lib/lua/5.1/?.so'

modkey           = "Mod1"
terminal         = "urxvtc"
editor           = os.getenv("EDITOR") or "vim"
editor_cmd       = terminal .. " -e " .. editor
volume_delta     = 5

do
  local function find_maxindex(dim)
    for i = 1, screen.count() do
      local s = screen[i]
      if not maxindex or s.geometry[dim] > screen[maxindex].geometry[dim] then
        maxindex = i
      end
      if not minindex or s.geometry[dim] < screen[minindex].geometry[dim] then
        minindex = i
      end
    end

    return maxindex, minindex
  end

  local maxindex, minindex = find_maxindex 'x'

  if maxindex == minindex then
    minindex, maxindex = find_maxindex 'y'
  end


  preferred_screen = maxindex
  left_screen      = minindex
  right_screen     = maxindex
end

require 'dmux'
require 'local-loader'

require 'awful.autofocus'
local naughty = require 'naughty'

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
local _, posix = pcall(require, 'posix')
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

if type(posix) == 'table' then
  posix.setenv('PATH', table.concat(paths, ':'))
end

-- shortcut for naughty.notify
function alert(msg)
  naughty.notify {
    title = 'Alert!',
    text  = tostring(msg),
  }
end

function dir(object, pattern)
  object     = object or _G
  local keys = {}

  for k in pairs(object) do
    if type(k) == 'string' then
      if not pattern or k:match(pattern) then
        keys[#keys + 1] = k
      end
    end
  end

  table.sort(keys)

  alert(table.concat(keys, '\n'))
end
