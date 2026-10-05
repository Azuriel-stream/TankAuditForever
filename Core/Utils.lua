local ADDON_NAME, TAU = ...

local Utils = {}
TAU.Utils = Utils

-- =========================================================================
-- Secret values (kb/restrictions.md). Aura data is secret during combat, encounters, M+ and PvP.
-- =========================================================================
function Utils.IsSecret(val)
    if val == nil then return false end
    if issecretvalue then
        return issecretvalue(val) == true
    end
    -- Fallback for clients without the primitive: secrets error on concatenation
    return not pcall(function() return val .. "" end)
end

function Utils.SafeString(val, fallback)
    if val == nil or Utils.IsSecret(val) or type(val) ~= "string" then
        return fallback
    end
    return val
end

-- Group Composition: "RAID", "PARTY" or "NONE"
function Utils.GetGroupType()
    if IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    end
    return "NONE"
end

-- Iterate a unit's auras. Returns false (and stops) as soon as the data is secret, i.e. restricted.
-- filter: "HELPFUL" or "HARMFUL"
function Utils.ForEachAura(unit, filter, callback)
    for index = 1, 255 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
        if not aura then return true end
        if Utils.IsSecret(aura.spellId) then return false end
        callback(aura)
    end
    return true
end

-- Build a set from a list of IDs (Data tables keep lists for readability)
function Utils.ToSet(list)
    local set = {}
    for _, v in ipairs(list or {}) do set[v] = true end
    return set
end

-- Forever: the global IsPlayerSpell is only a deprecation shim (loaded only with the loadDeprecationFallbacks CVar)
function Utils.IsKnown(spellID)
    return spellID ~= nil and C_SpellBook.IsSpellKnown(spellID) == true
end

-- True if the player knows any rank of the spell
function Utils.KnowsAny(ids)
    for _, id in ipairs(ids or {}) do
        if Utils.IsKnown(id) then return true end
    end
    return false
end

function Utils.SpellName(id)
    return id and C_Spell.GetSpellName(id) or nil
end

function Utils.SpellIcon(id)
    return id and C_Spell.GetSpellTexture(id) or nil
end

function Utils.SpellLink(id, fallbackName)
    local link = id and C_Spell.GetSpellLink(id)
    if link and not Utils.IsSecret(link) then return link end
    return "[" .. (fallbackName or "?") .. "]"
end

function Utils.FormatTime(seconds)
    if seconds >= 3600 then
        return math.ceil(seconds / 3600) .. "h"
    elseif seconds > 60 then
        return math.ceil(seconds / 60) .. "m"
    end
    return tostring(math.max(0, math.ceil(seconds))) .. "s"
end

-- Main-hand temporary enchant (sharpening stone, oil...). Returns hasEnchant, secondsLeft.
-- Forever: C_Item.GetWeaponEnchantInfo(slot) returns a list of WeaponEnchantInfo tables;
-- timeLeft is assumed to be milliseconds like the legacy API [unverified - check /taudit dump].
function Utils.GetMainHandEnchant()
    local slot = Enum.WeaponSlot and Enum.WeaponSlot.MainHand or 0
    local ok, enchants = pcall(C_Item.GetWeaponEnchantInfo, slot)
    if not ok or type(enchants) ~= "table" then return false, 0 end
    for _, info in ipairs(enchants) do
        if info.hasEnchant and not Utils.IsSecret(info.timeLeft) then
            return true, (info.timeLeft or 0) / 1000, info.enchantID
        end
    end
    return false, 0
end

-- "First Last" for Forever characters (surname is UnitName's 2nd return); nil if secret.
function Utils.GetUnitFullName(unit)
    if not unit or not UnitExists(unit) then return nil end
    local name, surname = UnitName(unit)
    name = Utils.SafeString(name, nil)
    surname = Utils.SafeString(surname, nil)
    if name and surname and surname ~= "" then
        return name .. " " .. surname
    end
    return name
end
