local error        = error
local pcall        = pcall
local string_lower = string.lower

local client     = client
local fake_input = root.fake_input
local timer      = timer

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

local function insert_unicode_digraph(digraph)
  local c = client.focus

  if not c then
    return
  end

  local codepoint_chars = digraphs[digraph]

  if not codepoint_chars then
    return
  end

  if is_urxvt(c) then -- urxvt wants the codepoint typed in with Shift and Ctrl down
    with_keys_down('Shift_L', 'Control_R', function()
      for i = 1, #codepoint_chars do
        press_key(codepoint_chars[i])
      end
    end)
  elseif is_firefox(c) then
    -- Firefox just has to be different - it likes Shift+Ctrl+u, then release,
    -- then the codepoint, then Space/Return
    with_keys_down('Shift_L', 'Control_R', function()
      press_key 'u'
    end)

    for i = 1, #codepoint_chars do
      press_key(codepoint_chars[i])
    end

    -- Firefox needs us to lag by a bit (100ms seems to work)
    -- for the Return to flush the Unicode character
    local t = timer { timeout = 0.1 }
    t:connect_signal('timeout', function()
      t:stop()
      t = nil
      press_key 'Return'
    end)

    t:start()
  else -- GTK applications (which is what I'm assuming here) want Shift+Ctrl+u, then
       -- then the codepoint, then release
    with_keys_down('Shift_L', 'Control_R', function()
      press_key 'u'

      for i = 1, #codepoint_chars do
        press_key(codepoint_chars[i])
      end
    end)
  end
end

return insert_unicode_digraph
