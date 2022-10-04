--- @type Mq
local mq = require 'mq'
local baseclass = require('aqo.classes.base')
local timer = require('aqo.utils.timer')
local common = require('aqo.common')

local shm = baseclass

shm.class = 'shm'
shm.classOrder = {'heal', 'assist', 'cast', 'cure', 'burn', 'recover', 'buff', 'rest', 'managepet'}

shm.SPELLSETS = {standard=1}

shm.addOption('SPELLSET', 'Spell Set', 'standard', shm.SPELLSETS, nil, 'combobox')
shm.addOption('USEMELEE', 'Use Melee', false, nil, 'Toggle attacking mobs with melee', 'checkbox')
shm.addOption('USESLOW', 'Use Slow', false, nil, 'Toggle casting slow on mobs', 'checkbox')
shm.addOption('SUMMONPET', 'Summon Pet', true, nil, 'Summon a pet', 'checkbox')
shm.addOption('USENUKES', 'Use Nukes', false, nil, 'Toggle use of nukes', 'checkbox')

shm.addSpell('heal', {'Chloroblast', 'Kragg\'s Salve', 'Superior Healing', 'Spirit Salve', 'Light Healing', 'Minor Healing'}, {me=75, mt=75, other=75})
shm.addSpell('canni', {'Cannibalize IV', 'Cannibalize III', 'Cannibalize II'}, {mana=true, threshold=70, combat=true, endurance=false, minhp=50, ooc=false})
shm.addSpell('pet', {'Frenzied Spirit'})
shm.addSpell('slow', {'Turgur\'s Insects', 'Togor\'s Insects'})
shm.addSpell('proc', {'Spirit of the Leopard', 'Spirit of the Jaguar'})
shm.addSpell('cure', {'Blood of Nadox'})
shm.addSpell('nuke', {'Spear of Torment'}, {opt='USENUKES'})

local standard = {}
table.insert(standard, shm.spells.nuke)

shm.spellRotations = {
    standard=standard
}

table.insert(shm.healAbilities, shm.spells.heal)
table.insert(shm.cures, shm.spells.cure)

shm.slow = common.get_best_spell({'Turgur\'s Insects', 'Togor\'s Insects'})
shm.canni = common.get_aa('Cannibalization', {mana=true, endurance=false, threshold=60, combat=true, minhp=80, ooc=false})
table.insert(shm.recoverAbilities, shm.canni)
table.insert(shm.recoverAbilities, shm.spells.canni)

shm.nuketimer = timer:new(3)

shm.cure = function()
--[[    local groupSize = mq.TLO.Group.GroupSize()
    if not groupSize then
        return
    end
    for i=0,groupSize-1 do
        local member = mq.TLO.Group.Member(i)
        if (member.Poisoned() or member.Diseased()) then
            
        end
    end]]
end

local melees = {'MNK','BER','ROG','BST','WAR','PAL','SHD'}
shm.buff = function()
    if common.am_i_dead() then return end

    if shm.spells.proc.name and mq.TLO.Me.SpellReady(shm.spells.proc.name)() and mq.TLO.Group.GroupSize() then
        for i=1,mq.TLO.Group.GroupSize()-1 do
            local member = mq.TLO.Group.Member(i)
            if melees[member.Class.ShortName()] and not member.Buff(shm.spells.proc.name)() then
                member.DoTarget()
                mq.delay(100, function() return mq.TLO.Target.ID() == member.ID() end)
                mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end)
                if not mq.TLO.Target.Buff(shm.spells.proc.name)() then
                    if common.cast(shm.spells.proc) then return end
                end
            end
        end
    end
end

return shm