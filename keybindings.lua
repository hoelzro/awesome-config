local audio       = require 'audio'
local awful       = require 'awful'
local naughty     = require 'naughty'

local insert_digraph = require('unicode-input').insert_unicode_digraph

local remorseful = require 'remorseful'

--[[local dashboard = ]] require 'dashboard'

local r_match = require('awful.rules').match
local iterate = require('awful.client').iterate

local function replaced_notify()
  local notification

  return function(args)
    if notification and notification.box.visible then
      args.replaces_id = notification.id
    end
    notification = naughty.notify(args)
  end
end

local mfact_notify      = replaced_notify()
local mcount_notify     = replaced_notify()
local brightness_notify = replaced_notify()

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

    do_brightness_notification {
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

    do_brightness_notification {
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
  mfact_notify {
    title = 'Window Factor',
    screen = mouse.screen,
    text  = tostring(awful.tag.getmwfact()),
  }
end

local function inform_master_change()
  mcount_notify {
    title = 'Master Count',
    screen = mouse.screen,
    text  = tostring(awful.tag.getnmaster()),
  }
end

local function myswap(dir)
  local focused = client.focus
  if not focused then
    return
  end

  local clients = awful.client.visible(focused.screen)

  for pos = 1, #clients do
    if clients[pos] == focused then

      if pos == 1 and dir == -1 then
        return awful.client.cycle(false, focused.screen)
      elseif pos == #clients and dir == 1 then
        return awful.client.cycle(true, focused.screen)
      else
        return awful.client.swap.byidx(dir)
      end
    end
  end
end

local awful_key = awful.key
local pcall     = pcall
local function key(modifiers, key, on_press, on_release)
  if on_press then
    local f = on_press

    on_press = function(...)
      local ok, err = pcall(f, ...)

      if not ok then
        alert(err)
      end
    end
  end

  if on_release then
    local f = on_release

    on_release = function(...)
      local ok, err = pcall(f, ...)

      if not ok then
        alert(err)
      end
    end
  end

  return awful_key(modifiers, key, on_press, on_release)
end

globalkeys = awful.util.table.join(
    key({ modkey,           }, "Left",   awful.tag.viewprev       ),
    key({ modkey,           }, "Right",  awful.tag.viewnext       ),
    key({ modkey, 'Shift'   }, "Escape", function() awful.spawn 'xautolock -locknow' end),
    key({                   }, "XF86Sleep", function() awful.spawn('gksudo systemctl suspend') end),
    key({                   }, "XF86Suspend", function() awful.spawn('gksudo systemctl suspend') end),
    key({ modkey,           }, 'q', function()
      local keepass_client

      local function match_keepass(c)
        return r_match(c, { class = 'keepassxc' })
      end

      for c in iterate(match_keepass, 1, nil) do
        keepass_client = c
        break
      end

      if keepass_client then
        local current_tag = awful.tag.selected(mouse.screen)
        keepass_client:move_to_tag(current_tag)
        client.focus = keepass_client
        keepass_client:raise()
      else
        awful.spawn 'firejail keepassxc'
      end
    end),

    key({                   }, "XF86AudioRaiseVolume", function() audio.louder(volume_delta) end),
    key({                   }, "XF86AudioLowerVolume", function() audio.quieter(volume_delta) end),
    key({                   },        "XF86AudioMute", audio.togglemute),

    key({                   },        "XF86AudioNext", audio.next),
    key({                   },        "XF86AudioPrev", audio.previous),
    key({                   },        "XF86AudioPlay", audio.toggle),
    key({                   },        "XF86AudioStop", audio.stop),

    key({                   }, 'XF86Back', awful.tag.viewprev),
    key({                   }, 'XF86Forward', awful.tag.viewnext),
    key({                   }, 'XF86MonBrightnessDown', lower_brightness),
    key({                   }, 'XF86MonBrightnessUp', raise_brightness),
    key({                   }, 'XF86ScreenSaver', function() awful.spawn 'xautolock -locknow' end),
    key({                   }, 'XF86Display', function() awful.spawn 'autorandr --change --default default' end),

    key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
            if client.focus then client.focus:raise() end
        end),
    key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
            if client.focus then client.focus:raise() end
        end),

    key({ modkey, "Shift"   }, "j", function () myswap( 1)    end),
    key({ modkey, "Shift"   }, "k", function () myswap(-1)    end),
    key({ modkey }, 'Tab', function () awful.screen.focus_relative(1) end),
    key({ modkey, 'Shift' }, 'Tab', awful.client.movetoscreen),
    key({ modkey, 'Shift' }, 'u', remorseful.cancel),

    key({ modkey,           }, "e", function () awful.spawn(terminal) end),

    key({ modkey,           }, "l",     function () increase_top_right( 0.05)     end),
    key({ modkey,           }, "h",     function () increase_top_right(-0.05)     end),
    key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1); inform_master_change() end),
    key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1); inform_master_change() end),
    --key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1)         end),
    --key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1)         end),
    key({ modkey,           }, "space", function () awful.layout.inc(layouts,  1) end),
    key({ modkey, "Shift"   }, "space", function () awful.layout.inc(layouts, -1) end),

    key({ modkey },            "r",     function () mypromptbox[mouse.screen]:run() end),
    key({modkey, 'Shift'}, 'r', function()
      awful.prompt.run {
        prompt  = 'Run Lua: ',
        textbox = mypromptbox[mouse.screen].widget,
        exe_callback = function(code)
          local f = load(code, 'chunk', 't', setmetatable({
            c = client.focus,
          }, {__index = _ENV}))
          f()
        end,
      }
    end),

    key({ modkey }, 'Escape', function() _G.keymap_widget:rotate_layout() end),

    key({ modkey }, 'f', function()
      local wibars = root.wibars

      for _, wibox in pairs(wibars) do
        wibox.visible = not wibox.visible
      end
    end),

    key({ modkey, 'Shift' }, "Right", audio.next),
    key({ modkey, 'Shift' }, "Left", audio.previous),
    key({ modkey, 'Shift' }, "Down", audio.toggle),
    key({ modkey, 'Shift' }, "KP_Add", function() audio.louder(volume_delta) end),
    key({ modkey, 'Shift' }, "KP_Subtract", function() audio.quieter(volume_delta) end),

    key({ modkey }, 'u', function()
      awful.prompt.run {
        prompt       = 'Insert Unicode digraph: ',
        textbox      = mypromptbox[mouse.screen].widget,
        exe_callback = insert_digraph,
      }
    end),

    key({ modkey, 'Shift' }, 's', function()
      awful.spawn.with_shell "echo -n '¯\\_(ツ)_/¯' | xclip -i -selection clipboard"
    end),

    -- XXX I'll need to `require 'dashboard'` after I'm done iterating
    key({ modkey }, 'BackSpace', function() dashboard.visible = true end, function() dashboard.visible = false end)
)

clientkeys = awful.util.table.join(
    key({ modkey, "Shift"   }, "c",      function (c)
      local is_urxvt = string.lower(c.class or '') == 'urxvt'

      -- XXX use awful.rules instead
      if is_urxvt then
        remorseful {
          start = function()
            remorseful.text = string.format('Closing %s (press Alt-Shift-u to cancel)', c.class)
            c.hidden = true
          end,

          commit = function()
            c:kill()
          end,

          cancel = function()
            c.hidden = false
          end,
        }
      else
        c:kill()
      end
    end),
    --key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ),
    key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end),
    key({ modkey,           }, "n",      function (c) c.minimized = not c.minimized    end),
    key({ modkey,           }, "m",
        function (c)
            local currently_maximized = (c.maximized or c.maximized_horizontal or c.maximized_vertical)

            c.maximized            = not currently_maximized
            c.maximized_horizontal = not currently_maximized
            c.maximized_vertical   = not currently_maximized
        end)
)

chromiumkeys = awful.util.table.join(
  clientkeys,
  key({ 'Shift', 'Control' }, 'q', noop),
  key({          'Control' }, 'd', noop),
  key({ 'Shift',           }, 'space', noop)
)

slackkeys = awful.util.table.join(
  clientkeys,
  key({ 'Control' }, 'w', noop)
)

keepasskeys = awful.util.table.join(
  clientkeys,
  key({ 'Control' }, 'v', noop)
)

local keynumber = 9

for i = 1, keynumber do
  globalkeys = awful.util.table.join(globalkeys,
    key({ modkey }, "#" .. i + 9,
      function ()
        local screen = mouse.screen
        if tags[screen][i] then
          tags[screen][i]:view_only()
        end
      end),
    key({ modkey, "Control" }, "#" .. i + 9,
      function ()
          local screen = mouse.screen
          if tags[screen][i] then
              awful.tag.viewtoggle(tags[screen][i])
          end
      end),
    key({ modkey, "Shift" }, "#" .. i + 9,
      function ()
        if client.focus and tags[client.focus.screen][i] then
          client.focus:move_to_tag(tags[client.focus.screen][i])
        end
      end),
    key({ modkey, "Control", "Shift" }, "#" .. i + 9,
      function ()
        if client.focus and tags[client.focus.screen][i] then
          awful.client.toggletag(tags[client.focus.screen][i])
        end
      end))
end

root.keys(globalkeys)
