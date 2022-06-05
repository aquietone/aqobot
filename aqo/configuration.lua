--- @type mq
local mq = require 'mq'
local logger = require('aqo.utils.logger')
local persistence = require('aqo.utils.persistence')
local modes = require('aqo.mode')

local config = {}

local mode = modes.from_string('manual')

local chase_target = ''

local chase_distance = 30

local camp_radius = 60

local assist = 'group'

local auto_assist_at = 98

local spell_set = ''

---burn as burns become available
local burn_always = false

---delay burn until mob below Pct HP, 0 ignores %.
local burn_percent = 0

---enable automatic burn on named mobs
local burn_all_named = false

---number of mobs to trigger burns
local burn_count = 5

---enable use of alliance spell
local use_alliance = false

local switch_with_ma = true

local pull_radius = 100

local pull_z_high = 25

local pull_z_low = 25

local pull_arc = 360

local pull_min_level = 0

local pull_max_level = 0

local ignores = {}

---Check whether the specified file exists or not.
---@param file_name string @The name of the file to check existence of.
---@return boolean @Returns true if the file exists, false otherwise.
function config.file_exists(file_name)
    local f = io.open(file_name, "r")
    if f ~= nil then io.close(f) return true else return false end
end

---Load mob ignore lists file
function config.load_ignores()
    local ignore_file = ('%s/%s'):format(mq.configDir, 'aqo_ignore.lua')
    if config.file_exists(ignore_file) then
        ignores = assert(loadfile(ignore_file))()
    end
end

function config.save_ignores()
    local ignore_file = ('%s/%s'):format(mq.configDir, 'aqo_ignore.lua')
    persistence.store(ignore_file, ignores)
end

---Load common settings from settings file
---@param settings_file string @The name of the settings file to load.
---@return table @Returns a table containing the loaded settings file content.
function config.load_settings(settings_file)
    if not config.file_exists(settings_file) then return end
    local settings = assert(loadfile(settings_file))()
    if not settings or not settings.common then return settings end
    if settings.common.MODE ~= nil then mode = modes.from_string(settings.common.MODE) end
    if settings.common.CHASETARGET ~= nil then chase_target = settings.common.CHASETARGET end
    if settings.common.CHASEDISTANCE ~= nil then chase_distance = settings.common.CHASEDISTANCE end
    if settings.common.CAMPRADIUS ~= nil then camp_radius = settings.common.CAMPRADIUS end
    if settings.common.ASSIST ~= nil then assist = settings.common.ASSIST end
    if settings.common.AUTOASSISTAT ~= nil then auto_assist_at = settings.common.AUTOASSISTAT end
    if settings.common.SPELLSET ~= nil then spell_set = settings.common.SPELLSET end
    if settings.common.BURNALWAYS ~= nil then burn_always = settings.common.BURNALWAYS end
    if settings.common.BURNPCT ~= nil then burn_percent = settings.common.BURNPCT end
    if settings.common.BURNALLNAMED ~= nil then burn_all_named = settings.common.BURNALLNAMED end
    if settings.common.BURNCOUNT ~= nil then burn_count = settings.common.BURNCOUNT end
    if settings.common.USEALLIANCE ~= nil then use_alliance = settings.common.USEALLIANCE end
    if settings.common.SWITCHWITHMA ~= nil then switch_with_ma = settings.common.SWITCHWITHMA end
    if settings.common.PULLRADIUS ~= nil then pull_radius = settings.common.PULLRADIUS end
    if settings.common.PULLHIGH ~= nil then pull_z_high = settings.common.PULLHIGH end
    if settings.common.PULLLOW ~= nil then pull_z_low = settings.common.PULLLOW end
    if settings.common.PULLARC ~= nil then pull_arc = settings.common.PULLARC end
    if settings.common.PULLMINLEVEL ~= nil then pull_min_level = settings.common.PULLMINLEVEL end
    if settings.common.PULLMAXLEVEL ~= nil then pull_max_level = settings.common.PULLMAXLEVEL end
    return settings
end

function config.get_all()
    return {
        MODE=mode:get_name(),
        CHASETARGET=chase_target,
        CHASEDISTANCE=chase_distance,
        CAMPRADIUS=camp_radius,
        ASSIST=assist,
        AUTOASSISTAT=auto_assist_at,
        SPELLSET=spell_set,
        BURNALWAYS=burn_always,
        BURNPCT=burn_percent,
        BURNALLNAMED=burn_all_named,
        BURNCOUNT=burn_count,
        USEALLIANCE=use_alliance,
        SWITCHWITHMA=switch_with_ma,
        PULLRADIUS=pull_radius,
        PULLHIGH=pull_z_high,
        PULLLOW=pull_z_low,
        PULLARC=pull_arc,
        PULLMINLEVEL=pull_min_level,
        PULLMAXLEVEL=pull_max_level,
    }
end

function config.get_mode()
    return mode
end

function config.set_mode(new_mode)
    mode = new_mode
end

function config.get_chase_target()
    return chase_target
end

function config.set_chase_target(new_chase_target)
    chase_target = new_chase_target
end

function config.get_chase_distance()
    return chase_distance
end

function config.set_chase_distance(new_chase_distance)
    chase_distance = new_chase_distance
end

function config.get_camp_radius()
    return camp_radius
end

function config.set_camp_radius(new_camp_radius)
    camp_radius = new_camp_radius
end

function config.get_assist()
    return assist
end

function config.set_assist(new_assist)
    assist = new_assist
end

function config.get_auto_assist_at()
    return auto_assist_at
end

function config.set_auto_assist_at(new_auto_assist_at)
    auto_assist_at = new_auto_assist_at
end

function config.get_spell_set()
    return spell_set
end

function config.set_spell_set(new_spell_set)
    spell_set = new_spell_set
end

function config.get_burn_always()
    return burn_always
end

function config.set_burn_always(new_burn_always)
    burn_always = new_burn_always
end

function config.get_burn_percent()
    return burn_percent
end

function config.set_burn_percent(new_burn_percent)
    burn_percent = new_burn_percent
end

function config.get_burn_all_named()
    return burn_all_named
end

function config.set_burn_all_named(new_burn_all_named)
    burn_all_named = new_burn_all_named
end

function config.get_burn_count()
    return burn_count
end

function config.set_burn_count(new_burn_count)
    burn_count = new_burn_count
end

function config.get_use_alliance()
    return use_alliance
end

function config.set_use_alliance(new_use_alliance)
    use_alliance = new_use_alliance
end

function config.get_switch_with_ma()
    return switch_with_ma
end

function config.set_switch_with_ma(new_switch_with_ma)
    switch_with_ma = new_switch_with_ma
end

function config.get_pull_radius()
    return pull_radius
end

function config.set_pull_radius(new_pull_radius)
    pull_radius = new_pull_radius
end

function config.get_pull_z_high()
    return pull_z_high
end

function config.set_pull_z_high(new_pull_z_high)
    pull_z_high = new_pull_z_high
end

function config.get_pull_z_low()
    return pull_z_low
end

function config.set_pull_z_low(new_pull_z_low)
    pull_z_low = new_pull_z_low
end

function config.get_pull_arc()
    return pull_arc
end

function config.set_pull_arc(new_pull_arc)
    pull_arc = new_pull_arc
end

function config.get_pull_min_level()
    return pull_min_level
end

function config.set_pull_min_level(new_pull_min_level)
    pull_min_level = new_pull_min_level
end

function config.get_pull_max_level()
    return pull_max_level
end

function config.set_pull_max_level(new_pull_max_level)
    pull_max_level = new_pull_max_level
end

function config.get_ignores(zone_short_name)
    if not zone_short_name then
        return ignores
    else
        return ignores[zone_short_name:lower()]
    end
end

function config.add_ignore(zone_short_name, mob_name)
    if ignores[zone_short_name:lower()][mob_name] then return false end
    ignores[zone_short_name:lower()][mob_name] = true
    return true
end

function config.remove_ignore(zone_short_name, mob_name)
    if not ignores[zone_short_name:lower()][mob_name] then return false end
    ignores[zone_short_name:lower()][mob_name] = nil
    return true
end

function config.ignores_contains(zone_short_name, mob_name)
    return ignores[zone_short_name:lower()][mob_name]
end

--for k,v in pairs(config.get_all()) do
--    logger.printf('%s: %s', k, v)
--end

return config