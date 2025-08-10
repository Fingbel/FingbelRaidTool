-- Fingbel Raid Tool - Parser

FRT = FRT or {}
FRT.Note = FRT.Note or {}
FRT.Note.Parser = FRT.Note.Parser or {}

do
  local Parser = FRT.Note.Parser

  -- Raid targets
  local RT_TEXCOORD = {
    [1]={0.00,0.25,0.00,0.25}, [2]={0.25,0.50,0.00,0.25},
    [3]={0.50,0.75,0.00,0.25}, [4]={0.75,1.00,0.00,0.25},
    [5]={0.00,0.25,0.25,0.50}, [6]={0.25,0.50,0.25,0.50},
    [7]={0.50,0.75,0.25,0.50}, [8]={0.75,1.00,0.25,0.50},
  }
  local RT_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"

  -- Class icons (character creation sheet)
  local CLASS_TEX = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
  local CLASS_TEXCOORD = {
    WARRIOR = {0.00,0.25,0.00,0.25},
    MAGE    = {0.25,0.50,0.00,0.25},
    ROGUE   = {0.50,0.75,0.00,0.25},
    DRUID   = {0.75,1.00,0.00,0.25},

    HUNTER  = {0.00,0.25,0.25,0.50},
    SHAMAN  = {0.25,0.50,0.25,0.50},
    PRIEST  = {0.50,0.75,0.25,0.50},
    WARLOCK = {0.75,1.00,0.25,0.50},

    PALADIN = {0.00,0.25,0.50,0.75},
  }

  -- Class colors (hex)
  local CLASS_HEX = {
    WARRIOR = "C79C6E", MAGE = "69CCF0", ROGUE = "FFF569",
    DRUID   = "FF7D0A", HUNTER = "ABD473", SHAMAN = "0070DE",
    PRIEST  = "FFFFFF", WARLOCK = "9482C9", PALADIN = "F58CBA",
  }

  -- helpers
  local function hex2rgb(hex)
    if not hex or string.len(hex) ~= 6 then return nil end
    local r = tonumber(string.sub(hex,1,2),16) or 255
    local g = tonumber(string.sub(hex,3,4),16) or 255
    local b = tonumber(string.sub(hex,5,6),16) or 255
    return { r/255, g/255, b/255 }
  end

  local function pushText(tokens, text, color, font)
    if not text or text == "" then return end
    local n = table.getn(tokens)
    if n > 0 then
      local prev = tokens[n]
      if prev and prev.kind == "text" then
        local sameFont  = (prev.font  == (font  or prev.font))
        local pc, nc    = prev.color, color
        local sameColor = ((not pc and not nc) or (pc and nc and pc[1]==nc[1] and pc[2]==nc[2] and pc[3]==nc[3]))
        if sameFont and sameColor then
          prev.value = (prev.value or "") .. text
          return
        end
      end
    end
    table.insert(tokens, { kind="text", value=text, color=color, font=font })
  end

  local function pushIcon(tokens, tex, tc, w, h)
    if not tc then return end
    table.insert(tokens, { kind="icon", tex=tex, tc=tc, w=w or 14, h=h or 14 })
  end

  local function pushLine(tokens)
    table.insert(tokens, { kind="linebreak" })
  end

  -- Parse supports:
  --  \n
  --  {rt1}..{rt8}
  --  [color=#RRGGBB] ... [/color]
  --  {ClassName}                    -> class icon
  --  [ClassName] ... [/ClassName]   -> class color span
  function Parser.Parse(text)
    local tokens = {}
    if type(text) ~= "string" or text == "" then return tokens end

    -- normalize newlines
    text = string.gsub(text, "\r\n", "\n")
    text = string.gsub(text, "\r", "\n")

    local i, n = 1, string.len(text)
    local curColor = nil
    local curFont  = "GameFontHighlight"
    local buf = ""

    local function flushBuf()
      if buf ~= "" then pushText(tokens, buf, curColor, curFont); buf = "" end
    end

    while i <= n do
      local ch = string.sub(text, i, i)

      -- newline
      if ch == "\n" then
        flushBuf(); pushLine(tokens); i = i + 1

      -- braces: {rtN} or {Class}
      elseif ch == "{" then
        -- {rtN}
        local a,b,num = string.find(text, "^%{rt([1-8])%}", i)
        if a then
          flushBuf(); pushIcon(tokens, RT_TEXTURE, RT_TEXCOORD[tonumber(num)], 14, 14); i = b + 1
        else
          -- {ClassName}
          local ac, bc, cname = string.find(text, "^%{([%a]+)%}", i)
          if ac then
            local up = string.upper(cname or "")
            if CLASS_TEXCOORD[up] then
              flushBuf(); pushIcon(tokens, CLASS_TEX, CLASS_TEXCOORD[up], 14, 14); i = bc + 1
            else
              -- unknown tag -> literal
              buf = buf .. "{"; i = i + 1
            end
          else
            buf = buf .. "{"; i = i + 1
          end
        end

      -- brackets: [color=#RRGGBB], [/color], [Class], [/Class]
      elseif ch == "[" then
        -- [color=#RRGGBB]
        local a,b,hex = string.find(text, "^%[color=#([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])%]", i)
        if a then
          flushBuf(); curColor = hex2rgb(hex) or curColor; i = b + 1
        else
          -- [/color]
          local ac,bc = string.find(text, "^%[/color%]", i)
          if ac then
            flushBuf(); curColor = nil; i = bc + 1
          else
            -- [ClassName]
            local ak,bk,cname = string.find(text, "^%[([%a]+)%]", i)
            if ak then
              local up = string.upper(cname or "")
              if CLASS_HEX[up] then
                flushBuf(); curColor = hex2rgb(CLASS_HEX[up]); i = bk + 1
              else
                buf = buf .. "["; i = i + 1
              end
            else
              -- [/ClassName]
              local a2,b2,cend = string.find(text, "^%[/([%a]+)%]", i)
              if a2 then
                local up2 = string.upper(cend or "")
                if CLASS_HEX[up2] then
                  flushBuf(); curColor = nil; i = b2 + 1
                else
                  buf = buf .. "["; i = i + 1
                end
              else
                buf = buf .. "["; i = i + 1
              end
            end
          end
        end

      else
        -- plain text
        buf = buf .. ch; i = i + 1
      end
    end

    flushBuf()
    return tokens
  end
end
