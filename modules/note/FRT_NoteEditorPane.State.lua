-- Fingbel Raid Tool — Note Editor Pane (State)
-- State container + dirty/baseline + blocker helpers

local FRT = FRT
local EP = FRT.Note.EditorPane

-- pane context (shared across files)
EP.state = EP.state or {}
local S = EP.state

-- runtime/UI references (populated in UI.Build)
S.parent           = nil
S.header           = nil
S.bottomBar        = nil
S.leftColumn       = nil
S.rightPane        = nil
S.rightOverlay     = nil
S.rightOverlayText = nil
S.raidDD           = nil
S.bossDD           = nil
S.listScroll       = nil
S.listChild        = nil
S.listButtons      = {}
S.titleBox         = nil
S.editor           = nil  -- CreateScrollableEdit result { edit=..., SetText/GetText/Refresh }
S.bossInfoLabel    = nil
S.buttons          = { new=nil, dup=nil, del=nil, save=nil, share=nil }

-- selection and UI SV
S.uiSV             = nil
S.currentRaid      = nil
S.currentId        = nil
S.currentBossFilter= "All"

-- editor state
S.editorEnabled    = false
S.baseline         = nil
S.squelch          = 0

-- pending flows
S.pending = {
  raidSwitch  = nil,
  noteSwitch  = nil,
  noteIsNew   = false,
  deleteId    = nil,
  bossFilter  = nil,
}

-- blocker frame (modal)
S.blocker = nil

-- ========================
-- Dirty / baseline helpers
-- ========================
function EP.BeginSquelch() S.squelch = (S.squelch or 0) + 1 end
function EP.EndSquelch() if S.squelch and S.squelch > 0 then S.squelch = S.squelch - 1 end end

function EP.EditorSnapshot()
  local ed = S.editor
  local t = (ed and ed.GetText and (ed.GetText() or "")) or ""
  local ttl = (S.titleBox and S.titleBox.GetText and (S.titleBox:GetText() or "")) or ""
  return { id = S.currentId, title = ttl, text = t }
end

function EP.SnapBaseline()
  S.baseline = EP.EditorSnapshot()
end

function EP.IsDirty()
  if not S.editorEnabled then return false end
  if not S.baseline then return false end
  local cur = EP.EditorSnapshot()
  if cur.id ~= S.baseline.id then return false end
  return not (cur.title == S.baseline.title and cur.text == S.baseline.text)
end

function EP.UpdateDirtyFromUserEdit()
  if (S.squelch or 0) > 0 then return end
  if EP.UpdateButtonsState then EP.UpdateButtonsState() end
end

-- ========================
-- Blocker helpers
-- ========================
local function EnsureBlocker()
  if S.blocker then return end
  local parent = S.parent
  if not parent then return end
  local b = CreateFrame("Frame", nil, parent)
  b:SetAllPoints(parent)
  b:EnableMouse(true)
  b:SetFrameStrata("DIALOG")
  b:SetFrameLevel((parent:GetFrameLevel() or 0) + 200)
  local t = b:CreateTexture(nil, "BACKGROUND")
  t:SetAllPoints(b)
  t:SetTexture(0,0,0,0)
  b:Hide()
  S.blocker = b
end

function EP.ShowBlocker()
  EnsureBlocker()
  if S.editor and S.editor.edit and S.editor.edit.ClearFocus then S.editor.edit:ClearFocus() end
  if S.titleBox and S.titleBox.ClearFocus then S.titleBox:ClearFocus() end
  if S.blocker then S.blocker:Show() end
end

function EP.HideBlocker()
  if S.blocker then S.blocker:Hide() end
end

-- ========================
-- Enable/disable editor UI
-- ========================
function EP.SetEditorEnabled(flag)
  S.editorEnabled = flag and true or false
  if not S.editorEnabled then
    if S.titleBox and S.titleBox.ClearFocus then S.titleBox:ClearFocus() end
    if S.editor and S.editor.edit and S.editor.edit.ClearFocus then S.editor.edit:ClearFocus() end
    if S.rightOverlay then S.rightOverlay:Show() end
  else
    if S.rightOverlay then S.rightOverlay:Hide() end
  end
  if EP.UpdateButtonsState then EP.UpdateButtonsState() end
end
