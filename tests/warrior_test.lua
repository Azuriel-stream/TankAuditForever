-- Warrior tank: checklist tiles, Blizzard slots, clicks, gratitude, combat freeze.
local H = require("helpers")

return function(sim, t)
    -- Solo, Battle Shout not learned: nothing to check
    t.eq(#H.Shown(sim), 0, "solo warrior without Battle Shout shows nothing")

    local w = t.fresh(function(s)
        H.Party(s)
        s.known[6673] = true                         -- Battle Shout
        s.known[71] = true                           -- Defensive Stance (known, not active)
        s.forms = { { spellID = 2457, active = true }, { spellID = 71, active = false } }
    end)
    H.Rescan(w)

    -- Checklist contents and order (self buffs first)
    local keys = H.Keys(w)
    t.eq(H.Shown(w)[1].item.tileKey, "SELF:BATTLE_SHOUT", "self buff first: " .. keys)
    for _, key in ipairs({ "SELF:DEFENSIVE_STANCE", "GROUP:FORTITUDE", "GROUP:SPIRIT", "GROUP:PALADIN_AURA",
                           "BLESSING:KINGS", "CONS:WELL_FED", "CONS:WEAPON_BUFF" }) do
        t.ok(H.Find(w, key), key .. " expected in: " .. keys)
    end
    for _, key in ipairs({ "GROUP:ARCANE_INTELLECT", "GROUP:BATTLE_SHOUT", "BLESSING:MIGHT", "HEALTHSTONE", "CONS:FLASK" }) do
        t.ok(not H.Find(w, key), key .. " not expected in: " .. keys)
    end

    -- Battle Shout tile: casts when clicked (missing), Blizzard slot filtered to every rank, red under 15 s
    local bs = H.Find(w, "SELF:BATTLE_SHOUT")
    t.eq(bs:GetAttribute("type"), "spell", "Battle Shout tile casts")
    t.eq(bs:GetAttribute("spell"), "Battle Shout", "casts Battle Shout")
    bs:Click()
    t.eq(w.casts[#w.casts].spell, "Battle Shout", "secure cast performed (down-click)")
    local slot = H.Container(w, bs)._slots.tile
    t.ok(slot._options.candidateFilters.includeSpellIDs[6192], "slot includes Battle Shout rank 3")
    t.eq(slot._filter, "HELPFUL", "slot shows helpful auras")
    local curve = slot._SetDurationText.options.textColor.curve
    t.eq(curve.points[2].x, 15, "countdown turns red at 15 s")

    -- Elixir tile covers Forever's renamed/new elixirs ([in-game] dump: 673 = Elixir of Minor Defense)
    w.env.TankAuditForeverDB.consumableLevel = 2
    H.Rescan(w)
    local elixirSlot = H.Container(w, w.env.TankAuditForever.Bar:GetTile("CONS:ELIXIR"))._slots.tile
    local elixirIds = elixirSlot._options.candidateFilters.includeSpellIDs
    t.ok(elixirIds[673] and elixirIds[1250920] and elixirIds[17538], "elixir tile: Minor Defense, Phalanx, Mongoose")
    t.ok(not elixirIds[7178], "utility draughts (water breathing) don't count as an elixir")
    w.env.TankAuditForeverDB.consumableLevel = 1
    H.Rescan(w)

    -- Weapon tile uses Blizzard's item-enchant display, sized by us
    local weapon = H.Find(w, "CONS:WEAPON_BUFF")
    local enchant = H.Container(w, weapon)._enchant
    t.ok(enchant and enchant._enchantSlot == 0, "weapon tile shows the main-hand enchant")

    -- Checklist: a present buff keeps its tile (Blizzard draws it lit on top)
    table.insert(w.units.player.auras, H.Aura(6192, "Battle Shout", { duration = 180, expirationTime = w.now + 180 }))
    H.Rescan(w)
    t.ok(H.Find(w, "SELF:BATTLE_SHOUT"), "present buff stays on the checklist")

    -- Group buff tile: click asks the party; throttled; gratitude whisper when it arrives
    local fort = H.Find(w, "GROUP:FORTITUDE")
    t.eq(fort:GetAttribute("type"), nil, "request tiles have no secure action")
    fort:Click()
    local req = t.contains(w.chat, "Fortitude", "request sent")
    t.eq(req.channel, "PARTY", "request goes to party")
    t.eq(#w.chat, 1, "one click sends one message (hook acts on the up half only)")
    fort:Click()
    t.eq(#w.chat, 1, "requests are throttled")
    table.insert(w.units.player.auras, H.Aura(1243, "Power Word: Fortitude", { sourceUnit = "party1",
        expirationTime = w.now + 3600, duration = 3600 }))
    H.Rescan(w)
    local thanks = w.chat[#w.chat]
    t.eq(thanks.channel, "WHISPER", "gratitude is a whisper")
    t.eq(thanks.target, "Lumen Brightwater", "whispers the caster by full Forever name")

    -- Top row: Salvation watch + one debuff tile per type the group can remove (priest: Magic/Disease, paladin: +Poison)
    local Bar = w.env.TankAuditForever.Bar
    t.ok(Bar:GetSalvationHolder():IsShown(), "Salvation slot watched")
    for _, dtype in ipairs({ "Magic", "Disease", "Poison" }) do
        t.ok(Bar:GetDebuffTile(dtype):IsShown(), dtype .. " debuff tile shown")
    end
    t.ok(not Bar:GetDebuffTile("Curse"):IsShown(), "nobody removes curses -> no Curse tile")
    local poison = Bar:GetDebuffTile("Poison")
    t.ok(not poison.bg:IsShown(), "empty debuff tile is invisible (no square) when not previewing")
    local poisonSlot = H.Container(w, poison)._slots.debuff
    t.ok(poisonSlot._options.candidateFilters.includeDispelTypes.Poison, "Blizzard slot shows Poison debuffs")
    -- Blizzard's debuff button swallows clicks, so our catcher sits on top and asks for a dispel
    t.eq(poison.catcher:GetAttribute("type"), nil, "warrior can't dispel: catcher requests")
    local chatBefore = #w.chat
    poison.catcher:Click()
    t.eq(#w.chat, chatBefore + 1, "one dispel request per click")
    t.ok(w.chat[#w.chat].msg:find("Poison"), "request names the dispel type")

    -- Combat freezes the layout: roster change in combat applies afterwards, with no protected changes
    local before = H.Keys(w)
    w:EnterCombat()
    w.units.party3 = { name = "Fern", surname = "Oakhollow", class = "DRUID", guid = "Player-1-00000004",
                       friendly = true, level = 60, auras = {} }
    w:Fire("GROUP_ROSTER_UPDATE")
    w:Advance(5)
    t.eq(H.Keys(w), before, "layout frozen in combat")
    -- Unlocking (or opening options) mid-fight requests a preview layout directly: it must wait for combat to end
    w:Slash("/taudit unlock")
    w:Slash("/taudit")
    t.eq(#w.violations, 0, "no protected-frame changes in combat")
    w:Slash("/taudit")
    w:Slash("/taudit lock")
    w:LeaveCombat()
    w:Advance(1)
    t.ok(H.Find(w, "GROUP:MARK_OF_THE_WILD"), "druid's Mark of the Wild tile appears after combat")
    t.ok(Bar:GetDebuffTile("Curse"):IsShown(), "level 60 druid adds a Curse tile after combat")

    -- Dispel levels: a level 15 paladin (Purify at 8, Cleanse at 42) covers Poison/Disease but not Magic
    local low = t.fresh(function(s)
        H.Party(s)
        s.units.party1 = s.units.party2     -- the paladin is the only party member (slots are contiguous in-game)
        s.units.party2 = nil
        s.units.party1.level = 15           -- low-level paladin
    end)
    H.Rescan(low)
    local LB = low.env.TankAuditForever.Bar
    t.ok(LB:GetDebuffTile("Poison"):IsShown() and LB:GetDebuffTile("Disease"):IsShown(), "level 15 paladin: Poison/Disease")
    t.ok(not LB:GetDebuffTile("Magic"):IsShown(), "level 15 paladin can't Cleanse yet: no Magic tile")
end
