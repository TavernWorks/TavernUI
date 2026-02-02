local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("Minimap", "AceEvent-3.0")

local defaults = {
    shape = "SQUARE",
    size = 180,
    scale = 1.0,
    lock = false,
    position = nil,
    strata = "BACKGROUND",
    opacity = 1.0,
    opacityMoving = 1.0,
    opacityMounted = 1.0,

    borderSize = 3,
    borderColor = {r=0, g=0, b=0, a=1},
    useClassColorBorder = false,

    mouseWheelZoom = true,
    autoZoomOut = true,

    showZoneText = true,
    zoneText = {
        position = "TOP", font = "", fadeOut = false,
        fontSize = 12, offsetX = 0, offsetY = -2,
        allCaps = true, useClassColor = false,
        colorSanctuary = {r=0.41, g=0.80, b=0.94, a=1},
        colorArena     = {r=1.00, g=0.10, b=0.10, a=1},
        colorFriendly  = {r=0.10, g=1.00, b=0.10, a=1},
        colorHostile   = {r=1.00, g=0.10, b=0.10, a=1},
        colorContested = {r=1.00, g=0.70, b=0.00, a=1},
        colorNormal    = {r=1.00, g=0.82, b=0.00, a=1},
    },

    showCoords = true,
    coords = {
        position = "TOPRIGHT", font = "", fadeOut = false,
        fontSize = 12, precision = "%.1f, %.1f",
        updateInterval = 1, offsetX = -2, offsetY = -2,
        useClassColor = false, color = {r=1, g=1, b=1, a=1},
    },

    showClock = true,
    clock = {
        position = "TOPLEFT", font = "", fadeOut = false,
        fontSize = 12, timeSource = "local", use24Hour = true,
        offsetX = 2, offsetY = -2,
        useClassColor = false, color = {r=1, g=1, b=1, a=1},
    },

    buttons = {
        zoom             = { show = false, scale = 1.0, strata = "MEDIUM", point = "BOTTOMRIGHT", offsetX = 0, offsetY = 0, fadeOut = false },
        mail             = { show = true,  scale = 1.0, strata = "MEDIUM", point = "BOTTOMLEFT",  offsetX = 0, offsetY = 0, fadeOut = false },
        craftingOrder    = { show = true,  scale = 1.0, strata = "MEDIUM", point = "BOTTOMRIGHT", offsetX = 0, offsetY = 0, fadeOut = false },
        addonCompartment = { show = false, scale = 1.0, strata = "MEDIUM", point = "TOPRIGHT",    offsetX = 0, offsetY = 0, fadeOut = false },
        difficulty       = { show = true,  scale = 1.0, strata = "MEDIUM", point = "TOPLEFT",     offsetX = 0, offsetY = 0, fadeOut = false },
        missions         = { show = false, scale = 1.0, strata = "MEDIUM", point = "TOPLEFT",     offsetX = 0, offsetY = 0, fadeOut = false },
        calendar         = { show = false, scale = 1.0, strata = "MEDIUM", point = "TOPRIGHT",    offsetX = 0, offsetY = 0, fadeOut = false },
        tracking         = { show = true,  scale = 1.0, strata = "MEDIUM", point = "TOPLEFT",     offsetX = 0, offsetY = 0, fadeOut = false },
    },
    hideAddonButtons = false,

    dungeonEye = {
        enabled = true, corner = "BOTTOMRIGHT",
        scale = 0.8, offsetX = 0, offsetY = 0,
    },
}

TavernUI:RegisterModuleDefaults("Minimap", defaults, true)

--------------------------------------------------------------------------------
-- File-scope: Layout workaround, hidden parent, zoom button hooks
--------------------------------------------------------------------------------

local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()
hiddenParent.Layout = function() end

local function EnsureLayout(frame)
    if frame and not frame.Layout then
        frame.Layout = function() end
    end
end

EnsureLayout(Minimap)
if MinimapCluster and MinimapCluster.IndicatorFrame then
    EnsureLayout(MinimapCluster.IndicatorFrame)
end

-- HybridMinimap handler
local hybridFrame = CreateFrame("Frame")
hybridFrame:RegisterEvent("ADDON_LOADED")
hybridFrame:SetScript("OnEvent", function(_, _, addonName)
    if addonName == "Blizzard_HybridMinimap" then
        local mod = TavernUI:GetModule("Minimap", true)
        if mod and mod:IsEnabled() and mod._setupDone then
            mod:SetShape()
        end
    end
end)

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function module:OnInitialize()
    self:RegisterMessage("TavernUI_ProfileChanged", "OnProfileChanged")
    self:WatchSetting("coords.updateInterval", function()
        if self.Elements and self.Elements.RefreshCoordsTicker then
            self.Elements.RefreshCoordsTicker()
        end
    end)
end

function module:OnEnable()
    C_Timer.After(0.5, function()
        if self:IsEnabled() then
            self:SetupMinimap()
        end
    end)
end

function module:OnDisable()
    self:StopTickers()
end

function module:OnProfileChanged()
    if self:IsEnabled() and self._setupDone then
        self:RefreshAll()
    end
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

function module:SetupMinimap()
    if self._setupDone then
        self:RefreshAll()
        return
    end
    self._setupDone = true

    self:HideBlizzardDecorations()
    self:SetShape()
    self:CreateBackdrop()
    self:UpdateSize()
    self:SetupDragging()
    self:UpdatePosition()
    self:UpdateLock()
    self:SetupMouseWheelZoom()
    self:SetupAutoZoom()
    self:UpdateStrata()
    self:ApplyOpacity()
    self:SetupOpacityEvents()

    -- Delegate to Elements
    if self.Elements then
        self.Elements.Setup()
    end

    self:StartTickers()
end

function module:RefreshAll()
    if not self._setupDone then return end

    self:SetShape()
    self:UpdateBackdrop()
    self:UpdateSize()
    self:UpdatePosition()
    self:UpdateLock()
    self:SetupMouseWheelZoom()
    self:SetupAutoZoom()
    self:UpdateStrata()
    self:ApplyOpacity()

    if self.Elements then
        self.Elements.RefreshAll()
    end

    self:RestartTickers()
end

--------------------------------------------------------------------------------
-- Tickers
--------------------------------------------------------------------------------

function module:StartTickers()
    if self.Elements and self.Elements.StartTickers then
        self.Elements.StartTickers()
    end
end

function module:StopTickers()
    if self.Elements and self.Elements.StopTickers then
        self.Elements.StopTickers()
    end
end

function module:RestartTickers()
    self:StopTickers()
    self:StartTickers()
end

--------------------------------------------------------------------------------
-- Shape
--------------------------------------------------------------------------------

local SQUARE_MASK = "Interface\\ChatFrame\\ChatFrameBackground"
local ROUND_MASK  = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

function module:SetShape()
    local shape = self:GetSetting("shape", "SQUARE")

    if shape == "SQUARE" then
        Minimap:SetMaskTexture(SQUARE_MASK)
        _G.GetMinimapShape = function() return "SQUARE" end
    else
        Minimap:SetMaskTexture(ROUND_MASK)
        _G.GetMinimapShape = function() return "ROUND" end
    end

    -- HybridMinimap
    if HybridMinimap and HybridMinimap.MapCanvas then
        if shape == "SQUARE" then
            HybridMinimap.MapCanvas:SetMaskTexture(SQUARE_MASK)
        else
            HybridMinimap.MapCanvas:SetMaskTexture(ROUND_MASK)
        end
    end

    -- Suppress blob ring for square
    if shape == "SQUARE" then
        if Minimap.SetArchBlobRingScalar then
            Minimap:SetArchBlobRingScalar(0)
        end
        if Minimap.SetQuestBlobRingScalar then
            Minimap:SetQuestBlobRingScalar(0)
        end
    else
        if Minimap.SetArchBlobRingScalar then
            Minimap:SetArchBlobRingScalar(1)
        end
        if Minimap.SetQuestBlobRingScalar then
            Minimap:SetQuestBlobRingScalar(1)
        end
    end

    -- Update backdrop mask
    if self.backdropFrame then
        self:UpdateBackdrop()
    end

    -- Refresh LibDBIcon if available
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if LDBIcon then
        pcall(function() LDBIcon:Refresh() end)
    end
end

--------------------------------------------------------------------------------
-- Backdrop / Border
--------------------------------------------------------------------------------

function module:CreateBackdrop()
    if self.backdropFrame then return end

    local f = CreateFrame("Frame", "TavernUI_MinimapBackdrop", Minimap, "BackdropTemplate")
    f:SetFrameStrata("BACKGROUND")
    f:SetFrameLevel(0)
    self.backdropFrame = f

    self:UpdateBackdrop()
end

function module:UpdateBackdrop()
    local f = self.backdropFrame
    if not f then return end

    local borderSize = self:GetSetting("borderSize", 3)
    local borderColor = self:GetSetting("borderColor", {r=0, g=0, b=0, a=1})
    local useClassColor = self:GetSetting("useClassColorBorder", false)
    local shape = self:GetSetting("shape", "SQUARE")

    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -borderSize, borderSize)
    f:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", borderSize, -borderSize)

    if borderSize > 0 then
        local r, g, b, a
        if useClassColor then
            local _, class = UnitClass("player")
            local color = RAID_CLASS_COLORS[class]
            if color then
                r, g, b, a = color.r, color.g, color.b, 1
            else
                r, g, b, a = 1, 1, 1, 1  -- fallback to white
            end
        else
            r = borderColor.r or 0
            g = borderColor.g or 0
            b = borderColor.b or 0
            a = borderColor.a or 1
        end

        if shape == "SQUARE" then
            f:SetBackdrop({
                edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeSize = borderSize,
            })
            f:SetBackdropBorderColor(r, g, b, a)
            if f.roundBorder then f.roundBorder:Hide() end
        else
            f:SetBackdrop(nil)
            if not f.roundBorder then
                f.roundBorder = f:CreateTexture(nil, "BACKGROUND")
                f.roundBorder:SetAllPoints(f)
                local mask = f:CreateMaskTexture()
                mask:SetAllPoints(f)
                mask:SetTexture(ROUND_MASK)
                f.roundBorder:AddMaskTexture(mask)
            end
            f.roundBorder:SetColorTexture(r, g, b, a)
            f.roundBorder:Show()
        end
        f:Show()
    else
        f:SetBackdrop(nil)
        if f.roundBorder then f.roundBorder:Hide() end
        f:Hide()
    end
end

--------------------------------------------------------------------------------
-- Size
--------------------------------------------------------------------------------

function module:UpdateSize()
    local size = self:GetSetting("size", 180)
    local scale = self:GetSetting("scale", 1.0)

    Minimap:SetSize(size, size)
    MinimapCluster:SetScale(scale)

    -- Force render update via zoom toggle trick
    local currentZoom = Minimap:GetZoom()
    if currentZoom > 0 then
        Minimap:SetZoom(currentZoom - 1)
        Minimap:SetZoom(currentZoom)
    else
        Minimap:SetZoom(1)
        Minimap:SetZoom(0)
    end

    -- Update LibDBIcon button radius
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if LDBIcon then
        pcall(function() LDBIcon:Refresh() end)
    end
end

--------------------------------------------------------------------------------
-- Dragging / Position
--------------------------------------------------------------------------------

function module:SetupDragging()
    if self._dragSetup then return end
    self._dragSetup = true

    Minimap:SetMovable(true)
    Minimap:SetClampedToScreen(true)

    -- Reparent minimap to UIParent so it's freely movable
    Minimap:SetParent(UIParent)

    Minimap:RegisterForDrag("LeftButton")
    Minimap:SetScript("OnDragStart", function(frame)
        if not module:GetSetting("lock", false) then
            frame:StartMoving()
        end
    end)
    Minimap:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, relPoint, x, y = frame:GetPoint()
        module:SetSetting("position", {point = point, relPoint = relPoint, x = x, y = y})
    end)
end

function module:UpdatePosition()
    local pos = self:GetSetting("position")
    if pos and pos.point then
        Minimap:ClearAllPoints()
        Minimap:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        Minimap:ClearAllPoints()
        Minimap:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -10)
    end
end

function module:UpdateLock()
    local locked = self:GetSetting("lock", false)
    Minimap:SetMovable(not locked)
end

--------------------------------------------------------------------------------
-- Mouse Wheel Zoom
--------------------------------------------------------------------------------

function module:SetupMouseWheelZoom()
    local enabled = self:GetSetting("mouseWheelZoom", true)
    if enabled then
        Minimap:EnableMouseWheel(true)
        Minimap:SetScript("OnMouseWheel", function(_, delta)
            local zoom = Minimap:GetZoom()
            if delta > 0 then
                if zoom < Minimap:GetZoomLevels() then
                    Minimap:SetZoom(zoom + 1)
                end
            else
                if zoom > 0 then
                    Minimap:SetZoom(zoom - 1)
                end
            end
        end)
    else
        Minimap:EnableMouseWheel(false)
        Minimap:SetScript("OnMouseWheel", nil)
    end
end

--------------------------------------------------------------------------------
-- Auto Zoom Out
--------------------------------------------------------------------------------

function module:SetupAutoZoom()
    local enabled = self:GetSetting("autoZoomOut", true)

    if enabled and not self._autoZoomHooked then
        self._autoZoomHooked = true
        local zoomTimer
        hooksecurefunc(Minimap, "SetZoom", function()
            if not module:GetSetting("autoZoomOut", true) then
                return
            end
            if zoomTimer then
                zoomTimer:Cancel()
            end
            local zoom = Minimap:GetZoom()
            if zoom > 0 then
                zoomTimer = C_Timer.NewTimer(15, function()
                    if Minimap:GetZoom() > 0 then
                        Minimap:SetZoom(0)
                    end
                end)
            end
        end)
    end
end

--------------------------------------------------------------------------------
-- Strata & Dynamic Opacity
--------------------------------------------------------------------------------

function module:UpdateStrata()
    local strata = self:GetSetting("strata", "BACKGROUND")
    Minimap:SetFrameStrata(strata)
    if self.backdropFrame then
        self.backdropFrame:SetFrameStrata(strata)
        self.backdropFrame:SetFrameLevel(0)
    end
end

function module:ApplyOpacity()
    local alpha
    if IsMounted() then
        alpha = self:GetSetting("opacityMounted", 1.0)
    elseif self._isMoving then
        alpha = self:GetSetting("opacityMoving", 1.0)
    else
        alpha = self:GetSetting("opacity", 1.0)
    end

    Minimap:SetAlpha(alpha)
    if self.backdropFrame then
        self.backdropFrame:SetAlpha(alpha)
    end
end

function module:SetupOpacityEvents()
    if self._opacityEventsRegistered then return end
    self._opacityEventsRegistered = true

    self:RegisterEvent("PLAYER_STARTED_MOVING", function()
        self._isMoving = true
        self:ApplyOpacity()
    end)
    self:RegisterEvent("PLAYER_STOPPED_MOVING", function()
        self._isMoving = false
        self:ApplyOpacity()
    end)
    self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", function()
        self:ApplyOpacity()
    end)
end

--------------------------------------------------------------------------------
-- Hide Blizzard Decorations
--------------------------------------------------------------------------------

function module:HideBlizzardDecorations()
    -- Hide MinimapCluster sub-frames we don't need
    local framesToHide = {
        MinimapBackdrop,
        MinimapBorder,
        MinimapBorderTop,
        MinimapNorthTag,
        MinimapCompassTexture,
    }

    for _, frame in ipairs(framesToHide) do
        if frame then
            if frame.Hide then frame:Hide() end
            if frame.SetAlpha then frame:SetAlpha(0) end
        end
    end

    -- Hide edge textures on Minimap itself
    if Minimap.EdgeTextures then
        for _, tex in ipairs(Minimap.EdgeTextures) do
            if tex and tex.Hide then tex:Hide() end
        end
    end

    -- Hide the cluster header bar
    if MinimapCluster then
        if MinimapCluster.BorderTop then
            MinimapCluster.BorderTop:Hide()
            MinimapCluster.BorderTop:SetAlpha(0)
        end
        if MinimapCluster.Background then
            MinimapCluster.Background:Hide()
            MinimapCluster.Background:SetAlpha(0)
        end
    end

    -- Zoom button visibility is handled by Elements.UpdateButtonVisibility()
end
