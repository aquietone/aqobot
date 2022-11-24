local class = require(AQO..'.classes.classbase')
local common = require(AQO..'.common')

class.class = 'pal'
class.classOrder = {'assist', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest'}

class.SPELLSETS = {standard=1}

class.addCommonOptions()
class.addCommonAbilities()

local standard = {}

class.spellRotations = {
    standard=standard
}

table.insert(class.DPSAbilities, common.getSkill('Kick'))

return class