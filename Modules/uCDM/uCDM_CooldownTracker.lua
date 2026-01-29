local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local Helpers = module.CooldownTrackerHelpers

local CooldownTracker = {}

CooldownTracker._hasChargesCache = {}

function CooldownTracker.UpdateTrinket(slotID)
    local itemID = GetInventoryItemID("player", slotID)
    return CooldownTracker.UpdateItem(itemID)
end

function CooldownTracker.UpdateItem(itemID)
    local startTime, duration = C_Container.GetItemCooldown(itemID)
    local _, spellID = GetItemSpell(itemID)
    local itemCount = C_Item.GetItemCount(itemID, false, false) or 0
    local itemCharges = Helpers.GetItemCharges(itemID)

    local buffStacks, buffRemaining, spellCharges = Helpers.GetItemBuffInfo(spellID, CooldownTracker._hasChargesCache)
    local stackDisplay = Helpers.GetStackDisplay(itemCount, itemCharges, spellCharges, buffStacks)
    local durationObj, isOnCooldown = Helpers.CreateCooldownDuration(startTime, duration)

    return {
        stackDisplay = stackDisplay,
        isOnCooldown = isOnCooldown,
        duration = durationObj,
        buffRemaining = buffRemaining,
    }
end

function CooldownTracker.UpdateSpell(spellID)
    if (not Helpers.SetupCooldownCurves()) then return end
    local duration = C_Spell.GetSpellCooldownDuration(spellID)
    local stacks, charges, hasCharges, chargeDuration, buffRemaining = Helpers.GetSpellInfo(spellID, CooldownTracker._hasChargesCache)
    local stackDisplay = Helpers.GetStackDisplay(nil, nil, nil, stacks, hasCharges, charges)
    local isUsable, noMana = Helpers.GetSpellUsability(spellID)
    
    return {
        stackDisplay = stackDisplay,
        isOnCooldown = Helpers.EvaluateRemainingPercentSafe(duration),
        duration = duration,
        buffRemaining = buffRemaining,
        chargeDuration = chargeDuration,
        isUsable = isUsable,
        noMana = noMana
    }
end

function CooldownTracker.UpdateEntry(entry)
    if not entry or not entry.frame then return nil end

    local data = nil

    if entry.spellID then
        data = CooldownTracker.UpdateSpell(entry.spellID)
    elseif entry.itemID then
        data = CooldownTracker.UpdateItem(entry.itemID)
    elseif entry.slotID then
        data = CooldownTracker.UpdateTrinket(entry.slotID)
    else
        return nil
    end
    
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
    Helpers.SetupCooldownCurves()
    module:LogInfo("CooldownTracker initialized")
end

module.CooldownTracker = CooldownTracker
