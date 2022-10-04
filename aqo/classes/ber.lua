---@type Mq
local mq = require('mq')
local baseclass = require('aqo.classes.base')
local common = require('aqo.common')

local ber = baseclass

ber.class = 'ber'
ber.classOrder = {'assist', 'mash', 'burn', 'recover', 'buff', 'rest'}

--ber.OPTS.... = {label='Use Alliance',   id='##alliance',    value=true,     tip='Use alliance',               type='checkbox'}

--table.insert(ber.DPSAbilities, {name='Kick',            type='ability'})
--table.insert(ber.DPSAbilities, common.get_disc('Head Pummel'))
--table.insert(ber.DPSAbilities, common.get_disc('Leg Cut'))

local aura = common.get_disc('Aura of Rage')
aura.type = 'discaura'
table.insert(ber.buffs, aura)
-- Aura of Rage, Aura of Rage Effect

local axes = mq.TLO.FindItem('Bonesplicer Axe').ID()
local components = mq.TLO.FindItem('Axe Components').ID()
local summonaxes = common.get_disc('Bonesplicer Axe')

ber.buff_class = function()
    local numAxes = mq.TLO.FindItemCount(axes)()
    if numAxes <= 25 and summonaxes then
        local numComponents = mq.TLO.FindItemCount(components)()
        if numComponents > 0 then
            common.use[summonaxes.type](summonaxes)
        end
    end
end

return ber