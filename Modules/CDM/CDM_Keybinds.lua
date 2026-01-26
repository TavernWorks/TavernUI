-- CDM Keybinds Module
-- Displays action bar keybinds on Essential and Utility cooldown viewer icons

local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("CDM")

if not module then return end

local VIEWER_ESSENTIAL = module.VIEWER_ESSENTIAL or "EssentialCooldownViewer"
local VIEWER_UTILITY = module.VIEWER_UTILITY or "UtilityCooldownViewer"

-- Cache for spell ID to keybind mapping
local spellToKeybind = {}
-- Cache for spell NAME to keybind mapping (fallback for macros)
local spellNameToKeybind = {}
local lastCacheUpdate = 0
local CACHE_UPDATE_INTERVAL = 1.0

-- Cache of known action buttons (built once, reused)
local cachedActionButtons = {}
local actionButtonsCached = false

-- Macro name to index cache (avoid looping through all macros)
local macroNameCache = {}
local macroCacheBuilt = false

-- Timer for periodic cache refresh
local cacheRefreshTimer = nil

local pendingRebuild = false

local function GetSettings(key)
    return module.GetSettings and module.GetSettings(key)
end

-- Format keybind text for display (shorten modifiers, max 4 chars)
local function FormatKeybind(keybind)
    if not keybind then return nil end

    local upper = keybind:upper()
    upper = upper:gsub(" ", "")
    
    upper = upper:gsub("MOUSEWHEELUP", "WU")
    upper = upper:gsub("MOUSEWHEELDOWN", "WD")
    upper = upper:gsub("MIDDLEMOUSE", "B3")
    upper = upper:gsub("MIDDLEBUTTON", "B3")
    upper = upper:gsub("BUTTON(%d+)", "B%1")
    
    upper = upper:gsub("SHIFT%-", "S")
    upper = upper:gsub("CTRL%-", "C")
    upper = upper:gsub("ALT%-", "A")
    
    upper = upper:gsub("NUMPADPLUS", "N+")
    upper = upper:gsub("NUMPADMINUS", "N-")
    upper = upper:gsub("NUMPADMULTIPLY", "N*")
    upper = upper:gsub("NUMPADDIVIDE", "N/")
    upper = upper:gsub("NUMPADPERIOD", "N.")
    upper = upper:gsub("NUMPADENTER", "NE")
    upper = upper:gsub("NUMPAD", "N")
    upper = upper:gsub("CAPSLOCK", "CAP")
    upper = upper:gsub("DELETE", "DEL")
    upper = upper:gsub("ESCAPE", "ESC")
    upper = upper:gsub("BACKSPACE", "BS")
    upper = upper:gsub("SPACE", "SP")
    upper = upper:gsub("INSERT", "INS")
    upper = upper:gsub("PAGEUP", "PU")
    upper = upper:gsub("PAGEDOWN", "PD")
    upper = upper:gsub("HOME", "HM")
    upper = upper:gsub("END", "ED")
    
    upper = upper:gsub("UPARROW", "UP")
    upper = upper:gsub("DOWNARROW", "DN")
    upper = upper:gsub("LEFTARROW", "LF")
    upper = upper:gsub("RIGHTARROW", "RT")
    
    if #upper > 4 then
        upper = upper:sub(1, 4)
    end

    return upper
end

-- Get the keybind for an action button by scanning the button directly
local function GetKeybindFromActionButton(button, actionSlot)
    if not button then return nil end
    
    if button.HotKey then
        local ok, hotkeyText = pcall(function() return button.HotKey:GetText() end)
        if ok and hotkeyText and hotkeyText ~= "" and hotkeyText ~= RANGE_INDICATOR then
            return FormatKeybind(hotkeyText)
        end
    end
    
    if button.hotKey then
        local ok, hotkeyText = pcall(function() return button.hotKey:GetText() end)
        if ok and hotkeyText and hotkeyText ~= "" and hotkeyText ~= RANGE_INDICATOR then
            return FormatKeybind(hotkeyText)
        end
    end
    
    if button.GetHotkey then
        local ok, hotkey = pcall(function() return button:GetHotkey() end)
        if ok and hotkey and hotkey ~= "" then
            return FormatKeybind(hotkey)
        end
    end
    
    local buttonName = button:GetName()
    if buttonName then
        local key1 = GetBindingKey("CLICK " .. buttonName .. ":LeftButton")
        if key1 then
            return FormatKeybind(key1)
        end
        
        if buttonName:match("ActionButton(%d+)$") then
            local num = tonumber(buttonName:match("ActionButton(%d+)$"))
            if num then
                key1 = GetBindingKey("ACTIONBUTTON" .. num)
                if key1 then return FormatKeybind(key1) end
            end
        elseif buttonName:match("MultiBarBottomLeftButton(%d+)$") then
            local num = tonumber(buttonName:match("MultiBarBottomLeftButton(%d+)$"))
            if num then
                key1 = GetBindingKey("MULTIACTIONBAR1BUTTON" .. num)
                if key1 then return FormatKeybind(key1) end
            end
        elseif buttonName:match("MultiBarBottomRightButton(%d+)$") then
            local num = tonumber(buttonName:match("MultiBarBottomRightButton(%d+)$"))
            if num then
                key1 = GetBindingKey("MULTIACTIONBAR2BUTTON" .. num)
                if key1 then return FormatKeybind(key1) end
            end
        elseif buttonName:match("MultiBarRightButton(%d+)$") then
            local num = tonumber(buttonName:match("MultiBarRightButton(%d+)$"))
            if num then
                key1 = GetBindingKey("MULTIACTIONBAR3BUTTON" .. num)
                if key1 then return FormatKeybind(key1) end
            end
        elseif buttonName:match("MultiBarLeftButton(%d+)$") then
            local num = tonumber(buttonName:match("MultiBarLeftButton(%d+)$"))
            if num then
                key1 = GetBindingKey("MULTIACTIONBAR4BUTTON" .. num)
                if key1 then return FormatKeybind(key1) end
            end
        elseif buttonName:match("^BT4Button(%d+)$") then
            local num = tonumber(buttonName:match("^BT4Button(%d+)$"))
            if num then
                key1 = GetBindingKey("CLICK " .. buttonName .. ":Keybind")
                if not key1 then
                    key1 = GetBindingKey("CLICK " .. buttonName .. ":LeftButton")
                end
                if not key1 and actionSlot then
                    local bar = math.ceil(num / 12)
                    local buttonInBar = ((num - 1) % 12) + 1
                    if bar == 1 then
                        key1 = GetBindingKey("ACTIONBUTTON" .. buttonInBar)
                    elseif bar == 3 then
                        key1 = GetBindingKey("MULTIACTIONBAR3BUTTON" .. buttonInBar)
                    elseif bar == 4 then
                        key1 = GetBindingKey("MULTIACTIONBAR4BUTTON" .. buttonInBar)
                    elseif bar == 5 then
                        key1 = GetBindingKey("MULTIACTIONBAR2BUTTON" .. buttonInBar)
                    elseif bar == 6 then
                        key1 = GetBindingKey("MULTIACTIONBAR1BUTTON" .. buttonInBar)
                    end
                end
                if key1 then return FormatKeybind(key1) end
            end
        elseif buttonName:match("^DominosActionButton(%d+)$") then
            local num = tonumber(buttonName:match("^DominosActionButton(%d+)$"))
            if num then
                key1 = GetBindingKey("CLICK " .. buttonName .. ":LeftButton")
                if not key1 and num <= 12 then
                    key1 = GetBindingKey("ACTIONBUTTON" .. num)
                elseif not key1 and num <= 24 then
                    key1 = GetBindingKey("ACTIONBUTTON" .. (num - 12))
                elseif not key1 and num <= 36 then
                    key1 = GetBindingKey("MULTIACTIONBAR3BUTTON" .. (num - 24))
                elseif not key1 and num <= 48 then
                    key1 = GetBindingKey("MULTIACTIONBAR4BUTTON" .. (num - 36))
                elseif not key1 and num <= 60 then
                    key1 = GetBindingKey("MULTIACTIONBAR1BUTTON" .. (num - 48))
                elseif not key1 and num <= 72 then
                    key1 = GetBindingKey("MULTIACTIONBAR2BUTTON" .. (num - 60))
                end
                if key1 then return FormatKeybind(key1) end
            end
        end
    end

    return nil
end

-- Parse macro body text to extract spell names/IDs
local function ParseMacroForSpells(macroIndex)
    local spellIDs = {}
    local spellNames = {}
    
    local macroName, iconTexture, body = GetMacroInfo(macroIndex)
    if not body then return spellIDs, spellNames end
    
    local simpleSpell = GetMacroSpell(macroIndex)
    if simpleSpell then
        spellIDs[simpleSpell] = true
        local spellInfo = C_Spell.GetSpellInfo(simpleSpell)
        if spellInfo and spellInfo.name then
            spellNames[spellInfo.name:lower()] = true
        end
    end
    
    for line in body:gmatch("[^\r\n]+") do
        local lineLower = line:lower()
        
        if not lineLower:match("^%s*%-%-") then
            local spellName = nil
            
            if lineLower:match("/cast") then
                local afterCast = line:match("/[cC][aA][sS][tT]%s*(.*)")
                if afterCast then
                    afterCast = afterCast:gsub("%[.-%]", "")
                    spellName = afterCast:match("^%s*(.-)%s*$")
                end
            end
            
            if not spellName or spellName == "" then
                if lineLower:match("/use") then
                    local afterUse = line:match("/[uU][sS][eE]%s*(.*)")
                    if afterUse then
                        afterUse = afterUse:gsub("%[.-%]", "")
                        spellName = afterUse:match("^%s*(.-)%s*$")
                    end
                end
            end
            
            if not spellName or spellName == "" then
                if lineLower:match("#showtooltip") then
                    spellName = line:match("#[sS][hH][oO][wW][tT][oO][oO][lL][tT][iI][pP]%s+(.+)")
                    if spellName then
                        spellName = spellName:match("^%s*(.-)%s*$")
                    end
                end
            end
            
            if spellName and spellName ~= "" and spellName ~= "?" then
                spellName = spellName:match("^([^;/]+)")
                if spellName then
                    spellName = spellName:match("^%s*(.-)%s*$")
                end
                
                if spellName and spellName ~= "" then
                    spellNames[spellName:lower()] = true
                    
                    local spellInfo = C_Spell.GetSpellInfo(spellName)
                    if spellInfo and spellInfo.spellID then
                        spellIDs[spellInfo.spellID] = true
                    end
                end
            end
        end
    end
    
    return spellIDs, spellNames
end

-- Helper to process an action button and add to cache
local function ProcessActionButton(button)
    if not button then return end

    local buttonName = button:GetName()
    local action

    if buttonName and buttonName:match("^BT4Button") then
        action = button._state_action
        if not action and button.GetAction then
            local actionType, actionSlot = button:GetAction()
            if actionType == "action" then
                action = actionSlot
            end
        end
    else
        action = button.action or (button.GetAction and button:GetAction())
    end

    if not action or action == 0 then return end
    
    local actionType, id = GetActionInfo(action)
    local keybind = nil
    
    if actionType == "spell" and id then
        keybind = keybind or GetKeybindFromActionButton(button, action)
        if keybind then
            if not spellToKeybind[id] then
                spellToKeybind[id] = keybind
            end
            local spellInfo = C_Spell.GetSpellInfo(id)
            if spellInfo and spellInfo.name then
                local nameLower = spellInfo.name:lower()
                if not spellNameToKeybind[nameLower] then
                    spellNameToKeybind[nameLower] = keybind
                end
            end
        end
    elseif actionType == "macro" then
        keybind = keybind or GetKeybindFromActionButton(button, action)
        if not keybind then return end
        
        local macroName = id and GetMacroInfo(id)
        
        if macroName then
            local macroSpells, macroSpellNames = ParseMacroForSpells(id)
            
            for spellID in pairs(macroSpells) do
                if not spellToKeybind[spellID] then
                    spellToKeybind[spellID] = keybind
                end
            end
            for spellName in pairs(macroSpellNames) do
                if not spellNameToKeybind[spellName] then
                    spellNameToKeybind[spellName] = keybind
                end
            end
        else
            if id and id > 0 then
                if not spellToKeybind[id] then
                    spellToKeybind[id] = keybind
                end
                local spellInfo = C_Spell.GetSpellInfo(id)
                if spellInfo and spellInfo.name then
                    local nameLower = spellInfo.name:lower()
                    if not spellNameToKeybind[nameLower] then
                        spellNameToKeybind[nameLower] = keybind
                    end
                end
            end
            
            local actionText = GetActionText(action)
            if actionText and actionText ~= "" then
                if not macroCacheBuilt then
                    for i = 1, 138 do
                        local mName = GetMacroInfo(i)
                        if mName then
                            macroNameCache[mName:lower()] = i
                        end
                    end
                    macroCacheBuilt = true
                end
                
                local macroIndex = macroNameCache[actionText:lower()]
                if macroIndex then
                    local macroSpells, macroSpellNames = ParseMacroForSpells(macroIndex)
                    for spellID in pairs(macroSpells) do
                        if not spellToKeybind[spellID] then
                            spellToKeybind[spellID] = keybind
                        end
                    end
                    for spellName in pairs(macroSpellNames) do
                        if not spellNameToKeybind[spellName] then
                            spellNameToKeybind[spellName] = keybind
                        end
                    end
                end
            end
        end
    end
end

-- Build the list of action buttons ONCE
local function BuildActionButtonCache()
    if actionButtonsCached then return end
    
    wipe(cachedActionButtons)
    local addedButtons = {}
    
    local buttonPrefixes = {
        "ActionButton",
        "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton",
        "MultiBarRightButton",
        "MultiBarLeftButton",
        "MultiBar5Button",
        "MultiBar6Button",
        "MultiBar7Button",
        "OverrideActionBarButton",
        "BT4Button",
        "DominosActionButton",
        "ElvUI_Bar1Button",
        "ElvUI_Bar2Button",
        "ElvUI_Bar3Button",
        "ElvUI_Bar4Button",
        "ElvUI_Bar5Button",
        "ElvUI_Bar6Button",
    }
    
    for _, prefix in ipairs(buttonPrefixes) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            if button and not addedButtons[button] then
                table.insert(cachedActionButtons, button)
                addedButtons[button] = true
            end
        end
    end
    
    for i = 1, 180 do
        local button = _G["DominosActionButton" .. i]
        if button and not addedButtons[button] then
            table.insert(cachedActionButtons, button)
            addedButtons[button] = true
        end
    end

    for i = 1, 120 do
        local button = _G["BT4Button" .. i]
        if button and not addedButtons[button] then
            table.insert(cachedActionButtons, button)
            addedButtons[button] = true
        end
    end

    table.sort(cachedActionButtons, function(a, b)
        local nameA = (type(a.GetName) == "function") and a:GetName() or ""
        local nameB = (type(b.GetName) == "function") and b:GetName() or ""

        local numA = nameA:match("^BT4Button(%d+)$")
        local numB = nameB:match("^BT4Button(%d+)$")
        if numA and numB then
            return tonumber(numA) < tonumber(numB)
        end

        numA = nameA:match("^DominosActionButton(%d+)$")
        numB = nameB:match("^DominosActionButton(%d+)$")
        if numA and numB then
            return tonumber(numA) < tonumber(numB)
        end

        local priorityA = nameA:match("^BT4") and 1 or nameA:match("^Dominos") and 2 or nameA:match("^ElvUI") and 3 or 4
        local priorityB = nameB:match("^BT4") and 1 or nameB:match("^Dominos") and 2 or nameB:match("^ElvUI") and 3 or 4
        if priorityA ~= priorityB then
            return priorityA < priorityB
        end

        return false
    end)

    actionButtonsCached = true
end

-- Scan cached action buttons and build spell-to-keybind cache
local function RebuildCache()
    if not actionButtonsCached then
        BuildActionButtonCache()
    end
    
    macroCacheBuilt = false
    wipe(macroNameCache)
    wipe(spellToKeybind)
    wipe(spellNameToKeybind)

    for _, button in ipairs(cachedActionButtons) do
        pcall(ProcessActionButton, button)
    end
    
    lastCacheUpdate = GetTime()
    pendingRebuild = false
end

-- Periodic cache refresh using timer instead of checking on every lookup
local function StartCacheRefreshTimer()
    if cacheRefreshTimer then
        cacheRefreshTimer:Cancel()
    end
    cacheRefreshTimer = C_Timer.NewTicker(CACHE_UPDATE_INTERVAL, function()
        if GetTime() - lastCacheUpdate >= CACHE_UPDATE_INTERVAL then
            RebuildCache()
        end
    end)
end

-- Get keybind for a spell ID (uses cache)
local function GetKeybindForSpell(spellID)
    if not spellID then return nil end
    
    local ok, result = pcall(function()
        return spellToKeybind[spellID]
    end)
    
    if ok then
        return result
    end
    return nil
end

-- Get keybind for a spell name (fallback for macros)
local function GetKeybindForSpellName(spellName)
    if not spellName then return nil end
    
    local ok, nameLower = pcall(function() return spellName:lower() end)
    if not ok or not nameLower then return nil end
    
    return spellNameToKeybind[nameLower]
end

-- Apply keybind text to a cooldown icon
local function ApplyKeybindToIcon(icon, viewerName)
    if not module:IsEnabled() then return end
    
    local trackerKey = viewerName == VIEWER_ESSENTIAL and "essential" or "utility"
    local settings = GetSettings(trackerKey)
    if not settings then return end
    
    if not settings.showKeybinds then
        if icon.keybindText then
            icon.keybindText:Hide()
        end
        return
    end
    
    local spellID
    local spellName
    local ok, result = pcall(function()
        local id = icon.spellID
        if not id and icon.GetSpellID then
            id = icon:GetSpellID()
        end
        return id
    end)
    
    if ok then
        spellID = result
    end
    
    if not spellID and icon.action then
        local actionOk, actionType, id = pcall(GetActionInfo, icon.action)
        if actionOk and actionType == "spell" then
            spellID = id
        end
    end
    
    pcall(function()
        if icon.cooldownInfo and icon.cooldownInfo.name then
            local testOk, _ = pcall(function() return icon.cooldownInfo.name:len() end)
            if testOk then
                spellName = icon.cooldownInfo.name
            end
        end
        if not spellName and spellID then
            local info = C_Spell.GetSpellInfo(spellID)
            if info and info.name then
                local testOk, _ = pcall(function() return info.name:len() end)
                if testOk then
                    spellName = info.name
                end
            end
        end
    end)
    
    local keybind = nil
    
    if spellID then
        if icon._lastSpellID and icon._lastSpellID ~= spellID then
            icon._lastKeybind = nil
        end
        
        keybind = GetKeybindForSpell(spellID)
        
        if not keybind then
            local ok, result = pcall(function()
                return C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(spellID)
            end)
            if ok and result and result ~= spellID then
                keybind = GetKeybindForSpell(result)
            end
        end
        
        if keybind then
            icon._lastKeybind = keybind
            icon._lastSpellID = spellID
        elseif icon._lastSpellID == spellID and icon._lastKeybind then
            keybind = icon._lastKeybind
        end
    end
    
    if not keybind and spellName then
        keybind = GetKeybindForSpellName(spellName)
        if keybind then
            icon._lastKeybind = keybind
            if spellID then
                icon._lastSpellID = spellID
            end
        end
    end
    
    if not keybind and not spellID and icon._lastKeybind then
        keybind = icon._lastKeybind
    end
    
    local keybindSize = settings.keybindSize or 10
    local keybindPoint = settings.keybindPoint or "TOPLEFT"
    local keybindOffsetX = settings.keybindOffsetX or 2
    local keybindOffsetY = settings.keybindOffsetY or -2
    local keybindColor = settings.keybindColor or {r = 1, g = 1, b = 1, a = 1}
    
    if not icon.keybindText then
        local textFrame = CreateFrame("Frame", nil, icon)
        textFrame:SetFrameStrata("TOOLTIP")
        textFrame:SetFrameLevel(icon:GetFrameLevel() + 100)
        textFrame:SetAllPoints(icon)
        
        icon.keybindText = textFrame:CreateFontString(nil, "OVERLAY")
        icon.keybindText:SetShadowOffset(1, -1)
        icon.keybindText:SetShadowColor(0, 0, 0, 1)
    end
    
    icon.keybindText:GetParent():SetFrameStrata("TOOLTIP")
    icon.keybindText:GetParent():SetFrameLevel(icon:GetFrameLevel() + 100)
    
    icon.keybindText:ClearAllPoints()
    icon.keybindText:SetPoint(keybindPoint, icon, keybindPoint, keybindOffsetX, keybindOffsetY)
    
    icon.keybindText:SetFont("Fonts\\FRIZQT__.TTF", keybindSize, "OUTLINE")
    
    icon.keybindText:SetTextColor(keybindColor.r, keybindColor.g, keybindColor.b, keybindColor.a or 1)
    
    if keybind then
        icon.keybindText:SetText(keybind)
        icon.keybindText:Show()
    else
        if icon.keybindText then
            icon.keybindText:SetText("")
            icon.keybindText:Hide()
        end
        icon._lastKeybind = nil
    end
end

-- Update keybinds on all icons in a viewer
local function UpdateViewerKeybinds(viewerName)
    local viewer = _G[viewerName]
    if not viewer then return end
    
    local numChildren = viewer:GetNumChildren()
    for i = 1, numChildren do
        local child = select(i, viewer:GetChildren())
        if child and child ~= viewer.Selection and child:IsShown() then
            if (child.Icon or child.icon) and (child.Cooldown or child.cooldown) then
                ApplyKeybindToIcon(child, viewerName)
            end
        end
    end
end

-- Update keybinds on Essential and Utility viewers
local function UpdateAllKeybinds()
    lastCacheUpdate = 0
    RebuildCache()
    StartCacheRefreshTimer()
    
    UpdateViewerKeybinds(VIEWER_ESSENTIAL)
    UpdateViewerKeybinds(VIEWER_UTILITY)
end

-- Throttle for event-driven updates
local updatePending = false
local UPDATE_THROTTLE = 0.5

local function ThrottledUpdate()
    if updatePending then return end
    updatePending = true
    
    C_Timer.After(UPDATE_THROTTLE, function()
        updatePending = false
        UpdateAllKeybinds()
    end)
end

-- Event frame for cache updates
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
eventFrame:RegisterEvent("UPDATE_BINDINGS")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingRebuild then
            C_Timer.After(0.2, UpdateAllKeybinds)
        end
        return
    end
    
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, function()
            actionButtonsCached = false
            macroCacheBuilt = false
            UpdateAllKeybinds()
        end)
        return
    end
    
    if event == "UPDATE_BINDINGS" or event == "ACTIONBAR_SLOT_CHANGED" then
        macroCacheBuilt = false
        wipe(macroNameCache)
        wipe(spellToKeybind)
        wipe(spellNameToKeybind)
    end
    
    ThrottledUpdate()
end)

-- Hook into viewer layout updates
local function HookViewerLayout(viewerName)
    local viewer = _G[viewerName]
    if not viewer then return end
    
    if viewer.Layout and not viewer._CDM_KeybindHooked then
        viewer._CDM_KeybindHooked = true
        hooksecurefunc(viewer, "Layout", function()
            C_Timer.After(0.15, function()
                UpdateViewerKeybinds(viewerName)
            end)
        end)
    end
end

-- Initialize hooks when viewers are available
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

initFrame:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" and arg == "Blizzard_CooldownManager" then
        C_Timer.After(0.5, function()
            HookViewerLayout(VIEWER_ESSENTIAL)
            HookViewerLayout(VIEWER_UTILITY)
            UpdateAllKeybinds()
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.0, function()
            HookViewerLayout(VIEWER_ESSENTIAL)
            HookViewerLayout(VIEWER_UTILITY)
            UpdateAllKeybinds()
        end)
    end
end)

-- Cleanup on disable
if module and module.OnDisable then
    local originalOnDisable = module.OnDisable
    module.OnDisable = function(self)
        if cacheRefreshTimer then
            cacheRefreshTimer:Cancel()
            cacheRefreshTimer = nil
        end
        if originalOnDisable then
            originalOnDisable(self)
        end
    end
end

-- Export functions
if module then
    module.UpdateAllKeybinds = UpdateAllKeybinds
    module.UpdateViewerKeybinds = UpdateViewerKeybinds
    module.ApplyKeybindToIcon = ApplyKeybindToIcon
end
