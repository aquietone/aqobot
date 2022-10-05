local baseclass = require(AQO..'.classes.base')
local common = require(AQO..'.common')

local mnk = baseclass

mnk.class = 'mnk'
mnk.classOrder = {'assist', 'mash', 'burn', 'recover', 'buff', 'rest'}

--mnk.OPTS.... = {label='Use Alliance',   id='##alliance',    value=true,     tip='Use alliance',               type='checkbox'}

table.insert(mnk.DPSAbilities, {name='Flying Kick',            type='ability'})
table.insert(mnk.DPSAbilities, {name='Tiger Claw',            type='ability'})
table.insert(mnk.DPSAbilities, common.get_disc('Leopard Claw'))

mnk.aura = common.get_disc('Disciple\'s Aura')
mnk.aura.type = 'discaura'
mnk.aura.checkfor = 'Disciples Aura'
table.insert(mnk.buffs, mnk.aura)

return mnk