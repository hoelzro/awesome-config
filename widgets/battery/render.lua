local floor = math.floor

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

local function render(renderer, batteries)
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

  local should_blink = eta and eta < 30
  if should_blink then
    renderer:push_blink()
  end

  renderer:push_fg_color(color)
  renderer:print(STATUS_TEXT[all_status] or STATUS_TEXT.unknown)
  renderer:pop_fg_color()

  if eta then
      local hours   = floor(eta / 60)
      local minutes = eta % 60

      renderer:printf(' %02d:%02d', hours, minutes)
  end

  for i = 1, #batteries do
    local battery = batteries[i]
    local charge = battery.charge or 0

    renderer:printf(' %d%%', charge)
  end

  if should_blink then
    renderer:pop_blink()
  end
end

return render
