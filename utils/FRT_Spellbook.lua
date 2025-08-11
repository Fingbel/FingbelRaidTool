-- FRT_Spellbook.lua
-- Locale-proof spellbook search by icon substring

FRT = FRT or {}
FRT.Spellbook = FRT.Spellbook or {}

do
  local BOOKTYPE_SPELL = BOOKTYPE_SPELL or "spell"

  function FRT.Spellbook.FindByIcons(substrList)
    if not substrList then return nil end
    local tabs = GetNumSpellTabs and GetNumSpellTabs() or 0
    local best, t = nil, 1
    while t <= tabs do
      local tabName, tabTex, offset, numSpells = GetSpellTabInfo(t)
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
end
