-- Fingbel Raid Tool — Spec Detector

SLASH_FRTSPEC1 = "/frtspec"

local function GuessSpecFromTalents()
  if not GetNumTalentTabs or not GetTalentTabInfo then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[FRT]|r Talent API unavailable.")
    return
  end

  local classLoc, classEN = UnitClass("player")
  local tabs = GetNumTalentTabs() or 0
  if tabs <= 0 then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[FRT]|r No talents available.")
    return
  end

  local names, points, total = {}, {}, 0
  for i = 1, tabs do
    local name, icon, spent = GetTalentTabInfo(i)
    names[i]  = name or ("Tree"..i)
    points[i] = spent or 0
    total     = total + (spent or 0)
  end

  -- find max
  local maxIdx, maxPts = 1, points[1] or 0
  for i = 2, tabs do
    if (points[i] or 0) > maxPts then
      maxIdx, maxPts = i, points[i]
    end
  end

  -- simple labeling
  local spec = names[maxIdx] or "Unknown"
  local label
  if total >= 31 and maxPts >= 31 then
    label = spec .. " (deep)"
  elseif total >= 21 and maxPts >= 21 then
    label = spec .. " (mid)"
  else
    label = spec
  end

  -- detect hybrid if two trees are close (within 5 pts) and both >= 20% of total
  local secondIdx, secondPts = nil, -1
  for i = 1, tabs do
    if i ~= maxIdx and (points[i] or 0) > secondPts then
      secondIdx, secondPts = i, points[i]
    end
  end
  if secondIdx and secondPts >= 0 then
    local close = math.abs((secondPts or 0) - (maxPts or 0)) <= 5
    local shareOk = total > 0 and ((maxPts/total) >= 0.2 and (secondPts/total) >= 0.2)
    if close and shareOk then
      label = string.format("%s/%s hybrid", spec, names[secondIdx] or ("Tree"..secondIdx))
    end
  end

  -- format like 21/30/0
  local dist = ""
  for i = 1, tabs do
    dist = dist .. tostring(points[i] or 0)
    if i < tabs then dist = dist .. "/" end
  end

  DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00[FRT]|r %s: %s — %s points [%s]", classLoc or "Class", label, tostring(total or 0), dist))
  for i = 1, tabs do
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s: %d", names[i] or ("Tree"..i), points[i] or 0))
  end
end

SlashCmdList["FRTSPEC"] = function()
  GuessSpecFromTalents()
end
