local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local floor = math.floor
local format = string.format

local function GetLocalTime24()
    return format("%02d:%02d", tonumber(date("%H")), tonumber(date("%M")))
end

local function GetLocalTime12()
    local hour = tonumber(date("%H"))
    local minute = tonumber(date("%M"))
    local ampm = hour >= 12 and "PM" or "AM"
    if hour == 0 then
        hour = 12
    elseif hour > 12 then
        hour = hour - 12
    end
    return format("%d:%02d %s", hour, minute, ampm)
end

local function GetServerTime()
    local hour, minute = GetGameTime()
    return format("%02d:%02d", hour, minute)
end

local formatFuncs = {
    ["24h"] = GetLocalTime24,
    ["12h"] = GetLocalTime12,
    server = GetServerTime,
}

local function FormatTimeRemaining(seconds)
    if not seconds or seconds <= 0 then return "N/A" end
    local days = floor(seconds / 86400)
    local hours = floor((seconds % 86400) / 3600)
    local minutes = floor((seconds % 3600) / 60)
    if days > 0 then
        return format("%dd %dh", days, hours)
    end
    return format("%dh %dm", hours, minutes)
end

DataBar:RegisterDatatext("Time", {
    label = "Time",
    labelShort = "T",
    pollInterval = 1,
    options = {
        format = {
            type = "select",
            name = "Format",
            desc = "Time display format",
            values = { ["24h"] = "24-Hour", ["12h"] = "12-Hour", server = "Server" },
            default = "24h",
        },
    },
    update = function(slot)
        local fmt = slot and slot.format or "24h"
        local fn = formatFuncs[fmt] or GetLocalTime24
        return fn()
    end,
    tooltip = function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Time", 1, 1, 1)
        GameTooltip:AddLine(" ")

        local numSaved = GetNumSavedInstances()
        if numSaved > 0 then
            local hasRaid = false
            for i = 1, numSaved do
                local name, _, reset, difficulty, locked, extended, _, isRaid, _, difficultyName = GetSavedInstanceInfo(i)
                if locked and isRaid and reset > 0 then
                    if not hasRaid then
                        GameTooltip:AddLine("Saved Raid(s)", 1, 0.82, 0)
                        hasRaid = true
                    end
                    local displayName = difficultyName and (name .. " (" .. difficultyName .. ")") or name
                    GameTooltip:AddDoubleLine(displayName, FormatTimeRemaining(reset), 0.8, 0.8, 0.8, 1, 1, 1)
                end
            end
            if hasRaid then
                GameTooltip:AddLine(" ")
            end
        end

        local numWorldBosses = GetNumSavedWorldBosses()
        if numWorldBosses > 0 then
            local hasBoss = false
            for i = 1, numWorldBosses do
                local name, _, reset = GetSavedWorldBossInfo(i)
                if reset > 0 then
                    if not hasBoss then
                        GameTooltip:AddLine("World Bosses", 1, 0.82, 0)
                        hasBoss = true
                    end
                    GameTooltip:AddDoubleLine(name, FormatTimeRemaining(reset), 0.8, 0.8, 0.8, 1, 1, 1)
                end
            end
            if hasBoss then
                GameTooltip:AddLine(" ")
            end
        end

        local dailyReset = C_DateAndTime.GetSecondsUntilDailyReset()
        if dailyReset then
            GameTooltip:AddDoubleLine("Daily Reset", FormatTimeRemaining(dailyReset), 0.8, 0.8, 0.8, 1, 1, 1)
        end

        local weeklyReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if weeklyReset then
            GameTooltip:AddDoubleLine("Weekly Reset", FormatTimeRemaining(weeklyReset), 0.8, 0.8, 0.8, 1, 1, 1)
        end

        GameTooltip:AddDoubleLine("Realm Time", GetServerTime(), 0.8, 0.8, 0.8, 1, 1, 1)

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-Click: Calendar", 0.5, 0.5, 0.5)
        GameTooltip:AddLine("Right-Click: Clock", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end,
    onClick = function(_, button)
        if button == "LeftButton" then
            ToggleCalendar()
        elseif button == "RightButton" then
            ToggleTimeManager()
        end
    end,
})
