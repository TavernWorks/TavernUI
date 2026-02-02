local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local floor = math.floor
local format = string.format

local function FormatGold(money)
    local gold = floor(money / 10000)
    local silver = floor((money % 10000) / 100)
    local copper = money % 100
    return format("%dg %ds %dc", gold, silver, copper)
end

local function FormatGoldDisplay(copper)
    local gold = floor(copper / 10000)
    if gold >= 1000000 then
        local millions = floor(gold / 1000000)
        local thousands = floor((gold % 1000000) / 1000)
        return format("%d,%03d,%03dg", millions, thousands, gold % 1000)
    elseif gold >= 1000 then
        return format("%d,%03dg", floor(gold / 1000), gold % 1000)
    end
    return gold .. "g"
end

local function GetCharKey()
    return UnitName("player") .. " - " .. GetRealmName()
end

local function SaveCharacterGold()
    if not TavernUI.db or not TavernUI.db.global then return end
    if not TavernUI.db.global.goldData then
        TavernUI.db.global.goldData = {}
    end
    local key = GetCharKey()
    TavernUI.db.global.goldData[key] = {
        money = GetMoney(),
        class = select(2, UnitClass("player")),
    }
end

local function BuildGoldManageMenu(frame)
    if not TavernUI.db or not TavernUI.db.global or not TavernUI.db.global.goldData then return end

    local currentKey = GetCharKey()

    MenuUtil.CreateContextMenu(frame, function(_, root)
        root:CreateTitle("Manage Gold Data")

        local hasChars = false
        local charList = {}
        for charKey, charData in pairs(TavernUI.db.global.goldData) do
            charList[#charList + 1] = {
                key = charKey,
                money = charData.money or 0,
                class = charData.class,
            }
        end
        table.sort(charList, function(a, b) return a.money > b.money end)

        for _, char in ipairs(charList) do
            hasChars = true
            local r, g, b = 1, 1, 1
            if char.class then
                local classColor = C_ClassColor.GetClassColor(char.class)
                if classColor then r, g, b = classColor.r, classColor.g, classColor.b end
            end
            local colorCode = format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
            local deleteKey = char.key
            local btn = root:CreateButton(colorCode .. char.key .. "|r - " .. FormatGoldDisplay(char.money), function()
                StaticPopupDialogs["TAVERNUI_GOLD_DELETE_CHAR"] = {
                    text = "Delete gold data for " .. deleteKey .. "?",
                    button1 = "Delete",
                    button2 = "Cancel",
                    OnAccept = function()
                        TavernUI.db.global.goldData[deleteKey] = nil
                        print("|cff00ccff[TavernUI]|r Removed gold data for " .. deleteKey)
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                }
                StaticPopup_Show("TAVERNUI_GOLD_DELETE_CHAR")
            end)
            if char.key == currentKey then
                btn:SetEnabled(false)
            end
        end

        if hasChars then
            root:CreateDivider()
            root:CreateButton("|cffFF6666Reset All (Keep Current)|r", function()
                StaticPopupDialogs["TAVERNUI_GOLD_RESET_ALL"] = {
                    text = "Delete gold data for ALL characters except current?",
                    button1 = "Reset All",
                    button2 = "Cancel",
                    OnAccept = function()
                        local keepKey = currentKey
                        local keepData = TavernUI.db.global.goldData[keepKey]
                        TavernUI.db.global.goldData = {}
                        if keepKey and keepData then
                            TavernUI.db.global.goldData[keepKey] = keepData
                        end
                        print("|cff00ccff[TavernUI]|r Reset gold data (kept current character)")
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                }
                StaticPopup_Show("TAVERNUI_GOLD_RESET_ALL")
            end)
        end
    end)
end

DataBar:RegisterDatatext("Gold", {
    label = "Gold",
    labelShort = "G",
    events = { "PLAYER_MONEY" },
    update = function()
        SaveCharacterGold()
        return FormatGoldDisplay(GetMoney())
    end,
    tooltip = function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Gold", 1, 1, 1)
        GameTooltip:AddLine(" ")

        local money = GetMoney() or 0
        GameTooltip:AddDoubleLine("Current:", FormatGold(money), 0.8, 0.8, 0.8, 1, 1, 1)

        if TavernUI.db and TavernUI.db.global and TavernUI.db.global.goldData then
            local charList = {}
            local total = 0
            local currentKey = GetCharKey()
            for charKey, charData in pairs(TavernUI.db.global.goldData) do
                local charMoney = charData.money or 0
                total = total + charMoney
                charList[#charList + 1] = {
                    key = charKey,
                    money = charMoney,
                    class = charData.class,
                    isCurrent = (charKey == currentKey),
                }
            end

            if #charList > 1 then
                table.sort(charList, function(a, b) return a.money > b.money end)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("All Characters", 1, 1, 1)
                for _, char in ipairs(charList) do
                    local r, g, b = 1, 1, 1
                    if char.class then
                        local classColor = C_ClassColor.GetClassColor(char.class)
                        if classColor then
                            r, g, b = classColor.r, classColor.g, classColor.b
                        end
                    end
                    local displayName = char.isCurrent and ("* " .. char.key) or char.key
                    GameTooltip:AddDoubleLine(displayName, FormatGold(char.money), r, g, b, 1, 1, 1)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine("Total:", FormatGold(total), 1, 1, 1, 1, 0.82, 0)
            end
        end

        if C_Bank and C_Bank.FetchDepositedMoney then
            local warboundMoney = C_Bank.FetchDepositedMoney(Enum.BankType.Account)
            if warboundMoney and warboundMoney > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Warbound Bank", 1, 1, 1)
                GameTooltip:AddDoubleLine("Account Gold:", FormatGold(warboundMoney), 0.8, 0.8, 0.8, 1, 0.82, 0)
            end
        end

        if C_WowTokenPublic and C_WowTokenPublic.GetCurrentMarketPrice then
            local tokenPrice = C_WowTokenPublic.GetCurrentMarketPrice()
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("WoW Token", 1, 1, 1)
            if tokenPrice and tokenPrice > 0 then
                GameTooltip:AddDoubleLine("Market Price:", FormatGold(tokenPrice), 0.8, 0.8, 0.8, 1, 0.82, 0)
            else
                GameTooltip:AddDoubleLine("Market Price:", "Updating...", 0.8, 0.8, 0.8, 0.5, 0.5, 0.5)
            end
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-Click: Open Currency", 0.5, 0.5, 0.5)
        GameTooltip:AddLine("Right-Click: Toggle Bags", 0.5, 0.5, 0.5)
        GameTooltip:AddLine("Middle-Click: Manage Characters", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end,
    onClick = function(frame, button)
        if button == "LeftButton" then
            ToggleCharacter("TokenFrame")
        elseif button == "RightButton" then
            ToggleAllBags()
        elseif button == "MiddleButton" then
            BuildGoldManageMenu(frame)
        end
    end,
})
