--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local movement = require('routines.movement')
local logger = require('utils.logger')
local timer = require('utils.timer')
local common = require('common')
local state = require('state')

function class.init(_aqo)
    class.classOrder = {'assist', 'mez', 'assist', 'aggro', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest'}
    class.EPIC_OPTS = {always=1,shm=1,burn=1,never=1}
    if state.emu then
        class.spellRotations = {emuancient={},emuaura65={},emuaura55={},emunoaura={}}
        class.DEFAULT_SPELLSET='emuancient'
    else
        class.spellRotations = {melee={},caster={},meleedot={}}
        class.DEFAULT_SPELLSET='melee'
    end
    class.initBase(_aqo, 'brd')

    -- what was this again?
    mq.cmd('/squelch /stick mod 0')

    class.addOption('USEEPIC', 'Epic', 'always', class.EPIC_OPTS, nil, 'combobox')
    class.addOption('MEZST', 'Mez ST', true, nil, 'Mez single target', 'checkbox')
    class.addOption('MEZAE', 'Mez AE', true, nil, 'Mez AOE', 'checkbox')
    class.addOption('MEZAECOUNT', 'Mez AE Count', 3, nil, 'Threshold to use AE Mez ability', 'inputint')
    class.addOption('USEINSULTS', 'Use Insults', true, nil, 'Use insult songs', 'checkbox')
    class.addOption('USEINTIMIDATE', 'Use Intimidate', false, nil, 'Use Intimidate (It may fear mobs without the appropriate AA\'s)', 'checkbox')
    class.addOption('USEBELLOW', 'Use Bellow', true, nil, 'Use Boastful Bellow AA', 'checkbox')
    class.addOption('USECACOPHONY', 'Use Cacophony', true, nil, 'Use Cacophony AA', 'checkbox')
    class.addOption('USEFADE', 'Use Fade', false, nil, 'Fade when aggro', 'checkbox')
    class.addOption('RALLYGROUP', 'Rallying Group', false, nil, 'Use Rallying Group AA', 'checkbox')
    class.addOption('USESWARM', 'Use Swarm', true, nil, 'Use swarm pet AAs', 'checkbox')
    class.addOption('USESNARE', 'Use Snare', false, nil, 'Use snare song', 'checkbox')
    class.addOption('USETWIST', 'Use Twist', false, nil, 'Use MQ2Twist instead of managing songs', 'checkbox')
    class.addOption('USEFIREDOTS', 'Use Fire DoT', false, nil, 'Toggle use of Fire DoT songs if they are in the selected song list', 'checkbox')
    class.addOption('USEFROSTDOTS', 'Use Frost DoT', false, nil, 'Toggle use of Frost DoT songs if they are in the selected song list', 'checkbox')
    class.addOption('USEPOISONDOTS', 'Use Poison DoT', false, nil, 'Toggle use of Poison DoT songs if they are in the selected song list', 'checkbox')
    class.addOption('USEDISEASEDOTS', 'Use Disease DoT', false, nil, 'Toggle use of Disease DoT songs if they are in the selected song list', 'checkbox')
    class.addOption('USEREGENSONG', 'Use Regen Song', false, nil, 'Toggle use of hp/mana regen song line', 'checkbox')
    class.loadSettings()

    -- All spells ID + Rank name
    class.addSpell('aura', {'Aura of Pli Xin Liako', 'Aura of Margidor', 'Aura of Begalru', 'Aura of the Muse', 'Aura of Insight'}) -- spell dmg, overhaste, flurry, triple atk
    class.addSpell('composite', {'Composite Psalm', 'Dissident Psalm', 'Dichotomic Psalm'}) -- DD+melee dmg bonus + small heal
    class.addSpell('aria', {'Aria of Pli Xin Liako', 'Aria of Margidor', 'Aria of Begalru', }) -- spell dmg, overhaste, flurry, triple atk
    class.addSpell('warmarch', {'War March of Centien Xi Va Xakra', 'War March of Radiwol', 'War March of Dekloaz'}) -- haste, atk, ds
    class.addSpell('arcane', {'Arcane Harmony', 'Arcane Symphony', 'Arcane Ballad', 'Arcane Aria'}) -- spell dmg proc
    class.addSpell('suffering', {'Shojralen\'s Song of Suffering', 'Omorden\'s Song of Suffering', 'Travenro\'s Song of Suffering', 'Storm Blade', 'Song of the Storm'}) -- melee dmg proc
    class.addSpell('spiteful', {'Von Deek\'s Spiteful Lyric', 'Omorden\'s Spiteful Lyric', 'Travenro\' Spiteful Lyric'}) -- AC
    class.addSpell('pulse', {'Pulse of Nikolas', 'Pulse of Vhal`Sera', 'Pulse of Xigarn', 'Cantata of Life', 'Chorus of Life', 'Wind of Marr', 'Chorus of Marr', 'Chorus of Replenishment', 'Cantata of Soothing'}, {opt='USEREGENSONG'}) -- heal focus + regen
    class.addSpell('sonata', {'Xetheg\'s Spry Sonata', 'Kellek\'s Spry Sonata', 'Kluzen\'s Spry Sonata'}) -- spell shield, AC, dmg mitigation
    class.addSpell('dirge', {'Dirge of the Restless', 'Dirge of Lost Horizons'}) -- spell+melee dmg mitigation
    class.addSpell('firenukebuff', {'Constance\'s Aria', 'Sontalak\'s Aria', 'Quinard\'s Aria', 'Rizlona\'s Fire', 'Rizlona\'s Embers'}) -- inc fire DD
    class.addSpell('firemagicdotbuff', {'Fyrthek Fior\'s Psalm of Potency', 'Velketor\'s Psalm of Potency', 'Akett\'s Psalm of Potency'}) -- inc fire+mag dot
    class.addSpell('crescendo', {'Zelinstein\'s Lively Crescendo', 'Zburator\'s Lively Crescendo', 'Jembel\'s Lively Crescendo'}) -- small heal hp, mana, end
    class.addSpell('insult', {'Yelinak\'s Insult', 'Sathir\'s Insult'}) -- synergy DD
    class.addSpell('insult2', {'Sogran\'s Insult', 'Omorden\'s Insult', 'Travenro\'s Insult'}) -- synergy DD 2
    class.addSpell('chantflame', {'Shak Dathor\'s Chant of Flame', 'Sontalak\'s Chant of Flame', 'Quinard\'s Chant of Flame', 'Vulka\'s Chant of Flame', 'Tuyen\'s Chant of Fire', 'Tuyen\'s Chant of Flame'}, {opt='USEFIREDOTS'})
    class.addSpell('chantfrost', {'Sylra Fris\' Chant of Frost', 'Yelinak\'s Chant of Frost', 'Ekron\'s Chant of Frost', 'Vulka\'s Chant of Frost', 'Tuyen\'s Chant of Ice', 'Tuyen\'s Chant of Frost'}, {opt='USEFROSTDOTS'})
    class.addSpell('chantdisease', {'Coagulus\' Chant of Disease', 'Zlexak\'s Chant of Disease', 'Hoshkar\'s Chant of Disease', 'Vulka\'s Chant of Disease', 'Tuyen\'s Chant of the Plague', 'Tuyen\'s Chant of Disease'}, {opt='USEDISEASEDOTS'})
    class.addSpell('chantpoison', {'Cruor\'s Chant of Poison', 'Malvus\'s Chant of Poison', 'Nexona\'s Chant of Poison', 'Vulka\'s Chant of Poison', 'Tuyen\'s Chant of Venom', 'Tuyen\'s Chant of Poison'}, {opt='USEPOISONDOTS'})
    class.addSpell('alliance', {'Coalition of Sticks and Stones', 'Covenant of Sticks and Stones', 'Alliance of Sticks and Stones'})
    class.addSpell('mezst', {'Slumber of the Diabo', 'Slumber of Zburator', 'Slumber of Jembel'})
    class.addSpell('mezae', {'Wave of Nocturn', 'Wave of Sleep', 'Wave of Somnolence'})

    -- haste song doesn't stack with enc haste?
    class.addSpell('overhaste', {'Ancient: Call of Power', 'Warsong of the Vah Shir', 'Battlecry of the Vah Shir'})
    class.addSpell('bardhaste', {'Verse of Veeshan', 'Psalm of Veeshan', 'Composition of Ervaj'})
    class.addSpell('emuhaste', {'War March of Muram', 'War March of the Mastruq', 'McVaxius\' Rousing Rondo', 'McVaxius\' Berserker Crescendo'})
    class.addSpell('snare', {'Selo\'s Consonant Chain'}, {opt='USESNARE'})
    class.addSpell('debuff', {'Harmony of Sound'})

    if state.emu then
        if class.spells.chantflame then class.spells.chantflame.checkfor = 'Chant of Flame' end
        if class.spells.chantfrost then class.spells.chantfrost.checkfor = 'Chant of Frost' end
        if class.spells.chantdisease then class.spells.chantdisease.checkfor = 'Chant of Plague' end
        if class.spells.chantpoison then class.spells.chantpoison.checkfor = 'Chant of Venom' end
        class.addSpell('selos', {'Selo\'s Accelerating Chorus'})
        table.insert(class.spellRotations.emuancient, class.spells.selos)
        table.insert(class.spellRotations.emuancient, class.spells.chantflame)
        table.insert(class.spellRotations.emuancient, class.spells.chantfrost)
        table.insert(class.spellRotations.emuancient, class.spells.chantdisease)
        table.insert(class.spellRotations.emuancient, class.spells.chantpoison)
        table.insert(class.spellRotations.emuancient, class.spells.overhaste)
        table.insert(class.spellRotations.emuancient, class.spells.suffering)
        table.insert(class.spellRotations.emuancient, class.spells.pulse)
        table.insert(class.spellRotations.emuancient, class.spells.bardhaste)
        --table.insert(class.spellRotations.emuancient, class.spells.arcane)

        table.insert(class.spellRotations.emuaura65, class.spells.selos)
        table.insert(class.spellRotations.emuaura65, class.spells.suffering)
        table.insert(class.spellRotations.emuaura65, class.spells.bardhaste)
        table.insert(class.spellRotations.emuaura65, class.spells.emuhaste)

        table.insert(class.spellRotations.emuaura55, class.spells.selos)
        table.insert(class.spellRotations.emuaura55, class.spells.pulse)
        table.insert(class.spellRotations.emuaura55, class.spells.overhaste)
        table.insert(class.spellRotations.emuaura55, class.spells.bardhaste)
        table.insert(class.spellRotations.emuaura55, class.spells.emuhaste)

        table.insert(class.spellRotations.emunoaura, class.spells.selos)
        table.insert(class.spellRotations.emunoaura, class.spells.pulse)
        table.insert(class.spellRotations.emunoaura, class.spells.overhaste)
        table.insert(class.spellRotations.emunoaura, class.spells.emuhaste)
        table.insert(class.spellRotations.emunoaura, class.spells.firenukebuff)

        --table.insert(class.DPSAbilities, common.getItem('Rapier of Somber Notes', {delay=1500}))
        --table.insert(class.selfBuffs, common.getItem('Songblade of the Eternal', {checkfor='Symphony of Battle'}))
        table.insert(class.selfBuffs, common.getAA('Sionachie\'s Crescendo'))

        table.insert(class.burnAbilities, common.getAA('A Tune Stuck In Your Head'))
        table.insert(class.burnAbilities, common.getBestDisc({'Puretone Discipline'}))
    else
        -- entries in the dots table are pairs of {spell id, spell name} in priority order
        class.spellRotations.melee = {
            class.spells.composite, class.spells.crescendo, class.spells.aria,
            class.spells.spiteful, class.spells.suffering, class.spells.warmarch,
            class.spells.pulse, class.spells.dirge
        }
        -- synergy, mezst, mstae

        class.spellRotations.caster = {
            class.spells.composite, class.spells.crescendo, class.spells.aria,
            class.spells.arcane, class.spells.firenukebuff, class.spells.suffering,
            class.spells.warmarch, class.spells.firemagicdotbuff, class.spells.pulse,
            class.spells.dirge
        }
        -- synergy, mezst, mezae

        class.spellRotations.meleedot = {
            class.spells.composite, class.spells.crescendo, class.spells.chantflame,
            class.spells.aria, class.spells.warmarch, class.spells.chantdisease,
            class.spells.suffering, class.spells.pulse, class.spells.dirge,
            class.spells.chantfrost
        }
        -- synergy, mezst, mezae

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

    table.insert(class.AEDPSAbilities, common.getAA('Vainglorious Shout', {threshold=4}))

    table.insert(class.defensiveAbilities, common.getAA('Shield of Notes'))
    table.insert(class.defensiveAbilities, common.getAA('Hymn of the Last Stand'))
    table.insert(class.defensiveAbilities, common.getBestDisc({'Deftdance Discipline'}))

    -- Aggro
    local preFade = function() mq.cmd('/attack off') end
    local postFade = function()
        mq.delay(1000)
        mq.cmd('/multiline ; /makemevis ; /attack on')
    end
    table.insert(class.fadeAbilities, common.getAA('Fading Memories', {opt='USEFADE', precase=preFade, postcast=postFade}))

    --table.insert(burnAAs, common.getAA('Glyph of Destruction (115+)'))
    --table.insert(burnAAs, common.getAA('Intensity of the Resolute'))

    -- Mana Recovery AAs
    class.rallyingsolo = common.getAA('Rallying Solo', {mana=true, endurance=true, threshold=20, combat=false, ooc=true})
    table.insert(class.recoverAbilities, class.rallyingsolo)
    class.rallyingcall = common.getAA('Rallying Call')

    -- Bellow handled separately as we want it to run its course and not be refreshed early
    class.bellow = common.getAA('Boastful Bellow')

    -- aa mez
    class.dirge = common.getAA('Dirge of the Sleepwalker')
    class.sonic = common.getAA('Sonic Disturbance')
    class.fluxstaff = common.getItem('Staff of Viral Flux')

    class.selos = common.getAA('Selo\'s Sonata')
end

local selosTimer = timer:new(30)
local crescendoTimer = timer:new(53)
local bellowTimer = timer:new(30)
local synergyTimer = timer:new(18)

class.resetClassTimers = function()
    bellowTimer:reset(0)
    synergyTimer:reset(0)
end

-- Casts alliance if we are fighting, alliance is enabled, the spell is ready, alliance isn't already on the mob, there is > 1 necro in group or raid, and we have at least a few dots on the mob.
local function tryAlliance()
    local alliance = class.spells.alliance and class.spells.alliance.name
    if class.isEnabled('USEALLIANCE') and alliance then
        if mq.TLO.Spell(alliance).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        if mq.TLO.Me.Gem(alliance)() and mq.TLO.Me.GemTimer(alliance)() == 0  and not mq.TLO.Target.Buff(alliance)() and mq.TLO.Spell(alliance).StacksTarget() then
            class.spells.alliance:use()
            return true
        end
    end
    return false
end

local function castSynergy()
    -- don't nuke if i'm not attacking
    local synergy = class.spells.insult and class.spells.insult.name
    if class.OPTS.USEINSULTS.value and synergyTimer:timerExpired() and synergy and mq.TLO.Me.Combat() then
        if not mq.TLO.Me.Song('Troubadour\'s Synergy')() and mq.TLO.Me.Gem(synergy)() and mq.TLO.Me.GemTimer(synergy)() == 0 then
            if mq.TLO.Spell(synergy).Mana() > mq.TLO.Me.CurrentMana() then
                return false
            end
            class.spells.insult:use()
            synergyTimer:reset()
            return true
        end
    end
    return false
end

local function isDotReady(spellId, spellName)
    -- don't dot if i'm not attacking
    if not spellName or not mq.TLO.Me.Combat() then return false end
    local actualSpellName = spellName
    if state.subscription ~= 'GOLD' then actualSpellName = spellName:gsub(' Rk%..*', '') end
    local songDuration = 0
    if not mq.TLO.Me.Gem(spellName)() or mq.TLO.Me.GemTimer(spellName)() ~= 0  then
        return false
    end
    if not mq.TLO.Target() or mq.TLO.Target.ID() ~= state.assistMobID or mq.TLO.Target.Type() == 'Corpse' then return false end

    songDuration = mq.TLO.Target.MyBuffDuration(actualSpellName)()
    if not common.isTargetDottedWith(spellId, actualSpellName) then
        -- target does not have the dot, we are ready
        logger.debug(logger.flags.class.cast, 'song ready %s', spellName)
        return true
    else
        if not songDuration then
            logger.debug(logger.flags.class.cast, 'song ready %s', spellName)
            return true
        end
    end

    return false
end

local function isSongReady(spellId, spellName)
    if not spellName then return false end
    local actualSpellName = spellName
    if state.subscription ~= 'GOLD' then actualSpellName = spellName:gsub(' Rk%..*', '') end
    if mq.TLO.Spell(spellName).Mana() > mq.TLO.Me.CurrentMana() or (mq.TLO.Spell(spellName).Mana() > 1000 and state.loop.PctMana < state.minMana) then
        return false
    end
    if mq.TLO.Spell(spellName).EnduranceCost() > mq.TLO.Me.CurrentEndurance() or (mq.TLO.Spell(spellName).EnduranceCost() > 1000 and state.loop.PctEndurance < state.minEndurance) then
        return false
    end
    if mq.TLO.Spell(spellName).TargetType() == 'Single' then
        return isDotReady(spellId, spellName)
    end

    if not mq.TLO.Me.Gem(spellName)() or mq.TLO.Me.GemTimer(spellName)() > 0 then
        return false
    end
    if spellName == (class.spells.crescendo and class.spells.crescendo.name) and (mq.TLO.Me.Buff(actualSpellName)() or not crescendoTimer:timerExpired()) then
        -- buggy song that doesn't like to go on CD
        return false
    end

    local songDuration = mq.TLO.Me.Song(actualSpellName).Duration() or mq.TLO.Me.Buff(actualSpellName).Duration()
    if not songDuration then
        logger.debug(logger.flags.class.cast, 'song ready %s', spellName)
        return true
    else
        local cast_time = mq.TLO.Spell(spellName).MyCastTime()
        if songDuration < cast_time +500 then
            logger.debug(logger.flags.class.cast, 'song ready %s', spellName)
        end
        return songDuration < cast_time + 500
    end
end

local function findNextSong()
    if tryAlliance() then return nil end
    if castSynergy() then return nil end
    if not mq.TLO.Target.Snared() and class.OPTS.USESNARE.value and ((mq.TLO.Target.PctHPs() or 100) < 30) then
        return class.spells.snare
    end
    for _,song in ipairs(class.spellRotations[class.OPTS.SPELLSET.value]) do -- iterates over the dots array. ipairs(dots) returns 2 values, an index and its value in the array. we don't care about the index, we just want the dot
        local song_id = song.id
        local song_name = song.name
        if isSongReady(song_id, song_name) and class.isAbilityEnabled(song.opt) and not mq.TLO.Target.Buff(song.checkfor)() then
            if song_name ~= (class.spells.composite and class.spells.composite.name) or mq.TLO.Target() then
                return song
            end
        end
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

function class.cast()
    if class.OPTS.USETWIST.value then return false end
    if not state.loop.Invis and class.doneSinging() then
        if mq.TLO.Target.Type() == 'NPC' and mq.TLO.Me.CombatState() == 'COMBAT' and (class.OPTS.USEEPIC.value == 'always' or state.burnActive or (class.OPTS.USEEPIC.value == 'shm' and mq.TLO.Me.Song('Prophet\'s Gift of the Ruchu')())) then
            if class.useEpic() then mq.delay(250) return true end
        end
        for _,clicky in ipairs(class.castClickies) do
            if clicky.targettype == 'Single' and mq.TLO.Target.Type() == 'NPC' then
                -- if single target clicky then make sure in combat
                if (clicky.duration == 0 or not mq.TLO.Target.Buff(clicky.checkfor)()) and mq.TLO.Me.CombatState() == 'COMBAT' then
                    if clicky:use() then
                        mq.delay(250)
                        return true
                    end
                end
            elseif clicky.duration == 0 or (not mq.TLO.Me.Buff(clicky.checkfor)() and not mq.TLO.Me.Song(clicky.checkfor)()) then
                -- otherwise just use the clicky if its instant or we don't already have the buff/song
                if clicky:use() then
                    mq.delay(250)
                    return true
                end
            end
        end
        local spell = findNextSong() -- find the first available dot to cast that is missing from the target
        if spell then -- if a song was found
            local didCast = false
            if spell.targettype == 'Single' and mq.TLO.Target.Type() == 'NPC' then
                if mq.TLO.Me.CombatState() == 'COMBAT' then didCast = spell:use() end
            else
                didCast = spell:use()
            end
            if not mq.TLO.Me.Casting() then
                -- not casting, so either we just played selos or missed a note, take some time for unknown reasons
                mq.delay(500)
            end
            if spell.name == (class.spells.crescendo and class.spells.crescendo.name) then crescendoTimer:reset() end
            return didCast
        end
    end
    return false
end

local fierceeye = common.getAA('Fierce Eye')
local epic = common.getItem('Blade of Vesagran') or common.getItem('Prismatic Dragon Blade')
function class.useEpic()
    if not fierceeye or not epic then
        if fierceeye then return fierceeye:use() end
        if epic then return epic:use() end
        return
    end
    local fierceeye_rdy = mq.TLO.Me.AltAbilityReady(fierceeye.name)()
    if epic:isReady() and fierceeye_rdy then
        mq.cmd('/stopsong')
        mq.delay(100)
        fierceeye:use()
        mq.delay(50)
        epic:use()
        return true
    end
end

function class.mashClass()
    if class.OPTS.USEBELLOW.value and class.bellow and bellowTimer:timerExpired() and class.bellow:use() then
        bellowTimer:reset()
    end
end

--[[function class.burnClass()
    if class.OPTS.USEEPIC.value == 'burn' then
        useEpic()
    end
end]]

function class.hold()
    if class.rallyingsolo and (mq.TLO.Me.Song(class.rallyingsolo.name)() or mq.TLO.Me.Buff(class.rallyingsolo.name)()) then
        if state.mobCount >= 3 then
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

function class.invis()
    mq.cmd('/stopcast')
    mq.delay(1)
    mq.cmd('/cast "selo\'s song of travel"')
    mq.delay(3500, function() return mq.TLO.Me.Invis() end)
    state.loop.Invis = true
end

local composite_names = {['Composite Psalm']=true,['Dissident Psalm']=true,['Dichotomic Psalm']=true}
local checkSpellTimer = timer:new(30)
function class.checkSpellSet()
    if not common.clearToBuff() or mq.TLO.Me.Moving() or class.OPTS.BYOS.value then return end
    if not class.doneSinging() then return end
    if state.spellSetLoaded ~= class.OPTS.SPELLSET.value or checkSpellTimer:timerExpired() then
        if class.OPTS.SPELLSET.value == 'melee' then
            common.swapSpell(class.spells.aria, 1)
            common.swapSpell(class.spells.arcane, 2)
            common.swapSpell(class.spells.spiteful, 3)
            common.swapSpell(class.spells.suffering, 4)
            common.swapSpell(class.spells.insult, 5)
            common.swapSpell(class.spells.warmarch, 6)
            common.swapSpell(class.spells.sonata, 7)
            common.swapSpell(class.spells.mezst, 8)
            common.swapSpell(class.spells.mezae, 9)
            common.swapSpell(class.spells.crescendo, 10)
            common.swapSpell(class.spells.pulse, 11)
            common.swapSpell(class.spells.composite, 12, composite_names)
            common.swapSpell(class.spells.dirge, 13)
            state.spellSetLoaded = class.OPTS.SPELLSET.value
        elseif class.OPTS.SPELLSET.value == 'caster' then
            common.swapSpell(class.spells.aria, 1)
            common.swapSpell(class.spells.arcane, 2)
            common.swapSpell(class.spells.firenukebuff, 3)
            common.swapSpell(class.spells.suffering, 4)
            common.swapSpell(class.spells.insult, 5)
            common.swapSpell(class.spells.warmarch, 6)
            common.swapSpell(class.spells.firemagicdotbuff, 7)
            common.swapSpell(class.spells.mezst, 8)
            common.swapSpell(class.spells.mezae, 9)
            common.swapSpell(class.spells.crescendo, 10)
            common.swapSpell(class.spells.pulse, 11)
            common.swapSpell(class.spells.composite, 12, composite_names)
            common.swapSpell(class.spells.dirge, 13)
            state.spellSetLoaded = class.OPTS.SPELLSET.value
        elseif class.OPTS.SPELLSET.value == 'meleedot' then
            common.swapSpell(class.spells.aria, 1)
            common.swapSpell(class.spells.chantflame, 2)
            common.swapSpell(class.spells.chantfrost, 3)
            common.swapSpell(class.spells.suffering, 4)
            common.swapSpell(class.spells.insult, 5)
            common.swapSpell(class.spells.warmarch, 6)
            common.swapSpell(class.spells.chantdisease, 7)
            common.swapSpell(class.spells.mezst, 8)
            common.swapSpell(class.spells.mezae, 9)
            common.swapSpell(class.spells.crescendo, 10)
            common.swapSpell(class.spells.pulse, 11)
            common.swapSpell(class.spells.composite, 12, composite_names)
            common.swapSpell(class.spells.dirge, 13)
            state.spellSetLoaded = class.OPTS.SPELLSET.value
        else -- emu spellsets
            common.swapSpell(class.spells.emuaura, 1)
            common.swapSpell(class.spells.pulse, 2)
            common.swapSpell(class.spells.emuhaste, 3)
            common.swapSpell(class.spells.suffering, 4)
            common.swapSpell(class.spells.firenukebuff, 5)
            common.swapSpell(class.spells.bardhaste, 6)
            common.swapSpell(class.spells.overhaste, 7)
            common.swapSpell(class.spells.selos, 8)
            --common.swapSpell(class.spells.snare, 9)
            --common.swapSpell(class.spells.chantflame, 10)
        end
        checkSpellTimer:reset()
    end
end
-- aura, chorus, war march, storm, rizlonas, verse, ancient,selos, chant flame, echoes, nivs

function class.pullCustom()
    if class.fluxstaff then
        class.fluxstaff:use()
    elseif class.sonic then
        class.sonic:use()
    end
end

function class.doneSinging()
    if class.OPTS.USETWIST.value then return true end
    if mq.TLO.Me.CastTimeLeft() > 4000 or not mq.TLO.Me.Casting() then
        if mq.TLO.Me.Casting() then mq.cmd('/stopsong') end
        mq.delay(100)
        if not class.spells.selos and class.selos and selosTimer:timerExpired() then
            class.selos:use()
            selosTimer:reset()
        end
        return true
    end
    return false
end

return class