local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local format = string.format
local iconString = "|T%s:14:14:0:0:64:64:4:60:4:60|t"

DataBar:RegisterDatatext("Loot Spec", {
    labelShort = "Loot",
    events = { "PLAYER_LOOT_SPEC_UPDATED", "ACTIVE_TALENT_GROUP_CHANGED" },
    update = function()
        local currentSpec = GetSpecialization()
        if not currentSpec then return "?" end

        local lootSpec = GetLootSpecialization()
        if lootSpec == 0 then
            local specID, specName, _, icon = GetSpecializationInfo(currentSpec)
            if specName and icon then
                return format("%s %s (Auto)", format(iconString, icon), specName)
            end
            return "Auto"
        end

        local numSpecs = GetNumSpecializations() or 0
        for i = 1, numSpecs do
            local specID, specName, _, icon = GetSpecializationInfo(i)
            if specID == lootSpec and specName and icon then
                return format("%s %s", format(iconString, icon), specName)
            end
        end
        return "?"
    end,
    tooltip = function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Loot Specialization", 1, 1, 1)
        GameTooltip:AddLine(" ")

        local currentSpec = GetSpecialization()
        local numSpecs = GetNumSpecializations() or 0
        local lootSpec = GetLootSpecialization()

        if lootSpec == 0 then
            local _, specName = GetSpecializationInfo(currentSpec)
            GameTooltip:AddLine(format("Current: %s (Auto)", specName or "?"), 1, 1, 1)
        else
            for i = 1, numSpecs do
                local specID, specName, _, icon = GetSpecializationInfo(i)
                if specID == lootSpec and specName then
                    GameTooltip:AddLine(format("Current: %s %s", format(iconString, icon), specName), 1, 1, 1)
                    break
                end
            end
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Available:", 0.7, 0.7, 0.7)

        local _, currentSpecName = GetSpecializationInfo(currentSpec)
        local isAuto = (lootSpec == 0)
        GameTooltip:AddLine(format("  %s (Auto)%s", currentSpecName or "Current", isAuto and " |cff00ff00(Active)|r" or ""), 1, 1, 1)

        for i = 1, numSpecs do
            local specID, specName, _, icon = GetSpecializationInfo(i)
            if specID then
                local iconText = format(iconString, icon)
                local isActive = (specID == lootSpec)
                GameTooltip:AddLine(format("  %s %s%s", iconText, specName, isActive and " |cff00ff00(Active)|r" or ""), 1, 1, 1)
            end
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-Click: Change Loot Spec", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end,
    onClick = function(frame, button)
        if button == "LeftButton" then
            local specIndex = GetSpecialization()
            if not specIndex then return end

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
