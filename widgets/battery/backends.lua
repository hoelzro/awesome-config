local open    = io.open
local sformat = string.format
local slower  = string.lower

local object = require 'gears.object'
local spawn = require 'awful.spawn'
local timer = require 'gears.timer'

local backends = {}
local log = print

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

function fs_backend:weak_connect_signal()
end
-- }}}

local function start_acpi_listen(emitter)
  local spawn_err = spawn.with_line_callback('acpi_listen', {
    stdout = function(line)
      if string.sub(line, 1, #'battery') == 'battery' then
        emitter:emit_signal 'battery'
      end
    end,

    exit = function(reason, exit_code)
      log(string.format('acpi_listen exited due to %s (exit code = %d)', reason, exit_code))
    end,
  })

  if type(spawn_err) == 'string' then
    log('failed to spawn acpi_listen: ' .. spawn_err)
  end
end

-- {{{ Power Supply Backend
local power_supply_backend = setmetatable({}, {__index = fs_backend})
backends.power_supply = power_supply_backend

function power_supply_backend:new() -- {{{
  local backend = setmetatable(fs_backend:new {
    root = '/sys/class/power_supply/',
  }, {__index = power_supply_backend})

  backend.event_emitter = object()
  start_acpi_listen(backend.event_emitter)

  return backend
end -- }}}

function power_supply_backend:weak_connect_signal(signal, callback)
  return self.event_emitter:weak_connect_signal(signal, callback)
end
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

function raw_data_backend:weak_connect_signal()
end
-- }}}

-- {{{ Mock Backend
local mock_backend = {}
backends.mock = mock_backend

function mock_backend:new(options) -- {{{
  options = options or {}

  local backend = setmetatable({}, {__index = mock_backend})
  backend.event_emitter = object()
  backend.energy_full = options.energy_full or 1
  backend.energy_now = options.energy_now or backend.energy_full
  backend.status = options.status or 'discharging'
  backend.rate = options.rate or (1 / 600)
  backend.not_charging_duration = options.not_charging_duration or 2
  backend.not_charging_ticks = 0
  backend.pending_status = nil

  backend.timer = timer.weak_start_new(1, function()
    return backend:_tick()
  end)

  return backend
end -- }}}

function mock_backend:_tick()
  if self.status == 'not charging' and self.not_charging_ticks > 0 then
    self.not_charging_ticks = self.not_charging_ticks - 1
    if self.not_charging_ticks == 0 and self.pending_status then
      self.status = self.pending_status
      self.pending_status = nil
    end
  end

  if self.status == 'charging' then
    self.energy_now = math.min(self.energy_full, self.energy_now + self.rate * self.energy_full)
  elseif self.status == 'discharging' then
    self.energy_now = math.max(0, self.energy_now - self.rate * self.energy_full)
  end

  self.event_emitter:emit_signal('battery')
  return true
end

function mock_backend:detect()
  return true
end

function mock_backend:state()
  local power_now = 0
  if self.status == 'charging' or self.status == 'discharging' then
    power_now = self.rate * self.energy_full * 3600
  end

  return {
    {
      status = self.status,
      power_now = power_now,
      energy_now = self.energy_now,
      energy_full = self.energy_full,
    }
  }
end

function mock_backend:plug_in()
  self.status = 'not charging'
  self.not_charging_ticks = self.not_charging_duration
  self.pending_status = 'charging'
  self.event_emitter:emit_signal('battery')
end

function mock_backend:unplug()
  self.status = 'discharging'
  self.not_charging_ticks = 0
  self.pending_status = nil
  self.event_emitter:emit_signal('battery')
end

function mock_backend:set_rate(rate)
  self.rate = rate
  self.event_emitter:emit_signal('battery')
end

function mock_backend:weak_connect_signal(signal, callback)
  return self.event_emitter:weak_connect_signal(signal, callback)
end
-- }}}

-- XXX apcupsd backend?

-- all members at integer indexes are "auto-discoverable"
backends[#backends + 1] = power_supply_backend

return backends
