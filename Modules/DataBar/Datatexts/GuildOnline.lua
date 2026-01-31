local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local format = string.format

local MAX_DISPLAY = 20

local function GetClassColor(className)
    if not className then return nil end
    if RAID_CLASS_COLORS[className] then
        return RAID_CLASS_COLORS[className]
    end
    return nil
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

local function StripMyRealm(name)
    if not name then return name end
    local myRealm = GetRealmName():gsub("%s", "")
    return name:gsub("%-" .. myRealm .. "$", "")
end

local function BuildGuildTooltip(frame)
    local showNotes = IsShiftKeyDown()

    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()

    if not IsInGuild() then
        GameTooltip:AddLine("No Guild", 1, 1, 1)
        GameTooltip:Show()
        return
    end

    local guildName = GetGuildInfo("player")
    GameTooltip:AddLine((guildName or "Guild") .. (showNotes and " (Notes)" or ""), 1, 1, 1)

    local motd = GetGuildRosterMOTD()
    if motd and motd ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("MOTD:", 1, 0.8, 0)
        GameTooltip:AddLine(motd, 0.8, 0.8, 0.8, true)
    end

    GameTooltip:AddLine(" ")
    local totalMembers, onlineMembers = GetNumGuildMembers()
    GameTooltip:AddLine(showNotes and "Online Members (Notes)" or "Online Members", 0.7, 0.7, 0.7)

    local shown = 0
    for i = 1, totalMembers do
        local name, rankName, _, level, _, zone, note, officerNote, online, status, engClass = GetGuildRosterInfo(i)
        if online and shown < MAX_DISPLAY then
            shown = shown + 1
            local r, g, b = 1, 1, 1
            local classColor = GetClassColor(engClass)
            if classColor then r, g, b = classColor.r, classColor.g, classColor.b end

            local statusText = ""
            if status == 1 then
                statusText = " |cffFFFF00(AFK)|r"
            elseif status == 2 then
                statusText = " |cffFF0000(DND)|r"
            end

            local displayName = StripMyRealm(name)
            local groupMark = IsPlayerInGroup(name) and " |cffaaaaaa*|r" or ""
            local left = level .. " " .. displayName .. groupMark .. statusText .. " |cff999999-|r " .. (rankName or "")

            local right, rr, rg, rb
            if showNotes then
                local noteText = ""
                if note and note ~= "" then
                    noteText = note
                end
                if officerNote and officerNote ~= "" then
                    if noteText ~= "" then
                        noteText = noteText .. " |cffFF8800[O: " .. officerNote .. "]|r"
                    else
                        noteText = "|cffFF8800[O: " .. officerNote .. "]|r"
                    end
                end
                if noteText == "" then
                    right, rr, rg, rb = "No note", 0.5, 0.5, 0.5
                else
                    right, rr, rg, rb = noteText, 0.9, 0.9, 0.6
                end
            else
                right, rr, rg, rb = zone or "", 0.7, 0.7, 0.7
            end
            GameTooltip:AddDoubleLine(left, right, r, g, b, rr, rg, rb)
        end
    end

    if onlineMembers > MAX_DISPLAY then
        GameTooltip:AddLine("... and " .. (onlineMembers - MAX_DISPLAY) .. " more", 0.7, 0.7, 0.7)
    end

    if shown == 0 then
        GameTooltip:AddLine("No members online", 0.7, 0.7, 0.7)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-Click: Open Guild", 0.5, 0.5, 0.5)
    GameTooltip:AddLine("Right-Click: Whisper/Invite Menu", 0.5, 0.5, 0.5)
    if showNotes then
        GameTooltip:AddLine("Release Shift: Show Zones", 0.5, 0.5, 0.5)
    else
        GameTooltip:AddLine("Hold Shift: Show Notes", 0.5, 0.5, 0.5)
    end
    GameTooltip:Show()
end

local function SendWhisperTo(name)
    if not name or name == "" then return end
    SetItemRef("player:" .. name, format("|Hplayer:%1$s|h[%1$s]|h", name), "LeftButton")
end

local function BuildGuildContextMenu(frame)
    if not IsInGuild() then return end

    local playerName = UnitName("player") .. "-" .. GetNormalizedRealmName()
    local totalMembers = GetNumGuildMembers()

    MenuUtil.CreateContextMenu(frame, function(_, root)
        root:CreateTitle("Guild Menu")

        local whisperMenu = root:CreateButton("Whisper")
        local hasWhisperTargets = false

        for i = 1, totalMembers do
            local name, _, _, level, _, _, _, _, online, _, engClass = GetGuildRosterInfo(i)
            if online and name ~= playerName then
                hasWhisperTargets = true
                local r, g, b = 1, 1, 1
                local classColor = GetClassColor(engClass)
                if classColor then r, g, b = classColor.r, classColor.g, classColor.b end
                local colorCode = format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
                local displayName = StripMyRealm(name)
                local whisperName = name
                whisperMenu:CreateButton(level .. " " .. colorCode .. displayName .. "|r", function()
                    SendWhisperTo(whisperName)
                end)
            end
        end

        if not hasWhisperTargets then
            local noMembers = whisperMenu:CreateButton("No members online")
            noMembers:SetEnabled(false)
        end

        local inviteMenu = root:CreateButton("Invite")
        local hasInviteTargets = false

        for i = 1, totalMembers do
            local name, _, _, level, _, _, _, _, online, _, engClass = GetGuildRosterInfo(i)
            if online and name ~= playerName and not IsPlayerInGroup(name) then
                hasInviteTargets = true
                local r, g, b = 1, 1, 1
                local classColor = GetClassColor(engClass)
                if classColor then r, g, b = classColor.r, classColor.g, classColor.b end
                local colorCode = format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
                local displayName = StripMyRealm(name)
                local inviteName = name
                inviteMenu:CreateButton(level .. " " .. colorCode .. displayName .. "|r", function()
                    C_PartyInfo.InviteUnit(inviteName)
                end)
            end
        end

        if not hasInviteTargets then
            local noInvite = inviteMenu:CreateButton("No invitable members")
            noInvite:SetEnabled(false)
        end

        root:CreateDivider()
        root:CreateButton("Open Guild Panel", function()
            ToggleGuildFrame()
        end)
    end)
end

DataBar:RegisterDatatext("Guild Online", {
    label = "Guild",
    labelShort = "Gu",
    events = { "GUILD_ROSTER_UPDATE" },
    update = function()
        return IsInGuild() and tostring(select(2, GetNumGuildMembers())) or "0"
    end,
    tooltip = BuildGuildTooltip,
    onClick = function(frame, button)
        if button == "LeftButton" then
            ToggleGuildFrame()
        elseif button == "RightButton" then
            BuildGuildContextMenu(frame)
        end
    end,
})
