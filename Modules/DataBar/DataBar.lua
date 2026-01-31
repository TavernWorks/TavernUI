-- TavernUI DataBar Module

local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("DataBar", "AceEvent-3.0")

local LibSharedMedia = LibStub("LibSharedMedia-3.0", true)
local Anchor = LibStub("LibAnchorRegistry-1.0", true)
local LibEditMode = LibStub("LibEditMode", true)
local useLibEditMode = LibEditMode and LibEditMode.AddFrame

local defaults = {
    bars = {},
    nextBarId = 1,
}

local defaultBarSettings = {
    width = 200,
    height = 40,
    background = {type = "solid", color = {r = 0.067, g = 0.067, b = 0.067}, opacity = 1, texture = nil},
    borders = {
        top = {enabled = true, color = {r = 1, g = 1, b = 1}, width = 1},
        bottom = {enabled = true, color = {r = 1, g = 1, b = 1}, width = 1},
        left = {enabled = true, color = {r = 1, g = 1, b = 1}, width = 1},
        right = {enabled = true, color = {r = 1, g = 1, b = 1}, width = 1},
    },
    textColor = {r = 1, g = 1, b = 1},
    useClassColor = false,
    labelColor = {r = 0.7, g = 0.7, b = 0.7},
    useLabelClassColor = false,
    font = nil,
    fontSize = 12,
    growthDirection = "horizontal",
    spacing = 4,
    anchorConfig = nil,
}

TavernUI:RegisterModuleDefaults("DataBar", defaults, false)

local datatextRegistry = {}

function module:RegisterDatatext(name, config)
    config = config or {}
    datatextRegistry[name] = {
        name = name,
        update = config.update,
        events = config.events,
        pollInterval = config.pollInterval,
        tooltip = config.tooltip,
        onClick = config.onClick,
        getColor = config.getColor,
        label = config.label or name,
        labelShort = config.labelShort,
        options = config.options,
        onScroll = config.onScroll,
        eventDelay = config.eventDelay,
    }
    self.datatextListDirty = true
end

function module:GetDatatext(name)
    return datatextRegistry[name]
end

function module:GetAllDatatexts()
    return datatextRegistry
end

function module:OnInitialize()
    self.frames = {}
    self.barFrames = {}
    self.slotFrames = {}
    self.slotTexts = {}
    self.anchorHandles = {}
    self.anchorNames = {}
    self.slotAnchorHandles = {}
    self.editModeFrames = {}
    self.optionsBuilt = false
    self.playerName = nil
    self.playerFullName = nil
    self.playerGUID = nil

    self:RegisterMessage("TavernUI_ProfileChanged", "OnProfileChanged")

    self:WatchSetting("enabled", function(newValue)
        if newValue then
            self:Enable()
        else
            self:Disable()
        end
    end)

    self:RegisterOptions()

    self:Debug("DataBar initialized")
end

function module:RegisterFrame(name, frame)
    self.frames[name] = frame
end

function module:GetFrame(name)
    return self.frames[name]
end

function module:OnEnable()
    local bars = self:GetSetting("bars", {})

    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    local playerName = UnitName("player")
    local playerRealm = GetRealmName()
    if playerName then
        self.playerName = playerName
        self.playerFullName = playerName .. "-" .. (playerRealm or "")
    end

    if Anchor then
        local minimap = _G["Minimap"]
        if minimap and not minimap:IsForbidden() then
            Anchor:Register("Blizzard.Minimap", minimap, {
                displayName = "Minimap",
                category = "blizzard",
            })
        end
    end

    for barId, bar in pairs(bars) do
        if bar.enabled then
            self:CreateBarFrame(barId, bar)
        end
    end

    self:StartUpdates()
    self:RefreshAllSlots()

    self:Debug("DataBar enabled")
end

function module:OnDisable()
    self:StopUpdates()

    for barId in pairs(self.barFrames) do
        self:DestroyBar(barId)
    end

    if Anchor then
        Anchor:Unregister("Blizzard.Minimap")
    end

    self:UnregisterAllEvents()
    self:Debug("DataBar disabled")
end

function module:OnProfileChanged()
    self:Debug("Profile changed, recreating bars")

    for barId in pairs(self.barFrames) do
        self:DestroyBar(barId)
    end

    if self:IsEnabled() then
        local bars = self:GetSetting("bars", {})
        for barId, bar in pairs(bars) do
            if bar.enabled then
                self:CreateBarFrame(barId, bar)
            end
        end
    end
end

function module:FormatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(num)
    end
end

function module:FormatMemory(kb)
    if kb >= 1024 then
        return string.format("%.1f MB", kb / 1024)
    else
        return string.format("%.0f KB", kb)
    end
end

function module:PLAYER_ENTERING_WORLD()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")

    local playerName = UnitName("player")
    local playerRealm = GetRealmName()
    if playerName then
        self.playerName = playerName
        self.playerFullName = playerName .. "-" .. (playerRealm or "")
        self.playerGUID = UnitGUID("player")
    end

    local bars = self:GetSetting("bars", {})
    for barId, bar in pairs(bars) do
        if bar.enabled and self.barFrames[barId] then
            self:UpdateBar(barId)
        end
    end

    self:RefreshAllSlots()
end

function module:CreateBar(name)
    local bars = self:GetSetting("bars", {})
    local nextBarId = self:GetSetting("nextBarId", 1)

    local barId = nextBarId

    local bar = {
        id = barId,
        name = name or ("Bar " .. barId),
        enabled = true,
        slots = {},
    }

    for k, v in pairs(defaultBarSettings) do
        if type(v) == "table" then
            bar[k] = CopyTable(v)
        else
            bar[k] = v
        end
    end

    self:SetSetting(string.format("bars[%d]", barId), bar)
    self:SetSetting("nextBarId", nextBarId + 1)

    if self:IsEnabled() then
        self:CreateBarFrame(barId, bar)
    end

    return barId
end

function module:DeleteBar(barId)
    self:DestroyBar(barId)
    self:SetSetting(string.format("bars[%d]", barId), nil)
end

function module:GetBar(barId)
    local bars = self:GetSetting("bars", {})
    return bars[barId]
end

function module:GetAllBars()
    return self:GetSetting("bars", {})
end

function module:CreateBarFrame(barId, bar)
    if self.barFrames[barId] then
        return
    end

    local frame = CreateFrame("Frame", "TavernUI_DataBar_" .. barId, UIParent)
    frame:SetSize(bar.width, bar.height)

    self.barFrames[barId] = frame
    self:RegisterFrame("bar" .. barId, frame)
    self.slotFrames[barId] = {}
    self.slotTexts[barId] = {}
    self.slotAnchorHandles[barId] = {}

    if Anchor then
        local anchorName = "TavernUI.DataBar" .. barId
        Anchor:Register(anchorName, frame, {
            displayName = bar.name,
            category = "bars",
        })
        self.anchorNames[barId] = anchorName

        if bar.anchorConfig and bar.anchorConfig.target then
            local target = bar.anchorConfig.target

            if target == "UIParent" or target == "" then
                local point = bar.anchorConfig.point or "CENTER"
                local relativePoint = bar.anchorConfig.relativePoint or "CENTER"
                local offsetX = bar.anchorConfig.offsetX or 0
                local offsetY = bar.anchorConfig.offsetY or 0
                frame:SetPoint(point, UIParent, relativePoint, offsetX, offsetY)
            else
                local config = {
                    target = target,
                    point = bar.anchorConfig.point or "CENTER",
                    relativePoint = bar.anchorConfig.relativePoint or "CENTER",
                    offsetX = bar.anchorConfig.offsetX or 0,
                    offsetY = bar.anchorConfig.offsetY or 0,
                    fallback = "UIParent",
                    fallbackPoint = "CENTER",
                }
                local handle = Anchor:AnchorTo(frame, config)
                self.anchorHandles[barId] = handle
            end
        else
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    self:UpdateBarStyling(barId, bar)
    self:UpdateBarSlots(barId, bar)

    if useLibEditMode then
        local anchorCfg = bar.anchorConfig
        local default = anchorCfg and {
            point = anchorCfg.point or "CENTER",
            x = anchorCfg.offsetX or 0,
            y = anchorCfg.offsetY or 0,
        } or { point = "CENTER", x = 0, y = 0 }

        LibEditMode:AddFrame(frame, function(f, layoutName, point, x, y)
            local id = f.barId
            if not id then return end
            local b = self:GetBar(id)
            if not b then return end
            if not b.anchorConfig then
                b.anchorConfig = {}
            end
            b.anchorConfig.target = "UIParent"
            b.anchorConfig.point = point
            b.anchorConfig.relativePoint = point
            b.anchorConfig.offsetX = x
            b.anchorConfig.offsetY = y
            self:UpdateBar(id)
        end, default, bar.name or ("DataBar " .. barId))
        frame.barId = barId
        self.editModeFrames[barId] = frame
    end
end

function module:DestroyBar(barId)
    if not self.barFrames[barId] then
        return
    end

    if self.anchorHandles[barId] then
        self.anchorHandles[barId]:Release()
        self.anchorHandles[barId] = nil
    end

    if Anchor and self.anchorNames[barId] then
        Anchor:Unregister(self.anchorNames[barId])
        self.anchorNames[barId] = nil
    end

    if useLibEditMode and self.editModeFrames[barId] then
        local f = self.editModeFrames[barId]
        LibEditMode.frameSelections[f] = nil
        LibEditMode.frameCallbacks[f] = nil
        LibEditMode.frameDefaults[f] = nil
        if LibEditMode.frameSettings then LibEditMode.frameSettings[f] = nil end
        if LibEditMode.frameButtons then LibEditMode.frameButtons[f] = nil end
        self.editModeFrames[barId] = nil
    end

    for slotIndex, slotFrame in pairs(self.slotFrames[barId] or {}) do
        self:UnregisterSlotUpdates(barId, slotIndex)
        if slotFrame then
            slotFrame:Hide()
            slotFrame:SetParent(nil)
        end
    end

    if self.barFrames[barId] then
        self.barFrames[barId]:Hide()
        self.barFrames[barId]:SetParent(nil)
    end

    self.barFrames[barId] = nil
    self.slotFrames[barId] = nil
    self.slotTexts[barId] = nil
    self.slotAnchorHandles[barId] = nil
end

function module:UpdateBar(barId)
    local bar = self:GetBar(barId)
    if not bar then
        return
    end

    if not self.barFrames[barId] then
        if bar.enabled then
            self:CreateBarFrame(barId, bar)
        end
        return
    end

    local frame = self.barFrames[barId]

    if bar.enabled then
        self:Debug("UpdateBar: Showing bar %d with %d slots", barId, #bar.slots)
        frame:Show()
        frame:SetSize(bar.width, bar.height)
        self:UpdateBarPosition(barId, bar)
        self:UpdateBarStyling(barId, bar)
        self:UpdateBarSlots(barId, bar)
    else
        self:Debug("UpdateBar: Hiding bar %d", barId)
        frame:Hide()
    end
end

function module:UpdateBarPosition(barId, bar)
    local frame = self.barFrames[barId]
    if not frame then
        return
    end

    if not bar then
        bar = self:GetBar(barId)
    end

    if not bar then
        return
    end

    if useLibEditMode and LibEditMode:IsInEditMode() then
        return
    end

    if self.anchorHandles[barId] then
        self.anchorHandles[barId]:Release()
        self.anchorHandles[barId] = nil
    end

    if bar.anchorConfig and bar.anchorConfig.target then
        local target = bar.anchorConfig.target

        if bar.anchorConfig.useDualAnchor and bar.anchorConfig.target2 then
            local target2 = bar.anchorConfig.target2

            if (target == "UIParent" or target == "") and (target2 == "UIParent" or target2 == "") then
                frame:ClearAllPoints()
                local point1 = bar.anchorConfig.point or "LEFT"
                local relativePoint1 = bar.anchorConfig.relativePoint or "LEFT"
                local offsetX1 = bar.anchorConfig.offsetX or 0
                local offsetY1 = bar.anchorConfig.offsetY or 0
                local point2 = bar.anchorConfig.point2 or "RIGHT"
                local relativePoint2 = bar.anchorConfig.relativePoint2 or "RIGHT"
                local offsetX2 = bar.anchorConfig.offsetX2 or 0
                local offsetY2 = bar.anchorConfig.offsetY2 or 0

                frame:SetPoint(point1, UIParent, relativePoint1, offsetX1, offsetY1)
                frame:SetPoint(point2, UIParent, relativePoint2, offsetX2, offsetY2)
            elseif Anchor then
                local config = {
                    target = target,
                    point = bar.anchorConfig.point or "LEFT",
                    relativePoint = bar.anchorConfig.relativePoint or "LEFT",
                    offsetX = bar.anchorConfig.offsetX or 0,
                    offsetY = bar.anchorConfig.offsetY or 0,
                    target2 = target2,
                    point2 = bar.anchorConfig.point2 or "RIGHT",
                    relativePoint2 = bar.anchorConfig.relativePoint2 or "RIGHT",
                    offsetX2 = bar.anchorConfig.offsetX2 or 0,
                    offsetY2 = bar.anchorConfig.offsetY2 or 0,
                }

                local handle = Anchor:AnchorDual(frame, config)
                self.anchorHandles[barId] = handle
            else
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end
        elseif target == "UIParent" or target == "" then
            frame:ClearAllPoints()
            local point = bar.anchorConfig.point or "CENTER"
            local relativePoint = bar.anchorConfig.relativePoint or "CENTER"
            local offsetX = bar.anchorConfig.offsetX or 0
            local offsetY = bar.anchorConfig.offsetY or 0
            frame:SetPoint(point, UIParent, relativePoint, offsetX, offsetY)
        elseif Anchor then
            local config = {
                target = target,
                point = bar.anchorConfig.point or "CENTER",
                relativePoint = bar.anchorConfig.relativePoint or "CENTER",
                offsetX = bar.anchorConfig.offsetX or 0,
                offsetY = bar.anchorConfig.offsetY or 0,
                fallback = "UIParent",
                fallbackPoint = "CENTER",
            }
            local handle = Anchor:AnchorTo(frame, config)
            self.anchorHandles[barId] = handle
        else
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    else
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function module:UpdateBarStyling(barId, bar)
    local frame = self.barFrames[barId]
    if not frame then
        return
    end

    if not bar then
        bar = self:GetBar(barId)
    end

    if not bar then
        return
    end

    if not frame.bg then
        frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    end
    frame.bg:SetAllPoints(frame)
    local c = bar.background.color or {r = 0.067, g = 0.067, b = 0.067}
    local opacity = bar.background.opacity or 1

    if bar.background.type == "texture" and LibSharedMedia and bar.background.texture then
        local texturePath = LibSharedMedia:Fetch("statusbar", bar.background.texture)
        if texturePath then
            frame.bg:SetColorTexture(0, 0, 0, 0)
            frame.bg:SetTexture(texturePath)
            frame.bg:SetVertexColor(1, 1, 1, opacity)
        else
            frame.bg:SetTexture(nil)
            frame.bg:SetColorTexture(c.r, c.g, c.b, opacity)
        end
    else
        frame.bg:SetTexture(nil)
        frame.bg:SetColorTexture(c.r, c.g, c.b, opacity)
    end

    if not frame.borders then
        frame.borders = {}
    end

    for side, config in pairs(bar.borders) do
        if config.enabled then
            if not frame.borders[side] then
                frame.borders[side] = frame:CreateTexture(nil, "BORDER")
            end
            local border = frame.borders[side]
            local c = config.color
            border:SetColorTexture(c.r, c.g, c.b, 1)
            border:ClearAllPoints()

            if side == "top" then
                border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
                border:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
                border:SetHeight(config.width)
            elseif side == "bottom" then
                border:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
                border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
                border:SetHeight(config.width)
            elseif side == "left" then
                border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
                border:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
                border:SetWidth(config.width)
            elseif side == "right" then
                border:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
                border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
                border:SetWidth(config.width)
            end
            border:Show()
        elseif frame.borders[side] then
            frame.borders[side]:Hide()
        end
    end

    if self.slotTexts[barId] then
        for slotIndex, text in pairs(self.slotTexts[barId]) do
            if text and text:IsVisible() then
                self:UpdateSlotColor(barId, slotIndex, text)
            end
        end
    end
end
