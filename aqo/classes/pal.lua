local class = require('classes.classbase')
local common = require('common')

function class.init(_aqo)
    class.initBase(_aqo)
    class.load_settings()
    class.setup_events()

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
end

return class