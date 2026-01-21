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

package.path  = table.concat(filter(splitpath(package.path), remove_local_path), ';') .. ';/home/rob/.config/awesome/lua53-modules/share/lua/5.3/?.lua'
package.cpath = table.concat(filter(splitpath(package.cpath), remove_local_path), ';')
package.cpath = package.cpath .. ';/home/rob/.config/awesome/?.so;/home/rob/.config/awesome/lua53-modules/lib/lua/5.3/?.so'

modkey           = "Mod1"
terminal         = "urxvt"
editor           = os.getenv("EDITOR") or "vim"
editor_cmd       = terminal .. " -e " .. editor
volume_delta     = 5

local naughty = require 'naughty'
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

if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = tostring(err) })
        in_error = false
    end)
end
-- }}}

require 'local-loader'

require 'awful.autofocus'

require 'naughty-screen'
require 'startup-programs'
require 'theme'
require 'tags'
require 'widgets'
require 'mousebindings'
require 'keybindings'
require 'clientrules'

local spawn = require 'awful.spawn'
local insert_unicode_char = require('unicode-input').insert_unicode_character

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

start_time = os.time()
screen_count = 0

local awful = require 'awful'
awful.screen.connect_for_each_screen(function(s)
  screen_count = screen_count + 1
end)

screen.connect_signal('removed', function()
  collectgarbage 'collect'
end)

function emoji()
  spawn.easy_async_with_shell('< /home/rob/.config/awesome/emoji.tsv rofi -dmenu', function(stdout)
    local selected_emoji = string.match(stdout, '^[^\t]+\t([^\n]+)')
    if not selected_emoji then
      return
    end
    insert_unicode_char(selected_emoji)
  end)
end
