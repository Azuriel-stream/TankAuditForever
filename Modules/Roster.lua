local ADDON_NAME, TAU = ...

-- Group composition: which classes are present (and in the player's raid subgroup).
-- Group members' identities are never secret on Forever (kb/restrictions.md §2b).
local Roster = TAU:RegisterModule("Roster")

Roster.classes = {}          -- [classFile] = online count, including the player
Roster.subgroupClasses = {}  -- [classFile] = count in the player's subgroup (party = whole group)
Roster.isSolo = true

local function Add(class, inSubgroup)
    Roster.classes[class] = (Roster.classes[class] or 0) + 1
    if inSubgroup then
        Roster.subgroupClasses[class] = (Roster.subgroupClasses[class] or 0) + 1
    end
end

function Roster:Update()
    wipe(self.classes)
    wipe(self.subgroupClasses)
    self.isSolo = not IsInGroup()

    if IsInRaid() then
        local count = GetNumGroupMembers()
        local mySubgroup = 1
        for i = 1, count do
            if UnitIsUnit("raid" .. i, "player") then
                local _, _, subgroup = GetRaidRosterInfo(i)
                mySubgroup = subgroup or 1
                break
            end
        end
        for i = 1, count do
            local _, _, subgroup, _, _, class, _, online = GetRaidRosterInfo(i)
            if online and class then
                Add(class, subgroup == mySubgroup)
            end
        end
        return
    end

    Add(TAU.playerClass, true)
    for i = 1, GetNumSubgroupMembers() do
        local unit = "party" .. i
        local _, class = UnitClass(unit)
        if class and UnitIsConnected(unit) then
            Add(class, true)
        end
    end
end

-- Count of a class in the group, not counting the player
function Roster:CountOthers(class, subgroupOnly)
    local source = subgroupOnly and self.subgroupClasses or self.classes
    local count = source[class] or 0
    if class == TAU.playerClass then count = count - 1 end
    return count
end

-- Count including the player
function Roster:Count(class, subgroupOnly)
    local source = subgroupOnly and self.subgroupClasses or self.classes
    return source[class] or 0
end
