local mq = require('mq')
local conditions = require('routines.conditions')
local common = require('common')

local SharedAbilities = {}

function SharedAbilities.getTaunt()
    return common.getSkill('Taunt', {aggro=true, condition=conditions.lowAggroInMelee})
end

function SharedAbilities.getKick()
    return common.getSkill('Kick', {condition=conditions.withinMeleeDistance})
end

function SharedAbilities.getRoundKick()
    return common.getSkill('Round Kick', {conditions=conditions.withinMeleeDistance})
end

function SharedAbilities.getBash()
    local condition = function()
        return (mq.TLO.Me.AltAbility('Improved Bash')() or mq.TLO.Me.Inventory('offhand').Type() == 'Shield')
            and (mq.TLO.Target.Distance3D() or 100) < (mq.TLO.Target.MaxMeleeTo() or 0)
    end
    return common.getSkill('Bash', {condition=condition})
end

return SharedAbilities