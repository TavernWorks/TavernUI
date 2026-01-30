local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

--[[
    Keybinds - Keybind lookup and display
    
    Handles finding keybinds for spells/items/trinkets and displaying them on frames.
]]

local Keybinds = {}

local CONSTANTS = {
    DEFAULT_KEYBIND_SIZE = 10,
    UPDATE_THROTTLE = 0.2,
}

-- Caches
local spellToKeybind = {}
local spellNameToKeybind = {}
local cachedActionButtons = {}
local actionButtonsCached = false
local macroNameCache = {}
local macroCacheBuilt = false

local RANGE_INDICATOR = "●"
local FONT_PATH = "Fonts\\FRIZQT__.TTF"

--------------------------------------------------------------------------------
-- Keybind Formatting
--------------------------------------------------------------------------------

local function FormatKeybind(keybind)
    if not keybind then return nil end
    
    local upper = keybind:upper():gsub(" ", "")
    
    -- Mouse buttons
    upper = upper:gsub("MOUSEWHEELUP", "WU")
    upper = upper:gsub("MOUSEWHEELDOWN", "WD")
    upper = upper:gsub("MIDDLEMOUSE", "B3")
    upper = upper:gsub("MIDDLEBUTTON", "B3")
    upper = upper:gsub("BUTTON(%d+)", "B%1")
    
    -- Modifiers
    upper = upper:gsub("SHIFT%-", "S")
    upper = upper:gsub("CTRL%-", "C")
    upper = upper:gsub("ALT%-", "A")
    
    -- Numpad
    upper = upper:gsub("NUMPADPLUS", "N+")
    upper = upper:gsub("NUMPADMINUS", "N-")
    upper = upper:gsub("NUMPADMULTIPLY", "N*")
    upper = upper:gsub("NUMPADDIVIDE", "N/")
    upper = upper:gsub("NUMPADPERIOD", "N.")
    upper = upper:gsub("NUMPADENTER", "NE")
    upper = upper:gsub("NUMPAD", "N")
    
    -- Special keys
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
    
    -- Arrow keys
    upper = upper:gsub("UPARROW", "UP")
    upper = upper:gsub("DOWNARROW", "DN")
    upper = upper:gsub("LEFTARROW", "LF")
    upper = upper:gsub("RIGHTARROW", "RT")
    
    -- Truncate
    if #upper > 4 then
        upper = upper:sub(1, 4)
    end
    
    return upper
end

--------------------------------------------------------------------------------
-- Action Button Cache
--------------------------------------------------------------------------------

local function BuildActionButtonCache()
    if actionButtonsCached then return end
    
    cachedActionButtons = {}
    
    -- Standard action bars
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
            if button then
                cachedActionButtons[#cachedActionButtons + 1] = button
            end
        end
    end
    
    -- Bartender4
    for i = 1, 120 do
        local button = _G["BT4Button" .. i]
        if button then
            cachedActionButtons[#cachedActionButtons + 1] = button
        end
    end
    
    -- Dominos
    for i = 1, 120 do
        local button = _G["DominosActionButton" .. i]
        if button then
            cachedActionButtons[#cachedActionButtons + 1] = button
        end
    end
    
    -- ElvUI
    for bar = 1, 10 do
        for i = 1, 12 do
            local button = _G["ElvUI_Bar" .. bar .. "Button" .. i]
            if button then
                cachedActionButtons[#cachedActionButtons + 1] = button
            end
        end
    end
    
    actionButtonsCached = true
end

local function GetKeybindFromActionButton(button)
    if not button then return nil end
    
    -- Try HotKey text
    local hotkeyRegions = {button.HotKey, button.hotKey}
    for _, hotkey in ipairs(hotkeyRegions) do
        if hotkey then
            local ok, text = pcall(function() return hotkey:GetText() end)
            if ok and text and text ~= "" and text ~= RANGE_INDICATOR then
                return FormatKeybind(text)
            end
        end
    end
    
    -- Try GetHotkey method
    if button.GetHotkey then
        local ok, hotkey = pcall(function() return button:GetHotkey() end)
        if ok and hotkey and hotkey ~= "" then
            return FormatKeybind(hotkey)
        end
    end
    
    -- Try binding lookup by button name
    local buttonName = button:GetName()
    if buttonName then
        local key = GetBindingKey("CLICK " .. buttonName .. ":LeftButton")
        if key then return FormatKeybind(key) end
    end
    
    return nil
end

--------------------------------------------------------------------------------
-- Cache Building
--------------------------------------------------------------------------------

local function ParseMacroForSpells(macroIndex)
    local spellIDs = {}
    local spellNames = {}
    
    local macroName, _, body = GetMacroInfo(macroIndex)
    if not body then return spellIDs, spellNames end
    
    -- Try simple spell lookup first
    local simpleSpell = GetMacroSpell(macroIndex)
    if simpleSpell then
        spellIDs[simpleSpell] = true
        local spellInfo = C_Spell.GetSpellInfo(simpleSpell)
        if spellInfo and spellInfo.name then
            spellNames[spellInfo.name:lower()] = true
        end
    end
    
    -- Parse macro body for /cast and /use commands
    for line in body:gmatch("[^\r\n]+") do
        local lineLower = line:lower()
        if not lineLower:match("^%s*%-%-") then
            local spellName = nil
            
            -- /cast command
            if lineLower:match("/cast") then
                local afterCast = line:match("/[cC][aA][sS][tT]%s*(.*)")
                if afterCast then
                    afterCast = afterCast:gsub("%[.-%]", "")
                    spellName = afterCast:match("^%s*(.-)%s*$")
                end
            end
            
            -- /use command
            if not spellName or spellName == "" then
                if lineLower:match("/use") then
                    local afterUse = line:match("/[uU][sS][eE]%s*(.*)")
                    if afterUse then
                        afterUse = afterUse:gsub("%[.-%]", "")
                        spellName = afterUse:match("^%s*(.-)%s*$")
                    end
                end
            end
            
            -- #showtooltip
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
                end
            end
        end
    end
    
    return spellIDs, spellNames
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

local function ProcessActionButton(button)
    local action = GetActionSlot(button)
    if not action then return end

    local ok, actionType, id = pcall(GetActionInfo, action)
    if not ok or not actionType then return end

    local keybind = GetKeybindFromActionButton(button)
    if keybind then
        if actionType == "spell" and id then
            if not spellToKeybind[id] then
                spellToKeybind[id] = keybind
            end
            local spellInfo = C_Spell.GetSpellInfo(id)
            if spellInfo and spellInfo.name and not spellNameToKeybind[spellInfo.name:lower()] then
                spellNameToKeybind[spellInfo.name:lower()] = keybind
            end
        elseif actionType == "item" and id then
            if not spellToKeybind[id] then
                spellToKeybind[id] = keybind
            end
        elseif actionType == "macro" and id then
            local spellIDs, spellNames = ParseMacroForSpells(id)
            for spellID in pairs(spellIDs) do
                if not spellToKeybind[spellID] then
                    spellToKeybind[spellID] = keybind
                end
            end
            for spellName in pairs(spellNames) do
                if not spellNameToKeybind[spellName] then
                    spellNameToKeybind[spellName] = keybind
                end
            end
        end
    end
end

local function RebuildCache(forceRebuild)
    if not forceRebuild and next(spellToKeybind) then return end

    BuildActionButtonCache()

    spellToKeybind = {}
    spellNameToKeybind = {}

    for _, button in ipairs(cachedActionButtons) do
        pcall(ProcessActionButton, button)
    end
end

--------------------------------------------------------------------------------
-- Keybind Lookup
--------------------------------------------------------------------------------

function Keybinds.GetSpellKeybind(spellID)
    if not spellID then return nil end

    RebuildCache(false)

    local ok, result = pcall(function()
        if spellToKeybind[spellID] then
            return spellToKeybind[spellID]
        end
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        if spellInfo and spellInfo.name then
            local nameLower = spellInfo.name:lower()
            if spellNameToKeybind[nameLower] then
                return spellNameToKeybind[nameLower]
            end
        end
        if C_Spell.GetOverrideSpell then
            local overrideID = C_Spell.GetOverrideSpell(spellID)
            if overrideID and overrideID ~= spellID then
                return Keybinds.GetSpellKeybind(overrideID)
            end
        end
        return nil
    end)
    if ok then return result end
    return nil
end

function Keybinds.GetItemKeybind(itemID)
    if not itemID then return nil end

    RebuildCache(false)
    local ok, result = pcall(function() return spellToKeybind[itemID] end)
    if ok then return result end
    return nil
end

function Keybinds.GetTrinketKeybind(slotID)
    if not slotID then return nil end
    
    local itemID = GetInventoryItemID("player", slotID)
    if itemID then
        return Keybinds.GetItemKeybind(itemID)
    end
    return nil
end

--------------------------------------------------------------------------------
-- Keybind Display
--------------------------------------------------------------------------------

function Keybinds.UpdateItem(item)
    if not item or not item.frame then return end
    
    local settings = module:GetViewerSettings(item.viewerKey)
    if not settings or not settings.showKeybinds then
        if item.frame._ucdmKeybindText then
            item.frame._ucdmKeybindText:Hide()
        end
        return
    end
    
    local frame = item.frame
    
    -- Get keybind based on what the item is tracking
    local keybind = nil
    if item.spellID then
        keybind = Keybinds.GetSpellKeybind(item.spellID)
    elseif item.itemID then
        keybind = Keybinds.GetItemKeybind(item.itemID)
    elseif item.slotID then
        keybind = Keybinds.GetTrinketKeybind(item.slotID)
    end
    
    if not keybind and item.source == "blizzard" then
        local spellID, itemID, slotID = nil, nil, nil
        pcall(function()
            spellID = frame.GetSpellID and frame:GetSpellID() or frame.spellID
            itemID = frame.GetItemID and frame:GetItemID() or frame.itemID
            slotID = frame.GetSlotID and frame:GetSlotID() or frame.slotID
            if frame.cooldownData then
                spellID = spellID or frame.cooldownData.spellID
                itemID = itemID or frame.cooldownData.itemID
                slotID = slotID or frame.cooldownData.slotID
            end
        end)
        if spellID then
            keybind = Keybinds.GetSpellKeybind(spellID)
        elseif itemID then
            keybind = Keybinds.GetItemKeybind(itemID)
        elseif slotID then
            keybind = Keybinds.GetTrinketKeybind(slotID)
        end
    end
    
    -- Create or update keybind text
    if not frame._ucdmKeybindText then
        frame._ucdmKeybindText = frame:CreateFontString(nil, "OVERLAY")
    end
    
    local keybindText = frame._ucdmKeybindText
    keybindText:SetFont(FONT_PATH, settings.keybindSize or CONSTANTS.DEFAULT_KEYBIND_SIZE, "OUTLINE")
    
    local bindPoint = frame
    if frame.Icon then
        bindPoint = frame.Icon
    end
    
    if keybind then
        local color = settings.keybindColor or {r = 1, g = 1, b = 1, a = 1}
        keybindText:SetText(keybind)
        keybindText:SetTextColor(color.r, color.g, color.b, color.a)
        keybindText:ClearAllPoints()
        keybindText:SetPoint(
            settings.keybindPoint or "TOPLEFT",
            bindPoint,
            settings.keybindPoint or "TOPLEFT",
            settings.keybindOffsetX or 2,
            settings.keybindOffsetY or -2
        )
        keybindText:Show()
    else
        keybindText:Hide()
    end
end

--------------------------------------------------------------------------------
-- Viewer Refresh
--------------------------------------------------------------------------------

function Keybinds.RefreshViewer(viewerKey)
    local items = module.ItemRegistry.GetItemsForViewer(viewerKey)
    if not items then return end
    
    for _, item in ipairs(items) do
        Keybinds.UpdateItem(item)
    end
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local updatePending = false

local function ThrottledRebuild(forceRebuild)
    if updatePending then return end
    updatePending = true
    
    C_Timer.After(CONSTANTS.UPDATE_THROTTLE, function()
        updatePending = false
        RebuildCache(forceRebuild)
        for _, viewerKey in ipairs(module.CONSTANTS.VIEWER_KEYS) do
            Keybinds.RefreshViewer(viewerKey)
        end
    end)
end

function Keybinds.Initialize()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    eventFrame:RegisterEvent("UPDATE_BINDINGS")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("SPELLS_CHANGED")
    
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            actionButtonsCached = false
            macroCacheBuilt = false
            RebuildCache(true)
            for _, viewerKey in ipairs(module.CONSTANTS.VIEWER_KEYS) do
                Keybinds.RefreshViewer(viewerKey)
            end
            return
        end
        
        if event == "UPDATE_BINDINGS" or event == "ACTIONBAR_SLOT_CHANGED" then
            macroCacheBuilt = false
            macroNameCache = {}
            ThrottledRebuild(true)
            return
        end
        
        if event == "SPELLS_CHANGED" then
            ThrottledRebuild(false)
            return
        end
    end)
    
    if IsLoggedIn() then
        RebuildCache(true)
    end
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

module.Keybinds = Keybinds
