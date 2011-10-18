--[[
- Expose?
- Key chords
- List keybindings?
]]

modkey           = "Mod1"
terminal         = "xterm"
editor           = os.getenv("EDITOR") or "vim"
editor_cmd       = terminal .. " -e " .. editor
preferred_screen = screen.count()

require 'local-loader'

require 'awful.autofocus'
require 'naughty'

require 'startup-programs'
require 'theme'
require 'tags'
require 'widgets'
require 'mousebindings'
require 'keybindings'
require 'clientrules'
