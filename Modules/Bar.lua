local ADDON_NAME, TAU = ...

-- The audit bar: a pool of SecureActionButtons (casting and cancelling buffs are protected actions).
-- Forever/secure rules (kb/restrictions.md §4b): secure buttons can't be shown, hidden, moved or reconfigured in
-- combat, so the bar freezes in its pre-combat state and applies any pending update after combat. Already
-- configured cast/cancel buttons keep working when clicked in combat.
local Bar = TAU:RegisterModule("Bar")
local Utils, L, D = TAU.Utils, TAU.L, TAU.Data

local MAX_BUTTONS = 16
local SIZE = 30
local SPACING = 4
local ROW_GAP = 18

local anchor, mover, timerFrame
local buttons = {}
local pendingState = nil      -- state to render once combat ends
local pendingLayout = false   -- position/scale/visibility to apply once combat ends
local preview = false

local function ApplyPosition()
    local p = TAU:Get("point")
    anchor:ClearAllPoints()
    anchor:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    anchor:SetScale(TAU:Get("scale"))
end

local function SavePosition()
    local point, _, relativePoint, x, y = anchor:GetPoint(1)
    if point then
        TAU:Set("point", { point, relativePoint, math.floor(x + 0.5), math.floor(y + 0.5) })
    end
end

local HINTS = {
    spell = "HINT_CAST", cancelaura = "HINT_CANCEL", request = "HINT_REQUEST", bags = "HINT_BAGS",
}

local function ShowTooltip(button)
    local entry = button.entry
    if not entry then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if entry.spellId then
        GameTooltip:SetSpellByID(entry.spellId)
    else
        GameTooltip:SetText(entry.label or "?", 1, 1, 1)
    end
    if entry.kind == "expiring" and entry.expiresAt then
        GameTooltip:AddLine(string.format(L["HINT_EXPIRES"], Utils.FormatTime(entry.expiresAt - GetTime())), 1, 0.82, 0)
    elseif entry.kind == "missing" then
        GameTooltip:AddLine(L["HINT_MISSING"], 1, 0.3, 0.3)
    end
    local actionType = entry.action and entry.action.type
    local hint = HINTS[actionType]
    if entry.kind == "debuff" then
        hint = actionType == "spell" and "HINT_DISPEL_SELF" or "HINT_DISPEL_REQUEST"
    end
    if hint then GameTooltip:AddLine(L[hint], 0.6, 0.8, 1) end
    GameTooltip:Show()
end

local function CreateBarButton(index)
    local b = CreateFrame("Button", "TankAuditForeverButton" .. index, anchor, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)
    -- Forever: for addon-owned secure buttons a mouse click follows the ActionButtonUseKeyDown CVar (default on =
    -- act on DOWN). Register both like Blizzard's action bars; the template acts on the right one.
    -- [in-game] 2026-10-05: registering only "LeftButtonUp" never cast (kb/gotchas.md#secure-clicks).
    b:RegisterForClicks("LeftButtonDown", "LeftButtonUp")

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    b.timer = b:CreateFontString(nil, "OVERLAY")
    b.timer:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    b.timer:SetPoint("CENTER", b, "CENTER", 0, 0)

    b.tag = b:CreateFontString(nil, "OVERLAY")
    b.tag:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    b.tag:SetPoint("BOTTOM", b, "TOP", 0, 1)

    b:SetScript("OnEnter", ShowTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Runs after the secure action (if any); still a hardware event, so chat requests are allowed
    b:HookScript("OnClick", function(self, _, down)
        if down then return end -- the hook sees both halves of the click; act once
        TAU.Requests:OnClick(self.entry)
    end)
    b:Hide()
    return b
end

local function SetupButton(b, entry)
    b.entry = entry
    b.icon:SetTexture(entry.icon or D.ICONS.UNKNOWN)
    b.icon:SetDesaturated(entry.kind == "missing")
    b.timer:SetText("")
    if entry.kind == "unwanted" then
        b.tag:SetText("|cffFF2222CANCEL|r")
    elseif entry.kind == "debuff" then
        b.tag:SetText("|cffFF2222DISPEL|r")
    else
        b.tag:SetText("")
    end

    local action = entry.action or {}
    if action.type == "spell" or action.type == "cancelaura" then
        b:SetAttribute("type", action.type)
        b:SetAttribute("spell", action.spell)
        b:SetAttribute("unit", action.unit)
    else
        b:SetAttribute("type", nil)
        b:SetAttribute("spell", nil)
        b:SetAttribute("unit", nil)
    end
end

local function PreviewState()
    local now = GetTime()
    return {
        top = {
            { key = "PREVIEW", kind = "debuff", label = L["PREVIEW"], icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges" },
        },
        bottom = {
            { key = "PREVIEW", kind = "missing", label = L["PREVIEW"], icon = "Interface\\Icons\\Spell_Holy_WordFortitude" },
            { key = "PREVIEW", kind = "missing", label = L["PREVIEW"], icon = "Interface\\Icons\\Spell_Magic_MageArmor" },
            { key = "PREVIEW", kind = "expiring", label = L["PREVIEW"], icon = D.ICONS.WELL_FED, expiresAt = now + 45 },
        },
    }
end

function Bar:UpdateTimers()
    local now = GetTime()
    for _, b in ipairs(buttons) do
        local entry = b.entry
        if entry and entry.expiresAt and b:IsShown() then
            local left = entry.expiresAt - now
            if left <= 0 then
                b.timer:SetText("|cffFF00000|r")
                b.icon:SetDesaturated(true)
            elseif left < 10 then
                b.timer:SetText("|cffFF2222" .. Utils.FormatTime(left) .. "|r")
            else
                b.timer:SetText("|cffFFFF00" .. Utils.FormatTime(left) .. "|r")
            end
        end
    end
end

function Bar:Render(state)
    if not anchor then return end
    if InCombatLockdown() then
        pendingState = state
        return
    end
    pendingState = nil
    if preview then state = PreviewState() end
    state = state or { top = {}, bottom = {} }

    local used = 0
    local function Row(list, y)
        local n = math.min(#list, MAX_BUTTONS - used)
        local x = -((n * SIZE) + ((n - 1) * SPACING)) / 2 + SIZE / 2
        for i = 1, n do
            used = used + 1
            local b = buttons[used]
            SetupButton(b, list[i])
            b:ClearAllPoints()
            b:SetPoint("CENTER", anchor, "CENTER", x, y)
            b:Show()
            x = x + SIZE + SPACING
        end
    end
    Row(state.top, SIZE + ROW_GAP)
    Row(state.bottom, 0)

    for i = used + 1, MAX_BUTTONS do
        local b = buttons[i]
        b.entry = nil
        if b:IsShown() then b:Hide() end
    end
    self:UpdateTimers()
end

function Bar:SetPreview(enabled)
    preview = enabled and true or false
    self:Render(TAU.Scanner.state)
end

function Bar:SetLocked(locked)
    TAU:Set("locked", locked)
    if mover then mover:SetShown(not locked) end
    self:SetPreview(not locked or (TAU.Options and TAU.Options:IsShown()))
    TAU:Print(locked and L["BAR_LOCKED"] or L["BAR_UNLOCKED"])
end

function Bar:ResetPosition()
    TAU:Set("point", TAU.CopyTable(TAU.DefaultConfig.point))
    if InCombatLockdown() then
        pendingLayout = true
        TAU:Print(L["IN_COMBAT_LATER"])
        return
    end
    ApplyPosition()
    TAU:Print(L["BAR_RESET"])
end

function Bar:SetScale(scale)
    TAU:Set("scale", scale)
    if InCombatLockdown() then pendingLayout = true return end
    anchor:SetScale(scale)
end

local function CreateBar()
    anchor = CreateFrame("Frame", "TankAuditForeverBar", UIParent)
    anchor:SetSize(MAX_BUTTONS * (SIZE + SPACING) / 2, (SIZE * 2) + ROW_GAP)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    ApplyPosition()

    -- Drag handle, shown only while unlocked (sits above the buttons)
    mover = CreateFrame("Frame", nil, anchor)
    mover:SetPoint("TOPLEFT", anchor, "TOPLEFT", -6, 6)
    mover:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 6, -6)
    mover:SetFrameLevel(anchor:GetFrameLevel() + 20)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    local bg = mover:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 1, 0.5, 0.25)
    local text = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER")
    text:SetText(L["BAR_DRAG_HINT"])
    mover:SetScript("OnDragStart", function()
        if not InCombatLockdown() then anchor:StartMoving() end
    end)
    mover:SetScript("OnDragStop", function()
        anchor:StopMovingOrSizing()
        SavePosition()
    end)
    mover:SetShown(not TAU:Get("locked"))
    preview = not TAU:Get("locked")

    for i = 1, MAX_BUTTONS do
        buttons[i] = CreateBarButton(i)
    end

    -- Countdown text updates are allowed in combat (only the protected frames themselves are locked)
    timerFrame = CreateFrame("Frame", "TAU_BarTimerFrame")
    local elapsedTotal = 0
    timerFrame:SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal >= 0.2 then
            elapsedTotal = 0
            Bar:UpdateTimers()
        end
    end)
end

local eventFrame = CreateFrame("Frame", "TAU_BarEventFrame")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if not anchor then
            CreateBar()
            Bar:Render(TAU.Scanner.state)
        end
        if pendingLayout then
            pendingLayout = false
            ApplyPosition()
            anchor:SetShown(TAU.isEnabled)
        end
        if pendingState then Bar:Render(pendingState) end
    end
end)

function Bar:OnLogin()
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    -- /reload in combat: secure frames must wait for combat to end
    if not InCombatLockdown() then CreateBar() end
end

function Bar:OnEnable()
    if not anchor then return end
    if InCombatLockdown() then pendingLayout = true return end
    anchor:Show()
end

function Bar:OnDisable()
    if not anchor then return end
    if InCombatLockdown() then pendingLayout = true return end
    preview = false
    self:Render({ top = {}, bottom = {} })
    anchor:Hide()
end

-- For tests and /taudit status
function Bar:GetButtons() return buttons end
function Bar:GetAnchor() return anchor end
