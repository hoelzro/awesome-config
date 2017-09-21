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
for s = 1, screen.count() do
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
end

tags[left_screen][4].master_width_factor = 0.20
