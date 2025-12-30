local open = io.open
local sformat = string.format
local unpack = unpack or table.unpack

local gio = require('lgi').Gio

local HWMON_PREFIX = '/sys/class/hwmon'

local backends = {}

-- XXX copy pasta
local function read_first_line(filename) -- {{{
  local f, err = open(filename, 'r')
  if not f then
    return nil, err
  end

  local line, err = f:read '*l'
  f:close()
  if not line then
    return nil, err
  end

  return line
end -- }}}

local function listdir(dirname)
  local dir = gio.File.new_for_path(dirname)
  local files = {}

  local fe = dir:enumerate_children('standard::name', gio.FileQueryInfoFlags.NONE)
  while true do
    local fi = fe:next_file()
    if not fi then
      break
    end
    files[#files + 1] = fi:get_name()
  end
  fe:close()

  return files
end

local function load_hwmon_data(hwmon_path)
  local temperatures = {}

  local temp_num = 1
  while true do
    local label = read_first_line(sformat('%s/temp%d_label', hwmon_path, temp_num))
    if not label then
      break
    end

    local value_path = sformat('%s/temp%d_input', hwmon_path, temp_num)

    temperatures[label] = value_path
    temp_num = temp_num + 1
  end

  return temperatures
end

local function load_sysfs_hwmon_data()
  local result = {}

  local hwmon_subdirs = listdir(HWMON_PREFIX)
  for i = 1, #hwmon_subdirs do
    local subdir = hwmon_subdirs[i]
    if not string.match(subdir, '^hwmon%d+$') then
      goto continue
    end

    local hwmon_path = HWMON_PREFIX .. '/' .. subdir
    local hwmon_name = read_first_line(hwmon_path .. '/name')
    if not hwmon_name then
      goto continue
    end

    result[hwmon_name] = load_hwmon_data(hwmon_path)

    ::continue::
  end

  return result
end

-- {{{ Filesystem Backend
local fs_backend = {}
backends.filesystem = fs_backend

function fs_backend:new(options) -- {{{
  assert(options.target)

  return setmetatable({
    target = options.target,
  }, {__index = fs_backend})
end -- }}}

function fs_backend:state() -- {{{
   -- XXX use read_first_line?
   local f, err = io.open(self.target, 'r')
   if not f then
     return nil, err
   end

   local line, err = f:read '*l'
   f:close()

   if not line then
     return nil, err
   end

   local temp, err = tonumber(line)
   if not temp then
     return nil, 'unable to convert temperature to number'
   end

   return temp / 1000
end -- }}}

--}}}

-- {{{ Sysfs backend
local sysfs_backend = setmetatable({}, {__index = fs_backend})
backends.sysfs = sysfs_backend

local hwmon_preference = {
  {'thinkpad', 'CPU'},
  {'k10temp', 'Tctl'},
}

function sysfs_backend:new() -- {{{
  return setmetatable(fs_backend:new {
    target = '',
  }, {__index = sysfs_backend})
end -- }}}

function sysfs_backend:detect() -- {{{
  assert(self.target == '')

  local hwmon_data = load_sysfs_hwmon_data()

  for i = 1, #hwmon_preference do
    local node, label = unpack(hwmon_preference[i])
    if hwmon_data[node] and hwmon_data[node][label] then
      self.target = hwmon_data[node][label]
      return true
    end
  end

  return false
end -- }}}

-- }}}

return backends
