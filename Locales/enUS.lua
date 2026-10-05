local ADDON_NAME, TAU = ...

local L = TAU:NewLocale("enUS")
if not L then return end

-- General & Addon Info
L["ADDON_TITLE"] = "TankAudit Forever"
L["ADDON_LOADED"] = "v%s loaded. Type |cffFFFFFF/taudit|r for options."
L["ADDON_ENABLED"] = "|cff00FF00Enabled.|r"
L["ADDON_DISABLED"] = "|cffFF4444Disabled.|r"
L["CLASS_NOT_SUPPORTED"] = "|cffFF4444%s is not supported yet (Warrior and Paladin tanks only).|r"
L["BAR_LOCKED"] = "Bar locked."
L["BAR_UNLOCKED"] = "Bar unlocked - drag it, then |cffFFFFFF/taudit lock|r."
L["BAR_RESET"] = "Bar position reset."
L["BAR_DRAG_HINT"] = "TankAudit - drag me"
L["IN_COMBAT_LATER"] = "In combat - the bar will update after combat."
L["UNKNOWN_COMMAND"] = "Unknown command. Type |cffFFFFFF/taudit help|r."
L["HELP"] = "Commands: |cffFFFFFF/taudit|r (options), lock, unlock, reset, scan, dump, status, debug, on, off"

-- Categories (spell-based entries use the client's localized spell names instead)
L["WELL_FED"] = "Well Fed"
L["WEAPON_BUFF"] = "Weapon Buff"
L["ELIXIR"] = "Elixir"
L["FLASK"] = "Flask"
L["HEALTHSTONE"] = "Healthstone"
L["PALADIN_AURA"] = "Paladin Aura"

-- Button hints
L["HINT_CAST"] = "Click to cast."
L["HINT_REQUEST"] = "Click to ask your group for it."
L["HINT_CANCEL"] = "Click to cancel this buff."
L["HINT_DISPEL_SELF"] = "Click to dispel it."
L["HINT_DISPEL_REQUEST"] = "Click to ask your group to dispel it."
L["HINT_BAGS"] = "Click to open your bags."
L["HINT_EXPIRES"] = "Expires in %s."
L["HINT_MISSING"] = "Missing."
L["PREVIEW"] = "Preview"

-- Local (chat frame) hints
L["MSG_LOCAL_FOOD"] = "You need to eat! Check your bags."
L["MSG_LOCAL_WEAPON"] = "Your weapon needs a Sharpening Stone, Weightstone or Oil!"
L["MSG_LOCAL_ELIXIR"] = "You need an Elixir! Check your bags."
L["MSG_LOCAL_FLASK"] = "You need a Flask! Check your bags."
L["MSG_WAIT_THROTTLE"] = "Wait a few seconds before asking again."
L["MSG_SOLO"] = "You're not in a group - nobody to ask."

-- Group messages
L["MSG_NEED_DISPEL"] = "I have %s (%s) - dispel me please!"
L["MSG_NEED_HS"] = "I need a Healthstone please!"
L["MSG_EXPIRING_SUFFIX"] = " (fading in %s)"

-- Options
L["OPT_ENABLE_ADDON"] = "Enable TankAudit"
L["OPT_ENABLE_ADDON_DESC"] = "Master switch for scanning and the audit bar."
L["UI_SECTION_BAR"] = "Audit Bar"
L["OPT_LOCK"] = "Lock bar"
L["OPT_LOCK_DESC"] = "Uncheck to drag the bar to a new position."
L["OPT_RESET"] = "Reset Position"
L["OPT_SCALE"] = "Scale (%)"
L["UI_SECTION_CHECKS"] = "What to Check"
L["OPT_SELF"] = "Self buffs & stance"
L["OPT_SELF_DESC"] = "Your own buffs: Battle Shout and Defensive Stance, or Righteous Fury."
L["OPT_GROUP"] = "Group buffs"
L["OPT_GROUP_DESC"] = "Buffs from classes in your group: Fortitude, Spirit, Mark of the Wild, Intellect, Battle Shout, blessings, auras."
L["OPT_CONSUMABLES"] = "Consumables (in groups)"
L["OPT_CONSUMABLES_DESC"] = "Well Fed, weapon buff, and optionally elixirs or flasks."
L["OPT_HEALTHSTONE"] = "Healthstone"
L["OPT_HEALTHSTONE_DESC"] = "Warn when a warlock is in the group and you carry no Healthstone."
L["OPT_DEBUFFS"] = "Dispellable debuffs"
L["OPT_DEBUFFS_DESC"] = "Show debuffs you or your group can dispel (out of combat only on Forever)."
L["OPT_UNWANTED"] = "Unwanted buffs"
L["OPT_UNWANTED_DESC"] = "Show Blessing of Salvation with a click-to-cancel button."
L["OPT_GRATITUDE"] = "Whisper thanks"
L["OPT_GRATITUDE_DESC"] = "When a buff you asked for arrives, whisper the caster a thank-you."
L["CONS_FOOD"] = "Food only"
L["CONS_ELIXIR"] = "Food & Elixirs"
L["CONS_FLASK"] = "Food & Flasks"
L["UI_SECTION_BLESSINGS"] = "Blessing Priority"
L["UI_BLESSINGS_NOTE"] = "With N paladins in the group, the top N blessings are expected."
L["UI_SECTION_WATCH"] = "Combat Watch"
L["OPT_WATCH"] = "Show Combat Watch"
L["OPT_WATCH_DESC"] = "Battle Shout / Righteous Fury icon with a live timer that keeps working in combat (red near expiry; dimmed red icon when missing)."
L["OPT_WATCH_COMBAT"] = "Only in combat"
L["OPT_WATCH_COMBAT_DESC"] = "Hide the Combat Watch icons while out of combat (the audit bar covers that)."
L["OPT_WATCH_SOUND"] = "Sound + glow warning"
L["OPT_WATCH_SOUND_DESC"] = "In combat, play a warning sound and glow the icon when the buff has about 15 seconds left (timed from your last cast)."
L["BTN_UP"] = "Up"
L["BTN_DOWN"] = "Down"
L["BTN_SCAN"] = "Scan Now"
L["BTN_DUMP"] = "Dump Auras"

-- Status / dump
L["STATUS_HEADER"] = "|cff00FF7F--- TankAudit Forever Status ---|r"
L["DUMP_HEADER"] = "|cff00FF7F--- Player auras (spellID / name / source / remaining) ---|r"
