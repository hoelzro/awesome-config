-- generated via some magic and Vim's :digraphs command
-- vim -c 'redir! > $HOME/.config/awesome/digraphs.json | silent echo json_encode(digraph_getlist(1)) | redir END | exit'

local json = require 'dkjson'

local f, err = io.open('/home/rob/.config/awesome/digraphs.json', 'r')
if err then
  alert('unable to load digraphs: ' .. tostring(err))
  return {}
end

local digraph_list, _, err = json.decode(f:read '*a')
f:close()

if err then
  alert('unable to load digraphs: ' .. tostring(err))
  return {}
end

local digraph_lookup = {}

for i = 1, #digraph_list do
  local digraph, char_to_insert = table.unpack(digraph_list[i])
  digraph_lookup[digraph] = char_to_insert
end

return digraph_lookup
