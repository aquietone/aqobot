---@type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local timer = require('utils.timer')
local common = require('common')
local config = require('interface.configuration')

function class.init(_aqo)
    class.classOrder = {'heal', 'cure', 'assist', 'aggro', 'debuff', 'cast', 'burn', 'recover', 'rez', 'buff', 'rest', 'managepet'}
    class.spellRotations = {standard={}}
    class.initBase(_aqo, 'shm')

    class.initClassOptions()
    class.loadSettings()
    class.initSpellLines(_aqo)
    class.initSpellConditions(_aqo)
    class.initSpellRotations(_aqo)
    class.initHeals(_aqo)
    class.initCures(_aqo)
    class.initBuffs(_aqo)
    class.initBurns(_aqo)
    class.initDPSAbilities(_aqo)
    class.initDebuffs(_aqo)
    class.initDefensiveAbilities(_aqo)
    class.initRecoverAbilities(_aqo)

    class.rezAbility = common.getAA('Call of the Wild')
    class.summonCompanion = common.getAA('Summon Companion')
    class.nuketimer = timer:new(3000)
end

function class.initClassOptions()
    class.addOption('USEDEBUFF', 'Use Malo', true, nil, 'Toggle casting malo on mobs', 'checkbox', nil, 'UseDebuff', 'bool')
    class.addOption('USEDISPEL', 'Use Dispel', true, nil, 'Toggle use of dispel', 'checkbox', nil, 'UseDispel', 'bool')
    class.addOption('USESLOW', 'Use Slow', true, nil, 'Toggle casting slow on mobs', 'checkbox', nil, 'UseSlow', 'bool')
    class.addOption('USENUKES', 'Use Nukes', true, nil, 'Toggle use of nukes', 'checkbox', nil, 'UseNukes', 'bool')
    class.addOption('USEDOTS', 'Use DoTs', true, nil, 'Toggle use of DoTs', 'checkbox', nil, 'UseDoTs', 'bool')
    class.addOption('USEEPIC', 'Use Epic', true, nil, 'Use epic in burns', 'checkbox', nil, 'UseEpic', 'bool')
end

function class.initSpellLines(_aqo)
    class.addSpell('heal', {'Ancient: Wilslik\'s Mending', 'Yoppa\'s Mending', 'Daluda\'s Mending', 'Chloroblast', 'Kragg\'s Salve', 'Superior Healing', 'Spirit Salve', 'Light Healing', 'Minor Healing'}, {panic=true, regular=true, tank=true, pet=60})
    class.addSpell('groupheal', {'Word of Reconstitution', 'Word of Restoration'}, {group=true})
    class.addSpell('canni', {'Cannibalize IV', 'Cannibalize III', 'Cannibalize II'}, {mana=true, threshold=70, combat=false, endurance=false, minhp=50, ooc=false})
    class.addSpell('pet', {'Commune with the Wild', 'True Spirit', 'Frenzied Spirit'})
    class.addSpell('slow', {'Turgur\'s Insects', 'Togor\'s Insects'}, {opt='USESLOW'})
    class.addSpell('proc', {'Spirit of the Leopard', 'Spirit of the Jaguar'}, {classes={MNK=true,BER=true,ROG=true,BST=true,WAR=true,PAL=true,SHD=true}})
    class.addSpell('champion', {'Champion', 'Ferine Avatar'})
    class.addSpell('cure', {'Blood of Nadox'})
    class.addSpell('nuke', {'Yoppa\'s Spear of Venom', 'Spear of Torment'}, {opt='USENUKES'})
    class.addSpell('slownuke', {'Ice Age'}, {opt='USENUKES'})
    class.addSpell('dot1', {'Nectar of Pain'}, {opt='USEDOTS'})
    class.addSpell('dot2', {'Curse of Sisslak'}, {opt='USEDOTS'})
    class.addSpell('dot3', {'Blood of Yoppa'}, {opt='USEDOTS'})
    class.addSpell('dot4', {'Breath of Wunshi', {opt='USEDOTS'}})
    class.addSpell('hottank', {'Spiritual Serenity', 'Breath of Trushar'}, {opt='USEHOTTANK', hot=true})
    class.addSpell('hotdps', {'Spiritual Serenity', 'Breath of Trushar'}, {opt='USEHOTDPS', hot=true})
    class.addSpell('slowproc', {'Lingering Sloth'}, {classes={WAR=true,PAL=true,SHD=true}})
    class.addSpell('panther', {'Talisman of the Panther'})
    class.addSpell('twincast', {'Frostfall Boon'}, {opt='USENUKES', regular=true, tank=true, tot=true})
    class.addSpell('torpor', {'Transcendent Torpor'})
    class.addSpell('rgc', {'Remove Greater Curse'}, {curse=true})
    class.addSpell('idol', {'Idol of Malos'}, {opt='USEDEBUFF'})
    class.addSpell('talisman', {'Talisman of Unification'}, {group=true, self=true, classes={WAR=true,SHD=true,PAL=true}})
    class.addSpell('focus', {'Talisman of Wunshi'}, {classes={WAR=true,SHD=true,PAL=true}})
    class.addSpell('dispel', {'Abashi\'s Disempowerment'}, {opt='USEDISPEL'})
    class.addSpell('debuff', {'Crippling Spasm'}, {opt='USEDEBUFF'})
end

function class.initSpellConditions(_aqo)
    if class.spells.twincast then
        class.spells.twincast.precast = function()
            mq.cmdf('/mqtar pc =%s', mq.TLO.Group.MainTank() or config.get('CHASETARGET'))
            mq.delay(1)
        end
    end
    if class.spells.idol then
        class.spells.idol.condition = function()
            return mq.TLO.Spawn('Spirit Idol')() ~= nil
        end
    end
end

function class.initSpellRotations(_aqo)
    table.insert(class.spellRotations.standard, class.spells.twincast)
    table.insert(class.spellRotations.standard, class.spells.slownuke)
    table.insert(class.spellRotations.standard, class.spells.dot1)
    table.insert(class.spellRotations.standard, class.spells.dot2)
    table.insert(class.spellRotations.standard, class.spells.dot3)
    table.insert(class.spellRotations.standard, class.spells.dot4)
    table.insert(class.spellRotations.standard, class.spells.nuke)
end

function class.initDPSAbilities(_aqo)

end

function class.initBurns(_aqo)
    local epic = common.getItem('Blessed Spiritstaff of the Heyokah', {opt='USEEPIC'}) or common.getItem('Crafted Talisman of Fates', {opt='USEEPIC'})

    table.insert(class.burnAbilities, common.getAA('Ancestral Aid'))
    table.insert(class.burnAbilities, epic)
    table.insert(class.burnAbilities, common.getAA('Rabid Bear'))
    table.insert(class.burnAbilities, common.getAA('Fundament: First spire of Ancestors'))
end

function class.initHeals(_aqo)
    --table.insert(class.healAbilities, class.spells.twincast)
    table.insert(class.healAbilities, class.spells.heal)
    table.insert(class.healAbilities, class.spells.hottank)
    table.insert(class.healAbilities, class.spells.hotdps)
    table.insert(class.healAbilities, common.getAA('Union of Spirits', {panic=true, tank=true, pet=30}))
end

function class.initCures(_aqo)
    table.insert(class.cures, class.spells.cure)
    table.insert(class.cures, class.radiant)
    table.insert(class.cures, class.spells.rgc)
end

function class.initBuffs(_aqo)
    table.insert(class.combatBuffs, class.spells.champion)
    table.insert(class.selfBuffs, common.getItem('Earring of Pain Deliverance', {CheckFor='Reyfin\'s Random Musings'}))
    table.insert(class.selfBuffs, common.getItem('Xxeric\'s Matted-Fur Mask', {CheckFor='Reyfin\'s Racing Thoughts'}))
    local pantherTablet = mq.TLO.FindItem('Imbued Rune of the Panther')()
    if not pantherTablet then
        table.insert(class.selfBuffs, class.spells.panther)
    end
    table.insert(class.singleBuffs, class.spells.slowproc)
    table.insert(class.singleBuffs, class.spells.proc)
    table.insert(class.selfBuffs, common.getAA('Pact of the Wolf', {RemoveBuff='Pact of the Wolf Effect'}))
    table.insert(class.selfBuffs, class.spells.champion)
    table.insert(class.selfBuffs, common.getAA('Languid Bite'))
    table.insert(class.singleBuffs, class.spells.focus)
    table.insert(class.singleBuffs, class.spells.talisman)
    table.insert(class.singleBuffs, common.getAA('Group Pact of the Wolf', {classes={SHD=true,WAR=true}}))
    --table.insert(class.groupBuffs, common.getAA('Group Pact of the Wolf', {group=true, self=false}))
    --table.insert(class.groupBuffs, class.spells.talisman)
    -- pact of the wolf, remove pact of the wolf effect

    class.addRequestAlias(class.radiant, 'radiant')
    class.addRequestAlias(class.spells.torpor, 'torpor')
    class.addRequestAlias(class.spells.talisman, 'talisman')
    class.addRequestAlias(class.spells.focus, 'focus')
end

function class.initDebuffs(_aqo)
    table.insert(class.debuffs, class.spells.dispel)
    table.insert(class.debuffs, class.spells.idol)
    table.insert(class.debuffs, common.getAA('Malosinete', {opt='USEDEBUFF'}))
    table.insert(class.debuffs, common.getAA('Turgur\'s Swarm', {opt='USESLOW'}) or class.spells.slow)
    table.insert(class.debuffs, class.spells.debuff)
end

function class.initDefensiveAbilities(_aqo)
    table.insert(class.defensiveAbilities, common.getAA('Ancestral Guard'))
end

function class.initRecoverAbilities(_aqo)
    class.canni = common.getAA('Cannibalization', {mana=true, endurance=false, threshold=60, combat=true, minhp=80, ooc=false})
    table.insert(class.recoverAbilities, class.canni)
    table.insert(class.recoverAbilities, class.spells.canni)
end

return class