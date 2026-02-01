local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local BlizzardCollector = {}

local VIEWER_CATEGORIES = {
    essential = Enum.CooldownViewerCategory.Essential,
    utility = Enum.CooldownViewerCategory.Utility,
    buff = Enum.CooldownViewerCategory.TrackedBuff,
}

local blizzardHooked = {}
local cooldownEventsFrame = nil

local function isIconFrame(frame)
    if not frame then return false end
    return (frame.Icon or frame.icon) and (frame.Cooldown or frame.cooldown)
end

local function hookBuffFrameEvents(frame, viewer)
    frame.__ucdmEventHooked = true
    local function TriggerLayout(delayed)
        if module:IsEnabled() and viewer:IsShown() and module.LayoutEngine then
            if delayed then
                C_Timer.After(0.1, function()
                    if module:IsEnabled() and viewer:IsShown() then
                        module.LayoutEngine.RefreshViewer("buff")
                    end
                end)
            else
                module.LayoutEngine.RefreshViewer("buff")
            end
        end
    end
    if frame.OnActiveStateChanged then
        hooksecurefunc(frame, "OnActiveStateChanged", function() TriggerLayout(true) end)
    end
    if frame.OnUnitAuraAddedEvent then
        hooksecurefunc(frame, "OnUnitAuraAddedEvent", function() TriggerLayout(true) end)
    end
    if frame.OnUnitAuraRemovedEvent then
        hooksecurefunc(frame, "OnUnitAuraRemovedEvent", function() TriggerLayout(true) end)
    end
    frame:HookScript("OnShow", function() TriggerLayout(false) end)
    frame:HookScript("OnHide", function() TriggerLayout(false) end)
end

function BlizzardCollector.ApplyViewerOverrides(viewer)
    if not viewer then return end
    viewer.iconScale = 1
    viewer.iconPadding = 0
end

function BlizzardCollector.HookBlizzardViewers(onHooksReady)
    local function HookViewer(viewerKey)
        local viewerName = module.CONSTANTS.VIEWER_NAMES[viewerKey]
        if not viewerName then return false end
        local viewer = _G[viewerName]
        if not viewer then return false end
        if blizzardHooked[viewerKey] then return true end
        blizzardHooked[viewerKey] = true

        viewer:HookScript("OnShow", function(self)
            if not module:IsEnabled() then return end
            C_Timer.After(0.05, function()
                if module:IsEnabled() and self:IsShown() then
                    module:RefreshViewer(viewerKey)
                end
            end)
        end)

        if module.LayoutEngine and module.LayoutEngine.IsLayoutDrivenByBlizzardHook and not module.LayoutEngine:IsLayoutDrivenByBlizzardHook(viewerKey) then
            viewer:HookScript("OnSizeChanged", function(self)
                if not module:IsEnabled() then return end
                if module.LayoutEngine.IsSettingViewerSize and module.LayoutEngine:IsSettingViewerSize(viewerKey) then return end
                module:RefreshViewer(viewerKey)
            end)
        end

        BlizzardCollector.ApplyViewerOverrides(viewer)

        if viewerKey == "buff" then
            BlizzardCollector._hookBuffViewerEvents(viewer, viewerKey)
        else
            BlizzardCollector._hookCooldownEventsShared()
        end
        return true
    end

    local allHooked = true
    for viewerKey, viewerName in pairs(module.CONSTANTS.VIEWER_NAMES) do
        if _G[viewerName] then
            HookViewer(viewerKey)
        else
            allHooked = false
        end
    end

    if not allHooked then
        local waitFrame = CreateFrame("Frame")
        waitFrame:RegisterEvent("ADDON_LOADED")
        waitFrame:SetScript("OnEvent", function(self, event, addonName)
            if addonName == "Blizzard_CooldownManager" then
                C_Timer.After(0.2, function()
                    for viewerKey in pairs(module.CONSTANTS.VIEWER_NAMES) do
                        HookViewer(viewerKey)
                    end
                    if onHooksReady then onHooksReady() end
                end)
                self:UnregisterAllEvents()
            end
        end)
    else
        if onHooksReady then onHooksReady() end
    end
end

function BlizzardCollector._hookBuffViewerEvents(viewer, viewerKey)
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterUnitEvent("UNIT_TARGET", "player")
    eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
    eventFrame:SetScript("OnEvent", function(self, event, unit)
        if not module:IsEnabled() then return end
        if viewer:IsShown() then
            C_Timer.After(0.1, function()
                if module:IsEnabled() and viewer:IsShown() then
                    module:RefreshViewer(viewerKey)
                end
            end)
        end
    end)
end

function BlizzardCollector._hookCooldownEventsShared()
    if cooldownEventsFrame then return end
    cooldownEventsFrame = CreateFrame("Frame")
    cooldownEventsFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    cooldownEventsFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    cooldownEventsFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    cooldownEventsFrame:SetScript("OnEvent", function()
        if not module:IsEnabled() then return end
        if InCombatLockdown() then return end
        C_Timer.After(0.1, function()
            if not module:IsEnabled() then return end
            for _, vk in ipairs({"essential", "utility"}) do
                local v = _G[module.CONSTANTS.VIEWER_NAMES[vk]]
                if v and v:IsShown() then
                    module:RefreshViewerContent(vk)
                end
            end
        end)
    end)
end

function BlizzardCollector.Collect(viewerKey, itemsByFrame)
    local viewerName = module.CONSTANTS.VIEWER_NAMES[viewerKey]
    if not viewerName then return nil, nil end
    local viewer = _G[viewerName]
    if not viewer then return nil, nil end
    local category = VIEWER_CATEGORIES[viewerKey]
    if not category then return nil, nil end

    local cooldownIDs = nil
    if viewer.GetCooldownIDs then
        cooldownIDs = viewer:GetCooldownIDs()
    end
    if not cooldownIDs or #cooldownIDs == 0 then
        cooldownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(category, true)
    end
    if not cooldownIDs or #cooldownIDs == 0 then
        return {}, {}
    end

    local framesByIndex = {}
    local numChildren = viewer:GetNumChildren()
    for i = 1, numChildren do
        local child = select(i, viewer:GetChildren())
        if child and child ~= viewer.Selection and isIconFrame(child) then
            if viewerKey == "buff" and not child.__ucdmEventHooked then
                hookBuffFrameEvents(child, viewer)
            end
            local layoutIndex = child.layoutIndex
            if layoutIndex and layoutIndex > 0 and layoutIndex <= #cooldownIDs then
                framesByIndex[layoutIndex] = child
            end
            if child.GetCooldownID then
                local frameCooldownID = child:GetCooldownID()
                for idx, cooldownID in ipairs(cooldownIDs) do
                    if cooldownID == frameCooldownID then
                        framesByIndex[idx] = child
                        break
                    end
                end
            end
        end
    end

    local newBlizzardItems = {}
    local seenFrames = {}
    itemsByFrame = itemsByFrame or {}

    for index, cooldownID in ipairs(cooldownIDs) do
        local cooldownInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
        if cooldownInfo then
            local frame = framesByIndex[index]
            if frame then
                seenFrames[frame] = true
                local spellID = cooldownInfo.spellID
                local itemID = frame.GetItemID and frame:GetItemID() or frame.itemID
                local slotID = frame.GetSlotID and frame:GetSlotID() or frame.slotID
                if frame.cooldownData then
                    itemID = itemID or frame.cooldownData.itemID
                    slotID = slotID or frame.cooldownData.slotID
                end

                local item = itemsByFrame[frame]
                if not item then
                    local id = "blizz_" .. viewerKey .. "_" .. cooldownID
                    item = module.CooldownItem.new({
                        id = id,
                        source = "blizzard",
                        viewerKey = viewerKey,
                        frame = frame,
                        spellID = spellID,
                        itemID = itemID,
                        slotID = slotID,
                        cooldownID = cooldownID,
                        index = index,
                        layoutIndex = index,
                    })
                else
                    item.spellID = spellID
                    item.itemID = itemID
                    item.slotID = slotID
                    item.cooldownID = cooldownID
                    item.index = index
                    item.layoutIndex = index
                    item.viewerKey = viewerKey
                end
                newBlizzardItems[#newBlizzardItems + 1] = item
            end
        end
    end
    return newBlizzardItems, seenFrames
end

module.BlizzardCollector = BlizzardCollector
