-- Tiny Tiny RSS
-- Irssi

local unpack = unpack or table.unpack

local awful     = require 'awful'
local beautiful = require 'beautiful'
local wibox     = require 'wibox'
local textclock = require 'wibox.widget.textclock'
local calendar  = require 'awful.widget.calendar_popup'

local dpi = require('beautiful').xresources.apply_dpi

local battery = require 'widgets.battery'
local config = require 'widgets.config'
local music_widget = require 'widgets.music'
local temp_widget = require 'widgets.temperature'

local weather = require 'widgets.weather'

local remorseful = require 'remorseful'
local safe_restart = require 'safe-restart'

local function separator()
  local sep = wibox.widget.textbox()
  sep:set_text ' | '
  return sep
end

local function attached(attacher, attached)
  attacher:attach(attached)
  return attached
end

awesome.register_xproperty('_NET_WM_ICON_NAME', 'string')
awesome.register_xproperty('WM_ICON_NAME', 'string')

local myawesomemenu = {
   { "manual", terminal .. " -e man awesome" },
   { "edit config", editor_cmd .. " " .. awful.util.getdir("config") .. "/rc.lua" },
   { "restart", safe_restart },
}

mymainmenu = awful.menu({ items = { { "awesome", myawesomemenu, beautiful.awesome_icon },
                                    { "open terminal", terminal }
                                  }
                        })

local mylauncher = awful.widget.launcher({ image = beautiful.awesome_icon,
                                     menu = mymainmenu })
local mysystray = wibox.widget.systray()

local mywibar = setmetatable({}, {__mode = 'k'})
root.wibars  = mywibar
mypromptbox = setmetatable({}, {__mode = 'k'})
local mylayoutbox = {}
local mytaglist = {}
mytaglist.buttons = awful.util.table.join(
                    awful.button({ }, 1, function(t) t:view_only() end),
                    awful.button({ modkey }, 1, awful.client.movetotag),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, awful.client.toggletag),
                    awful.button({ }, 4, awful.tag.viewnext),
                    awful.button({ }, 5, awful.tag.viewprev)
                    )
local mytasklist = {}
local client_menu
mytasklist.buttons = awful.util.table.join(
  awful.button({ }, 1, function (c)
    if not c:isvisible() then
      c:tags()[1]:view_only()
    end
    client.focus = c
    c:raise()
  end),

  awful.button({ }, 3, function ()
    if client_menu then
      client_menu:hide()
      client_menu = nil
    else
      client_menu = awful.menu.clients({ theme = {width=250} })
    end
  end),

  awful.button({'Ctrl'}, 3, function(c)
    if client_menu then
      client_menu:hide()
      client_menu = nil
    else
      local properties = {
        'minimized', 'ontop', 'above', 'below', 'fullscreen', 'maximized',
        'maximized_horizontal', 'maximized_vertical', 'sticky', 'floating',
      }

      local entries = {}

      for i = 1, #properties do
        local prop_name = properties[i]
        local pretty_name = string.gsub(string.gsub(prop_name, '_', ' '), '%f[a-z]([a-z])', string.upper)

        if c[prop_name] then
          pretty_name = '✓ ' .. prop_name
        else
          pretty_name = '  ' .. prop_name
        end

        local function toggle_prop()
          c[prop_name] = not c[prop_name]
        end

        entries[#entries + 1] = {
          pretty_name,
          toggle_prop,
        }
      end

      local function rename_window()
        awful.prompt.run {
          prompt       = 'New Name: ',
          textbox      = mypromptbox[mouse.screen].widget,
          exe_callback = function(name)
            c.name = name

            c:set_xproperty('_NET_WM_ICON_NAME', name)
            c:set_xproperty('WM_ICON_NAME', name)
          end,
        }
      end

      entries[#entries + 1] = { '----------------------------------------' }

      entries[#entries + 1] = { 'rename window', rename_window }

      client_menu = awful.menu {
        items = entries,
        theme = {
          width = 250,
        },
      }
      client_menu:show()
    end
  end),

  awful.button({ }, 4, function ()
    awful.client.focus.byidx(1)
    if client.focus then client.focus:raise() end
  end),

  awful.button({ }, 5, function ()
    awful.client.focus.byidx(-1)
    if client.focus then client.focus:raise() end
  end))

awful.screen.connect_for_each_screen(function(s)
    mypromptbox[s] = awful.widget.prompt()
    mylayoutbox[s] = awful.widget.layoutbox(s)
    mylayoutbox[s]:buttons(awful.util.table.join(
                           awful.button({ }, 1, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(layouts, -1) end),
                           awful.button({ }, 4, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(layouts, -1) end)))
    mytaglist[s] = awful.widget.taglist(s, awful.widget.taglist.filter.all, mytaglist.buttons)

    mytasklist[s] = awful.widget.tasklist{
      screen = s,
      filter = awful.widget.tasklist.filter.currenttags, 
      buttons = mytasklist.buttons,

      widget_template = {
        {
          {
            {
              id = 'clienticon',
              widget = awful.widget.clienticon,
            },
            id     = 'icon_margin_role',
            left   = dpi(4),
            widget = wibox.container.margin,
          },
          {
              {
                  id = 'scroll',
                  layout = wibox.container.scroll.horizontal,
                  step_function = wibox.container.scroll.step_functions.linear_back_and_forth,
                  speed = 300, -- XXX figure me out - 300 is good for linear_back_and_forth, but shit for linear_increase
                  {
                    id     = 'text_role',
                    widget = wibox.widget.textbox,
                  }
              },
              id     = 'text_margin_role',
              left   = dpi(4),
              right  = dpi(4),
              widget = wibox.container.margin,
          },
          fill_space = true,
          layout     = wibox.layout.fixed.horizontal
        },
        id = 'background_role',
        widget = wibox.container.background,
        create_callback = function(self, c)
          self:get_children_by_id('clienticon')[1].client = c

          local scroll_kid = self:get_children_by_id('scroll')[1]
          scroll_kid:set_extra_space(10) -- XXX fontmetrics, dpi
          scroll_kid:pause()
          scroll_kid:connect_signal('mouse::enter', function()
            scroll_kid:continue()
          end)
          scroll_kid:connect_signal('mouse::leave', function()
            scroll_kid:pause()
            scroll_kid:reset_scrolling()
          end)
        end,
      },
    }

    mywibar[s] = awful.wibar({ position = "top", screen = s })

    local left  = wibox.layout.fixed.horizontal()
    local right = wibox.layout.fixed.horizontal()
    left:add(mylauncher)
    left:add(mytaglist[s])
    left:add(mypromptbox[s])

    left:add(remorseful.widget)

    local month_calendar = calendar.month {
      screen       = s,
      spacing      = 0,
      margin       = 0,
      start_sunday = true,
      style_month = {
        border_width = 0,
      },
      style_header = {
        border_width = 0,
      },
      style_weekday = {
        border_width = 0,
      },
      style_weeknumber = {
        border_width = 0,
      },
      style_normal = {
        border_width = 0,
      },
      style_focus = {
        border_width = 0,
      },
    }

    right:add(music_widget())
    right:add(separator())
    right:add(temp_widget())
    right:add(separator())
    local battery_widget = battery()
    if battery_widget then
      right:add(battery_widget)
      right:add(separator())
    end
    right:add(mysystray)
    right:add(separator())
    right:add(weather())
    right:add(separator())
    right:add(textclock('%a %b %d', 60))

    local timezones = config.timezones or {}
    local primary_timezone

    for i = 1, #timezones do
      local name, timezone = unpack(timezones[i])
      if name == timezones.primary then
        primary_timezone = timezones[i]
        goto continue
      end

      right:add(textclock(' <b>' .. name .. '</b>: %H:%M', 60, timezone))

      ::continue::
    end

    if primary_timezone then
      local name, timezone = unpack(primary_timezone)
      right:add(attached(month_calendar, textclock(' <b>' .. name .. '</b>: %H:%M:%S', 1, timezone)))
    end

    right:add(separator())
    right:add(mylayoutbox[s])

    local top = wibox.layout.align.horizontal()
    top:set_left(left)
    top:set_middle(mytasklist[s])
    top:set_right(right)

    mywibar[s]:set_widget(top)
end)

screen.connect_signal('removed', function(s)
  mywibar[s] = nil
  mypromptbox[s] = nil
end)
