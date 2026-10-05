-- Shared setup for TankAuditForever wowsim tests (loaded by the *_test.lua files via dofile).
local H = {}

H.SPELLS = {
    [6673] = "Battle Shout", [71] = "Defensive Stance", [25780] = "Righteous Fury",
    [1243] = "Power Word: Fortitude", [14752] = "Divine Spirit", [20217] = "Blessing of Kings",
    [19740] = "Blessing of Might", [19977] = "Blessing of Light", [19742] = "Blessing of Wisdom",
    [465] = "Devotion Aura", [1038] = "Blessing of Salvation", [4987] = "Cleanse",
}

-- Party: player + priest (party1) + paladin (party2), target a hostile mob
function H.Party(sim)
    for id, name in pairs(H.SPELLS) do sim.spells[id] = name end
    sim.units.party2 = { name = "Aldric", surname = "Dawnward", class = "PALADIN", guid = "Player-1-00000003",
                         friendly = true, level = 60, auras = {} }
    sim.group = "party"
end

function H.Aura(spellId, name, opts)
    local a = { spellId = spellId, name = name, icon = 136000, expirationTime = 0, duration = 0 }
    for k, v in pairs(opts or {}) do a[k] = v end
    return a
end

-- Rescan and let the coalescing timer fire
function H.Rescan(sim)
    sim:Fire("UNIT_AURA", "player", { isFullUpdate = true })
    sim:Advance(1)
end

function H.Shown(sim)
    local TAU = sim.env.TankAuditForever
    local out = {}
    for _, b in ipairs(TAU.Bar:GetButtons()) do
        if b:IsShown() and b.entry then out[#out + 1] = b end
    end
    return out
end

function H.Find(sim, label)
    for _, b in ipairs(H.Shown(sim)) do
        if b.entry.label == label then return b end
    end
end

function H.Labels(sim)
    local out = {}
    for _, b in ipairs(H.Shown(sim)) do out[#out + 1] = b.entry.label .. ":" .. b.entry.kind end
    return table.concat(out, ", ")
end

return H
