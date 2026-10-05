local ADDON_NAME, TAU = ...

-- Spell/item IDs for WoW: Forever 1.60.1, collected from Wowhead's Forever database (tools/wowhead.ps1).
-- Auras carry the ID of the rank that was cast, so every rank is listed. Verify with /taudit dump.
-- Display names come from the client (C_Spell.GetSpellName) unless an entry sets `label` (a locale key).

TAU.Data = {}
local D = TAU.Data

-- Self buffs per tank class. `stance` = shapeshift spellID that must be active instead of an aura.
-- `knownIds` = only check when the player knows any of these spells. `skipSolo` = ignore when ungrouped.
D.SELF = {
    WARRIOR = {
        { key = "BATTLE_SHOUT", ids = { 6673, 5242, 6192, 11549, 11550, 11551, 25289, 27578 }, warn = 15, requireKnown = true },
        { key = "DEFENSIVE_STANCE", stance = 71, skipSolo = true },
    },
    PALADIN = {
        { key = "RIGHTEOUS_FURY", ids = { 25780 }, warn = 60, requireKnown = true },
    },
}

-- Combat Watch: self buffs kept visible IN COMBAT through a Blizzard aura container (exact timer) plus a cast-based
-- estimate for the audio warning (kb/addons/TankAudit.md). `duration` = fallback until the real one is learned.
D.WATCH = {
    WARRIOR = {
        { key = "BATTLE_SHOUT", ids = { 6673, 5242, 6192, 11549, 11550, 11551, 25289, 27578 },
          icon = "Interface\\Icons\\Ability_Warrior_BattleShout", duration = 180 },
    },
    PALADIN = {
        { key = "RIGHTEOUS_FURY", ids = { 25780 },
          icon = "Interface\\Icons\\Spell_Holy_SealOfFury", duration = 1800 },
    },
}

-- Group buffs from other classes. Checked only when a `provider` class is in the group
-- (`subgroupOnly`: in your raid subgroup). `skipFor` = tank classes that don't need it.
-- `greater` = group/greater versions that also satisfy the buff.
D.GROUP = {
    { key = "FORTITUDE", provider = "PRIEST",
      ids = { 1243, 1244, 1245, 2791, 10937, 10938 }, greater = { 21562, 21564 } },
    { key = "SPIRIT", provider = "PRIEST",
      ids = { 14752, 14818, 14819, 27841 }, greater = { 27681 } },
    { key = "MARK_OF_THE_WILD", provider = "DRUID",
      ids = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 1291335, 1310503 }, greater = { 21849, 21850 } },
    { key = "THORNS", provider = "DRUID",
      ids = { 467, 782, 1075, 8914, 9756, 9910 } },
    { key = "ARCANE_INTELLECT", provider = "MAGE", skipFor = { WARRIOR = true },
      ids = { 1459, 1460, 1461, 10156, 10157 }, greater = { 23028 } },
    { key = "BATTLE_SHOUT", provider = "WARRIOR", subgroupOnly = true, skipFor = { WARRIOR = true },
      ids = { 6673, 5242, 6192, 11549, 11550, 11551, 25289, 27578 } },
    { key = "PALADIN_AURA", provider = "PALADIN", subgroupOnly = true, label = "PALADIN_AURA",
      castId = 465, -- Devotion Aura: what a paladin tank casts when no aura is up
      ids = { 465, 643, 1032, 10290, 10291, 10292, 10293,   -- Devotion
              7294, 10298, 10299, 10300, 10301,             -- Retribution
              19746,                                        -- Concentration
              19876, 19895, 19896,                          -- Shadow Resistance
              19888, 19897, 19898,                          -- Frost Resistance
              19891, 19899, 19900 } },                      -- Fire Resistance
}

-- Paladin blessings, ordered by the user's priority list (Config.blessingPriority).
-- Blessing of Sanctuary isn't in Forever (Wowhead); Kings is baseline (not a talent) on Forever.
D.BLESSINGS = {
    KINGS  = { ids = { 20217 }, greater = { 25898 } },
    MIGHT  = { ids = { 19740, 19834, 19835, 19836, 19837, 19838, 25291 }, greater = { 25782, 25916 } },
    LIGHT  = { ids = { 19977, 19978, 19979 }, greater = { 25890 } },
    WISDOM = { ids = { 19742, 19850, 19852, 19853, 19854, 25290 }, greater = { 25894, 25918 } },
}

-- Buffs a tank wants removed (shown as click-to-cancel).
D.UNWANTED = {
    { key = "SALVATION", ids = { 1038, 25895 } },
}

-- Consumables (checked only in groups)
D.WELL_FED = { 19705, 19706, 19708, 19709, 19710, 19711, 24799, 24870, 25694, 25941,
               1225778, 1225779, 1225780, 1225782, 1248406, 1248420, 1248421, 1248422, 1248688,
               1249519, 1249520, 1249521, 1249523, 1249907, 1249926, 1249927, 1283082, 1294007,
               1302064, 1319310 }
-- Battle/guardian elixirs useful to tanks (buff spell IDs, not item IDs). Incomplete by nature:
-- add IDs from /taudit dump. 11405 (Elixir of the Giants) is from Vanilla data [unverified].
D.ELIXIRS = { 17538, 11348, 3593, 11405, 17537, 11334, 11371, 17539, 24382, 16323 }
D.FLASKS = { 17626, 17627, 17628, 17629, 17624, 1293740, 1293741, 1293742, 1293743 }

D.HEALTHSTONES = { 5512, 19004, 19005, 5511, 19006, 19007, 5509, 19008, 19009,
                   5510, 19010, 19011, 9421, 19012, 19013 }

-- Fallback icons for category entries
D.ICONS = {
    WELL_FED = "Interface\\Icons\\Spell_Misc_Food",
    WEAPON_BUFF = "Interface\\Icons\\INV_Stone_SharpeningStone_01",
    ELIXIR = "Interface\\Icons\\INV_Potion_32",
    FLASK = "Interface\\Icons\\INV_Potion_62",
    HEALTHSTONE = "Interface\\Icons\\INV_Stone_04",
    UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark",
}

-- Which classes can remove each debuff type
D.DISPEL_CLASSES = {
    Magic   = { PRIEST = true, PALADIN = true },
    Curse   = { MAGE = true, DRUID = true },
    Poison  = { DRUID = true, PALADIN = true, SHAMAN = true },
    Disease = { PRIEST = true, PALADIN = true, SHAMAN = true },
}

-- The player's own dispels per debuff type (first known spell is cast)
D.PLAYER_DISPELS = {
    PALADIN = {
        Magic   = { 4987 },          -- Cleanse
        Poison  = { 4987, 1152 },    -- Cleanse, Purify
        Disease = { 4987, 1152 },
    },
    WARRIOR = {},
}
