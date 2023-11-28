--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
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
    self.spellRotations = {standard={}}
    self.classOrder = {'heal', 'rez', 'assist', 'debuff', 'mash', 'cast', 'burn', 'recover', 'buff', 'rest'}
    self:initBase('clr')


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

    self.rezAbility = common.getAA('Blessing of Resurrection')
end

function Cleric:initClassOptions()
    self:addOption('USEYAULP', 'Use Yaulp', false, nil, 'Toggle use of Yaulp', 'checkbox', nil, 'UseYaulp', 'bool')
    self:addOption('USEHAMMER', 'Use Hammer', false, nil, 'Toggle use of summoned hammer pet', 'checkbox', nil, 'UseHammer', 'bool')
    self:addOption('USEHOTGROUP', 'Use Group HoT', true, nil, 'Toggle use of group HoT', 'checkbox', nil, 'UseHoTGroup', 'bool')
    self:addOption('USESTUN', 'Use Stun', true, nil, 'Toggle use of stuns', 'checkbox', nil, 'UseStun', 'bool')
    self:addOption('USEDEBUFF', 'Use Reverse DS', true, nil, 'Toggle use of Mark reverse DS', 'checkbox', nil, 'UseDebuff', 'bool')
end

function Cleric:initSpellLines()
    if state.emu then
        self:addSpell('heal', {'Ancient: Hallowed Light', 'Pious Light', 'Holy Light', 'Divine Light', 'Healing Light', 'Superior Healing', 'Healing', 'Light Healing', 'Minor Healing'}, {tank=true, panic=true, regular=true})
        --self:addSpell('remedy', {'Pious Remedy', 'Supernal Remedy', 'Remedy'}, {regular=true, panic=true, pet=60})
        self:addSpell('desperate', {'Desperate Renewal'}, {panic=true, pet=15})
        self:addSpell('aura', {'Aura of Divinity'}, {aura=true})
        self:addSpell('yaulp', {'Yaulp VI'}, {combat=true, ooc=false, opt='USEYAULP'})
        self:addSpell('armor', {'Armor of the Pious', 'Armor of the Zealot'})
        self:addSpell('spellhaste', {'Aura of Devotion'})
        self:addSpell('hammerpet', {'Unswerving Hammer of Justice'}, {opt='USEHAMMER'})
        self:addSpell('groupheal', {'Word of Vivification', 'Word of Replenishment', 'Word of Redemption'}, {threshold=3, regular=true, single=true, group=true, pct=70})
        self:addSpell('hottank', {'Pious Elixir', 'Holy Elixir', 'Celestial Healing', 'Celestial Health', 'Celestial Remedy'}, {opt='USEHOTTANK', hot=true})
        self:addSpell('hotdps', {'Pious Elixir', 'Holy Elixir', 'Celestial Healing', 'Celestial Health', 'Celestial Remedy'}, {opt='USEHOTDPS', hot=true})
        self:addSpell('hotgroup', {'Elixir of Divinity'}, {opt='USEHOTGROUP', grouphot=true})
        self:addSpell('groupaego', {'Hand of Conviction', 'Hand of Virtue', 'Blessing of Aegolism', 'Blessing of Temperance'}, {classes={WAR=true,SHD=true,PAL=true}})
        self:addSpell('singleaego', {'Conviction', 'Virtue', 'Aegolism', 'Temperance', 'Bravery'}, {classes={WAR=true,SHD=true,PAL=true}})
        self:addSpell('symbol', {'Symbol of Balikor', 'Symbol of Kazad', 'Symbol of Marzin', 'Symbol of Naltron', 'Symbol of Pinzarn', 'Symbol of Ryltan', 'Symbol of Transal'}, {classes={CLR=true,DRU=true,SHM=true,MAG=true,ENC=true,WIZ=true,NEC=true}})
        self:addSpell('groupsymbol', {'Balikor\'s Mark', 'Kazad\'s Mark', 'Marzin\'s Mark', 'Naltron\'s Mark'}, {classes={CLR=true,DRU=true,SHM=true,MAG=true,ENC=true,WIZ=true,NEC=true}})
        self:addSpell('di', {'Divine Intervention'})
        self:addSpell('rgc', {'Remove Greater Curse'}, {curse=true})
        self:addSpell('stun', {'Vigilant Condemnation', 'Sound of Divinity', 'Shock of Wonder', 'Holy Might', 'Stun'}, {opt='USESTUN'})
        self:addSpell('aestun', {'Silent Dictation'})
        self:addSpell('mark', {'Mark of the Blameless', 'Mark of the Righteous', 'Mark of Kings', 'Mark of Karn', 'Mark of Retribution'}, {opt='USEDEBUFF'})
    else
        self:addSpell('lightheal', {'Ancient: Hallowed Light', 'Sacred Light', 'Pious Light', 'Holy Light', 'Divine Light', 'Healing Light', 'Superior Healing', 'Healing', 'Light Healing', 'Minor Healing'}, {tank=true, panic=true, regular=true})
        self:addSpell('remedy1', {'Avowed Remedy', 'Guileless Remedy', 'Sincere Remedy', 'Merciful Remedy', 'Spiritual Remedy', 'Sacred Remedy', 'Pious Remedy', 'Supernal Remedy', 'Remedy'}, {tank=true, panic=true, regular=true})
        self:addSpell('remedy2', {'Guileless Remedy', 'Sincere Remedy', 'Merciful Remedy', 'Spiritual Remedy'}, {tank=true, panic=true, regular=true})
        self:addSpell('intervention1', {'Avowed Intervention', 'Atoned Intervention', 'Sincere Intervention', 'Merciful Intervention', 'Mystical Intervention'}, {tank=true, panic=true, regular=true})
        self:addSpell('intervention2', {'Atoned Intervention', 'Sincere Intervention', 'Merciful Intervention', 'Mystical Intervention'}, {tank=true, panic=true, regular=true})
        -- Slot 5
        self:addSpell('renewal', {'Heroic Renewal', 'Determined Renewal', 'Dire Renewal', 'Furial Renewal', 'Fervid Renewal', 'Desperate Renewal'}, {tank=true, panic=true}) -- slower heal
        self:addSpell('remedy3', {'Merciful Remedy'}) -- faster heal
        -- Slot 6
        self:addSpell('issuance', {'Issuance of Heroism', 'Issuance of Conviction', 'Issuance of Sincerity', 'Issuance of Mercy', 'Issuance of Spirit'})
        self:addSpell('splash', {'Acceptance Splash', 'Refreshing Splash', 'Restoring Splash', 'Mending Splash', 'Convalescent Splash'})
        self:addSpell('groupheal', {'Syllable of Acceptance', 'Syllable of Invigoration', 'Syllable of Soothing', 'Syllable of Mending', 'Syllable of Convalescence', 'Word of Vivification', 'Word of Replenishment', 'Word of Redemption'})
        self:addSpell('ward', {'Ward of Commitment', 'Ward of Persistence', 'Ward of Righteousness', 'Ward of Assurance', 'Ward of Surety'}) -- heals on break
        self:addSpell('composite', {'Ecliptic Blessing', 'Composite Blessing', 'Dichotomic Blessing'})
        self:addSpell('di', {'Divine Interference', 'Divine Mediation', 'Divine Intermediation', 'Divine Imposition', 'Divine Indemnification', 'Divine Intervention'})
        -- slot 12
        self:addSpell('retort', {'Axoeviq\'s Retort', 'Jorlleag\'s Retort', 'Curate\'s Retort', 'Vicarum\'s Retort'})
        self:addSpell('rebuke', {'Unyielding Admonition', 'Unyielding Rebuke', 'Unyielding Censure', 'Unyielding Judgement'})
        self:addSpell('bulwark', {'Divine Bulwark'})
        self:addSpell('groupheal2', {'Word of Greater Vivification', 'Word of Greater Rejuvination', 'Word of Greater Replenishment', 'Word of Greater Restoration', 'Word of Greater Reformation'})
        -- slot 13
        self:addSpell('da', {'Divine Keep'}) -- Divine Keep
        self:addSpell('alliance', {'Sincere Coalition', 'Divine Alliance'})
        self:addSpell('shining', {'Shining Steel', 'Shining Fortitude', 'Shining Aegis', 'Shining Fortress', 'Shining Bulwark'})

        self:addSpell('groupsymbol', {'Unified Hand of Helmsbane', 'Unified Hand of the Diabo', 'Unified Hand of Jorlleag', 'Unified Hand of Emra', 'Unified Hand of Nonia', 'Balikor\'s Mark', 'Kazad\'s Mark', 'Marzin\'s Mark', 'Naltron\'s Mark'}, {classes={CLR=true,DRU=true,SHM=true,MAG=true,ENC=true,WIZ=true,NEC=true}})
        self:addSpell('groupaego', {'Unified Hand of Infallibility', 'Unified Hand of Persistence', 'Unified Hand of Righteousness', 'Unified Hand of Assurance', 'Unified Hand of Surety', 'Hand of Conviction', 'Hand of Virtue', 'Blessing of Aegolism', 'Blessing of Temperance'}, {classes={WAR=true,SHD=true,PAL=true}})
        self:addSpell('armor', {'Armor of the Avowed', 'Armor of Penance', 'Armor of Sincerity', 'Armor of the Merciful', 'Armor of the Ardent', 'Armor of the Pious', 'Armor of the Zealot'})
        self:addSpell('spellhaste', {'Hand of Devotion', 'Hand of Devoutness', 'Hand of Reverence', 'Hand of Sanctity', 'Hand of Zeal'}, {classes={CLR=true,DRU=true,SHM=true,MAG=true,ENC=true,WIZ=true,NEC=true}})

        self:addSpell('aura', {'Bastion of Divinity', 'Aura of Divinity'})

        self:addSpell('vie', {'Rallied Citadel of Vie', 'Rallied Sanctuary of Vie'})
        self:addSpell('bigvie', {'Rallied Greater Aegis of Vie', 'Rallied Greater Blessing of Vie', 'Rallied Greater Protection of Vie', 'Rallied Greater Guard of Vie', 'Rallied Greater Ward of Vie'})

        self:addSpell('mark', {'Mark of THormir', 'Mark of Ezra', 'Mark of Wenglawks', 'Mark of Shandral', 'Mark of the Vicarum', 'Mark of the Blameless', 'Mark of the Righteous', 'Mark of Kings', 'Mark of Karn', 'Mark of Retribution'})

        self:addSpell('grouphot', {'Avowed Acquittal', 'Devout Acquittal', 'Sincere Acquittal', 'Merciful Acquittal', 'Ardent Acquittal', 'Elixir of Divinity'})
    end
end

function Cleric:initSpellRotations()
    table.insert(self.spellRotations.standard, self.spells.stun)
end

function Cleric:initHeals()
    if state.emu then
        table.insert(self.healAbilities, common.getAA('Burst of Life', {panic=true}))
        table.insert(self.healAbilities, common.getItem('Weighted Hammer of Conviction', {tank=true, regular=true, panic=true, pet=60}))
        table.insert(self.healAbilities, common.getItem('Harmony of the Soul', {panic=true}))
        table.insert(self.healAbilities, self.spells.heal)
        table.insert(self.healAbilities, common.getAA('Divine Arbitration', {panic=true}))
        table.insert(self.healAbilities, self.spells.groupheal)
        table.insert(self.healAbilities, self.spells.hotgroup)
        --table.insert(self.healAbilities, self.spells.remedy)
        table.insert(self.healAbilities, self.spells.hottank)
        table.insert(self.healAbilities, self.spells.hotdps)
    else
        table.insert(self.healAbilities, common.getAA('Burst of Life', {panic=true}))
        table.insert(self.healAbilities, common.getItem('Weighted Hammer of Conviction', {tank=true, regular=true, panic=true, pet=60}))
        table.insert(self.healAbilities, common.getItem('Harmony of the Soul', {panic=true}))
        table.insert(self.healAbilities, common.getAA('Divine Arbitration', {panic=true}))
        table.insert(self.healAbilities, self.spells.remedy1)
        table.insert(self.healAbilities, self.spells.remedy2)
        table.insert(self.healAbilities, self.spells.intervention1)
        table.insert(self.healAbilities, self.spells.intervention2)
        table.insert(self.healAbilities, self.spells.composite)
        table.insert(self.healAbilities, self.spells.remedy3)
        table.insert(self.healAbilities, self.spells.groupheal)
        table.insert(self.healAbilities, self.spells.grouphot)
    end
end

function Cleric:initCures()
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
    table.insert(self.selfBuffs, self.spells.yaulp)
    table.insert(self.selfBuffs, self.spells.armor)
    table.insert(self.selfBuffs, self.spells.spellhaste)
    table.insert(self.selfBuffs, common.getItem('Earring of Pain Deliverance', {CheckFor='Reyfin\'s Random Musings'}))
    table.insert(self.selfBuffs, common.getItem('Xxeric\'s Matted-Fur Mask', {CheckFor='Reyfin\'s Racing Thoughts'}))

    table.insert(self.singleBuffs, self.spells.groupsymbol)
    table.insert(self.singleBuffs, self.spells.aego)
    table.insert(self.singleBuffs, self.spells.symbol)
    table.insert(self.singleBuffs, self.spells.singleaego)
    table.insert(self.groupBuffs, self.spells.groupaego)

    self:addRequestAlias(self.spells.singleaego, 'singleaego')
    self:addRequestAlias(self.spells.groupaego, 'aego')
    self:addRequestAlias(self.spells.symbol, 'symbol')
    self:addRequestAlias(self.spells.groupsymbol, 'grpsymbol')
    self:addRequestAlias(self.spells.spellhaste, 'spellhaste')
    self:addRequestAlias(self.spells.di, 'di')
    self:addRequestAlias(self.radiant, 'radiant')
    self.cr = common.getAA('Celestial Regeneration')
    self:addRequestAlias(self.cr, 'cr')
    self.focusedcr = common.getAA('Focused Celestial Regeneration')
    self:addRequestAlias(self.focusedcr, 'focusedcr')
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
    table.insert(self.DPSAbilities, self.spells.hammerpet)
end

function Cleric:initDebuffs()
    table.insert(self.debuffs, self.spells.mark)
end

function Cleric:initRecoverAbilities()
    self.qm = common.getAA('Quiet Miracle', {mana=true, threshold=15, combat=true})
    table.insert(self.recoverAbilities, self.qm)
    self:addRequestAlias(self.qm, 'qm')
end

return Cleric