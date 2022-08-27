local sformat = string.format

local awful = require 'awful'
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

  local reverse_color
  local prev_render
  local blink_timer = timer {
    timeout = 1,
    callback = function()
      local markup = prev_render:markup()
      if reverse_color then
        w:set_markup(sformat('<span background="red">%s</span>', markup))
      else
        w:set_markup(markup)
      end

      reverse_color = not reverse_color
    end,
  }

  local function refresh()
    local state = backend:state()
    local r = make_renderer()
    render(r, state)

    if r.is_blinking and not blink_timer.started then
      blink_timer:start()
    elseif blink_timer.started and not r.is_blinking then
      blink_timer:stop()
    end

    w:set_markup(r:markup())
    prev_render = r
  end

  timer {
    timeout   = 60,
    autostart = true,
    call_now  = true,

    callback = refresh,
  }

  local spawn_err = spawn.with_line_callback('acpi_listen', {
    stdout = function(line)
      if string.sub(line, 1, #'battery') == 'battery' then
        refresh()
      end
    end,

    exit = function(reason, exit_code)
      log(string.format('acpi_listen exited due to %s (exit code = %d)', reason, exit_code))
    end,
  })

  if type(spawn_err) == 'string' then
    log('failed to spawn acpi_listen: ' .. spawn_err)
  end

  w:buttons(awful.util.table.join(
    awful.button({}, 1, refresh)))

  return w
end

return make_widget
