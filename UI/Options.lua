local ADDON_NAME, TAU = ...

-- Options panel in the TankAlertForever style (ButtonFrameTemplate) + slash commands.
local Options = TAU:RegisterModule("Options")
local L, D, Utils = TAU.L, TAU.Data, TAU.Utils

local optionsPanel = nil
local widgetCounter = 0

local function GetUniqueWidgetName(prefix)
    widgetCounter = widgetCounter + 1
    return string.format("TAU_%s_%d", prefix or "Widget", widgetCounter)
end

local function Rescan()
    if TAU.Scanner then TAU.Scanner:Queue() end
end

-- UI Helper: Create Checkbox
local function CreateCheckbox(parent, text, tooltip, onClick)
    local cb = CreateFrame("CheckButton", GetUniqueWidgetName("CheckButton"), parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb.Text:SetFontObject("GameFontHighlight")
    cb.Text:SetText(text)

    cb:SetScript("OnClick", function(self)
        if onClick then onClick(self:GetChecked()) end
    end)

    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(text, 1, 1, 1)
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return cb
end

-- UI Helper: Create Slider (MinimalSliderWithSteppersTemplate)
local function CreateSlider(parent, text, minVal, maxVal, step, onValChanged)
    local slider = CreateFrame("Frame", GetUniqueWidgetName("Slider"), parent, "MinimalSliderWithSteppersTemplate")
    slider:SetSize(220, 24)

    local title = slider:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 19, 2)
    title:SetText(text)

    local Label = MinimalSliderWithSteppersMixin.Label
    local formatters = {
        [Label.Right] = CreateMinimalSliderFormatter(Label.Right, function(value)
            return tostring(math.floor(value + 0.5))
        end),
    }
    slider:Init(minVal, minVal, maxVal, (maxVal - minVal) / step, formatters)
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if onValChanged then onValChanged(math.floor(value + 0.5)) end
    end, slider)
    return slider
end

-- UI Helper: gold section header with a horizontal divider underneath
local function CreateSectionHeader(parent, text, y)
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2")
    header:SetPoint("TOPLEFT", 16, y)
    header:SetText(text)

    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -4, -2)
    divider:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
    return header
end

local function CreateButton(parent, text, width, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, 22)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn
end

-- Optional consumables on top of food: "+ Elixir" or "+ Flask" (at most one, both may be off).
-- consumableLevel: 1 = food only, 2 = + elixir, 3 = + flask.
-- Not a WowStyle1Dropdown: opening an addon dropdown's menu crashed the Forever beta client
-- (Lua assertion in Blizzard_Menu AcquireMenu; kb/gotchas.md#menu-crash).
local CONSUMABLE_OPTIONS = {
    { level = 2, label = "CONS_ELIXIR_SHORT", x = 268 },
    { level = 3, label = "CONS_FLASK_SHORT", x = 368 },
}

local function CreateConsumableOptions(parent)
    local boxes = {}
    for _, opt in ipairs(CONSUMABLE_OPTIONS) do
        local cb = CreateCheckbox(parent, L[opt.label], L["CONS_MODE_DESC"], function(checked)
            TAU:Set("consumableLevel", checked and opt.level or 1)
            for level, other in pairs(boxes) do other:SetChecked(level == TAU:Get("consumableLevel")) end
            Rescan()
        end)
        cb:SetPoint("TOPLEFT", opt.x, -182)
        boxes[opt.level] = cb
    end
    return boxes
end

local function BlessingName(key)
    local def = D.BLESSINGS[key]
    return (def and Utils.SpellName(def.ids[1])) or key
end

local function CreateOptionsPanel()
    if optionsPanel then return optionsPanel end

    local f = CreateFrame("Frame", "TankAuditForeverOptionsPanel", UIParent, "ButtonFrameTemplate")
    f:SetSize(540, 590)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)

    f:SetTitle(L["ADDON_TITLE"] .. " |cff888888v" .. TAU.version .. "|r")
    f:SetPortraitToClassIcon(TAU.playerClass or "WARRIOR")

    local widgets = {}
    f.widgets = widgets
    local content = f.Inset

    -- Attic: master switch next to the portrait
    widgets.master = CreateCheckbox(f, L["OPT_ENABLE_ADDON"], L["OPT_ENABLE_ADDON_DESC"], function(checked)
        if checked then TAU:Enable() else TAU:Disable() end
    end)
    widgets.master:SetPoint("TOPLEFT", 64, -28)

    -- 1. Audit bar
    CreateSectionHeader(content, L["UI_SECTION_BAR"], -12)
    widgets.lock = CreateCheckbox(content, L["OPT_LOCK"], L["OPT_LOCK_DESC"], function(checked)
        TAU.Bar:SetLocked(checked)
    end)
    widgets.lock:SetPoint("TOPLEFT", 14, -40)

    widgets.reset = CreateButton(content, L["OPT_RESET"], 130, function() TAU.Bar:ResetPosition() end)
    widgets.reset:SetPoint("TOPLEFT", 268, -42)

    widgets.scale = CreateSlider(content, L["OPT_SCALE"], 50, 200, 10, function(val)
        TAU.Bar:SetScale(val / 100)
    end)
    widgets.scale:SetPoint("TOPLEFT", 0, -88)

    -- 2. What to check
    CreateSectionHeader(content, L["UI_SECTION_CHECKS"], -126)
    local checks = {
        { key = "checkSelf", text = "OPT_SELF", x = 14, y = -154 },
        { key = "checkGroup", text = "OPT_GROUP", x = 268, y = -154 },
        { key = "checkConsumables", text = "OPT_CONSUMABLES", x = 14, y = -182 },
        { key = "checkHealthstone", text = "OPT_HEALTHSTONE", x = 14, y = -210 },
        { key = "checkDebuffs", text = "OPT_DEBUFFS", x = 268, y = -210 },
        { key = "checkUnwanted", text = "OPT_UNWANTED", x = 14, y = -238 },
        { key = "gratitude", text = "OPT_GRATITUDE", x = 268, y = -238 },
    }
    widgets.checks = {}
    for _, def in ipairs(checks) do
        local cb = CreateCheckbox(content, L[def.text], L[def.text .. "_DESC"], function(checked)
            TAU:Set(def.key, checked)
            Rescan()
        end)
        cb:SetPoint("TOPLEFT", def.x, def.y)
        widgets.checks[def.key] = cb
    end
    widgets.consumables = CreateConsumableOptions(content)

    -- 3. Blessing priority (per tank class)
    CreateSectionHeader(content, L["UI_SECTION_BLESSINGS"], -276)
    local note = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 18, -300)
    note:SetText(L["UI_BLESSINGS_NOTE"])

    widgets.blessings = {}
    for i = 1, 4 do
        local y = -320 - (i - 1) * 26
        local row = {}
        row.label = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.label:SetPoint("TOPLEFT", 22, y - 4)
        row.up = CreateButton(content, L["BTN_UP"], 56, function()
            TAU:MoveBlessing(i, -1)
            Options:Refresh()
            Rescan()
        end)
        row.up:SetPoint("TOPLEFT", 268, y)
        row.down = CreateButton(content, L["BTN_DOWN"], 56, function()
            TAU:MoveBlessing(i, 1)
            Options:Refresh()
            Rescan()
        end)
        row.down:SetPoint("LEFT", row.up, "RIGHT", 4, 0)
        widgets.blessings[i] = row
    end

    -- 4. In-combat warning (sound + glow on the self-buff tile)
    CreateSectionHeader(content, L["UI_SECTION_WATCH"], -432)
    widgets.watch = {}
    local sound = CreateCheckbox(content, L["OPT_WATCH_SOUND"], L["OPT_WATCH_SOUND_DESC"], function(checked)
        TAU:Set("watchSound", checked)
    end)
    sound:SetPoint("TOPLEFT", 14, -460)
    widgets.watch.watchSound = sound

    -- 5. Bottom bar
    local scan = CreateButton(f, L["BTN_SCAN"], 100, function() TAU.Scanner:Scan() end)
    scan:SetPoint("BOTTOMLEFT", 6, 3)
    local dump = CreateButton(f, L["BTN_DUMP"], 100, function() TAU.Scanner:Dump() end)
    dump:SetPoint("LEFT", scan, "RIGHT", 4, 0)

    f:SetScript("OnShow", function()
        Options:Refresh()
        TAU.Bar:SetPreview(true)
    end)
    f:SetScript("OnHide", function()
        TAU.Bar:SetPreview(not TAU:Get("locked"))
    end)

    f:Hide()
    optionsPanel = f
    tinsert(UISpecialFrames, "TankAuditForeverOptionsPanel")
    return f
end

-- Synchronize widgets with the saved settings
function Options:Refresh()
    if not optionsPanel then return end
    local w = optionsPanel.widgets
    w.master:SetChecked(TAU:Get("enabled"))
    w.lock:SetChecked(TAU:Get("locked"))
    w.scale:SetValue(math.floor(TAU:Get("scale") * 100 + 0.5))
    for key, cb in pairs(w.checks) do
        cb:SetChecked(TAU:Get(key))
    end
    for key, cb in pairs(w.watch) do
        cb:SetChecked(TAU:Get(key))
    end
    for level, cb in pairs(w.consumables) do
        cb:SetChecked(TAU:Get("consumableLevel") == level)
    end

    local priority = TAU:GetBlessingPriority()
    for i, row in ipairs(w.blessings) do
        local key = priority[i]
        row.label:SetText(key and (i .. ". " .. BlessingName(key)) or "")
        row.up:SetEnabled(i > 1)
        row.down:SetEnabled(i < #priority)
    end
end

function Options:IsShown()
    return optionsPanel ~= nil and optionsPanel:IsShown()
end

function Options:Toggle()
    local panel = CreateOptionsPanel()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
    end
end

function Options:PrintStatus()
    TAU:Print(L["STATUS_HEADER"])
    TAU:Print("Enabled: %s  Class: %s  Bar: %s", tostring(TAU.isEnabled), tostring(TAU.playerClass),
        TAU:Get("locked") and "locked" or "unlocked")
    local plan = TAU.Scanner.plan
    local names = {}
    for _, item in ipairs(plan.tiles or {}) do names[#names + 1] = item.label or item.key end
    TAU:Print("Tiles: %s", #names > 0 and table.concat(names, ", ") or "-")
    local types = {}
    for dtype, action in pairs(plan.dispelActions or {}) do types[#types + 1] = dtype .. "(" .. action.type .. ")" end
    table.sort(types)
    TAU:Print("Salvation watch: %s  Debuff types: %s", tostring(plan.salvation == true),
        #types > 0 and table.concat(types, "/") or "-")
end

-- =========================================================================
-- Slash Command Dispatcher
-- =========================================================================
local function HandleSlashCommands(msg)
    local cmd = string.lower(strtrim(msg or ""))

    if not TAU:IsSupportedClass() then
        TAU:Print(L["CLASS_NOT_SUPPORTED"], tostring(TAU.playerClass))
        return
    end

    if cmd == "" or cmd == "config" then
        Options:Toggle()
    elseif cmd == "lock" then
        TAU.Bar:SetLocked(true)
    elseif cmd == "unlock" then
        TAU.Bar:SetLocked(false)
    elseif cmd == "reset" then
        TAU.Bar:ResetPosition()
    elseif cmd == "scan" or cmd == "test" then
        TAU.Scanner:Scan()
    elseif cmd == "dump" or cmd == "debug buffs" then
        TAU.Scanner:Dump()
    elseif cmd == "status" then
        Options:PrintStatus()
    elseif cmd == "on" then
        TAU:Enable()
    elseif cmd == "off" then
        TAU:Disable()
    elseif cmd == "debug" then
        local db = TAU.db
        TAU:Print("Last blocked event: %s", tostring(db._lastBlockedEvent or "none"))
        TAU:Print("Function: %s", tostring(db._lastBlockedFunction or "none"))
        TAU:Print("Stack:\n%s", tostring(db._lastBlockedStack or "-"))
    elseif cmd == "help" then
        TAU:Print(L["HELP"])
    else
        TAU:Print(L["UNKNOWN_COMMAND"])
    end
end

SLASH_TANKAUDITFOREVER1 = "/taudit"
SLASH_TANKAUDITFOREVER2 = "/tau"
SLASH_TANKAUDITFOREVER3 = "/tankaudit"
SlashCmdList["TANKAUDITFOREVER"] = HandleSlashCommands
