--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local logger = require('utils.logger')
local timer = require('utils.timer')
local common = require('common')
local config = require('interface.configuration')
local abilities = require('ability')
local mode = require('mode')
local state = require('state')
local ui = require('interface.ui')

local Necromancer = class:new()

function Necromancer:init()
    self.classOrder = {'assist', 'aggro', 'mash', 'debuff', 'cast', 'burn', 'recover', 'rez', 'buff', 'rest', 'managepet'}
    self.spellRotations = {standard={},short={}}
    self:initBase('nec')

    self:initClassOptions()
    self:loadSettings()
    self:initSpellLines()
    self:initSpellConditions()
    self:initSpellRotations()
    self:initBurns()
    self:initBuffs()
    self:initDebuffs()
    self:initDefensiveAbilities()
    self:addCommonAbilities()

    self.tcclick = common.getItem('Bifold Focus of the Evil Eye')

    -- lifeburn/dying grasp combo
    self.lifeburn = common.getAA('Life Burn')
    self.dyinggrasp = common.getAA('Dying Grasp')

    -- Mana Recovery AAs
    self.deathbloom = common.getAA('Death Bloom', {nodmz=true})
    self.bloodmagic = common.getAA('Blood Magic', {nodmz=true})

    self.convergence = common.getAA('Convergence')
    self.rezAbility = self.convergence
    self.summonCompanion = common.getAA('Summon Companion')
    self.neccount = 1
end

function Necromancer:initClassOptions()
    self:addOption('STOPPCT', 'DoT Stop Pct', 0, nil, 'Percent HP to stop refreshing DoTs on mobs', 'inputint', nil, 'StopPct', 'int')
    self:addOption('USEDEBUFF', 'Debuff', true, nil, 'Debuff targets with scent', 'checkbox', nil, 'UseDebuff', 'bool')
    self:addOption('USEBUFFSHIELD', 'Buff Shield', false, nil, 'Keep shield buff up. Replaces corruption DoT.', 'checkbox', nil, 'UseBuffShield', 'bool')
    self:addOption('USEMANATAP', 'Mana Drain', false, nil, 'Use group mana drain dot. Replaces Ignite DoT.', 'checkbox', nil, 'UseManaTap', 'bool')
    self:addOption('USEREZ', 'Use Rez', true, nil, 'Use Convergence AA to rez group members', 'checkbox', nil, 'UseRez', 'bool')
    self:addOption('USEFD', 'Feign Death', true, nil, 'Use FD AA\'s to reduce aggro', 'checkbox', nil, 'UseFD', 'bool')
    self:addOption('USEINSPIRE', 'Inspire Ally', true, nil, 'Use Inspire Ally pet buff', 'checkbox', nil, 'UseInspire', 'bool')
    self:addOption('USEDISPEL', 'Use Dispel', true, nil, 'Dispel mobs with Eradicate Magic AA', 'checkbox', nil, 'UseDispel', 'bool')
    self:addOption('USEWOUNDS', 'Use Wounds', true, nil, 'Use wounds DoT', 'checkbox', nil, 'UseWounds', 'bool')
    self:addOption('MULTIDOT', 'Multi DoT', false, nil, 'DoT all mobs', 'checkbox', nil, 'MultiDoT', 'bool')
    self:addOption('MULTICOUNT', 'Multi DoT #', 3, nil, 'Number of mobs to rotate through when multi-dot is enabled', 'inputint', nil, 'MultiCount', 'int')
    self:addOption('USENUKES', 'Use Nukes', true, nil, 'Toggle use of nukes', 'checkbox', nil, 'UseNukes', 'bool')
    self:addOption('USEDOTS', 'Use DoTs', true, nil, 'Toggle use of DoTs, in case mobs are just dying too fast', 'checkbox', nil, 'UseDoTs', 'bool')
    self:addOption('USELICH', 'Use Lich', true, nil, 'Toggle use of lich, incase you\'re just farming and don\'t really need it', 'checkbox', nil, 'UseLich', 'bool')
    self:addOption('BURNPROC', 'Burn on Proc', false, nil, 'Toggle use of burns once proliferation dot lands', 'checkbox', nil, 'BurnProc', 'bool')
end

function Necromancer:initSpellLines()
    self:addSpell('composite', {'Ecliptic Paroxysm', 'Composite Paroxysm', 'Dissident Paroxysm', 'Dichotomic Paroxysm'}, {opt='USEDOTS'})
    self:addSpell('wounds', {'Putrefying Wounds', 'Infected Wounds', 'Septic Wounds', 'Cyclotoxic Wounds', 'Mortiferous Wounds', 'Pernicious Wounds', 'Necrotizing Wounds', 'Splirt', 'Splart', 'Splort'}, {opt='USEWOUNDS'})
    self:addSpell('fireshadow', {'Raging Shadow', 'Scalding Shadow', 'Broiling Shadow', 'Burning Shadow', 'Smouldering Shadow', 'Coruscating Shadow', 'Blazing Shadow', 'Blistering Shadow', 'Scorching Shadow'}, {opt='USEDOTS'})
    self:addSpell('pyreshort', {'Pyre of Illandrin', 'Pyre of Va Xakra', 'Pyre of Klraggek', 'Pyre of the Shadewarden', 'Pyre of Jorobb', 'Pyre of Marnek', 'Pyre of Hazarak', 'Pyre of Nos', 'Soul Reaper\'s Pyre', 'Dread Pyre', 'Funeral Pyre of Kelador'}, {opt='USEDOTS'})
    self:addSpell('pyrelong', {'Pyre of the Abandoned', 'Pyre of the Neglected', 'Pyre of the Wretched', 'Pyre of the Fereth', 'Pyre of the Lost', 'Pyre of the Forsaken', 'Pyre of the Piq\'a', 'Pyre of the Bereft', 'Pyre of the Forgotten', 'Pyre of Mori', 'Night Fire'}, {opt='USEDOTS'})
    self:addSpell('venom', {'Luggald Venom', 'Hemorrhagic Venom', 'Crystal Crawler Venom', 'Polybiad Venom', 'Glistenwing Venom', 'Binaesa Venom', 'Naeya Venom', 'Argendev\'s Venom', 'Slitheren Venom', 'Chaos Venom', 'Blood of Thule'}, {opt='USEDOTS'})
    self:addSpell('magic', {'Extermination', 'Extinction', 'Oblivion', 'Inevitable End', 'Annihilation', 'Termination', 'Doom', 'Demise', 'Mortal Coil', 'Dark Nightmare', 'Horror'}, {opt='USEDOTS'})
    self:addSpell('decay', {'Goremand\'s Decay', 'Fleshrot\'s Decay', 'Danvid\'s Decay', 'Mourgis\' Decay', 'Livianus\' Decay', 'Wuran\'s Decay', 'Ulork\'s Decay', 'Folasar\'s Decay', 'Megrima\'s Decay', 'Chaos Plague', 'Dark Plague'}, {opt='USEDOTS'})
    self:addSpell('grip', {'Grip of Terrastride', 'Grip of Quietus', 'Grip of Zorglim', 'Grip of Kraz', 'Grip of Jabaum', 'Grip of Zalikor', 'Grip of Zargo', 'Grip of Mori'}, {opt='USEDOTS'})
    self:addSpell('haze', {'Uncia\'s Pallid Haze', 'Zelnithak\'s Pallid Haze', 'Drachnia\'s Pallid Haze', 'Bomoda\'s Pallid Haze', 'Plexipharia\'s Pallid Haze', 'Halstor\'s Pallid Haze', 'Ivrikdal\'s Pallid Haze', 'Arachne\'s Pallid Haze', 'Fellid\'s Pallid Haze', 'Venom of Anguish'}, {opt='USEDOTS'})
    self:addSpell('grasp', {'Helmsbane\'s Grasp', 'The Protector\'s Grasp', 'Tserrina\'s Grasp', 'Bomoda\'s Grasp', 'Plexipharia\'s Grasp', 'Halstor\'s Grasp', 'Ivrikdal\'s Grasp', 'Arachne\'s Grasp', 'Fellid\'s Grasp', 'Ancient: Curse of Mori', 'Fang of Death'}, {opt='USEDOTS'})
    self:addSpell('leech', {'Ghastly Leech', 'Twilight Leech', 'Frozen Leech', 'Ashen Leech', 'Dark Leech'}, {opt='USEDOTS'})
    self:addSpell('ignite', {'Ignite Remembrance', 'Ignite Cognition', 'Ignite Intellect', 'Ignite Memories', 'Ignite Synapses', 'Ignite Thoughts', 'Ignite Potential', 'Thoughtburn', 'Ignite Energy'}, {opt='USEDOTS'})
    self:addSpell('scourge', {'Scourge of Destiny', 'Scourge of Fates'}, {opt='USEDOTS'})
    self:addSpell('corruption', {'Deterioration', 'Decomposition', 'Miasma', 'Effluvium', 'Liquefaction', 'Dissolution', 'Mortification', 'Fetidity', 'Putrescence'}, {opt='USEDOTS'})
    -- Lifetaps
    self:addSpell('tapee', {'Soullash', 'Soulflay', 'Soulgouge', 'Soulsiphon', 'Soulrend', 'Soulrip', 'Soulspike'}) -- unused
    self:addSpell('tap', {'Maraud Essence', 'Draw Essence', 'Consume Essence', 'Hemorrhage Essence', 'Plunder Essence', 'Bleed Essence', 'Divert Essence', 'Drain Essence', 'Ancient: Touch of Orshilak'}) -- unused
    self:addSpell('tapsummon', {'Vollmondnacht Orb', 'Dusternacht Orb', 'Dunkelnacht Orb', 'Finsternacht Orb', 'Shadow Orb'}) -- unused
    -- Wounds proc
    self:addSpell('proliferation', {'Infected Proliferation', 'Septic Proliferation', 'Cyclotoxic Proliferation', 'Violent Proliferation', 'Violent Necrosis'})
    -- combo dots
    self:addSpell('combodisease', {'Fleshrot\'s Grip of Decay', 'Danvid\'s Grip of Decay', 'Mourgis\' Grip of Decay', 'Livianus\' Grip of Decay'}, {opt='USEDOTS'})
    self:addSpell('chaotic', {'Chaotic Fetor', 'Chaotic Acridness', 'Chaotic Miasma', 'Chaotic Effluvium', 'Chaotic Liquefaction', 'Chaotic Corruption', 'Chaotic Contagion'}, {opt='USEDOTS'}) -- unused
    -- sphere
    self:addSpell('sphere', {'Remote Sphere of Rot', 'Remote Sphere of Withering', 'Remote Sphere of Blight', 'Remote Sphere of Decay', 'Echo of Dissolution', 'Sphere of Dissolution', 'Sphere of Withering', 'Sphere of Blight', 'Withering Decay'}) -- unused
    -- Alliance
    self:addSpell('alliance', {'Malevolent Conjunction', 'Malevolent Coalition', 'Malevolent Covenant', 'Malevolent Alliance'}, {opt='USEALLIANCE'})
    -- Nukes
    self:addSpell('synergy', {'Decree for Blood', 'Proclamation for Blood', 'Assert for Blood', 'Refute for Blood', 'Impose for Blood', 'Impel for Blood', 'Provocation of Blood', 'Compel for Blood', 'Exigency for Blood', 'Call for Blood'}, {opt='USENUKES'})
    self:addSpell('venin', {'Necrotizing Venin', 'Embalming Venin', 'Searing Venin', 'Effluvial Venin', 'Liquefying Venin', 'Dissolving Venin', 'Decaying Venin', 'Blighted Venin', 'Withering Venin', 'Acikin', 'Neurotoxin'}, {opt='USENUKES'})
    -- Debuffs
    self:addSpell('scentterris', {'Scent of Terris'}) -- AA only
    self:addSpell('scentmortality', {'Scent of The Realm', 'Scent of The Grave', 'Scent of Mortality', 'Scent of Extinction', 'Scent of Dread', 'Scent of Nightfall', 'Scent of Doom', 'Scent of Gloom', 'Scent of Midnight'})
    self:addSpell('snare', {'Afflicted Darkness', 'Harrowing Darkness', 'Tormenting Darkness', 'Gnawing Darkness', 'Grasping Darkness', 'Clutching Darkness', 'Viscous Darkness', 'Tenuous Darkness', 'Clawing Darkness', 'Desecrating Darkness'}, {opt='USESNARE'}) -- unused
    -- Mana Drain
    self:addSpell('manatap', {'Mind Disintegrate', 'Mind Atrophy', 'Mind Erosion', 'Mind Excoriation', 'Mind Extraction', 'Mind Strip', 'Mind Abrasion', 'Thought Flay', 'Mind Decomposition', 'Mind Flay'}, {opt='USEMANATAP'})
    -- Buffs
    self:addSpell('lich', {'Realmside', 'Lunaside', 'Gloomside', 'Contraside', 'Forgottenside', 'Forsakenside', 'Shadowside', 'Darkside', 'Netherside', 'Ancient: Allure of Extinction', 'Dark Possession', 'Grave Pact', 'Ancient: Seduction of Chaos'}, {opt='USELICH', nodmz=true})
    self:addSpell('flesh', {'Flesh to Toxin', 'Flesh to Venom', 'Flesh to Poison'})
    self:addSpell('shield', {'Shield of Inescapability', 'Shield of Inevitability', 'Shield of Destiny', 'Shield of Order', 'Shield of Consequence', 'Shield of Fate'})
    self:addSpell('rune', {'Golemskin', 'Carrion Skin', 'Frozen Skin', 'Ashen Skin', 'Deadskin', 'Zombieskin', 'Ghoulskin', 'Grimskin', 'Corpseskin', 'Dull Pain'}) -- unused
    self:addSpell('tapproc', {'Bestow Ruin', 'Bestow Rot', 'Bestow Dread', 'Bestow Relife', 'Bestow Doom', 'Bestow Mortality', 'Bestow Decay', 'Bestow Unlife', 'Bestow Undeath'}) -- unused
    self:addSpell('defensiveproc', {'Necrotic Cysts', 'Necrotic Sores', 'Necrotic Boils', 'Necrotic Pustules'}, {classes={WAR=true,PAL=true,SHD=true}})
    self:addSpell('reflect', {'Mirror'})
    self:addSpell('hpbuff', {'Shield of Memories', 'Shadow Guard', 'Shield of Maelin'}) -- pre-unity
    self:addSpell('dmf', {'Dead Men Floating'})
    -- Pet spells
    self:addSpell('pet', {'Merciless Assassin', 'Unrelenting Assassin', 'Restless Assassin', 'Reliving Assassin', 'Revived Assassin', 'Unearthed Assassin', 'Reborn Assassin', 'Raised Assassin', 'Unliving Murderer', 'Dark Assassin', 'Child of Bertoxxulous'})
    self:addSpell('pethaste', {'Sigil of Putrefaction', 'Sigil of Undeath', 'Sigil of Decay', 'Sigil of the Arcron', 'Sigil of the Doomscale', 'Sigil of the Sundered', 'Sigil of the Preternatural', 'Sigil of the Moribund', 'Glyph of Darkness'})
    self:addSpell('petheal', {'Bracing Revival', 'Frigid Salubrity', 'Icy Revival', 'Algid Renewal', 'Icy Mending', 'Algid Mending', 'Chilled Mending', 'Gelid Mending', 'Icy Stitches', 'Dark Salve'}) -- unused
    self:addSpell('petaegis', {'Aegis of Valorforged', 'Aegis of Rumblecrush', 'Aegis of Orfur', 'Aegis of Zeklor', 'Aegis of Japac', 'Aegis of Nefori', 'Phantasmal Ward', 'Bulwark of Calliav'}) -- unused
    self:addSpell('petshield', {'Cascading Runeshield', 'Cascading Shadeshield', 'Cascading Dreadshield', 'Cascading Deathshield', 'Cascading Doomshield', 'Cascading Boneshield', 'Cascading Bloodshield', 'Cascading Deathshield'}) -- unused
    self:addSpell('petillusion', {'Form of Mottled Bone'})
    self:addSpell('inspire', {'Instill Ally', 'Inspire Ally', 'Incite Ally', 'Infuse Ally', 'Imbue Ally', 'Sanction Ally', 'Empower Ally', 'Energize Ally', 'Necrotize Ally'})
    self:addSpell('swarm', {'Call Skeleton Thrall', 'Call Skeleton Mass', 'Call Skeleton Horde', 'Call Skeleton Army', 'Call Skeleton Mob', 'Call Skeleton Throng', 'Call Skeleton Host', 'Call Skeleton Crush', 'Call Skeleton Swarm'})
end

function Necromancer:initSpellConditions()
    if self.spells.manatap then self.spells.manatap.condition = function() return (mq.TLO.Group.LowMana(70)() or 0) > 2 end end
    if self.spells.alliance then self.spells.alliance.condition = function() return self.neccount > 1 and not mq.TLO.Target.Buff(self.spells.alliance.Name)() and mq.TLO.Spell(self.spells.alliance.Name).StacksTarget() end end
    if not state.emu and self.spells.synergy then
        self.spells.synergy.condition = function()
            return not mq.TLO.Me.Song('Defiler\'s Synergy')() and mq.TLO.Target.MyBuff(self.spells.pyreshort and self.spells.pyreshort.Name)() and
                    mq.TLO.Target.MyBuff(self.spells.venom and self.spells.venom.Name)() and
                    mq.TLO.Target.MyBuff(self.spells.magic and self.spells.magic.Name)() end
    end
    if self.spells.pyreshort and self.tcclick then
        self.spells.pyreshort.precast = function()
            if not mq.TLO.Me.Buff('Heretic\'s Twincast')() then
                self.tcclick:use()
            end
        end
    end
    if self.spells.combodisease then
        self.spells.combodisease.condition = function()
            return (not common.isTargetDottedWith(self.spells.decay.ID, self.spells.decay.Name) or not common.isTargetDottedWith(self.spells.grip.ID, self.spells.grip.Name)) and mq.TLO.Me.SpellReady(self.spells.combodisease.Name)()
        end
    end
end

function Necromancer:initSpellRotations()
    -- entries in the dots table are pairs of {spell id, spell name} in priority order
    local standard = {}
    if state.emu then table.insert(self.spellRotations.standard, self.spells.decay) end
    table.insert(self.spellRotations.standard, self.spells.alliance)
    table.insert(self.spellRotations.standard, self.spells.wounds)
    table.insert(self.spellRotations.standard, self.spells.composite)
    table.insert(self.spellRotations.standard, self.spells.pyreshort)
    table.insert(self.spellRotations.standard, self.spells.venom)
    table.insert(self.spellRotations.standard, self.spells.magic)
    table.insert(self.spellRotations.standard, self.spells.synergy)
    table.insert(self.spellRotations.standard, self.spells.manatap)
    table.insert(self.spellRotations.standard, self.spells.combodisease)
    table.insert(self.spellRotations.standard, self.spells.haze)
    table.insert(self.spellRotations.standard, self.spells.grasp)
    table.insert(self.spellRotations.standard, self.spells.fireshadow)
    table.insert(self.spellRotations.standard, self.spells.leech)
    table.insert(self.spellRotations.standard, self.spells.pyrelong)
    table.insert(self.spellRotations.standard, self.spells.ignite)
    table.insert(self.spellRotations.standard, self.spells.scourge)
    table.insert(self.spellRotations.standard, self.spells.corruption)

    table.insert(self.spellRotations.short, self.spells.swarm)
    table.insert(self.spellRotations.short, self.spells.alliance)
    table.insert(self.spellRotations.short, self.spells.composite)
    table.insert(self.spellRotations.short, self.spells.pyreshort)
    table.insert(self.spellRotations.short, self.spells.venom)
    table.insert(self.spellRotations.short, self.spells.magic)
    table.insert(self.spellRotations.short, self.spells.synergy)
    table.insert(self.spellRotations.short, self.spells.manatap)
    table.insert(self.spellRotations.short, self.spells.combodisease)
    table.insert(self.spellRotations.short, self.spells.haze)
    table.insert(self.spellRotations.short, self.spells.grasp)
    table.insert(self.spellRotations.short, self.spells.fireshadow)
    table.insert(self.spellRotations.short, self.spells.leech)
    table.insert(self.spellRotations.short, self.spells.pyrelong)
    table.insert(self.spellRotations.short, self.spells.ignite)

    self.swap_gem = 8
    self.swap_gem_dis = 9
end

function Necromancer:initBurns()
    -- entries in the items table are MQ item datatypes
    table.insert(self.burnAbilities, common.getItem(mq.TLO.InvSlot('Chest').Item.Name()))
    table.insert(self.burnAbilities, common.getItem('Rage of Rolfron'))
    table.insert(self.burnAbilities, common.getItem('Blightbringer\'s Tunic of the Grave')) -- buff, 5 minute CD
    --table.insert(items, common.getItem('Vicious Rabbit')) -- 5 minute CD
    --table.insert(items, common.getItem('Necromantic Fingerbone')) -- 3 minute CD
    --table.insert(items, common.getItem('Amulet of the Drowned Mariner')) -- 5 minute CD

    self.pre_burn_items = {}
    table.insert(self.pre_burn_items, common.getItem('Blightbringer\'s Tunic of the Grave')) -- buff
    table.insert(self.pre_burn_items, common.getItem(mq.TLO.InvSlot('Chest').Item.Name())) -- buff, Consuming Magic

    -- entries in the AAs table are pairs of {aa name, aa id}
    table.insert(self.burnAbilities, self.silent) -- song, 12 minute CD
    table.insert(self.burnAbilities, common.getAA('Mercurial Torment')) -- buff, 24 minute CD
    table.insert(self.burnAbilities, common.getAA('Heretic\'s Twincast')) -- buff, 15 minute CD
    if not state.emu then
        table.insert(self.burnAbilities, common.getAA('Spire of Necromancy')) -- buff
    else
        table.insert(self.burnAbilities, common.getAA('Fundament: Third Spire of Necromancy')) -- buff, 7:30 minute CD
        table.insert(self.burnAbilities, common.getAA('Embalmer\'s Carapace'))
    end
    table.insert(self.burnAbilities, common.getAA('Hand of Death')) -- song, 8:30 minute CD
    table.insert(self.burnAbilities, common.getAA('Gathering Dusk')) -- song, Duskfall Empowerment, 10 minute CD
    table.insert(self.burnAbilities, common.getAA('Companion\'s Fury')) -- 10 minute CD
    table.insert(self.burnAbilities, common.getAA('Companion\'s Fortification')) -- 15 minute CD
    table.insert(self.burnAbilities, common.getAA('Rise of Bones', {delay=1500})) -- 10 minute CD
    table.insert(self.burnAbilities, common.getAA('Swarm of Decay', {delay=1500})) -- 9 minute CD

    self.glyph = common.getAA('Mythic Glyph of Ultimate Power V')
    self.intensity = common.getAA('Intensity of the Resolute')

    self.wakethedead = common.getAA('Wake the Dead') -- 3 minute CD

    self.funeralpyre = common.getAA('Funeral Pyre') -- song, 20 minute CD

    self.pre_burn_AAs = {}
    table.insert(self.pre_burn_AAs, common.getAA('Mercurial Torment')) -- buff
    table.insert(self.pre_burn_AAs, common.getAA('Heretic\'s Twincast')) -- buff
    if not state.emu then
        table.insert(self.pre_burn_AAs, common.getAA('Spire of Necromancy')) -- buff
    else
        table.insert(self.pre_burn_AAs, common.getAA('Fundament: Third Spire of Necromancy')) -- buff
    end
end

function Necromancer:initBuffs()
    -- Buffs
    self.unity = common.getAA('Mortifier\'s Unity')

    if state.emu then
        table.insert(self.selfBuffs, self.spells.lich)
        table.insert(self.selfBuffs, self.spells.hpbuff)
        table.insert(self.selfBuffs, common.getAA('Gift of the Grave', {RemoveBuff='Gift of the Grave Effect'}))
        table.insert(self.singleBuffs, self.spells.defensiveproc)
        table.insert(self.combatBuffs, common.getAA('Reluctant Benevolence'))
    else
        table.insert(self.selfBuffs, self.unity)
    end
    table.insert(self.selfBuffs, self.spells.shield)
    table.insert(self.petBuffs, self.spells.inspire)
    table.insert(self.petBuffs, self.spells.pethaste)
    table.insert(self.petBuffs, common.getAA('Fortify Companion'))
    local dmf = common.getAA('Dead Man Floating')
    table.insert(self.selfBuffs, dmf or self.spells.dmf)

    self:addRequestAlias(self.spells.defensiveproc, 'PUSTULES')
    self:addRequestAlias(dmf or self.spells.dmf, 'DMF')
end

function Necromancer:initDebuffs()
    self.dispel = common.getAA('Eradicate Magic', {opt='USEDISPEL'})

    self.scent = common.getAA('Scent of Thule', {opt='USEDEBUFF'}) or common.getAA('Scent of Terris', {opt='USEDEBUFF'})
    self.debuffTimer = timer:new(30000)
    table.insert(self.debuffs, self.dispel)
    table.insert(self.debuffs, self.scent)
end

function Necromancer:initDefensiveAbilities()
    -- Aggro
    local postFD = function()
        mq.delay(1000)
        mq.cmd('/stand')
        mq.cmd('/makemevis')
    end
    table.insert(self.fadeAbilities, common.getAA('Death\'s Effigy', {opt='USEFD', postcast=postFD}))
    table.insert(self.aggroReducers, common.getAA('Death Peace', {opt='USEFD', postcast=postFD}))
end

-- Determine swap gem based on wherever wounds, broiling shadow or pyre of the wretched is currently mem'd
local function setSwapGems()
    Necromancer.swap_gem = mq.TLO.Me.Gem(Necromancer.spells.wounds and Necromancer.spells.wounds.Name or 'unknown')() or
            mq.TLO.Me.Gem(Necromancer.spells.fireshadow and Necromancer.spells.fireshadow.Name or 'unknown')() or
            mq.TLO.Me.Gem(Necromancer.spells.pyrelong and Necromancer.spells.pyrelong.Name or 'unknown')() or 10
            Necromancer.swap_gem_dis = mq.TLO.Me.Gem(Necromancer.spells.decay and Necromancer.spells.decay.Name or 'unknown')() or
            mq.TLO.Me.Gem(Necromancer.spells.grip and Necromancer.spells.grip.Name or 'unknown')() or 11
end

--[[
Count the number of necros in group or raid to determine whether alliance should be used.
This is currently only called once up front when the script starts.
]]--
local function countNecros()
    Necromancer.neccount = 1
    if mq.TLO.Raid.Members() > 0 then
        Necromancer.neccount = mq.TLO.SpawnCount('pc necromancer raid')()
    elseif mq.TLO.Group.Members() then
        Necromancer.neccount = mq.TLO.SpawnCount('pc necromancer group')()
    end
end

function Necromancer:resetClassTimers()
    self.debuffTimer:reset(0)
end

function Necromancer:swapSpells()
    -- Only swap spells in standard spell set
    if state.spellSetLoaded ~= 'standard' or mq.TLO.Me.Moving() then return end

    local woundsName = self.spells.wounds and self.spells.wounds.Name
    local pyrelongName = self.spells.pyrelong and self.spells.pyrelong.Name
    local fireshadowName = self.spells.fireshadow and self.spells.fireshadow.Name
    local woundsDuration = mq.TLO.Target.MyBuffDuration(woundsName)()
    local pyrelongDuration = mq.TLO.Target.MyBuffDuration(pyrelongName)()
    local fireshadowDuration = mq.TLO.Target.MyBuffDuration(fireshadowName)()
    if mq.TLO.Me.Gem(woundsName)() then
        if not self:isEnabled('USEWOUNDS') or (woundsDuration and woundsDuration > 20000) then
            if not pyrelongDuration or pyrelongDuration < 20000 then
                abilities.swapSpell(self.spells.pyrelong, self.swap_gem or 10)
            elseif not fireshadowDuration or fireshadowDuration < 20000 then
                abilities.swapSpell(self.spells.fireshadow, self.swap_gem or 10)
            end
        end
    elseif mq.TLO.Me.Gem(pyrelongName)() then
        if pyrelongDuration and pyrelongDuration > 20000 then
            if self:isEnabled('USEWOUNDS') and (not woundsDuration or woundsDuration < 20000) then
                abilities.swapSpell(self.spells.wounds, self.swap_gem or 10)
            elseif not fireshadowDuration or fireshadowDuration < 20000 then
                abilities.swapSpell(self.spells.fireshadow, self.swap_gem or 10)
            end
        end
    elseif mq.TLO.Me.Gem(fireshadowName)() then
        if fireshadowDuration and fireshadowDuration > 20000 then
            if self:isEnabled('USEWOUNDS') and (not woundsDuration or woundsDuration < 20000) then
                abilities.swapSpell(self.spells.wounds, self.swap_gem or 10)
            elseif not pyrelongDuration or pyrelongDuration < 20000 then
                abilities.swapSpell(self.spells.pyrelong, self.swap_gem or 10)
            end
        end
    else
        -- maybe we got interrupted or something and none of these are mem'd anymore? just memorize wounds again
        abilities.swapSpell(self.spells.wounds, self.swap_gem or 10)
    end
end

-- Check whether a dot is applied to the target
local function targetHasProliferation()
    if not mq.TLO.Target.MyBuff(class.spells.proliferation and class.spells.proliferation.Name)() then return false else return true end
end

local function isNecBurnConditionMet()
    if class:isEnabled('BURNPROC') and targetHasProliferation() then
        logger.info('\arActivating Burns (proliferation proc)\ax')
        state.burnActiveTimer:reset()
        state.burnActive = true
        return true
    end
end

function Necromancer:alwaysCondition()
    if mq.TLO.Me.AltAbilityReady('Heretic\'s Twincast')() and not mq.TLO.Me.AltAbilityReady('Hand of Death')() then
        return false
    elseif not mq.TLO.Me.AltAbilityReady('Heretic\'s Twincast')() and mq.TLO.Me.AltAbilityReady('Hand of Death')() then
        return false
    else
        return true
    end
end

--[[
Base crit - 62%

Auspice - 33% crit
IOG - 13% crit
Bard Epic (12) + Fierce Eye (15) - 27% crit

Spire - 25% crit
OOW robe - 40% crit
Intensity - 50% crit
Glyph - 15% crit
]]--
function Necromancer:burnClass()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag.
    -- Test them both for each item, and see which one(s) actually work.
    --if common.isBurnConditionMet(self.alwaysCondition) or isNecBurnConditionMet() then
    local base_crit = 62
    local auspice = mq.TLO.Me.Song('Auspice of the Hunter')()
    if auspice then base_crit = base_crit + 33 end
    local iog = mq.TLO.Me.Song('Illusions of Grandeur')()
    if iog then base_crit = base_crit + 13 end
    local brd_epic = mq.TLO.Me.Song('Spirit of Vesagran')()
    if brd_epic then base_crit = base_crit + 12 end
    local fierce_eye = mq.TLO.Me.Song('Fierce Eye')()
    if fierce_eye then base_crit = base_crit + 15 end

    if mq.TLO.SpawnCount('corpse radius 150')() > 0 and self.wakethedead then
        self.wakethedead:use()
        mq.delay(1500)
    end

    if config.get('USEGLYPH') and self.intensity and self.glyph then
        if not mq.TLO.Me.Song(self.intensity.Name)() and mq.TLO.Me.Buff('heretic\'s twincast')() then
            self.glyph:use()
        end
    end
    if config.get('USEINTENSITY') and self.glyph and self.intensity then
        if not mq.TLO.Me.Buff(self.glyph.Name)() and mq.TLO.Me.Buff('heretic\'s twincast')() then
            self.intensity:use()
        end
    end

    if self.lifeburn and mq.TLO.Me.PctHPs() > 90 and mq.TLO.Me.AltAbilityReady('Life Burn')() and (state.emu or (self.dyinggrasp and mq.TLO.Me.AltAbilityReady('Dying Grasp')())) then
        self.lifeburn:use()
        mq.delay(5)
        if self.dyinggrasp then self.dyinggrasp:use() end
    end
end

function Necromancer:preburn()
    logger.info('Pre-burn')

    for _,item in ipairs(self.pre_burn_items) do
        item:use()
    end

    for _,aa in ipairs(self.pre_burn_AAs) do
        aa:use()
    end

    if config.get('USEGLYPH') and self.intensity and self.glyph then
        if not mq.TLO.Me.Song(self.intensity.Name)() and mq.TLO.Me.Buff('heretic\'s twincast')() then
            self.glyph:use()
        end
    end
end

function Necromancer:recover()
    if self.spells.lich and mq.TLO.Me.PctHPs() < 40 and mq.TLO.Me.Buff(self.spells.lich.Name)() then
        logger.info('Removing lich to avoid dying!')
        mq.cmdf('/removebuff %s', self.spells.lich.Name)
    end
    -- modrods
    common.checkMana()
    local pct_mana = mq.TLO.Me.PctMana()
    if self.deathbloom and pct_mana < 65 then
        -- death bloom at some %
        self.deathbloom:use()
    end
    if self.bloodmagic and mq.TLO.Me.CombatState() == 'COMBAT' then
        if pct_mana < 40 then
            -- blood magic at some %
            self.bloodmagic:use()
        end
    end
end

local function safeToStand()
    if mq.TLO.Raid.Members() > 0 and mq.TLO.SpawnCount('pc raid tank radius 300')() > 2 then
        return true
    end
    if mq.TLO.Group.MainTank() then
        if not mq.TLO.Group.MainTank.Dead() then
            return true
        elseif mq.TLO.SpawnCount('npc radius 100')() == 0 then
            return true
        else
            return false
        end
    elseif mq.TLO.SpawnCount('npc radius 100')() == 0 then
        return true
    else
        return false
    end
end

local checkAggroTimer = timer:new(10000)
function Necromancer:aggroOld()
    if state.emu then return end
    if mode.currentMode:isManualMode() then return end
    if self:isEnabled('USEFD') and mq.TLO.Me.CombatState() == 'COMBAT' and mq.TLO.Target() then
        if mq.TLO.Me.TargetOfTarget.ID() == mq.TLO.Me.ID() or checkAggroTimer:timerExpired() then
            if self.deathseffigy and mq.TLO.Me.PctAggro() >= 90 then
                if self.dyinggrasp and mq.TLO.Me.PctHPs() < 40 and mq.TLO.Me.AltAbilityReady('Dying Grasp')() then
                    self.dyinggrasp:use()
                end
                self.deathseffigy:use()
                if mq.TLO.Me.Feigning() then
                    checkAggroTimer:reset()
                    mq.delay(500)
                    if safeToStand() then
                        mq.TLO.Me.Sit() -- Use a sit TLO to stand up, what wizardry is this?
                        mq.cmd('/makemevis')
                    end
                end
            elseif self.deathpeace and mq.TLO.Me.PctAggro() >= 70 then
                self.deathpeace:use()
                if mq.TLO.Me.Feigning() then
                    checkAggroTimer:reset()
                    mq.delay(500)
                    if safeToStand() then
                        mq.TLO.Me.Sit() -- Use a sit TLO to stand up, what wizardry is this?
                        mq.cmd('/makemevis')
                    end
                end
            end
        end
    end
end

local composite_names = {['Composite Paroxysm']=true, ['Dissident Paroxysm']=true, ['Dichotomic Paroxysm']=true}
local checkSpellTimer = timer:new(30000)
function Necromancer:checkSpellSet()
    if not common.clearToBuff() or mq.TLO.Me.Moving() or self:isEnabled('BYOS') then return end
    local spellSet = self.OPTS.SPELLSET.value
    if state.spellSetLoaded ~= spellSet or checkSpellTimer:timerExpired() then
        if spellSet == 'standard' then
            if abilities.swapSpell(self.spells.composite, 1, false, composite_names) then return end
            if abilities.swapSpell(self.spells.pyreshort, 2) then return end
            if abilities.swapSpell(self.spells.venom, 3) then return end
            if abilities.swapSpell(self.spells.magic, 4) then return end
            if abilities.swapSpell(self.spells.haze, 5) then return end
            if abilities.swapSpell(self.spells.grasp, 6) then return end
            if abilities.swapSpell(self.spells.leech, 7) then return end
            --if abilities.swapSpell(self.spells.decay, 11) then return end
            if abilities.swapSpell(self.spells.combodisease, 11) then return end
            if abilities.swapSpell(self.spells.synergy, 13) then return end
            state.spellSetLoaded = spellSet
        elseif spellSet == 'short' then
            if abilities.swapSpell(self.spells.composite, 1, false, composite_names) then return end
            if abilities.swapSpell(self.spells.pyreshort, 2) then return end
            if abilities.swapSpell(self.spells.venom, 3) then return end
            if abilities.swapSpell(self.spells.magic, 4) then return end
            if abilities.swapSpell(self.spells.haze, 5) then return end
            if abilities.swapSpell(self.spells.grasp, 6) then return end
            if abilities.swapSpell(self.spells.leech, 7) then return end
            --if abilities.swapSpell(self.spells.decay, 11) then return end
            if abilities.swapSpell(self.spells.combodisease, 11) then return end
            if abilities.swapSpell(self.spells.synergy, 13) then return end
            state.spellSetLoaded = spellSet
        end
        checkSpellTimer:reset()
        setSwapGems()
    end
    if spellSet == 'standard' then
        if self:isEnabled('USEMANATAP') then
            if abilities.swapSpell(self.spells.manatap, 8) then return end
        else
            if abilities.swapSpell(self.spells.ignite, 8) then return end
        end
        if self:isEnabled('USEALLIANCE') then
            if abilities.swapSpell(self.spells.alliance, 9) then return end
        else
            if self:isEnabled('USEMANATAP') then
                if abilities.swapSpell(self.spells.ignite, 9) then return end
            else
                if abilities.swapSpell(self.spells.scourge, 9) then return end
            end
        end
        if self:isEnabled('USEBUFFSHIELD') then
            if abilities.swapSpell(self.spells.shield, 12) then return end
        else
            if self:isEnabled('USEMANATAP') and self:isEnabled('USEALLIANCE') then
                if abilities.swapSpell(self.spells.ignite, 12) then return end
            elseif self:isEnabled('USEMANATAP') or self:isEnabled('USEALLIANCE') then
                if abilities.swapSpell(self.spells.scourge, 12) then return end
            else
                if abilities.swapSpell(self.spells.corruption, 12) then return end
            end
        end
        if not self:isEnabled('USEWOUNDS') then
            if abilities.swapSpell(self.spells.pyrelong, 10) then return end
        else
            if abilities.swapSpell(self.spells.wounds, 10) then return end
        end
    elseif spellSet == 'short' then
        if self:isEnabled('USEMANATAP') then
            if abilities.swapSpell(self.spells.manatap, 8) then return end
        else
            if abilities.swapSpell(self.spells.ignite, 8) then return end
        end
        if self:isEnabled('USEALLIANCE') then
            if abilities.swapSpell(self.spells.alliance, 9) then return end
        else
            if self:isEnabled('USEMANATAP') then
                if abilities.swapSpell(self.spells.ignite, 9) then return end
            else
                if abilities.swapSpell(self.spells.scourge, 9) then return end
            end
        end
        if self:isEnabled('USEINSPIRE') then
            if abilities.swapSpell(self.spells.inspire, 12) then return end
        else
            if self:isEnabled('USEMANATAP') and self:isEnabled('USEALLIANCE') then
                if abilities.swapSpell(self.spells.ignite, 12) then return end
            elseif self:isEnabled('USEMANATAP') or self:isEnabled('USEALLIANCE') then
                if abilities.swapSpell(self.spells.scourge, 12) then return end
            else
                if abilities.swapSpell(self.spells.venin, 12) then return end
            end
        end
        if not self:isEnabled('USEWOUNDS') then
            if abilities.swapSpell(self.spells.pyrelong, 10) then return end
        else
            if abilities.swapSpell(self.spells.swarm, 10) then return end
        end
    end
end

local necCountTimer = timer:new(60000)

-- if Necromancer:isEnabled('USEALLIANCE') and necCountTimer:timerExpired() then
--    countNecros()
--    necCountTimer:reset()
-- end

function Necromancer:drawBurnTab()
    self.OPTS.BURNPROC.value = ui.drawCheckBox('Burn On Proc', self.OPTS.BURNPROC.value, 'Burn when proliferation procs')
end

return Necromancer
