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
        isOnCooldown = durationObj:EvaluateRemainingPercent(CooldownCurves.Binary)
    end

    return durationObj, isOnCooldown
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

    local usable, noMana = C_Spell.IsSpellUsable(spellID)
    if not usable then
        return false, noMana
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

local Helpers = {
    SetupCooldownCurves = SetupCooldownCurves,
    GetHasCharges = GetHasCharges,
    CreateCooldownDuration = CreateCooldownDuration,
    GetStacksAndRemainingBuffTime = GetStacksAndRemainingBuffTime,
    GetSpellInfo = GetSpellInfo,
    GetWeaponEnchantBuff = GetWeaponEnchantBuff,
    GetItemBuffInfo = GetItemBuffInfo,
    GetItemCharges = GetItemCharges,
    GetStackDisplay = GetStackDisplay,
    GetSpellUsability = GetSpellUsability,
    CooldownCurves = CooldownCurves,
}

module.CooldownTrackerHelpers = Helpers
