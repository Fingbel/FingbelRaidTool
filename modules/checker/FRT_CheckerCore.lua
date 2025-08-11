-- FRT_CheckerCore.lua
-- Logic-only orchestrator: state, refresh, casting, events, pub/sub

FRT = FRT or {}
FRT.CheckerCore = FRT.CheckerCore or {}

do
  local state = {
    roster = {},
    columns = {},
    results = {},
  }

  local function recompute()
    state.roster  = FRT.Group.BuildRoster()
    state.columns = FRT.CheckerColumns.Build(state.roster)
    state.results = FRT.CheckerScan.Run(state.roster, state.columns)
    if FRT.Bus and FRT.Bus.Notify then FRT.Bus.Notify() end
  end

  -- Public getters
  function FRT.CheckerCore.GetRoster()  return state.roster  end
  function FRT.CheckerCore.GetColumns() return state.columns end
  function FRT.CheckerCore.GetResults() return state.results end

  function FRT.CheckerCore.RefreshNow()
    recompute()
  end

  function FRT.CheckerCore.SetLiveEvents(enable)
    if enable then
      FRT.GroupEvents.Enable(function() recompute() end, 0.15)
    else
      FRT.GroupEvents.Disable()
    end
  end

  function FRT.CheckerCore.Subscribe(fn)
    if FRT.Bus and FRT.Bus.Subscribe then FRT.Bus.Subscribe(fn) end
  end

  function FRT.CheckerCore.PlayerCanProvide(key)
    return FRT.CheckerRegistry.PlayerCanProvide(key)
  end

  -- Click-to-buff entry point used by Viewer
  function FRT.CheckerCore.TryCast(key, unit, useGroup)
    if not key or not unit then return false end
    if not FRT.CheckerRegistry.PlayerCanProvide(key) then return false end
    if UnitIsDeadOrGhost(unit) then return false end
    if not UnitIsFriend("player", unit) then return false end

    local icons = FRT.CheckerRegistry.GetSpellIcons(key)
    if not icons then return false end

    local ok = false
    if useGroup and icons.group then
      ok = FRT.Cast.ByIcons(icons.group, unit)
      if not ok and icons.single then
        ok = FRT.Cast.ByIcons(icons.single, unit)
      end
    else
      if icons.single then ok = FRT.Cast.ByIcons(icons.single, unit) end
    end
    return ok and true or false
  end

  -- Optional slash delegator (kept tiny)
  local Checker = { name = "Checker" }
  function Checker.OnSlash(module, cmd, rest)
    if cmd ~= "check" then return false end
    local sub = ""
    if rest and rest ~= "" then local _,_,cap = string.find(rest, "^(%S+)"); sub = string.lower(cap or "") end
    if sub == "" or sub == "buffs" or sub == "ui" then
      if FRT.CheckerViewer and FRT.CheckerViewer.Show then
        -- Prime then show to avoid first-open blank
        FRT.CheckerCore.SetLiveEvents(true)
        FRT.CheckerCore.RefreshNow()
        FRT.CheckerViewer.Show()
      else
        if FRT and FRT.Print then FRT.Print("Checker: viewer not loaded (FRT_CheckerViewer.lua).") end
      end
      return true
    elseif sub == "help" then
      if FRT and FRT.Print then
        FRT.Print("Checker:")
        FRT.Print("  /frt check ui   - open Missing Buffs viewer")
      end
      return true
    end
    if FRT and FRT.Print then FRT.Print("Checker: unknown subcommand. Try /frt check ui") end
    return true
  end

  function Checker.GetHelp(module)
    return { "/frt check ui  - open the viewer" }
  end

  function Checker.OnLoad(module)
    if FRT and FRT.Print then FRT.Print("Checker core loaded (logic-only, modular).") end
  end

  if FRT.RegisterModule then
    FRT.RegisterModule(Checker.name, Checker)
  end
end
