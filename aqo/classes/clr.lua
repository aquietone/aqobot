--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local common = require('common')

function class.init(_aqo)
    class.spellRotations = {standard={}}
    class.classOrder = {'heal', 'assist', 'debuff', 'mash', 'cast', 'burn', 'recover', 'buff', 'rest', 'rez'}
    class.initBase(_aqo, 'clr')


    class.initClassOptions()
    class.loadSettings()
    class.initSpellLines(_aqo)
    class.initSpellRotations(_aqo)
    class.initHeals(_aqo)
    class.initBuffs(_aqo)
    class.initBurns(_aqo)
    class.initDPSAbilities(_aqo)

    table.insert(class.cures, class.radiant)
    --table.insert(class.cures, class.rgc)

    table.insert(class.recoverAbilities, common.getAA('Quiet Miracle', {mana=true, threshold=15, combat=true}))

    table.insert(class.debuffs, class.spells.mark)

    class.rezAbility = common.getAA('Blessing of Resurrection')
end

function class.initClassOptions()
    class.addOption('USEYAULP', 'Use Yaulp', false, nil, 'Toggle use of Yaulp', 'checkbox')
    class.addOption('USEHAMMER', 'Use Hammer', false, nil, 'Toggle use of summoned hammer pet', 'checkbox')
    class.addOption('USEHOTGROUP', 'Use Group HoT', true, nil, 'Toggle use of group HoT', 'checkbox')
    class.addOption('USESTUN', 'Use Stun', true, nil, 'Toggle use of stuns', 'checkbox')
    class.addOption('USEDEBUFF', 'Use Reverse DS', true, nil, 'Toggle use of Mark reverse DS', 'checkbox')
end

function class.initSpellLines(_aqo)
    class.addSpell('heal', {'Ancient: Hallowed Light', 'Pious Light', 'Holy Light', 'Divine Light', 'Healing Light', 'Superior Healing', 'Light Healing', 'Minor Healing'}, {tank=true, panic=true, regular=true})
    --class.addSpell('remedy', {'Pious Remedy', 'Supernal Remedy', 'Remedy'}, {regular=true, panic=true, pet=60})
    class.addSpell('desperate', {'Desperate Renewal'}, {panic=true, pet=15})
    class.addSpell('aura', {'Aura of Divinity'}, {aura=true})
    class.addSpell('yaulp', {'Yaulp VI'}, {combat=true, ooc=false, opt='USEYAULP'})
    class.addSpell('armor', {'Armor of the Pious', 'Armor of the Zealot'})
    class.addSpell('spellhaste', {'Aura of Devotion'})
    class.addSpell('hammerpet', {'Unswerving Hammer of Justice'}, {opt='USEHAMMER'})
    class.addSpell('groupheal', {'Word of Vivification', 'Word of Replenishment', 'Word of Redemption'}, {threshold=3, group=true, pct=70})
    class.addSpell('hottank', {'Pious Elixir', 'Holy Elixir', 'Celestial Healing'}, {opt='USEHOTTANK', hot=true})
    class.addSpell('hotdps', {'Pious Elixir', 'Holy Elixir', 'Celestial Healing'}, {opt='USEHOTDPS', hot=true})
    class.addSpell('hotgroup', {'Elixir of Divinity'}, {opt='USEHOTGROUP', grouphot=true})
    class.addSpell('aego', {'Hand of Conviction', 'Hand of Virtue', 'Blessing of Aegolism', 'Blessing of Temperance'}, {classes={WAR=true,SHD=true,PAL=true}})
    class.addSpell('singleaego', {'Conviction', 'Virtue', 'Aegolism', 'Temperance'}, {classes={WAR=true,SHD=true,PAL=true}})
    class.addSpell('symbol', {'Symbol of Balikor', 'Symbol of Kazad', 'Symbol of Marzin', 'Symbol of Naltron', 'Symbol of Pinzarn', 'Symbol of Ryltan', 'Symbol of Transal'}, {classes={CLR=true,DRU=true,SHM=true,MAG=true,ENC=true,WIZ=true,NEC=true}})
    class.addSpell('grpsymbol', {'Balikor\'s Mark', 'Kazad\'s Mark', 'Marzin\'s Mark', 'Naltron\'s Mark'}, {classes={CLR=true,DRU=true,SHM=true,MAG=true,ENC=true,WIZ=true,NEC=true}})
    class.addSpell('di', {'Divine Intervention'})
    class.addSpell('rgc', {'Remove Greater Curse'}, {curse=true})
    class.addSpell('stun', {'Vigilant Condemnation', 'Sound of Divinity', 'Shock of Wonder', 'Stun'}, {opt='USESTUN'})
    class.addSpell('aestun', {'Silent Dictation'})
    class.addSpell('mark', {'Mark of the Blameless', 'Mark of the Righteous', 'Mark of Kings', 'Mark of Karn', 'Mark of Retribution'}, {opt='USEDEBUFF'})
end

function class.initSpellRotations(_aqo)
    table.insert(class.spellRotations.standard, class.spells.stun)
end

function class.initHeals(_aqo)
    table.insert(class.healAbilities, common.getAA('Burst of Life', {panic=true}))
    table.insert(class.healAbilities, common.getItem('Weighted Hammer of Conviction', {tank=true, regular=true, panic=true, pet=60}))
    table.insert(class.healAbilities, common.getItem('Harmony of the Soul', {panic=true}))
    table.insert(class.healAbilities, class.spells.heal)
    table.insert(class.healAbilities, common.getAA('Divine Arbitration', {panic=true}))
    table.insert(class.healAbilities, class.spells.groupheal)
    table.insert(class.healAbilities, class.spells.hotgroup)
    --table.insert(class.healAbilities, class.spells.remedy)
    table.insert(class.healAbilities, class.spells.hottank)
    table.insert(class.healAbilities, class.spells.hotdps)
end

function class.initBuffs(_aqo)
    -- Project Lazarus only
    local aaAura = common.getAA('Spirit Mastery', {checkfor='Aura of Pious Divinity'})
    if aaAura then
        table.insert(class.auras, aaAura)
    else
        table.insert(class.auras, class.spells.aura)
    end
    table.insert(class.selfBuffs, class.spells.yaulp)
    table.insert(class.selfBuffs, class.spells.armor)
    table.insert(class.selfBuffs, class.spells.spellhaste)
    table.insert(class.selfBuffs, common.getItem('Earring of Pain Deliverance', {checkfor='Reyfin\'s Random Musings'}))
    table.insert(class.selfBuffs, common.getItem('Xxeric\'s Matted-Fur Mask', {checkfor='Reyfin\'s Racing Thoughts'}))

    table.insert(class.singleBuffs, class.spells.grpsymbol)
    table.insert(class.singleBuffs, class.spells.aego)
    table.insert(class.singleBuffs, class.spells.symbol)
    table.insert(class.singleBuffs, class.spells.singleaego)
    table.insert(class.groupBuffs, class.spells.aego)

    class.addRequestAlias(class.spells.singleaego, 'singleaego')
    class.addRequestAlias(class.spells.aego, 'aego')
    class.addRequestAlias(class.spells.symbol, 'symbol')
    class.addRequestAlias(class.spells.grpsymbol, 'grpsymbol')
    class.addRequestAlias(class.spells.spellhaste, 'spellhaste')
    class.addRequestAlias(class.spells.di, 'di')
    class.addRequestAlias(class.radiant, 'radiant')
    class.cr = common.getAA('Celestial Regeneration')
    class.addRequestAlias(class.cr, 'cr')
    class.focusedcr = common.getAA('Focused Celestial Regeneration')
    class.addRequestAlias(class.focusedcr, 'focusedcr')
end

function class.initBurns(_aqo)
    table.insert(class.burnAbilities, common.getAA('Celestial Rapidity'))
    --table.insert(class.burnAbilities, common.getAA('Celestial Regeneration'))
    table.insert(class.burnAbilities, common.getAA('Exquisite Benediction'))
    table.insert(class.burnAbilities, common.getAA('Flurry of Life'))
    table.insert(class.burnAbilities, common.getAA('Fundament: Second Spire of Divinity'))
    --table.insert(class.burnAbilities, common.getAA('Healing Frenzy'))
    table.insert(class.burnAbilities, common.getAA('Improved Twincast'))

    --table.insert(class.burnAbilities, common.getAA('Focused Celestial Regeneration'))
end

function class.initDPSAbilities(_aqo)
    table.insert(class.DPSAbilities, class.spells.hammerpet)
end

return class