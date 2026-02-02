local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local floor = math.floor
local format = string.format

local iconString = "|T%s:14:14:0:0:64:64:4:60:4:60|t"
local goldIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:0:0|t"

local function AbbrevNumber(n)
    if n >= 1000000 then
        return format("%.1fM", n / 1000000)
    elseif n >= 10000 then
        return format("%.1fK", n / 1000)
    end
    return tostring(n)
end

DataBar:RegisterDatatext("Currencies", {
    labelShort = "Curr",
    events = { "CURRENCY_DISPLAY_UPDATE" },
    update = function()
        local parts = {}
        for i = 1, 3 do
            local info = C_CurrencyInfo.GetBackpackCurrencyInfo(i)
            if info and info.quantity then
                local icon = format(iconString, info.iconFileID)
                parts[#parts + 1] = icon .. " " .. AbbrevNumber(info.quantity)
            end
        end
        if #parts > 0 then
            return table.concat(parts, " ")
        end
        return "No Currencies"
    end,
    tooltip = function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Currencies", 1, 1, 1)
        GameTooltip:AddLine(" ")

        local money = GetMoney() or 0
        local gold = floor(money / 10000)
        local silver = floor((money % 10000) / 100)
        local copper = money % 100
        GameTooltip:AddDoubleLine(goldIcon .. " Gold", format("%dg %ds %dc", gold, silver, copper), 1, 0.82, 0, 1, 1, 1)

        local hasAny = false
        for i = 1, 3 do
            local info = C_CurrencyInfo.GetBackpackCurrencyInfo(i)
            if info and info.name then
                hasAny = true
                local icon = format(iconString, info.iconFileID)
                local quantityText = tostring(info.quantity)
                if info.maxQuantity and info.maxQuantity > 0 then
                    quantityText = format("%d / %d", info.quantity, info.maxQuantity)
                end
                GameTooltip:AddDoubleLine(icon .. " " .. info.name, quantityText, 1, 1, 1, 1, 1, 1)
            end
        end

        if not hasAny then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("No currencies tracked", 0.7, 0.7, 0.7)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-Click: Open Currency Panel", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end,
    onClick = function(_, button)
        if button == "LeftButton" then
            ToggleCharacter("TokenFrame")
        end
    end,
})
