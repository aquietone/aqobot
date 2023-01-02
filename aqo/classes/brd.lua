--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local logger = require('utils.logger')
local timer = require('utils.timer')
local common = require('common')
local state = require('state')

-- what was this again?
mq.cmd('/squelch /stick mod 0')

class.class = 'brd'
class.classOrder = {'assist', 'mez', 'assist', 'cast', 'mash', 'burn', 'aggro', 'recover', 'buff', 'rest'}

if state.emu then
    class.SPELLSETS = {emuancient=1,emuaura65=1,emuaura55=1,emunoaura=1}
    class.DEFAULT_SPELLSET='emuancient'
else
    class.SPELLSETS = {melee=1,caster=1,meleedot=1}
    class.DEFAULT_SPELLSET='melee'
end
class.EPIC_OPTS = {always=1,shm=1,burn=1,never=1}

class.addCommonOptions()
class.addCommonAbilities()
class.addOption('USEEPIC', 'Epic', 'always', class.EPIC_OPTS, nil, 'combobox')
class.addOption('MEZST', 'Mez ST', true, nil, 'Mez single target', 'checkbox')
class.addOption('MEZAE', 'Mez AE', true, nil, 'Mez AOE', 'checkbox')
class.addOption('MEZAECOUNT', 'Mez AE Count', 3, nil, 'Threshold to use AE Mez ability', 'checkbox')
class.addOption('USEINSULTS', 'Use Insults', true, nil, 'Use insult songs', 'checkbox')
class.addOption('USEINTIMIDATE', 'Use Intimidate', false, nil, 'Use Intimidate (It may fear mobs without the appropriate AA\'s)', 'checkbox')
class.addOption('USEBELLOW', 'Use Bellow', true, nil, 'Use Boastful Bellow AA', 'checkbox')
class.addOption('USECACOPHONY', 'Use Cacophony', true, nil, 'Use Cacophony AA', 'checkbox')
class.addOption('USEFADE', 'Use Fade', false, nil, 'Fade when aggro', 'checkbox')
class.addOption('RALLYGROUP', 'Rallying Group', false, nil, 'Use Rallying Group AA', 'checkbox')
class.addOption('USESWARM', 'Use Swarm', true, nil, 'Use swarm pet AAs', 'checkbox')
class.addOption('USESNARE', 'Use Snare', false, nil, 'Use snare song', 'checkbox')
class.addOption('USETWIST', 'Use Twist', false, nil, 'Use MQ2Twist instead of managing songs', 'checkbox')
class.addOption('USEDOTS', 'Use DoTs', false, nil, 'Toggle use of DoT songs if they are in the selected song list', 'checkbox')

-- All spells ID + Rank name
class.addSpell('aura', {'Aura of Pli Xin Liako', 'Aura of Margidor', 'Aura of Begalru', 'Aura of the Muse', 'Aura of Insight'}) -- spell dmg, overhaste, flurry, triple atk
class.addSpell('composite', {'Composite Psalm', 'Dissident Psalm', 'Dichotomic Psalm'}) -- DD+melee dmg bonus + small heal
class.addSpell('aria', {'Aria of Pli Xin Liako', 'Aria of Margidor', 'Aria of Begalru', }) -- spell dmg, overhaste, flurry, triple atk
class.addSpell('warmarch', {'War March of Centien Xi Va Xakra', 'War March of Radiwol', 'War March of Dekloaz'}) -- haste, atk, ds
class.addSpell('arcane', {'Arcane Harmony', 'Arcane Symphony', 'Arcane Ballad'}) -- spell dmg proc
class.addSpell('suffering', {'Shojralen\'s Song of Suffering', 'Omorden\'s Song of Suffering', 'Travenro\'s Song of Suffering', 'Song of the Storm'}) -- melee dmg proc
class.addSpell('spiteful', {'Von Deek\'s Spiteful Lyric', 'Omorden\'s Spiteful Lyric', 'Travenro\' Spiteful Lyric'}) -- AC
class.addSpell('pulse', {'Pulse of Nikolas', 'Pulse of Vhal`Sera', 'Pulse of Xigarn', 'Chorus of Life', 'Wind of Marr', 'Chorus of Marr', 'Chorus of Replenishment', 'Cantata of Soothing'}) -- heal focus + regen
class.addSpell('sonata', {'Xetheg\'s Spry Sonata', 'Kellek\'s Spry Sonata', 'Kluzen\'s Spry Sonata'}) -- spell shield, AC, dmg mitigation
class.addSpell('dirge', {'Dirge of the Restless', 'Dirge of Lost Horizons'}) -- spell+melee dmg mitigation
class.addSpell('firenukebuff', {'Constance\'s Aria', 'Sontalak\'s Aria', 'Quinard\'s Aria', 'Rizlona\'s Fire', 'Rizlona\'s Embers'}) -- inc fire DD
class.addSpell('firemagicdotbuff', {'Fyrthek Fior\'s Psalm of Potency', 'Velketor\'s Psalm of Potency', 'Akett\'s Psalm of Potency'}) -- inc fire+mag dot
class.addSpell('crescendo', {'Zelinstein\'s Lively Crescendo', 'Zburator\'s Lively Crescendo', 'Jembel\'s Lively Crescendo'}) -- small heal hp, mana, end
class.addSpell('insult', {'Yelinak\'s Insult', 'Sathir\'s Insult'}) -- synergy DD
class.addSpell('insult2', {'Sogran\'s Insult', 'Omorden\'s Insult', 'Travenro\'s Insult'}) -- synergy DD 2
class.addSpell('chantflame', {'Shak Dathor\'s Chant of Flame', 'Sontalak\'s Chant of Flame', 'Quinard\'s Chant of Flame', 'Tuyen\'s Chant of Fire', 'Tuyen\'s Chant of Flame'}, {opt='USEDOTS'})
class.addSpell('chantfrost', {'Sylra Fris\' Chant of Frost', 'Yelinak\'s Chant of Frost', 'Ekron\'s Chant of Frost', 'Tuyen\'s Chant of Ice', 'Tuyen\'s Chant of Frost'}, {opt='USEDOTS'})
class.addSpell('chantdisease', {'Coagulus\' Chant of Disease', 'Zlexak\'s Chant of Disease', 'Hoshkar\'s Chant of Disease', 'Tuyen\'s Chant of the Plague', 'Tuyen\'s Chant of Disease'}, {opt='USEDOTS'})
class.addSpell('chantpoison', {'Cruor\'s Chant of Poison', 'Malvus\'s Chant of Poison', 'Nexona\'s Chant of Poison', 'Tuyen\'s Chant of Venom', 'Tuyen\'s Chant of Poison'}, {opt='USEDOTS'})
class.addSpell('alliance', {'Coalition of Sticks and Stones', 'Covenant of Sticks and Stones', 'Alliance of Sticks and Stones'})
class.addSpell('mezst', {'Slumber of the Diabo', 'Slumber of Zburator', 'Slumber of Jembel'})
class.addSpell('mezae', {'Wave of Nocturn', 'Wave of Sleep', 'Wave of Somnolence'})

-- haste song doesn't stack with enc haste?
class.addSpell('overhaste', {'Ancient: Call of Power', 'Warsong of the Vah Shir', 'Battlecry of the Vah Shir'})
class.addSpell('bardhaste', {'Verse of Veeshan', 'Psalm of Veeshan', 'Composition of Ervaj'})
class.addSpell('emuhaste', {'War March of Muram', 'War March of the Mastruq', 'McVaxius\' Rousing Rondo', 'McVaxius\' Berserker Crescendo'})
class.addSpell('snare', {'Selo\'s Consonant Chain'}, {opt='USESNARE'})
class.addSpell('debuff', {'Harmony of Sound'})

local selos = common.getAA('Selo\'s Sonata')
if state.emu then
    class.addSpell('selos', {'Selo\'s Accelerating Chorus'})
end

-- entries in the dots table are pairs of {spell id, spell name} in priority order
local melee = {
    class.spells.composite, class.spells.crescendo, class.spells.aria,
    class.spells.spiteful, class.spells.suffering, class.spells.warmarch,
    class.spells.pulse, class.spells.dirge
}
-- synergy, mezst, mstae

local caster = {
    class.spells.composite, class.spells.crescendo, class.spells.aria,
    class.spells.arcane, class.spells.firenukebuff, class.spells.suffering,
    class.spells.warmarch, class.spells.firemagicdotbuff, class.spells.pulse,
    class.spells.dirge
}
-- synergy, mezst, mezae

local meleedot = {
    class.spells.composite, class.spells.crescendo, class.spells.chantflame,
    class.spells.aria, class.spells.warmarch, class.spells.chantdisease,
    class.spells.suffering, class.spells.pulse, class.spells.dirge,
    class.spells.chantfrost
}
-- synergy, mezst, mezae

local emuancient = {
    class.spells.selos, class.spells.overhaste, class.spells.pulse, class.spells.bardhaste, class.spells.spiteful, class.spells.chantflame
}

local emuaura65 = {
    class.spells.selos, class.spells.pulse, class.spells.spiteful, class.spells.bardhaste, class.spells.emuhaste
}

local emuaura55 = {
    class.spells.selos, class.spells.pulse, class.spells.overhaste, class.spells.bardhaste, class.spells.emuhaste
}
local emunoaura = {
    class.spells.selos, class.spells.pulse, class.spells.overhaste, class.spells.emuhaste, class.spells.firenukebuff
}

local songs = {}
if state.emu then
    songs.emuancient = emuancient
    songs.emuaura65 = emuaura65
    songs.emuaura55 = emuaura55
    songs.emunoaura = emunoaura
    --table.insert(class.DPSAbilities, common.getItem('Rapier of Somber Notes', {delay=1500}))
    --table.insert(class.selfBuffs, common.getItem('Songblade of the Eternal', {checkfor='Symphony of Battle'}))
    table.insert(class.selfBuffs, common.getAA('Sionachie\'s Crescendo'))

    table.insert(class.burnAbilities, common.getAA('A Tune Stuck In Your Head'))
else
    songs.melee = melee
    songs.caster = caster
    songs.meleedot = meleedot
    table.insert(class.groupBuffs, common.getItem('Songblade of the Eternal') or common.getItem('Rapier of Somber Notes'))
end

table.insert(class.auras, class.spells.aura)

table.insert(class.burnAbilities, common.getItem(mq.TLO.InvSlot('Chest').Item.Name()))
table.insert(class.burnAbilities, common.getItem('Rage of Rolfron'))
table.insert(class.burnAbilities, common.getAA('Quick Time'))
table.insert(class.burnAbilities, common.getAA('Funeral Dirge'))
table.insert(class.burnAbilities, common.getAA('Spire of the Minstrels'))
table.insert(class.burnAbilities, common.getAA('Bladed Song'))
table.insert(class.burnAbilities, common.getAA('Dance of Blades'))
table.insert(class.burnAbilities, common.getAA('Flurry of Notes'))
table.insert(class.burnAbilities, common.getAA('Frenzied Kicks'))
table.insert(class.burnAbilities, common.getBestDisc({'Thousand Blades'}))

table.insert(class.DPSAbilities, common.getAA('Cacophony', {opt='USECACOPHONY'}))
-- Delay after using swarm pet AAs while pets are spawning
table.insert(class.DPSAbilities, common.getAA('Lyrical Prankster', {opt='USESWARM', delay=1500}))
table.insert(class.DPSAbilities, common.getAA('Song of Stone', {opt='USESWARM', delay=1500}))
table.insert(class.DPSAbilities, common.getBestDisc({'Reflexive Rebuttal'}))
table.insert(class.DPSAbilities, common.getSkill('Intimidation', {opt='USEINTIMIDATE'}))
table.insert(class.DPSAbilities, common.getSkill('Kick'))
table.insert(class.DPSAbilities, common.getAA('Selo\'s Kick'))

-- Bellow handled separately as we want it to run its course and not be refreshed early
local bellow = common.getAA('Boastful Bellow')

table.insert(class.AEDPSAbilities, common.getAA('Vainglorious Shout', {threshold=4}))

table.insert(class.defensiveAbilities, common.getAA('Shield of Notes'))
table.insert(class.defensiveAbilities, common.getAA('Hymn of the Last Stand'))
table.insert(class.defensiveAbilities, common.getBestDisc({'Deftdance Discipline'}))

-- Aggro
class.drop_aggro = common.getAA('Fading Memories')

--table.insert(burnAAs, common.getAA('Glyph of Destruction (115+)'))
--table.insert(burnAAs, common.getAA('Intensity of the Resolute'))

-- Mana Recovery AAs
local rallyingsolo = common.getAA('Rallying Solo', {mana=true, endurance=true, threshold=20, combat=false, ooc=true})
table.insert(class.recoverAbilities, rallyingsolo)
local rallyingcall = common.getAA('Rallying Call')

-- aa mez
local dirge = common.getAA('Dirge of the Sleepwalker')
local sonic = common.getAA('Sonic Disturbance')
local fluxstaff = common.getItem('Staff of Viral Flux')

local song_timer = timer:new(3)
local selos_timer = timer:new(30)
local crescendo_timer = timer:new(53)
local boastful_timer = timer:new(30)
local synergy_timer = timer:new(18)
class.item_timer = timer:new(1)

class.reset_class_timers = function()
    boastful_timer:reset(0)
    synergy_timer:reset(0)
end

-- Casts alliance if we are fighting, alliance is enabled, the spell is ready, alliance isn't already on the mob, there is > 1 necro in group or raid, and we have at least a few dots on the mob.
local function try_alliance()
    local alliance = class.spells.alliance and class.spells.alliance.name
    if class.OPTS.USEALLIANCE.value and alliance then
        if mq.TLO.Spell(alliance).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        if mq.TLO.Me.Gem(alliance)() and mq.TLO.Me.GemTimer(alliance)() == 0  and not mq.TLO.Target.Buff(alliance)() and mq.TLO.Spell(alliance).StacksTarget() then
            class.spells.alliance:use()
            song_timer:reset()
            return true
        end
    end
    return false
end

local function cast_synergy()
    -- don't nuke if i'm not attacking
    local synergy = class.spells.insult and class.spells.insult.name
    if class.OPTS.USEINSULTS.value and synergy_timer:timer_expired() and synergy and mq.TLO.Me.Combat() then
        if not mq.TLO.Me.Song('Troubadour\'s Synergy')() and mq.TLO.Me.Gem(synergy)() and mq.TLO.Me.GemTimer(synergy)() == 0 then
            if mq.TLO.Spell(synergy).Mana() > mq.TLO.Me.CurrentMana() then
                return false
            end
            class.spells.insult:use()
            song_timer:reset()
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
    if state.subscription ~= 'GOLD' then actualSpellName = spellName:gsub(' Rk%..*', '') end
    local songDuration = 0
    if not mq.TLO.Me.Gem(spellName)() or mq.TLO.Me.GemTimer(spellName)() ~= 0  then
        return false
    end
    if not mq.TLO.Target() or mq.TLO.Target.ID() ~= state.assist_mob_id or mq.TLO.Target.Type() == 'Corpse' then return false end

    songDuration = mq.TLO.Target.MyBuffDuration(actualSpellName)()
    if not common.is_target_dotted_with(spellId, actualSpellName) then
        -- target does not have the dot, we are ready
        logger.debug(logger.log_flags.class.cast, 'song ready %s', spellName)
        return true
    else
        if not songDuration then
            logger.debug(logger.log_flags.class.cast, 'song ready %s', spellName)
            return true
        end
    end

    return false
end

local function is_song_ready(spellId, spellName)
    if not spellName then return false end
    local actualSpellName = spellName
    if state.subscription ~= 'GOLD' then actualSpellName = spellName:gsub(' Rk%..*', '') end
    if mq.TLO.Spell(spellName).Mana() > mq.TLO.Me.CurrentMana() or (mq.TLO.Spell(spellName).Mana() > 1000 and state.loop.PctMana < state.min_mana) then
        return false
    end
    if mq.TLO.Spell(spellName).EnduranceCost() > mq.TLO.Me.CurrentEndurance() or (mq.TLO.Spell(spellName).EnduranceCost() > 1000 and state.loop.PctEndurance < state.min_end) then
        return false
    end
    if mq.TLO.Spell(spellName).TargetType() == 'Single' then
        return is_dot_ready(spellId, spellName)
    end

    if not mq.TLO.Me.Gem(spellName)() or mq.TLO.Me.GemTimer(spellName)() > 0 then
        return false
    end
    if spellName == (class.spells.crescendo and class.spells.crescendo.name) and (mq.TLO.Me.Buff(actualSpellName)() or not crescendo_timer:timer_expired()) then
        -- buggy song that doesn't like to go on CD
        return false
    end

    local songDuration = mq.TLO.Me.Song(actualSpellName).Duration() or mq.TLO.Me.Buff(actualSpellName).Duration()
    if not songDuration then
        logger.debug(logger.log_flags.class.cast, 'song ready %s', spellName)
        return true
    else
        local cast_time = mq.TLO.Spell(spellName).MyCastTime()
        if songDuration < cast_time + 2500 then
            logger.debug(logger.log_flags.class.cast, 'song ready %s', spellName)
        end
        return songDuration < cast_time + 2500
    end
end

local function find_next_song()
    if try_alliance() then return nil end
    if cast_synergy() then return nil end
    if not mq.TLO.Target.Snared() and class.OPTS.USESNARE.value and ((mq.TLO.Target.PctHPs() or 100) < 30) then
        return class.spells.snare
    end
    for _,song in ipairs(songs[class.OPTS.SPELLSET.value]) do -- iterates over the dots array. ipairs(dots) returns 2 values, an index and its value in the array. we don't care about the index, we just want the dot
        local song_id = song.id
        local song_name = song.name
        if is_song_ready(song_id, song_name) and class.isAbilityEnabled(song.opt) then
            if song_name ~= (class.spells.composite and class.spells.composite.name) or mq.TLO.Target() then
                return song
            end
        end
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

class.cast = function()
    if class.OPTS.USETWIST.value then return false end
    if not state.loop.Invis and class.can_i_sing() and class.item_timer:timer_expired() then
        local spell = find_next_song() -- find the first available dot to cast that is missing from the target
        if spell then -- if a dot was found
            local did_cast = false
            if mq.TLO.Spell(spell.name).TargetType() == 'Single' and mq.TLO.Me.CombatState() == 'COMBAT' then
                did_cast = spell:use() -- then cast the dot
            else
                did_cast = spell:use() -- then cast the dot
            end
            if did_cast and spell.name ~= (class.spells.selos and class.spells.selos.name) then song_timer:reset() class.item_timer:reset() end
            if spell.name == (class.spells.crescendo and class.spells.crescendo.name) then crescendo_timer:reset() end
            return true
        end
    end
    return false
end

local fierceeye = common.getAA('Fierce Eye')
local epic = common.getItem('Blade of Vesagran') or common.getItem('Prismatic Dragon Blade')
local function use_epic()
    if not fierceeye or not epic then
        if fierceeye then fierceeye:use() end
        if epic then epic:use() end
        return
    end
    local fierceeye_rdy = mq.TLO.Me.AltAbilityReady(fierceeye.name)() or true
    if mq.TLO.FindItem('=Blade of Vesagran').Timer() == '0' and fierceeye_rdy and class.item_timer:timer_expired() then
        fierceeye:use()
        epic:use()
        class.item_timer:reset()
    end
end

class.mash_class = function()
    if class.OPTS.USEEPIC.value == 'always' or (class.OPTS.USEEPIC.value == 'shm' and mq.TLO.Me.Song('Prophet\'s Gift of the Ruchu')()) then
        use_epic()
    end

    if class.OPTS.USEBELLOW.value and bellow and boastful_timer:timer_expired() and bellow:use() then
        boastful_timer:reset()
    end
end

class.burn_class = function()
    if class.OPTS.USEEPIC.value == 'burn' then
        use_epic()
    end
end

class.hold = function()
    if rallyingsolo and (mq.TLO.Me.Song(rallyingsolo.name)() or mq.TLO.Me.Buff(rallyingsolo.name)()) then
        if state.mob_count >= 3 then
            return false
        elseif mq.TLO.Target() and mq.TLO.Target.Named() then
            return false
        else
            return true
        end
    else
        return false
    end
end

local composite_names = {['Composite Psalm']=true,['Dissident Psalm']=true,['Dichotomic Psalm']=true}
local check_spell_timer = timer:new(30)
class.check_spell_set = function()
    if not common.clear_to_buff() or mq.TLO.Me.Moving() or class.OPTS.BYOS.value then return end
    if not class.can_i_sing() then return end
    if state.spellset_loaded ~= class.OPTS.SPELLSET.value or check_spell_timer:timer_expired() then
        if class.OPTS.SPELLSET.value == 'melee' then
            common.swap_spell(class.spells.aria, 1)
            common.swap_spell(class.spells.arcane, 2)
            common.swap_spell(class.spells.spiteful, 3)
            common.swap_spell(class.spells.suffering, 4)
            common.swap_spell(class.spells.insult, 5)
            common.swap_spell(class.spells.warmarch, 6)
            common.swap_spell(class.spells.sonata, 7)
            common.swap_spell(class.spells.mezst, 8)
            common.swap_spell(class.spells.mezae, 9)
            common.swap_spell(class.spells.crescendo, 10)
            common.swap_spell(class.spells.pulse, 11)
            common.swap_spell(class.spells.composite, 12, composite_names)
            common.swap_spell(class.spells.dirge, 13)
            state.spellset_loaded = class.OPTS.SPELLSET.value
        elseif class.OPTS.SPELLSET.value == 'caster' then
            common.swap_spell(class.spells.aria, 1)
            common.swap_spell(class.spells.arcane, 2)
            common.swap_spell(class.spells.firenukebuff, 3)
            common.swap_spell(class.spells.suffering, 4)
            common.swap_spell(class.spells.insult, 5)
            common.swap_spell(class.spells.warmarch, 6)
            common.swap_spell(class.spells.firemagicdotbuff, 7)
            common.swap_spell(class.spells.mezst, 8)
            common.swap_spell(class.spells.mezae, 9)
            common.swap_spell(class.spells.crescendo, 10)
            common.swap_spell(class.spells.pulse, 11)
            common.swap_spell(class.spells.composite, 12, composite_names)
            common.swap_spell(class.spells.dirge, 13)
            state.spellset_loaded = class.OPTS.SPELLSET.value
        elseif class.OPTS.SPELLSET.value == 'meleedot' then
            common.swap_spell(class.spells.aria, 1)
            common.swap_spell(class.spells.chantflame, 2)
            common.swap_spell(class.spells.chantfrost, 3)
            common.swap_spell(class.spells.suffering, 4)
            common.swap_spell(class.spells.insult, 5)
            common.swap_spell(class.spells.warmarch, 6)
            common.swap_spell(class.spells.chantdisease, 7)
            common.swap_spell(class.spells.mezst, 8)
            common.swap_spell(class.spells.mezae, 9)
            common.swap_spell(class.spells.crescendo, 10)
            common.swap_spell(class.spells.pulse, 11)
            common.swap_spell(class.spells.composite, 12, composite_names)
            common.swap_spell(class.spells.dirge, 13)
            state.spellset_loaded = class.OPTS.SPELLSET.value
        else -- emu spellsets
            common.swap_spell(class.spells.emuaura, 1)
            common.swap_spell(class.spells.pulse, 2)
            common.swap_spell(class.spells.emuhaste, 3)
            common.swap_spell(class.spells.suffering, 4)
            common.swap_spell(class.spells.firenukebuff, 5)
            common.swap_spell(class.spells.bardhaste, 6)
            common.swap_spell(class.spells.overhaste, 7)
            common.swap_spell(class.spells.selos, 8)
            --common.swap_spell(class.spells.snare, 9)
            --common.swap_spell(class.spells.chantflame, 10)
        end
        check_spell_timer:reset()
    end
end
-- aura, chorus, war march, storm, rizlonas, verse, ancient,selos, chant flame, echoes, nivs

class.pull_func = function()
    if fluxstaff then
        fluxstaff:use()
    elseif sonic then
        sonic:use()
    end
end

class.can_i_sing = function()
    if class.OPTS.USETWIST.value then return true end
    if song_timer:timer_expired() or mq.TLO.Me.CastTimeLeft() > 4000 then
        if mq.TLO.Me.Casting() then mq.cmd('/stopsong') end
        if not class.spells.selos and selos and selos_timer:timer_expired() then
            selos:use()
            selos_timer:reset()
        end
        return true
    end
    return false
end

return class