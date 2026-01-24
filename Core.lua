-- TavernUI Core.lua
-- Main addon logic for TavernUI

local TavernUI = _G.TavernUI
if not TavernUI then return end

local AF = TavernUI.AF

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function TavernUI:Initialize()
    -- Print welcome message
    print(string.format("|cff00ff00TavernUI|r v%s loaded!", self.version))
    
    -- Initialize configuration
    self:InitializeConfig()
    
    -- Initialize modules
    self:InitializeModules()
    
    -- Register events
    self:RegisterEvents()
    
    -- Create slash commands
    self:RegisterSlashCommands()
    
    -- Fire initialization complete event
    self:Fire("TAVERNUI_INITIALIZED")
end

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

function TavernUI:InitializeConfig()
    -- Initialize saved variables
    if not TavernUIConfig then
        TavernUIConfig = {
            enabled = true,
            -- Add your default config values here
        }
    end
    
    self.config = TavernUIConfig
end

-------------------------------------------------------------------------------
-- Modules
-------------------------------------------------------------------------------

function TavernUI:InitializeModules()
    -- Initialize your modules here
    -- Example: self:InitializeModule("ExampleModule")
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

function TavernUI:RegisterEvents()
    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(self, event, ...)
        if TavernUI[event] then
            TavernUI[event](TavernUI, ...)
        end
    end)
    
    -- Register events you need
    -- frame:RegisterEvent("PLAYER_LOGIN")
    -- frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    self.eventFrame = frame
end

-- Event handlers
function TavernUI:PLAYER_LOGIN()
    -- Called when player logs in
end

function TavernUI:PLAYER_ENTERING_WORLD()
    -- Called when entering world
end

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------

function TavernUI:RegisterSlashCommands()
    _G["SLASH_TAVERNUI1"] = "/tui"
    
    SlashCmdList.TAVERNUI = function(msg)
        self:HandleSlashCommand(msg)
    end
end

function TavernUI:HandleSlashCommand(msg)
    local command = string.lower(msg:match("^%s*(%S*)") or "")
    
    if command == "" or command == "help" then
        self:PrintHelp()
    elseif command == "config" then
        -- Open config
        print("|cff00ff00TavernUI|r: Configuration panel (coming soon)")
    elseif command == "reload" then
        ReloadUI()
    else
        print(string.format("|cff00ff00TavernUI|r: Unknown command '%s'. Type /tui help for commands.", command))
    end
end

function TavernUI:PrintHelp()
    print("|cff00ff00TavernUI|r Commands:")
    print("  /tui - Show this help")
    print("  /tui config - Open configuration")
    print("  /tui reload - Reload UI")
end

-------------------------------------------------------------------------------
-- Utility Functions
-------------------------------------------------------------------------------

function TavernUI:Print(msg)
    print(string.format("|cff00ff00TavernUI|r: %s", tostring(msg)))
end

function TavernUI:Fire(event, ...)
    -- Fire custom events if needed
    -- You can extend this to use a callback system
end
