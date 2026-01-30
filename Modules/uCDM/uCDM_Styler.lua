local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("uCDM", true)

if not module then return end

local Styler = {}

local CONSTANTS = {
    MAX_MASK_TEXTURES = 10,
    TEXTURE_BASE_CROP_PIXELS = 4,
    TEXTURE_SOURCE_SIZE = 64,
}

local pendingStyling = {}
local setupDone = {}

function Styler.RefreshViewer(viewerKey)
    local settings = module:GetViewerSettings(viewerKey)
    if not settings then return end
    
    local activeRows = module.LayoutEngine.GetActiveRows(settings)

    if #activeRows == 0 then return end
    
    local viewer = module.LayoutEngine.GetViewerFrame(viewerKey)
    if not viewer then return end
    
    local allEntries = module.EntrySystem.GetMergedEntriesForViewer(viewerKey)
    if not allEntries then
        module:LogError("Styler.RefreshViewer: Failed to get entries for viewer:", viewerKey)
        return
    end

    -- Use LayoutEngine's row assignment logic to ensure we style exactly what is laid out
    local rowAssignments, usedEntries = module.LayoutEngine.BuildRowAssignments(allEntries, activeRows, settings, viewerKey)

    Styler.ApplyViewerStyling(viewer, rowAssignments or {}, activeRows, viewerKey, true)
end

function Styler.Initialize()
    pendingStyling = {}
    setupDone = {}
end

function Styler.RemoveMaskTextures(frame)
    if not frame then return end
    
    local textures = {frame.Icon, frame.icon}
    for _, tex in ipairs(textures) do
        if tex and tex.GetMaskTexture and tex.RemoveMaskTexture then
            for i = 1, CONSTANTS.MAX_MASK_TEXTURES do
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

    local name = frame.GetName and frame:GetName()
    if not (name and name:find("^uCDMCustomFrame_")) then
        Styler.RemoveMaskTextures(frame)
    end
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
            if tex.SetSnapToPixelGrid then
                tex:SetSnapToPixelGrid(false)
            end
            if tex.SetBlendMode then
                tex:SetBlendMode("BLEND")
            end
        end
    end
    
    local cooldown = frame.Cooldown or frame.cooldown
    if cooldown then
        local name = frame.GetName and frame:GetName()
        if name and name:find("^uCDMCustomFrame_") then
            cooldown:ClearAllPoints()
            cooldown:SetAllPoints(frame)
            cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8")
            cooldown:SetSwipeColor(0, 0, 0, 0.8)
        end
    end
end

function Styler.ApplyTexCoord(frame)
    if not frame then return end
    
    local z = frame._ucdmZoom or 0
    local aspectRatio = frame._ucdmAspectRatio or 1.0
    
    local iconSize = frame._ucdmIconSize
    if not iconSize then
        local width = frame:GetWidth()
        local height = frame:GetHeight()
        iconSize = math.max(width or CONSTANTS.TEXTURE_SOURCE_SIZE, height or CONSTANTS.TEXTURE_SOURCE_SIZE)
    end
    
    local cropPixels = CONSTANTS.TEXTURE_BASE_CROP_PIXELS
    local sourceSize = CONSTANTS.TEXTURE_SOURCE_SIZE
    local baseCrop = (cropPixels * iconSize) / (sourceSize * sourceSize)
    
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
    
    local size = config.iconSize or config.size
    if not size then
        local width = frame:GetWidth()
        local height = frame:GetHeight()
        size = math.max(width or 40, height or 40)
    end
    
    local aspectRatio = config.aspectRatioCrop or 1.0
    local zoom = config.zoom or 0
    local borderSize = config.iconBorderSize or 0
    local borderColor = config.iconBorderColor or {r = 0, g = 0, b = 0, a = 1}
    
    frame._ucdmZoom = zoom
    frame._ucdmAspectRatio = aspectRatio
    frame._ucdmIconSize = size
    
    Styler.ApplyTexCoord(frame)
    Styler.ApplyBorder(frame, borderSize, borderColor)
    
    local textures = {frame.Icon, frame.icon}
    for _, tex in ipairs(textures) do
        if tex then
            tex:ClearAllPoints()
            tex:SetAllPoints(frame)
            if tex.SetSnapToPixelGrid then
                tex:SetSnapToPixelGrid(false)
            end
            if tex.SetBlendMode then
                tex:SetBlendMode("BLEND")
            end
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
            if not data or not data.config then
                module:LogError("Styler.ProcessPendingStyling: Invalid data for frame")
            else
                local success, err = pcall(function()
                    Styler.SetupIconOnce(frame)
                    Styler.ApplyIconStyleImmediate(frame, data.config)
                end)
                if not success then
                    module:LogError("Styler.ProcessPendingStyling: Error applying styling:", err)
                else
                    frame._ucdmStylingPending = nil
                end
            end
        end
        pendingStyling[frame] = nil
    end
end

local function SetFontStringPoint(fs, point, relativeTo, relativePoint, offsetX, offsetY)
    if not fs or not fs.SetFont then return end
    if not fs.ClearAllPoints or not fs.SetPoint then
        module:LogError("SetFontStringPoint: FontString missing required methods")
        return
    end
    
    fs:ClearAllPoints()
    fs:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
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
                TavernUI:ApplyFont(cooldown.text, frame, durationSize)
                SetFontStringPoint(cooldown.text, durationPoint, frame, durationPoint, durationOffsetX, durationOffsetY)
            end
            local success, regions = pcall(function() return { cooldown:GetRegions() } end)
            if not success then
                module:LogError("Styler.ApplyTextStyle: Failed to get cooldown regions:", regions)
            elseif regions then
                for _, region in ipairs(regions) do
                    if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                        TavernUI:ApplyFont(region, frame, durationSize)
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
                TavernUI:ApplyFont(fs, frame, stackSize)
                SetFontStringPoint(fs, stackPoint, frame, stackPoint, stackOffsetX, stackOffsetY)
            end
        end
        
        local countText = frame.Count or frame.count
        if countText then
            TavernUI:ApplyFont(countText, frame, stackSize)
            SetFontStringPoint(countText, stackPoint, frame, stackPoint, stackOffsetX, stackOffsetY)
        end
    end
end

function Styler.ApplyViewerStyling(viewer, rowDistribution, activeRows, viewerKey, forceImmediate)
    if not viewer or not rowDistribution or not activeRows then return end
    
    local force = forceImmediate or module:IsInInitialPhase()
    
    for rowNum, rowConfig in ipairs(activeRows) do
        local entriesInRow = rowDistribution[rowNum]
        if entriesInRow then
            for _, entry in ipairs(entriesInRow) do
                if entry.frame then
                    Styler.ApplyIconStyle(entry.frame, rowConfig, force)
                    Styler.ApplyTextStyle(entry.frame, rowConfig)
                end
            end
        end
    end
    
    for rowNum, rowConfig in ipairs(activeRows) do
        local borderKey = "__ucdmRowBorder" .. rowNum
        local borderTexture = viewer[borderKey]
        if borderTexture then
            local color = rowConfig.rowBorderColor or {r = 0, g = 0, b = 0, a = 1}
            borderTexture:SetColorTexture(color.r, color.g, color.b, color.a)
        end
    end
end

module.Styler = Styler
