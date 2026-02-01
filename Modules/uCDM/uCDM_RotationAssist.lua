local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

--[[
    RotationAssist - Highlights next recommended spell via C_AssistedCombat

    Three independent features sharing one ticker:
    1. CDM Icon Highlighting   - border on Essential/Utility viewer icons
    2. Action Bar Highlighting - border on action bar buttons
    3. Standalone Button       - movable icon with GCD swipe and keybind
]]

local RotationAssist = {}

-- Shared state
local lastSpellID = nil
local inCombat = false
local updateTimer = nil
local initialized = false

-- Overlay caches
local cdmOverlays = {}       -- frame -> overlay
local actionBarOverlays = {} -- button -> overlay

-- Action button cache
local cachedActionButtons = nil
local actionButtonsCached = false

-- Standalone button
local assistButton = nil

local GCD_SPELL_ID = 61304

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function GetSetting(path, default)
    return module:GetSetting("rotationAssist." .. path, default)
end

local function IsAPIAvailable()
    return C_AssistedCombat and C_AssistedCombat.GetNextCastSpell
end

local function GetNextSpellID()
    if not IsAPIAvailable() then return nil end
    local ok, spellID = pcall(C_AssistedCombat.GetNextCastSpell)
    if ok and spellID and spellID ~= 0 then
        return spellID
    end
    return nil
end

local function ShouldRun()
    if not module:IsEnabled() then return false end
    if not IsAPIAvailable() then return false end

    local essEnabled = GetSetting("cdmHighlight.essential.enabled", false)
    local utilEnabled = GetSetting("cdmHighlight.utility.enabled", false)
    local abEnabled = GetSetting("actionBarHighlight.enabled", false)
    local btnEnabled = GetSetting("button.enabled", false)

    return essEnabled or utilEnabled or abEnabled or btnEnabled
end

--------------------------------------------------------------------------------
-- Inner Border Overlay (4-edge texture approach, no BackdropTemplate)
--------------------------------------------------------------------------------

local function CreateOverlay(parent, frameLevel)
    local overlay = CreateFrame("Frame", nil, parent)
    overlay:SetAllPoints(parent)
    overlay:SetFrameLevel((frameLevel or parent:GetFrameLevel()) + 15)

    local edges = {}
    for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        edges[edge] = overlay:CreateTexture(nil, "OVERLAY")
        edges[edge]:SetColorTexture(0, 1, 0.84, 0.8)
    end

    local fill = overlay:CreateTexture(nil, "OVERLAY")
    fill:SetAllPoints(overlay)
    fill:SetColorTexture(0, 1, 0.84, 0.4)
    fill:Hide()

    overlay._edges = edges
    overlay._fill = fill
    overlay._thickness = 2
    overlay._style = "border"

    function overlay:SetBorderColor(r, g, b, a)
        for _, tex in pairs(self._edges) do
            tex:SetColorTexture(r, g, b, a or 1)
        end
        self._fill:SetColorTexture(r, g, b, (a and a * 0.5) or 0.4)
    end

    function overlay:SetStyle(style)
        self._style = style
        if style == "glow" then
            self._fill:Show()
            for _, tex in pairs(self._edges) do tex:Hide() end
        else -- "border"
            self._fill:Hide()
            for _, tex in pairs(self._edges) do tex:Show() end
        end
    end

    function overlay:SetBorderSize(px)
        self._thickness = px
        self:UpdateEdges()
    end

    function overlay:UpdateEdges()
        local t = self._thickness
        local edges = self._edges

        edges.TOP:ClearAllPoints()
        edges.TOP:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
        edges.TOP:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
        edges.TOP:SetHeight(t)

        edges.BOTTOM:ClearAllPoints()
        edges.BOTTOM:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
        edges.BOTTOM:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
        edges.BOTTOM:SetHeight(t)

        edges.LEFT:ClearAllPoints()
        edges.LEFT:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -t)
        edges.LEFT:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, t)
        edges.LEFT:SetWidth(t)

        edges.RIGHT:ClearAllPoints()
        edges.RIGHT:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -t)
        edges.RIGHT:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, t)
        edges.RIGHT:SetWidth(t)
    end

    overlay:UpdateEdges()
    overlay:Hide()
    return overlay
end

--------------------------------------------------------------------------------
-- CDM Icon Highlighting
--------------------------------------------------------------------------------

local function GetCDMOverlay(frame)
    if cdmOverlays[frame] then return cdmOverlays[frame] end
    local overlay = CreateOverlay(frame)
    cdmOverlays[frame] = overlay
    return overlay
end

local function MatchesSpellID(item, nextSpellID)
    if not item or not nextSpellID then return false end

    -- Direct spell ID match
    if item.spellID and item.spellID == nextSpellID then return true end

    -- Override: does item's spell override TO the next spell?
    if item.spellID and C_Spell.GetOverrideSpell then
        local ok, overrideID = pcall(C_Spell.GetOverrideSpell, item.spellID)
        if ok and overrideID and overrideID == nextSpellID then return true end
    end

    -- Reverse: does the next spell override TO the item's spell?
    if item.spellID and C_Spell.GetOverrideSpell then
        local ok, overrideID = pcall(C_Spell.GetOverrideSpell, nextSpellID)
        if ok and overrideID and overrideID == item.spellID then return true end
    end

    return false
end

local function UpdateViewerHighlight(viewerKey, nextSpellID)
    local settings = GetSetting("cdmHighlight." .. viewerKey)
    if not settings or not settings.enabled then
        -- Hide all overlays for this viewer
        if module.ItemRegistry then
            local items = module.ItemRegistry.GetItemsForViewer(viewerKey)
            for _, item in ipairs(items) do
                if item.frame and cdmOverlays[item.frame] then
                    cdmOverlays[item.frame]:Hide()
                end
            end
        end
        return
    end

    local color = settings.color or {r = 0, g = 1, b = 0.84, a = 0.8}
    local thickness = settings.thickness or 2
    local style = settings.style or "border"

    if not module.ItemRegistry then return end
    local items = module.ItemRegistry.GetItemsForViewer(viewerKey)

    for _, item in ipairs(items) do
        if item.frame then
            local overlay = GetCDMOverlay(item.frame)
            if nextSpellID and MatchesSpellID(item, nextSpellID) then
                overlay:SetBorderColor(color.r, color.g, color.b, color.a)
                overlay:SetBorderSize(thickness)
                overlay:SetStyle(style)
                overlay:Show()
            else
                overlay:Hide()
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Action Bar Highlighting
--------------------------------------------------------------------------------

local function BuildActionButtonCache()
    if actionButtonsCached then return end

    cachedActionButtons = {}
    local added = {}

    -- Scan globals for action buttons
    for globalName, frame in pairs(_G) do
        if type(globalName) == "string" and type(frame) == "table" and not added[frame] then
            if type(frame.GetObjectType) == "function" and (frame.action or (frame.GetAction and type(frame.GetAction) == "function")) then
                if globalName:match("ActionButton%d+$") or (globalName:match("Button%d+$") and globalName:match("Bar")) then
                    cachedActionButtons[#cachedActionButtons + 1] = frame
                    added[frame] = true
                end
            end
        end
    end

    -- Blizzard bars
    local barPrefixes = {
        "ActionButton",
        "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton",
        "MultiBarRightButton",
        "MultiBarLeftButton",
    }
    for _, prefix in ipairs(barPrefixes) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            if button and not added[button] then
                cachedActionButtons[#cachedActionButtons + 1] = button
                added[button] = true
            end
        end
    end

    -- Bartender4
    for i = 1, 120 do
        local button = _G["BT4Button" .. i]
        if button and not added[button] then
            cachedActionButtons[#cachedActionButtons + 1] = button
            added[button] = true
        end
    end

    -- Dominos
    for i = 1, 120 do
        local button = _G["DominosActionButton" .. i]
        if button and not added[button] then
            cachedActionButtons[#cachedActionButtons + 1] = button
            added[button] = true
        end
    end

    -- ElvUI
    for bar = 1, 10 do
        for i = 1, 12 do
            local button = _G["ElvUI_Bar" .. bar .. "Button" .. i]
            if button and not added[button] then
                cachedActionButtons[#cachedActionButtons + 1] = button
                added[button] = true
            end
        end
    end

    actionButtonsCached = true
end

local function GetActionBarOverlay(button)
    if actionBarOverlays[button] then return actionBarOverlays[button] end
    local overlay = CreateOverlay(button)
    actionBarOverlays[button] = overlay
    return overlay
end

local function GetActionSlot(button)
    local buttonName = button and button.GetName and button:GetName()
    local action

    if buttonName and buttonName:match("^BT4Button") then
        action = button._state_action
        if (not action or action == 0) and button.GetAction then
            local ok, aType, actionSlot = pcall(function()
                local t, s = button:GetAction()
                return t, s
            end)
            if ok and aType == "action" and type(actionSlot) == "number" then
                action = actionSlot
            end
        end
    else
        if type(button.action) == "number" then
            action = button.action
        end
        if (not action or action == 0) and button.GetAction then
            local ok, r1, r2 = pcall(function()
                local a, b = button:GetAction()
                return a, b
            end)
            if ok then
                if type(r2) == "number" and (r1 == "action" or r1 == nil) then
                    action = r2
                elseif type(r1) == "number" then
                    action = r1
                end
            end
        end
    end

    if not action or action == 0 then return nil end
    return action
end

local function ActionButtonMatchesSpell(button, nextSpellID)
    local action = GetActionSlot(button)
    if not action then return false end

    local ok, actionType, id = pcall(GetActionInfo, action)
    if not ok or not actionType then return false end

    if actionType == "spell" and id then
        if id == nextSpellID then return true end
        -- Check override spells in both directions
        if C_Spell.GetOverrideSpell then
            local ok2, overrideID = pcall(C_Spell.GetOverrideSpell, id)
            if ok2 and overrideID and overrideID == nextSpellID then return true end
            local ok3, reverseID = pcall(C_Spell.GetOverrideSpell, nextSpellID)
            if ok3 and reverseID and reverseID == id then return true end
        end
        return false
    elseif actionType == "macro" and id then
        -- Check macro spell via API first
        local ok2, macroSpell = pcall(GetMacroSpell, id)
        if ok2 and macroSpell and macroSpell == nextSpellID then return true end

        -- Parse macro body for spell matches
        local ok3, macroName, macroIcon, macroBody = pcall(GetMacroInfo, id)
        if ok3 and macroBody then
            for line in macroBody:gmatch("[^\r\n]+") do
                local spellName = nil

                -- Match /cast or /use commands
                local castMatch = line:match("^%s*/[cC][aA][sS][tT]%s+(.*)")
                local useMatch = line:match("^%s*/[uU][sS][eE]%s+(.*)")
                local afterCmd = castMatch or useMatch

                if afterCmd then
                    -- Strip conditionals [...]
                    afterCmd = afterCmd:gsub("%[.-%]", "")
                    -- Get first spell name/id (before semicolons or end of line)
                    spellName = afterCmd:match("^%s*(.-)%s*[;]") or afterCmd:match("^%s*(.-)%s*$")
                    if spellName then
                        spellName = strtrim(spellName)
                    end
                end

                if spellName and spellName ~= "" and spellName ~= "?" then
                    local spellIDFromName = tonumber(spellName)
                    if spellIDFromName then
                        if spellIDFromName == nextSpellID then return true end
                    else
                        local ok4, spellInfo = pcall(C_Spell.GetSpellInfo, spellName)
                        if ok4 and spellInfo and spellInfo.spellID == nextSpellID then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    return false
end

local function UpdateActionBarHighlight(nextSpellID)
    local settings = GetSetting("actionBarHighlight")
    if not settings or not settings.enabled then
        -- Hide all action bar overlays
        for _, overlay in pairs(actionBarOverlays) do
            overlay:Hide()
        end
        return
    end

    BuildActionButtonCache()
    if not cachedActionButtons then return end

    local color = settings.color or {r = 0, g = 1, b = 0.84, a = 0.8}
    local thickness = settings.thickness or 2
    local style = settings.style or "border"

    for _, button in ipairs(cachedActionButtons) do
        local overlay = GetActionBarOverlay(button)
        if nextSpellID and ActionButtonMatchesSpell(button, nextSpellID) then
            overlay:SetBorderColor(color.r, color.g, color.b, color.a)
            overlay:SetBorderSize(thickness)
            overlay:SetStyle(style)
            overlay:Show()
        else
            overlay:Hide()
        end
    end
end

--------------------------------------------------------------------------------
-- Standalone Rotation Assist Button
--------------------------------------------------------------------------------

local function ApplyButtonPosition()
    if not assistButton then return end
    local anchorFrom = GetSetting("button.anchorFrom", "CENTER")
    local anchorTo = GetSetting("button.anchorTo", "CENTER")
    local x = GetSetting("button.offsetX", 0)
    local y = GetSetting("button.offsetY", -180)
    assistButton:ClearAllPoints()
    assistButton:SetPoint(anchorFrom, UIParent, anchorTo, x, y)
end

local function CreateAssistButton()
    if assistButton then return assistButton end

    local btn = CreateFrame("Button", "TavernUI_RotationAssistButton", UIParent)
    btn:SetSize(56, 56)
    btn:SetFrameStrata("MEDIUM")
    btn:SetClampedToScreen(true)
    btn:SetMovable(true)
    btn:EnableMouse(true)

    -- Icon
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(btn)
    btn.Icon = icon

    -- Cooldown (GCD swipe)
    local cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cooldown:SetAllPoints(btn)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetDrawSwipe(true)
    cooldown:SetHideCountdownNumbers(true)
    btn.Cooldown = cooldown

    -- Border overlay (4-edge)
    local border = CreateOverlay(btn)
    border:SetBorderColor(0, 0, 0, 1)
    border:SetBorderSize(2)
    btn.Border = border

    -- Keybind text
    local keybindText = TavernUI:CreateFontString(btn, 13)
    keybindText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    keybindText:SetJustifyH("RIGHT")
    btn.KeybindText = keybindText

    -- Drag handling
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        if not GetSetting("button.isLocked", true) then
            self:StartMoving()
        end
    end)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Compute offset relative to the configured anchor point on UIParent
        local anchorFrom = GetSetting("button.anchorFrom", "CENTER")
        local anchorTo = GetSetting("button.anchorTo", "CENTER")
        -- Re-anchor so the frame stores clean offset values
        local cx, cy = self:GetCenter()
        if cx and cy then
            self:ClearAllPoints()
            self:SetPoint(anchorFrom, UIParent, anchorTo, 0, 0)
            local ax, ay = self:GetCenter()
            self:ClearAllPoints()
            if ax and ay then
                local dx = cx - ax
                local dy = cy - ay
                module:SetSetting("rotationAssist.button.offsetX", math.floor(dx + 0.5))
                module:SetSetting("rotationAssist.button.offsetY", math.floor(dy + 0.5))
            end
            ApplyButtonPosition()
        end
    end)

    btn:Hide()
    assistButton = btn
    return btn
end

local function ApplyButtonSettings()
    local btn = CreateAssistButton()

    local size = GetSetting("button.iconSize", 56)
    btn:SetSize(size, size)

    local strata = GetSetting("button.frameStrata", "MEDIUM")
    btn:SetFrameStrata(strata)

    -- Border
    if GetSetting("button.showBorder", true) then
        local borderColor = GetSetting("button.borderColor", {r = 0, g = 0, b = 0, a = 1})
        local borderThickness = GetSetting("button.borderThickness", 2)
        btn.Border:SetBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
        btn.Border:SetBorderSize(borderThickness)
        btn.Border:Show()
    else
        btn.Border:Hide()
    end

    -- GCD swipe
    local swipeEnabled = GetSetting("button.cooldownSwipeEnabled", true)
    btn.Cooldown:SetDrawSwipe(swipeEnabled)

    -- Keybind text
    local showKeybind = GetSetting("button.showKeybind", true)
    if showKeybind then
        local keybindColor = GetSetting("button.keybindColor", {r = 1, g = 1, b = 1, a = 1})
        local keybindSize = GetSetting("button.keybindSize", 13)
        local keybindPoint = GetSetting("button.keybindPoint", "BOTTOMRIGHT")
        local keybindOffsetX = GetSetting("button.keybindOffsetX", -2)
        local keybindOffsetY = GetSetting("button.keybindOffsetY", 2)

        TavernUI:ApplyFont(btn.KeybindText, btn, keybindSize)
        btn.KeybindText:SetTextColor(keybindColor.r, keybindColor.g, keybindColor.b, keybindColor.a)
        btn.KeybindText:ClearAllPoints()
        btn.KeybindText:SetPoint(keybindPoint, btn, keybindPoint, keybindOffsetX, keybindOffsetY)
    else
        btn.KeybindText:Hide()
    end

    ApplyButtonPosition()
end

local function UpdateButtonVisibility()
    if not assistButton then return end

    if not GetSetting("button.enabled", false) then
        assistButton:Hide()
        return
    end

    local mode = GetSetting("button.visibility", "always")

    if mode == "always" then
        assistButton:Show()
    elseif mode == "combat" then
        if inCombat then
            assistButton:Show()
        else
            assistButton:Hide()
        end
    elseif mode == "hostile" then
        local exists = UnitExists("target")
        local canAttack = UnitCanAttack("player", "target")
        if exists and canAttack then
            assistButton:Show()
        else
            assistButton:Hide()
        end
    end
end

local function UpdateButtonIcon(spellID)
    if not assistButton then return end

    if not spellID then
        assistButton.Icon:SetTexture(nil)
        assistButton.KeybindText:SetText("")
        return
    end

    -- Set icon texture
    local ok, spellInfo = pcall(C_Spell.GetSpellInfo, spellID)
    if ok and spellInfo then
        local iconID = spellInfo.iconID or spellInfo.originalIconID
        if iconID then
            assistButton.Icon:SetTexture(iconID)
        end
    end

    -- Usability tinting
    local ok2, isUsable = pcall(C_Spell.IsSpellUsable, spellID)
    if ok2 then
        if isUsable then
            assistButton.Icon:SetVertexColor(1, 1, 1, 1)
        else
            assistButton.Icon:SetVertexColor(0.4, 0.4, 0.4, 1)
        end
    else
        assistButton.Icon:SetVertexColor(1, 1, 1, 1)
    end

    -- Keybind text
    if GetSetting("button.showKeybind", true) and module.Keybinds then
        local keybind = module.Keybinds.GetSpellKeybind(spellID)
        assistButton.KeybindText:SetText(keybind or "")
        if keybind then
            assistButton.KeybindText:Show()
        else
            assistButton.KeybindText:Hide()
        end
    end
end

local function UpdateGCDCooldown()
    if not assistButton or not assistButton.Cooldown then return end
    if not GetSetting("button.cooldownSwipeEnabled", true) then return end

    local ok, cdInfo = pcall(C_Spell.GetSpellCooldown, GCD_SPELL_ID)
    if ok and cdInfo and cdInfo.startTime and cdInfo.duration and cdInfo.duration > 0 then
        assistButton.Cooldown:SetCooldown(cdInfo.startTime, cdInfo.duration)
    end
end

--------------------------------------------------------------------------------
-- Shared Update Loop
--------------------------------------------------------------------------------

local function DoUpdate()
    if not ShouldRun() then return end

    local nextSpellID = GetNextSpellID()

    -- Track whether the spell changed (for debug/future use)
    local changed = (nextSpellID ~= lastSpellID)
    lastSpellID = nextSpellID

    -- Always update all features every tick to keep state current.
    -- The ticker rate (0.1s combat, 0.25s idle) provides throttling.

    -- CDM highlights
    if GetSetting("cdmHighlight.essential.enabled", false) then
        UpdateViewerHighlight("essential", nextSpellID)
    end
    if GetSetting("cdmHighlight.utility.enabled", false) then
        UpdateViewerHighlight("utility", nextSpellID)
    end

    -- Action bar highlights
    if GetSetting("actionBarHighlight.enabled", false) then
        UpdateActionBarHighlight(nextSpellID)
    end

    -- Standalone button
    if GetSetting("button.enabled", false) then
        UpdateButtonIcon(nextSpellID)
        if assistButton and assistButton:IsShown() then
            UpdateGCDCooldown()
        end
    end
end

local function StopTicker()
    if updateTimer then
        updateTimer:Cancel()
        updateTimer = nil
    end
end

local function StartTicker()
    StopTicker()
    if not ShouldRun() then return end

    local function Tick()
        if not ShouldRun() then
            StopTicker()
            return
        end

        DoUpdate()

        local interval = inCombat and 0.1 or 0.25
        updateTimer = C_Timer.NewTimer(interval, Tick)
    end

    Tick()
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

local function HideAllHighlights()
    -- CDM overlays
    for _, overlay in pairs(cdmOverlays) do
        overlay:Hide()
    end

    -- Action bar overlays
    for _, overlay in pairs(actionBarOverlays) do
        overlay:Hide()
    end

    -- Button
    if assistButton then
        assistButton:Hide()
    end

    lastSpellID = nil
end

--------------------------------------------------------------------------------
-- Refresh (apply all settings, restart ticker)
--------------------------------------------------------------------------------

local function Refresh()
    if not module:IsEnabled() then
        HideAllHighlights()
        StopTicker()
        return
    end

    if not ShouldRun() then
        HideAllHighlights()
        StopTicker()
        return
    end

    -- Apply button settings if enabled
    if GetSetting("button.enabled", false) then
        ApplyButtonSettings()
        UpdateButtonVisibility()
    elseif assistButton then
        assistButton:Hide()
    end

    -- If CDM highlights are disabled, hide their overlays
    if not GetSetting("cdmHighlight.essential.enabled", false) then
        UpdateViewerHighlight("essential", nil)
    end
    if not GetSetting("cdmHighlight.utility.enabled", false) then
        UpdateViewerHighlight("utility", nil)
    end

    -- If action bar highlight is disabled, hide overlays
    if not GetSetting("actionBarHighlight.enabled", false) then
        UpdateActionBarHighlight(nil)
    end

    -- Force a fresh update cycle
    lastSpellID = nil
    StartTicker()
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function RotationAssist.Initialize()
    if initialized then return end
    initialized = true

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    eventFrame:RegisterEvent("UPDATE_BINDINGS")

    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            inCombat = InCombatLockdown()
            actionButtonsCached = false
            C_Timer.After(1.0, Refresh)
        elseif event == "PLAYER_REGEN_DISABLED" then
            inCombat = true
            UpdateButtonVisibility()
        elseif event == "PLAYER_REGEN_ENABLED" then
            inCombat = false
            UpdateButtonVisibility()
        elseif event == "PLAYER_TARGET_CHANGED" then
            UpdateButtonVisibility()
            lastSpellID = nil
        elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_BINDINGS" then
            actionButtonsCached = false
        elseif event == "SPELL_UPDATE_COOLDOWN" then
            if assistButton and assistButton:IsShown() then
                UpdateGCDCooldown()
            end
        end
    end)

    -- Watch for setting changes
    local settingPaths = {
        "rotationAssist.cdmHighlight.essential.enabled",
        "rotationAssist.cdmHighlight.essential.color",
        "rotationAssist.cdmHighlight.essential.thickness",
        "rotationAssist.cdmHighlight.essential.style",
        "rotationAssist.cdmHighlight.utility.enabled",
        "rotationAssist.cdmHighlight.utility.color",
        "rotationAssist.cdmHighlight.utility.thickness",
        "rotationAssist.cdmHighlight.utility.style",
        "rotationAssist.actionBarHighlight.enabled",
        "rotationAssist.actionBarHighlight.color",
        "rotationAssist.actionBarHighlight.thickness",
        "rotationAssist.actionBarHighlight.style",
        "rotationAssist.button.enabled",
        "rotationAssist.button.isLocked",
        "rotationAssist.button.iconSize",
        "rotationAssist.button.visibility",
        "rotationAssist.button.frameStrata",
        "rotationAssist.button.showBorder",
        "rotationAssist.button.borderThickness",
        "rotationAssist.button.borderColor",
        "rotationAssist.button.cooldownSwipeEnabled",
        "rotationAssist.button.showKeybind",
        "rotationAssist.button.keybindSize",
        "rotationAssist.button.keybindColor",
        "rotationAssist.button.keybindPoint",
        "rotationAssist.button.keybindOffsetX",
        "rotationAssist.button.keybindOffsetY",
        "rotationAssist.button.anchorFrom",
        "rotationAssist.button.anchorTo",
        "rotationAssist.button.offsetX",
        "rotationAssist.button.offsetY",
    }

    for _, path in ipairs(settingPaths) do
        module:WatchSetting(path, function()
            Refresh()
        end)
    end

    -- Profile change handler
    module:RegisterMessage("TavernUI_ProfileChanged", function()
        HideAllHighlights()
        lastSpellID = nil
        C_Timer.After(0.3, Refresh)
    end)
end

-- Public API for options/refresh
RotationAssist.Refresh = Refresh
RotationAssist.HideAllHighlights = HideAllHighlights

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

module.RotationAssist = RotationAssist
