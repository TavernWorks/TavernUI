local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local Helpers = module.CooldownTrackerHelpers

local CooldownTracker = {}

-- Normalize frame element access (Blizzard uses inconsistent casing)
local function GetIcon(frame)
    return frame and (frame.Icon or frame.icon)
end

local function GetCooldown(frame)
    return frame and (frame.Cooldown or frame.cooldown)
end

local function GetCount(frame)
    return frame and (frame.Count or frame.count)
end

CooldownTracker._hasChargesCache = {}

local function ApplySwipeStyle(cooldown)
    if not cooldown then return end
    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
    if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
    if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8") end
    if cooldown.SetSwipeColor then cooldown:SetSwipeColor(0, 0, 0, 0.8) end
end

CooldownTracker.ApplySwipeStyle = ApplySwipeStyle

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
    local itemCharges = Helpers.GetItemCharges(itemID)

    local buffStacks, buffRemaining, spellCharges = Helpers.GetItemBuffInfo(spellID, CooldownTracker._hasChargesCache)
    local stackDisplay = Helpers.GetStackDisplay(itemCount, itemCharges, spellCharges, buffStacks)
    local durationObj = Helpers.CreateCooldownDuration(startTime, duration)

    return {
        stackDisplay = stackDisplay,
        duration = durationObj,
        buffRemaining = buffRemaining,
    }
end

function CooldownTracker.UpdateSpell(spellID)
    local duration = C_Spell.GetSpellCooldownDuration(spellID)
    local stacks, charges, hasCharges, chargeDuration, buffRemaining = Helpers.GetSpellStackAndChargeInfo(spellID, CooldownTracker._hasChargesCache)
    local stackDisplay = Helpers.GetStackDisplay(nil, nil, nil, stacks, hasCharges, charges)
    local isUsable, noMana = Helpers.GetSpellUsability(spellID)

    return {
        stackDisplay = stackDisplay,
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
    end
    local startTime, duration, enable = GetActionCooldown(slot)
    if type(startTime) ~= "number" or type(duration) ~= "number" or duration <= 0 then
        return { duration = nil, stackDisplay = nil }
    end
    local durationObj = Helpers.CreateCooldownDuration(startTime, duration)
    return {
        duration = durationObj,
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
    local durationObj = Helpers.CreateCooldownDuration(startTime, duration)
    local data = {
        duration = durationObj,
        stackDisplay = nil,
    }
    local frame = entry.frame
    local cooldown = GetCooldown(frame)
    if cooldown and data.duration then
        cooldown:SetCooldownFromDurationObject(data.duration, true)
        cooldown:Show()
    end
    local icon = GetIcon(frame)
    if icon then
        icon:SetDesaturation(data.duration and 1 or 0)
        icon:SetVertexColor(1.0, 1.0, 1.0)
    end
    local countText = GetCount(frame)
    if countText then countText:Hide() end
    return data
end

-- Try to get cooldown from SpellScanner if available (provides more accurate tracking)
local function TryGetScannerCooldown(entry)
    local scanner = TavernUI.SpellScanner or TavernUI:GetModule("SpellScanner", true)
    if not scanner then return nil end

    local startTime, duration

    -- Try direct spell lookup
    if entry.spellID and scanner.GetSpellActiveCooldown then
        startTime, duration = scanner:GetSpellActiveCooldown(entry.spellID)
    end

    -- Try action slot lookup
    if not startTime and entry.actionSlotID then
        local slot = tonumber(entry.actionSlotID)
        if slot and slot >= 1 and slot <= 120 then
            local atype, id = GetActionInfo(slot)
            if id then
                if (atype == "spell" or atype == "macro") and scanner.GetSpellActiveCooldown then
                    startTime, duration = scanner:GetSpellActiveCooldown(id)
                elseif atype == "item" and scanner.GetItemActiveCooldown then
                    startTime, duration = scanner:GetItemActiveCooldown(id)
                end
            end
        end
    end

    -- Try item lookup
    if not startTime and entry.itemID and scanner.GetItemActiveCooldown then
        startTime, duration = scanner:GetItemActiveCooldown(entry.itemID)
    end

    if startTime and duration then
        local durationObj = Helpers.CreateCooldownDuration(startTime, duration)
        if durationObj then
            return { buffRemaining = durationObj, stackDisplay = nil }
        end
    end

    return nil
end

function CooldownTracker.GetEntryData(entry)
    -- Try SpellScanner first for more accurate cooldown tracking
    if entry.spellID or entry.actionSlotID or entry.itemID then
        local scannerData = TryGetScannerCooldown(entry)
        if scannerData then return scannerData end
    end

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
    local cooldown = GetCooldown(frame)

    if cooldown then
        local durationObj = data.buffRemaining or data.chargeDuration or data.duration
        if durationObj then
            local useReverse = data.buffRemaining ~= nil or data.duration ~= nil
            cooldown:SetCooldownFromDurationObject(durationObj, useReverse)
            cooldown:Show()
        else
            cooldown:Clear()
        end
    end

    local icon = GetIcon(frame)
    if icon then
        local hasCooldown = data.duration or data.buffRemaining or data.chargeDuration
        if hasCooldown then
            icon:SetDesaturation(1)
            icon:SetVertexColor(1.0, 1.0, 1.0)
        elseif data.isUsable == false then
            icon:SetDesaturation(0)
            icon:SetVertexColor(data.noMana and 0.5 or 0.4, data.noMana and 0.5 or 0.4, data.noMana and 1.0 or 0.4)
        else
            icon:SetDesaturation(0)
            icon:SetVertexColor(1.0, 1.0, 1.0)
        end
    end

    local countText = GetCount(frame)
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

module.CooldownTracker = CooldownTracker
