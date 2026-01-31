local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local floor = math.floor

local SLOT_NAMES = {
    [1] = HEADSLOT, [2] = NECKSLOT, [3] = SHOULDERSLOT,
    [5] = CHESTSLOT, [6] = WAISTSLOT, [7] = LEGSSLOT,
    [8] = FEETSLOT, [9] = WRISTSLOT, [10] = HANDSSLOT,
    [16] = MAINHANDSLOT, [17] = SECONDARYHANDSLOT,
}

local function GetDurabilityPercent()
    local total, broken = 0, 0
    for i = 1, 19 do
        local current, maximum = GetInventoryItemDurability(i)
        if current and maximum then
            total = total + maximum
            broken = broken + (maximum - current)
        end
    end
    if total == 0 then return 100 end
    return floor(((total - broken) / total) * 100)
end

DataBar:RegisterDatatext("Durability", {
    label = "Gear",
    labelShort = "D",
    events = { "UPDATE_INVENTORY_DURABILITY" },
    update = function()
        return GetDurabilityPercent() .. "%"
    end,
    tooltip = function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Durability", 1, 1, 1)
        GameTooltip:AddLine(" ")
        for slot, name in pairs(SLOT_NAMES) do
            local current, maximum = GetInventoryItemDurability(slot)
            if current and maximum then
                local pct = floor((current / maximum) * 100)
                local r, g = 1, 1
                if pct <= 25 then
                    r, g = 1, 0
                elseif pct <= 50 then
                    r, g = 1, 1
                else
                    r, g = 0, 1
                end
                GameTooltip:AddDoubleLine(name, pct .. "%", 1, 1, 1, r, g, 0)
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-Click: Open Character", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end,
    onClick = function(_, button)
        if button == "LeftButton" then
            ToggleCharacter("PaperDollFrame")
        end
    end,
    getColor = function()
        local pct = GetDurabilityPercent()
        if pct <= 25 then
            return 1, 0, 0
        elseif pct <= 50 then
            return 1, 1, 0
        end
        return 0, 1, 0
    end,
})
