local dbus = require 'donut.dbus'

return {
  run             = require 'donut.cqueues',
  get_session_bus = dbus.get_session_bus,
  get_bus         = dbus.get_bus,
  decode_variant  = require('donut.dbus_proxy').decode_variant,
}
