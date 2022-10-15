---@type Mq
local mq = require 'mq'
local class = require(AQO..'.classes.classbase')
local timer = require(AQO..'.utils.timer')
local common = require(AQO..'.common')

class.class = 'shm'
class.classOrder = {'heal', 'cure', 'assist', 'cast', 'burn', 'aggro', 'recover', 'buff', 'rest', 'managepet'}

class.SPELLSETS = {standard=1}

class.addCommonOptions()
class.addOption('USEDEBUFF', 'Use Malo', true, nil, 'Toggle casting malo on mobs', 'checkbox')
class.addOption('USESLOW', 'Use Slow', true, nil, 'Toggle casting slow on mobs', 'checkbox')
class.addOption('USEHOT', 'Use HoT', false, nil, 'Toggle use of heal over time', 'checkbox')
class.addOption('USENUKES', 'Use Nukes', true, nil, 'Toggle use of nukes', 'checkbox')

class.addSpell('heal', {'Daluda\'s Mending', 'Chloroblast', 'Kragg\'s Salve', 'Superior Healing', 'Spirit Salve', 'Light Healing', 'Minor Healing'}, {me=75, mt=65, other=65, pet=60})
class.addSpell('canni', {'Cannibalize IV', 'Cannibalize III', 'Cannibalize II'}, {mana=true, threshold=70, combat=true, endurance=false, minhp=50, ooc=false})
class.addSpell('pet', {'True Spirit', 'Frenzied Spirit'})
class.addSpell('slow', {'Turgur\'s Insects', 'Togor\'s Insects'})
class.addSpell('proc', {'Ferine Avatar', 'Spirit of the Leopard', 'Spirit of the Jaguar'})
class.addSpell('cure', {'Blood of Nadox'})
class.addSpell('nuke', {'Spear of Torment'}, {opt='USENUKES'})
class.addSpell('hot', {'Breath of Trushar'}, {opt='USEHOT', hot=true})

table.insert(class.selfBuffs, common.getAA('Pact of the Wolf', {removesong='Pact of the Wolf Effect'}))
--table.insert(class.groupBuffs, common.getAA('Group Pact of the Wolf', {group=true, self=false}))
-- pact of the wolf, remove pact of the wolf effect

local standard = {}
table.insert(standard, class.spells.nuke)

class.spellRotations = {
    standard=standard
}

table.insert(class.healAbilities, class.spells.heal)
table.insert(class.healAbilities, class.spells.hot)
table.insert(class.cures, class.spells.cure)
table.insert(class.burnAbilities, common.getAA('Ancestral Aid'))
table.insert(class.healAbilities, common.getAA('Union of Spirits', {me=30, mt=30, other=30}))

class.debuff = common.getAA('Malosinete')
class.slow = common.getAA('Turgur\'s Swarm') or common.getBestSpell({'Turgur\'s Insects', 'Togor\'s Insects'})
class.canni = common.getAA('Cannibalization', {mana=true, endurance=false, threshold=60, combat=true, minhp=80, ooc=false})
table.insert(class.recoverAbilities, class.canni)
table.insert(class.recoverAbilities, class.spells.canni)

table.insert(class.defensiveAbilities, common.getAA('Ancestral Guard'))

class.radiant = common.getAA('Radiant Cure')
class.requestAliases.radiant = 'radiant'

class.nuketimer = timer:new(3)

class.cure = function()
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
class.buff_class = function()
    if common.am_i_dead() then return end

    if class.spells.proc and mq.TLO.Me.SpellReady(class.spells.proc.name)() and mq.TLO.Group.GroupSize() then
        for i=1,mq.TLO.Group.GroupSize()-1 do
            local member = mq.TLO.Group.Member(i)
            local distance = member.Distance3D() or 300
            if melees[member.Class.ShortName()] and not member.Dead() and not member.Buff(class.spells.proc.name)() and distance < 100 then
                member.DoTarget()
                mq.delay(100, function() return mq.TLO.Target.ID() == member.ID() end)
                mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end)
                if not mq.TLO.Target.Buff(class.spells.proc.name)() then
                    if class.spells.proc:use() then return end
                end
            end
        end
    end
end

return class