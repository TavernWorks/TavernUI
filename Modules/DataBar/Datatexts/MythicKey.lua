local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local format = string.format
local C_MythicPlus = C_MythicPlus
local C_ChallengeMode = C_ChallengeMode
local C_Spell_GetSpellCooldown = C_Spell.GetSpellCooldown
local C_SpellBook_IsSpellKnown = C_SpellBook.IsSpellKnown

local dungeonTeleportSpells = {
    -- Wrath of the Lich King
    [556] = {1254555},  -- Pit of Saron
    -- Cataclysm
    [438] = {410080},   -- The Vortex Pinnacle
    [456] = {424142},   -- Throne of the Tides
    [507] = {445424},   -- Grim Batol
    -- Pandaria
    [2]   = {131204},   -- Temple of the Jade Serpent
    [56]  = {131205},   -- Stormstout Brewery
    [57]  = {131225},   -- Gate of the Setting Sun
    [58]  = {131206},   -- Shado-Pan Monastery
    [59]  = {131228},   -- Siege of Niuzao Temple
    [60]  = {131222},   -- Mogu'shan Palace
    [76]  = {131232},   -- Scholomance
    [77]  = {131231},   -- Scarlet Halls
    [78]  = {131229},   -- Scarlet Monastery
    -- Warlords of Draenor
    [161] = {159898, 1254557}, -- Skyreach
    [163] = {159895},   -- Bloodmaul Slag Mines
    [164] = {159897},   -- Auchindoun
    [165] = {159899},   -- Shadowmoon Burial Grounds
    [166] = {159900},   -- Grimrail Depot
    [167] = {159902},   -- Upper Blackrock Spire
    [168] = {159901},   -- The Everbloom
    [169] = {159896},   -- Iron Docks
    -- Legion
    [198] = {424163},   -- Darkheart Thicket
    [199] = {424153},   -- Black Rook Hold
    [200] = {393764},   -- Halls of Valor
    [206] = {410078},   -- Neltharion's Lair
    [210] = {393766},   -- Court of Stars
    [227] = {373262},   -- Lower Karazhan
    [234] = {373262},   -- Upper Karazhan
    [239] = {1254551},  -- Seat of the Triumvirate
    -- Battle for Azeroth
    [244] = {424187},   -- Atal'Dazar
    [245] = {410071},   -- Freehold
    [247] = {467553, 467555}, -- The MOTHERLODE!!
    [248] = {424167},   -- Waycrest Manor
    [251] = {410074},   -- The Underrot
    [353] = {445418, 464256}, -- Siege of Boralus
    [369] = {373274},   -- Mechagon Junkyard
    [370] = {373274},   -- Mechagon Workshop
    -- Shadowlands
    [375] = {354464},   -- Mists of Tirna Scithe
    [376] = {354462},   -- The Necrotic Wake
    [377] = {354468},   -- De Other Side
    [378] = {354465},   -- Halls of Atonement
    [379] = {354463},   -- Plaguefall
    [380] = {354469},   -- Sanguine Depths
    [381] = {354466},   -- Spires of Ascension
    [382] = {354467},   -- Theater of Pain
    [391] = {367416},   -- Tazavesh: Streets of Wonder
    [392] = {367416},   -- Tazavesh: So'leah's Gambit
    -- Dragonflight
    [399] = {393256},   -- Ruby Life Pools
    [400] = {393262},   -- The Nokhud Offensive
    [401] = {393279},   -- The Azure Vault
    [402] = {393273},   -- Algeth'ar Academy
    [403] = {393222},   -- Uldaman: Legacy of Tyr
    [404] = {393276},   -- Neltharus
    [405] = {393267},   -- Brackenhide Hollow
    [406] = {393283},   -- Halls of Infusion
    [463] = {424197},   -- Dawn of the Infinite: Galakrond's Fall
    [464] = {424197},   -- Dawn of the Infinite: Murozond's Rise
    -- The War Within
    [499] = {445444},   -- Priory of the Sacred Flame
    [500] = {445443},   -- The Rookery
    [501] = {445269},   -- The Stonevault
    [502] = {445416},   -- City of Threads
    [503] = {445417},   -- Ara-Kara, City of Echoes
    [504] = {445441},   -- Darkflame Cleft
    [505] = {445414},   -- The Dawnbreaker
    [506] = {445440},   -- Cinderbrew Meadery
    [525] = {1216786},  -- Operation: Floodgate
    [542] = {1237215},  -- Eco-Dome Al'dani
    -- Midnight
    [557] = {1254400},  -- Windrunner Spire
    [558] = {1254572},  -- Magisters' Terrace
    [559] = {1254563},  -- Nexus-Point Xenas
    [560] = {1254559},  -- Maisara Caverns
}

local function GetKeyColor(level)
    if not level or level == 0 then return 0.7, 0.7, 0.7 end
    if level >= 20 then return 1, 0.5, 0 end
    if level >= 15 then return 0.64, 0.21, 0.93 end
    if level >= 10 then return 0, 0.44, 0.87 end
    if level >= 5 then return 0.12, 1, 0 end
    return 1, 1, 1
end

local function GetShortDungeonName(mapID)
    local name = C_ChallengeMode.GetMapUIInfo(mapID)
    if name then
        return name:match("^(%S+)") or name
    end
    return "?"
end

local function UpdateSecureAttributes(secureButton)
    if InCombatLockdown() then return end

    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    if not mapID then
        secureButton:SetAttribute("type", nil)
        secureButton:SetAttribute("spell", nil)
        return
    end

    local spells = dungeonTeleportSpells[mapID]
    if not spells then
        secureButton:SetAttribute("type", nil)
        secureButton:SetAttribute("spell", nil)
        return
    end

    for _, spellID in ipairs(spells) do
        if C_SpellBook_IsSpellKnown(spellID) then
            local cdInfo = C_Spell_GetSpellCooldown(spellID)
            if cdInfo and cdInfo.startTime == 0 then
                secureButton:SetAttribute("type", "spell")
                secureButton:SetAttribute("spell", spellID)
                return
            else
                secureButton:SetAttribute("type", nil)
                secureButton:SetAttribute("spell", nil)
                return
            end
        end
    end

    secureButton:SetAttribute("type", nil)
    secureButton:SetAttribute("spell", nil)
end

local function HasTeleportSpell(mapID)
    if not mapID then return false end
    local spells = dungeonTeleportSpells[mapID]
    if not spells then return false end
    for _, spellID in ipairs(spells) do
        if C_SpellBook_IsSpellKnown(spellID) then
            return true
        end
    end
    return false
end

DataBar:RegisterDatatext("Mythic Key", {
    labelShort = "Key",
    events = { "CHALLENGE_MODE_MAPS_UPDATE", "BAG_UPDATE", "CHALLENGE_MODE_KEYSTONE_SLOTTED" },
    update = function()
        local keystoneLevel = C_MythicPlus.GetOwnedKeystoneLevel()
        local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()

        if keystoneLevel and keystoneLevel > 0 and mapID then
            local shortName = GetShortDungeonName(mapID)
            local r, g, b = GetKeyColor(keystoneLevel)
            return format("|cff%02x%02x%02x+%d|r %s", r * 255, g * 255, b * 255, keystoneLevel, shortName)
        end
        return "No Key"
    end,
    tooltip = function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Mythic+ Keystone", 1, 1, 1)
        GameTooltip:AddLine(" ")

        local keystoneLevel = C_MythicPlus.GetOwnedKeystoneLevel()
        local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()

        if keystoneLevel and keystoneLevel > 0 and mapID then
            local name = C_ChallengeMode.GetMapUIInfo(mapID)
            local r, g, b = GetKeyColor(keystoneLevel)
            GameTooltip:AddDoubleLine("Current Key:",
                format("|cff%02x%02x%02x+%d %s|r", r * 255, g * 255, b * 255, keystoneLevel, name or "Unknown"),
                1, 1, 1)

            if HasTeleportSpell(mapID) then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Left-Click: Teleport to Dungeon", 0.5, 0.5, 0.5)
            else
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Teleport spell not learned", 0.5, 0.3, 0.3)
            end
        else
            GameTooltip:AddLine("No keystone in bags", 0.7, 0.7, 0.7)
        end

        GameTooltip:AddLine("Right-Click: Open Group Finder", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end,
    setupSecureButton = function(slotFrame)
        if slotFrame.secureButton then return slotFrame.secureButton end

        local secureButton = CreateFrame("Button", nil, slotFrame, "SecureActionButtonTemplate")
        secureButton:SetAllPoints(slotFrame)
        secureButton:EnableMouse(true)
        secureButton:RegisterForClicks("LeftButtonDown", "RightButtonUp")
        secureButton:SetFrameLevel(slotFrame:GetFrameLevel() + 10)
        slotFrame.secureButton = secureButton

        secureButton:SetScript("PreClick", function(btn, button)
            if button == "LeftButton" and not InCombatLockdown() then
                UpdateSecureAttributes(btn)
            end
        end)

        secureButton:SetScript("PostClick", function(btn, button)
            if button == "RightButton" then
                if InCombatLockdown() then return end
                if PVEFrame and PVEFrame:IsShown() then
                    HideUIPanel(PVEFrame)
                else
                    PVEFrame_ShowFrame("GroupFinderFrame", LFGListPVEStub)
                end
            end
        end)

        return secureButton
    end,
})
