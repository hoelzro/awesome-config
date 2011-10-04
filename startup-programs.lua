local programs = {
 'xset b off',
 'xmodmap ~/.xmodmap',
 'xrdb -load ~/.Xdefaults',
}

for _, cmd in ipairs(programs) do
  os.execute(cmd .. ' &')
end
