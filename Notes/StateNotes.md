# Notes

`state.lua` defines a table `state` which stores the shared state of the script to be set and consumed by all of the modules.

## Actions

The field `state.actionTaken` is a boolean which is set to `true` when some action has been taken in a given iteration of the main script loop. This is done to attempt following an `OnPulse` sort of model similar to plugins, opposed to running as a synchronous script. Once `state.actionTaken` has been set to true, all remaining processing within the same iteration should return immediately, taking no other actions.

## State Handlers

Various modules may trigger some action which takes more than one frame to complete, such as getting into position to fight a mob, memorizing a spell or casting a spell. Each of these will almost always have some followup action to be performed as well.

### Positioning

Engaging a mob in melee sets `state.positioning` to `true`, triggering the `handlePositioningState` handler. This handler will return `false` until navigation is no longer active (character has reached the mob) or the `state.positioningTimer` timer has expired (5 seconds).

### Queued Action

The `handleQueuedAction` state handler supports a singular action to be queued up. This is a very dumb workaround to implementing a full queueing system. When some action 

### Mem Spell


### Casting


## Combat State

## 