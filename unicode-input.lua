local error        = error
local pcall        = pcall
local string_lower = string.lower

local client      = client
local gears_timer = require 'gears.timer'
local fake_input  = root.fake_input
local timer       = timer

local digraphs = require 'digraphs'

local function is_urxvt(c)
  return string_lower(c.class or '') == 'urxvt'
end

local function is_firefox(c)
  return string_lower(c.class or '') == 'firefox'
end

local function with_keys_down(...)
  local keys           = { ... }
  local action         = keys[#keys]
  keys[#keys]          = nil
  local ok, err        = true
  local last_key_index = 0

  for i = 1, #keys do
    ok, err = pcall(fake_input, 'key_press', keys[i])
    if not ok then
      break
    end
    last_key_index = i
  end

  if ok then
    ok, err = pcall(action)
  end

  for i = last_key_index, 1, -1 do
    pcall(fake_input, 'key_release', keys[i])
  end

  if not ok then
    error(err)
  end
end

local function press_key(key)
  fake_input('key_press', key)
  fake_input('key_release', key)
end

local function insert_unicode_character(c)
  local client = client.focus

  if not client then
    return
  end

  local codepoint = utf8.codepoint(c)
  local codepoint_chars = {}

  for ch in string.gmatch(string.format('%x', codepoint), '.') do
    codepoint_chars[#codepoint_chars + 1] = ch
  end

  gears_timer {
    timeout     = 0.1,
    autostart   = true,
    single_shot = true,
    callback    = function()
      if is_urxvt(client) then -- urxvt wants the codepoint typed in with Shift and Ctrl down
        with_keys_down('Shift_L', 'Control_R', function()
          for i = 1, #codepoint_chars do
            press_key(codepoint_chars[i])
          end
        end)
      else -- GTK applications (which is what I'm assuming here) want Shift+Ctrl+u, then
           -- then the codepoint, then release
        with_keys_down('Shift_L', 'Control_R', function()
          press_key 'u'

          for i = 1, #codepoint_chars do
            press_key(codepoint_chars[i])
          end
        end)
      end
    end,
  }
end

local function insert_unicode_digraph(digraph)
  if not digraphs[digraph] then
    return
  end

  insert_unicode_character(digraphs[digraph])
end

return {
  insert_unicode_digraph = insert_unicode_digraph,
  insert_unicode_character = insert_unicode_character,
}
