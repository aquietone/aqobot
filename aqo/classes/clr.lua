--- @type Mq
local mq = require 'mq'
local baseclass = require(AQO..'.classes.classbase')
local common = require(AQO..'.common')

local clr = baseclass

clr.class = 'clr'
clr.classOrder = {'heal', 'assist', 'mash', 'burn', 'recover', 'buff', 'rest'}

clr.SPELLSETS = {standard=1}

clr.addOption('SPELLSET', 'Spell Set', 'standard', clr.SPELLSETS, nil, 'combobox')
clr.addOption('USEMELEE', 'Use Melee', false, nil, 'Toggle attacking mobs with melee', 'checkbox')
clr.addOption('USEYAULP', 'Use Yaulp', false, nil, 'Toggle use of Yaulp', 'checkbox')
clr.addOption('USEHAMMER', 'Use Hammer', false, nil, 'Toggle use of summoned hammer pet', 'checkbox')

--clr.addSpell('heal', {'Healing Light', 'Superior Healing', 'Light Healing', 'Minor Healing'}, {me=70, mt=70, other=50})
clr.addSpell('remedy', {'Supernal Remedy', 'Remedy'}, {me=75, mt=75, other=75})
clr.addSpell('aura', {'Aura of Divinity'}, {aura=true})
clr.addSpell('yaulp', {'Yaulp VI'}, {combat=true, ooc=false, opt='USEYAULP'})
clr.addSpell('armor', {'Armor of the Zealot'})
clr.addSpell('hammerpet', {'Unswerving Hammer of Justice'}, {opt='USEHAMMER'})
clr.addSpell('groupheal', {'Word of Replenishment', 'Word of Redemption'}, {threshold=3, group=true, pct=70})
--common.getAA('Celestial Regeneration')
--common.getAA('Divine Arbitration')

local standard = {}

clr.spellRotations = {
    standard=standard
}

table.insert(clr.DPSAbilities, clr.spells.hammerpet)

--table.insert(clr.healAbilities, clr.spells.heal)
table.insert(clr.healAbilities, common.getAA('Divine Arbitration', {me=30, mt=30, other=30}))
table.insert(clr.healAbilities, clr.spells.groupheal)
table.insert(clr.healAbilities, clr.spells.remedy)

-- Project Lazarus only
local aaAura = common.getAA('Spirit Mastery', {checkfor='Aura of Pious Divinity'})
if aaAura then
    table.insert(clr.auras, aaAura)
else
    table.insert(clr.auras, clr.spells.aura)
end
table.insert(clr.selfBuffs, clr.spells.yaulp)
table.insert(clr.selfBuffs, clr.spells.armor)

return clr