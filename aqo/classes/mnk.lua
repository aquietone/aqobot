local class = require(AQO..'.classes.classbase')
local common = require(AQO..'.common')

class.class = 'mnk'
class.classOrder = {'assist', 'heal', 'mash', 'burn', 'aggro', 'recover', 'buff', 'rest'}

class.addCommonOptions()
class.addCommonAbilities()
class.addOption('USEFADE', 'Use Feign Death', true, nil, 'Toggle use of Feign Death in combat', 'checkbox')

table.insert(class.DPSAbilities, common.getItem('Fistwraps of Celestial Discipline', {delay=1000}))
table.insert(class.DPSAbilities, common.getSkill('Flying Kick'))
table.insert(class.DPSAbilities, common.getSkill('Tiger Claw'))
table.insert(class.DPSAbilities, common.getBestDisc({'Dragon Fang', 'Clawstriker\'s Flurry', 'Leopard Claw'}))
table.insert(class.DPSAbilities, common.getAA('Five Point Palm'))
--table.insert(class.DPSAbilities, common.getAA('Stunning Kick'))
table.insert(class.DPSAbilities, common.getAA('Eye Gouge'))

table.insert(class.burnAbilities, common.getAA('Fundament: Second Spire of the Sensei'))
table.insert(class.burnAbilities, common.getBestDisc({'Speed Focus Discipline'}))
table.insert(class.burnAbilities, common.getBestDisc({'Crystalpalm Discipline', 'Innerflame Discipline'}))
table.insert(class.burnAbilities, common.getBestDisc({'Heel of Kai', 'Heel of Kanji'}))
table.insert(class.burnAbilities, common.getAA('Destructive Force', {opt='USEAOE'}))

table.insert(class.auras, common.getBestDisc({'Master\'s Aura', 'Disciple\'s Aura'}, {checkfor='Disciples Aura'}))
table.insert(class.combatBuffs, common.getBestDisc({'Fists of Wu'}))
table.insert(class.combatBuffs, common.getAA('Zan Fi\'s Whistle'))
table.insert(class.combatBuffs, common.getAA('Infusion of Thunder'))
table.insert(class.selfBuffs, common.getItem('Gloves of the Crimson Sigil', {checkfor='Call of Fire'}))
table.insert(class.selfBuffs, common.getItem('Eye of Might', {checkfor='Furious Might'}))
table.insert(class.selfBuffs, common.getItem('Pauldron of Dark Auspices', {checkfor='Frost Guard'}))
--table.insert(class.selfBuffs, common.getItem('Ring of Organic Darkness', {checkfor='Taelosian Guard'}))

table.insert(class.healAbilities, common.getSkill('Mend', {me=60, self=true}))

table.insert(class.defensiveAbilities, common.getSkill('Feign Death', {stand=true}))
class.drop_aggro = common.getSkill('Feign Death')

return class