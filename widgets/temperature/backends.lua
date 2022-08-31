local backends = {}

-- {{{ Filesystem Backend
local fs_backend = {}
backends.filesystem = fs_backend

function fs_backend:new(options) -- {{{
  assert(options.target)

  return setmetatable({
    target = options.target,
  }, {__index = fs_backend})
end -- }}}

function fs_backend:state() -- {{{
   local f, err = io.open(self.target, 'r')
   if not f then
     return nil, err
   end

   local line, err = f:read '*l'
   f:close()

   if not line then
     return nil, err
   end

   local temp, err = tonumber(line)
   if not temp then
     return nil, 'unable to convert temperature to number'
   end

   return temp / 1000
end -- }}}

--}}}

return backends
