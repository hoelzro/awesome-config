local open    = io.open
local sformat = string.format
local slower  = string.lower

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

    states[i] = {
      status      = assert(read_first_line(sformat('%s/status', battery_path))),
      power_now   = tonumber(assert(read_first_line(sformat('%s/power_now', battery_path)))),
      energy_now  = tonumber(assert(read_first_line(sformat('%s/energy_now', battery_path)))),
      energy_full = tonumber(assert(read_first_line(sformat('%s/energy_full', battery_path)))),
    }
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

-- {{{ ACPI Backend (sysfs + acpi_listen events)
local object = require 'gears.object'
local spawn = require 'awful.spawn'

local acpi_backend = setmetatable({}, {__index = sysfs_backend})
backends.acpi = acpi_backend

local log = print

function acpi_backend:new() -- {{{
  local events = object()

  local spawn_err = spawn.with_line_callback('acpi_listen', {
    stdout = function(line)
      if string.sub(line, 1, #'battery') == 'battery' then
        events:emit_signal 'battery'
      end
    end,

    exit = function(reason, exit_code)
      log(sformat('acpi_listen exited due to %s (exit code = %d)', reason, exit_code))
    end,
  })

  if type(spawn_err) == 'string' then
    log('failed to spawn acpi_listen: ' .. spawn_err)
  end

  return setmetatable({
    root = '/sys/class/power_supply/',
    events = events,
  }, {__index = acpi_backend})
end -- }}}

function acpi_backend:weak_connect_signal(signal, callback) -- {{{
  return self.events:weak_connect_signal(signal, callback)
end -- }}}
-- }}}

-- {{{ Mock Backend (for testing)
local timer = require 'gears.timer'

local mock_backend = {}
backends.mock = mock_backend

-- Default rate: full discharge in 10 minutes = 1/600 per second
local DEFAULT_RATE = 1 / 600

function mock_backend:new(options) -- {{{
  options = options or {}

  local events = object()

  -- energy_full is 100 "units" for simplicity; charge is in [0, 1]
  local energy_full = 100
  local charge = options.initial_charge or 1.0
  local status = options.initial_status or 'Discharging'
  local rate = options.rate or DEFAULT_RATE

  local instance = setmetatable({
    events = events,
    _energy_full = energy_full,
  }, {__index = mock_backend})

  -- Expose mutable state via closures
  function instance:state()
    return {
      {
        status = status,
        power_now = rate * energy_full,
        energy_now = charge * energy_full,
        energy_full = energy_full,
      }
    }
  end

  function instance:plug_in()
    status = 'Charging'
    events:emit_signal 'battery'
  end

  function instance:unplug()
    status = 'Discharging'
    events:emit_signal 'battery'
  end

  function instance:set_rate(new_rate)
    rate = new_rate
  end

  function instance:set_charge(new_charge)
    charge = math.max(0, math.min(1, new_charge))
  end

  function instance:get_charge()
    return charge
  end

  -- Timer to update charge level once per second
  local update_timer = timer.start_new(1, function()
    if slower(status) == 'charging' then
      charge = math.min(1, charge + rate)
      if charge >= 1 then
        status = 'Full'
      end
    elseif slower(status) == 'discharging' then
      charge = math.max(0, charge - rate)
    end
    -- Emit signal so the widget updates
    events:emit_signal 'battery'
    return true
  end)

  -- Store timer reference to prevent GC
  instance._update_timer = update_timer

  return instance
end -- }}}

function mock_backend:detect() -- {{{
  return true
end -- }}}

function mock_backend:weak_connect_signal(signal, callback) -- {{{
  return self.events:weak_connect_signal(signal, callback)
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
    assert(type(battery.power_now) == 'number', type(battery.charge))
    assert(type(battery.energy_now) == 'number', type(battery.charge))
    assert(type(battery.energy_full) == 'number', type(battery.charge))
    assert(BATTERY_STATES[slower(battery.status)], battery.status)

    for k in pairs(battery) do
      assert(k == 'power_now' or k == 'energy_now' or k == 'energy_full' or k == 'status', k)
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
backends[#backends + 1] = acpi_backend

return backends
