local awful = require 'awful'

layouts = {
    awful.layout.suit.tile,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.tile.top,

    awful.layout.suit.fair,
    awful.layout.suit.fair.horizontal,
    awful.layout.suit.max,
    awful.layout.suit.floating,
}

tags = {}
for s = 1, screen.count() do
    tags[s] = awful.tag({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, s, {
      layouts[7],
      layouts[1],
      layouts[3],
      layouts[1],
      layouts[7],
      layouts[1],
      layouts[1],
      layouts[1],
      layouts[1],
    })
end

awful.tag.setmwfact(0.20, tags[1][4])
