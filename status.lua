local mq = require('mq')
local actor = require('interface.actor')
local Timer = require('libaqo.timer')
local mode  = require('mode')
local state = require('state')

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
    if not message.content.Buffs then state.actors[message.content.Name].Buffs = nil end
    if not message.content.Songs then state.actors[message.content.Name].Songs = nil end
    if not message.content.wantBuffs then state.actors[message.content.Name].wantBuffs = nil end
    if not message.content.gimme then state.actors[message.content.Name].gimme = nil end
    for toon, toonState in pairs(state.actors) do
        if mq.gettime() - (toonState.LastSent or 0) > 30000 then
            state.actors[toon] = nil
        end
    end
end

local ignoredebuffs = {['HC Jugular Gash']=true, ['Resurrection Sickness']=true, ['Revival Sickness']=true, ['HC Roar of Challenge']=true, ['Aura of Destruction']=true, ['HC Knuckle Smash']=true}
local statusTimer = Timer:new(1000)
function status.send(class)
    if not statusTimer:expired() then return end
    statusTimer:reset()
    local header = {script = 'aqo', server = mq.TLO.EverQuest.Server()}
    -- Send info on any debuffs
    local buffs = {}
    for i=1,42 do
        local aBuff = mq.TLO.Me.Buff(i)
        if aBuff() and not aBuff.Spell.Beneficial() and not ignoredebuffs[aBuff.Name()] then
            local buffData = {Name=aBuff.Name(),Duration=aBuff.Duration.TotalSeconds()}
            if aBuff.CounterNumber() and (aBuff.CounterNumber() or 0) > 0 then
                buffData.CounterNumber=aBuff.CounterNumber()
                buffData.CounterType=aBuff.CounterType()
            end
            table.insert(buffs, buffData)
        end
    end
    if state.testCures then
        table.insert(buffs, {Name='Poison Debuff', Duration=60, CounterNumber=10, CounterType='Poison'})
        -- table.insert(buffs, {Name='Corruption Debuff', Duration=60, CounterNumber=10, CounterType='Corruption'})
        -- table.insert(buffs, {Name='Disease Debuff', Duration=60, CounterNumber=10, CounterType='Disease'})
        -- table.insert(buffs, {Name='Curse Debuff', Duration=60, CounterNumber=10, CounterType='Curse'})
        -- table.insert(buffs, {Name='Debuff', Duration=60})
    end
    local songs = {}
    for i=1,20 do
        local aSong = mq.TLO.Me.Song(i)
        if aSong() and not aSong.Spell.Beneficial() then
            local songData = {Name=aSong.Name(),Duration=aSong.Duration.TotalSeconds()}
            if aSong.CounterNumber() and (aSong.CounterNumber() or 0) > 0 then
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
    local missingAggro = {}
    if mode.currentMode:isTankMode() then
        for i=1,mq.TLO.Me.XTargetSlots() do
            if (mq.TLO.Me.XTarget(i).PctAggro() or 100) < 100 then
                table.insert(missingAggro, mq.TLO.Me.XTarget(i).ID())
            end
        end
    end

    local status = {
        id = 'status',
        Name = mq.TLO.Me.CleanName(),
        Class = mq.TLO.Me.Class.ShortName(),
        Buffs = buffs,
        Songs = songs,
        wantBuffs = wantBuffs,
        availableBuffs = availableBuffs,
        missingAggro = missingAggro,
        gimme = gimme,
        availableSupplies = availableSupplies,
        LastSent = mq.gettime(),
    }
    actor.actor:send(header, status)
end

return status