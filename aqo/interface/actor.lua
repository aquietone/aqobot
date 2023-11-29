local actors = require('actors')

local export = {
    callbacks = {}
}

function export.register(name, callback)
    export.callbacks[name] = callback
end

export.actor = actors.register("aqo", function (message)
    if message.content and export.callbacks[message.content.id] then
        export.callbacks[message.content.id](message)
    end
end)

return export

--[[
    -- example reply, unused
    if message.content.id == 'replytothismessage' then
        message:reply(0, {Name=mq.TLO.Me.CleanName()})
    end
]]