local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("QoL", "AceEvent-3.0")

local NUM_BAGS = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
local BACKPACK_CONTAINER = BACKPACK_CONTAINER
local LE_ITEM_QUALITY_POOR = (Enum and Enum.ItemQuality and Enum.ItemQuality.Poor) or 0
local SELL_BATCH_SIZE = 10

local REPAIR_PRIORITY = {
    none = 1,
    player = 2,
    guild = 3,
    guild_then_player = 4,
}

local LOOT_TICK_INTERVAL = 0.033
local EnumLootSlotTypeNone = Enum and Enum.LootSlotType and Enum.LootSlotType.None
local EnumLootSlotTypeItem = Enum and Enum.LootSlotType and Enum.LootSlotType.Item

local QUAZII_FPS_CVARS = {
    ["vsync"] = "0",
    ["LowLatencyMode"] = "3",
    ["MSAAQuality"] = "0",
    ["ffxAntiAliasingMode"] = "0",
    ["alphaTestMSAA"] = "1",
    ["cameraFov"] = "90",
    ["graphicsQuality"] = "9",
    ["graphicsShadowQuality"] = "0",
    ["graphicsLiquidDetail"] = "1",
    ["graphicsParticleDensity"] = "5",
    ["graphicsSSAO"] = "0",
    ["graphicsDepthEffects"] = "0",
    ["graphicsComputeEffects"] = "0",
    ["graphicsOutlineMode"] = "1",
    ["OutlineEngineMode"] = "1",
    ["graphicsTextureResolution"] = "2",
    ["graphicsSpellDensity"] = "0",
    ["spellClutter"] = "1",
    ["spellVisualDensityFilterSetting"] = "1",
    ["graphicsProjectedTextures"] = "1",
    ["projectedTextures"] = "1",
    ["graphicsViewDistance"] = "3",
    ["graphicsEnvironmentDetail"] = "0",
    ["graphicsGroundClutter"] = "0",
    ["gxTripleBuffer"] = "0",
    ["textureFilteringMode"] = "5",
    ["graphicsRayTracedShadows"] = "0",
    ["rtShadowQuality"] = "0",
    ["ResampleQuality"] = "4",
    ["ffxSuperResolution"] = "1",
    ["VRSMode"] = "0",
    ["GxApi"] = "D3D12",
    ["physicsLevel"] = "0",
    ["maxFPS"] = "144",
    ["maxFPSBk"] = "60",
    ["targetFPS"] = "61",
    ["useTargetFPS"] = "0",
    ["ResampleSharpness"] = "0.2",
    ["Contrast"] = "75",
    ["Brightness"] = "50",
    ["Gamma"] = "1",
    ["particulatesEnabled"] = "0",
    ["clusteredShading"] = "0",
    ["volumeFogLevel"] = "0",
    ["reflectionMode"] = "0",
    ["ffxGlow"] = "0",
    ["farclip"] = "5000",
    ["horizonStart"] = "1000",
    ["horizonClip"] = "5000",
    ["lodObjectCullSize"] = "35",
    ["lodObjectFadeScale"] = "50",
    ["lodObjectMinSize"] = "0",
    ["doodadLodScale"] = "50",
    ["entityLodDist"] = "7",
    ["terrainLodDist"] = "350",
    ["TerrainLodDiv"] = "512",
    ["waterDetail"] = "1",
    ["rippleDetail"] = "0",
    ["weatherDensity"] = "3",
    ["entityShadowFadeScale"] = "15",
    ["groundEffectDist"] = "40",
    ["ResampleAlwaysSharpen"] = "1",
    ["cameraDistanceMaxZoomFactor"] = "2.6",
    ["CameraReduceUnexpectedMovement"] = "1",
}

local PIXEL_PERFECT_SCALE_BY_HEIGHT = {
    [900] = 768 / 900,
    [1024] = 768 / 1024,
    [1080] = 768 / 1080,
    [1200] = 768 / 1200,
    [1440] = 768 / 1440,
    [1600] = 768 / 1600,
    [1800] = 768 / 1800,
    [2160] = 768 / 2160,
}

local STANDARD_RESOLUTIONS = {
    { 1920, 1080 },
    { 2560, 1440 },
    { 3840, 2160 },
    { 1920, 1200 },
    { 2560, 1600 },
    { 3440, 1440 },
    { 2560, 1080 },
    { 1280, 720 },
    { 1680, 1050 },
}

local function GetScaleForHeight(height)
    if not height or height <= 0 then return 1.0 end
    local scale = PIXEL_PERFECT_SCALE_BY_HEIGHT[height] or (768 / height)
    return math.max(0.4, math.min(1.15, scale))
end

local function GetPixelPerfectUIScale()
    local _, physicalHeight = GetPhysicalScreenSize()
    if not physicalHeight or physicalHeight <= 0 then
        return 1.0
    end
    local perfect = PIXEL_PERFECT_SCALE_BY_HEIGHT[physicalHeight] or (768 / physicalHeight)
    return math.max(0.4, math.min(1.15, perfect))
end

function module:ApplyScaleForResolution(width, height)
    local scale = GetScaleForHeight(height)
    self:SetSetting("uiScaleMode", "manual")
    self:SetSetting("uiScale", scale)
    self:ApplyUIScale()
end

local defaults = {
    autoRepair = false,
    repairPriority = "none",
    autoSellJunk = false,
    alwaysAutoLoot = false,
    speedyAutoLoot = false,
    autoConfirmBoP = false,
    fpsBackup = nil,
    uiScaleMode = "manual",
    uiScale = 1.0,
    hidePlayerFrame = false,
}
TavernUI:RegisterModuleDefaults("QoL", defaults, true)

function module:OnInitialize()
    self:RegisterMessage("TavernUI_ProfileChanged", "OnProfileChanged")
    if TavernUI.RegisterModuleOptions then
        self:RegisterOptions()
    end
end

function module:OnEnable()
    self:RegisterEvent("MERCHANT_SHOW", "OnMerchantShow")
    self:RegisterEvent("MERCHANT_CLOSED", "OnMerchantClosed")
    self:RegisterEvent("LOOT_READY", "OnLootReady")
    self:RegisterEvent("LOOT_OPENED", "OnLootReady")
    self:RegisterEvent("LOOT_CLOSED", "OnLootClosed")
    self:RegisterEvent("UI_ERROR_MESSAGE", "OnLootErrorMessage")
    self:SetupBoPConfirm()
    self:ApplyLootSettings()
    self:ApplyFrameHider()
    self:ApplyUIScale()
end

function module:OnDisable()
    self:UnregisterAllEvents()
    self.saleTotal = nil
    self:CancelLootTicker()
    if self.bopFrame then
        self.bopFrame:UnregisterEvent("LOOT_BIND_CONFIRM")
        self.bopFrame:SetScript("OnEvent", nil)
    end
    if PlayerFrame then
        PlayerFrame:Show()
    end
end

function module:OnProfileChanged()
    if self:IsEnabled() then
        self:ApplyLootSettings()
        self:ApplyFrameHider()
    end
end

function module:ApplyFrameHider()
    if not PlayerFrame then return end
    if self:GetSetting("hidePlayerFrame", false) then
        PlayerFrame:Hide()
    else
        PlayerFrame:Show()
    end
end

function module:OnMerchantShow()
    if not CanMerchantRepair() then
        return
    end
    if self:GetSetting("autoRepair", true) then
        self:DoAutoRepair()
    end
    if self:GetSetting("autoSellJunk", true) then
        self:SellJunk()
    end
    self:RegisterEvent("BAG_UPDATE_DELAYED", "OnBagUpdateDelayed")
end

function module:OnMerchantClosed()
    self:UnregisterEvent("BAG_UPDATE_DELAYED")
    self.saleTotal = nil
end

function module:OnBagUpdateDelayed()
    if self.saleTotal then
        self:SellJunk()
    else
        self:UnregisterEvent("BAG_UPDATE_DELAYED")
    end
end

function module:DoAutoRepair()
    local cost = GetRepairAllCost()
    if cost <= 0 then
        return
    end

    local priority = self:GetSetting("repairPriority", "guild_then_player")
    if REPAIR_PRIORITY[priority] == REPAIR_PRIORITY.none then
        return
    end

    local useGuild = false
    if priority == "guild" or priority == "guild_then_player" then
        if self:CanUseGuildRepair(cost) then
            useGuild = true
        elseif priority == "guild" then
            return
        end
    end

    if useGuild or GetMoney() >= cost then
        RepairAllItems(useGuild)
        TavernUI:Print(GetCoinTextureString(cost) .. " " .. (useGuild and "(" .. GUILD .. ")" or ""))
    end
end

function module:CanUseGuildRepair(cost)
    if not IsInGuild() or not CanGuildBankRepair or not CanGuildBankRepair() then
        return false
    end
    local text = GetGuildInfoText and GetGuildInfoText()
    if text and text:find("%[noautorepair%]") then
        return false
    end
    local withdraw = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney()
    if not withdraw then
        return false
    end
    return withdraw < 0 or withdraw >= cost
end

local function getContainerNumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag)
    end
    return GetContainerNumSlots and GetContainerNumSlots(bag)
end

local function getContainerItemID(bag, slot)
    if C_Container and C_Container.GetContainerItemID then
        return C_Container.GetContainerItemID(bag, slot)
    end
    return GetContainerItemID and GetContainerItemID(bag, slot)
end

local function getContainerItemInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        return C_Container.GetContainerItemInfo(bag, slot)
    end
    return nil
end

local function useContainerItem(bag, slot)
    if C_Container and C_Container.UseContainerItem then
        C_Container.UseContainerItem(bag, slot)
    elseif UseContainerItem then
        UseContainerItem(bag, slot)
    end
end

function module:SellJunk()
    self.saleTotal = self.saleTotal or self:GetJunkValue()
    local count = 0

    for bag = BACKPACK_CONTAINER, NUM_BAGS do
        local numSlots = getContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local itemID = getContainerItemID(bag, slot)
                if itemID then
                    local _, _, quality, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemID)
                    if quality == LE_ITEM_QUALITY_POOR and sellPrice and sellPrice > 0 then
                        local info = getContainerItemInfo(bag, slot)
                        local locked = info and info.isLocked
                        if not locked then
                            useContainerItem(bag, slot)
                            count = count + 1
                            if count >= SELL_BATCH_SIZE then
                                break
                            end
                        end
                    end
                end
            end
            if count >= SELL_BATCH_SIZE then
                break
            end
        end
    end

    local remaining = self:GetJunkValue()
    if remaining == 0 or count == 0 then
        if count > 0 and self.saleTotal and self.saleTotal > remaining then
            TavernUI:Print(GetCoinTextureString(self.saleTotal - remaining) .. " from junk")
        end
        self.saleTotal = nil
        self:UnregisterEvent("BAG_UPDATE_DELAYED")
    end
end

function module:GetJunkValue()
    local total = 0
    for bag = BACKPACK_CONTAINER, NUM_BAGS do
        local numSlots = getContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local itemID = getContainerItemID(bag, slot)
                if itemID then
                    local _, _, quality, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemID)
                    if quality == LE_ITEM_QUALITY_POOR and sellPrice and sellPrice > 0 then
                        local info = getContainerItemInfo(bag, slot)
                        if info and not info.isLocked then
                            total = total + (sellPrice * (info.stackCount or 1))
                        end
                    end
                end
            end
        end
    end
    return total
end

function module:ProcessLootItem(itemLink, quantity)
    if not itemLink or not C_Item or not C_Item.GetItemInfo then
        return true
    end
    local _, _, _, _, _, _, _, stackCount, _, _, isCraftingReagent = C_Item.GetItemInfo(itemLink)
    local itemFamily = C_Item.GetItemFamily(itemLink)
    for bagSlot = BACKPACK_CONTAINER, NUM_BAGS do
        local freeSlots, bagFamily = C_Container.GetContainerNumFreeSlots(bagSlot)
        if freeSlots and freeSlots > 0 then
            if bagSlot == 5 then
                if isCraftingReagent then
                    return true
                else
                    return false
                end
            end
            if not bagFamily or bagFamily == 0 or (itemFamily and bit.band(itemFamily, bagFamily) > 0) then
                return true
            end
        end
    end
    return false
end

function module:LootSlot(slot)
    local slotType = GetLootSlotType(slot)
    if slotType == EnumLootSlotTypeNone then
        return true
    end
    local _, _, _, lootLocked, isQuestItem = GetLootSlotInfo(slot)
    if lootLocked then
        return false
    end
    if slotType == EnumLootSlotTypeItem and isQuestItem then
        return false
    end
    local link = GetLootSlotLink(slot)
    local quantity = select(2, GetLootSlotInfo(slot))
    if link and not self:ProcessLootItem(link, quantity) then
        return false
    end
    LootSlot(slot)
    return true
end

function module:CancelLootTicker()
    if self.lootTicker then
        self.lootTicker:Cancel()
        self.lootTicker = nil
    end
end

function module:StartSpeedyLooting(numItems)
    self:CancelLootTicker()
    local slot = numItems
    self.lootTicker = C_Timer.NewTicker(LOOT_TICK_INTERVAL, function()
        if slot >= 1 then
            module:LootSlot(slot)
            slot = slot - 1
        else
            module:CancelLootTicker()
        end
    end, numItems + 1)
end

function module:OnLootReady(autoLoot)
    if not self:GetSetting("speedyAutoLoot", true) then
        return
    end
    if not self.initialAutoLootState then
        self.initialAutoLootState = autoLoot or (not autoLoot and GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE"))
    end
    local numItems = GetNumLootItems()
    if numItems == 0 or self.lastNumLoot == numItems then
        return
    end
    self.lastNumLoot = numItems
    if self.initialAutoLootState then
        self:StartSpeedyLooting(numItems)
    end
end

function module:OnLootClosed()
    self.initialAutoLootState = nil
    self.lastNumLoot = nil
    self:CancelLootTicker()
end

function module:OnLootErrorMessage(_, message)
    if message == ERR_INV_FULL or message == ERR_ITEM_MAX_COUNT then
        self:CancelLootTicker()
    end
end

function module:SetupBoPConfirm()
    if not self.bopFrame then
        self.bopFrame = CreateFrame("Frame", nil, UIParent)
        self.bopFrame:SetScript("OnEvent", function(_, event, slot)
            if event == "LOOT_BIND_CONFIRM" and slot and module:GetSetting("autoConfirmBoP", true) then
                local numGroup = (GetNumGroupMembers and GetNumGroupMembers()) or 0
                if numGroup <= 1 then
                    ConfirmLootSlot(slot)
                end
            end
        end)
    end
    if self:GetSetting("autoConfirmBoP", true) then
        self.bopFrame:RegisterEvent("LOOT_BIND_CONFIRM")
    else
        self.bopFrame:UnregisterEvent("LOOT_BIND_CONFIRM")
    end
end

function module:ApplyLootSettings()
    if self:GetSetting("alwaysAutoLoot", false) then
        C_CVar.SetCVar("autoLootDefault", "1")
    else
        C_CVar.SetCVar("autoLootDefault", "0")
    end
    self:SetupBoPConfirm()
end

function module:BackupCurrentFPSSettings()
    local backup = {}
    for cvar, _ in pairs(QUAZII_FPS_CVARS) do
        local success, current = pcall(C_CVar.GetCVar, cvar)
        if success and current then
            backup[cvar] = current
        end
    end
    self:SetSetting("fpsBackup", backup)
    return true
end

function module:RestorePreviousFPSSettings()
    local L = LibStub("AceLocale-3.0"):GetLocale("TavernUI", true)
    local backup = self:GetSetting("fpsBackup")
    if not backup or type(backup) ~= "table" then
        TavernUI:Print(L["NO_GRAPHICS_BACKUP"] or "No backup found. Apply FPS settings first to create a backup.")
        return false
    end
    local successCount = 0
    for cvar, value in pairs(backup) do
        local ok = pcall(C_CVar.SetCVar, cvar, tostring(value))
        if ok then successCount = successCount + 1 end
    end
    self:SetSetting("fpsBackup", nil)
    TavernUI:Print(string.format(L["RESTORED_N_GRAPHICS_SETTINGS"] or "Restored %d previous settings.", successCount))
    return true
end

function module:ApplyQuaziiFPSSettings()
    local L = LibStub("AceLocale-3.0"):GetLocale("TavernUI", true)
    self:BackupCurrentFPSSettings()
    local successCount = 0
    local failCount = 0
    for cvar, value in pairs(QUAZII_FPS_CVARS) do
        local success = pcall(function()
            C_CVar.SetCVar(cvar, value)
        end)
        if success then
            successCount = successCount + 1
        else
            failCount = failCount + 1
        end
    end
    TavernUI:Print(L["PREVIOUS_SETTINGS_BACKED_UP"] or "Previous settings backed up. Applied FPS settings. Use Restore to revert.")
    if failCount > 0 then
        TavernUI:Print(string.format(L["N_SETTINGS_COULD_NOT_BE_APPLIED"] or "%d settings could not be applied (may require restart).", failCount))
    end
end

function module:CheckCVarsMatch()
    local matchCount, totalCount = 0, 0
    for cvar, expectedVal in pairs(QUAZII_FPS_CVARS) do
        totalCount = totalCount + 1
        local currentVal = C_CVar.GetCVar(cvar)
        if currentVal == expectedVal then
            matchCount = matchCount + 1
        end
    end
    return matchCount == totalCount, matchCount, totalCount
end

function module:ApplyUIScale()
    local mode = self:GetSetting("uiScaleMode", "manual")
    local scale
    if mode == "pixelperfect" then
        scale = GetPixelPerfectUIScale()
    else
        scale = self:GetSetting("uiScale", 1.0)
    end
    scale = math.max(0.4, math.min(1.15, scale))
    pcall(C_CVar.SetCVar, "useUiScale", "0")
    if UIParent then
        UIParent:SetScale(scale)
    end
end

local REPAIR_PRIORITY_ORDER = { "none", "guild_then_player", "guild", "player" }

function module:RegisterOptions()
    local L = LibStub("AceLocale-3.0"):GetLocale("TavernUI", true)
    local priorityValues = {
        [1] = L["DISABLED"],
        [2] = L["GUILD_THEN_PLAYER"],
        [3] = L["GUILD_ONLY"],
        [4] = L["PLAYER_ONLY"],
    }
    local options = {
        type = "group",
        name = L["QOL"],
        args = {
            repair = {
                type = "group",
                name = L["AUTO_REPAIR"],
                order = 10,
                args = {
                    autoRepair = {
                        type = "toggle",
                        name = L["ENABLE"],
                        desc = L["AUTO_REPAIR_DESC"],
                        order = 1,
                        get = function() return self:GetSetting("autoRepair", true) end,
                        set = function(_, v) self:SetSetting("autoRepair", v) end,
                    },
                    repairPriority = {
                        type = "select",
                        name = L["REPAIR_WITH"],
                        desc = L["REPAIR_WITH_DESC"],
                        order = 2,
                        values = priorityValues,
                        get = function()
                            local val = self:GetSetting("repairPriority", "guild_then_player")
                            for i, key in ipairs(REPAIR_PRIORITY_ORDER) do
                                if key == val then return i end
                            end
                            return 2
                        end,
                        set = function(_, v)
                            self:SetSetting("repairPriority", REPAIR_PRIORITY_ORDER[v] or "guild_then_player")
                        end,
                        disabled = function() return not self:GetSetting("autoRepair", true) end,
                    },
                },
            },
            sell = {
                type = "group",
                name = L["AUTO_SELL_JUNK"],
                order = 20,
                args = {
                    autoSellJunk = {
                        type = "toggle",
                        name = L["ENABLE"],
                        desc = L["AUTO_SELL_JUNK_DESC"],
                        order = 1,
                        get = function() return self:GetSetting("autoSellJunk", true) end,
                        set = function(_, v) self:SetSetting("autoSellJunk", v) end,
                    },
                },
            },
            frameHider = {
                type = "group",
                name = L["FRAME_HIDER"],
                order = 35,
                args = {
                    hidePlayerFrame = {
                        type = "toggle",
                        name = L["HIDE_PLAYER_FRAME"],
                        desc = L["HIDE_PLAYER_FRAME_DESC"],
                        order = 1,
                        get = function() return self:GetSetting("hidePlayerFrame", false) end,
                        set = function(_, v)
                            self:SetSetting("hidePlayerFrame", v)
                            self:ApplyFrameHider()
                        end,
                    },
                },
            },
            loot = {
                type = "group",
                name = L["LOOT"],
                order = 30,
                args = {
                    speedyAutoLoot = {
                        type = "toggle",
                        name = L["SPEEDY_AUTO_LOOT"],
                        desc = L["SPEEDY_AUTO_LOOT_DESC"],
                        order = 1,
                        get = function() return self:GetSetting("speedyAutoLoot", true) end,
                        set = function(_, v) self:SetSetting("speedyAutoLoot", v) end,
                    },
                    alwaysAutoLoot = {
                        type = "toggle",
                        name = L["ALWAYS_AUTO_LOOT"],
                        desc = L["ALWAYS_AUTO_LOOT_DESC"],
                        order = 2,
                        get = function() return self:GetSetting("alwaysAutoLoot", false) end,
                        set = function(_, v)
                            self:SetSetting("alwaysAutoLoot", v)
                            self:ApplyLootSettings()
                        end,
                    },
                    autoConfirmBoP = {
                        type = "toggle",
                        name = L["AUTO_CONFIRM_BOP"],
                        desc = L["AUTO_CONFIRM_BOP_DESC"],
                        order = 3,
                        get = function() return self:GetSetting("autoConfirmBoP", true) end,
                        set = function(_, v)
                            self:SetSetting("autoConfirmBoP", v)
                            self:ApplyLootSettings()
                        end,
                    },
                },
            },
            graphics = {
                type = "group",
                name = L["GRAPHICS_SETTINGS"],
                order = 40,
                args = {
                    graphicsDesc = {
                        type = "description",
                        name = L["GRAPHICS_SETTINGS_DESC"],
                        order = 1,
                    },
                    applyFps = {
                        type = "execute",
                        name = L["APPLY_FPS_SETTINGS"],
                        order = 2,
                        func = function()
                            self:ApplyQuaziiFPSSettings()
                        end,
                    },
                    restoreFps = {
                        type = "execute",
                        name = L["RESTORE_PREVIOUS_SETTINGS"],
                        order = 3,
                        func = function()
                            if self:RestorePreviousFPSSettings() then
                            end
                        end,
                        disabled = function()
                            local backup = self:GetSetting("fpsBackup")
                            return not backup or type(backup) ~= "table" or next(backup) == nil
                        end,
                    },
                    graphicsStatus = {
                        type = "description",
                        name = function()
                            local _, matched, total = self:CheckCVarsMatch()
                            if total and total > 0 and matched >= 50 then
                                return L["GRAPHICS_ALL_APPLIED"]
                            elseif total and total > 0 then
                                return string.format(L["GRAPHICS_N_MATCH"], matched, total)
                            end
                            return ""
                        end,
                        order = 4,
                    },
                },
            },
            uiScale = {
                type = "group",
                name = L["UI_SCALE"],
                order = 50,
                args = {
                    uiScaleMode = {
                        type = "select",
                        name = L["SCALE_MODE"],
                        desc = L["SCALE_MODE_DESC"],
                        order = 1,
                        values = {
                            manual = L["MANUAL"],
                            pixelperfect = L["PIXEL_PERFECT"],
                        },
                        get = function() return self:GetSetting("uiScaleMode", "manual") end,
                        set = function(_, v)
                            self:SetSetting("uiScaleMode", v)
                            self:ApplyUIScale()
                        end,
                    },
                    uiScale = {
                        type = "range",
                        name = L["SCALE"],
                        desc = L["GLOBAL_UI_SCALE_DESC"],
                        order = 2,
                        min = 0.4,
                        max = 1.15,
                        step = 0.01,
                        bigStep = 0.05,
                        get = function() return self:GetSetting("uiScale", 1.0) end,
                        set = function(_, v)
                            self:SetSetting("uiScale", v)
                            self:ApplyUIScale()
                        end,
                        disabled = function() return self:GetSetting("uiScaleMode", "manual") ~= "manual" end,
                    },
                    uiScaleInfo = {
                        type = "description",
                        name = function()
                            local w, h = GetScreenWidth(), GetScreenHeight()
                            local physW, physH = GetPhysicalScreenSize()
                            local uiScale = UIParent and UIParent.GetScale and UIParent:GetScale() or 1
                            local parts = { string.format(L["RESOLUTION_NxN"], w, h) }
                            if physW and physH then
                                table.insert(parts, string.format(L["PHYSICAL_NxN"], physW, physH))
                            end
                            local scaleStr = ("%.4f"):format(uiScale):gsub("0+$", ""):gsub("%.$", "")
                            table.insert(parts, string.format(L["UI_SCALE_S"], scaleStr))
                            return table.concat(parts, "\n")
                        end,
                        order = 3,
                        fontSize = "medium",
                    },
                    uiScalePresetsHeader = {
                        type = "description",
                        name = L["APPLY_SCALE_FOR_STANDARD"],
                        order = 4,
                        fontSize = "medium",
                    },
                },
            },
        },
    }
    for i, res in ipairs(STANDARD_RESOLUTIONS) do
        local w, h = res[1], res[2]
        options.args.uiScale.args["uiScaleApply_" .. w .. "_" .. h] = {
            type = "execute",
            name = string.format("%d×%d", w, h),
            desc = string.format(L["APPLY_PIXEL_PERFECT_NxN"], w, h),
            order = 10 + i,
            func = function()
                self:ApplyScaleForResolution(w, h)
            end,
        }
    end
    TavernUI:RegisterModuleOptions("QoL", options, "QoL")
end
