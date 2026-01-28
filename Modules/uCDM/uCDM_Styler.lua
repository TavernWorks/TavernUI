local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local Styler = {}

local pendingStyling = {}
local setupDone = {}

local FONT_PATH = "Fonts\\FRIZQT__.TTF"

function Styler.Initialize()
    pendingStyling = {}
    setupDone = {}
    
    module:LogInfo("Styler initialized")
end

function Styler.RemoveMaskTextures(frame)
    if not frame then return end
    
    local textures = {frame.Icon, frame.icon}
    for _, tex in ipairs(textures) do
        if tex and tex.GetMaskTexture and tex.RemoveMaskTexture then
            for i = 1, 10 do
                local mask = tex:GetMaskTexture(i)
                if mask then
                    tex:RemoveMaskTexture(mask)
                end
            end
        end
    end
end

function Styler.StripBlizzardOverlay(frame)
    if not frame or not frame.GetRegions then return end
    
    for _, region in ipairs({frame:GetRegions()}) do
        if region:IsObjectType("Texture") and region.GetAtlas then
            local ok, atlas = pcall(region.GetAtlas, region)
            if ok and atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                region:SetTexture("")
                region:Hide()
                region.Show = function() end
            end
        end
    end
end

function Styler.PreventAtlasBorder(texture)
    if not texture or texture.__ucdmAtlasBlocked then return end
    texture.__ucdmAtlasBlocked = true
    
    if texture.SetAtlas then
        hooksecurefunc(texture, "SetAtlas", function(self)
            if self.SetTexture then self:SetTexture(nil) end
            if self.SetAlpha then self:SetAlpha(0) end
        end)
    end
    
    if texture.SetTexture then texture:SetTexture(nil) end
    if texture.SetAlpha then texture:SetAlpha(0) end
end

function Styler.SetupIconOnce(frame)
    if not frame or setupDone[frame] then return end
    setupDone[frame] = true
    
    Styler.RemoveMaskTextures(frame)
    Styler.StripBlizzardOverlay(frame)
    
    if frame.DebuffBorder then Styler.PreventAtlasBorder(frame.DebuffBorder) end
    if frame.BuffBorder then Styler.PreventAtlasBorder(frame.BuffBorder) end
    if frame.TempEnchantBorder then Styler.PreventAtlasBorder(frame.TempEnchantBorder) end
    
    if frame.NormalTexture then
        frame.NormalTexture:SetAlpha(0)
    end
    if frame.GetNormalTexture then
        local normalTex = frame:GetNormalTexture()
        if normalTex then
            normalTex:SetAlpha(0)
        end
    end
    
    if frame.CooldownFlash then
        frame.CooldownFlash:SetAlpha(0)
        if not frame.CooldownFlash.__ucdmHooked then
            frame.CooldownFlash.__ucdmHooked = true
            hooksecurefunc(frame.CooldownFlash, "Show", function(self)
                self:SetAlpha(0)
            end)
        end
    end
    
    local textures = {frame.Icon, frame.icon}
    for _, tex in ipairs(textures) do
        if tex then
            tex:ClearAllPoints()
            tex:SetAllPoints(frame)
        end
    end
    
    local cooldown = frame.Cooldown or frame.cooldown
    if cooldown then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints(frame)
        cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8")
        cooldown:SetSwipeColor(0, 0, 0, 0.8)
    end
end

function Styler.ApplyTexCoord(frame)
    if not frame then return end
    
    local z = frame._ucdmZoom or 0
    local aspectRatio = frame._ucdmAspectRatio or 1.0
    local baseCrop = 0.08
    
    local left = baseCrop + z
    local right = 1 - baseCrop - z
    local top = baseCrop + z
    local bottom = 1 - baseCrop - z
    
    if aspectRatio > 1.0 then
        local cropAmount = 1.0 - (1.0 / aspectRatio)
        local availableHeight = bottom - top
        local offset = (cropAmount * availableHeight) / 2.0
        top = top + offset
        bottom = bottom - offset
    end
    
    local tex = frame.Icon or frame.icon
    if tex and tex.SetTexCoord then
        tex:SetTexCoord(left, right, top, bottom)
    end
end

function Styler.ApplyBorder(frame, borderSize, borderColor)
    if not frame then return end
    
    borderSize = borderSize or 0
    if borderSize <= 0 then
        if frame._ucdmBorder then
            frame._ucdmBorder:Hide()
        end
        frame:SetHitRectInsets(0, 0, 0, 0)
        return
    end
    
    if not frame._ucdmBorder then
        frame._ucdmBorder = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    end
    
    local bc = borderColor or {r = 0, g = 0, b = 0, a = 1}
    frame._ucdmBorder:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
    
    frame._ucdmBorder:ClearAllPoints()
    frame._ucdmBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", -borderSize, borderSize)
    frame._ucdmBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", borderSize, -borderSize)
    frame._ucdmBorder:Show()
    
    frame:SetHitRectInsets(-borderSize, -borderSize, -borderSize, -borderSize)
end

function Styler.ApplyIconStyleImmediate(frame, config)
    if not frame then return end
    
    local size = config.iconSize or config.size or 40
    local aspectRatio = config.aspectRatioCrop or 1.0
    local zoom = config.zoom or 0
    local borderSize = config.iconBorderSize or 0
    local borderColor = config.iconBorderColor or {r = 0, g = 0, b = 0, a = 1}
    
    local width = size
    local height = size / aspectRatio
    
    pcall(function()
        frame:SetSize(width, height)
    end)
    
    frame._ucdmZoom = zoom
    frame._ucdmAspectRatio = aspectRatio
    
    Styler.ApplyTexCoord(frame)
    Styler.ApplyBorder(frame, borderSize, borderColor)
    
    local textures = {frame.Icon, frame.icon}
    for _, tex in ipairs(textures) do
        if tex then
            tex:ClearAllPoints()
            tex:SetAllPoints(frame)
        end
    end
    
    local cooldown = frame.Cooldown or frame.cooldown
    if cooldown then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints(frame)
        cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8")
        cooldown:SetSwipeColor(0, 0, 0, 0.8)
    end
end

function Styler.ApplyIconStyle(frame, config, force)
    if not frame then return end
    
    local shouldForce = force or module:IsInInitialPhase()
    
    if InCombatLockdown() and not shouldForce then
        Styler.QueueForStyling(frame, config)
        return
    end
    
    Styler.SetupIconOnce(frame)
    Styler.ApplyIconStyleImmediate(frame, config)
end

function Styler.QueueForStyling(frame, config)
    if not frame then return end
    
    pendingStyling[frame] = {
        config = config,
        timestamp = GetTime(),
    }
end

function Styler.ProcessPendingStyling()
    if not next(pendingStyling) then return end
    
    local shouldForce = module:IsInInitialPhase()
    
    if InCombatLockdown() and not shouldForce then return end
    
    for frame, data in pairs(pendingStyling) do
        if frame and frame:IsShown() then
            local ok = pcall(function()
                Styler.SetupIconOnce(frame)
                Styler.ApplyIconStyleImmediate(frame, data.config)
            end)
            if ok then
                frame._ucdmStylingPending = nil
            end
        end
        pendingStyling[frame] = nil
    end
end

local function SetFontStringPoint(fs, point, relativeTo, relativePoint, offsetX, offsetY)
    if not fs or not fs.SetFont then return end
    pcall(function()
        fs:ClearAllPoints()
        fs:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
    end)
end

function Styler.ApplyTextStyle(frame, config)
    if not frame then return end
    
    local durationSize = config.durationSize or 0
    local stackSize = config.stackSize or 0
    local durationPoint = config.durationPoint or "CENTER"
    local durationOffsetX = config.durationOffsetX or 0
    local durationOffsetY = config.durationOffsetY or 0
    local stackPoint = config.stackPoint or "BOTTOMRIGHT"
    local stackOffsetX = config.stackOffsetX or 0
    local stackOffsetY = config.stackOffsetY or 0
    
    if durationSize > 0 then
        local cooldown = frame.Cooldown or frame.cooldown
        if cooldown then
            if cooldown.text then
                cooldown.text:SetFont(FONT_PATH, durationSize, "OUTLINE")
                SetFontStringPoint(cooldown.text, durationPoint, frame, durationPoint, durationOffsetX, durationOffsetY)
            end
            local ok, regions = pcall(function() return { cooldown:GetRegions() } end)
            if ok and regions then
                for _, region in ipairs(regions) do
                    if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                        region:SetFont(FONT_PATH, durationSize, "OUTLINE")
                        SetFontStringPoint(region, durationPoint, frame, durationPoint, durationOffsetX, durationOffsetY)
                    end
                end
            end
        end
    end
    
    if stackSize > 0 then
        local chargeFrame = frame.ChargeCount
        if chargeFrame then
            local fs = chargeFrame.Current or chargeFrame.Count or chargeFrame.count
            if fs then
                fs:SetFont(FONT_PATH, stackSize, "OUTLINE")
                SetFontStringPoint(fs, stackPoint, frame, stackPoint, stackOffsetX, stackOffsetY)
            end
        end
        
        local countText = frame.Count or frame.count
        if countText then
            countText:SetFont(FONT_PATH, stackSize, "OUTLINE")
            SetFontStringPoint(countText, stackPoint, frame, stackPoint, stackOffsetX, stackOffsetY)
        end
    end
end

function Styler.ApplyViewerStyling(viewer, rowDistribution, activeRows, viewerKey)
    if not viewer or not rowDistribution or not activeRows then return end
    
    local force = module:IsInInitialPhase()
    
    for rowNum, entriesInRow in pairs(rowDistribution) do
        local rowConfig = activeRows[rowNum]
        if rowConfig then
            for _, entry in ipairs(entriesInRow) do
                if entry.frame then
                    Styler.ApplyIconStyle(entry.frame, rowConfig, force)
                    Styler.ApplyTextStyle(entry.frame, rowConfig)
                end
            end
        end
    end
end

module.Styler = Styler
