-- Google Reader
-- Irssi

require 'obvious.basic_mpd'
require 'obvious.battery'
require 'obvious.clock'
require 'obvious.cpu'
require 'obvious.mem'
require 'obvious.temp_info'

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

obvious.clock.set_editor(editor_cmd)
obvious.clock.set_shortformat '%a %b %d %T'
obvious.clock.set_longformat(function() return '%a %b %d %T' end)
obvious.clock.set_shorttimer(1)

obvious.basic_mpd.set_format '$artist - $title'

obvious.basic_mpd():buttons(awful.util.table.join(
  awful.button({ }, 1, function() obvious.basic_mpd.connection:toggle_play() end),
  awful.button({ }, 4, function() obvious.basic_mpd.connection:next() end),
  awful.button({ }, 5, function() obvious.basic_mpd.connection:previous() end)
))

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

local mylauncher = awful.widget.launcher({ image = image(beautiful.awesome_icon),
                                     menu = mymainmenu })
local mysystray = widget({ type = "systray" })

local mywibox = {}
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
    mypromptbox[s] = awful.widget.prompt({ layout = awful.widget.layout.horizontal.leftright })
    mylayoutbox[s] = awful.widget.layoutbox(s)
    mylayoutbox[s]:buttons(awful.util.table.join(
                           awful.button({ }, 1, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(layouts, -1) end),
                           awful.button({ }, 4, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(layouts, -1) end)))
    mytaglist[s] = awful.widget.taglist(s, awful.widget.taglist.label.all, mytaglist.buttons)

    mytasklist[s] = awful.widget.tasklist(function(c)
                                              return awful.widget.tasklist.label.currenttags(c, s)
                                          end, mytasklist.buttons)

    mywibox[s] = awful.wibox({ position = "top", screen = s })
    mywibox[s].widgets = {
        {
            mylauncher,
            mytaglist[s],
            mypromptbox[s],
            layout = awful.widget.layout.horizontal.leftright
        },
        mylayoutbox[s],
        s == preferred_screen and obvious.clock() or nil,
        s == preferred_screen and mysystray or nil,
        (s == preferred_screen and has_battery()) and obvious.battery() or nil,
        s == preferred_screen and obvious.temp_info() or nil,
        s == preferred_screen and obvious.basic_mpd() or nil,
        mytasklist[s],
        layout = awful.widget.layout.horizontal.rightleft
    }
end
