--- @type Mq
local mq = require 'mq'
local baseclass = require('aqo.classes.base')
local mez = require('aqo.routines.mez')
local logger = require('aqo.utils.logger')
local timer = require('aqo.utils.timer')
local common = require('aqo.common')
local config = require('aqo.configuration')
local state = require('aqo.state')

-- what was this again?
mq.cmd('/squelch /stick mod 0')

local brd = baseclass

brd.class = 'brd'
brd.classOrder = {'assist', 'mez', 'assist', 'cast', 'mash', 'burn', 'aggro', 'recover', 'buff', 'rest'}

brd.SPELLSETS = {melee=1,caster=1,meleedot=1}
brd.EPIC_OPTS = {always=1,shm=1,burn=1,never=1}

brd.addOption('SPELLSET', 'Spell Set', 'melee', brd.SPELLSETS, nil, 'combobox')
brd.addOption('USEEPIC', 'Epic', 'always', brd.EPIC_OPTS, nil, 'combobox')
brd.addOption('USEALLIANCE', 'Use Alliance', true, nil, 'Use alliance spell', 'checkbox')
brd.addOption('MEZST', 'Mez ST', true, nil, 'Mez single target', 'checkbox')
brd.addOption('MEZAE', 'Mez AE', true, nil, 'Mez AOE', 'checkbox')
brd.addOption('MEZAECOUNT', 'Mez AE Count', 3, nil, 'Threshold to use AE Mez ability', 'checkbox')
brd.addOption('USEINSULTS', 'Use Insults', true, nil, 'Use insult songs', 'checkbox')
brd.addOption('USEBELLOW', 'Use Bellow', true, nil, 'Use Boastful Bellow AA', 'checkbox')
brd.addOption('USEFADE', 'Use Fade', false, nil, 'Fade when aggro', 'checkbox')
brd.addOption('BYOS', 'BYOS', false, nil, 'Bring your own spells', 'checkbox')
brd.addOption('RALLYGROUP', 'Rallying Group', false, nil, 'Use Rallying Group AA', 'checkbox')
brd.addOption('USESWARM', 'Use Swarm', true, nil, 'Use swarm pet AAs', 'checkbox')
brd.addOption('USESNARE', 'Use Snare', false, nil, 'Use snare song', 'checkbox')

-- All spells ID + Rank name
brd.addSpell('aura', {'Aura of Pli Xin Liako', 'Aura of Margidor', 'Aura of Begalru'}) -- spell dmg, overhaste, flurry, triple atk
brd.addSpell('composite', {'Composite Psalm', 'Dissident Psalm', 'Dichotomic Psalm'}) -- DD+melee dmg bonus + small heal
brd.addSpell('aria', {'Aria of Pli Xin Liako', 'Aria of Margidor', 'Aria of Begalru'}) -- spell dmg, overhaste, flurry, triple atk
brd.addSpell('warmarch', {'War March of Centien Xi Va Xakra', 'War March of Radiwol', 'War March of Dekloaz', 'Vilia\'s Verses of Celerity'}) -- haste, atk, ds
brd.addSpell('arcane', {'Arcane Harmony', 'Arcane Symphony', 'Arcane Ballad'}) -- spell dmg proc
brd.addSpell('suffering', {'Shojralen\'s Song of Suffering', 'Omorden\'s Song of Suffering', 'Travenro\'s Song of Suffering'}) -- melee dmg proc
brd.addSpell('spiteful', {'Von Deek\'s Spiteful Lyric', 'Omorden\'s Spiteful Lyric', 'Travenro\' Spiteful Lyric', 'Psalm of Purity'}) -- AC
brd.addSpell('pulse', {'Pulse of Nikolas', 'Pulse of Vhal`Sera', 'Pulse of Xigarn', 'Cantata of Soothing'}) -- heal focus + regen
brd.addSpell('sonata', {'Xetheg\'s Spry Sonata', 'Kellek\'s Spry Sonata', 'Kluzen\'s Spry Sonata'}) -- spell shield, AC, dmg mitigation
brd.addSpell('dirge', {'Dirge of the Restless', 'Dirge of Lost Horizons'}) -- spell+melee dmg mitigation
brd.addSpell('firenukebuff', {'Constance\'s Aria', 'Sontalak\'s Aria', 'Quinard\'s Aria'}) -- inc fire DD
brd.addSpell('firemagicdotbuff', {'Fyrthek Fior\'s Psalm of Potency', 'Velketor\'s Psalm of Potency', 'Akett\'s Psalm of Potency'}) -- inc fire+mag dot
brd.addSpell('crescendo', {'Zelinstein\'s Lively Crescendo', 'Zburator\'s Lively Crescendo', 'Jembel\'s Lively Crescendo'}) -- small heal hp, mana, end
brd.addSpell('insult', {'Yelinak\'s Insult', 'Sathir\'s Insult'}) -- synergy DD
brd.addSpell('insult2', {'Sogran\'s Insult', 'Omorden\'s Insult', 'Travenro\'s Insult'}) -- synergy DD 2
brd.addSpell('chantflame', {'Shak Dathor\'s Chant of Flame', 'Sontalak\'s Chant of Flame', 'Quinard\'s Chant of Flame'})
brd.addSpell('chantfrost', {'Sylra Fris\' Chant of Frost', 'Yelinak\'s Chant of Frost', 'Ekron\'s Chant of Frost'})
brd.addSpell('chantdisease', {'Coagulus\' Chant of Disease', 'Zlexak\'s Chant of Disease', 'Hoshkar\'s Chant of Disease'})
brd.addSpell('chantpoison', {'Cruor\'s Chant of Poison', 'Malvus\'s Chant of Poison', 'Nexona\'s Chant of Poison'})
brd.addSpell('alliance', {'Coalition of Sticks and Stones', 'Covenant of Sticks and Stones', 'Alliance of Sticks and Stones'})
brd.addSpell('mezst', {'Slumber of the Diabo', 'Slumber of Zburator', 'Slumber of Jembel'})
brd.addSpell('mezae', {'Wave of Nocturn', 'Wave of Sleep', 'Wave of Somnolence'})
brd.addSpell('snare', {'Selo\'s Consonant Chain'}, {opt='USESNARE'})

-- entries in the dots table are pairs of {spell id, spell name} in priority order
local melee = {
    brd.spells.composite, brd.spells.crescendo, brd.spells.aria,
    brd.spells.spiteful, brd.spells.suffering, brd.spells.warmarch,
    brd.spells.pulse, brd.spells.dirge
}
-- synergy, mezst, mstae

local caster = {
    brd.spells.composite, brd.spells.crescendo, brd.spells.aria,
    brd.spells.arcane, brd.spells.firenukebuff, brd.spells.suffering,
    brd.spells.warmarch, brd.spells.firemagicdotbuff, brd.spells.pulse,
    brd.spells.dirge
}
-- synergy, mezst, mezae

local meleedot = {
    brd.spells.composite, brd.spells.crescendo, brd.spells.chantflame,
    brd.spells.aria, brd.spells.warmarch, brd.spells.chantdisease,
    brd.spells.suffering, brd.spells.pulse, brd.spells.dirge,
    brd.spells.chantfrost
}
-- synergy, mezst, mezae

local songs = {
    melee=melee,
    caster=caster,
    meleedot=meleedot,
}

table.insert(brd.burnAbilities, {id=mq.TLO.InvSlot('Chest').Item.ID(),          type='item'})
table.insert(brd.burnAbilities, {id=mq.TLO.FindItem('Rage of Rolfron').ID(),    type='item'})

table.insert(brd.burnAbilities, common.get_aa('Quick Time'))
table.insert(brd.burnAbilities, common.get_aa('Funeral Dirge'))
table.insert(brd.burnAbilities, common.get_aa('Spire of the Minstrels'))
table.insert(brd.burnAbilities, common.get_aa('Bladed Song'))
table.insert(brd.burnAbilities, common.get_aa('Dance of Blades'))
table.insert(brd.burnAbilities, common.get_aa('Flurry of Notes'))
table.insert(brd.burnAbilities, common.get_aa('Frenzied Kicks'))

table.insert(brd.burnAbilities, common.get_disc('Thousand Blades'))

table.insert(brd.DPSAbilities, common.get_aa('Cacophony'))
-- Delay after using swarm pet AAs while pets are spawning
table.insert(brd.DPSAbilities, common.get_aa('Lyrical Prankster', {opt='USESWARM', delay=1500}))
table.insert(brd.DPSAbilities, common.get_aa('Song of Stone', {opt='USESWARM', delay=1500}))

table.insert(brd.DPSAbilities, common.get_disc('Reflexive Rebuttal'))

table.insert(brd.DPSAbilities, {name='Intimidation',    type='ability'})
table.insert(brd.DPSAbilities, {name='Kick',            type='ability'})

local bellow = common.get_aa('Boastful Bellow')

table.insert(brd.AEDPSAbilities, common.get_aa('Vainglorious Shout', {threshold=4}))

table.insert(baseclass.defensiveAbilities, common.get_aa('Shield of Notes'))
table.insert(baseclass.defensiveAbilities, common.get_aa('Hymn of the Last Stand'))

-- Aggro
brd.drop_aggro = common.get_aa('Fading Memories')

table.insert(brd.buffs, {name=brd.spells.aura.name, id=brd.spells.aura.id, type='spellaura'})
table.insert(brd.buffs, {id=mq.TLO.FindItem('Songblade of the Eternal').ID() or mq.TLO.FindItem('Rapier of Somber Notes').ID(), type='item'})

--table.insert(burnAAs, common.get_aa('Glyph of Destruction (115+)'))
--table.insert(burnAAs, common.get_aa('Intensity of the Resolute'))

-- deftdance discipline

local selos = common.get_aa('Selo\'s Sonata')
-- Mana Recovery AAs
local rallyingsolo = common.get_aa('Rallying Solo', {mana=true, endurance=true, threshold=20, combat=false, ooc=true})
table.insert(brd.recoverAbilities, rallyingsolo)
local rallyingcall = common.get_aa('Rallying Call')

-- aa mez
local dirge = common.get_aa('Dirge of the Sleepwalker')
local sonic = common.get_aa('Sonic Disturbance')
local fluxstaff = mq.TLO.FindItem('Staff of Viral Flux').ID()

local song_timer = timer:new(3)
local selos_timer = timer:new(30)
local crescendo_timer = timer:new(53)
local boastful_timer = timer:new(30)
local synergy_timer = timer:new(18)

brd.reset_class_timers = function()
    boastful_timer:reset(0)
    synergy_timer:reset(0)
end

-- Casts alliance if we are fighting, alliance is enabled, the spell is ready, alliance isn't already on the mob, there is > 1 necro in group or raid, and we have at least a few dots on the mob.
local function try_alliance()
    local alliance = brd.spells.alliance.name
    if brd.OPTS.USEALLIANCE.value and alliance then
        if mq.TLO.Spell(alliance).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        if mq.TLO.Me.Gem(alliance)() and mq.TLO.Me.GemTimer(alliance)() == 0  and not mq.TLO.Target.Buff(alliance)() and mq.TLO.Spell(alliance).StacksTarget() then
            common.cast(alliance, true)
            return true
        end
    end
    return false
end

local function cast_synergy()
    -- don't nuke if i'm not attacking
    local synergy = brd.spells.insult.name
    if brd.OPTS.USEINSULTS.value and synergy_timer:timer_expired() and synergy and mq.TLO.Me.Combat() then
        if not mq.TLO.Me.Song('Troubadour\'s Synergy')() and mq.TLO.Me.Gem(synergy)() and mq.TLO.Me.GemTimer(synergy)() == 0 then
            if mq.TLO.Spell(synergy).Mana() > mq.TLO.Me.CurrentMana() then
                return false
            end
            common.cast(synergy, true)
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
    if spellName == brd.spells.crescendo.name and (mq.TLO.Me.Buff(actualSpellName)() or not crescendo_timer:timer_expired()) then
        -- buggy song that doesn't like to go on CD
        return false
    end

    local songDuration = mq.TLO.Me.Song(actualSpellName).Duration()
    if not songDuration then
        logger.debug(logger.log_flags.class.cast, 'song ready %s', spellName)
        return true
    else
        local cast_time = mq.TLO.Spell(spellName).MyCastTime()
        if songDuration < cast_time + 3000 then
            logger.debug(logger.log_flags.class.cast, 'song ready %s', spellName)
        end
        return songDuration < cast_time + 3000
    end
end

local function find_next_song()
    if try_alliance() then return nil end
    if cast_synergy() then return nil end
    if not mq.TLO.Target.Snared() and brd.OPTS.USESNARE.value and ((mq.TLO.Target.PctHPs() or 100) < 30) then
        return brd.spells.snare
    end
    for _,song in ipairs(songs[brd.OPTS.SPELLSET.value]) do -- iterates over the dots array. ipairs(dots) returns 2 values, an index and its value in the array. we don't care about the index, we just want the dot
        local song_id = song.id
        local song_name = song.name
        if is_song_ready(song_id, song_name) then
            if song_name ~= brd.spells.composite.name or mq.TLO.Target() then
                return song
            end
        end
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

brd.cast = function()
    if not mq.TLO.Me.Invis() and brd.can_i_sing() then
        local spell = find_next_song() -- find the first available dot to cast that is missing from the target
        if spell then -- if a dot was found
            if mq.TLO.Spell(spell.name).TargetType() == 'Single' and mq.TLO.Me.CombatState() == 'COMBAT' then
                common.cast(spell.name, true) -- then cast the dot
            else
                common.cast(spell.name) -- then cast the dot
            end
            song_timer:reset()
            if spell.name == brd.spells.crescendo.name then crescendo_timer:reset() end
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

brd.mash_class = function()
    if brd.OPTS.USEEPIC.value == 'always' or (brd.OPTS.USEEPIC.value == 'shm' and mq.TLO.Me.Song('Prophet\'s Gift of the Ruchu')()) then
        use_epic()
    end

    if brd.OPTS.USEBELLOW.value and boastful_timer:timer_expired() and common.use_aa(bellow) then
        boastful_timer:reset()
    end
end

brd.burn_class = function()
    if brd.OPTS.USEEPIC.value == 'burn' then
        use_epic()
    end
end

brd.hold = function()
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
brd.check_spell_set = function()
    if not common.clear_to_buff() or mq.TLO.Me.Moving() or common.am_i_dead() or brd.OPTS.BYOS.value then return end
    if not brd.can_i_sing() then return end
    if state.spellset_loaded ~= brd.OPTS.SPELLSET or check_spell_timer:timer_expired() then
        if brd.OPTS.SPELLSET == 'melee' then
            common.swap_spell(brd.spells.aria, 1)
            common.swap_spell(brd.spells.arcane, 2)
            common.swap_spell(brd.spells.spiteful, 3)
            common.swap_spell(brd.spells.suffering, 4)
            common.swap_spell(brd.spells.insult, 5)
            common.swap_spell(brd.spells.warmarch, 6)
            common.swap_spell(brd.spells.sonata, 7)
            common.swap_spell(brd.spells.mezst, 8)
            common.swap_spell(brd.spells.mezae, 9)
            common.swap_spell(brd.spells.crescendo, 10)
            common.swap_spell(brd.spells.pulse, 11)
            common.swap_spell(brd.spells.composite, 12, composite_names)
            common.swap_spell(brd.spells.dirge, 13)
            state.spellset_loaded = brd.OPTS.SPELLSET
        elseif brd.OPTS.SPELLSET == 'caster' then
            common.swap_spell(brd.spells.aria, 1)
            common.swap_spell(brd.spells.arcane, 2)
            common.swap_spell(brd.spells.firenukebuff, 3)
            common.swap_spell(brd.spells.suffering, 4)
            common.swap_spell(brd.spells.insult, 5)
            common.swap_spell(brd.spells.warmarch, 6)
            common.swap_spell(brd.spells.firemagicdotbuff, 7)
            common.swap_spell(brd.spells.mezst, 8)
            common.swap_spell(brd.spells.mezae, 9)
            common.swap_spell(brd.spells.crescendo, 10)
            common.swap_spell(brd.spells.pulse, 11)
            common.swap_spell(brd.spells.composite, 12, composite_names)
            common.swap_spell(brd.spells.dirge, 13)
            state.spellset_loaded = brd.OPTS.SPELLSET
        elseif brd.OPTS.SPELLSET == 'meleedot' then
            common.swap_spell(brd.spells.aria, 1)
            common.swap_spell(brd.spells.chantflame, 2)
            common.swap_spell(brd.spells.chantfrost, 3)
            common.swap_spell(brd.spells.suffering, 4)
            common.swap_spell(brd.spells.insult, 5)
            common.swap_spell(brd.spells.warmarch, 6)
            common.swap_spell(brd.spells.chantdisease, 7)
            common.swap_spell(brd.spells.mezst, 8)
            common.swap_spell(brd.spells.mezae, 9)
            common.swap_spell(brd.spells.crescendo, 10)
            common.swap_spell(brd.spells.pulse, 11)
            common.swap_spell(brd.spells.composite, 12, composite_names)
            common.swap_spell(brd.spells.dirge, 13)
            state.spellset_loaded = brd.OPTS.SPELLSET
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

brd.can_i_sing = function()
    if song_timer:timer_expired() then
        if mq.TLO.Me.Casting() then mq.cmd('/stopsong') end
        return true
    end
    return false
end

brd.main_loop_old = function()
    -- keep cursor clear for spell swaps and such
    if selos_timer:timer_expired() then
        common.use_aa(selos)
        selos_timer:reset()
    end
end

return brd