local baseclass = require('aqo.classes.base')

local ber = baseclass

ber.class = 'ber'
ber.classOrder = {'assist', 'mash', 'burn', 'recover', 'buff', 'rest'}

--ber.OPTS.... = {label='Use Alliance',   id='##alliance',    value=true,     tip='Use alliance',               type='checkbox'}

--table.insert(ber.DPSAbilities, {name='Kick',            type='ability'})

return ber