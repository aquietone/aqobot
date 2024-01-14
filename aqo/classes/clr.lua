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
    self:addCommonAbilities()

    self.rezAbility = common.getAA('Blessing of Resurrection')
end

function Cleric:initClassOptions()
    self:addOption('USEYAULP', 'Use Yaulp', false, nil, 'Toggle use of Yaulp', 'checkbox', nil, 'UseYaulp', 'bool')
    self:addOption('USESPLASH', 'Use Splash', true, nil, 'Toggle use of splash heal', 'checkbox', nil, 'UseSplash', 'bool')
    self:addOption('USEVIE', 'Use Vie', true, nil, 'Toggle use of Vie spell line', 'checkbox', nil, 'UseVie', 'bool')
    self:addOption('USEHAMMER', 'Use Hammer', false, nil, 'Toggle use of summoned hammer pet', 'checkbox', nil, 'UseHammer', 'bool')
    self:addOption('USEHOTGROUP', 'Use Group HoT', true, nil, 'Toggle use of group HoT', 'checkbox', nil, 'UseHoTGroup', 'bool')
    self:addOption('USESTUN', 'Use Stun', true, nil, 'Toggle use of stuns', 'checkbox', nil, 'UseStun', 'bool')
    self:addOption('USEDEBUFF', 'Use Reverse DS', true, nil, 'Toggle use of Mark reverse DS', 'checkbox', nil, 'UseDebuff', 'bool')
    self:addOption('USESYMBOL', 'Use Symbol', false, nil, 'Toggle use of Symbol buff line', 'checkbox', nil, 'UseSymbol', 'bool')
    self:addOption('USERETORT', 'Use Retort', true, nil, 'Toggle use of Retort spell line', 'checkbox', nil, 'UseRetort', 'bool')
end

Cleric.SpellLines = {
    -- emu or before remedies standard heal
    {Group='lightheal', Spells={'Ancient: Hallowed Light', 'Pious Light', 'Holy Light', 'Divine Light', 'Healing Light', 'Superior Healing', 'Healing', 'Light Healing', 'Minor Healing'}, Options={tank=true, panic=true, regular=true}},
    {Group='lightheal', Spells={'Ancient: Hallowed Light', 'Pious Light', 'Holy Light', 'Divine Light', 'Healing Light', 'Superior Healing', 'Healing', 'Light Healing', 'Minor Healing'}, Options={tank=true, panic=true, regular=true}},
    -- live, multiple remedies main heals
    {Group='remedy', NumToPick=3, Spells={'Avowed Remedy', 'Guileless Remedy', 'Sincere Remedy', 'Merciful Remedy', 'Spiritual Remedy', 'Sacred Remedy', 'Pious Remedy', 'Supernal Remedy', 'Remedy'}, Options={tank=true, panic=true, regular=true}},
    -- Slot 5
    {Group='renewal', Spells={'Heroic Renewal', 'Determined Renewal', 'Dire Renewal', 'Furial Renewal', 'Fervid Renewal', 'Desperate Renewal'}, Options={tank=true, panic=true}}, -- slower heal
    {Group='intervention', NumToPick=2, Spells={'Avowed Intervention', 'Atoned Intervention', 'Sincere Intervention', 'Merciful Intervention', 'Mystical Intervention'}, Options={tank=true, panic=true, regular=true}},
    {Group='groupheal', Spells={'Syllable of Acceptance', 'Syllable of Invigoration', 'Syllable of Soothing', 'Syllable of Mending', 'Syllable of Convalescence', 'Word of Vivification', 'Word of Replenishment', 'Word of Redemption'}, Options={threshold=3, regular=true, single=true, group=true, pct=70}},
    {Group='groupheal2', Spells={'Word of Greater Vivification', 'Word of Greater Rejuvination', 'Word of Greater Replenishment', 'Word of Greater Restoration', 'Word of Greater Reformation'}, Options={threshold=3, regular=true, single=true, group=true, pct=70}},
    {Group='grouphot', Spells={'Avowed Acquittal', 'Devout Acquittal', 'Sincere Acquittal', 'Merciful Acquittal', 'Ardent Acquittal', 'Elixir of Divinity'}, Options={opt='USEHOTGROUP', grouphot=true}},
    {Group='hottank', Spells={'Pious Elixir', 'Holy Elixir', 'Celestial Healing', 'Celestial Health', 'Celestial Remedy'}, Options={opt='USEHOTTANK', hot=true}},
    {Group='hotdps', Spells={'Pious Elixir', 'Holy Elixir', 'Celestial Healing', 'Celestial Health', 'Celestial Remedy'}, Options={opt='USEHOTDPS', hot=true}},
    -- Slot 6
    {Group='issuance', Spells={'Issuance of Heroism', 'Issuance of Conviction', 'Issuance of Sincerity', 'Issuance of Mercy', 'Issuance of Spirit'}},
    {Group='splash', Spells={'Acceptance Splash', 'Refreshing Splash', 'Restoring Splash', 'Mending Splash', 'Convalescent Splash'}, Options={opt='USESPLASH', group=true, threshold=3}},
    {Group='ward', Spells={'Ward of Commitment', 'Ward of Persistence', 'Ward of Righteousness', 'Ward of Assurance', 'Ward of Surety'}, Options={tank=true, regular=true}}, -- heals on break
    {Group='composite', Spells={'Ecliptic Blessing', 'Composite Blessing', 'Dichotomic Blessing'}, Options={tank=true, panic=true}},

    {Group='mark', Spells={'Mark of Thormir', 'Mark of Ezra', 'Mark of Wenglawks', 'Mark of Shandral', 'Mark of the Vicarum', 'Mark of the Blameless', 'Mark of the Righteous', 'Mark of Kings', 'Mark of Karn', 'Mark of Retribution'}, Options={opt='USEDEBUFF'}},

    {Group='aura', Spells={'Bastion of Divinity', 'Aura of Divinity'}, Options={aura=true}},
    {Group='spellhaste', Spells={'Hand of Devotion', 'Hand of Devoutness', 'Hand of Reverence', 'Hand of Sanctity', 'Hand of Zeal', 'Aura of Devotion'}, Options={classes={CLR=true,DRU=true,SHM=true,MAG=true,ENC=true,WIZ=true,NEC=true}}},
    {Group='groupaego', Spells={'Unified Hand of Infallibility', 'Unified Hand of Persistence', 'Unified Hand of Righteousness', 'Unified Hand of Assurance', 'Unified Hand of Surety', 'Hand of Conviction', 'Hand of Virtue', 'Blessing of Aegolism', 'Blessing of Temperance'}, Options={classes={CLR=true,WAR=true,SHD=true,PAL=true}}},
    {Group='singleaego', Spells={'Conviction', 'Virtue', 'Aegolism', 'Temperance', 'Bravery'}, Options={classes={CLR=true,WAR=true,SHD=true,PAL=true}}},
    {Group='groupsymbol', Spells={'Unified Hand of Helmsbane', 'Unified Hand of the Diabo', 'Unified Hand of Jorlleag', 'Unified Hand of Emra', 'Unified Hand of Nonia', 'Balikor\'s Mark', 'Kazad\'s Mark', 'Marzin\'s Mark', 'Naltron\'s Mark'}, Options={opt='USESYMBOL', classes={CLR=true,DRU=true,SHM=true,MAG=true,ENC=true,WIZ=true,NEC=true}, condition=function() return mq.TLO.SpawnCount('pc group class druid')() > 0 end}},
    {Group='singlesymbol', Spells={'Symbol of Balikor', 'Symbol of Kazad', 'Symbol of Marzin', 'Symbol of Naltron', 'Symbol of Pinzarn', 'Symbol of Ryltan', 'Symbol of Transal'}, Options={opt='USESYMBOL', classes={CLR=true,DRU=true,SHM=true,MAG=true,ENC=true,WIZ=true,NEC=true}, condition=function() return mq.TLO.SpawnCount('pc group class druid')() > 0 end}},
    {Group='di', Spells={'Divine Interference', 'Divine Mediation', 'Divine Intermediation', 'Divine Imposition', 'Divine Indemnification', 'Divine Intervention'}},
    {Group='shining', Spells={'Shining Steel', 'Shining Fortitude', 'Shining Aegis', 'Shining Fortress', 'Shining Bulwark'}},
    {Group='armor', Spells={'Armor of the Avowed', 'Armor of Penance', 'Armor of Sincerity', 'Armor of the Merciful', 'Armor of the Ardent', 'Armor of the Pious', 'Armor of the Zealot'}},
    {Group='vie', Spells={'Rallied Citadel of Vie', 'Rallied Sanctuary of Vie'}, Options={opt='USEVIE'}},
    {Group='bigvie', Spells={'Rallied Greater Aegis of Vie', 'Rallied Greater Blessing of Vie', 'Rallied Greater Protection of Vie', 'Rallied Greater Guard of Vie', 'Rallied Greater Ward of Vie'}, Options={opt='USEVIE'}},

    {Group='yaulp', Spells={'Yaulp VI'}, Options={combat=true, ooc=false, opt='USEYAULP'}},
    {Group='hammerpet', Spells={'Unswerving Hammer of Justice'}, Options={opt='USEHAMMER'}},

    {Group='rgc', Spells={'Remove Greater Curse'}, Options={curse=true}},
    {Group='stun', Spells={'Vigilant Condemnation', 'Sound of Divinity', 'Shock of Wonder', 'Holy Might', 'Stun'}, Options={opt='USESTUN'}},
    {Group='aestun', Spells={'Silent Dictation'}},

    -- slot 12
    {Group='retort', Spells={'Axoeviq\'s Retort', 'Jorlleag\'s Retort', 'Curate\'s Retort', 'Vicarum\'s Retort'}, Options={opt='USERETORT', classes={WAR=true,SHD=true,PAL=true}}},
    -- twincast nuke
    {Group='rebuke', Spells={'Unyielding Admonition', 'Unyielding Rebuke', 'Unyielding Censure', 'Unyielding Judgement'}},
    -- slot 13
    {Group='da', Spells={'Divine Bulwark', 'Divine Keep', 'Divine Indemnity', 'Divine Haven', 'Divine Fortitude', 'Divine Eminence', 'Divine Destiny', 'Divine Custody', 'Divine Barrier', 'Divine Aura'}},
    {Group='alliance', Spells={'Sincere Coalition', 'Divine Alliance'}, Options={tank=true, regular=true}},
}

function Cleric:initSpellRotations()
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
    table.insert(self.healAbilities, self.spells.intervention1)
    table.insert(self.healAbilities, self.spells.intervention2)
    table.insert(self.healAbilities, self.spells.composite)
    table.insert(self.healAbilities, self.spells.remedy3)
    table.insert(self.healAbilities, self.spells.groupheal)
    table.insert(self.healAbilities, self.spells.grouphot)
    -- table.insert(self.healAbilities, common.getItem('Weighted Hammer of Conviction', {tank=true, regular=true, panic=true, pet=60}))
    -- table.insert(self.healAbilities, self.spells.hottank)
    -- table.insert(self.healAbilities, self.spells.hotdps)
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
    table.insert(self.selfBuffs, self.spells.groupsymbol)
    table.insert(self.selfBuffs, self.spells.groupaego)
    table.insert(self.selfBuffs, common.getItem('Earring of Pain Deliverance', {CheckFor='Reyfin\'s Random Musings'}))
    table.insert(self.selfBuffs, common.getItem('Xxeric\'s Matted-Fur Mask', {CheckFor='Reyfin\'s Racing Thoughts'}))

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

local composite_names = {['Ecliptic Blessing']=true, ['Composite Blessing']=true, ['Dissident Blessing']=true, ['Dichotomic Blessing']=true}
local checkSpellTimer = timer:new(30000)
function Cleric:checkSpellSet()
    if not common.clearToBuff() or mq.TLO.Me.Moving() or self:isEnabled('BYOS') then return end
    local spellSet = self.OPTS.SPELLSET.value
    if state.spellSetLoaded ~= spellSet or checkSpellTimer:timerExpired() then
        if spellSet == 'standard' then
            if mq.TLO.Me.Level() >= 101 then
                if abilities.swapSpell(self.spells.remedy1, 1) then return end
                if abilities.swapSpell(self.spells.remedy2, 2) then return end
                if abilities.swapSpell(self.spells.intervention1, 3) then return end
                if abilities.swapSpell(self.spells.intervention2, 4) then return end
                if abilities.swapSpell(self.spells.renewal, 5) then return end
                if abilities.swapSpell(self.spells.di, 6) then return end
                if abilities.swapSpell(self.spells.ward, 7) then return end
                if abilities.swapSpell(self.spells.groupheal, 8) then return end
                if abilities.swapSpell(self.spells.groupheal2, 9) then return end
                if abilities.swapSpell(self.spells.composite, 10, false, composite_names) then return end
                if abilities.swapSpell(self.spells.retort, 11) then return end
                if abilities.swapSpell(self.spells.rebuke, 12) then return end
                if abilities.swapSpell(self.spells.shining, 13) then return end
            else

            end
        end
        checkSpellTimer:reset()
    end
end

return Cleric