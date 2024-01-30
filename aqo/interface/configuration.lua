--- @type Mq
local mq = require 'mq'
local constants = require('constants')
local logger = require('utils.logger')
local modes = require('mode')

local config = {
    SETTINGS_FILE = ('%s/aqobot_%s_%s.lua'):format(mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me.CleanName()),

    -- General settings
    MODE = {
        value = 'manual',
        tip = 'The mode to run as: 0|manual|1|assist|2|chase|3|vorpal|4|tank|5|pullertank|6|puller|7|huntertank',
        label = 'Mode',
        type = 'combobox',
        options = modes.modes,
        tlo = 'Mode',
        tlotype = 'string',
    },
    CHASETARGET = {
        value = '',
        tip = 'Name of the person to chase in chase mode. Its using an exact match spawn search for PC\'s only',
        label = 'Chase Target',
        type = 'inputtext',
        tlo = 'ChaseTarget',
        tlotype = 'string',
    },
    CHASEDISTANCE = {
        value = 30,
        tip = 'Distance threshold to trigger chasing the chase target',
        label = 'Chase Distance',
        type = 'inputint',
        tlo = 'ChaseDistance',
        tlotype = 'int',
    },
    CHASEPAUSED = {
        value = false,
        tip = 'Chase the chase target while paused',
        label = 'Chase While Paused',
        type = 'checkbox',
        tlo = 'ChasePaused',
        tlotype = 'bool',
    },
    CAMPRADIUS = {
        value = 60,
        tip = 'The radius within which you will assist on mobs',
        label = 'Camp Radius',
        type = 'inputint',
        tlo = 'CampRadius',
        tlotype = 'int',
    },
    ASSIST = {
        value = 'group',
        tip = 'Who to assist. Group MA, Raid MA 1, 2 or 3',
        label = 'Assist',
        type = 'combobox',
        options = constants.assists,
        tlo = 'Assist',
        tlotype = 'string',
    },
    AUTOASSISTAT = {
        value = 98,
        tip = 'Mob Percent HP to begin assisting',
        label = 'Assist %',
        type = 'inputint',
        tlo = 'AutoAssistAt',
        tlotype = 'int',
    },
    ASSISTNAMES = {
        value = '',
        tip = 'Comma separated, ordered list of names to assist, mainly for manual assist mode in raids.',
        label = 'Assist Names',
        type = 'inputtext',
        emu = true,
        tlo = 'AssistNames',
        tlotype = 'string',
    },
    SWITCHWITHMA = {
        value = true,
        tip = 'Swap targets if the MA swaps targets',
        label = 'Switch With MA',
        type = 'checkbox',
        tlo = 'SwitchWithMA',
        tlotype = 'bool',
    },
    NUKEMANAMIN = {
        value = 15,
        tip = 'Minimum mana threshold to pause casting nukes',
        classes = constants.nukeClasses,
        label = 'Nuke Mana Min',
        type = 'inputint',
        tlo = 'NukeManaMin',
        tlotype = 'int',
    },
    DOTMANAMIN = {
        value = 15,
        tip = 'Minimum mana threshold to pause casting DoTs',
        classes = constants.dotClasses,
        label = 'DoT Mana Min',
        type = 'inputint',
        tlo = 'DoTManaMin',
        tlotype = 'int',
    },

    -- Heal settings
    HEALPCT = {
        value = 75,
        tip = 'The Percent HP to begin casting normal heals on a character',
        label = 'Heal Pct',
        type = 'inputint',
        tlo = 'HealPct',
        tlotype = 'int',
    },
    PANICHEALPCT = {
        value = 30,
        tip = 'The Percent HP to begin casting panic heals on a character',
        classes = constants.healClasses,
        label = 'Panic Heal Pct',
        type = 'inputint',
        tlo = 'PanicHealPct',
        tlotype = 'int',
    },
    GROUPHEALPCT = {
        value = 75,
        tip = 'The Percent HP to begin casting group heals',
        classes = constants.healClasses,
        label = 'Group Heal Pct',
        type = 'inputint',
        tlo = 'GroupHealPct',
        tlotype = 'int',
    },
    GROUPHEALMIN = {
        value = 3,
        tip = 'The number of group members which must be injured to begin casting group heals',
        classes = constants.healClasses,
        label = 'Group Heal Min',
        type = 'inputint',
        tlo = 'GroupHealMin',
        tlotype = 'int',
    },
    HOTHEALPCT = {
        value = 90,
        tip = 'The Percent HP to begin casting HoTs on a character',
        classes = constants.healClasses,
        label = 'HoT Pct',
        type = 'inputint',
        tlo = 'HoTHealPct',
        tlotype = 'int',
    },
    REZGROUP = {
        value = false,
        tip = 'Toggle rezzing of group members',
        label = 'Rez Group',
        type = 'checkbox',
        tlo = 'RezGroup',
        tlotype = 'bool',
    },
    REZRAID = {
        value = false,
        tip = 'Toggle rezzing of raid members',
        label = 'Rez Raid',
        type = 'checkbox',
        tlo = 'RezRaid',
        tlotype = 'bool',
    },
    REZINCOMBAT = {
        value = false,
        tip = 'Toggle use of rez abilities during combat',
        label = 'Rez In Combat',
        type = 'checkbox',
        tlo = 'RezInCombat',
        tlotype = 'bool',
    },
    PRIORITYTARGET = {
        value = '',
        tip = 'For EMU, where group main tank role is unreliable, assign a character name to treat like the main tank',
        classes = constants.healClasses,
        label = 'Priority Target',
        type = 'inputtext',
        emu = true,
        tlo = 'PriorityTarget',
        tlotype = 'string',
    },
    XTARGETHEAL = {
        value = false,
        tip = 'Toggle healing of PCs on XTarget',
        classes = constants.healClasses,
        label = 'Heal XTarget',
        type = 'checkbox',
        tlo = 'XTargetHeal',
        tlotype = 'bool',
    },

    -- Burn settings
    BURNALWAYS = {
        value = false,
        tip = 'Burn routine is always entered and burn abilities are used as available. Its not great, it doesn\'t attempt to line up CDs or anything',
        label = 'Burn Always',
        type = 'checkbox',
        tlo = 'BurnAlways',
        tlotype = 'bool',
    },
    BURNPCT = {
        value = 0,
        tip = 'Same as Burn Always, but only after mob HP is below this percent',
        label = 'Burn Percent',
        type = 'inputint',
        tlo = 'BurnPct',
        tlotype = 'int',
    },
    BURNALLNAMED = {
        value = false,
        tip = 'Enter burn routine when ${Target.Named} is true. Kinda sucks with ToL zones since so many akhevan trash mobs return true',
        label = 'Burn Named',
        type = 'checkbox',
        tlo = 'BurnAllNamed',
        tlotype = 'bool',
    },
    BURNCOUNT = {
        value = 5,
        tip = 'Enter burn routine when greater than or equal to this number of mobs are within camp radius',
        label = 'Burn Count',
        type = 'inputint',
        tlo = 'BurnCount',
        tlotype = 'int',
    },
    USEGLYPH = {
        value = false,
        tip = 'Toggle use of Glyph of Destruction on burns',
        label = 'Use Glyph',
        type = 'checkbox',
        emu = false,
        tlo = 'UseGlyph',
        tlotype = 'bool',
    },
    USEINTENSITY = {
        value = false,
        tip = 'Toggle use of Intensity of the Resolute Veteran AA on burns',
        label = 'Use Intensity',
        type = 'checkbox',
        emu = false,
        tlo = 'UseIntensity',
        tlotype = 'bool',
    },

    -- Pull settings
    PULLWITH = {
        value = 'melee',
        tip = 'How to pull mobs. May be one of melee, ranged, spell',
        label = 'Pull With',
        type = 'combobox',
        options = constants.pullWith,
        tlo = 'PullWith',
        tlotype = 'string',
    },
    PULLRADIUS = {
        value = 100,
        tip = 'The radius within which you will pull mobs when in a puller role',
        label = 'Pull Radius',
        type = 'inputint',
        tlo = 'PullRadius',
        tlotype = 'int',
    },
    PULLHIGH = {
        value = 25,
        tip = 'The upper Z radius for pulling mobs when in a puller role',
        label = 'Pull ZHigh',
        type = 'inputint',
        tlo = 'PullHigh',
        tlotype = 'int',
    },
    PULLLOW = {
        value = 25,
        tip = 'The lower Z radius for pulling mobs when in a puller role',
        label = 'Pull ZLow',
        type = 'inputint',
        tlo = 'PullLow',
        tlotype = 'int',
    },
    PULLARC = {
        value = 360,
        tip = 'The pull arc, centered around the direction the character is currently facing, to pull mobs from',
        label = 'Pull Arc',
        type = 'inputint',
        tlo = 'PullArc',
        tlotype = 'int',
    },
    PULLMINLEVEL = {
        value = 0,
        tip = 'The minimum level mob to pull when in a puller role',
        label = 'Pull Min Level',
        type = 'inputint',
        tlo = 'PullMinLevel',
        tlotype = 'int',
    },
    PULLMAXLEVEL = {
        value = 0,
        tip = 'The maxmimum level mob to pull when in a puller role',
        label = 'Pull Max Level',
        type = 'inputint',
        tlo = 'PullMaxLevel',
        tlotype = 'int',
    },
    GROUPWATCHWHO = {
        value = 'healer',
        tip = 'Who to watch mana/endurance for, to decide whether to hold pulls and med',
        label = 'Group Watch',
        type = 'combobox',
        options = constants.groupWatchOptions,
        tlo = 'GroupWatchWho',
        tlotype = 'string',
    },
    GROUPSTAYCLOSE = {
        value = false,
        tip = 'Toggle whether puller should hold pulls if a group member is not with the group',
        label = 'Group Stay Close',
        type = 'checkbox',
        tlo = 'GroupStayClose',
        tlotype = 'bool',
    },

    RECOVERPCT = {
        value = 70,
        tip = 'Percent mana or endurance to trigger recover abilities',
        label = 'Recover Pct',
        type = 'inputint',
        tlo = 'RecoverPct',
        tlotype = 'int',
    },
    MEDCOMBAT = {
        value = false,
        tip = 'Toggle whether to med during combat. If on, character will still heal, tank, cc, debuff and buff, just not assist.',
        label = 'Med In Combat',
        type = 'checkbox',
        tlo = 'MedCombat',
        tlotype = 'bool',
    },
    MEDHPSTART = {
        value = 5,
        tip = 'The Percent HP to begin medding at',
        label = 'Med HP Start',
        type = 'inputint',
        tlo = 'MedHPStart',
        tlotype = 'int',
    },
    MEDHPSTOP = {
        value = 30,
        tip = 'The Percent HP to stop medding at',
        label = 'Med HP Stop',
        type = 'inputint',
        tlo = 'MedHPStop',
        tlotype = 'int',
    },
    MEDMANASTART = {
        value = 5,
        tip = 'The Percent Mana to begin medding at',
        label = 'Med Mana Start',
        type = 'inputint',
        tlo = 'MedManaStart',
        tlotype = 'int',
    },
    MEDMANASTOP = {
        value = 30,
        tip = 'The Percent Mana to stop medding at',
        label = 'Med Mana Stop',
        type = 'inputint',
        tlo = 'MedManaStop',
        tlotype = 'int',
    },
    MEDENDSTART = {
        value = 5,
        tip = 'The Percent Endurance to begin medding at',
        label = 'Med End Start',
        type = 'inputint',
        tlo = 'MedEndStart',
        tlotype = 'int',
    },
    MEDENDSTOP = {
        value = 30,
        tip = 'The Percent Endurance to stop medding at',
        label = 'Med End Stop',
        type = 'inputint',
        tlo = 'MedManaStop',
        tlotype = 'int',
    },
    MANASTONESTART = {
        value = 35,
        tip = 'Percent Mana to begin spamming manastone (EMU only)',
        label = 'Manastone Start Mana',
        classes = constants.manaClasses,
        type = 'inputint',
        emu = true,
        tlo = 'ManastoneStart',
        tlotype = 'int',
    },
    MANASTONESTARTHP = {
        value = 75,
        tip = 'Minimum Percent HP to begin spamming manastone (EMU only)',
        label = 'Manastone Start HP',
        classes = constants.manaClasses,
        type = 'inputint',
        emu = true,
        tlo = 'ManastoneStartHP',
        tlotype = 'int',
    },
    MANASTONESTOPHP = {
        value = 50,
        tip = 'Percent HP to stop spamming manastone (EMU only)',
        label = 'Manastone Stop HP',
        classes = constants.manaClasses,
        type = 'inputint',
        emu = true,
        tlo = 'ManastoneStopHP',
        tlotype = 'int',
    },
    MANASTONETIME = {
        value = 1,
        tip = 'Duration, in seconds, to spam manastone (EMU only)',
        label = 'Manastone Duration',
        classes = constants.manaClasses,
        type = 'inputint',
        emu = true,
        tlo = 'ManastoneTime',
        tlotype = 'int',
    },

    -- Other settings
    LOOTMOBS = {
        value = true,
        tip = 'Toggle looting of mob corpses on or off for emu',
        label = 'Loot Mobs',
        type = 'checkbox',
        emu = true,
        tlo = 'LootMobs',
        tlotype = 'bool',
    },
    LOOTCOMBAT = {
        value = false,
        tip = 'Toggle looting of mob corpses during combat on or off for emu',
        label = 'Loot In Combat',
        type = 'checkbox',
        emu = true,
        tlo = 'LootCombat',
        tlotype = 'bool',
    },

    MAINTANK = {
        value = false,
        tip = 'Toggle use of tanking abilities in case main tank role doesn\'t work, like on emu',
        label = 'Main Tank',
        type = 'checkbox',
        emu = true,
        tlo = 'MainTank',
        tlotype = 'bool',
    },
    RESISTSTOPCOUNT = {
        value = 3,
        tip = 'The number of resists after which to stop trying casting a spell on a mob',
        label = 'Resist Stop Count',
        type = 'inputint',
        tlo = 'ResistStopCount',
        tlotype = 'int',
    },

    TIMESTAMPS = {
        value = false,
        tip = 'Enable timestamps on log messages',
        label = 'Timestamps',
        type = 'checkbox',
        tlo = 'Timestamps',
        tlotype = 'bool',
    },
    THEME = {
        value = 'BLACK',
        tip = 'Pick a UI color scheme',
        label = 'Theme',
        type = 'combobox',
        tlo = 'Theme',
        tlotype = 'string',
    },
    OPACITY = {
        value = 100,
        tip = 'Set the window opacity',
        label = 'Opacity',
        type = 'inputint',
        tlo = 'Opacity',
        tlotype = 'int',
    },
    LOCKED = {
        value = true,
        tip = 'Lock the window position',
        label = 'Lock Window',
        type = 'checkbox',
        tlo = 'Locked',
        tlotype = 'boolean',
    },
    WINDOWPOSX = {
        value = 200,
        tip = '',
        label = '',
        type = 'inputint',
        tlo = 'WindowPosX',
        tlotype = 'int'
    },
    WINDOWPOSY = {
        value = 200,
        tip = '',
        label = '',
        type = 'inputint',
        tlo = 'WindowPosY',
        tlotype = 'int'
    },
    WINDOWWIDTH = {
        value = 200,
        tip = '',
        label = '',
        type = 'inputint',
        tlo = 'WindowWidth',
        tlotype = 'int'
    },
    WINDOWHEIGHT = {
        value = 200,
        tip = '',
        label = '',
        type = 'inputint',
        tlo = 'WindowHeight',
        tlotype = 'int'
    },
}

function config.get(key)
    return config[key].value
end

function config.set(key, value)
    config[key].value = value
end

function config.getAll()
    local configMap = {}
    for key,cfg in pairs(config) do
        if type(config[key]) == 'table' then
            configMap[key] = cfg.value
        end
    end
    return configMap
end

local categories = {'Assist', 'Camp', 'Burn', 'Heal', 'Pull', 'Tank', 'Rest', 'Loot', 'Debug'}
function config.categories()
    return categories
end

local configByCategory = {
    Assist={'MODE','ASSIST','AUTOASSISTAT','ASSISTNAMES','SWITCHWITHMA','RESISTSTOPCOUNT','NUKEMANAMIN','DOTMANAMIN'},
    Camp={'CAMPRADIUS','CHASETARGET','CHASEDISTANCE','CHASEPAUSED'},
    Burn={'BURNALWAYS','BURNALLNAMED','BURNCOUNT','BURNPCT','USEGLYPH','USEINTENSITY'},
    Pull={'PULLRADIUS','PULLLOW','PULLHIGH','PULLMINLEVEL','PULLMAXLEVEL','PULLARC','GROUPWATCHWHO','GROUPSTAYCLOSE','PULLWITH'},
    Heal={'HEALPCT','PANICHEALPCT','HOTHEALPCT','GROUPHEALPCT','GROUPHEALMIN','XTARGETHEAL','REZGROUP','REZRAID','REZINCOMBAT','PRIORITYTARGET'},
    Tank={'MAINTANK'},
    Rest={'MEDCOMBAT','RECOVERPCT','MEDHPSTART','MEDHPSTOP','MEDMANASTART','MEDMANASTOP','MEDENDSTART','MEDENDSTOP','MANASTONESTART','MANASTONESTARTHP','MANASTONESTOPHP','MANASTONETIME'},
    Loot={'LOOTMOBS','LOOTCOMBAT'},
    Debug={'TIMESTAMPS'},
}
function config.getByCategory(category)
    return configByCategory[category]
end

---Get or set the specified configuration option. Currently applies to pull settings only.
---@param name string @The name of the setting.
---@param current_value any @The current value of the specified setting.
---@param new_value string @The new value for the setting.
---@param key string @The configuration key to be set.
function config.getOrSetOption(name, current_value, new_value, key)
    if config[key] == nil then return end
    if new_value then
        if config[key].options and not config[key].options[new_value] then logger.info('\arInvalid option for \ay%s\ax: \ay%s\ax', key, new_value) return end
        if type(current_value) == 'number' then
            config[key].value = tonumber(new_value) or current_value
        elseif type(current_value) == 'boolean' then
            if constants.booleans[new_value] == nil then return end
            config[key].value = constants.booleans[new_value]
        else
            config[key].value = new_value
        end
        logger.info('Setting %s to: %s', key, config[key].value)
    else
        logger.info('%s: %s', name, current_value)
    end
end

---Check whether the specified file exists or not.
---@param file_name string @The name of the file to check existence of.
---@return boolean @Returns true if the file exists, false otherwise.
function config.fileExists(file_name)
    local f = io.open(file_name, "r")
    if f ~= nil then io.close(f) return true else return false end
end

---Load common settings from settings file
---@return table|nil @Returns a table containing the loaded settings file content.
function config.loadSettings()
    if not config.fileExists(config.SETTINGS_FILE) then return nil end
    local settings = assert(loadfile(config.SETTINGS_FILE))()
    if not settings or not settings.common then return settings end
    for setting,value in pairs(settings.common) do
        if config[setting] then config[setting].value = value end
    end
    modes.currentMode = modes.fromString(config.MODE.value)
    logger.timestamps = config.TIMESTAMPS and config.TIMESTAMPS.value or false
    return settings
end

local ignores = {}

---Load mob ignore lists file
function config.loadIgnores()
    local ignore_file = ('%s/%s'):format(mq.configDir, 'aqo_ignore.lua')
    if config.fileExists(ignore_file) then
        ignores = assert(loadfile(ignore_file))()
    end
end

function config.saveIgnores()
    local ignore_file = ('%s/%s'):format(mq.configDir, 'aqo_ignore.lua')
    mq.pickle(ignore_file, ignores)
end

function config.getIgnores(zone_short_name)
    if not zone_short_name then
        return ignores
    else
        return ignores[zone_short_name:lower()]
    end
end

function config.addIgnore(zone_short_name, mob_name)
    if ignores[zone_short_name:lower()] and ignores[zone_short_name:lower()][mob_name] then
        logger.info('\at%s\ax already in ignore list for zone \ay%s\az, skipping', mob_name, zone_short_name)
        return
    end
    if not ignores[zone_short_name:lower()] then ignores[zone_short_name:lower()] = {} end
    ignores[zone_short_name:lower()][mob_name] = true
    logger.info('Added pull ignore \at%s\ax for zone \ay%s\ax', mob_name, zone_short_name)
    config.saveIgnores()
end

function config.removeIgnore(zone_short_name, mob_name)
    if not ignores[zone_short_name:lower()] or not ignores[zone_short_name:lower()][mob_name] then
        logger.info('\at%s\ax not found in ignore list for zone \ay%s\az, skipping', mob_name, zone_short_name)
        return
    end
    ignores[zone_short_name:lower()][mob_name] = nil
    logger.info('Removed pull ignore \at%s\ax for zone \ay%s\ax', mob_name, zone_short_name)
    config.saveIgnores()
end

function config.ignoresContains(zone_short_name, mob_name)
    return ignores[zone_short_name:lower()] and ignores[zone_short_name:lower()][mob_name]
end

return config