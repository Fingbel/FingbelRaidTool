-- FRT_Casting.lua
-- Safe casting helpers (temporary target swap, retarget)

FRT = FRT or {}
FRT.Cast = FRT.Cast or {}

do
  local BOOKTYPE_SPELL = BOOKTYPE_SPELL or "spell"

  function FRT.Cast.SafeCastOnUnit(spellIndex, unit)
    if not spellIndex or not unit then return false end

    if SpellIsTargeting and SpellIsTargeting() then SpellStopTargeting() end

    local had  = UnitExists("target")
    local same = had and UnitIsUnit and UnitIsUnit("target", unit)

    if not same then TargetUnit(unit) end
    CastSpell(spellIndex, BOOKTYPE_SPELL)

    if SpellIsTargeting and SpellIsTargeting() then
      SpellTargetUnit(unit)
      if SpellIsTargeting() then SpellStopTargeting() end
    end

    if not same then
      if had then TargetLastTarget() else ClearTarget() end
    end
    return true
  end

  function FRT.Cast.ByIcons(iconList, unit)
    local idx = FRT.Spellbook and FRT.Spellbook.FindByIcons(iconList)
    if not idx then return false end
    return FRT.Cast.SafeCastOnUnit(idx, unit)
  end
end
