local promise = require 'cqueues.promise'

local lgi = require 'lgi'
local gio = lgi.require 'Gio'
local glib = lgi.require 'GLib'

local parse_xml = require('lxp.lom').parse

local PRIMITIVE_VARIANT_TYPES = {
  b = true, -- boolean
  d = true, -- double
  i = true, -- 32-bit signed int
  o = true, -- object path
  s = true, -- string
  t = true, -- 64-bit unsigned int
  u = true, -- 32-bit unsigned int
}

-- XXX only call me from dbus_call (why? I'm guessing due to the `return true` bit below and the
--     auto-unpacking behavior from tuples, and/or only covering the subset of variants returned by
--     making D-Bus calls?)
-- XXX either way, I'm going to disregard this and hope nothing breaks 😅
local function decode_variant(v)
  if not glib.Variant:is_type_of(v) then
    return v
  end

  local vtype = v.type
  local first = string.sub(vtype, 1, 1)

  if first == '(' then -- tuple
    local contents = {}
    local n = v:n_children()

    for i = 0, n - 1 do
      contents[i + 1] = decode_variant(v:get_child_value(i))
    end

    if n == 0 then
      return true -- XXX I hate this - dummy placeholder for assert to work with
    else
      return table.unpack(contents, 1, n)
    end
  elseif first == 'a' then -- array
    if string.sub(vtype, 2, 2) == '{' then
      local contents = {}
      local n = v:n_children()

      for i = 0, n - 1 do
        local entry = v:get_child_value(i)
        local name = decode_variant(entry:get_child_value(0))
        local value = decode_variant(entry:get_child_value(1))
        contents[name] = value
      end

      return contents
    else
      local contents = {}
      local n = v:n_children()

      for i = 0, n - 1 do
        contents[i + 1] = decode_variant(v:get_child_value(i))
      end

      return contents
    end
  elseif vtype == 'v' then
    return decode_variant(v.value)
  elseif PRIMITIVE_VARIANT_TYPES[vtype] then
    return v.value
  end

  error(string.format('unable to handle variant of type %q', v.type))
end

local function dbus_call(params)
  local dbus = params.dbus

  local p = promise.new()

  local parameters = glib.Variant.new_tuple(params.parameters)

  dbus:call(
    params.bus_name,
    params.object_path,
    params.interface_name,
    params.method_name,
    parameters,
    glib.VariantType.new(params.reply_type),
    gio.DBusCallFlags.NONE,
    -1,
    nil,
    function(_, res)
      local res, err = dbus:call_finish(res)

      if res then
        p:set(true, res)
      else
        p:set(false, err)
      end
    end)

  local ok, err_or_result = pcall(p.get, p)
  if ok then
    return decode_variant(err_or_result)
  else
    return nil, err_or_result
  end
end

local function gather_parameters(lom)
  local parameters = {}

  for i = 1, #lom do
    if type(lom[i]) == 'table' and lom[i].tag == 'arg' and lom[i].attr.direction == 'in' then
      parameters[#parameters+1] = { name = lom[i].attr.name, type = lom[i].attr.type }
    end
  end

  return parameters
end

local function gather_return_values(lom)
  local parameters = {}

  for i = 1, #lom do
    if type(lom[i]) == 'table' and lom[i].tag == 'arg' and lom[i].attr.direction == 'out' then
      parameters[#parameters+1] = { name = lom[i].attr.name, type = lom[i].attr.type }
    end
  end

  return parameters
end

local function gather_methods(lom)
  local methods = {}

  for i = 1, #lom do
    if type(lom[i]) == 'table' and lom[i].tag == 'method' then
      methods[#methods+1] = {
        name = lom[i].attr.name,
        parameters = gather_parameters(lom[i]),
        return_values = gather_return_values(lom[i]),
      }
    end
  end

  return methods
end

local function gather_interfaces(lom)
  local interfaces = {}

  for i = 1, #lom do
    if type(lom[i]) == 'table' and lom[i].tag == 'interface' then
      interfaces[#interfaces+1] = { name = lom[i].attr.name, methods = gather_methods(lom[i]) }
    end
  end

  return interfaces
end

local function value_as_variant(spec, value)
  -- if we already have a variant, just go with that
  if glib.Variant:is_type_of(value) then
    assert(spec.type == 'v')
    -- XXX what if it's already wrapping a variant?
    return glib.Variant('v', value)
  end

  if type(value) == 'string' then
    assert(spec.type == 's')
    return glib.Variant('s', value)
  elseif type(value) == 'table' then
    if string.sub(spec.type, 1, 1) == 'a' then
      assert(#spec.type == 2)
      local element_type = string.sub(spec.type, 2, 2)
      local child_values = {}

      -- XXX #value, or something else like value.n?
      for i = 1, #value do
        child_values[i] = value_as_variant(element_type, value[i])
      end

      return glib.Variant(spec.type, child_values)
    end
  end
  error(string.format('unable to handle value of type %q with spec type of %q', type(value), spec.type))
end

local function generate_method(dbus, bus_name, object_path, interface_name, method_name, parameters, return_values)
  assert(#return_values <= 1)

  local reply_type
  if #return_values == 1 then
    reply_type = '(' .. return_values[1].type .. ')'
  else
    reply_type = '()'
  end

  return function(_, ...)
    -- XXX do this part in dbus_call? 
    local n_params = select('#', ...)
    local variant_parameters = {}

    for i = 1, n_params do
      local param_spec = parameters[i]
      local param_value = select(i, ...)

      variant_parameters[i] = value_as_variant(param_spec, param_value)
    end

    return dbus_call {
      dbus           = dbus,
      bus_name       = bus_name,
      object_path    = object_path,
      interface_name = interface_name,
      method_name    = method_name,
      parameters     = variant_parameters,
      reply_type     = reply_type,
    }
  end
end

local function generate_methods(dbus, bus_name, object_path, interfaces)
  local generated = {}
  local claims = {}

  for i = 1, #interfaces do
    local interface_name = interfaces[i].name
    local methods = interfaces[i].methods

    for j = 1, #methods do
      local method = methods[j]

      if claims[method.name] then
        error(string.format('ambiguous method %q is provided by both %q and %q', method.name, interface_name, claims[method.name]))
      end
      claims[method.name] = interface_name
      generated[method.name] = generate_method(dbus, bus_name, object_path, interface_name, method.name, method.parameters, method.return_values)
    end
  end

  return generated
end

-- I *think* that just 'k' is correct here - the keys are dbus connection objects,
-- so we shouldn't be restricting them from getting GC'd.  The values are
-- (bus_name, object_path) → proxy object tables, and those should *not* be reachable
-- from elsewhere in Lua land, so using 'v' for the mode would result in them getting
-- collected every time
local proxy_cache = setmetatable({}, {__mode = 'k'})

local function dbus_proxy(dbus, bus_name, object_path)
  local this_bus_cache = proxy_cache[dbus]
  if not this_bus_cache then
    -- values need to be weak, since proxy_cache has strong values but we don't want
    -- to keep proxy objects around if the rest of the program has stopped using them
    this_bus_cache = setmetatable({}, {__mode = 'v'})
    proxy_cache[dbus] = this_bus_cache
  end

  local cache_key = bus_name .. '\x1f' .. object_path

  local cached_proxy = this_bus_cache[cache_key]
  if cached_proxy then
    return cached_proxy
  end

  local xml, err = dbus_call {
    dbus           = dbus,
    bus_name       = bus_name,
    object_path    = object_path,
    interface_name = 'org.freedesktop.DBus.Introspectable',
    method_name    = 'Introspect',
    parameters     = {},
    reply_type     = '(s)',
  }
  if not xml then
    return nil, err
  end
  local lom, err = parse_xml(xml)
  if not lom then
    return nil, err
  end
  local interfaces = gather_interfaces(lom)
  local proxy = generate_methods(dbus, bus_name, object_path, interfaces)
  this_bus_cache[cache_key] = proxy
  return proxy
end

return dbus_proxy
