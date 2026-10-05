-- Options panel and slash commands.
return function(sim, t)
    local TAU = sim.env.TankAuditForever
    local db = sim.env.TankAuditForeverDB
    t.ok(db and db.enabled, "SavedVariables initialized")

    sim:Slash("/taudit")
    local panel = sim.env.TankAuditForeverOptionsPanel
    t.ok(panel and panel:IsShown(), "/taudit opens the options panel")
    local w = panel.widgets

    -- Preview icons while the panel is open
    local shown = 0
    for _, b in ipairs(TAU.Bar:GetButtons()) do if b:IsShown() then shown = shown + 1 end end
    t.ok(shown > 0, "bar shows a preview while options are open")

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

    -- Off / on
    sim:Slash("/taudit off")
    t.eq(TAU.isEnabled, false, "/taudit off disables")
    sim:Slash("/taudit on")
    t.eq(TAU.isEnabled, true, "/taudit on enables")
end
