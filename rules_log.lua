local pprint = require 'pretty'.print
local format = string.format
local tostring = tostring
local oldmatch    = awful.rules.match

awful.rules.match = function(c, rule)
  local matches = oldmatch(c, rule)

  print(format('Matching rule %s for client %s: %s', pprint(rule), tostring(c.name), matches and 'true' or 'false'))

  return matches
end
