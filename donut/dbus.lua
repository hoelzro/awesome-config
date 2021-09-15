local cqueues = require 'cqueues'
local promise = require 'cqueues.promise'

local lgi = require 'lgi'
local gio = lgi.require 'Gio'
local glib = lgi.require 'GLib'

local dbus_proxy = require 'donut.dbus_proxy'

local module = {}

local function dbus_wrapper(dbus)
  local mt = {}

  function mt:__index(k)
    if k == 'proxy' then
      return function(_, bus_name, object_path)
        return dbus_proxy(dbus, bus_name, object_path)
      end
    elseif k == 'subscribe' then
      return function(_, params)
        local flags = params.flags or gio.DBusCallFlags.NONE
        dbus:signal_subscribe(params.sender, params.interface, params.member, params.object_path, params.arg0, flags, params.callback)
      end
    else
      local v = dbus[k]

      if type(v) == 'function' then
        return function(_, ...)
          return v(dbus, ...)
        end
      end

      return v
    end
  end

  return setmetatable({}, mt)
end

function module.get_session_bus()
  local bus_address = os.getenv 'DBUS_SESSION_BUS_ADDRESS'
  if not bus_address then
    return nil, 'Unable to determine session bus address'
  end

  local p = promise.new()

  -- XXX observable/cancellable?
  gio.DBusConnection.new_for_address(bus_address, gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION, nil, nil, function(dbus, res)
    local res, err = gio.DBusConnection.new_for_address_finish(res)

    if res then
      p:set(true, res)
    else
      p:set(false, err)
    end
  end)

  local ok, err_or_result = pcall(p.get, p)
  if ok then
    return dbus_wrapper(err_or_result)
  else
    return nil, err_or_result
  end
end

function module.get_bus(addr)
  local p = promise.new()

  gio.DBusConnection.new_for_address(addr, gio.DBusConnectionFlags.AUTHENTICATION_CLIENT, nil, nil, function(dbus, res)
    local res, err = gio.DBusConnection.new_for_address_finish(res)

    if res then
      p:set(true, res)
    else
      p:set(false, err)
    end
  end)

  local ok, err_or_result = pcall(p.get, p)
  if ok then
    return dbus_wrapper(err_or_result)
  else
    return nil, err_or_result
  end
end

return module
