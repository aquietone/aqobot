--- @type Mq
local mq = require 'mq'
local baseclass = require('aqo.classes.base')
local common = require('aqo.common')

local shm = baseclass

shm.class = 'shm'
shm.classOrder = {'heal', 'assist', 'cast', 'burn', 'recover', 'buff', 'rest', 'managepet'}

shm.SPELLSETS = {standard=1}

shm.addOption('SPELLSET', 'Spell Set', 'standard', shm.SPELLSETS, nil, 'combobox')
shm.addOption('USEMELEE', 'Use Melee', false, nil, 'Toggle attacking mobs with melee', 'checkbox')

shm.addSpell('heal', {'Superior Healing', 'Spirit Salve', 'Light Healing', 'Minor Healing'}, {me=80, mt=70, other=70})
shm.addSpell('canni', {'Cannibalize II'}, {mana=true, threshold=70, combat=true, endurance=false, minhp=50, ooc=false})

local standard = {}

shm.spellRotations = {
    standard=standard
}

table.insert(shm.healAbilities, shm.spells.heal)
table.insert(shm.recoverAbilities, shm.spells.canni)

shm.heal = function()
    for _,heal in ipairs(shm.healAbilities) do
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

return shm