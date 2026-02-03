local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local Keybinds = {}

local CONSTANTS = {
    DEFAULT_KEYBIND_SIZE = 10,
    UPDATE_THROTTLE = 0.2,
}

local spellToKeybind = {}
local spellNameToKeybind = {}
local itemToKeybind = {}
local cachedActionButtons = {}
local actionButtonsCached = false

local RANGE_INDICATOR = "●"

local function FormatKeybind(keybind)
    if not keybind then return nil end

    local upper = keybind:upper():gsub(" ", "")

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

local function BuildActionButtonCache()
    if actionButtonsCached then return end

    cachedActionButtons = {}
    local added = {}

    local barPrefixes = {
        "ActionButton",
        "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton",
        "MultiBarRightButton",
        "MultiBarLeftButton",
        "MultiBar5Button",
        "MultiBar6Button",
        "MultiBar7Button",
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

    for i = 1, 180 do
        local button = _G["BT4Button" .. i]
        if button and not added[button] then
            cachedActionButtons[#cachedActionButtons + 1] = button
            added[button] = true
        end
    end

    for i = 1, 180 do
        local button = _G["DominosActionButton" .. i]
        if button and not added[button] then
            cachedActionButtons[#cachedActionButtons + 1] = button
            added[button] = true
        end
    end

    for bar = 1, 15 do
        for i = 1, 12 do
            local button = _G["ElvUI_Bar" .. bar .. "Button" .. i]
            if button and not added[button] then
                cachedActionButtons[#cachedActionButtons + 1] = button
                added[button] = true
            end
        end
    end

    for globalName, frame in pairs(_G) do
        if type(globalName) == "string" and type(frame) == "table" and not added[frame] then
            if type(frame.GetObjectType) == "function" then
                local hasAction = frame.action or (frame.GetAction and type(frame.GetAction) == "function")
                if hasAction and globalName:match("Button%d+$") then
                    cachedActionButtons[#cachedActionButtons + 1] = frame
                    added[frame] = true
                end
            end
        end
    end

    actionButtonsCached = true
end

local function GetKeybindFromActionButton(button)
    if not button then return nil end

    local action = GetActionSlot(button)
    if action then
        local keybind = GetKeybindFromActionSlot(action)
        if keybind then return keybind end
    end

    local buttonName = button:GetName()
    if buttonName then
        local key = GetBindingKey("CLICK " .. buttonName .. ":LeftButton")
        if key then return FormatKeybind(key) end
    end

    local hotkeyRegions = {button.HotKey, button.hotKey}
    for _, hotkey in ipairs(hotkeyRegions) do
        if hotkey then
            local ok, text = pcall(function() return hotkey:GetText() end)
            if ok and text and text ~= "" and text ~= RANGE_INDICATOR then
                return FormatKeybind(text)
            end
        end
    end

    if button.GetHotkey then
        local ok, hotkey = pcall(function() return button:GetHotkey() end)
        if ok and hotkey and hotkey ~= "" then
            return FormatKeybind(hotkey)
        end
    end

    return nil
end

local function GetBindingCommandForActionSlot(slot)
    if not slot or slot < 1 or slot > 120 then return nil end

    if slot <= 12 then
        return "ACTIONBUTTON" .. slot
    elseif slot <= 24 then
        return "ACTIONBUTTON" .. (slot - 12)
    elseif slot <= 36 then
        return "MULTIACTIONBAR3BUTTON" .. (slot - 24)
    elseif slot <= 48 then
        return "MULTIACTIONBAR4BUTTON" .. (slot - 36)
    elseif slot <= 60 then
        return "MULTIACTIONBAR2BUTTON" .. (slot - 48)
    elseif slot <= 72 then
        return "MULTIACTIONBAR1BUTTON" .. (slot - 60)
    elseif slot <= 84 then
        return "MULTIACTIONBAR5BUTTON" .. (slot - 72)
    elseif slot <= 96 then
        return "MULTIACTIONBAR6BUTTON" .. (slot - 84)
    elseif slot <= 108 then
        return "MULTIACTIONBAR7BUTTON" .. (slot - 96)
    end

    return nil
end

local function GetKeybindFromActionSlot(slot)
    local cmd = GetBindingCommandForActionSlot(slot)
    if not cmd then return nil end
    local key = GetBindingKey(cmd)
    if key then return FormatKeybind(key) end
    return nil
end

local function ParseMacroForSpells(macroIndex)
    local spellIDs = {}
    local spellNames = {}
    local itemIDs = {}

    local _, _, body = GetMacroInfo(macroIndex)
    if not body then return spellIDs, spellNames, itemIDs end

    local simpleSpell = GetMacroSpell(macroIndex)
    if simpleSpell then
        spellIDs[simpleSpell] = true
        local spellInfo = C_Spell.GetSpellInfo(simpleSpell)
        if spellInfo and spellInfo.name then
            spellNames[spellInfo.name:lower()] = true
        end
    end

    local simpleItem = GetMacroItem(macroIndex)
    if simpleItem then
        local itemID = GetItemInfoInstant(simpleItem)
        if itemID then
            itemIDs[itemID] = true
        end
    end

    for line in body:gmatch("[^\r\n]+") do
        local lineLower = line:lower()

        if not lineLower:match("^%s*%-%-") and not lineLower:match("^%s*//") then
            local patterns = {
                "/cast%s+(.+)",
                "/use%s+(.+)",
                "#showtooltip%s+(.+)",
                "#show%s+(.+)",
            }

            for _, pattern in ipairs(patterns) do
                local match = line:match(pattern)
                if match then
                    match = match:gsub("%[.-%]", " ")
                    for part in match:gmatch("[^;]+") do
                        local name = part:match("^%s*(.-)%s*$")
                        name = name:gsub("%(.-%)", "")
                        name = name:match("^%s*(.-)%s*$")

                        if name and name ~= "" and name ~= "?" then
                            local id = tonumber(name)
                            if id then
                                spellIDs[id] = true
                                local spellInfo = C_Spell.GetSpellInfo(id)
                                if spellInfo and spellInfo.name then
                                    spellNames[spellInfo.name:lower()] = true
                                end
                            else
                                spellNames[name:lower()] = true
                                local spellInfo = C_Spell.GetSpellInfo(name)
                                if spellInfo and spellInfo.spellID then
                                    spellIDs[spellInfo.spellID] = true
                                end
                                local itemID = GetItemInfoInstant(name)
                                if itemID then
                                    itemIDs[itemID] = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return spellIDs, spellNames, itemIDs
end

local function GetActionSlot(button)
    if not button then return nil end

    local action
    local buttonName = button.GetName and button:GetName()

    if buttonName and buttonName:match("^BT4Button") then
        action = button._state_action
    end

    if not action or action == 0 then
        if type(button.action) == "number" and button.action > 0 then
            action = button.action
        end
    end

    if (not action or action == 0) and button.GetAction then
        local ok, r1, r2 = pcall(button.GetAction, button)
        if ok then
            if type(r1) == "number" and r1 > 0 then
                action = r1
            elseif type(r2) == "number" and r2 > 0 then
                action = r2
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
    if not keybind then
        keybind = GetKeybindFromActionSlot(action)
    end
    if not keybind then return end

    if actionType == "spell" and id then
        spellToKeybind[id] = keybind
        local spellInfo = C_Spell.GetSpellInfo(id)
        if spellInfo and spellInfo.name then
            spellNameToKeybind[spellInfo.name:lower()] = keybind
        end

    elseif actionType == "item" and id then
        itemToKeybind[id] = keybind

    elseif actionType == "macro" and id then
        local macroSpellIDs, macroSpellNames, macroItemIDs = ParseMacroForSpells(id)

        for spellID in pairs(macroSpellIDs) do
            spellToKeybind[spellID] = keybind
        end
        for spellName in pairs(macroSpellNames) do
            spellNameToKeybind[spellName] = keybind
        end
        for itemID in pairs(macroItemIDs) do
            itemToKeybind[itemID] = keybind
        end
    end
end

local function RebuildCache()
    BuildActionButtonCache()

    spellToKeybind = {}
    spellNameToKeybind = {}
    itemToKeybind = {}

    for _, button in ipairs(cachedActionButtons) do
        pcall(ProcessActionButton, button)
    end
end

function Keybinds.GetSpellKeybind(spellID, visited)
    if not spellID then return nil end

    visited = visited or {}
    if visited[spellID] then return nil end
    visited[spellID] = true

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
            return Keybinds.GetSpellKeybind(overrideID, visited)
        end
    end

    return nil
end

function Keybinds.GetItemKeybind(itemID)
    if not itemID then return nil end
    return itemToKeybind[itemID]
end

function Keybinds.GetTrinketKeybind(slotID)
    if not slotID then return nil end

    local itemID = GetInventoryItemID("player", slotID)
    if itemID then
        return Keybinds.GetItemKeybind(itemID)
    end
    return nil
end

function Keybinds.UpdateItem(item)
    if not item or not item.frame then return end

    local keybind = nil

    if item.actionSlotID then
        keybind = GetKeybindFromActionSlot(item.actionSlotID)
    end

    if not keybind and item.spellID then
        keybind = Keybinds.GetSpellKeybind(item.spellID)
    end

    if not keybind and item.itemID then
        keybind = Keybinds.GetItemKeybind(item.itemID)
    end

    if not keybind and item.slotID then
        keybind = Keybinds.GetTrinketKeybind(item.slotID)
    end

    if not keybind and item.source == "blizzard" then
        local frame = item.frame
        pcall(function()
            local spellID = frame.GetSpellID and frame:GetSpellID() or frame.spellID
            local itemID = frame.GetItemID and frame:GetItemID() or frame.itemID
            local slotID = frame.GetSlotID and frame:GetSlotID() or frame.slotID

            if frame.cooldownData then
                spellID = spellID or frame.cooldownData.spellID
                itemID = itemID or frame.cooldownData.itemID
                slotID = slotID or frame.cooldownData.slotID
            end

            if spellID and not keybind then
                keybind = Keybinds.GetSpellKeybind(spellID)
            end
            if itemID and not keybind then
                keybind = Keybinds.GetItemKeybind(itemID)
            end
            if slotID and not keybind then
                keybind = Keybinds.GetTrinketKeybind(slotID)
            end
        end)
    end

    local settings = module:GetViewerSettings(item.viewerKey)
    item:setKeybind(keybind, settings)
    item:refreshIcon()
end

function Keybinds.RefreshViewer(viewerKey)
    local items = module.ItemRegistry.GetItemsForViewer(viewerKey)
    if not items then return end

    for _, item in ipairs(items) do
        Keybinds.UpdateItem(item)
    end
end

local updatePending = false

local function ThrottledRebuild()
    if updatePending then return end
    updatePending = true

    C_Timer.After(CONSTANTS.UPDATE_THROTTLE, function()
        updatePending = false
        RebuildCache()
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
    eventFrame:RegisterEvent("UPDATE_MACROS")

    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            actionButtonsCached = false
            C_Timer.After(0.5, function()
                RebuildCache()
                for _, viewerKey in ipairs(module.CONSTANTS.VIEWER_KEYS) do
                    Keybinds.RefreshViewer(viewerKey)
                end
            end)
            return
        end

        ThrottledRebuild()
    end)

    if IsLoggedIn() then
        C_Timer.After(0.1, RebuildCache)
    end
end

Keybinds.GetActionSlotFromButton = GetActionSlot
Keybinds.RebuildCache = RebuildCache
module.Keybinds = Keybinds