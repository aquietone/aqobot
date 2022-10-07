--- @type Mq
local mq = require 'mq'
local baseclass = require(AQO..'.classes.base')
local logger = require(AQO..'.utils.logger')
local timer = require(AQO..'.utils.timer')
local common = require(AQO..'.common')
local state = require(AQO..'.state')

-- what was this again?
mq.cmd('/squelch /stick mod 0')

local brd = baseclass

brd.class = 'brd'
brd.classOrder = {'assist', 'mez', 'assist', 'cast', 'mash', 'burn', 'aggro', 'recover', 'buff', 'rest'}

brd.SPELLSETS = {melee=1,caster=1,meleedot=1,emuaura55=1,emuaura65=1,emunoaura=1}
brd.EPIC_OPTS = {always=1,shm=1,burn=1,never=1}

brd.addOption('SPELLSET', 'Spell Set', 'melee', brd.SPELLSETS, nil, 'combobox')
brd.addOption('USEEPIC', 'Epic', 'always', brd.EPIC_OPTS, nil, 'combobox')
brd.addOption('USEALLIANCE', 'Use Alliance', true, nil, 'Use alliance spell', 'checkbox')
brd.addOption('MEZST', 'Mez ST', true, nil, 'Mez single target', 'checkbox')
brd.addOption('MEZAE', 'Mez AE', true, nil, 'Mez AOE', 'checkbox')
brd.addOption('MEZAECOUNT', 'Mez AE Count', 3, nil, 'Threshold to use AE Mez ability', 'checkbox')
brd.addOption('USEINSULTS', 'Use Insults', true, nil, 'Use insult songs', 'checkbox')
brd.addOption('USEINTIMIDATE', 'Use Intimidate', false, nil, 'Use Intimidate (It may fear mobs without the appropriate AA\'s', 'checkbox')
brd.addOption('USEBELLOW', 'Use Bellow', true, nil, 'Use Boastful Bellow AA', 'checkbox')
brd.addOption('USEFADE', 'Use Fade', false, nil, 'Fade when aggro', 'checkbox')
brd.addOption('BYOS', 'BYOS', false, nil, 'Bring your own spells', 'checkbox')
brd.addOption('RALLYGROUP', 'Rallying Group', false, nil, 'Use Rallying Group AA', 'checkbox')
brd.addOption('USESWARM', 'Use Swarm', true, nil, 'Use swarm pet AAs', 'checkbox')
brd.addOption('USESNARE', 'Use Snare', false, nil, 'Use snare song', 'checkbox')
brd.addOption('USETWIST', 'Use Twist', false, nil, 'Use MQ2Twist instead of managing songs', 'checkbox')

-- All spells ID + Rank name
brd.addSpell('aura', {'Aura of Pli Xin Liako', 'Aura of Margidor', 'Aura of Begalru'}) -- spell dmg, overhaste, flurry, triple atk
brd.addSpell('composite', {'Composite Psalm', 'Dissident Psalm', 'Dichotomic Psalm'}) -- DD+melee dmg bonus + small heal
brd.addSpell('aria', {'Aria of Pli Xin Liako', 'Aria of Margidor', 'Aria of Begalru', }) -- spell dmg, overhaste, flurry, triple atk
brd.addSpell('warmarch', {'War March of Centien Xi Va Xakra', 'War March of Radiwol', 'War March of Dekloaz'}) -- haste, atk, ds
brd.addSpell('arcane', {'Arcane Harmony', 'Arcane Symphony', 'Arcane Ballad'}) -- spell dmg proc
brd.addSpell('suffering', {'Shojralen\'s Song of Suffering', 'Omorden\'s Song of Suffering', 'Travenro\'s Song of Suffering'}) -- melee dmg proc
brd.addSpell('spiteful', {'Von Deek\'s Spiteful Lyric', 'Omorden\'s Spiteful Lyric', 'Travenro\' Spiteful Lyric'}) -- AC
brd.addSpell('pulse', {'Pulse of Nikolas', 'Pulse of Vhal`Sera', 'Pulse of Xigarn'}) -- heal focus + regen
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

-- haste song doesn't stack with enc haste?
brd.addSpell('emuaura', {'Aura of the Muse', 'Aura of Insight'}, {aura=true})
brd.addSpell('overhaste', {'Warsong of the Vah Shir', 'Battlecry of the Vah Shir'})
brd.addSpell('bardhaste', {'Psalm of Veeshan', 'Composition of Ervaj'})
brd.addSpell('emuhaste', {'War March of the Mastruq', 'McVaxius\' Rousing Rondo', 'McVaxius\' Berserker Crescendo'})
brd.addSpell('emuregen', {'Chorus of Marr', 'Chorus of Replenishment', 'Cantata of Soothing'})
brd.addSpell('emunukebuff', {'Rizlona\'s Fire', 'Rizlona\'s Embers'})
brd.addSpell('emuproc', {'Song of the Storm'})
brd.addSpell('snare', {'Selo\'s Consonant Chain'}, {opt='USESNARE'})

local selos = common.getAA('Selo\'s Sonata')
if not selos then
    brd.addSpell('selos', {'Selo\'s Accelerating Chorus'})
end
table.insert(brd.buffs, brd.spells.emuaura)

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

local emuaura65 = {}
if brd.spells.selos then table.insert(emuaura65, brd.spells.selos) end
table.insert(emuaura65, brd.spells.emuregen)
table.insert(emuaura65, brd.spells.emuproc)
table.insert(emuaura65, brd.spells.bardhaste)
table.insert(emuaura65, brd.spells.emuhaste)

local emuaura55 = {
    brd.spells.selosb, brd.spells.emuregen, brd.spells.overhaste, brd.spells.bardhaste, brd.spells.emuhaste
}
local emunoaura = {
    brd.spells.selos, brd.spells.emuregen, brd.spells.overhaste, brd.spells.emuhaste, brd.spells.emunukebuff
}

local songs = {
    melee=melee,
    caster=caster,
    meleedot=meleedot,
    emuaura55=emuaura55,
    emuaura65=emuaura65,
    emunoaura=emunoaura,
}

table.insert(brd.burnAbilities, common.getItem(mq.TLO.InvSlot('Chest').Item.Name()))
table.insert(brd.burnAbilities, common.getItem('Rage of Rolfron'))

table.insert(brd.burnAbilities, common.getAA('Quick Time'))
table.insert(brd.burnAbilities, common.getAA('Funeral Dirge'))
table.insert(brd.burnAbilities, common.getAA('Spire of the Minstrels'))
table.insert(brd.burnAbilities, common.getAA('Bladed Song'))
table.insert(brd.burnAbilities, common.getAA('Dance of Blades'))
table.insert(brd.burnAbilities, common.getAA('Flurry of Notes'))
table.insert(brd.burnAbilities, common.getAA('Frenzied Kicks'))

table.insert(brd.burnAbilities, common.getBestDisc({'Thousand Blades'}))

table.insert(brd.DPSAbilities, common.getAA('Cacophony'))
-- Delay after using swarm pet AAs while pets are spawning
table.insert(brd.DPSAbilities, common.getAA('Lyrical Prankster', {opt='USESWARM', delay=1500}))
table.insert(brd.DPSAbilities, common.getAA('Song of Stone', {opt='USESWARM', delay=1500}))

table.insert(brd.DPSAbilities, common.getBestDisc({'Reflexive Rebuttal'}))

table.insert(brd.DPSAbilities, common.getSkill('Intimidation', {opt='USEINTIMIDATE'}))
table.insert(brd.DPSAbilities, common.getSkill('Kick'))

local bellow = common.getAA('Boastful Bellow')

table.insert(brd.AEDPSAbilities, common.getAA('Vainglorious Shout', {threshold=4}))

table.insert(baseclass.defensiveAbilities, common.getAA('Shield of Notes'))
table.insert(baseclass.defensiveAbilities, common.getAA('Hymn of the Last Stand'))

-- Aggro
brd.drop_aggro = common.getAA('Fading Memories')

table.insert(brd.buffs, brd.spells.aura)
table.insert(brd.buffs, common.getItem('Songblade of the Eternal') or common.getItem('Rapier of Somber Notes'))

--table.insert(burnAAs, common.getAA('Glyph of Destruction (115+)'))
--table.insert(burnAAs, common.getAA('Intensity of the Resolute'))

-- deftdance discipline

-- Mana Recovery AAs
local rallyingsolo = common.getAA('Rallying Solo', {mana=true, endurance=true, threshold=20, combat=false, ooc=true})
table.insert(brd.recoverAbilities, rallyingsolo)
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

brd.reset_class_timers = function()
    boastful_timer:reset(0)
    synergy_timer:reset(0)
end

-- Casts alliance if we are fighting, alliance is enabled, the spell is ready, alliance isn't already on the mob, there is > 1 necro in group or raid, and we have at least a few dots on the mob.
local function try_alliance()
    local alliance = brd.spells.alliance and brd.spells.alliance.name
    if brd.OPTS.USEALLIANCE.value and alliance then
        if mq.TLO.Spell(alliance).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        if mq.TLO.Me.Gem(alliance)() and mq.TLO.Me.GemTimer(alliance)() == 0  and not mq.TLO.Target.Buff(alliance)() and mq.TLO.Spell(alliance).StacksTarget() then
            brd.spells.alliance:use()
            song_timer:reset()
            return true
        end
    end
    return false
end

local function cast_synergy()
    -- don't nuke if i'm not attacking
    local synergy = brd.spells.insult and brd.spells.insult.name
    if brd.OPTS.USEINSULTS.value and synergy_timer:timer_expired() and synergy and mq.TLO.Me.Combat() then
        if not mq.TLO.Me.Song('Troubadour\'s Synergy')() and mq.TLO.Me.Gem(synergy)() and mq.TLO.Me.GemTimer(synergy)() == 0 then
            if mq.TLO.Spell(synergy).Mana() > mq.TLO.Me.CurrentMana() then
                return false
            end
            brd.spells.insult:use()
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
    if spellName == (brd.spells.crescendo and brd.spells.crescendo.name) and (mq.TLO.Me.Buff(actualSpellName)() or not crescendo_timer:timer_expired()) then
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
    if not mq.TLO.Target.Snared() and brd.OPTS.USESNARE.value and ((mq.TLO.Target.PctHPs() or 100) < 30) then
        return brd.spells.snare
    end
    for _,song in ipairs(songs[brd.OPTS.SPELLSET.value]) do -- iterates over the dots array. ipairs(dots) returns 2 values, an index and its value in the array. we don't care about the index, we just want the dot
        local song_id = song.id
        local song_name = song.name
        if is_song_ready(song_id, song_name) then
            if song_name ~= (brd.spells.composite and brd.spells.composite.name) or mq.TLO.Target() then
                return song
            end
        end
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

brd.cast = function()
    if brd.OPTS.USETWIST.value then return false end
    if not mq.TLO.Me.Invis() and brd.can_i_sing() then
        local spell = find_next_song() -- find the first available dot to cast that is missing from the target
        if spell then -- if a dot was found
            local did_cast = false
            if mq.TLO.Spell(spell.name).TargetType() == 'Single' and mq.TLO.Me.CombatState() == 'COMBAT' then
                did_cast = spell:use() -- then cast the dot
            else
                did_cast = spell:use() -- then cast the dot
            end
            if did_cast and spell.name ~= (brd.spells.selos and brd.spells.selos.name) then song_timer:reset() end
            if spell.name == (brd.spells.crescendo and brd.spells.crescendo.name) then crescendo_timer:reset() end
            return true
        end
    end
    return false
end

local fierceeye = common.getAA('Fierce Eye')
local epic = common.getItem('Blade of Vesagran')
local function use_epic()
    local fierceeye_rdy = fierceeye and mq.TLO.Me.AltAbilityReady(fierceeye.name)() or true
    if epic and mq.TLO.FindItem('=Blade of Vesagran').Timer() == '0' and fierceeye_rdy then
        if fierceeye then fierceeye:use() end
        epic:use()
    end
end

brd.mash_class = function()
    if brd.OPTS.USEEPIC.value == 'always' or (brd.OPTS.USEEPIC.value == 'shm' and mq.TLO.Me.Song('Prophet\'s Gift of the Ruchu')()) then
        use_epic()
    end

    if brd.OPTS.USEBELLOW.value and bellow and boastful_timer:timer_expired() and bellow:use() then
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
    if state.spellset_loaded ~= brd.OPTS.SPELLSET.value or check_spell_timer:timer_expired() then
        if brd.OPTS.SPELLSET.value == 'melee' then
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
            state.spellset_loaded = brd.OPTS.SPELLSET.value
        elseif brd.OPTS.SPELLSET.value == 'caster' then
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
            state.spellset_loaded = brd.OPTS.SPELLSET.value
        elseif brd.OPTS.SPELLSET.value == 'meleedot' then
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
            state.spellset_loaded = brd.OPTS.SPELLSET.value
        elseif brd.OPTS.SPELLSET.value == 'emuaura' or brd.OPTS.SPELLSET.value == 'emunoaura' then
            common.swap_spell(brd.spells.emuaura, 1)
            common.swap_spell(brd.spells.emuregen, 2)
            common.swap_spell(brd.spells.emuhaste, 3)
            common.swap_spell(brd.spells.emuproc, 4)
            common.swap_spell(brd.spells.emunukebuff, 5)
            common.swap_spell(brd.spells.bardhaste, 6)
            common.swap_spell(brd.spells.overhaste, 7)
            common.swap_spell(brd.spells.selos, 8)
            common.swap_spell(brd.spells.snare, 9)
        end
        check_spell_timer:reset()
    end
end

brd.pull_func = function()
    if fluxstaff then
        fluxstaff:use()
    elseif sonic then
        sonic:use()
    end
end

brd.can_i_sing = function()
    if brd.OPTS.USETWIST.value then return true end
    if song_timer:timer_expired() then
        if mq.TLO.Me.Casting() then mq.cmd('/stopsong') end
            -- keep cursor clear for spell swaps and such
        if selos and selos_timer:timer_expired() then
            selos:use()
            selos_timer:reset()
        end
        return true
    end
    return false
end

brd.main_loop_old = function()
    -- keep cursor clear for spell swaps and such
    if selos_timer:timer_expired() then
        selos:use()
        selos_timer:reset()
    end
end

return brd