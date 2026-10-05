-- Options panel and slash commands.
return function(sim, t)
    local TAU = sim.env.TankAuditForever
    local db = sim.env.TankAuditForeverDB
    t.ok(db and db.enabled, "SavedVariables initialized")

    sim:Slash("/taudit")
    local panel = sim.env.TankAuditForeverOptionsPanel
    t.ok(panel and panel:IsShown(), "/taudit opens the options panel")
    local w = panel.widgets

    -- Preview: every tile is shown while the panel is open
    local shown, total = 0, #TAU.Bar:GetTiles()
    for _, tile in ipairs(TAU.Bar:GetTiles()) do if tile:IsShown() then shown = shown + 1 end end
    t.ok(total > 0 and shown == total, "all tiles previewed while options are open")
    local poisonTile = TAU.Bar:GetDebuffTile("Poison")
    t.ok(poisonTile:IsShown() and poisonTile.bg:IsShown(), "debuff tile squares visible in preview")

    -- Sound warning checkbox
    w.watch.watchSound:Click()
    t.eq(db.watchSound, false, "sound warning toggles")

    -- Checkboxes write settings
    w.checks.checkHealthstone:Click()
    t.eq(db.checkHealthstone, false, "healthstone checkbox toggles")

    -- Consumable dropdown
    for _, item in ipairs(w.consumables._menuItems) do
        if item.data == 3 then item.Pick() end
    end
    t.eq(db.consumableLevel, 3, "consumable mode saved")

    -- Scale slider (percent)
    w.scale.Slider:SetValue(150)
    t.eq(db.scale, 1.5, "scale saved as a factor")

    -- Blessing priority: move the 2nd up
    local before = { db.blessingPriority.WARRIOR[1], db.blessingPriority.WARRIOR[2] }
    panel.widgets.blessings[2].up:Click()
    t.eq(db.blessingPriority.WARRIOR[1], before[2], "priority moved up")
    t.eq(db.blessingPriority.WARRIOR[2], before[1], "priority swapped")

    -- Unlock / lock via slash
    sim:Slash("/taudit unlock")
    t.eq(db.locked, false, "/taudit unlock")
    sim:Slash("/taudit lock")
    t.eq(db.locked, true, "/taudit lock")

    -- Closing the options window ends the preview: squares hidden again
    sim:Slash("/taudit")
    t.ok(not panel:IsShown(), "options closed")
    t.ok(not poisonTile.bg:IsShown(), "debuff tile squares hidden after preview")

    -- Off / on
    sim:Slash("/taudit off")
    t.eq(TAU.isEnabled, false, "/taudit off disables")
    sim:Slash("/taudit on")
    t.eq(TAU.isEnabled, true, "/taudit on enables")
end
