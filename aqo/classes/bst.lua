---@type Mq
local mq = require('mq')
local baseclass = require(AQO..'.classes.classbase')
local common = require(AQO..'.common')

local bst = baseclass

bst.class = 'bst'
bst.classOrder = {'assist', 'cast', 'mash', 'burn', 'recover', 'buff', 'rest', 'managepet'}

bst.SPELLSETS = {standard=1}

bst.addOption('SPELLSET', 'Spell Set', 'standard', bst.SPELLSETS, nil, 'combobox')
bst.addOption('SUMMONPET', 'Summon Pet', true, nil, 'Summon a pet', 'checkbox')
bst.addOption('BUFFPET', 'Buff Pet', true, nil, 'Use pet buffs', 'checkbox')

bst.addSpell('pethaste',{'Arag\'s Celerity'}) -- pet haste
bst.addSpell('pet', {'Spirit of Sorsha, pet'}, {opt='SUMMONPET'}) -- pet
bst.addSpell('petbuff', {'Spirit of Rellic'}) -- pet buff
bst.addSpell('groupregen', {'Spiritual Vigor'}) -- group buff
bst.addSpell('heal', {'Trushar\'s Mending'}, {me=75, self=true}) -- heal
bst.addSpell('petheal', {'Healing of Sorsha'}) -- pet heal
bst.addSpell('fero', {'Ferocity'}) -- like shm avatar

local standard = {}

bst.spellRotations = {
    standard=standard
}

table.insert(bst.DPSAbilities, common.getSkill('Kick'))
table.insert(bst.DPSAbilities, common.getAA('Feral Swipe'))
table.insert(bst.burnAbilities, common.getBestDisc({'Bestial Fury Discipline'})) -- burn disc

table.insert(bst.petBuffs, bst.spells.pethaste)
table.insert(bst.petBuffs, bst.spells.petbuff)

table.insert(bst.healAbilities, bst.spells.heal)

table.insert(bst.selfBuffs, bst.spells.groupregen)
table.insert(bst.selfBuffs, bst.spells.fero)
table.insert(bst.selfBuffs, common.getAA('Gelid Rending'))

local melees = {MNK=true,BER=true,ROG=true}
bst.buff_class = function()
    if common.am_i_dead() then return end

    if bst.spells.fero and mq.TLO.Me.SpellReady(bst.spells.fero.name)() and mq.TLO.Group.GroupSize() then
        for i=1,mq.TLO.Group.GroupSize()-1 do
            local member = mq.TLO.Group.Member(i)
            local distance = member.Distance3D() or 300
            if melees[member.Class.ShortName()] and not member.Buff(bst.spells.fero.name)() and distance < 100 then
                member.DoTarget()
                mq.delay(100, function() return mq.TLO.Target.ID() == member.ID() end)
                mq.delay(1000, function() return mq.TLO.Target.BuffsPopulated() end)
                if not mq.TLO.Target.Buff(bst.spells.fero.name)() then
                    if bst.spells.fero:use() then return end
                end
            end
        end
    end
end

return bst