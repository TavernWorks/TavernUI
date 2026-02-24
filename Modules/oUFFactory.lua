local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local oUF = TavernUI.oUF

local Factory = {}
TavernUI.oUFFactory = Factory

Factory.frames = {}
Factory.hasSpawned = false

local SOLO_UNITS = { "player", "target", "targettarget", "focus", "focustarget", "pet" }
local CASTBAR_UNITS = { "player", "target", "focus" }

function TavernUI:GetCastbarSetting(unit, key, default)
    if not self.Config then return default end
    return self.Config:Get("TUI.Castbar.units." .. unit .. "." .. key, default)
end

function TavernUI:SetCastbarSetting(unit, key, value)
    if not self.Config then return false end
    return self.Config:Set("TUI.Castbar.units." .. unit .. "." .. key, value)
end

local function GetSpawnMode(unit)
    local ufModule = TavernUI:GetModule("UnitFrames", true)
    if ufModule and TavernUI:IsModuleEnabled("UnitFrames") then
        local unitType = ufModule:GetUnitType(unit)
        local ufDB = ufModule:GetUnitDB(unitType)
        if ufDB and ufDB.enabled then
            return "full"
        end
    end

    local cbModule = TavernUI:GetModule("Castbar", true)
    if cbModule and TavernUI:IsModuleEnabled("Castbar") then
        for _, cbUnit in ipairs(CASTBAR_UNITS) do
            if cbUnit == unit then
                local unitEnabled = TavernUI:GetCastbarSetting(unit, "enabled", true)
                if unitEnabled ~= false then
                    return "castbar_only"
                end
            end
        end
    end

    return nil
end

local function IsCastbarModuleHandling(unit)
    local cbModule = TavernUI:GetModule("Castbar", true)
    if not cbModule or not TavernUI:IsModuleEnabled("Castbar") then return false end
    for _, cbUnit in ipairs(CASTBAR_UNITS) do
        if cbUnit == unit then
            local unitEnabled = TavernUI:GetCastbarSetting(unit, "enabled", true)
            return unitEnabled ~= false
        end
    end
    return false
end

Factory.GetSpawnMode = GetSpawnMode
Factory.IsCastbarModuleHandling = IsCastbarModuleHandling

local function AdaptiveStyle(frame, unit)
    local mode = GetSpawnMode(unit)

    if mode == "full" then
        local ufModule = TavernUI:GetModule("UnitFrames")
        ufModule:StyleFrame(frame, unit)

    elseif mode == "castbar_only" then
        local width = TavernUI:GetCastbarSetting(unit, "width", 220)
        local height = TavernUI:GetCastbarSetting(unit, "height", 20)

        frame:SetSize(width, height)

        local ufModule = TavernUI:GetModule("UnitFrames", true)
        if ufModule and ufModule.CastbarShared then
            local cbDb = {
                showCastbar = true,
                castbar = {
                    anchor = {
                        point = "TOPLEFT", relPoint = "TOPLEFT", offX = 0, offY = 0,
                        point2 = "BOTTOMRIGHT", relPoint2 = "BOTTOMRIGHT",
                    },
                },
            }
            ufModule.CastbarShared:CreateCastbar(frame, unit, cbDb)
        end
    end
end

local function SafeDisableBlizzardCastbar()
    if PlayerCastingBarFrame and PlayerCastingBarFrame.SetAndUpdateShowCastbar then
        PlayerCastingBarFrame:SetAndUpdateShowCastbar(false)
    end
    if PetCastingBarFrame and PetCastingBarFrame.SetAndUpdateShowCastbar then
        PetCastingBarFrame:SetAndUpdateShowCastbar(false)
    end
end

function Factory:SpawnFrames()
    if self.hasSpawned then return end
    self.hasSpawned = true

    if not oUF then
        TavernUI:Print("|cffff0000oUF not found. Cannot spawn frames.|r")
        return
    end

    SafeDisableBlizzardCastbar()

    oUF:RegisterStyle("TavernUI", AdaptiveStyle)
    oUF:SetActiveStyle("TavernUI")

    oUF:Factory(function(oufSelf)
        for _, unit in ipairs(SOLO_UNITS) do
            local mode = GetSpawnMode(unit)
            if mode then
                local prefix = mode == "full" and "TavernUI_UF_" or "TavernUI_CB_"
                local globalName = prefix .. unit:gsub("^%l", string.upper)

                -- In castbar_only mode the oUF frame is just a hidden host for the
                -- castbar element.  We must NOT let oUF hide the Blizzard unit frames
                -- (PlayerFrame, TargetFrame, FocusFrame) because the user may still
                -- want them visible.  Temporarily replace DisableBlizzard with a no-op
                -- for the duration of this spawn, then restore it.
                local savedDisableBlizzard
                if mode == "castbar_only" then
                    savedDisableBlizzard = oUF.DisableBlizzard
                    oUF.DisableBlizzard = function() end
                end

                local frame = oufSelf:Spawn(unit, globalName)

                if savedDisableBlizzard then
                    oUF.DisableBlizzard = savedDisableBlizzard
                end

                frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                self.frames[unit] = frame

                if mode == "castbar_only" then
                    frame:SetAlpha(0)
                    frame:Hide()
                end
            end
        end

        local ufModule = TavernUI:GetModule("UnitFrames", true)
        if ufModule and TavernUI:IsModuleEnabled("UnitFrames") then
            local bossDB = ufModule:GetUnitDB("boss")
            if bossDB and bossDB.enabled then
                for i = 1, 5 do
                    local unit = "boss" .. i
                    local frame = oufSelf:Spawn(unit, "TavernUI_UF_Boss" .. i)
                    if i == 1 then
                        frame:SetPoint("RIGHT", UIParent, "RIGHT", -50, 0)
                    else
                        frame:SetPoint("TOP", self.frames["boss" .. (i - 1)], "BOTTOM", 0, -8)
                    end
                    self.frames[unit] = frame
                end
            end

            local arenaDB = ufModule:GetUnitDB("arena")
            if arenaDB and arenaDB.enabled then
                for i = 1, 3 do
                    local unit = "arena" .. i
                    local frame = oufSelf:Spawn(unit, "TavernUI_UF_Arena" .. i)
                    if i == 1 then
                        frame:SetPoint("RIGHT", UIParent, "RIGHT", -50, 100)
                    else
                        frame:SetPoint("TOP", self.frames["arena" .. (i - 1)], "BOTTOM", 0, -8)
                    end
                    self.frames[unit] = frame
                end
            end
        end

        self:DistributeFrames()
    end)
end

function Factory:DistributeFrames()
    local ufModule = TavernUI:GetModule("UnitFrames", true)
    local cbModule = TavernUI:GetModule("Castbar", true)

    for unit, frame in pairs(self.frames) do
        local mode = GetSpawnMode(unit)
        if mode == "full" and ufModule then
            ufModule.frames[unit] = frame
            if cbModule and IsCastbarModuleHandling(unit) then
                if not cbModule.oufFrames then cbModule.oufFrames = {} end
                cbModule.oufFrames[unit] = frame
            end
        elseif mode == "castbar_only" and cbModule then
            if not cbModule.oufFrames then cbModule.oufFrames = {} end
            cbModule.oufFrames[unit] = frame
        end
    end
end

function Factory:GetFrame(unit)
    return self.frames[unit]
end
