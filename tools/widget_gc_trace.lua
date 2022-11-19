local timer = require 'gears.timer'

-- XXX seeing how a widget is reachable would be :chef_kiss:
-- XXX to exercise this, I need to xrandr screens and such - should I hook into screen events?

local function log(...)
  print(os.date '%F %T', ...)
end

local widgets = setmetatable({}, {__mode = 'k'})

local canary_mt = {}

function canary_mt:__gc()
  if self.__tostring then
    log(string.format('%s got collected', self:__tostring()))
  else
    log(string.format('%s got collected', self.widget_name))
  end
end

local function widget_gc_trace(w, extra_data)
  local call_site

  if debug.getinfo(1, 't').istailcall then
    log 'Avoid tail calling widget_gc_trace to get origin tracking'
  else
    local caller = debug.getinfo(2, 'Sl')
    call_site = string.format('%s:%d', caller.short_src, caller.currentline)
  end

  widgets[w] = setmetatable({
    -- storing name, and not the widget itself, so as to avoid creating a strong reference
    widget_name = tostring(w),
    track_time  = os.time(),
    origin      = call_site,
  }, canary_mt)
  if extra_data then
    for k, v in pairs(extra_data) do
      widgets[w][k] = v
    end
  end
  return w
end

local function dump_data()
  collectgarbage 'collect'
  collectgarbage 'collect'

  print '--- Dumping Widget Data ---'
  for widget, metadata in pairs(widgets) do
    -- XXX use __tostring here too
    log(widget)
    if metadata.__tostring then
      log(metadata:__tostring())
    else
      local pretty = require 'pretty'
      pretty.print(metadata)
    end
  end
end

timer {
  timeout = 60,
  autostart = true,

  callback = dump_data,
}

return widget_gc_trace
