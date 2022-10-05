local baseclass = require(AQO..'.classes.base')
local common = require(AQO..'.common')

local rog = baseclass

rog.class = 'rog'
rog.classOrder = {'assist', 'mash', 'burn', 'recover', 'buff', 'rest'}

--rog.OPTS.... = {label='Use Alliance',   id='##alliance',    value=true,     tip='Use alliance',               type='checkbox'}

table.insert(rog.DPSAbilities, common.getSkill('Kick'))
table.insert(rog.DPSAbilities, common.getSkill('Backstab'))

return rog