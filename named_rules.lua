local builder_methods = {}

function builder_methods:build()
  local rules = {}
  local metadata = {}

  for k, v in pairs(self) do
    if type(k) == 'table' then
      metadata[k] = { name = v }
    else
      rules[k] = v
    end
  end

  return rules, metadata
end

local builder_mt = {__index = builder_methods}

function builder_mt:__newindex(rule_name, rule)
  -- XXX duplicate entries for a given name is a no-no
  rawset(self, rule, rule_name) -- XXX dunno if stashing the reverse lookup in self is the right thing, but it'll do for now
  rawset(self, #self + 1, rule)
end

local function builder()
  return setmetatable({}, builder_mt)
end

return builder
