-- Fingbel Raid Tool - Parser
-- FRT_NoteParser.lua --

FRT = FRT or {}
FRT.Note = FRT.Note or {}
FRT.Note.Parser = FRT.Note.Parser or {}

local Role = (FRT.Role or {})
local D    = FRT.Data or {}

-- ========== string helpers ==========
local function trim(s)  return (string.gsub(tostring(s or ""), "^%s*(.-)%s*$", "%1")) end
local function upper(s) return string.upper(tostring(s or "")) end
local function titleCase(s)
  s = tostring(s or ""); s = string.lower(s)
  return (string.gsub(s, "^%l", string.upper))
end

-- ========== placeholder token helpers ==========
local function baseToken(raw)
  local up = upper(raw or "")
  up = string.gsub(up, "%d+$", "")   -- strip trailing digits
  up = string.gsub(up, "_+$", "")    -- strip trailing underscores
  return up
end
local function tokenSuffix(raw)
  return string.match(tostring(raw or ""), "(%d+)$")
end

-- ========== active-role keys for section gating ==========
local function getActiveKeys()
  local role   = (Role.GetRole   and Role.GetRole())   or ""
  local kind   = (Role.GetKind   and Role.GetKind())   or ""
  local school = (Role.GetSchool and Role.GetSchool()) or ""
  local _, classToken = UnitClass("player"); classToken = classToken or ""

  local up = string.upper
  local set = {}
  set[up(role)]       = true
  set[up(kind)]       = true
  set[up(school)]     = true
  set[up(classToken)] = true

  if up(kind) == "RDPS" then set.RANGED = true end
  if up(kind) == "MDPS" then set.MELEE  = true end
  return set
end

local function normalizeSectionKey(raw)
  local key = upper(trim(raw or ""))
  local aliases = D.SectionAliases or {}
  if aliases[key] then key = aliases[key] end
  return key
end

local function normalizeHex(h)
  if not h then return nil end
  if string.len(h) == 3 then
    local r,g,b = string.sub(h,1,1), string.sub(h,2,2), string.sub(h,3,3)
    return r..r..g..g..b..b
  end
  return h
end

do
  local Parser = FRT.Note.Parser

  -- static data
  local RT_TEXTURE       = D.RaidTargets and D.RaidTargets.TEXTURE or "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
  local RT_TEXCOORD      = D.RaidTargets and D.RaidTargets.COORDS   or {}
  local CLASS_TEX        = D.ClassIcons and D.ClassIcons.TEXTURE    or "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
  local CLASS_TEXCOORD   = D.ClassIcons and D.ClassIcons.COORDS     or {}
  local CLASS_HEX        = D.ClassColorsHex or {}
  local ROLE_HEX         = D.RoleColorsHex or {}
  local PH_NEUTRAL_HEX   = D.PlaceholderNeutralHex or "FFD100"

  local SECTIONS         = D.Sections or {}
  local SECTION_COLORS   = D.SectionColorsHex or {}

  local function hex2rgb(hex)
    return (D.HexToRGB and D.HexToRGB(hex)) or {1,1,1}
  end

  -- emitters
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

  local function pushLine(tokens) table.insert(tokens, { kind="linebreak" }) end

  local function ensureLineBreak(tokens)
    local n = table.getn(tokens)
    if n == 0 then return end
    local last = tokens[n]
    if last and last.kind ~= "linebreak" then pushLine(tokens) end
  end

  -- colors
  local function colorForPlaceholderToken(raw)
    local baseUP = baseToken(raw)
    local canon  = (D.RoleSynonyms and D.RoleSynonyms[baseUP]) or baseUP
    if CLASS_HEX[canon] then return hex2rgb(CLASS_HEX[canon]) end
    if ROLE_HEX[canon]  then return hex2rgb(ROLE_HEX[canon])  end
    if ROLE_HEX[baseUP] then return hex2rgb(ROLE_HEX[baseUP]) end
    return hex2rgb(PH_NEUTRAL_HEX)
  end

  local function sectionColor(keyUP)
    if CLASS_HEX[keyUP]      then return hex2rgb(CLASS_HEX[keyUP]) end
    if SECTION_COLORS[keyUP] then return hex2rgb(SECTION_COLORS[keyUP]) end
    if ROLE_HEX[keyUP]       then return hex2rgb(ROLE_HEX[keyUP]) end
    return hex2rgb(PH_NEUTRAL_HEX)
  end

  private_sectionLabel = nil
  local function sectionLabel(keyUP)
    if SECTIONS[keyUP] and SECTIONS[keyUP].label then return SECTIONS[keyUP].label end
    if CLASS_HEX[keyUP] then return titleCase(keyUP) end
    return keyUP
  end

  local function pushSectionSeparator(tokens, keyUP, curFont)
    local label = sectionLabel(keyUP)
    local color = sectionColor(keyUP)
    local line  = string.rep("-", 13) .. label .. string.rep("-", 13)
    ensureLineBreak(tokens)
    pushText(tokens, line, color, curFont)
    pushLine(tokens)
  end

  -- parser
  function Parser.Parse(text)
    local tokens = {}
    if type(text) ~= "string" or text == "" then return tokens end

    text = string.gsub(text, "\r\n", "\n")
    text = string.gsub(text, "\r", "\n")

    local showAll = (FRT_Saved and FRT_Saved.ui and FRT_Saved.ui.viewer and FRT_Saved.ui.viewer.showAll) or false
    local active       = getActiveKeys()
    local blockVisible = true

    local i, n = 1, string.len(text)
    local curColor     = nil      -- span color ([color]...[/color] or [Class]...[/Class])
    local oneShotColor = nil      -- next-word-only color when no closing [/color] exists
    local curFont      = "GameFontHighlight"
    local buf          = ""

    local function emitIcon(tex,tc,w,h) if blockVisible then pushIcon(tokens, tex, tc, w, h) end end
    local function emitLine()           if blockVisible then pushLine(tokens) end end

    local function emitText(s)
      if not blockVisible or s == "" then return end

      -- one-shot: color only the next word, *then* re-inject the rest back into buf
      if oneShotColor and not curColor then
        local lead, word, tail = string.match(s, "^(%s*)(%S+)(.*)$")
        if word and word ~= "" then
          if lead and lead ~= "" then pushText(tokens, lead, nil, curFont) end
          pushText(tokens, word, oneShotColor, curFont)
          oneShotColor = nil
          -- IMPORTANT: do NOT emit 'tail' as plain text; put it back to be parsed normally
          buf = (tail or "")
          return
        else
          -- still only whitespace; keep waiting for the next non-space
          pushText(tokens, s, nil, curFont)
          return
        end
      end

      -- normal text (honor active span color)
      pushText(tokens, s, curColor, curFont)
    end

    local function flushBuf()
      -- Keep flushing until emitText stops leaving leftovers in `buf`
      while buf ~= "" do
        local before = buf
        emitText(buf)     -- may color just the next word and put the "tail" back into buf
        if buf == before then
          -- safety: if nothing changed (shouldn’t happen), break to avoid an infinite loop
          buf = ""
        end
      end
    end

    while i <= n do
      local ch = string.sub(text, i, i)

      if ch == "\n" then
        flushBuf(); emitLine(); i = i + 1

      elseif ch == "{" then
        -- raid target {rtN} or placeholders {TOKEN}
        local a,b,num = string.find(text, "^%{rt([1-8])%}", i)
        if a then
          flushBuf(); emitIcon(RT_TEXTURE, RT_TEXCOORD[tonumber(num)], 14, 14); i = b + 1
        else
          local ac, bc, raw = string.find(text, "^%{([%w_]+)%}", i)
          if ac then
            local upraw  = upper(raw or "")
            local base   = baseToken(upraw)
            local suffix = tokenSuffix(raw)

            if upraw == "ROLE" or upraw == "KIND" or upraw == "SCHOOL" or upraw == "CLASS" then
              local val = raw
              if upraw == "ROLE"   and Role.GetRole   then val = Role.GetRole()   end
              if upraw == "KIND"   and Role.GetKind   then val = Role.GetKind()   end
              if upraw == "SCHOOL" and Role.GetSchool then val = Role.GetSchool() end
              if upraw == "CLASS"  then local _, c = UnitClass("player"); val = c or "?" end
              flushBuf()
              if blockVisible then pushText(tokens, val, colorForPlaceholderToken(val), curFont) end
              i = bc + 1

            elseif CLASS_TEXCOORD[base] then
              flushBuf()
              if blockVisible then
                if suffix then
                  pushText(tokens, raw, colorForPlaceholderToken(raw), curFont) -- {SHAMAN1} → colored text
                else
                  emitIcon(CLASS_TEX, CLASS_TEXCOORD[base], 14, 14)             -- {SHAMAN}  → icon
                end
              end
              i = bc + 1

            else
              flushBuf()
              if blockVisible then pushText(tokens, raw, colorForPlaceholderToken(raw), curFont) end
              i = bc + 1
            end
          else
            buf = buf .. "{"; i = i + 1
          end
        end
      elseif ch == "[" then
        -- [Section=...]
        local sa, sb, stag, sval = string.find(text, "^%[([A-Za-z]+)%s*=%s*([^%]]+)%]", i)
          if sa and upper(stag) == "SECTION" then
            local key = normalizeSectionKey(sval)
          if SECTIONS[key] or D.ClassColorsHex[key] or active[key] then
            blockVisible = showAll or (active[key] == true)
          end
          flushBuf()
          if blockVisible then pushSectionSeparator(tokens, key, curFont) end
          i = sb + 1

        else
          -- [color=RRGGBB] or [c=RRGGBB]  (one-shot if no matching closer exists later)
          local a,b,tag,hex = string.find(
            text,
            "^%[([A-Za-z]+)%s*=%s*([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]?[0-9a-fA-F]?[0-9a-fA-F]?)%]",
            i
          )
          hex = normalizeHex(hex)
          local isColorOpen = a and ((tag == "color") or (tag == "c"))
          if isColorOpen then
            flushBuf()
            local closer = "%[/" .. tag .. "%]"
            local closePos = string.find(text, closer, b + 1)
            if closePos then
              -- span mode until matching closer
              curColor = hex2rgb(hex) or curColor
              i = b + 1
            else
              -- ONE-SHOT: color the next word only; do not consume a following '['
              local j = b + 1
              local wsA, wsB = string.find(text, "^[ \t]+", j)
              if wsA then
                if blockVisible then pushText(tokens, string.sub(text, wsA, wsB), curColor, curFont) end
                j = wsB + 1
              end
              if j <= n then
                local rest = string.sub(text, j)
                local word = string.match(rest, "^([%w_]+)")
                if word and word ~= "" then
                  if blockVisible then pushText(tokens, word, hex2rgb(hex), curFont) end
                  i = j + string.len(word)
                else
                  -- next token isn't a word (e.g. '[' while typing) → don't eat it
                  i = b + 1
                end
              else
                i = b + 1
              end
            end

          else
            -- [/color] or [/c]
            local ac,bc,ctag = string.find(text, "^%[/([A-Za-z]+)%]", i)
            local isColorClose = ac and ((ctag == "color") or (ctag == "c"))
            if isColorClose then
              flushBuf(); curColor = nil; i = bc + 1

            else
              -- [Class] ... [/Class] spans (unchanged)
              local ak,bk,cname = string.find(text, "^%[([%a]+)%]", i)
              if ak and D.ClassColorsHex[upper(cname or "")] then
                flushBuf(); curColor = hex2rgb(D.ClassColorsHex[upper(cname)]); i = bk + 1

              else
                local a2,b2,cend = string.find(text, "^%[/([%a]+)%]", i)
                if a2 and D.ClassColorsHex[upper(cend or "")] then
                  flushBuf(); curColor = nil; i = b2 + 1

                else
                  -- FALLBACK: treat '[' as literal so typing doesn't freeze the UI
                  buf = buf .. "["
                  i = i + 1
                end
              end
            end
          end
        end

      else
        buf = buf .. ch; i = i + 1
      end
    end

    flushBuf()
    return tokens
  end
end