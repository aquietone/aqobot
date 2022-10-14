local baseclass = require(AQO..'.classes.classbase')
local common = require(AQO..'.common')

local mnk = baseclass

mnk.class = 'mnk'
mnk.classOrder = {'assist', 'heal', 'mash', 'burn', 'recover', 'buff', 'rest'}

--mnk.OPTS.... = {label='Use Alliance',   id='##alliance',    value=true,     tip='Use alliance',               type='checkbox'}

table.insert(mnk.DPSAbilities, common.getSkill('Flying Kick'))
table.insert(mnk.DPSAbilities, common.getSkill('Tiger Claw'))
table.insert(mnk.DPSAbilities, common.getBestDisc({'Clawstriker\'s Flurry', 'Leopard Claw'}))

table.insert(mnk.burnAbilities, common.getBestDisc({'Heel of Kanji'}))
table.insert(mnk.burnAbilities, common.getBestDisc({'Innerflame Discipline'}))
table.insert(mnk.burnAbilities, common.getBestDisc({'Speed Focus Discipline'}))

table.insert(mnk.auras, common.getBestDisc({'Master\'s Aura', 'Disciple\'s Aura'}, {checkfor='Disciples Aura'}))
table.insert(mnk.combatBuffs, common.getBestDisc({'Fists of Wu'}))
table.insert(mnk.combatBuffs, common.getAA('Zan Fi\'s Whistle'))
table.insert(mnk.combatBuffs, common.getAA('Infusion of Thunder'))
table.insert(mnk.selfBuffs, common.getItem('Gloves of the Crimson Sigil', {checkfor='Call of Fire'}))

table.insert(mnk.healAbilities, common.getSkill('Mend', {me=60, self=true}))

return mnk