local awful = require 'awful'
local rmatch = require('rex_pcre').match
local amixerpattern = '\\[(\\d{1,3})%\\].*\\[(on|off)\\]'

local volume_icon_base = '/usr/share/icons/gnome/24x24/status/'
local function louder()
    local volume = get_mixer_state()
    volume = volume + 5
    if volume > 100 then
      volume = 100
    end
    os.execute('amixer set Master ' .. volume .. '%')

    naughty.notify {
      title = 'Volume Changed',
      text  = volume .. '%',
      icon  = volume_icon_base .. 'stock_volume-max.png'
    }
end

local function quieter()
    local volume = get_mixer_state()
    volume = volume - 5
    if volume < 0 then
      volume = 0
    end
    os.execute('amixer set Master ' .. volume .. '%')
    naughty.notify {
      title = 'Volume Changed',
      text  = volume .. '%',
      icon  = volume_icon_base .. 'stock_volume-min.png'
    }
end

local function togglemute()
    local _, state = get_mixer_state()

    if state == 'on' then
      os.execute('amixer set Master mute')
      naughty.notify {
        title = 'Volume Changed',
        text  = 'Muted',
        icon  = volume_icon_base .. 'stock_volume-mute.png'
      }
    else
      os.execute('amixer set Master unmute')
      naughty.notify {
        title = 'Volume Changed',
        text  = 'Unmuted',
        icon  = volume_icon_base .. 'stock_volume-max.png'
      }
    end
end

local function get_mixer_state()
  local pipe   = assert(io.popen 'amixer get Master')
  local output = pipe:read '*a'
  pipe:close()

  return rmatch(output, amixerpattern)
end

globalkeys = awful.util.table.join(
    awful.key({ modkey,           }, "Left",   awful.tag.viewprev       ),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext       ),
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore),
    awful.key({ modkey, 'Shift'   }, "Escape", function() awful.util.spawn('sflock') end),
    awful.key({                   }, "XF86Sleep", function() awful.util.spawn('gksudo pm-suspend') end),
    awful.key({                   }, "XF86Suspend", function() awful.util.spawn('gksudo pm-suspend') end),
    awful.key({ modkey,           }, "q", function() awful.util.spawn('keepassx') end),

    awful.key({                   }, "XF86AudioRaiseVolume", louder),
    awful.key({                   }, "XF86AudioLowerVolume", quieter),
    awful.key({                   },        "XF86AudioMute", togglemute),

    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
            if client.focus then client.focus:raise() end
        end),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
            if client.focus then client.focus:raise() end
        end),
    awful.key({ modkey,           }, "w", function () mymainmenu:show({keygrabber=true}) end),

    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end),

    awful.key({ modkey,           }, "e", function () awful.util.spawn(terminal) end),
    awful.key({ modkey, "Control" }, "r", awesome.restart),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)    end),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)    end),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1)      end),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1)      end),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1)         end),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1)         end),
    awful.key({ modkey,           }, "space", function () awful.layout.inc(layouts,  1) end),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(layouts, -1) end),

    awful.key({ modkey },            "r",     function () mypromptbox[mouse.screen]:run() end),

    awful.key({ modkey }, "x",
              function ()
                  awful.prompt.run({ prompt = "Run Lua code: " },
                  mypromptbox[mouse.screen].widget,
                  awful.util.eval, nil,
                  awful.util.getdir("cache") .. "/history_eval")
              end)
)

clientkeys = awful.util.table.join(
    awful.key({ modkey,           }, "f",      function (c) c.fullscreen = not c.fullscreen  end),
    awful.key({ modkey, "Shift"   }, "c",      function (c) c:kill()                         end),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end),
    awful.key({ modkey,           }, "o",      awful.client.movetoscreen                        ),
    awful.key({ modkey, "Shift"   }, "r",      function (c) c:redraw()                       end),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end),
    awful.key({ modkey,           }, "n",      function (c) c.minimized = not c.minimized    end),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c.maximized_vertical   = not c.maximized_vertical
        end)
)

local keynumber = 0
for s = 1, screen.count() do
   keynumber = math.min(9, math.max(#tags[s], keynumber));
end

for i = 1, keynumber do
    globalkeys = awful.util.table.join(globalkeys,
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = mouse.screen
                        if tags[screen][i] then
                            awful.tag.viewonly(tags[screen][i])
                        end
                  end),
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = mouse.screen
                      if tags[screen][i] then
                          awful.tag.viewtoggle(tags[screen][i])
                      end
                  end),
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus and tags[client.focus.screen][i] then
                          awful.client.movetotag(tags[client.focus.screen][i])
                      end
                  end),
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus and tags[client.focus.screen][i] then
                          awful.client.toggletag(tags[client.focus.screen][i])
                      end
                  end))
end

root.keys(globalkeys)
