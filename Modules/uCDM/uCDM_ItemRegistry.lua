local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

--[[
    ItemRegistry - Central store for all CooldownItems

    Responsibilities:
    1. Collect items from Blizzard cooldown viewer frames
    2. Create and manage custom items
    3. Provide items to LayoutEngine for positioning
    4. Handle item ordering
]]

local ItemRegistry = {}

local VIEWER_CATEGORIES = {
    essential = Enum.CooldownViewerCategory.Essential,
    utility = Enum.CooldownViewerCategory.Utility,
    buff = Enum.CooldownViewerCategory.TrackedBuff,
}

-- Storage
local itemsByViewer = {}      -- viewerKey -> {CooldownItem, ...}
local itemsById = {}          -- id -> CooldownItem
local itemsByFrame = {}       -- frame -> CooldownItem
local blizzardHooked = {}     -- viewerKey -> boolean
local customFramePool = {}
local customFrameCounter = 0
local initialized = false

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function ItemRegistry.Initialize()
    itemsByViewer = {}
    itemsById = {}
    itemsByFrame = {}

    for _, viewerKey in ipairs(module.CONSTANTS.VIEWER_KEYS) do
        itemsByViewer[viewerKey] = {}
    end

    initialized = true
end

function ItemRegistry.Reset()
    -- Release all custom frames
    for id, item in pairs(itemsById) do
        if item.source == "custom" and item.frame then
            ItemRegistry._releaseCustomFrame(item.frame)
        end
    end

    itemsByViewer = {}
    itemsById = {}
    itemsByFrame = {}

    for _, viewerKey in ipairs(module.CONSTANTS.VIEWER_KEYS) do
        itemsByViewer[viewerKey] = {}
    end

    initialized = false
end

--------------------------------------------------------------------------------
-- Blizzard Frame Hooking
--------------------------------------------------------------------------------

function ItemRegistry.HookBlizzardViewers()
    local function HookViewer(viewerKey)
        local viewerName = module.CONSTANTS.VIEWER_NAMES[viewerKey]
        if not viewerName then return false end

        local viewer = _G[viewerName]
        if not viewer then return false end
        if blizzardHooked[viewerKey] then return true end

        blizzardHooked[viewerKey] = true

        -- Hook OnShow to refresh items
        viewer:HookScript("OnShow", function(self)
            if not module:IsEnabled() then return end
            C_Timer.After(0.05, function()
                if module:IsEnabled() and self:IsShown() then
                    module:RefreshViewer(viewerKey)
                end
            end)
        end)

        if not module.LayoutEngine.IsLayoutDrivenByBlizzardHook(viewerKey) then
            viewer:HookScript("OnSizeChanged", function(self)
                if not module:IsEnabled() then return end
                if module.LayoutEngine.IsSettingViewerSize(viewerKey) then return end
                module:RefreshViewer(viewerKey)
            end)
        end

        -- Buff viewer needs extra event handling
        if viewerKey == "buff" then
            ItemRegistry._hookBuffViewerEvents(viewer, viewerKey)
        else
            ItemRegistry._hookCooldownEvents(viewer, viewerKey)
        end
        return true
    end

    -- Try to hook all viewers
    local allHooked = true
    for viewerKey, viewerName in pairs(module.CONSTANTS.VIEWER_NAMES) do
        if _G[viewerName] then
            HookViewer(viewerKey)
        else
            allHooked = false
        end
    end

    -- If not all hooked, wait for addon load
    if not allHooked then
        local waitFrame = CreateFrame("Frame")
        waitFrame:RegisterEvent("ADDON_LOADED")
        waitFrame:SetScript("OnEvent", function(self, event, addonName)
            if addonName == "Blizzard_CooldownManager" then
                C_Timer.After(0.2, function()
                    for viewerKey in pairs(module.CONSTANTS.VIEWER_NAMES) do
                        HookViewer(viewerKey)
                    end
                    -- Trigger initial collection
                    for _, vk in ipairs({"essential", "utility", "buff"}) do
                        ItemRegistry.CollectBlizzardItems(vk)
                    end
                    module:RefreshAllViewers()
                end)
                self:UnregisterAllEvents()
            end
        end)
    end
end

function ItemRegistry._hookBuffViewerEvents(viewer, viewerKey)
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

function ItemRegistry._hookCooldownEvents(viewer, viewerKey)
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
                    module:RefreshViewerContent(viewerKey)
                end
            end)
        end
    end)
end

--------------------------------------------------------------------------------
-- Blizzard Frame Collection
--------------------------------------------------------------------------------

function ItemRegistry.CollectBlizzardItems(viewerKey)
    local viewerName = module.CONSTANTS.VIEWER_NAMES[viewerKey]
    if not viewerName then return end

    local viewer = _G[viewerName]
    if not viewer then return end

    local category = VIEWER_CATEGORIES[viewerKey]
    if not category then return end

    -- Get cooldown IDs from viewer or API
    local cooldownIDs = nil
    if viewer.GetCooldownIDs then
        cooldownIDs = viewer:GetCooldownIDs()
    end
    if not cooldownIDs or #cooldownIDs == 0 then
        cooldownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(category, true)
    end
    if not cooldownIDs or #cooldownIDs == 0 then
        return
    end

    -- Build frame lookup by layout index and cooldown ID
    local framesByIndex = {}
    local numChildren = viewer:GetNumChildren()

    for i = 1, numChildren do
        local child = select(i, viewer:GetChildren())
        if child and child ~= viewer.Selection and ItemRegistry._isIconFrame(child) then
            -- Hook buff frame events if needed
            if viewerKey == "buff" and not child.__ucdmEventHooked then
                ItemRegistry._hookBuffFrameEvents(child, viewer)
            end

            -- Map by layout index
            local layoutIndex = child.layoutIndex
            if layoutIndex and layoutIndex > 0 and layoutIndex <= #cooldownIDs then
                framesByIndex[layoutIndex] = child
            end

            -- Also try matching by cooldown ID
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

    -- Create/update items for each cooldown
    local newBlizzardItems = {}
    local seenFrames = {}

    for index, cooldownID in ipairs(cooldownIDs) do
        local cooldownInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
        if cooldownInfo then
            local frame = framesByIndex[index]
            if frame then
                seenFrames[frame] = true

                -- Extract IDs from frame
                local spellID = cooldownInfo.spellID
                local itemID = frame.GetItemID and frame:GetItemID() or frame.itemID
                local slotID = frame.GetSlotID and frame:GetSlotID() or frame.slotID

                if frame.cooldownData then
                    itemID = itemID or frame.cooldownData.itemID
                    slotID = slotID or frame.cooldownData.slotID
                end

                -- Find or create item
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
                    itemsById[id] = item
                    itemsByFrame[frame] = item
                else
                    -- Update existing item
                    local oldSpellID = item.spellID
                    local oldIndex = item.index
                    local oldCooldownID = item.cooldownID
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

    -- Get existing custom items for this viewer
    local customItems = {}
    local currentItems = itemsByViewer[viewerKey] or {}
    for _, item in ipairs(currentItems) do
        if item.source == "custom" then
            customItems[#customItems + 1] = item
        end
    end

    -- Remove stale blizzard items
    for _, item in ipairs(currentItems) do
        if item.source == "blizzard" and item.frame and not seenFrames[item.frame] then
            itemsById[item.id] = nil
            itemsByFrame[item.frame] = nil
        end
    end

    -- Combine: blizzard items first, then custom
    local allItems = {}
    for _, item in ipairs(newBlizzardItems) do
        allItems[#allItems + 1] = item
    end
    for _, item in ipairs(customItems) do
        allItems[#allItems + 1] = item
    end

    -- Sort by index
    table.sort(allItems, function(a, b)
        return (a.index or 9999) < (b.index or 9999)
    end)

    -- Update layout indices
    for i, item in ipairs(allItems) do
        item.layoutIndex = i
    end

    itemsByViewer[viewerKey] = allItems
end

function ItemRegistry._isIconFrame(frame)
    if not frame then return false end
    return (frame.Icon or frame.icon) and (frame.Cooldown or frame.cooldown)
end

function ItemRegistry._hookBuffFrameEvents(frame, viewer)
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

--------------------------------------------------------------------------------
-- Custom Items
--------------------------------------------------------------------------------

function ItemRegistry.LoadCustomEntries()
    local customEntries = module:GetSetting("customEntries", {})
    if not customEntries or #customEntries == 0 then return end

    local viewersToRefresh = {}
    for _, config in ipairs(customEntries) do
        if config.enabled ~= false and ItemRegistry._isValidCustomConfig(config) then
            local item = ItemRegistry.CreateCustomItem(config, true)
            if item then
                viewersToRefresh[item.viewerKey] = true
            end
        end
    end

    -- Refresh affected viewers after a short delay
    C_Timer.After(0.1, function()
        if module:IsEnabled() then
            for viewerKey in pairs(viewersToRefresh) do
                module:RefreshViewer(viewerKey)
            end
        end
    end)
end

function ItemRegistry._isValidCustomConfig(config)
    if not config or type(config) ~= "table" then return false end
    if config.viewer == "buff" then return false end  -- Can't add custom to buff viewer
    return config.spellID or config.itemID or config.slotID
end

function ItemRegistry.CreateCustomItem(config, skipDBSave)
    if not ItemRegistry._isValidCustomConfig(config) then
        module:LogError("Invalid custom item config")
        return nil
    end

    -- Normalize viewer key
    local viewerKey = config.viewer
    if viewerKey == "custom" or not viewerKey then
        viewerKey = "essential"
    end

    -- Generate ID if not provided
    local id = config.id
    if not id then
        customFrameCounter = customFrameCounter + 1
        id = "custom_" .. GetTime() .. "_" .. customFrameCounter
    end

    if itemsById[id] then return itemsById[id] end

    -- Create frame parented to Blizzard's viewer so it picks up same padding/styling
    local viewer = module:GetViewerFrame(viewerKey)
    local frame = ItemRegistry._acquireCustomFrame(id, viewer)
    if not frame then
        module:LogError("Failed to create frame for custom item")
        return nil
    end

    -- Determine index
    local index = config.index
    if not index then
        local viewerItems = itemsByViewer[viewerKey] or {}
        index = #viewerItems + 1
    end

    -- Create item
    local item = module.CooldownItem.new({
        id = id,
        source = "custom",
        viewerKey = viewerKey,
        frame = frame,
        spellID = config.spellID,
        itemID = config.itemID,
        slotID = config.slotID,
        index = index,
        config = config.config or config,
        enabled = config.enabled ~= false,
    })

    -- Set icon
    item:refreshIcon()

    if viewer then
        frame:SetParent(viewer)
    else
        frame:SetParent(UIParent)
    end

    -- Register
    itemsById[id] = item
    itemsByFrame[frame] = item

    -- Add to viewer's item list
    if not itemsByViewer[viewerKey] then
        itemsByViewer[viewerKey] = {}
    end
    table.insert(itemsByViewer[viewerKey], item)

    -- Re-sort and update layout indices
    table.sort(itemsByViewer[viewerKey], function(a, b)
        return (a.index or 9999) < (b.index or 9999)
    end)
    for i, vi in ipairs(itemsByViewer[viewerKey]) do
        vi.layoutIndex = i
    end

    -- Save to DB unless told not to
    if not skipDBSave then
        local customEntries = module:GetSetting("customEntries", {})
        local exists = false
        for _, existing in ipairs(customEntries) do
            if existing.id == item.id then
                exists = true
                break
            end
        end

        if not exists then
            customEntries[#customEntries + 1] = {
                id = item.id,
                spellID = item.spellID,
                itemID = item.itemID,
                slotID = item.slotID,
                viewer = item.viewerKey,
                index = item.index,
                enabled = item.enabled,
                config = item.config,
            }
            module:SetSetting("customEntries", customEntries)
        end
    end

    return item
end

function ItemRegistry.RemoveCustomItem(id)
    local item = itemsById[id]
    if not item then return false end
    if item.source ~= "custom" then return false end

    local viewerKey = item.viewerKey

    -- Release frame
    if item.frame then
        item.frame:Hide()
        ItemRegistry._releaseCustomFrame(item.frame)
        itemsByFrame[item.frame] = nil
    end

    -- Remove from viewer list
    local viewerItems = itemsByViewer[viewerKey]
    if viewerItems then
        for i, vi in ipairs(viewerItems) do
            if vi.id == id then
                table.remove(viewerItems, i)
                break
            end
        end
        -- Re-index remaining items
        for i, vi in ipairs(viewerItems) do
            vi.layoutIndex = i
        end
    end

    -- Remove from ID lookup
    itemsById[id] = nil

    -- Update saved settings
    local customEntries = module:GetSetting("customEntries", {})
    for i, config in ipairs(customEntries) do
        if config.id == id then
            table.remove(customEntries, i)
            module:SetSetting("customEntries", customEntries)
            break
        end
    end

    -- Refresh the viewer
    if module.LayoutEngine then
        module.LayoutEngine.RefreshViewer(viewerKey)
    end

    return true
end

function ItemRegistry._acquireCustomFrame(id, parent)
    local frame = table.remove(customFramePool)

    if not frame then
        frame = CreateFrame("Button", "uCDMCustomFrame_" .. id, parent or UIParent)
        frame:SetSize(40, 40)

        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(frame)
        frame.Icon = icon

        local mask = frame:CreateMaskTexture()
        mask:SetAtlas("UI-HUD-CoolDownManager-Mask")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
        frame.IconMask = mask

        -- Create cooldown WITHOUT template to avoid circular mask
        local cooldown = CreateFrame("Cooldown", nil, frame)
        cooldown:SetAllPoints(frame)
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawBling(false)
        cooldown:SetDrawSwipe(true)
        cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8")
        cooldown:SetSwipeColor(0, 0, 0, 0.8)
        cooldown:SetHideCountdownNumbers(false)
        frame.Cooldown = cooldown

        local count = TavernUI:CreateFontString(frame, 16)
        count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        frame.Count = count
    end

    frame._ucdmItemId = id
    frame:Show()
    return frame
end

function ItemRegistry._releaseCustomFrame(frame)
    if not frame then return end

    frame:Hide()
    frame:ClearAllPoints()
    frame._ucdmItemId = nil

    if #customFramePool < 50 then
        table.insert(customFramePool, frame)
    end
end

--------------------------------------------------------------------------------
-- Accessors
--------------------------------------------------------------------------------

function ItemRegistry.GetItemsForViewer(viewerKey)
    return itemsByViewer[viewerKey] or {}
end

function ItemRegistry.GetItem(id)
    return itemsById[id]
end

function ItemRegistry.GetItemByFrame(frame)
    return itemsByFrame[frame]
end

function ItemRegistry.ReorderItem(id, newIndex, viewerKey)
    local item = itemsById[id]
    if not item then return false end

    viewerKey = viewerKey or item.viewerKey
    local items = itemsByViewer[viewerKey]
    if not items then return false end

    -- Find current position
    local currentIndex = nil
    for i, vi in ipairs(items) do
        if vi.id == id then
            currentIndex = i
            break
        end
    end

    if not currentIndex then return false end
    if newIndex < 1 or newIndex > #items then return false end

    -- Move item
    table.remove(items, currentIndex)
    table.insert(items, newIndex, item)

    -- Update indices
    for i, vi in ipairs(items) do
        vi.index = i
        vi.layoutIndex = i
    end

    -- Update DB for custom items
    local customEntries = module:GetSetting("customEntries", {})
    for _, vi in ipairs(items) do
        if vi.source == "custom" then
            for _, cfg in ipairs(customEntries) do
                if cfg.id == vi.id then
                    cfg.index = vi.index
                    break
                end
            end
        end
    end
    module:SetSetting("customEntries", customEntries)

    return true
end

function ItemRegistry.MoveItemToViewer(id, newViewerKey)
    local item = itemsById[id]
    if not item then return false end
    if item.source ~= "custom" then return false end
    if newViewerKey == "buff" then return false end

    local oldViewerKey = item.viewerKey
    if oldViewerKey == newViewerKey then return true end

    -- Remove from old viewer
    local oldItems = itemsByViewer[oldViewerKey]
    if oldItems then
        for i, vi in ipairs(oldItems) do
            if vi.id == id then
                table.remove(oldItems, i)
                break
            end
        end
        for i, vi in ipairs(oldItems) do
            vi.layoutIndex = i
        end
    end

    -- Add to new viewer
    item.viewerKey = newViewerKey
    if not itemsByViewer[newViewerKey] then
        itemsByViewer[newViewerKey] = {}
    end
    item.index = #itemsByViewer[newViewerKey] + 1
    item.layoutIndex = item.index
    table.insert(itemsByViewer[newViewerKey], item)

    -- Update parent
    local viewer = module:GetViewerFrame(newViewerKey)
    if viewer and item.frame then
        item.frame:SetParent(viewer)
    end

    -- Update DB
    local customEntries = module:GetSetting("customEntries", {})
    for _, cfg in ipairs(customEntries) do
        if cfg.id == id then
            cfg.viewer = newViewerKey
            cfg.index = item.index
            break
        end
    end
    module:SetSetting("customEntries", customEntries)

    return true
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

module.ItemRegistry = ItemRegistry
