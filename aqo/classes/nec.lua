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

function class.init(_aqo)
    class.classOrder = {'assist', 'aggro', 'mash', 'debuff', 'cast', 'burn', 'recover', 'rez', 'buff', 'rest', 'managepet'}
    class.spellRotations = {standard={},short={}}
    class.initBase(_aqo, 'nec')

    class.initClassOptions()
    class.loadSettings()
    class.initSpellLines()
    class.initSpellConditions()
    class.initSpellRotations()
    class.initBurns()
    class.initBuffs()
    class.initDebuffs()
    class.initDefensiveAbilities()

    class.tcclick = common.getItem('Bifold Focus of the Evil Eye')

    -- lifeburn/dying grasp combo
    class.lifeburn = common.getAA('Life Burn')
    class.dyinggrasp = common.getAA('Dying Grasp')

    -- Mana Recovery AAs
    class.deathbloom = common.getAA('Death Bloom', {nodmz=true})
    class.bloodmagic = common.getAA('Blood Magic', {nodmz=true})

    class.convergence = common.getAA('Convergence')
    class.rezAbility = class.convergence
    class.summonCompanion = common.getAA('Summon Companion')
    class.neccount = 1
end

function class.initClassOptions()
    class.addOption('STOPPCT', 'DoT Stop Pct', 0, nil, 'Percent HP to stop refreshing DoTs on mobs', 'inputint', nil, 'StopPct', 'int')
    class.addOption('USEDEBUFF', 'Debuff', true, nil, 'Debuff targets with scent', 'checkbox', nil, 'UseDebuff', 'bool')
    class.addOption('USEBUFFSHIELD', 'Buff Shield', false, nil, 'Keep shield buff up. Replaces corruption DoT.', 'checkbox', nil, 'UseBuffShield', 'bool')
    class.addOption('USEMANATAP', 'Mana Drain', false, nil, 'Use group mana drain dot. Replaces Ignite DoT.', 'checkbox', nil, 'UseManaTap', 'bool')
    class.addOption('USEREZ', 'Use Rez', true, nil, 'Use Convergence AA to rez group members', 'checkbox', nil, 'UseRez', 'bool')
    class.addOption('USEFD', 'Feign Death', true, nil, 'Use FD AA\'s to reduce aggro', 'checkbox', nil, 'UseFD', 'bool')
    class.addOption('USEINSPIRE', 'Inspire Ally', true, nil, 'Use Inspire Ally pet buff', 'checkbox', nil, 'UseInspire', 'bool')
    class.addOption('USEDISPEL', 'Use Dispel', true, nil, 'Dispel mobs with Eradicate Magic AA', 'checkbox', nil, 'UseDispel', 'bool')
    class.addOption('USEWOUNDS', 'Use Wounds', true, nil, 'Use wounds DoT', 'checkbox', nil, 'UseWounds', 'bool')
    class.addOption('MULTIDOT', 'Multi DoT', false, nil, 'DoT all mobs', 'checkbox', nil, 'MultiDoT', 'bool')
    class.addOption('MULTICOUNT', 'Multi DoT #', 3, nil, 'Number of mobs to rotate through when multi-dot is enabled', 'inputint', nil, 'MultiCount', 'int')
    class.addOption('USENUKES', 'Use Nukes', true, nil, 'Toggle use of nukes', 'checkbox', nil, 'UseNukes', 'bool')
    class.addOption('USEDOTS', 'Use DoTs', true, nil, 'Toggle use of DoTs, in case mobs are just dying too fast', 'checkbox', nil, 'UseDoTs', 'bool')
    class.addOption('USELICH', 'Use Lich', true, nil, 'Toggle use of lich, incase you\'re just farming and don\'t really need it', 'checkbox', nil, 'UseLich', 'bool')
    class.addOption('BURNPROC', 'Burn on Proc', false, nil, 'Toggle use of burns once proliferation dot lands', 'checkbox', nil, 'BurnProc', 'bool')
end

function class.initSpellLines()
    class.addSpell('composite', {'Composite Paroxysm', 'Dissident Paroxysm', 'Dichotomic Paroxysm'}, {opt='USEDOTS'})
    class.addSpell('wounds', {'Putrefying Wounds', 'Infected Wounds', 'Septic Wounds', 'Cyclotoxic Wounds', 'Mortiferous Wounds', 'Pernicious Wounds', 'Necrotizing Wounds', 'Splirt', 'Splart', 'Splort'}, {opt='USEWOUNDS'})
    class.addSpell('fireshadow', {'Raging Shadow', 'Scalding Shadow', 'Broiling Shadow', 'Burning Shadow', 'Smouldering Shadow', 'Coruscating Shadow', 'Blazing Shadow', 'Blistering Shadow', 'Scorching Shadow'}, {opt='USEDOTS'})
    class.addSpell('pyreshort', {'Pyre of Illandrin', 'Pyre of Va Xakra', 'Pyre of Klraggek', 'Pyre of the Shadewarden', 'Pyre of Jorobb', 'Pyre of Marnek', 'Pyre of Hazarak', 'Pyre of Nos', 'Soul Reaper\'s Pyre', 'Dread Pyre', 'Funeral Pyre of Kelador'}, {opt='USEDOTS'})
    class.addSpell('pyrelong', {'Pyre of the Abandoned', 'Pyre of the Neglected', 'Pyre of the Wretched', 'Pyre of the Fereth', 'Pyre of the Lost', 'Pyre of the Forsaken', 'Pyre of the Piq\'a', 'Pyre of the Bereft', 'Pyre of the Forgotten', 'Pyre of Mori', 'Night Fire'}, {opt='USEDOTS'})
    class.addSpell('venom', {'Luggald Venom', 'Hemorrhagic Venom', 'Crystal Crawler Venom', 'Polybiad Venom', 'Glistenwing Venom', 'Binaesa Venom', 'Naeya Venom', 'Argendev\'s Venom', 'Slitheren Venom', 'Chaos Venom', 'Blood of Thule'}, {opt='USEDOTS'})
    class.addSpell('magic', {'Extermination', 'Extinction', 'Oblivion', 'Inevitable End', 'Annihilation', 'Termination', 'Doom', 'Demise', 'Mortal Coil', 'Dark Nightmare', 'Horror'}, {opt='USEDOTS'})
    class.addSpell('decay', {'Goremand\'s Decay', 'Fleshrot\'s Decay', 'Danvid\'s Decay', 'Mourgis\' Decay', 'Livianus\' Decay', 'Wuran\'s Decay', 'Ulork\'s Decay', 'Folasar\'s Decay', 'Megrima\'s Decay', 'Chaos Plague', 'Dark Plague'}, {opt='USEDOTS'})
    class.addSpell('grip', {'Grip of Terrastride', 'Grip of Quietus', 'Grip of Zorglim', 'Grip of Kraz', 'Grip of Jabaum', 'Grip of Zalikor', 'Grip of Zargo', 'Grip of Mori'}, {opt='USEDOTS'})
    class.addSpell('haze', {'Uncia\'s Pallid Haze', 'Zelnithak\'s Pallid Haze', 'Drachnia\'s Pallid Haze', 'Bomoda\'s Pallid Haze', 'Plexipharia\'s Pallid Haze', 'Halstor\'s Pallid Haze', 'Ivrikdal\'s Pallid Haze', 'Arachne\'s Pallid Haze', 'Fellid\'s Pallid Haze', 'Venom of Anguish'}, {opt='USEDOTS'})
    class.addSpell('grasp', {'Helmsbane\'s Grasp', 'The Protector\'s Grasp', 'Tserrina\'s Grasp', 'Bomoda\'s Grasp', 'Plexipharia\'s Grasp', 'Halstor\'s Grasp', 'Ivrikdal\'s Grasp', 'Arachne\'s Grasp', 'Fellid\'s Grasp', 'Ancient: Curse of Mori', 'Fang of Death'}, {opt='USEDOTS'})
    class.addSpell('leech', {'Ghastly Leech', 'Twilight Leech', 'Frozen Leech', 'Ashen Leech', 'Dark Leech'}, {opt='USEDOTS'})
    class.addSpell('ignite', {'Ignite Remembrance', 'Ignite Cognition', 'Ignite Intellect', 'Ignite Memories', 'Ignite Synapses', 'Ignite Thoughts', 'Ignite Potential', 'Thoughtburn', 'Ignite Energy'}, {opt='USEDOTS'})
    class.addSpell('scourge', {'Scourge of Destiny', 'Scourge of Fates'}, {opt='USEDOTS'})
    class.addSpell('corruption', {'Deterioration', 'Decomposition', 'Miasma', 'Effluvium', 'Liquefaction', 'Dissolution', 'Mortification', 'Fetidity', 'Putrescence'}, {opt='USEDOTS'})
    -- Lifetaps
    class.addSpell('tapee', {'Soullash', 'Soulflay', 'Soulgouge', 'Soulsiphon', 'Soulrend', 'Soulrip', 'Soulspike'}) -- unused
    class.addSpell('tap', {'Maraud Essence', 'Draw Essence', 'Consume Essence', 'Hemorrhage Essence', 'Plunder Essence', 'Bleed Essence', 'Divert Essence', 'Drain Essence', 'Ancient: Touch of Orshilak'}) -- unused
    class.addSpell('tapsummon', {'Vollmondnacht Orb', 'Dusternacht Orb', 'Dunkelnacht Orb', 'Finsternacht Orb', 'Shadow Orb'}) -- unused
    -- Wounds proc
    class.addSpell('proliferation', {'Infected Proliferation', 'Septic Proliferation', 'Cyclotoxic Proliferation', 'Violent Proliferation', 'Violent Necrosis'})
    -- combo dots
    class.addSpell('combodisease', {'Fleshrot\'s Grip of Decay', 'Danvid\'s Grip of Decay', 'Mourgis\' Grip of Decay', 'Livianus\' Grip of Decay'}, {opt='USEDOTS'})
    class.addSpell('chaotic', {'Chaotic Fetor', 'Chaotic Acridness', 'Chaotic Miasma', 'Chaotic Effluvium', 'Chaotic Liquefaction', 'Chaotic Corruption', 'Chaotic Contagion'}, {opt='USEDOTS'}) -- unused
    -- sphere
    class.addSpell('sphere', {'Remote Sphere of Rot', 'Remote Sphere of Withering', 'Remote Sphere of Blight', 'Remote Sphere of Decay', 'Echo of Dissolution', 'Sphere of Dissolution', 'Sphere of Withering', 'Sphere of Blight', 'Withering Decay'}) -- unused
    -- Alliance
    class.addSpell('alliance', {'Malevolent Conjunction', 'Malevolent Coalition', 'Malevolent Covenant', 'Malevolent Alliance'}, {opt='USEALLIANCE'})
    -- Nukes
    class.addSpell('synergy', {'Decree for Blood', 'Proclamation for Blood', 'Assert for Blood', 'Refute for Blood', 'Impose for Blood', 'Impel for Blood', 'Provocation of Blood', 'Compel for Blood', 'Exigency for Blood', 'Call for Blood'}, {opt='USENUKES'})
    class.addSpell('venin', {'Necrotizing Venin', 'Embalming Venin', 'Searing Venin', 'Effluvial Venin', 'Liquefying Venin', 'Dissolving Venin', 'Decaying Venin', 'Blighted Venin', 'Withering Venin', 'Acikin', 'Neurotoxin'}, {opt='USENUKES'})
    -- Debuffs
    class.addSpell('scentterris', {'Scent of Terris'}) -- AA only
    class.addSpell('scentmortality', {'Scent of The Realm', 'Scent of The Grave', 'Scent of Mortality', 'Scent of Extinction', 'Scent of Dread', 'Scent of Nightfall', 'Scent of Doom', 'Scent of Gloom', 'Scent of Midnight'})
    class.addSpell('snare', {'Afflicted Darkness', 'Harrowing Darkness', 'Tormenting Darkness', 'Gnawing Darkness', 'Grasping Darkness', 'Clutching Darkness', 'Viscous Darkness', 'Tenuous Darkness', 'Clawing Darkness', 'Desecrating Darkness'}, {opt='USESNARE'}) -- unused
    -- Mana Drain
    class.addSpell('manatap', {'Mind Disintegrate', 'Mind Atrophy', 'Mind Erosion', 'Mind Excoriation', 'Mind Extraction', 'Mind Strip', 'Mind Abrasion', 'Thought Flay', 'Mind Decomposition', 'Mind Flay'}, {opt='USEMANATAP'})
    -- Buffs
    class.addSpell('lich', {'Realmside', 'Lunaside', 'Gloomside', 'Contraside', 'Forgottenside', 'Forsakenside', 'Shadowside', 'Darkside', 'Netherside', 'Ancient: Allure of Extinction', 'Dark Possession', 'Grave Pact', 'Ancient: Seduction of Chaos'}, {opt='USELICH', nodmz=true})
    class.addSpell('flesh', {'Flesh to Toxin', 'Flesh to Venom', 'Flesh to Poison'})
    class.addSpell('shield', {'Shield of Inescapability', 'Shield of Inevitability', 'Shield of Destiny', 'Shield of Order', 'Shield of Consequence', 'Shield of Fate'})
    class.addSpell('rune', {'Golemskin', 'Carrion Skin', 'Frozen Skin', 'Ashen Skin', 'Deadskin', 'Zombieskin', 'Ghoulskin', 'Grimskin', 'Corpseskin', 'Dull Pain'}) -- unused
    class.addSpell('tapproc', {'Bestow Ruin', 'Bestow Rot', 'Bestow Dread', 'Bestow Relife', 'Bestow Doom', 'Bestow Mortality', 'Bestow Decay', 'Bestow Unlife', 'Bestow Undeath'}) -- unused
    class.addSpell('defensiveproc', {'Necrotic Cysts', 'Necrotic Sores', 'Necrotic Boils', 'Necrotic Pustules'}, {classes={WAR=true,PAL=true,SHD=true}})
    class.addSpell('reflect', {'Mirror'})
    class.addSpell('hpbuff', {'Shield of Memories', 'Shadow Guard', 'Shield of Maelin'}) -- pre-unity
    -- Pet spells
    class.addSpell('pet', {'Merciless Assassin', 'Unrelenting Assassin', 'Restless Assassin', 'Reliving Assassin', 'Revived Assassin', 'Unearthed Assassin', 'Reborn Assassin', 'Raised Assassin', 'Unliving Murderer', 'Dark Assassin', 'Child of Bertoxxulous'})
    class.addSpell('pethaste', {'Sigil of Putrefaction', 'Sigil of Undeath', 'Sigil of Decay', 'Sigil of the Arcron', 'Sigil of the Doomscale', 'Sigil of the Sundered', 'Sigil of the Preternatural', 'Sigil of the Moribund', 'Glyph of Darkness'})
    class.addSpell('petheal', {'Bracing Revival', 'Frigid Salubrity', 'Icy Revival', 'Algid Renewal', 'Icy Mending', 'Algid Mending', 'Chilled Mending', 'Gelid Mending', 'Icy Stitches', 'Dark Salve'}) -- unused
    class.addSpell('petaegis', {'Aegis of Valorforged', 'Aegis of Rumblecrush', 'Aegis of Orfur', 'Aegis of Zeklor', 'Aegis of Japac', 'Aegis of Nefori', 'Phantasmal Ward', 'Bulwark of Calliav'}) -- unused
    class.addSpell('petshield', {'Cascading Runeshield', 'Cascading Shadeshield', 'Cascading Dreadshield', 'Cascading Deathshield', 'Cascading Doomshield', 'Cascading Boneshield', 'Cascading Bloodshield', 'Cascading Deathshield'}) -- unused
    class.addSpell('petillusion', {'Form of Mottled Bone'})
    class.addSpell('inspire', {'Instill Ally', 'Inspire Ally', 'Incite Ally', 'Infuse Ally', 'Imbue Ally', 'Sanction Ally', 'Empower Ally', 'Energize Ally', 'Necrotize Ally'})
    class.addSpell('swarm', {'Call Skeleton Thrall', 'Call Skeleton Mass', 'Call Skeleton Horde', 'Call Skeleton Army', 'Call Skeleton Mob', 'Call Skeleton Throng', 'Call Skeleton Host', 'Call Skeleton Crush', 'Call Skeleton Swarm'})
end

function class.initSpellConditions()
    if class.spells.manatap then class.spells.manatap.condition = function() return (mq.TLO.Group.LowMana(70)() or 0) > 2 end end
    if class.spells.alliance then class.spells.alliance.condition = function() return class.neccount > 1 and not mq.TLO.Target.Buff(class.spells.alliance.Name)() and mq.TLO.Spell(class.spells.alliance.Name).StacksTarget() end end
    if not state.emu and class.spells.synergy then
        class.spells.synergy.condition = function()
            return not mq.TLO.Me.Song('Defiler\'s Synergy')() and mq.TLO.Target.MyBuff(class.spells.pyreshort and class.spells.pyreshort.Name)() and
                    mq.TLO.Target.MyBuff(class.spells.venom and class.spells.venom.Name)() and
                    mq.TLO.Target.MyBuff(class.spells.magic and class.spells.magic.Name)() end
    end
    class.spells.pyreshort.precast = function()
        if class.tcclick and not mq.TLO.Me.Buff('Heretic\'s Twincast')() then
            class.tcclick:use()
        end
    end
    if class.spells.combodisease then
        class.spells.combodisease.condition = function()
            return (not common.isTargetDottedWith(class.spells.decay.ID, class.spells.decay.Name) or not common.isTargetDottedWith(class.spells.grip.ID, class.spells.grip.Name)) and mq.TLO.Me.SpellReady(class.spells.combodisease.Name)()
        end
    end
end

function class.initSpellRotations()
    -- entries in the dots table are pairs of {spell id, spell name} in priority order
    local standard = {}
    if state.emu then table.insert(class.spellRotations.standard, class.spells.decay) end
    table.insert(class.spellRotations.standard, class.spells.alliance)
    table.insert(class.spellRotations.standard, class.spells.wounds)
    table.insert(class.spellRotations.standard, class.spells.composite)
    table.insert(class.spellRotations.standard, class.spells.pyreshort)
    table.insert(class.spellRotations.standard, class.spells.venom)
    table.insert(class.spellRotations.standard, class.spells.magic)
    table.insert(class.spellRotations.standard, class.spells.synergy)
    table.insert(class.spellRotations.standard, class.spells.manatap)
    table.insert(class.spellRotations.standard, class.spells.combodisease)
    table.insert(class.spellRotations.standard, class.spells.haze)
    table.insert(class.spellRotations.standard, class.spells.grasp)
    table.insert(class.spellRotations.standard, class.spells.fireshadow)
    table.insert(class.spellRotations.standard, class.spells.leech)
    table.insert(class.spellRotations.standard, class.spells.pyrelong)
    table.insert(class.spellRotations.standard, class.spells.ignite)
    table.insert(class.spellRotations.standard, class.spells.scourge)
    table.insert(class.spellRotations.standard, class.spells.corruption)

    table.insert(class.spellRotations.short, class.spells.swarm)
    table.insert(class.spellRotations.short, class.spells.alliance)
    table.insert(class.spellRotations.short, class.spells.composite)
    table.insert(class.spellRotations.short, class.spells.pyreshort)
    table.insert(class.spellRotations.short, class.spells.venom)
    table.insert(class.spellRotations.short, class.spells.magic)
    table.insert(class.spellRotations.short, class.spells.synergy)
    table.insert(class.spellRotations.short, class.spells.manatap)
    table.insert(class.spellRotations.short, class.spells.combodisease)
    table.insert(class.spellRotations.short, class.spells.haze)
    table.insert(class.spellRotations.short, class.spells.grasp)
    table.insert(class.spellRotations.short, class.spells.fireshadow)
    table.insert(class.spellRotations.short, class.spells.leech)
    table.insert(class.spellRotations.short, class.spells.pyrelong)
    table.insert(class.spellRotations.short, class.spells.ignite)

    class.swap_gem = 8
    class.swap_gem_dis = 9
end

function class.initBurns()
    -- entries in the items table are MQ item datatypes
    table.insert(class.burnAbilities, common.getItem(mq.TLO.InvSlot('Chest').Item.Name()))
    table.insert(class.burnAbilities, common.getItem('Rage of Rolfron'))
    table.insert(class.burnAbilities, common.getItem('Blightbringer\'s Tunic of the Grave')) -- buff, 5 minute CD
    --table.insert(items, common.getItem('Vicious Rabbit')) -- 5 minute CD
    --table.insert(items, common.getItem('Necromantic Fingerbone')) -- 3 minute CD
    --table.insert(items, common.getItem('Amulet of the Drowned Mariner')) -- 5 minute CD

    class.pre_burn_items = {}
    table.insert(class.pre_burn_items, common.getItem('Blightbringer\'s Tunic of the Grave')) -- buff
    table.insert(class.pre_burn_items, common.getItem(mq.TLO.InvSlot('Chest').Item.Name())) -- buff, Consuming Magic

    -- entries in the AAs table are pairs of {aa name, aa id}
    table.insert(class.burnAbilities, class.silent) -- song, 12 minute CD
    table.insert(class.burnAbilities, common.getAA('Mercurial Torment')) -- buff, 24 minute CD
    table.insert(class.burnAbilities, common.getAA('Heretic\'s Twincast')) -- buff, 15 minute CD
    if not state.emu then
        table.insert(class.burnAbilities, common.getAA('Spire of Necromancy')) -- buff
    else
        table.insert(class.burnAbilities, common.getAA('Fundament: Third Spire of Necromancy')) -- buff, 7:30 minute CD
        table.insert(class.burnAbilities, common.getAA('Embalmer\'s Carapace'))
    end
    table.insert(class.burnAbilities, common.getAA('Hand of Death')) -- song, 8:30 minute CD
    table.insert(class.burnAbilities, common.getAA('Gathering Dusk')) -- song, Duskfall Empowerment, 10 minute CD
    table.insert(class.burnAbilities, common.getAA('Companion\'s Fury')) -- 10 minute CD
    table.insert(class.burnAbilities, common.getAA('Companion\'s Fortification')) -- 15 minute CD
    table.insert(class.burnAbilities, common.getAA('Rise of Bones', {delay=1500})) -- 10 minute CD
    table.insert(class.burnAbilities, common.getAA('Swarm of Decay', {delay=1500})) -- 9 minute CD

    class.glyph = common.getAA('Mythic Glyph of Ultimate Power V')
    class.intensity = common.getAA('Intensity of the Resolute')

    class.wakethedead = common.getAA('Wake the Dead') -- 3 minute CD

    class.funeralpyre = common.getAA('Funeral Pyre') -- song, 20 minute CD

    class.pre_burn_AAs = {}
    table.insert(class.pre_burn_AAs, common.getAA('Mercurial Torment')) -- buff
    table.insert(class.pre_burn_AAs, common.getAA('Heretic\'s Twincast')) -- buff
    if not state.emu then
        table.insert(class.pre_burn_AAs, common.getAA('Spire of Necromancy')) -- buff
    else
        table.insert(class.pre_burn_AAs, common.getAA('Fundament: Third Spire of Necromancy')) -- buff
    end
end

function class.initBuffs()
    -- Buffs
    class.unity = common.getAA('Mortifier\'s Unity')

    if state.emu then
        table.insert(class.selfBuffs, class.spells.lich)
        table.insert(class.selfBuffs, class.spells.hpbuff)
        table.insert(class.selfBuffs, common.getAA('Gift of the Grave', {RemoveBuff='Gift of the Grave Effect'}))
        table.insert(class.singleBuffs, class.spells.defensiveproc)
        table.insert(class.combatBuffs, common.getAA('Reluctant Benevolence'))
    else
        table.insert(class.selfBuffs, class.unity)
    end
    table.insert(class.selfBuffs, class.spells.shield)
    table.insert(class.petBuffs, class.spells.inspire)
    table.insert(class.petBuffs, class.spells.pethaste)
    table.insert(class.petBuffs, common.getAA('Fortify Companion'))
    
    class.addRequestAlias(class.spells.defensiveproc, 'defensiveproc')
end

function class.initDebuffs()
    class.dispel = common.getAA('Eradicate Magic', {opt='USEDISPEL'})

    class.scent = common.getAA('Scent of Thule', {opt='USEDEBUFF'}) or common.getAA('Scent of Terris', {opt='USEDEBUFF'})
    class.debuffTimer = timer:new(30000)
    table.insert(class.debuffs, class.dispel)
    table.insert(class.debuffs, class.scent)
end

function class.initDefensiveAbilities()
    -- Aggro
    local postFD = function()
        mq.delay(1000)
        mq.cmdf('/multiline ; /stand ; /makemevis')
    end
    table.insert(class.fadeAbilities, common.getAA('Death\'s Effigy', {opt='USEFD', postcast=postFD}))
    table.insert(class.aggroReducers, common.getAA('Death Peace', {opt='USEFD', postcast=postFD}))
end

-- Determine swap gem based on wherever wounds, broiling shadow or pyre of the wretched is currently mem'd
local function setSwapGems()
    class.swap_gem = mq.TLO.Me.Gem(class.spells.wounds and class.spells.wounds.Name or 'unknown')() or
            mq.TLO.Me.Gem(class.spells.fireshadow and class.spells.fireshadow.Name or 'unknown')() or
            mq.TLO.Me.Gem(class.spells.pyrelong and class.spells.pyrelong.Name or 'unknown')() or 10
    class.swap_gem_dis = mq.TLO.Me.Gem(class.spells.decay and class.spells.decay.Name or 'unknown')() or
            mq.TLO.Me.Gem(class.spells.grip and class.spells.grip.Name or 'unknown')() or 11
end

--[[
Count the number of necros in group or raid to determine whether alliance should be used.
This is currently only called once up front when the script starts.
]]--
local function countNecros()
    class.neccount = 1
    if mq.TLO.Raid.Members() > 0 then
        class.neccount = mq.TLO.SpawnCount('pc necromancer raid')()
    elseif mq.TLO.Group.Members() then
        class.neccount = mq.TLO.SpawnCount('pc necromancer group')()
    end
end

function class.resetClassTimers()
    class.debuffTimer:reset(0)
end

function class.swapSpells()
    -- Only swap spells in standard spell set
    if state.spellSetLoaded ~= 'standard' or mq.TLO.Me.Moving() then return end

    local woundsName = class.spells.wounds and class.spells.wounds.Name
    local pyrelongName = class.spells.pyrelong and class.spells.pyrelong.Name
    local fireshadowName = class.spells.fireshadow and class.spells.fireshadow.Name
    local woundsDuration = mq.TLO.Target.MyBuffDuration(woundsName)()
    local pyrelongDuration = mq.TLO.Target.MyBuffDuration(pyrelongName)()
    local fireshadowDuration = mq.TLO.Target.MyBuffDuration(fireshadowName)()
    if mq.TLO.Me.Gem(woundsName)() then
        if not class.isEnabled('USEWOUNDS') or (woundsDuration and woundsDuration > 20000) then
            if not pyrelongDuration or pyrelongDuration < 20000 then
                abilities.swapSpell(class.spells.pyrelong, class.swap_gem or 10)
            elseif not fireshadowDuration or fireshadowDuration < 20000 then
                abilities.swapSpell(class.spells.fireshadow, class.swap_gem or 10)
            end
        end
    elseif mq.TLO.Me.Gem(pyrelongName)() then
        if pyrelongDuration and pyrelongDuration > 20000 then
            if class.isEnabled('USEWOUNDS') and (not woundsDuration or woundsDuration < 20000) then
                abilities.swapSpell(class.spells.wounds, class.swap_gem or 10)
            elseif not fireshadowDuration or fireshadowDuration < 20000 then
                abilities.swapSpell(class.spells.fireshadow, class.swap_gem or 10)
            end
        end
    elseif mq.TLO.Me.Gem(fireshadowName)() then
        if fireshadowDuration and fireshadowDuration > 20000 then
            if class.isEnabled('USEWOUNDS') and (not woundsDuration or woundsDuration < 20000) then
                abilities.swapSpell(class.spells.wounds, class.swap_gem or 10)
            elseif not pyrelongDuration or pyrelongDuration < 20000 then
                abilities.swapSpell(class.spells.pyrelong, class.swap_gem or 10)
            end
        end
    else
        -- maybe we got interrupted or something and none of these are mem'd anymore? just memorize wounds again
        abilities.swapSpell(class.spells.wounds, class.swap_gem or 10)
    end
end

-- Check whether a dot is applied to the target
local function targetHasProliferation()
    if not mq.TLO.Target.MyBuff(class.spells.proliferation and class.spells.proliferation.Name)() then return false else return true end
end

local function isNecBurnConditionMet()
    if class.isEnabled('BURNPROC') and targetHasProliferation() then
        logger.info('\arActivating Burns (proliferation proc)\ax')
        state.burnActiveTimer:reset()
        state.burnActive = true
        return true
    end
end

function class.alwaysCondition()
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
function class.burnClass()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag.
    -- Test them both for each item, and see which one(s) actually work.
    --if common.isBurnConditionMet(class.alwaysCondition) or isNecBurnConditionMet() then
    local base_crit = 62
    local auspice = mq.TLO.Me.Song('Auspice of the Hunter')()
    if auspice then base_crit = base_crit + 33 end
    local iog = mq.TLO.Me.Song('Illusions of Grandeur')()
    if iog then base_crit = base_crit + 13 end
    local brd_epic = mq.TLO.Me.Song('Spirit of Vesagran')()
    if brd_epic then base_crit = base_crit + 12 end
    local fierce_eye = mq.TLO.Me.Song('Fierce Eye')()
    if fierce_eye then base_crit = base_crit + 15 end

    if mq.TLO.SpawnCount('corpse radius 150')() > 0 and class.wakethedead then
        class.wakethedead:use()
        mq.delay(1500)
    end

    if config.get('USEGLYPH') and class.intensity and class.glyph then
        if not mq.TLO.Me.Song(class.intensity.Name)() and mq.TLO.Me.Buff('heretic\'s twincast')() then
            class.glyph:use()
        end
    end
    if config.get('USEINTENSITY') and class.glyph and class.intensity then
        if not mq.TLO.Me.Buff(class.glyph.Name)() and mq.TLO.Me.Buff('heretic\'s twincast')() then
            class.intensity:use()
        end
    end

    if class.lifeburn and state.loop.PctHPs > 90 and mq.TLO.Me.AltAbilityReady('Life Burn')() and (state.emu or (class.dyinggrasp and mq.TLO.Me.AltAbilityReady('Dying Grasp')())) then
        class.lifeburn:use()
        mq.delay(5)
        if class.dyinggrasp then class.dyinggrasp:use() end
    end
end

function class.preburn()
    logger.info('Pre-burn')

    for _,item in ipairs(class.pre_burn_items) do
        item:use()
    end

    for _,aa in ipairs(class.pre_burn_AAs) do
        aa:use()
    end

    if config.get('USEGLYPH') and class.intensity and class.glyph then
        if not mq.TLO.Me.Song(class.intensity.Name)() and mq.TLO.Me.Buff('heretic\'s twincast')() then
            class.glyph:use()
        end
    end
end

function class.recover()
    if class.spells.lich and state.loop.PctHPs < 40 and mq.TLO.Me.Buff(class.spells.lich.Name)() then
        logger.info('Removing lich to avoid dying!')
        mq.cmdf('/removebuff %s', class.spells.lich.Name)
    end
    -- modrods
    common.checkMana()
    local pct_mana = state.loop.PctMana
    if class.deathbloom and pct_mana < 65 then
        -- death bloom at some %
        class.deathbloom:use()
    end
    if class.bloodmagic and mq.TLO.Me.CombatState() == 'COMBAT' then
        if pct_mana < 40 then
            -- blood magic at some %
            class.bloodmagic:use()
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
function class.aggroOld()
    if state.emu then return end
    if mode.currentMode:isManualMode() then return end
    if class.isEnabled('USEFD') and mq.TLO.Me.CombatState() == 'COMBAT' and mq.TLO.Target() then
        if mq.TLO.Me.TargetOfTarget.ID() == state.loop.ID or checkAggroTimer:timerExpired() then
            if class.deathseffigy and mq.TLO.Me.PctAggro() >= 90 then
                if class.dyinggrasp and state.loop.PctHPs < 40 and mq.TLO.Me.AltAbilityReady('Dying Grasp')() then
                    class.dyinggrasp:use()
                end
                class.deathseffigy:use()
                if mq.TLO.Me.Feigning() then
                    checkAggroTimer:reset()
                    mq.delay(500)
                    if safeToStand() then
                        mq.TLO.Me.Sit() -- Use a sit TLO to stand up, what wizardry is this?
                        mq.cmd('/makemevis')
                    end
                end
            elseif class.deathpeace and mq.TLO.Me.PctAggro() >= 70 then
                class.deathpeace:use()
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
function class.checkSpellSet()
    if not common.clearToBuff() or mq.TLO.Me.Moving() or class.isEnabled('BYOS') then return end
    local spellSet = class.OPTS.SPELLSET.value
    if state.spellSetLoaded ~= spellSet or checkSpellTimer:timerExpired() then
        if spellSet == 'standard' then
            abilities.swapSpell(class.spells.composite, 1, composite_names)
            abilities.swapSpell(class.spells.pyreshort, 2)
            abilities.swapSpell(class.spells.venom, 3)
            abilities.swapSpell(class.spells.magic, 4)
            abilities.swapSpell(class.spells.haze, 5)
            abilities.swapSpell(class.spells.grasp, 6)
            abilities.swapSpell(class.spells.leech, 7)
            --abilities.swapSpell(class.spells.decay, 11)
            abilities.swapSpell(class.spells.combodisease, 11)
            abilities.swapSpell(class.spells.synergy, 13)
            state.spellSetLoaded = spellSet
        elseif spellSet == 'short' then
            abilities.swapSpell(class.spells.composite, 1, composite_names)
            abilities.swapSpell(class.spells.pyreshort, 2)
            abilities.swapSpell(class.spells.venom, 3)
            abilities.swapSpell(class.spells.magic, 4)
            abilities.swapSpell(class.spells.haze, 5)
            abilities.swapSpell(class.spells.grasp, 6)
            abilities.swapSpell(class.spells.leech, 7)
            --abilities.swapSpell(class.spells.decay, 11)
            abilities.swapSpell(class.spells.combodisease, 11)
            abilities.swapSpell(class.spells.synergy, 13)
            state.spellSetLoaded = spellSet
        end
        checkSpellTimer:reset()
        setSwapGems()
    end
    if spellSet == 'standard' then
        if class.isEnabled('USEMANATAP') then
            abilities.swapSpell(class.spells.manatap, 8)
        else
            abilities.swapSpell(class.spells.ignite, 8)
        end
        if class.isEnabled('USEALLIANCE') then
            abilities.swapSpell(class.spells.alliance, 9)
        else
            if class.isEnabled('USEMANATAP') then
                abilities.swapSpell(class.spells.ignite, 9)
            else
                abilities.swapSpell(class.spells.scourge, 9)
            end
        end
        if class.isEnabled('USEBUFFSHIELD') then
            abilities.swapSpell(class.spells.shield, 12)
        else
            if class.isEnabled('USEMANATAP') and class.isEnabled('USEALLIANCE') then
                abilities.swapSpell(class.spells.ignite, 12)
            elseif class.isEnabled('USEMANATAP') or class.isEnabled('USEALLIANCE') then
                abilities.swapSpell(class.spells.scourge, 12)
            else
                abilities.swapSpell(class.spells.corruption, 12)
            end
        end
        if not class.isEnabled('USEWOUNDS') then
            abilities.swapSpell(class.spells.pyrelong, 10)
        else
            abilities.swapSpell(class.spells.wounds, 10)
        end
    elseif spellSet == 'short' then
        if class.isEnabled('USEMANATAP') then
            abilities.swapSpell(class.spells.manatap, 8)
        else
            abilities.swapSpell(class.spells.ignite, 8)
        end
        if class.isEnabled('USEALLIANCE') then
            abilities.swapSpell(class.spells.alliance, 9)
        else
            if class.isEnabled('USEMANATAP') then
                abilities.swapSpell(class.spells.ignite, 9)
            else
                abilities.swapSpell(class.spells.scourge, 9)
            end
        end
        if class.isEnabled('USEINSPIRE') then
            abilities.swapSpell(class.spells.inspire, 12)
        else
            if class.isEnabled('USEMANATAP') and class.isEnabled('USEALLIANCE') then
                abilities.swapSpell(class.spells.ignite, 12)
            elseif class.isEnabled('USEMANATAP') or class.isEnabled('USEALLIANCE') then
                abilities.swapSpell(class.spells.scourge, 12)
            else
                abilities.swapSpell(class.spells.venin, 12)
            end
        end
        if not class.isEnabled('USEWOUNDS') then
            abilities.swapSpell(class.spells.pyrelong, 10)
        else
            abilities.swapSpell(class.spells.swarm, 10)
        end
    end
end

local necCountTimer = timer:new(60000)

-- if class.isEnabled('USEALLIANCE') and necCountTimer:timerExpired() then
--    countNecros()
--    necCountTimer:reset()
-- end

function class.drawBurnTab()
    class.OPTS.BURNPROC.value = ui.drawCheckBox('Burn On Proc', class.OPTS.BURNPROC.value, 'Burn when proliferation procs')
end

return class