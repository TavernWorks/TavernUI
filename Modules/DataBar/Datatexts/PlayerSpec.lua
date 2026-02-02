local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local format = string.format
local iconString = "|T%s:14:14:0:0:64:64:4:60:4:60|t"

-- TalentLoadoutManager integration (lazy — TLM may load after TavernUI)
local activeLoadoutID = nil

local function GetTLM()
    local TLM = TalentLoadoutManagerAPI
    if TLM and TLM.GlobalAPI and TLM.CharacterAPI then
        return TLM
    end
    return nil
end

local function GetActiveLoadoutInfo()
    local TLM = GetTLM()
    if TLM then
        local info = TLM.CharacterAPI:GetActiveLoadoutInfo()
        if info then
            activeLoadoutID = info.id
            return info
        end
    end
    return nil
end

local function GetAllLoadouts(specID)
    local TLM = GetTLM()
    if TLM then
        return TLM.GlobalAPI:GetLoadouts(specID) or {}
    end
    local loadouts = {}
    local builds = C_ClassTalents.GetConfigIDsBySpecID(specID)
    if builds then
        for _, configID in ipairs(builds) do
            local configInfo = C_Traits.GetConfigInfo(configID)
            if configInfo and configInfo.name then
                table.insert(loadouts, {
                    id = configID,
                    name = configInfo.name,
                    displayName = configInfo.name,
                    isBlizzardLoadout = true,
                })
            end
        end
    end
    return loadouts
end

local function LoadLoadout(loadoutID)
    local TLM = GetTLM()
    if TLM then
        TLM.CharacterAPI:LoadLoadout(loadoutID, true)
    else
        if not _G.PlayerSpellsFrame then
            if _G.PlayerSpellsFrame_LoadUI then
                _G.PlayerSpellsFrame_LoadUI()
            else
                return
            end
        end
        local targetID = loadoutID
        if _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.TalentsFrame then
            _G.PlayerSpellsFrame.TalentsFrame:LoadConfigByPredicate(function(_, cID)
                return cID == targetID
            end)
        end
    end
    C_Timer.After(0.2, function()
        DataBar:RefreshDatatext("Player Spec")
    end)
end

local function GetLoadoutName(specID)
    if not PlayerUtil.CanUseClassTalents() then return nil end

    if C_ClassTalents.GetHasStarterBuild() and C_ClassTalents.GetStarterBuildActive() then
        activeLoadoutID = nil
        return "Starter Build"
    end

    local activeInfo = GetActiveLoadoutInfo()
    if activeInfo then
        return activeInfo.displayName or activeInfo.name
    end

    local configID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
    if configID then
        activeLoadoutID = configID
        local configInfo = C_Traits.GetConfigInfo(configID)
        if configInfo and configInfo.name then
            return configInfo.name
        end
    end

    return nil
end

DataBar:RegisterDatatext("Player Spec", {
    labelShort = "Spec",
    events = {
        "PLAYER_TALENT_UPDATE",
        "ACTIVE_TALENT_GROUP_CHANGED",
        "PLAYER_LOOT_SPEC_UPDATED",
        "TRAIT_CONFIG_UPDATED",
        "TRAIT_CONFIG_LIST_UPDATED",
    },
    eventDelay = 0.2,
    init = function()
        local TLM = GetTLM()
        if not TLM or not TLM.RegisterCallback or not TLM.Event then return end
        local callbackOwner = {}
        local function OnLoadoutChanged()
            C_Timer.After(0.1, function()
                DataBar:RefreshDatatext("Player Spec")
            end)
        end
        TLM:RegisterCallback(TLM.Event.LoadoutListUpdated, OnLoadoutChanged, callbackOwner)
        TLM:RegisterCallback(TLM.Event.LoadoutUpdated, OnLoadoutChanged, callbackOwner)
        TLM:RegisterCallback(TLM.Event.CustomLoadoutApplied, OnLoadoutChanged, callbackOwner)
    end,
    options = {
        displayMode = {
            type = "select",
            name = "Display Mode",
            desc = "What to show on the bar",
            values = { icon = "Icon Only", loadout = "Icon + Loadout", full = "Icon + Spec / Loadout" },
            default = "full",
        },
    },
    update = function(slot)
        local specIndex = GetSpecialization()
        if not specIndex then return "No Spec" end

        local specID, specName, _, icon = GetSpecializationInfo(specIndex)
        if not specID or specID == 0 or not icon or not specName then return "?" end

        local iconText = format(iconString, icon)
        local loadoutName = GetLoadoutName(specID)
        local displayMode = slot and slot.displayMode or "full"

        if displayMode == "icon" then
            return iconText
        elseif displayMode == "loadout" then
            if loadoutName then
                return iconText .. " " .. loadoutName
            end
            return iconText
        else
            if loadoutName then
                return iconText .. " " .. specName .. " / " .. loadoutName
            end
            return iconText .. " " .. specName
        end
    end,
    tooltip = function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Talent Specialization", 1, 1, 1)
        GameTooltip:AddLine(" ")

        local currentSpec = GetSpecialization()
        local numSpecs = GetNumSpecializations() or 0

        GameTooltip:AddLine("Specializations", 0.7, 0.7, 0.7)
        for i = 1, numSpecs do
            local specID, specName, _, icon = GetSpecializationInfo(i)
            if specName then
                local iconText = format(iconString, icon)
                local status = (i == currentSpec) and " |cff00ff00(Active)|r" or ""
                GameTooltip:AddLine(iconText .. " " .. specName .. status, 1, 1, 1)
            end
        end

        if currentSpec and PlayerUtil.CanUseClassTalents() then
            local specID = GetSpecializationInfo(currentSpec)
            if specID then
                local loadouts = GetAllLoadouts(specID)
                if #loadouts > 0 or C_ClassTalents.GetHasStarterBuild() then
                    GameTooltip:AddLine(" ")
                    local headerText = GetTLM() and "Loadouts (TLM)" or "Loadouts"
                    GameTooltip:AddLine(headerText, 0.7, 0.7, 0.7)

                    if C_ClassTalents.GetHasStarterBuild() then
                        local isActive = C_ClassTalents.GetStarterBuildActive()
                        local status = isActive and " |cff00ff00(Active)|r" or ""
                        GameTooltip:AddLine("|cff0070DDStarter Build|r" .. status, 1, 1, 1)
                    end

                    for _, loadout in ipairs(loadouts) do
                        local isActive = (loadout.id == activeLoadoutID)
                        local status = isActive and " |cff00ff00(Active)|r" or ""
                        local name = loadout.displayName or loadout.name or "Unknown"
                        if loadout.isBlizzardLoadout == false then
                            name = "|cff00ff00[TLM]|r " .. name
                        end
                        GameTooltip:AddLine(name .. status, 1, 1, 1)
                    end
                end
            end
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Loot Specialization", 0.7, 0.7, 0.7)
        local lootSpec = GetLootSpecialization()
        if lootSpec == 0 then
            local _, specName = GetSpecializationInfo(currentSpec)
            GameTooltip:AddLine(format("%s (Auto)", specName or "Current Spec"), 1, 1, 1)
        else
            for i = 1, numSpecs do
                local specID, specName = GetSpecializationInfo(i)
                if specID == lootSpec then
                    GameTooltip:AddLine(specName, 1, 1, 1)
                    break
                end
            end
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-Click: Change Spec", 0.5, 0.5, 0.5)
        GameTooltip:AddLine("Shift+Left-Click: Open Talents", 0.5, 0.5, 0.5)
        GameTooltip:AddLine("Ctrl+Left-Click: Change Loadout", 0.5, 0.5, 0.5)
        GameTooltip:AddLine("Right-Click: Change Loot Spec", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end,
    onClick = function(frame, button)
        local specIndex = GetSpecialization()
        if not specIndex then return end

        if button == "LeftButton" then
            if IsShiftKeyDown() then
                if not InCombatLockdown() then
                    TogglePlayerSpellsFrame()
                end
            elseif IsControlKeyDown() then
                local specID = GetSpecializationInfo(specIndex)
                if not specID or not PlayerUtil.CanUseClassTalents() then return end

                MenuUtil.CreateContextMenu(frame, function(_, root)
                    local titleText = GetTLM() and "Switch Loadout (TLM)" or "Switch Loadout"
                    root:CreateTitle(titleText)

                    if C_ClassTalents.GetHasStarterBuild() then
                        local isActive = C_ClassTalents.GetStarterBuildActive()
                        root:CreateButton("|cff0070DDStarter Build|r" .. (isActive and " |cff00ff00*|r" or ""), function()
                            if InCombatLockdown() then return end
                            if not _G.PlayerSpellsFrame then
                                if _G.PlayerSpellsFrame_LoadUI then
                                    _G.PlayerSpellsFrame_LoadUI()
                                else
                                    return
                                end
                            end
                            local starterID = Constants.TraitConsts.STARTER_BUILD_TRAIT_CONFIG_ID
                            if _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.TalentsFrame then
                                _G.PlayerSpellsFrame.TalentsFrame:LoadConfigByPredicate(function(_, configID)
                                    return configID == starterID
                                end)
                            end
                        end)
                    end

                    local loadouts = GetAllLoadouts(specID)
                    for _, loadout in ipairs(loadouts) do
                        local isActive = (loadout.id == activeLoadoutID)
                        local name = loadout.displayName or loadout.name or "Unknown"
                        if loadout.isBlizzardLoadout == false then
                            name = "|cff00ff00[TLM]|r " .. name
                        end
                        local loadoutID = loadout.id
                        root:CreateButton(name .. (isActive and " |cff00ff00*|r" or ""), function()
                            if InCombatLockdown() then return end
                            LoadLoadout(loadoutID)
                        end)
                    end
                end)
            else
                local numSpecs = GetNumSpecializations() or 0
                MenuUtil.CreateContextMenu(frame, function(_, root)
                    root:CreateTitle("Switch Specialization")
                    for i = 1, numSpecs do
                        local specID, specName, _, icon = GetSpecializationInfo(i)
                        if specName then
                            local iconText = format(iconString, icon)
                            local isActive = (i == specIndex)
                            root:CreateButton(iconText .. " " .. specName .. (isActive and " |cff00ff00*|r" or ""), function()
                                if InCombatLockdown() then
                                    print("|cffFF6B6BTavernUI:|r Cannot change specialization in combat")
                                    return
                                end
                                C_SpecializationInfo.SetSpecialization(i)
                            end)
                        end
                    end
                end)
            end
        elseif button == "RightButton" then
            local numSpecs = GetNumSpecializations() or 0
            local currentLoot = GetLootSpecialization()

            MenuUtil.CreateContextMenu(frame, function(_, root)
                root:CreateTitle("Loot Specialization")

                local _, currentSpecName = GetSpecializationInfo(specIndex)
                local isAuto = (currentLoot == 0)
                root:CreateButton(format("%s (Auto)", currentSpecName or "Current") .. (isAuto and " |cff00ff00*|r" or ""), function()
                    SetLootSpecialization(0)
                end)

                root:CreateDivider()

                for i = 1, numSpecs do
                    local specID, specName, _, icon = GetSpecializationInfo(i)
                    if specID then
                        local iconText = format(iconString, icon)
                        local isActive = (specID == currentLoot)
                        root:CreateButton(iconText .. " " .. specName .. (isActive and " |cff00ff00*|r" or ""), function()
                            SetLootSpecialization(specID)
                        end)
                    end
                end
            end)
        end
    end,
})

