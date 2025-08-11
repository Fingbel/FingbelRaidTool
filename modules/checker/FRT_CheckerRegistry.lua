-- FRT_CheckerRegistry.lua
-- Adapt FRT.Data.Buffs into runtime defs + icon lookup

FRT = FRT or {}
FRT.CheckerRegistry = FRT.CheckerRegistry or {}

do
  local D = FRT.Data or {}
  local defs = nil
  local byKey = {}
  local orderIndex = {}
  local spellIcons = {}

  local function buildOnce()
    if defs then return end
    defs = {}

    -- Build ordering index
    if D.BuffOrder then
      local i=1
      while i <= table.getn(D.BuffOrder) do
        orderIndex[ D.BuffOrder[i] ] = i
        i=i+1
      end
    end

    -- Gather keys (respect BuffOrder, then add the rest)
    local keys = {}
    if D.BuffOrder and table.getn(D.BuffOrder) > 0 then
      local i=1
      while i <= table.getn(D.BuffOrder) do
        table.insert(keys, D.BuffOrder[i]); i=i+1
      end
    end
    if D.Buffs then
      local k,_ ; for k,_ in pairs(D.Buffs) do
        local found=false; local j=1
        while j <= table.getn(keys) do if keys[j]==k then found=true; break end j=j+1 end
        if not found then table.insert(keys, k) end
      end
    end

    -- Build defs array
    local i=1
    while i <= table.getn(keys) do
      local k = keys[i]
      local b = D.Buffs and D.Buffs[k]
      if b then
        local needFn = FRT.DataNeed.Resolve(b.need or "always")
        local def = {
          key        = k,
          label      = b.label or k,
          providers  = b.providers or {},
          tex        = b.texSubstrings or {},
          headerIcon = b.headerIcon or "Interface\\Icons\\INV_Misc_QuestionMark",
          needFn     = needFn,
          ord        = orderIndex[k] or 999,
        }
        table.insert(defs, def)
        byKey[k] = def

        -- spell icons may live inline or in D.SpellIcons fallback
        spellIcons[k] = (b.spellIcons) or ((D.SpellIcons and D.SpellIcons[k]) or nil)
      end
      i=i+1
    end
  end

  function FRT.CheckerRegistry.GetBuffDefs()
    buildOnce()
    return defs
  end

  function FRT.CheckerRegistry.GetBuffDefByKey(key)
    buildOnce()
    return byKey[key]
  end

  function FRT.CheckerRegistry.GetSpellIcons(key)
    buildOnce()
    return spellIcons[key]
  end

  function FRT.CheckerRegistry.PlayerCanProvide(key)
    buildOnce()
    local def = byKey[key]
    if not def then return false end
    local cls = FRT.Class and FRT.Class.Self() or "UNKNOWN"
    return (def.providers and def.providers[cls] == true) and true or false
  end
end
