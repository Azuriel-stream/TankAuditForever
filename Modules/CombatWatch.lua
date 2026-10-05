local ADDON_NAME, TAU = ...

-- Combat Watch: keeps self buffs (Battle Shout / Righteous Fury) trackable IN COMBAT, where Forever hides aura data.
--   Display: a Blizzard CustomAuraContainer slot per buff. Blizzard renders icon, countdown (red under the warning
--            threshold via a color curve) and sweep from the real aura, even while it's secret. Under it sits our own
--            "missing" placeholder, visible whenever the slot is empty.
--   Alert:   our own casts aren't secret, so a cast-based estimate (last cast + learned duration) drives a sound and
--            a red glow at the threshold. Verified in-game 2026-10-05 (kb/addons/TankAudit.md).
-- Aura buttons accept layout calls only until PLAYER_LOGIN, so everything is built at ADDON_LOADED (OnInitialize).
local Watch = TAU:RegisterModule("CombatWatch")
local D = TAU.Data

local ICON_SIZE = 36
local SPACING = 6

local row          -- our frame holding the watch icons (anchored above the audit bar)
local entries = {} -- { def, idSet, holder, glow, expiresAt, warned }
local ticker = nil

local function WarnSeconds() return TAU:Get("watchWarnSeconds") or 15 end

local function BuildCountdownCurve()
    local warn = WarnSeconds()
    local curve = C_CurveUtil.CreateColorCurve()
    curve:AddPoint(0, CreateColor(1, 0.15, 0.15, 1))
    curve:AddPoint(warn, CreateColor(1, 0.15, 0.15, 1))
    curve:AddPoint(warn + 0.5, CreateColor(1, 1, 1, 1))
    curve:AddPoint(86400, CreateColor(1, 1, 1, 1))
    return curve
end

-- One watched buff: placeholder (ours) + Blizzard aura slot on top + our alert glow above both
local function BuildEntry(def, index)
    local holder = CreateFrame("Frame", "TAU_Watch" .. index, row)
    holder:SetSize(ICON_SIZE, ICON_SIZE)
    holder:SetPoint("LEFT", row, "LEFT", (index - 1) * (ICON_SIZE + SPACING), 0)

    local missing = holder:CreateTexture(nil, "BACKGROUND")
    missing:SetAllPoints()
    missing:SetTexture(def.icon)
    missing:SetDesaturated(true)
    missing:SetVertexColor(1, 0.35, 0.35)

    local idSet = {}
    for _, id in ipairs(def.ids) do idSet[id] = true end

    local container = CreateFrame("AuraContainer", nil, holder, "CustomAuraContainerTemplate")
    container:SetAllPoints(holder)
    container:SetUnit("player")
    local slot = container:AddAuraSlot(def.key, "HELPFUL", { candidateFilters = { includeSpellIDs = idSet } })
    slot:SetAllPoints(holder)

    local icon = slot:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    slot:SetIcon(icon)

    local cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetHideCountdownNumbers(true)
    slot:SetDurationCooldown(cooldown)

    local text = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
    text:SetPoint("CENTER", slot, "CENTER", 0, 0)
    slot:SetDurationText(text, {
        textColor = { curve = BuildCountdownCurve(), property = Enum.DurationTextBindingProperty.RemainingDuration },
    })

    -- Alert glow: our own frame layered above the Blizzard slot
    local glowFrame = CreateFrame("Frame", nil, holder)
    glowFrame:SetAllPoints()
    glowFrame:SetFrameLevel(holder:GetFrameLevel() + 10)
    local glow = glowFrame:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("TOPLEFT", -6, 6)
    glow:SetPoint("BOTTOMRIGHT", 6, -6)
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.1, 0.1)
    glow:Hide()

    return { def = def, idSet = idSet, holder = holder, glow = glow, expiresAt = nil, warned = false }
end

-- Out of combat the aura is readable: learn the real duration and the exact expiry.
local function SyncFromAuras()
    for _, e in ipairs(entries) do
        e.expiresAt = nil
        for _, id in ipairs(e.def.ids) do
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
            if aura and not TAU.Utils.IsSecret(aura.expirationTime) then
                if aura.duration and aura.duration > 0 then
                    TAU.db.watchDurations[id] = aura.duration
                end
                e.expiresAt = (aura.expirationTime and aura.expirationTime > 0) and aura.expirationTime or nil
                break
            end
        end
    end
end

local function Alert(e)
    e.warned = true
    e.glow:Show()
    if TAU:Get("watchSound") then
        PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
    end
end

local function Tick()
    if not InCombatLockdown() then
        SyncFromAuras()
    end
    local now, warn = GetTime(), WarnSeconds()
    for _, e in ipairs(entries) do
        local left = e.expiresAt and (e.expiresAt - now)
        local inWindow = left ~= nil and left <= warn
        if inWindow and InCombatLockdown() and not e.warned then
            Alert(e)
        elseif not inWindow then
            e.warned = false
            e.glow:Hide()
        end
        if not InCombatLockdown() then e.glow:Hide() end
    end
end

-- Own casts are readable in combat: restart the estimate from the cast.
function Watch:OnSpellCast(spellID)
    if TAU.Utils.IsSecret(spellID) then return end
    for _, e in ipairs(entries) do
        if e.idSet[spellID] then
            local duration = TAU.db.watchDurations[spellID] or e.def.duration
            e.expiresAt = GetTime() + duration
            e.warned = false
            e.glow:Hide()
        end
    end
end

function Watch:UpdateVisibility()
    if not row then return end
    local visible = TAU.isEnabled and TAU:Get("combatWatch")
    if visible and TAU:Get("watchOnlyInCombat") and not InCombatLockdown() then visible = false end
    -- Alpha, not Show/Hide: the row contains Blizzard aura frames, which must not be toggled in combat
    row:SetAlpha(visible and 1 or 0)
end

local eventFrame = CreateFrame("Frame", "TAU_CombatWatchEvents")
eventFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        Watch:OnSpellCast(spellID)
    else
        Watch:UpdateVisibility()
    end
end)

function Watch:OnInitialize()
    local _, class = UnitClass("player")
    local defs = class and D.WATCH[class]
    if not defs or not TAU.SUPPORTED_CLASSES[class] then return end
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end

    row = CreateFrame("Frame", "TankAuditForeverWatch", UIParent)
    row:SetSize(#defs * (ICON_SIZE + SPACING) - SPACING, ICON_SIZE)
    row:SetPoint("CENTER", UIParent, "CENTER", 0, -40) -- re-anchored to the bar at login

    for i, def in ipairs(defs) do
        local ok, entry = pcall(BuildEntry, def, i)
        if ok then
            entries[#entries + 1] = entry
        else
            TAU:Print("|cffFF4444Combat Watch unavailable:|r %s", tostring(entry))
        end
    end
end

function Watch:OnLogin()
    if not row then return end
    local anchor = TAU.Bar:GetAnchor()
    if anchor then
        row:ClearAllPoints()
        -- Above the audit bar's top row
        row:SetPoint("BOTTOM", anchor, "CENTER", 0, 30 + 18 + 15 + 22)
    end
end

function Watch:OnEnable()
    if not row then return end
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    if ticker then ticker:Cancel() end
    ticker = C_Timer.NewTicker(0.25, Tick)
    self:UpdateVisibility()
end

function Watch:OnDisable()
    eventFrame:UnregisterAllEvents()
    if ticker then ticker:Cancel(); ticker = nil end
    for _, e in ipairs(entries) do e.glow:Hide() end
    self:UpdateVisibility()
end

-- For tests
function Watch:GetEntries() return entries end
function Watch:GetRow() return row end
