local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local format = string.format

-- Build reverse lookup: localized class name -> class token (e.g., "Warrior" -> "WARRIOR")
local unlocalizedClasses = {}
do
    local classMale = LOCALIZED_CLASS_NAMES_MALE
    local classFemale = LOCALIZED_CLASS_NAMES_FEMALE
    if classMale then
        for token, localized in pairs(classMale) do unlocalizedClasses[localized] = token end
    end
    if classFemale then
        for token, localized in pairs(classFemale) do unlocalizedClasses[localized] = token end
    end
end

local function GetClassColor(className)
    if not className then return nil end
    if RAID_CLASS_COLORS[className] then
        return RAID_CLASS_COLORS[className]
    end
    local classToken = unlocalizedClasses[className]
    return classToken and RAID_CLASS_COLORS[classToken]
end

local function CountOnlineFriends()
    local wowOnline = 0
    for i = 1, C_FriendList.GetNumFriends() do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected then
            wowOnline = wowOnline + 1
        end
    end
    local _, bnetOnline = BNGetNumFriends()
    return wowOnline, bnetOnline or 0
end

local function IsPlayerInGroup(name)
    if not IsInGroup() then return false end
    for i = 1, GetNumGroupMembers() do
        local unit = IsInRaid() and ("raid" .. i) or ("party" .. i)
        local unitName, unitRealm = UnitName(unit)
        if unitName then
            local fullUnit = unitRealm and unitRealm ~= "" and (unitName .. "-" .. unitRealm) or unitName
            if fullUnit == name or unitName == name then return true end
        end
    end
    return false
end

local function GetStatusText(info)
    if info.afk then return " |cffFFFF00(AFK)|r" end
    if info.dnd then return " |cffFF0000(DND)|r" end
    return ""
end

local function GetBNetStatusText(gameInfo)
    if gameInfo.isGameAFK then return " |cffFFFF00(AFK)|r" end
    if gameInfo.isGameBusy then return " |cffFF0000(DND)|r" end
    return ""
end

local function BuildFriendsTooltip(frame)
    local showNotes = IsShiftKeyDown()

    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(showNotes and "Friends (Notes)" or "Friends", 1, 1, 1)
    GameTooltip:AddLine(" ")

    local hasAny = false

    -- WoW Friends
    local wowFriends = {}
    for i = 1, C_FriendList.GetNumFriends() do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected then
            wowFriends[#wowFriends + 1] = info
        end
    end

    if #wowFriends > 0 then
        hasAny = true
        GameTooltip:AddLine("WoW Friends", 0.7, 0.7, 0.7)
        for _, info in ipairs(wowFriends) do
            local r, g, b = 1, 1, 1
            local classColor = GetClassColor(info.className)
            if classColor then r, g, b = classColor.r, classColor.g, classColor.b end

            local status = GetStatusText(info)
            local groupMark = IsPlayerInGroup(info.name) and " |cffaaaaaa*|r" or ""
            local levelStr = (info.level and info.level > 0) and (info.level .. " ") or ""
            local left = levelStr .. info.name .. groupMark .. status

            local right, rr, rg, rb
            if showNotes then
                if info.notes and info.notes ~= "" then
                    right, rr, rg, rb = info.notes, 0.9, 0.9, 0.6
                else
                    right, rr, rg, rb = "No note", 0.5, 0.5, 0.5
                end
            else
                right, rr, rg, rb = info.area or "", 0.7, 0.7, 0.7
            end
            GameTooltip:AddDoubleLine(left, right, r, g, b, rr, rg, rb)
        end
    end

    -- Battle.net friends - split by game type
    local bnetRetail, bnetClassic, bnetOther = {}, {}, {}
    local bnetTotal = BNGetNumFriends()
    for i = 1, bnetTotal do
        local bnetInfo = C_BattleNet.GetFriendAccountInfo(i)
        if bnetInfo and bnetInfo.gameAccountInfo and bnetInfo.gameAccountInfo.isOnline then
            local gameInfo = bnetInfo.gameAccountInfo
            local client = gameInfo.clientProgram or ""
            if client == BNET_CLIENT_WOW then
                local wowProjectID = gameInfo.wowProjectID
                if wowProjectID == WOW_PROJECT_MAINLINE then
                    bnetRetail[#bnetRetail + 1] = { account = bnetInfo, game = gameInfo }
                else
                    bnetClassic[#bnetClassic + 1] = { account = bnetInfo, game = gameInfo }
                end
            else
                bnetOther[#bnetOther + 1] = { account = bnetInfo, game = gameInfo }
            end
        end
    end

    if #bnetRetail > 0 then
        if hasAny then GameTooltip:AddLine(" ") end
        hasAny = true
        GameTooltip:AddLine("Battle.net (Retail)", 0.31, 0.69, 0.9)
        for _, entry in ipairs(bnetRetail) do
            local gameInfo = entry.game
            local accountName = entry.account.accountName or "?"
            local charName = gameInfo.characterName
            local r, g, b = 1, 1, 1
            local classColor = GetClassColor(gameInfo.className)
            if classColor then r, g, b = classColor.r, classColor.g, classColor.b end

            local status = GetBNetStatusText(gameInfo)
            local groupMark = (charName and IsPlayerInGroup(charName)) and " |cffaaaaaa*|r" or ""
            local left = charName and (charName .. " (" .. accountName .. ")" .. groupMark .. status) or (accountName .. status)

            local right, rr, rg, rb
            if showNotes then
                local note = entry.account.note
                if note and note ~= "" then
                    right, rr, rg, rb = note, 0.9, 0.9, 0.6
                else
                    right, rr, rg, rb = "No note", 0.5, 0.5, 0.5
                end
            else
                right, rr, rg, rb = gameInfo.areaName or "", 0.7, 0.7, 0.7
            end
            GameTooltip:AddDoubleLine(left, right, r, g, b, rr, rg, rb)
        end
    end

    if #bnetClassic > 0 then
        if hasAny then GameTooltip:AddLine(" ") end
        hasAny = true
        GameTooltip:AddLine("Battle.net (Classic)", 0.6, 0.4, 0.2)
        for _, entry in ipairs(bnetClassic) do
            local gameInfo = entry.game
            local accountName = entry.account.accountName or "?"
            local charName = gameInfo.characterName
            local r, g, b = 0.8, 0.8, 0.8
            local classColor = GetClassColor(gameInfo.className)
            if classColor then r, g, b = classColor.r, classColor.g, classColor.b end

            local status = GetBNetStatusText(gameInfo)
            local left = charName and (charName .. " (" .. accountName .. ")" .. status) or (accountName .. status)

            local right, rr, rg, rb
            if showNotes then
                local note = entry.account.note
                if note and note ~= "" then
                    right, rr, rg, rb = note, 0.9, 0.9, 0.6
                else
                    right, rr, rg, rb = "No note", 0.5, 0.5, 0.5
                end
            else
                right, rr, rg, rb = gameInfo.richPresence or "", 0.7, 0.7, 0.7
            end
            GameTooltip:AddDoubleLine(left, right, r, g, b, rr, rg, rb)
        end
    end

    if #bnetOther > 0 then
        if hasAny then GameTooltip:AddLine(" ") end
        hasAny = true
        GameTooltip:AddLine("Other Games", 0.5, 0.5, 0.5)
        for _, entry in ipairs(bnetOther) do
            local accountName = entry.account.accountName or "?"
            local status = GetBNetStatusText(entry.game)
            local right, rr, rg, rb
            if showNotes then
                local note = entry.account.note
                if note and note ~= "" then
                    right, rr, rg, rb = note, 0.9, 0.9, 0.6
                else
                    right, rr, rg, rb = "No note", 0.5, 0.5, 0.5
                end
            else
                local gameName = entry.game.richPresence or entry.game.clientProgram or "Online"
                right, rr, rg, rb = gameName, 0.5, 0.5, 0.5
            end
            GameTooltip:AddDoubleLine(accountName .. status, right, 0.8, 0.8, 0.8, rr, rg, rb)
        end
    end

    if not hasAny then
        GameTooltip:AddLine("No friends online", 0.7, 0.7, 0.7)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-Click: Open Friends", 0.5, 0.5, 0.5)
    GameTooltip:AddLine("Right-Click: Whisper/Invite Menu", 0.5, 0.5, 0.5)
    if showNotes then
        GameTooltip:AddLine("Release Shift: Show Zones", 0.5, 0.5, 0.5)
    else
        GameTooltip:AddLine("Hold Shift: Show Notes", 0.5, 0.5, 0.5)
    end
    GameTooltip:Show()
end

local function SendWhisperTo(name, isBNet)
    if not name or name == "" then return end
    if isBNet then
        ChatFrameUtil.SendBNetTell(name)
    else
        SetItemRef("player:" .. name, format("|Hplayer:%1$s|h[%1$s]|h", name), "LeftButton")
    end
end

local function InvitePlayer(nameOrGameID, isBNet)
    if not nameOrGameID then return end
    if isBNet then
        BNInviteFriend(nameOrGameID)
    else
        C_PartyInfo.InviteUnit(nameOrGameID)
    end
end

local function BuildFriendsContextMenu(frame)
    local wowFriends = {}
    for i = 1, C_FriendList.GetNumFriends() do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected then
            wowFriends[#wowFriends + 1] = info
        end
    end

    local bnetRetail, bnetClassic, bnetOther = {}, {}, {}
    local bnetTotal = BNGetNumFriends()
    for i = 1, bnetTotal do
        local bnetInfo = C_BattleNet.GetFriendAccountInfo(i)
        if bnetInfo and bnetInfo.gameAccountInfo and bnetInfo.gameAccountInfo.isOnline then
            local gameInfo = bnetInfo.gameAccountInfo
            local client = gameInfo.clientProgram or ""
            if client == BNET_CLIENT_WOW then
                if gameInfo.wowProjectID == WOW_PROJECT_MAINLINE then
                    bnetRetail[#bnetRetail + 1] = { account = bnetInfo, game = gameInfo }
                else
                    bnetClassic[#bnetClassic + 1] = { account = bnetInfo, game = gameInfo }
                end
            else
                bnetOther[#bnetOther + 1] = { account = bnetInfo, game = gameInfo }
            end
        end
    end

    MenuUtil.CreateContextMenu(frame, function(_, root)
        root:CreateTitle("Friends Menu")

        local whisperMenu = root:CreateButton("Whisper")
        local hasWhisperTargets = false

        for _, info in ipairs(wowFriends) do
            hasWhisperTargets = true
            local r, g, b = 1, 1, 1
            local classColor = GetClassColor(info.className)
            if classColor then r, g, b = classColor.r, classColor.g, classColor.b end
            local colorCode = format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
            local whisperName = info.name
            whisperMenu:CreateButton(colorCode .. info.name .. "|r", function()
                SendWhisperTo(whisperName, false)
            end)
        end

        for _, entry in ipairs(bnetRetail) do
            hasWhisperTargets = true
            local charName = entry.game.characterName
            local accountName = entry.account.accountName or "?"
            local displayName = charName and charName ~= "" and (charName .. " (" .. accountName .. ")") or accountName
            local whisperName = accountName
            whisperMenu:CreateButton(displayName, function()
                SendWhisperTo(whisperName, true)
            end)
        end

        for _, entry in ipairs(bnetClassic) do
            hasWhisperTargets = true
            local accountName = entry.account.accountName or "?"
            local whisperName = accountName
            whisperMenu:CreateButton(accountName .. " (Classic)", function()
                SendWhisperTo(whisperName, true)
            end)
        end

        for _, entry in ipairs(bnetOther) do
            hasWhisperTargets = true
            local accountName = entry.account.accountName or "?"
            local gameName = entry.game.richPresence or entry.game.clientProgram or "Online"
            local whisperName = accountName
            whisperMenu:CreateButton(accountName .. " (" .. gameName .. ")", function()
                SendWhisperTo(whisperName, true)
            end)
        end

        if not hasWhisperTargets then
            local noFriends = whisperMenu:CreateButton("No friends online")
            noFriends:SetEnabled(false)
        end

        local inviteMenu = root:CreateButton("Invite")
        local hasInviteTargets = false

        for _, info in ipairs(wowFriends) do
            if not IsPlayerInGroup(info.name) then
                hasInviteTargets = true
                local r, g, b = 1, 1, 1
                local classColor = GetClassColor(info.className)
                if classColor then r, g, b = classColor.r, classColor.g, classColor.b end
                local colorCode = format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
                local inviteName = info.name
                inviteMenu:CreateButton(colorCode .. info.name .. "|r", function()
                    InvitePlayer(inviteName, false)
                end)
            end
        end

        for _, entry in ipairs(bnetRetail) do
            local charName = entry.game.characterName
            if charName and charName ~= "" and not IsPlayerInGroup(charName) then
                hasInviteTargets = true
                local gameID = entry.game.gameAccountID
                inviteMenu:CreateButton(charName, function()
                    InvitePlayer(gameID, true)
                end)
            end
        end

        if not hasInviteTargets then
            local noInvite = inviteMenu:CreateButton("No invitable friends")
            noInvite:SetEnabled(false)
        end

        root:CreateDivider()
        root:CreateButton("Open Friends Panel", function()
            ToggleFriendsFrame()
        end)
    end)
end

DataBar:RegisterDatatext("Friends Online", {
    label = "Friends",
    labelShort = "Fr",
    events = { "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED" },
    update = function()
        local wow, bnet = CountOnlineFriends()
        return tostring(wow + bnet)
    end,
    tooltip = BuildFriendsTooltip,
    onClick = function(frame, button)
        if button == "LeftButton" then
            ToggleFriendsFrame()
        elseif button == "RightButton" then
            BuildFriendsContextMenu(frame)
        end
    end,
})
