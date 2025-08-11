-- FRT_CheckerCore.lua
-- Logic-only orchestrator: state, refresh, casting, events, pub/sub
-- + compact-mode row builder (group-or-player)

FRT = FRT or {}
FRT.CheckerCore = FRT.CheckerCore or {}

do
  local state = {
    roster = {},   -- array of { name, unit, class, group = 1..8, ... }
    columns = {},  -- array of { key, label, icon }
    results = {},  -- map name -> { present = { [key] = true/false/"__NA__" } }
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

  -- Click-to-buff entry used by Viewer
  function FRT.CheckerCore.TryCast(key, unit, useGroup)
    if not key or not unit then return false end
    if not FRT.CheckerRegistry.PlayerCanProvide(key) then return false end
    if UnitIsDeadOrGhost(unit) then return false end
    if not UnitIsFriend("player", unit) then return false end

    local icons = FRT.CheckerRegistry.GetSpellIcons(key)
    if not icons then return false end

    local ok = false
    if useGroup and icons.group then
      -- Probe with SINGLE (more reliable range API), cast GROUP
      local probe = icons.single or icons.group
      ok = FRT.Cast.ByIconsWithProbe(icons.group, unit, probe)
      if not ok and icons.single then
        -- optional fallback if group failed for other reasons
        ok = FRT.Cast.ByIcons(icons.single, unit)
      end
    else
      if icons.single then ok = FRT.Cast.ByIcons(icons.single, unit) end
    end
    return ok and true or false
  end

  ------------------------------------------------------------------
  -- BuildRows: compact mode aggregator (group row or player rows)
  -- cols: visible columns (array of {key,...})
  -- opts: { compact=true, thresholdOn, thresholdOff }
  -- Returns array of row descriptors:
  --   { type="group", groupId=G, groupSize=N, perCol = {
  --        [key] = { eligible, missing, anchor=unit, canGroupCast=true/false }
  --     }}
  -- or { type="player", idx = rosterIndex }
  ------------------------------------------------------------------
  local function _buildGroupsIndex(roster)
    local groups = {}
    local i=1
    while i <= table.getn(roster) do
      local r = roster[i]
      local g = r.group or 1
      groups[g] = groups[g] or { members = {}, size = 0 }
      table.insert(groups[g].members, { idx=i, name=r.name, unit=r.unit })
      groups[g].size = groups[g].size + 1
      i = i + 1
    end
    return groups
  end

  local function _present(results, name, key)
    local res = results[name]
    if not res or not res.present then return "__NA__" end
    return res.present[key]
  end

  function FRT.CheckerCore.BuildRows(cols, opts)
    local rows = {}
    local compact      = opts and opts.compact
    local thresholdOn  = (opts and opts.thresholdOn)  or 0.60
    local thresholdOff = (opts and opts.thresholdOff) or 0.50
    if not compact then return rows end

    local roster  = state.roster or {}
    local results = state.results or {}
    local groups  = _buildGroupsIndex(roster)

    -- Decide per group whether to show a single group row or per-player rows
    local gId = 1
    while gId <= 8 do
      local gi = groups[gId]
      if gi and gi.members and table.getn(gi.members) > 0 then
        -- Compute per-column tallies and anchors
        local perCol = {}
        local showGroup = false

        local c=1
        while c <= table.getn(cols) do
          local key = cols[c].key
          local eligible, missing = 0, 0
          local anchorUnit = nil

          local canGroupCast = false
          if FRT.CheckerRegistry and FRT.CheckerRegistry.GetSpellIcons and FRT.CheckerCore.PlayerCanProvide then
            local icons = FRT.CheckerRegistry.GetSpellIcons(key)
            canGroupCast = (icons and icons.group) and FRT.CheckerCore.PlayerCanProvide(key) and true or false
          end

          local m=1
          while m <= table.getn(gi.members) do
            local mi   = gi.members[m]
            local pval = _present(results, roster[mi.idx].name, key)
            local isNA = (pval == "__NA__")
            if not isNA then
              eligible = eligible + 1
              if not pval then
                missing = missing + 1
                if not anchorUnit then anchorUnit = roster[mi.idx].unit end
              else
                if not anchorUnit then anchorUnit = roster[mi.idx].unit end
              end
            end
            m = m + 1
          end

          perCol[key] = { eligible=eligible, missing=missing, anchor=anchorUnit, canGroupCast=canGroupCast }

          -- group choice flag (if any visible col crosses threshold)
          if canGroupCast and eligible > 0 then
            local ratio = missing / eligible
            if ratio >= thresholdOn then
              showGroup = true
            end
          end
          c = c + 1
        end

        if showGroup then
          local groupUnits = {}
          local m=1
          while m <= table.getn(gi.members) do
            local mi = gi.members[m]
            local u  = roster[mi.idx].unit
            if u then table.insert(groupUnits, u) end
            m = m + 1
          end

          table.insert(rows, {
            type      = "group",
            groupId   = gId,
            groupSize = gi.size,
            units     = groupUnits,   -- <— NEW: pass subgroup unit tokens to the viewer
            perCol    = perCol
          })
        else
          -- otherwise add each player who has at least one missing among visible cols
          local m=1
          while m <= table.getn(gi.members) do
            local mi = gi.members[m]
            local name = roster[mi.idx].name
            local res = results[name]
            local shouldShow = false
            if res and res.present then
              local c=1
              while c <= table.getn(cols) do
                local key = cols[c].key
                local pval = res.present[key]
                local isNA = (pval == "__NA__")
                if not isNA and not pval then
                  shouldShow = true; break
                end
                c = c + 1
              end
            end
            if shouldShow then
              table.insert(rows, { type="player", idx = mi.idx })
            end
            m = m + 1
          end
        end
      end
      gId = gId + 1
    end

    return rows
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
