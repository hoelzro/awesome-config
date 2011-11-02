require 'awful.rules'

local chat_tag = tags[1][4]

awful.rules.rules = {
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = true,
                     keys = clientkeys,
                     buttons = clientbuttons,
                     floating = false } },
    { rule = { class = "Chromium" },
      properties = { tag = tags[preferred_screen][1], keys = chromiumkeys } },
    { rule = { class = "Firefox" },
      properties = { tag = tags[preferred_screen][9] } },
    { rule = { class = "Claws-mail" },
      properties = { tag = tags[preferred_screen][3] } },

    { rule       = { class = 'XTerm' },
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

    { rule       = {},
      properties = {},
      callback   = function(client)
        if client.transient_for then
          awful.client.floating.set(client, true)
        end
      end,
    },
}

client.add_signal("manage", function (c, startup)
    c:add_signal("mouse::enter", function(c)
        if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
            and awful.client.focus.filter(c) then
            client.focus = c
        end
    end)

    if not startup then
        if not c.size_hints.user_position and not c.size_hints.program_position then
            awful.placement.no_overlap(c)
            awful.placement.no_offscreen(c)
        end
    end
end)

client.add_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.add_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
