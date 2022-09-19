--- @type Mq
local mq = require 'mq'
local assist = require('aqo.routines.assist')
local camp = require('aqo.routines.camp')
local mez = require('aqo.routines.mez')
local pull = require('aqo.routines.pull')
local tank = require('aqo.routines.tank')
local logger = require('aqo.utils.logger')
local persistence = require('aqo.utils.persistence')
local timer = require('aqo.utils.timer')
local common = require('aqo.common')
local config = require('aqo.configuration')
local state = require('aqo.state')
local ui = require('aqo.ui')

local brd = {}

local song_timer = timer:new(3)
local SPELLSETS = {melee=1,caster=1,meleedot=1}
local EPIC_OPTS = {always=1,shm=1,burn=1,never=1}
local OPTS = {
    RALLYGROUP=false,
    USEFADE=false,
    MEZST=true,
    MEZAE=true,
    USEEPIC='always',
    BYOS=false,
    USEINSULTS=true,
    USEBELLOW=true,
    USESWARM=true,
}
config.SPELLSET = 'melee'
mq.cmd('/squelch /stick mod 0')

-- All spells ID + Rank name
local spells = {
    aura = common.get_best_spell({'Aura of Pli Xin Liako', 'Aura of Margidor', 'Aura of Begalru'}), -- spell dmg, overhaste, flurry, triple atk
    composite = common.get_best_spell({'Composite Psalm', 'Dissident Psalm', 'Dichotomic Psalm'}), -- DD+melee dmg bonus + small heal
    aria = common.get_best_spell({'Aria of Pli Xin Liako', 'Aria of Margidor', 'Aria of Begalru'}), -- spell dmg, overhaste, flurry, triple atk
    warmarch = common.get_best_spell({'War March of Centien Xi Va Xakra', 'War March of Radiwol', 'War March of Dekloaz'}), -- haste, atk, ds
    arcane = common.get_best_spell({'Arcane Harmony', 'Arcane Symphony', 'Arcane Ballad'}), -- spell dmg proc
    suffering = common.get_best_spell({'Shojralen\'s Song of Suffering', 'Omorden\'s Song of Suffering', 'Travenro\'s Song of Suffering'}), -- melee dmg proc
    spiteful = common.get_best_spell({'Von Deek\'s Spiteful Lyric', 'Omorden\'s Spiteful Lyric', 'Travenro\' Spiteful Lyric'}), -- AC
    pulse = common.get_best_spell({'Pulse of Nikolas', 'Pulse of Vhal`Sera', 'Pulse of Xigarn'}), -- heal focus + regen
    sonata = common.get_best_spell({'Xetheg\'s Spry Sonata', 'Kellek\'s Spry Sonata', 'Kluzen\'s Spry Sonata'}), -- spell shield, AC, dmg mitigation
    dirge = common.get_best_spell({'Dirge of the Restless', 'Dirge of Lost Horizons'}), -- spell+melee dmg mitigation
    firenukebuff = common.get_best_spell({'Constance\'s Aria', 'Sontalak\'s Aria', 'Quinard\'s Aria'}), -- inc fire DD
    firemagicdotbuff = common.get_best_spell({'Fyrthek Fior\'s Psalm of Potency', 'Velketor\'s Psalm of Potency', 'Akett\'s Psalm of Potency'}), -- inc fire+mag dot
    crescendo = common.get_best_spell({'Zelinstein\'s Lively Crescendo', 'Zburator\'s Lively Crescendo', 'Jembel\'s Lively Crescendo'}), -- small heal hp, mana, end
    insult = common.get_best_spell({'Yelinak\'s Insult', 'Sathir\'s Insult'}), -- synergy DD
    insult2 = common.get_best_spell({'Sogran\'s Insult', 'Omorden\'s Insult', 'Travenro\'s Insult'}), -- synergy DD 2
    chantflame = common.get_best_spell({'Shak Dathor\'s Chant of Flame', 'Sontalak\'s Chant of Flame', 'Quinard\'s Chant of Flame'}),
    chantfrost = common.get_best_spell({'Sylra Fris\' Chant of Frost', 'Yelinak\'s Chant of Frost', 'Ekron\'s Chant of Frost'}),
    chantdisease = common.get_best_spell({'Coagulus\' Chant of Disease', 'Zlexak\'s Chant of Disease', 'Hoshkar\'s Chant of Disease'}),
    chantpoison = common.get_best_spell({'Cruor\'s Chant of Poison', 'Malvus\'s Chant of Poison', 'Nexona\'s Chant of Poison'}),
    alliance = common.get_best_spell({'Coalition of Sticks and Stones', 'Covenant of Sticks and Stones', 'Alliance of Sticks and Stones'}),
    mezst = common.get_best_spell({'Slumber of the Diabo', 'Slumber of Zburator', 'Slumber of Jembel'}),
    mezae = common.get_best_spell({'Wave of Nocturn', 'Wave of Sleep', 'Wave of Somnolence'}),
}
for name,spell in pairs(spells) do
    if spell.name then
        logger.printf('[%s] Found spell: %s (%s)', name, spell.name, spell.id)
    else
        logger.printf('[%s] Could not find spell!', name)
    end
end

-- entries in the dots table are pairs of {spell id, spell name} in priority order
local melee = {
    spells.composite, spells.crescendo, spells.aria,
    spells.spiteful, spells.suffering, spells.warmarch,
    spells.pulse, spells.dirge
}
-- synergy, mezst, mstae

local caster = {
    spells.composite, spells.crescendo, spells.aria,
    spells.arcane, spells.firenukebuff, spells.suffering,
    spells.warmarch, spells.firemagicdotbuff, spells.pulse,
    spells.dirge
}
-- synergy, mezst, mezae

local meleedot = {
    spells.composite, spells.crescendo, spells.chantflame,
    spells.aria, spells.warmarch, spells.chantdisease,
    spells.suffering, spells.pulse, spells.dirge,
    spells.chantfrost
}
-- synergy, mezst, mezae

local songs = {
    melee=melee,
    caster=caster,
    meleedot=meleedot,
}

-- entries in the items table are MQ item datatypes
local items = {}
table.insert(items, mq.TLO.InvSlot('Chest').Item.ID())
table.insert(items, mq.TLO.FindItem('Rage of Rolfron').ID())

-- entries in the AAs table are pairs of {aa name, aa id}
local burnAAs = {}
table.insert(burnAAs, common.get_aa('Quick Time'))
table.insert(burnAAs, common.get_aa('Funeral Dirge'))
table.insert(burnAAs, common.get_aa('Spire of the Minstrels'))
table.insert(burnAAs, common.get_aa('Bladed Song'))
table.insert(burnAAs, common.get_aa('Dance of Blades'))
table.insert(burnAAs, common.get_aa('Flurry of Notes'))
table.insert(burnAAs, common.get_aa('Frenzied Kicks'))

--table.insert(burnAAs, common.get_aa('Glyph of Destruction (115+)'))
--table.insert(burnAAs, common.get_aa('Intensity of the Resolute'))

local burnDiscs = {}
table.insert(burnDiscs, common.get_disc('Thousand Blades'))
-- deftdance discipline

local mashAAs = {}
table.insert(mashAAs, common.get_aa('Cacophony'))
table.insert(mashAAs, common.get_aa('Boastful Bellow'))
table.insert(mashAAs, common.get_aa('Lyrical Prankster'))
table.insert(mashAAs, common.get_aa('Song of Stone'))
--table.insert(mashAAs, get_aaid_and_name('Vainglorious Shout'))

local mashAbilities = {}
table.insert(mashAbilities, 'Intimidation')
table.insert(mashAbilities, 'Kick')

local mashDiscs = {}
table.insert(mashDiscs, common.get_disc('Reflexive Rebuttal'))

local selos = common.get_aa('Selo\'s Sonata')
-- Mana Recovery AAs
local rallyingsolo = common.get_aa('Rallying Solo')
local rallyingcall = common.get_aa('Rallying Call')
local shieldofnotes = common.get_aa('Shield of Notes')
local hymn = common.get_aa('Hymn of the Last Stand')
-- Mana Recovery items
--local item_feather = mq.TLO.FindItem('Unified Phoenix Feather')
--local item_horn = mq.TLO.FindItem('Miniature Horn of Unity') -- 10 minute CD
-- Agro
local fade = common.get_aa('Fading Memories')
-- aa mez
local dirge = common.get_aa('Dirge of the Sleepwalker')
local sonic = common.get_aa('Sonic Disturbance')
local fluxstaff = mq.TLO.FindItem('Staff of Viral Flux').ID()
local symphony = mq.TLO.FindItem('Songblade of the Eternal').ID() or mq.TLO.FindItem('Rapier of Somber Notes').ID()

local SETTINGS_FILE = ('%s/bardbot_%s_%s.lua'):format(mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me.CleanName())
brd.load_settings = function()
    local settings = config.load_settings(SETTINGS_FILE)
    if not settings or not settings.brd then return end
    for setting,value in pairs(settings.brd) do
        OPTS[setting] = value
    end
end

brd.save_settings = function()
    persistence.store(SETTINGS_FILE, {common=config.get_all(), brd=OPTS})
end

local boastful_timer = timer:new(30)
local synergy_timer = timer:new(18)
local crescendo_timer = timer:new(53)
brd.reset_class_timers = function()
    boastful_timer:reset(0)
    synergy_timer:reset(0)
end

local function cast(spell_name, requires_target, requires_los)
    if not common.in_control() or (requires_los and not mq.TLO.Target.LineOfSight()) then return end
    if requires_target and mq.TLO.Target.ID() ~= state.assist_mob_id then return end
    if mq.TLO.Me.Casting() then mq.cmd('/stopsong') end
    logger.printf('Casting \ar%s\ax', spell_name)
    mq.cmdf('/cast "%s"', spell_name)
    mq.delay(10)
    if not mq.TLO.Me.Casting() then mq.cmdf('/cast %s', spell_name) end
    mq.delay(10)
    if not mq.TLO.Me.Casting() then mq.cmdf('/cast %s', spell_name) end
    mq.delay(10)
    song_timer:reset()
    if spell_name == spells.crescendo.name then crescendo_timer:reset() end
end

local function cast_mez(spell_name)
    if not common.in_control() or not mq.TLO.Target.LineOfSight() then return end
    local mez_target_id = mq.TLO.Target.ID()
    if mq.TLO.Me.Casting() then mq.cmd('/stopsong') end
    logger.printf('Casting \ar%s\ax', spell_name)
    mq.cmdf('/cast "%s"', spell_name)
    mq.delay(10)
    if not mq.TLO.Me.Casting() then mq.cmdf('/cast %s', spell_name) end
    mq.delay(10)
    if not mq.TLO.Me.Casting() then mq.cmdf('/cast %s', spell_name) end
    mq.delay(10)
    assist.check_target(brd.reset_class_timers)
    if mq.TLO.Target.ID() ~= mez_target_id then
        mq.delay(1000)
        assist.attack()
    end
    mq.delay(3200, function() return not mq.TLO.Me.Casting() end)
    mq.cmd('/stopcast')
end

local function check_mez()
    -- don't try to mez in manual mode
    if config.MODE:is_manual_mode() or config.MODE:is_tank_mode() then return end
    if OPTS.MEZAE and spells.mezae.name then
        mez.do_ae(spells.mezae.name, cast)
    end
    if OPTS.MEZST and spells.mezst.name then
        mez.do_single(spells.mezst.name, cast)-- cast_mez)
    end
end

-- Casts alliance if we are fighting, alliance is enabled, the spell is ready, alliance isn't already on the mob, there is > 1 necro in group or raid, and we have at least a few dots on the mob.
local function try_alliance()
    if config.USEALLIANCE and spells.alliance.name then
        if mq.TLO.Spell(spells.alliance.name).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        if mq.TLO.Me.Gem(spells.alliance.name)() and mq.TLO.Me.GemTimer(spells.alliance.name)() == 0  and not mq.TLO.Target.Buff(spells.alliance.name)() and mq.TLO.Spell(spells.alliance.name).StacksTarget() then
            cast(spells.alliance.name, true, true)
            return true
        end
    end
    return false
end

local function cast_synergy()
    -- don't nuke if i'm not attacking
    if OPTS.USEINSULTS and synergy_timer:timer_expired() and spells.insult.name and mq.TLO.Me.Combat() then
        if not mq.TLO.Me.Song('Troubadour\'s Synergy')() and mq.TLO.Me.Gem(spells.insult.name)() and mq.TLO.Me.GemTimer(spells.insult.name)() == 0 then
            if mq.TLO.Spell(spells.insult.name).Mana() > mq.TLO.Me.CurrentMana() then
                return false
            end
            cast(spells.insult.name, true, true)
            synergy_timer:reset()
            return true
        end
    end
    return false
end

local function is_dot_ready(spellId, spellName)
    -- don't dot if i'm not attacking
    if not spellName or not mq.TLO.Me.Combat() then return false end
    local actualSpellName = spellName
    if state.get_subscription() ~= 'GOLD' then actualSpellName = spellName:gsub(' Rk%..*', '') end
    local songDuration = 0
    if not mq.TLO.Me.Gem(spellName)() or mq.TLO.Me.GemTimer(spellName)() ~= 0  then
        return false
    end
    if not mq.TLO.Target() or mq.TLO.Target.ID() ~= state.assist_mob_id or mq.TLO.Target.Type() == 'Corpse' then return false end

    songDuration = mq.TLO.Target.MyBuffDuration(actualSpellName)()
    if not common.is_target_dotted_with(spellId, actualSpellName) then
        -- target does not have the dot, we are ready
        logger.debug(state.debug, 'song ready %s', spellName)
        return true
    else
        if not songDuration then
            logger.debug(state.debug, 'song ready %s', spellName)
            return true
        end
    end

    return false
end

local function is_song_ready(spellId, spellName)
    if not spellName then return false end
    local actualSpellName = spellName
    if state.subscription ~= 'GOLD' then actualSpellName = spellName:gsub(' Rk%..*', '') end
    if mq.TLO.Spell(spellName).Mana() > mq.TLO.Me.CurrentMana() or (mq.TLO.Spell(spellName).Mana() > 1000 and mq.TLO.Me.PctMana() < state.min_mana) then
        return false
    end
    if mq.TLO.Spell(spellName).EnduranceCost() > mq.TLO.Me.CurrentEndurance() or (mq.TLO.Spell(spellName).EnduranceCost() > 1000 and mq.TLO.Me.PctEndurance() < state.min_end) then
        return false
    end
    if mq.TLO.Spell(spellName).TargetType() == 'Single' then
        return is_dot_ready(spellId, spellName)
    end

    if not mq.TLO.Me.Gem(spellName)() or mq.TLO.Me.GemTimer(spellName)() > 0 then
        return false
    end
    if spellName == spells.crescendo.name and (mq.TLO.Me.Buff(actualSpellName)() or not crescendo_timer:timer_expired()) then
        -- buggy song that doesn't like to go on CD
        return false
    end

    local songDuration = mq.TLO.Me.Song(actualSpellName).Duration()
    if not songDuration then
        logger.debug(state.debug, 'song ready %s', spellName)
        return true
    else
        local cast_time = mq.TLO.Spell(spellName).MyCastTime()
        if songDuration < cast_time + 3000 then
            logger.debug(state.debug, 'song ready %s', spellName)
        end
        return songDuration < cast_time + 3000
    end
end

local function find_next_song()
    if try_alliance() then return nil end
    if cast_synergy() then return nil end
    for _,song in ipairs(songs[config.SPELLSET]) do -- iterates over the dots array. ipairs(dots) returns 2 values, an index and its value in the array. we don't care about the index, we just want the dot
        local song_id = song.id
        local song_name = song.name
        if is_song_ready(song_id, song_name) then
            if song_name ~= 'Composite Psalm' or mq.TLO.Target() then
                return song
            end
        end
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

local function cycle_songs()
    if not mq.TLO.Me.Invis() then
        local spell = find_next_song() -- find the first available dot to cast that is missing from the target
        if spell then -- if a dot was found
            if mq.TLO.Spell(spell.name).TargetType() == 'Single' and mq.TLO.Me.CombatState() == 'COMBAT' then
                cast(spell.name, true, true) -- then cast the dot
            else
                cast(spell.name) -- then cast the dot
            end
            return true
        end
    end
    return false
end

local fierceeye = common.get_aa('Fierce Eye')
local function use_epic()
    local epic = mq.TLO.FindItem('=Blade of Vesagran')
    local fierceeye_rdy = fierceeye and mq.TLO.Me.AltAbilityReady(fierceeye.name)() or true
    if epic.Timer() == '0' and fierceeye_rdy then
        common.use_aa(fierceeye)
        common.use_item(epic)
    end
end

local function mash()
    local cur_mode = config.MODE
    -- try mash in manual mode only if auto attack is on
    if (cur_mode:is_tank_mode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:is_assist_mode() and assist.should_assist()) or (cur_mode:is_manual_mode() and mq.TLO.Me.Combat()) then
        if OPTS.USEEPIC == 'always' or (OPTS.USEEPIC == 'shm' and mq.TLO.Me.Song('Prophet\'s Gift of the Ruchu')()) then
            use_epic()
        end
        for _,aa in ipairs(mashAAs) do
            if aa.name ~= 'Boastful Bellow' or (OPTS.USEBELLOW and boastful_timer:timer_expired()) then
                if common.use_aa(aa) then
                    if aa.name == 'Boastful Bellow' then
                        boastful_timer:reset()
                    elseif aa.name == 'Song of Stone' or aa.name == 'Lyrical Prankster' then
                        mq.delay(1500)
                    end
                end
            end
        end
        for _,disc in ipairs(mashDiscs) do
            common.use_disc(disc)
        end
        for _,ability in ipairs(mashAbilities) do
            common.use_ability(ability)
        end
    end
end

local function try_burn()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag.
    -- Test them both for each item, and see which one(s) actually work.
    if common.is_burn_condition_met() then

        if OPTS.USEEPIC == 'burn' then
            use_epic()
        end

        --[[
        |===========================================================================================
        |Item Burn
        |===========================================================================================
        ]]--

        for _,item_id in ipairs(items) do
            local item = mq.TLO.FindItem(item_id)
            common.use_item(item)
        end

        --[[
        |===========================================================================================
        |Spell Burn
        |===========================================================================================
        ]]--

        for _,aa in ipairs(burnAAs) do
            common.use_aa(aa)
        end

        --[[
        |===========================================================================================
        |Disc Burn
        |===========================================================================================
        ]]--
        for _,disc in ipairs(burnDiscs) do
            common.use_disc(disc)
        end
    end
end

local function check_mana()
    -- modrods
    common.check_mana()
    local pct_mana = mq.TLO.Me.PctMana()
    local pct_end = mq.TLO.Me.PctEndurance()
    if rallyingsolo and mq.TLO.Me.CombatState() ~= 'COMBAT' and (pct_mana < 20 or pct_end < 20) then
        -- death bloom at some %
        common.use_aa(rallyingsolo)
    end
end

local check_aggro_timer = timer:new(5)
local function check_aggro()
    if common.am_i_dead() or config.MODE:is_tank_mode() then return end
    if mq.TLO.Me.CombatState() == 'COMBAT' and mq.TLO.Me.PctHPs() < 50 then
        common.use_aa(shieldofnotes)
        common.use_aa(hymn)
    end
    if config.MODE:get_name() ~= 'manual' and OPTS.USEFADE and state.mob_count > 0 and check_aggro_timer:timer_expired() then
        if ((mq.TLO.Target() and mq.TLO.Me.PctAggro() >= 70) or mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID()) and mq.TLO.Me.PctHPs() < 50 then
            common.use_aa(fade)
            check_aggro_timer:reset()
            mq.delay(1000)
            mq.cmd('/makemevis')
        end
    end
end

local function check_buffs()
    if common.am_i_dead() then return end
    common.check_combat_buffs()
    if not common.clear_to_buff() then return end
    if spells.aura.name then
        local buffName = spells.aura.name
        if state.subscription ~= 'GOLD' then buffName = spells.aura.name:gsub(' Rk%..*', '') end
        if not mq.TLO.Me.Aura(buffName)() then
            local restore_gem = nil
            if not mq.TLO.Me.Gem(spells.aura.name)() then
                restore_gem = {name=mq.TLO.Me.Gem(1)()}
                common.swap_spell(spells.aura, 1)
            end
            mq.delay(3000, function() return mq.TLO.Me.Gem(spells.aura.name)() and mq.TLO.Me.GemTimer(spells.aura.name)() == 0  end)
            cast(spells.aura.name)
            if restore_gem then
                common.swap_spell(restore_gem, 1)
            end
        end
    end

    common.check_item_buffs()

    if symphony and not mq.TLO.Me.Buff('Symphony of Battle')() then
        local item = mq.TLO.FindItem(symphony)
        common.use_item(item)
    end
end

local function pause_for_rally()
    if rallyingsolo and (mq.TLO.Me.Song(rallyingsolo.name)() or mq.TLO.Me.Buff(rallyingsolo.name)()) then
        if state.mob_count >= 3 then
            return true
        elseif mq.TLO.Target() and mq.TLO.Target.Named() then
            return true
        else
            return false
        end
    else
        return false
    end
end

--[[
local melee = {
    spells.aria, spells.arcane, spells.spiteful,
    spells.suffering, spells.insult, spells.warmarch,
    spells.sonata, spells.mezst, spells.mezae, 
    spells.crescendo, spells.pulse, spells.composite, 
    spells.dirge
}
-- synergy, mezst, mstae

local caster = {
    spells.aria, spells.arcane, spells.firenukebuff,
    spells.suffering, spells.insult, spells.warmarch,
    spells.firemagicdotbuff, spells.mezst, spells.mezae,
    spells.crescendo, spells.pulse, spells.composite,
    spells.dirge
}
-- synergy, mezst, mezae

local meleedot = {
    spells.aria, spells.chantflame, spells.chantfrost,
    spells.suffering, spells.insult, spells.warmarch,
    spells.chantdisease, spells.mezst, spells.mezae,
    spells.crescendo, spells.pulse, spells.composite,
    spells.dirge
}
]]
local composite_names = {['Composite Psalm']=true,['Dissident Psalm']=true,['Dichotomic Psalm']=true}
local check_spell_timer = timer:new(30)
local function check_spell_set()
    if not common.clear_to_buff() or mq.TLO.Me.Moving() or common.am_i_dead() or OPTS.BYOS then return end
    if state.spellset_loaded ~= config.SPELLSET or check_spell_timer:timer_expired() then
        --for i, song in ipairs(songs[config.SPELLSET]) do
        --    common.swap_spell(song, i, i == 12 and composite_names or nil)
        --end
        if config.SPELLSET == 'melee' then
            common.swap_spell(spells.aria, 1)
            common.swap_spell(spells.arcane, 2)
            common.swap_spell(spells.spiteful, 3)
            common.swap_spell(spells.suffering, 4)
            common.swap_spell(spells.insult, 5)
            common.swap_spell(spells.warmarch, 6)
            common.swap_spell(spells.sonata, 7)
            common.swap_spell(spells.mezst, 8)
            common.swap_spell(spells.mezae, 9)
            common.swap_spell(spells.crescendo, 10)
            common.swap_spell(spells.pulse, 11)
            common.swap_spell(spells.composite, 12, composite_names)
            common.swap_spell(spells.dirge, 13)
            state.spellset_loaded = config.SPELLSET
        elseif config.SPELLSET == 'caster' then
            common.swap_spell(spells.aria, 1)
            common.swap_spell(spells.arcane, 2)
            common.swap_spell(spells.firenukebuff, 3)
            common.swap_spell(spells.suffering, 4)
            common.swap_spell(spells.insult, 5)
            common.swap_spell(spells.warmarch, 6)
            common.swap_spell(spells.firemagicdotbuff, 7)
            common.swap_spell(spells.mezst, 8)
            common.swap_spell(spells.mezae, 9)
            common.swap_spell(spells.crescendo, 10)
            common.swap_spell(spells.pulse, 11)
            common.swap_spell(spells.composite, 12, composite_names)
            common.swap_spell(spells.dirge, 13)
            state.spellset_loaded = config.SPELLSET
        elseif config.SPELLSET == 'meleedot' then
            common.swap_spell(spells.aria, 1)
            common.swap_spell(spells.chantflame, 2)
            common.swap_spell(spells.chantfrost, 3)
            common.swap_spell(spells.suffering, 4)
            common.swap_spell(spells.insult, 5)
            common.swap_spell(spells.warmarch, 6)
            common.swap_spell(spells.chantdisease, 7)
            common.swap_spell(spells.mezst, 8)
            common.swap_spell(spells.mezae, 9)
            common.swap_spell(spells.crescendo, 10)
            common.swap_spell(spells.pulse, 11)
            common.swap_spell(spells.composite, 12, composite_names)
            common.swap_spell(spells.dirge, 13)
            state.spellset_loaded = config.SPELLSET
        end
        check_spell_timer:reset()
    end
end

brd.pull_func = function()
    if fluxstaff then
        local item = mq.TLO.FindItem(fluxstaff)
        common.use_item(item)
    elseif sonic then
        common.use_aa(sonic)
    end
end

brd.setup_events = function()
    mez.setup_events()
end

brd.process_cmd = function(opt, new_value)
    if new_value then
        if opt == 'USEEPIC' then
            if EPIC_OPTS[new_value] then
                logger.printf('Setting %s to: %s', opt, new_value)
                OPTS[opt] = new_value
            end
        elseif opt == 'SPELLSET' then
            if SPELLSETS[new_value] then
                logger.printf('Setting %s to: %s', opt, new_value)
                config.SPELLSET = new_value
            end
        elseif type(OPTS[opt]) == 'boolean' then
            if common.BOOL.FALSE[new_value] then
                logger.printf('Setting %s to: false', opt)
                if OPTS[opt] ~= nil then OPTS[opt] = false end
            elseif common.BOOL.TRUE[new_value] then
                logger.printf('Setting %s to: true', opt)
                if OPTS[opt] ~= nil then OPTS[opt] = true end
            end
        elseif type(OPTS[opt]) == 'number' then
            if tonumber(new_value) then
                logger.printf('Setting %s to: %s', opt, tonumber(new_value))
                if OPTS[opt] ~= nil then OPTS[opt] = tonumber(new_value) end
            end
        else
            logger.printf('Unsupported command line option: %s %s', opt, new_value)
        end
    else
        if OPTS[opt] ~= nil then
            logger.printf('%s: %s', opt:lower(), OPTS[opt])
        else
            logger.printf('Unrecognized option: %s', opt)
        end
    end
end

local function can_i_sing()
    if song_timer:timer_expired() then
        if mq.TLO.Me.Casting() then mq.cmd('/stopsong') end
        return true
    end
    return false
end

local selos_timer = timer:new(30)
brd.main_loop = function()
    -- keep cursor clear for spell swaps and such
    if selos_timer:timer_expired() then
        common.use_aa(selos)
        selos_timer:reset()
    end
    if not state.pull_in_progress then
        -- ensure correct spells are loaded based on selected spell set
        if can_i_sing() then check_spell_set() end
        if config.MODE:is_tank_mode() then
            -- get mobs in camp
            camp.mob_radar()
            -- pick mob to tank if not tanking
            tank.find_mob_to_tank()
            tank.tank_mob()
        else
            -- check our surroundings for mobs to deal with
            camp.mob_radar()
        end
        -- check whether we need to return to camp
        camp.check_camp()
        -- check whether we need to go chasing after the chase target
        common.check_chase()
        if not pause_for_rally() then
            -- assist the MA if the target matches assist criteria
            if config.MODE:is_assist_mode() then
                assist.check_target(brd.reset_class_timers)
                assist.attack()
            end
            -- check we have the correct target to attack
            check_mez()
            -- assist the MA if the target matches assist criteria
            if config.MODE:is_assist_mode() then
                assist.check_target(brd.reset_class_timers)
                assist.attack()
            end
            -- begin actual combat stuff
            assist.send_pet()
            if mq.TLO.Me.CombatState() ~= 'ACTIVE' and mq.TLO.Me.CombatState() ~= 'RESTING' then
                if can_i_sing() then cycle_songs() end
            end
            mash()
            -- pop a bunch of burn stuff if burn conditions are met
            if can_i_sing() then try_burn() end
            -- try not to run OOM
            check_aggro()
        end
        check_mana()
        if can_i_sing() then check_buffs() end
        common.rest()
    end
    if config.MODE:is_pull_mode() and not pause_for_rally() then
        pull.pull_mob(brd.pull_func)
    end
end

---Draw bard specific settings which can be toggled on the skills tab
brd.draw_skills_tab = function()
    config.SPELLSET = ui.draw_combo_box('Spell Set', config.SPELLSET, SPELLSETS, true)
    OPTS.USEEPIC = ui.draw_combo_box('Epic', OPTS.USEEPIC, EPIC_OPTS, true)
    config.USEALLIANCE = ui.draw_check_box('Alliance', '##alliance', config.USEALLIANCE, 'Use alliance spell')
    OPTS.MEZST = ui.draw_check_box('Mez ST', '##mezst', OPTS.MEZST, 'Mez single target')
    OPTS.MEZAE = ui.draw_check_box('Mez AE', '##mezae', OPTS.MEZAE, 'Mez AOE')
    config.AEMEZCOUNT = ui.draw_input_int('AE Mez Count', '##aemezcnt', config.AEMEZCOUNT, 'Threshold to use AE Mez ability')
    OPTS.USEINSULTS = ui.draw_check_box('Use Insults', '##useinsults', OPTS.USEINSULTS, 'Use insult songs')
    OPTS.USEBELLOW = ui.draw_check_box('Use Bellow', '##usebellow', OPTS.USEBELLOW, 'Use Boastful Bellow AA')
    OPTS.USEFADE = ui.draw_check_box('Use Fade', '##usefade', OPTS.USEFADE, 'Fade when agro')
    OPTS.BYOS = ui.draw_check_box('BYOS', '##byos', OPTS.BYOS, 'Bring your own spells')
    OPTS.RALLYGROUP = ui.draw_check_box('Rallying Group', '##rallygroup', OPTS.RALLYGROUP, 'Use Rallying Group AA')
end

return brd
