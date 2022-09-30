local baseclass = require('aqo.classes.base')

local mnk = baseclass

mnk.class = 'mnk'
mnk.classOrder = {'assist', 'mash', 'burn', 'recover', 'buff', 'rest'}

--mnk.OPTS.... = {label='Use Alliance',   id='##alliance',    value=true,     tip='Use alliance',               type='checkbox'}

table.insert(mnk.DPSAbilities, {name='Flying Kick',            type='ability'})
table.insert(mnk.DPSAbilities, {name='Tiger Claw',            type='ability'})

return mnk