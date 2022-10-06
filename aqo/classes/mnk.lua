local baseclass = require(AQO..'.classes.base')
local common = require(AQO..'.common')

local mnk = baseclass

mnk.class = 'mnk'
mnk.classOrder = {'assist', 'mash', 'burn', 'recover', 'buff', 'rest'}

--mnk.OPTS.... = {label='Use Alliance',   id='##alliance',    value=true,     tip='Use alliance',               type='checkbox'}

table.insert(mnk.DPSAbilities, common.getSkill('Flying Kick'))
table.insert(mnk.DPSAbilities, common.getSkill('Tiger Claw'))
table.insert(mnk.DPSAbilities, common.getBestDisc({'Clawstriker\'s Fury', 'Leopard Claw'}))

table.insert(mnk.burnAbilities, common.getBestDisc({'Innerflame Discipline'}))
table.insert(mnk.burnAbilities, common.getBestDisc({'Thunderkick Discipline'}))

table.insert(mnk.buffs, common.getBestDisc({'Master\'s Aura', 'Disciple\'s Aura'}, {combat=false, checkfor='Disciples Aura'}))
table.insert(mnk.buffs, common.getBestDisc({'Fists of Wu'}, {combat=true, ooc=false}))

return mnk