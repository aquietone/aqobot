---@type Mq
local mq = require('mq')
local class = require('classes.classbase')
local common = require('common')

class.class = 'bst'
class.classOrder = {'assist', 'cast', 'mash', 'burn', 'heal', 'recover', 'buff', 'rest', 'managepet'}

class.SPELLSETS = {standard=1}
class.addCommonOptions()
class.addCommonAbilities()
class.addOption('USENUKES', 'Use Nukes', true, nil, 'Toggle use of nukes', 'checkbox')
class.addOption('USEFOCUSEDPARAGON', 'Use Focused Paragon (Self)', true, nil, 'Toggle use of Focused Paragon of Spirits', 'checkbox')
class.addOption('PARAGONOTHERS', 'Use Focused Paragon (Group)', true, nil, 'Toggle use of Focused Paragon of Spirits on others', 'checkbox')
class.addOption('USEPARAGON', 'Use Group Paragon', false, nil, 'Toggle use of Paragon of Spirit', 'checkbox')
class.addOption('USEDOTS', 'Use DoTs', false, nil, 'Toggle use of DoTs', 'checkbox')

class.addSpell('pet', {'Spirit of Rashara', 'Spirit of Alladnu', 'Spirit of Sorsha'}, {opt='SUMMONPET'}) -- pet
class.addSpell('pethaste',{'Growl of the Beast', 'Arag\'s Celerity'}) -- pet haste
class.addSpell('petbuff', {'Spirit of Oroshar', 'Spirit of Rellic'}) -- pet buff
class.addSpell('petheal', {'Healing of Mikkity', 'Healing of Sorsha'}, {opt='HEALPET', pet=50}) -- pet heal
class.addSpell('nuke', {'Ancient: Savage Ice', 'Glacier Spear', 'Trushar\'s Frost'}, {opt='USENUKES'})
class.addSpell('heal', {'Trushar\'s Mending'}, {me=75, self=true}) -- heal
class.addSpell('fero', {'Ferocity of Irionu', 'Ferocity'}, {classes={WAR=true,MNK=true,BER=true,ROG=true}}) -- like shm avatar
class.addSpell('feralvigor', {'Feral Vigor'}, {classes={WAR=true,SHD=true,PAL=true}}) -- like shm avatar
class.addSpell('panther', {'Growl of the Panther'})
class.addSpell('groupregen', {'Spiritual Rejuvenation', 'Spiritual Ascendance', 'Feral Vigor', 'Spiritual Vigor'}) -- group buff
class.addSpell('grouphp', {'Spiritual Vitality'})
class.addSpell('dot', {'Chimera Blood'}, {opt='USEDOTS'})

local standard = {}
table.insert(standard, class.spells.nuke)
table.insert(standard, class.spells.dot)

class.spellRotations = {
    standard=standard
}

table.insert(class.DPSAbilities, common.getSkill('Kick'))
table.insert(class.DPSAbilities, common.getBestDisc({'Rake'}))
table.insert(class.DPSAbilities, common.getAA('Feral Swipe'))
table.insert(class.DPSAbilities, common.getAA('Chameleon Strike'))
table.insert(class.DPSAbilities, common.getAA('Bite of the Asp'))
table.insert(class.DPSAbilities, common.getAA('Roar of Thunder'))
table.insert(class.DPSAbilities, common.getAA('Gorilla Smash'))
table.insert(class.DPSAbilities, common.getAA('Raven Claw'))

table.insert(class.burnAbilities, common.getBestDisc({'Empathic Fury', 'Bestial Fury Discipline'})) -- burn disc
table.insert(class.burnAbilities, common.getAA('Fundament: Third Spire of the Savage Lord'))
table.insert(class.burnAbilities, common.getAA('Frenzy of Spirit'))
table.insert(class.burnAbilities, common.getAA('Bestial Bloodrage'))
table.insert(class.burnAbilities, common.getAA('Group Bestial Alignment'))
table.insert(class.burnAbilities, common.getAA('Bestial Alignment', {skipifbuff='Group Bestial Alignment'}))
table.insert(class.burnAbilities, common.getAA('Attack of the Warders', {delay=1500}))

table.insert(class.healAbilities, class.spells.heal)
table.insert(class.healAbilities, class.spells.petheal)

table.insert(class.selfBuffs, class.spells.groupregen)
table.insert(class.selfBuffs, class.spells.grouphp)
table.insert(class.selfBuffs, class.spells.fero)
table.insert(class.selfBuffs, class.spells.panther)
table.insert(class.selfBuffs, common.getAA('Gelid Rending'))
table.insert(class.selfBuffs, common.getAA('Pact of the Wurine'))
table.insert(class.selfBuffs, common.getAA('Protection of the Warder'))
table.insert(class.selfBuffs, common.getItem('Gloves of the Crimson Sigil', {checkfor='Call of Fire'}))

table.insert(class.singleBuffs, class.spells.fero)
table.insert(class.singleBuffs, class.spells.feralvigor)

table.insert(class.petBuffs, class.spells.pethaste)
table.insert(class.petBuffs, class.spells.petbuff)
table.insert(class.petBuffs, common.getItem('Savage Lord\'s Totem', {checkfor='Savage Wildcaller\'s Blessing'}))
table.insert(class.petBuffs, common.getAA('Taste of Blood', {checkfor='Blood Frenzy'}))

class.paragon = common.getAA('Paragon of Spirit', {opt='USEPARAGON'})
class.fParagon = common.getAA('Focused Paragon of Spirits', {opt='USEFOCUSEDPARAGON', mana=true, threshold=70, combat=true, endurance=false, minhp=20, ooc=true})
table.insert(class.recoverAbilities, class.fParagon)

class.addRequestAlias(class.fParagon, 'fparagon')
class.addRequestAlias(class.paragon, 'paragon')

local casterpriests = {clr=true,shm=true,dru=true,mag=true,nec=true,enc=true,wiz=true,shd=true}
class.recover_class = function()
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
    if class.isEnabled('PARAGONOTHERS') and class.fParagon then
        local groupSize = mq.TLO.Group.GroupSize()
        if groupSize then
            for i=1,groupSize do
                local member = mq.TLO.Group.Member(i)
                local memberPctMana = member.PctMana() or 100
                local memberDistance = member.Distance3D() or 300
                local memberClass = member.Class.ShortName() or 'WAR'
                if casterpriests[memberClass:lower()] and memberPctMana < 70 and memberDistance < 100 and mq.TLO.Me.AltAbilityReady(class.fParagon.name)() then
                    member.DoTarget()
                    mq.delay(100, function() return mq.TLO.Target.ID() == member.ID() end)
                    class.fParagon:use()
                    return
                end
            end
        end
    end
end

return class