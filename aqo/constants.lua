local constants = {}

constants.commandHelp = {
    {command='help', tip='Output the help text'},
    {command='pause [on|1|off|0]', tip='Pause or resume the script'},
    {command='show', tip='Display the UI window'},
    {command='hide', tip='Hide the UI window'},
    {command='mode [mode]', tip='Set the current mode of the script. Valid Modes:\n\t\t0|manual|1|assist|2|chase|3|vorpal|4|tank|5|pullertank|6|puller|7|huntertank'},
    {command='resetcamp', tip='Reset the centerpoint of the camp to your current X,Y,Z coordinates'},
    {command='burnnow', tip='Activate burn abilities'},
    {command='preburn', tip='Activate pre-burn abilities, like to use glyph in guild hall'},
    {command='addclicky <mash|burn|buff|heal>', tip='Adds the currently held item to the clicky group specified'},
    {command='removeclicky', tip='Removes the currently held item from clickies'},
    {command='listclickies', tip='Displays the list of added clickies'},
    {command='ignore', tip='Adds the targeted mob to the ignore list for the current zone'},
    {command='unignore', tip='Removes the targeted mob from the ignore list for the current zone'},
    {command='door', tip='Click the nearest door'},
    {command='bark', tip='Make all group members repeat the following phrase'},
    {command='invis', tip='Use class invis ability'},
    {command='tribute', tip='Toggle personal tribute on or off'},
    {command='sell', tip='Sells items marked to be sold to the targeted or already opened vendor'},
    {command='manastone', tip='Spam manastone to get some mana back'},
    {command='armpets', tip='Summon pet gear for configured pets'},
    {command='debug', tip='Toggle the specified debug option on or off'},
    {command='restart', tip='Restart the script'},
    {command='update', tip='Downloads the latest source zip'},
    {command='docs', tip='Launches the documentation site in a browser window'},
    {command='wiki', tip='Launches the Lazarus wiki in a browser window'},
    {command='baz', tip='Launches the Lazarus Bazaar in a browser window'},
}

constants.instantHealClickies = {
    'Orb of Shadows',
    'Distillate of Celestial Healing X',
    --'Distillate of Divine Healing X',
    'Sanguine Mind Crystal III',
}
constants.durationHealClickies = {
    'Distillate of Celestial Healing X',
}
constants.ddClickies = {
    'Molten Orb',
    'Lava Orb',
}
constants.deleteWhenDead = {
    ['Molten Orb']=true,
    ['Lava Orb']=true,
    ['Sanguine Mind Crystal III']=true,
    ['Large Modulation Shard']=true,
}

constants.assists = {group=1,raid1=1,raid2=1,raid3=1,manual=1}
constants.groupWatchOptions = {healer=1,self=1,none=1}
constants.pullWith = {melee=1,ranged=1,spell=1,item=1,custom=1}
constants.pullStates = {NOT='NOT',SCAN='SCAN',APPROACHING='APPROACHING',ENGAGING='ENGAGING',RETURNING='RETURNING',WAITING='WAITING'}

constants.manaClasses = {clr=true,dru=true,shm=true,enc=true,mag=true,nec=true,wiz=true}
constants.petClasses = {bst=true,mag=true,nec=true,dru=true,enc=true,shd=true,shm=true}
constants.buffClasses = {clr=true,dru=true,shm=true,enc=true,mag=true,nec=true,rng=true,bst=true}
constants.healClasses = {clr=true,dru=true,shm=true}
constants.tankClasses = {pal=true,shd=true,war=true}
constants.meleeClasses = {ber=true,brd=true,bst=true,mnk=true,rng=true,rog=true}
constants.fdClasses = {mnk=true,nec=true,shd=true,bst=true}

constants.DMZ = {
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
constants.xpBuffs = {42962,42617,42616}
constants.gmBuffs = {34835,35989,35361,25732,34567,36838,43040,36266,36423}

constants.booleans = {
    ['1']=true, ['true']=true,['on']=true,
    ['0']=false, ['false']=false,['off']=false,
}

constants.ignoreBuff = {
    ['HC Bracing Defense']=true,
    ['HC Visziaj\'s Grasp Recourse']=true,
    ['HC Defense of Calrena']=true,
}

constants.slotList = 'earrings, rings, leftear, rightear, leftfinger, rightfinger, face, head, neck, shoulder, chest, feet, arms, leftwrist, rightwrist, wrists, charm, powersource, mainhand, offhand, ranged, ammo, legs, waist, hands'

constants.routines = {heal=1,assist=1,mash=1,burn=1,cast=1,cure=1,buff=1,rest=1,ae=1,mez=1,aggro=1,ohshit=1,rez=1,recover=1,managepet=1}

constants.classLists = {
    'DPSAbilities', 'AEDPSAbilities', 'burnAbilities', 'tankAbilities', 'tankBurnAbilities', 'AETankAbilities', 'healAbilities',
    'fadeAbilities', 'defensiveAbilities', 'aggroReducers', 'recoverAbilities', 'combatBuffs', 'auras', 'selfBuffs',
    'groupBuffs', 'singleBuffs', 'petBuffs', 'cures', 'clickies', 'castClickies', 'pullClickies', 'debuffs'
}

constants.uiThemes = {
    TEAL = {
        windowbg = ImVec4(.2, .2, .2, .6),
        bg = ImVec4(0, .3, .3, 1),
        hovered = ImVec4(0, .4, .4, 1),
        active = ImVec4(0, .5, .5, 1),
        button = ImVec4(0, .3, .3, 1),
        text = ImVec4(1, 1, 1, 1),
    },
    PINK = {
        windowbg = ImVec4(.2, .2, .2, .6),
        bg = ImVec4(1, 0, .5, 1),
        hovered = ImVec4(1, 0, .5, 1),
        active = ImVec4(1, 0, .7, 1),
        button = ImVec4(1, 0, .4, 1),
        text = ImVec4(1, 1, 1, 1),
    },
    GOLD = {
        windowbg = ImVec4(.2, .2, .2, .6),
        bg = ImVec4(.4, .2, 0, 1),
        hovered = ImVec4(.6, .4, 0, 1),
        active = ImVec4(.7, .5, 0, 1),
        button = ImVec4(.5, .3, 0, 1),
        text = ImVec4(1, 1, 1, 1),
    },
}

constants.icons = {
    FA_PLAY = '\xef\x81\x8b',
    FA_PAUSE = '\xef\x81\x8c',
    FA_STOP = '\xef\x81\x8d',
    FA_SAVE = '\xee\x85\xa1',
    FA_HEART = '\xef\x80\x84',
    FA_FIRE = '\xef\x81\xad',
    FA_MEDKIT = '\xef\x83\xba',
    FA_FIGHTER_JET = '\xef\x83\xbb',
    MD_LOCAL_HOSPITAL = '\xee\x95\x88',
    FA_BICYCLE = '\xef\x88\x86',
    FA_BUS = '\xef\x88\x87',
    MD_EXPLORE = '\xee\xa1\xba',
    MD_HELP = '\xee\xa2\x87',
}

return constants