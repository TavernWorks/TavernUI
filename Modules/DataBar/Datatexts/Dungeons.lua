local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local C_ChallengeMode = C_ChallengeMode

local NAME_TO_SHORT = {
    -- Classic
    ["Scholomance"] = "SCOLO",
    ["Scarlet Halls"] = "HALLS",
    ["Scarlet Monastery"] = "SCARL",

    -- Wrath
    ["Pit of Saron"] = "PIT",

    -- Mists of Pandaria
    ["Temple of the Jade Serpent"] = "TJS",
    ["Stormstout Brewery"] = "BREW",
    ["Shado-Pan Monastery"] = "SHADO",
    ["Siege of Niuzao Temple"] = "SNT",
    ["Gate of the Setting Sun"] = "GATE",
    ["Mogu'shan Palace"] = "MOGU",

    -- Warlords of Draenor
    ["Bloodmaul Slag Mines"] = "BSM",
    ["Auchindoun"] = "AUCH",
    ["Skyreach"] = "SKY",
    ["Shadowmoon Burial Grounds"] = "SBG",
    ["Grimrail Depot"] = "GD",
    ["Upper Blackrock Spire"] = "UBRS",
    ["The Everbloom"] = "EB",
    ["Iron Docks"] = "ID",

    -- Legion
    ["Eye of Azshara"] = "EOA",
    ["Darkheart Thicket"] = "DHT",
    ["Black Rook Hold"] = "BRH",
    ["Halls of Valor"] = "HOV",
    ["Neltharion's Lair"] = "NL",
    ["Vault of the Wardens"] = "VOTW",
    ["Maw of Souls"] = "MOS",
    ["The Arcway"] = "ARC",
    ["Court of Stars"] = "COS",
    ["Cathedral of Eternal Night"] = "COEN",
    ["Return to Karazhan: Lower"] = "LOWER",
    ["Return to Karazhan: Upper"] = "UPPER",
    ["Seat of the Triumvirate"] = "SEAT",

    -- Battle for Azeroth
    ["Atal'Dazar"] = "AD",
    ["Freehold"] = "FH",
    ["The MOTHERLODE!!"] = "ML",
    ["Waycrest Manor"] = "WCM",
    ["Kings' Rest"] = "KR",
    ["Temple of Sethraliss"] = "TOS",
    ["The Underrot"] = "UR",
    ["Shrine of the Storm"] = "SOTS",
    ["Siege of Boralus"] = "SIEGE",
    ["Operation: Mechagon - Junkyard"] = "YARD",
    ["Operation: Mechagon - Workshop"] = "WORK",
    ["Tol Dagor"] = "TD",

    -- Shadowlands
    ["Mists of Tirna Scithe"] = "MISTS",
    ["The Necrotic Wake"] = "NW",
    ["De Other Side"] = "DOS",
    ["Halls of Atonement"] = "HOA",
    ["Plaguefall"] = "PF",
    ["Sanguine Depths"] = "SD",
    ["Spires of Ascension"] = "SOA",
    ["Theater of Pain"] = "TOP",
    ["Tazavesh: Streets of Wonder"] = "STRT",
    ["Tazavesh: So'leah's Gambit"] = "GMBT",

    -- Dragonflight
    ["Ruby Life Pools"] = "RLP",
    ["The Nokhud Offensive"] = "NO",
    ["The Azure Vault"] = "AV",
    ["Algeth'ar Academy"] = "AA",
    ["Uldaman: Legacy of Tyr"] = "ULD",
    ["Neltharus"] = "NELT",
    ["Brackenhide Hollow"] = "BH",
    ["Halls of Infusion"] = "HOI",
    ["Dawn of the Infinite: Galakrond's Fall"] = "FALL",
    ["Dawn of the Infinite: Murozond's Rise"] = "RISE",

    -- The War Within
    ["Priory of the Sacred Flame"] = "PRIO",
    ["The Rookery"] = "ROOK",
    ["The Stonevault"] = "SV",
    ["City of Threads"] = "COT",
    ["Ara-Kara, City of Echoes"] = "ARAK",
    ["Darkflame Cleft"] = "DFC",
    ["The Dawnbreaker"] = "DAWN",
    ["Cinderbrew Meadery"] = "MEAD",
    ["Grim Batol"] = "GB",
    ["Operation: Floodgate"] = "FLOOD",
    ["Eco-Dome Al'dani"] = "EDA",

    -- Midnight
    ["Windrunner Spire"] = "WIND",
    ["Magisters' Terrace"] = "MAGI",
    ["Nexus-Point Xenas"] = "XENAS",
    ["Maisara Caverns"] = "CAVNS",
    ["Murder Row"] = "MURD",
}

function DataBar:GetShortDungeonName(mapID)
    local name = C_ChallengeMode.GetMapUIInfo(mapID)
    if name then
        return NAME_TO_SHORT[name] or name:match("^(%S+)") or name
    end
    return "?"
end
