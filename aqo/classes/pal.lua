local class = require('classes.classbase')
local common = require('common')

function class.init(_aqo)
    class.classOrder = {'assist', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest'}
    class.spellRotations = {standard={}}
    class.initBase(_aqo, 'pal')
    class.loadSettings()

    table.insert(class.DPSAbilities, common.getSkill('Kick'))
end

return class