local audio   = require 'audio'
local awful   = require 'awful'
local naughty = require 'naughty'
local volume  = require 'volume'

local do_volume_notification
do
  local volume_icon_base = '/usr/share/icons/gnome/24x24/status/'
  local volume_notification

  do_volume_notification = function(args)
    if args.icon then
      args.icon = volume_icon_base .. args.icon
    end

    if volume_notification and volume_notification.box.screen then
      args.replaces_id = volume_notification.id
    end

    volume_notification = naughty.notify(args)
  end
end

local function louder()
    local volume = volume.increment()

    do_volume_notification {
      title   = 'Volume Changed',
      text    = tostring(volume) .. '%',
      icon    = 'stock_volume-max.png',
      opacity = volume / 100,
    }
end

local function quieter()
    local volume = volume.decrement()

    do_volume_notification {
      title   = 'Volume Changed',
      text    = tostring(volume) .. '%',
      icon    = 'stock_volume-min.png',
      opacity = volume / 100,
    }
end

local function togglemute()
    local state = volume.toggle()

    if state then
      do_volume_notification {
        title = 'Volume Changed',
        text  = 'Muted',
        icon  = 'stock_volume-mute.png'
      }
    else
      do_volume_notification {
        title = 'Volume Changed',
        text  = 'Unmuted',
        icon  = 'stock_volume-max.png'
      }
    end
end

local function noop()
end

local lower_brightness
local raise_brightness

do
  local brightness_level = 100

  function lower_brightness()
    local step = math.floor(65535 / 20) -- 5%
    os.execute('xbrightness -' .. tostring(step))

    brightness_level = brightness_level - 5
    if brightness_level < 0 then
      brightness_level = 0
    end

    -- I know, not volume...
    do_volume_notification {
      title = 'Brightness Changed',
      text  = tostring(brightness_level) .. '%'
    }
  end

  function raise_brightness()
    local step = math.floor(65535 / 20) -- 5%
    os.execute('xbrightness +' .. tostring(step))

    brightness_level = brightness_level + 5
    if brightness_level > 100 then
      brightness_level = 100
    end

    -- I know, not volume...
    do_volume_notification {
      title = 'Brightness Changed',
      text  = tostring(brightness_level) .. '%'
    }
  end
end

local function current_layout()
  return awful.layout.get(client.focus.screen)
end

local function increase_top_right(factor)
  local layout = current_layout()

  if layout.mirror then
    factor = factor * - 1
  end

  awful.tag.incmwfact(factor)
end

globalkeys = awful.util.table.join(
    awful.key({ modkey,           }, "Left",   awful.tag.viewprev       ),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext       ),
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore),
    awful.key({ modkey, 'Shift'   }, "Escape", function() awful.util.spawn('slimlock') end),
    awful.key({                   }, "XF86Sleep", function() awful.util.spawn('gksudo pm-suspend') end),
    awful.key({                   }, "XF86Suspend", function() awful.util.spawn('gksudo pm-suspend') end),
    awful.key({ modkey,           }, "q", function() awful.util.spawn('keepassx') end),
    awful.key({ modkey,           }, "`", function() awful.util.spawn('disper -e') end),

    awful.key({                   }, "XF86AudioRaiseVolume", louder),
    awful.key({                   }, "XF86AudioLowerVolume", quieter),
    awful.key({                   },        "XF86AudioMute", togglemute),

    awful.key({                   },        "XF86AudioNext", audio.next),
    awful.key({                   },        "XF86AudioPrev", audio.previous),
    awful.key({                   },        "XF86AudioPlay", audio.toggle),
    awful.key({                   },        "XF86AudioStop", audio.stop),

    awful.key({                   }, 'XF86Back', awful.tag.viewprev),
    awful.key({                   }, 'XF86Forward', awful.tag.viewnext),
    awful.key({                   }, 'XF86MonBrightnessDown', lower_brightness),
    awful.key({                   }, 'XF86MonBrightnessUp', raise_brightness),
    awful.key({                   }, 'XF86ScreenSaver', function() awful.util.spawn('slimlock') end),

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
          local currentscreen = client.focus.screen
          local newscreen     = currentscreen + 1
          if newscreen > screen.count() then
            newscreen = 1
          end
          awful.screen.focus(newscreen)
        end),

    awful.key({ modkey,           }, "e", function () awful.util.spawn(terminal) end),
    awful.key({ modkey, "Control" }, "r", awesome.restart),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit),

    awful.key({ modkey,           }, "l",     function () increase_top_right( 0.05)     end),
    awful.key({ modkey,           }, "h",     function () increase_top_right(-0.05)     end),
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
              end),
    awful.key({ modkey }, 'f', function()
      local wiboxes = root.wiboxes()

      for _, wibox in pairs(wiboxes) do
        wibox.visible = not wibox.visible
      end
    end)
)

clientkeys = awful.util.table.join(
    awful.key({ modkey, "Shift"   }, "c",      function (c) c:kill()                         end),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end),
    awful.key({ modkey,           }, "o",      awful.client.movetoscreen                        ),
    awful.key({ modkey, "Shift"   }, "r",      function (c) c:redraw()                       end),
    awful.key({ modkey,           }, "n",      function (c) c.minimized = not c.minimized    end),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c.maximized_vertical   = not c.maximized_vertical
        end)
)

chromiumkeys = awful.util.table.join(
  clientkeys,
  awful.key({ 'Shift', 'Control' }, 'q', noop),
  awful.key({          'Control' }, 'd', noop),
  awful.key({ 'Shift',           }, 'space', noop)
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
