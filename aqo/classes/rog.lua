local baseclass = require('aqo.classes.base')

local rog = baseclass

rog.class = 'rog'
rog.classOrder = {'assist', 'mash', 'burn', 'recover', 'rest'}

--rog.OPTS.... = {label='Use Alliance',   id='##alliance',    value=true,     tip='Use alliance',               type='checkbox'}

table.insert(rog.DPSAbilities, {name='Kick',            type='ability'})

return rog