local wibox = require 'wibox'

local utils = {}

utils.font = 'Monospace 14'

function utils.textbox(opts)
  opts.widget = wibox.widget.textbox
  opts.font = opts.font or utils.font

  return opts
end

return utils
