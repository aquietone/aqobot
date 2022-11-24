---@type Mq
local mq = require 'mq'
local class = require(AQO..'.classes.classbase')
local timer = require(AQO..'.utils.timer')
local common = require(AQO..'.common')

class.class = 'shm'
class.classOrder = {'heal', 'cure', 'assist', 'cast', 'burn', 'aggro', 'recover', 'buff', 'rest', 'managepet'}

class.SPELLSETS = {standard=1}

class.addCommonOptions()
class.addCommonAbilities()
class.addOption('USEDEBUFF', 'Use Malo', true, nil, 'Toggle casting malo on mobs', 'checkbox')
class.addOption('USESLOW', 'Use Slow', true, nil, 'Toggle casting slow on mobs', 'checkbox')
class.addOption('USENUKES', 'Use Nukes', true, nil, 'Toggle use of nukes', 'checkbox')
class.addOption('USEEPIC', 'Use Epic', true, nil, 'Use epic in burns', 'checkbox')

class.addSpell('heal', {'Daluda\'s Mending', 'Chloroblast', 'Kragg\'s Salve', 'Superior Healing', 'Spirit Salve', 'Light Healing', 'Minor Healing'}, {panic=true, regular=true, tank=true, pet=60})
class.addSpell('canni', {'Cannibalize IV', 'Cannibalize III', 'Cannibalize II'}, {mana=true, threshold=70, combat=false, endurance=false, minhp=50, ooc=false})
class.addSpell('pet', {'Commune with the Wild', 'True Spirit', 'Frenzied Spirit'})
class.addSpell('slow', {'Turgur\'s Insects', 'Togor\'s Insects'})
class.addSpell('proc', {'Spirit of the Leopard', 'Spirit of the Jaguar'}, {classes={MNK=true,BER=true,ROG=true,BST=true,WAR=true,PAL=true,SHD=true}})
class.addSpell('champion', {'Champion', 'Ferine Avatar'})
class.addSpell('cure', {'Blood of Nadox'})
class.addSpell('nuke', {'Spear of Torment'}, {opt='USENUKES'})
class.addSpell('hottank', {'Spiritual Serenity', 'Breath of Trushar'}, {opt='USEHOTTANK', hot=true})
class.addSpell('hotdps', {'Spiritual Serenity', 'Breath of Trushar'}, {opt='USEHOTDPS', hot=true})
class.addSpell('slowproc', {'Lingering Sloth'}, {classes={WAR=true,PAL=true,SHD=true}})
class.addSpell('panther', {'Talisman of the Panther'})

local epic = common.getItem('Blessed Spiritstaff of the Heyokah', {opt='USEEPIC'}) or common.getItem('Crafted Talisman of Fates', {opt='USEEPIC'})

table.insert(class.selfBuffs, common.getItem('Earring of Pain Deliverance', {checkfor='Reyfin\'s Random Musings'}))
table.insert(class.selfBuffs, common.getItem('Xxeric\'s Matted-Fur Mask', {checkfor='Reyfin\'s Racing Thoughts'}))
table.insert(class.selfBuffs, class.spells.panther)
table.insert(class.singleBuffs, class.spells.slowproc)
table.insert(class.singleBuffs, class.spells.proc)
table.insert(class.selfBuffs, common.getAA('Pact of the Wolf', {removesong='Pact of the Wolf Effect'}))
table.insert(class.selfBuffs, class.spells.champion)
--table.insert(class.groupBuffs, common.getAA('Group Pact of the Wolf', {group=true, self=false}))
-- pact of the wolf, remove pact of the wolf effect

local standard = {}
table.insert(standard, class.spells.nuke)

class.spellRotations = {
    standard=standard
}

table.insert(class.healAbilities, class.spells.heal)
table.insert(class.healAbilities, class.spells.hottank)
table.insert(class.healAbilities, class.spells.hotdps)
table.insert(class.healAbilities, common.getAA('Union of Spirits', {panic=true, tank=true, pet=30}))
table.insert(class.cures, class.spells.cure)
table.insert(class.burnAbilities, common.getAA('Ancestral Aid'))
table.insert(class.burnAbilities, epic)

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

return class