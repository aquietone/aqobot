local constants = {}

constants.commandHelp = {
    {command='help', tip='Output the help text'},
    {command='pause [on|1|off|0]', tip='Pause or resume the script'},
    {command='show', tip='Display the UI window'},
    {command='hide', tip='Hide the UI window'},
    {command='save', tip='Save current settings'},
    {command='restart', tip='Restart the script'},
    {command='mode [mode]', tip='Set the current mode of the script. Valid Modes:\n\t\t0|manual|1|assist|2|chase|3|vorpal|4|tank|5|pullertank|6|puller|7|huntertank'},
    {command='assistme', tip='Set the current target ID to the tank mob ID. Useful for manual mode to trigger tanking behavior'},
    {command='resetcamp', tip='Reset the centerpoint of the camp to your current X,Y,Z coordinates'},
    {command='return', tip='Return to camp'},
    {command='burnnow', tip='Activate burn abilities'},
    {command='preburn', tip='Activate pre-burn abilities, like to use glyph in guild hall'},
    {command='addclicky <mash|cast|burn|buff|petbuff|heal|defensive|mana|summon|debuff|pull> [key/value]', tip='Adds the currently held item to the clicky group specified'},
    {command='removeclicky', tip='Removes the currently held item from clickies'},
    {command='enableclicky', tip='Enables the currently held item'},
    {command='disableclicky', tip='Disables the currently held item'},
    {command='listclickies', tip='Displays the list of added clickies'},
    {command='buffaliases', tip='Displays the list of available buff aliases for wantbuff and offerbuff commands'},
    {command='wantbuff <buffalias> [on|1|off|0]', tip='Enables or disables begging for the specified buff alias'},
    {command='offerbuff <buffalias> [on|1|off|0]', tip='Enables or disables offering the specified buff alias for buff begging'},
    {command='ignore', tip='Adds the targeted mob to the ignore list for the current zone'},
    {command='unignore', tip='Removes the targeted mob from the ignore list for the current zone'},
    {command='door', tip='Click the nearest door'},
    {command='bark', tip='Make all group members repeat the following phrase'},
    {command='invis', tip='Use class invis ability'},
    {command='tribute', tip='Toggle personal tribute on or off'},
    {command='manastone', tip='Spam manastone to get some mana back'},
    {command='armpets', tip='Summon pet gear for configured pets'},
    {command='nowcast', tip='Tells the named character or yourself to cast a spell on the specified target ID.', example='/nowcast [name] alias <targetID>'},
    {command='blockspells', tip='Block common spells on self and pet'},
    {command='rez <name>', tip='Rez the specified character', example='/aqo rez sometank'},
    {command='rebuff', tip='Cast buffs on command, ignoring combat checks'},
    {command='rezall', tip='Rez whole group or raid'},
    {command='rtz', tip='Run your group towards the zone line you are facing'},
    {command='sell', tip='Sells items marked to be sold to the targeted or already opened vendor'},
    {command='update', tip='Downloads the latest source zip'},
    {command='docs', tip='Launches the documentation site in a browser window'},
    {command='wiki', tip='Launches the Lazarus wiki in a browser window'},
    {command='baz', tip='Launches the Lazarus Bazaar in a browser window'},
    {command='gettingstarted', tip='Opens the AQO Getting Started window'},
    {command='debug', tip='Toggle the specified debug option on or off'},
}

constants.bufflines = {
    -- Standard Buffs
    {key='AEGO', label='Aegolism (Cleric HP/AC)', category='Standard', exclusivewith='SYMBOL, SKIN'},
    {key='SYMBOL', label='Symbol (Cleric HP)', category='Standard', exclusivewith='AEGO'},
    {key='SKIN', label='Skin (Druid HP)', category='Standard', exclusivewith='AEGO'},
    {key='FOCUS', label='Focus (Shaman HP)', category='Standard'},
    {key='HASTE', label='Haste', category='Standard'},
    {key='EPICHASTE', label='Enc Epic Haste', category='Standard'},
    {key='KEI', label='Clarity', category='Standard'},
    {key='SHOUT', label='Shout (Ranger Atk)', category='Standard'},
    {key='STRENGTH', label='Strength (Ranger HP)', category='Standard', exclusivewith='BRELLS,SV'},
    {key='BRELLS', label='Brells (Paladin HP)', category='Standard', exclusivewith='STRENGTH,SV'},
    {key='SV', label='SV (Beast Lord HP)', category='Standard', exclusivewith='BRELLS,STRENGTH'},
    {key='SE', label='SE (Beast Lord Regen)', category='Standard'},
    {key='VIGOR', label='Feral Vigor', category='Standard'},
    {key='REGEN', label='Regen', category='Standard'},
    -- Stat Buffs
    {key='CHAMPION', label='Champion (Shm)', category='Stats'},
    {key='FEROCITY', label='Ferocity (Bst)', category='Stats'},
    {key='WOLF', label='Pact of Wolf (Shm)', category='Stats'},
    {key='STR', label='Strength', category='Stats'},
    {key='CHA', label='Charisma', category='Stats'},
    {key='DEX', label='Dexterity', category='Stats'},
    {key='AGI', label='Agility', category='Stats'},
    {key='WIS', label='Wisdom', category='Stats'},
    {key='INT', label='Intelligence', category='Stats'},
    -- Utility Buffs
    {key='DMF', label='Dead Man Floating', category='Utility'},
    {key='DS', label='Damage Shield', category='Utility'},
    {key='SOW', label='Spirit of Wolf', category='Utility'},
    -- Short Term Buffs
    {key='NECROTIC', label='Necro Damage Proc', category='Short Term Buffs'},
    {key='REPTILE', label='Druid Heal Proc', category='Short Term Buffs'},
    {key='VIE', label='Vie', category='Short Term Buffs'},
    {key='DI', label='Divine Intervention', category='Short Term Buffs'},
    {key='DG', label='Divine Guardian', category='Short Term Buffs'},
    {key='DG2', label='Divine Guardian Clicky', category='Short Term Buffs'},
    {key='RUNE', label='Rune', category='Short Term Buffs'},
    {key='MANAPROC', label='Mana DD Proc (Enchanter)', category='Short Term Buffs'},
    {key='RECURSION', label='Mana DD Proc (Enchanter Clicky)', category='Short Term Buffs'},
    {key='SLOWPROC', label='Slow Proc', category='Short Term Buffs'},
    {key='TEMPDS', label='Temporary Damage Shield', category='Short Term Buffs'},
    {key='FPARAGON', label='Focused Paragon', category='Short Term Buffs'},
    {key='MELEEPROC', label='Melee Proc', category='Short Term Buffs'},
    -- Resist Buffs
    {key='RESCOLD', label='Resist Cold', category='Resists'},
    {key='RESFIRE', label='Resist Fire', category='Resists'},
    {key='RESDIS', label='Resist Disease', category='Resists'},
    {key='RESMAGIC', label='Resist Magic', category='Resists'},
    {key='RESPOI', label='Resist Poison', category='Resists'},
    {key='RESCORR', label='Resist Corruption', category='Resists'},
}
constants.buffcategories = {'Standard','Stats','Utility','Short Term Buffs','Resists'}
-- Class buff beg defaults
constants.buffs = {
    BER = {
        AEGO = false,
        SYMBOL = true,
        SKIN = true,
        FOCUS = true,
        HASTE = true,
        SHOUT = true,
        STRENGTH = true,
        BRELLS = false,
        SV = false,
        DMF = true,
        DS = true,
        NECROTIC = false,
        REPTILE = false,
        CHAMPION = true,
        WOLF = true,
        FEROCITY = true,
        MELEEPROC = true,
    },
    BRD = {
        AEGO = false,
        SYMBOL = true,
        SKIN = true,
        FOCUS = true,
        HASTE = true,
        SHOUT = true,
        STRENGTH = true,
        BRELLS = false,
        SV = false,
        DMF = true,
        DS = true,
        NECROTIC = false,
        REPTILE = false,
        CHAMPION = true,
        WOLF = true,
    },
    MNK = {
        AEGO = false,
        SYMBOL = true,
        SKIN = true,
        FOCUS = true,
        HASTE = true,
        SHOUT = true,
        STRENGTH = true,
        BRELLS = false,
        SV = false,
        DMF = true,
        DS = true,
        NECROTIC = false,
        REPTILE = false,
        CHAMPION = true,
        WOLF = true,
        FEROCITY = true,
        MELEEPROC = true,
    },
    ROG = {
        AEGO = false,
        SYMBOL = true,
        SKIN = true,
        FOCUS = true,
        HASTE = true,
        SHOUT = true,
        STRENGTH = true,
        BRELLS = false,
        SV = false,
        DMF = true,
        DS = true,
        NECROTIC = false,
        REPTILE = false,
        CHAMPION = true,
        WOLF = true,
        FEROCITY = true,
        MELEEPROC = true,
    },

    CLR = {
        SE = true,
        SKIN = true,
        KEI = true,
        BRELLS = true,
        SHOUT = false,
        SV = false,
        FOCUS = false,
        NECROTIC = true,
        REPTILE = true,
        DMF = true,
        DS = true,
        FPARAGON = true,
    },
    DRU = {
        SE = true,
        SYMBOL = true,
        SPELLHASTE = true,
        KEI = true,
        BRELLS = true,
        SHOUT = false,
        SV = false,
        FOCUS = true,
        NECROTIC = true,
        DMF = true,
        FPARAGON = true,
    },
    SHM = {
        SE = true,
        AEGO = false,
        SYMBOL = true,
        SKIN = true,
        SPELLHASTE = true,
        KEI = true,
        BRELLS = true,
        SHOUT = false,
        SV = false,
        NECROTIC = true,
        REPTILE = true,
        DMF = true,
        DS = true,
        FPARAGON = true,
    },

    PAL = {
        AEGO = true,
        SKIN = false,
        HASTE = true,
        EPICHASTE = true,
        KEI = true,
        SHOUT = true,
        STRENGTH = false,
        SV = false,
        FOCUS = true,
        NECROTIC = true,
        REPTILE = true,
        DMF = true,
        DS = true,
        DI = true,
        DG = true,
        DG2 = true,
        VIE = true,
        SLOWPROC = true,
        CHAMPION = true,
        WOLF = true,
        TEMPDS = true,
        FPARAGON = true,
        VIGOR = true,
        CHA = true,
    },
    SHD = {
        AEGO = true,
        SKIN = false,
        HASTE = true,
        EPICHASTE = true,
        KEI = true,
        BRELLS = true,
        SHOUT = true,
        STRENGTH = false,
        SV = false,
        FOCUS = true,
        NECROTIC = true,
        REPTILE = true,
        DMF = true,
        DS = true,
        DI = true,
        DG = true,
        DG2 = true,
        VIE = true,
        SLOWPROC = true,
        CHAMPION = true,
        WOLF = true,
        TEMPDS = true,
        FPARAGON = true,
        VIGOR = true,
        CHA = true,
    },
    WAR = {
        AEGO = false,
        SYMBOL = true,
        SKIN = true,
        HASTE = true,
        EPICHASTE = true,
        KEI = true,
        BRELLS = true,
        STRENGTH = false,
        SHOUT = true,
        STR = true,
        SV = false,
        FOCUS = true,
        NECROTIC = true,
        REPTILE = true,
        DMF = true,
        DS = true,
        DI = true,
        DG = true,
        DG2 = true,
        VIE = true,
        SLOWPROC = true,
        CHAMPION = true,
        WOLF = true,
        TEMPDS = true,
        VIGOR = true,
        CHA = true,
    },

    ENC = {
        SE = true,
        AEGO = false,
        SYMBOL = true,
        SKIN = true,
        SPELLHASTE = true,
        BRELLS = true,
        SHOUT = false,
        SV = false,
        FOCUS = true,
        NECROTIC = true,
        REPTILE = true,
        DMF = true,
        DS = true,
    },
    MAG = {
        SE = true,
        AEGO = false,
        SYMBOL = true,
        SKIN = true,
        SPELLHASTE = true,
        BRELLS = true,
        KEI = true,
        SHOUT = false,
        SV = false,
        FOCUS = true,
        NECROTIC = true,
        REPTILE = true,
        DMF = true,
        MANAPROC = true,
        RECURSION = true,
    },
    NEC = {
        SE = true,
        AEGO = false,
        SYMBOL = true,
        SKIN = true,
        SPELLHASTE = true,
        BRELLS = true,
        KEI = true,
        SHOUT = false,
        SV = false,
        FOCUS = true,
        REPTILE = true,
        DS = true,
        MANAPROC = true,
        RECURSION = true,
    },
    WIZ = {
        SE = true,
        AEGO = false,
        SYMBOL = true,
        SKIN = true,
        SPELLHASTE = true,
        BRELLS = true,
        KEI = true,
        SHOUT = false,
        SV = false,
        FOCUS = true,
        NECROTIC = true,
        REPTILE = true,
        DMF = true,
        FPARAGON = true,
        MANAPROC = true,
        RECURSION = true,
    },

    BST = {
        AEGO = false,
        SYMBOL = true,
        SKIN = true,
        FOCUS = true,
        SPELLHASTE = true,
        KEI = true,
        NECROTIC = true,
        REPTILE = true,
        DMF = true,
        DS = true,
        CHAMPION = true,
        WOLF = true,
        FEROCITY = true,
    },
    RNG = {
        SE = true,
        AEGO = false,
        SYMBOL = true,
        SKIN = true,
        FOCUS = true,
        SPELLHASTE = true,
        KEI = true,
        NECROTIC = true,
        REPTILE = true,
        DMF = true,
        DS = true,
        CHAMPION = true,
        WOLF = true,
    },
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
    'Blazing Void Orb',
    'Molten Orb',
    'Lava Orb',
}
constants.deleteWhenDead = {
    ['Blazing Void Orb']=true,
    ['Molten Orb']=true,
    ['Lava Orb']=true,
    ['Sanguine Mind Crystal III']=true,
    ['Large Modulation Shard']=true,
}

constants.assists = {group=1,raid1=1,raid2=1,raid3=1,actor=1,manual=1}
constants.groupWatchOptions = {healer=1,self=1,none=1}
constants.pullWith = {melee=1,ranged=1,spell=1,item=1,custom=1}
constants.pullStates = {NOT='NOT',SCAN='SCAN',APPROACHING='APPROACHING',ENGAGING='ENGAGING',WAIT_FOR_AGGRO='WAIT_FOR_AGGRO',RETURNING='RETURNING',WAITING='WAITING',PULLED='PULLED'}

constants.manaClasses = {CLR=true,DRU=true,SHM=true,ENC=true,MAG=true,NEC=true,WIZ=true,RNG=true}
constants.petClasses = {BST=true,MAG=true,NEC=true,DRU=true,ENC=true,SHD=true,SHM=true}
constants.buffClasses = {CLR=true,DRU=true,SHM=true,ENC=true,MAG=true,NEC=true,RNG=true,BST=true}
constants.healClasses = {CLR=true,DRU=true,SHM=true,PAL=true}
constants.hybridHealClasses = {RNG=true,BST=true}
constants.tankClasses = {PAL=true,SHD=true,WAR=true}
constants.meleeClasses = {BER=true,BRD=true,BST=true,MNK=true,RNG=true,ROG=true}
constants.nukeClasses = {BST=true,CLR=true,DRU=true,ENC=true,MAG=true,NEC=true,RNG=true,SHM=true,WIZ=true}
constants.dotClasses = {BST=true,DRU=true,ENC=true,NEC=true,RNG=true,SHD=true,SHM=true}
constants.fdClasses = {MNK=true,NEC=true,SHD=true,BST=true}
constants.intClasses = {ENC=true,MAG=true,NEC=true,WIZ=true}

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

constants.burns = {first=1,second=1,third=1,quick=1,long=1,epicburn=1}

constants.slotList = 'earrings, rings, leftear, rightear, leftfinger, rightfinger, face, head, neck, shoulder, chest, feet, arms, leftwrist, rightwrist, wrists, charm, powersource, mainhand, offhand, ranged, ammo, legs, waist, hands'

constants.routines = {heal=1,assist=1,mash=1,burn=1,cast=1,cure=1,buff=1,rest=1,ae=1,mez=1,aggro=1,ohshit=1,rez=1,recover=1,managepet=1}

constants.classLists = {
    'DPSAbilities', 'AEDPSAbilities', 'burnAbilities', 'tankAbilities', 'tankBurnAbilities', 'AETankAbilities', 'healAbilities',
    'fadeAbilities', 'defensiveAbilities', 'aggroReducers', 'recoverAbilities', 'combatBuffs', 'auras', 'selfBuffs',
    'singleBuffs', 'petBuffs', 'cures', 'debuffs', 'clickies', 'castClickies', 'pullClickies', 'requestAliases', 'rezAbility'
}

constants.uiThemes = {
    BLACK = {
        windowbg = ImVec4(.1, .1, .1, .9),
        bg = ImVec4(0, 0, 0, 1),
        hovered = ImVec4(.4, .4, .4, 1),
        active = ImVec4(.3, .3, .3, 1),
        button = ImVec4(.3, .3, .3, 1),
        text = ImVec4(1, 1, 1, 1),
    },
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

constants.BLOCKSPELLS = {
    3384, -- Talisman of the Tribunal
    3242, -- Guard of Druzzil
    3444, -- Protection of Seasons
    1582, -- Talisman of the Serpent
    10607, -- Illusion: War Pirate
    21684, -- Form of the Black Wolf
    27743, -- Illusion: Drachnid
    30707, -- Pact of the Wolf Effect
    36838, -- It's Levitation, But Fancier!
}
constants.BLOCKPETSPELLS = {
    3384, -- Talisman of the Tribunal
    3242, -- Guard of Druzzil
    3444, -- Protection of Seasons
    1582, -- Talisman of the Serpent
    21684, -- Form of the Black Wolf
    30707, -- Pact of the Wolf Effect
    36838, -- It's Levitation, But Fancier!
}

return constants