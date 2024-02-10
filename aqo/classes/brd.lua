--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local assist = require('routines.assist')
local conditions = require('routines.conditions')
local logger = require('utils.logger')
local timer = require('libaqo.timer')
local abilities = require('ability')
local common = require('common')
local state = require('state')

local Bard = class:new()

function Bard:init()
    self.classOrder = {'assist', 'mez', 'assist', 'aggro', 'burn', 'cast', 'mash', 'ae', 'recover', 'buff', 'rest'}
    self.EPIC_OPTS = {always=1,shm=1,burn=1,never=1}
    if state.emu then
        self.spellRotations = {emuancient={},emucaster70={},emuaura65={},emuaura55={},emunoaura={},custom={}}
        self.defaultSpellset='emuancient'
    else
        self.spellRotations = {melee={},caster={},meleedot={},custom={}}
        self.defaultSpellset='melee'
    end
    self:initBase('BRD')

    -- what was this again?
    mq.cmd('/squelch /stick mod 0')

    self:initClassOptions()
    self:loadSettings()
    self:initSpellLines()
    self:initSpellRotations()
    self:initAbilities()
    self:addCommonAbilities()
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

-- melee haste v98 (Bard Haste) (Composition of Ervaj (lvl 60), Melody of Ervaj (lvl 50))
-- melee haste v119 (BardHaste2) (Aria song line, Aura song line, Echo song line, Warsong)
Bard.SpellLines = {
    {-- spell dmg, overhaste, flurry, triple atk. Slot 1
        Group='aria',
        Spells={'Aria of Tenisbre', 'Aria of Pli Xin Liako', 'Aria of Margidor', 'Aria of Begalru', 'Aria of Maetanrus', --[[emu cutoff]] },
        Options={Gem=1}
    },
    {-- spell dmg proc. Slot 2
        Group='arcane',
        Spells={'Arcane Rhythm', 'Arcane Harmony', 'Arcane Symphony', 'Arcane Ballad', 'Arcane Melody', --[[emu cutoff]] 'Arcane Aria'},
        Options={Gem=2}
    },
    {-- frost dot. Slot 2
        Group='chantfrost',
        Spells={'Swarn\'s Chant of Frost', 'Sylra Fris\' Chant of Frost', 'Yelinak\'s Chant of Frost', 'Ekron\'s Chant of Frost', 'Kirchen\'s Chant of Frost', --[[emu cutoff]] 'Vulka\'s Chant of Frost', 'Tuyen\'s Chant of Ice', 'Tuyen\'s Chant of Frost'},
        Options={opt='USEFROSTDOTS', Gem=2, CheckFor=state.emu and 'Chant of Frost'}
    },
    {-- AC. Slot 3
        Group='spiteful',
        Spells={'Tatalros\' Spiteful Lyric', 'Von Deek\'s Spiteful Lyric', 'Omorden\'s Spiteful Lyric', 'Travenro\' Spiteful Lyric', 'Fjilnauk\'s Spiteful Lyric', --[[emu cutoff]] 'Guardian Rhythms'},
        Options={Gem=function() return Bard:get('SPELLSET') == 'melee' and 3 or nil end}
    },
    {-- inc fire DD. Slot 3
        Group='firenukebuff',
        Spells={'Flariton\'s Aria', 'Constance\'s Aria', 'Sontalak\'s Aria', 'Quinard\'s Aria', 'Nilsara\'s Aria', --[[emu cutoff]] 'Yelhun\'s Mystic Call', 'Rizlona\'s Fire', 'Rizlona\'s Embers'},
        Options={Gem=function() return Bard:get('SPELLSET') == 'caster' and 3 or nil end}
    },
    {-- fire dot. Slot 3
        Group='chantflame',
        Spells={'Kindleheart\'s Chant of Flame', 'Shak Dathor\'s Chant of Flame', 'Sontalak\'s Chant of Flame', 'Quinard\'s Chant of Flame', 'Nilsara\'s Chant of Flame', --[[emu cutoff]] 'Vulka\'s Chant of Flame', 'Tuyen\'s Chant of Fire', 'Tuyen\'s Chant of Flame'},
        Options={opt='USEFIREDOTS', Gem=3, CheckFor=state.emu and 'Chant of Flame'}
    },
    {-- melee dmg proc. Slot 4
        Group='suffering',
        Spells={'Kanghammer\'s Song of Suffering', 'Shojralen\'s Song of Suffering', 'Omorden\'s Song of Suffering', 'Travenro\'s Song of Suffering', 'Fjilnauk\'s Song of Suffering', --[[emu cutoff]] 'Storm Blade', 'Song of the Storm'},
        Options={Gem=4}
    },
    {-- synergy DD. Slot 5
        Group='insult',
        Spells={'Nord\'s Disdain', 'Yelinak\'s Insult', 'Sathir\'s Insult', 'Tsaph\'s Insult', 'Garath\'s Insult', --[[emu cutoff]] 'Brusco\'s Boastful Bellow'},
        Options={opt='USEINSULTS', Gem=5}
    },
    {-- haste, atk, ds. Slot 6
        Group='warmarch',
        Spells={'War March of Nokk', 'War March of Centien Xi Va Xakra', 'War March of Radiwol', 'War March of Dekloaz', 'War March of Jocelyn', --[[emu cutoff]] 'War March of Muram', 'War March of the Mastruq', 'McVaxius\' Rousing Rondo', 'McVaxius\' Berserker Crescendo', 'Anthem de Arms', 'Chant of Battle'},
        Options={Gem=6}
    },
    {-- spell shield, AC, dmg mitigation. Slot 7
        Group='sonata',
        Spells={'Dhakka\'s Spry Sonata', 'Xetheg\'s Spry Sonata', 'Kellek\'s Spry Sonata', 'Kluzen\'s Spry Sonata', 'Dhakka\'s Spry Sonata', --[[emu cutoff]] },
        Options={Gem=function() return Bard:get('SPELLSET') == 'melee' and 7 or nil end}
    },
    {-- inc fire+mag dot. Slot 7
        Group='firemagicdotbuff',
        Spells={'Tatalros\' Psalm of Potency', 'Fyrthek Fior\'s Psalm of Potency', 'Velketor\'s Psalm of Potency', 'Akett\'s Psalm of Potency', 'Horthin\'s Psalm of Potency', --[[emu cutoff]] },
        Options={Gem=function() return Bard:get('SPELLSET') == 'caster' and 7 or nil end}
    },
    {-- disease dot. Slot 7
        Group='chantdisease',
        Spells={'Goremand\'s Chant of Disease', 'Coagulus\' Chant of Disease', 'Zlexak\'s Chant of Disease', 'Hoshkar\'s Chant of Disease', 'Horthin\'s Chant of Disease', --[[emu cutoff]] 'Vulka\'s Chant of Disease', 'Tuyen\'s Chant of the Plague', 'Tuyen\'s Chant of Disease'},
        Options={opt='USEDISEASEDOTS', Gem=7, CheckFor=state.emu and 'Chant of Plague'}
    },
    {-- single target mez. Slot 8
        Group='mezst',
        Spells={'Slumber of Suja', 'Slumber of the Diabo', 'Slumber of Zburator', 'Slumber of Jembel', 'Slumber of Silisia', --[[emu cutoff]] 'Lullaby of Morell', 'Crission\'s Pixie Strike', 'Kelin\'s Lucid Lullaby'},
        Options={opt='MEZST', Gem=8}
    },
    {-- aoe mez. Slot 9
        Group='mezae',
        Spells={'Wave of Stupor', 'Wave of Nocturn', 'Wave of Sleep', 'Wave of Somnolence', 'Wave of Torpor', --[[emu cutoff]] },
        Options={opt='MEZAE', Gem=9}
    },
    {-- small heal hp, mana, end. Slot 10
        Group='crescendo',
        Spells={'Regar\'s Lively Crescendo', 'Zelinstein\'s Lively Crescendo', 'Zburator\'s Lively Crescendo', 'Jembel\'s Lively Crescendo', 'Silisia\'s Lively Crescendo', --[[emu cutoff]] },
        Options={Gem=10}
    },
    {-- heal focus + regen. Slot 11
        Group='pulse',
        Spells={'Pulse of August', 'Pulse of Nikolas', 'Pulse of Vhal`Sera', 'Pulse of Xigarn', 'Pulse of Sionachie', --[[emu cutoff]] 'Cantata of Life', 'Chorus of Life', 'Wind of Marr', 'Chorus of Marr', 'Chorus of Replenishment', 'Cantata of Soothing', 'Hymn of Restoration'},
        Options={opt='USEREGENSONG', Gem=11}
    },
    {-- DD+melee dmg bonus + small heal. Slot 12
        Group='composite',
        Spells={'Ecliptic Psalm', 'Composite Psalm', 'Dissident Psalm', 'Dichotomic Psalm'},
        Options={Gem=12}
    },
    {-- spell+melee dmg mitigation. Slot 13
        Group='dirge',
        Spells={'Dirge of the Onokiwan', 'Dirge of the Restless', 'Dirge of Lost Horizons'},
        Options={Gem=13}
    },

    {Group='aura', Spells={'Aura of Tenisbre', 'Aura of Pli Xin Liako', 'Aura of Margidor', 'Aura of Begalru', 'Aura of Maetanrus', --[[emu cutoff]] 'Aura of the Muse', 'Aura of Insight'}, Options={aurabuff=true}}, -- spell dmg, overhaste, flurry, triple atk
    {Group='insultpushback', Spells={'Eoreg\'s Insult', 'Sogran\'s Insult', 'Omorden\'s Insult', 'Travenro\'s Insult', 'Fjilnauk\'s Insult', --[[emu cutoff]] }, Options={opt='USEINSULTS'}}, -- synergy DD 2
    {Group='chantpoison', Spells={'Marsin\'s Chant of Poison', 'Cruor\'s Chant of Poison', 'Malvus\'s Chant of Poison', 'Nexona\'s Chant of Poison', 'Serisaria\'s Chant of Poison', --[[emu cutoff]] 'Vulka\'s Chant of Poison', 'Tuyen\'s Chant of Venom', 'Tuyen\'s Chant of Poison'}, Options={opt='USEPOISONDOTS', CheckFor=state.emu and 'Chant of Venom'}},
    {Group='alliance', Spells={'Conjunction of Sticks and Stones', 'Coalition of Sticks and Stones', 'Covenant of Sticks and Stones', 'Alliance of Sticks and Stones'}},

    -- resonating barrier, new defensive stun proc?
    -- Fatesong of Zoraxmen, increase cold nuke dmg
    -- Appeasing Accelerando, aggro reduction
    -- Chorus of Shalowain, hp,mana,end regen
    -- Grayleaf's Reckless Renewal, heal/hot focus
    -- Psalm of the Nomad, DS, resists, ac
    -- Voice of Suja, charm
    -- Zinnia's Melodic Binding, PB slow
    -- haste song doesn't stack with enc haste?
    {Group='overhaste', Spells={'Ancient: Call of Power', 'Warsong of the Vah Shir', 'Battlecry of the Vah Shir'}},
    {Group='bardhaste', Spells={'Verse of Veeshan', 'Psalm of Veeshan', 'Composition of Ervaj'}},
    {Group='emuhaste', Spells={'War March of Muram', 'War March of the Mastruq', 'McVaxius\' Rousing Rondo', 'McVaxius\' Berserker Crescendo', 'Anthem de Arms'}},
    {Group='snare', Spells={'Selo\'s Consonant Chain'}, Options={opt='USESNARE'}},
    {Group='debuff', Spells={'Harmony of Sound'}},
    {Group='jonthans', Spells={'Jonthan\'s Whistling Warsong'}, Options={}},
    {Group='magicweapons', Spells={'Magical Monologue'}, Options={}},
    {Group='chantmagic', Spells={'Fufil\'s Curtailing Chant'}, Options={}},
    {Group='selos', Spells={'Selo\'s Accelerating Chorus', 'Selo\'s Rhythm of Speed', 'Selo\'s Accelerando'}},

    {Group='aedot', Spells={'Denon\'s Disruptive Discord', 'Chords of Dissonance'}, Options={'USEAOE'}},
    {Group='aeslow', Spells={'Largo\'s Melodic Binding'}, Options={}},
    {Group='manasong', Spells={'Cassindra\'s Chorus of Clarity', 'Cassindra\'s Chant of Clarity'}, Options={}},
    {Group='dispel', Spells={'Alenia\'s Disenchanting Melody'}, Options={}}
}

Bard.compositeNames = {['Ecliptic Psalm']=true,['Composite Psalm']=true,['Dissident Psalm']=true,['Dichotomic Psalm']=true}
Bard.allDPSSpellGroups = {'aria', 'arcane', 'chantfrost', 'spiteful', 'firenukebuff', 'chantflame', 'suffering', 'insult', 'warmarch', 'sonata', 'firemagicdotbuff', 'chantdisease',
    'crescendo', 'pulse', 'composite', 'dirge', 'insultpushback', 'chantpoison', 'alliance', 'overhaste', 'bardhaste', 'emuhaste', 'snare', 'debuff'}

Bard.Abilities = {
    {
        Type='AA',
        Name='Fierce Eye',
        Options={key='fierceeye'}
    },
    { -- Epic 2.0
        Type='Item',
        Name='Blade of Vesagran',
        Options={key='epic'}
    },
    { -- Epic 1.5
        Type='Item',
        Name='Prismatic Dragon Blade',
        Options={key='epic'}
    },
    -- Bellow handled separately as we want it to run its course and not be refreshed early
    { -- single target AA with fulmination
        Type='AA',
        Name='Boastful Bellow',
        Options={key='bellow'}
    },
    { -- long AA mez
        Type='AA',
        Name='Dirge of the Sleepwalker',
        Options={key='dirge'}
    },
    { -- pull ability
        Type='AA',
        Name='Sonic Disturbance',
        Options={key='sonic'}
    },
    { -- pull ability
        Type='Item',
        Name='Staff of Viral Flux',
        Options={key='fluxstaff'}
    },
    {
        Type='AA',
        Name='Selo\'s Sonata',
        Options={key='selos'}
    },

    -- DPS
    {
        Type='Disc',
        Group='reflexive',
        Names={'Reflexive Rebuttal'},
        Options={dps=true}
    },
    {
        Type='Skill',
        Name='Intimidation',
        Options={opt='USEINTIMIDATE', dps=true}
    },
    {
        Type='Skill',
        Name='Kick',
        Options={dps=true, condition=conditions.withinMeleeDistance},
    },
    {
        Type='AA',
        Name='Selo\'s Kick',
        Options={dps=true}
    },

    -- AE DPS
    { -- aoe aa
        Type='AA',
        Name='Vainglorious Shout',
        Options={aedps=true, threshold=3}
    },

    -- Burns
    {
        Type='Item',
        Name=mq.TLO.InvSlot('Chest').Item.Name(),
        Options={first=true}
    },
    {
        Type='Item',
        Name='Rage of Rolfron',
        Options={first=true}
    },
    {
        Type='AA',
        Name='Quick Time',
        Options={first=true}
    },
    {
        Type='AA',
        Name='Funeral Dirge',
        Options={first=true}
    },
    {
        Type='AA',
        Name='Spire of the Minstrels',
        Options={first=true}
    },
    {
        Type='first=true',
        Name='Third Spire of the Minstrels',
        Options={emu=true, first=true}
    },
    {
        Type='AA',
        Name='Bladed Song',
        Options={first=true}
    },
    {
        Type='AA',
        Name='Dance of Blades',
        Options={first=true}
    },
    {
        Type='AA',
        Name='Flurry of Notes',
        Options={first=true}
    },
    {
        Type='AA',
        Name='Frenzied Kicks',
        Options={first=true}
    },
    {
        Type='Disc',
        Group='thousand',
        Names={'Thousand Blades'},
        Options={first=true}
    },
    {
        Type='AA',
        Name='Cacophony',
        Options={first=true, opt='USECACOPHONY'}
    },
    {
        Type='AA',
        Name='Lyrical Prankster',
        Options={first=true, opt='USESWARM', delay=1500}
    },
    {
        Type='AA',
        Name='Song of Stone',
        Options={first=true, opt='USESWARM', delay=1500}
    },
    {
        Type='AA',
        Name='A Tune Stuck In Your Head',
        Options={first=true}
    },
    {
        Type='Disc',
        Group='puretone',
        Names={'Puretone Discipline'},
        Options={first=true}
    },

    -- Buffs
    {
        Type='AA',
        Name='Sionachie\'s Crescendo',
        Options={selfbuff=true}
    },

    -- Defensives and Fade
    {
        Type='AA',
        Name='Shield of Notes',
        Options={defensive=true}
    },
    {
        Type='AA',
        Name='Hymn of the Last Stand',
        Options={defensive=true}
    },
    {
        Type='Disc',
        Group='deftdance',
        Names={'Deftdance Discipline'},
        Options={defensive=true}
    },
    {
        Type='AA',
        Name='Fading Memories',
        Options={fade=true, opt='USEFADE', precast=function() mq.cmd('/attack off') end, postcast=function() mq.delay(1000) mq.cmd('/makemevis') mq.cmd('/attack on') end}
    },

    -- Recover
    {
        Type='AA',
        Name='Rallying Solo',
        Options={recover=true, mana=true, endurance=true, threshold=20, combat=false, ooc=true}
    },
    {
        Type='AA',
        Name='Rallying Call',
        Options={recover=true}
    },
}

function Bard:initSpellRotations()
    self:initBYOSCustom()
    if state.emu then
        self.spellRotations.emuancient = {}
        self.spellRotations.emucaster70 = {}
        self.spellRotations.emuaura65 = {}
        self.spellRotations.emuaura55 = {}
        self.spellRotations.emunoaura = {}
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
        self.spellRotations.melee = {}
        self.spellRotations.caster = {}
        self.spellRotations.meleedot = {}
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
    if Bard:isEnabled('USEINSULTS') and synergyTimer:expired() and synergy and mq.TLO.Me.Combat() then
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
    if mq.TLO.Spell(spellName).Mana() > mq.TLO.Me.CurrentMana() or (mq.TLO.Spell(spellName).Mana() > 1000 and mq.TLO.Me.PctMana() < state.minMana) then
        return false
    end
    if mq.TLO.Spell(spellName).EnduranceCost() > mq.TLO.Me.CurrentEndurance() or (mq.TLO.Spell(spellName).EnduranceCost() > 1000 and mq.TLO.Me.PctEndurance() < state.minEndurance) then
        return false
    end
    if mq.TLO.Spell(spellName).TargetType() == 'Single' then
        return isDotReady(spellId, spellName)
    end

    if not mq.TLO.Me.Gem(spellName)() or mq.TLO.Me.GemTimer(spellName)() > 0 then
        return false
    end
    if spellName == (Bard.spells.crescendo and Bard.spells.crescendo.name) and (mq.TLO.Me.Buff(actualSpellName)() or not crescendoTimer:expired()) then
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
    if not Bard.spellRotations[Bard:get('SPELLSET')] then return nil end
    for _,song in ipairs(Bard.spellRotations[Bard:get('SPELLSET')]) do -- iterates over the dots array. ipairs(dots) returns 2 values, an index and its value in the array. we don't care about the index, we just want the dot
        local song_id = song.ID
        local song_name = song.Name
        if Bard:isAbilityEnabled(song.opt) and isSongReady(song_id, song_name) and not mq.TLO.Target.Buff(song.CheckFor)() then
            if song_name ~= (Bard.spells.composite and Bard.spells.composite.Name) or mq.TLO.Target() then
                return song
            end
        end
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

function Bard:cast()
    if self:isEnabled('USETWIST') or mq.TLO.Me.Invis() then return false end
    if not mq.TLO.Me.Invis() and self:doneSinging() then
        --if mq.TLO.Target.Type() == 'NPC' and mq.TLO.Me.CombatState() == 'COMBAT' then
        if mq.TLO.Target.Type() == 'NPC' and mq.TLO.Me.Combat() then
            local useEpic = self:get('USEEPIC')
            if (useEpic == 'always' or state.burnActive or (useEpic == 'shm' and mq.TLO.Me.Song('Prophet\'s Gift of the Ruchu')())) then
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
                if assist.isFighting() then didCast = spell:use() end
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
    if self:isEnabled('USEBELLOW') and self.bellow and bellowTimer:expired() and self.bellow:use() then
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
end

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
        if not self.spells.selos and self.selos and selosTimer:expired() then
            self.selos:use()
            selosTimer:reset()
        end
        return true
    end
    return false
end

return Bard
