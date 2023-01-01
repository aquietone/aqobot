--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local common = require('common')

class.class = 'clr'
class.classOrder = {'cure', 'heal', 'assist', 'mash', 'burn', 'recover', 'buff', 'rest', 'rez'}

class.SPELLSETS = {standard=1}
class.addCommonOptions()
class.addCommonAbilities()
class.addOption('USEYAULP', 'Use Yaulp', false, nil, 'Toggle use of Yaulp', 'checkbox')
class.addOption('USEHAMMER', 'Use Hammer', false, nil, 'Toggle use of summoned hammer pet', 'checkbox')
class.addOption('USEHOTGROUP', 'Use Group HoT', true, nil, 'Toggle use of group HoT', 'checkbox')

class.addSpell('heal', {'Ancient: Hallowed Light', 'Pious Light', 'Holy Light', 'Divine Light', 'Healing Light', 'Superior Healing', 'Light Healing', 'Minor Healing'}, {tank=true, panic=true, regular=true})
--class.addSpell('remedy', {'Pious Remedy', 'Supernal Remedy', 'Remedy'}, {regular=true, panic=true, pet=60})
class.addSpell('desperate', {'Desperate Renewal'}, {panic=true, pet=15})
class.addSpell('aura', {'Aura of Divinity'}, {aura=true})
class.addSpell('yaulp', {'Yaulp VI'}, {combat=true, ooc=false, opt='USEYAULP'})
class.addSpell('armor', {'Armor of the Pious', 'Armor of the Zealot'})
class.addSpell('spellhaste', {'Aura of Devotion'})
class.addSpell('hammerpet', {'Unswerving Hammer of Justice'}, {opt='USEHAMMER'})
class.addSpell('groupheal', {'Word of Vivification', 'Word of Replenishment', 'Word of Redemption'}, {threshold=3, group=true, pct=70})
class.addSpell('hottank', {'Pious Elixir', 'Holy Elixir'}, {opt='USEHOTTANK', hot=true})
class.addSpell('hotdps', {'Pious Elixir', 'Holy Elixir'}, {opt='USEHOTDPS', hot=true})
class.addSpell('hotgroup', {'Elixir of Divinity'}, {opt='USEHOTGROUP', grouphot=true})
class.addSpell('aego', {'Hand of Conviction', 'Hand of Virtue'})
class.addSpell('di', {'Divine Intervention'})
class.addSpell('rgc', {'Remove Greater Curse'}, {curse=true})

local standard = {}

class.spellRotations = {
    standard=standard
}

table.insert(class.DPSAbilities, class.spells.hammerpet)

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

table.insert(class.burnAbilities, common.getAA('Celestial Rapidity'))
--table.insert(class.burnAbilities, common.getAA('Celestial Regeneration'))
table.insert(class.burnAbilities, common.getAA('Exquisite Benediction'))
table.insert(class.burnAbilities, common.getAA('Flurry of Life'))
table.insert(class.burnAbilities, common.getAA('Fundament: Second Spire of Divinity'))
--table.insert(class.burnAbilities, common.getAA('Healing Frenzy'))
table.insert(class.burnAbilities, common.getAA('Improved Twincast'))

--table.insert(class.burnAbilities, common.getAA('Focused Celestial Regeneration'))

table.insert(class.cures, class.radiant)
table.insert(class.cures, class.rgc)

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

class.rezAbility = common.getAA('Blessing of Resurrection')

class.aego = class.spells.aego
class.requestAliases.aego = 'aego'
class.di = class.spells.di
class.requestAliases.di = 'di'
class.requestAliases.radiant = 'radiant'
class.spellhaste = class.spells.spellhaste
class.requestAliases.spellhaste = 'spellhaste'
class.cr = common.getAA('Celestial Regeneration')
class.requestAliases.cr = 'cr'
class.focusedcr = common.getAA('Focused Celestial Regeneration')
class.requestAliases.focusedcr = 'focusedcr'

return class