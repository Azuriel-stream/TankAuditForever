local ADDON_NAME, TAU = ...

_G["TankAuditForever"] = TAU

TAU.name = ADDON_NAME
TAU.version = "2.0.0"
TAU.modules = {}
TAU.moduleOrder = {}
TAU.isInitialized = false
TAU.isEnabled = false

-- Tank classes this version supports. Class data lives in Data/Buffs.lua; Druid and Shaman can be
-- added there once Forever confirms how they tank.
TAU.SUPPORTED_CLASSES = { WARRIOR = true, PALADIN = true }

local eventFrame = CreateFrame("Frame", "TAU_EventFrame")

-- Security Action Interceptor: records blocked/forbidden actions for /taudit debug
local securityFrame = CreateFrame("Frame", "TAU_SecurityFrame")
pcall(securityFrame.RegisterEvent, securityFrame, "ADDON_ACTION_BLOCKED")
pcall(securityFrame.RegisterEvent, securityFrame, "ADDON_ACTION_FORBIDDEN")
securityFrame:SetScript("OnEvent", function(self, event, addonName, functionName)
    if addonName ~= ADDON_NAME then return end
    local stack = (debugstack and debugstack(2, 8, 8)) or "No stack available"
    if TankAuditForeverDB then
        TankAuditForeverDB._lastBlockedEvent = event
        TankAuditForeverDB._lastBlockedFunction = functionName
        TankAuditForeverDB._lastBlockedStack = stack
    end
end)

function TAU:Print(msg, ...)
    if select("#", ...) > 0 then
        msg = string.format(msg, ...)
    end
    print("|cff00FF7F[TankAudit]|r " .. tostring(msg))
end

-- Module Registration (initialized/enabled in registration order)
function TAU:RegisterModule(name)
    local module = { name = name }
    TAU.modules[name] = module
    TAU[name] = module
    table.insert(TAU.moduleOrder, name)
    return module
end

local function CallModules(method)
    for _, name in ipairs(TAU.moduleOrder) do
        local mod = TAU.modules[name]
        if type(mod[method]) == "function" then
            local ok, err = pcall(mod[method], mod)
            if not ok then
                TAU:Print("|cffFF4444Error in %s:%s:|r %s", name, method, tostring(err))
            end
        end
    end
end

function TAU:IsSupportedClass()
    return TAU.SUPPORTED_CLASSES[TAU.playerClass] == true
end

-- Lifecycle Management
function TAU:Enable()
    if TAU.isEnabled or not TAU:IsSupportedClass() then return end
    TAU.isEnabled = true
    TAU.db.enabled = true
    CallModules("OnEnable")
    TAU:Print(TAU.L["ADDON_ENABLED"])
end

function TAU:Disable()
    if not TAU.isEnabled then return end
    TAU.isEnabled = false
    TAU.db.enabled = false
    CallModules("OnDisable")
    TAU:Print(TAU.L["ADDON_DISABLED"])
end

local function OnEvent(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if not TAU.isInitialized then
            TAU.isInitialized = true
            TAU:InitConfig()
            CallModules("OnInitialize")
        end
        eventFrame:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        TAU.playerClass = class
        eventFrame:UnregisterEvent("PLAYER_LOGIN")

        if not TAU:IsSupportedClass() then
            TAU:Print(TAU.L["CLASS_NOT_SUPPORTED"], tostring(class))
            return
        end
        CallModules("OnLogin")
        if TAU.db.enabled then
            TAU.isEnabled = true
            CallModules("OnEnable")
        end
        TAU:Print(TAU.L["ADDON_LOADED"], TAU.version)
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", OnEvent)
