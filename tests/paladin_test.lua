-- Paladin tank: self-castable buffs, Salvation cancel, own dispel, unsupported classes.
local H = require("helpers")

return function(sim, t)
    local p = t.fresh(function(s)
        s.units.player.class = "PALADIN"
        H.Party(s)
        s.known[25780] = true   -- Righteous Fury
        s.known[465] = true     -- Devotion Aura
        s.known[20217] = true   -- Blessing of Kings
        s.known[4987] = true    -- Cleanse
    end)
    H.Rescan(p)

    local rf = H.Find(p, "Righteous Fury")
    t.ok(rf and rf:GetAttribute("spell") == "Righteous Fury", "missing Righteous Fury is castable: " .. H.Labels(p))

    local aura = H.Find(p, "Paladin Aura")
    t.ok(aura and aura:GetAttribute("spell") == "Devotion Aura", "paladin casts Devotion Aura itself")

    -- Two paladins (player + party2): the paladin priority list starts Kings, Wisdom
    local kings = H.Find(p, "Blessing of Kings")
    t.ok(kings and kings:GetAttribute("type") == "spell", "Kings is self-castable")
    t.ok(H.Find(p, "Blessing of Wisdom"), "second paladin -> second blessing (Wisdom)")
    t.ok(not H.Find(p, "Battle Shout"), "no warrior in group -> no Battle Shout")

    -- Unwanted Salvation: click cancels it (secure cancelaura)
    table.insert(p.units.player.auras, H.Aura(1038, "Blessing of Salvation", { expirationTime = p.now + 3600 }))
    -- A dispellable debuff the paladin can Cleanse
    table.insert(p.units.player.auras, H.Aura(18267, "Curse of Weakness", { isHarmful = true, dispelName = "Curse" }))
    table.insert(p.units.player.auras, H.Aura(17228, "Shadow Bolt Volley", { isHarmful = true, dispelName = "Magic" }))
    H.Rescan(p)

    local salv = H.Find(p, "Blessing of Salvation")
    t.ok(salv and salv.entry.kind == "unwanted", "Salvation shown as unwanted")
    t.eq(salv:GetAttribute("type"), "cancelaura", "Salvation button cancels the aura")
    salv:Click()
    t.eq(p.casts[#p.casts].cancel, "Blessing of Salvation", "secure cancel performed")
    H.Rescan(p)
    t.ok(not H.Find(p, "Blessing of Salvation"), "Salvation gone after cancel")

    local magic = H.Find(p, "Shadow Bolt Volley")
    t.ok(magic and magic:GetAttribute("spell") == "Cleanse", "paladin dispels Magic with Cleanse")
    t.ok(not H.Find(p, "Curse of Weakness"), "curse hidden: nobody in the group can remove it")

    -- Unsupported class: no bar, a clear message
    local mage = t.fresh(function(s) s.units.player.class = "MAGE" end)
    t.contains(mage.output, "not supported", "unsupported class is told so")
    t.eq(#H.Shown(mage), 0, "no bar for unsupported classes")
end
