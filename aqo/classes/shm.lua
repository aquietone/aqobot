---@type Mq
local mq = require 'mq'
local baseclass = require(AQO..'.classes.classbase')
local timer = require(AQO..'.utils.timer')
local common = require(AQO..'.common')

local shm = baseclass

shm.class = 'shm'
shm.classOrder = {'heal', 'assist', 'cast', 'cure', 'burn', 'aggro', 'recover', 'buff', 'rest', 'managepet'}

shm.SPELLSETS = {standard=1}

shm.addOption('SPELLSET', 'Spell Set', 'standard', shm.SPELLSETS, nil, 'combobox')
shm.addOption('USEMELEE', 'Use Melee', false, nil, 'Toggle attacking mobs with melee', 'checkbox')
shm.addOption('USESLOW', 'Use Slow', false, nil, 'Toggle casting slow on mobs', 'checkbox')
shm.addOption('SUMMONPET', 'Summon Pet', true, nil, 'Summon a pet', 'checkbox')
shm.addOption('USENUKES', 'Use Nukes', false, nil, 'Toggle use of nukes', 'checkbox')
shm.addOption('USEHOT', 'Use HoT', false, nil, 'Toggle use of heal over time', 'checkbox')
shm.addOption('SERVEBUFFREQUESTS', 'Serve Buff Requests', true, nil, 'Toggle serving buff requests', 'checkbox')

shm.addSpell('heal', {'Daluda\'s Mending', 'Chloroblast', 'Kragg\'s Salve', 'Superior Healing', 'Spirit Salve', 'Light Healing', 'Minor Healing'}, {me=75, mt=65, other=65})
shm.addSpell('canni', {'Cannibalize IV', 'Cannibalize III', 'Cannibalize II'}, {mana=true, threshold=70, combat=true, endurance=false, minhp=50, ooc=false})
shm.addSpell('pet', {'True Spirit', 'Frenzied Spirit'})
shm.addSpell('slow', {'Turgur\'s Insects', 'Togor\'s Insects'})
shm.addSpell('proc', {'Ferine Avatar', 'Spirit of the Leopard', 'Spirit of the Jaguar'})
shm.addSpell('cure', {'Blood of Nadox'})
shm.addSpell('nuke', {'Spear of Torment'}, {opt='USENUKES'})
shm.addSpell('hot', {'Breath of Trushar'}, {opt='USEHOT', hot=true})

table.insert(shm.selfBuffs, common.getAA('Pact of the Wolf', {removesong='Pact of the Wolf Effect'}))
--table.insert(shm.groupBuffs, common.getAA('Group Pact of the Wolf', {group=true, self=false}))
-- pact of the wolf, remove pact of the wolf effect

local standard = {}
table.insert(standard, shm.spells.nuke)

shm.spellRotations = {
    standard=standard
}

table.insert(shm.healAbilities, shm.spells.heal)
table.insert(shm.healAbilities, shm.spells.hot)
table.insert(shm.cures, shm.spells.cure)
table.insert(shm.burnAbilities, common.getAA('Ancestral Aid'))
table.insert(shm.healAbilities, common.getAA('Union of Spirits', {me=30, mt=30, other=30}))

shm.slow = common.getAA('Turgur\'s Swarm') or common.getBestSpell({'Turgur\'s Insects', 'Togor\'s Insects'})
shm.canni = common.getAA('Cannibalization', {mana=true, endurance=false, threshold=60, combat=true, minhp=80, ooc=false})
table.insert(shm.recoverAbilities, shm.canni)
table.insert(shm.recoverAbilities, shm.spells.canni)

table.insert(shm.defensiveAbilities, common.getAA('Ancestral Guard'))

shm.radiant = common.getAA('Radiant Cure')
shm.requestAliases.radiant = 'radiant'

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

local melees = {MNK=true,BER=true,ROG=true,BST=true,WAR=true,PAL=true,SHD=true}
shm.buff_class = function()
    if common.am_i_dead() then return end

    if shm.spells.proc and mq.TLO.Me.SpellReady(shm.spells.proc.name)() and mq.TLO.Group.GroupSize() then
        for i=1,mq.TLO.Group.GroupSize()-1 do
            local member = mq.TLO.Group.Member(i)
            local distance = member.Distance3D() or 300
            if melees[member.Class.ShortName()] and not member.Buff(shm.spells.proc.name)() and distance < 100 then
                member.DoTarget()
                mq.delay(100, function() return mq.TLO.Target.ID() == member.ID() end)
                mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end)
                if not mq.TLO.Target.Buff(shm.spells.proc.name)() then
                    if shm.spells.proc:use() then return end
                end
            end
        end
    end
end

return shm