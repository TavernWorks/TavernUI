local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local Keybinds = {}

local spellToKeybind = {}
local spellNameToKeybind = {}
local cachedActionButtons = {}
local actionButtonsCached = false
local macroNameCache = {}
local macroCacheBuilt = false
local cachedSpellIDs = {}

local RANGE_INDICATOR = "●"

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
        keybind = GetKeybindFromActionButton(button, action)
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
    elseif actionType == "item" and id then
        keybind = GetKeybindFromActionButton(button, action)
        if keybind then
            if not spellToKeybind[id] then
                spellToKeybind[id] = keybind
            end
        end
    elseif actionType == "macro" then
        keybind = GetKeybindFromActionButton(button, action)
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

local function BuildActionButtonCache()
    if actionButtonsCached then return end
    
    cachedActionButtons = {}
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

local function RebuildCache(forceRebuild)
    if not actionButtonsCached then
        BuildActionButtonCache()
    end
    
    if forceRebuild then
        macroCacheBuilt = false
        macroNameCache = {}
        spellToKeybind = {}
        spellNameToKeybind = {}
        cachedSpellIDs = {}
    end

    for _, button in ipairs(cachedActionButtons) do
        pcall(ProcessActionButton, button)
    end
end

local function SafeCompare(a, b)
    if not a or not b then
        return a == b
    end
    
    local aIsSecret = issecretvalue(a)
    local bIsSecret = issecretvalue(b)
    
    if aIsSecret or bIsSecret then
        local compareOk, result = pcall(function()
            return a == b
        end)
        if compareOk then
            return result
        end
        return false
    end
    
    return a == b
end

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

local function GetOrCacheKeybindForSpell(spellID)
    if not spellID then return nil end

    local ok, isCached = pcall(function()
        return cachedSpellIDs[spellID]
    end)
    if ok and isCached then
        return GetKeybindForSpell(spellID)
    end

    if not actionButtonsCached then
        BuildActionButtonCache()
    end

    RebuildCache(false)
    local keybind = GetKeybindForSpell(spellID)

    if keybind then
        ok, _ = pcall(function()
            cachedSpellIDs[spellID] = true
        end)
    end

    return keybind
end

local function GetKeybindForSpellName(spellName)
    if not spellName then return nil end
    
    local ok, nameLower = pcall(function() return spellName:lower() end)
    if not ok or not nameLower then return nil end
    
    return spellNameToKeybind[nameLower]
end

local function GetKeybindForSpellID(spellID)
    if not spellID then return nil end
    
    local keybind = GetOrCacheKeybindForSpell(spellID)
    if keybind then
        return keybind
    end
    
    local ok, overrideID = pcall(function()
        return C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(spellID)
    end)
    
    if ok and overrideID and not SafeCompare(overrideID, spellID) then
        return GetOrCacheKeybindForSpell(overrideID)
    end
    
    return nil
end

local function GetKeybindForItemID(itemID)
    if not itemID then return nil end
    
    local ok, result = pcall(function()
        return spellToKeybind[itemID]
    end)
    
    if ok then
        return result
    end
    
    if not actionButtonsCached then
        BuildActionButtonCache()
    end
    
    RebuildCache(false)
    
    return spellToKeybind[itemID]
end

function Keybinds.GetSpellKeybind(spellID)
    if not spellID then return nil end
    
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if not spellInfo then return nil end
    
    local keybind = GetKeybindForSpellID(spellID)
    if keybind then
        return keybind
    end
    
    local spellName = spellInfo.name
    if spellName then
        return GetKeybindForSpellName(spellName)
    end
    
    return nil
end

function Keybinds.GetItemKeybind(itemID)
    if not itemID then return nil end
    
    return GetKeybindForItemID(itemID)
end

function Keybinds.GetTrinketKeybind(slotID)
    if not slotID then return nil end
    
    local trinketItemID = GetInventoryItemID("player", slotID)
    if not trinketItemID then return nil end
    
    return Keybinds.GetItemKeybind(trinketItemID)
end

function Keybinds.UpdateEntry(entry)
    if not entry or not entry.frame then return end
    
    local settings = module:GetViewerSettings(entry.source)
    if not settings or not settings.showKeybinds then return end
    
    local frame = entry.frame
    local spellID = entry.spellID
    local itemID = entry.itemID
    local slotID = entry.slotID
    
    if not spellID and not itemID and not slotID then
        if frame.GetSpellID then
            spellID = frame:GetSpellID()
        elseif frame.spellID then
            spellID = frame.spellID
        elseif frame._spellID then
            spellID = frame._spellID
        end
        
        if frame.GetItemID then
            itemID = frame:GetItemID()
        elseif frame.itemID then
            itemID = frame.itemID
        elseif frame._itemID then
            itemID = frame._itemID
        end
        
        if frame.GetSlotID then
            slotID = frame:GetSlotID()
        elseif frame.slotID then
            slotID = frame.slotID
        elseif frame._slotID then
            slotID = frame._slotID
        end
        
        if frame.cooldownData then
            if frame.cooldownData.spellID then
                spellID = frame.cooldownData.spellID
            end
            if frame.cooldownData.itemID then
                itemID = frame.cooldownData.itemID
            end
            if frame.cooldownData.slotID then
                slotID = frame.cooldownData.slotID
            end
        end
        
        if spellID or itemID or slotID then
            entry.spellID = spellID
            entry.itemID = itemID
            entry.slotID = slotID
        end
    end
    
    local keybind = nil
    
    if spellID then
        keybind = Keybinds.GetSpellKeybind(spellID)
    elseif itemID then
        keybind = Keybinds.GetItemKeybind(itemID)
    elseif slotID then
        keybind = Keybinds.GetTrinketKeybind(slotID)
    end
    
    if not entry.frame._ucdmKeybindText then
        entry.frame._ucdmKeybindText = entry.frame:CreateFontString(nil, "OVERLAY")
        entry.frame._ucdmKeybindText:SetFont("Fonts\\FRIZQT__.TTF", settings.keybindSize or 10, "OUTLINE")
    end
    
    local keybindText = entry.frame._ucdmKeybindText
    local keybindColor = settings.keybindColor or {r = 1, g = 1, b = 1, a = 1}
    
    if keybind then
        keybindText:SetText(keybind)
        keybindText:SetTextColor(keybindColor.r, keybindColor.g, keybindColor.b, keybindColor.a)
        keybindText:SetPoint(settings.keybindPoint or "TOPLEFT", entry.frame, settings.keybindPoint or "TOPLEFT", settings.keybindOffsetX or 2, settings.keybindOffsetY or -2)
        keybindText:Show()
    else
        keybindText:Hide()
    end
end

function Keybinds.UpdateViewer(viewerKey, entries)
    if not entries then return end
    
    local settings = module:GetViewerSettings(viewerKey)
    if not settings or not settings.showKeybinds then return end
    
    for _, entry in ipairs(entries) do
        Keybinds.UpdateEntry(entry)
    end
end

local updatePending = false
local UPDATE_THROTTLE = 0.2

local function ThrottledRebuild(forceRebuild)
    if updatePending then return end
    updatePending = true
    
    C_Timer.After(UPDATE_THROTTLE, function()
        updatePending = false
        RebuildCache(forceRebuild)
        if module.RefreshManager then
            for _, viewerKey in ipairs({"essential", "utility", "buff", "custom"}) do
                module.RefreshManager.RefreshKeybinds(viewerKey)
            end
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
            C_Timer.After(0.1, function()
                RebuildCache(true)
                if module.RefreshManager then
                    for _, viewerKey in ipairs({"essential", "utility", "buff", "custom"}) do
                        module.RefreshManager.RefreshKeybinds(viewerKey)
                    end
                end
            end)
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
    
    C_Timer.After(0.5, function()
        RebuildCache(true)
    end)
end

module.Keybinds = Keybinds
