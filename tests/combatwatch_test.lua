-- Combat Watch: Blizzard aura slot setup + cast-based warning in combat.
local H = require("helpers")

return function(sim, t)
    local TAU = sim.env.TankAuditForever
    local entries = TAU.CombatWatch:GetEntries()
    t.eq(#entries, 1, "warrior watches one buff")
    local e = entries[1]
    t.eq(e.def.key, "BATTLE_SHOUT", "warrior watches Battle Shout")

    -- The Blizzard slot is filtered to every Battle Shout rank on the player's helpful auras
    local container
    for _, f in ipairs(sim.frames) do
        if f._type == "AuraContainer" then container = f end
    end
    t.ok(container, "aura container created")
    t.eq(container._unit, "player", "container watches the player")
    local slot = container._slots.BATTLE_SHOUT
    t.eq(slot._filter, "HELPFUL", "slot filters helpful auras")
    t.ok(slot._options.candidateFilters.includeSpellIDs[6192], "slot includes Battle Shout rank 3")
    t.ok(slot._SetIcon and slot._SetDurationText and slot._SetDurationCooldown, "icon, countdown and sweep configured")
    t.ok(#slot._SetDurationText.options.textColor.curve.points >= 3, "countdown color curve configured")

    -- Out of combat: learns the real duration and exact expiry from the readable aura
    table.insert(sim.units.player.auras, H.Aura(6192, "Battle Shout", { duration = 180, expirationTime = sim.now + 170 }))
    sim:Advance(1)
    t.eq(TAU.db.watchDurations[6192], 180, "real duration learned out of combat")
    t.ok(e.expiresAt and math.abs(e.expiresAt - (sim.now + 169)) < 1, "exact expiry synced out of combat")

    -- In combat the aura is secret; the estimate keeps counting and warns at 15 s
    sim:EnterCombat()
    sim:Advance(150)
    t.eq(#sim.sounds, 0, "no warning while plenty of time is left")
    sim:Advance(10)
    t.eq(#sim.sounds, 1, "warning sound at ~15 s left")
    t.ok(e.glow:IsShown(), "glow shown")
    sim:Advance(3)
    t.eq(#sim.sounds, 1, "warning plays once, not every tick")

    -- Recasting in combat restarts the estimate from the cast (own casts aren't secret)
    sim:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1-1-1-6192-01", 6192)
    t.ok(not e.glow:IsShown(), "recast clears the glow")
    t.ok(math.abs(e.expiresAt - (sim.now + 180)) < 0.01, "estimate restarted with the learned duration")
    sim:Advance(170)
    t.eq(#sim.sounds, 2, "warns again before the recast buff runs out")

    -- Leaving combat hides the glow
    sim:LeaveCombat()
    sim:Advance(1)
    t.ok(not e.glow:IsShown(), "glow hidden out of combat")
    t.eq(#sim.violations, 0, "no protected-frame violations")

    -- Only-in-combat visibility uses alpha
    TAU:Set("watchOnlyInCombat", true)
    TAU.CombatWatch:UpdateVisibility()
    t.eq(TAU.CombatWatch:GetRow():GetAlpha(), 0, "hidden out of combat")
    sim:EnterCombat()
    t.eq(TAU.CombatWatch:GetRow():GetAlpha(), 1, "shown in combat")
    sim:LeaveCombat()

    -- Paladin watches Righteous Fury
    local p = t.fresh(function(s) s.units.player.class = "PALADIN" end)
    local pe = p.env.TankAuditForever.CombatWatch:GetEntries()
    t.eq(pe[1] and pe[1].def.key, "RIGHTEOUS_FURY", "paladin watches Righteous Fury")
end
