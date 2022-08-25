local floor   = math.floor
local open    = io.open
local sformat = string.format

local backends = {}

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

-- {{{ Filesystem Backend
local fs_backend = {}
backends.filesystem = fs_backend

function fs_backend:new(options) -- {{{
  assert(options.root)

  return setmetatable({
    root = options.root,
  }, {__index = fs_backend})
end -- }}}

function fs_backend:detect() -- {{{
  local batteries = {}

  -- assume there are 100 or fewer batteries - that's *probably* fine 😅
  for i = 0, 100 do
    local f = open(self.root .. '/BAT' .. tostring(i) .. '/type')
    if f then
      local battery_type = f:read '*l'
      if string.lower(battery_type) == 'battery' then
        batteries[#batteries + 1] = self.root .. '/BAT' .. tostring(i)
      end
      f:close()
    end
  end

  self.batteries = batteries

  return #batteries > 0
end -- }}}

function fs_backend:state() -- {{{
  local states = {}

  for i = 1, #self.batteries do
    local battery_path = self.batteries[i]

    local battery_status = assert(read_first_line(sformat('%s/status', battery_path))):lower()
    local battery_charge = tonumber(assert(read_first_line(sformat('%s/capacity', battery_path))))

    local capacity_microwh = tonumber(assert(read_first_line(sformat('%s/energy_now', battery_path))))
    local rate_microw = tonumber(assert(read_first_line(sformat('%s/power_now', battery_path))))

    states[i] = {
      charge = battery_charge,
      status = battery_status,
    }

    if rate_microw ~= 0 then
      local battery_time_hours = capacity_microwh / rate_microw
      states[i].time = floor(battery_time_hours * 60)
    end
  end

  return states
end -- }}}
-- }}}

-- {{{ Sysfs Backend
local sysfs_backend = setmetatable({}, {__index = fs_backend})
backends.sysfs = sysfs_backend

function sysfs_backend:new() -- {{{
  return setmetatable(fs_backend:new {
    root = '/sys/class/power_supply/',
  }, {__index = sysfs_backend})
end -- }}}
-- }}}

-- {{{ Raw Data Backend
local raw_data_backend = {}
backends.raw_data = raw_data_backend

local BATTERY_STATES = {
  charging         = true,
  discharging      = true,
  full             = true,
  ['not charging'] = true,
}

function raw_data_backend:new(options) -- {{{
  assert(options.batteries)
  for i = 1, #options.batteries do
    local battery = options.batteries[i]
    assert(type(battery.charge) == 'number', type(battery.charge))
    assert(BATTERY_STATES[battery.status], battery.status)
    if battery.time then
      assert(type(battery.time) == 'number', type(battery.time))
    end

    for k in pairs(battery) do
      assert(k == 'charge' or k == 'status' or k == 'time', k)
    end
  end

  return setmetatable({
    batteries = options.batteries,
  }, {__index = raw_data_backend})
end -- }}}

function raw_data_backend:detect() -- {{{
  return true
end -- }}}

function raw_data_backend:state() -- {{{
  return self.batteries
end -- }}}
-- }}}

-- XXX apcupsd backend?

-- all members at integer indexes are "auto-discoverable"
backends[#backends + 1] = sysfs_backend

return backends
