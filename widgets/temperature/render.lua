local function render(r, temp)
  local color = 'red'
  if temp < 50 then
    color = 'green'
  elseif temp >= 50 and temp < 60 then
    color = 'yellow'
  end

  r:printf('%.2f ', temp)
  r:push_fg_color(color)
  r:print 'C'
  r:pop_fg_color()
end

return render
