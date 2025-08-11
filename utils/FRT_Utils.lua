-- FRT_Utils.lua
-- Small shared helpers used across modules (Vanilla/Turtle, Lua 5.0)

FRT = FRT or {}

-- Sorted iteration for stable prints/debug (not performance-critical)
function FRT.SortedKeys(t)
  local keys, k = {}, nil
  for k in pairs(t or {}) do table.insert(keys, k) end
  table.sort(keys)
  return keys
end
