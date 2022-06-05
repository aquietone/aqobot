--- @type mq
local mq = require 'mq'
local assist = require('aqo.routines.assist')
local camp = require('aqo.routines.camp')
local mez = require('aqo.routines.mez')
local logger = require('aqo.utils.logger')
local persistence = require('aqo.utils.persistence')
local timer = require('aqo.utils.timer')
local common = require('aqo.common')
local config = require('aqo.configuration')
local state = require('aqo.state')
local ui = require('aqo.ui')

local brd = {}

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
}
config.set_spell_set('melee')
mq.cmd('/squelch /stick mod 0')

--[[
    - aria
    - chant of flame
    - chant of frost
    - song of suffering
    - yelinaks insult
    - war march
    - chant of disease
    - sathir's insult
    - ae mez
    - chant of poison
    - pulse
    - composite
    - dirge

    general use AAs: bladed song, cacophony, boastful bellow, epic+fierce eye, lyrical prankster
]]
-- All spells ID + Rank name
local spells = {
    ['aura']=common.get_spell('Aura of Pli Xin Liako') or common.get_spell('Aura of Margidor') or common.get_spell('Aura of Begalru') or {name=nil,id=nil}, -- spell dmg, overhaste, flurry, triple atk
    ['composite']=common.get_spell('Composite Psalm') or common.get_spell('Dissident Psalm') or common.get_spell('Dichotomic Psalm') or {name=nil,id=nil}, -- DD+melee dmg bonus + small heal
    ['aria']=common.get_spell('Aria of Pli Xin Liako') or common.get_spell('Aria of Margidor') or common.get_spell('Aria of Begalru') or {name=nil,id=nil}, -- spell dmg, overhaste, flurry, triple atk
    ['warmarch']=common.get_spell('War March of Centien Xi Va Xakra') or common.get_spell('War March of Radiwol') or common.get_spell('War March of Dekloaz') or {name=nil,id=nil}, -- haste, atk, ds
    ['arcane']=common.get_spell('Arcane Harmony') or common.get_spell('Arcane Symphony') or common.get_spell('Arcane Ballad') or {name=nil,id=nil}, -- spell dmg proc
    ['suffering']=common.get_spell('Shojralen\'s Song of Suffering') or common.get_spell('Omorden\'s Song of Suffering') or common.get_spell('Travenro\'s Song of Suffering') or {name=nil,id=nil}, -- melee dmg proc
    ['spiteful']=common.get_spell('Von Deek\'s Spiteful Lyric') or common.get_spell('Omorden\'s Spiteful Lyric') or common.get_spell('Travenro\' Spiteful Lyric') or {name=nil,id=nil}, -- AC
    ['pulse']=common.get_spell('Pulse of Nikolas') or common.get_spell('Pulse of Vhal`Sera') or common.get_spell('Pulse of Xigarn') or {name=nil,id=nil}, -- heal focus + regen
    ['sonata']=common.get_spell('Xetheg\'s Spry Sonata') or common.get_spell('Kellek\'s Spry Sonata') or common.get_spell('Kluzen\'s Spry Sonata') or {name=nil,id=nil}, -- spell shield, AC, dmg mitigation
    ['dirge']=common.get_spell('Dirge of the Restless') or common.get_spell('Dirge of Lost Horizons') or {name=nil,id=nil},-- or common.get_spell('Dirge of the Restless'), -- spell+melee dmg mitigation
    ['firenukebuff']=common.get_spell('Constance\'s Aria') or common.get_spell('Sontalak\'s Aria') or common.get_spell('Quinard\'s Aria') or {name=nil,id=nil}, -- inc fire DD
    ['firemagicdotbuff']=common.get_spell('Fyrthek Fior\'s Psalm of Potency') or common.get_spell('Velketor\'s Psalm of Potency') or common.get_spell('Akett\'s Psalm of Potency') or {name=nil,id=nil}, -- inc fire+mag dot
    ['crescendo']=common.get_spell('Zelinstein\'s Lively Crescendo') or common.get_spell('Zburator\'s Lively Crescendo') or common.get_spell('Jembel\'s Lively Crescendo') or {name=nil,id=nil}, -- small heal hp, mana, end
    ['insult']=common.get_spell('Yelinak\'s Insult') or common.get_spell('Sathir\'s Insult') or {name=nil,id=nil}, -- synergy DD
    ['insult2']=common.get_spell('Sogran\'s Insult') or common.get_spell('Omorden\'s Insult') or common.get_spell('Travenro\'s Insult') or {name=nil,id=nil}, -- synergy DD 2
    ['chantflame']=common.get_spell('Shak Dathor\'s Chant of Flame') or common.get_spell('Sontalak\'s Chant of Flame') or common.get_spell('Quinard\'s Chant of Flame') or {name=nil,id=nil},
    ['chantfrost']=common.get_spell('Sylra Fris\' Chant of Frost') or common.get_spell('Yelinak\'s Chant of Frost') or common.get_spell('Ekron\'s Chant of Frost') or {name=nil,id=nil},
    ['chantdisease']=common.get_spell('Coagulus\' Chant of Disease') or common.get_spell('Zlexak\'s Chant of Disease') or common.get_spell('Hoshkar\'s Chant of Disease') or {name=nil,id=nil},
    ['chantpoison']=common.get_spell('Cruor\'s Chant of Poison') or common.get_spell('Malvus\'s Chant of Poison') or common.get_spell('Nexona\'s Chant of Poison') or {name=nil,id=nil},
    ['alliance']=common.get_spell('Coalition of Sticks and Stones') or common.get_spell('Covenant of Sticks and Stones') or common.get_spell('Alliance of Sticks and Stones') or {name=nil,id=nil},
    ['mezst']=common.get_spell('Slumber of the Diabo') or common.get_spell('Slumber of Zburator') or common.get_spell('Slumber of Jembel') or {name=nil,id=nil},
    ['mezae']=common.get_spell('Wave of Nocturn') or common.get_spell('Wave of Sleep') or common.get_spell('Wave of Somnolence') or {name=nil,id=nil},
}
for name,spell in pairs(spells) do
    if spell['name'] then
        logger.printf('[%s] Found spell: %s (%s)', name, spell['name'], spell['id'])
    else
        logger.printf('[%s] Could not find spell!', name)
    end
end

-- entries in the dots table are pairs of {spell id, spell name} in priority order
local melee = {}
table.insert(melee, spells['composite'])
table.insert(melee, spells['crescendo'])
table.insert(melee, spells['aria'])
table.insert(melee, spells['spiteful'])
table.insert(melee, spells['suffering'])
table.insert(melee, spells['warmarch'])
table.insert(melee, spells['pulse'])
table.insert(melee, spells['dirge'])
-- synergy
-- mezst
-- mezae

local caster = {}
table.insert(caster, spells['composite'])
table.insert(caster, spells['crescendo'])
table.insert(caster, spells['aria'])
table.insert(caster, spells['arcane'])
table.insert(caster, spells['firenukebuff'])
table.insert(caster, spells['suffering'])
table.insert(caster, spells['warmarch'])
table.insert(caster, spells['firemagicdotbuff'])
table.insert(caster, spells['pulse'])
table.insert(caster, spells['dirge'])
-- synergy
-- mezst
-- mezae

local meleedot = {}
table.insert(meleedot, spells['composite'])
table.insert(meleedot, spells['crescendo'])
table.insert(meleedot, spells['chantflame'])
table.insert(meleedot, spells['aria'])
table.insert(meleedot, spells['warmarch'])
table.insert(meleedot, spells['chantdisease'])
table.insert(meleedot, spells['suffering'])
table.insert(meleedot, spells['pulse'])
table.insert(meleedot, spells['dirge'])
table.insert(meleedot, spells['chantfrost'])
-- synergy
-- mezst
-- mezae

local songs = {
    ['melee']=melee,
    ['caster']=caster,
    ['meleedot']=meleedot,
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

local SETTINGS_FILE = ('%s/bardbot_%s_%s.lua'):format(mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me.CleanName())
brd.load_settings = function()
    local settings = config.load_settings(SETTINGS_FILE)
    if not settings or not settings.brd then return end
    if settings.brd.USESWARM ~= nil then OPTS.USESWARM = settings.brd.USESWARM end
    if settings.brd.RALLYGROUP ~= nil then OPTS.RALLYGROUP = settings.brd.RALLYGROUP end
    if settings.brd.USEFADE ~= nil then OPTS.USEFADE = settings.brd.USEFADE end
    if settings.brd.MEZST ~= nil then OPTS.MEZST = settings.brd.MEZST end
    if settings.brd.MEZAE ~= nil then OPTS.MEZAE = settings.brd.MEZAE end
    if settings.brd.USEEPIC ~= nil then OPTS.USEEPIC = settings.brd.USEEPIC end
    if settings.brd.BYOS ~= nil then OPTS.BYOS = settings.brd.BYOS end
    if settings.brd.USEINSULTS ~= nil then OPTS.USEINSULTS = settings.brd.USEINSULTS end
    if settings.brd.USEBELLOW ~= nil then OPTS.USEBELLOW = settings.brd.USEBELLOW end
end

brd.save_settings = function()
    persistence.store(SETTINGS_FILE, {common=config.get_all(), brd=OPTS})
end

local boastful_timer = timer:new(30)
local synergy_timer = timer:new(18)
local crescendo_timer = timer:new(50)
brd.reset_class_timers = function()
    boastful_timer:reset(0)
    synergy_timer:reset(0)
end

local function cast(spell_name, requires_target, requires_los)
    if not common.in_control() or (requires_los and not mq.TLO.Target.LineOfSight()) then return end
    if requires_target and mq.TLO.Target.ID() ~= state.get_assist_mob_id() then return end
    logger.printf('Casting \ar%s\ax', spell_name)
    mq.cmdf('/cast "%s"', spell_name)
    mq.delay(10)
    if not mq.TLO.Me.Casting() then mq.cmdf('/cast %s', spell_name) end
    mq.delay(10)
    if not mq.TLO.Me.Casting() then mq.cmdf('/cast %s', spell_name) end
    mq.delay(10)
    mq.delay(3200, function()
        -- this caused client to lock up...
        common.check_chase()
        assist.check_target(brd.reset_class_timers)
        assist.attack(true) -- don't attack unless already have los to the target to avoid delay in delay
        return not mq.TLO.Me.Casting()
    end)
    mq.cmd('/stopcast')
    if spells['crescendo'] and spell_name == spells['crescendo']['name'] then crescendo_timer:reset() end
end

local function cast_mez(spell_name)
    if not common.in_control() or not mq.TLO.Target.LineOfSight() then return end
    local mez_target_id = mq.TLO.Target.ID()
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
    if config.get_mode():get_name() == 'manual' then return end
    if OPTS.MEZAE and spells['mezae'] then
        mez.do_ae(spells['mezae']['name'], cast)
    end
    if OPTS.MEZST and spells['mezst'] then
        mez.do_single(spells['mezst']['name'], cast_mez)
    end
end

-- Casts alliance if we are fighting, alliance is enabled, the spell is ready, alliance isn't already on the mob, there is > 1 necro in group or raid, and we have at least a few dots on the mob.
local function try_alliance()
    if config.get_use_alliance() and spells['alliance'] then
        if mq.TLO.Spell(spells['alliance']['name']).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        if mq.TLO.Me.Gem(spells['alliance']['name'])() and mq.TLO.Me.GemTimer(spells['alliance']['name'])() == 0  and not mq.TLO.Target.Buff(spells['alliance']['name'])() and mq.TLO.Spell(spells['alliance']['name']).StacksTarget() then
            cast(spells['alliance']['name'], true, true)
            return true
        end
    end
    return false
end

local function cast_synergy()
    -- don't nuke if i'm not attacking
    if OPTS.USEINSULTS and synergy_timer:timer_expired() and spells['insult'] and mq.TLO.Me.Combat() then
        if not mq.TLO.Me.Song('Troubadour\'s Synergy')() and mq.TLO.Me.Gem(spells['insult']['name'])() and mq.TLO.Me.GemTimer(spells['insult']['name'])() == 0 then
            if mq.TLO.Spell(spells['insult']['name']).Mana() > mq.TLO.Me.CurrentMana() then
                return false
            end
            cast(spells['insult']['name'], true, true)
            synergy_timer:reset()
            return true
        end
    end
    return false
end

local function is_dot_ready(spellId, spellName)
    -- don't dot if i'm not attacking
    if not spellName or not mq.TLO.Me.Combat() then return false end
    local songDuration = 0
    if not mq.TLO.Me.Gem(spellName)() or mq.TLO.Me.GemTimer(spellName)() ~= 0  then
        return false
    end
    if not mq.TLO.Target() or mq.TLO.Target.ID() ~= state.get_assist_mob_id() or mq.TLO.Target.Type() == 'Corpse' then return false end

    songDuration = mq.TLO.Target.MyBuffDuration(spellName)()
    if not common.is_target_dotted_with(spellId, spellName) then
        -- target does not have the dot, we are ready
        logger.debug(state.get_debug(), 'song ready %s', spellName)
        return true
    else
        if not songDuration then
            logger.debug(state.get_debug(), 'song ready %s', spellName)
            return true
        end
    end

    return false
end

local function is_song_ready(spellId, spellName)
    if not spellName then return false end
    if mq.TLO.Spell(spellName).Mana() > mq.TLO.Me.CurrentMana() or (mq.TLO.Spell(spellName).Mana() > 1000 and mq.TLO.Me.PctMana() < state.get_min_mana()) then
        return false
    end
    if mq.TLO.Spell(spellName).EnduranceCost() > mq.TLO.Me.CurrentEndurance() or (mq.TLO.Spell(spellName).EnduranceCost() > 1000 and mq.TLO.Me.PctEndurance() < state.get_min_end()) then
        return false
    end
    if mq.TLO.Spell(spellName).TargetType() == 'Single' then
        return is_dot_ready(spellId, spellName)
    end

    if not mq.TLO.Me.Gem(spellName)() or mq.TLO.Me.GemTimer(spellName)() > 0 then
        return false
    end
    if spellName == spells['crescendo']['name'] and (mq.TLO.Me.Buff(spells['crescendo']['name'])() or not crescendo_timer:timer_expired()) then
        -- buggy song that doesn't like to go on CD
        return false
    end

    local songDuration = mq.TLO.Me.Song(spellName).Duration()
    if not songDuration then
        logger.debug(state.get_debug(), 'song ready %s', spellName)
        return true
    else
        local cast_time = mq.TLO.Spell(spellName).MyCastTime()
        if songDuration < cast_time + 3000 then
            logger.debug(state.get_debug(), 'song ready %s', spellName)
        end
        return songDuration < cast_time + 3000
    end
end

local function find_next_song()
    if try_alliance() then return nil end
    if cast_synergy() then return nil end
    for _,song in ipairs(songs[config.get_spell_set()]) do -- iterates over the dots array. ipairs(dots) returns 2 values, an index and its value in the array. we don't care about the index, we just want the dot
        local spell_id = song['id']
        local spell_name = song['name']
        if is_song_ready(spell_id, spell_name) then
            if spell_name ~= 'Composite Psalm' or mq.TLO.Target() then
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
            if mq.TLO.Spell(spell['name']).TargetType() == 'Single' and mq.TLO.Me.CombatState() == 'COMBAT' then
                cast(spell['name'], true, true) -- then cast the dot
            else
                cast(spell['name']) -- then cast the dot
            end
            return true
        end
    end
    return false
end

local fierceeye = common.get_aa('Fierce Eye')
local function use_epic()
    local epic = mq.TLO.FindItem('=Blade of Vesagran')
    local fierceeye_rdy = mq.TLO.Me.AltAbilityReady(fierceeye['name'])()
    if epic.Timer() == '0' and fierceeye_rdy then
        common.use_aa(fierceeye)
        common.use_item(epic)
    end
end

local function mash()
    local cur_mode = config.get_mode()
    -- try mash in manual mode only if auto attack is on
    if (cur_mode:is_tank_mode() and mq.TLO.Me.CombatState() == 'COMBAT') or (cur_mode:is_assist_mode() and assist.should_assist()) or (cur_mode:is_manual_mode() and mq.TLO.Me.Combat()) then--and mq.TLO.Me.CombatState() == 'COMBAT') then
        if OPTS.USEEPIC == 'always' then
            use_epic()
        elseif OPTS.USEEPIC == 'shm' and mq.TLO.Me.Song('Prophet\'s Gift of the Ruchu')() then
            use_epic()
        end
        for _,aa in ipairs(mashAAs) do
            if aa['name'] ~= 'Boastful Bellow' or (OPTS.USEBELLOW and boastful_timer:timer_expired()) then
                if common.use_aa(aa) then
                    if aa['name'] == 'Boastful Bellow' then
                        boastful_timer:reset()
                    elseif aa['name'] == 'Song of Stone' or aa['name'] == 'Lyrical Prankster' then
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
    if common.am_i_dead() then return end
    if mq.TLO.Me.CombatState() == 'COMBAT' and mq.TLO.Me.PctHPs() < 50 then
        common.use_aa(shieldofnotes)
        common.use_aa(hymn)
    end
    if config.get_mode():get_name() ~= 'manual' and OPTS.USEFADE and state.get_mob_count() > 0 and check_aggro_timer:timer_expired() then
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
    if spells['aura'] and not mq.TLO.Me.Aura(spells['aura']['name'])() then
        local restore_gem = nil
        if not mq.TLO.Me.Gem(spells['aura']['name'])() then
            restore_gem = {name=mq.TLO.Me.Gem(1)()}
            common.swap_spell(spells['aura'], 1)
        end
        mq.delay(3000, function() return mq.TLO.Me.Gem(spells['aura']['name'])() and mq.TLO.Me.GemTimer(spells['aura']['name'])() == 0  end)
        cast(spells['aura']['name'])
        if restore_gem then
            common.swap_spell(restore_gem, 1)
        end
    end

    common.check_item_buffs()
end

local function pause_for_rally()
    if rallyingsolo and mq.TLO.Me.Song(rallyingsolo['name'])() or mq.TLO.Me.Buff(rallyingsolo['name'])() then
        if state.get_mob_count() >= 3 then
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

local composite_names = {['Composite Psalm']=true,['Dissident Psalm']=true,['Dichotomic Psalm']=true}
local check_spell_timer = timer:new(30)
local function check_spell_set()
    if not common.clear_to_buff() or mq.TLO.Me.Moving() or common.am_i_dead() or OPTS.BYOS then return end
    if state.get_spellset_loaded() ~= config.get_spell_set() or check_spell_timer:timer_expired() then
        if config.get_spell_set() == 'melee' then
            common.swap_spell(spells['aria'], 1)
            common.swap_spell(spells['arcane'], 2)
            common.swap_spell(spells['spiteful'], 3)
            common.swap_spell(spells['suffering'], 4)
            common.swap_spell(spells['insult'], 5)
            common.swap_spell(spells['warmarch'], 6)
            common.swap_spell(spells['sonata'], 7)
            common.swap_spell(spells['mezst'], 8)
            common.swap_spell(spells['mezae'], 9)
            common.swap_spell(spells['crescendo'], 10)
            common.swap_spell(spells['pulse'], 11)
            common.swap_spell(spells['composite'], 12, composite_names)
            common.swap_spell(spells['dirge'], 13)
            state.set_spellset_loaded(config.get_spell_set())
        elseif config.get_spell_set() == 'caster' then
            common.swap_spell(spells['aria'], 1)
            common.swap_spell(spells['arcane'], 2)
            common.swap_spell(spells['firenukebuff'], 3)
            common.swap_spell(spells['suffering'], 4)
            common.swap_spell(spells['insult'], 5)
            common.swap_spell(spells['warmarch'], 6)
            common.swap_spell(spells['firemagicdotbuff'], 7)
            common.swap_spell(spells['mezst'], 8)
            common.swap_spell(spells['mezae'], 9)
            common.swap_spell(spells['crescendo'], 10)
            common.swap_spell(spells['pulse'], 11)
            common.swap_spell(spells['composite'], 12, composite_names)
            common.swap_spell(spells['dirge'], 13)
            state.set_spellset_loaded(config.get_spell_set())
        elseif config.get_spell_set() == 'meleedot' then
            common.swap_spell(spells['aria'], 1)
            common.swap_spell(spells['chantflame'], 2)
            common.swap_spell(spells['chantfrost'], 3)
            common.swap_spell(spells['suffering'], 4)
            common.swap_spell(spells['insult'], 5)
            common.swap_spell(spells['warmarch'], 6)
            common.swap_spell(spells['chantdisease'], 7)
            common.swap_spell(spells['mezst'], 8)
            common.swap_spell(spells['mezae'], 9)
            common.swap_spell(spells['crescendo'], 10)
            common.swap_spell(spells['pulse'], 11)
            common.swap_spell(spells['composite'], 12, composite_names)
            common.swap_spell(spells['dirge'], 13)
            state.set_spellset_loaded(config.get_spell_set())
        end
        check_spell_timer:reset()
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
                config.set_spell_set(new_value)
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

local selos_timer = timer:new(30)
brd.main_loop = function()
    -- keep cursor clear for spell swaps and such
    if selos_timer:timer_expired() then
        common.use_aa(selos)
        selos_timer:reset()
    end
    -- ensure correct spells are loaded based on selected spell set
    check_spell_set()
    -- check whether we need to return to camp
    camp.check_camp()
    -- check whether we need to go chasing after the chase target
    common.check_chase()
    -- check our surroundings for mobs to deal with
    camp.mob_radar()
    if not pause_for_rally() then
        -- assist the MA if the target matches assist criteria
        assist.check_target(brd.reset_class_timers)
        assist.attack()
        -- check we have the correct target to attack
        check_mez()
        -- assist the MA if the target matches assist criteria
        assist.check_target(brd.reset_class_timers)
        assist.attack()
        -- begin actual combat stuff
        assist.send_pet()
        if mq.TLO.Me.CombatState() ~= 'ACTIVE' and mq.TLO.Me.CombatState() ~= 'RESTING' then
            cycle_songs()
        end
        mash()
        -- pop a bunch of burn stuff if burn conditions are met
        try_burn()
        -- try not to run OOM
        check_aggro()
    end
    check_mana()
    check_buffs()
    common.rest()
end

brd.draw_skills_tab = function()
    config.set_spell_set(ui.draw_combo_box('Spell Set', config.get_spell_set(), SPELLSETS, true))
    OPTS.USEEPIC = ui.draw_combo_box('Epic', OPTS.USEEPIC, EPIC_OPTS, true)
    config.set_use_alliance(ui.draw_check_box('Alliance', '##alliance', config.get_use_alliance(), 'Use alliance spell'))
    OPTS.MEZST = ui.draw_check_box('Mez ST', '##mezst', OPTS.MEZST, 'Mez single target')
    OPTS.MEZAE = ui.draw_check_box('Mez AE', '##mezae', OPTS.MEZAE, 'Mez AOE')
    OPTS.USEINSULTS = ui.draw_check_box('Use Insults', '##useinsults', OPTS.USEINSULTS, 'Use insult songs')
    OPTS.USEBELLOW = ui.draw_check_box('Use Bellow', '##usebellow', OPTS.USEBELLOW, 'Use Boastful Bellow AA')
    OPTS.USEFADE = ui.draw_check_box('Use Fade', '##usefade', OPTS.USEFADE, 'Fade when agro')
    OPTS.BYOS = ui.draw_check_box('BYOS', '##byos', OPTS.BYOS, 'Bring your own spells')
    OPTS.RALLYGROUP = ui.draw_check_box('Rallying Group', '##rallygroup', OPTS.RALLYGROUP, 'Use Rallying Group AA')
end

brd.draw_burn_tab = function()
    config.set_burn_count(ui.draw_input_int('Burn Count', '##burncnt', config.get_burn_count(), 'Trigger burns if this many mobs are on aggro'))
    config.set_burn_percent(ui.draw_input_int('Burn Percent', '##burnpct', config.get_burn_percent(), 'Percent health to begin burns'))
    config.set_burn_always(ui.draw_check_box('Burn Always', '##burnalways', config.get_burn_always(), 'Always be burning'))
    config.set_burn_all_named(ui.draw_check_box('Burn Named', '##burnnamed', config.get_burn_all_named(), 'Burn all named'))
end

return brd
