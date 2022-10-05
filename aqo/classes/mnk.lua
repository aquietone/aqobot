local baseclass = require(AQO..'.classes.base')
local common = require(AQO..'.common')

local mnk = baseclass

mnk.class = 'mnk'
mnk.classOrder = {'assist', 'mash', 'burn', 'recover', 'buff', 'rest'}

--mnk.OPTS.... = {label='Use Alliance',   id='##alliance',    value=true,     tip='Use alliance',               type='checkbox'}

table.insert(mnk.DPSAbilities, common.getSkill('Flying Kick'))
table.insert(mnk.DPSAbilities, common.getSkill('Tiger Claw'))
table.insert(mnk.DPSAbilities, common.getBestDisc({'Leopard Claw'}))

mnk.aura = common.getBestDisc({'Disciple\'s Aura'})
mnk.aura.type = 'discaura'
mnk.aura.checkfor = 'Disciples Aura'
table.insert(mnk.buffs, mnk.aura)

return mnk