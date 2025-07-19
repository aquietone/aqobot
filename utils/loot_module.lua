local mq = require 'mq'
local actors = require('actors')

local loot_module = {}

function loot_module.init()
    loot_module.module_actor = actors.register('loot_module', loot_module.module_callback)
    loot_module.lns_actor = actors.register('lootnscoot', loot_module.lns_callback)
    mq.cmdf('/lua run lootnscoot directed aqo lootnscoot')
end

function loot_module.lns_callback(message)
    local action = message.content.action
    -- printf('action: %s', action)
end

function loot_module.module_callback(message)
    local msg = message()
    local subject = msg.Subject
    -- printf('subject: %s', subject)
    if msg.Who == mq.TLO.Me.CleanName() and (subject == 'done_looting' or subject == 'done_processing') then
        loot_module.looting = false
    end
end

function loot_module.doloot()
    loot_module.looting = true
    loot_module.lns_actor:send({script='lootnscoot',mailbox='lootnscoot'},{directions='doloot',who=mq.TLO.Me.CleanName(),limit=3})
    local timeout = 10000
    local starttime = mq.gettime()
    while loot_module.looting do
        if mq.gettime() - starttime > timeout then loot_module.looting = false break end
        mq.delay(100)
    end
    -- printf('done looting after %s', mq.gettime() - starttime)
end

return loot_module