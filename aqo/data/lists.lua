local lists = {}

lists.instantHealClickies = {
    'Orb of Shadows',
    'Distillate of Celestial Healing X',
    --'Distillate of Divine Healing X',
    'Sanguine Mind Crystal III',
}
lists.durationHealClickies = {
    'Distillate of Celestial Healing X',
}
lists.ddClickies = {
    'Molten Orb',
    'Lava Orb',
}

lists.manaClasses = {clr=true,dru=true,shm=true,enc=true,mag=true,nec=true,wiz=true}
lists.petClasses = {bst=true,mag=true,nec=true,dru=true,enc=true,shd=true,shm=true}
lists.buffClasses = {clr=true,dru=true,shm=true,enc=true,mag=true,nec=true,rng=true,bst=true}
lists.healClasses = {clr=true,dru=true,shm=true}
lists.tankClasses = {pal=true,shd=true,war=true}
lists.meleeClasses = {ber=true,brd=true,bst=true,mnk=true,rng=true,rog=true}
lists.fdClasses = {mnk=true,nec=true,shd=true,bst=true}

lists.DMZ = {
    [344] = 1,
    [345] = 1,
    [202] = 1,
    [203] = 1,
    [279] = 1,
    [151] = 1,
    [220] = 1,
    [386] = 1,
    [33506] = 1,
}

-- xp6, xp5, xp4
lists.xpBuffs = {42962,42617,42616}
lists.gmBuffs = {34835,35989,35361,25732,34567,36838,43040,36266,36423}

lists.booleans = {
    ['1']=true, ['true']=true,['on']=true,
    ['0']=false, ['false']=false,['off']=false,
}

lists.ignoreBuff = {
    ['HC Bracing Defense']=true,
    ['HC Visziaj\'s Grasp Recourse']=true,
    ['HC Defense of Calrena']=true,
}

lists.slotList = 'earrings, rings, leftear, rightear, leftfinger, rightfinger, face, head, neck, shoulder, chest, feet, arms, leftwrist, rightwrist, wrists, charm, powersource, mainhand, offhand, ranged, ammo, legs, waist, hands'

lists.routines = {heal=1,assist=1,mash=1,burn=1,cast=1,cure=1,buff=1,rest=1,ae=1,mez=1,aggro=1,ohshit=1,rez=1,recover=1,managepet=1}

return lists