---@type Mq
local mq = require 'mq'
local baseclass = require(AQO..'.classes.base')
local timer = require(AQO..'.utils.timer')
local common = require(AQO..'.common')

local dru = baseclass

dru.class = 'dru'
dru.classOrder = {'heal', 'assist', 'cast', 'burn', 'recover', 'buff', 'rest'}

dru.SPELLSETS = {standard=1}

dru.addOption('SPELLSET', 'Spell Set', 'standard', dru.SPELLSETS, nil, 'combobox')
dru.addOption('USEMELEE', 'Use Melee', false, nil, 'Toggle attacking mobs with melee', 'checkbox')
dru.addOption('USENUKES', 'Use Nukes', false, nil, 'Toggle use of nuke spells', 'checkbox')
dru.addOption('USESNARE', 'Use Snare', true, nil, 'Cast snare on mobs', 'checkbox')

dru.addSpell('heal', {'Chloroblast', 'Superior Healing', 'Nature\'s Renewal', 'Light Healing', 'Minor Healing'}, {me=75, mt=75, other=75})
dru.addSpell('firenuke', {'Wildfire', 'Scoriae', 'Firestrike'}, {opt='USENUKES'})
dru.addSpell('snare', {'Ensnare', 'Snare'})
dru.addSpell('aura', {'Aura of the Grove'}, {aura=true})

-- Aura of the Grove, Aura of the Grove Effect

local standard = {}
table.insert(standard, dru.spells.firenuke)

dru.spellRotations = {
    standard=standard
}

table.insert(dru.healAbilities, dru.spells.heal)

table.insert(dru.buffs, dru.spells.aura)

dru.nuketimer = timer:new(5)

dru.heal = function()
    for _,heal in ipairs(dru.healAbilities) do
        if common.is_spell_ready(heal) then
            if mq.TLO.Me.PctHPs() < heal.me then
                mq.cmdf('/mqt myself')
                mq.delay(100, function() return mq.TLO.Target.ID() == mq.TLO.Me.ID() end)
                heal:use()
                return
            elseif (mq.TLO.Group.MainTank.PctHPs() or 100) < heal.mt then
                mq.cmdf('/mqt id %d', mq.TLO.Group.MainTank.ID())
                mq.delay(100, function() return mq.TLO.Target.ID() == mq.TLO.Group.MainTank.ID() end)
                heal:use()
                return
            elseif mq.TLO.Group.GroupSize() then
                for i=1,mq.TLO.Group.GroupSize()-1 do
                    local member = mq.TLO.Group.Member(i)
                    if (member.PctHPs() or 100) < heal.other then
                        member.DoTarget()
                        mq.delay(100, function() return mq.TLO.Target.ID() == member.ID() end)
                        heal:use()
                        return
                    end
                end
            end
        end
    end
end

return dru