local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local FrameManager = {}

local framePool = {}
local MAX_POOL_SIZE = 50

function FrameManager.Initialize()
    framePool = {}
    module:LogInfo("FrameManager initialized")
end

function FrameManager.GetPooledFrame()
    if #framePool > 0 then
        local frame = table.remove(framePool)
        frame:Show()
        return frame
    end
    
    return nil
end

function FrameManager.CreateCustomFrame(entry)
    local frame = FrameManager.GetPooledFrame()
    
    if not frame then
        frame = CreateFrame("Button", "uCDMCustomFrame" .. entry.id, UIParent)
        frame:SetSize(40, 40)
        
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(frame)
        frame.Icon = icon
        
        local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
        cooldown:SetAllPoints(frame)
        frame.Cooldown = cooldown
        
        local count = frame:CreateFontString(nil, "OVERLAY")
        count:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        frame.Count = count
    end
    
    frame._ucdmEntryID = entry.id
    return frame
end

function FrameManager.ReleaseFrame(frame)
    if not frame then return end
    
    frame:Hide()
    frame:ClearAllPoints()
    
    if frame._ucdmEntryID then
        frame._ucdmEntryID = nil
    end
    
    if #framePool < MAX_POOL_SIZE then
        table.insert(framePool, frame)
    end
end

function FrameManager.PositionFrame(frame, x, y, parent)
    if not frame or not parent then return end
    
    pcall(function()
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", parent, "CENTER", x, y)
    end)
end

function FrameManager.PrepareFrame(frame, frameType)
    if not frame then return end
    
    if frameType == "blizzard" then
        return frame
    elseif frameType == "custom" then
        return frame
    end
    
    return frame
end

function FrameManager.UpdateFrame(frame, entry)
    if not frame or not entry then return end
    
    if entry.type == "custom" then
        if frame.Icon and entry.config then
            local iconFileID = entry.config.iconFileID or 134400
            frame.Icon:SetTexture(iconFileID)
        end
    end
end

module.FrameManager = FrameManager
