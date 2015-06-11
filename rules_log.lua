local rules = require 'awful.rules'
local pprint = require 'pretty'.dump
local format = string.format
local tostring = tostring
local oldmatch    = rules.match

rules.match = function(c, rule)
  local matches = oldmatch(c, rule)

  print(format('Matching rule %s for client %s: %s', pprint(rule), tostring(c.name), matches and 'true' or 'false'))

  return matches
end
