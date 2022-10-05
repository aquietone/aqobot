--- @type Mq
local mq = require 'mq'
local logger = require(AQO..'.utils.logger')
local persistence = require(AQO..'.utils.persistence')
local modes = require(AQO..'.mode')

local config = {
    MODE = modes.from_string('manual'),
    CHASETARGET = '',
    CHASEDISTANCE = 30,
    CAMPRADIUS = 60,
    ASSIST = 'group',
    AUTOASSISTAT = 98,
    SWITCHWITHMA = true,

    BURNALWAYS = false,
    BURNPCT = 0,
    BURNALLNAMED = false,
    BURNCOUNT = 5,
    USEGLYPH = false,
    USEINTENSITY = false,

    PULLRADIUS = 100,
    PULLHIGH = 25,
    PULLLOW = 25,
    PULLARC = 360,
    PULLMINLEVEL = 0,
    PULLMAXLEVEL = 0,
    GROUPWATCHWHO = 'healer',
    MEDMANASTART = 5,
    MEDMANASTOP = 30,
    MEDENDSTART = 5,
    MEDENDSTOP = 30,
}

local ignores = {}

function config.get_all()
    return {
        MODE = config.MODE:get_name(),
        CHASETARGET = config.CHASETARGET,
        CHASEDISTANCE = config.CHASEDISTANCE,
        CAMPRADIUS = config.CAMPRADIUS,
        ASSIST = config.ASSIST,
        AUTOASSISTAT = config.AUTOASSISTAT,
        SWITCHWITHMA = config.SWITCHWITHMA,

        BURNALWAYS = config.BURNALWAYS,
        BURNPCT = config.BURNPCT,
        BURNALLNAMED = config.BURNALLNAMED,
        BURNCOUNT = config.BURNCOUNT,
        USEGLYPH = config.USEGLYPH,
        USEINTENSITY = config.USEINTENSITY,

        PULLRADIUS = config.PULLRADIUS,
        PULLHIGH = config.PULLHIGH,
        PULLLOW = config.PULLLOW,
        PULLARC = config.PULLARC,
        PULLMINLEVEL = config.PULLMINLEVEL,
        PULLMAXLEVEL = config.PULLMAXLEVEL,
        GROUPWATCHWHO = config.GROUPWATCHWHO,
        MEDMANASTART = config.MEDMANASTART,
        MEDMANASTOP = config.MEDMANASTOP,
        MEDENDSTART = config.MEDENDSTART,
        MEDENDSTOP = config.MEDENDSTOP,
    }
end

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
---@return table|nil @Returns a table containing the loaded settings file content.
function config.load_settings(settings_file)
    if not config.file_exists(settings_file) then return nil end
    local settings = assert(loadfile(settings_file))()
    if not settings or not settings.common then return settings end
    for setting,value in pairs(settings.common) do
        config[setting] = value
    end
    if settings.common.MODE ~= nil then config.MODE = modes.from_string(settings.common.MODE) end
    return settings
end

function config.get_ignores(zone_short_name)
    if not zone_short_name then
        return ignores
    else
        return ignores[zone_short_name:lower()]
    end
end

function config.add_ignore(zone_short_name, mob_name)
    if ignores[zone_short_name:lower()] and ignores[zone_short_name:lower()][mob_name] then return end
    if not ignores[zone_short_name:lower()] then ignores[zone_short_name:lower()] = {} end
    ignores[zone_short_name:lower()][mob_name] = true
    logger.printf('Added pull ignore \ay%s\ax for zone \ar%s\ax', mob_name, zone_short_name)
    config.save_ignores()
end

function config.remove_ignore(zone_short_name, mob_name)
    if not ignores[zone_short_name:lower()] or not ignores[zone_short_name:lower()][mob_name] then return end
    ignores[zone_short_name:lower()][mob_name] = nil
    logger.printf('Removed pull ignore \ay%s\ax for zone \ar%s\ax', mob_name, zone_short_name)
    config.save_ignores()
end

function config.ignores_contains(zone_short_name, mob_name)
    return ignores[zone_short_name:lower()] and ignores[zone_short_name:lower()][mob_name]
end

--for k,v in pairs(config.get_all()) do
--    logger.printf('%s: %s', k, v)
--end

return config