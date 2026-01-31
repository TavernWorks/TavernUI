local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("ResourceBars")

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
local libEditModeRegisteredBars = {}
local combatApplyQueue = {}
local combatEventRegistered = false

local POSITION_CHANGE_THRESHOLD = 1
local EDIT_OVERLAY_BORDER_R, EDIT_OVERLAY_BORDER_G, EDIT_OVERLAY_BORDER_B = 0.2, 0.8, 1
local EDIT_OVERLAY_FILL_R, EDIT_OVERLAY_FILL_G, EDIT_OVERLAY_FILL_B, EDIT_OVERLAY_FILL_A = 0.2, 0.8, 1, 0.25

local function GetBarFrame(barId)
    return module.bars and module.bars[barId] or nil
end

local function SetBarAnchorConfig(barId, anchorConfig)
    if module:IsResourceBarType(barId) then
        module:SetSetting("resourceBarAnchorConfig", anchorConfig)
        for _, rid in ipairs(module:GetResourceBarIds()) do
            if module.bars and module.bars[rid] then
                Anchoring.ApplyAnchor(Anchoring, rid)
            end
        end
    elseif module:IsSpecialResourceType(barId) then
        module:SetSetting("specialResourceAnchorConfig", anchorConfig)
        for _, rid in ipairs(module:GetSpecialResourceBarIds()) do
            if module.bars and module.bars[rid] then
                Anchoring.ApplyAnchor(Anchoring, rid)
            end
        end
    else
        module:SetSetting("bars." .. barId .. "." .. module.CONSTANTS.KEY_ANCHOR_CONFIG, anchorConfig)
    end
end

local function GetBarPosition(barId)
    local frame = GetBarFrame(barId)
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

local function HasPositionChanged(barId, startPos)
    if not startPos then return false end
    local current = GetBarPosition(barId)
    if not current then return true end
    if math.abs(current.x - startPos.x) > POSITION_CHANGE_THRESHOLD or math.abs(current.y - startPos.y) > POSITION_CHANGE_THRESHOLD then
        return true
    end
    return current.point ~= startPos.point or current.relativePoint ~= startPos.relativePoint or current.relativeToName ~= startPos.relativeToName
end

local function ShouldApplyAnchor(barId)
    local config = module:GetBarConfig(barId)
    if not config or not config.anchorConfig then return false end
    local target = config.anchorConfig.target
    return target and target ~= ""
end

local function ReleaseAnchor(barId)
    local handle = anchorHandles[barId]
    if handle then
        if handle.Release then
            handle:Release()
        end
        anchorHandles[barId] = nil
    end
end

local function GetEditModeLayoutPositions()
    local db = module:GetDB()
    if not db.editModeLayoutPositions then db.editModeLayoutPositions = {} end
    return db.editModeLayoutPositions
end

function Anchoring:ClearLayoutPositionForBar(barId)
    if not useLibEditMode or not LibEditMode or not LibEditMode.GetActiveLayoutName then return end
    local layoutName = LibEditMode:GetActiveLayoutName()
    if not layoutName then return end
    local positions = GetEditModeLayoutPositions()
    if not positions[layoutName] then return end
    local key = module:IsSpecialResourceType(barId) and "SpecialResource" or (module:IsResourceBarType(barId) and "ResourceBar" or barId)
    positions[layoutName][key] = nil
end

local function SetBarDraggable(barId, frame, enable)
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

local function CreateNudgeButton(parent, direction, deltaX, deltaY, barId)
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
    btn:SetScript("OnEnter", function(self)
        line1:SetColorTexture(EDIT_OVERLAY_BORDER_R, EDIT_OVERLAY_BORDER_G, EDIT_OVERLAY_BORDER_B, 1)
        line2:SetColorTexture(EDIT_OVERLAY_BORDER_R, EDIT_OVERLAY_BORDER_G, EDIT_OVERLAY_BORDER_B, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        line1:SetColorTexture(1, 1, 1, 0.9)
        line2:SetColorTexture(1, 1, 1, 0.9)
    end)
    btn:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local frame = GetBarFrame(barId)
        if not frame or not frame.GetPoint then return end
        local pos = GetBarPosition(barId)
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
            positions[layoutName][barId] = { point = pos.point, x = newX, y = newY }
        end
        UpdateEditOverlayInfo(barId)
    end)
    return btn
end

function UpdateEditOverlayInfo(barId)
    local frame = GetBarFrame(barId)
    local overlay = frame and frame.editModeOverlay
    if not overlay or not overlay.infoText then return end
    local w = frame:GetWidth()
    local h = frame:GetHeight()
    local dimStr = (w and h) and ("%d x %d"):format(math.floor(w + 0.5), math.floor(h + 0.5)) or "?"
    local pos = GetBarPosition(barId)
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

local function CreateEditOverlay(barId, frame)
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
    local nudgeLeft = CreateNudgeButton(overlay, "LEFT", -1, 0, barId)
    nudgeLeft:SetPoint("RIGHT", overlay, "LEFT", -4, 0)
    local nudgeRight = CreateNudgeButton(overlay, "RIGHT", 1, 0, barId)
    nudgeRight:SetPoint("LEFT", overlay, "RIGHT", 4, 0)
    local infoText = TavernUI:CreateFontString(overlay, 12)
    infoText:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    infoText:SetTextColor(0.7, 0.7, 0.7, 1)
    overlay.infoText = infoText
    local nudgeUp = CreateNudgeButton(overlay, "UP", 0, 1, barId)
    nudgeUp:SetPoint("BOTTOM", overlay, "TOP", 0, 4)
    local nudgeDown = CreateNudgeButton(overlay, "DOWN", 0, -1, barId)
    nudgeDown:SetPoint("TOP", overlay, "BOTTOM", 0, -4)
    overlay:Hide()
    frame.editModeOverlay = overlay
end

function ShowEditOverlayForBar(barId)
    for bid, f in pairs(module.bars or {}) do
        if f and f.editModeOverlay then
            f.editModeOverlay:SetShown(bid == barId)
        end
    end
    UpdateEditOverlayInfo(barId)
end

function HideEditOverlayForBar(barId)
    local frame = GetBarFrame(barId)
    if frame and frame.editModeOverlay then
        frame.editModeOverlay:Hide()
    end
end

local RESOURCE_BAR_ANCHOR_NAME = "TavernUI.ResourceBars.ResourceBar"
local SPECIAL_RESOURCE_ANCHOR_NAME = "TavernUI.ResourceBars.SpecialResource"
local function GetMainBarAnchorName(barId)
    return "TavernUI.ResourceBars." .. barId
end
local MAIN_DISPLAY_NAMES = {
    HEALTH = "Health",
    PRIMARY_POWER = "Primary Power",
    ALTERNATE_POWER = "Alternate Power",
}

function Anchoring:RegisterBar(barId, frame)
    if not frame then return end
    
    if module:IsSpecialResourceType(barId) then
        Anchor:Register(SPECIAL_RESOURCE_ANCHOR_NAME, frame, {
            displayName = "Special Resource",
            category = "resourcebars",
        })
    elseif module:IsResourceBarType(barId) then
        Anchor:Register(RESOURCE_BAR_ANCHOR_NAME, frame, {
            displayName = "Resource Bar",
            category = "resourcebars",
        })
    else
        local name = GetMainBarAnchorName(barId)
        Anchor:Register(name, frame, {
            displayName = MAIN_DISPLAY_NAMES[barId] or barId,
            category = "resourcebars",
        })
    end
    if useLibEditMode then
        local displayName = module:IsSpecialResourceType(barId) and "Special Resource" or (module:IsResourceBarType(barId) and "Resource Bar" or (MAIN_DISPLAY_NAMES[barId] or barId))
        local defaultPos = GetBarPosition(barId)
        local default = defaultPos and { point = defaultPos.point or "CENTER", x = defaultPos.x or 0, y = defaultPos.y or 0 } or { point = "CENTER", x = 0, y = -180 }
        LibEditMode:AddFrame(frame, function(f, layoutName, point, x, y)
            local id = f.barId
            if not id then return end
            local key = module:IsSpecialResourceType(id) and "SpecialResource" or (module:IsResourceBarType(id) and "ResourceBar" or id)
            local positions = GetEditModeLayoutPositions()
            if not positions[layoutName] then positions[layoutName] = {} end
            positions[layoutName][key] = { point = point, x = x, y = y }
            local config = module:GetBarConfig(id)
            local ac = (config and config.anchorConfig and type(config.anchorConfig) == "table") and config.anchorConfig or {}
            local newConfig = {
                target = "UIParent",
                point = point,
                relativePoint = point,
                offsetX = x,
                offsetY = y,
            }
            SetBarAnchorConfig(id, newConfig)
            positions[layoutName][key] = nil
            if not module:IsResourceBarType(id) and not module:IsSpecialResourceType(id) then
                Anchoring:ApplyAnchor(id)
            end
        end, default, displayName)
        libEditModeRegisteredBars[barId] = true
        CreateEditOverlay(barId, frame)
        local sel = LibEditMode.frameSelections and LibEditMode.frameSelections[frame]
        if sel then
            sel:SetAlpha(0)
            local oldShow = sel.Show
            sel.Show = function(self)
                if oldShow then oldShow(self) end
                ShowEditOverlayForBar(barId)
            end
            local oldHide = sel.Hide
            sel.Hide = function(self)
                if oldHide then oldHide(self) end
                HideEditOverlayForBar(barId)
            end
        end
    end
end

local function IsEditModeShown()
    local em = _G.EditModeManagerFrame
    return em and em:IsShown()
end

local function ProcessCombatApplyQueue()
    local queue = combatApplyQueue
    combatApplyQueue = {}
    for barId, _ in pairs(queue) do
        Anchoring:ApplyAnchor(barId)
    end
end

function Anchoring:ApplyAnchor(barId)
    local frame = GetBarFrame(barId)
    if not frame then return end
    
    if InCombatLockdown() then
        combatApplyQueue[barId] = true
        if not combatEventRegistered then
            combatEventRegistered = true
            local ef = CreateFrame("Frame")
            ef:RegisterEvent("PLAYER_REGEN_ENABLED")
            ef:SetScript("OnEvent", function(_, event)
                if event == "PLAYER_REGEN_ENABLED" then
                    ProcessCombatApplyQueue()
                end
            end)
        end
        return
    end
    
    if useLibEditMode and libEditModeRegisteredBars[barId] then
        local layoutName = LibEditMode:GetActiveLayoutName()
        if layoutName then
            local positions = GetEditModeLayoutPositions()
            local key = module:IsSpecialResourceType(barId) and "SpecialResource" or (module:IsResourceBarType(barId) and "ResourceBar" or barId)
            local pos = positions[layoutName] and positions[layoutName][key]
            if pos and pos.point then
                ReleaseAnchor(barId)
                frame:ClearAllPoints()
                frame:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
                return
            end
        end
    end

    if not useLibEditMode and IsEditModeShown() then
        ReleaseAnchor(barId)
        frame:ClearAllPoints()
        local cx, cy = frame:GetCenter()
        local px, py = UIParent:GetCenter()
        if cx and cy and px and py then
            frame:SetPoint("CENTER", UIParent, "CENTER", math.floor(cx - px + 0.5), math.floor(cy - py + 0.5))
        else
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
        end
        SetBarDraggable(barId, frame, true)
        if not editModeStartPositions[barId] then
            editModeStartPositions[barId] = GetBarPosition(barId)
        end
        return
    end
    
    if not ShouldApplyAnchor(barId) then
        ReleaseAnchor(barId)
        return
    end
    
    local config = module:GetBarConfig(barId)
    local anchorConfig = config.anchorConfig
    
    ReleaseAnchor(barId)
    
    local handle = Anchor:AnchorTo(frame, {
        target = anchorConfig.target,
        point = anchorConfig.point or "CENTER",
        relativePoint = anchorConfig.relativePoint or "CENTER",
        offsetX = anchorConfig.offsetX or 0,
        offsetY = anchorConfig.offsetY or 0,
        deferred = false,
    })
    
    if handle then
        anchorHandles[barId] = handle
    else
        module:Debug("Failed to create anchor for " .. barId)
    end
end

function Anchoring:UnregisterBar(barId, frame)
    ReleaseAnchor(barId)
    if module:IsSpecialResourceType(barId) then
        Anchor:Unregister(SPECIAL_RESOURCE_ANCHOR_NAME)
    elseif module:IsResourceBarType(barId) then
        Anchor:Unregister(RESOURCE_BAR_ANCHOR_NAME)
    else
        Anchor:Unregister(GetMainBarAnchorName(barId))
    end
    libEditModeRegisteredBars[barId] = nil
    if useLibEditMode and frame and LibEditMode and LibEditMode.frameSelections then
        LibEditMode.frameSelections[frame] = nil
        LibEditMode.frameCallbacks[frame] = nil
        LibEditMode.frameDefaults[frame] = nil
        if LibEditMode.frameSettings then LibEditMode.frameSettings[frame] = nil end
        if LibEditMode.frameButtons then LibEditMode.frameButtons[frame] = nil end
    end
end

function Anchoring:UpdateAnchors()
    if not module:IsEnabled() then return end
    local EditModeManagerFrame = _G.EditModeManagerFrame
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        return
    end
    for barId, _ in pairs(module.bars or {}) do
        local frame = GetBarFrame(barId)
        if frame then
            self:RegisterBar(barId, frame)
            self:ApplyAnchor(barId)
        end
    end
end

local editModeStartPositions = {}
local editModeHooked = false

local function OnEditModeEnter()
    if useLibEditMode or not module:IsEnabled() then return end
    editModeStartPositions = {}
    for barId, frame in pairs(module.bars or {}) do
        if frame then
            editModeStartPositions[barId] = GetBarPosition(barId)
        end
    end
    for barId, frame in pairs(module.bars or {}) do
        if frame and not libEditModeRegisteredBars[barId] then
            ReleaseAnchor(barId)
            frame:ClearAllPoints()
            local cx, cy = frame:GetCenter()
            local px, py = UIParent:GetCenter()
            if cx and cy and px and py then
                frame:SetPoint("CENTER", UIParent, "CENTER", math.floor(cx - px + 0.5), math.floor(cy - py + 0.5))
            end
            SetBarDraggable(barId, frame, true)
        end
    end
end

local function OnEditModeSave()
    if useLibEditMode or not module:IsEnabled() then return end
    for barId, frame in pairs(module.bars or {}) do
        if frame and not libEditModeRegisteredBars[barId] then
            SetBarDraggable(barId, frame, false)
        end
    end
    for barId, startPos in pairs(editModeStartPositions) do
        if HasPositionChanged(barId, startPos) then
            local current = GetBarPosition(barId)
            if current then
                local target = (current.relativeToName and current.relativeToName ~= "") and current.relativeToName or "UIParent"
                local config = module:GetBarConfig(barId)
                local ac = (config and config.anchorConfig and type(config.anchorConfig) == "table") and config.anchorConfig or {}
                SetBarAnchorConfig(barId, {
                    target = target,
                    point = current.point or "CENTER",
                    relativePoint = current.relativePoint or "CENTER",
                    offsetX = current.x or 0,
                    offsetY = current.y or 0,
                })
            end
            ReleaseAnchor(barId)
        else
            Anchoring.ApplyAnchor(Anchoring, barId)
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

function Anchoring.RefreshBar(barId)
    if not module:IsEnabled() then return end
    local EditModeManagerFrame = _G.EditModeManagerFrame
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        return
    end
    if ShouldApplyAnchor(barId) then
        Anchoring.ApplyAnchor(Anchoring, barId)
    else
        ReleaseAnchor(barId)
    end
end

local SCREEN_ANCHOR_NAME = "TavernUI.Screen"
local screenAnchorFrame = nil
local screenAnchorRegistered = false

local function GetOrCreateScreenAnchorFrame()
    if screenAnchorFrame then return screenAnchorFrame end
    if not UIParent then return nil end
    local f = CreateFrame("Frame", "TavernUI_ScreenAnchor", UIParent)
    f:SetSize(10, 10)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetAlpha(0)
    f:EnableMouse(false)
    screenAnchorFrame = f
    return f
end

local function RegisterScreenAnchor()
    if not screenAnchorRegistered and Anchor then
        local frame = GetOrCreateScreenAnchorFrame()
        if frame then
            Anchor:Register(SCREEN_ANCHOR_NAME, frame, {
                displayName = "Screen",
                category = "screen",
            })
            screenAnchorRegistered = true
        end
    end
end

function Anchoring:Initialize()
    RegisterScreenAnchor()
    self:UpdateAnchors()
    HookEditMode()
end

module.Anchoring = Anchoring
