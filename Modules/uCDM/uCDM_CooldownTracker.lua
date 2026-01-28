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
        isOnCooldown = duration:EvaluateRemainingPercent(Helpers.CooldownCurves.Binary),
        duration = duration,
        buffRemaining = buffRemaining,
        chargeDuration = chargeDuration,
        isUsable = isUsable,
        noMana = noMana
    }
end

function CooldownTracker.UpdateEntry(entry)
    if not entry or not entry.frame then return nil end
    if entry.type ~= "custom" then return nil end
    
    local data = nil
    
    if entry.spellID then
        data = CooldownTracker.UpdateSpell(entry.spellID)
        if data and entry.type == "custom" then
            data.isUsable = C_Spell.IsSpellUsable(entry.spellID) or false
        end
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

    if data.isOnCooldown then
        frame.Icon:SetDesaturation(data.isOnCooldown)
    elseif frame.Icon and data.isUsable ~= nil then
        if data.isUsable then
            frame.Icon:SetVertexColor(1.0, 1.0, 1.0)
        elseif data.noMana then
            frame.Icon:SetVertexColor(0.5, 0.5, 1.0)
        else
            frame.Icon:SetVertexColor(0.4, 0.4, 0.4)
        end
    end    
    
    if frame.Count then
        if data.stackDisplay then
            frame.Count:SetText(data.stackDisplay)
            frame.Count:Show()
        else
            frame.Count:Hide()
        end
    end
    
    return data
end

function CooldownTracker.Initialize()
    Helpers.SetupCooldownCurves()
    module:LogInfo("CooldownTracker initialized")
end

module.CooldownTracker = CooldownTracker
