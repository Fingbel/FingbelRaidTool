-- FRT_DataNeed.lua
-- Need predicates (reusable tokens)

FRT = FRT or {}
FRT.DataNeed = FRT.DataNeed or {}

do
  local NEED = {
    always = function(unit) return true end,
    mana   = function(unit) local pt = UnitPowerType and UnitPowerType(unit) or 0; return (pt == 0) end,
  }

  -- Merge user-provided tokens from FRT.Data.NeedTokens, if any
  local D = FRT.Data or {}
  if D.NeedTokens then
    local k, fn
    for k,fn in pairs(D.NeedTokens) do
      if type(k) == "string" and type(fn) == "function" then NEED[k] = fn end
    end
  end

  function FRT.DataNeed.Resolve(name)
    if type(name) == "function" then return name end
    return NEED[name or "always"] or NEED.always
  end
end
