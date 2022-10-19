local class = require(AQO..'.classes.classbase')
local common = require(AQO..'.common')

class.class = 'mnk'
class.classOrder = {'assist', 'heal', 'mash', 'burn', 'recover', 'buff', 'rest'}

class.addCommonOptions()
--class.OPTS.... = {label='Use Alliance',   id='##alliance',    value=true,     tip='Use alliance',               type='checkbox'}

table.insert(class.DPSAbilities, common.getSkill('Flying Kick'))
table.insert(class.DPSAbilities, common.getSkill('Tiger Claw'))
table.insert(class.DPSAbilities, common.getBestDisc({'Dragon Fang', 'Clawstriker\'s Flurry', 'Leopard Claw'}))

table.insert(class.burnAbilities, common.getBestDisc({'Heel of Kai', 'Heel of Kanji'}))
table.insert(class.burnAbilities, common.getBestDisc({'Innerflame Discipline'}))
table.insert(class.burnAbilities, common.getBestDisc({'Speed Focus Discipline'}))

table.insert(class.auras, common.getBestDisc({'Master\'s Aura', 'Disciple\'s Aura'}, {checkfor='Disciples Aura'}))
table.insert(class.combatBuffs, common.getBestDisc({'Fists of Wu'}))
table.insert(class.combatBuffs, common.getAA('Zan Fi\'s Whistle'))
table.insert(class.combatBuffs, common.getAA('Infusion of Thunder'))
table.insert(class.selfBuffs, common.getItem('Gloves of the Crimson Sigil', {checkfor='Call of Fire'}))
table.insert(class.selfBuffs, common.getItem('Pauldron of Dark Auspices', {checkfor='Frost Guard'}))

table.insert(class.healAbilities, common.getSkill('Mend', {me=60, self=true}))

return class