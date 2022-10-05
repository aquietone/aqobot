---@type Mq
local mq = require('mq')
local baseclass = require(AQO..'.classes.base')
local common = require(AQO..'.common')

local ber = baseclass

ber.class = 'ber'
ber.classOrder = {'assist', 'mash', 'burn', 'recover', 'buff', 'rest'}

--ber.OPTS.... = {label='Use Alliance',   id='##alliance',    value=true,     tip='Use alliance',               type='checkbox'}

table.insert(ber.DPSAbilities, common.getSkill('Kick'))
table.insert(ber.DPSAbilities, common.getSkill('Frenzy'))
table.insert(ber.DPSAbilities, common.getBestDisc({'Rage Volley'}))
--table.insert(ber.DPSAbilities, common.getBestDisc({'Head Pummel'}))
--table.insert(ber.DPSAbilities, common.getBestDisc({'Leg Cut'}))

local aura = common.getBestDisc({'Aura of Rage'})
aura.type = 'discaura'
table.insert(ber.buffs, aura)
-- Aura of Rage, Aura of Rage Effect

local axes = mq.TLO.FindItem('Bonesplicer Axe').ID()
local components = mq.TLO.FindItem('Axe Components').ID()
local summonaxes = common.getBestDisc({'Bonesplicer Axe'})

ber.buff_class = function()
    local numAxes = mq.TLO.FindItemCount(axes)()
    if numAxes <= 25 and summonaxes then
        local numComponents = mq.TLO.FindItemCount(components)()
        if numComponents > 0 then
            summonaxes:use()
        end
    end
end

return ber