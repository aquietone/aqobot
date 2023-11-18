---@type Mq
local mq = require 'mq'
local class = require('classes.classbase')
local timer = require('utils.timer')
local common = require('common')
local config = require('interface.configuration')

local Shaman = class:new()
--[[
    http://forums.eqfreelance.net/index.php?topic=9389.0
    
    -- Self buffs
    self:addSpell('selfprocheal', {'Watchful Spirit', 'Attentive Spirit', 'Responsive Spirit'}) -- self buff, proc heal when hit
    table.insert(self.selfBuffs, common.getAA('Pact of the Wolf'))
    table.insert(self.selfBuffs, self.spells.selfprocheal)
    table.insert(self.selfBuffs, common.getAA('Preincarnation'))

    -- Keep up on group
    self:addSpell('grouphot', {'Reverie of Renewal', 'Spirit of Renewal', 'Spectre of Renewal', 'Cloud of Renewal', 'Shear of Renewal'}) -- group HoT
    self:addSpell('composite', {'Ecliptic Roar', 'Composite Roar', 'Dissident Roar', 'Dichotomic Roar'}) -- stacks with HoT but overwrites regen, blocked by dots

    -- Use Often
    self:addSpell('splash', {'Spiritual Shower', 'Spiritual Squall', 'Spiritual Swell'}) -- splash, easiest to cast on self, requires los
    self:addSpell('recourse', {'Grayleaf\'s Recourse', 'Rowain\'s Recourse', 'Zrelik\'s Recourse', 'Eyrzekla\'s Recourse', 'Krasir\'s Recourse'})
    self:addSpell('intervention', {'Immortal Intervention', 'Antediluvian Intervention', 'Primordial Intervention', 'Prehistoric Intervention', 'Historian\'s' Intervention'})

    self:addSpell('tcnuke', {'Gelid Gift', 'Polar Gift', 'Wintry Gift', 'Frostbitten Gift', 'Glacial Gift'}) -- tot nuke, cast on MA/MT, next two heals twincast, use with spiritual shower

    self:addSpell('alliance', {'Ancient Coalition', 'Ancient Alliance'}) -- keep up on tank, proc ae heal from target

    self:addSpell('singlefocus', {'Heroic Focusing', 'Vampyre Focusing', 'Kromrif Focusing', 'Wulthan Focusing', 'Doomscale Focusing'})
    self:addSpell('singleunity', {'Unity of the Heroic', 'Unity of the Vampyre', 'Unity of the Kromrif', 'Unity of the Wulthan', 'Unity of the Doomscale'})
    self:addSpell('groupunity', {'Talisman of the Heroic', 'Talisman of the Usurper', 'Talisman of the Ry\'Gorr', 'Talisman of the Wulthan', 'Talisman of the Doomscale'})
    self:addSpell('growth', {'Overwhelming Growth', 'Fervent Growth', 'Frenzied Growth', 'Savage Growth', 'Ferocious Growth'})
    
    self:addSpell('malo', {'Malosinera', 'Malosinetra', 'Malosinara', 'Malosinata', 'Malosinete'})
    Call of the Ancients -- 5 minute duration ward AE healing

    self:addSpell('reckless1', {'Reckless Reinvigoration', 'Reckless Resurgence', 'Reckless Renewal', 'Reckless Rejuvination', 'Reckless Regeneration'})
    self:addSpell('reckless2', {'Reckless Resurgence', 'Reckless Renewal', 'Reckless Rejuvination', 'Reckless Regeneration'})
    self:addSpell('reckless3', {'Reckless Renewal', 'Reckless Rejuvination', 'Reckless Regeneration'})
    -- Main healing: 2-4 Reckless spells
    table.insert(self.healAbilities, self.spells.reckless1) -- single target
    table.insert(self.healAbilities, self.spells.reckless2) -- single target
    table.insert(self.healAbilities, self.spells.reckless3) -- single target
    table.insert(self.healAbilities, self.spells.tcnuke) -- cast on MT
    -- Group Healing
    table.insert(self.healAbilities, self.spells.splash) -- cast on self
    table.insert(self.healAbilities, self.spells.recourse) -- group heal, several stages of healing
    table.insert(self.healAbilities, self.spells.intervention) -- longer refresh quick group heal
    table.insert(self.healAbilities, self.spells.grouphot)
    table.insert(self.healAbilities, common.getAA('Soothsayer\'s Intervention')) -- AA instant version of intervention spell
    table.insert(self.healAbilities, common.getAA('Ancestral Guard Spirit')) -- AA buff on target, big HoT below 50% HP, use on fragile melee
    
    common.getAA('Forceful Rejuvination') -- use to refresh group heals
    Chest clicky -- clicky group heal
    Small Manisi Branch -- direct heal clicky
    Apothic Dragon Spine Hammer -- clicky heal like manisi branch

    self.callAbility = common.getAA('Call of the Wild')
    self.rezStick = common.getItem('Staff of Forbidden Rites')
    self.rezAbility = common.getAA('Rejuvination of Spirit') -- 96% rez, ooc only

    -- Burns
    table.insert(self.burnAbilities, common.getItem('Blessed Spiritstaff of the Heyokah'), {first=true}) -- 2.0 click
    table.insert(self.burnAbilities, common.getAA('Spire of Ancestors'), {first=true}) -- inc total healing, dot crit
    table.insert(self.burnAbilities, common.getAA('Apex of Ancestors'), {first=true}) -- inc proc mod, accuracy, min dmg
    --table.insert(self.burnAbilities, common.getAA('Ancestral Aid'), {first=true}) -- large HoT, stacks, use with tranquil blessings
    table.insert(self.burnAbilities, common.getAA('Union of Spirits'), {first=true}) -- instant cast, use on monks/rogues
    table.insert(self.selfBuffs, common.getAA('Group Pact of the Wolf')) -- aura, cast before self wolf, they stack

    -- DPS
    Fleeting Spirit -- twin cast dots
    Obeah -- DoT
    Desperate Vampyre Blood -- DoT
    
    Rabid Bear -- inc melee stuff, procs heal group
    Pack of the Black Fang -- self buff, lags raids
    Languid Bite -- don't use on raids
    
]]
function Shaman:init()
    self.classOrder = {'heal', 'cure', 'assist', 'aggro', 'debuff', 'cast', 'burn', 'recover', 'rez', 'buff', 'rest', 'managepet'}
    self.spellRotations = {standard={}}
    self:initBase('shm')

    self:initClassOptions()
    self:loadSettings()
    self:initSpellLines()
    self:initSpellConditions()
    self:initSpellRotations()
    self:initHeals()
    self:initCures()
    self:initBuffs()
    self:initBurns()
    self:initDPSAbilities()
    self:initDebuffs()
    self:initDefensiveAbilities()
    self:initRecoverAbilities()

    self.rezAbility = common.getAA('Call of the Wild')
    self.summonCompanion = common.getAA('Summon Companion')
    self.nuketimer = timer:new(3000)
end

function Shaman:initClassOptions()
    self:addOption('USEDEBUFF', 'Use Malo', true, nil, 'Toggle casting malo on mobs', 'checkbox', nil, 'UseDebuff', 'bool')
    self:addOption('USEDISPEL', 'Use Dispel', true, nil, 'Toggle use of dispel', 'checkbox', nil, 'UseDispel', 'bool')
    self:addOption('USESLOW', 'Use Slow', true, nil, 'Toggle casting slow on mobs', 'checkbox', nil, 'UseSlow', 'bool')
    self:addOption('USENUKES', 'Use Nukes', true, nil, 'Toggle use of nukes', 'checkbox', nil, 'UseNukes', 'bool')
    self:addOption('USEDOTS', 'Use DoTs', true, nil, 'Toggle use of DoTs', 'checkbox', nil, 'UseDoTs', 'bool')
    self:addOption('USEEPIC', 'Use Epic', true, nil, 'Use epic in burns', 'checkbox', nil, 'UseEpic', 'bool')
end

function Shaman:initSpellLines()
    self:addSpell('heal', {'Ancient: Wilslik\'s Mending', 'Yoppa\'s Mending', 'Daluda\'s Mending', 'Chloroblast', 'Kragg\'s Salve', 'Superior Healing', 'Spirit Salve', 'Light Healing', 'Minor Healing'}, {panic=true, regular=true, tank=true, pet=60})
    self:addSpell('groupheal', {'Word of Reconstitution', 'Word of Restoration'}, {group=true})
    self:addSpell('canni', {'Cannibalize IV', 'Cannibalize III', 'Cannibalize II'}, {mana=true, threshold=70, combat=false, endurance=false, minhp=50, ooc=false})
    self:addSpell('pet', {'Commune with the Wild', 'True Spirit', 'Frenzied Spirit'})
    self:addSpell('slow', {'Turgur\'s Insects', 'Togor\'s Insects'}, {opt='USESLOW'})
    self:addSpell('proc', {'Spirit of the Leopard', 'Spirit of the Jaguar'}, {classes={MNK=true,BER=true,ROG=true,BST=true,WAR=true,PAL=true,SHD=true}})
    self:addSpell('champion', {'Champion', 'Ferine Avatar'})
    self:addSpell('cure', {'Blood of Nadox'})
    self:addSpell('nuke', {'Yoppa\'s Spear of Venom', 'Spear of Torment'}, {opt='USENUKES'})
    self:addSpell('slownuke', {'Ice Age'}, {opt='USENUKES'})
    self:addSpell('dot1', {'Nectar of Pain'}, {opt='USEDOTS'})
    self:addSpell('dot2', {'Curse of Sisslak'}, {opt='USEDOTS'})
    self:addSpell('dot3', {'Blood of Yoppa'}, {opt='USEDOTS'})
    self:addSpell('dot4', {'Breath of Wunshi', {opt='USEDOTS'}})
    self:addSpell('hottank', {'Spiritual Serenity', 'Breath of Trushar'}, {opt='USEHOTTANK', hot=true})
    self:addSpell('hotdps', {'Spiritual Serenity', 'Breath of Trushar'}, {opt='USEHOTDPS', hot=true})
    self:addSpell('slowproc', {'Lingering Sloth'}, {classes={WAR=true,PAL=true,SHD=true}})
    self:addSpell('panther', {'Talisman of the Panther'})
    self:addSpell('twincast', {'Frostfall Boon'}, {opt='USENUKES', regular=true, tank=true, tot=true})
    self:addSpell('torpor', {'Transcendent Torpor'})
    self:addSpell('rgc', {'Remove Greater Curse'}, {curse=true})
    self:addSpell('idol', {'Idol of Malos'}, {opt='USEDEBUFF'})
    self:addSpell('talisman', {'Talisman of Unification'}, {group=true, self=true, classes={WAR=true,SHD=true,PAL=true}})
    self:addSpell('focus', {'Talisman of Wunshi'}, {classes={WAR=true,SHD=true,PAL=true}})
    self:addSpell('dispel', {'Abashi\'s Disempowerment'}, {opt='USEDISPEL'})
    self:addSpell('debuff', {'Crippling Spasm'}, {opt='USEDEBUFF'})
end

function Shaman:initSpellConditions()
    if self.spells.twincast then
        self.spells.twincast.precast = function()
            mq.cmdf('/mqtar pc =%s', mq.TLO.Group.MainTank() or config.get('CHASETARGET'))
            mq.delay(1)
        end
    end
    if self.spells.idol then
        self.spells.idol.condition = function()
            return mq.TLO.Spawn('Spirit Idol')() ~= nil
        end
    end
end

function Shaman:initSpellRotations()
    table.insert(self.spellRotations.standard, self.spells.twincast)
    table.insert(self.spellRotations.standard, self.spells.slownuke)
    table.insert(self.spellRotations.standard, self.spells.dot1)
    table.insert(self.spellRotations.standard, self.spells.dot2)
    table.insert(self.spellRotations.standard, self.spells.dot3)
    table.insert(self.spellRotations.standard, self.spells.dot4)
    table.insert(self.spellRotations.standard, self.spells.nuke)
end

function Shaman:initDPSAbilities()

end

function Shaman:initBurns()
    local epic = common.getItem('Blessed Spiritstaff of the Heyokah', {opt='USEEPIC'}) or common.getItem('Crafted Talisman of Fates', {opt='USEEPIC'})

    table.insert(self.burnAbilities, common.getAA('Ancestral Aid'))
    table.insert(self.burnAbilities, epic)
    table.insert(self.burnAbilities, common.getAA('Rabid Bear'))
    table.insert(self.burnAbilities, common.getAA('Fundament: First spire of Ancestors'))
end

function Shaman:initHeals()
    --table.insert(self.healAbilities, self.spells.twincast)
    table.insert(self.healAbilities, self.spells.heal)
    table.insert(self.healAbilities, self.spells.hottank)
    table.insert(self.healAbilities, self.spells.hotdps)
    table.insert(self.healAbilities, common.getAA('Union of Spirits', {panic=true, tank=true, pet=30}))
end

function Shaman:initCures()
    table.insert(self.cures, self.spells.cure)
    table.insert(self.cures, self.radiant)
    table.insert(self.cures, self.spells.rgc)
end

function Shaman:initBuffs()
    table.insert(self.combatBuffs, self.spells.champion)
    table.insert(self.selfBuffs, common.getItem('Earring of Pain Deliverance', {CheckFor='Reyfin\'s Random Musings'}))
    table.insert(self.selfBuffs, common.getItem('Xxeric\'s Matted-Fur Mask', {CheckFor='Reyfin\'s Racing Thoughts'}))
    local pantherTablet = mq.TLO.FindItem('Imbued Rune of the Panther')()
    if not pantherTablet then
        table.insert(self.selfBuffs, self.spells.panther)
    end
    table.insert(self.singleBuffs, self.spells.slowproc)
    table.insert(self.singleBuffs, self.spells.proc)
    table.insert(self.selfBuffs, common.getAA('Pact of the Wolf', {RemoveBuff='Pact of the Wolf Effect'}))
    table.insert(self.selfBuffs, self.spells.champion)
    table.insert(self.selfBuffs, common.getAA('Languid Bite'))
    table.insert(self.singleBuffs, self.spells.focus)
    table.insert(self.singleBuffs, self.spells.talisman)
    table.insert(self.singleBuffs, common.getAA('Group Pact of the Wolf', {classes={SHD=true,WAR=true}}))
    --table.insert(self.groupBuffs, common.getAA('Group Pact of the Wolf', {group=true, self=false}))
    --table.insert(self.groupBuffs, self.spells.talisman)
    -- pact of the wolf, remove pact of the wolf effect

    self:addRequestAlias(self.radiant, 'radiant')
    self:addRequestAlias(self.spells.torpor, 'torpor')
    self:addRequestAlias(self.spells.talisman, 'talisman')
    self:addRequestAlias(self.spells.focus, 'focus')
end

function Shaman:initDebuffs()
    table.insert(self.debuffs, self.spells.dispel)
    table.insert(self.debuffs, self.spells.idol)
    table.insert(self.debuffs, common.getAA('Malosinete', {opt='USEDEBUFF'}))
    table.insert(self.debuffs, common.getAA('Turgur\'s Swarm', {opt='USESLOW'}) or self.spells.slow)
    table.insert(self.debuffs, self.spells.debuff)
end

function Shaman:initDefensiveAbilities()
    table.insert(self.defensiveAbilities, common.getAA('Ancestral Guard'))
end

function Shaman:initRecoverAbilities()
    self.canni = common.getAA('Cannibalization', {mana=true, endurance=false, threshold=60, combat=true, minhp=80, ooc=false})
    table.insert(self.recoverAbilities, self.canni)
    table.insert(self.recoverAbilities, self.spells.canni)
end

return Shaman