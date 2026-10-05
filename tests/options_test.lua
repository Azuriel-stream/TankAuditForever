-- Options panel and slash commands.
return function(sim, t)
    local TAU = sim.env.TankAuditForever
    local db = sim.env.TankAuditForeverDB
    t.ok(db and db.enabled, "SavedVariables initialized")

    sim:Slash("/tau")
    local panel = sim.env.TankAuditForeverOptionsPanel
    t.ok(panel and panel:IsShown(), "/tau opens the options panel")
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

    -- Consumables: "+ Elixir" / "+ Flask" on top of food, at most one (a dropdown menu crashed the beta client)
    w.consumables[2]:Click()
    t.eq(db.consumableLevel, 2, "+ Elixir selected")
    w.consumables[3]:Click()
    t.eq(db.consumableLevel, 3, "+ Flask selected")
    t.ok(w.consumables[3]:GetChecked() and not w.consumables[2]:GetChecked(), "only one add-on checked")
    w.consumables[3]:Click()
    t.eq(db.consumableLevel, 1, "unchecking it means food only")
    t.ok(not w.consumables[2]:GetChecked() and not w.consumables[3]:GetChecked(), "both unchecked")
    w.consumables[3]:Click()
    for _, f in ipairs(sim.frames) do
        t.ok(f._type ~= "DropdownButton", "no Blizzard menu dropdowns in TankAudit")
    end

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
