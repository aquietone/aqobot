---@type Mq
local mq = require('mq')
local baseclass = require(AQO..'.classes.classbase')
local common = require(AQO..'.common')

local rog = baseclass

rog.class = 'rog'
rog.classOrder = {'assist', 'mash', 'burn', 'recover', 'buff', 'rest'}

--rog.OPTS.... = {label='Use Alliance',   id='##alliance',    value=true,     tip='Use alliance',               type='checkbox'}

table.insert(rog.DPSAbilities, common.getSkill('Kick'))
table.insert(rog.DPSAbilities, common.getSkill('Backstab'))

table.insert(rog.combatBuffs, common.getAA('Envenomed Blades'))
table.insert(rog.combatBuffs, common.getBestDisc({'Thief\'s Eyes'}))
table.insert(rog.selfBuffs, common.getItem('Faded Gloves of the Shadows', {checkfor='Strike Poison'}))
table.insert(rog.burnAbilities, common.getAA('Rogue\'s Fury'))

table.insert(rog.burnAbilities, common.getBestDisc({'Duelist Discipline'}))
table.insert(rog.burnAbilities, common.getBestDisc({'Deadly Precision Discipline'}))

return rog