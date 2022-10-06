local baseclass = require(AQO..'.classes.base')
local assist = require(AQO..'.routines.assist')

local mag = baseclass

mag.class = 'mag'
mag.classOrder = {'assist', 'cast', 'burn', 'recover', 'buff', 'rest', 'managepet'}

mag.SPELLSETS = {standard=1}

mag.addOption('SPELLSET', 'Spell Set', 'standard', mag.SPELLSETS, nil, 'combobox')
mag.addOption('USEMELEE', 'Use Melee', false, nil, 'Toggle attacking mobs with melee', 'checkbox')
mag.addOption('SUMMONPET', 'Summon Pet', true, nil, 'Toggle summoning of pet', 'checkbox')
mag.addOption('BUFFPET', 'Buff Pet', true, nil, 'Toggle buffing of pet', 'checkbox')
mag.addOption('USEFIRENUKES', 'Use Fire Nukes', true, nil, 'Toggle use of fire nuke line', 'checkbox')
mag.addOption('USEMAGICNUKES', 'Use Magic Nukes', false, nil, 'Toggle use of magic nuke line', 'checkbox')

mag.addSpell('firenuke', {'Sun Vortex', 'Seeking Flame of Seukor', 'Char', 'Bolt of Flame'}, {opt='USEFIRENUKES'})
mag.addSpell('magicnuke', {'Rock of Taelosia'}, {opt='USEMAGICNUKES'})
mag.addSpell('pet', {'Greater Vocaration: Water', 'Vocarate: Water', 'Conjuration: Water', 
                    'Lesser Conjuration: Water', 'Minor Conjuration: Water', 'Greater Summoning: Water', 
                    'Summoning: Water', 'Lesser Summoning: Water', 'Minor Summoning: Water', 'Elementalkin: Water'})
mag.addSpell('petbuff', {'Burnout V', 'Burnout IV', 'Burnout III', 'Burnout II', 'Burnout'})
mag.addSpell('petstrbuff', {'Earthen Strength'})

mag.addSpell('manaregen', {'Elemental Siphon'}) -- self mana regen
mag.addSpell('acregen', {'Xegony\'s Phantasmal Guard'}) -- self regen/ac buff
mag.addSpell('petheal', {'Planar Renewal'}) -- pet heal

table.insert(mag.petBuffs, mag.spells.petbuff)
table.insert(mag.petBuffs, mag.spells.petstrbuff)

table.insert(mag.buffs, mag.spells.manaregen)
table.insert(mag.buffs, mag.spells.acregen)

local standard = {}
table.insert(standard, mag.spells.firenuke)
table.insert(standard, mag.spells.magicnuke)

mag.spellRotations = {
    standard=standard
}

mag.pull_func = function()
    assist.send_pet()
end

return mag