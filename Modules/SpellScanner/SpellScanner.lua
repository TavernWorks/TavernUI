-- Buff Scanner: learns buff durations out of combat and applies them in combat
-- so uCDM can show timers without reading protected aura APIs.

local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("SpellScanner", "AceEvent-3.0")

TavernUI:RegisterModuleDefaults("SpellScanner", {}, true)

module.activeBuffs = {}
module.pendingScanning = {}
module.scanMode = false
module.autoScan = false

module._addSpellId = ""
module._addSpellDuration = ""
module._addItemId = ""
module._addItemDuration = ""

local function DebugPrint(...)
    if TavernUI.db and TavernUI.db.profile and TavernUI.db.profile.general and TavernUI.db.profile.general.debug then
        print("|cff8888ff[BuffScanner]|r", ...)
    end
end

local function GetDB()
    if TavernUI.db and TavernUI.db.global then
        if not TavernUI.db.global.spellScanner then
            TavernUI.db.global.spellScanner = {
                spells = {},
                items = {},
                autoScan = false,
            }
        end
        if TavernUI.db.global.spellScanner.autoScan ~= nil then
            module.autoScan = TavernUI.db.global.spellScanner.autoScan
        end
        return TavernUI.db.global.spellScanner
    end
    return nil
end

local function GetScannedSpell(spellID)
    local db = GetDB()
    if db and db.spells and db.spells[spellID] then
        return db.spells[spellID]
    end
    return nil
end

local function GetScannedItem(itemID)
    local db = GetDB()
    if db and db.items and db.items[itemID] then
        return db.items[itemID]
    end
    return nil
end

local function GetCastSpellIDForBuff(buffSpellID)
    local db = GetDB()
    if not db or not db.spells then
        return nil
    end
    for castSpellID, data in pairs(db.spells) do
        if data.buffSpellID == buffSpellID then
            return castSpellID
        end
    end
    return nil
end

local function GetScannedDataByUseSpellID(useSpellID)
    local db = GetDB()
    if not db then
        return nil
    end
    if db.spells and db.spells[useSpellID] then
        return db.spells[useSpellID]
    end
    if db.items then
        for _, data in pairs(db.items) do
            if data and data.useSpellID == useSpellID then
                return data
            end
        end
    end
    return nil
end

local function SaveScannedSpell(castSpellID, data)
    local db = GetDB()
    if not db then
        return false
    end
    db.spells[castSpellID] = {
        buffSpellID = data.buffSpellID,
        duration = data.duration,
        icon = data.icon,
        name = data.name,
        scannedAt = time(),
    }
    return true
end

local function SaveScannedItem(itemID, data)
    local db = GetDB()
    if not db then
        return false
    end
    db.items[itemID] = {
        useSpellID = data.useSpellID,
        buffSpellID = data.buffSpellID,
        duration = data.duration,
        icon = data.icon,
        name = data.name,
        scannedAt = time(),
    }
    return true
end

local function ScanSpellFromBuffs(castSpellID, itemID)
    if InCombatLockdown() then
        module.pendingScanning[castSpellID] = { timestamp = GetTime(), itemID = itemID }
        return false
    end

    if GetScannedSpell(castSpellID) then
        return true
    end

    local now = GetTime()
    local bestMatch = nil

    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or not aura then
            break
        end

        local spellId = aura.spellId
        local duration = aura.duration
        local expirationTime = aura.expirationTime
        local icon = aura.icon
        local name = aura.name

        local buffAge = 999
        pcall(function()
            if expirationTime and duration and duration > 0 then
                buffAge = duration - (expirationTime - now)
            end
        end)

        local isRecentBuff = false
        pcall(function()
            isRecentBuff = buffAge < 2 and duration and duration >= 3
        end)

        if isRecentBuff then
            if not bestMatch or buffAge < bestMatch.age then
                bestMatch = {
                    spellId = spellId,
                    duration = duration,
                    icon = icon,
                    name = name,
                    age = buffAge,
                    expirationTime = expirationTime,
                }
            end
        end
    end

    if bestMatch then
        local success = SaveScannedSpell(castSpellID, {
            buffSpellID = bestMatch.spellId,
            duration = bestMatch.duration,
            icon = bestMatch.icon,
            name = bestMatch.name,
        })

        if success then
            if itemID then
                SaveScannedItem(itemID, {
                    useSpellID = castSpellID,
                    buffSpellID = bestMatch.spellId,
                    duration = bestMatch.duration,
                    icon = bestMatch.icon,
                    name = bestMatch.name,
                })
            end

            module.activeBuffs[castSpellID] = {
                startTime = bestMatch.expirationTime - bestMatch.duration,
                duration = bestMatch.duration,
                expirationTime = bestMatch.expirationTime,
                source = itemID and "item" or "spell",
                sourceId = itemID or castSpellID,
            }

            if module.scanMode then
                print(string.format("|cff00ff00TavernUI:|r Buff Scanner learned: %s = %.1fs", bestMatch.name or "?", bestMatch.duration))
            end

            return true
        end
    end

    return false
end

local function ProcessPendingScanning()
    if InCombatLockdown() then
        return
    end
    if not next(module.pendingScanning) then
        return
    end
    for spellID, data in pairs(module.pendingScanning) do
        ScanSpellFromBuffs(spellID, data.itemID)
        module.pendingScanning[spellID] = nil
    end
end

local function OnSpellCastSucceeded(unit, castGUID, spellID)
    if unit ~= "player" or not spellID or spellID <= 0 then
        return
    end

    local data = GetScannedSpell(spellID) or GetScannedDataByUseSpellID(spellID)

    if data then
        local now = GetTime()
        local dur = data.duration or 0
        module.activeBuffs[spellID] = {
            startTime = now,
            duration = dur,
            expirationTime = now + dur,
            source = "spell",
            sourceId = spellID,
        }
        DebugPrint("CAST in combat: spellID=" .. tostring(spellID) .. " stored duration=" .. tostring(dur) .. " exp=" .. tostring(now + dur) .. " (buffSpellID=" .. tostring(data.buffSpellID) .. ")")
        return
    end

    DebugPrint("CAST: spellID=" .. tostring(spellID) .. " not in db (no stored duration)")
    if module.scanMode or module.autoScan then
        if InCombatLockdown() then
            module.pendingScanning[spellID] = { timestamp = GetTime(), itemID = nil }
        else
            C_Timer.After(0.3, function()
                ScanSpellFromBuffs(spellID, nil)
            end)
        end
    end
end

local function CleanupExpiredBuffs()
    local now = GetTime()
    for spellID, data in pairs(module.activeBuffs) do
        if data.expirationTime and data.expirationTime < now then
            module.activeBuffs[spellID] = nil
        end
    end
end

function module:IsSpellActive(spellID)
    if not spellID then
        return false
    end

    local now = GetTime()
    local buff = self.activeBuffs[spellID]
    if buff and buff.expirationTime > now then
        DebugPrint("IsSpellActive(" .. spellID .. ") HIT direct: exp=" .. tostring(buff.expirationTime) .. " dur=" .. tostring(buff.duration))
        return true, buff.expirationTime, buff.duration
    end

    local castSpellID = GetCastSpellIDForBuff(spellID)
    if castSpellID and castSpellID ~= spellID then
        buff = self.activeBuffs[castSpellID]
        if buff and buff.expirationTime > now then
            DebugPrint("IsSpellActive(" .. spellID .. ") HIT via castSpellID=" .. castSpellID .. " exp=" .. tostring(buff.expirationTime) .. " dur=" .. tostring(buff.duration))
            return true, buff.expirationTime, buff.duration
        end
    end

    local data = GetScannedSpell(spellID) or (castSpellID and GetScannedSpell(castSpellID))
    if data and data.buffSpellID and not InCombatLockdown() then
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, data.buffSpellID)
        if ok and aura and aura.expirationTime then
            DebugPrint("IsSpellActive(" .. spellID .. ") HIT aura API: exp=" .. tostring(aura.expirationTime) .. " dur=" .. tostring(aura.duration))
            return true, aura.expirationTime, aura.duration
        end
    end

    local hadBuff = self.activeBuffs[spellID] or (castSpellID and self.activeBuffs[castSpellID])
    if hadBuff then
        local b = self.activeBuffs[spellID] or self.activeBuffs[castSpellID]
        DebugPrint("IsSpellActive(" .. spellID .. ") MISS expired: buff.exp=" .. tostring(b and b.expirationTime) .. " now=" .. now)
    end
    return false
end

function module:IsItemActive(itemID)
    if not itemID then
        return false
    end
    local data = GetScannedItem(itemID)
    if data and data.useSpellID then
        return self:IsSpellActive(data.useSpellID)
    end
    return false
end

function module:IsSpellScanned(spellID)
    return GetScannedSpell(spellID) ~= nil
end

function module:GetScannedDuration(spellID)
    local data = GetScannedSpell(spellID)
    return data and data.duration or nil
end

function module:GetSpellActiveCooldown(spellID)
    if not spellID then
        return nil, nil
    end

    local now = GetTime()
    local buff = self.activeBuffs[spellID]
    if buff and buff.expirationTime and buff.expirationTime > now and buff.startTime and buff.duration then
        return buff.startTime, buff.duration
    end

    local castSpellID = GetCastSpellIDForBuff(spellID)
    if castSpellID and castSpellID ~= spellID then
        buff = self.activeBuffs[castSpellID]
        if buff and buff.expirationTime and buff.expirationTime > now and buff.startTime and buff.duration then
            return buff.startTime, buff.duration
        end
    end

    return nil, nil
end

function module:GetItemActiveCooldown(itemID)
    if not itemID then return nil, nil end
    local data = GetScannedItem(itemID)
    if data and data.useSpellID then
        return self:GetSpellActiveCooldown(data.useSpellID)
    end
    return nil, nil
end

function module:ToggleScanMode()
    self.scanMode = not self.scanMode
    return self.scanMode
end

function module:SetAutoScan(enabled)
    self.autoScan = enabled
    local db = GetDB()
    if db then
        db.autoScan = enabled
    end
end

function module:AddSpellManually(spellID, duration)
    spellID = tonumber(spellID)
    duration = tonumber(duration)
    if not spellID or spellID <= 0 or not duration or duration <= 0 then
        return false, "Need valid spell ID and duration (seconds)."
    end
    local info = C_Spell.GetSpellInfo(spellID)
    local name = info and info.name or ("Spell " .. spellID)
    local icon = info and info.icon or nil
    local success = SaveScannedSpell(spellID, {
        buffSpellID = spellID,
        duration = duration,
        icon = icon,
        name = name,
    })
    return success, success and ("Added: " .. name .. " = " .. duration .. "s") or "Failed to add."
end

function module:AddItemManually(itemID, duration)
    itemID = tonumber(itemID)
    duration = tonumber(duration)
    if not itemID or itemID <= 0 or not duration or duration <= 0 then
        return false, "Need valid item ID and duration (seconds)."
    end
    local _, useSpellID = C_Item.GetItemSpell(itemID)
    if not useSpellID then
        return false, "Item has no use spell."
    end
    local itemName = C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID) or ("Item " .. itemID)
    local spellInfo = C_Spell.GetSpellInfo(useSpellID)
    local name = spellInfo and spellInfo.name or itemName
    local icon = spellInfo and spellInfo.icon or nil
    if not SaveScannedSpell(useSpellID, {
        buffSpellID = useSpellID,
        duration = duration,
        icon = icon,
        name = name,
    }) then
        return false, "Failed to add spell."
    end
    SaveScannedItem(itemID, {
        useSpellID = useSpellID,
        buffSpellID = useSpellID,
        duration = duration,
        icon = icon,
        name = name,
    })
    return true, "Added: " .. itemName .. " = " .. duration .. "s"
end

function module:RemoveSpell(spellID)
    spellID = tonumber(spellID)
    if not spellID then
        return false
    end
    local db = GetDB()
    if not db or not db.spells or not db.spells[spellID] then
        return false
    end
    db.spells[spellID] = nil
    return true
end

function module:RemoveItem(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end
    local db = GetDB()
    if not db or not db.items or not db.items[itemID] then
        return false
    end
    db.items[itemID] = nil
    return true
end

function module:OnInitialize()
    GetDB()
    self:RegisterOptions()
end

function module:OnEnable()
    TavernUI.SpellScanner = self
    self.autoScan = (GetDB() and TavernUI.db.global.spellScanner.autoScan) or false

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
        if event == "PLAYER_LOGIN" then
            GetDB()
        elseif event == "PLAYER_REGEN_ENABLED" then
            C_Timer.After(0.3, ProcessPendingScanning)
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            OnSpellCastSucceeded(arg1, arg2, arg3)
        end
    end)
    self._eventFrame = frame

    self._cleanupTicker = C_Timer.NewTicker(1, CleanupExpiredBuffs)
end

function module:OnDisable()
    if self._cleanupTicker then
        self._cleanupTicker:Cancel()
        self._cleanupTicker = nil
    end
    if self._eventFrame then
        self._eventFrame:UnregisterAllEvents()
        self._eventFrame:SetScript("OnEvent", nil)
        self._eventFrame = nil
    end
    TavernUI.SpellScanner = nil
end

function module:RefreshOptions()
    if TavernUI.RegisterModuleOptions then
        TavernUI:RegisterModuleOptions("SpellScanner", self:BuildOptions(), "Buff Scanner")
    end
    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
    if AceConfigRegistry then
        AceConfigRegistry:NotifyChange("TavernUI")
    end
end

function module:BuildOptions()
    local db = GetDB()
    local args = {
        desc = {
            type = "description",
            name = "Learns buff durations when you use spells/items out of combat, so cooldown timers work in combat without reading protected APIs. Add spells to the Buff viewer in uCDM to see them.",
            order = 1,
        },
        scanMode = {
            type = "toggle",
            name = "Scan mode",
            desc = "When ON, the next spell or item you use out of combat will be learned (duration from your buff). Turn OFF after learning.",
            order = 10,
            get = function()
                return module.scanMode
            end,
            set = function(_, value)
                module.scanMode = value
                if value then
                    print("|cff00ff00TavernUI:|r Buff Scanner: Scan mode ON – use a spell/item out of combat to learn it.")
                else
                    print("|cff00ff00TavernUI:|r Buff Scanner: Scan mode OFF")
                end
            end,
        },
        autoScan = {
            type = "toggle",
            name = "Auto-scan",
            desc = "When ON, unknown spells you cast out of combat are learned automatically.",
            order = 11,
            get = function()
                local d = GetDB()
                return d and d.autoScan
            end,
            set = function(_, value)
                module:SetAutoScan(value)
            end,
        },
        headerDiscovered = {
            type = "header",
            name = "Discovered (click row to remove)",
            order = 20,
        },
    }

    local order = 21
    if db and db.spells then
        local spellIds = {}
        for id in pairs(db.spells) do
            spellIds[#spellIds + 1] = id
        end
        table.sort(spellIds)
        for _, spellID in ipairs(spellIds) do
            local data = db.spells[spellID]
            local name = data and data.name or ("Spell " .. spellID)
            local dur = data and data.duration or 0
            args["spell_" .. spellID] = {
                type = "execute",
                name = string.format("[%d] %s [%.1fs]", spellID, name, dur),
                desc = "Click to remove this spell",
                order = order,
                func = function()
                    if module:RemoveSpell(spellID) then
                        print("|cff00ff00TavernUI:|r Removed spell " .. spellID)
                        module:RefreshOptions()
                    end
                end,
            }
            order = order + 1
        end
    end
    if db and db.items then
        local itemIds = {}
        for id in pairs(db.items) do
            itemIds[#itemIds + 1] = id
        end
        table.sort(itemIds)
        for _, itemID in ipairs(itemIds) do
            local data = db.items[itemID]
            local name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)) or ("Item " .. itemID)
            local dur = data and data.duration or 0
            args["item_" .. itemID] = {
                type = "execute",
                name = string.format("[%d] %s [%.1fs]", itemID, name, dur),
                desc = "Click to remove this item",
                order = order,
                func = function()
                    if module:RemoveItem(itemID) then
                        print("|cff00ff00TavernUI:|r Removed item " .. itemID)
                        module:RefreshOptions()
                    end
                end,
            }
            order = order + 1
        end
    end
    if order == 21 then
        args.discoveredNone = {
            type = "description",
            name = "  (none yet – use Scan mode or Add manually below)",
            order = 21,
        }
        order = 22
    end

    args.headerAdd = {
        type = "header",
        name = "Add manually",
        order = 100,
    }
    args.addSpellId = {
        type = "input",
        name = "Spell ID",
        desc = "Spell ID (e.g. from Wowhead).",
        order = 101,
        get = function()
            return module._addSpellId
        end,
        set = function(_, value)
            module._addSpellId = value or ""
        end,
    }
    args.addSpellDuration = {
        type = "input",
        name = "Duration (seconds)",
        desc = "Buff duration in seconds.",
        order = 102,
        get = function()
            return module._addSpellDuration
        end,
        set = function(_, value)
            module._addSpellDuration = value or ""
        end,
    }
    args.addSpell = {
        type = "execute",
        name = "Add spell",
        order = 103,
        func = function()
            local ok, msg = module:AddSpellManually(module._addSpellId, module._addSpellDuration)
            if ok then
                module._addSpellId = ""
                module._addSpellDuration = ""
                print("|cff00ff00TavernUI:|r " .. msg)
                module:RefreshOptions()
            else
                print("|cffff0000TavernUI:|r " .. (msg or "Failed"))
            end
        end,
    }
    args.addItemId = {
        type = "input",
        name = "Item ID",
        desc = "Item ID (e.g. combat potion from Wowhead).",
        order = 104,
        get = function()
            return module._addItemId
        end,
        set = function(_, value)
            module._addItemId = value or ""
        end,
    }
    args.addItemDuration = {
        type = "input",
        name = "Duration (seconds)",
        desc = "Buff duration in seconds.",
        order = 105,
        get = function()
            return module._addItemDuration
        end,
        set = function(_, value)
            module._addItemDuration = value or ""
        end,
    }
    args.addItem = {
        type = "execute",
        name = "Add item",
        order = 106,
        func = function()
            local ok, msg = module:AddItemManually(module._addItemId, module._addItemDuration)
            if ok then
                module._addItemId = ""
                module._addItemDuration = ""
                print("|cff00ff00TavernUI:|r " .. msg)
                module:RefreshOptions()
            else
                print("|cffff0000TavernUI:|r " .. (msg or "Failed"))
            end
        end,
    }

    return {
        type = "group",
        name = "Buff Scanner",
        args = args,
    }
end

function module:RegisterOptions()
    if TavernUI.RegisterModuleOptions then
        TavernUI:RegisterModuleOptions("SpellScanner", self:BuildOptions(), "Buff Scanner")
    end
end
