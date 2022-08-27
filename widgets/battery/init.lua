local spawn = require 'awful.spawn'
local wibox = require 'wibox'
local timer = require 'gears.timer'

local backends = require 'widgets.battery.backends'
local render = require 'widgets.battery.render'
local make_renderer = require 'widgets.renderer'

local backend = backends.sysfs:new()
local has_battery = backend:detect()

local log = print

local function make_widget()
  if not has_battery then
    return
  end

  local w = wibox.widget {
    text = 'Battery Info',
    widget = wibox.widget.textbox,
  }

  timer {
    timeout   = 60,
    autostart = true,
    call_now  = true,

    callback = function()
      local state = backend:state()
      local r = make_renderer()
      render(r, state)
      w:set_markup(r:markup())
    end,
  }

  local spawn_err = spawn.with_line_callback('acpi_listen', {
    stdout = function(line)
      if string.sub(line, 1, #'battery') == 'battery' then
        local state = backend:state()
        local r = make_renderer()
        render(r, state)
        w:set_markup(r:markup())
      end
    end,

    exit = function(reason, exit_code)
      log(string.format('acpi_listen exited due to %s (exit code = %d)', reason, exit_code))
    end,
  })

  if type(spawn_err) == 'string' then
    log('failed to spawn acpi_listen: ' .. spawn_err)
  end

  return w
end

return make_widget
