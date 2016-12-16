/*
	Round Phases
*/
#define PHASE_DISABLED 0
#define PHASE_NULL 1
#define PHASE_BUILD 2
#define PHASE_WAR 4
#define PHASE_SUDDEN 8

/*
	Entity States
*/
#define STATE_VALID 1
#define STATE_BASE 2
#define STATE_GRABBED 4
#define STATE_SAVED 8
#define STATE_DELETED 16
#define STATE_BREAKABLE 32
#define STATE_PHASE 64

/*
	Class Indexes.
*/
#define TOTAL_CLASSES 9

#define CLASS_NONE 0
#define CLASS_SCOUT 1
#define CLASS_SOLDIER 2
#define CLASS_PYRO 3
#define CLASS_DEMOMAN 4
#define CLASS_HEAVY 5
#define CLASS_ENGINEER 6
#define CLASS_MEDIC 7
#define CLASS_SNIPER 8
#define CLASS_SPY 9

#if defined _buildwars_included
	#endinput
#endif
#define _buildwars_included

/**
 * Gets the current state of an entity
 *
 * @param iEntity		The specific entity.
 * @return			 	A bitvalue containing the entity's state.
 *					 0: Entity is not a valid prop.
 *					 1: Entity is a valid prop for BuildWars.
 *					 2: Entity also belongs to a player's base.
 *					 4: Entity is being grabbed by a player.
 *					 8: Entity is currently being saved.
 *					16: Entity is currently being deleted. 
 *					32: Entity may not be a prop, but can be broken via gunfire.
 *					64: Entity is currently phased. 
**/
native BuildWars_GetEntityState(iEntity);

/**
 * Gets the current state of a valid prop.
 *
 * @param iEntity		The specific entity.
 * @return				The team the entity belongs to.
**/
native BuildWars_GetPropTeam(iEntity);

/**
 * Gets the owner of a valid prop.
 *
 * @param iEntity		The specific entity.
 * @return				The userid for the owner.
**/
native BuildWars_GetPropOwner(iEntity);

/**
 * Gets the current state of an entity. Assumes provided string is 64 chars.
 *
 * @param iEntity		The specific entity.
 * @return				Entity's name as defined in configation file.
**/
native BuildWars_GetPropName(iEntity, String:name[]);

/**
 * Forwards when the phase for BuildWars is changed.
 * @param iPhase		The current phase of BuildWars.
 *					 0: The phase is currently disabled... Not running perhaps?
 *					 1: The phase is currently Null.
 *					 2: The phase is currently Build.
 *					 4: The phase is currently War.
 *					 8: The phase is currently Sudden Death. 
**/
forward BuildWars_OnPhaseChange(_iPhase);

/**
 * Forwards when the help plugin is loaded.
**/
forward BuildWars_OnHelpLoad();

/**
 * Forwards when the class plugin is loaded.
**/
forward BuildWars_OnClassesLoad();

/**
 * Forwards when a client has his/her classes loaded.
 * @param client		The client that just had classes loaded.
 * @param class	 		The class index.
**/
forward BuildWars_OnClassChange(client, class);