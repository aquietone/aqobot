---@type Mq
local mq = require('mq')
local class = require(AQO..'.classes.classbase')
local common = require(AQO..'.common')
local state = require(AQO..'.state')

class.class = 'ber'
class.classOrder = {'assist', 'mash', 'burn', 'recover', 'buff', 'rest'}

class.addCommonOptions()
class.addCommonAbilities()
--class.addOption('USEEPIC', 'Epic', 'always', class.EPIC_OPTS, nil, 'combobox')
if state.emu then
    class.addOption('USEDECAP', 'Use Decap', true, nil, 'Toggle use of decap AA', 'checkbox')
end

table.insert(class.DPSAbilities, common.getItem('Raging Taelosian Alloy Axe'))
table.insert(class.DPSAbilities, common.getBestDisc({'Overpowering Frenzy'}))
table.insert(class.DPSAbilities, common.getSkill('Frenzy'))
table.insert(class.DPSAbilities, common.getBestDisc({'Destroyer\'s Volley', 'Rage Volley'}))
table.insert(class.DPSAbilities, common.getBestDisc({'Confusing Strike'}))
table.insert(class.DPSAbilities, common.getAA('Binding Axe'))
table.insert(class.DPSAbilities, common.getBestDisc({'Bewildering Scream'}))
--table.insert(class.DPSAbilities, common.getBestDisc({'Head Pummel'}))
--table.insert(class.DPSAbilities, common.getBestDisc({'Leg Cut'}))

table.insert(class.AEDPSAbilities, common.getAA('Rampage', {threshold=3}))

--quick burns
table.insert(class.burnAbilities, common.getBestDisc({'Cleaving Anger Discipline'}, {quick=true}))
table.insert(class.burnAbilities, common.getItem('Rage Bound Chestguard', {quick=true}))
table.insert(class.burnAbilities, common.getAA('Fundament: Third Spire of Savagery', {quick=true}))
table.insert(class.burnAbilities, common.getAA('Vehement Rage', {quick=true}))
table.insert(class.burnAbilities, common.getAA('Juggernaut Surge', {quick=true}))
table.insert(class.burnAbilities, common.getAA('Blood Pact', {quick=true}))
table.insert(class.burnAbilities, common.getBestDisc({'Blind Rage Discipline'}, {quick=true}))
table.insert(class.burnAbilities, common.getBestDisc({'Cleaving Rage Discipline'}, {quick=true, long=true}))
table.insert(class.burnAbilities, common.getAA('Cry of Battle', {quick=true}))
table.insert(class.burnAbilities, common.getAA('Uncanny Resilience'))

-- long burns
table.insert(class.burnAbilities, common.getAA('Savage Spirit', {long=true}))
table.insert(class.burnAbilities, common.getAA('Untamed Rage', {long=true}))
table.insert(class.burnAbilities, common.getBestDisc({'Cleaving Rage Discipline'}, {long=true}))
table.insert(class.burnAbilities, common.getBestDisc({'Ancient: Cry of Chaos'}, {long=true}))
table.insert(class.burnAbilities, common.getBestDisc({'Vengeful Flurry Discipline'}, {long=true}))
table.insert(class.burnAbilities, common.getAA('Fundament: Second Spire of Savagery', {long=true}))
table.insert(class.burnAbilities, common.getBestDisc({'War Cry'}, {long=true}))
table.insert(class.burnAbilities, common.getAA('Reckless Abandon', {long=true}))
table.insert(class.burnAbilities, common.getAA('Cascading Rage', {long=true}))
table.insert(class.burnAbilities, common.getAA('Blinding Fury', {long=true}))


table.insert(class.combatBuffs, common.getBestDisc({'Cry Havoc'}, {combat=true, ooc=false}))
if state.emu then table.insert(class.combatBuffs, common.getAA('Decapitation', {opt='USEDECAP', combat=true})) end
table.insert(class.combatBuffs, common.getAA('Battle Leap'))

table.insert(class.auras, common.getBestDisc({'Bloodlust Aura', 'Aura of Rage'}, {combat=false}))

table.insert(class.selfBuffs, common.getBestDisc({'Bonesplicer Axe'}, {summons='Bonesplicer Axe', summonMinimum=101, summonComponent='Axe Components'}))

return class