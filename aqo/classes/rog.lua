---@type Mq
local mq = require('mq')
local class = require(AQO..'.classes.classbase')
local common = require(AQO..'.common')

class.class = 'rog'
class.classOrder = {'assist', 'mash', 'burn', 'recover', 'buff', 'rest'}

class.addCommonOptions()
--class.OPTS.... = {label='Use Alliance',   id='##alliance',    value=true,     tip='Use alliance',               type='checkbox'}

table.insert(class.DPSAbilities, common.getSkill('Kick'))
table.insert(class.DPSAbilities, common.getSkill('Backstab'))
table.insert(class.DPSAbilities, common.getAA('Twisted Shank'))
table.insert(class.DPSAbilities, common.getBestDisc({'Assault'}))

table.insert(class.combatBuffs, common.getAA('Envenomed Blades'))
table.insert(class.combatBuffs, common.getBestDisc({'Thief\'s Eyes'}))
table.insert(class.selfBuffs, common.getItem('Faded Gloves of the Shadows', {checkfor='Strike Poison'}))
table.insert(class.burnAbilities, common.getAA('Rogue\'s Fury'))

table.insert(class.burnAbilities, common.getBestDisc({'Duelist Discipline'}))
table.insert(class.burnAbilities, common.getBestDisc({'Deadly Precision Discipline'}))

return class