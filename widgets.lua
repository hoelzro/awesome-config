-- Tiny Tiny RSS
-- Irssi

local awful     = require 'awful'
local beautiful = require 'beautiful'
local wibox     = require 'wibox'

require 'obvious.battery'
require 'obvious.clock'
local music_widget = require 'obvious.music'
require 'obvious.temp_info'
require 'obvious.keymap_switch'
local weather = require 'obvious.weather'

local audio = require 'audio'

local has_battery

do
  local found_battery

  function has_battery()
    if found_battery == nil then
      local pipe   = io.popen 'acpi'
      local output = pipe:read '*a'
      pipe:close()

      found_battery = not not string.match(output, '^Battery 0') -- force true/false
    end

    return found_battery
  end
end

local function separator()
  local sep = wibox.widget.textbox()
  sep:set_text ' | '
  return sep
end

obvious.clock.set_editor(editor_cmd)
obvious.clock.set_shortformat '%a %b %d %T'
obvious.clock.set_longformat(function() return '%a %b %d %T' end)
obvious.clock.set_shorttimer(1)
obvious.clock.set_scrolling(true)

music_widget.set_format  '$icon $artist - $title'
music_widget.set_backend 'mpris'
music_widget.set_length(50)
music_widget.set_marquee(true)

music_widget():buttons(awful.util.table.join(
  awful.button({ }, 1, function() audio.toggle() end),
  awful.button({ }, 4, function() audio.next() end),
  awful.button({ }, 5, function() audio.previous() end)
))

obvious.keymap_switch.set_layouts { 'us', 'ru' }

local myawesomemenu = {
   { "manual", terminal .. " -e man awesome" },
   { "edit config", editor_cmd .. " " .. awful.util.getdir("config") .. "/rc.lua" },
   { "restart", awesome.restart },
   { "quit", awesome.quit }
}

mymainmenu = awful.menu({ items = { { "awesome", myawesomemenu, beautiful.awesome_icon },
                                    { "open terminal", terminal }
                                  }
                        })

local mylauncher = awful.widget.launcher({ image = beautiful.awesome_icon,
                                     menu = mymainmenu })
local mysystray = wibox.widget.systray()

local mywibar = {}
root.wibars  = mywibar
mypromptbox = {}
local mylayoutbox = {}
local mytaglist = {}
mytaglist.buttons = awful.util.table.join(
                    awful.button({ }, 1, awful.tag.viewonly),
                    awful.button({ modkey }, 1, awful.client.movetotag),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, awful.client.toggletag),
                    awful.button({ }, 4, awful.tag.viewnext),
                    awful.button({ }, 5, awful.tag.viewprev)
                    )
local mytasklist = {}
mytasklist.buttons = awful.util.table.join(
                     awful.button({ }, 1, function (c)
                                              if not c:isvisible() then
                                                  awful.tag.viewonly(c:tags()[1])
                                              end
                                              client.focus = c
                                              c:raise()
                                          end),
                     awful.button({ }, 3, function ()
                                              if instance then
                                                  instance:hide()
                                                  instance = nil
                                              else
                                                  instance = awful.menu.clients({ width=250 })
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

for s = 1, screen.count() do
    mypromptbox[s] = awful.widget.prompt()
    mylayoutbox[s] = awful.widget.layoutbox(s)
    mylayoutbox[s]:buttons(awful.util.table.join(
                           awful.button({ }, 1, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(layouts, -1) end),
                           awful.button({ }, 4, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(layouts, -1) end)))
    mytaglist[s] = awful.widget.taglist(s, awful.widget.taglist.filter.all, mytaglist.buttons)

    mytasklist[s] = awful.widget.tasklist(s, awful.widget.tasklist.filter.currenttags, mytasklist.buttons)

    mywibar[s] = awful.wibar({ position = "top", screen = s })

    local left  = wibox.layout.fixed.horizontal()
    local right = wibox.layout.fixed.horizontal()
    left:add(mylauncher)
    left:add(mytaglist[s])
    left:add(mypromptbox[s])
    if s == preferred_screen  then
      _G.keymap_widget = obvious.keymap_switch()

      right:add(music_widget())
      right:add(separator())
      right:add(obvious.temp_info())
      right:add(separator())
      if has_battery() then
        right:add(obvious.battery())
        right:add(separator())
      end
      right:add(_G.keymap_widget)
      right:add(mysystray)
      right:add(separator())
      right:add(weather())
      right:add(separator())
      right:add(obvious.clock())
    end
    right:add(separator())
    right:add(mylayoutbox[s])

    local top = wibox.layout.align.horizontal()
    top:set_left(left)
    top:set_middle(mytasklist[s])
    top:set_right(right)

    mywibar[s]:set_widget(top)
end
