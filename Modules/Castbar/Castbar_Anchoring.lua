local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("Castbar")

if not module then return end

local Anchor = LibStub("LibAnchorRegistry-1.0", true)

if not Anchor then
    module:Debug("LibAnchorRegistry-1.0 not found")
    return
end

local LibEditMode = LibStub("LibEditMode", true)
local useLibEditMode = LibEditMode and LibEditMode.AddFrame

local Anchoring = {}
local anchorHandles = {}
local libEditModeRegistered = {}
local combatApplyQueue = {}
local combatEventRegistered = false
local combatEventFrame = nil

local POSITION_CHANGE_THRESHOLD = 1
local EDIT_OVERLAY_BORDER_R, EDIT_OVERLAY_BORDER_G, EDIT_OVERLAY_BORDER_B = 0.2, 0.8, 1
local EDIT_OVERLAY_FILL_R, EDIT_OVERLAY_FILL_G, EDIT_OVERLAY_FILL_B, EDIT_OVERLAY_FILL_A = 0.2, 0.8, 1, 0.25

local ANCHOR_NAMES = {
    player = "TavernUI.Castbar.player",
    target = "TavernUI.Castbar.target",
    focus  = "TavernUI.Castbar.focus",
}
module.ANCHOR_NAMES = ANCHOR_NAMES

local DISPLAY_NAMES = {
    player = "Player Castbar",
    target = "Target Castbar",
    focus  = "Focus Castbar",
}

local function GetBarFrame(unitKey)
    local bar = module:GetCastbar(unitKey)
    return bar and bar.frame or nil
end

local function GetBarPosition(unitKey)
    local frame = GetBarFrame(unitKey)
    if not frame or not frame.GetPoint then return nil end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then return nil end
    local relativeToName = (relativeTo and relativeTo.GetName and relativeTo:GetName()) or (relativeTo == UIParent and "UIParent") or nil
    return {
        point = point,
        relativeToName = relativeToName,
        relativePoint = relativePoint,
        x = x or 0,
        y = y or 0,
    }
end

local function HasPositionChanged(unitKey, startPos)
    if not startPos then return false end
    local current = GetBarPosition(unitKey)
    if not current then return true end
    if math.abs(current.x - startPos.x) > POSITION_CHANGE_THRESHOLD or math.abs(current.y - startPos.y) > POSITION_CHANGE_THRESHOLD then
        return true
    end
    return current.point ~= startPos.point or current.relativePoint ~= startPos.relativePoint or current.relativeToName ~= startPos.relativeToName
end

local function ShouldApplyAnchor(unitKey)
    local settings = module:GetUnitSettings(unitKey)
    if not settings or not settings.anchorConfig then return false end
    local target = settings.anchorConfig.target
    return target and target ~= ""
end

local function SetAnchorConfig(unitKey, anchorConfig)
    module:SetSetting("units." .. unitKey .. ".anchorConfig", anchorConfig)
end

local function ReleaseAnchor(unitKey)
    local handle = anchorHandles[unitKey]
    if handle then
        if handle.Release then
            handle:Release()
        end
        anchorHandles[unitKey] = nil
    end
end

local function SetBarDraggable(frame, enable)
    if not frame or not frame.SetMovable then return end
    if enable then
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
        frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    else
        frame:SetMovable(false)
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
    end
end

local function GetEditModeLayoutPositions()
    local db = module:GetDB()
    if not db.editModeLayoutPositions then db.editModeLayoutPositions = {} end
    return db.editModeLayoutPositions
end

function Anchoring:ClearLayoutPositionForBar(unitKey)
    if not useLibEditMode or not LibEditMode or not LibEditMode.GetActiveLayoutName then return end
    local layoutName = LibEditMode:GetActiveLayoutName()
    if not layoutName then return end
    local positions = GetEditModeLayoutPositions()
    if positions[layoutName] then
        positions[layoutName][unitKey] = nil
    end
end

local function UpdateEditOverlayInfo(unitKey)
    local frame = GetBarFrame(unitKey)
    local overlay = frame and frame.editModeOverlay
    if not overlay or not overlay.infoText then return end
    local w = frame:GetWidth()
    local h = frame:GetHeight()
    local dimStr = (w and h) and ("%d x %d"):format(math.floor(w + 0.5), math.floor(h + 0.5)) or "?"
    local pos = GetBarPosition(unitKey)
    local anchorStr
    if pos then
        local rel = (pos.relativeToName and pos.relativeToName ~= "" and pos.relativeToName ~= "UIParent") and pos.relativeToName or nil
        if rel then
            anchorStr = ("%s to %s"):format(pos.point or "CENTER", rel)
        else
            anchorStr = ("%s %d, %d"):format(pos.point or "CENTER", math.floor((pos.x or 0) + 0.5), math.floor((pos.y or 0) + 0.5))
        end
    else
        anchorStr = "?"
    end
    overlay.infoText:SetText(dimStr .. "  |  " .. anchorStr)
end

local function CreateNudgeButton(parent, direction, deltaX, deltaY, unitKey)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(18, 18)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.1, 0.1, 0.1, 0.7)
    local line1 = btn:CreateTexture(nil, "ARTWORK")
    line1:SetColorTexture(1, 1, 1, 0.9)
    line1:SetSize(7, 2)
    local line2 = btn:CreateTexture(nil, "ARTWORK")
    line2:SetColorTexture(1, 1, 1, 0.9)
    line2:SetSize(7, 2)
    if direction == "DOWN" then
        line1:SetPoint("CENTER", btn, "CENTER", -2, 1)
        line1:SetRotation(math.rad(-45))
        line2:SetPoint("CENTER", btn, "CENTER", 2, 1)
        line2:SetRotation(math.rad(45))
    elseif direction == "UP" then
        line1:SetPoint("CENTER", btn, "CENTER", -2, -1)
        line1:SetRotation(math.rad(45))
        line2:SetPoint("CENTER", btn, "CENTER", 2, -1)
        line2:SetRotation(math.rad(-45))
    elseif direction == "LEFT" then
        line1:SetPoint("CENTER", btn, "CENTER", -1, -2)
        line1:SetRotation(math.rad(-45))
        line2:SetPoint("CENTER", btn, "CENTER", -1, 2)
        line2:SetRotation(math.rad(45))
    else
        line1:SetPoint("CENTER", btn, "CENTER", 1, -2)
        line1:SetRotation(math.rad(45))
        line2:SetPoint("CENTER", btn, "CENTER", 1, 2)
        line2:SetRotation(math.rad(-45))
    end
    btn:SetScript("OnEnter", function()
        line1:SetColorTexture(EDIT_OVERLAY_BORDER_R, EDIT_OVERLAY_BORDER_G, EDIT_OVERLAY_BORDER_B, 1)
        line2:SetColorTexture(EDIT_OVERLAY_BORDER_R, EDIT_OVERLAY_BORDER_G, EDIT_OVERLAY_BORDER_B, 1)
    end)
    btn:SetScript("OnLeave", function()
        line1:SetColorTexture(1, 1, 1, 0.9)
        line2:SetColorTexture(1, 1, 1, 0.9)
    end)
    btn:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local frame = GetBarFrame(unitKey)
        if not frame then return end
        local pos = GetBarPosition(unitKey)
        if not pos then return end
        local step = IsShiftKeyDown() and 10 or 1
        local newX = (pos.x or 0) + deltaX * step
        local newY = (pos.y or 0) + deltaY * step
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.point, newX, newY)
        local layoutName = LibEditMode and LibEditMode:GetActiveLayoutName()
        if layoutName then
            local positions = GetEditModeLayoutPositions()
            if not positions[layoutName] then positions[layoutName] = {} end
            positions[layoutName][unitKey] = { point = pos.point, x = newX, y = newY }
        end
        UpdateEditOverlayInfo(unitKey)
    end)
    return btn
end

local function CreateEditOverlay(unitKey, frame)
    if frame.editModeOverlay then return end
    local overlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    overlay:SetAllPoints()
    overlay:SetFrameLevel(frame:GetFrameLevel() + 5)
    overlay:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    overlay:SetBackdropColor(EDIT_OVERLAY_FILL_R, EDIT_OVERLAY_FILL_G, EDIT_OVERLAY_FILL_B, EDIT_OVERLAY_FILL_A)
    overlay:SetBackdropBorderColor(EDIT_OVERLAY_BORDER_R, EDIT_OVERLAY_BORDER_G, EDIT_OVERLAY_BORDER_B, 1)
    overlay:EnableMouse(false)

    local nudgeLeft = CreateNudgeButton(overlay, "LEFT", -1, 0, unitKey)
    nudgeLeft:SetPoint("RIGHT", overlay, "LEFT", -4, 0)
    local nudgeRight = CreateNudgeButton(overlay, "RIGHT", 1, 0, unitKey)
    nudgeRight:SetPoint("LEFT", overlay, "RIGHT", 4, 0)
    local nudgeUp = CreateNudgeButton(overlay, "UP", 0, 1, unitKey)
    nudgeUp:SetPoint("BOTTOM", overlay, "TOP", 0, 4)
    local nudgeDown = CreateNudgeButton(overlay, "DOWN", 0, -1, unitKey)
    nudgeDown:SetPoint("TOP", overlay, "BOTTOM", 0, -4)

    local infoText = TavernUI:CreateFontString(overlay, 12)
    infoText:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    infoText:SetTextColor(0.7, 0.7, 0.7, 1)
    overlay.infoText = infoText

    overlay:Hide()
    frame.editModeOverlay = overlay
end

local function ShowEditOverlay(unitKey)
    for _, uKey in ipairs({ "player", "target", "focus" }) do
        local f = GetBarFrame(uKey)
        if f and f.editModeOverlay then
            f.editModeOverlay:SetShown(uKey == unitKey)
        end
    end
    UpdateEditOverlayInfo(unitKey)
end

local function HideEditOverlay(unitKey)
    local frame = GetBarFrame(unitKey)
    if frame and frame.editModeOverlay then
        frame.editModeOverlay:Hide()
    end
end

function Anchoring:RegisterBar(unitKey, frame)
    if not frame then return end
    local anchorName = ANCHOR_NAMES[unitKey]
    local displayName = DISPLAY_NAMES[unitKey] or unitKey
    if not anchorName then return end

    Anchor:Register(anchorName, frame, {
        displayName = displayName,
        category = "castbars",
    })

    if useLibEditMode then
        local defaultPos = GetBarPosition(unitKey)
        local default = defaultPos and { point = defaultPos.point or "CENTER", x = defaultPos.x or 0, y = defaultPos.y or 0 }
            or { point = "CENTER", x = 0, y = -150 }

        LibEditMode:AddFrame(frame, function(f, layoutName, point, x, y)
            local uKey = f.unitKey
            if not uKey then return end
            local positions = GetEditModeLayoutPositions()
            if not positions[layoutName] then positions[layoutName] = {} end
            positions[layoutName][uKey] = { point = point, x = x, y = y }

            SetAnchorConfig(uKey, {
                target = "UIParent",
                point = point,
                relativePoint = point,
                offsetX = x,
                offsetY = y,
            })
            positions[layoutName][uKey] = nil
            Anchoring:ApplyAnchor(uKey)
        end, default, displayName)

        libEditModeRegistered[unitKey] = true
        frame.unitKey = unitKey
        CreateEditOverlay(unitKey, frame)

        local sel = LibEditMode.frameSelections and LibEditMode.frameSelections[frame]
        if sel then
            sel:SetAlpha(0)
            local oldShow = sel.Show
            sel.Show = function(self)
                if oldShow then oldShow(self) end
                ShowEditOverlay(unitKey)
            end
            local oldHide = sel.Hide
            sel.Hide = function(self)
                if oldHide then oldHide(self) end
                HideEditOverlay(unitKey)
            end
        end
    end
end

function Anchoring:UnregisterBar(unitKey, frame)
    ReleaseAnchor(unitKey)
    local anchorName = ANCHOR_NAMES[unitKey]
    if anchorName then
        Anchor:Unregister(anchorName)
    end
    libEditModeRegistered[unitKey] = nil
    if useLibEditMode and frame and LibEditMode then
        if LibEditMode.frameSelections then LibEditMode.frameSelections[frame] = nil end
        if LibEditMode.frameCallbacks then LibEditMode.frameCallbacks[frame] = nil end
        if LibEditMode.frameDefaults then LibEditMode.frameDefaults[frame] = nil end
        if LibEditMode.frameSettings then LibEditMode.frameSettings[frame] = nil end
        if LibEditMode.frameButtons then LibEditMode.frameButtons[frame] = nil end
    end
end

local function ProcessCombatApplyQueue()
    local queue = combatApplyQueue
    combatApplyQueue = {}
    for unitKey, _ in pairs(queue) do
        Anchoring:ApplyAnchor(unitKey)
    end
end

function Anchoring:ApplyAnchor(unitKey)
    local frame = GetBarFrame(unitKey)
    if not frame then return end

    if InCombatLockdown() then
        combatApplyQueue[unitKey] = true
        if not combatEventRegistered then
            combatEventRegistered = true
            combatEventFrame = CreateFrame("Frame")
            combatEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            combatEventFrame:SetScript("OnEvent", function(_, event)
                if event == "PLAYER_REGEN_ENABLED" then
                    ProcessCombatApplyQueue()
                end
            end)
        end
        return
    end

    if useLibEditMode and libEditModeRegistered[unitKey] then
        local layoutName = LibEditMode:GetActiveLayoutName()
        if layoutName then
            local positions = GetEditModeLayoutPositions()
            local pos = positions[layoutName] and positions[layoutName][unitKey]
            if pos and pos.point then
                ReleaseAnchor(unitKey)
                frame:ClearAllPoints()
                frame:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
                return
            end
        end
    end

    if not ShouldApplyAnchor(unitKey) then
        ReleaseAnchor(unitKey)
        return
    end

    local settings = module:GetUnitSettings(unitKey)
    local anchorConfig = settings.anchorConfig

    ReleaseAnchor(unitKey)

    local handle = Anchor:AnchorTo(frame, {
        target = anchorConfig.target,
        point = anchorConfig.point or "CENTER",
        relativePoint = anchorConfig.relativePoint or "CENTER",
        offsetX = anchorConfig.offsetX or 0,
        offsetY = anchorConfig.offsetY or 0,
        deferred = true,
    })

    if handle then
        anchorHandles[unitKey] = handle
    end
end

function Anchoring:UpdateAnchors()
    if not module:IsEnabled() then return end
    local EditModeManagerFrame = _G.EditModeManagerFrame
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return end

    for _, unitKey in ipairs({ "player", "target", "focus" }) do
        local frame = GetBarFrame(unitKey)
        if frame then
            self:RegisterBar(unitKey, frame)
            self:ApplyAnchor(unitKey)
        end
    end
end

local editModeStartPositions = {}
local editModeHooked = false

local function OnEditModeEnter()
    if useLibEditMode or not module:IsEnabled() then return end
    editModeStartPositions = {}
    for _, unitKey in ipairs({ "player", "target", "focus" }) do
        local frame = GetBarFrame(unitKey)
        if frame then
            editModeStartPositions[unitKey] = GetBarPosition(unitKey)
            if not libEditModeRegistered[unitKey] then
                ReleaseAnchor(unitKey)
                frame:ClearAllPoints()
                local cx, cy = frame:GetCenter()
                local px, py = UIParent:GetCenter()
                if cx and cy and px and py then
                    frame:SetPoint("CENTER", UIParent, "CENTER", math.floor(cx - px + 0.5), math.floor(cy - py + 0.5))
                end
                SetBarDraggable(frame, true)
            end
        end
    end
end

local function OnEditModeSave()
    if useLibEditMode or not module:IsEnabled() then return end
    for _, unitKey in ipairs({ "player", "target", "focus" }) do
        local frame = GetBarFrame(unitKey)
        if frame and not libEditModeRegistered[unitKey] then
            SetBarDraggable(frame, false)
        end
    end
    for unitKey, startPos in pairs(editModeStartPositions) do
        if HasPositionChanged(unitKey, startPos) then
            local current = GetBarPosition(unitKey)
            if current then
                local target = (current.relativeToName and current.relativeToName ~= "") and current.relativeToName or "UIParent"
                SetAnchorConfig(unitKey, {
                    target = target,
                    point = current.point or "CENTER",
                    relativePoint = current.relativePoint or "CENTER",
                    offsetX = current.x or 0,
                    offsetY = current.y or 0,
                })
            end
            ReleaseAnchor(unitKey)
        else
            Anchoring:ApplyAnchor(unitKey)
        end
    end
    editModeStartPositions = {}
end

local function HookEditMode()
    if useLibEditMode or editModeHooked then return end
    local EditModeManagerFrame = _G.EditModeManagerFrame
    if EditModeManagerFrame then
        EditModeManagerFrame:HookScript("OnShow", OnEditModeEnter)
        EditModeManagerFrame:HookScript("OnHide", OnEditModeSave)
    end
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "EDIT_MODE_LAYOUTS_UPDATED" then
            OnEditModeSave()
        end
    end)
    local C_EditMode = _G.C_EditMode
    if C_EditMode and C_EditMode.SaveLayouts then
        hooksecurefunc(C_EditMode, "SaveLayouts", OnEditModeSave)
    end
    editModeHooked = true
end

function Anchoring:Cleanup()
    if combatEventFrame then
        combatEventFrame:UnregisterAllEvents()
        combatEventFrame:SetScript("OnEvent", nil)
        combatEventFrame = nil
        combatEventRegistered = false
    end
    combatApplyQueue = {}

    for _, unitKey in ipairs({ "player", "target", "focus" }) do
        ReleaseAnchor(unitKey)
    end
end

function Anchoring:Initialize()
    self:UpdateAnchors()
    HookEditMode()
end

module.Anchoring = Anchoring
