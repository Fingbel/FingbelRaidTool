-- FRT_Spellbook.lua
-- Locale-proof spellbook search by icon substring (+ optional name fallback)

FRT = FRT or {}
FRT.Spellbook = FRT.Spellbook or {}

do
  local BOOKTYPE_SPELL = BOOKTYPE_SPELL or "spell"

  -- Existing (kept): returns highest-rank match by icon substring(s)
  function FRT.Spellbook.FindByIcons(substrList)
    if not substrList then return nil end
    local tabs = GetNumSpellTabs and GetNumSpellTabs() or 0
    local best, t = nil, 1
    while t <= tabs do
      local _, _, offset, numSpells = GetSpellTabInfo(t)
      offset = offset or 0 ; numSpells = numSpells or 0
      local i=1
      while i <= numSpells do
        local idx = offset + i
        local tex = GetSpellTexture and GetSpellTexture(idx, BOOKTYPE_SPELL) or nil
        if tex then
          local s=1
          while s <= table.getn(substrList) do
            if string.find(tex, substrList[s], 1, true) then best = idx end
            s=s+1
          end
        end
        i=i+1
      end
      t=t+1
    end
    return best
  end

  -- NEW: find highest-rank by localized name substring(s)
  function FRT.Spellbook.FindByNames(nameSubstrList)
    if not nameSubstrList then return nil end
    local tabs = GetNumSpellTabs and GetNumSpellTabs() or 0
    local best, t = nil, 1
    while t <= tabs do
      local _, _, offset, numSpells = GetSpellTabInfo(t)
      offset = offset or 0 ; numSpells = numSpells or 0
      local i=1
      while i <= numSpells do
        local idx  = offset + i
        local name = GetSpellName and GetSpellName(idx, BOOKTYPE_SPELL) or nil
        if name then
          local s=1
          while s <= table.getn(nameSubstrList) do
            if string.find(name, nameSubstrList[s], 1, true) then best = idx end
            s=s+1
          end
        end
        i=i+1
      end
      t=t+1
    end
    return best
  end

  -- NEW: resolve by icons first; if provided, verify/override by names
  -- If icons resolve to an index but its name doesn't contain any of nameSubstrList,
  -- try a pure name lookup to disambiguate (e.g., Gift vs Mark with same icon).
  function FRT.Spellbook.Resolve(iconSubstrList, nameSubstrList)
    local idx = FRT.Spellbook.FindByIcons(iconSubstrList)
    if nameSubstrList and idx then
      local nm = GetSpellName and GetSpellName(idx, BOOKTYPE_SPELL) or ""
      local ok = false
      local s=1
      while s <= table.getn(nameSubstrList) do
        if string.find(nm or "", nameSubstrList[s], 1, true) then ok = true; break end
        s=s+1
      end
      if not ok then
        local byName = FRT.Spellbook.FindByNames(nameSubstrList)
        if byName then idx = byName end
      end
    elseif (not idx) and nameSubstrList then
      idx = FRT.Spellbook.FindByNames(nameSubstrList)
    end
    return idx
  end
end
