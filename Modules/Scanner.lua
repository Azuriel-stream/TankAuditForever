local ADDON_NAME, TAU = ...

-- Builds the audit state from the player's auras, group, gear and bags.
-- Forever: aura data is secret in combat (kb/restrictions.md), so scanning runs only out of combat and the bar keeps
-- its last pre-combat state while fighting.
local Scanner = TAU:RegisterModule("Scanner")
local Utils, D, L = TAU.Utils, TAU.Data, TAU.L

local frame = CreateFrame("Frame", "TAU_ScannerFrame")
local ticker = nil
local queued = false

local GROUP_WARN = 60        -- seconds before a group buff counts as expiring
local CONSUMABLE_WARN = 60

-- state.top = debuffs / unwanted buffs, state.bottom = missing + expiring buffs
Scanner.state = { top = {}, bottom = {} }

-- Entry: { key, kind = "missing"|"expiring"|"debuff"|"unwanted", label, icon, spellId, expiresAt,
--          messageKey, watchIds, dispelType, action = { type = "spell"|"cancelaura"|"request"|"bags", spell, unit } }

local function ReadAuras(filter)
    local list, byId = {}, {}
    local ok = Utils.ForEachAura("player", filter, function(aura)
        list[#list + 1] = aura
        byId[aura.spellId] = byId[aura.spellId] or aura
    end)
    return ok, list, byId
end

local function FindAura(byId, ...)
    for i = 1, select("#", ...) do
        local ids = select(i, ...)
        for _, id in ipairs(ids or {}) do
            if byId[id] then return byId[id] end
        end
    end
    return nil
end

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
local function CastOrRequest(castIds, castId)
    if castId and Utils.IsKnown(castId) then
        return { type = "spell", spell = Utils.SpellName(castId), unit = "player" }
    end
    for _, id in ipairs(castIds or {}) do
        if Utils.IsKnown(id) then
            return { type = "spell", spell = Utils.SpellName(id), unit = "player" }
        end
    end
    return { type = "request" }
end

-- Adds a missing or expiring entry for a buff definition
local function Evaluate(list, aura, warn, entry)
    local now = GetTime()
    if not aura then
        entry.kind = "missing"
        list[#list + 1] = entry
    elseif aura.expirationTime and aura.expirationTime > 0 and (aura.expirationTime - now) < warn then
        entry.kind = "expiring"
        entry.expiresAt = aura.expirationTime
        list[#list + 1] = entry
    end
end

local function SpellEntry(key, ids, labelKey)
    return {
        key = key,
        label = (labelKey and L[labelKey]) or Utils.SpellName(ids[1]) or key,
        icon = Utils.SpellIcon(ids[1]) or D.ICONS.UNKNOWN,
        spellId = ids[1],
        messageKey = key,
    }
end

function Scanner:Scan()
    if not TAU.isEnabled then return end
    if InCombatLockdown() then return end

    local okHelp, helpful, helpById = ReadAuras("HELPFUL")
    local okHarm, harmful = ReadAuras("HARMFUL")
    if not okHelp or not okHarm then return end -- restricted right now; keep the previous state

    local Roster = TAU.Roster
    Roster:Update()
    local class = TAU.playerClass
    local solo = Roster.isSolo
    local top, selfMissing, bottom = {}, {}, {}

    -- 1. Self buffs / stance
    if TAU:Get("checkSelf") then
        for _, def in ipairs(D.SELF[class] or {}) do
            if def.stance then
                if not (def.skipSolo and solo) and Utils.IsKnown(def.stance) and not IsStanceActive(def.stance) then
                    local entry = SpellEntry(def.key, { def.stance })
                    entry.kind = "missing"
                    entry.action = { type = "spell", spell = Utils.SpellName(def.stance) }
                    selfMissing[#selfMissing + 1] = entry
                end
            elseif not def.requireKnown or Utils.KnowsAny(def.ids) then
                local entry = SpellEntry(def.key, def.ids)
                entry.action = CastOrRequest(def.ids)
                Evaluate(selfMissing, FindAura(helpById, def.ids), def.warn or 15, entry)
            end
        end
    end

    -- 2. Group buffs from classes present in the group
    if TAU:Get("checkGroup") and not solo then
        for _, def in ipairs(D.GROUP) do
            local present = Roster:Count(def.provider, def.subgroupOnly) > 0
            if present and not (def.skipFor and def.skipFor[class]) then
                local entry = SpellEntry(def.key, def.ids, def.label)
                entry.action = CastOrRequest(def.ids, def.castId)
                entry.watchIds = MergeIds(def.ids, def.greater)
                Evaluate(bottom, FindAura(helpById, def.ids, def.greater), GROUP_WARN, entry)
            end
        end

        -- Paladin blessings: the top N of the priority list, N = paladins in the group
        local paladins = Roster:Count("PALADIN")
        local priority = TAU:GetBlessingPriority()
        for i = 1, math.min(paladins, #priority) do
            local key = priority[i]
            local def = D.BLESSINGS[key]
            if def then
                local entry = SpellEntry(key, def.ids)
                entry.action = CastOrRequest(def.ids)
                entry.watchIds = MergeIds(def.ids, def.greater)
                Evaluate(bottom, FindAura(helpById, def.ids, def.greater), GROUP_WARN, entry)
            end
        end
    end

    -- 3. Consumables (groups only)
    if TAU:Get("checkConsumables") and not solo then
        local function Category(key, aura, iconKey)
            local entry = { key = key, label = L[key], icon = D.ICONS[iconKey or key], action = { type = "bags" } }
            Evaluate(bottom, aura, CONSUMABLE_WARN, entry)
        end

        local fed = FindAura(helpById, D.WELL_FED)
        if not fed then
            for _, aura in ipairs(helpful) do
                if aura.name == L["WELL_FED"] then fed = aura break end
            end
        end
        Category("WELL_FED", fed)

        local hasEnchant, secondsLeft = Utils.GetMainHandEnchant()
        local weaponAura = nil
        if hasEnchant then
            -- expirationTime 0 = present without a known expiry
            weaponAura = { expirationTime = secondsLeft > 0 and (GetTime() + secondsLeft) or 0 }
        end
        Category("WEAPON_BUFF", weaponAura)

        local level = TAU:Get("consumableLevel")
        if level == 2 then
            Category("ELIXIR", FindAura(helpById, D.ELIXIRS))
        elseif level == 3 then
            Category("FLASK", FindAura(helpById, D.FLASKS))
        end
    end

    -- 4. Healthstone (a warlock other than you is in the group)
    if TAU:Get("checkHealthstone") and Roster:CountOthers("WARLOCK") > 0 then
        local carried = 0
        for _, itemID in ipairs(D.HEALTHSTONES) do
            carried = carried + (C_Item.GetItemCount(itemID) or 0)
        end
        if carried == 0 then
            bottom[#bottom + 1] = { key = "HEALTHSTONE", kind = "missing", label = L["HEALTHSTONE"],
                icon = D.ICONS.HEALTHSTONE, messageKey = "HEALTHSTONE", action = { type = "request" } }
        end
    end

    -- 5. Unwanted buffs (click to cancel)
    if TAU:Get("checkUnwanted") then
        for _, def in ipairs(D.UNWANTED) do
            local aura = FindAura(helpById, def.ids)
            if aura then
                top[#top + 1] = { key = def.key, kind = "unwanted", label = aura.name, icon = aura.icon,
                    spellId = aura.spellId, action = { type = "cancelaura", spell = aura.name } }
            end
        end
    end

    -- 6. Debuffs that you or your group can dispel
    if TAU:Get("checkDebuffs") then
        local ownDispels = D.PLAYER_DISPELS[class] or {}
        for _, aura in ipairs(harmful) do
            local dtype = Utils.SafeString(aura.dispelName, nil)
            local classes = dtype and D.DISPEL_CLASSES[dtype]
            if classes then
                local action
                for _, id in ipairs(ownDispels[dtype] or {}) do
                    if Utils.IsKnown(id) then
                        action = { type = "spell", spell = Utils.SpellName(id), unit = "player" }
                        break
                    end
                end
                if not action then
                    for dispelClass in pairs(classes) do
                        if Roster:CountOthers(dispelClass) > 0 then action = { type = "request" } break end
                    end
                end
                if action then
                    top[#top + 1] = { key = "DEBUFF", kind = "debuff", label = aura.name, icon = aura.icon,
                        spellId = aura.spellId, dispelType = dtype, action = action }
                end
            end
        end
    end

    -- 7. Smart visibility: solo, show buff reminders only when about to fight (hostile target + missing self buffs)
    local hostileTarget = UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
    local showBuffs = not solo or (hostileTarget and #selfMissing > 0)
    if showBuffs then
        for i = #selfMissing, 1, -1 do table.insert(bottom, 1, selfMissing[i]) end
    else
        bottom = {}
    end

    self.state = { top = top, bottom = bottom }
    TAU.Gratitude:Check(helpful)
    TAU.Bar:Render(self.state)
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

local function OnEvent(self, event, arg1)
    if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
        Scanner:Queue()
    elseif not InCombatLockdown() then
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
    -- Periodic rescan so "expiring" thresholds are crossed without an event
    ticker = C_Timer.NewTicker(3, function()
        if not InCombatLockdown() then Scanner:Scan() end
    end)
    self:Queue()
end

function Scanner:OnDisable()
    frame:UnregisterAllEvents()
    frame:SetScript("OnEvent", nil)
    if ticker then ticker:Cancel(); ticker = nil end
    self.state = { top = {}, bottom = {} }
end
