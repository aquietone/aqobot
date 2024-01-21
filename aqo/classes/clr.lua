local mq = require('mq')
local class = require('classes.classbase')
local timer = require('utils.timer')
local abilities = require('ability')
local common = require('common')
local state = require('state')

local Cleric = class:new()

--[[
    https://docs.google.com/document/d/1CmsduTMq79UzZdqrA2D_njt0IxD7RwwTVrj9_wkZukc/edit
    https://forums.daybreakgames.com/eq/index.php?threads/cleric-guide.288234/#post-4193435

    table.insert(self.healAbilities, common.getAA('Burst of Life'))
    table.insert(self.healAbilities, common.getAA('Blessing of Sanctuary'))
    table.insert(self.healAbilities, common.getAA('Sanctuary'))
    table.insert(self.healAbilities, common.getAA('Beacon of Life'))

    table.insert(self.healAbilities, common.getAA('Focused Celestial Regeneration'))
    table.insert(self.healAbilities, common.getAA('Exquisite Benediction'))
    table.insert(self.healAbilities, common.getAA('Celestial Regeneration'))

    table.insert(self.healAbilities, common.getAA('Divine Guardian')) -- like DI, stacks

    table.insert(self.recover, common.getAA('Vetunka\'s Perseverance'))
    table.insert(self.recover, common.getAA('Quiet Prayer'))

    common.getAA('Blessing of Resurrection')
    common.getAA('Divine Resurrection')
    common.getAA('Call of the Herald')

    table.insert(self.healAbilities, common.getAA('Divine Arbitration'))
    table.insert(self.healAbilities, common.getItem('Aegis of Superior Divinity'))
    table.insert(self.healAbilities, common.getItem('Harmony of the Soul'))

    table.insert(self.burnAbilities, common.getAA('Divine Peace'))
    
    table.insert(self.cures, common.getAA('Radiant Cure'))
    table.insert(self.cures, common.getAA('Group Purified Soul'))
    table.insert(self.cures, common.getAA('Purified Spirits'))
    table.insert(self.cures, common.getAA('Purify Soul'))
    table.insert(self.cures, common.getAA('Ward of Purity'))

    table.insert(self.defensiveAbilities, common.getAA('Bestow Divine Aura'))
    table.insert(self.defensiveAbilities, common.getAA('Divine Aura'))
    table.insert(self.defensiveAbilities, common.getAA('Divine Retribution'))

]]
function Cleric:init()
    self.spellRotations = {standard={},custom={}}
    self.classOrder = {'heal', 'rez', 'assist', 'debuff', 'mash', 'cast', 'burn', 'recover', 'buff', 'rest'}
    self:initBase('CLR')

    self:initClassOptions()
    self:loadSettings()
    self:initSpellLines()
    self:initSpellRotations()
    self:initHeals()
    self:initCures()
    self:initBuffs()
    self:initBurns()
    self:initDPSAbilities()
    self:initDebuffs()
    self:initRecoverAbilities()
    self:addCommonAbilities()

    self.rezAbility = common.getAA('Blessing of Resurrection')
end

function Cleric:initClassOptions()
    self:addOption('USEYAULP', 'Use Yaulp', false, nil, 'Toggle use of Yaulp', 'checkbox', nil, 'UseYaulp', 'bool')
    self:addOption('USESPLASH', 'Use Splash', true, nil, 'Toggle use of splash heal + twincast nuke', 'checkbox', nil, 'UseSplash', 'bool')
    self:addOption('USEVIE', 'Use Vie', true, nil, 'Toggle use of Vie spell line', 'checkbox', nil, 'UseVie', 'bool')
    self:addOption('USEHAMMER', 'Use Hammer', false, nil, 'Toggle use of summoned hammer pet', 'checkbox', nil, 'UseHammer', 'bool')
    -- HoTs only mem'd in BYOS
    self:addOption('USEHOTGROUP', 'Use Group HoT', true, nil, 'Toggle use of group HoT', 'checkbox', nil, 'UseHoTGroup', 'bool')
    self:addOption('USESTUN', 'Use Stun', true, nil, 'Toggle use of stuns', 'checkbox', nil, 'UseStun', 'bool')
    -- use mark if mem'd in BYOS, otherwise use retort line to apply reverse DS with USERETORT
    --self:addOption('USEDEBUFF', 'Use Reverse DS', true, nil, 'Toggle use of Mark reverse DS', 'checkbox', nil, 'UseDebuff', 'bool')
    self:addOption('USESYMBOL', 'Use Symbol', false, nil, 'Toggle use of Symbol buff line', 'checkbox', nil, 'UseSymbol', 'bool')
    self:addOption('USERETORT', 'Use Retort', true, nil, 'Toggle use of Retort spell line', 'checkbox', nil, 'UseRetort', 'bool')
    self:addOption('USECURES', 'Use Cures', true, nil, 'Toggle use of cure spells', 'checkbox', nil, 'UseCures', 'bool')
end
--[[
-- dps burns
common.getAA('Celestial Hammer') -- hammer pet 60 seconds, 10 min cd, timer 12
-- nuke burns
common.getAA('Battle Frenzy') -- 100% nuke crit, inc crit dmg, 15 min cd, timer 74
common.getAA('Turn Undead') -- large undead nuke + dot, 2:30 cd, timer 6
-- melee burns
common.getAA('Divine Avatar') -- melee burn, +4k hp regen for 3min, inc nuke crits, 9 min cd, timer 10
common.getAA('Divine Retribution') -- melee burn, stun procs, 20 min cd, timer 13

-- heal burns
common.getAA('Celestial Rapidity') -- 50% spell haste for 36 seconds, 10 min cd, timer 73
common.getAA('Channeling of the Divine') -- twincast 19 spells, 10 min cd, timer 43
common.getAA('Flurry of Life') -- inc instant heals 35%, 15 min cd, timer 32
common.getAA('Spire of the Vicar') -- inc healing, reduce inc melee dmg, inc crit chance, inc crit dmg, 7:30 cd, timer 40
common.getAA('Forceful Rejuvenation') -- 
common.getAA('Healing Frenzy') -- 100% crit heals for 18 seconds, 15 min cd, timer 63
common.getAA('Silent Casting') -- 

-- group heals
common.getAA('Beacon of Life') -- 39k group heal, 3 min cd, timer 17
common.getAA('Celestial Regeneration') -- large group HoT, 7:30 cd, timer 3
common.getAA('Divine Arbitration') -- balances group hp then heals 135k across group, 3 min, timer 9
common.getAA('Exquisite Benediction') -- 13k heal per tick,300 seconds, stationary ward, 20 min cd, timer 11

-- utilities
common.getAA('Bestow Divine Aura') -- targeted DA, 5 min cd, timer 60
common.getAA('Blessing of Resurrection') -- normal rez
common.getAA('Divine Aura') -- self DA, 5 min cd, timer 4
common.getAA('Divine Resurrection') -- 100% rez
common.getAA('Repel the Wicked') -- knockback+memblur, 1 min cd, timer 39
common.getAA('Call of the Herald') -- call to corpse
common.getAA('Divine Peace') -- fade
common.getAA('Holy Step') -- leap
common.getAA('Group Perfected Invisibility to Undead') -- 
common.getAA('Improved Twincast') -- twincast 21 damage spells, 15 min cd, timer 76
common.getAA('Innate Invis to Undead') -- 
common.getAA('Mass Group Buff') -- 
common.getAA('Tranquil Blessings') -- 

-- non-tank oh shit heals
common.getAA('Blessing of Sanctuary') -- 82k heal + drops target to bottom of agro, 15 min cd, timer 16

-- single heals
common.getAA('Burst of Life') -- 53k heal, 3 min cd, timer 44
common.getAA('Divine Guardian') -- large heal if target drops below 30% hp, cant recast for 1 min after it procs, 5 min cd, timer 75
common.getAA('Focused Celestial Regeneration') -- large single target HoT, 5 min cd, timer 61

-- self heals
common.getAA('Sanctuary') -- 165k self heal + drops self to lowest agro, 15 min cd, timer 14

-- cures
common.getAA('Group Purify Soul') -- group cure all, 15 min cd, timer 34
common.getAA('Purify Soul') -- single target cure all, 5 min cd, timer 7
common.getAA('Ward of Purity') -- stationary ward that cures for 300 seconds, 20 min cd, timer 11
common.getAA('Purified Spirits') -- self cure all, 2 min cd, timer 36
common.getAA('Radiant Cure') -- group cure poison, disease, curse, 1 min cd, timer 8

-- rest
common.getAA('Quiet Prayer') -- consume 90k mana to heal 90k hp+mana to target, 20 min cd, timer 41
common.getAA('Veturika\'s Presence') -- self only restore 90k hp+mana, 20 min cd, timer 41
common.getAA('Yaulp') -- casts highest yaulp spell

-- buffs
common.getAA('Saint\'s Unity') -- self buff, casts self armor buff line
]]
Cleric.SpellLines = {
    {-- multiple remedies main heals lvl 101+ or just 1 remedy below lvl 100. Slot 1, 2, 5
        Group='remedy',
        NumToPick=mq.TLO.Me.Level() < 101 and 1 or 2,
        Spells={'Avowed Remedy', 'Guileless Remedy', 'Sincere Remedy', 'Merciful Remedy', 'Spiritual Remedy', --[[emu cutoff]] 'Sacred Remedy', 'Pious Remedy', 'Supernal Remedy', 'Remedy'},
        Options={Gems={1,2}, tank=true, panic=true, regular=true}
    },
    {-- emu or before remedies standard heal. Slot 2, otherwise slot 11
        Group='lightheal',
        Spells={'Avowed Light', 'Fervent Light', 'Sincere Light', 'Merciful Light', 'Ardent Light', 'Reverent Light', 'Earnest Light', 'Devout Light', --[[emu cutoff]] 'Ancient: Hallowed Light', 'Pious Light', 'Holy Light', 'Divine Light', 'Healing Light', 'Superior Healing', 'Healing', 'Light Healing', 'Minor Healing'},
        Options={Gem=function() return mq.TLO.Me.Level() < 101 and 2 or 11 end, tank=true, panic=true, regular=true}
    },
    {-- Heal target + nuke targets target. Slot 3, 4
        Group='intervention',
        NumToPick=2,
        Spells={'Avowed Intervention', 'Atoned Intervention', 'Sincere Intervention', 'Merciful Intervention', 'Mystical Intervention', --[[emu cutoff]] },
        Options={Gems={3,4}, tank=true, panic=true, regular=true}
    },
    {-- Large heal after 18 seconds. Slot 5
        Group='promised',
        Spells={'Promised Redediation', 'Promised Reclamation', 'Promised Redemption', 'Promised Remedy', 'Promised Rehabilitation', --[[emu cutoff]] },
        Options={Gem=5, tank=true}
    },
    {-- large proc heal on near death. Slot 6
        Group='di',
        Spells={'Divine Interference', 'Divine Mediation', 'Divine Intermediation', 'Divine Imposition', 'Divine Indemnification', --[[emu cutoff]] 'Divine Intervention'},
        Options={Gem=6}
    },
    {-- Large quick heal, heals more the lower the targets hp. Slot 7
        Group='seventeenth',
        Spells={'Eighteenth Rejuvenation', 'Seventeenth Rejuvenation', 'Sixteenth Serenity', --[[emu cutoff]] },
        Options={Gem=7,tank=true,}
    },
    {-- targeted aoe heal. Slot 7
        Group='splash',
        Spells={'Acceptance Splash', 'Refreshing Splash', 'Restoring Splash', 'Mending Splash', 'Convalescent Splash', --[[emu cutoff]] },
        Options={opt='USESPLASH', Gem=7, tank=true, group=true, threshold=3, --[[condition=function() check for twincast end]]}
    },
    {-- Single target cure all. Slot 7
        Group='cureall',
        Spells={'Sanctified Blood', 'Expurgated Blood', 'Unblemished Blood', --[[emu cutoff]] },
        Options={opt='USECURES',Gem=function() return not Cleric:isEnabled('USESPLASH') and 7 or nil end,curse=true,poison=true,disease=true,corruption=true},
    },
    {-- Regular group heal, slower than syllable. Slot 8
        Group='groupheal',
        Spells={'Word of Acceptance', 'Word of Redress', 'Word of Soothing', 'Word of Mending', 'Word of Convalescence', --[[emu cutoff]] },
        Options={Gem=8, threshold=3, group=true},
    },
    {-- Group heal with cure component. Slot 8
        Group='grouphealcure',
        Spells={'Word of Greater Vivification', 'Word of Greater Rejuvenation', 'Word of Greater Replenishment', 'Word of Greater Restoration', 'Word of Greater Reformation', --[[emu cutoff]] },
        Options={opt='USECURES', Gem=function() return Cleric:isEnabled('USESPLASH') and 8 or nil end, threshold=3, regular=true, single=true, group=true, pct=70}
    },
    {-- Regular group heal. Slot 9
        Group='grouphealquick',
        Spells={'Syllable of Acceptance', 'Syllable of Invigoration', 'Syllable of Soothing', 'Syllable of Mending', 'Syllable of Convalescence', --[[emu cutoff]] 'Word of Vivification', 'Word of Replenishment', 'Word of Redemption'},
        Options={Gem=9, threshold=3, regular=true, single=true, group=true, pct=70}
    },
    {-- Slot 10
        Group='composite',
        Spells={'Ecliptic Blessing', 'Composite Blessing', 'Dissident Blessing', 'Dichotomic Blessing'},
        Options={Gem=10, tank=true, panic=true}
    },
    -- {-- TODO: when to use? maybe lower levels? slower heal. Slot 11
    --     Group='renewal',
    --     Spells={'Heroic Renewal', 'Determined Renewal', 'Dire Renewal', 'Furial Renewal', 'Fervid Renewal', 'Desperate Renewal'},
    --     Options={Gem=5, tank=true, panic=true}
    -- },
    {-- Heal proc on target + reverse DS on targets target. Slot 11
        Group='retort',
        Spells={'Axoeviq\'s Retort', 'Jorlleag\'s Retort', 'Curate\'s Retort', 'Vicarum\'s Retort', --[[emu cutoff]] },
        Options={Gem=function() return not Cleric:isEnabled('USESPLASH') and 11 or nil end, opt='USERETORT', classes={WAR=true,SHD=true,PAL=true}}
    },
    {-- twincast nuke, only use with splash. Slot 11
        Group='rebuke',
        Spells={'Unyielding Admonition', 'Unyielding Rebuke', 'Unyielding Censure', 'Unyielding Judgement', --[[emu cutoff]] },
        Options={opt='USESPLASH', Gem=11, condition=function() mq.TLO.Me.SpellReady(Cleric.spells.splash.Name)() end}
    },
    {-- heals on break, Slot 12
        Group='ward',
        Spells={'Ward of Commitment', 'Ward of Persistence', 'Ward of Righteousness', 'Ward of Assurance', 'Ward of Surety', --[[emu cutoff]] },
        Options={Gem=12, tank=true, regular=true}
    },
    {-- Slot 12
        Group='alliance',
        Spells={'Sincere Coalition', 'Divine Alliance'},
        Options={opt='USEALLIANCE', Gem=12, tank=true, regular=true}
    },
    {-- dmg absorb, proc heal on wearer and stun on wearers target. 72 charges. Slot 13
        Group='shining',
        Spells={'Shining Steel', 'Shining Fortitude', 'Shining Aegis', 'Shining Fortress', 'Shining Bulwark', --[[emu cutoff]] },
        Options={Gem=13, classes={CLR=true,WAR=true,SHD=true,PAL=true}},
    },
    {-- Don't keep mem'd, 12 charges. Group heal proc on big aoe. Same as consequence but not part of the stacking group. Swap gem
        Group='response',
        Spells={'Divine Response', --[[emu cutoff]] },
        Options={swap=true}
    },
    {-- Don't keep mem'd, 12 charges. Group heal proc on big aoe. Swap gem
        Group='consequence',
        Spells={'Divine Contingency', 'Divine Consequence', 'Divine Reaction', --[[emu cutoff]] },
        Options={opt='USERESPONSE', swap=true}
    },

    -- Buffs
    {Group='aura', Spells={'Bastion of Divinity', 'Aura of Divinity'}, Options={aura=true}},
    {Group='spellhaste', Spells={'Hand of Devotion', 'Hand of Devoutness', 'Hand of Reverence', 'Hand of Sanctity', 'Hand of Zeal', --[[emu cutoff]] 'Aura of Devotion'}, Options={classes={CLR=true,DRU=true,SHM=true,MAG=true,ENC=true,WIZ=true,NEC=true}}},
    {Group='groupaego', Spells={'Unified Hand of Infallibility', 'Unified Hand of Persistence', 'Unified Hand of Righteousness', 'Unified Hand of Assurance', 'Unified Hand of Surety', --[[emu cutoff]] 'Hand of Conviction', 'Hand of Virtue', 'Blessing of Aegolism', 'Blessing of Temperance'}, Options={classes={CLR=true,WAR=true,SHD=true,PAL=true}}},
    {Group='singleaego', Spells={--[[emu cutoff]] 'Conviction', 'Virtue', 'Aegolism', 'Temperance', 'Bravery'}, Options={classes={CLR=true,WAR=true,SHD=true,PAL=true}}},
    {Group='groupsymbol', Spells={'Unified Hand of Helmsbane', 'Unified Hand of the Diabo', 'Unified Hand of Jorlleag', 'Unified Hand of Emra', 'Unified Hand of Nonia', --[[emu cutoff]] 'Balikor\'s Mark', 'Kazad\'s Mark', 'Marzin\'s Mark', 'Naltron\'s Mark'}, Options={opt='USESYMBOL', classes={CLR=true,DRU=true,SHM=true,MAG=true,ENC=true,WIZ=true,NEC=true}, condition=function() return mq.TLO.SpawnCount('pc group class druid')() > 0 end}},
    {Group='singlesymbol', Spells={--[[emu cutoff]] 'Symbol of Balikor', 'Symbol of Kazad', 'Symbol of Marzin', 'Symbol of Naltron', 'Symbol of Pinzarn', 'Symbol of Ryltan', 'Symbol of Transal'}, Options={opt='USESYMBOL', classes={CLR=true,DRU=true,SHM=true,MAG=true,ENC=true,WIZ=true,NEC=true}, condition=function() return mq.TLO.SpawnCount('pc group class druid')() > 0 end}},
    {Group='armor', Spells={'Armor of the Avowed', 'Armor of Penance', 'Armor of Sincerity', 'Armor of the Merciful', 'Armor of the Ardent', 'Armor of the Pious', 'Armor of the Zealot'}},
    -- Group buff, cast on self when down, damage absorb then heal proc on fade. absorbs 4x non-greater version. Swap gem
    {Group='bigvie', Spells={'Rallied Greater Aegis of Vie', 'Rallied Greater Blessing of Vie', 'Rallied Greater Protection of Vie', 'Rallied Greater Guard of Vie', 'Rallied Greater Ward of Vie', --[[emu cutoff]] }, Options={opt='USEVIE'}},
    -- Just use greater line instead
    -- {Group='vie', Spells={'Rallied Citadel of Vie', 'Rallied Sanctuary of Vie'}, Options={opt='USEVIE'}},

    -- Other stuff, BYOS mostly
    {-- Heal target + nuke targets target. Slot 3, 4
        Group='contravention',
        NumToPick=2,
        Spells={'Avowed Contavention', 'Atoned Contavention', 'Sincere Contavention', 'Merciful Contavention', 'Mystical Contavention', --[[emu cutoff]] },
        Options={opt='USENUKES'}
    },
    {Group='grouphotcure', Spells={'Avowed Acquittal', 'Devout Acquittal', 'Sincere Acquittal', 'Merciful Acquittal', 'Ardent Acquittal', --[[emu cutoff]] }, Options={opt='USEHOTGROUP', grouphot=true}},
    {Group='grouphot', Spells={'Elixir of Realization', 'Elixir of Benevolence', 'Elixir of Transcendence', 'Elixir of Wulthan', 'Elixir of the Seas', --[[emu cutoff]] 'Elixir of Divinity'}, Options={opt='USEHOTGROUP', grouphot=true}},
    {Group='hottank', Spells={--[[emu cutoff]] 'Pious Elixir', 'Holy Elixir', 'Celestial Healing', 'Celestial Health', 'Celestial Remedy'}, Options={opt='USEHOTTANK', hot=true}},
    {Group='hotdps', Spells={--[[emu cutoff]] 'Pious Elixir', 'Holy Elixir', 'Celestial Healing', 'Celestial Health', 'Celestial Remedy'}, Options={opt='USEHOTDPS', hot=true}},
    {Group='issuance', Spells={'Issuance of Heroism', 'Issuance of Conviction', 'Issuance of Sincerity', 'Issuance of Mercy', 'Issuance of Spirit', --[[emu cutoff]] }}, -- stationary ward heal, requires enemy on target
    {Group='mark', Spells={'Mark of Thormir', 'Mark of Ezra', 'Mark of Wenglawks', 'Mark of Shandral', 'Mark of the Vicarum', 'Mark of the Blameless', 'Mark of the Righteous', 'Mark of Kings', 'Mark of Karn', 'Mark of Retribution'}, Options={opt='USEDEBUFF'}},
    {Group='yaulp', Spells={'Yaulp VI'}, Options={combat=true, ooc=false, opt='USEYAULP'}},
    {Group='hammerpet', Spells={'Unswerving Hammer of Justice'}, Options={Gem=11, opt='USEHAMMER'}},
    {Group='rgc', Spells={'Remove Greater Curse'}, Options={curse=true}},
    {Group='stun', Spells={'Vigilant Condemnation', 'Sound of Divinity', 'Shock of Wonder', 'Holy Might', 'Stun'}, Options={opt='USESTUN'}},
    {Group='aestun', Spells={'Silent Dictation'}},
    {Group='da', Spells={'Divine Bulwark', 'Divine Keep', 'Divine Indemnity', 'Divine Haven', 'Divine Fortitude', 'Divine Eminence', 'Divine Destiny', 'Divine Custody', --[[emu cutoff]] 'Divine Barrier', 'Divine Aura'}},
}

Cleric.allDPSSpellGroups = {'rebuke', 'contravention', 'stun', 'aestun'}

function Cleric:initSpellRotations()
    self:initBYOSCustom()
    table.insert(self.spellRotations.standard, self.spells.stun)
end

function Cleric:initHeals()
    table.insert(self.healAbilities, common.getAA('Burst of Life', {panic=true}))
    table.insert(self.healAbilities, common.getItem('Harmony of the Soul', {panic=true}))
    table.insert(self.healAbilities, common.getAA('Divine Arbitration', {panic=true}))
    if mq.TLO.Me.Level() >= 101 then
        table.insert(self.healAbilities, self.spells.remedy1)
        table.insert(self.healAbilities, self.spells.remedy2)
    else
        table.insert(self.healAbilities, self.spells.lightheal)
    end
    table.insert(self.healAbilities, self.spells.splash)
    table.insert(self.healAbilities, self.spells.intervention1)
    table.insert(self.healAbilities, self.spells.intervention2)
    table.insert(self.healAbilities, self.spells.composite)
    if mq.TLO.Me.Level() < 101 then
        table.insert(self.healAbilities, self.spells.remedy1)
    else
        table.insert(self.healAbilities, self.spells.remedy3)
    end
    table.insert(self.healAbilities, self.spells.grouphealquick)
    table.insert(self.healAbilities, self.spells.groupheal)
    table.insert(self.healAbilities, self.spells.grouphealcure)
    table.insert(self.healAbilities, self.spells.grouphot)
    -- table.insert(self.healAbilities, common.getItem('Weighted Hammer of Conviction', {tank=true, regular=true, panic=true, pet=60}))
    -- table.insert(self.healAbilities, self.spells.hottank)
    -- table.insert(self.healAbilities, self.spells.hotdps)
end

function Cleric:initCures()
    table.insert(self.cures, self.spells.cureall)
    table.insert(self.cures, self.spells.grouphealcure)
    table.insert(self.cures, self.radiant)
    table.insert(self.cures, self.spells.rgc)
end

function Cleric:initBuffs()
    -- Project Lazarus only
    local aaAura = common.getAA('Spirit Mastery', {CheckFor='Aura of Pious Divinity'})
    if aaAura then
        table.insert(self.auras, aaAura)
    else
        table.insert(self.auras, self.spells.aura)
    end

    table.insert(self.selfBuffs, self.spells.response)
    table.insert(self.selfBuffs, self.spells.consequence)

    table.insert(self.selfBuffs, self.spells.yaulp)
    table.insert(self.selfBuffs, self.spells.armor)
    table.insert(self.selfBuffs, self.spells.spellhaste)
    table.insert(self.selfBuffs, self.spells.groupsymbol)
    table.insert(self.selfBuffs, self.spells.groupaego)
    table.insert(self.selfBuffs, common.getItem('Earring of Pain Deliverance', {CheckFor='Reyfin\'s Random Musings'}))
    table.insert(self.selfBuffs, common.getItem('Xxeric\'s Matted-Fur Mask', {CheckFor='Reyfin\'s Racing Thoughts'}))

    table.insert(self.singleBuffs, self.spells.retort)
    table.insert(self.singleBuffs, self.spells.shining)

    if self.spells.groupaego then
        table.insert(self.singleBuffs, self.spells.groupaego)
    else
        table.insert(self.singleBuffs, self.spells.singleaego)
    end
    if self.spells.groupsymbol then
        table.insert(self.singleBuffs, self.spells.groupsymbol)
    else
        table.insert(self.singleBuffs, self.spells.singlesymbol)
    end

    self:addRequestAlias(self.spells.singleaego, 'SINGLEAEGO')
    self:addRequestAlias(self.spells.groupaego, 'AEGO')
    self:addRequestAlias(self.spells.singlesymbol, 'SINGLESYMBOL')
    self:addRequestAlias(self.spells.groupsymbol, 'SYMBOL')
    self:addRequestAlias(self.spells.spellhaste, 'SPELLHASTE')
    self:addRequestAlias(self.spells.di, 'DI')
    self:addRequestAlias(self.radiant, 'RC')
    self.cr = common.getAA('Celestial Regeneration')
    self:addRequestAlias(self.cr, 'CR')
    self.focusedcr = common.getAA('Focused Celestial Regeneration')
    self:addRequestAlias(self.focusedcr, 'FCR')
end

function Cleric:initBurns()
    if state.emu then
        table.insert(self.burnAbilities, common.getAA('Celestial Rapidity'))
        --table.insert(self.burnAbilities, common.getAA('Celestial Regeneration'))
        table.insert(self.burnAbilities, common.getAA('Exquisite Benediction'))
        table.insert(self.burnAbilities, common.getAA('Flurry of Life'))
        if state.emu then
            table.insert(self.burnAbilities, common.getAA('Fundament: Second Spire of Divinity'))
        else
            table.insert(self.burnAbilities, common.getAA('Spire of the Vicar'))
        end
        --table.insert(self.burnAbilities, common.getAA('Healing Frenzy'))
        table.insert(self.burnAbilities, common.getAA('Improved Twincast'))

        --table.insert(self.burnAbilities, common.getAA('Focused Celestial Regeneration'))
    else
        table.insert(self.burnAbilities, common.getAA('Silent Casting'))
        table.insert(self.burnAbilities, common.getAA('Channeling the Divine')) -- twincast heals
        table.insert(self.burnAbilities, common.getAA('Healing Frenzy')) -- 100% chance to crit heal, doesn't stack with fierce eye crit mod or auspice or intensity
        table.insert(self.burnAbilities, common.getAA('Flurry of Life')) -- increases base heals by 35%
        table.insert(self.burnAbilities, common.getAA('Celestial Rapidity')) -- healing spell haste, pair with war Imperator's Command and Healing Frenzy
        table.insert(self.burnAbilities, common.getAA('Spire of the Vicar'))

        -- DPS burns
        -- table.insert(self.burnAbilities, common.getAA('Improved Twincast'))
        -- table.insert(self.burnAbilities, common.getAA('Divine Avatar'))
        -- table.insert(self.burnAbilities, common.getAA('Battle Frenzy'))
        -- table.insert(self.burnAbilities, common.getAA('Turn Undead'))
        -- table.insert(self.burnAbilities, common.getAA('Celestial Hammer'))
    end
end

function Cleric:initDPSAbilities()
    table.insert(self.DPSAbilities, self.spells.rebuke)
    table.insert(self.DPSAbilities, self.spells.hammerpet)
end

function Cleric:initDebuffs()
    table.insert(self.debuffs, self.spells.mark)
end

function Cleric:initRecoverAbilities()
    self.qm = common.getAA('Quiet Miracle', {mana=true, threshold=15, combat=true})
    table.insert(self.recoverAbilities, self.qm)
    self:addRequestAlias(self.qm, 'QM')
end

Cleric.compositeNames = {['Ecliptic Blessing']=true, ['Composite Blessing']=true, ['Dissident Blessing']=true, ['Dichotomic Blessing']=true}

return Cleric