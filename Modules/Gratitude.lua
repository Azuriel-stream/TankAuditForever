local ADDON_NAME, TAU = ...

-- When a requested buff arrives, whisper its caster a thank-you.
-- Forever: AuraData.sourceUnit names the actual caster, and group members' names aren't secret.
local Gratitude = TAU:RegisterModule("Gratitude")
local Utils, D = TAU.Utils, TAU.Data

local REQUEST_WINDOW = 60  -- seconds after a request during which a new buff counts as the answer

function Gratitude:Check(helpfulAuras)
    local pending = TAU.Requests.pending
    if not pending then return end
    if (GetTime() - pending.time) > REQUEST_WINDOW then
        TAU.Requests.pending = nil
        return
    end

    for _, aura in ipairs(helpfulAuras) do
        if pending.ids[aura.spellId] then
            TAU.Requests.pending = nil
            if not TAU:Get("gratitude") then return end

            local source = aura.sourceUnit
            if not source or Utils.IsSecret(source) or not UnitExists(source) or UnitIsUnit(source, "player") then
                return
            end
            local target = Utils.GetUnitFullName(source)
            local firstName = Utils.SafeString((UnitName(source)), nil)
            if target and firstName then
                local text = D.THANKS[math.random(1, #D.THANKS)]
                C_ChatInfo.SendChatMessage(string.format(text, pending.link, firstName), "WHISPER", nil, target)
            end
            return
        end
    end
end
