---@type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local timer = require('utils.timer')
local common = require('common')

function class.init(_aqo)
    class.classOrder = {'heal', 'cure', 'assist', 'aggro', 'debuff', 'cast', 'burn', 'recover', 'buff', 'rest', 'managepet'}
    class.SPELLSETS = {standard=1}
    class.initBase(_aqo, 'shm')

    class.addOption('USEDEBUFF', 'Use Malo', true, nil, 'Toggle casting malo on mobs', 'checkbox')
    class.addOption('USESLOW', 'Use Slow', true, nil, 'Toggle casting slow on mobs', 'checkbox')
    class.addOption('USENUKES', 'Use Nukes', true, nil, 'Toggle use of nukes', 'checkbox')
    class.addOption('USEDOTS', 'Use DoTs', true, nil, 'Toggle use of DoTs', 'checkbox')
    class.addOption('USEEPIC', 'Use Epic', true, nil, 'Use epic in burns', 'checkbox')

    class.addSpell('heal', {'Ancient: Wilslik\'s Mending', 'Yoppa\'s Mending', 'Daluda\'s Mending', 'Chloroblast', 'Kragg\'s Salve', 'Superior Healing', 'Spirit Salve', 'Light Healing', 'Minor Healing'}, {panic=true, regular=true, tank=true, pet=60})
    class.addSpell('canni', {'Cannibalize IV', 'Cannibalize III', 'Cannibalize II'}, {mana=true, threshold=70, combat=false, endurance=false, minhp=50, ooc=false})
    class.addSpell('pet', {'Commune with the Wild', 'True Spirit', 'Frenzied Spirit'})
    class.addSpell('slow', {'Turgur\'s Insects', 'Togor\'s Insects'}, {opt='USESLOW'})
    class.addSpell('proc', {'Spirit of the Leopard', 'Spirit of the Jaguar'}, {classes={MNK=true,BER=true,ROG=true,BST=true,WAR=true,PAL=true,SHD=true}})
    class.addSpell('champion', {'Champion', 'Ferine Avatar'})
    class.addSpell('cure', {'Blood of Nadox'})
    class.addSpell('nuke', {'Spear of Torment'}, {opt='USENUKES'})
    class.addSpell('dot1', {'Nectar of Pain'}, {opt='USEDOTS'})
    class.addSpell('dot2', {'Curse of Sisslak'}, {opt='USEDOTS'})
    class.addSpell('dot3', {'Blood of Yoppa'}, {opt='USEDOTS'})
    class.addSpell('hottank', {'Spiritual Serenity', 'Breath of Trushar'}, {opt='USEHOTTANK', hot=true})
    class.addSpell('hotdps', {'Spiritual Serenity', 'Breath of Trushar'}, {opt='USEHOTDPS', hot=true})
    class.addSpell('slowproc', {'Lingering Sloth'}, {classes={WAR=true,PAL=true,SHD=true}})
    class.addSpell('panther', {'Talisman of the Panther'})
    class.addSpell('twincast', {'Frostfall Boon'}, {opt='USENUKES', regular=true, tank=true, tot=true})
    class.addSpell('torpor', {'Transcendent Torpor'})
    class.addSpell('rgc', {'Remove Greater Curse'}, {curse=true})
    class.addSpell('idol', {'Idol of Malos'}, {opt='USEDEBUFF'})
    class.addSpell('talisman', {'Talisman of Unification'}, {group=true, self=true})

    if class.spells.twincast then class.spells.twincast.precast = function()
            mq.cmdf('/mqtar pc =%s', mq.TLO.Group.MainTank() or _aqo.config.CHASETARGET.value)
            mq.delay(1)
        end
    end
    if class.spells.idol then class.spells.idol.condition = function()
            return mq.TLO.Spawn('Spirit Idol')() ~= nil
        end
    end
    local epic = common.getItem('Blessed Spiritstaff of the Heyokah', {opt='USEEPIC'}) or common.getItem('Crafted Talisman of Fates', {opt='USEEPIC'})

    local arcanum1 = common.getAA('Focus of Arcanum')
    local arcanum2 = common.getAA('Acute Focus of Arcanum', {skipifbuff='Enlightened Focus of Arcanum'})
    local arcanum3 = common.getAA('Enlightened Focus of Arcanum', {skipifbuff='Acute Focus of Arcanum'})
    local arcanum4 = common.getAA('Empowered Focus of Arcanum')
    table.insert(class.combatBuffs, arcanum2)
    table.insert(class.combatBuffs, arcanum3)

    table.insert(class.selfBuffs, common.getItem('Earring of Pain Deliverance', {checkfor='Reyfin\'s Random Musings'}))
    table.insert(class.selfBuffs, common.getItem('Xxeric\'s Matted-Fur Mask', {checkfor='Reyfin\'s Racing Thoughts'}))
    table.insert(class.selfBuffs, class.spells.panther)
    table.insert(class.singleBuffs, class.spells.slowproc)
    table.insert(class.singleBuffs, class.spells.proc)
    table.insert(class.selfBuffs, common.getAA('Pact of the Wolf', {removesong='Pact of the Wolf Effect'}))
    table.insert(class.selfBuffs, class.spells.champion)
    --table.insert(class.groupBuffs, common.getAA('Group Pact of the Wolf', {group=true, self=false}))
    --table.insert(class.groupBuffs, class.spells.talisman)
    -- pact of the wolf, remove pact of the wolf effect

    local standard = {}
    table.insert(standard, class.spells.twincast)
    table.insert(standard, class.spells.dot1)
    table.insert(standard, class.spells.dot2)
    table.insert(standard, class.spells.dot3)
    table.insert(standard, class.spells.nuke)

    class.spellRotations = {
        standard=standard
    }

    --table.insert(class.healAbilities, class.spells.twincast)
    table.insert(class.healAbilities, class.spells.heal)
    table.insert(class.healAbilities, class.spells.hottank)
    table.insert(class.healAbilities, class.spells.hotdps)
    table.insert(class.healAbilities, common.getAA('Union of Spirits', {panic=true, tank=true, pet=30}))
    table.insert(class.cures, class.spells.cure)
    table.insert(class.burnAbilities, common.getAA('Ancestral Aid'))
    table.insert(class.burnAbilities, epic)

    table.insert(class.cures, class.radiant)
    table.insert(class.cures, class.rgc)

    table.insert(class.debuffs, class.spells.idol)
    table.insert(class.debuffs, common.getAA('Malosinete', {opt='USEDEBUFF'}))
    table.insert(class.debuffs, common.getAA('Turgur\'s Swarm', {opt='USESLOW'}) or class.spells.slow)
    class.canni = common.getAA('Cannibalization', {mana=true, endurance=false, threshold=60, combat=true, minhp=80, ooc=false})
    table.insert(class.recoverAbilities, class.canni)
    table.insert(class.recoverAbilities, class.spells.canni)

    table.insert(class.defensiveAbilities, common.getAA('Ancestral Guard'))

    class.addRequestAlias(class.radiant, 'radiant')
    class.addRequestAlias(class.spells.torpor, 'torpor')
    class.addRequestAlias(class.spells.talisman, 'talisman')

    class.nuketimer = timer:new(3)
end

return class