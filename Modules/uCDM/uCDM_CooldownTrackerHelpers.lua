local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local function CreateCooldownDuration(startTime, duration)
    if not startTime or not duration or duration <= 0 then
        return nil
    end
    local durationObj = C_DurationUtil.CreateDuration()
    durationObj:SetTimeFromStart(startTime, duration, 1)
    return durationObj
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

local function GetSpellStackAndChargeInfo(spellID, chargesCache)
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
    
    local chargeInfo = C_Spell.GetSpellCharges(spellID)
    if chargeInfo then
        charges = chargeInfo.currentCharges
        hasCharges = true
        chargesCache[spellID] = true
        chargeDuration = C_Spell.GetSpellChargeDuration(spellID)
    else
        hasCharges = chargesCache[spellID] or false
    end

    return stacks, charges, hasCharges, chargeDuration, buffRemaining
end

local function GetWeaponEnchantBuff(spellID)
    if not spellID then
        return nil, nil
    end

    local function CreateEnchantDuration(expTime)
        if not expTime or expTime <= 0 then return nil end
        local durationObj = C_DurationUtil.CreateDuration()
        durationObj:SetTimeFromStart(GetTime(), expTime, 1)
        return durationObj
    end

    local mhHas, mhExp, _, mhEnchantID, ohHas, ohExp, _, ohEnchantID = GetWeaponEnchantInfo()

    if mhHas and mhEnchantID == spellID then
        return mhEnchantID, CreateEnchantDuration(mhExp)
    elseif ohHas and ohEnchantID == spellID then
        return ohEnchantID, CreateEnchantDuration(ohExp)
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

    local stacks, charges, _, _, buffDur = GetSpellStackAndChargeInfo(spellID, chargesCache)
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
    -- Item context
    if itemCount then
        -- Prefer spell charges over item charges when they match or item charges is nil
        local displayCharges = (itemCharges == itemCount or not itemCharges) and spellCharges or itemCharges
        if displayCharges then return displayCharges end
        if buffStacks and buffStacks > 0 then return buffStacks end
        if itemCount > 1 then return itemCount end
        return nil
    end

    -- Spell context
    if hasCharges and charges then return charges end
    if buffStacks and buffStacks > 0 then return buffStacks end
    return nil
end

local function GetSpellUsability(spellID)
    if not spellID then return true, false end

    local usable, noMana = C_Spell.IsSpellUsable(spellID)
    if usable == nil then return true, false end
    if not usable then
        return false, noMana or false
    end

    if UnitExists("target") then
        local inRange = C_Spell.IsSpellInRange(spellID, "target")
        if inRange == false then
            return false, false
        end
    end

    return true, noMana
end

local Helpers = {
    CreateCooldownDuration = CreateCooldownDuration,
    GetStacksAndRemainingBuffTime = GetStacksAndRemainingBuffTime,
    GetSpellStackAndChargeInfo = GetSpellStackAndChargeInfo,
    GetWeaponEnchantBuff = GetWeaponEnchantBuff,
    GetItemBuffInfo = GetItemBuffInfo,
    GetItemCharges = GetItemCharges,
    GetStackDisplay = GetStackDisplay,
    GetSpellUsability = GetSpellUsability,
}

module.CooldownTrackerHelpers = Helpers
