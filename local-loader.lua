local loaders    = package.loaders
local fileloader = loaders[2]

local function localloader(filename)
  local regularfile = fileloader(filename)
  if type(regularfile) == 'string' then
    return ''
  end

  local localfile = fileloader('local.' .. filename)

  if type(localfile) == 'string' then
    return regularfile
  else
    return function(...)
      local retval = regularfile(...)
      localfile(...)
      return retval
    end
  end
end

table.insert(loaders, 2, localloader)
