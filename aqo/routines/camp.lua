--- @type Mq
local mq = require 'mq'
local logger = require('aqo.utils.logger')
local timer = require('aqo.utils.timer')
local common = require('aqo.common')
local config = require('aqo.configuration')
local state = require('aqo.state')

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

local xtar_corpse_count = 'xtarhater npccorpse radius %d zradius 50'
local xtar_count = 'xtarhater radius %d zradius 50'
local xtar_spawn = '%d, xtarhater radius %d zradius 50'
---Determine the number of mobs within the camp radius.
---Sets common.MOB_COUNT to the total number of mobs on xtarget within the camp radius.
---Adds the mob ID of each mob found to the common.TARGETS table.
camp.mob_radar = function()
    local num_corpses = 0
    local targets = state.targets
    num_corpses = mq.TLO.SpawnCount(xtar_corpse_count:format(config.CAMPRADIUS))()
    local mob_count = mq.TLO.SpawnCount(xtar_count:format(config.CAMPRADIUS))() - num_corpses
    if mob_count > 0 then
        for i=1,mob_count do
            if i > 13 then break end
            local mob = mq.TLO.NearestSpawn(xtar_spawn:format(i, config.CAMPRADIUS))
            local mob_id = mob.ID()
            if mob_id and mob_id > 0 then
                if not mob() or mob.Type() == 'Corpse' then
                    targets[mob_id] = nil
                    num_corpses = num_corpses+1
                elseif not targets[mob_id] then
                    logger.debug(state.debug, 'Adding mob_id %d', mob_id)
                    targets[mob_id] = {meztimer=timer:new(30)}
                end
            end
        end
        state.mob_count = mob_count - num_corpses
    end
    state.targets = targets -- is this necessary if targets is by ref
end

---Checks for any mobs in common.TARGETS which are no longer valid and removes them from the table.
camp.clean_targets = function()
    local targets = state.targets
    for mobid,_ in pairs(targets) do
        local spawn = mq.TLO.Spawn(string.format('id %s', mobid))
        if not spawn() or spawn.Type() == 'Corpse' then
            targets[mobid] = nil
        end
    end
    state.targets = targets -- is this necessary if targets is by ref
end

---Return to camp if alive and in a camp mode and not currently fighting and more than 15ft from the camp center location.
camp.check_camp = function()
    if not config.MODE:return_to_camp() or not camp.Active then return end
    if common.am_i_dead() or mq.TLO.Me.Casting() or not common.clear_to_buff() then return end
    --if common.is_fighting() or not state.camp then return end
    --if mq.TLO.Me.XTarget() > 0 then return end
    if mq.TLO.Zone.ID() ~= state.camp.ZoneID then
        logger.printf('Clearing camp due to zoning.')
        state.camp.Active = false
        return
    end
    if common.check_distance(mq.TLO.Me.X(), mq.TLO.Me.Y(), camp.X, camp.Y) > 15 then
        if not mq.TLO.Navigation.Active() and mq.TLO.Navigation.PathExists(string.format('locyxz %d %d %d', camp.Y, camp.X, camp.Z))() then
            mq.cmdf('/nav locyxz %d %d %d log=off', camp.Y, camp.X, camp.Z)
        end
    end
end

---Draw a maploc at the given heading on the pull radius circle.
---@param camp_x number @
---@param camp_y number @
---@param heading number @The MQ heading degrees pointing to where to draw the maploc.
---@param color string @The color input to the /maploc command.
local function draw_maploc(camp_x, camp_y, camp_z, heading, color)
    if heading < 0 then
        heading = 360 - heading
    elseif heading > 360 then
        heading = heading - 360
    end
    local x_move = math.cos(math.rad(common.convert_heading(heading)))
    if x_move > 0 and heading > 0 and heading < 180 then
        x_move = x_move * -1
    elseif x_move < 0 and heading >= 180 then
        x_move = math.abs(x_move)
    end
    local y_move = math.sin(math.rad(common.convert_heading(heading)))
    if y_move > 0 and heading > 90 and heading < 270 then
        y_move = y_move * -1
    elseif y_move < 0 and (heading <= 90 or heading >= 270) then
        y_move = math.abs(y_move)
    end
    local x_off = camp_x + config.PULLRADIUS * x_move
    local y_off = camp_y + config.PULLRADIUS * y_move
    mq.cmdf('/squelch /maploc size 10 width 2 color %s radius 5 rcolor 0 0 0 %s %s %s', color, y_off, x_off, camp_z)
end

---Set the left and right pull arc values based on the configured PULLARC option.
local function set_pull_angles()
    local pull_arc = config.PULLARC
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
    logger.debug(state.debug, 'arcleft: %s, arcright: %s', camp.PullArcLeft, camp.PullArcRight)
end

---Set, update or clear the CAMP values depending on whether currently in a camp mode or not.
---@param reset boolean|nil @If true, then reset the camp to pickup the latest options.
camp.set_camp = function(reset)
    local mode = config.MODE
    if mode:set_camp_mode() then
        mq.cmd('/squelch /maploc remove')
        if not camp.Active or reset then
            camp.Active = true
            camp.X = mq.TLO.Me.X()
            camp.Y = mq.TLO.Me.Y()
            camp.Z = mq.TLO.Me.Z()
            camp.Heading = mq.TLO.Me.Heading.Degrees()
            camp.ZoneID = mq.TLO.Zone.ID()
        end
        if mode:is_pull_mode() then
            if config.PULLARC > 0 and config.PULLARC < 360 then
                set_pull_angles()
                draw_maploc(camp.X, camp.Y, camp.Z, camp.PullArcLeft, '0 0 255')
                draw_maploc(camp.X, camp.Y, camp.Z, camp.PullArcRight, '0 0 255')
                draw_maploc(camp.X, camp.Y, camp.Z, camp.Heading, '255 0 0')
            else
                camp.PullArcLeft = 0
                camp.PullArcRight = 0
            end
            mq.cmdf('/squelch /maploc size 10 width 1 color 0 0 255 radius %s rcolor 0 0 255 %s %s %s', config.PULLRADIUS, camp.Y, camp.X, camp.Z)
        else
            camp.PullArcLeft = 0
            camp.PullArcRight = 0
        end
        logger.printf('Camp set to \ayX: %.02f Y: %.02f Z: %.02f R: %s H: %.02f\ax', camp.X, camp.Y, camp.Z, config.CAMPRADIUS, camp.Heading)
        mq.cmdf('/squelch /maploc size 10 width 1 color 255 0 0 radius %s rcolor 255 0 0 %s %s %s', config.CAMPRADIUS, camp.Y+1, camp.X+1, camp.Z)
    elseif camp.Active then
        camp.Active = false
        mq.cmd('/squelch /mapf campradius 0')
        mq.cmd('/squelch /mapf pullradius 0')
        mq.cmd('/squelch /maploc remove')
    end
end

return camp