-- FRT_CheckerScan.lua
-- Turn (roster + columns) into results[name] = {present, missing}

FRT = FRT or {}
FRT.CheckerScan = FRT.CheckerScan or {}

do
  function FRT.CheckerScan.Run(roster, columns)
    local results = {}
    local i=1
    while i <= table.getn(roster or {}) do
      local e = roster[i]
      local seen = FRT.Auras.Collect(e.unit)
      local present, missing = {}, {}
      local c=1
      while c <= table.getn(columns or {}) do
        local key = columns[c].key
        local def = FRT.CheckerRegistry.GetBuffDefByKey(key)
        if def and def.needFn(e.unit) then
          local ok = false
          local _, path = FRT.Auras.Match(seen, def.tex)
          if path then ok = true end
          if ok then present[key] = path else table.insert(missing, key) end
        else
          present[key] = "__NA__"
        end
        c=c+1
      end
      results[e.name] = { present=present, missing=missing }
      i=i+1
    end
    return results
  end
end
