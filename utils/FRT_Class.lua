-- FRT_Class.lua
-- Class helpers (colors, ordering, self)

FRT = FRT or {}
FRT.Class = FRT.Class or {}

do
  local D = FRT.Data or {}

  local function hex2rgb(hex)
    if not hex or string.len(hex) ~= 6 then return 1,1,1 end
    local r = tonumber(string.sub(hex,1,2),16) or 255
    local g = tonumber(string.sub(hex,3,4),16) or 255
    local b = tonumber(string.sub(hex,5,6),16) or 255
    return r/255, g/255, b/255
  end

  function FRT.Class.Self()
    local loc, file = UnitClass("player")
    return file or loc or "UNKNOWN"
  end

  function FRT.Class.ColorRGB(class)
    local t = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if t then return t.r, t.g, t.b end
    local hex = (D.ClassColorsHex and D.ClassColorsHex[class]) or nil
    if hex then return hex2rgb(hex) end
    return 1,1,1
  end

  function FRT.Class.Compare(a, b, order)
    order = order or (D.ClassOrder or {})
    local ca = order[a or "UNKNOWN"] or 999
    local cb = order[b or "UNKNOWN"] or 999
    return ca < cb
  end
end
