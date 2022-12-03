local awful     = require 'awful'
local rules     = require 'awful.rules'
local beautiful = require 'beautiful'

local manage_log = require 'manage_log'
local named_rules = require 'named_rules'

-- XXX I bet I could leverage the named rules thing to enable smarter reloading of rules?
local rules = named_rules()

rules.general = {
  rule       = {},
  callback   = manage_log.record,
  properties = {
    border_width = beautiful.border_width,
    border_color = beautiful.border_normal,
    focus        = true,
    keys         = clientkeys,
    buttons      = clientbuttons,
    floating     = false,
  },
}

rules.chromium = {
  rule       = { class = 'Chromium' },
  properties = { keys = chromiumkeys },
}

rules.slack = {
  rule       = { class = 'Slack' },
  properties = { buttons = slackbuttons, keys = slackkeys },
}

rules.keepass = {
  rule       = { instance = 'keepassx' },
  properties = { keys = keepasskeys },
}

rules.steam = {
  rule       = { class = 'Steam' },
  properties = { floating = true },
}

rules.splash = {
  rule       = { type = 'splash' },
  properties = { floating = true },
}

rules.dialog = {
  rule       = { type = 'dialog' },
  properties = { floating = true },
}

rules.sshaskpass = {
  rule = {
    class = 'SshAskpass',
  },
  properties = {
    floating = true,
  },
}

rules.transient_for = {
  rule       = {},
  properties = {
    size_hints_honor = false,
  },
  callback = function(client)
    if client.transient_for then
      awful.client.floating.set(client, true)
      client:move_to_screen(client.transient_for.screen)
      client:move_to_tag(client.transient_for.first_tag)
    end
  end,
}

local rule_metadata
-- XXX this sucks
require('awful.rules').rules, rule_metadata = rules:build()

rules = require 'awful.rules' -- XXX this sucks - remove this
local log = print

-- XXX "lawg" for original client properties?
log 'here'
rules.add_rule_source('my-clientrules', function(c)
  for i = 1, #rules.rules do
    local rule = rules.rules[i]
    local rule_matches = rules.matches(c, rule)
    log(string.format('client = %s - checking rule #%d (%s) - %s', tostring(c), i, (rule_metadata[rule] or {name='<unknown>'}).name, tostring(rule_matches)))
  end
end, {}, {'awful.rules'})
log 'there'

client.connect_signal("manage", function (c)
    c:connect_signal("mouse::enter", function(c)
        if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
            and awful.client.focus.filter(c) then
            client.focus = c
        end
    end)

    if not awesome.startup then
        if not c.size_hints.user_position and not c.size_hints.program_position then
            awful.placement.no_overlap(c)
            awful.placement.no_offscreen(c)
        end
        if c.first_tag == screen[1].selected_tag then
          c:move_to_screen(mouse.screen.index)
          c:move_to_tag(mouse.screen.selected_tag)
        end
        client.focus = c
    end
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
