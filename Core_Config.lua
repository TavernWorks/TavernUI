-- TavernUI Core_Config.lua
-- Centralized configuration manager with change callbacks, validation, and deep table initialization

local AceAddon = LibStub("AceAddon-3.0")
local TavernUI = AceAddon:GetAddon("TavernUI")

local type = type
local pairs = pairs
local ipairs = ipairs
local string = string
local table = table

local CURRENT_CONFIG_VERSION = 1

local Config = {}
Config.callbacks = {}
Config.callbackIdCounter = 0

function Config:Debug(...)
    if TavernUI.db and TavernUI.db.profile.general.debug then
        TavernUI:Print("|cff999999[Config]|r", ...)
    end
end

function Config:OnInitialize()
    self.db = TavernUI.db
    self:CheckVersion()
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
    self:Debug("Config manager initialized")
end

function Config:CheckVersion()
    if not self.db.global.configVersion or self.db.global.configVersion ~= CURRENT_CONFIG_VERSION then
        self:Debug("Config version mismatch detected. Resetting to defaults.")
        self.db:ResetDB()
        self.db.global.configVersion = CURRENT_CONFIG_VERSION
        TavernUI:Print("|cffff0000Configuration reset to defaults due to version change.|r")
    end
end

function Config:OnProfileChanged()
    self.callbacks = {}
    self.callbackIdCounter = 0
    self:Debug("Profile changed - cleared all callbacks")
end

local function ParsePath(path)
    if type(path) ~= "string" then
        return nil, "Path must be a string"
    end
    
    if not path:match("^TUI%.") then
        return nil, "Path must start with 'TUI.'"
    end
    
    local parts = {}
    local current = ""
    local inBrackets = false
    
    for i = 1, #path do
        local char = path:sub(i, i)
        
        if char == "[" then
            if current ~= "" then
                table.insert(parts, current)
                current = ""
            end
            inBrackets = true
            current = current .. char
        elseif char == "]" then
            current = current .. char
            table.insert(parts, current)
            current = ""
            inBrackets = false
        elseif char == "." and not inBrackets then
            if current ~= "" then
                table.insert(parts, current)
                current = ""
            end
        else
            current = current .. char
        end
    end
    
    if current ~= "" then
        table.insert(parts, current)
    end
    
    if #parts < 2 then
        return nil, "Path must have at least TUI.ModuleName"
    end
    
    if parts[1] ~= "TUI" then
        return nil, "Path must start with 'TUI.'"
    end
    
    return parts
end

local function ResolvePath(parts)
    if not parts or #parts < 2 then
        return nil
    end
    
    local moduleName = parts[2]
    if not moduleName then
        return nil
    end
    
    local db = TavernUI.db
    if not db or not db.profile then
        return nil
    end
    
    local current = db.profile[moduleName]
    if not current then
        return nil
    end
    
    for i = 3, #parts do
        local part = parts[i]
        if not part then
            break
        end
        
        local key
        if part:match("^%[.*%]$") then
            local index = tonumber(part:match("%[(%d+)%]"))
            if index then
                key = index
            else
                return nil
            end
        else
            key = part
        end
        
        if type(current) ~= "table" then
            return nil
        end
        
        current = current[key]
        if current == nil then
            return nil
        end
    end
    
    return current
end

local function EnsurePath(parts, createTables)
    if not parts or #parts < 2 then
        return false
    end
    
    local moduleName = parts[2]
    if not moduleName then
        return false
    end
    
    local db = TavernUI.db
    if not db or not db.profile then
        return false
    end
    
    if not db.profile[moduleName] then
        if createTables then
            db.profile[moduleName] = {}
        else
            return false
        end
    end
    
    local current = db.profile[moduleName]
    local parent = db.profile
    
    for i = 3, #parts do
        local part = parts[i]
        if not part then
            break
        end
        
        local key
        if part:match("^%[.*%]$") then
            local index = tonumber(part:match("%[(%d+)%]"))
            if index then
                key = index
            else
                return false
            end
        else
            key = part
        end
        
        if type(current) ~= "table" then
            if createTables then
                current = {}
                parent[moduleName] = current
            else
                return false
            end
        end
        
        if current[key] == nil then
            if createTables then
                current[key] = {}
            else
                return false
            end
        end
        
        parent = current
        moduleName = key
        current = current[key]
    end
    
    return true
end

local function GetParentAndKey(parts)
    if not parts or #parts < 2 then
        return nil, nil
    end
    
    local moduleName = parts[2]
    local db = TavernUI.db
    if not db or not db.profile then
        return nil, nil
    end
    
    if not db.profile[moduleName] then
        db.profile[moduleName] = {}
    end
    
    if #parts == 2 then
        return db.profile, moduleName
    end
    
    local current = db.profile[moduleName]
    local parent = db.profile[moduleName]
    local prevKey = moduleName
    
    for i = 3, #parts - 1 do
        local part = parts[i]
        if not part then
            break
        end
        
        local partKey
        if part:match("^%[.*%]$") then
            local index = tonumber(part:match("%[(%d+)%]"))
            if index then
                partKey = index
            else
                return nil, nil
            end
        else
            partKey = part
        end
        
        if type(current) ~= "table" then
            current = {}
            parent[prevKey] = current
        end
        
        if current[partKey] == nil then
            current[partKey] = {}
        end
        
        parent = current
        prevKey = partKey
        current = current[partKey]
    end
    
    local lastPart = parts[#parts]
    local key
    if lastPart:match("^%[.*%]$") then
        local index = tonumber(lastPart:match("%[(%d+)%]"))
        if index then
            key = index
        else
            return nil, nil
        end
    else
        key = lastPart
    end
    
    if type(current) ~= "table" then
        current = {}
        parent[prevKey] = current
    end
    
    return current, key
end

local function ValidateValue(value, options)
    if not options then
        return true, nil
    end
    
    if options.type then
        local valueType = type(value)
        if valueType ~= options.type then
            return false, string.format("Expected type %s, got %s", options.type, valueType)
        end
    end
    
    if options.type == "number" then
        if options.min and value < options.min then
            return false, string.format("Value %s is below minimum %s", value, options.min)
        end
        if options.max and value > options.max then
            return false, string.format("Value %s is above maximum %s", value, options.max)
        end
    end
    
    if options.validate and type(options.validate) == "function" then
        local valid, err = options.validate(value)
        if not valid then
            return false, err or "Validation failed"
        end
    end
    
    return true, nil
end

function Config:Get(path, defaultValue)
    local parts, err = ParsePath(path)
    if not parts then
        self:Debug("Get failed:", err or "Invalid path", path)
        return defaultValue
    end
    
    local value = ResolvePath(parts)
    if value == nil then
        return defaultValue
    end
    
    return value
end

function Config:Set(path, value, options)
    local parts, err = ParsePath(path)
    if not parts then
        self:Debug("Set failed:", err or "Invalid path", path)
        return false
    end
    
    if options then
        local valid, errMsg = ValidateValue(value, options)
        if not valid then
            self:Debug("Validation failed for", path, ":", errMsg)
            if options.fallback ~= nil then
                value = options.fallback
            else
                return false
            end
        end
    end
    
    local parent, key = GetParentAndKey(parts)
    if not parent or not key then
        self:Debug("Set failed: Could not resolve path", path)
        return false
    end
    
    local oldValue = parent[key]
    
    if oldValue == value then
        return true
    end
    
    parent[key] = value
    
    self:FireCallbacks(path, value, oldValue)
    
    if options and options.callback and type(options.callback) == "function" then
        options.callback(value, oldValue)
    end
    
    return true
end

function Config:EnsurePath(path)
    local parts, err = ParsePath(path)
    if not parts then
        self:Debug("EnsurePath failed:", err or "Invalid path", path)
        return false
    end
    
    return EnsurePath(parts, true)
end

function Config:RegisterChangeCallback(path, callback)
    if type(path) ~= "string" then
        self:Debug("RegisterChangeCallback failed: path must be a string")
        return nil
    end
    
    if type(callback) ~= "function" then
        self:Debug("RegisterChangeCallback failed: callback must be a function")
        return nil
    end
    
    local parts, err = ParsePath(path)
    if not parts then
        self:Debug("RegisterChangeCallback failed:", err or "Invalid path", path)
        return nil
    end
    
    self.callbackIdCounter = self.callbackIdCounter + 1
    local id = self.callbackIdCounter
    
    if not self.callbacks[path] then
        self.callbacks[path] = {}
    end
    
    self.callbacks[path][id] = callback
    
    self:Debug("Registered callback", id, "for path", path)
    
    return id
end

function Config:UnregisterChangeCallback(path, id)
    if not self.callbacks[path] then
        return false
    end
    
    if self.callbacks[path][id] then
        self.callbacks[path][id] = nil
        if not next(self.callbacks[path]) then
            self.callbacks[path] = nil
        end
        return true
    end
    
    return false
end

function Config:FireCallbacks(path, newValue, oldValue)
    if not self.callbacks[path] then
        return
    end
    
    for id, callback in pairs(self.callbacks[path]) do
        local success, err = pcall(callback, newValue, oldValue)
        if not success then
            self:Debug("Callback error for", path, ":", err)
        end
    end
end

function Config:GetModulePath(moduleName)
    return "TUI." .. moduleName
end

TavernUI.Config = Config
