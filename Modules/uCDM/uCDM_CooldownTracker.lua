local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local CooldownCurves = {
    initialized = false,
    Binary = nil,
}

local function SetupCooldownCurves()
    if CooldownCurves.initialized then return true end
    if not C_CurveUtil or not C_CurveUtil.CreateCurve then
        return false
    end

    CooldownCurves.Binary = C_CurveUtil.CreateCurve()
    CooldownCurves.Binary:AddPoint(0.0, 0)
    CooldownCurves.Binary:AddPoint(0.001, 1)
    CooldownCurves.Binary:AddPoint(1.0, 1)

    CooldownCurves.initialized = true
    return true
end

local function GetHasCharges(spellID, chargesCache)
    if not spellID or type(spellID) ~= "number" then return false end

    local ok, cacheKey = pcall(function() return "spell_" .. spellID end)
    if not ok or not cacheKey then return false end

    local chargeInfo = C_Spell.GetSpellCharges(spellID)
    if chargeInfo then
        local setOk = pcall(function() chargesCache[cacheKey] = true end)
        if setOk then
            return true
        end
    end

    local getOk, cached = pcall(function() return chargesCache[cacheKey] end)
    return (getOk and cached) or false
end

local function CreateCooldownDuration(startTime, duration)
    if not startTime or not duration then
        return nil, 0
    end

    local durationObj = C_DurationUtil.CreateDuration()

    local ok = pcall(durationObj.SetTimeFromStart, durationObj, startTime, duration, 1)
    if not ok then
        return nil, 0
    end

    local isOnCooldown = 0
    if SetupCooldownCurves() then
        local ok, val = pcall(durationObj.EvaluateRemainingPercent, durationObj, CooldownCurves.Binary)
        if ok and type(val) == "number" then
            local okCmp = pcall(function() return val > 0 end)
            if okCmp then
                isOnCooldown = val
            end
        end
    end

    return durationObj, isOnCooldown
end

local function EvaluateRemainingPercentSafe(durationObj)
    if not durationObj or not SetupCooldownCurves() then return 0 end
    local ok, val = pcall(durationObj.EvaluateRemainingPercent, durationObj, CooldownCurves.Binary)
    if not ok or type(val) ~= "number" then return 0 end
    local okCmp = pcall(function() return val > 0 end)
    if not okCmp then return 0 end
    return val
end

local function GetStacksAndRemainingBuffTime(auraData)
    if auraData then
        local stacks = auraData.applications or 0
        local buffRemaining = nil
        if auraData.auraInstanceID then
            local auraDurationInfo = C_UnitAuras.GetAuraDuration("player", auraData.auraInstanceID)
            buffRemaining = auraDurationInfo
        end
        return stacks, buffRemaining
    end
    return 0, nil
end

local function GetSpellInfo(spellID, chargesCache)
    if not spellID then
        return 0, nil, false, 0
    end

    local stacks = 0
    local charges = nil
    local hasCharges = false
    local chargeDuration = nil
    local buffRemaining = nil

    local scanner = TavernUI.SpellScanner
    if scanner and scanner.IsSpellActive then
        local ok, active, exp, dur = pcall(scanner.IsSpellActive, spellID)
        if ok and active and exp and dur and dur > 0 then
            local startTime = exp - dur
            local durationObj = CreateCooldownDuration(startTime, dur)
            if durationObj then
                if TavernUI.db and TavernUI.db.profile and TavernUI.db.profile.general and TavernUI.db.profile.general.debug then
                    print("|cff88ff88[uCDM Helpers]|r GetSpellInfo(" .. tostring(spellID) .. ") using scanner: startTime=" .. tostring(startTime) .. " dur=" .. tostring(dur) .. " exp=" .. tostring(exp))
                end
                hasCharges = GetHasCharges(spellID, chargesCache)
                local chargeInfo = C_Spell.GetSpellCharges(spellID)
                if chargeInfo then
                    charges = chargeInfo.currentCharges
                    hasCharges = true
                    chargeDuration = C_Spell.GetSpellChargeDuration(spellID)
                end
                return stacks, charges, hasCharges, chargeDuration, durationObj
            end
        end
    end

    local auraData = C_UnitAuras.GetUnitAuraBySpellID("player", spellID)
    if auraData then
        stacks, buffRemaining = GetStacksAndRemainingBuffTime(auraData)
    end

    hasCharges = GetHasCharges(spellID, chargesCache)
    local chargeInfo = C_Spell.GetSpellCharges(spellID)
    if chargeInfo then
        charges = chargeInfo.currentCharges
        hasCharges = true
        chargeDuration = C_Spell.GetSpellChargeDuration(spellID)
    end

    return stacks, charges, hasCharges, chargeDuration, buffRemaining
end

local function GetWeaponEnchantBuff(spellID)
    if not spellID then
        return nil, nil
    end

    local mhHas, mhExp, _, mhEnchantID, ohHas, ohExp, _, ohEnchantID = GetWeaponEnchantInfo()

    if mhHas and mhEnchantID == spellID then
        if mhExp and mhExp > 0 then
            local buffDurationObj = C_DurationUtil.CreateDuration()
            local currentTime = GetTime()
            buffDurationObj:SetTimeFromStart(currentTime, mhExp, 1)
            return mhEnchantID, buffDurationObj
        end
        return mhEnchantID, nil
    elseif ohHas and ohEnchantID == spellID then
        if ohExp and ohExp > 0 then
            local buffDurationObj = C_DurationUtil.CreateDuration()
            local currentTime = GetTime()
            buffDurationObj:SetTimeFromStart(currentTime, ohExp, 1)
            return ohEnchantID, buffDurationObj
        end
        return ohEnchantID, nil
    end

    return nil, nil
end

local function GetItemBuffInfo(spellID, chargesCache)
    if not spellID then
        return 0, nil, nil
    end

    local enchantID, weaponEnchantBuff = GetWeaponEnchantBuff(spellID)
    if enchantID then
        return 0, weaponEnchantBuff, nil
    end

    local stacks, charges, _, _, buffDur = GetSpellInfo(spellID, chargesCache)
    return stacks, buffDur, charges
end

local function GetItemCharges(itemID)
    if not itemID then return nil end

    local charges = GetItemCount(itemID, nil, true)
    if charges and charges > 0 then
        return charges
    end
    return nil
end

local function GetStackDisplay(itemCount, itemCharges, spellCharges, buffStacks, hasCharges, charges)
    if itemCount then
        local displayCharges = nil
        if itemCharges == itemCount or not itemCharges then
            displayCharges = spellCharges
        else
            displayCharges = itemCharges
        end

        if displayCharges ~= nil then
            return displayCharges
        end

        if buffStacks and buffStacks > 0 then
            return buffStacks
        end

        if itemCount > 1 then
            return itemCount
        end

        return nil
    else
        if hasCharges and charges ~= nil then
            return charges
        elseif buffStacks and buffStacks > 0 then
            return buffStacks
        end
        return nil
    end
end

local function GetSpellUsability(spellID)
    if not spellID then return true, false end

    local ok, usable, noMana = pcall(C_Spell.IsSpellUsable, spellID)
    if not ok or usable == nil then return true, false end
    if not usable then
        return false, noMana and true or false
    end

    local spellName = GetSpellInfo(spellID)
    if spellName then
        local target = "target"
        if UnitExists(target) then
            local inRange = C_Spell.IsSpellInRange(spellName, target)
            if inRange == 0 then
                return false, false
            end
        end
    end

    return true, noMana
end

local CooldownTracker = {}
CooldownTracker._hasChargesCache = {}

function CooldownTracker.UpdateTrinket(slotID)
    local itemID = GetInventoryItemID("player", slotID)
    if not itemID then return nil end
    return CooldownTracker.UpdateItem(itemID)
end

function CooldownTracker.UpdateItem(itemID)
    if not itemID then return nil end
    local startTime, duration = C_Container.GetItemCooldown(itemID)
    local _, spellID = GetItemSpell(itemID)
    local itemCount = C_Item.GetItemCount(itemID, false, false) or 0
    local itemCharges = GetItemCharges(itemID)

    local buffStacks, buffRemaining, spellCharges = GetItemBuffInfo(spellID, CooldownTracker._hasChargesCache)
    local stackDisplay = GetStackDisplay(itemCount, itemCharges, spellCharges, buffStacks)
    local durationObj, isOnCooldown = CreateCooldownDuration(startTime, duration)

    return {
        stackDisplay = stackDisplay,
        isOnCooldown = isOnCooldown,
        duration = durationObj,
        buffRemaining = buffRemaining,
    }
end

function CooldownTracker.UpdateSpell(spellID)
    if (not SetupCooldownCurves()) then return end
    local duration = C_Spell.GetSpellCooldownDuration(spellID)
    local stacks, charges, hasCharges, chargeDuration, buffRemaining = GetSpellInfo(spellID, CooldownTracker._hasChargesCache)
    local stackDisplay = GetStackDisplay(nil, nil, nil, stacks, hasCharges, charges)
    local isUsable, noMana = GetSpellUsability(spellID)

    return {
        stackDisplay = stackDisplay,
        isOnCooldown = EvaluateRemainingPercentSafe(duration),
        duration = duration,
        buffRemaining = buffRemaining,
        chargeDuration = chargeDuration,
        isUsable = isUsable,
        noMana = noMana
    }
end

function CooldownTracker.UpdateActionSlot(slot)
    if not slot or slot < 1 or slot > 120 then return nil end
    local actionType, id = GetActionInfo(slot)
    if actionType == "spell" and id then
        return CooldownTracker.UpdateSpell(id)
    elseif actionType == "item" and id then
        return CooldownTracker.UpdateItem(id)
    elseif actionType == "macro" and id then
        local spellName = GetMacroSpell(id)
        if spellName then
            local spellInfo = C_Spell.GetSpellInfo(spellName)
            if spellInfo and spellInfo.spellID then
                return CooldownTracker.UpdateSpell(spellInfo.spellID)
            end
        end
        local itemName = GetMacroItem(id)
        if itemName then
            local itemLink = GetItemInfo(itemName)
            if itemLink then
                local itemID = tonumber(itemLink:match("item:(%d+)"))
                if itemID then
                    return CooldownTracker.UpdateItem(itemID)
                end
            end
        end
    end
    local startTime, duration, enable = GetActionCooldown(slot)
    if not startTime or not duration or duration <= 0 then
        return { duration = nil, isOnCooldown = 0, stackDisplay = nil }
    end
    local durationObj, isOnCooldown = CreateCooldownDuration(startTime, duration)
    return {
        duration = durationObj,
        isOnCooldown = isOnCooldown,
        stackDisplay = nil,
    }
end

function CooldownTracker.UpdateOverride(entry)
    if not entry or not entry.frame then return nil end
    local startTime, duration = nil, nil
    if entry.viewerKey and entry.layoutIndex then
        startTime, duration = module:GetSlotCooldownOverride(entry.viewerKey, entry.layoutIndex)
    end
    if not startTime or not duration then return nil end
    local durationObj, isOnCooldown = CreateCooldownDuration(startTime, duration)
    local data = {
        duration = durationObj,
        isOnCooldown = isOnCooldown,
        stackDisplay = nil,
    }
    local frame = entry.frame
    local cooldown = frame.Cooldown or frame.cooldown
    if cooldown and data.duration then
        cooldown:SetCooldownFromDurationObject(data.duration, true)
        cooldown:Show()
    end
    local icon = frame.Icon or frame.icon
    if icon then
        if data.isOnCooldown and data.isOnCooldown > 0 then
            icon:SetDesaturation(data.isOnCooldown)
            icon:SetVertexColor(1.0, 1.0, 1.0)
        else
            icon:SetDesaturation(0)
            icon:SetVertexColor(1.0, 1.0, 1.0)
        end
    end
    local countText = frame.Count or frame.count
    if countText then countText:Hide() end
    return data
end

function CooldownTracker.GetEntryData(entry)
    if entry.spellID then
        return CooldownTracker.UpdateSpell(entry.spellID)
    elseif entry.itemID then
        return CooldownTracker.UpdateItem(entry.itemID)
    elseif entry.slotID then
        return CooldownTracker.UpdateTrinket(entry.slotID)
    elseif entry.actionSlotID then
        return CooldownTracker.UpdateActionSlot(entry.actionSlotID)
    end
    return nil
end

function CooldownTracker.UpdateEntry(entry)
    if not entry or not entry.frame then return nil end

    local data = CooldownTracker.UpdateOverride(entry)
    if data then return data end

    data = CooldownTracker.GetEntryData(entry)
    if not data then return nil end

    local frame = entry.frame
    local cooldown = frame.Cooldown or frame.cooldown

    if cooldown then
        if data.buffRemaining then
            cooldown:SetCooldownFromDurationObject(data.buffRemaining, true)
            cooldown:Show()
        elseif data.chargeDuration then
            cooldown:SetCooldownFromDurationObject(data.chargeDuration, false)
            cooldown:Show()
        elseif data.duration then
            cooldown:SetCooldownFromDurationObject(data.duration, true)
            cooldown:Show()
        elseif data.chargeDuration then
            cooldown:SetCooldownFromDurationObject(data.chargeDuration, true)
            cooldown:Show()
        else
            cooldown:Clear()
        end
    end

    local icon = frame.Icon or frame.icon
    if icon then
        if data.isOnCooldown and data.isOnCooldown > 0 then
            icon:SetDesaturation(data.isOnCooldown)
            icon:SetVertexColor(1.0, 1.0, 1.0)
        elseif data.isUsable ~= nil then
            icon:SetDesaturation(0)
            if data.isUsable then
                icon:SetVertexColor(1.0, 1.0, 1.0)
            elseif data.noMana then
                icon:SetVertexColor(0.5, 0.5, 1.0)
            else
                icon:SetVertexColor(0.4, 0.4, 0.4)
            end
        else
            icon:SetDesaturation(0)
            icon:SetVertexColor(1.0, 1.0, 1.0)
        end
    end

    local countText = frame.Count or frame.count
    if countText then
        if data.stackDisplay then
            countText:SetText(data.stackDisplay)
            countText:Show()
        else
            countText:Hide()
        end
    end

    return data
end

function CooldownTracker.Initialize()
    SetupCooldownCurves()
end

CooldownTracker.CreateCooldownDuration = CreateCooldownDuration
module.CooldownTracker = CooldownTracker
