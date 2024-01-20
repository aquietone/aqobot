--- @type Mq
local mq = require 'mq'
local config = require('interface.configuration')
local helpers = require('utils.helpers')
local logger = require('utils.logger')
local movement = require('utils.movement')
local timer = require('utils.timer')
local common = require('common')
local mode = require('mode')
local state = require('state')

local camp = {
    Active=false,
    X=0,
    Y=0,
    Z=0,
    Heading=0,
    ZoneID=0,
    PullArcLeft=0,
    PullArcRight=0,
}

function camp.init() end

function camp.mobRadarB()
    local distanceFromCamp = false
    local x, y, z
    if camp.Active or mode.currentMode:getName() ~= 'huntertank' then
        distanceFromCamp = true
        x, y, z = camp.X, camp.Y, camp.Z
    end
    local xtarIDs = {}
    for i=1,20 do
        local xtarID = mq.TLO.Me.XTarget(i).ID()
        if xtarID then
            xtarIDs[xtarID] = true
        end
    end
    local function campPredicate(spawn)
        if spawn.Type() ~= 'NPC' then return false end
        if distanceFromCamp then
            local d = helpers.distance(x, spawn.X(), y, spawn.Y())
            if d > config.get('CAMPRADIUS')^2 then return false end
        else
            if spawn.Distance3D() > config.get('CAMPRADIUS') then return false end
        end
        if not xtarIDs[spawn.ID()] then return false end
        return true
    end

    state.targets = mq.getFilteredSpawns(campPredicate)
    state.mobCount = #state.targets
    state.mobCountNoPets = #state.targets
end

local xtar_count = 'xtarhater npc radius %d zradius 50 loc %d %d %d'
local xtar_spawn = '%d, xtarhater npc radius %d zradius 50 loc %d %d %d'
local xtar_nopet_count = 'xtarhater radius %d zradius 50 nopet loc %d %d %d'
---Determine the number of mobs within the camp radius.
---Sets common.mobCount to the total number of mobs on xtarget within the camp radius.
---Adds the mob ID of each mob found to the common.TARGETS table.
function camp.mobRadar()
    local x, y, z
    if not camp.Active or mode.currentMode:getName() == 'huntertank' then
        x, y, z = mq.TLO.Me.X(), mq.TLO.Me.Y(), mq.TLO.Me.Z()
    else
        x, y, z = camp.X, camp.Y, camp.Z
    end
    logger.debug(logger.flags.routines.camp, xtar_count:format(config.get('CAMPRADIUS') or 0, x, y, z))
    state.mobCount = mq.TLO.SpawnCount(xtar_count:format(config.get('CAMPRADIUS') or 0, x, y, z))()
    state.mobCountNoPets = mq.TLO.SpawnCount(xtar_nopet_count:format(config.get('CAMPRADIUS') or 0, x, y, z))()
    if state.mobCount > 0 then
        for i=1,state.mobCount do
            if i > 13 then break end
            logger.debug(logger.flags.routines.camp, xtar_spawn:format(i, config.get('CAMPRADIUS') or 0, x, y, z))
            local mob = mq.TLO.NearestSpawn(xtar_spawn:format(i, config.get('CAMPRADIUS') or 0, x, y, z))
            local mob_id = mob.ID()
            if mob_id and mob_id > 0 then
                if not mob() or mob.Type() == 'Corpse' then
                    state.targets[mob_id] = nil
                elseif not state.targets[mob_id] then
                    logger.debug(logger.flags.routines.camp, 'Adding mob_id %d', mob_id)
                    state.targets[mob_id] = {meztimer=timer:new(30000)}
                    state.targets[mob_id].meztimer:reset(0)
                end
            end
        end
    end
end

---Checks for any mobs in common.TARGETS which are no longer valid and removes them from the table.
function camp.cleanTargets()
    for mobid,_ in pairs(state.targets) do
        local spawn = mq.TLO.Spawn(string.format('id %s', mobid))
        if not spawn() or spawn.Type() == 'Corpse' then
            state.targets[mobid] = nil
        end
    end
end

---Return to camp if alive and in a camp mode and not currently fighting and more than 15ft from the camp center location.
local checkCampTimer = timer:new(2000)
function camp.checkCamp()
    if not mode.currentMode:isReturnToCampMode() or not camp.Active then return end
    if not checkCampTimer:timerExpired() then return end
    checkCampTimer:reset()
    if (state.class ~= 'BRD' and mq.TLO.Me.Casting()) or not common.clearToBuff() then return end
    if mq.TLO.Zone.ID() ~= camp.ZoneID then
        logger.info('Clearing camp due to zoning.')
        camp.Active = false
        return
    end
    if helpers.distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), camp.X, camp.Y) > 15^2 then
        movement.navToLoc(camp.X, camp.Y, camp.Z)
    end
end

---Draw a maploc at the given heading on the pull radius circle.
---@param camp_x number @
---@param camp_y number @
---@param heading number @The MQ heading degrees pointing to where to draw the maploc.
---@param color string @The color input to the /maploc command.
local function drawMapLoc(camp_x, camp_y, camp_z, heading, color)
    if heading < 0 then
        heading = 360 - heading
    elseif heading > 360 then
        heading = heading - 360
    end
    local x_move = math.cos(math.rad(helpers.convertHeading(heading)))
    if x_move > 0 and heading > 0 and heading < 180 then
        x_move = x_move * -1
    elseif x_move < 0 and heading >= 180 then
        x_move = math.abs(x_move)
    end
    local y_move = math.sin(math.rad(helpers.convertHeading(heading)))
    if y_move > 0 and heading > 90 and heading < 270 then
        y_move = y_move * -1
    elseif y_move < 0 and (heading <= 90 or heading >= 270) then
        y_move = math.abs(y_move)
    end
    local x_off = camp_x + config.get('PULLRADIUS') * x_move
    local y_off = camp_y + config.get('PULLRADIUS') * y_move
    mq.cmdf('/squelch /maploc size 10 width 2 color %s radius 5 rcolor 0 0 0 %s %s %s', color, y_off, x_off, camp_z)
end

---Set the left and right pull arc values based on the configured PULLARC option.
local function setPullAngles()
    local pull_arc = config.get('PULLARC')
    if not pull_arc or pull_arc == 0 then return end
    if not camp.Heading then camp.Heading = 0 end
    if camp.Heading-(pull_arc*.5) < 0 then
        camp.PullArcLeft = 360-((pull_arc*.5)-camp.Heading)
    else
        camp.PullArcLeft = camp.Heading-(pull_arc*.5)
    end
    if camp.Heading + (pull_arc*.5) > 360 then
        camp.PullArcRight = (pull_arc*.5)+camp.Heading-360
    else
        camp.PullArcRight = (pull_arc*.5)+camp.Heading
    end
    logger.debug(logger.flags.routines.camp, 'arcleft: %s, arcright: %s', camp.PullArcLeft, camp.PullArcRight)
end

---Set, update or clear the CAMP values depending on whether currently in a camp mode or not.
---@param reset boolean|nil @If true, then reset the camp to pickup the latest options.
function camp.setCamp(reset)
    local mode = mode.currentMode
    if mode:isCampMode() then
        mq.cmd('/squelch /maploc remove')
        if not camp.Active or reset then
            camp.Active = true
            camp.X = mq.TLO.Me.X()
            camp.Y = mq.TLO.Me.Y()
            camp.Z = mq.TLO.Me.Z()
            camp.Heading = mq.TLO.Me.Heading.Degrees()
            camp.ZoneID = mq.TLO.Zone.ID()
        end
        if mode:isPullMode() then
            if config.get('PULLARC') > 0 and config.get('PULLARC') < 360 then
                setPullAngles()
                drawMapLoc(camp.X, camp.Y, camp.Z, camp.PullArcLeft, '0 0 255')
                drawMapLoc(camp.X, camp.Y, camp.Z, camp.PullArcRight, '0 0 255')
                drawMapLoc(camp.X, camp.Y, camp.Z, camp.Heading, '255 0 0')
            else
                camp.PullArcLeft = 0
                camp.PullArcRight = 0
            end
            mq.cmdf('/squelch /maploc size 10 width 1 color 0 0 255 radius %s rcolor 0 0 255 %s %s %s', config.get('PULLRADIUS'), camp.Y, camp.X, camp.Z)
        else
            camp.PullArcLeft = 0
            camp.PullArcRight = 0
        end
        logger.info('Camp set to \ayX: %.02f Y: %.02f Z: %.02f R: %s H: %.02f\ax', camp.X, camp.Y, camp.Z, config.get('CAMPRADIUS'), camp.Heading)
        mq.cmdf('/squelch /maploc size 10 width 1 color 255 0 0 radius %s rcolor 255 0 0 %s %s %s', config.get('CAMPRADIUS'), camp.Y+1, camp.X+1, camp.Z)
    elseif camp.Active then
        camp.Active = false
        mq.cmd('/squelch /mapf campradius 0')
        mq.cmd('/squelch /mapf pullradius 0')
        mq.cmd('/squelch /maploc remove')
    end
end

return camp