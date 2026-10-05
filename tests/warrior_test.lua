-- Warrior tank in a party with a priest and a paladin.
local H = require("helpers")

return function(sim, t)
    -- Solo, no target: nothing to show
    t.eq(#H.Shown(sim), 0, "solo warrior without a hostile target shows nothing")

    local w = t.fresh(function(s)
        H.Party(s)
        s.known[6673] = true                         -- Battle Shout
        s.known[71] = true                           -- Defensive Stance (known, not active)
        s.forms = { { spellID = 2457, active = true }, { spellID = 71, active = false } }
    end)
    H.Rescan(w)

    local bs = H.Find(w, "Battle Shout")
    t.ok(bs, "missing Battle Shout is shown: " .. H.Labels(w))
    t.eq(bs.entry.kind, "missing", "Battle Shout is missing")
    t.eq(bs:GetAttribute("type"), "spell", "Battle Shout button casts")
    t.eq(bs:GetAttribute("spell"), "Battle Shout", "casts Battle Shout")
    t.ok(bs.icon:IsDesaturated(), "missing buffs are desaturated")

    local stance = H.Find(w, "Defensive Stance")
    t.ok(stance and stance:GetAttribute("spell") == "Defensive Stance", "inactive Defensive Stance is shown and castable")

    t.ok(H.Find(w, "Power Word: Fortitude"), "priest in group -> Fortitude expected")
    t.ok(H.Find(w, "Divine Spirit"), "priest in group -> Divine Spirit expected")
    t.ok(H.Find(w, "Blessing of Kings"), "1 paladin -> first blessing (Kings) expected")
    t.ok(not H.Find(w, "Blessing of Might"), "only one blessing with one paladin")
    t.ok(H.Find(w, "Paladin Aura"), "paladin in group -> aura expected")
    t.ok(H.Find(w, "Well Fed") and H.Find(w, "Weapon Buff"), "consumables checked in groups")
    t.ok(not H.Find(w, "Healthstone"), "no warlock -> no healthstone check")

    -- Clicking a group buff asks in party chat (no secure action)
    local fort = H.Find(w, "Power Word: Fortitude")
    t.eq(fort:GetAttribute("type"), nil, "request buttons have no secure action")
    fort:Click()
    local req = t.contains(w.chat, "Fortitude", "request sent")
    t.eq(req.channel, "PARTY", "request goes to party")

    -- Throttle: a second click right away is refused
    fort:Click()
    t.eq(#w.chat, 1, "requests are throttled")

    -- The priest buffs us -> whisper thanks to the caster
    table.insert(w.units.player.auras, H.Aura(1243, "Power Word: Fortitude", { sourceUnit = "party1",
        expirationTime = w.now + 3600, duration = 3600 }))
    H.Rescan(w)
    local thanks = w.chat[#w.chat]
    t.eq(thanks.channel, "WHISPER", "gratitude is a whisper")
    t.eq(thanks.target, "Lumen Brightwater", "whispers the caster by full Forever name")
    t.ok(thanks.msg:find("Lumen"), "thanks mentions the caster's first name")
    t.ok(not H.Find(w, "Power Word: Fortitude"), "Fortitude no longer missing")

    -- Clicking Battle Shout performs the secure cast
    bs = H.Find(w, "Battle Shout")
    bs:Click()
    t.eq(w.casts[#w.casts].spell, "Battle Shout", "secure button cast Battle Shout")

    -- Expiring group buff (under 60 s) gets a countdown
    w.units.player.auras[1].expirationTime = w.now + 30
    H.Rescan(w)
    local expiring = H.Find(w, "Power Word: Fortitude")
    t.eq(expiring and expiring.entry.kind, "expiring", "Fortitude under 60 s is expiring")
    t.ok(expiring.timer:GetText():find("s"), "countdown text shown")

    -- Combat freezes the bar: no protected changes, no errors, state kept
    local before = #H.Shown(w)
    w:EnterCombat()
    table.insert(w.units.player.auras, H.Aura(25289, "Battle Shout", { expirationTime = w.now + 180 }))
    H.Rescan(w)
    w:Advance(5)
    t.eq(#H.Shown(w), before, "bar is frozen in combat")
    t.eq(#w.violations, 0, "no protected-frame changes in combat")
    w:LeaveCombat()
    w:Advance(1)
    t.ok(not H.Find(w, "Battle Shout"), "after combat the bar catches up (Battle Shout now present)")
end
