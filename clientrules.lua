local awful     = require 'awful'
local rules     = require 'awful.rules'
local beautiful = require 'beautiful'

local success, json = pcall(require, "cjson")
if not success then
  json = require("json")
end

local window_buffer = {}
local window_buffer_size = 0
local window_buffer_max = 100

local flush_window_buffer = function()
        for i, v in pairs(window_buffer) do
                print(json.encode(v))
        end
        window_buffer = {}
        window_buffer_size = 0
end

table.insert(root.keys, awful.key({ modkey, "Control", "Shift" }, "f", flush_window_buffer))

rules.rules = {
    { rule = { },
      callback = function(c)
          local t = {
             ["message"] = "rule evaluation",
             ["when"] = os.date("%Y-%m-%dT%H:%M:%S"),
             ["name"] = c.name,
             ["type"] = c.type,
             ["class"] = c.class,
             ["instance"] = c.instance,
             ["role"] = c.role,
          }
          table.insert(window_buffer, t)
          window_buffer_size = window_buffer_size + 1
          if window_buffer_size > window_buffer_max then
                for i = 1, window_buffer_size - window_buffer_max, 1 do
                        table.remove(window_buffer, 1)
                end
          end
      end,
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = true,
                     keys = clientkeys,
                     buttons = clientbuttons,
                     floating = false } },
    { rule = { class = "Chromium" },
      properties = { keys = chromiumkeys } },
    { rule = { class = "Slack" },
      properties = { buttons = slackbuttons, keys = slackkeys } },
    { rule = { instance = 'keepassx' },
      properties = { keys = keepasskeys } },

    { rule = { class = "Claws-mail", role = 'message_search' },
      properties = { floating = true } },

    { rule       = { class = 'Gajim', role = 'roster' },
      properties = { },
      callback   = awful.client.setmaster },

    { rule       = { class = 'Steam' },
      properties = { floating = true } },

    { rule       = { type = 'splash' },
      properties = { floating = true } },

    {
        rule = {
          class = 'QtQmlViewer',
        },
        properties = {
          floating = true,
        },
    },

    {
        rule = {
          class = 'SshAskpass',
        },
        properties = {
          floating = true,
        },
    },

    {
        rule = {
          class = 'Gajim',
          name = 'XML Console',
        },
        properties = {
          floating = true,
        },
    },

    {
        rule = {
            type = 'dialog',
        },
        properties = {
          floating = true,
        },
    },

    { rule       = {},
      properties = {
        size_hints_honor = false,
      },
      callback   = function(client)
        if client.transient_for then
          awful.client.floating.set(client, true)
          client:move_to_screen(client.transient_for.screen)
          client:move_to_tag(client.transient_for.first_tag)
        end
      end,
    },
}

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
