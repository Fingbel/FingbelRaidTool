-- Fingbel Raid Tool - Checker Core Module (stub)

local Checker = {}
Checker.name = "Checker"

--===============================
-- Slash handling
--===============================
function Checker.OnSlash(module, cmd, rest)
  if cmd ~= "check" then
    return false
  end

  local _, _, sub, arg = string.find(tostring(rest or ""), "^(%S*)%s*(.*)$")
  sub = string.lower(sub or "")

  if sub == "" or sub == "help" then
    FRT.Print("Checker (stub) usage:")
    FRT.Print("  /frt check ping      - test command")
    FRT.Print("  /frt check ui        - open checker tab")
    return true
  end

  if sub == "ping" then
    FRT.Print("Checker: pong")
    return true
  end

  if sub == "ui" then
    if FRT and FRT.Editor and FRT.Editor.Show then
      FRT.Editor.Show("Checker")
    end
    return true
  end

  FRT.Print("Checker (stub): nothing to run yet.")
  return true
end

function Checker.GetHelp(module)
  return {
    "/frt check ping  - test the checker stub",
    "/frt check ui    - open the Checker tab",
  }
end

--===============================
-- Editor panel registration
--===============================
local function RegisterCheckerPanel()
  if not (FRT and FRT.Editor and FRT.Editor.RegisterPanel) then
    return
  end

  FRT.Editor.RegisterPanel("Checker", function(parent)
    -- visible bg
    local bg = CreateFrame("Frame", nil, parent)
    bg:SetAllPoints(parent)
    bg:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" })
    bg:SetBackdropColor(0, 0, 0, 0.25)

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("Checker (stub)")

    local hint = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    hint:SetText("Empty for now. Click Ping to test.")

    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetWidth(100)
    btn:SetHeight(22)
    btn:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)
    btn:SetText("Ping")
    btn:SetScript("OnClick", function()
      Checker.OnSlash(Checker, "check", "ping")
    end)
  end, { title = "Checker", order = 50 })
end

--===============================
-- Lifecycle (core calls m.OnLoad(m) after VARIABLES_LOADED)
--===============================
function Checker.OnLoad(module)
  FRT.Print("Checker stub loaded.")
  if FRT and FRT.Checker_RegisterEditorPanel then
    FRT.Checker_RegisterEditorPanel()
  end
end

--===============================
-- Register with core
--===============================
FRT.RegisterModule(Checker.name, Checker)

-- In case this file loads after the editor, try once now too
RegisterCheckerPanel()
