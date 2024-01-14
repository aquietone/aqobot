--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local logger = require('utils.logger')
local timer = require('utils.timer')
local abilities = require('ability')
local common = require('common')
local state = require('state')

local Bard = class:new()

function Bard:init()
    self.classOrder = {'assist', 'mez', 'assist', 'aggro', 'burn', 'cast', 'mash', 'ae', 'recover', 'buff', 'rest'}
    self.EPIC_OPTS = {always=1,shm=1,burn=1,never=1}
    if state.emu then
        self.spellRotations = {emuancient={},emucaster70={},emuaura65={},emuaura55={},emunoaura={}}
        self.DEFAULT_SPELLSET='emuancient'
    else
        self.spellRotations = {melee={},caster={},meleedot={}}
        self.DEFAULT_SPELLSET='melee'
    end
    self:initBase('brd')

    -- what was this again?
    mq.cmd('/squelch /stick mod 0')

    self:initClassOptions()
    self:loadSettings()
    self:initSpellLines()
    self:initSpellRotations()
    self:initDPSAbilities()
    self:initBurns()
    self:initBuffs()
    self:initDefensiveAbilities()
    self:initRecoverAbilities()
    self:addCommonAbilities()

    self.fierceeye = common.getAA('Fierce Eye')
    self.epic = common.getItem('Blade of Vesagran') or common.getItem('Prismatic Dragon Blade')

    -- Bellow handled separately as we want it to run its course and not be refreshed early
    self.bellow = common.getAA('Boastful Bellow')

    -- aa mez
    self.dirge = common.getAA('Dirge of the Sleepwalker')
    self.sonic = common.getAA('Sonic Disturbance')
    self.fluxstaff = common.getItem('Staff of Viral Flux')

    self.selos = common.getAA('Selo\'s Sonata')
end

function Bard:initClassOptions()
    self:addOption('USEEPIC', 'Epic', 'always', self.EPIC_OPTS, 'Set how to use bard epic', 'combobox', nil, 'UseEpic', 'string')
    self:addOption('MEZST', 'Mez ST', true, nil, 'Mez single target', 'checkbox', nil, 'MezST', 'bool')
    self:addOption('MEZAE', 'Mez AE', true, nil, 'Mez AOE', 'checkbox', nil, 'MezAE', 'bool')
    self:addOption('MEZAECOUNT', 'Mez AE Count', 3, nil, 'Threshold to use AE Mez ability', 'inputint', nil, 'MezAECount', 'int')
    self:addOption('USEINSULTS', 'Use Insults', true, nil, 'Use insult songs', 'checkbox', nil, 'UseInsults', 'bool')
    self:addOption('USEINTIMIDATE', 'Use Intimidate', false, nil, 'Use Intimidate (It may fear mobs without the appropriate AA\'s)', 'checkbox', nil, 'UseIntimidate', 'bool')
    self:addOption('USEBELLOW', 'Use Bellow', true, nil, 'Use Boastful Bellow AA', 'checkbox', nil, 'UseBellow', 'bool')
    self:addOption('USECACOPHONY', 'Use Cacophony', true, nil, 'Use Cacophony AA', 'checkbox', nil, 'UseCacophony', 'bool')
    self:addOption('USEFADE', 'Use Fade', false, nil, 'Fade when aggro', 'checkbox', nil, 'UseFade', 'bool')
    self:addOption('RALLYGROUP', 'Rallying Group', false, nil, 'Use Rallying Group AA', 'checkbox', nil, 'RallyGroup', 'bool')
    self:addOption('USESWARM', 'Use Swarm', true, nil, 'Use swarm pet AAs', 'checkbox', nil, 'UseSwarm', 'bool')
    self:addOption('USESNARE', 'Use Snare', false, nil, 'Use snare song', 'checkbox', nil, 'UseSnare', 'bool')
    self:addOption('USETWIST', 'Use Twist', false, nil, 'Use MQ2Twist instead of managing songs', 'checkbox', nil, 'UseTwist', 'bool')
    self:addOption('USEFIREDOTS', 'Use Fire DoT', false, nil, 'Toggle use of Fire DoT songs if they are in the selected song list', 'checkbox', nil, 'UseFireDoTs', 'bool')
    self:addOption('USEFROSTDOTS', 'Use Frost DoT', false, nil, 'Toggle use of Frost DoT songs if they are in the selected song list', 'checkbox', nil, 'UseFrostDoTs', 'bool')
    self:addOption('USEPOISONDOTS', 'Use Poison DoT', false, nil, 'Toggle use of Poison DoT songs if they are in the selected song list', 'checkbox', nil, 'UsePoisonDoTs', 'bool')
    self:addOption('USEDISEASEDOTS', 'Use Disease DoT', false, nil, 'Toggle use of Disease DoT songs if they are in the selected song list', 'checkbox', nil, 'UseDiseaseDoTs', 'bool')
    self:addOption('USEREGENSONG', 'Use Regen Song', false, nil, 'Toggle use of hp/mana regen song line', 'checkbox', nil, 'UseRegenSong', 'bool')
end

function Bard:initSpellLines()
    -- All spells ID + Rank name
    self:addSpell('aura', {'Aura of Tenisbre', 'Aura of Pli Xin Liako', 'Aura of Margidor', 'Aura of Begalru', 'Aura of the Muse', 'Aura of Insight'}) -- spell dmg, overhaste, flurry, triple atk
    self:addSpell('composite', {'Composite Psalm', 'Dissident Psalm', 'Dichotomic Psalm'}) -- DD+melee dmg bonus + small heal
    self:addSpell('aria', {'Aria of Tenisbre', 'Aria of Pli Xin Liako', 'Aria of Margidor', 'Aria of Begalru', }) -- spell dmg, overhaste, flurry, triple atk
    self:addSpell('warmarch', {'War March of Nokk', 'War March of Centien Xi Va Xakra', 'War March of Radiwol', 'War March of Dekloaz'}) -- haste, atk, ds
    self:addSpell('arcane', {'Arcane Rhythm', 'Arcane Harmony', 'Arcane Symphony', 'Arcane Ballad', 'Arcane Aria'}) -- spell dmg proc
    self:addSpell('suffering', {'Kanghammer\'s Song of Suffering', 'Shojralen\'s Song of Suffering', 'Omorden\'s Song of Suffering', 'Travenro\'s Song of Suffering', 'Storm Blade', 'Song of the Storm'}) -- melee dmg proc
    self:addSpell('spiteful', {'Tatalros\' Spiteful Lyric', 'Von Deek\'s Spiteful Lyric', 'Omorden\'s Spiteful Lyric', 'Travenro\' Spiteful Lyric'}) -- AC
    self:addSpell('pulse', {'Pulse of August', 'Pulse of Nikolas', 'Pulse of Vhal`Sera', 'Pulse of Xigarn', 'Cantata of Life', 'Chorus of Life', 'Wind of Marr', 'Chorus of Marr', 'Chorus of Replenishment', 'Cantata of Soothing'}, {opt='USEREGENSONG'}) -- heal focus + regen
    self:addSpell('sonata', {'Dhakka\'s Spry Sonata', 'Xetheg\'s Spry Sonata', 'Kellek\'s Spry Sonata', 'Kluzen\'s Spry Sonata'}) -- spell shield, AC, dmg mitigation
    self:addSpell('dirge', {'Dirge of the Restless', 'Dirge of Lost Horizons'}) -- spell+melee dmg mitigation
    self:addSpell('firenukebuff', {'Flariton\'s Aria', 'Constance\'s Aria', 'Sontalak\'s Aria', 'Quinard\'s Aria', 'Rizlona\'s Fire', 'Rizlona\'s Embers'}) -- inc fire DD
    self:addSpell('firemagicdotbuff', {'Tatalros\' Psalm of Potency', 'Fyrthek Fior\'s Psalm of Potency', 'Velketor\'s Psalm of Potency', 'Akett\'s Psalm of Potency'}) -- inc fire+mag dot
    self:addSpell('crescendo', {'Regar\'s Lively Crescendo', 'Zelinstein\'s Lively Crescendo', 'Zburator\'s Lively Crescendo', 'Jembel\'s Lively Crescendo'}) -- small heal hp, mana, end
    self:addSpell('insult', {'Yelinak\'s Insult', 'Sathir\'s Insult'}) -- synergy DD
    self:addSpell('insult2', {'Eoreg\'s Insult', 'Sogran\'s Insult', 'Omorden\'s Insult', 'Travenro\'s Insult'}) -- synergy DD 2
    self:addSpell('chantflame', {'Kindleheart\'s Chant of Flame', 'Shak Dathor\'s Chant of Flame', 'Sontalak\'s Chant of Flame', 'Quinard\'s Chant of Flame', 'Vulka\'s Chant of Flame', 'Tuyen\'s Chant of Fire', 'Tuyen\'s Chant of Flame'}, {opt='USEFIREDOTS'})
    self:addSpell('chantfrost', {'Swarn\'s Chant of Frost', 'Sylra Fris\' Chant of Frost', 'Yelinak\'s Chant of Frost', 'Ekron\'s Chant of Frost', 'Vulka\'s Chant of Frost', 'Tuyen\'s Chant of Ice', 'Tuyen\'s Chant of Frost'}, {opt='USEFROSTDOTS'})
    self:addSpell('chantdisease', {'Goremand\'s Chant of Disease', 'Coagulus\' Chant of Disease', 'Zlexak\'s Chant of Disease', 'Hoshkar\'s Chant of Disease', 'Vulka\'s Chant of Disease', 'Tuyen\'s Chant of the Plague', 'Tuyen\'s Chant of Disease'}, {opt='USEDISEASEDOTS'})
    self:addSpell('chantpoison', {'Marsin\'s Chant of Poison', 'Cruor\'s Chant of Poison', 'Malvus\'s Chant of Poison', 'Nexona\'s Chant of Poison', 'Vulka\'s Chant of Poison', 'Tuyen\'s Chant of Venom', 'Tuyen\'s Chant of Poison'}, {opt='USEPOISONDOTS'})
    self:addSpell('alliance', {'Coalition of Sticks and Stones', 'Covenant of Sticks and Stones', 'Alliance of Sticks and Stones'})
    self:addSpell('mezst', {'Slumber of Suja', 'Slumber of the Diabo', 'Slumber of Zburator', 'Slumber of Jembel', 'Lullaby of Morell'})
    self:addSpell('mezae', {'Wave of Stupor', 'Wave of Nocturn', 'Wave of Sleep', 'Wave of Somnolence'})
    -- resonating barrier, new defensive stun proc?
    -- Fatesong of Zoraxmen, increase cold nuke dmg
    -- Appeasing Accelerando, aggro reduction
    -- Chorus of Shalowain, hp,mana,end regen
    -- Grayleaf's Reckless Renewal, heal/hot focus
    -- Psalm of the Nomad, DS, resists, ac
    -- Voice of Suja, charm
    -- Zinnia's Melodic Binding, PB slow
    -- haste song doesn't stack with enc haste?
    self:addSpell('overhaste', {'Ancient: Call of Power', 'Warsong of the Vah Shir', 'Battlecry of the Vah Shir'})
    self:addSpell('bardhaste', {'Verse of Veeshan', 'Psalm of Veeshan', 'Composition of Ervaj'})
    self:addSpell('emuhaste', {'War March of Muram', 'War March of the Mastruq', 'McVaxius\' Rousing Rondo', 'McVaxius\' Berserker Crescendo', 'Anthem de Arms'})
    self:addSpell('snare', {'Selo\'s Consonant Chain'}, {opt='USESNARE'})
    self:addSpell('debuff', {'Harmony of Sound'})

    if state.emu then
        if self.spells.chantflame then self.spells.chantflame.CheckFor = 'Chant of Flame' end
        if self.spells.chantfrost then self.spells.chantfrost.CheckFor = 'Chant of Frost' end
        if self.spells.chantdisease then self.spells.chantdisease.CheckFor = 'Chant of Plague' end
        if self.spells.chantpoison then self.spells.chantpoison.CheckFor = 'Chant of Venom' end
        self:addSpell('selos', {'Selo\'s Accelerating Chorus', 'Selo\'s Rhythm of Speed'})
    end
end

function Bard:initSpellRotations()
    if state.emu then
        table.insert(self.spellRotations.emuancient, self.spells.selos)
        table.insert(self.spellRotations.emuancient, self.spells.chantflame)
        table.insert(self.spellRotations.emuancient, self.spells.chantfrost)
        table.insert(self.spellRotations.emuancient, self.spells.chantdisease)
        table.insert(self.spellRotations.emuancient, self.spells.chantpoison)
        table.insert(self.spellRotations.emuancient, self.spells.overhaste)
        table.insert(self.spellRotations.emuancient, self.spells.suffering)
        table.insert(self.spellRotations.emuancient, self.spells.pulse)
        table.insert(self.spellRotations.emuancient, self.spells.bardhaste)

        table.insert(self.spellRotations.emucaster70, self.spells.selos)
        table.insert(self.spellRotations.emucaster70, self.spells.chantflame)
        table.insert(self.spellRotations.emucaster70, self.spells.chantfrost)
        table.insert(self.spellRotations.emucaster70, self.spells.chantdisease)
        table.insert(self.spellRotations.emucaster70, self.spells.chantpoison)
        table.insert(self.spellRotations.emucaster70, self.spells.overhaste)
        table.insert(self.spellRotations.emucaster70, self.spells.arcane)
        table.insert(self.spellRotations.emucaster70, self.spells.pulse)
        table.insert(self.spellRotations.emucaster70, self.spells.bardhaste)

        table.insert(self.spellRotations.emuaura65, self.spells.selos)
        table.insert(self.spellRotations.emuaura65, self.spells.suffering)
        table.insert(self.spellRotations.emuaura65, self.spells.bardhaste)
        table.insert(self.spellRotations.emuaura65, self.spells.emuhaste)

        table.insert(self.spellRotations.emuaura55, self.spells.selos)
        table.insert(self.spellRotations.emuaura55, self.spells.pulse)
        table.insert(self.spellRotations.emuaura55, self.spells.overhaste)
        table.insert(self.spellRotations.emuaura55, self.spells.bardhaste)
        table.insert(self.spellRotations.emuaura55, self.spells.emuhaste)

        table.insert(self.spellRotations.emunoaura, self.spells.selos)
        table.insert(self.spellRotations.emunoaura, self.spells.pulse)
        table.insert(self.spellRotations.emunoaura, self.spells.overhaste)
        table.insert(self.spellRotations.emunoaura, self.spells.emuhaste)
        table.insert(self.spellRotations.emunoaura, self.spells.firenukebuff)
    else
        -- entries in the dots table are pairs of {spell id, spell name} in priority order
        self.spellRotations.melee = {
            self.spells.composite, self.spells.crescendo, self.spells.aria,
            self.spells.spiteful, self.spells.suffering, self.spells.warmarch,
            self.spells.pulse, self.spells.dirge
        }
        -- synergy, mezst, mstae

        self.spellRotations.caster = {
            self.spells.composite, self.spells.crescendo, self.spells.aria,
            self.spells.arcane, self.spells.firenukebuff, self.spells.suffering,
            self.spells.warmarch, self.spells.firemagicdotbuff, self.spells.pulse,
            self.spells.dirge
        }
        -- synergy, mezst, mezae

        self.spellRotations.meleedot = {
            self.spells.composite, self.spells.crescendo, self.spells.chantflame,
            self.spells.aria, self.spells.warmarch, self.spells.chantdisease,
            self.spells.suffering, self.spells.pulse, self.spells.dirge,
            self.spells.chantfrost
        }
        -- synergy, mezst, mezae
    end
end

function Bard:initDPSAbilities()
    table.insert(self.DPSAbilities, common.getBestDisc({'Reflexive Rebuttal'}))
    table.insert(self.DPSAbilities, common.getSkill('Intimidation', {opt='USEINTIMIDATE'}))
    table.insert(self.DPSAbilities, common.getSkill('Kick'))
    table.insert(self.DPSAbilities, common.getAA('Selo\'s Kick'))

    table.insert(self.AEDPSAbilities, common.getAA('Vainglorious Shout', {threshold=2}))
end

function Bard:initBurns()
    table.insert(self.burnAbilities, common.getItem(mq.TLO.InvSlot('Chest').Item.Name()))
    table.insert(self.burnAbilities, common.getItem('Rage of Rolfron'))
    table.insert(self.burnAbilities, common.getAA('Quick Time'))
    table.insert(self.burnAbilities, common.getAA('Funeral Dirge'))
    if state.emu then
        table.insert(self.burnAbilities, common.getAA('Third Spire of the Minstrels'))
    else
        table.insert(self.burnAbilities, common.getAA('Spire of the Minstrels'))
    end
    table.insert(self.burnAbilities, common.getAA('Bladed Song'))
    table.insert(self.burnAbilities, common.getAA('Dance of Blades'))
    table.insert(self.burnAbilities, common.getAA('Flurry of Notes'))
    table.insert(self.burnAbilities, common.getAA('Frenzied Kicks'))
    table.insert(self.burnAbilities, common.getBestDisc({'Thousand Blades'}))
    table.insert(self.burnAbilities, common.getAA('Cacophony', {opt='USECACOPHONY'}))
    -- Delay after using swarm pet AAs while pets are spawning
    table.insert(self.burnAbilities, common.getAA('Lyrical Prankster', {opt='USESWARM', delay=1500}))
    table.insert(self.burnAbilities, common.getAA('Song of Stone', {opt='USESWARM', delay=1500}))

    table.insert(self.burnAbilities, common.getAA('A Tune Stuck In Your Head'))
    table.insert(self.burnAbilities, common.getBestDisc({'Puretone Discipline'}))
end

function Bard:initBuffs()
    table.insert(self.auras, self.spells.aura)
    table.insert(self.selfBuffs, common.getAA('Sionachie\'s Crescendo'))
end

function Bard:initDefensiveAbilities()
    table.insert(self.defensiveAbilities, common.getAA('Shield of Notes'))
    table.insert(self.defensiveAbilities, common.getAA('Hymn of the Last Stand'))
    table.insert(self.defensiveAbilities, common.getBestDisc({'Deftdance Discipline'}))

    -- Aggro
    local preFade = function() mq.cmd('/attack off') end
    local postFade = function()
        mq.delay(1000)
        mq.cmd('/makemevis')
        mq.cmd('/attack on')
    end
    table.insert(self.fadeAbilities, common.getAA('Fading Memories', {opt='USEFADE', precase=preFade, postcast=postFade}))
end

function Bard:initRecoverAbilities()
    -- Mana Recovery AAs
    self.rallyingsolo = common.getAA('Rallying Solo', {mana=true, endurance=true, threshold=20, combat=false, ooc=true})
    table.insert(self.recoverAbilities, self.rallyingsolo)
    self.rallyingcall = common.getAA('Rallying Call')
end

local selosTimer = timer:new(30000)
local crescendoTimer = timer:new(53000)
local bellowTimer = timer:new(30000)
local synergyTimer = timer:new(18000)

function Bard:resetClassTimers()
    bellowTimer:reset(0)
    synergyTimer:reset(0)
end

-- Casts alliance if we are fighting, alliance is enabled, the spell is ready, alliance isn't already on the mob, there is > 1 necro in group or raid, and we have at least a few dots on the mob.
local function tryAlliance()
    local alliance = Bard.spells.alliance and Bard.spells.alliance.Name
    if Bard:isEnabled('USEALLIANCE') and alliance then
        if mq.TLO.Spell(alliance).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        if mq.TLO.Me.Gem(alliance)() and mq.TLO.Me.GemTimer(alliance)() == 0  and not mq.TLO.Target.Buff(alliance)() and mq.TLO.Spell(alliance).StacksTarget() then
            Bard.spells.alliance:use()
            return true
        end
    end
    return false
end

local function castSynergy()
    -- don't nuke if i'm not attacking
    local synergy = Bard.spells.insult and Bard.spells.insult.Name
    if Bard:isEnabled('USEINSULTS') and synergyTimer:timerExpired() and synergy and mq.TLO.Me.Combat() then
        if not mq.TLO.Me.Song('Troubadour\'s Synergy')() and mq.TLO.Me.Gem(synergy)() and mq.TLO.Me.GemTimer(synergy)() == 0 then
            if mq.TLO.Spell(synergy).Mana() > mq.TLO.Me.CurrentMana() then
                return false
            end
            Bard.spells.insult:use()
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
    if spellName == (Bard.spells.crescendo and Bard.spells.crescendo.name) and (mq.TLO.Me.Buff(actualSpellName)() or not crescendoTimer:timerExpired()) then
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
    if not mq.TLO.Target.Snared() and Bard:isEnabled('USESNARE') and ((mq.TLO.Target.PctHPs() or 100) < 30) then
        return Bard.spells.snare
    end
    if not Bard.spellRotations[Bard.OPTS.SPELLSET.value] then return nil end
    for _,song in ipairs(Bard.spellRotations[Bard.OPTS.SPELLSET.value]) do -- iterates over the dots array. ipairs(dots) returns 2 values, an index and its value in the array. we don't care about the index, we just want the dot
        local song_id = song.ID
        local song_name = song.Name
        if isSongReady(song_id, song_name) and Bard:isAbilityEnabled(song.opt) and not mq.TLO.Target.Buff(song.CheckFor)() then
            if song_name ~= (Bard.spells.composite and Bard.spells.composite.Name) or mq.TLO.Target() then
                return song
            end
        end
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

function Bard:cast()
    if self:isEnabled('USETWIST') or mq.TLO.Me.Invis() then return false end
    if not state.loop.Invis and self:doneSinging() then
        --if mq.TLO.Target.Type() == 'NPC' and mq.TLO.Me.CombatState() == 'COMBAT' then
        if mq.TLO.Target.Type() == 'NPC' and mq.TLO.Me.Combat() then
            if (self.OPTS.USEEPIC.value == 'always' or state.burnActive or (self.OPTS.USEEPIC.value == 'shm' and mq.TLO.Me.Song('Prophet\'s Gift of the Ruchu')())) then
                if self:useEpic() then mq.delay(250) return true end
            end
            for _,clicky in ipairs(self.castClickies) do
                if clicky.enabled then
                    if clicky.TargetType == 'Single' then
                        -- if single target clicky then make sure in combat
                        if (clicky.Duration == 0 or not mq.TLO.Target.Buff(clicky.CheckFor)()) then
                            if clicky:use() then
                                mq.delay(250)
                                return true
                            end
                        end
                    elseif clicky.Duration == 0 or (not mq.TLO.Me.Buff(clicky.CheckFor)() and not mq.TLO.Me.Song(clicky.CheckFor)()) then
                        -- otherwise just use the clicky if its instant or we don't already have the buff/song
                        if clicky:use() then
                            mq.delay(250)
                            return true
                        end
                    end
                end
            end
        end
        local spell = findNextSong() -- find the first available dot to cast that is missing from the target
        if spell then -- if a song was found
            local didCast = false
            if spell.TargetType == 'Single' and mq.TLO.Target.Type() == 'NPC' then
                if mq.TLO.Me.CombatState() == 'COMBAT' then didCast = spell:use() end
            else
                didCast = spell:use()
            end
            if not mq.TLO.Me.Casting() then
                -- not casting, so either we just played selos or missed a note, take some time for unknown reasons
                mq.delay(500)
            end
            if spell.Name == (self.spells.crescendo and self.spells.crescendo.Name) then crescendoTimer:reset() end
            return didCast
        end
    end
    return false
end

function Bard:useEpic()
    if not self.fierceeye or not self.epic then
        if self.fierceeye then return self.fierceeye:use() end
        if self.epic then return self.epic:use() end
        return
    end
    local fierceeye_rdy = mq.TLO.Me.AltAbilityReady(self.fierceeye.Name)()
    if self.epic:isReady() == abilities.IsReady.SHOULD_CAST and fierceeye_rdy then
        mq.cmd('/stopsong')
        mq.delay(250)
        self.fierceeye:use()
        mq.delay(250)
        self.epic:use()
        mq.delay(500)
        return true
    end
end
function Bard:burnClass() Bard:useEpic() end

function Bard:mashClass()
    if self:isEnabled('USEBELLOW') and self.bellow and bellowTimer:timerExpired() and self.bellow:use() then
        bellowTimer:reset()
    end
end

function Bard:hold()
    if self.rallyingsolo and (mq.TLO.Me.Song(self.rallyingsolo.Name)() or mq.TLO.Me.Buff(self.rallyingsolo.Name)()) then
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

function Bard:invis()
    mq.cmd('/stopcast')
    mq.delay(1)
    mq.cmd('/cast "selo\'s song of travel"')
    mq.delay(3500, function() return mq.TLO.Me.Invis() end)
    state.loop.Invis = true
end

local composite_names = {['Composite Psalm']=true,['Dissident Psalm']=true,['Dichotomic Psalm']=true}
local checkSpellTimer = timer:new(30000)
function Bard:checkSpellSet()
    if not common.clearToBuff() or mq.TLO.Me.Moving() or self:isEnabled('BYOS') then return end
    if not self:doneSinging() then return end
    local spellSet = self.OPTS.SPELLSET.value
    if state.spellSetLoaded ~= spellSet or checkSpellTimer:timerExpired() then
        if spellSet == 'melee' then
            if abilities.swapSpell(self.spells.aria, 1) then return end
            if abilities.swapSpell(self.spells.arcane, 2) then return end
            if abilities.swapSpell(self.spells.spiteful, 3) then return end
            if abilities.swapSpell(self.spells.suffering, 4) then return end
            if abilities.swapSpell(self.spells.insult, 5) then return end
            if abilities.swapSpell(self.spells.warmarch, 6) then return end
            if abilities.swapSpell(self.spells.sonata, 7) then return end
            if abilities.swapSpell(self.spells.mezst, 8) then return end
            if abilities.swapSpell(self.spells.mezae, 9) then return end
            if abilities.swapSpell(self.spells.crescendo, 10) then return end
            if abilities.swapSpell(self.spells.pulse, 11) then return end
            if abilities.swapSpell(self.spells.composite, 12, false, composite_names) then return end
            if abilities.swapSpell(self.spells.dirge, 13) then return end
            state.spellSetLoaded = spellSet
        elseif spellSet == 'caster' then
            if abilities.swapSpell(self.spells.aria, 1) then return end
            if abilities.swapSpell(self.spells.arcane, 2) then return end
            if abilities.swapSpell(self.spells.firenukebuff, 3) then return end
            if abilities.swapSpell(self.spells.suffering, 4) then return end
            if abilities.swapSpell(self.spells.insult, 5) then return end
            if abilities.swapSpell(self.spells.warmarch, 6) then return end
            if abilities.swapSpell(self.spells.firemagicdotbuff, 7) then return end
            if abilities.swapSpell(self.spells.mezst, 8) then return end
            if abilities.swapSpell(self.spells.mezae, 9) then return end
            if abilities.swapSpell(self.spells.crescendo, 10) then return end
            if abilities.swapSpell(self.spells.pulse, 11) then return end
            if abilities.swapSpell(self.spells.composite, 12, false, composite_names) then return end
            if abilities.swapSpell(self.spells.dirge, 13) then return end
            state.spellSetLoaded = spellSet
        elseif spellSet == 'meleedot' then
            if abilities.swapSpell(self.spells.aria, 1) then return end
            if abilities.swapSpell(self.spells.chantflame, 2) then return end
            if abilities.swapSpell(self.spells.chantfrost, 3) then return end
            if abilities.swapSpell(self.spells.suffering, 4) then return end
            if abilities.swapSpell(self.spells.insult, 5) then return end
            if abilities.swapSpell(self.spells.warmarch, 6) then return end
            if abilities.swapSpell(self.spells.chantdisease, 7) then return end
            if abilities.swapSpell(self.spells.mezst, 8) then return end
            if abilities.swapSpell(self.spells.mezae, 9) then return end
            if abilities.swapSpell(self.spells.crescendo, 10) then return end
            if abilities.swapSpell(self.spells.pulse, 11) then return end
            if abilities.swapSpell(self.spells.composite, 12, false, composite_names) then return end
            if abilities.swapSpell(self.spells.dirge, 13) then return end
            state.spellSetLoaded = spellSet
        else -- emu spellsets
            if abilities.swapSpell(self.spells.emuaura, 1) then return end
            if abilities.swapSpell(self.spells.pulse, 2) then return end
            if abilities.swapSpell(self.spells.emuhaste, 3) then return end
            if abilities.swapSpell(self.spells.suffering, 4) then return end
            if abilities.swapSpell(self.spells.firenukebuff, 5) then return end
            if abilities.swapSpell(self.spells.bardhaste, 6) then return end
            if abilities.swapSpell(self.spells.overhaste, 7) then return end
            if abilities.swapSpell(self.spells.selos, 8) then return end
            --if abilities.swapSpell(self.spells.snare, 9) then return end
            --if abilities.swapSpell(self.spells.chantflame, 10) then return end
        end
        checkSpellTimer:reset()
    end
end
-- aura, chorus, war march, storm, rizlonas, verse, ancient,selos, chant flame, echoes, nivs

function Bard:pullCustom()
    if self.fluxstaff then
        self.fluxstaff:use()
    elseif self.sonic then
        self.sonic:use()
    end
end

function Bard:doneSinging()
    if self:isEnabled('USETWIST') then return true end
    if mq.TLO.Me.CastTimeLeft() > 0 and not mq.TLO.Window('CastingWindow').Open() then
        mq.delay(250)
        mq.cmd('/stopsong')
        mq.delay(1)
    end
    if not mq.TLO.Me.Casting() then
        if not self.spells.selos and self.selos and selosTimer:timerExpired() then
            self.selos:use()
            selosTimer:reset()
        end
        return true
    end
    return false
end

return Bard
