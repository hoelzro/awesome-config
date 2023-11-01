local spawn      = require 'awful.spawn'
local fs         = require 'gears.filesystem'
local naughty    = require 'naughty'
local lgi        = require 'lgi'
local Gio        = lgi.require 'Gio'

local function ls(dir)
  local enum = Gio.File.new_for_path('/home/rob/.config/awesome/'):enumerate_children('', 0, nil, nil)

  return function()
    local f = enum:next_file()

    if f then
      return f:get_name()
    end
  end
end

local function easy_async(command)
  local this_coro = coroutine.running()

  spawn.easy_async(command, function(stdout, stderr, reason, status)
    coroutine.resume(this_coro, stdout, stderr, reason, status)
  end)

  return coroutine.yield()
end

-- XXX handling errors in here is no good
local function safe_restart()
  local config_dir = fs.get_configuration_dir()

  local lua_config_files = {}

  for filename in ls(config_dir) do
    if string.sub(filename, -4) == '.lua' then
      lua_config_files[#lua_config_files + 1] = filename
    end
  end

  local broken_files = {}

  for i = 1, #lua_config_files do
    local _, stderr, _, status = easy_async { 'luac', '-p', config_dir .. '/' .. lua_config_files[i] }
    if status ~= 0 then
      broken_files[#broken_files + 1] = {lua_config_files[i], stderr}
    end
  end

  for i = 1, #broken_files do
    local broken_filename = broken_files[i][1]
    local error_msg       = string.gsub(string.gsub(broken_files[i][2], '^%s*luac:%s*[^:]*:', ''), '%s+$', '')

    naughty.notify {
      title  = 'Refusing to restart - config parse errors',
      text   = broken_filename .. ' line ' .. error_msg,
      preset = naughty.config.presets.critical,
    }
  end

  -- fix up borked tag assignments
  do
    local tags = root.tags()
    local clients = client.get()

    for i = 1, #clients do
      local c = clients[i]
      local ewmh_desktop = tonumber(c:get_xproperty '_NET_WM_DESKTOP')
      if ewmh_desktop >= #tags then
        c:set_xproperty('_NET_WM_DESKTOP', ewmh_desktop % #tags)
      end
    end
  end

  if #broken_files == 0 then
    awesome.restart()
  end
end

return function()
  coroutine.resume(coroutine.create(safe_restart))
end
