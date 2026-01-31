-- TavernUI ExtendedAnchorFrames Module
-- Registers extended frames (Action Bars, etc.) as anchor targets

local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:NewModule("ExtendedAnchorFrames", "AceEvent-3.0")

local Anchor = LibStub("LibAnchorRegistry-1.0", true)

local defaults = {
    enabled = true,
}
TavernUI:RegisterModuleDefaults("ExtendedAnchorFrames", defaults, true)

local registeredFrames = {}

local function RegisterFrame(anchorName, frame, displayName, category)
    if not Anchor or not frame then return false end
    
    if registeredFrames[anchorName] then
        return true
    end
    
    if not frame:IsForbidden() then
        Anchor:Register(anchorName, frame, {
            displayName = displayName,
            category = category or "blizzard",
        })
        registeredFrames[anchorName] = true
        module:Debug("Registered anchor:", anchorName, displayName)
        return true
    end
    
    return false
end

local function RegisterBlizzardActionBars()
    local actionBarMapping = {
        [1] = "MainActionBar",
        [2] = "MultiBarBottomLeft",
        [3] = "MultiBarBottomRight",
        [4] = "MultiBarRight",
        [5] = "MultiBarLeft",
        [6] = "MultiBar5",
        [7] = "MultiBar6",
        [8] = "MultiBar7",
    }
    
    for barId = 1, 8 do
        local frameName = actionBarMapping[barId]
        if frameName then
            local frame = _G[frameName]
            if frame then
                RegisterFrame("Blizzard.ActionBar" .. barId, frame, "Action Bar " .. barId, "actionbars")
            end
        end
    end
end

local function RegisterDominoesActionBars()
    if not _G.Dominos then return end
    
    if _G.Dominos.bars then
        for barId, bar in pairs(_G.Dominos.bars) do
            if bar and bar.frame then
                local displayName = bar.name or ("Dominoes Bar " .. tostring(barId))
                RegisterFrame("Dominos.Bar" .. tostring(barId), bar.frame, displayName, "actionbars")
            end
        end
    end
    
    if _G.Dominos and _G.Dominos.db and _G.Dominos.db.profile then
        local bars = _G.Dominos.db.profile.bars
        if bars then
            for barId, barData in pairs(bars) do
                if barData then
                    local barFrame = _G["DominosBar" .. tostring(barId)]
                    if not barFrame and _G.Dominos.bars and _G.Dominos.bars[barId] and _G.Dominos.bars[barId].frame then
                        barFrame = _G.Dominos.bars[barId].frame
                    end
                    if barFrame then
                        local displayName = barData.name or ("Dominoes Bar " .. tostring(barId))
                        RegisterFrame("Dominos.Bar" .. tostring(barId), barFrame, displayName, "actionbars")
                    end
                end
            end
        end
    end
end

local function RegisterBTActionBars()
    if not _G.Bartender4 then return end
    
    if _G.Bartender4.db then
        local bars = _G.Bartender4.db.profile.bars
        if bars then
            for barId, barData in pairs(bars) do
                if barData and barData.id then
                    local barFrame = _G["BT4Bar" .. barData.id]
                    if not barFrame and _G.Bartender4.barObjects then
                        local barObj = _G.Bartender4.barObjects[barId]
                        if barObj and barObj.frame then
                            barFrame = barObj.frame
                        end
                    end
                    
                    if barFrame then
                        local displayName = barData.name or ("BT Action Bar " .. barData.id)
                        RegisterFrame("Bartender4.Bar" .. barData.id, barFrame, displayName, "actionbars")
                    end
                end
            end
        end
    end
end

local function RegisterBlizzardUnitFrames()
    local unitFrames = {
        { global = "TargetFrame", name = "Target Frame", anchor = "Blizzard.TargetFrame" },
        { global = "FocusFrame", name = "Focus Frame", anchor = "Blizzard.FocusFrame" },
    }

    for _, info in ipairs(unitFrames) do
        local frame = _G[info.global]
        if frame then
            RegisterFrame(info.anchor, frame, info.name, "unitframes")
        end
    end
end

local function RegisterAllFrames()
    if not module:IsEnabled() then return end
    if not Anchor then return end

    RegisterBlizzardActionBars()
    RegisterBlizzardUnitFrames()
    RegisterDominoesActionBars()
    RegisterBTActionBars()
end

function module:OnInitialize()
    self:RegisterMessage("TavernUI_ProfileChanged", "OnProfileChanged")
end

function module:OnEnable()
    self:Debug("ExtendedAnchorFrames module enabled")
    
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:RegisterEvent("ADDON_LOADED")
        self.eventFrame:RegisterEvent("PLAYER_LOGIN")
        self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        self.eventFrame:SetScript("OnEvent", function(frame, event, ...)
            if not module:IsEnabled() then return end
            
            if event == "ADDON_LOADED" then
                local addonName = ...
                if addonName == "Dominos" or addonName == "Bartender4" then
                    C_Timer.After(0.5, RegisterAllFrames)
                end
            elseif event == "PLAYER_LOGIN" then
                C_Timer.After(0.5, RegisterAllFrames)
            elseif event == "PLAYER_ENTERING_WORLD" then
                C_Timer.After(1.0, RegisterAllFrames)
            end
        end)
    end
    
    C_Timer.After(0.5, RegisterAllFrames)
end

function module:OnDisable()
    self:Debug("ExtendedAnchorFrames module disabled")
    
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
    end
    
    if Anchor then
        for anchorName in pairs(registeredFrames) do
            Anchor:Unregister(anchorName)
        end
    end
    
    registeredFrames = {}
end

function module:OnProfileChanged()
    if self:IsEnabled() then
        RegisterAllFrames()
    end
end
