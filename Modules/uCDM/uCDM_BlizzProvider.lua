local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local BlizzProvider = {}

local VIEWER_NAMES = {
    essential = "EssentialCooldownViewer",
    utility = "UtilityCooldownViewer",
    buff = "BuffIconCooldownViewer",
}

BlizzProvider.VIEWER_NAMES = VIEWER_NAMES

local viewerHooks = {}
local entryCache = {}
local initialized = false

local function IsIconFrame(frame)
    if not frame then return false end
    return (frame.Icon or frame.icon) and (frame.Cooldown or frame.cooldown)
end

local function CollectEntries(viewerName, viewerKey)
    local viewer = _G[viewerName]
    if not viewer then return {} end
    
    local entries = {}
    local numChildren = viewer:GetNumChildren()
    local isBuff = viewerKey == "buff"
    
    for i = 1, numChildren do
        local child = select(i, viewer:GetChildren())
        
        if child and child ~= viewer.Selection and IsIconFrame(child) then
            local shouldInclude = true
            
            if isBuff then
                if not child.__ucdmEventHooked then
                    child.__ucdmEventHooked = true
                    local buffViewer = viewer
                    local buffViewerName = viewerName
                    
                    local function TriggerLayout()
                        if module:IsEnabled() and buffViewer:IsShown() then
                            C_Timer.After(0.1, function()
                                if module:IsEnabled() and buffViewer:IsShown() and module.LayoutEngine then
                                    module.LayoutEngine.LayoutViewer("buff")
                                end
                            end)
                        end
                    end
                    
                    if child.OnActiveStateChanged then
                        hooksecurefunc(child, "OnActiveStateChanged", TriggerLayout)
                    end
                    if child.OnUnitAuraAddedEvent then
                        hooksecurefunc(child, "OnUnitAuraAddedEvent", TriggerLayout)
                    end
                    if child.OnUnitAuraRemovedEvent then
                        hooksecurefunc(child, "OnUnitAuraRemovedEvent", TriggerLayout)
                    end
                    
                    child:HookScript("OnShow", function()
                        TriggerLayout()
                    end)
                    
                    child:HookScript("OnHide", function()
                        TriggerLayout()
                    end)
                end
                
                if not child.originalX then
                    local point, relativeTo, relativePoint, x, y = child:GetPoint(1)
                    child.originalX = x or 0
                    child.originalY = y or 0
                end
                
                shouldInclude = true
            else
                local isShown = child:IsShown()
                if not isShown then
                    shouldInclude = false
                end
            end
            
            if shouldInclude then
                local frameID = child:GetName() or ("frame_" .. i)
                local layoutIndex = child.layoutIndex or i
                local entryID = "blizz_" .. viewerKey .. "_" .. layoutIndex
                
                local spellID = nil
                local itemID = nil
                local slotID = nil
                
                if child.GetSpellID then
                    spellID = child:GetSpellID()
                elseif child.spellID then
                    spellID = child.spellID
                elseif child._spellID then
                    spellID = child._spellID
                end
                
                if child.GetItemID then
                    itemID = child:GetItemID()
                elseif child.itemID then
                    itemID = child.itemID
                elseif child._itemID then
                    itemID = child._itemID
                end
                
                if child.GetSlotID then
                    slotID = child:GetSlotID()
                elseif child.slotID then
                    slotID = child.slotID
                elseif child._slotID then
                    slotID = child._slotID
                end
                
                if not spellID and not itemID and not slotID then
                    if child.cooldownData then
                        if child.cooldownData.spellID then
                            spellID = child.cooldownData.spellID
                        end
                        if child.cooldownData.itemID then
                            itemID = child.cooldownData.itemID
                        end
                        if child.cooldownData.slotID then
                            slotID = child.cooldownData.slotID
                        end
                    end
                end
                
                local metadata = {
                    index = layoutIndex,
                    priority = 0,
                    layoutIndex = layoutIndex,
                    spellID = spellID,
                    itemID = itemID,
                    slotID = slotID,
                }
                
                local entry = module.EntrySystem.CreateEntry(entryID, "blizzard", viewerKey, child, metadata)
                if entry then
                    table.insert(entries, entry)
                end
            end
        end
    end
    
    if isBuff then
        table.sort(entries, function(a, b)
            local indexA = a.layoutIndex or 9999
            local indexB = b.layoutIndex or 9999
            
            if indexA ~= indexB then
                return indexA < indexB
            end
            
            local frameA = a.frame
            local frameB = b.frame
            
            if frameA.originalY and frameB.originalY then
                if math.abs(frameA.originalY - frameB.originalY) < 1 then
                    return (frameA.originalX or 0) < (frameB.originalX or 0)
                end
                return (frameA.originalY or 0) > (frameB.originalY or 0)
            end
            
            return indexA < indexB
        end)
    else
        table.sort(entries, function(a, b)
            local indexA = a.layoutIndex or a.index or 9999
            local indexB = b.layoutIndex or b.index or 9999
            return indexA < indexB
        end)
    end
    
    return entries
end

local function HookViewerLayout(viewerName, viewerKey)
    if viewerHooks[viewerName] and viewerHooks[viewerName].hooked then
        return
    end
    
    local viewer = _G[viewerName]
    if not viewer then return end
    
    viewerHooks[viewerName] = {
        hooked = true,
    }
    
    viewer:HookScript("OnShow", function(self)
        if not module:IsEnabled() then return end
        C_Timer.After(0.02, function()
            if module:IsEnabled() and self:IsShown() then
                BlizzProvider.RefreshEntries(viewerKey)
                if module.LayoutEngine then
                    module.LayoutEngine.LayoutViewer(viewerKey)
                end
            end
        end)
    end)
    
            viewer:HookScript("OnHide", function(self)
                if self.__ucdmSizeChangeTimer then
                    self.__ucdmSizeChangeTimer:Cancel()
                    self.__ucdmSizeChangeTimer = nil
                end
                if viewerKey == "buff" and module.LayoutEngine then
                    C_Timer.After(0.05, function()
                        if module:IsEnabled() and module.LayoutEngine then
                            module.LayoutEngine.LayoutViewer("buff")
                        end
                    end)
                end
            end)
    
    viewer:HookScript("OnSizeChanged", function(self)
        if not module:IsEnabled() then return end
        
        if self.__ucdmSizeChangeTimer then
            self.__ucdmSizeChangeTimer:Cancel()
            self.__ucdmSizeChangeTimer = nil
        end
        
        self.__ucdmSizeChangeTimer = C_Timer.NewTimer(0.1, function()
            self.__ucdmSizeChangeTimer = nil
            if module:IsEnabled() then
                BlizzProvider.RefreshEntries(viewerKey)
                if module.LayoutEngine then
                    module.LayoutEngine.LayoutViewer(viewerKey)
                end
            end
        end)
    end)
    
    if viewerKey == "buff" then
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterUnitEvent("UNIT_TARGET", "player")
        
        eventFrame:SetScript("OnEvent", function(self, event, unit)
            if not module:IsEnabled() then return end
            
            if event == "UNIT_TARGET" and unit == "player" then
                if viewer:IsShown() then
                    C_Timer.After(0.1, function()
                        if module:IsEnabled() and viewer:IsShown() then
                            BlizzProvider.RefreshEntries(viewerKey)
                            if module.LayoutEngine then
                                module.LayoutEngine.LayoutViewer(viewerKey)
                            end
                        end
                    end)
                end
            end
        end)
    elseif viewerKey ~= "buff" then
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
        eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
        
        eventFrame:SetScript("OnEvent", function(self, event)
            if not module:IsEnabled() then return end
            if InCombatLockdown() then return end
            
            if viewer:IsShown() then
                C_Timer.After(0.1, function()
                    if module:IsEnabled() and viewer:IsShown() then
                        BlizzProvider.RefreshEntries(viewerKey)
                        if module.LayoutEngine then
                            module.LayoutEngine.LayoutViewer(viewerKey)
                        end
                    end
                end)
            end
        end)
    end
    
    if viewer:IsShown() then
        C_Timer.After(0.3, function()
            if module:IsEnabled() and viewer:IsShown() then
                BlizzProvider.RefreshEntries(viewerKey)
                if module.LayoutEngine then
                    module.LayoutEngine.LayoutViewer(viewerKey)
                end
            end
        end)
    end
    
    module:LogInfo("Hooked layout for " .. viewerName)
end

function BlizzProvider.Reset()
    initialized = false
    viewerHooks = {}
    entryCache = {}
    for viewerKey, viewerName in pairs(VIEWER_NAMES) do
        local viewer = _G[viewerName]
        if viewer then
            viewerHooks[viewerName] = nil
        end
    end
end

function BlizzProvider.Initialize()
    if initialized then return end
    
    local function WaitForBlizzardCM()
        if not _G.EssentialCooldownViewer or not _G.UtilityCooldownViewer or not _G.BuffIconCooldownViewer then
            C_Timer.After(0.5, WaitForBlizzardCM)
            return
        end
        
        for viewerKey, viewerName in pairs(VIEWER_NAMES) do
            HookViewerLayout(viewerName, viewerKey)
            
            C_Timer.After(0.2, function()
                BlizzProvider.RefreshEntries(viewerKey)
                if module.LayoutEngine then
                    module.LayoutEngine.LayoutViewer(viewerKey)
                end
            end)
        end
        
        initialized = true
        module:LogInfo("BlizzProvider initialized")
    end
    
    if _G.EssentialCooldownViewer and _G.UtilityCooldownViewer and _G.BuffIconCooldownViewer then
        WaitForBlizzardCM()
    else
        module:RegisterEvent("ADDON_LOADED", function(event, addonName)
            if addonName == "Blizzard_CooldownManager" then
                WaitForBlizzardCM()
                module:UnregisterEvent("ADDON_LOADED")
            end
        end)
        
        WaitForBlizzardCM()
    end
end

function BlizzProvider.GetEntries(viewerKey)
    local viewerName = VIEWER_NAMES[viewerKey]
    if not viewerName then return {} end
    
    return CollectEntries(viewerName, viewerKey)
end

function BlizzProvider.RefreshEntries(viewerKey)
    local viewerName = VIEWER_NAMES[viewerKey]
    if not viewerName then return {} end
    
    local existingEntries = module.EntrySystem.GetEntriesForViewer(viewerKey, "blizzard")
    for _, entry in ipairs(existingEntries) do
        module.EntrySystem.RemoveEntry(entry.id)
    end
    
    local entries = CollectEntries(viewerName, viewerKey)
    entryCache[viewerKey] = entries
    
    return entries
end

module.BlizzProvider = BlizzProvider
