local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local floor = math.floor
local format = string.format

local NUM_BAGS = NUM_BAG_SLOTS + 1

local function ColorGradient(percent)
    if percent <= 0 then return 0.1, 1, 0.1 end
    if percent >= 1 then return 1, 0.1, 0.1 end
    if percent < 0.5 then
        return 0.1 + 1.8 * percent, 1, 0.1
    else
        return 1, 1 - 1.8 * (percent - 0.5), 0.1
    end
end

local bagData = {}

local function GetBagTotals()
    local totalSlots, usedSlots = 0, 0
    wipe(bagData)

    for i = 0, NUM_BAGS do
        local numSlots = C_Container.GetContainerNumSlots(i)
        if numSlots and numSlots > 0 then
            local freeSlots, bagType = C_Container.GetContainerNumFreeSlots(i)
            if not bagType or bagType == 0 then
                totalSlots = totalSlots + numSlots
                usedSlots = usedSlots + (numSlots - freeSlots)
                bagData[i] = {
                    free = freeSlots,
                    total = numSlots,
                    used = numSlots - freeSlots,
                }
            end
        end
    end

    return usedSlots, totalSlots
end

DataBar:RegisterDatatext("Bags", {
    label = "Bags",
    labelShort = "",
    events = { "BAG_UPDATE" },
    update = function()
        local used, total = GetBagTotals()
        return format("%d/%d", used, total)
    end,
    getColor = function()
        local used, total = GetBagTotals()
        if total == 0 then return nil end
        local r, g, b = ColorGradient(used / total)
        return r, g, b
    end,
    tooltip = function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Bags", 1, 1, 1)
        GameTooltip:AddLine(" ")

        local iconString = "|T%s:14:14:0:0:64:64:4:60:4:60|t  %s"

        for i = 0, NUM_BAGS do
            local bagName = C_Container.GetBagName(i)
            if bagName and bagData[i] then
                local data = bagData[i]
                local percent = data.total > 0 and (data.used / data.total) or 0
                local r2, g2, b2 = ColorGradient(percent)

                if i > 0 then
                    local invID = C_Container.ContainerIDToInventoryID(i)
                    local icon = GetInventoryItemTexture("player", invID)
                    local quality = GetInventoryItemQuality("player", invID) or 1
                    local r1, g1, b1 = GetItemQualityColor(quality)

                    GameTooltip:AddDoubleLine(
                        format(iconString, icon or "", bagName),
                        format("%d / %d", data.used, data.total),
                        r1, g1, b1, r2, g2, b2
                    )
                else
                    GameTooltip:AddDoubleLine(
                        bagName,
                        format("%d / %d", data.used, data.total),
                        1, 1, 1, r2, g2, b2
                    )
                end
            end
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-Click: Toggle Bags", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end,
    onClick = function(_, button)
        if button == "LeftButton" then
            ToggleAllBags()
        end
    end,
})
