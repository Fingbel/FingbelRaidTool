-- FRT_Auras.lua
-- Aura helpers (Vanilla API)

FRT = FRT or {}
FRT.Auras = FRT.Auras or {}

do
  local MAX_BUFFS = 16

  function FRT.Auras.Collect(unit)
    local seen, i = {}, 1
    while i <= MAX_BUFFS do
      local tex = UnitBuff(unit, i)
      if not tex then break end
      seen[tex] = true
      i=i+1
    end
    return seen
  end

  function FRT.Auras.Match(seen, substrings)
    if not seen or not substrings then return false, nil end
    local path, _ = nil, nil
    for path,_ in pairs(seen) do
      local j=1
      while j <= table.getn(substrings) do
        if string.find(path, substrings[j], 1, true) then
          return true, path
        end
        j=j+1
      end
    end
    return false, nil
  end
end
