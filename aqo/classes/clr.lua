--- @type Mq
local mq = require 'mq'
local class = require(AQO..'.classes.classbase')
local common = require(AQO..'.common')

class.class = 'clr'
class.classOrder = {'heal', 'assist', 'mash', 'burn', 'recover', 'buff', 'rest'}

class.SPELLSETS = {standard=1}
class.addCommonOptions()
class.addOption('USEYAULP', 'Use Yaulp', false, nil, 'Toggle use of Yaulp', 'checkbox')
class.addOption('USEHAMMER', 'Use Hammer', false, nil, 'Toggle use of summoned hammer pet', 'checkbox')

--class.addSpell('heal', {'Healing Light', 'Superior Healing', 'Light Healing', 'Minor Healing'}, {me=70, mt=70, other=50})
class.addSpell('remedy', {'Supernal Remedy', 'Remedy'}, {me=75, mt=75, other=75})
class.addSpell('aura', {'Aura of Divinity'}, {aura=true})
class.addSpell('yaulp', {'Yaulp VI'}, {combat=true, ooc=false, opt='USEYAULP'})
class.addSpell('armor', {'Armor of the Zealot'})
class.addSpell('hammerpet', {'Unswerving Hammer of Justice'}, {opt='USEHAMMER'})
class.addSpell('groupheal', {'Word of Replenishment', 'Word of Redemption'}, {threshold=3, group=true, pct=70})
--common.getAA('Celestial Regeneration')
--common.getAA('Divine Arbitration')

local standard = {}

class.spellRotations = {
    standard=standard
}

table.insert(class.DPSAbilities, class.spells.hammerpet)

--table.insert(class.healAbilities, class.spells.heal)
table.insert(class.healAbilities, common.getAA('Divine Arbitration', {me=30, mt=30, other=30}))
table.insert(class.healAbilities, class.spells.groupheal)
table.insert(class.healAbilities, class.spells.remedy)

-- Project Lazarus only
local aaAura = common.getAA('Spirit Mastery', {checkfor='Aura of Pious Divinity'})
if aaAura then
    table.insert(class.auras, aaAura)
else
    table.insert(class.auras, class.spells.aura)
end
table.insert(class.selfBuffs, class.spells.yaulp)
table.insert(class.selfBuffs, class.spells.armor)

return class