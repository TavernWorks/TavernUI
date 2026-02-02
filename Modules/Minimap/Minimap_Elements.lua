local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("Minimap", true)

if not module then return end

local Elements = {}
module.Elements = Elements

local FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"

local function GetFont(key)
    return TavernUI:GetFontPath(key) or FALLBACK_FONT
end

local function SafeSetFont(fontString, key, size, flags)
    if not fontString:SetFont(GetFont(key), size, flags) then
        fontString:SetFont(FALLBACK_FONT, size, flags)
    end
end

local clockTicker, coordsTicker

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function GetClassColor()
    local _, class = UnitClass("player")
    local color = RAID_CLASS_COLORS[class]
    if not color then
        return 1, 1, 1  -- fallback to white
    end
    return color.r, color.g, color.b
end

local function JustifyFromPoint(point)
    if point:find("LEFT") then return "LEFT" end
    if point:find("RIGHT") then return "RIGHT" end
    return "CENTER"
end

local hiddenHolder = CreateFrame("Frame")
hiddenHolder:Hide()
hiddenHolder.Layout = function() end

-- Button holder lives outside the Minimap widget hierarchy so that
-- the Minimap's native mouse handling does not swallow clicks.
local buttonHolder = CreateFrame("Frame", "TavernUI_MinimapButtonHolder", UIParent)
buttonHolder:SetAllPoints(Minimap)
buttonHolder:EnableMouse(false)

local suppressedFrames = {}

local function HideFrame(frame)
    if not frame then return end
    suppressedFrames[frame] = true
    frame:SetParent(hiddenHolder)
    frame:Hide()
    if not frame.Layout then
        frame.Layout = function() end
    end
    -- Hook Show once to prevent Blizzard layout from re-showing
    if not frame._tavernShowHooked then
        frame._tavernShowHooked = true
        hooksecurefunc(frame, "Show", function(self)
            if suppressedFrames[self] then
                self:Hide()
            end
        end)
    end
end

local function ShowFrame(frame, parent)
    if not frame then return end
    suppressedFrames[frame] = nil
    frame:SetParent(parent or MinimapCluster)
    frame:SetFrameLevel(Minimap:GetFrameLevel() + 10)
    frame:Show()
end

--------------------------------------------------------------------------------
-- Fade System
--------------------------------------------------------------------------------

local fadeableButtons = {}
local isMinimapHovered = false
local fadeCheckTimer = nil

local function CheckMinimapHover()
    if Minimap:IsMouseOver() then return true end
    for frame in pairs(fadeableButtons) do
        if frame:IsShown() and frame:IsMouseOver() then
            return true
        end
    end
    return false
end

local function ShowFadedButtons()
    isMinimapHovered = true
    if fadeCheckTimer then fadeCheckTimer:Cancel(); fadeCheckTimer = nil end
    for frame in pairs(fadeableButtons) do
        frame:SetAlpha(1)
    end
end

local function StartFadeCheck()
    if fadeCheckTimer then fadeCheckTimer:Cancel() end
    fadeCheckTimer = C_Timer.NewTimer(0.3, function()
        fadeCheckTimer = nil
        if not CheckMinimapHover() then
            isMinimapHovered = false
            for frame in pairs(fadeableButtons) do
                frame:SetAlpha(0)
            end
        end
    end)
end

local function HookButtonFade(frame)
    if not frame or frame._tavernFadeHooked then return end
    frame._tavernFadeHooked = true
    frame:HookScript("OnEnter", function()
        if fadeableButtons[frame] then
            ShowFadedButtons()
        end
    end)
    frame:HookScript("OnLeave", function()
        if fadeableButtons[frame] then
            StartFadeCheck()
        end
    end)
end

local fadeHooksSetup = false
local function SetupFadeHooks()
    if fadeHooksSetup then return end
    fadeHooksSetup = true
    Minimap:HookScript("OnEnter", ShowFadedButtons)
    Minimap:HookScript("OnLeave", StartFadeCheck)
end

--------------------------------------------------------------------------------
-- Zone Text
--------------------------------------------------------------------------------

local zoneFrame, zoneText

local function CreateZoneText()
    if zoneFrame then return end

    zoneFrame = CreateFrame("Frame", "TavernUI_MinimapZone", Minimap)
    zoneFrame:SetSize(Minimap:GetWidth(), 20)
    zoneFrame:SetPoint("TOP", Minimap, "TOP", 0, 0)

    zoneText = zoneFrame:CreateFontString(nil, "OVERLAY")
    zoneText:SetPoint("TOP", zoneFrame, "TOP", 0, 0)
    zoneText:SetJustifyH("CENTER")

    -- Tooltip
    zoneFrame:EnableMouse(true)
    zoneFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        local zone = GetZoneText() or ""
        local subZone = GetSubZoneText() or ""
        GameTooltip:AddLine(zone, 1, 1, 1)
        if subZone ~= "" and subZone ~= zone then
            GameTooltip:AddLine(subZone, 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    zoneFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function GetZoneColor()
    local useClassColor = module:GetSetting("zoneText.useClassColor", false)
    if useClassColor then
        local r, g, b = GetClassColor()
        return r, g, b
    end

    local pvpType = C_PvP.GetZonePVPInfo()
    local colorKey
    if pvpType == "sanctuary" then
        colorKey = "colorSanctuary"
    elseif pvpType == "arena" then
        colorKey = "colorArena"
    elseif pvpType == "friendly" then
        colorKey = "colorFriendly"
    elseif pvpType == "hostile" then
        colorKey = "colorHostile"
    elseif pvpType == "contested" then
        colorKey = "colorContested"
    else
        colorKey = "colorNormal"
    end

    local c = module:GetSetting("zoneText." .. colorKey, {r=1, g=0.82, b=0, a=1})
    return c.r or 1, c.g or 0.82, c.b or 0, c.a or 1
end

local function UpdateZoneText()
    if not zoneFrame or not zoneText then return end

    local show = module:GetSetting("showZoneText", true)
    if not show then
        zoneFrame:Hide()
        return
    end
    zoneFrame:Show()

    local position = module:GetSetting("zoneText.position", "TOP")
    local fontKey = module:GetSetting("zoneText.font", "")
    local fontSize = module:GetSetting("zoneText.fontSize", 12)
    local offsetX = module:GetSetting("zoneText.offsetX", 0)
    local offsetY = module:GetSetting("zoneText.offsetY", -2)
    local allCaps = module:GetSetting("zoneText.allCaps", true)
    local fadeOut = module:GetSetting("zoneText.fadeOut", false)

    zoneFrame:ClearAllPoints()
    zoneFrame:SetPoint(position, Minimap, position, 0, 0)
    zoneFrame:SetWidth(Minimap:GetWidth())

    local justify = JustifyFromPoint(position)
    SafeSetFont(zoneText, fontKey, fontSize, "OUTLINE")
    zoneText:SetJustifyH(justify)
    zoneText:ClearAllPoints()
    zoneText:SetPoint(position, zoneFrame, position, offsetX, offsetY)

    local text = GetMinimapZoneText() or ""
    if allCaps then
        text = text:upper()
    end
    zoneText:SetText(text)

    local r, g, b, a = GetZoneColor()
    zoneText:SetTextColor(r, g, b, a)

    if fadeOut then
        SetupFadeHooks()
        fadeableButtons[zoneFrame] = true
        HookButtonFade(zoneFrame)
        zoneFrame:SetAlpha(isMinimapHovered and 1 or 0)
    else
        fadeableButtons[zoneFrame] = nil
        zoneFrame:SetAlpha(1)
    end
end

--------------------------------------------------------------------------------
-- Coordinates
--------------------------------------------------------------------------------

local coordsFrame, coordsText

local function CreateCoords()
    if coordsFrame then return end

    coordsFrame = CreateFrame("Frame", "TavernUI_MinimapCoords", Minimap)
    coordsFrame:SetSize(60, 16)

    coordsText = coordsFrame:CreateFontString(nil, "OVERLAY")
end

local function UpdateCoords()
    if not coordsFrame or not coordsText then return end

    local show = module:GetSetting("showCoords", true)
    if not show then
        coordsFrame:Hide()
        return
    end
    coordsFrame:Show()

    local position = module:GetSetting("coords.position", "TOPRIGHT")
    local fontKey = module:GetSetting("coords.font", "")
    local fontSize = module:GetSetting("coords.fontSize", 12)
    local offsetX = module:GetSetting("coords.offsetX", -2)
    local offsetY = module:GetSetting("coords.offsetY", -2)
    local precision = module:GetSetting("coords.precision", "%.1f, %.1f")
    local useClassColor = module:GetSetting("coords.useClassColor", false)
    local color = module:GetSetting("coords.color", {r=1, g=1, b=1, a=1})
    local fadeOut = module:GetSetting("coords.fadeOut", false)

    coordsFrame:ClearAllPoints()
    coordsFrame:SetPoint(position, Minimap, position, 0, 0)

    local justify = JustifyFromPoint(position)
    SafeSetFont(coordsText, fontKey, fontSize, "OUTLINE")
    coordsText:SetJustifyH(justify)
    coordsText:ClearAllPoints()
    coordsText:SetPoint(position, coordsFrame, position, offsetX, offsetY)

    -- Get player coords
    local x, y = 0, 0
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then
            x, y = pos:GetXY()
            x = x * 100
            y = y * 100
        end
    end

    local success, formatted = pcall(string.format, precision, x, y)
    coordsText:SetText(success and formatted or string.format("%.1f, %.1f", x, y))

    if useClassColor then
        local r, g, b = GetClassColor()
        coordsText:SetTextColor(r, g, b)
    else
        coordsText:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
    end

    if fadeOut then
        SetupFadeHooks()
        fadeableButtons[coordsFrame] = true
        HookButtonFade(coordsFrame)
        coordsFrame:SetAlpha(isMinimapHovered and 1 or 0)
    else
        fadeableButtons[coordsFrame] = nil
        coordsFrame:SetAlpha(1)
    end
end

--------------------------------------------------------------------------------
-- Clock
--------------------------------------------------------------------------------

local clockFrame, clockText

local function CreateClock()
    if clockFrame then return end

    clockFrame = CreateFrame("Button", "TavernUI_MinimapClock", Minimap)
    clockFrame:SetSize(50, 16)

    clockText = clockFrame:CreateFontString(nil, "OVERLAY")

    clockFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    clockFrame:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            if ToggleCalendar then
                ToggleCalendar()
            end
        elseif button == "RightButton" then
            if TimeManagerFrame then
                if TimeManagerFrame:IsShown() then
                    TimeManagerFrame:Hide()
                else
                    TimeManagerFrame:Show()
                end
            end
        end
    end)
    clockFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Clock", 1, 1, 1)
        GameTooltip:AddLine("Left-click: Calendar", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-click: Stopwatch", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    clockFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Hide Blizzard clock
    if TimeManagerClockButton then
        TimeManagerClockButton:Hide()
    end
end

local function UpdateClock()
    if not clockFrame or not clockText then return end

    local show = module:GetSetting("showClock", true)
    if not show then
        clockFrame:Hide()
        return
    end
    clockFrame:Show()

    local position = module:GetSetting("clock.position", "TOPLEFT")
    local fontKey = module:GetSetting("clock.font", "")
    local fontSize = module:GetSetting("clock.fontSize", 12)
    local offsetX = module:GetSetting("clock.offsetX", 2)
    local offsetY = module:GetSetting("clock.offsetY", -2)
    local timeSource = module:GetSetting("clock.timeSource", "local")
    local use24Hour = module:GetSetting("clock.use24Hour", true)
    local useClassColor = module:GetSetting("clock.useClassColor", false)
    local color = module:GetSetting("clock.color", {r=1, g=1, b=1, a=1})
    local fadeOut = module:GetSetting("clock.fadeOut", false)

    clockFrame:ClearAllPoints()
    clockFrame:SetPoint(position, Minimap, position, 0, 0)

    local justify = JustifyFromPoint(position)
    SafeSetFont(clockText, fontKey, fontSize, "OUTLINE")
    clockText:SetJustifyH(justify)
    clockText:ClearAllPoints()
    clockText:SetPoint(position, clockFrame, position, offsetX, offsetY)

    local hour, minute
    if timeSource == "server" then
        hour, minute = GetGameTime()
    else
        local dateTable = date("*t")
        hour = dateTable.hour
        minute = dateTable.min
    end

    local timeStr
    if use24Hour then
        timeStr = string.format("%02d:%02d", hour, minute)
    else
        local suffix = hour >= 12 and "PM" or "AM"
        hour = hour % 12
        if hour == 0 then hour = 12 end
        timeStr = string.format("%d:%02d %s", hour, minute, suffix)
    end

    clockText:SetText(timeStr)

    if useClassColor then
        local r, g, b = GetClassColor()
        clockText:SetTextColor(r, g, b)
    else
        clockText:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
    end

    if fadeOut then
        SetupFadeHooks()
        fadeableButtons[clockFrame] = true
        HookButtonFade(clockFrame)
        clockFrame:SetAlpha(isMinimapHovered and 1 or 0)
    else
        fadeableButtons[clockFrame] = nil
        clockFrame:SetAlpha(1)
    end
end

--------------------------------------------------------------------------------
-- Button Visibility / Positioning / Fade
--------------------------------------------------------------------------------

-- Resolve a frame from multiple possible references (TWW changed many names)
local function ResolveFrame(...)
    for i = 1, select("#", ...) do
        local frame = select(i, ...)
        if frame then return frame end
    end
    return nil
end

-- Resolve all button frames once (called each update since addons can load late)
local function GetButtonFrames()
    return {
        zoom = {
            ResolveFrame(Minimap and Minimap.ZoomIn,  MinimapCluster and MinimapCluster.ZoomIn,  MinimapZoomIn),
            ResolveFrame(Minimap and Minimap.ZoomOut, MinimapCluster and MinimapCluster.ZoomOut, MinimapZoomOut),
        },
        mail = ResolveFrame(
            MinimapCluster and MinimapCluster.IndicatorFrame and MinimapCluster.IndicatorFrame.MailFrame,
            MiniMapMailFrame
        ),
        craftingOrder = MinimapCluster and MinimapCluster.IndicatorFrame
            and MinimapCluster.IndicatorFrame.CraftingOrderFrame,
        addonCompartment = AddonCompartmentFrame,
        difficulty = ResolveFrame(
            MinimapCluster and MinimapCluster.InstanceDifficulty,
            MiniMapInstanceDifficulty
        ),
        missions = ResolveFrame(
            ExpansionLandingPageMinimapButton,
            GarrisonLandingPageMinimapButton
        ),
        calendar = GameTimeFrame,
        tracking = ResolveFrame(
            MinimapCluster and MinimapCluster.Tracking,
            MinimapCluster and MinimapCluster.TrackingFrame,
            MiniMapTracking
        ),
    }
end

-- Apply per-button settings (position, scale, strata, fade)
local function ApplyButtonSettings(frame, buttonKey, extraOffsetY)
    if not frame then return end

    local path = "buttons." .. buttonKey
    local show = module:GetSetting(path .. ".show", false)

    if not show then
        HideFrame(frame)
        fadeableButtons[frame] = nil
        return
    end

    ShowFrame(frame, buttonHolder)

    local scale   = module:GetSetting(path .. ".scale", 1.0)
    local strata  = module:GetSetting(path .. ".strata", "MEDIUM")
    local point   = module:GetSetting(path .. ".point", "CENTER")
    local offsetX = module:GetSetting(path .. ".offsetX", 0)
    local offsetY = module:GetSetting(path .. ".offsetY", 0) + (extraOffsetY or 0)
    local fadeOut = module:GetSetting(path .. ".fadeOut", false)

    frame:SetScale(scale)
    frame:SetFrameStrata(strata)
    frame:ClearAllPoints()
    frame:SetPoint(point, Minimap, point, offsetX, offsetY)

    if fadeOut then
        SetupFadeHooks()
        fadeableButtons[frame] = true
        HookButtonFade(frame)
        frame:SetAlpha(isMinimapHovered and 1 or 0)
    else
        fadeableButtons[frame] = nil
        frame:SetAlpha(1)
    end
end

local function UpdateButtons()
    local frames = GetButtonFrames()

    -- Zoom: both frames share one config, offset zoomIn above zoomOut
    local zoomFrames = frames.zoom
    if zoomFrames then
        ApplyButtonSettings(zoomFrames[2], "zoom", 0)   -- zoomOut at base
        ApplyButtonSettings(zoomFrames[1], "zoom", 20)   -- zoomIn 20px above
    end

    -- All single-frame buttons
    local singles = {"mail", "craftingOrder", "addonCompartment", "difficulty", "missions", "calendar", "tracking"}
    for _, key in ipairs(singles) do
        ApplyButtonSettings(frames[key], key)
    end
end

-- Addon Button Hiding (LibDBIcon — separate from per-button system)
local function UpdateAddonButtons()
    local hide = module:GetSetting("hideAddonButtons", false)
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if not LDBIcon then return end

    if hide then
        pcall(function() LDBIcon:ShowOnEnter(true) end)
    else
        pcall(function() LDBIcon:ShowOnEnter(false) end)
    end
end

--------------------------------------------------------------------------------
-- Dungeon Eye (QueueStatusButton)
--------------------------------------------------------------------------------

local function UpdateDungeonEye()
    local btn = QueueStatusButton
    if not btn then return end

    local enabled = module:GetSetting("dungeonEye.enabled", true)
    if not enabled then
        HideFrame(btn)
        return
    end

    ShowFrame(btn, buttonHolder)

    local corner = module:GetSetting("dungeonEye.corner", "BOTTOMRIGHT")
    local scale = module:GetSetting("dungeonEye.scale", 0.8)
    local offsetX = module:GetSetting("dungeonEye.offsetX", 0)
    local offsetY = module:GetSetting("dungeonEye.offsetY", 0)

    btn:SetScale(scale)
    btn:ClearAllPoints()
    btn:SetPoint(corner, Minimap, corner, offsetX, offsetY)

    -- Hook UpdatePosition to persist our placement
    if not btn._tavernHooked then
        btn._tavernHooked = true
        hooksecurefunc(btn, "UpdatePosition", function()
            if module:IsEnabled() and module:GetSetting("dungeonEye.enabled", true) then
                local c = module:GetSetting("dungeonEye.corner", "BOTTOMRIGHT")
                local s = module:GetSetting("dungeonEye.scale", 0.8)
                local ox = module:GetSetting("dungeonEye.offsetX", 0)
                local oy = module:GetSetting("dungeonEye.offsetY", 0)
                btn:SetScale(s)
                btn:ClearAllPoints()
                btn:SetPoint(c, Minimap, c, ox, oy)
            end
        end)
    end
end

--------------------------------------------------------------------------------
-- Pet Battles
--------------------------------------------------------------------------------

local petBattleFrame = CreateFrame("Frame")
petBattleFrame:RegisterEvent("PET_BATTLE_OPENING_START")
petBattleFrame:RegisterEvent("PET_BATTLE_CLOSE")
petBattleFrame:SetScript("OnEvent", function(_, event)
    local mod = TavernUI:GetModule("Minimap", true)
    if not mod or not mod:IsEnabled() then return end

    if event == "PET_BATTLE_OPENING_START" then
        Minimap:Hide()
        if mod.backdropFrame then
            mod.backdropFrame:Hide()
        end
    elseif event == "PET_BATTLE_CLOSE" then
        Minimap:Show()
        if mod.backdropFrame then
            mod.backdropFrame:Show()
        end
    end
end)

--------------------------------------------------------------------------------
-- Calendar Invites
--------------------------------------------------------------------------------

local calendarFrame = CreateFrame("Frame")
calendarFrame:RegisterEvent("CALENDAR_UPDATE_PENDING_INVITES")
calendarFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
calendarFrame:SetScript("OnEvent", function()
    local mod = TavernUI:GetModule("Minimap", true)
    if not mod or not mod:IsEnabled() then return end

    if GameTimeFrame and not mod:GetSetting("buttons.calendar.show", false) then
        local numPending = C_Calendar.GetNumPendingInvites()
        if numPending and numPending > 0 then
            GameTimeFrame:Show()
        else
            GameTimeFrame:Hide()
        end
    end
end)

--------------------------------------------------------------------------------
-- Zone Change Events
--------------------------------------------------------------------------------

local zoneEventFrame = CreateFrame("Frame")
zoneEventFrame:RegisterEvent("ZONE_CHANGED")
zoneEventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
zoneEventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zoneEventFrame:SetScript("OnEvent", function()
    local mod = TavernUI:GetModule("Minimap", true)
    if not mod or not mod:IsEnabled() then return end
    UpdateZoneText()
end)

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function Elements.Setup()
    CreateZoneText()
    CreateCoords()
    CreateClock()

    -- Hide Blizzard zone text
    if MinimapCluster and MinimapCluster.ZoneTextButton then
        MinimapCluster.ZoneTextButton:Hide()
    end
    if MinimapZoneText then
        MinimapZoneText:Hide()
    end
    if MinimapZoneTextButton then
        MinimapZoneTextButton:Hide()
    end

    Elements.RefreshAll()
end

function Elements.RefreshAll()
    UpdateZoneText()
    UpdateCoords()
    UpdateClock()
    UpdateButtons()
    UpdateAddonButtons()
    UpdateDungeonEye()
end

local function StartCoordsTicker()
    local interval = module:GetSetting("coords.updateInterval", 1)
    interval = math.max(interval, 0.1)  -- minimum 100ms to prevent spam
    coordsTicker = C_Timer.NewTicker(interval, function()
        if module:IsEnabled() then
            UpdateCoords()
        end
    end)
end

function Elements.StartTickers()
    Elements.StopTickers()

    -- Clock ticker (1 second)
    clockTicker = C_Timer.NewTicker(1, function()
        if module:IsEnabled() then
            UpdateClock()
        end
    end)

    -- Coords ticker (configurable interval)
    StartCoordsTicker()
end

function Elements.RefreshCoordsTicker()
    if coordsTicker then
        coordsTicker:Cancel()
        coordsTicker = nil
    end
    if not module:IsEnabled() then
        return
    end
    StartCoordsTicker()
end

function Elements.StopTickers()
    if clockTicker then
        clockTicker:Cancel()
        clockTicker = nil
    end
    if coordsTicker then
        coordsTicker:Cancel()
        coordsTicker = nil
    end
end

-- Expose individual updaters for options panel instant feedback
Elements.UpdateZoneText = UpdateZoneText
Elements.UpdateCoords = UpdateCoords
Elements.UpdateClock = UpdateClock
Elements.UpdateButtons = UpdateButtons
Elements.UpdateAddonButtons = UpdateAddonButtons
Elements.UpdateDungeonEye = UpdateDungeonEye
