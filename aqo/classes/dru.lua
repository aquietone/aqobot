---@type Mq
local mq = require 'mq'
local baseclass = require('aqo.classes.base')
local common = require('aqo.common')

local dru = baseclass

dru.class = 'dru'
dru.classOrder = {'heal', 'assist', 'cast', 'burn', 'recover', 'buff', 'rest'}

dru.SPELLSETS = {standard=1}

dru.addOption('SPELLSET', 'Spell Set', 'standard', dru.SPELLSETS, nil, 'combobox')
dru.addOption('USEMELEE', 'Use Melee', false, nil, 'Toggle attacking mobs with melee', 'checkbox')
dru.addOption('USENUKES', 'Use Nukes', false, nil, 'Toggle use of nuke spells', 'checkbox')

dru.addSpell('heal', {'Superior Healing', 'Nature\'s Renewal', 'Minor Healing'}, {me=70, mt=70, other=50})
dru.addSpell('firenuke', {'Firestrike'}, {opt='USENUKES'})

local standard = {}
table.insert(standard, dru.spells.firenuke)

dru.spellRotations = {
    standard=standard
}

table.insert(dru.healAbilities, dru.spells.heal)

dru.heal = function()
    for _,heal in ipairs(dru.healAbilities) do
        if common.is_spell_ready(heal) then
            if mq.TLO.Me.PctHPs() < heal.me then
                mq.cmdf('/mqt myself')
                mq.delay(100, function() return mq.TLO.Target.ID() == mq.TLO.Me.ID() end)
                common.cast(heal.name)
                return
            elseif (mq.TLO.Group.MainTank.PctHPs() or 100) < heal.mt then
                mq.cmdf('/mqt id %d', mq.TLO.Group.MainTank.ID())
                mq.delay(100, function() return mq.TLO.Target.ID() == mq.TLO.Group.MainTank.ID() end)
                common.cast(heal.name)
                return
            elseif mq.TLO.Group.GroupSize() then
                for i=1,mq.TLO.Group.GroupSize()-1 do
                    local member = mq.TLO.Group.Member(i)
                    if (member.PctHPs() or 100) < heal.other then
                        member.DoTarget()
                        mq.delay(100, function() return mq.TLO.Target.ID() == member.ID() end)
                        common.cast(heal.name)
                        return
                    end
                end
            end
        end
    end
end

return dru