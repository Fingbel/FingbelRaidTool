-- FRT_Casting.lua
-- Safe casting helpers (temporary target swap, retarget, no self-cast fallback)

FRT = FRT or {}
FRT.Cast = FRT.Cast or {}

do
  local BOOKTYPE_SPELL = BOOKTYPE_SPELL or "spell"

  -- Temporarily force CVar to avoid auto self-cast fallback
  local function _withAutoSelfCastDisabled(fn)
    local okGet, prev = pcall(GetCVar, "autoSelfCast")
    if not okGet then prev = nil end
    pcall(SetCVar, "autoSelfCast", "0")
    local ok, ret = pcall(fn)
    if prev ~= nil then pcall(SetCVar, "autoSelfCast", tostring(prev)) end
    return ok and ret
  end

  ------------------------------------------------------------
  -- Public: range/visibility helpers
  ------------------------------------------------------------
  function FRT.Cast.IsInRangeByIndex(spellIndex, unit)
    if not spellIndex or not unit then return false end
    local name = GetSpellName(spellIndex, BOOKTYPE_SPELL)
    if not name then return false end
    local r = IsSpellInRange(name, unit)
    if r == 1 then return true end
    if r == 0 then return false end
    -- r == nil => API can’t tell (typical for some group buffs). Don’t block.
    return true
  end

  function FRT.Cast.InRangeByIcons(iconList, unit)
    local idx = FRT.Spellbook and FRT.Spellbook.FindByIcons(iconList)
    if not idx then return false end
    return FRT.Cast.IsInRangeByIndex(idx, unit)
  end

  -- Prefer single-target spell for range checks
  function FRT.Cast.InRangeByKey(key, unit, _)
    local icons = FRT.CheckerRegistry and FRT.CheckerRegistry.GetSpellIcons(key)
    if not icons then return false end
    local list = icons.single or icons.group
    if not list then return false end
    return FRT.Cast.InRangeByIcons(list, unit)
  end

  function FRT.Cast.IsVisiblyReachable(unit)
    if not unit then return false end
    if UnitIsConnected and UnitIsConnected(unit) == 0 then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return false end
    if UnitIsVisible and not UnitIsVisible(unit) then return false end
    return true
  end

  ------------------------------------------------------------
  -- Core: safe cast (optional probe index for range-gating)
  ------------------------------------------------------------
  function FRT.Cast.SafeCastOnUnit(spellIndex, unit, probeSpellIndex)
    if not spellIndex or not unit then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return false end
    if UnitIsFriend and not UnitIsFriend("player", unit) then return false end

    if not FRT.Cast.IsVisiblyReachable(unit) then
      if FRT and FRT.Print then FRT.Print("|cffffcc00Target too far (not visible).|r") end
      if SpellIsTargeting and SpellIsTargeting() then SpellStopTargeting() end
      return false
    end

    -- Use probe (usually the SINGLE spell) for reliable range gating
    local gateIndex = probeSpellIndex or spellIndex
    if gateIndex and not FRT.Cast.IsInRangeByIndex(gateIndex, unit) then
      if FRT and FRT.Print then FRT.Print("|cffffcc00Out of range.|r") end
      return false
    end

    if SpellIsTargeting and SpellIsTargeting() then SpellStopTargeting() end

    local hadTarget  = UnitExists("target")
    local sameTarget = hadTarget and UnitIsUnit and UnitIsUnit("target", unit)

    local function doCast()
      if not sameTarget then TargetUnit(unit) end
      CastSpell(spellIndex, BOOKTYPE_SPELL)
      if SpellIsTargeting and SpellIsTargeting() then
        SpellTargetUnit(unit)
        if SpellIsTargeting() then
          SpellStopTargeting()
          return false
        end
      end
      return true
    end

    local ok = _withAutoSelfCastDisabled(doCast)

    if not sameTarget then
      if hadTarget then TargetLastTarget() else ClearTarget() end
    end
    return ok and true or false
  end

  ------------------------------------------------------------
  -- Convenience
  ------------------------------------------------------------
  function FRT.Cast.ByIcons(iconList, unit)
    local idx = FRT.Spellbook and FRT.Spellbook.FindByIcons(iconList)
    if not idx then return false end
    return FRT.Cast.SafeCastOnUnit(idx, unit)
  end

  -- cast by icons, but gate range using a probe icon list (eg SINGLE)
  function FRT.Cast.ByIconsWithProbe(iconListToCast, unit, probeIconList)
    local castIdx = FRT.Spellbook and FRT.Spellbook.FindByIcons(iconListToCast)
    if not castIdx then return false end
    local probeIdx = nil
    if probeIconList then
      probeIdx = FRT.Spellbook and FRT.Spellbook.FindByIcons(probeIconList) or nil
    end
    return FRT.Cast.SafeCastOnUnit(castIdx, unit, probeIdx)
  end

  -- Resolve by icons with optional name fallback, then safe-cast
  function FRT.Cast.BySignature(iconList, nameList, unit)
    local idx = FRT.Spellbook and FRT.Spellbook.Resolve and FRT.Spellbook.Resolve(iconList, nameList)
    if not idx then return false end
    return FRT.Cast.SafeCastOnUnit(idx, unit)
  end
end
