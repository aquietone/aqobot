--- @type Mq
local mq = require 'mq'
local baseclass = require('aqo.classes.base')
local common = require('aqo.common')

local clr = baseclass

clr.class = 'clr'
clr.classOrder = {'heal', 'assist', 'mash', 'burn', 'recover', 'buff', 'rest'}

clr.SPELLSETS = {standard=1}

clr.addOption('SPELLSET', 'Spell Set', 'standard', clr.SPELLSETS, nil, 'combobox')
clr.addOption('USEMELEE', 'Use Melee', false, nil, 'Toggle attacking mobs with melee', 'checkbox')

clr.addSpell('heal', {'Superior Healing', 'Light Healing', 'Minor Healing'}, {me=70, mt=70, other=50})

local standard = {}

clr.spellRotations = {
    standard=standard
}

table.insert(clr.healAbilities, clr.spells.heal)

clr.heal = function()
    for _,heal in ipairs(clr.healAbilities) do
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

return clr