local ADDON_NAME, TAU = ...

TAU.L = setmetatable({}, {
    __index = function(tbl, key)
        -- Fallback to the raw key if translation is missing
        return key
    end
})

local currentLocale = GetLocale and GetLocale() or "enUS"

function TAU:NewLocale(locale)
    if locale == "enUS" or locale == currentLocale then
        return TAU.L
    end
    return nil
end
