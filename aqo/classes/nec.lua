--- @type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local logger = require('utils.logger')
local timer = require('utils.timer')
local common = require('common')
local config = require('configuration')
local state = require('state')
local ui = require('ui')

function class.init(_aqo)
    class.initBase(_aqo)
    class.load_settings()
    class.setup_events()

    class.class = 'nec'
    class.classOrder = {'assist', 'mash', 'cast', 'burn', 'aggro', 'recover', 'rez', 'buff', 'rest', 'managepet'}

    class.addCommonAbilities()
    class.initializeClassOptions()
    class.initializeSpellLines()
    class.initializeSpellConditions()
    class.initializeSpellRotations()
    class.initializeBurns()
    class.initializeBuffs()

    class.tcclick = common.getItem('Bifold Focus of the Evil Eye')

    -- lifeburn/dying grasp combo
    class.lifeburn = common.getAA('Life Burn')
    class.dyinggrasp = common.getAA('Dying Grasp')

    -- Mana Recovery AAs
    class.deathbloom = common.getAA('Death Bloom')
    class.bloodmagic = common.getAA('Blood Magic')
    -- Agro
    class.deathpeace = common.getAA('Death Peace')
    class.deathseffigy = common.getAA('Death\'s Effigy')

    class.convergence = common.getAA('Convergence')
    class.rezAbility = class.convergence
    class.dispel = common.getAA('Eradicate Magic')

    class.scent = common.getAA('Scent of Thule')
    class.debuff_timer = timer:new(30)

    class.neccount = 1
end

function class.initializeClassOptions()
    class.SPELLSETS = {standard=1,short=1}
    class.addCommonOptions()
    class.addOption('STOPPCT', 'DoT Stop Pct', 0, nil, 'Percent HP to stop refreshing DoTs on mobs', 'inputint')
    class.addOption('DEBUFF', 'Debuff', true, nil, 'Debuff targets', 'checkbox') -- enable use of debuffs
    class.addOption('USEBUFFSHIELD', 'Buff Shield', false, nil, 'Keep shield buff up. Replaces corruption DoT.', 'checkbox')
    class.addOption('USEMANATAP', 'Mana Drain', false, nil, 'Use group mana drain dot. Replaces Ignite DoT.', 'checkbox')
    class.addOption('USEREZ', 'Use Rez', true, nil, 'Use Convergence AA to rez group members', 'checkbox')
    class.addOption('USEFD', 'Feign Death', true, nil, 'Use FD AA\'s to reduce aggro', 'checkbox')
    class.addOption('USEINSPIRE', 'Inspire Ally', true, nil, 'Use Inspire Ally pet buff', 'checkbox')
    class.addOption('USEDISPEL', 'Use Dispel', true, nil, 'Dispel mobs with Eradicate Magic AA', 'checkbox')
    class.addOption('USEWOUNDS', 'Use Wounds', true, nil, 'Use wounds DoT', 'checkbox')
    class.addOption('MULTIDOT', 'Multi DoT', false, nil, 'DoT all mobs', 'checkbox')
    class.addOption('MULTICOUNT', 'Multi DoT #', 3, nil, 'Number of mobs to rotate through when multi-dot is enabled', 'inputint')
    class.addOption('USENUKES', 'Use Nukes', true, nil, 'Toggle use of nukes', 'checkbox')
    class.addOption('USEDOTS', 'Use DoTs', true, nil, 'Toggle use of DoTs, in case mobs are just dying too fast', 'checkbox')
    class.addOption('USELICH', 'Use Lich', true, nil, 'Toggle use of lich, incase you\'re just farming and don\'t really need it', 'checkbox')
    class.addOption('BURNPROC', 'Burn on Proc', false, nil, 'Toggle use of burns once proliferation dot lands', 'checkbox')
end

function class.initializeSpellLines()
    class.addSpell('composite', {'Composite Paroxysm', 'Dissident Paroxysm', 'Dichotomic Paroxysm'})
    class.addSpell('wounds', {'Infected Wounds', 'Septic Wounds', 'Cyclotoxic Wounds', 'Mortiferous Wounds', 'Pernicious Wounds', 'Necrotizing Wounds', 'Splirt', 'Splart', 'Splort'})
    class.addSpell('fireshadow', {'Scalding Shadow', 'Broiling Shadow', 'Burning Shadow', 'Smouldering Shadow', 'Coruscating Shadow', 'Blazing Shadow', 'Blistering Shadow', 'Scorching Shadow'})
    class.addSpell('pyreshort', {'Pyre of Va Xakra', 'Pyre of Klraggek', 'Pyre of the Shadewarden', 'Pyre of Jorobb', 'Pyre of Marnek', 'Pyre of Hazarak', 'Pyre of Nos', 'Soul Reaper\'s Pyre', 'Dread Pyre', 'Funeral Pyre of Kelador'})
    class.addSpell('pyrelong', {'Pyre of the Neglected', 'Pyre of the Wretched', 'Pyre of the Fereth', 'Pyre of the Lost', 'Pyre of the Forsaken', 'Pyre of the Piq\'a', 'Pyre of the Bereft', 'Pyre of the Forgotten', 'Pyre of Mori', 'Night Fire'})
    class.addSpell('venom', {'Hemorrhagic Venom', 'Crystal Crawler Venom', 'Polybiad Venom', 'Glistenwing Venom', 'Binaesa Venom', 'Naeya Venom', 'Argendev\'s Venom', 'Slitheren Venom', 'Chaos Venom', 'Blood of Thule'})
    class.addSpell('magic', {'Extinction', 'Oblivion', 'Inevitable End', 'Annihilation', 'Termination', 'Doom', 'Demise', 'Mortal Coil', 'Dark Nightmare', 'Horror'})
    class.addSpell('decay', {'Fleshrot\'s Decay', 'Danvid\'s Decay', 'Mourgis\' Decay', 'Livianus\' Decay', 'Wuran\'s Decay', 'Ulork\'s Decay', 'Folasar\'s Decay', 'Megrima\'s Decay', 'Chaos Plague', 'Dark Plague'})
    class.addSpell('grip', {'Grip of Quietus', 'Grip of Zorglim', 'Grip of Kraz', 'Grip of Jabaum', 'Grip of Zalikor', 'Grip of Zargo', 'Grip of Mori'})
    class.addSpell('haze', {'Zelnithak\'s Pallid Haze', 'Drachnia\'s Pallid Haze', 'Bomoda\'s Pallid Haze', 'Plexipharia\'s Pallid Haze', 'Halstor\'s Pallid Haze', 'Ivrikdal\'s Pallid Haze', 'Arachne\'s Pallid Haze', 'Fellid\'s Pallid Haze', 'Venom of Anguish'})
    class.addSpell('grasp', {'The Protector\'s Grasp', 'Tserrina\'s Grasp', 'Bomoda\'s Grasp', 'Plexipharia\'s Grasp', 'Halstor\'s Grasp', 'Ivrikdal\'s Grasp', 'Arachne\'s Grasp', 'Fellid\'s Grasp', 'Ancient: Curse of Mori', 'Fang of Death'})
    class.addSpell('leech', {'Twilight Leech', 'Frozen Leech', 'Ashen Leech', 'Dark Leech'})
    class.addSpell('ignite', {'Ignite Cognition', 'Ignite Intellect', 'Ignite Memories', 'Ignite Synapses', 'Ignite Thoughts', 'Ignite Potential', 'Thoughtburn', 'Ignite Energy'})
    class.addSpell('scourge', {'Scourge of Destiny', 'Scourge of Fates'})
    class.addSpell('corruption', {'Decomposition', 'Miasma', 'Effluvium', 'Liquefaction', 'Dissolution', 'Mortification', 'Fetidity', 'Putrescence'})
    -- Lifetaps
    class.addSpell('tapee', {'Soulflay', 'Soulgouge', 'Soulsiphon', 'Soulrend', 'Soulrip', 'Soulspike'}) -- unused
    class.addSpell('tap', {'Maraud Essence', 'Draw Essence', 'Consume Essence', 'Hemorrhage Essence', 'Plunder Essence', 'Bleed Essence', 'Divert Essence', 'Drain Essence', 'Ancient: Touch of Orshilak'}) -- unused
    class.addSpell('tapsummon', {'Vollmondnacht Orb', 'Dusternacht Orb', 'Dunkelnacht Orb', 'Finsternacht Orb', 'Shadow Orb'}) -- unused
    -- Wounds proc
    class.addSpell('proliferation', {'Infected Proliferation', 'Septic Proliferation', 'Cyclotoxic Proliferation', 'Violent Proliferation', 'Violent Necrosis'})
    -- combo dots
    class.addSpell('combodisease', {'Fleshrot\'s Grip of Decay', 'Danvid\'s Grip of Decay', 'Mourgis\' Grip of Decay', 'Livianus\' Grip of Decay'})
    class.addSpell('chaotic', {'Chaotic Acridness', 'Chaotic Miasma', 'Chaotic Effluvium', 'Chaotic Liquefaction', 'Chaotic Corruption', 'Chaotic Contagion'}) -- unused
    -- sphere
    class.addSpell('sphere', {'Remote Sphere of Rot', 'Remote Sphere of Withering', 'Remote Sphere of Blight', 'Remote Sphere of Decay', 'Echo of Dissolution', 'Sphere of Dissolution', 'Sphere of Withering', 'Sphere of Blight', 'Withering Decay'}) -- unused
    -- Alliance
    class.addSpell('alliance', {'Malevolent Conjunction', 'Malevolent Coalition', 'Malevolent Covenant', 'Malevolent Alliance'})
    -- Nukes
    class.addSpell('synergy', {'Proclamation for Blood', 'Assert for Blood', 'Refute for Blood', 'Impose for Blood', 'Impel for Blood', 'Provocation of Blood', 'Compel for Blood', 'Exigency for Blood', 'Call for Blood'})
    class.addSpell('venin', {'Embalming Venin', 'Searing Venin', 'Effluvial Venin', 'Liquefying Venin', 'Dissolving Venin', 'Decaying Venin', 'Blighted Venin', 'Withering Venin', 'Acikin', 'Neurotoxin'})
    -- Debuffs
    class.addSpell('scentterris', {'Scent of Terris'}) -- AA only
    class.addSpell('scentmortality', {'Scent of The Grave', 'Scent of Mortality', 'Scent of Extinction', 'Scent of Dread', 'Scent of Nightfall', 'Scent of Doom', 'Scent of Gloom', 'Scent of Midnight'})
    class.addSpell('snare', {'Harrowing Darkness', 'Tormenting Darkness', 'Gnawing Darkness', 'Grasping Darkness', 'Clutching Darkness', 'Viscous Darkness', 'Tenuous Darkness', 'Clawing Darkness', 'Desecrating Darkness'}) -- unused
    -- Mana Drain
    class.addSpell('manatap', {'Mind Atrophy', 'Mind Erosion', 'Mind Excoriation', 'Mind Extraction', 'Mind Strip', 'Mind Abrasion', 'Thought Flay', 'Mind Decomposition', 'Mind Flay'})
    -- Buffs
    class.addSpell('lich', {'Lunaside', 'Gloomside', 'Contraside', 'Forgottenside', 'Forsakenside', 'Shadowside', 'Darkside', 'Netherside', 'Ancient: Allure of Extinction', 'Dark Possession', 'Grave Pact', 'Ancient: Seduction of Chaos'}, {opt='USELICH'})
    class.addSpell('flesh', {'Flesh to Toxin', 'Flesh to Venom', 'Flesh to Poison'})
    class.addSpell('shield', {'Shield of Inevitability', 'Shield of Destiny', 'Shield of Order', 'Shield of Consequence', 'Shield of Fate'})
    class.addSpell('rune', {'Carrion Skin', 'Frozen Skin', 'Ashen Skin', 'Deadskin', 'Zombieskin', 'Ghoulskin', 'Grimskin', 'Corpseskin', 'Dull Pain'}) -- unused
    class.addSpell('tapproc', {'Bestow Rot', 'Bestow Dread', 'Bestow Relife', 'Bestow Doom', 'Bestow Mortality', 'Bestow Decay', 'Bestow Unlife', 'Bestow Undeath'}) -- unused
    class.addSpell('defensiveproc', {'Necrotic Cysts', 'Necrotic Sores', 'Necrotic Boils', 'Necrotic Pustules'}, {classes={WAR=true,PAL=true,SHD=true}})
    class.addSpell('reflect', {'Mirror'})
    class.addSpell('hpbuff', {'Shadow Guard', 'Shield of Maelin'}) -- pre-unity
    -- Pet spells
    class.addSpell('pet', {'Unrelenting Assassin', 'Restless Assassin', 'Reliving Assassin', 'Revived Assassin', 'Unearthed Assassin', 'Reborn Assassin', 'Raised Assassin', 'Unliving Murderer', 'Dark Assassin', 'Child of Bertoxxulous'})
    class.addSpell('pethaste', {'Sigil of Undeath', 'Sigil of Decay', 'Sigil of the Arcron', 'Sigil of the Doomscale', 'Sigil of the Sundered', 'Sigil of the Preternatural', 'Sigil of the Moribund', 'Glyph of Darkness'})
    class.addSpell('petheal', {'Frigid Salubrity', 'Icy Revival', 'Algid Renewal', 'Icy Mending', 'Algid Mending', 'Chilled Mending', 'Gelid Mending', 'Icy Stitches', 'Dark Salve'}) -- unused
    class.addSpell('petaegis', {'Aegis of Rumblecrush', 'Aegis of Orfur', 'Aegis of Zeklor', 'Aegis of Japac', 'Aegis of Nefori', 'Phantasmal Ward', 'Bulwark of Calliav'}) -- unused
    class.addSpell('petshield', {'Cascading Shadeshield', 'Cascading Dreadshield', 'Cascading Deathshield', 'Cascading Doomshield', 'Cascading Boneshield', 'Cascading Bloodshield', 'Cascading Deathshield'}) -- unused
    class.addSpell('petillusion', {'Form of Mottled Bone'})
    class.addSpell('inspire', {'Inspire Ally', 'Incite Ally', 'Infuse Ally', 'Imbue Ally', 'Sanction Ally', 'Empower Ally', 'Energize Ally', 'Necrotize Ally'})
    class.addSpell('swarm', {'Call Skeleton Mass', 'Call Skeleton Horde', 'Call Skeleton Army', 'Call Skeleton Mob', 'Call Skeleton Throng', 'Call Skeleton Host', 'Call Skeleton Crush', 'Call Skeleton Swarm'})
end

function class.initializeSpellConditions()
    if class.spells.manatap then class.spells.manatap.condition = function() return class.isAbilityEnabled(class.spells.manatap.opt) and (mq.TLO.Group.LowMana(70)() or 0) > 2 end end
    if class.spells.alliance then class.spells.alliance.condition = function() return class.neccount > 1 and not mq.TLO.Target.Buff(class.spells.alliance.name)() and mq.TLO.Spell(class.spells.alliance.name).StacksTarget() end end
    if not state.emu and class.spells.synergy then
        class.spells.synergy.condition = function()
            return not mq.TLO.Me.Song('Defiler\'s Synergy')() and mq.TLO.Target.MyBuff(class.spells.pyreshort and class.spells.pyreshort.name)() and
                    mq.TLO.Target.MyBuff(class.spells.venom and class.spells.venom.name)() and
                    mq.TLO.Target.MyBuff(class.spells.magic and class.spells.magic.name)() end
    end
    class.spells.pyreshort.precast = function()
        if class.tcclick and not mq.TLO.Me.Buff('Heretic\'s Twincast')() then
            class.tcclick:use()
        end
    end
end

function class.initializeSpellRotations()
    -- entries in the dots table are pairs of {spell id, spell name} in priority order
    local standard = {}
    table.insert(standard, class.spells.alliance)
    table.insert(standard, class.spells.wounds)
    table.insert(standard, class.spells.composite)
    table.insert(standard, class.spells.pyreshort)
    table.insert(standard, class.spells.venom)
    table.insert(standard, class.spells.magic)
    table.insert(standard, class.spells.manatap)
    table.insert(standard, class.spells.combodisease)
    table.insert(standard, class.spells.haze)
    table.insert(standard, class.spells.grasp)
    table.insert(standard, class.spells.fireshadow)
    table.insert(standard, class.spells.leech)
    table.insert(standard, class.spells.pyrelong)
    table.insert(standard, class.spells.ignite)
    table.insert(standard, class.spells.scourge)
    table.insert(standard, class.spells.corruption)

    local short = {}
    table.insert(short, class.spells.swarm)
    table.insert(short, class.spells.composite)
    table.insert(short, class.spells.pyreshort)
    table.insert(short, class.spells.venom)
    table.insert(short, class.spells.magic)
    table.insert(short, class.spells.combodisease)
    table.insert(short, class.spells.haze)
    table.insert(short, class.spells.grasp)
    table.insert(short, class.spells.fireshadow)
    table.insert(short, class.spells.leech)
    table.insert(short, class.spells.pyrelong)
    table.insert(short, class.spells.ignite)

    class.spellRotations = {
        standard=standard,
        short=short,
    }

    class.swap_gem = 8
    class.swap_gem_dis = 9
end

function class.initializeBurns()
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
    table.insert(class.burnAbilities, common.getAA('Silent Casting')) -- song, 12 minute CD
    table.insert(class.burnAbilities, common.getAA('Focus of Arcanum')) -- buff, 10 minute CD
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
    table.insert(class.pre_burn_AAs, common.getAA('Focus of Arcanum')) -- buff
    table.insert(class.pre_burn_AAs, common.getAA('Mercurial Torment')) -- buff
    table.insert(class.pre_burn_AAs, common.getAA('Heretic\'s Twincast')) -- buff
    if not state.emu then
        table.insert(class.pre_burn_AAs, common.getAA('Spire of Necromancy')) -- buff
    else
        table.insert(class.pre_burn_AAs, common.getAA('Fundament: Third Spire of Necromancy')) -- buff
    end
end

function class.initializeBuffs()
    -- Buffs
    class.unity = common.getAA('Mortifier\'s Unity')

    if state.emu then
        table.insert(class.selfBuffs, class.spells.lich)
        table.insert(class.selfBuffs, class.spells.hpbuff)
        table.insert(class.selfBuffs, common.getAA('Gift of the Grave', {removesong='Gift of the Grave Effect'}))
        table.insert(class.singleBuffs, class.spells.defensiveproc)
        table.insert(class.combatBuffs, common.getAA('Reluctant Benevolence'))
    else
        table.insert(class.selfBuffs, class.unity)
    end
    table.insert(class.selfBuffs, class.spells.shield)
    table.insert(class.petBuffs, class.spells.inspire)
    table.insert(class.petBuffs, class.spells.pethaste)

    class.buffs={
        self={},
        pet={
            class.spells.pethaste,
            class.spells.petillusion,
        },
    }

    class.addRequestAlias(class.spells.defensiveproc, 'defensiveproc')
end

-- Determine swap gem based on wherever wounds, broiling shadow or pyre of the wretched is currently mem'd
local function set_swap_gems()
    class.swap_gem = mq.TLO.Me.Gem(class.spells.wounds and class.spells.wounds.name or 'unknown')() or
            mq.TLO.Me.Gem(class.spells.fireshadow and class.spells.fireshadow.name or 'unknown')() or
            mq.TLO.Me.Gem(class.spells.pyrelong and class.spells.pyrelong.name or 'unknown')() or 10
            class.swap_gem_dis = mq.TLO.Me.Gem(class.spells.decay and class.spells.decay.name or 'unknown')() or mq.TLO.Me.Gem(class.spells.grip and class.spells.grip.name or 'unknown')() or 11
end

--[[
Count the number of necros in group or raid to determine whether alliance should be used.
This is currently only called once up front when the script starts.
]]--
local function get_necro_count()
    class.neccount = 1
    if mq.TLO.Raid.Members() > 0 then
        class.neccount = mq.TLO.SpawnCount('pc necromancer raid')()
    elseif mq.TLO.Group.Members() then
        class.neccount = mq.TLO.SpawnCount('pc necromancer group')()
    end
end

class.reset_class_timers = function()
    class.debuff_timer:reset(0)
end

local function should_swap_dots()
    -- Only swap spells in standard spell set
    if state.spellset_loaded ~= 'standard' or mq.TLO.Me.Moving() then return end

    local woundsName = class.spells.wounds and class.spells.wounds.name
    local pyrelongName = class.spells.pyrelong and class.spells.pyrelong.name
    local fireshadowName = class.spells.fireshadow and class.spells.fireshadow.name
    local woundsDuration = mq.TLO.Target.MyBuffDuration(woundsName)()
    local pyrelongDuration = mq.TLO.Target.MyBuffDuration(pyrelongName)()
    local fireshadowDuration = mq.TLO.Target.MyBuffDuration(fireshadowName)()
    if mq.TLO.Me.Gem(woundsName)() then
        if not class.OPTS.USEWOUNDS.value or (woundsDuration and woundsDuration > 20000) then
            if not pyrelongDuration or pyrelongDuration < 20000 then
                common.swap_spell(class.spells.pyrelong, class.swap_gem or 10)
            elseif not fireshadowDuration or fireshadowDuration < 20000 then
                common.swap_spell(class.spells.fireshadow, class.swap_gem or 10)
            end
        end
    elseif mq.TLO.Me.Gem(pyrelongName)() then
        if pyrelongDuration and pyrelongDuration > 20000 then
            if class.OPTS.USEWOUNDS.value and (not woundsDuration or woundsDuration < 20000) then
                common.swap_spell(class.spells.wounds, class.swap_gem or 10)
            elseif not fireshadowDuration or fireshadowDuration < 20000 then
                common.swap_spell(class.spells.fireshadow, class.swap_gem or 10)
            end
        end
    elseif mq.TLO.Me.Gem(fireshadowName)() then
        if fireshadowDuration and fireshadowDuration > 20000 then
            if class.OPTS.USEWOUNDS.value and (not woundsDuration or woundsDuration < 20000) then
                common.swap_spell(class.spells.wounds, class.swap_gem or 10)
            elseif not pyrelongDuration or pyrelongDuration < 20000 then
                common.swap_spell(class.spells.pyrelong, class.swap_gem or 10)
            end
        end
    else
        -- maybe we got interrupted or something and none of these are mem'd anymore? just memorize wounds again
        common.swap_spell(class.spells.wounds, class.swap_gem or 10)
    end

    -- Using combo disease spell instead of swapping between grip and decay
    --[[local decayName = class.spells.decay and class.spells.decay.name
    local gripName = class.spells.grip and class.spells.grip.name
    local decayDuration = mq.TLO.Target.MyBuffDuration(decayName)()
    local gripDuration = mq.TLO.Target.MyBuffDuration(gripName)()
    if mq.TLO.Me.Gem(decayName)() then
        if decayDuration and decayDuration > 20000 then
            if not gripDuration or gripDuration < 20000 then
                common.swap_spell(class.spells.grip, swap_gem_dis or 11)
            end
        end
    elseif mq.TLO.Me.Gem(gripName)() then
        if gripDuration and gripDuration > 20000 then
            if not decayDuration or decayDuration < 20000 then
                common.swap_spell(class.spells.decay, swap_gem_dis or 11)
            end
        end
    else
        -- maybe we got interrupted or something and none of these are mem'd anymore? just memorize decay again
        common.swap_spell(class.spells.decay, swap_gem_dis or 11)
    end]]
end

--[[class.find_next_spell = function()
    if try_alliance() then return nil end
    if not state.emu then
        cast_synergy()
        return nil
    end
    -- Just cast composite as part of the normal dot rotation, no special handling
    --if common.is_spell_ready(spells.composite.id, spells.composite.name) then
    --    return spells.composite.id, spells.composite.name
    --end
    if class.isEnabled('USEMANATAP') and class.spells.manatap and state.loop.PctMana < 40 and mq.TLO.Me.SpellReady(class.spells.manatap.name)() and mq.TLO.Spell(class.spells.manatap.name).Mana() < mq.TLO.Me.CurrentMana() then
        return class.spells.manatap
    end
    if class.spells.swarm and mq.TLO.Me.SpellReady(class.spells.swarm.name)() and mq.TLO.Spell(class.spells.swarm.name).Mana() < mq.TLO.Me.CurrentMana() then
        return class.spells.swarm
    end
    local pct_hp = mq.TLO.Target.PctHPs()
    if pct_hp and pct_hp > class.OPTS.STOPPCT.value and class.isEnabled('USEDOTS') then
        for _,dot in ipairs(class.spellRotations[class.OPTS.SPELLSET.value]) do -- iterates over the dots array. ipairs(dots) returns 2 values, an index and its value in the array. we don't care about the index, we just want the dot
            local resistCount = (state.resists[dot.name] and state.resists[dot.name]) or 0
            if class.spells.combodisease and dot.id == class.spells.combodisease.id and resistCount < config.RESISTSTOPCOUNT.value then
                if (not common.is_target_dotted_with(class.spells.decay.id, class.spells.decay.name) or not common.is_target_dotted_with(class.spells.grip.id, class.spells.grip.name)) and mq.TLO.Me.SpellReady(class.spells.combodisease.name)() then
                    return dot
                end
            end
            if (class.OPTS.USEWOUNDS.value or not class.spells.wounds or dot.id ~= class.spells.wounds.id) and common.is_spell_ready(dot) and resistCount < config.RESISTSTOPCOUNT.value then
                return dot -- if is_dot_ready returned true then return this dot as the dot we should cast
            end
        end
    end
    if class.isEnabled('USEMANATAP') and class.spells.manatap and mq.TLO.Me.SpellReady(class.spells.manatap.name)() and mq.TLO.Spell(class.spells.manatap.name).Mana() < mq.TLO.Me.CurrentMana() then
        return class.spells.manatap
    end
    if class.isEnabled('USENUKES') and class.spells.venin and mq.TLO.Me.SpellReady(class.spells.venin.name)() and mq.TLO.Spell(class.spells.venin.name).Mana() < mq.TLO.Me.CurrentMana() then
        return class.spells.venin
    end
    if state.emu then
        cast_synergy()
    end
    return nil -- we found no missing dot that was ready to cast, so return nothing
end
]]

-- Check whether a dot is applied to the target
local function target_has_proliferation()
    if not mq.TLO.Target.MyBuff(class.spells.proliferation and class.spells.proliferation.name)() then return false else return true end
end

local function is_nec_burn_condition_met()
    if class.OPTS.BURNPROC.value and target_has_proliferation() then
        print(logger.logLine('\arActivating Burns (proliferation proc)\ax'))
        state.burn_active_timer:reset()
        state.burn_active = true
        return true
    end
end

class.always_condition = function()
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
class.burn_class = function()
    -- Some items use Timer() and some use IsItemReady(), this seems to be mixed bag.
    -- Test them both for each item, and see which one(s) actually work.
    --if common.is_burn_condition_met(class.always_condition) or is_nec_burn_condition_met() then
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

    if class.OPTS.USEGLYPH.value and class.intensity and class.glyph then
        if not mq.TLO.Me.Song(class.intensity.name)() and mq.TLO.Me.Buff('heretic\'s twincast')() then
            class.glyph:use()
        end
    end
    if class.OPTS.USEINTENSITY.value and class.glyph and class.intensity then
        if not mq.TLO.Me.Buff(class.glyph.name)() and mq.TLO.Me.Buff('heretic\'s twincast')() then
            class.intensity:use()
        end
    end

    if class.lifeburn and class.dyinggrasp and state.loop.PctHPs > 90 and mq.TLO.Me.AltAbilityReady('Life Burn')() and mq.TLO.Me.AltAbilityReady('Dying Grasp')() then
        class.lifeburn:use()
        mq.delay(5)
        class.dyinggrasp:use()
    end
end

function class.preburn()
    print(logger.logLine('Pre-burn'))

    for _,item in ipairs(class.pre_burn_items) do
        item:use()
    end

    for _,aa in ipairs(class.pre_burn_AAs) do
        aa:use()
    end

    if class.OPTS.USEGLYPH.value and class.intensity and class.glyph then
        if not mq.TLO.Me.Song(class.intensity.name)() and mq.TLO.Me.Buff('heretic\'s twincast')() then
            class.glyph:use()
        end
    end
end

class.recover = function()
    if class.spells.lich and state.loop.PctHPs < 40 and mq.TLO.Me.Buff(class.spells.lich.name)() then
        print(logger.logLine('Removing lich to avoid dying!'))
        mq.cmdf('/removebuff %s', class.spells.lich.name)
    end
    -- modrods
    common.check_mana()
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

local function safe_to_stand()
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

local check_aggro_timer = timer:new(10)
class.aggro = function()
    if state.emu then return end
    if config.MODE.value:is_manual_mode() then return end
    if class.OPTS.USEFD.value and mq.TLO.Me.CombatState() == 'COMBAT' and mq.TLO.Target() then
        if mq.TLO.Me.TargetOfTarget.ID() == state.loop.ID or check_aggro_timer:timer_expired() then
            if class.deathseffigy and mq.TLO.Me.PctAggro() >= 90 then
                if class.dyinggrasp and state.loop.PctHPs < 40 and mq.TLO.Me.AltAbilityReady('Dying Grasp')() then
                    class.dyinggrasp:use()
                end
                class.deathseffigy:use()
                if mq.TLO.Me.Feigning() then
                    check_aggro_timer:reset()
                    mq.delay(500)
                    if safe_to_stand() then
                        mq.TLO.Me.Sit() -- Use a sit TLO to stand up, what wizardry is this?
                        mq.cmd('/makemevis')
                    end
                end
            elseif class.deathpeace and mq.TLO.Me.PctAggro() >= 70 then
                class.deathpeace:use()
                if mq.TLO.Me.Feigning() then
                    check_aggro_timer:reset()
                    mq.delay(500)
                    if safe_to_stand() then
                        mq.TLO.Me.Sit() -- Use a sit TLO to stand up, what wizardry is this?
                        mq.cmd('/makemevis')
                    end
                end
            end
        end
    end
end

local composite_names = {['Composite Paroxysm']=true, ['Dissident Paroxysm']=true, ['Dichotomic Paroxysm']=true}
local check_spell_timer = timer:new(30)
class.check_spell_set = function()
    if not common.clear_to_buff() or mq.TLO.Me.Moving() then return end
    if state.spellset_loaded ~= class.OPTS.SPELLSET.value or check_spell_timer:timer_expired() then
        if class.OPTS.SPELLSET.value == 'standard' then
            common.swap_spell(class.spells.composite, 1, composite_names)
            common.swap_spell(class.spells.pyreshort, 2)
            common.swap_spell(class.spells.venom, 3)
            common.swap_spell(class.spells.magic, 4)
            common.swap_spell(class.spells.haze, 5)
            common.swap_spell(class.spells.grasp, 6)
            common.swap_spell(class.spells.leech, 7)
            --common.swap_spell(class.spells.decay, 11)
            common.swap_spell(class.spells.combodisease, 11)
            common.swap_spell(class.spells.synergy, 13)
            state.spellset_loaded = class.OPTS.SPELLSET.value
        elseif class.OPTS.SPELLSET.value == 'short' then
            common.swap_spell(class.spells.composite, 1, composite_names)
            common.swap_spell(class.spells.pyreshort, 2)
            common.swap_spell(class.spells.venom, 3)
            common.swap_spell(class.spells.magic, 4)
            common.swap_spell(class.spells.haze, 5)
            common.swap_spell(class.spells.grasp, 6)
            common.swap_spell(class.spells.leech, 7)
            --common.swap_spell(class.spells.decay, 11)
            common.swap_spell(class.spells.combodisease, 11)
            common.swap_spell(class.spells.synergy, 13)
            state.spellset_loaded = class.OPTS.SPELLSET.value
        end
        check_spell_timer:reset()
        set_swap_gems()
    end
    if class.OPTS.SPELLSET.value == 'standard' then
        if class.isEnabled('USEMANATAP') then
            common.swap_spell(class.spells.manatap, 8)
        else
            common.swap_spell(class.spells.ignite, 8)
        end
        if class.isEnabled('USEALLIANCE') then
            common.swap_spell(class.spells.alliance, 9)
        else
            if class.isEnabled('USEMANATAP') then
                common.swap_spell(class.spells.ignite, 9)
            else
                common.swap_spell(class.spells.scourge, 9)
            end
        end
        if class.isEnabled('USEBUFFSHIELD') then
            common.swap_spell(class.spells.shield, 12)
        else
            if class.isEnabled('USEMANATAP') and class.isEnabled('USEALLIANCE') then
                common.swap_spell(class.spells.ignite, 12)
            elseif class.isEnabled('USEMANATAP') or class.isEnabled('USEALLIANCE') then
                common.swap_spell(class.spells.scourge, 12)
            else
                common.swap_spell(class.spells.corruption, 12)
            end
        end
        if not class.OPTS.USEWOUNDS then
            common.swap_spell(class.spells.pyrelong, 10)
        else
            common.swap_spell(class.spells.wounds, 10)
        end
    elseif class.OPTS.SPELLSET.value == 'short' then
        if class.isEnabled('USEMANATAP') then
            common.swap_spell(class.spells.manatap, 8)
        else
            common.swap_spell(class.spells.ignite, 8)
        end
        if class.isEnabled('USEALLIANCE') then
            common.swap_spell(class.spells.alliance, 9)
        else
            if class.isEnabled('USEMANATAP') then
                common.swap_spell(class.spells.ignite, 9)
            else
                common.swap_spell(class.spells.scourge, 9)
            end
        end
        if class.isEnabled('USEINSPIRE') then
            common.swap_spell(class.spells.inspire, 12)
        else
            if class.isEnabled('USEMANATAP') and class.isEnabled('USEALLIANCE') then
                common.swap_spell(class.spells.ignite, 12)
            elseif class.isEnabled('USEMANATAP') or class.isEnabled('USEALLIANCE') then
                common.swap_spell(class.spells.scourge, 12)
            else
                common.swap_spell(class.spells.venin, 12)
            end
        end
        if not class.OPTS.USEWOUNDS then
            common.swap_spell(class.spells.pyrelong, 10)
        else
            common.swap_spell(class.spells.swarm, 10)
        end
    end
end

local nec_count_timer = timer:new(60)

-- if class.OPTS.USEALLIANCE.value and nec_count_timer:timer_expired() then
--    get_necro_count()
--    nec_count_timer:reset()
-- end

class.draw_burn_tab = function()
    class.OPTS.BURNPROC.value = ui.draw_check_box('Burn On Proc', '##burnproc', class.OPTS.BURNPROC.value, 'Burn when proliferation procs')
end

return class