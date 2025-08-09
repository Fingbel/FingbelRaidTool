-- FRT_NoteParser.lua (Vanilla 1.12)
FRT = FRT or {}
FRT.Note = FRT.Note or {}
FRT.Note.Parser = FRT.Note.Parser or {}

do
  local Parser = FRT.Note.Parser

  -- Raid target texcoords on UI-RaidTargetingIcons
  local RT_TEXCOORD = {
    [1]={0.00,0.25,0.00,0.25}, [2]={0.25,0.50,0.00,0.25},
    [3]={0.50,0.75,0.00,0.25}, [4]={0.75,1.00,0.00,0.25},
    [5]={0.00,0.25,0.25,0.50}, [6]={0.25,0.50,0.25,0.50},
    [7]={0.50,0.75,0.25,0.50}, [8]={0.75,1.00,0.25,0.50},
  }
  local RT_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"

  local function hex2rgb(hex) -- "RRGGBB" -> 0..1
    if not hex or string.len(hex) ~= 6 then return nil end
    local r = tonumber(string.sub(hex,1,2),16) or 255
    local g = tonumber(string.sub(hex,3,4),16) or 255
    local b = tonumber(string.sub(hex,5,6),16) or 255
    return { r/255, g/255, b/255 }
  end

  local function pushText(tokens, text, color, font)
    if not text or text == "" then return end
    table.insert(tokens, { kind="text", value=text, color=color, font=font })
  end
  local function pushIcon(tokens, idx, w, h)
    local tc = RT_TEXCOORD[idx]
    if not tc then return end
    table.insert(tokens, { kind="icon", tex=RT_TEXTURE, tc=tc, w=w or 16, h=h or 16 })
  end
  local function pushLine(tokens)
    table.insert(tokens, { kind="linebreak" })
  end

  --- Parse a note string into renderable tokens
  -- Supported:
  --   - \n newlines
  --   - {rt1}..{rt8} raid target icons
  --   - [color=#RRGGBB] ... [/color]
  function Parser.Parse(text)
    local tokens = {}
    if type(text) ~= "string" or text == "" then
      return tokens
    end

    -- Normalise line endings
    text = string.gsub(text, "\r\n", "\n")
    text = string.gsub(text, "\r", "\n")

    local i, n = 1, string.len(text)
    local curColor = nil
    local curFont  = "GameFontHighlight" -- you can change this default if you want
    local buf = ""

    local function flushBuf()
      if buf ~= "" then
        pushText(tokens, buf, curColor, curFont)
        buf = ""
      end
    end

    while i <= n do
      local ch = string.sub(text, i, i)

      -- Newline
      if ch == "\n" then
        flushBuf()
        pushLine(tokens)
        i = i + 1

      -- Raid icon tag {rtN}
      elseif ch == "{" then
        -- Try to match {rtX}
        local a,b, num = string.find(text, "^%{rt([1-8])%}", i)
        if a then
          flushBuf()
          pushIcon(tokens, tonumber(num), 16, 16)
          i = b + 1
        else
          -- Not a recognized tag; treat '{' as literal
          buf = buf .. ch
          i = i + 1
        end

      -- Color open tag [color=#RRGGBB]
      elseif ch == "[" then
        -- Open
        local a,b, hex = string.find(text, "^%[color=#([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])%]", i)
        if a then
          flushBuf()
          curColor = hex2rgb(hex) or curColor
          i = b + 1
        else
          -- Close tag [/color]
          local ac, bc = string.find(text, "^%[/color%]", i)
          if ac then
            flushBuf()
            curColor = nil
            i = bc + 1
          else
            -- Unknown bracketed tag; treat '[' as literal
            buf = buf .. ch
            i = i + 1
          end
        end

      else
        -- Plain text
        buf = buf .. ch
        i = i + 1
      end
    end

    flushBuf()
    return tokens
  end
end
