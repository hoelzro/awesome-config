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

  local total_power_now   = 0 -- μw
  local total_energy_now  = 0 -- μw/h
  local total_energy_full = 0 -- μw/h

  for i = 1, #batteries do
    local battery = batteries[i]
    local status = string.lower(battery.status)

    if status == 'charging' then
      all_status = 'charging'
    elseif status == 'discharging' then
      all_status = 'discharging'
    end
    -- XXX other statuses?

    total_power_now   = total_power_now   + battery.power_now
    total_energy_now  = total_energy_now  + battery.energy_now
    total_energy_full = total_energy_full + battery.energy_full
  end

  local total_eta -- minutes
  if total_power_now ~= 0 then
    local battery_time_hours

    if all_status == 'charging' then
      battery_time_hours = (total_energy_full - total_energy_now) / total_power_now
    else
      battery_time_hours = total_energy_now / total_power_now
    end

    total_eta = floor(battery_time_hours * 60)
  end

  local total_charge = total_energy_now / total_energy_full

  local color
  if total_charge >= 0.6 then
    color = 'green'
  elseif total_charge >= 0.35 then
    color = 'yellow'
  else
    color = 'red'
  end

  local should_blink = total_eta and total_eta < 30 and all_status == 'discharging'
  if should_blink then
    renderer:push_blink()
  end

  renderer:push_fg_color(color)
  renderer:print(STATUS_TEXT[all_status] or STATUS_TEXT.unknown)
  renderer:pop_fg_color()

  if total_eta then
      local hours   = floor(total_eta / 60)
      local minutes = total_eta % 60

      renderer:printf(' %02d:%02d', hours, minutes)
  end

  for i = 1, #batteries do
    local battery = batteries[i]
    local charge = battery.energy_now / battery.energy_full

    renderer:printf(' %d%%', floor(charge * 100))
  end

  if should_blink then
    renderer:pop_blink()
  end
end

return render
