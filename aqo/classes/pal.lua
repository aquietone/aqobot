local class = require('classes.classbase')
local common = require('common')

function class.init(_aqo)
    class.classOrder = {'assist', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest'}
    class.SPELLSETS = {standard=1}
    class.initBase(_aqo, 'pal')

    local standard = {}

    class.spellRotations = {
        standard=standard
    }

    table.insert(class.DPSAbilities, common.getSkill('Kick'))
end

return class