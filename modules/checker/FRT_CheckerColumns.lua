-- FRT_CheckerColumns.lua
-- Decide which buff columns to show, and in what order

FRT = FRT or {}
FRT.CheckerColumns = FRT.CheckerColumns or {}

do
  local function detectProviders(roster)
    local p = {}
    local i=1
    while i <= table.getn(roster) do
      p[ roster[i].class or "" ] = true
      i=i+1
    end
    return p
  end

  function FRT.CheckerColumns.Build(roster)
    local defs = FRT.CheckerRegistry.GetBuffDefs() or {}
    local providers = detectProviders(roster or {})
    local selfClass = (FRT.Class and FRT.Class.Self()) or "UNKNOWN"

    local cols = {}
    local i=1
    while i <= table.getn(defs) do
      local d = defs[i]
      -- Show column only if a provider of that buff is present in the group
      local needed, cls = false, nil
      for cls in pairs(d.providers or {}) do
        if providers[cls] then needed = true; break end
      end
      if needed then
        table.insert(cols, { key=d.key, label=d.label, icon=d.headerIcon, canSelf=(d.providers and d.providers[selfClass] == true), ord=d.ord or 999 })
      end
      i=i+1
    end

    table.sort(cols, function(a,b)
      local wa = a.canSelf and 0 or 1
      local wb = b.canSelf and 0 or 1
      if wa ~= wb then return wa < wb end
      return (a.ord or 999) < (b.ord or 999)
    end)

    -- Strip helpers
    local out, j = {}, 1
    while j <= table.getn(cols) do
      local c = cols[j]
      out[j] = { key=c.key, label=c.label, icon=c.icon }
      j=j+1
    end
    return out
  end
end
