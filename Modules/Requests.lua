local ADDON_NAME, TAU = ...

-- Lua side of bar clicks: chat requests and opening bags. Casting and cancelling are done by the
-- secure buttons themselves (Modules/Bar.lua).
local Requests = TAU:RegisterModule("Requests")
local Utils, D, L = TAU.Utils, TAU.Data, TAU.L

local REQUEST_THROTTLE = 5   -- seconds per buff
local lastSent = {}

-- The latest request, for Modules/Gratitude.lua: { ids = set, time, link }
Requests.pending = nil

local function Pick(list)
    return list[math.random(1, #list)]
end

local LOCAL_HINTS = {
    WELL_FED = "MSG_LOCAL_FOOD",
    WEAPON_BUFF = "MSG_LOCAL_WEAPON",
    ELIXIR = "MSG_LOCAL_ELIXIR",
    FLASK = "MSG_LOCAL_FLASK",
}

function Requests:BuildMessage(entry)
    if entry.kind == "debuff" then
        return string.format(L["MSG_NEED_DISPEL"], entry.label or "?", entry.dispelType or "?")
    end
    if entry.key == "HEALTHSTONE" then
        return L["MSG_NEED_HS"]
    end
    local link = Utils.SpellLink(entry.spellId, entry.label)
    local msg = string.format(Pick(D.REQUESTS[entry.messageKey] or D.REQUESTS.DEFAULT), link)
    if entry.kind == "expiring" and entry.expiresAt then
        local left = entry.expiresAt - GetTime()
        if left > 0 then
            msg = msg .. string.format(L["MSG_EXPIRING_SUFFIX"], Utils.FormatTime(left))
        end
    end
    return msg
end

function Requests:Request(entry)
    local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY") or nil
    if not channel then
        TAU:Print(L["MSG_SOLO"])
        return
    end

    local now = GetTime()
    local throttleKey = entry.key .. (entry.label or "")
    if lastSent[throttleKey] and (now - lastSent[throttleKey]) < REQUEST_THROTTLE then
        TAU:Print(L["MSG_WAIT_THROTTLE"])
        return
    end
    lastSent[throttleKey] = now

    C_ChatInfo.SendChatMessage(self:BuildMessage(entry), channel)

    if entry.watchIds then
        Requests.pending = { ids = entry.watchIds, time = now, link = Utils.SpellLink(entry.spellId, entry.label) }
    end
end

-- Called from the bar buttons' OnClick hook (a hardware event, so chat is allowed in combat too)
function Requests:OnClick(entry)
    local action = entry and entry.action
    if not action then return end
    if action.type == "request" then
        self:Request(entry)
    elseif action.type == "bags" then
        OpenAllBags()
        local hint = LOCAL_HINTS[entry.key]
        if hint then TAU:Print(L[hint]) end
    end
end

function Requests:OnDisable()
    wipe(lastSent)
    Requests.pending = nil
end
