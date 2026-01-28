local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local CustomProvider = {}

function CustomProvider.CreateEntry(config)
    if not config then
        module:LogError("CustomProvider.CreateEntry: config is required")
        return nil
    end
    
    if config.viewer == "buff" then
        module:LogError("CustomProvider.CreateEntry: Cannot add custom entries to buff viewer")
        return nil
    end
    
    local trackingType = nil
    local id = nil
    
    if config.spellID then
        trackingType = module.EntrySystem.TRACKING_TYPE.SPELL
        id = config.spellID
    elseif config.itemID then
        trackingType = module.EntrySystem.TRACKING_TYPE.ITEM
        id = config.itemID
    elseif config.slotID then
        trackingType = module.EntrySystem.TRACKING_TYPE.TRINKET
        id = config.slotID
    else
        module:LogError("CustomProvider.CreateEntry: Must provide spellID, itemID, or slotID")
        return nil
    end
    
    local entryID = module.EntrySystem.GenerateID("custom", trackingType, id)
    local viewerKey = config.viewer or "essential"
    if viewerKey == "custom" then
        viewerKey = "essential"
        config.viewer = "essential"
    end
    
    local frame = module.FrameManager.CreateCustomFrame({id = entryID})
    
    if not frame then
        module:LogError("CustomProvider.CreateEntry: Failed to create frame")
        return nil
    end
    
    if config.spellID then
        local spellInfo = C_Spell.GetSpellInfo(config.spellID)
        if spellInfo and frame.Icon then
            frame.Icon:SetTexture(spellInfo.iconID)
            frame._iconFileID = spellInfo.iconID
        end
    elseif config.itemID then
        local itemInfo = nil
        if C_Item and C_Item.GetItemInfoByID then
            local ok, result = pcall(C_Item.GetItemInfoByID, config.itemID)
            if ok and result then
                itemInfo = result
            end
        end
        if not itemInfo then
            local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(config.itemID)
            if itemTexture then
                itemInfo = { iconFileID = itemTexture }
            end
        end
        if itemInfo and frame.Icon then
            frame.Icon:SetTexture(itemInfo.iconFileID)
            frame._iconFileID = itemInfo.iconFileID
        end
    elseif config.slotID then
        local itemID = GetInventoryItemID("player", config.slotID)
        if itemID then
            local itemInfo = nil
            if C_Item and C_Item.GetItemInfoByID then
                local ok, result = pcall(C_Item.GetItemInfoByID, itemID)
                if ok and result then
                    itemInfo = result
                end
            end
            if not itemInfo then
                local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemID)
                if itemTexture then
                    itemInfo = { iconFileID = itemTexture }
                end
            end
            if itemInfo and frame.Icon then
                frame.Icon:SetTexture(itemInfo.iconFileID)
                frame._iconFileID = itemInfo.iconFileID
            end
        end
    end
    
    if not frame._iconFileID then
        frame.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    
    if viewerKey ~= "custom" then
        local viewer = module.LayoutEngine.GetViewerFrame(viewerKey)
        if viewer then
            frame:SetParent(viewer)
        end
    end
    
    if not frame then
        module:LogError("CustomProvider.CreateEntry: Failed to create frame")
        return nil
    end
    
    local index = config.index
    if not index then
        index = module.EntrySystem.GetNextIndex(viewerKey)
    end
    
    local metadata = {
        spellID = config.spellID,
        itemID = config.itemID,
        slotID = config.slotID,
        index = index,
        priority = config.priority or 0,
        config = config,
        enabled = config.enabled ~= false,
    }
    
    local entry = module.EntrySystem.CreateEntry(entryID, "custom", viewerKey, frame, metadata)
    
    if entry then
        if module.CooldownTracker then
            module.CooldownTracker.UpdateEntry(entry)
        end
        
        local db = module:GetDB()
        if db then
            if not db.customEntries then
                db.customEntries = {}
            end
            
            local alreadyExists = false
            for _, existing in ipairs(db.customEntries) do
                if existing.id == entryID then
                    alreadyExists = true
                    break
                end
            end
            
            if not alreadyExists then
                local entryConfig = {
                    id = entryID,
                    spellID = config.spellID,
                    itemID = config.itemID,
                    slotID = config.slotID,
                    viewer = viewerKey,
                    index = index,
                    enabled = config.enabled ~= false,
                    config = config,
                }
                
                table.insert(db.customEntries, entryConfig)
            end
        end
        
        module.EntrySystem.ReindexViewer(viewerKey)
        
        if module.RefreshManager then
            module.RefreshManager.RefreshViewer(viewerKey)
        end
    end
    
    return entry
end

function CustomProvider.RemoveEntry(entryID)
    if not entryID then return end
    
    local entry = module.EntrySystem.GetEntry(entryID)
    if not entry then return end
    
    local viewerKey = entry.source
    
    if entry.frame and entry.type == "custom" then
        module.FrameManager.ReleaseFrame(entry.frame)
    end
    
    module.EntrySystem.RemoveEntry(entryID)
    
    local db = module:GetDB()
    if db and db.customEntries then
        for i, entryConfig in ipairs(db.customEntries) do
            if entryConfig.id == entryID then
                table.remove(db.customEntries, i)
                break
            end
        end
    end
    
        module.EntrySystem.ReindexViewer(viewerKey)
        
        if module.RefreshManager then
            module.RefreshManager.RefreshViewer(viewerKey)
        end
end

function CustomProvider.LoadFromDB()
    local db = module:GetDB()
    if not db or not db.customEntries then
        return
    end
    
    for _, entryConfig in ipairs(db.customEntries) do
        if entryConfig.enabled ~= false then
            local ok, entry = pcall(function()
                return CustomProvider.CreateEntry(entryConfig)
            end)
            if not ok then
                module:LogError("Failed to load custom entry: " .. tostring(entry))
            end
        end
    end
    
    local count = #(db.customEntries or {})
    if count > 0 then
        module:LogInfo("Loaded " .. count .. " custom entries from DB")
    end
end

function CustomProvider.Initialize()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
            
            C_Timer.After(0.2, function()
                local db = module:GetDB()
                if db and db.customEntries then
                    for _, entryConfig in ipairs(db.customEntries) do
                        if entryConfig.viewer == "custom" then
                            entryConfig.viewer = "essential"
                        end
                    end
                end
                
                CustomProvider.LoadFromDB()
                
                module:LogInfo("CustomProvider initialized")
            end)
        end
    end)
    
    if IsLoggedIn() then
        eventFrame:GetScript("OnEvent")(eventFrame, "PLAYER_ENTERING_WORLD")
    end
end

module.CustomProvider = CustomProvider
