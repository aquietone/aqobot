--- @type Mq
local mq = require 'mq'
local baseclass = require('aqo.classes.base')
local common = require('aqo.common')

local clr = baseclass

clr.class = 'clr'
clr.classOrder = {'heal', 'assist', 'mash', 'burn', 'recover', 'buff', 'rest'}

--mnk.OPTS.... = {label='Use Alliance',   id='##alliance',    value=true,     tip='Use alliance',               type='checkbox'}

clr.addSpell('heal', {'Minor Healing'})

table.insert(clr.healAbilities, {name=clr.spells.heal.name, id=clr.spells.heal.id, me=80, mt=80, other=80})

clr.heal = function()
    for _,heal in ipairs(clr.heals) do
        if common.is_spell_ready(heal) then
            if mq.TLO.Me.PctHPs() < heal.me then
                mq.cmdf('/mqt myself')
                mq.delay(100, function() return mq.TLO.Target.ID() == mq.TLO.Me.ID() end)
                common.cast(heal.name)
                return
            elseif mq.TLO.Group.MainTank.PctHPs() < heal.mt then
                mq.cmdf('/mqt id %d', mq.TLO.Group.MainTank.ID())
                mq.delay(100, function() return mq.TLO.Target.ID() == mq.TLO.Group.MainTank.ID() end)
                common.cast(heal.name)
                return
            elseif mq.TLO.Group.GroupSize() then
                for i=2,mq.TLO.Group.GroupSize() do
                    local member = mq.TLO.Group.Member(i)
                    if member.PctHPs() or 100 < heal.other then
                        member.DoTarget()
                        mq.delay(100, function() return mq.TLO.Target.ID() == member.ID() end)
                        common.cast(heal.name)
                        return
                    end
                end
            end
        end
    end
end

return clr