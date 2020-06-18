local awful = require 'awful'

layouts = {
    awful.layout.suit.tile,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.tile.top,

    awful.layout.suit.max,
    awful.layout.suit.floating,
}

awful.layout.suit.tile.left.mirror = true
awful.layout.suit.tile.top.mirror  = true

layouts.tilebottom = layouts[3]
layouts.max        = layouts[5]
layouts.default    = layouts.max

tags = {}
awful.screen.connect_for_each_screen(function(s)
    tags[s] = awful.tag({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, s, {
      layouts.max,
      layouts.default,
      layouts.max,
      layouts.default,
      layouts.max,
      layouts.default,
      layouts.default,
      layouts.default,
      layouts.default,
    })

    s:connect_signal('removed', function()
      tags[s] = nil
    end)
end)

client.connect_signal('request::tag', function(c, tag, opts)
  if tag ~= nil or (opts or {}).reason ~= 'screen-removed' then
    return
  end

  local current_screen = c.first_tag.screen
  local new_screen

  for other_screen in screen do
    if other_screen ~= current_screen then
      new_screen = other_screen
      break
    end
  end

  local current_tag = c.first_tag
  local new_tag

  if new_screen then
    for i = 1, #tags[new_screen] do
      local other_tag = tags[new_screen][i]
      if other_tag.index == current_tag.index then
        new_tag = other_tag
        break
      end
    end
  end

  if new_tag then
    c:move_to_tag(new_tag)
  else
    -- XXX fallback?
    alert(string.format('unable to move client %s to new screen', tostring(c)))
  end
end)
