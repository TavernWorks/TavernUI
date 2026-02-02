local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local floor = math.floor
local format = string.format
local max = math.max
local min = math.min

local volumeCVars = {
    master = "Sound_MasterVolume",
    music = "Sound_MusicVolume",
    sfx = "Sound_SFXVolume",
    ambience = "Sound_AmbienceVolume",
    dialog = "Sound_DialogVolume",
}

local function GetVolume(volumeType)
    local cvar = volumeCVars[volumeType] or volumeCVars.master
    local value = tonumber(C_CVar.GetCVar(cvar)) or 1
    return floor(value * 100 + 0.5)
end

local function SetVolume(volumeType, percent)
    local cvar = volumeCVars[volumeType] or volumeCVars.master
    percent = max(0, min(100, percent))
    C_CVar.SetCVar(cvar, percent / 100)
end

local function IsMuted()
    return C_CVar.GetCVar("Sound_EnableAllSound") == "0"
end

local function ToggleMute()
    local muted = IsMuted()
    C_CVar.SetCVar("Sound_EnableAllSound", muted and "1" or "0")
end

local function BuildVolumeTooltip(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Volume", 1, 1, 1)
    GameTooltip:AddLine(" ")

    if IsMuted() then
        GameTooltip:AddLine("Sound is MUTED", 1, 0.2, 0.2)
        GameTooltip:AddLine(" ")
    end

    GameTooltip:AddDoubleLine("Master Volume:", GetVolume("master") .. "%", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Music Volume:", GetVolume("music") .. "%", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("SFX Volume:", GetVolume("sfx") .. "%", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Ambience Volume:", GetVolume("ambience") .. "%", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Dialog Volume:", GetVolume("dialog") .. "%", 0.7, 0.7, 0.7, 1, 1, 1)

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Scroll: Adjust Volume", 0.5, 0.5, 0.5)
    GameTooltip:AddLine("Left-Click: Audio Settings", 0.5, 0.5, 0.5)
    GameTooltip:AddLine("Right-Click: Toggle Mute", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

DataBar:RegisterDatatext("Volume", {
    label = "Volume",
    labelShort = "V",
    pollInterval = 1,
    update = function()
        if IsMuted() then
            return "Muted"
        end
        return GetVolume("master") .. "%"
    end,
    getColor = function()
        if IsMuted() then
            return 1, 0.2, 0.2
        end
        local vol = GetVolume("master")
        if vol < 25 then
            return 1, 0.8, 0.2
        end
        return nil
    end,
    tooltip = BuildVolumeTooltip,
    onClick = function(frame, button)
        if button == "LeftButton" then
            if Settings and Settings.OpenToCategory and Settings.AUDIO_CATEGORY_ID then
                Settings.OpenToCategory(Settings.AUDIO_CATEGORY_ID)
            end
        elseif button == "RightButton" then
            ToggleMute()
            if GameTooltip:IsShown() then
                BuildVolumeTooltip(frame)
            end
        end
    end,
    onScroll = function(frame, delta)
        local step = 5
        local currentVol = GetVolume("master")
        SetVolume("master", currentVol + (delta * step))
        if GameTooltip:IsShown() then
            BuildVolumeTooltip(frame)
        end
    end,
})
