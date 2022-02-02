# AQO Bot Overview

## File Structure

- *aqo.lua*: launch script, handles the outermost run loop and bindings.
- *aqo/common.lua*: helper functions reused by all class implementations.
- *aqo/configuration.lua*: maintains configuration settings common to all classes.
- *aqo/mode.lua*: defines the available modes which classes can run in.
- *aqo/state.lua*: maintains internal state such as camp location.
- *aqo/ui.lua*: implements the UI window and helper functions for class specific UI pieces.
- *aqo/classes/{class_short_name}.lua*: class specific implementations.
- *aqo/routines/assist.lua*: implements functionality related to engaging mobs in assist modes.
- *aqo/routines/camp.lua*: implements functionality related to setting camp details and staying within the camp.
- *aqo/routines/mez.lua*: implements functionality related to mezzing mobs in camp.
- *aqo/routines/pull.lua*: implements functionality related to pulling mobs in pull modes.
- *aqo/routines/tank.lua*: implements functionality related to tanking mobs in tank modes.
- *aqo/utils/logger.lua*: provides logging functions like printf and debug.
- *aqo/utils/persistence.lua*: provides lua table persistence to a file.
- *aqo/utils/timer.lua*: provides a timer class.

## Modes

The configured mode controls how a character will behave at a high level.

### Manual
This mode will not stick to mobs or do any assisting. It will cast buffs when not invis, and use its combat routines if a mob is engaged manually.

- Assists MA: No
- Breaks Invis: No
- Chases: No
- Sets camp: No

### Assist
This mode will stay within a defined camp radius and assist the defined main assist and do everything which a support or DPS role should do.

- Assists MA: Yes
- Breaks Invis: Yes
- Chases: No
- Sets camp: Yes

### Chase
This mode will follow the defined main assist and do everything which a support or DPS role should do.

- Assists MA: Yes
- Breaks Invis: No
- Chases: Yes
- Sets camp: No

### Vorpal
This mode will do everything which a support or DPS role should do, without trying to stay within a defined camp radius or chasing the defined main assist.

- Assists MA: Yes
- Breaks Invis: No
- Chases: No
- Sets camp: No

### Tank
This mode will attempt to tank any mob which appears within the defined camp radius.

- Assists MA: No
- Breaks Invis: Yes (not yet?)
- Chases: No
- Sets camp: Yes

### Puller Tank
This mode will pull mobs within the defined pull radius back to the defined camp radius and attempt to tank them when they arrive.

- Assists MA: No
- Breaks Invis: Yes (not yet?)
- Chases: No
- Sets camp: Yes

### Puller
This mode will pull mobs within the defined pull radius back to the defined camp radius and do everything which a support or DPS role should do.

- Assists MA: Yes
- Breaks Invis: Yes (not yet?)
- Chases: No
- Sets camp: Yes

## Burn Conditions
A number of controls exist which can be configured to decide when to trigger burn abilities.

### Burn Always
Use all available burns on cooldowns.

### Burn All Named
Use burns whenever `${Target.Named}==TRUE`.

### Burn Count
Use burns whenever the number of mobs on extended target exceeds the defined value.

### Burn Percent
Use burns once the target is below the defined HP percent value.
