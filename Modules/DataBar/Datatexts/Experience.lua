local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local floor = math.floor

DataBar:RegisterDatatext("Experience", {
    label = "XP",
    labelShort = "XP",
    events = { "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION" },
    update = function()
        if UnitLevel("player") >= GetMaxLevelForLatestExpansion() then
            return "Max Level"
        end
        local current, max = UnitXP("player"), UnitXPMax("player")
        local pct = max > 0 and floor((current / max) * 100) or 0
        return pct .. "%"
    end,
    tooltip = function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Experience", 1, 1, 1)
        GameTooltip:AddLine(" ")
        if UnitLevel("player") >= GetMaxLevelForLatestExpansion() then
            GameTooltip:AddLine("Maximum level reached!", 0.5, 1, 0.5)
            GameTooltip:Show()
            return
        end
        local current, max = UnitXP("player"), UnitXPMax("player")
        local remaining = max - current
        GameTooltip:AddDoubleLine("Current XP:", DataBar:FormatNumber(current) .. " / " .. DataBar:FormatNumber(max), 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:AddDoubleLine("Remaining:", DataBar:FormatNumber(remaining) .. " to level " .. (UnitLevel("player") + 1), 0.7, 0.7, 0.7, 1, 1, 1)

        local rested = GetXPExhaustion()
        if rested and rested > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Rested XP:", DataBar:FormatNumber(rested), 0.2, 0.6, 1, 0.2, 0.6, 1)
            local restedPercent = max > 0 and floor((rested / max) * 100 + 0.5) or 0
            GameTooltip:AddDoubleLine("Rested Bonus:", restedPercent .. "% of level", 0.2, 0.6, 1, 0.2, 0.6, 1)
        end

        local exhaustionStateID, exhaustionStateName = GetRestState()
        if exhaustionStateName then
            GameTooltip:AddLine(" ")
            if exhaustionStateID == 1 then
                GameTooltip:AddLine("Rested (150% XP from kills)", 0.2, 0.6, 1)
            else
                GameTooltip:AddLine("Normal XP rate", 0.7, 0.7, 0.7)
            end
        end

        GameTooltip:Show()
    end,
})
