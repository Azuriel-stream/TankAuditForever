local ADDON_NAME, TAU = ...

TAU.DefaultConfig = {
    enabled = true,

    -- Audit bar
    locked = true,
    scale = 1.0,
    point = { "CENTER", "CENTER", 0, -100 }, -- point, relativePoint (on UIParent), x, y

    -- What to check
    checkSelf = true,
    checkGroup = true,
    checkConsumables = true,
    consumableLevel = 1,      -- 1 = Food only, 2 = Food & Elixirs, 3 = Food & Flasks
    checkHealthstone = true,
    checkDebuffs = true,
    checkUnwanted = true,
    gratitude = true,          -- whisper the caster when a requested buff arrives

    -- Combat Watch (in-combat self-buff timers)
    combatWatch = true,
    watchOnlyInCombat = false,
    watchSound = true,
    watchWarnSeconds = 15,
    watchDurations = {},       -- [spellID] = real duration learned out of combat

    -- With N paladins in the group, the first N entries are expected (per tank class).
    blessingPriority = {
        WARRIOR = { "KINGS", "MIGHT", "LIGHT", "WISDOM" },
        PALADIN = { "KINGS", "WISDOM", "MIGHT", "LIGHT" },
    },
}

-- Deep Copy Table Helper
local function CopyTable(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = type(v) == "table" and CopyTable(v) or v
    end
    return copy
end
TAU.CopyTable = CopyTable

-- Merge Defaults recursively without overwriting existing user values
local function MergeDefaults(target, source)
    for k, v in pairs(source) do
        if target[k] == nil then
            target[k] = type(v) == "table" and CopyTable(v) or v
        elseif type(target[k]) == "table" and type(v) == "table" then
            MergeDefaults(target[k], v)
        end
    end
end

function TAU:InitConfig()
    if type(TankAuditForeverDB) ~= "table" then
        TankAuditForeverDB = CopyTable(TAU.DefaultConfig)
    else
        MergeDefaults(TankAuditForeverDB, TAU.DefaultConfig)
    end
    TAU.db = TankAuditForeverDB
end

function TAU:Get(key)
    if TAU.db and TAU.db[key] ~= nil then
        return TAU.db[key]
    end
    return TAU.DefaultConfig[key]
end

function TAU:Set(key, value)
    if TAU.db then
        TAU.db[key] = value
    end
end

function TAU:GetBlessingPriority()
    local class = TAU.playerClass or "WARRIOR"
    local all = TAU.db.blessingPriority
    if not all[class] then
        all[class] = CopyTable(TAU.DefaultConfig.blessingPriority.WARRIOR)
    end
    return all[class]
end

function TAU:MoveBlessing(index, direction)
    local list = TAU:GetBlessingPriority()
    local target = index + direction
    if target < 1 or target > #list then return end
    list[index], list[target] = list[target], list[index]
end
