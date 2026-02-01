local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local LibEditMode = LibStub("LibEditMode", true)
local useLibEditMode = LibEditMode and LibEditMode.AddFrame

local M = TavernUI:NewModule("Anchoring")

local POSITION_CHANGE_THRESHOLD = 1
local EDIT_OVERLAY_LEVEL_OFFSET = 500
local SELECTION_FRAME_LEVEL_OFFSET = 600
local EDIT_OVERLAY_BORDER = 2
local EDIT_OVERLAY_FILL_ALPHA = 0.2
local NUDGE_STEP = 5

local VALID_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local anchors = {}
local frames = {}
local optionsById = {}
local lastAppliedConfig = {}
local registered = {}
local overlays = {}
local combatApplyQueue = {}
local combatEventRegistered = false
local editModeStartPositions = {}
local editModeHooked = false
local screenAnchorRegistered = false

local function RegistryRegister(name, frame, metadata)
    if not name or type(name) ~= "string" or name == "" then return false end
    if not frame or not frame.SetPoint then return false end
    metadata = metadata or {}
    anchors[name] = { frame = frame, metadata = metadata }
    return true
end

local function RegistryUnregister(name)
    if not name or type(name) ~= "string" then return false end
    anchors[name] = nil
    return true
end

function M:Get(anchorName)
    if not anchorName or type(anchorName) ~= "string" then return nil, nil end
    local data = anchors[anchorName]
    if not data then return nil, nil end
    return data.frame, data.metadata
end

function M:GetAll()
    local result = {}
    for name, data in pairs(anchors) do
        result[name] = { frame = data.frame, metadata = data.metadata }
    end
    return result
end

local function ToNum(v)
    return tonumber(v) or 0
end

local function GetFramePosition(frame)
    if not frame or not frame.GetPoint then return nil end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then return nil end
    local relativeToName = nil
    if relativeTo then
        if relativeTo.GetName then relativeToName = relativeTo:GetName()
        elseif relativeTo == UIParent then relativeToName = "UIParent" end
    end
    return { point = point, relativeToName = relativeToName, relativePoint = relativePoint, x = ToNum(x), y = ToNum(y) }
end

local function HasPositionChanged(id, startPos)
    if not startPos then return false end
    local frame = frames[id]
    if not frame then return false end
    local current = GetFramePosition(frame)
    if not current then return true end
    if math.abs(current.x - startPos.x) > POSITION_CHANGE_THRESHOLD or math.abs(current.y - startPos.y) > POSITION_CHANGE_THRESHOLD then return true end
    return current.point ~= startPos.point or current.relativePoint ~= startPos.relativePoint or current.relativeToName ~= startPos.relativeToName
end

local function ShouldApplyAnchor(id)
    local opts = optionsById[id]
    if not opts or not opts.getConfig then return false end
    local config = opts.getConfig(id)
    if not config or not config.target or config.target == "" or config.target == "UIParent" then return false end
    return true
end

local function ConfigMatches(id, config)
    local last = lastAppliedConfig[id]
    if not last then return false end
    return last.target == (config.target or "") and (last.point or "CENTER") == (config.point or "CENTER") and (last.relativePoint or "CENTER") == (config.relativePoint or "CENTER") and (last.offsetX or 0) == (config.offsetX or 0) and (last.offsetY or 0) == (config.offsetY or 0)
end

local function SetFrameDraggable(frame, enable)
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

local function ApplyPixelAnchor(frame, point, relativeTo, relativePoint, offsetX, offsetY)
    if not frame or not frame.ClearAllPoints then return end
    frame:ClearAllPoints()
    frame:SetPoint(point or "CENTER", relativeTo, relativePoint or "CENTER", ToNum(offsetX), ToNum(offsetY))
end

function M:ApplyAnchor(id)
    local frame = frames[id]
    local opts = optionsById[id]
    if not frame or not opts or not opts.getConfig then return end
    local config = opts.getConfig(id)
    if not config or not config.target or config.target == "" then
        lastAppliedConfig[id] = nil
        return
    end

    if InCombatLockdown() and frame:IsProtected() then
        combatApplyQueue[id] = true
        if not combatEventRegistered then
            combatEventRegistered = true
            local ef = CreateFrame("Frame")
            ef:RegisterEvent("PLAYER_REGEN_ENABLED")
            ef:SetScript("OnEvent", function(_, event)
                if event == "PLAYER_REGEN_ENABLED" then
                    for key, _ in pairs(combatApplyQueue) do
                        combatApplyQueue[key] = nil
                        M:ApplyAnchor(key)
                    end
                end
            end)
        end
        return
    end

    local point = (config.point and VALID_POINTS[config.point]) and config.point or "CENTER"
    local relativePoint = (config.relativePoint and VALID_POINTS[config.relativePoint]) and config.relativePoint or "CENTER"
    local offsetX = config.offsetX or 0
    local offsetY = config.offsetY or 0

    if config.target == "UIParent" then
        ApplyPixelAnchor(frame, point, UIParent, relativePoint, offsetX, offsetY)
        lastAppliedConfig[id] = { target = "UIParent", point = point, relativePoint = relativePoint, offsetX = offsetX, offsetY = offsetY }
        if opts.afterApplyAnchor then opts.afterApplyAnchor(id) end
        return
    end

    if ConfigMatches(id, config) then return end

    local targetData = anchors[config.target]
    local relativeTo = (targetData and targetData.frame) or UIParent
    if not targetData then
        relativePoint = point
    end

    ApplyPixelAnchor(frame, point, relativeTo, relativePoint, offsetX, offsetY)
    lastAppliedConfig[id] = { target = config.target, point = point, relativePoint = relativePoint, offsetX = offsetX, offsetY = offsetY }
    if opts.afterApplyAnchor then opts.afterApplyAnchor(id) end
end

local function NudgeAndApply(id, dx, dy)
    local opts = optionsById[id]
    if not opts or not opts.getConfig or not opts.setConfig then return end
    local config = opts.getConfig(id) or {}
    if not config.target or config.target == "" then
        config.target = "UIParent"
        config.point = "CENTER"
        config.relativePoint = "CENTER"
        config.offsetX = 0
        config.offsetY = 0
    end
    config.offsetX = (config.offsetX or 0) + dx
    config.offsetY = (config.offsetY or 0) + dy
    opts.setConfig(id, config)
    M:ApplyAnchor(id)
    if opts.afterSetConfig then opts.afterSetConfig(id) end
end

local function UpdateOverlayInfo(overlay, id)
    if not overlay.infoLabel then return end
    local frame = frames[id]
    if not frame then return end
    local w, h = frame:GetSize()
    local pos = GetFramePosition(frame)
    if not pos then overlay.infoLabel:SetText(string.format("%dx%d", w or 0, h or 0)); return end
    overlay.infoLabel:SetText(string.format("%dx%d | %s %.0f, %.0f", w or 0, h or 0, pos.point or "CENTER", pos.x or 0, pos.y or 0))
end

local NUDGE_BTN_SIZE = 18
local NUDGE_CHEVRON_SIZE = 7
local NUDGE_CHEVRON_THICK = 2

local function GetEditOverlayTheme()
    local Skins = TavernUI:GetModule("Skins", true)
    local Theme = Skins and Skins.Theme
    if Theme then
        local accent = Theme.accentColor or Theme.borderColor or { r = 0.82, g = 0.82, b = 0.82, a = 1 }
        local w = Theme.borderWidth or EDIT_OVERLAY_BORDER
        return accent.r, accent.g, accent.b, w
    end
    return 0.82, 0.82, 0.82, EDIT_OVERLAY_BORDER
end

local function CreateNudgeButton(overlay, id, direction)
    local dx = (direction == "L" and -1 or direction == "R" and 1 or 0) * NUDGE_STEP
    local dy = (direction == "D" and -1 or direction == "U" and 1 or 0) * NUDGE_STEP
    local btn = CreateFrame("Button", nil, overlay, "BackdropTemplate")
    btn:SetSize(NUDGE_BTN_SIZE, NUDGE_BTN_SIZE)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    btn:SetBackdropColor(0.1, 0.1, 0.1, 0.7)
    local r, g, b = GetEditOverlayTheme()
    btn:SetBackdropBorderColor(r, g, b, 1)

    local line1 = btn:CreateTexture(nil, "ARTWORK")
    line1:SetColorTexture(1, 1, 1, 0.9)
    line1:SetSize(NUDGE_CHEVRON_SIZE, NUDGE_CHEVRON_THICK)
    local line2 = btn:CreateTexture(nil, "ARTWORK")
    line2:SetColorTexture(1, 1, 1, 0.9)
    line2:SetSize(NUDGE_CHEVRON_SIZE, NUDGE_CHEVRON_THICK)

    if direction == "D" then
        line1:SetPoint("CENTER", btn, "CENTER", -2, 1)
        line1:SetRotation(math.rad(-45))
        line2:SetPoint("CENTER", btn, "CENTER", 2, 1)
        line2:SetRotation(math.rad(45))
    elseif direction == "U" then
        line1:SetPoint("CENTER", btn, "CENTER", -2, -1)
        line1:SetRotation(math.rad(45))
        line2:SetPoint("CENTER", btn, "CENTER", 2, -1)
        line2:SetRotation(math.rad(-45))
    elseif direction == "L" then
        line1:SetPoint("CENTER", btn, "CENTER", 1, -2)
        line1:SetRotation(math.rad(-45))
        line2:SetPoint("CENTER", btn, "CENTER", 1, 2)
        line2:SetRotation(math.rad(45))
    else
        line1:SetPoint("CENTER", btn, "CENTER", -1, -2)
        line1:SetRotation(math.rad(45))
        line2:SetPoint("CENTER", btn, "CENTER", -1, 2)
        line2:SetRotation(math.rad(-45))
    end

    btn.line1 = line1
    btn.line2 = line2

    btn:SetScript("OnEnter", function(self)
        self.line1:SetVertexColor(1, 0.8, 0, 1)
        self.line2:SetVertexColor(1, 0.8, 0, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self.line1:SetVertexColor(1, 1, 1, 0.9)
        self.line2:SetVertexColor(1, 1, 1, 0.9)
    end)
    btn:SetScript("OnClick", function()
        NudgeAndApply(id, dx, dy)
        UpdateOverlayInfo(overlay, id)
    end)
    return btn
end

local function CreateEditOverlay(id, frame)
    if overlays[id] then return overlays[id] end
    local opts = optionsById[id]
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetFrameLevel(frame:GetFrameLevel() + EDIT_OVERLAY_LEVEL_OFFSET)
    overlay:SetFrameStrata("TOOLTIP")
    local contentW, contentH = opts and opts.getContentSize and opts.getContentSize(id)
    if contentW and contentH and contentW > 0 and contentH > 0 and frame then
        overlay:SetSize(contentW, contentH)
        overlay:ClearAllPoints()
        overlay:SetPoint("CENTER", frame, "CENTER", 0, 0)
    else
        overlay:SetAllPoints(frame)
    end
    overlay:EnableMouse(false)
    overlay.anchorId = id

    local r, g, b, edgeSize = GetEditOverlayTheme()
    local fill = overlay:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(r, g, b, EDIT_OVERLAY_FILL_ALPHA)
    local left = overlay:CreateTexture(nil, "BORDER")
    left:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 0)
    left:SetWidth(edgeSize)
    left:SetColorTexture(r, g, b, 1)
    local right = overlay:CreateTexture(nil, "BORDER")
    right:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(edgeSize)
    right:SetColorTexture(r, g, b, 1)
    local top = overlay:CreateTexture(nil, "BORDER")
    top:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    top:SetPoint("TOPRIGHT", right, "TOPLEFT", 0, 0)
    top:SetHeight(edgeSize)
    top:SetColorTexture(r, g, b, 1)
    local bottom = overlay:CreateTexture(nil, "BORDER")
    bottom:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
    bottom:SetHeight(edgeSize)
    bottom:SetColorTexture(r, g, b, 1)

    local infoLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoLabel:SetPoint("TOP", overlay, "TOP", 0, -4)
    infoLabel:SetJustifyH("CENTER")
    overlay.infoLabel = infoLabel

    local nudgeUp = CreateNudgeButton(overlay, id, "U")
    nudgeUp:SetPoint("BOTTOM", overlay, "TOP", 0, 4)
    local nudgeDown = CreateNudgeButton(overlay, id, "D")
    nudgeDown:SetPoint("TOP", overlay, "BOTTOM", 0, -4)
    local nudgeLeft = CreateNudgeButton(overlay, id, "L")
    nudgeLeft:SetPoint("RIGHT", overlay, "LEFT", -4, 0)
    local nudgeRight = CreateNudgeButton(overlay, id, "R")
    nudgeRight:SetPoint("LEFT", overlay, "RIGHT", 4, 0)

    overlays[id] = overlay
    return overlay
end

local function ShowAllEditOverlays()
    if not useLibEditMode then return end
    for id in pairs(registered) do
        local opts = optionsById[id]
        if opts and opts.onEditModeEnter then opts.onEditModeEnter(id) end
    end
    for id in pairs(registered) do
        local frame = frames[id]
        if frame and frame:IsShown() then
            local overlay = CreateEditOverlay(id, frame)
            local opts = optionsById[id]
            local contentW, contentH = opts and opts.getContentSize and opts.getContentSize(id)
            if contentW and contentH and contentW > 0 and contentH > 0 and frame then
                overlay:SetSize(contentW, contentH)
                overlay:ClearAllPoints()
                overlay:SetPoint("CENTER", frame, "CENTER", 0, 0)
            else
                overlay:SetAllPoints(frame)
            end
            UpdateOverlayInfo(overlay, id)
            overlay:Show()
        end
    end
end

local function HideAllEditOverlays()
    for _, overlay in pairs(overlays) do overlay:Hide() end
end

local function PersistAllPositionsOnExit()
    if not useLibEditMode then return end
    for id in pairs(registered) do
        local frame = frames[id]
        local opts = optionsById[id]
        if frame and opts and opts.setConfig and frame:GetPoint(1) then
            local pos = GetFramePosition(frame)
            if pos then
                local target = (pos.relativeToName and pos.relativeToName ~= "" and pos.relativeToName ~= "UIParent") and pos.relativeToName or "UIParent"
                opts.setConfig(id, {
                    target = target,
                    point = pos.point or "CENTER",
                    relativePoint = pos.relativePoint or "CENTER",
                    offsetX = ToNum(pos.x),
                    offsetY = ToNum(pos.y),
                })
                M:ApplyAnchor(id)
                if opts.afterSetConfig then opts.afterSetConfig(id) end
            end
        end
    end
end

function M:Register(id, frame, opts)
    if not frame or not opts or not opts.displayName or not opts.anchorName or not opts.category or not opts.getConfig or not opts.setConfig then return end
    frames[id] = frame
    optionsById[id] = opts
    frame.anchorId = id

    RegistryRegister(opts.anchorName, frame, { displayName = opts.displayName, category = opts.category })

    if useLibEditMode and not registered[id] and opts.addToEditMode ~= false then
        local pos = GetFramePosition(frame)
        local default = pos and { point = pos.point or "CENTER", x = ToNum(pos.x), y = ToNum(pos.y) } or { point = "CENTER", x = 0, y = -180 }
        LibEditMode:AddFrame(frame, function(f, layoutName, point, x, y)
            local key = f.anchorId
            if not key then return end
            local o = optionsById[key]
            if not o then return end
            local newConfig = {
                target = "UIParent",
                point = point or "CENTER",
                relativePoint = point or "CENTER",
                offsetX = ToNum(x),
                offsetY = ToNum(y),
            }
            o.setConfig(key, newConfig)
            M:ApplyAnchor(key)
            if o.afterSetConfig then o.afterSetConfig(key) end
        end, default, opts.displayName)
        local sel = LibEditMode.frameSelections and LibEditMode.frameSelections[frame]
        if sel then sel:SetFrameLevel(frame:GetFrameLevel() + SELECTION_FRAME_LEVEL_OFFSET) end
        registered[id] = true
    end
    M:ApplyAnchor(id)
end

function M:Unregister(id, anchorName)
    if not id then return end
    lastAppliedConfig[id] = nil
    registered[id] = nil
    if overlays[id] then overlays[id]:Hide(); overlays[id] = nil end
    local frame = frames[id]
    frames[id] = nil
    optionsById[id] = nil
    if useLibEditMode and frame and LibEditMode and LibEditMode.frameSelections then
        LibEditMode.frameSelections[frame] = nil
        LibEditMode.frameCallbacks[frame] = nil
        LibEditMode.frameDefaults[frame] = nil
        if LibEditMode.frameSettings then LibEditMode.frameSettings[frame] = nil end
        if LibEditMode.frameButtons then LibEditMode.frameButtons[frame] = nil end
    end
    if anchorName then RegistryUnregister(anchorName) end
end

function M:Refresh(id)
    local EditModeManagerFrame = _G.EditModeManagerFrame
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return end
    if ShouldApplyAnchor(id) then M:ApplyAnchor(id) else lastAppliedConfig[id] = nil end
end

function M:ClearLayoutPosition(id)
    local opts = optionsById[id]
    if not opts or not opts.setConfig then return end
    opts.setConfig(id, {})
    lastAppliedConfig[id] = nil
end

function M:IsEditModeActive()
    local em = _G.EditModeManagerFrame
    return em and em:IsShown()
end

function M:GetFrame(id)
    return frames[id]
end

local function OnEditModeEnter()
    if useLibEditMode then return end
    editModeStartPositions = {}
    for id, frame in pairs(frames) do
        if frame and registered[id] then
            editModeStartPositions[id] = GetFramePosition(frame)
        end
    end
    for id, frame in pairs(frames) do
        if frame and not registered[id] then
            lastAppliedConfig[id] = nil
            frame:ClearAllPoints()
            local cx, cy = frame:GetCenter()
            local px, py = UIParent:GetCenter()
            if cx and cy and px and py then
                frame:SetPoint("CENTER", UIParent, "CENTER", ToNum(cx) - ToNum(px), ToNum(cy) - ToNum(py))
            else
                frame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
            end
            SetFrameDraggable(frame, true)
            if not editModeStartPositions[id] then editModeStartPositions[id] = GetFramePosition(frame) end
        end
    end
end

local function OnEditModeSave()
    if useLibEditMode then return end
    for id, frame in pairs(frames) do
        if frame and not registered[id] then SetFrameDraggable(frame, false) end
    end
    for id, startPos in pairs(editModeStartPositions) do
        if HasPositionChanged(id, startPos) then
            local frame = frames[id]
            local pos = frame and GetFramePosition(frame)
            if pos then
                local opts = optionsById[id]
                if opts and opts.setConfig then
                    local target = (pos.relativeToName and pos.relativeToName ~= "" and pos.relativeToName ~= "UIParent") and pos.relativeToName or "UIParent"
                    opts.setConfig(id, {
                        target = target,
                        point = pos.point or "CENTER",
                        relativePoint = pos.relativePoint or "CENTER",
                        offsetX = pos.x or 0,
                        offsetY = pos.y or 0,
                    })
                    if opts.afterSetConfig then opts.afterSetConfig(id) end
                end
                lastAppliedConfig[id] = nil
            end
        else
            M:ApplyAnchor(id)
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
    editModeHooked = true
end

local BLIZZARD_SCREEN_ANCHOR = "UIWidgetCenterScreenContainerFrame"

local function RegisterScreenAnchor()
    if screenAnchorRegistered then return end
    if not UIParent then return end
    screenAnchorRegistered = true
    local blizzardFrame = _G[BLIZZARD_SCREEN_ANCHOR]
    if blizzardFrame then
        RegistryRegister(BLIZZARD_SCREEN_ANCHOR, blizzardFrame, { displayName = "Screen", category = "screen" })
        return
    end
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", function(_, event, addonName)
        if addonName ~= "Blizzard_UIWidgets" then return end
        eventFrame:UnregisterEvent("ADDON_LOADED")
        local frame = _G[BLIZZARD_SCREEN_ANCHOR]
        if frame then
            RegistryRegister(BLIZZARD_SCREEN_ANCHOR, frame, { displayName = "Screen", category = "screen" })
        end
    end)
end

function M:OnEnable()
    RegisterScreenAnchor()
    HookEditMode()
    if useLibEditMode and LibEditMode then
        LibEditMode:RegisterCallback("enter", ShowAllEditOverlays)
        LibEditMode:RegisterCallback("exit", function()
            PersistAllPositionsOnExit()
            HideAllEditOverlays()
        end)
    end
end

function M:Initialize()
end
