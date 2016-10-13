local old_connect_signal    = assert(dbus.connect_signal)
local old_disconnect_signal = assert(dbus.disconnect_signal)

local callbacks = {}
local wrapper_functions = {}

function dbus.connect_signal(name, callback)
  local cbs = callbacks[name]

  if not cbs then
    cbs = {}
    callbacks[name] = cbs

    wrapper_functions[name] = function(...)
      if #cbs == 1 then
        return cbs[1](...)
      else
        for i = 1, #cbs do
          -- XXX pcall
          cbs[i](...)
        end
      end
    end

    old_connect_signal(name, wrapper_functions[name])
  end

  cbs[#cbs + 1] = callback
end

function dbus.disconnect_signal(name, callback)
  local cbs = callbacks[name]

  if not cbs then
    return
  end

  for i = 1, #cbs do
    if cbs[i] == callback then
      table.remove(cbs, i)
      break
    end
  end

  if #cbs == 0 then
    old_disconnect_signal(name, wrapper_functions[name])
    wrapper_functions[name] = nil
    callbacks[name] = nil
  end
end
