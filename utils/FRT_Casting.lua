-- FRT_Casting.lua
-- Safe casting helpers (temporary target swap, retarget, no self-cast fallback)

FRT = FRT or {}
FRT.Cast = FRT.Cast or {}

do
  local BOOKTYPE_SPELL = BOOKTYPE_SPELL or "spell"

  ------------------------------------------------------------
  -- Utilities
  ------------------------------------------------------------
  local function _IsInRangeByIndex(spellIndex, unit)
    if not spellIndex or not unit then return false end
    local name = GetSpellName(spellIndex, BOOKTYPE_SPELL)
    if not name then return false end
    local r = IsSpellInRange(name, unit)
    return r == 1
  end

  -- FRT_Casting.lua (add near top)
  local function _IsVisiblyReachable(unit)
    if not unit then return false end
    if UnitIsConnected and UnitIsConnected(unit) == 0 then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return false end
    if UnitIsVisible and not UnitIsVisible(unit) then return false end
    return true
  end


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
  -- Public: range checks the same way viewer wants to gate clicks
  ------------------------------------------------------------
  function FRT.Cast.InRangeByIcons(iconList, unit)
    local idx = FRT.Spellbook and FRT.Spellbook.FindByIcons(iconList)
    if not idx then return false end
    return _IsInRangeByIndex(idx, unit)
  end

  function FRT.Cast.InRangeByKey(key, unit, useGroup)
    local icons = FRT.CheckerRegistry and FRT.CheckerRegistry.GetSpellIcons(key)
    if not icons then return false end
    local list = (useGroup and icons.group) or icons.single or icons.group
    if not list then return false end
    return FRT.Cast.InRangeByIcons(list, unit)
  end

  ------------------------------------------------------------
  -- Core: safe cast that never falls back to self
  ------------------------------------------------------------
  function FRT.Cast.SafeCastOnUnit(spellIndex, unit)
    if not spellIndex or not unit then return false end

    -- Basic safety: only try friendly, living units
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return false end
    if UnitIsFriend and not UnitIsFriend("player", unit) then return false end

    if not _IsVisiblyReachable(unit) then
      if FRT and FRT.Print then FRT.Print("|cffffcc00Target too far (not visible).|r") end
      if SpellIsTargeting and SpellIsTargeting() then SpellStopTargeting() end
      return false
    end

    -- Hard RANGE GATE: refuse before we touch target, also stops any click-casting mode
    if not _IsInRangeByIndex(spellIndex, unit) then
      if SpellIsTargeting and SpellIsTargeting() then SpellStopTargeting() end
      if FRT and FRT.Print then FRT.Print("|cffffcc00Out of range.|r") end
      return false
    end

    -- Clean any previous targeting cursor
    if SpellIsTargeting and SpellIsTargeting() then SpellStopTargeting() end

    local hadTarget  = UnitExists("target")
    local sameTarget = hadTarget and UnitIsUnit and UnitIsUnit("target", unit)

    -- Perform the cast with autoSelfCast temporarily disabled
    local function doCast()
      if not sameTarget then TargetUnit(unit) end
      CastSpell(spellIndex, BOOKTYPE_SPELL)

      -- If the spell requires a click target (e.g., single-target buff UX)
      if SpellIsTargeting and SpellIsTargeting() then
        SpellTargetUnit(unit)
        -- If still targeting here, it failed to accept the unit -> abort
        if SpellIsTargeting() then
          SpellStopTargeting()
          return false
        end
      end
      return true
    end

    local ok = _withAutoSelfCastDisabled(doCast)

    -- Restore previous target
    if not sameTarget then
      if hadTarget then TargetLastTarget() else ClearTarget() end
    end

    return ok and true or false
  end

  ------------------------------------------------------------
  -- Convenience: cast by icon list
  ------------------------------------------------------------
  function FRT.Cast.ByIcons(iconList, unit)
    local idx = FRT.Spellbook and FRT.Spellbook.FindByIcons(iconList)
    if not idx then return false end
    return FRT.Cast.SafeCastOnUnit(idx, unit)
  end
end
