local mq = require 'mq'
local class = require('classes.classbase')
local mez = require('routines.mez')
local timer = require('libaqo.timer')
local logger = require('utils.logger')
local abilities = require('ability')
local common = require('common')
local config = require('interface.configuration')
local state = require('state')

local Enchanter = class:new()

--[[
    https://forums.eqfreelance.net/index.php?topic=16075.0
]]
function Enchanter:init()
    self.classOrder = {'assist', 'mez', 'assist', 'aggro', 'debuff', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest', 'managepet', 'rez'}
    self.spellRotations = {standard={},custom={}}
    self.AURAS = {twincast=true, combatinnate=true, spellfocus=true, regen=true, disempower=true,}
    self:initBase('ENC')

    self:initClassOptions()
    self:loadSettings()
    self:initSpellLines()
    self:initSpellRotations()
    self:initAbilities()
    self:addCommonAbilities()
end

function Enchanter:initClassOptions()
    self:addOption('AURA1', 'Aura 1', 'twincast', self.AURAS, 'The first aura to keep up', 'combobox', nil, 'Aura1', 'string')
    self:addOption('AURA2', 'Aura 2', 'combatinnate', self.AURAS, 'The second aura to keep up', 'combobox', nil, 'Aura2', 'string')
    self:addOption('INTERRUPTFORMEZ', 'Interrupt for Mez', false, nil, 'Toggle interrupting current spell casts to cast mez', 'checkbox', nil, 'InterruptForMez', 'bool')
    self:addOption('TASHTHENMEZ', 'Tash Then Mez', true, nil, 'Toggle use of tash prior to attempting to mez mobs', 'checkbox', nil, 'TashThenMez', 'bool')
    self:addOption('USECHAOTIC', 'Use Chaotic', true, nil, 'Toggle use of Chaotic mez line', 'checkbox', nil, 'UseChaotic', 'bool')
    self:addOption('USECHARM', 'Use Charm', false, nil, 'Attempt to maintain a charm pet instead of using a regular pet', 'checkbox', nil, 'UseCharm', 'bool')
    self:addOption('USEDOTS', 'Use DoTs', true, nil, 'Toggle use of DoTs', 'checkbox', nil, 'UseDoTs', 'bool')
    self:addOption('USEHASTE', 'Buff Haste', true, nil, 'Toggle use of haste buff line', 'checkbox', nil, 'UseHaste', 'bool')
    self:addOption('MEZST', 'Use Mez', true, nil, 'Use single target mez on adds within camp radius', 'checkbox', nil, 'MezST', 'bool')
    self:addOption('MEZAE', 'Use AE Mez', true, nil, 'Use AE Mez if 3 or more mobs are within camp radius', 'checkbox', nil, 'MezAE', 'bool')
    self:addOption('MEZAECOUNT', 'AE Mez Count', 3, nil, 'Threshold to use AE Mez ability', 'inputint', nil, 'MezAECount', 'bool')
    self:addOption('USEMINDOVERMATTER', 'Use Mind Over Matter', true, nil, 'Toggle use of Mind over Matter', 'checkbox', nil, 'UseMindOverMatter', 'bool')
    self:addOption('USENIGHTSTERROR', 'Buff Nights Terror', true, nil, 'Toggle use of Nights Terror buff line', 'checkbox', nil, 'UseNDT', 'bool')
    self:addOption('USENUKES', 'Use Nuke', true, nil, 'Toggle use of nukes', 'checkbox', nil, 'UseNukes', 'bool')
    self:addOption('USEPHANTASMAL', 'Use Phantasmal', true, nil, 'Toggle use of Phantasmal', 'checkbox', nil, 'UsePhantasmal', 'bool')
    self:addOption('USEREPLICATION', 'Buff Mana Proc', true, nil, 'Toggle use of Replication buff line', 'checkbox', nil, 'UseReplication', 'bool')
    self:addOption('USESHIELDOFFATE', 'Use Shield of Fate', true, nil, 'Toggle use of Shield of Fate', 'checkbox', nil, 'UseShieldOfFate', 'bool')
    self:addOption('USESLOW', 'Use Slow', false, nil, 'Toggle use of single target slow ability', 'checkbox', nil, 'UseSlow', 'bool')
    self:addOption('USESLOWAOE', 'Use Slow AOE', true, nil, 'Toggle use of AOE slow ability', 'checkbox', nil, 'UseSlowAOE', 'bool')
    self:addOption('USESPELLGUARD', 'Use Spell Guard', true, nil, 'Toggle use of Spell Guard', 'checkbox', nil, 'UseSpellGuard', 'bool')
    self:addOption('USEDEBUFF', 'Use Tash', false, nil, 'Toggle use of single target tash ability', 'checkbox', nil, 'UseDebuff', 'bool')
    self:addOption('USEDEBUFFAOE', 'Use Tash AOE', true, nil, 'Toggle use of AOE tash ability', 'checkbox', nil, 'UseDebuffAOE', 'bool')
    self:addOption('USEDISPEL', 'Use Dispel', true, nil, 'Dispel mobs with Eradicate Magic AA', 'checkbox', nil, 'UseDispel', 'bool')
end
--[[
    edict of tashan
    deviser's auspice
    chaotic puzzlement
    bewildering wave
    mind vortex
    throttling grip
    hastening of jharin
    mindrift
    composite reinforcement
    polyluminous rune
    voice of perception
    night's perpetual terror
    constance's animation
]]
-- mindreap, polyluminous assault, chromashear, psychological appropriation, chromatic flare
Enchanter.SpellLines = {
    {-- Slot 1
        Group='tash',
        Spells={'Roar of Tashan', 'Edict of Tashan', 'Proclamation of Tashan', 'Order of Tashan', 'Decree of Tashan', 'Enunciation of Tashan', 'Declaration of Tashan', 'Clamor of Tashan', --[[emu cutoff]] 'Bite of Tashani', 'Echo of Tashan', 'Tashani', 'Tashan'},
        Options={debuff=true, opt='USEDEBUFF', Gem=1}
    },
    {-- Slot 2
        Group='charm',
        Spells={'Esoteric Command', 'Marvel\'s Command', 'Deviser\'s Command', 'Transfixer\'s Command', 'Enticer\'s Command', --[[emu cutoff]] 'Beguile', 'Charm'},
        Options={opt='USECHARM', Gem=2}
    },
    {-- 6 tick mez + twincast on next spell. Slot 3
        Group='meznoblur',
        Spells={'Chaotic Conundrum', 'Chaotic Puzzlement', 'Chaotic Deception', 'Chaotic Delusion', 'Chaotic Bewildering', 'Chaotic Confounding', 'Chaotic Confusion', 'Chaotic Baffling', --[[emu cutoff]] },
        Options={opt='USECHAOTIC', Gem=3}
    },
    {-- 9 ticks. Slot 3
        Group='mezst',
        Spells={'Flummox', 'Addle', 'Deceive', 'Delude', 'Bewilder', 'Confound', 'Mislead', 'Baffle', --[[emu cutoff]] 'Euphoria', 'Entrance', 'Mesmerization', 'Enthrall', 'Mesmerize'},
        Options={Gem=3, precast=function() if not mq.TLO.Target.Tashed() and Enchanter:isEnabled('TASHTHENMEZ') and Enchanter.spells.tash then
            Enchanter.spells.tash:use()
            mq.delay(50)
            mq.delay(2000, function() return not mq.TLO.Me.Casting() and not mq.TLO.Me.SpellInCooldown() end)
        end
        return true end}
    },
    {-- targeted AE mez. Slot 4
        Group='mezaeprocblur',
        Spells={'Entrancing Stare', 'Mesmeric Stare', 'Deceiving Stare', 'Transfixing Stare', 'Anodyne Stare', 'Mesmerizing Stare', 'Sedative Stare', 'Soporific Stare', --[[emu cutoff]] 'Entrancing Lights'},
        Options={Gem=4}
    },
    {-- main dot. Slot 5
        Group='dot1',
        Spells={'Asphyxiating Grasp', 'Throttling Grip', 'Pulmonary Grip', 'Strangulate', 'Drown', 'Stifle', 'Suffocation', 'Constrict', --[[emu cutoff]] 'Arcane Noose', 'Suffocate', 'Choke', 'Suffocating Sphere', 'Shallow Breath'},
        Options={opt='USEDOTS', Gem=5}
    },
    {-- 77k nuke, procs synery. Slot 6, 7
        Group='mindnuke',
        NumToPick=2,
        Spells={'Mindrend', 'Mindreap', 'Mindrift', 'Mindslash', 'Mindsunder', 'Mindcleave', 'Mindscythe', 'Mindblade', --[[emu cutoff]] 'Ancient: Neurosis', 'Madness of Ikkibi', 'Insanity'},
        Options={opt='USENUKES', Gems={6,7}}
    },
    {-- 28k nuke. Slot 8
        Group='nuke2',
        Spells={'Chromaclap', 'Chromashear', 'Chromoashock', 'Chromareave', 'Chromarift', 'Chromaclash', 'Chromaruin', 'Chromarcana', --[[emu cutoff]] 'Chromaburst', 'Anarchy', 'Chaos Flux', 'Sanity Warp', 'Chaotic Feedback'},
        Options={opt='USENUKES', Gem=function(lvl) return (lvl <= 60 and 7) or 8 end}
    },
    {-- single target dmg proc buff. Slot 9
        Group='procbuff',
        Spells={'Mana Reproduction', 'Mana Rebirth', 'Mana Replication', 'Mana Repetition', 'Mana Reciprocation', 'Mana Reverberation', 'Mana Repercussion', 'Mana Reiteration', --[[emu cutoff]] 'Mana Recursion', 'Mana Flare'},
        Options={swap=false, Gem=9, singlebuff=true, selfbuff=true, classes={MAG=true,WIZ=true,NEC=true,ENC=true,RNG=true}}
    },
    {-- extra dot. Slot 10
        Group='dot2',
        Spells={'Mind Whirl', 'Mind Vortex', 'Mind Coil', 'Mind Tempest', 'Mind Storm', 'Mind Squall', 'Mind Spiral', 'Mind Helix', --[[emu cutoff]] 'Mind Shatter'},
        Options={opt='USEDOTS', Gem=10}
    },
    {-- 24k. when use dots off. Slot 10
        Group='nuke3',
        Spells={'Cognitive Appropriation', 'Psychological Appropriation', 'Ideological Appropriation', 'Psychic Appropriation', 'Intellectual Appropriation', 'Mental Appropriation', --[[emu cutoff]]},
        Options={opt='USENUKES', Gem=function() return not Enchanter:isEnabled('USEDOTS') and 10 or nil end}
    },
    {-- restore mana, add dmg proc, inc dmg. Slot 11
        Group='composite',
        Spells={'Ecliptic Reinforcement', 'Composite Reinforcement', 'Dissident Reinforcement', 'Dichotomic Reinforcement'},
        Options={Gem=11}
    },
    {-- mez proc on being hit. Slot 12
        Group='unity',
        Spells={'Esoteric Unity', 'Marvel\'s Unity', 'Deviser\'s Unity', 'Transfixer\'s Unity', 'Enticer\'s Unity', 'Phantasmal Unity', 'Arcane Unity', 'Spectral Unity', --[[emu cutoff]]},
        Options={Gem=12}
    },
    {-- melee attack proc. Slot 13 or 2
        Group='nightsterror',
        Spells={'Night\'s Perpetual Terror', 'Night\'s Endless Terror', --[[emu cutoff]]},
        Options={opt='USENIGHTSTERROR', Gem=function() return (not Enchanter:isEnabled('USEALLIANCE') and 13) or (not Enchanter:isEnabled('USECHARM') and 2) or nil end}
    },
    {-- Slot 13
        Group='alliance',
        Spells={'Chromatic Conjunction', 'Chromatic Coalition', 'Chromatic Covenant', 'Chromatic Alliance'},
        Options={opt='USEALLIANCE', Gem=13}
    },

    {Group='mezst2', Spells={'Flummoxing Flash', 'Addling Flash'}}, -- 6 ticks
    {Group='mezae', Spells={'Stupefying Wave', 'Bewildering Wave', 'Neutralizing Wave', 'Bliss of the Nihil'}}, -- targeted AE mez
    {Group='mezaehate', Spells={'Vexing Glance', 'Confounding Glance'}}, -- targeted AE mez + 100% hate reduction
    {Group='mezpbae', Spells={'Wonderment', 'Bewilderment'}},
    {Group='mezpbae2', Spells={'Perilous Confounding', 'Perilous Bewilderment'}}, -- lvl 120
    {Group='mezshield', Spells={'Ward of the Stupefier', 'Ward of the Beguiler', 'Ward of the Deviser'}}, -- mez proc on being hit

    {Group='rune', Spells={'Disquieting Rune', 'Marvel\'s Rune'}}, -- 160k rune, self
    {Group='rune2', Spells={'Rune of Zoraxmen', 'Rune of Tearc', 'Rune III', 'Rune II', 'Rune I'}, Options={Gem=function(lvl) return lvl <= 60 and 8 or nil end}}, -- 90k rune, single target
    {Group='dotrune', Spells={'Aegis of Dhakka', 'Aegis of Xetheg'}}, -- absorb DoT dmg
    {Group='guard', Spells={'Shield of Inescapability', 'Shield of Inevitability', 'Shield of Destiny', 'Shield of Order'}, Options={selfbuff=true}}, -- spell + melee guard
    {Group='dotmiti', Spells={'Deviser\'s Auspice', 'Transfixer\'s Auspice'}}, -- DoT guard
    {Group='spellmiti', Spells={'Aegis of Elmara', 'Aegis of Sefra'}}, -- 20% spell mitigation

    {Group='meleemiti', Spells={'Gloaming Auspice', 'Eclipsed Auspice'}}, -- melee guard, + hate
    {Group='absorbbuff', Spells={'Brimstone Stability', 'Brimstone Endurance'}}, -- increase absorb dmg, + hate
    {Group='aggrorune', Spells={'Esoteric Rune', 'Ghastly Rune'}}, -- single target rune + hate increase
    -- Polyradiant Rune -- hate mod rune, stun proc on fade

    {Group='groupdotrune', Spells={'Legion of Dhakka', 'Legion of Xetheg', 'Legion of Cekenar'}},
    {Group='groupspellrune', Spells={'Legion of Ogna', 'Legion of Liako', 'Legion of Kildrukaun'}},
    {Group='groupaggrorune', Spells={'Gloaming Rune', 'Eclipsed Rune'}}, -- group rune + big nuke/aggro reduction proc

    {Group='debuffdot', Spells={'Dismaying Constriction', 'Perplexing Constriction', 'Confounding Constriction', 'Confusing Constriction', 'Baffling Constriction'}}, -- debuff + nuke + dot
    {Group='manadot', Spells={'Tears of Kasha', 'Tears of Xenacious'}}, -- hp + mana DoT
    {Group='nukerune', Spells={'Chromatic Spike', 'Chromatic Flare'}}, -- 18k nuke + self rune

    {Group='nuke1', Spells={'Polyradiant Assault', 'Polyluminous Assault', 'Colored Chaos'}}, -- 35k nuke
    {Group='aenuke', Spells={'Gravity Roil'}}, -- 23k targeted ae nuke

    {Group='calm', Spells={'Still Mind'}},
    {Group='stunst', Spells={'Dizzying Spindle', 'Dizzying Vortex', 'Dyn\'s Dizzying Draught',  'Whirl till you hurl'}}, -- single target stun
    {Group='stunae', Spells={'Remote Color Calibration', 'Remote Color Conflagration'}},
    {Group='stunpbae', Spells={'Color Calibration', 'Color Conflagration', 'Color Shift', 'Color Flux'}, {Gem=function(lvl) return not Enchanter:get('MEZAE') and lvl <= 60 and 4 or nil end}},
    {Group='stunaerune', Spells={'Polyluminous Rune', 'Polycascading Rune', 'Polyfluorescent Rune', 'Ethereal Rune', 'Arcane Rune'}, Options={selfbuff=true}}, -- self rune, proc ae stun on fade

    {Group='pet', Spells={'Flariton\'s Animation', 'Constance\'s Animation', 'Omica\'s Animation', 'Nureya\'s Animation', 'Gordianus\' Animation', 'Xorlex\'s Animation', 'Seronvall\'s Animation', 'Novak\'s Animation', --[[emu cutoff]]  'Aeidorb\'s Animation', 'Boltran\'s Animation', 'Uleen\'s Animation', 'Sagar\'s Animation', 'Sisna\'s Animation', 'Shalee\'s Animation', 'Kilan\'s Animation', 'Myrcil\'s Animation', 'Juli\'s Animation', 'Pendril\'s Animation'}, Options={}},
    {Group='pethaste', Spells={'Invigorated Minion'}, Options={petbuff=true}},
    -- buffs
    -- {Group='unified', Spells={'Unified Alacrity'}, Options={emu=true, alias='KEI', selfbuff=true}},
    {Group='keigroup', Spells={'Voice of Preordination', 'Voice of Perception', 'Voice of Sagacity', 'Voice of Perspicacity', 'Voice of Precognition', 'Voice of Foresight', 'Voice of Premeditation', 'Voice of Forethought', 'Unified Alacrity', 'Voice of Clairvoyance', 'Voice of Quellious'}, Options={alias='KEI', selfbuff=true}},
    {Group='kei', Spells={'Preordination', 'Scrying Visions', 'Sagacity', 'Foresight', 'Premiditation', 'Forethought', 'Clairovoyance', 'Clarity', 'Breeze'}, Options={alias='SINGLEKEI', selfbuff=function() return not Enchanter.spells.keigroup and true or false end}},
    {Group='grouphaste', Spells={'Hastening of Margator', 'Hastening of Jharin', 'Hastening of Cekenar', 'Hastening of Milyex', 'Hastening of Prokev', 'Hastening of Sviir', 'Hastening of Aransir', 'Hastening of Novak', 'Unified Alacrity', 'Hastening of Salik', 'Vallon\'s Quickening'}, Options={alias='HASTE'}}, -- group haste
    {Group='haste', Spells={'Speed of Margator', 'Speed of Itzal', 'Speed of Cekenar', 'Speed of Milyex', 'Speed of Prokev', 'Speed of Sviir', 'Speed of Aransir', 'Speed of Novak', 'Visions of Grandeur', 'Augmentation', 'Alacrity', 'Quickness'}, Options={alias='SINGLEHASTE'}}, -- single target buff
    -- auras - mana, learners, spellfocus, combatinnate, disempower, rune, twincast
    {Group='twincast', Spells={'Twincast Aura'}, Options={aurabuff=true, condition=function() return Enchanter:get('AURA1') == Enchanter.spells.twincast.Name or Enchanter:get('AURA2') == Enchanter.spells.twincast.Name end}},
    {Group='regen', Spells={'Esoteric Aura', 'Marvel\'s Aura', 'Deviser\'s Aura'}, Options={aurabuff=true, condition=function() return Enchanter:get('AURA1') == Enchanter.spells.regen.Name or Enchanter:get('AURA2') == Enchanter.spells.regen.Name end}}, -- mana + end regen aura
    {Group='spellfocus', Spells={'Intensifying Aura', 'Enhancing Aura', 'Fortifying Aura'}, Options={aurabuff=true, condition=function() return Enchanter:get('AURA1') == Enchanter.spells.spellfocus.Name or Enchanter:get('AURA2') == Enchanter.spells.spellfocus.Name end}}, -- increase dmg of DDs
    {Group='combatinnate', Spells={'Mana Ripple Aura', 'Mana Radix Aura', 'Mana Replication Aura'}, Options={aurabuff=true, condition=function() return Enchanter:get('AURA1') == Enchanter.spells.combatinnate.Name or Enchanter:get('AURA2') == Enchanter.spells.combatinnate.Name end}}, -- dmg proc on spells, Issuance of Mana Radix == place aura at location
    {Group='disempower', Spells={'Arcane Disjunction Aura'}, Options={aurabuff=true, condition=function() return Enchanter:get('AURA1') == Enchanter.spells.disempower.Name or Enchanter:get('AURA2') == Enchanter.spells.disempower.Name end}},
    -- 'Runic Scintillation Aura' -- rune aura
    -- unity buffs
    {Group='shield', Spells={'Shield of Memories', 'Shield of Shadow', 'Shield of Restless Ice', 'Greater Shielding', 'Major Shielding', 'Shielding', 'Lesser Shielding', 'Minor Shielding'}},
    {Group='ward', Spells={'Ward of the Beguiler', 'Ward of the Transfixer'}},

    {Group='spasm', Spells={'Synapsis Spasm', 'Insipid Weakness', 'Listless Power', 'Feckless Might', 'Disempower', 'Ebbing Strength', 'Enfeeblement', 'Weaken'}, Options={debuff=true, opt='USEDEBUFF', emu=true, Gem=function(lvl) return lvl <= 60 and 6 or nil end}},
    {Group='dispel', Spells={'Abashi\'s Disempowerment', 'Recant Magic', 'Nullify Magic', 'Strip Enchantment', 'Cancel Magic', 'Taper Enchantment'}, Options={opt='USEDISPEL'}},
    {Group='slow', Spells={'Tepid Deeds', 'Languid Pace'}, Options={opt='USESLOW', debuff=true, slow=true, Gem=function(lvl) return lvl <= 60 and 2 or nil end}}
}

Enchanter.compositeNames = {['Ecliptic Reinforcement']=true,['Composite Reinforcement']=true,['Dissident Reinforcement']=true,['Dichotomic Reinforcement']=true}
Enchanter.allDPSSpellGroups = {'dot1', 'dot2', 'mindnuke1', 'mindnuke2', 'nuke1', 'nuke2', 'nuke3', 'manadot', 'nukerune', 'debuffdot', 'stunst', 'stunae', 'stunpbae', 'stunaerune'}

Enchanter.Abilities = {
    -- Burns
    {
        Type='Item',
        Name=mq.TLO.InvSlot('Chest').Item.Name(),
        Options={first=true}
    },
    -- {
    --     Type='Item',
    --     Name='Rage of Rolfron',
    --     Options={first=true}
    -- },
    { -- song, 12 minute CD
        Type='AA',
        Name='Illusions of Grandeur',
        Options={first=true}
    },
    { -- 20 minute CD, increase crit for 27 spells
        Type='AA',
        Name='Calculated Insanity',
        Options={first=true}
    },
    { -- buff, 7:30 minute CD
        Type='AA',
        Name='Spire of Enchantment',
        Options={first=true}
    },
    {
        Type='AA',
        Name='Fundament: Second Spire of Enchantment',
        Options={first=true}
    },
    { -- 15min CD
        Type='AA',
        Name='Improved Twincast',
        Options={first=true}
    },
    { -- 15min CD
        Type='AA',
        Name='Chromatic Haze',
        Options={first=true}
    },
    { -- 10 minute CD
        Type='AA',
        Name='Companion\'s Fury',
        Options={first=true}
    },
    { -- 15 minute CD
        Type='AA',
        Name='Companion\'s Fortification',
        Options={first=true}
    },
    { -- decrease melee dmg + DoT
        Type='AA',
        Name='Mental Corruption',
        Options={first=true}
    },

    -- Debuffs
    {
        Type='AA',
        Name='Eradicate Magic',
        Options={debuff=true, opt='USEDISPEL'}
    },
    {
        Type='AA',
        Name='Bite of Tashani',
        Options={debuff=true, opt='USETASHAOE'}
    },
    { -- AE slow on 8 targets
        Type='AA',
        Name='Enveloping Helix',
        Options={debuff=true, opt='USESLOWAOE'}
    },
    { -- single target slow
        Type='AA',
        Name='Slowing Helix',
        Options={debuff=true, opt='USESLOW'}
    },
    {
        Type='Item',
        Name='Serpent of Vindication',
        Options={debuff=true, opt='USESLOW'}
    },

    -- Defensive
    {
        Type='AA',
        Name='Self Stasis',
        Options={fade=true, postcast=function() mq.delay(1000) mq.cmd('/removebuff "Self Stasis"') mq.cmd('/makemevis') end}
    },

    -- Buffs
    {
        Type='AA',
        Name='Dimensional Shield',
        Options={selfbuff=true}
    },
    {
        Type='AA',
        Name='Eldritch Rune',
        Options={selfbuff=true}
    },
    {
        Type='AA',
        Name='Glyph Spray',
        Options={alias='SPRAY'}
    },
    { -- group buff, melee/spell shield that procs rune
        Type='AA',
        Name='Reactive Rune',
        Options={selfbuff=true}
    },
    { -- absorb dmg using mana
        Type='AA',
        Name='Mind over Matter',
        Options={selfbuff=true, opt='USEMINDOVERMATTER'}
    },
    { -- 5min CD, another rune?
        Type='AA',
        Name='Veil of Mindshadow',
        Options={selfbuff=true}
    },
    { -- summon clicky mana heal
        Type='AA',
        Name='Azure Mind Crystal',
        Options={key='azure', summonMinimum=1, nodmz=true, selfbuff=true}
    },
    { -- summon clicky hp heal
        Type='AA',
        Name='Sanguine Mind Crystal',
        Options={key='sanguine', summonMinimum=1, nodmz=true, selfbuff=true}
    },
    {
        Type='AA',
        Name='Auroria Mastery',
        Options={CheckFor='Aura of Bedazzlement', aurabuff=true}
    },
    {
        Type='Item',
        Name='Staff of Eternal Eloquence',
        Options={classes={MAG=true,WIZ=true,NEC=true,ENC=true,RNG=true}, singlebuff=true}
    },
    {
        Type='AA',
        Name='Orator\'s Unity',
        Options={CheckFor='Ward of the Beguiler', selfbuff=true}
    },
    {
        Type='AA',
        Name='Fortify Companion',
        Options={petbuff=true}
    },

    -- Recover
    {
        Type='AA',
        Name='Gather Mana',
        Options={recover=true}
    },
    {
        Type='AA',
        Name='Mana Draw',
        Options={recover=true}
    },

    -- Extras
    {
        Type='AA',
        Name='Beam of Slumber',
        Options={key='mezbeam'}
    },
    { -- 3min single target mez
        Type='AA',
        Name='Noctambulate',
        Options={key='longmez'}
    },
    {
        Type='AA',
        Name='Beguiler\'s Banishment',
        Options={key='aekbblur'}
    },
    {
        Type='AA',
        Name='Beguiler\'s Directed Banishment',
        Options={key='kbblur'}
    },
    {
        Type='AA',
        Name='Blanket of Forgetfulness',
        Options={key='aeblur'}
    },
    {
        Type='AA',
        Name='Summon Companion',
        Options={key='summoncompanion'}
    }
}

function Enchanter:initSpellRotations()
    self:initBYOSCustom()
    self.spellRotations.standard = {}
    -- tash, command, chaotic, deceiving stare, pulmonary grip, mindrift, fortifying aura, mind coil, unity, dissident, mana replication, night's endless terror
    -- entries in the dots table are pairs of {spell id, spell name} in priority order
    table.insert(self.spellRotations.standard, self.spells.dotmiti)
    --table.insert(self.spellRotations.standard, self.spells.meznoblur)
    --table.insert(self.spellRotations.standard, self.spells.mezae)
    table.insert(self.spellRotations.standard, self.spells.dot1)
    table.insert(self.spellRotations.standard, self.spells.dot2)
    table.insert(self.spellRotations.standard, self.spells.mindnuke1)
    table.insert(self.spellRotations.standard, self.spells.mindnuke2)
    table.insert(self.spellRotations.standard, self.spells.nuke1)
    table.insert(self.spellRotations.standard, self.spells.nuke2)
    table.insert(self.spellRotations.standard, self.spells.nuke3)
    table.insert(self.spellRotations.standard, self.spells.composite)
    table.insert(self.spellRotations.standard, self.spells.stunaerune)
    table.insert(self.spellRotations.standard, self.spells.guard)
    table.insert(self.spellRotations.standard, self.spells.nightsterror)
    table.insert(self.spellRotations.standard, self.spells.combatinnate)
end

local function castSynergy()
    if Enchanter.spells.mindnuke1 and not mq.TLO.Me.Song('Beguiler\'s Synergy')() and mq.TLO.Me.SpellReady(Enchanter.spells.mindnuke1.Name)() then
        if mq.TLO.Spell(Enchanter.spells.mindnuke1.Name).Mana() > mq.TLO.Me.CurrentMana() then
            return false
        end
        Enchanter.spells.mindnuke1:use()
        return true
    end
    return false
end

-- composite
-- synergy
-- nuke5
-- dot2
function Enchanter:findNextSpell()
    if self:isEnabled('USEDEBUFF') and self.spells.tash and not mq.TLO.Target.Tashed() and self.spells.tash:isReady() == abilities.IsReady.SHOULD_CAST then return self.spells.tash end
    if self.spells.composite and self.spells.composite:isReady() == abilities.IsReady.SHOULD_CAST then return self.spells.composite end
    if castSynergy() then return nil end
    --if state.emu and self.spells.spasm and self.spells.spasm:isReady() == abilities.IsReady.SHOULD_CAST then return self.spells.spasm end
    if self.spells.nuke5 and self.spells.nuke5:isReady() == abilities.IsReady.SHOULD_CAST then return self.spells.nuke5 end
    if self.spells.dot1 and self.spells.dot1:isReady() == abilities.IsReady.SHOULD_CAST then return self.spells.dot1 end
    if self.spells.dot2 and self.spells.dot2:isReady() == abilities.IsReady.SHOULD_CAST then return self.spells.dot2 end
    if self.spells.nuke4 and self.spells.nuke4:isReady() == abilities.IsReady.SHOULD_CAST then return self.spells.nuke4 end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end

function Enchanter:recover()
    -- modrods
    common.checkMana()
    --if mq.TLO.Me.PctMana() < 20 then
    --    if self.gathermana and self.gathermana:use() then return end
    --end
    --if mq.TLO.Me.PctMana() < 20 then
    --    if self.manadraw and self.manadraw:use() then return end
    --end
    if mq.TLO.Me.PctMana() < 70 and self.azure then
        local cursor = mq.TLO.Cursor()
        if cursor and cursor:find(self.azure.Name) then mq.cmd('/autoinventory') mq.delay(1) end
        local manacrystal = mq.TLO.FindItem(self.azure.Name)
        if manacrystal() then
            abilities.use(abilities.Item:new({Name=manacrystal(), ID=manacrystal.ID()}), self)
        end
    end
    if mq.TLO.Zone.ShortName() ~= 'poknowledge' and mq.TLO.Me.PctMana() < config.get('MANASTONESTART') and mq.TLO.Me.PctHPs() > config.get('MANASTONESTARTHP') then
        local manastone = mq.TLO.FindItem('Manastone')
        if not manastone() then return end
        local manastoneTimer = timer:new((config.get('MANASTONETIME') or 0)*1000)
        while mq.TLO.Me.PctHPs() > config.get('MANASTONESTOPHP') and mq.TLO.Me.PctMana() < 90 do
            mq.cmd('/useitem Manastone')
            if manastoneTimer:expired() then break end
        end
    end
end

local function missing_unity_buffs(name)
    local spell = mq.TLO.Spell(name)
    for i=1,spell.NumEffects() do
        local trigger_spell = spell.Trigger(i)
        if not mq.TLO.Me.Buff(trigger_spell.Name())() then return true end
    end
    return false
end

--[[
#Event CAST_IMMUNE                 "Your target has no mana to affect#*#"
#Event CAST_IMMUNE                 "Your target is immune to changes in its run speed#*#"
#Event CAST_IMMUNE                 "Your target is immune to snare spells#*#"
#Event CAST_IMMUNE                 "Your target is immune to the stun portion of this effect#*#"
#Event CAST_IMMUNE                 "Your target looks unaffected#*#"
]]--

return Enchanter