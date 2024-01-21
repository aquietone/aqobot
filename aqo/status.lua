local mq = require('mq')
local state = require('state')
local actor = require('interface.actor')
local Timer = require('utils.timer')

local status = {}

function status.init()
    actor.register('status', status.callback)
end

local function processTable(parent, tableName, tableValue)
    parent[tableName] = {}
    for key, value in pairs(tableValue) do
        if type('value') == 'table' then
            processTable(parent[tableName], key, value)
        else
            parent[tableName][key] = value
        end
    end
end

function status.callback(message)
    state.actors[message.content.Name] = state.actors[message.content.Name] or {}
    for key, value in pairs(message.content) do
        if key ~= 'Name' and key ~= 'id' then
            if type(value) == 'table' then
                processTable(state.actors[message.content.Name], key, value)
            else
                state.actors[message.content.Name][key] = value
            end
        end
    end
    if not message.content.buffs then state.actors[message.content.Name].buffs = nil end
    if not message.content.songs then state.actors[message.content.Name].songs = nil end
    if not message.content.wantBuffs then state.actors[message.content.Name].wantBuffs = nil end
    if not message.content.gimme then state.actors[message.content.Name].gimme = nil end
    for toon, toonState in pairs(state.actors) do
        if mq.gettime() - (toonState.LastSent or 0) > 30000 then
            state.actors[toon] = nil
        end
    end
end

local statusTimer = Timer:new(1000)
function status.send(class)
    if not statusTimer:timerExpired() then return end
    statusTimer:reset()
    local header = {script = 'aqo'}
    -- Send info on any debuffs
    local buffs = {}
    for i=1,42 do
        local aBuff = mq.TLO.Me.Buff(i)
        if aBuff() and not aBuff.Spell.Beneficial() then
            local buffData = {Name=aBuff.Name(),Duration=aBuff.Duration.TotalSeconds()}
            if aBuff.CounterNumber() and aBuff.CounterNumber() > 0 then
                buffData.CounterNumber=aBuff.CounterNumber()
                buffData.CounterType=aBuff.CounterType()
            end
            table.insert(buffs, buffData)
        end
    end
    local songs = {}
    for i=1,20 do
        local aSong = mq.TLO.Me.Song(i)
        if aSong() and not aSong.Spell.Beneficial() then
            local songData = {Name=aSong.Name(),Duration=aSong.Duration.TotalSeconds()}
            if aSong.CounterNumber() and aSong.CounterNumber() > 0 then
                songData.CounterNumber=aSong.CounterNumber()
                songData.CounterType=aSong.CounterType()
            end
            table.insert(songs, songData)
        end
    end
    -- Send info on any missing or fading buffs
    local wantBuffs = class:wantBuffs()
    local availableBuffs = class:getRequestAliases()
    local gimme = {}
    local availableSupplies = {}
    local status = {
        id = 'status',
        Name = mq.TLO.Me.CleanName(),
        Class = mq.TLO.Me.Class.ShortName(),
        Buffs = buffs,
        Songs = songs,
        wantBuffs = wantBuffs,
        availableBuffs = availableBuffs,
        gimme = gimme,
        availableSupplies = availableSupplies,
        LastSent = mq.gettime(),
    }
    actor.actor:send(header, status)
end

return status