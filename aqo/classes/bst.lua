---@type Mq
local mq = require('mq')
local class = require('classes.classbase')
local lists = require('data.lists')
local common = require('common')
local config = require('configuration')

--[[
    spirit of rashara
    ancient: savage ice
    growl of the beast
    muada's mending
    chimera blood
    ferocity of irionu
    spiritual rejuvination
    glacier spear
    sha's legacy
    reptilian venom
    growl of the panther
    spirit of oroshar
]]
function class.init(_aqo)
    class.classOrder = {'assist', 'aggro', 'cast', 'mash', 'burn', 'heal', 'recover', 'buff', 'rest', 'managepet', 'rez'}
    class.spellRotations = {standard={}}
    class.initBase(_aqo, 'bst')

    class.initClassOptions()
    class.loadSettings()
    class.initSpellLines(_aqo)
    class.initSpellRotations()
    class.initDPSAbilities(_aqo)
    class.initBurns(_aqo)
    class.initHeals(_aqo)
    class.initBuffs(_aqo)
    class.initDefensiveAbilities(_aqo)
    class.initRecoverAbilities(_aqo)

    class.useCommonListProcessor = true
end

function class.initClassOptions()
    class.addOption('USENUKES', 'Use Nukes', true, nil, 'Toggle use of nukes', 'checkbox')
    class.addOption('USEFOCUSEDPARAGON', 'Use Focused Paragon (Self)', true, nil, 'Toggle use of Focused Paragon of Spirits', 'checkbox')
    class.addOption('PARAGONOTHERS', 'Use Focused Paragon (Group)', true, nil, 'Toggle use of Focused Paragon of Spirits on others', 'checkbox')
    class.addOption('USEPARAGON', 'Use Group Paragon', false, nil, 'Toggle use of Paragon of Spirit', 'checkbox')
    class.addOption('USEDOTS', 'Use DoTs', false, nil, 'Toggle use of DoTs', 'checkbox')
    class.addOption('USEFD', 'Feign Death', true, nil, 'Use FD AA\'s to reduce aggro', 'checkbox')
    class.addOption('USESLOW', 'Use Slow', false, nil, 'Toggle casting slow on mobs', 'checkbox')
end

function class.initSpellLines(_aqo)
    class.addSpell('pet', {'Spirit of Rashara', 'Spirit of Alladnu', 'Spirit of Sorsha'}, {opt='SUMMONPET'}) -- pet
    class.addSpell('pethaste',{'Growl of the Beast', 'Arag\'s Celerity'}, {swap=true}) -- pet haste
    class.addSpell('petbuff', {'Spirit of Oroshar', 'Spirit of Rellic'}, {swap=true}) -- pet buff
    class.addSpell('petheal', {'Healing of Mikkity', 'Healing of Sorsha'}, {opt='HEALPET', pet=50}) -- pet heal
    class.addSpell('nuke', {'Ancient: Savage Ice', 'Glacier Spear', 'Trushar\'s Frost'}, {opt='USENUKES'})
    class.addSpell('nuke2', {'Glacier Spear'}, {opt='USENUKES'})
    class.addSpell('heal', {'Trushar\'s Mending'}, {me=75, self=true}) -- heal
    class.addSpell('fero', {'Ferocity of Irionu', 'Ferocity'}, {classes={WAR=true,MNK=true,BER=true,ROG=true}}) -- like shm avatar
    class.addSpell('feralvigor', {'Feral Vigor'}, {classes={WAR=true,SHD=true,PAL=true}}) -- like shm avatar
    class.addSpell('panther', {'Growl of the Panther'}, {skipifbuff='Wild Spirit Infusion'})
    class.addSpell('groupregen', {'Spiritual Rejuvenation', 'Spiritual Ascendance', 'Feral Vigor', 'Spiritual Vigor'}, {swap=true}) -- group buff
    class.addSpell('grouphp', {'Spiritual Vitality'}, {swap=true})
    class.addSpell('dot', {'Chimera Blood'}, {opt='USEDOTS'})
    class.addSpell('swarmpet', {'Reptilian Venom'}, {delay=1500})
    class.addSpell('slow', {'Sha\'s Legacy'}, {opt='USESLOW'})
end

function class.initSpellRotations()
    table.insert(class.spellRotations.standard, class.spells.swarmpet)
    table.insert(class.spellRotations.standard, class.spells.dot)
    table.insert(class.spellRotations.standard, class.spells.nuke)
    table.insert(class.spellRotations.standard, class.spells.nuke2)
end

function class.initDPSAbilities(_aqo)
    table.insert(class.DPSAbilities, common.getSkill('Kick', {conditions=_aqo.conditions.withinMeleeDistance}))
    table.insert(class.DPSAbilities, common.getBestDisc({'Rake', {conditions=_aqo.conditions.withinMeleeDistance}}))
    table.insert(class.DPSAbilities, common.getAA('Feral Swipe', {conditions=_aqo.conditions.withinMeleeDistance}))
    table.insert(class.DPSAbilities, common.getAA('Chameleon Strike', {conditions=_aqo.conditions.withinMeleeDistance}))
    table.insert(class.DPSAbilities, common.getAA('Bite of the Asp', {conditions=_aqo.conditions.withinMeleeDistance}))
    table.insert(class.DPSAbilities, common.getAA('Roar of Thunder', {conditions=_aqo.conditions.withinMeleeDistance}))
    table.insert(class.DPSAbilities, common.getAA('Gorilla Smash', {conditions=_aqo.conditions.withinMeleeDistance}))
    table.insert(class.DPSAbilities, common.getAA('Raven Claw', {conditions=_aqo.conditions.withinMeleeDistance}))
end

function class.initBurns(_aqo)
    table.insert(class.burnAbilities, common.getBestDisc({'Empathic Fury', 'Bestial Fury Discipline'})) -- burn disc
    table.insert(class.burnAbilities, common.getAA('Fundament: Third Spire of the Savage Lord'))
    table.insert(class.burnAbilities, common.getAA('Frenzy of Spirit'))
    table.insert(class.burnAbilities, common.getAA('Bestial Bloodrage'))
    table.insert(class.burnAbilities, common.getAA('Group Bestial Alignment'))
    table.insert(class.burnAbilities, common.getAA('Bestial Alignment', {skipifbuff='Group Bestial Alignment', condition=_aqo.conditions.skipifbuff}))
    table.insert(class.burnAbilities, common.getAA('Attack of the Warders', {delay=1500}))
end

function class.initBuffs(_aqo)
    local buffCondition = function(ability)
        return _aqo.conditions.checkMana(ability) and _aqo.conditions.missingBuff(ability)
    end
    if class.spells.groupregen then class.spells.groupregen.condition = buffCondition end
    if class.spells.grouphp then class.spells.grouphp.condition = buffCondition end
    --class.spells.fero.condition = buffCondition
    if class.spells.panther then class.spells.panther.condition = buffCondition end
    table.insert(class.selfBuffs, class.spells.groupregen)
    table.insert(class.selfBuffs, class.spells.grouphp)
    table.insert(class.selfBuffs, class.spells.fero)
    table.insert(class.selfBuffs, class.spells.panther)
    table.insert(class.selfBuffs, common.getAA('Gelid Rending'))
    table.insert(class.selfBuffs, common.getAA('Pact of the Wurine'))
    table.insert(class.selfBuffs, common.getAA('Protection of the Warder'))

    if class.spells.fero then
        local singleBuffCondition = function(ability)
            return _aqo.conditions.checkMana(ability)
        end
        class.spells.fero.condition = singleBuffCondition
    end
    table.insert(class.singleBuffs, class.spells.fero)
    table.insert(class.singleBuffs, class.spells.feralvigor)

    local petBuffCondition = function(ability)
        return _aqo.conditions.checkMana(ability) and _aqo.conditions.stacksPet(ability) and _aqo.conditions.missingPetBuff(ability)
    end
    if class.spells.pethaste then class.spells.pethaste.condition = petBuffCondition end
    if class.spells.petbuff then class.spells.petbuff.condition = petBuffCondition end
    table.insert(class.petBuffs, class.spells.pethaste)
    table.insert(class.petBuffs, class.spells.petbuff)
    --local epicOpts = {CheckFor='Savage Wildcaller\'s Blessing', condition=_aqo.conditions.missingPetCheckFor}
    local epicOpts = {CheckFor='Might of the Wild Spirits', condition=_aqo.conditions.missingPetCheckFor}
    table.insert(class.petBuffs, common.getItem('Spiritcaller Totem of the Feral', epicOpts) or common.getItem('Savage Lord\'s Totem', epicOpts))
    table.insert(class.petBuffs, common.getAA('Taste of Blood', {CheckFor='Blood Frenzy', condition=_aqo.conditions.missingPetCheckFor}))

    class.paragon = common.getAA('Paragon of Spirit', {opt='USEPARAGON'})
    class.fParagon = common.getAA('Focused Paragon of Spirits', {opt='USEFOCUSEDPARAGON', mana=true, threshold=70, combat=true, endurance=false, minhp=20, ooc=true})
    class.addRequestAlias(class.fParagon, 'fparagon')
    class.addRequestAlias(class.paragon, 'paragon')
    class.addRequestAlias(class.spells.groupregen, 'rejuv')
end

function class.initHeals(_aqo)
    table.insert(class.healAbilities, class.spells.heal)
    table.insert(class.healAbilities, class.spells.petheal)
end

function class.initDefensiveAbilities(_aqo)
    local postFD = function()
        mq.delay(1000)
        mq.cmdf('/multiline ; /stand ; /makemevis')
    end
    table.insert(class.fadeAbilities, common.getAA('Playing Possum', {opt='USEFD', postcast=postFD}))
end

function class.initRecoverAbilities(_aqo)
    if class.fParagon then
        class.fParagon.condition = function(ability)
            return mq.TLO.Me.PctMana() <= config.get('RECOVERPCT')
        end
    end
    table.insert(class.recoverAbilities, class.fParagon)
end

function class.recoverClass()
    local lowmana = mq.TLO.Group.LowMana(50)() or 0
    local groupSize = mq.TLO.Group.Members() or 0
    local needEnd = 0
    if class.isEnabled('USEPARAGON') then
        for i=1,groupSize do
            if (mq.TLO.Group.Member(i).PctEndurance() or 100) < 50 then
                needEnd = needEnd + 1
            end
        end
        if (needEnd+lowmana) >= 3 and class.paragon:isReady() then
            class.paragon:use()
        end
    end
    local originalTargetID = 0
    if class.isEnabled('PARAGONOTHERS') and class.fParagon then
        local groupSize = mq.TLO.Group.GroupSize()
        if groupSize then
            for i=1,groupSize do
                local member = mq.TLO.Group.Member(i)
                local memberPctMana = member.PctMana() or 100
                local memberDistance = member.Distance3D() or 300
                local memberClass = member.Class.ShortName() or 'WAR'
                if lists.manaClasses[memberClass:lower()] and memberPctMana < 70 and memberDistance < 100 and mq.TLO.Me.AltAbilityReady(class.fParagon.Name)() then
                    member.DoTarget()
                    class.fParagon:use()
                    if originalTargetID > 0 then mq.cmdf('/squelch /mqtar id %s', originalTargetID) else mq.cmd('/squelch /mqtar clear') end
                    return
                end
            end
        end
    end
end

return class