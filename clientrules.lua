local awful     = require 'awful'
local rules     = require 'awful.rules'
local beautiful = require 'beautiful'

local chat_tag = tags[left_screen][4]

rules.rules = {
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = true,
                     keys = clientkeys,
                     buttons = clientbuttons,
                     floating = false } },
    { rule = { class = "Chromium" },
      properties = { keys = chromiumkeys } },
    { rule = { instance = 'keepassx' },
      properties = { keys = keepasskeys } },
    { rule = { class = "Firefox" },
      properties = { tag = tags[preferred_screen][1] } },
    { rule = { class = "Claws-mail" },
      properties = { tag = tags[preferred_screen][3] } },

    { rule = { class = "Claws-mail", role = 'message_search' },
      properties = { floating = true } },

    { rule       = { class = 'Gajim' },
      properties = { tag = chat_tag },
      callback   = awful.client.setslave },

    { rule       = { class = 'Gajim', role = 'roster' },
      properties = { },
      callback   = awful.client.setmaster },

    { rule       = { class = 'Steam' },
      properties = { floating = true } },

    { rule       = { type = 'splash' },
      properties = { floating = true } },

    { rule_any   = { class = { 'XTerm', 'URxvt' } },
      properties = {},
      callback   = function(client)
        local tags = client:tags()
        local found

        for _, tag in ipairs(tags) do
          if tag == chat_tag then
            found = true
            break
          end
        end

        if found then
          awful.client.setslave(client)
        end
      end,
    },

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
        if c.first_tag == screen[left_screen].selected_tag then
          c:move_to_screen(mouse.screen.index)
          c:move_to_tag(mouse.screen.selected_tag)
        end
        client.focus = c
    end
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
