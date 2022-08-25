local floor   = math.floor
local sformat = string.format
local tconcat = table.concat

local STATUS_TEXT = {
  charged           = '↯',
  full              = '↯',
  high              = '↯',

  discharging       = '▼',
  ['not connected'] = '▼',

  charging          = '▲',

  unknown           = '⌁',
  ['not charging']  = '⌁',
}

local escape
local has_awful_util, awful_util = pcall(require, 'awful.util')
if has_awful_util then
  escape = awful_util.escape
else
  escape = function(s) return s end
end

local function colorize(color, text)
  return sformat('<span foreground="%s">%s</span>', color, text)
end

-- XXX add blinking

local function render(batteries)
  local markup = {}

  local all_status = 'charged'
  local eta
  local total_charge = 0

  for i = 1, #batteries do
    local battery = batteries[i]
    local charge = battery.charge or 0
    local status = battery.status
    local time = battery.time

    if status == 'charging' then
      all_status = 'charging'
    elseif status == 'discharging' then
      all_status = 'discharging'
    end

    if time then
      -- XXX extrapolate total time?
      eta = time
    end

    total_charge = total_charge + (charge / #batteries)
  end

  local color
  if total_charge >= 60 then
    color = 'green'
  elseif total_charge >= 35 then
    color = 'yellow'
  else
    color = 'red'
  end

  local markup = {}
  markup[#markup + 1] = colorize(color, escape(STATUS_TEXT[all_status] or STATUS_TEXT.unknown))

  if eta then
      local hours   = floor(eta / 60)
      local minutes = eta % 60

      markup[#markup + 1] = escape(sformat('%02d:%02d', hours, minutes))
  end

  for i = 1, #batteries do
    local battery = batteries[i]
    local charge = battery.charge or 0

    markup[#markup + 1] = escape(sformat('%d%%', charge))
  end

  return tconcat(markup, ' ')
end

return render
