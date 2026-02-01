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

function ItemRegistry._onActionBarSlotChanged(slot)
    if not slot or not module:IsEnabled() then return end

    local viewerKeys = {}
    for _, item in pairs(itemsById) do
        if item.actionSlotID == slot then
            if item.refreshIcon then
                item:refreshIcon()
            end
            if item.viewerKey then
                viewerKeys[item.viewerKey] = true
            end
        end
    end

    if next(viewerKeys) then
        C_Timer.After(0.1, function()
            if not module:IsEnabled() then return end
            for viewerKey in pairs(viewerKeys) do
                module:RefreshViewer(viewerKey)
            end
        end)
    end
end

function ItemRegistry.Initialize()
    itemsByViewer = {}
    itemsById = {}
    itemsByFrame = {}

    for _, viewerKey in ipairs(module.CONSTANTS.VIEWER_KEYS) do
        itemsByViewer[viewerKey] = {}
    end

    local actionBarFrame = CreateFrame("Frame")
    actionBarFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    actionBarFrame:SetScript("OnEvent", function(self, event, slot)
        if event == "ACTIONBAR_SLOT_CHANGED" and slot then
            ItemRegistry._onActionBarSlotChanged(slot)
        end
    end)

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
-- Blizzard Frame Hooking & Collection (delegated to BlizzardCollector)
--------------------------------------------------------------------------------

function ItemRegistry.HookBlizzardViewers()
    local BlizzardCollector = module.BlizzardCollector
    if not BlizzardCollector or not BlizzardCollector.HookBlizzardViewers then
        return
    end
    BlizzardCollector.HookBlizzardViewers(function()
        for _, vk in ipairs({"essential", "utility", "buff"}) do
            ItemRegistry.CollectBlizzardItems(vk)
        end
        module:RefreshAllViewers()
    end)
end

--------------------------------------------------------------------------------
-- Blizzard Frame Collection (merge BlizzardCollector result with custom items)
--------------------------------------------------------------------------------

function ItemRegistry.CollectBlizzardItems(viewerKey)
    local BlizzardCollector = module.BlizzardCollector
    if not BlizzardCollector or not BlizzardCollector.Collect then
        return
    end
    local newBlizzardItems, seenFrames = BlizzardCollector.Collect(viewerKey, itemsByFrame)
    if not newBlizzardItems then return end

    for _, item in ipairs(newBlizzardItems) do
        itemsById[item.id] = item
        itemsByFrame[item.frame] = item
    end

    local customItems = {}
    local currentItems = itemsByViewer[viewerKey] or {}
    for _, item in ipairs(currentItems) do
        if item.source == "custom" then
            customItems[#customItems + 1] = item
        end
    end

    for _, item in ipairs(currentItems) do
        if item.source == "blizzard" and item.frame and not (seenFrames and seenFrames[item.frame]) then
            itemsById[item.id] = nil
            itemsByFrame[item.frame] = nil
        end
    end

    local allItems = {}
    for _, item in ipairs(newBlizzardItems) do
        allItems[#allItems + 1] = item
    end
    for _, item in ipairs(customItems) do
        allItems[#allItems + 1] = item
    end

    table.sort(allItems, function(a, b)
        return (a.index or 9999) < (b.index or 9999)
    end)

    for i, item in ipairs(allItems) do
        item.layoutIndex = i
    end

    itemsByViewer[viewerKey] = allItems
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
    if config.viewer == "buff" then return false end
    if config.actionSlotID and type(config.actionSlotID) == "number" and config.actionSlotID >= 1 and config.actionSlotID <= 120 then
        return true
    end
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

    local item = module.CooldownItem.new({
        id = id,
        source = "custom",
        viewerKey = viewerKey,
        frame = frame,
        spellID = config.spellID,
        itemID = config.itemID,
        slotID = config.slotID,
        actionSlotID = config.actionSlotID,
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
                actionSlotID = item.actionSlotID,
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

    if frame.Icon and frame.Icon.GetNumMaskTextures then
        for i = frame.Icon:GetNumMaskTextures(), 1, -1 do
            local m = frame.Icon:GetMaskTexture(i)
            if m then frame.Icon:RemoveMaskTexture(m) end
        end
        frame.IconMask = nil
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
    frame.__ucdmTooltipHooked = nil

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

function ItemRegistry.ClearViewerItems(viewerKey)
    if not viewerKey then return end
    itemsByViewer[viewerKey] = {}
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

module.ItemRegistry = ItemRegistry
