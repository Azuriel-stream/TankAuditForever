local ADDON_NAME, TAU = ...

-- Out of combat, decides WHAT the audit bar shows: which tiles (checklist), in which order, and what clicking a
-- missing tile does. Whether each buff is up, and its timer, is drawn live by Blizzard aura slots on the tiles
-- (Modules/Bar.lua), which keeps working in combat. Forever hides aura data from addons in combat, so planning only
-- runs out of combat and the layout freezes during fights (kb/restrictions.md).
local Scanner = TAU:RegisterModule("Scanner")
local Utils, D, L = TAU.Utils, TAU.Data, TAU.L

local frame = CreateFrame("Frame", "TAU_ScannerFrame")
local ticker = nil
local queued = false

-- plan.tiles = ordered list of items: { tileKey, key, label, spellId, messageKey, watchIds,
--                                       action = { type = "spell"|"request"|"bags", spell, unit } }
-- plan.salvation = show the Salvation (cancel) slot
-- plan.dispelActions = { [dispelType] = action } for the debuff tiles to show ("spell" = own dispel, "request" = ask)
Scanner.plan = { tiles = {} }

local function IsStanceActive(spellID)
    for i = 1, GetNumShapeshiftForms() do
        local _, active, _, formSpellID = GetShapeshiftFormInfo(i)
        if active and formSpellID == spellID then return true end
    end
    return false
end

local function MergeIds(a, b)
    local set = Utils.ToSet(a)
    for _, id in ipairs(b or {}) do set[id] = true end
    return set
end

-- Action for a buff the player may be able to cast on themselves
local function CastOrRequest(ids, castId)
    if castId and Utils.IsKnown(castId) then
        return { type = "spell", spell = Utils.SpellName(castId), unit = "player" }
    end
    for _, id in ipairs(ids or {}) do
        if Utils.IsKnown(id) then
            return { type = "spell", spell = Utils.SpellName(id), unit = "player" }
        end
    end
    return { type = "request" }
end

local function SpellItem(tileKey, key, ids, labelKey)
    return {
        tileKey = tileKey,
        key = key,
        label = (labelKey and L[labelKey]) or Utils.SpellName(ids[1]) or key,
        spellId = ids[1],
        messageKey = key,
    }
end

-- Dispel types worth showing, with the click action for each: cast your own dispel if you know one,
-- otherwise ask the group (only if someone in it has the class AND level to remove that type).
local function DispelActions(class, Roster)
    local actions = {}
    for dtype, requirements in pairs(D.DISPEL_LEVELS) do
        for _, id in ipairs((D.PLAYER_DISPELS[class] or {})[dtype] or {}) do
            if Utils.IsKnown(id) then
                actions[dtype] = { type = "spell", spell = Utils.SpellName(id), unit = "player" }
                break
            end
        end
        if not actions[dtype] and Roster:OthersCanDispel(requirements) then
            actions[dtype] = { type = "request" }
        end
    end
    return actions
end

function Scanner:BuildPlan()
    local Roster = TAU.Roster
    Roster:Update()
    local class = TAU.playerClass
    local solo = Roster.isSolo
    local tiles = {}

    -- 1. Self buffs (always, solo too) and stance (groups only, when not in it)
    if TAU:Get("checkSelf") then
        for _, def in ipairs(D.SELF[class] or {}) do
            if def.stance then
                if not (def.skipSolo and solo) and Utils.IsKnown(def.stance) and not IsStanceActive(def.stance) then
                    local item = SpellItem("SELF:" .. def.key, def.key, { def.stance })
                    item.action = { type = "spell", spell = Utils.SpellName(def.stance) }
                    tiles[#tiles + 1] = item
                end
            elseif not def.requireKnown or Utils.KnowsAny(def.ids) then
                local item = SpellItem("SELF:" .. def.key, def.key, def.ids)
                item.action = CastOrRequest(def.ids)
                tiles[#tiles + 1] = item
            end
        end
    end

    if not solo then
        -- 2. Group buffs from classes present
        if TAU:Get("checkGroup") then
            for _, def in ipairs(D.GROUP) do
                if Roster:Count(def.provider, def.subgroupOnly) > 0 and not (def.skipFor and def.skipFor[class]) then
                    local item = SpellItem("GROUP:" .. def.key, def.key, def.ids, def.label)
                    item.action = CastOrRequest(def.ids, def.castId)
                    item.watchIds = MergeIds(def.ids, def.greater)
                    tiles[#tiles + 1] = item
                end
            end

            -- Paladin blessings: the top N of the priority list, N = paladins in the group
            local priority = TAU:GetBlessingPriority()
            for i = 1, math.min(Roster:Count("PALADIN"), #priority) do
                local def = D.BLESSINGS[priority[i]]
                if def then
                    local item = SpellItem("BLESSING:" .. priority[i], priority[i], def.ids)
                    item.action = CastOrRequest(def.ids)
                    item.watchIds = MergeIds(def.ids, def.greater)
                    tiles[#tiles + 1] = item
                end
            end
        end

        -- 3. Consumables
        if TAU:Get("checkConsumables") then
            local function Consumable(key)
                tiles[#tiles + 1] = { tileKey = "CONS:" .. key, key = key, label = L[key], action = { type = "bags" } }
            end
            Consumable("WELL_FED")
            local level = TAU:Get("consumableLevel")
            if level == 2 then Consumable("ELIXIR") elseif level == 3 then Consumable("FLASK") end
            Consumable("WEAPON_BUFF")
        end
    end

    -- 4. Healthstone: only when a warlock (other than you) is around and you carry none
    if TAU:Get("checkHealthstone") and Roster:CountOthers("WARLOCK") > 0 then
        local carried = 0
        for _, itemID in ipairs(D.HEALTHSTONES) do
            carried = carried + (C_Item.GetItemCount(itemID) or 0)
        end
        if carried == 0 then
            tiles[#tiles + 1] = { tileKey = "HEALTHSTONE", key = "HEALTHSTONE", label = L["HEALTHSTONE"],
                messageKey = "HEALTHSTONE", action = { type = "request" } }
        end
    end

    return {
        tiles = tiles,
        salvation = TAU:Get("checkUnwanted"),
        dispelActions = TAU:Get("checkDebuffs") and DispelActions(class, Roster) or {},
    }
end

function Scanner:Scan()
    if not TAU.isEnabled or InCombatLockdown() then return end

    -- Gratitude needs the (readable, out-of-combat) aura list
    local helpful = {}
    if not Utils.ForEachAura("player", "HELPFUL", function(aura) helpful[#helpful + 1] = aura end) then
        return -- restricted right now; keep the current plan
    end

    self.plan = self:BuildPlan()
    TAU.Gratitude:Check(helpful)
    TAU.Bar:Apply(self.plan)
end

-- Coalesce bursts of events into one scan
function Scanner:Queue()
    if queued then return end
    queued = true
    C_Timer.After(0.2, function()
        queued = false
        Scanner:Scan()
    end)
end

-- /taudit dump: everything needed to verify spell IDs in Data/Buffs.lua
function Scanner:Dump()
    if InCombatLockdown() then
        TAU:Print(L["IN_COMBAT_LATER"])
        return
    end
    TAU:Print(L["DUMP_HEADER"])
    local now = GetTime()
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
        Utils.ForEachAura("player", filter, function(a)
            local source = a.sourceUnit and Utils.GetUnitFullName(a.sourceUnit) or "-"
            local left = (a.expirationTime and a.expirationTime > 0) and Utils.FormatTime(a.expirationTime - now) or "-"
            TAU:Print("%s %d  %s  src:%s  %s%s", filter == "HARMFUL" and "|cffFF4444DEBUFF|r" or "buff",
                a.spellId, tostring(a.name), source, left, a.dispelName and ("  type:" .. a.dispelName) or "")
        end)
    end
    local slot = Enum.WeaponSlot and Enum.WeaponSlot.MainHand or 0
    local ok, enchants = pcall(C_Item.GetWeaponEnchantInfo, slot)
    if ok and type(enchants) == "table" then
        for _, e in ipairs(enchants) do
            TAU:Print("weapon enchant: has=%s timeLeft(raw)=%s enchantID=%s", tostring(e.hasEnchant),
                tostring(e.timeLeft), tostring(e.enchantID))
        end
    end
    for i = 1, GetNumShapeshiftForms() do
        local _, active, _, spellID = GetShapeshiftFormInfo(i)
        TAU:Print("stance %d: spellID=%s active=%s", i, tostring(spellID), tostring(active))
    end
end

local function OnEvent()
    if not InCombatLockdown() then
        Scanner:Queue()
    end
end

function Scanner:OnEnable()
    frame:RegisterUnitEvent("UNIT_AURA", "player")
    frame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_EQUIPMENT_CHANGED",
        "BAG_UPDATE_DELAYED", "SPELLS_CHANGED", "UPDATE_SHAPESHIFT_FORM", "PLAYER_REGEN_ENABLED",
        "PLAYER_ENTERING_WORLD" }) do
        frame:RegisterEvent(event)
    end
    frame:SetScript("OnEvent", OnEvent)
    if ticker then ticker:Cancel() end
    -- Periodic replan (stance, bags, roster changes without events)
    ticker = C_Timer.NewTicker(3, function()
        if not InCombatLockdown() then Scanner:Scan() end
    end)
    self:Queue()
end

function Scanner:OnDisable()
    frame:UnregisterAllEvents()
    frame:SetScript("OnEvent", nil)
    if ticker then ticker:Cancel(); ticker = nil end
    self.plan = { tiles = {} }
end
