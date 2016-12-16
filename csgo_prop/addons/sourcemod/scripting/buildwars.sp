/*
	==================================================================================================================================================
	Version 3.4.2
	==================================================================================================================================================
	- Plugin is now compatible with SM 1.7. (Older versions will not load / will crash during use).
	- MoreColors.inc is now optional; plugin defaults to SM commands if MoreColors is not available at compile time.
	- Plugin no longer refuses to boot if 'buildwars' doesn't exist in databases.cfg
	--- Plugin now disables features that require the database to function, namely bases and admin zones.
	--- Fixed a few extremely remote bugs that could happen if database connection is lost.
	- Plugin now requires AutoExecConfig during compile time, allowing the .cfg file to update when/if necessary.
	- Plugin now utilizes GetClientAuthId over GetClientAuthString as the latter was depreciated.
	--- Any data saved within the database via the old method (STEAM:x:x:xxxxxxxxx) will not load under this method.
	--- Instead, data is saved in string format as a SteamID64 (uint64), ex: 76561197968573709
	------- This means if you want your previous bases to be compatible, you have to convert your SteamIDs into SteamID64. (http://steamid.co/)
	- Translation file buildwars.phrases has been replaced with buildwars.css.phrases and buildwars.csgo.phrases.
	- Configuration file buildwars.cfg has been replaced with buildwars.css.cfg and buildwars.csgo.cfg.
	==================================================================================================================================================

	==================================================================================================================================================
	Version 3.4.3
	==================================================================================================================================================
	- Multiple areas of the plugin have been reworked to update previously half-assed/non-existant CS:GO support.
	--- Phase notifications (current time left, current phase, etc) have been improved upon and no longer spam chat.
	--- Disclaimer: CS:GO still does not support proper .wav playing, so sound support is not available.

	- Bug Fixes!
	--- An issue introduced in v3.4.2 involving configuration files not loading correctly has been squashed.
	--- Props are now correctly spawned when placed on top of glass or transparent entities (previously, props would spawn on the other side).
	--- Plugin no longer attempts to create the dissolver effect when running on a CS:GO server.
	--- The Concrete Pipe is no longer a default prop in CS:GO due to it apparently being broken.
	--- Numerous errors in the default props file for CS:GO have been corrected; blame alcohol.
	--- Key Actions will no longer interfere with administrators attempting to create Zones.

	- Improvements! Features! Miscellaneous!
	--- Players that spawn during the Building phase will now automatically pull out their Knife, to better accomodate Key Actions.
	--- The Weapon Inspection event (defaults to the 'f' key, or console command 'lookatweapon') is now hooked in CS:GO to display current phase time remaining.
	--- Players attempting to spawn props when the maximum entity count has been reached are now correctly informed.
	--- Plugin no longer supports the 'Legacy' phase. Maps that provide 'Legacy' gameplay now have full control. (Legacy = Not using the plugin's Build/War phase)
	--- Plugin now generates some of the LogErrors as well as convar protection specific messages to /sourcemod/logs/buildwars.debug.log while in DEBUG_MODE.
	--- Depreciated buildwars_notify_mode, as plugin now accurately detects CS:S and CS:GO and manages messages correctly.
	--- Depreciated the usage of Dynamic Hooks as it's unnecessary work for a cosmetic change applying to only the Build phase.

	- The Notify Newbies feature, controlled by buildwars_notify_newbies, has been reworked.
	--- Previously, this feature would spam the user until they typed !build or !help, and then disable itself.
	--- Feature now sends a single message the first 3 times joining the server informing them of the !build / !help command.

	- Implemented a Convar Protection system similar to my KvConfigs / CS:GO Idle Manager.
	--- Said system prevents any convar defined within the configuration file from being changed by any means other than provided commands.
	--- bw_setprotected <convar> <value> - Lets you modify a protected convar, however, changes must be re-applied per map change unless modified in the cfg.
	--- bw_remprotected <convar> - Removes protected status of a convar and returns it to its original value. Ditto to the re-application.
	--- Convar buildwars_convar_bounds has been added, which removes the upper/lower bounds of specified convars, to complement the system.

	- The translation files have received a complete (and unnecessary) overhaul.
	--- Multiple phrases that were no longer being used have been removed.
	--- Multiple changes have been made to the naming scheme of various features.

	- Several convenience/simplicity changes have been made to the structure of the menus.
	--- Players are no longer able to assign a color to individual props. Props are assigned a default color (be it random or static) based on a client's setting.
	--- The ability to set a prop's default color has been moved to the Prop Actions menu.
	--- The ability to remove all of one's props from the map has been moved to the Prop Actions menu.
	--- Players are no longer able to set their default Position, Rotation, and Distance interval within the Player Actions menu.
	------ These abilities already exist within the Move Prop, Rotate Prop, and Control Prop menus.
	--- The Check Prop ability (which identifies the prop and its owner) has been moved to the Prop Actions menu from the main menu.

	- Multiple changes have been made to the structure of the menus to better accomdate CS:GO's lack of a menu slot, and only pertain to CS:GO servers.
	--- Players with BuildWars admin will now find their "Rot: ? ? ?" and "Pos: ? ? ?" menu options on the following page.
	--- The cosmetic spacers (Translation: menuOptionSpacerSelection) have been disabled.
	--- Pagination for main menus, where appropriate, has been disabled, allowing for 7 options and an Exit option (vs 6 options, Next/Back/Exit).

	- Key Actions now assign different default values to new clients. (Key Actions = 'e', Right Click / Left Click with a Knife)
	--- The 'e' key no longer has a default value, as CS:GO binds 'e' to open the buy menu.
	--- Left clicking with a Knife will now bring up the main menu.
	--- Right clicking with a Knife will now bring up the Prop Actions menu.
	
	- The base feature has had its menu redesigned, to better suit both CS:GO and more coherent usage of the base system.
	--- Additionally, the ability to move entire bases has been removed. Too much potential for abuse / unnecessary strain on the server.
	--- Options have been condensed into a single menu so everything necessary is available, instead of having multiple menus with a confusing layout.
	--- Current Design:
	------ Activate Base 			(Opens a menu listing the available bases)
	-----> Active: <Base Name> 		(Option replaces the previous after selecting a base)
	------ Place Spawn Point
	-----> Remove Save Point 		(Option replaces the previous after placing a save point)
	------ Spawn Base Props
	------ Save Target Prop
	------ Unsave Target Prop
	------ Reset Base: <Base Name>
	--- The "Update Save Point" option is not available on CS:GO servers due to menu size restraints, but appears below Remove Save Point on CS:S servers.
	
	==================================================================================================================================================
*/

#pragma semicolon 1

#define PLUGIN_VERSION "3.4.3"

#include <sourcemod>
#include <sdktools>
#include <adminmenu>
#include <clientprefs>
#include <buildwars>
#include <sdkhooks>
#include <cstrike>
#include <autoexecconfig>
#undef REQUIRE_EXTENSIONS
#tryinclude <morecolors>
#define REQUIRE_EXTENSIONS

//Hardcoded limits for various features; increase if you need more than the provided values.
#define MAX_CONFIG_PROPS 64		//Allowed pre-defined props.
#define MAX_CONFIG_COLORS 32	//Allowed pre-defined colors.
#define MAX_CONFIG_ROTATIONS 24	//Allowed pre-defined rotations.
#define MAX_CONFIG_POSITIONS 24	//Allowed pre-defined positions.
#define MAX_CONFIG_COMMANDS 24	//Allowed pre-defined commands.
#define MAX_CONFIG_MAPS 64		//Allowed pre-defined maps.
#define MAX_CONFIG_MODES 64		//Allowed pre-defined sudden death modes.
#define MAX_CONFIG_OPERATIONS 24//Allowed operations per sudden death modes.
#define MAX_SPAWN_POINTS 32		//Allowed spawn points.
#define MAX_PHASE_SOUNDS 16		//Allowed notify sounds.
#define MAX_CONFIG_GROUPS 16	//Allowed pre-defined configuration groups.
#define MAX_CONFIG_DURATIONS 32	//Allowed pre-defined gimp durations.

//Maximum limit of entities the 2009 Source engine allows before crashing.
#define MAX_SERVER_ENTITIES 2048

//Total number of defined cvars.
#define CVAR_COUNT 80

//Cvar indexes.
#define cPluginEnabled 0
#define cPluginDatabase 1
#define cPluginDebug 2
#define cMaximumEntities 3
#define cHelpUrl 4
#define cAdvertDelay 5
#define cConvarBounds 6
#define cNotifyNewPlayers 7
#define cNotifyPhaseChange 8
#define cNotifyPhaseStartSounds 9
#define cNotifyPhaseEnd 10
#define cNotifyPhaseEndSounds 11
#define cNotifyFrequency 12
#define cDisableRadio 13
#define cDisableSuicide 14
#define cDisableFalling 15
#define cDisableDrowning 16
#define cDisableCrouching 17
#define cDisableRadar 18
#define cDisableSlowing 19
#define cDisableBreaking 20
#define cDisableThird 21
#define cDisableConsoleChat 22
#define cDisableFlying 23
#define cDisableLegacy 24
#define cDisableBuild 25
#define cDisableWar 26
#define cDisableSudden 27
#define cDurationLegacy 28
#define cDurationBuild 29
#define cDurationWar 30
#define cEnableSudden 31
#define cEnableAdvancingTeam 32
#define cDissolveProps 33
#define cPhaseStuckBeacon 34
#define cPropDeleteDelay 35
#define cPhasePropDeleteDelay 36
#define cEnableAnywhereBuyzone 37
#define cForceMenusClose 38
#define cPropColoringTerrorist 39
#define cPropColoringCounter 40
#define cPropColoringSpec 41
#define cCanRedAccess 42
#define cCanBlueAccess 43
#define cControlNonSolid 44
#define cControlDistance 45
#define cControlRefreshRate 46
#define cControlMinDistance 47
#define cControlMaxDistance 48
#define cControlChangeInterval 49
#define cEnableZoneControl 50
#define cIgnoreWinConditions 51
#define cModifyFallDamage 52
#define cModifyCrouchSpeed 53
#define cPropProximityFlagDelay 54
#define cPhaseReadyAllow 55
#define cReadyBuildPercent 56
#define cReadyChangeDelay 57
#define cReadyWaitDelay 58
#define cReadyMinimumPlayers 59
#define cReadyWarPercent 60
#define cScrambleRounds 61
#define cMaintainTeamSizes 62
#define cMaintainTeamSpawns 63
#define cPersistentProps 64
#define cPersistentPropColors 65
#define cPropPhaseFlagDelay 66
#define cEnableAntiAway 67
#define cAntiAwayDelay 68
#define cAntiAwayKick 69
#define cAntiAwayKickDelay 70
#define cAntiAwayReturn 71
#define cAntiAwaySpec 72
#define cAntiAwaySpecDelay 73
#define cAntiAwayForce 74
#define cAntiAwayForceDelay 75
#define cBaseDistance 76
#define cBaseDefaultNames 77
#define cBaseDefaultColor 78
#define cDefaultGimpDuration 79

//Command Indexes...
#define COMMAND_MAIN 0
#define COMMAND_ROTATION 1
#define COMMAND_POSITION 2
#define COMMAND_DELETE 3
#define COMMAND_CONTROL 4
#define COMMAND_CHECK 5
#define COMMAND_STUCK 6
#define COMMAND_HELP 7
#define COMMAND_READY 8
#define COMMAND_CLEAR 9
#define COMMAND_THIRD 10
#define COMMAND_FLY 11
#define COMMAND_CLONE 12
#define COMMAND_PHASE 13

#define MODE_NORMAL 0
#define MODE_DEBUG 1
#define MODE_BUILD 2
#define MODE_IMITATE 3

//Quick Function Keys / Indexes...
#define FUNCTION_KEY_USE 0
#define FUNCTION_KEY_USE_CHAR "0"
#define FUNCTION_KEY_LEFT 1
#define FUNCTION_KEY_LEFT_CHAR "1"
#define FUNCTION_KEY_RIGHT 2
#define FUNCTION_KEY_RIGHT_CHAR "2"

#define FUNCTION_DISABLED 0
#define FUNCTION_MAIN_MENU 1
#define FUNCTION_MODIFY_MENU 2
#define FUNCTION_CONTROL_MENU 3
#define FUNCTION_SPAWN_PROP 4
#define FUNCTION_CLONE_PROP 5
#define FUNCTION_DELETE_PROP 6
#define FUNCTION_GRAB_PROP 7
#define FUNCTION_CHECK_PROP 8
#define FUNCTION_PHASE_PROP 9
#define FUNCTION_TOGGLE_THIRD 10
#define FUNCTION_TOGGLE_FLYING 11

//Quick Access...
#define QUICK_DISABLE 0
#define QUICK_MENU 1
#define QUICK_DELETE 2
#define QUICK_CLONE 3

//Phase Disable Flags...
#define DISABLE_SPAWN 1
#define DISABLE_DELETE 2
#define DISABLE_ROTATE 4
#define DISABLE_MOVE 8
#define DISABLE_CONTROL 16
#define DISABLE_CHECK 32
#define DISABLE_TELE 64
#define DISABLE_COLOR 128
#define DISABLE_CLEAR 256
#define DISABLE_ADMIN_SPAWN 512
#define DISABLE_ADMIN_DELETE 1024
#define DISABLE_ADMIN_ROTATE 2048
#define DISABLE_ADMIN_MOVE 4096
#define DISABLE_ADMIN_CONTROL 8192
#define DISABLE_ADMIN_CHECK 16384
#define DISABLE_ADMIN_TELE 32768
#define DISABLE_ADMIN_COLOR 65536
#define DISABLE_ADMIN_CLEAR 131072
#define DISABLE_PHASE 262144
#define DISABLE_ADMIN_PHASE 524288

//Spawn Modes...
#define SPAWNING_DISABLED 0
#define SPAWNING_TEAMS 1
#define SPAWNING_SINGLES 2
#define SPAWNING_TIMED 3

//Round Points...
#define POINTS_KILL 100
#define POINTS_DEATH -50
#define POINTS_BUILD -1
#define POINTS_DELETE 1

//Admin Targeting...
#define TARGET_SINGLE 0
#define TARGET_RED 1
#define TARGET_BLUE 2
#define TARGET_ALL 3

//Modifcation Axis...
#define POSITION_AXIS_X 0
#define POSITION_AXIS_Y 1
#define POSITION_AXIS_Z 2

//States
#define STATE_AUTO 0
#define STATE_DISABLE 1
#define STATE_ENABLE 2

//Wall Array Indexes
#define INDEX_ENTITY 64
#define INDEX_MOVED 65

//Menu Indexes
#define MENU_MAIN 0
#define MENU_CREATE 1
#define MENU_ROTATE 2
#define MENU_MOVE 3
#define MENU_CONTROL 4
#define MENU_COLOR 5
#define MENU_ACTION 6
#define MENU_ADMIN 7
#define MENU_BASE_LEGACY -1
#define MENU_BASE_MAIN 8
#define MENU_BASE_MOVE 9
#define MENU_BASE_ACTIVE 10

#define ADMIN_MENU_CLEAR 0
#define ADMIN_MENU_STUCK 1
#define ADMIN_MENU_COLOR 2
#define ADMIN_MENU_GIMP 3
#define ADMIN_MENU_BASE 4
#define ADMIN_MENU_ZONE 5

//Restrictions...
#define RESTRICTION_WEAPONS 40
#define RESTRICTION_RED 0
#define RESTRICTION_BLUE 1
#define RESTRICTION_TOTAL 2

#define ALPHA_PROP_NORMAL -1
#define ALPHA_PROP_GRABBED 200
#define ALPHA_PROP_PHASED 150
#define ALPHA_PROP_DELETED 100
#define ALPHA_PROP_SAVED 200
#define ALPHA_PROP_WAR 150

#define GRENADE_NULL 0
#define GRENADE_HE 1
#define GRENADE_FB 2
#define GRENADE_SG 4
#define GRENADE_MO 8
#define GRENADE_DE 16

#define NOTIFICATION_OFF 0
#define NOTIFICATION_CSS 1
#define NOTIFICATION_CSGO 2

//Sprites...
#define SPRITE_CSS_HALO "sprites/halo01.vmt"
#define SPRITE_CSS_LASER "sprites/laser.vmt"
#define SPRITE_CSS_FLASH "sprites/muzzleflash4.vmt"
#define SPRITE_CSS_BALL "sprites/strider_blackball.vmt"

#define SPRITE_CSGO_HALO "sprites/halo01.vmt"
#define SPRITE_CSGO_LASER "sprites/laserbeam.vmt"
#define SPRITE_CSGO_FLASH "sprites/smoke.vmt"
#define SPRITE_CSGO_BALL "sprites/xfireball3.vmt"

//Modes...
#define MODE_DEATHMATCH 1	//No Props
#define MODE_ASSAULT 2		//Destructable props
#define MODE_DODGE 3		//Dodgeball type gameplay

//- States for cells.
#define cCastInteger 0
#define cCastFloat 1
#define cCastString 2

#define TOTAL_ZONE_HELP 4
new String:g_sZoneHelp[TOTAL_ZONE_HELP][192] =
{
	"1) This feature lets you assign a zone type to the three primary areas of a map:",
	"2) - Terrorist Side, Counter-Terrorist Side, and Neutral (usually area where Wall is, if it is thick enough).",
	"3) It also allows definition of four different areas where players cannot build",
	"4) There can only be one of each area; creating a second will delete the first."
};

//Various declarations to save time.
new String:g_sAxisDisplay[][] = {"X", "Y", "Z"};
new String:g_sPropTypes[][] = { "prop_dynamic", "prop_dynamic_override", "prop_physics_multiplayer", "prop_physics_override", "prop_physics" };

//Queries
new String:g_sSQL_BaseLoad[] = { "SELECT `base_index`, `base_count` FROM `buildwars_bases` WHERE `steamid` = '%s'" };
new String:g_sSQL_BaseCreate[] = { "INSERT INTO `buildwars_bases` (`steamid`, `base_index`) VALUES ('%s', NULL)" };
new String:g_sSQL_BaseUpdate[] = { "UPDATE `buildwars_bases` SET `base_count` = %d WHERE `base_index` = '%d'" };
new String:g_sSQL_PropLoad[] = { "SELECT `prop_index`, `prop_type`, `pos_x`, `pos_y`, `pos_z`, `ang_x`, `ang_y`, `ang_z` FROM `buildwars_props` WHERE `prop_base` = %d" };
new String:g_sSQL_PropSaveIndex[] = { "REPLACE INTO buildwars_props (prop_index, prop_base, prop_type, pos_x, pos_y, pos_z, ang_x, `ang_y`, `ang_z`, `steamid`) VALUES (%d, %d, %d, %.2f, %.2f, %.2f, %.2f, %.2f, %.2f, '%s')" };
new String:g_sSQL_PropSaveLegacy[] = { "REPLACE INTO buildwars_props (prop_index, prop_base, prop_type, pos_x, pos_y, pos_z, ang_x, ang_y, ang_z, steamid) VALUES (NULL, %d, %d, %.2f, %.2f, %.2f, %.2f, %.2f, %.2f, '%s')" };
new String:g_sSQL_PropDelete[] = { "DELETE FROM buildwars_props WHERE prop_index = %d" };
new String:g_sSQL_PropEmpty[] = { "DELETE FROM buildwars_props WHERE prop_base = %d AND steamid = '%s'" };
new String:g_sSQL_PropCheck[] = { "SELECT prop_index FROM buildwars_props WHERE prop_base = %d" };

enum MapZoneEditor
{
	Step,
	Float:Point1[3],
	Float:Point2[3]
};

enum MapZoneType
{
	Team_T,
	Team_CT,
	Team_None,
	Block_Build
};

enum MapZone
{
	Id,
	MapZoneType:Type,
	String:Map[32],
	Float:Point1[3],
	Float:Point2[3]
};

enum Access
{
	iAccess,
	bool:bAdmin,
	bool:bAfkImmunity,
	bool:bAccessMove,
	bool:bAccessRotate,
	bool:bAccessCheck,
	bool:bAccessControl,
	bool:bAccessCrouch,
	bool:bAccessRadar,
	bool:bAccessCustom,
	bool:bAccessSpec,
	bool:bAccessProp,
	bool:bAccessDelete,
	bool:bAccessClear,
	bool:bAccessThird,
	bool:bAccessFly,
	bool:bAccessPhase,
	bool:bAccessTeleport,
	bool:bAccessColor,
	bool:bAccessBase,
	bool:bAccessSettings,
	bool:bAccessAdminMenu,
	bool:bAccessAdminGimp,
	bool:bAccessAdminDelete,
	bool:bAccessAdminClear,
	bool:bAccessAdminStuck,
	bool:bAccessAdminColor,
	bool:bAccessAdminBase,
	bool:bAccessAdminTarget,
	bool:bAccessAdminZone,
	bool:bAccessExplosives,
	iTotalProps,
	iTotalPropsAdvance,
	iTotalDeletes,
	iTotalTeleports,
	iTotalColors,
	iTotalBases,
	iTotalBaseProps,
	Float:fStuckDelay
};

new g_Cfg_iPropAccess[MAX_CONFIG_PROPS];
new g_Cfg_iPropTypes[MAX_CONFIG_PROPS];
new g_Cfg_iPropTypeToBase[MAX_CONFIG_PROPS];
new g_Cfg_iBaseToPropType[MAX_CONFIG_PROPS];
new g_Cfg_iPropHealth[MAX_CONFIG_PROPS][4];
new g_Cfg_iColorAccess[MAX_CONFIG_PROPS];
new g_Cfg_iColorArrays[MAX_CONFIG_COLORS][4];
new g_Cfg_iModeDuration[MAX_CONFIG_MODES];
new g_Cfg_iModeMethod[MAX_CONFIG_MODES];
new g_iCfg_GimpDurations[MAX_CONFIG_DURATIONS];
new bool:g_Cfg_bModeCenter[MAX_CONFIG_MODES];
new bool:g_Cfg_bPropAlpha[MAX_CONFIG_PROPS];
new bool:g_Cfg_bModeChat[MAX_CONFIG_MODES];
new String:g_Cfg_sPropNames[MAX_CONFIG_PROPS][64];
new String:g_Cfg_sPropPaths[MAX_CONFIG_PROPS][256];
new String:g_Cfg_sColorNames[MAX_CONFIG_COLORS][64];
new String:g_Cfg_sModes[MAX_CONFIG_MODES][192];
new String:g_Cfg_sModesChat[MAX_CONFIG_MODES][192];
new String:g_Cfg_sModesCenter[MAX_CONFIG_MODES][192];
new String:g_Cfg_sModesStart[MAX_CONFIG_MODES][512];
new String:g_Cfg_sModesEnd[MAX_CONFIG_MODES][512];
new String:g_Cfg_sGimpDisplays[MAX_CONFIG_DURATIONS][128];
new Float:g_Cfg_fPropRadius[MAX_CONFIG_PROPS];
new Float:g_Cfg_fDefinedRotations[MAX_CONFIG_ROTATIONS];
new Float:g_Cfg_fDefinedPositions[MAX_CONFIG_POSITIONS];

new Handle:g_hRestrictCvar[RESTRICTION_TOTAL][RESTRICTION_WEAPONS] = { { INVALID_HANDLE, ... }, { INVALID_HANDLE, ... } };
new g_iRestrictOriginal[RESTRICTION_TOTAL][RESTRICTION_WEAPONS];
new bool:g_bRestrictReturn[RESTRICTION_TOTAL][RESTRICTION_WEAPONS];
new bool:g_bRestrictState[RESTRICTION_TOTAL][RESTRICTION_WEAPONS];

new bool:g_bAccessAdmin[MAX_CONFIG_GROUPS];
new bool:g_bAccessImmunity[MAX_CONFIG_GROUPS];
new bool:g_bAccessMove[MAX_CONFIG_GROUPS];
new bool:g_bAccessRotate[MAX_CONFIG_GROUPS];
new bool:g_bAccessCheck[MAX_CONFIG_GROUPS];
new bool:g_bAccessControl[MAX_CONFIG_GROUPS];
new bool:g_bAccessCrouch[MAX_CONFIG_GROUPS];
new bool:g_bAccessRadar[MAX_CONFIG_GROUPS];
new bool:g_bAccessCustom[MAX_CONFIG_GROUPS];
new bool:g_bAccessSpec[MAX_CONFIG_GROUPS];
new bool:g_bAccessProp[MAX_CONFIG_GROUPS];
new bool:g_bAccessThird[MAX_CONFIG_GROUPS];
new bool:g_bAccessFly[MAX_CONFIG_GROUPS];
new bool:g_bAccessPhase[MAX_CONFIG_GROUPS];
new bool:g_bAccessDelete[MAX_CONFIG_GROUPS];
new bool:g_bAccessClear[MAX_CONFIG_GROUPS];
new bool:g_bAccessTeleport[MAX_CONFIG_GROUPS];
new bool:g_bAccessColor[MAX_CONFIG_GROUPS];
new bool:g_bAccessBase[MAX_CONFIG_GROUPS];
new bool:g_bAccessSettings[MAX_CONFIG_GROUPS];
new bool:g_bAccessAdminMenu[MAX_CONFIG_GROUPS];
new bool:g_bAccessAdminGimp[MAX_CONFIG_GROUPS];
new bool:g_bAccessAdminDelete[MAX_CONFIG_GROUPS];
new bool:g_bAccessAdminClear[MAX_CONFIG_GROUPS];
new bool:g_bAccessAdminStuck[MAX_CONFIG_GROUPS];
new bool:g_bAccessAdminColor[MAX_CONFIG_GROUPS];
new bool:g_bAccessAdminBase[MAX_CONFIG_GROUPS];
new bool:g_bAccessAdminTarget[MAX_CONFIG_GROUPS];
new bool:g_bAccessAdminZone[MAX_CONFIG_GROUPS];
new bool:g_bAccessExplosives[MAX_CONFIG_GROUPS];
new g_iAccessIdens[MAX_CONFIG_GROUPS];
new g_iAccessFlags[MAX_CONFIG_GROUPS];
new g_iAccessTotalProps[MAX_CONFIG_GROUPS];
new g_iAccessTotalAdvanceProps[MAX_CONFIG_GROUPS];
new g_iAccessTotalDeletes[MAX_CONFIG_GROUPS];
new g_iAccessTotalTeleports[MAX_CONFIG_GROUPS];
new g_iAccessTotalColors[MAX_CONFIG_GROUPS];
new g_iAccessTotalBases[MAX_CONFIG_GROUPS];
new g_iAccessTotalBaseProps[MAX_CONFIG_GROUPS];
new Float:g_fAccessStuckDelay[MAX_CONFIG_GROUPS];
new String:g_sAccessOverrides[MAX_CONFIG_PROPS][64];

new bool:g_bWithinRestricted[MAX_SERVER_ENTITIES + 1];
new g_iPropTeam[MAX_SERVER_ENTITIES + 1];
new g_iPropState[MAX_SERVER_ENTITIES + 1];
new g_iPropUser[MAX_SERVER_ENTITIES + 1];
new g_iPropType[MAX_SERVER_ENTITIES + 1];
new g_iBaseIndex[MAX_SERVER_ENTITIES + 1];
new g_iPropColor[MAX_SERVER_ENTITIES + 1][6];
new Float:g_fPropDelete[MAX_SERVER_ENTITIES + 1];
new String:g_sPropOwner[MAX_SERVER_ENTITIES + 1][32];
new Handle:g_hPropPhase[MAX_SERVER_ENTITIES + 1] = { INVALID_HANDLE, ... };
new Handle:g_hPropDelete[MAX_SERVER_ENTITIES + 1] = { INVALID_HANDLE, ... };

new g_Access[MAXPLAYERS + 1][Access];
new g_iCurrentTeam[MAXPLAYERS + 1];
new g_iCurrentClass[MAXPLAYERS + 1];
new g_iLastTeam[MAXPLAYERS + 1];
new g_iPlayerTeleports[MAXPLAYERS + 1];
new g_iPlayerDeletes[MAXPLAYERS + 1];
new g_iPlayerProps[MAXPLAYERS + 1];
new g_iPlayerColors[MAXPLAYERS + 1];
new g_iPlayerControl[MAXPLAYERS + 1] = { -1, ... };
new g_iPlayerRotation[MAXPLAYERS + 1];
new g_iPlayerPosition[MAXPLAYERS + 1];
new g_iPlayerColor[MAXPLAYERS + 1];
new g_iPlayerCustom[MAXPLAYERS + 1][3];
new g_iPlayerGimp[MAXPLAYERS + 1];
new g_iPlayerPrevious[MAXPLAYERS + 1];
new g_iLastDrawZone[MAXPLAYERS + 1] = { -1, ... };
new g_iLastDrawTime[MAXPLAYERS + 1];
new g_iConfigNewbie[MAXPLAYERS + 1];
new bool:g_bPlayerControl[MAXPLAYERS + 1];
new bool:g_bPlayerCrouching[MAXPLAYERS + 1];
new bool:g_bToggleCrouching[MAXPLAYERS + 1];
new bool:g_bResetCrouching[MAXPLAYERS + 1];
new bool:g_bTeleporting[MAXPLAYERS + 1];
new bool:g_bTeleported[MAXPLAYERS + 1];
new bool:g_bAfk[MAXPLAYERS + 1];
new bool:g_bCookiesLoaded[MAXPLAYERS + 1];
new bool:g_bAccessLoaded[MAXPLAYERS + 1];
new bool:g_bReturning[MAXPLAYERS + 1];
new bool:g_bThirdPerson[MAXPLAYERS + 1];
new bool:g_bFlying[MAXPLAYERS + 1];
new bool:g_bFlyingPaused[MAXPLAYERS + 1];
new bool:g_bAlive[MAXPLAYERS + 1];
new bool:g_bReady[MAXPLAYERS + 1];
new bool:g_bResetSpeed[MAXPLAYERS + 1];
new bool:g_bResetGravity[MAXPLAYERS + 1];
new bool:g_bCustomToggle[MAXPLAYERS + 1][3];
new bool:g_bLockedAxis[MAXPLAYERS + 1][3];
new bool:g_bActivity[MAXPLAYERS + 1];
new bool:g_bCustomKnife[MAXPLAYERS + 1];
new String:g_sAuthString[MAXPLAYERS + 1][48];
new String:g_sName[MAXPLAYERS + 1][32];
new Float:g_fAfkRemaining[MAXPLAYERS + 1];
new Float:g_fTeleRemaining[MAXPLAYERS + 1];
new Float:g_fConfigDistance[MAXPLAYERS + 1];
new Float:g_fConfigAxis[MAXPLAYERS + 1][3];
new Handle:g_hArray_PlayerProps[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };
new Handle:g_hTimer_TeleportPlayer[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };
new Handle:g_hTimer_Control[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };
new Handle:g_hTimer_RespawnPlayer[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };
new Handle:g_hTimer_AfkCheck[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };
new Handle:g_hTimer_ExpireGimp[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };
new g_iZoneEditor[MAXPLAYERS+1][MapZoneEditor];

new bool:g_bCurrentSave[MAXPLAYERS + 1];
new Handle:g_hTimer_CurrentSave[MAXPLAYERS + 1];
new Float:g_fCurrentSavePos[MAXPLAYERS + 1][3];
new g_iPlayerBaseMenu[MAXPLAYERS + 1] = { -1, ... };
new g_iPlayerBaseQuery[MAXPLAYERS + 1] = { 0, ... };
new g_iPlayerBaseLoading[MAXPLAYERS + 1] = { 0, ... };
new g_iPlayerBaseFailed[MAXPLAYERS + 1];
new g_iPlayerBase[MAXPLAYERS + 1][7];
new g_iPlayerBaseCount[MAXPLAYERS + 1][7];
new g_bPlayerBaseSpawned[MAXPLAYERS + 1] = { false, ... };
new g_iPlayerBaseCurrent[MAXPLAYERS + 1] = { -1, ... };
new Float:g_fPlayerBasePosition[MAXPLAYERS + 1][3];

new Handle:g_hCvar[CVAR_COUNT] = { INVALID_HANDLE, ... };
new Handle:g_hTimer_Update = INVALID_HANDLE;
new Handle:g_hTrie_CfgDefinedCmds = INVALID_HANDLE;
new Handle:g_hTrie_RestrictIndex = INVALID_HANDLE;
new Handle:g_hArray_RedPlayers = INVALID_HANDLE;
new Handle:g_hArray_BluePlayers = INVALID_HANDLE;
new Handle:g_hArray_WallEntity = INVALID_HANDLE;
new Handle:g_hTrie_CfgWalls = INVALID_HANDLE;
new Handle:g_hArrayPropData = INVALID_HANDLE;
new Handle:g_hKvPlayerData = INVALID_HANDLE;
new Handle:g_hSql_Database = INVALID_HANDLE;
new Handle:g_hWeaponRestrict = INVALID_HANDLE;
new Handle:g_hLimitTeams = INVALID_HANDLE;
new Handle:g_hIgnoreRound = INVALID_HANDLE;
new Handle:g_hRoundRestart = INVALID_HANDLE;
new Handle:g_hServerTags = INVALID_HANDLE;
new Handle:g_cCookieVersion = INVALID_HANDLE;
new Handle:g_cCookieGimp = INVALID_HANDLE;
new Handle:g_cCookieRotation = INVALID_HANDLE;
new Handle:g_cCookiePosition = INVALID_HANDLE;
new Handle:g_cCookieColor = INVALID_HANDLE;
new Handle:g_cCookieDistance = INVALID_HANDLE;
new Handle:g_cCookieCustom = INVALID_HANDLE;
new Handle:g_cCookieControl = INVALID_HANDLE;
new Handle:g_cCookieNewbie = INVALID_HANDLE;
new Handle:g_hForwardPhaseChange = INVALID_HANDLE;
new Handle:g_hArray_RestrictDefines = INVALID_HANDLE;
new Handle:g_hArray_CvarProtected = INVALID_HANDLE;
new Handle:g_hArray_CvarOriginal = INVALID_HANDLE;
new Handle:g_hArray_CvarValues = INVALID_HANDLE;
new Handle:g_hArray_CvarHandles = INVALID_HANDLE;

new bool:g_bGrabBlock;
new bool:g_bAfkSpecKick;
new bool:g_bAfkAutoSpec;
new bool:g_bPersistentRounds;
new bool:g_bAfkEnable;
new bool:g_bAfkReturn;
new bool:g_bAfkAutoKick;
new bool:g_bMaintainSize;
new bool:g_bMaintainSpawns;
new bool:g_bReadyInProgress;
new bool:g_bEnabled;
new bool:g_bLateLoad;
new bool:g_bEnding;
new bool:g_bDissolve;
new bool:g_bLegacyPhaseFighting;
new bool:g_bCrouchSpeed;
new bool:g_bSpawningIgnore;
new bool:g_bBaseColors;
new bool:g_bGlobalOffensive;
new bool:g_bPersistentColors;
new bool:g_bSuddenDeath;
new bool:g_bNotifyNewbies;
new bool:g_bLoadedRestrictions;
new bool:g_bCloseMenus;
new bool:g_bLateQuery;
new bool:g_bRedAccess;
new bool:g_bBlueAccess;
new bool:g_bZoneControl;
new bool:g_bAdvancingTeam;
new bool:g_bPluginExplosives;
new bool:g_bSql;
new bool:g_bMapDataLoaded;
new bool:g_bDisableConsoleChat;
new bool:g_bDatabaseFound;

new g_iCurrentTime;
new g_iAdvancingTeam;
new g_iCfg_TotalAccess;
new g_iNumProps;
new g_iNumColors;
new g_iCfg_TotalRotations;
new g_iCfg_DefaultRotation;
new g_iCfg_TotalPositions;
new g_iCfg_DefaultPosition;
new g_iNumModes;
new g_iCfg_TotalDurations;
new g_iDebugMode;
new g_iFlashDuration;
new g_iFlashAlpha;
new g_iMaximumEntities;
new g_iCurEntities;
new g_iCurrentRound;
new g_iLastScramble;
new g_iLimitTeams;
new g_iScrambleRounds;
new g_iReadyMinimum;
new g_iBuildDuration;
new g_iWarDuration;
new g_iSuddenDuration;
new g_iNotifyPhaseSoundsEnd;
new g_iOwnerEntity;
new g_iReadyWait;
new g_iWallEntities;
new g_iRedTeleports[MAX_SPAWN_POINTS];
new g_iBlueTeleports[MAX_SPAWN_POINTS];
new g_iBeamSprite;
new g_iHaloSprite;
new g_iPersistentColors[6] = { 255, 255, 255, 255, 0, 0 };
new g_iBaseColors[6] = { 255, 255, 255, 255, 0, 0 };
new g_iPropColoringTerrorist[4];
new g_iPropColoringCounter[4];
new g_iPropColoringSpec[4];
new g_iReadyDelay;
new g_iReadyCountdown;
new g_iDisableRadar;
new g_iDisableCrouching;
new g_iReadyNeeded;
new g_iReadyCurrent;
new g_iReadyTotal;
new g_iStuckBeacon;
new g_iDeleteNotify;
new g_iGimpDefault;
new g_iAlwaysBuyzone;
new g_iInfiniteGrenades;
new g_iNotifyPhaseSoundsBegin;
new g_iNotifyPhaseChange;
new g_iCurrentDisable;
new g_iDisableSlowing;
new g_iDisableBreaking;
new g_iDisableThirdPerson;
new g_iDisableFlying;
new g_iWarDisable;
new g_iSuddenDisable;
new g_iUniqueProp;
new g_iNumSeconds;
new g_iPlayersRed;
new g_iPlayersBlue;
new g_iPointsRed;
new g_iPointsBlue;
new g_iNumRedSpawns;
new g_iNumBlueSpawns;
new g_iSpriteRed;
new g_iSpriteBlue;
new g_iPhase;
new g_iMyWeapons;
new g_iCurrentMode;
new g_iDisableSuicide;
new g_iDisableFalling;
new g_iDisableRadio;
new g_iDisableDrowning;
new g_iBuildDisable;
new g_iLegacyDisable;
new g_iRestrictWeapon;
new g_iReadyPhase;
new g_iGlowSprite;
new g_iFlashSprite;
new g_iLegacyDuration;
new g_iSqlLoadStep;
new g_iMapZone[64][MapZone];
new g_iTotalZones;
new g_iNotifyFrequency;
new Float:g_fProximityDelay;
new Float:g_fPhaseDelay;
new Float:g_fGrabMinimum;
new Float:g_fGrabMaximum;
new Float:g_fGrabInterval;
new Float:g_fAfkForceSpecDelay;
new Float:g_fAfkSpecKickDelay;
new Float:g_fAfkDelay;
new Float:g_fAfkAutoDelay;
new Float:g_fReadyPercent;
new Float:g_fGrabDistance;
new Float:g_fGrabUpdate;
new Float:g_fRoundRestart;
new Float:g_fRedTeleports[MAX_SPAWN_POINTS][3];
new Float:g_fBlueTeleports[MAX_SPAWN_POINTS][3];
new Float:g_fReadyAlive;
new Float:g_fBaseDistance;
new Float:g_fDeleteDelay;
new Float:g_fFallDamage;
new Float:g_fZeroVector[3];
new String:g_sPrefixSelect[16];
new String:g_sPrefixEmpty[16];
new String:g_sNotifyPhaseSoundsEnd[MAX_PHASE_SOUNDS][PLATFORM_MAX_PATH];
new String:g_sCurrentMap[64];
new String:g_sDissolve[8];
new String:g_sTitle[128];
new String:g_sHelp[128];
new String:g_sNotifyPhaseSoundsBegin[MAX_PHASE_SOUNDS][PLATFORM_MAX_PATH];
new String:g_sModeWeapon[32];
new String:g_sDatabase[32];
new String:g_sBaseNames[7][32];
new String:g_sWallData[256];
new String:g_sPluginLog[PLATFORM_MAX_PATH];

public Plugin:myinfo =
{
	name = "BuildWars (v3)",
	author = "Panduh (AlliedMods: thetwistedpanda)",
	description = "Gameplay modification where teams must build their own defenses then attack the opposing team.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegPluginLibrary("buildwars");
	CreateNative("BuildWars_GetEntityState", Native_GetEntityState);
	CreateNative("BuildWars_GetPropTeam", Native_GetPropTeam);
	CreateNative("BuildWars_GetPropOwner", Native_GetPropOwner);
	CreateNative("BuildWars_GetBlockedZone", Native_GetBlockedZone);
	CreateNative("BuildWars_GetCurrentZone", Native_GetCurrentZone);
	CreateNative("BuildWars_GetAdvanceTeam", Native_GetAdvanceTeam);

	g_bLateLoad = g_bLateQuery = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	decl String:sBuffer[32], String:sSounds[2048], String:sColors[6][4];
	GetGameFolderName(sBuffer, sizeof(sBuffer));
	g_bGlobalOffensive = StrEqual(sBuffer, "csgo", false);

	LoadTranslations("common.phrases");
	if(g_bGlobalOffensive)
	{
		LoadTranslations("buildwars.csgo.phrases");
		AutoExecConfig_SetFile("buildwars.csgo");
	}
	else
	{
		LoadTranslations("buildwars.css.phrases");
		AutoExecConfig_SetFile("buildwars.css");
	}

	CreateConVar("buildwars_version", PLUGIN_VERSION, "BuildWars: Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_CHEAT|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_hCvar[cPluginEnabled] = AutoExecConfig_CreateConVar("buildwars_enable", "1", "Plugin Status (0 = Disabled, 1 = Enabled)", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bEnabled = GetConVarBool(g_hCvar[cPluginEnabled]);

	g_hCvar[cPluginDebug] = AutoExecConfig_CreateConVar("buildwars_debug", "0", "Debugging Status (0 = Normal, 1 = Debug, 2 = Build, 3 = Immitate)", FCVAR_NONE, true, 0.0, true, 3.0);
	g_iDebugMode = GetConVarInt(g_hCvar[cPluginDebug]);

	g_hCvar[cPluginDatabase] = AutoExecConfig_CreateConVar("buildwars_database", "buildwars", "The entry within databases.cfg to use for BuildWars.", FCVAR_NONE);
	GetConVarString(g_hCvar[cPluginDatabase], g_sDatabase, sizeof(g_sDatabase));

	g_hCvar[cMaximumEntities] = AutoExecConfig_CreateConVar("buildwars_maximum_entities", "1900", "Prevents entities from being created by the plugin if at least this many have been spawned in-game.", FCVAR_NONE, true, 0.0, true, 2048.0);
	g_iMaximumEntities = GetConVarInt(g_hCvar[cMaximumEntities]);

	g_hCvar[cNotifyFrequency] = AutoExecConfig_CreateConVar("buildwars_notify_frequency", "30", "How frequently notifications will be sent if buildwars_notify_mode is set to 2 for CS:GO support.", FCVAR_NONE, true, 0.0);
	g_iNotifyFrequency = GetConVarInt(g_hCvar[cNotifyFrequency]);

	g_hCvar[cNotifyPhaseChange] = AutoExecConfig_CreateConVar("buildwars_notify_phase", "5", "The number of seconds prior to the end of a phase that messages begin to be printed to chat.", FCVAR_NONE, true, 0.0);
	g_iNotifyPhaseChange = GetConVarInt(g_hCvar[cNotifyPhaseChange]);

	g_hCvar[cNotifyPhaseEndSounds] = AutoExecConfig_CreateConVar("buildwars_notify_phase_sounds_end", "npc/overwatch/radiovoice/one.wav, npc/overwatch/radiovoice/two.wav, npc/overwatch/radiovoice/three.wav, npc/overwatch/radiovoice/four.wav, npc/overwatch/radiovoice/five.wav", "(CS:S Only) Sequential sounds that play prior to the end of a phase, with the first index playing 1 second prior to wall falling. Use `?` to skip a sound declaration for that second. Separate multiple sounds with `, `.", FCVAR_NONE);
	GetConVarString(g_hCvar[cNotifyPhaseEndSounds], sSounds, sizeof(sSounds));
	g_iNotifyPhaseSoundsEnd = ExplodeString(sSounds, ", ", g_sNotifyPhaseSoundsEnd, sizeof(g_sNotifyPhaseSoundsEnd), sizeof(g_sNotifyPhaseSoundsEnd[]));

	g_hCvar[cNotifyPhaseStartSounds] = AutoExecConfig_CreateConVar("buildwars_notify_phase_sounds_begin", "npc/attack_helicopter/aheli_damaged_alarm1.wav", "(CS:S Only) Sequential sounds that play from the beginning of a new phase, with the first index playing when the wall falls. Use `?` to skip a sound declaration for that second. Separate multiple sounds with `, `.", FCVAR_NONE);
	GetConVarString(g_hCvar[cNotifyPhaseStartSounds], sSounds, sizeof(sSounds));
	g_iNotifyPhaseSoundsBegin = ExplodeString(sSounds, ", ", g_sNotifyPhaseSoundsBegin, sizeof(g_sNotifyPhaseSoundsBegin), sizeof(g_sNotifyPhaseSoundsBegin[]));

	g_hCvar[cDisableRadio] = AutoExecConfig_CreateConVar("buildwars_disable_radio", "15", "The phases that clients will not be allowed to issue radio commands. Add desired phases together. (0 = Always Allowed, 1 = Legacy, 2 = Build, 4 = War, 8 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 15.0);
	g_iDisableRadio = GetConVarInt(g_hCvar[cDisableRadio]);

	g_hCvar[cDisableSuicide] = AutoExecConfig_CreateConVar("buildwars_disable_suicide", "15", "The phases that clients will not be allowed to suicide. Add desired phases together. (0 = Always Allowed, 1 = Legacy, 2 = Build, 4 = War, 8 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 15.0);
	g_iDisableSuicide = GetConVarInt(g_hCvar[cDisableSuicide]);

	g_hCvar[cDisableFalling] = AutoExecConfig_CreateConVar("buildwars_disable_falling", "3", "The phases that clients will not take fall damage. Add desired phases together. (0 = Always Allowed, 1 = Legacy, 2 = Build, 4 = War, 8 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 15.0);
	g_iDisableFalling = GetConVarInt(g_hCvar[cDisableFalling]);

	g_hCvar[cDisableDrowning] = AutoExecConfig_CreateConVar("buildwars_disable_drowning", "7", "The phases that clients will not take drowning damage. Add desired phases together. (0 = Always Allowed, 1 = Legacy, 2 = Build, 4 = War, 8 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 15.0);
	g_iDisableDrowning = GetConVarInt(g_hCvar[cDisableDrowning]);

	g_hCvar[cDisableSlowing] = AutoExecConfig_CreateConVar("buildwars_disable_slowing", "15", "The phases that clients will not slow down after taking damage. Add desired phases together. (0 = Always Allowed, 1 = Legacy, 2 = Build, 4 = War, 8 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 15.0);
	g_iDisableSlowing = GetConVarInt(g_hCvar[cDisableSlowing]);

	g_hCvar[cDisableCrouching] = AutoExecConfig_CreateConVar("buildwars_disable_crouching", "3", "The phases that clients will not be allowed to crouch. Add desired phases together. (0 = Always Allowed, 1 = Legacy, 2 = Build, 4 = War, 8 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 15.0);
	g_iDisableCrouching = GetConVarInt(g_hCvar[cDisableCrouching]);

	g_hCvar[cDisableBreaking] = AutoExecConfig_CreateConVar("buildwars_disable_breaking", "3", "The phases that clients will not be allowed to break func_breakable entities. Add desired phases together. (0 = Always Allowed, 1 = Legacy, 2 = Build, 4 = War, 8 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 15.0);
	g_iDisableBreaking = GetConVarInt(g_hCvar[cDisableBreaking]);

	g_hCvar[cDisableThird] = AutoExecConfig_CreateConVar("buildwars_disable_thirdperson", "12", "The phases that clients will not be allowed to use third person mode. Add desired phases together. (0 = Always Allowed, 1 = Legacy, 2 = Build, 4 = War, 8 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 15.0);
	g_iDisableThirdPerson = GetConVarInt(g_hCvar[cDisableThird]);

	g_hCvar[cDisableFlying] = AutoExecConfig_CreateConVar("buildwars_disable_flying", "12", "The phases that clients will not be allowed to use flying mode. Add desired phases together. (0 = Always Allowed, 1 = Legacy, 2 = Build, 4 = War, 8 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 15.0);
	g_iDisableFlying = GetConVarInt(g_hCvar[cDisableFlying]);

	g_hCvar[cDisableRadar] = AutoExecConfig_CreateConVar("buildwars_disable_radar", "0", "The phases that clients will not be allowed to use their radar. Add desired phases together. (0 = Always Allowed, 1 = Legacy, 2 = Build, 4 = War, 8 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 15.0);
	g_iDisableRadar = GetConVarInt(g_hCvar[cDisableRadar]);

	g_hCvar[cDurationLegacy] = AutoExecConfig_CreateConVar("buildwars_duration_legacy", "300", "The number of seconds, corresponding to when the dividing wall falls, that clients are allowed to build. A value of 0 will prevent the combat phase from occuring.", FCVAR_NONE, true, 0.0);
	g_iLegacyDuration = GetConVarInt(g_hCvar[cDurationLegacy]);

	g_hCvar[cDurationBuild] = AutoExecConfig_CreateConVar("buildwars_duration_build", "240", "The number of seconds that clients are allowed to build.", FCVAR_NONE, true, 0.0);
	g_iBuildDuration = GetConVarInt(g_hCvar[cDurationBuild]);

	g_hCvar[cDurationWar] = AutoExecConfig_CreateConVar("buildwars_duration_war", "180", "The number of seconds that clients are allowed to combat. A value of 0 will result in the war phase lasting until one team is defeated.", FCVAR_NONE, true, 0.0);
	g_iWarDuration = GetConVarInt(g_hCvar[cDurationWar]);

	g_hCvar[cEnableSudden] = AutoExecConfig_CreateConVar("buildwars_sudden_death", "1", "If enabled, and buildwars_duration_war is non-zero, a Sudden Death mode will activate to encourage the round to complete.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bSuddenDeath = GetConVarBool(g_hCvar[cEnableSudden]);

	g_hCvar[cDisableLegacy] = AutoExecConfig_CreateConVar("buildwars_disable_features_legacy", "0", "Core features that are disabled during the Legacy phase. Refer to `configs/buildwars/buildwars.access.cfg` for valid values.", FCVAR_NONE, true, 0.0);
	g_iLegacyDisable = GetConVarInt(g_hCvar[cDisableLegacy]);

	g_hCvar[cDisableBuild] = AutoExecConfig_CreateConVar("buildwars_disable_features_build", "0", "Core features that are disabled during the Build phase. Refer to `configs/buildwars/buildwars.access.cfg` for valid values.", FCVAR_NONE, true, 0.0);
	g_iBuildDisable = GetConVarInt(g_hCvar[cDisableBuild]);

	g_hCvar[cDisableWar] = AutoExecConfig_CreateConVar("buildwars_disable_features_war", "413", "Core features that are disabled during the War phase. Refer to `configs/buildwars/buildwars.access.cfg` for valid values.", FCVAR_NONE, true, 0.0);
	g_iWarDisable = GetConVarInt(g_hCvar[cDisableWar]);

	g_hCvar[cDisableSudden] = AutoExecConfig_CreateConVar("buildwars_disable_features_sudden", "15359", "Core features that are disabled during Sudden Death. Refer to `configs/buildwars/buildwars.access.cfg` for valid values.", FCVAR_NONE, true, 0.0);
	g_iSuddenDisable = GetConVarInt(g_hCvar[cDisableSudden]);

	g_hCvar[cPropColoringSpec] = AutoExecConfig_CreateConVar("buildwars_prop_coloring_spec", "255 255 255 255", "The default color combination for Spectators when they do not have access to custom colors.", FCVAR_NONE);
	GetConVarString(g_hCvar[cPropColoringSpec], sBuffer, sizeof(sBuffer));
	ExplodeString(sBuffer, " ", sColors, sizeof(sColors), sizeof(sColors[]));
	for(new i = 0; i <= 3; i++)
		g_iPropColoringSpec[i] = StringToInt(sColors[i]);

	g_hCvar[cPropColoringTerrorist] = AutoExecConfig_CreateConVar("buildwars_prop_coloring_red", "255 0 0 255", "The default color combination for Terrorists when they do not have access to custom colors.", FCVAR_NONE);
	GetConVarString(g_hCvar[cPropColoringTerrorist], sBuffer, sizeof(sBuffer));
	ExplodeString(sBuffer, " ", sColors, sizeof(sColors), sizeof(sColors[]));
	for(new i = 0; i <= 3; i++)
		g_iPropColoringTerrorist[i] = StringToInt(sColors[i]);

	g_hCvar[cPropColoringCounter] = AutoExecConfig_CreateConVar("buildwars_prop_coloring_blue", "0 0 255 255", "The default color combination for Counter-Terrorists when they do not have access to custom colors.", FCVAR_NONE);
	GetConVarString(g_hCvar[cPropColoringCounter], sBuffer, sizeof(sBuffer));
	ExplodeString(sBuffer, " ", sColors, sizeof(sColors), sizeof(sColors[]));
	for(new i = 0; i <= 3; i++)
		g_iPropColoringCounter[i] = StringToInt(sColors[i]);

	g_hCvar[cDissolveProps] = AutoExecConfig_CreateConVar("buildwars_dissolve", "3", "(CS:S ONLY) The dissolve effect to be used for removing props. (-1 = Disabled, 0 = Energy, 1 = Light, 2 = Heavy, 3 = Core)", FCVAR_NONE, true, -1.0, true, 3.0);
	GetConVarString(g_hCvar[cDissolveProps], g_sDissolve, sizeof(g_sDissolve));
	g_bDissolve = GetConVarInt(g_hCvar[cDissolveProps]) >= 0 ? true : false;

	g_hCvar[cPhasePropDeleteDelay] = AutoExecConfig_CreateConVar("buildwars_enable_delayed_delete", "12", "The phases that deleting props will be delayed by buildwars_prop_delete_delay seconds. (0 = Always Instant, 1 = Legacy, 2 = Build, 4 = War, 8 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 15.0);
	g_iDeleteNotify = GetConVarInt(g_hCvar[cPhasePropDeleteDelay]);

	g_hCvar[cPhaseStuckBeacon] = AutoExecConfig_CreateConVar("buildwars_enable_teleport_beacon", "12", "The phases that players will be beaconed for if they use the Teleport feature. (0 = Never Beaconed, 1 = Legacy, 2 = Build, 4 = War, 8 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 15.0);
	g_iStuckBeacon = GetConVarInt(g_hCvar[cPhaseStuckBeacon]);

	g_hCvar[cEnableAnywhereBuyzone] = AutoExecConfig_CreateConVar("buildwars_enable_buyzones", "3", "The phases that clients will be able to access the buyzone from anywhere. (0 = Func_Buyzones, 1 = Legacy, 2 = Build, 4 = War, 8 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 15.0);
	g_iAlwaysBuyzone = GetConVarInt(g_hCvar[cEnableAnywhereBuyzone]);

	g_hCvar[cPropDeleteDelay] = AutoExecConfig_CreateConVar("buildwars_prop_delete_delay", "5", "The delay, in seconds, for props marked for deletion during buildwars_delete_notify phases to actually be deleted", FCVAR_NONE, true, 0.0);
	g_fDeleteDelay = GetConVarFloat(g_hCvar[cPropDeleteDelay]);

	g_hCvar[cForceMenusClose] = AutoExecConfig_CreateConVar("buildwars_close_menus", "1", "If enabled, all menus will be closed at the start of the War phase and Sudden Death.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bCloseMenus = GetConVarInt(g_hCvar[cForceMenusClose]) ? true : false;

	g_hCvar[cCanRedAccess] = AutoExecConfig_CreateConVar("buildwars_access_team_red", "1", "Controls whether or not Terrorists have access to any features provided by Build Wars.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bRedAccess = GetConVarInt(g_hCvar[cCanRedAccess]) ? true : false;

	g_hCvar[cCanBlueAccess] = AutoExecConfig_CreateConVar("buildwars_access_team_blue", "1", "Controls whether or not Counter-Terrorists have access to any features provided by Build Wars.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bBlueAccess = GetConVarInt(g_hCvar[cCanBlueAccess]) ? true : false;

	g_hCvar[cControlDistance] = AutoExecConfig_CreateConVar("buildwars_grab_distance", "768", "The maximum distance at which props can be grabbed from. (0 = No Maximum)", FCVAR_NONE, true, 0.0);
	g_fGrabDistance = GetConVarFloat(g_hCvar[cControlDistance]);

	g_hCvar[cControlRefreshRate] = AutoExecConfig_CreateConVar("buildwars_grab_update", "0.1", "The frequency at which grabbed objects will update.", FCVAR_NONE, true, 0.1);
	g_fGrabUpdate = GetConVarFloat(g_hCvar[cControlRefreshRate]);

	g_hCvar[cControlMinDistance] = AutoExecConfig_CreateConVar("buildwars_grab_minimum", "50", "The distance players can decrease their grab distance to.", FCVAR_NONE, true, 0.0);
	g_fGrabMinimum = GetConVarFloat(g_hCvar[cControlMinDistance]);

	g_hCvar[cControlMaxDistance] = AutoExecConfig_CreateConVar("buildwars_grab_maximum", "300", "The distance players can increase their grab distance to.", FCVAR_NONE, true, 0.0);
	g_fGrabMaximum = GetConVarFloat(g_hCvar[cControlMaxDistance]);

	g_hCvar[cControlChangeInterval] = AutoExecConfig_CreateConVar("buildwars_grab_interval", "10", "The interval at which a players grab distance will increase/decrease.", FCVAR_NONE, true, 0.0);
	g_fGrabInterval = GetConVarFloat(g_hCvar[cControlChangeInterval]);

	g_hCvar[cControlNonSolid] = AutoExecConfig_CreateConVar("buildwars_grab_non_solid", "1", "If enabled, controlled props will be given no-block status while they're being controlled", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bGrabBlock = GetConVarInt(g_hCvar[cControlNonSolid]) ? true : false;

	g_hCvar[cIgnoreWinConditions] = AutoExecConfig_CreateConVar("buildwars_spawning_ignore", "0", "If enabled, the plugin will control mp_ignore_round_win_conditions to keep the round from ending prematurely.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bSpawningIgnore = GetConVarInt(g_hCvar[cIgnoreWinConditions]) ? true : false;

	g_hCvar[cPropProximityFlagDelay] = AutoExecConfig_CreateConVar("buildwars_proximity_delay", "5.0", "The number of seconds for a proximity flagged prop to lose its no-block state. (0 = Disabled)", FCVAR_NONE, true, 0.0);
	g_fProximityDelay = GetConVarFloat(g_hCvar[cPropProximityFlagDelay]);

	g_hCvar[cPropPhaseFlagDelay] = AutoExecConfig_CreateConVar("buildwars_phase_delay", "5.0", "The number of seconds for a phased prop to return to normal. (0 = Disabled)", FCVAR_NONE, true, 0.0);
	g_fPhaseDelay = GetConVarFloat(g_hCvar[cPropPhaseFlagDelay]);

	g_hCvar[cPhaseReadyAllow] = AutoExecConfig_CreateConVar("buildwars_ready_enable", "7", "The phases in which players will be able to type \"!ready\" to end the current phase early. (0 = Always Allowed, 1 = Legacy, 2 = Build, 4 = War, 8 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 15.0);
	g_iReadyPhase = GetConVarInt(g_hCvar[cPhaseReadyAllow]);

	g_hCvar[cReadyBuildPercent] = AutoExecConfig_CreateConVar("buildwars_ready_percent", "0.70", "The percent of players needed to flag \"ready\", used for causing the dividing wall to fall early.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_fReadyPercent = GetConVarFloat(g_hCvar[cReadyBuildPercent]);

	g_hCvar[cReadyWarPercent] = AutoExecConfig_CreateConVar("buildwars_ready_alive", "0.95", "The percent of players needed to flag \"ready\", used for ending the war phase early (and starting Sudden Death)", FCVAR_NONE, true, 0.0, true, 1.0);
	g_fReadyAlive = GetConVarFloat(g_hCvar[cReadyWarPercent]);

	g_hCvar[cReadyChangeDelay] = AutoExecConfig_CreateConVar("buildwars_ready_delay", "5", "The number of seconds to wait before starting the war phase if triggered by ready.", FCVAR_NONE, true, 0.0, true, 60.0);
	g_iReadyDelay = GetConVarInt(g_hCvar[cReadyChangeDelay]);

	g_hCvar[cReadyWaitDelay] = AutoExecConfig_CreateConVar("buildwars_ready_wait", "20", "The number of seconds after the round starts before ready becomes active.", FCVAR_NONE, true, 0.0);
	g_iReadyWait = GetConVarInt(g_hCvar[cReadyWaitDelay]);

	g_hCvar[cReadyMinimumPlayers] = AutoExecConfig_CreateConVar("buildwars_ready_minimum", "2", "The minimum number of players needed before ready becomes active.", FCVAR_NONE, true, 0.0);
	g_iReadyMinimum = GetConVarInt(g_hCvar[cReadyMinimumPlayers]);

	g_hCvar[cMaintainTeamSizes] = AutoExecConfig_CreateConVar("buildwars_maintain_size", "0", "If enabled, team sizes will be checked upon player deaths and round endings to maintain mp_limitteams.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bMaintainSize = GetConVarInt(g_hCvar[cMaintainTeamSizes]) ? true : false;

	g_hCvar[cMaintainTeamSpawns] = AutoExecConfig_CreateConVar("buildwars_maintain_spawns", "1", "If enabled, spawn points will be maintained to ensure that there always (MaxClients / 2) spawns available for each team.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bMaintainSpawns = GetConVarInt(g_hCvar[cMaintainTeamSpawns]) ? true : false;

	g_hCvar[cPersistentProps] = AutoExecConfig_CreateConVar("buildwars_persistent_rounds", "1", "If enabled, player props will remain until the end of the round, allowing ownership to be returned if the player reconnects.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bPersistentRounds = GetConVarInt(g_hCvar[cPersistentProps]) ? true : false;

	g_hCvar[cPersistentPropColors] = AutoExecConfig_CreateConVar("buildwars_persistent_colors", "", "The R G B A Fx Mode combination that player props will be turned if they disconnect during persistent rounds. (\"\" = Disabled, Disable Fx / Mode with -1 for their values.)", FCVAR_NONE);
	GetConVarString(g_hCvar[cPersistentPropColors], sBuffer, sizeof(sBuffer));
	g_bPersistentColors = StrEqual(sBuffer, "") ? false : true;
	if(g_bPersistentColors)
	{
		ExplodeString(sBuffer, " ", sColors, sizeof(sColors), sizeof(sColors[]));
		for(new i = 0; i <= 5; i++)
			g_iPersistentColors[i] = StringToInt(sColors[i]);
	}

	g_hCvar[cScrambleRounds] = AutoExecConfig_CreateConVar("buildwars_scramble_rounds", "0", "The number of rounds required before teams are scrambled.", FCVAR_NONE, true, 0.0);
	g_iScrambleRounds = GetConVarInt(g_hCvar[cScrambleRounds]);

	g_hCvar[cEnableAntiAway] = AutoExecConfig_CreateConVar("buildwars_afk_enable", "1", "If enabled, public players will be checked for afk status at the start of each round.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bAfkEnable = GetConVarInt(g_hCvar[cEnableAntiAway]) ? true : false;

	g_hCvar[cAntiAwayDelay] = AutoExecConfig_CreateConVar("buildwars_afk_delay", "150", "The number of seconds after the start of the round that public players are checked for being afk.", FCVAR_NONE, true, 0.0);
	g_fAfkDelay = GetConVarFloat(g_hCvar[cAntiAwayDelay]);

	g_hCvar[cAntiAwayKick] = AutoExecConfig_CreateConVar("buildwars_afk_auto_kick", "1", "If enabled, public players who are found to be afk are automatically added to a kick query.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bAfkAutoKick = GetConVarInt(g_hCvar[cAntiAwayKick]) ? true : false;

	g_hCvar[cAntiAwayKickDelay] = AutoExecConfig_CreateConVar("buildwars_afk_auto_kick_delay", "150", "The number of seconds after a player is found to be afk that they are removed from the server.", FCVAR_NONE, true, 0.0);
	g_fAfkAutoDelay = GetConVarFloat(g_hCvar[cAntiAwayKickDelay]);

	g_hCvar[cAntiAwayReturn] = AutoExecConfig_CreateConVar("buildwars_afk_return", "1", "If enabled, players who have been marked for afk and thrown into spectate will be able to return at any time up until the build phase ends.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bAfkReturn = GetConVarInt(g_hCvar[cAntiAwayReturn])? true : false;

	g_hCvar[cAntiAwaySpec] = AutoExecConfig_CreateConVar("buildwars_afk_spec_kick", "1", "If enabled, public players who manually join spectate are automatically added to a kick query.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bAfkSpecKick = GetConVarInt(g_hCvar[cAntiAwaySpec]) ? true : false;

	g_hCvar[cAntiAwaySpecDelay] = AutoExecConfig_CreateConVar("buildwars_afk_spec_kick_delay", "300", "The number of seconds after a public player joins spectate that they are removed from the game.", FCVAR_NONE, true, 0.0);
	g_fAfkSpecKickDelay = GetConVarFloat(g_hCvar[cAntiAwaySpecDelay]);

	g_hCvar[cAntiAwayForce] = AutoExecConfig_CreateConVar("buildwars_afk_force_spec", "1", "If enabled, all players are automatically thrown into spectate x seconds after connecting if they have not yet joined a team (to trigger spectator kicking, if non-admin).", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bAfkAutoSpec = GetConVarInt(g_hCvar[cAntiAwayForce])? true : false;

	g_hCvar[cAntiAwayForceDelay] = AutoExecConfig_CreateConVar("buildwars_afk_force_spec_delay", "180", "The number of seconds after a player connects that they are thrown into spectate if not on a team.", FCVAR_NONE, true, 0.0);
	g_fAfkForceSpecDelay = GetConVarFloat(g_hCvar[cAntiAwayForceDelay]);

	g_hCvar[cBaseDistance] = AutoExecConfig_CreateConVar("buildwars_base_distance", "1500", "Props greater than this distance from the origin of the base location will not be saved, to prevent corruption. (0.0 = Disabled)", FCVAR_NONE, true, 0.0);
	g_fBaseDistance = GetConVarFloat(g_hCvar[cBaseDistance]);

	g_hCvar[cBaseDefaultNames] = AutoExecConfig_CreateConVar("buildwars_base_names", "Alpha, Beta, Gamma, Delta, Epsilon, Zeta, Eta", "The names to be assigned to the client bases. Up to 7 bases are supported. Separate values with \", \".", FCVAR_NONE);
	GetConVarString(g_hCvar[cBaseDefaultNames], sSounds, sizeof(sSounds));
	ExplodeString(sSounds, ", ", g_sBaseNames, sizeof(g_sBaseNames), sizeof(g_sBaseNames[]));

	g_hCvar[cBaseDefaultColor] = AutoExecConfig_CreateConVar("buildwars_base_color", "255 255 255 245 0 0", "For base props only, the R G B A Fx Mode combination used in place of the original coloring. (\"\" = Original Coloring)", FCVAR_NONE);
	GetConVarString(g_hCvar[cBaseDefaultColor], sBuffer, sizeof(sBuffer));
	g_bBaseColors = StrEqual(sBuffer, "") ? false : true;
	if(g_bBaseColors)
	{
		ExplodeString(sBuffer, " ", sColors, sizeof(sColors), sizeof(sColors[]));
		for(new i = 0; i <= 5; i++)
			g_iBaseColors[i] = StringToInt(sColors[i]);
	}

	g_hCvar[cDefaultGimpDuration] = AutoExecConfig_CreateConVar("buildwars_gimp_default", "5", "The default number of minutes to gimp a player for if the administrator does not provide a duration.", FCVAR_NONE, true, 0.0);
	g_iGimpDefault = GetConVarInt(g_hCvar[cDefaultGimpDuration]);

	g_hCvar[cModifyFallDamage] = AutoExecConfig_CreateConVar("buildwars_fall_damage", "100.0", "If buildwars_disable_falling is enabled for a specific phase, this is the highest amount of fall damage to ignore. (0.0 = Current Health)", FCVAR_NONE, true, 0.0);
	g_fFallDamage = GetConVarFloat(g_hCvar[cModifyFallDamage]);

	g_hCvar[cNotifyNewPlayers] = AutoExecConfig_CreateConVar("buildwars_notify_newbies", "1.0", "If enabled, new players will receive a basic notice for their first 3 maps on the server.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bNotifyNewbies = GetConVarInt(g_hCvar[cNotifyNewPlayers]) ? true : false;

	g_hCvar[cModifyCrouchSpeed] = AutoExecConfig_CreateConVar("buildwars_crouch_speed", "1", "If enabled, crouched players will move roughly same speed as running players.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bCrouchSpeed = GetConVarInt(g_hCvar[cModifyCrouchSpeed]) ? true : false;

	g_hCvar[cEnableZoneControl] = AutoExecConfig_CreateConVar("buildwars_enable_zone_control", "1", "Enables / Disables the Zone Control feature.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bZoneControl = GetConVarBool(g_hCvar[cEnableZoneControl]);

	g_hCvar[cEnableAdvancingTeam] = AutoExecConfig_CreateConVar("buildwars_enable_advancing_team", "1", "If enabled, teams will swap between which one is encouraged to defend and which one to advance. Also controls Rush Zones.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bAdvancingTeam = GetConVarBool(g_hCvar[cEnableAdvancingTeam]);

	g_hCvar[cDisableConsoleChat] = AutoExecConfig_CreateConVar("buildwars_disable_console_chat", "0", "If enabled, all messages from console will be blocked.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bDisableConsoleChat = GetConVarBool(g_hCvar[cDisableConsoleChat]);

	g_hCvar[cHelpUrl] = AutoExecConfig_CreateConVar("buildwars_help", "", "The page that appears when a user types the help command into chat (\"\" = Disabled)", FCVAR_NONE);
	GetConVarString(g_hCvar[cHelpUrl], g_sHelp, sizeof(g_sHelp));

	g_hCvar[cConvarBounds] = AutoExecConfig_CreateConVar("buildwars_convar_bounds", "mp_buytime,mp_roundtime,mp_roundtime_defuse,mp_roundtime_hostage,mp_timelimit,mp_maxrounds,mp_winlimit,mp_warmuptime", "These ConVars will have their upper and lower bounds removed to allow modification outside normal limits. Separate multiple entries with \",\".", FCVAR_NONE);
	new String:sBoundsBuffer[2048], String:sBoundsExplode[32][128], Float:fBuffer;
	GetConVarString(g_hCvar[cConvarBounds], sBoundsBuffer, sizeof(sBoundsBuffer));

	new iCount = ExplodeString(sBoundsBuffer, ",", sBoundsExplode, sizeof(sBoundsExplode), sizeof(sBoundsExplode[]));
	for(new i = 0; i < iCount; i++)
	{
		new Handle:hConvar = FindConVar(sBoundsExplode[i]);
		if(hConvar != INVALID_HANDLE)
		{
			if(GetConVarBounds(hConvar, ConVarBound_Lower, fBuffer))
				SetConVarBounds(hConvar, ConVarBound_Lower, false);

			if(GetConVarBounds(hConvar, ConVarBound_Upper, fBuffer))
				SetConVarBounds(hConvar, ConVarBound_Upper, false);

			CloseHandle(hConvar);
		}
	}

	if(g_bGlobalOffensive)
	{
		AutoExecConfig(true, "buildwars.csgo");
	}
	else
	{
		AutoExecConfig(true, "buildwars.css");
	}

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	g_bDatabaseFound = SQL_CheckConfig(g_sDatabase);

	for(new i = 0; i < CVAR_COUNT; i++)
		if(g_hCvar[i] != INVALID_HANDLE)
			HookConVarChange(g_hCvar[i], OnSettingsChange);

	g_hLimitTeams = FindConVar("mp_limitteams");
	HookConVarChange(g_hLimitTeams, OnSettingsChange);
	g_iLimitTeams = GetConVarInt(g_hLimitTeams);

	g_hRoundRestart = FindConVar("mp_round_restart_delay");
	HookConVarChange(g_hRoundRestart, OnSettingsChange);
	g_fRoundRestart = GetConVarFloat(g_hRoundRestart);

	g_hIgnoreRound = FindConVar("mp_ignore_round_win_conditions");

	HookEvent("round_start", Event_OnRoundStart, EventHookMode_Pre);
	HookEvent("player_team", Event_OnPlayerTeam, EventHookMode_Pre);
	HookEvent("player_spawn", Event_OnPlayerSpawn, EventHookMode_Pre);
	HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Pre);
	HookEvent("player_changename", Event_OnPlayerName, EventHookMode_Pre);
	HookEvent("player_blind", Event_PlayerBlind, EventHookMode_Post);
	HookEvent("flashbang_detonate", Event_OnFlashExplode, EventHookMode_Pre);
	HookEvent("hegrenade_detonate", Event_OnGrenadeExplode, EventHookMode_Pre);
	HookEvent("smokegrenade_detonate", Event_OnSmokeExplode, EventHookMode_Pre);
	if(g_bGlobalOffensive)
	{
		HookEvent("inspect_weapon", Event_OnInspectWeapon, EventHookMode_Pre);
		HookEvent("molotov_detonate", Event_OnMolotovExplode, EventHookMode_Pre);
		HookEvent("decoy_detonate", Event_OnDecoyExplode, EventHookMode_Pre);
	}

	g_hServerTags = FindConVar("sv_tags");
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
	AddCommandListener(Command_Kill, "kill");
	AddCommandListener(Command_Kill, "explode");
	AddCommandListener(Command_Class, "joinclass");
	AddCommandListener(Command_Join, "jointeam");
	AddCommandListener(Command_Spec, "spectate");
	AddCommandListener(Command_Radio, "coverme");
	AddCommandListener(Command_Radio, "takepoint");
	AddCommandListener(Command_Radio, "holdpos");
	AddCommandListener(Command_Radio, "regroup");
	AddCommandListener(Command_Radio, "followme");
	AddCommandListener(Command_Radio, "takingfire");
	AddCommandListener(Command_Radio, "go");
	AddCommandListener(Command_Radio, "getout");
	AddCommandListener(Command_Radio, "fallback");
	AddCommandListener(Command_Radio, "sticktog");
	AddCommandListener(Command_Radio, "getinpos");
	AddCommandListener(Command_Radio, "stormfront");
	AddCommandListener(Command_Radio, "report");
	AddCommandListener(Command_Radio, "roger");
	AddCommandListener(Command_Radio, "enemyspot");
	AddCommandListener(Command_Radio, "needbackup");
	AddCommandListener(Command_Radio, "sectorclear");
	AddCommandListener(Command_Radio, "inposition");
	AddCommandListener(Command_Radio, "reportingin");
	AddCommandListener(Command_Radio, "negative");
	AddCommandListener(Command_Radio, "enemydown");

	g_hArray_RestrictDefines = CreateArray(5);
	if(g_bGlobalOffensive)
	{
		PushArrayString(g_hArray_RestrictDefines, "awp");
		PushArrayString(g_hArray_RestrictDefines, "hkp2000");
		PushArrayString(g_hArray_RestrictDefines, "p250");
		PushArrayString(g_hArray_RestrictDefines, "ump45");
		PushArrayString(g_hArray_RestrictDefines, "mac10");
		PushArrayString(g_hArray_RestrictDefines, "usp");
		PushArrayString(g_hArray_RestrictDefines, "deagle");
		PushArrayString(g_hArray_RestrictDefines, "negev");
		PushArrayString(g_hArray_RestrictDefines, "m249");
		PushArrayString(g_hArray_RestrictDefines, "galil");
		PushArrayString(g_hArray_RestrictDefines, "galilar");
		PushArrayString(g_hArray_RestrictDefines, "famas");
		PushArrayString(g_hArray_RestrictDefines, "m4a1");
		PushArrayString(g_hArray_RestrictDefines, "sg556");
		PushArrayString(g_hArray_RestrictDefines, "p90");
		PushArrayString(g_hArray_RestrictDefines, "fiveseven");
		PushArrayString(g_hArray_RestrictDefines, "ak47");
		PushArrayString(g_hArray_RestrictDefines, "ssg08");
		PushArrayString(g_hArray_RestrictDefines, "g3sg1");
		PushArrayString(g_hArray_RestrictDefines, "aug");
		PushArrayString(g_hArray_RestrictDefines, "scar17");
		PushArrayString(g_hArray_RestrictDefines, "scar20");
		PushArrayString(g_hArray_RestrictDefines, "mp9");
		PushArrayString(g_hArray_RestrictDefines, "mp7");
		PushArrayString(g_hArray_RestrictDefines, "bizon");
		PushArrayString(g_hArray_RestrictDefines, "glock");
		PushArrayString(g_hArray_RestrictDefines, "tec9");
		PushArrayString(g_hArray_RestrictDefines, "elite");
		PushArrayString(g_hArray_RestrictDefines, "nova");
		PushArrayString(g_hArray_RestrictDefines, "xm1014");
		PushArrayString(g_hArray_RestrictDefines, "sawedoff");
		PushArrayString(g_hArray_RestrictDefines, "mag7");
		PushArrayString(g_hArray_RestrictDefines, "hegrenade");
		PushArrayString(g_hArray_RestrictDefines, "incgrenade");
		PushArrayString(g_hArray_RestrictDefines, "flashbang");
		PushArrayString(g_hArray_RestrictDefines, "smokegrenade");
		PushArrayString(g_hArray_RestrictDefines, "molotov");
		PushArrayString(g_hArray_RestrictDefines, "decoy");
		PushArrayString(g_hArray_RestrictDefines, "taser");
	}
	else
	{
		PushArrayString(g_hArray_RestrictDefines, "glock");
		PushArrayString(g_hArray_RestrictDefines, "usp");
		PushArrayString(g_hArray_RestrictDefines, "p228");
		PushArrayString(g_hArray_RestrictDefines, "deagle");
		PushArrayString(g_hArray_RestrictDefines, "elite");
		PushArrayString(g_hArray_RestrictDefines, "fiveseven");
		PushArrayString(g_hArray_RestrictDefines, "m3");
		PushArrayString(g_hArray_RestrictDefines, "xm1014");
		PushArrayString(g_hArray_RestrictDefines, "galil");
		PushArrayString(g_hArray_RestrictDefines, "ak47");
		PushArrayString(g_hArray_RestrictDefines, "scout");
		PushArrayString(g_hArray_RestrictDefines, "sg552");
		PushArrayString(g_hArray_RestrictDefines, "awp");
		PushArrayString(g_hArray_RestrictDefines, "g3sg1");
		PushArrayString(g_hArray_RestrictDefines, "famas");
		PushArrayString(g_hArray_RestrictDefines, "m4a1");
		PushArrayString(g_hArray_RestrictDefines, "aug");
		PushArrayString(g_hArray_RestrictDefines, "sg550");
		PushArrayString(g_hArray_RestrictDefines, "mac10");
		PushArrayString(g_hArray_RestrictDefines, "tmp");
		PushArrayString(g_hArray_RestrictDefines, "mp5navy");
		PushArrayString(g_hArray_RestrictDefines, "ump45");
		PushArrayString(g_hArray_RestrictDefines, "p90");
		PushArrayString(g_hArray_RestrictDefines, "m249");
		PushArrayString(g_hArray_RestrictDefines, "flashbang");
		PushArrayString(g_hArray_RestrictDefines, "hegrenade");
		PushArrayString(g_hArray_RestrictDefines, "smokegrenade");
	}

	RegAdminCmd("sm_gimp", 		Command_Gimp, 		ADMFLAG_GENERIC, 	"[BuildWars.Admin] Restricts targeted player from accessing any feature of the mod for x minutes. | Usage: sm_gimp <target> <duration>");
	RegAdminCmd("sm_gimplist", 	Command_List, 		ADMFLAG_GENERIC, 	"[BuildWars.Admin] Displays all players that are currently gimped and their duration. | Usage: sm_gimplist");
	RegAdminCmd("sm_ungimp", 	Command_UnGimp, 	ADMFLAG_GENERIC, 	"[BuildWars.Admin] Removes the gimp status from targeted player. | Usage: sm_ungimp <target>");
	RegAdminCmd("bw_info", 		Command_Info, 		ADMFLAG_GENERIC,	"[BuildWars.Admin] Displays all relevant information of any valid prop_* / func_* iEnt at the admin's crosshairs. | Usage: bw_info");
	RegAdminCmd("bw_color", 	Command_Color, 		ADMFLAG_GENERIC, 	"[BuildWars.Admin] Modifies the color of any valid prop_* / func_* iEnt at the admin's crosshairs. | Usage: bw_color <R=255> <G=255> <B=255> <A=255> | Values 0 - 255 Valid");
	RegAdminCmd("bw_effect", 	Command_Fx, 		ADMFLAG_GENERIC, 	"[BuildWars.Admin] Modifies the RenderFx of any valid  prop_* / func_* iEnt at the admin's crosshairs. | Usage: bw_effect <E=0> | Values 0 - 25 Valid.");
	RegAdminCmd("bw_mode",		Command_Mode, 		ADMFLAG_GENERIC, 	"[BuildWars.Admin] Modifies the RenderMode of any valid  prop_* / func_* iEnt at the admin's crosshairs. | Usage: bw_mode <M=0> | Values 0 - 11 Valid.");
	RegAdminCmd("bw_wall", 		Command_Wall, 		ADMFLAG_CHEATS, 	"[BuildWars.Admin] Use only on the wall between teams, saves the targetname of the wall to the database for non-legacy support.");
	RegAdminCmd("bw_update", 	Command_Update, 	ADMFLAG_RCON,		"[BuildWars.Admin] Command for updating the databases of the plugin; only use when instructed to!");
	RegAdminCmd("bw_setprotected", Command_SetProtected, ADMFLAG_RCON, "[BuildWars.Admin] Sets a protected cvar to the provided value. Protected CVARs cannot be changed outside of this command.");
	RegAdminCmd("bw_remprotected", Command_RemProtected, ADMFLAG_RCON, "[BuildWars.Admin] Removes a proteced cvar from protection array.");
	RegServerCmd("bw_chat", 	Command_Chat, 		"[BuildWars.Server] Command for utilizing the chat translation prefix in a chat message to all players. Usage: bw_chat <string:message>");
	RegServerCmd("bw_hint", 	Command_Hint, 		"[BuildWars.Server] Command for utilizing the hint translation prefix in a hint message to all players. Usage: bw_hint <string:message>");
	RegServerCmd("bw_key", 		Command_Key, 		"[BuildWars.Server] Command for utilizing the key-hint translation prefix in a key hint message to all players. Usage: bw_key <string:message>");
	RegServerCmd("bw_center", 	Command_Center, 	"[BuildWars.Server] Command for utilizing the center translation prefix in a center message to all players. Usage: bw_center <string:message>");

	g_cCookieVersion = 	RegClientCookie("BuildWars.Version",	"The client's version.", 			CookieAccess_Private);
	g_cCookieGimp = 	RegClientCookie("BuildWars.Gimp", 		"The client's gimp duration.", 		CookieAccess_Private);
	g_cCookieNewbie = 	RegClientCookie("BuildWars.Newbie", 	"The client's newbie status.", 		CookieAccess_Private);
	g_cCookieRotation = RegClientCookie("BuildWars.Rotation",	"The client's rotation settings.", 	CookieAccess_Private);
	g_cCookiePosition = RegClientCookie("BuildWars.Position", 	"The client's position settings.", 	CookieAccess_Private);
	g_cCookieColor = 	RegClientCookie("BuildWars.Color", 		"The client's color settings.", 	CookieAccess_Private);
	g_cCookieDistance = RegClientCookie("BuildWars.Distance", 	"The client's distance settings.", 	CookieAccess_Private);
	g_cCookieCustom = 	RegClientCookie("BuildWars.Config", 	"The client's quick key settings.", CookieAccess_Private);
	g_cCookieControl =	RegClientCookie("BuildWars.Control", 	"The client's control settings.", 	CookieAccess_Private);

	g_iMyWeapons = 		FindSendPropOffs("CBaseCombatCharacter", 	"m_hMyWeapons");
	g_iOwnerEntity = 	FindSendPropOffs("CBaseCombatWeapon", 		"m_hOwnerEntity");
	g_iFlashDuration =	FindSendPropOffs("CCSPlayer", 				"m_flFlashDuration");
	g_iFlashAlpha = 	FindSendPropOffs("CCSPlayer", 				"m_flFlashMaxAlpha");

	g_hForwardPhaseChange = CreateGlobalForward("BuildWars_OnPhaseChange", ET_Ignore, Param_Cell);

	g_hKvPlayerData = CreateKeyValues("BuildWars_Persistent");
	g_hArrayPropData = CreateArray();
	g_hArray_WallEntity = CreateArray(67);
	g_hArray_RedPlayers = CreateArray();
	g_hArray_BluePlayers = CreateArray();
	g_hTrie_CfgDefinedCmds = CreateTrie();
	g_hTrie_CfgWalls = CreateTrie();

	if(g_bEnabled)
		ServerCommand("mp_restartgame 1");

	AddCustomTag();
	BuildPath(Path_SM, g_sPluginLog, sizeof(g_sPluginLog), "logs/buildwars.debug.log");
}

public OnPluginEnd()
{
	if(g_bEnabled)
	{
		RemCustomTag();
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				if(g_iDisableRadar)
					ToggleRadar(i, STATE_ENABLE);

				if(g_iDisableThirdPerson && g_bThirdPerson[i])
					ToggleThird(i, STATE_DISABLE);

				if(g_iDisableFlying && g_bFlying[i])
					ToggleFlying(i, STATE_DISABLE);

				Bool_ClearClientProps(i);
				ClearClientControl(i);
				ClearClientTeleport(i);
				ClearClientRespawn(i);
			}
		}

		new iSize = GetArraySize(g_hArrayPropData);
		for(new i = 0; i < iSize; i++)
		{
			new iEnt = GetArrayCell(g_hArrayPropData, i);
			if(IsValidEntity(iEnt) && g_iPropState[iEnt] & STATE_VALID)
				Entity_DeleteProp(iEnt, false);
		}

		decl String:sBuffer[64], Float:fOrigin[3];
		iSize = GetArraySize(g_hArray_WallEntity);
		for(new i = 0; i < iSize; i++)
		{
			new iTmpEnt = GetArrayCell(g_hArray_WallEntity, i, INDEX_ENTITY);

			GetArrayString(g_hArray_WallEntity, i, sBuffer, sizeof(sBuffer));
			DispatchKeyValue(iTmpEnt, "targetname", sBuffer);

			if(GetArrayCell(g_hArray_WallEntity, i, INDEX_MOVED))
			{
				GetEntPropVector(iTmpEnt, Prop_Send, "m_vecOrigin", fOrigin);
				fOrigin[2] += 15000.0;

				TeleportEntity(iTmpEnt, fOrigin, NULL_VECTOR, NULL_VECTOR);
			}
		}

		if(g_iPhase == PHASE_SUDDEN)
		{
			if(g_hWeaponRestrict != INVALID_HANDLE)
			{
				if(g_bRestrictReturn[0][g_iRestrictWeapon])
				{
					g_bRestrictReturn[0][g_iRestrictWeapon] = false;
					SetConVarInt(g_hRestrictCvar[0][g_iRestrictWeapon], g_iRestrictOriginal[0][g_iRestrictWeapon]);
				}

				if(g_bRestrictReturn[1][g_iRestrictWeapon])
				{
					g_bRestrictReturn[1][g_iRestrictWeapon] = false;
					SetConVarInt(g_hRestrictCvar[1][g_iRestrictWeapon], g_iRestrictOriginal[1][g_iRestrictWeapon]);
				}
			}
		}

		ServerCommand("mp_restartgame 1");
	}
}

public OnAllPluginsLoaded()
{
	if(g_bEnabled)
	{
		g_bPluginExplosives = LibraryExists("buildwars.explosives");
		if(!g_bLoadedRestrictions)
			Define_Restrictions();
	}
}

public OnLibraryRemoved(const String:name[])
{
	if(StrEqual(name, "buildwars.explosives"))
	{
		g_bPluginExplosives = false;
	}
}

public OnLibraryAdded(const String:name[])
{
	if(StrEqual(name, "buildwars.explosives") && !g_bPluginExplosives)
	{
		g_bPluginExplosives = true;
	}
}

Define_Restrictions()
{
	if(g_hWeaponRestrict == INVALID_HANDLE)
		g_hWeaponRestrict = FindConVar("sm_weaponrestrict_version");

	if(g_hWeaponRestrict != INVALID_HANDLE)
	{
		g_bLoadedRestrictions = true;
		if(g_hTrie_RestrictIndex != INVALID_HANDLE)
			ClearTrie(g_hTrie_RestrictIndex);
		else
			g_hTrie_RestrictIndex = CreateTrie();

		decl String:sWeapon[32], String:sBuffer[32];
		new iSize = GetArraySize(g_hArray_RestrictDefines);
		for(new i = 0; i < iSize; i++)
		{
			GetArrayString(g_hArray_RestrictDefines, i, sWeapon, sizeof(sWeapon));
			SetTrieValue(g_hTrie_RestrictIndex, sWeapon, i);

			Format(sBuffer, sizeof(sBuffer), "sm_restrict_%s_t", sWeapon);

			if(g_hRestrictCvar[0][i] == INVALID_HANDLE)
				g_hRestrictCvar[0][i] = FindConVar(sBuffer);

			if(g_hRestrictCvar[0][i] != INVALID_HANDLE)
			{
				g_iRestrictOriginal[0][i] = GetConVarInt(g_hRestrictCvar[0][i]);
				g_bRestrictState[0][i] = (g_iRestrictOriginal[0][i] == -1) ? false : true;
			}
			else
			{
				g_iRestrictOriginal[0][i] = -1;
				g_bRestrictState[0][i] = false;
			}

			Format(sBuffer, sizeof(sBuffer), "sm_restrict_%s_ct", sWeapon);
			if(g_hRestrictCvar[1][i] != INVALID_HANDLE)
			{
				if(g_hRestrictCvar[1][i] == INVALID_HANDLE)
					g_hRestrictCvar[1][i] = FindConVar(sBuffer);

				g_iRestrictOriginal[1][i] = GetConVarInt(g_hRestrictCvar[1][i]);
				g_bRestrictState[1][i] = (g_iRestrictOriginal[1][i] == -1) ? false : true;
			}
			else
			{
				g_iRestrictOriginal[1][i] = -1;
				g_bRestrictState[1][i] = false;
			}
		}
	}
}

public OnMapStart()
{
	g_iCurEntities = 0;
	for(new i = 1; i <= MAX_SERVER_ENTITIES; i++)
		if(IsValidEntity(i))
			g_iCurEntities++;

	if(g_bEnabled)
	{
		GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));

		if(g_bGlobalOffensive)
		{
			g_iBeamSprite = PrecacheModel(SPRITE_CSGO_LASER);
			g_iHaloSprite = PrecacheModel(SPRITE_CSGO_HALO);
			g_iGlowSprite = PrecacheModel(SPRITE_CSGO_BALL);
			g_iFlashSprite = PrecacheModel(SPRITE_CSGO_FLASH);
		}
		else
		{
			g_iSpriteRed = PrecacheModel("sprites/redglow2.vmt", true);
			g_iSpriteBlue = PrecacheModel("sprites/blueglow2.vmt", true);
			g_iBeamSprite = PrecacheModel(SPRITE_CSS_LASER, true);
			g_iHaloSprite = PrecacheModel(SPRITE_CSS_HALO, true);
			g_iGlowSprite = PrecacheModel(SPRITE_CSS_BALL, true);
			g_iFlashSprite = PrecacheModel(SPRITE_CSS_FLASH, true);
		}

		for(new i = 0; i < g_iNotifyPhaseSoundsEnd; i++)
			PrecacheSound(g_sNotifyPhaseSoundsEnd[i], true);

		for(new i = 0; i < g_iNotifyPhaseSoundsBegin; i++)
			PrecacheSound(g_sNotifyPhaseSoundsBegin[i], true);

		Define_Settings();
		Define_Configs();
		Define_Props();
		Define_Colors();
		Define_Modes();

		SetSpawns();
		SetDownloads();

		for(new i = 1; i <= MaxClients; i++)
			if(g_hArray_PlayerProps[i] == INVALID_HANDLE)
				g_hArray_PlayerProps[i] = CreateArray();

		g_iCurrentRound = 0;
		g_iLastScramble = 0;

		for(new i = 0; i < g_iNumProps; i++)
			PrecacheModel(g_Cfg_sPropPaths[i]);

		if(g_bPersistentRounds)
		{
			if(g_hKvPlayerData == INVALID_HANDLE || g_hKvPlayerData != INVALID_HANDLE && CloseHandle(g_hKvPlayerData))
				g_hKvPlayerData = CreateKeyValues("BuildWars_Persistent");

			ClearArray(g_hArrayPropData);
		}

		g_iAdvancingTeam = GetRandomInt(2, 3);
		GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	}
}

public OnMapEnd()
{
	if(g_bEnabled)
	{
		g_iWallEntities = 0;
		g_iPhase = PHASE_LEGACY;
		g_bMapDataLoaded = false;
		ClearArray(g_hArray_WallEntity);
		Format(g_sWallData, sizeof(g_sWallData), "");

		g_bEnding = true;
		Array_Empty(CS_TEAM_T);
		Array_Empty(CS_TEAM_CT);

		if(g_hTimer_Update != INVALID_HANDLE && CloseHandle(g_hTimer_Update))
			g_hTimer_Update = INVALID_HANDLE;

		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				ClearClientControl(i);
				ClearClientTeleport(i);
				ClearClientRespawn(i);

				Bool_ClearClientProps(i, false);
				if(g_bDatabaseFound && g_hSql_Database != INVALID_HANDLE)
				{
					if(g_Access[i][bAccessBase])
					{
						g_iPlayerBaseQuery[i] = 0;
						if(g_bPlayerBaseSpawned[i])
							g_bPlayerBaseSpawned[i] = false;

						if(g_bCurrentSave[i])
						{
							g_bCurrentSave[i] = false;
							if(g_hTimer_CurrentSave[i] != INVALID_HANDLE && CloseHandle(g_hTimer_CurrentSave[i]))
								g_hTimer_CurrentSave[i] = INVALID_HANDLE;
						}
					}
				}
			}
		}

		if(g_bSpawningIgnore)
			SetConVarInt(g_hIgnoreRound, 0);

		if(g_iPhase == PHASE_SUDDEN)
		{
			if(g_hWeaponRestrict != INVALID_HANDLE)
			{
				if(g_bRestrictReturn[0][g_iRestrictWeapon])
				{
					g_bRestrictReturn[0][g_iRestrictWeapon] = false;
					SetConVarInt(g_hRestrictCvar[0][g_iRestrictWeapon], g_iRestrictOriginal[0][g_iRestrictWeapon]);
				}

				if(g_bRestrictReturn[1][g_iRestrictWeapon])
				{
					g_bRestrictReturn[1][g_iRestrictWeapon] = false;
					SetConVarInt(g_hRestrictCvar[1][g_iRestrictWeapon], g_iRestrictOriginal[1][g_iRestrictWeapon]);
				}
			}

			CreateTimer((g_fRoundRestart * 0.1), Timer_ModeExecute, 1, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public OnConfigsExecuted()
{
	if(g_bEnabled)
	{
		if(g_bDatabaseFound && g_hSql_Database == INVALID_HANDLE)
			SQL_TConnect(SQL_Connect_Database, (StrEqual(g_sDatabase, "") || !SQL_CheckConfig(g_sDatabase)) ? "storage-local" : g_sDatabase);
		else
		{
			Define_Walls();

			if(g_bZoneControl)
				Define_Zones();
		}

		Format(g_sTitle, sizeof(g_sTitle), "%T", "menuPluginTitle", LANG_SERVER);
		Format(g_sPrefixSelect, sizeof(g_sPrefixSelect), "%T", "menuOptionActive", LANG_SERVER);
		Format(g_sPrefixEmpty, sizeof(g_sPrefixEmpty), "%T", "menuOptionEmpty", LANG_SERVER);

		if(g_bLateLoad)
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i))
				{
					g_iCurrentTeam[i] = GetClientTeam(i);
					g_bAlive[i] = IsPlayerAlive(i);
					GetClientAuthId(i, AuthId_SteamID64, g_sAuthString[i], sizeof(g_sAuthString[]), true);
					GetClientName(i, g_sName[i], sizeof(g_sName[]));
					ClearClientAccess(i);
					LoadClientAccess(i);

					switch(g_iCurrentTeam[i])
					{
						case CS_TEAM_T:
						{
							Array_Push(i, g_iCurrentTeam[i]);
							g_iCurrentClass[i] = GetRandomInt(1, 4);
						}
						case CS_TEAM_CT:
						{
							Array_Push(i, g_iCurrentTeam[i]);
							g_iCurrentClass[i] = GetRandomInt(5, 8);
						}
					}

					if(!g_bCookiesLoaded[i] && AreClientCookiesCached(i))
						LoadClientCookies(i);

					if(g_Access[i][bAccessBase])
						LoadClientBase(i);

					SDKHook(i, SDKHook_WeaponSwitchPost, Hook_WeaponSwitchPost);
					SDKHook(i, SDKHook_WeaponEquipPost, Hook_WeaponEquipPost);
					SDKHook(i, SDKHook_PostThinkPost, Hook_PostThinkPost);
					SDKHook(i, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
					SDKHook(i, SDKHook_PreThinkPost, Hook_PreThinkPost);
					SDKHook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
				}
			}

			g_bLateLoad = false;
		}

		Define_Convars();
		Define_Restrictions();
	}
}

SaveClientData(client)
{
	new iSize = GetArraySize(g_hArray_PlayerProps[client]);
	for(new i = 0; i < iSize; i++)
	{
		new iEnt = GetArrayCell(g_hArray_PlayerProps[client], i);
		if(IsValidEntity(iEnt))
		{
			PushArrayCell(g_hArrayPropData, iEnt);
			if(g_bPersistentColors)
				SetPropColor(iEnt, g_iPersistentColors);
			if(g_iPropState[iEnt] & STATE_SAVED)
				g_iPropState[iEnt] &= ~STATE_SAVED;
		}
	}
	ClearArray(g_hArray_PlayerProps[client]);

	if(KvJumpToKey(g_hKvPlayerData, g_sAuthString[client], true))
	{
		if(g_iPlayerProps[client] > 0)
		{
			KvSetNum(g_hKvPlayerData, "UserId", GetClientUserId(client));
			KvSetNum(g_hKvPlayerData, "Team", g_iCurrentTeam[client]);
		}

		KvSetNum(g_hKvPlayerData, "Delete", g_iPlayerDeletes[client]);
		KvSetNum(g_hKvPlayerData, "Teleport", g_iPlayerTeleports[client]);
		KvSetNum(g_hKvPlayerData, "Color", g_iPlayerColors[client]);

		if(g_Access[client][bAccessBase])
		{
			if(g_bDatabaseFound && g_hSql_Database != INVALID_HANDLE)
			{
				if(g_Access[client][iTotalBases] == 1)
				{
					if(g_bPlayerBaseSpawned[client])
						KvSetNum(g_hKvPlayerData, "Base", 1);
				}
				else
				{
					if(g_bPlayerBaseSpawned[client])
						KvSetNum(g_hKvPlayerData, "Base", g_iPlayerBaseCurrent[client]);
				}
			}
		}

		KvGoBack(g_hKvPlayerData);
	}
}

LoadClientData(client)
{
	if(!KvGotoFirstSubKey(g_hKvPlayerData))
		return;

	decl String:sBuffer[32];
	do
	{
		KvGetSectionName(g_hKvPlayerData, sBuffer, sizeof(sBuffer));
		if(StrEqual(sBuffer, g_sAuthString[client]))
		{
			new _iUserId = KvGetNum(g_hKvPlayerData, "UserId", 0);
			g_iLastTeam[client] = KvGetNum(g_hKvPlayerData, "Team", 0);

			g_iPlayerDeletes[client] = KvGetNum(g_hKvPlayerData, "Delete", 0);
			g_iPlayerTeleports[client] = KvGetNum(g_hKvPlayerData, "Teleport", 0);
			g_iPlayerColors[client] = KvGetNum(g_hKvPlayerData, "Color", 0);

			if(g_Access[client][bAccessBase])
			{
				if(g_bDatabaseFound && g_hSql_Database != INVALID_HANDLE)
				{
					if(g_Access[client][iTotalBases] == 1)
						g_bPlayerBaseSpawned[client] = KvGetNum(g_hKvPlayerData, "Base", -1) != -1 ? true : false;
					else
					{
						g_iPlayerBaseCurrent[client] = KvGetNum(g_hKvPlayerData, "Base", -1);
						g_bPlayerBaseSpawned[client] = g_iPlayerBaseCurrent[client] != -1 ? true : false;
					}
				}
			}

			if(_iUserId)
			{
				new _iStart = GetArraySize(g_hArrayPropData);
				if(_iStart)
				{
					_iStart -= 1;
					new _iCurrent = GetClientUserId(client);
					for(new i = _iStart; i >= 0; i--)
					{
						new iEnt = GetArrayCell(g_hArrayPropData, i);
						if(g_iPropState[iEnt] & STATE_VALID && g_iPropUser[iEnt] == _iUserId)
						{
							RemoveFromArray(g_hArrayPropData, i);
							g_iPropUser[iEnt] = _iCurrent;
							PushArrayCell(g_hArray_PlayerProps[client], iEnt);

							if(g_bPersistentColors)
								RevertPropColor(iEnt);
						}
					}

					g_iPlayerProps[client] = GetArraySize(g_hArray_PlayerProps[client]);
				}
			}

			KvDeleteThis(g_hKvPlayerData);
		}
	}
	while (KvGotoNextKey(g_hKvPlayerData));
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (buttons & IN_ATTACK2 || g_iCurrentTeam[client] == CS_TEAM_SPECTATOR && buttons & IN_RELOAD)
	{
		if(g_bDatabaseFound && g_hSql_Database != INVALID_HANDLE)
		{
			if (g_iZoneEditor[client][Step] == 1)
			{
				decl Float:vOrigin[3];
				GetClientAbsOrigin(client, vOrigin);
				g_iZoneEditor[client][Point1] = vOrigin;

				DisplayPleaseWaitMenu(client);

				CreateTimer(1.0, ChangeStep, GetClientSerial(client));
				return Plugin_Handled;
			}
			else if (g_iZoneEditor[client][Step] == 2)
			{
				decl Float:vOrigin[3];
				GetClientAbsOrigin(client, vOrigin);
				g_iZoneEditor[client][Point2] = vOrigin;

				g_iZoneEditor[client][Step] = 3;

				DisplaySelectZoneTypeMenu(client);
				return Plugin_Handled;
			}
		}
	}

	if(g_bEnabled)
	{
		if(!g_bEnding)
		{
			if(!g_bActivity[client] && g_bAlive[client] && (buttons & IN_ATTACK || buttons & IN_DUCK || buttons & IN_ATTACK2 || buttons & IN_FORWARD || buttons & IN_BACK || buttons & IN_USE || buttons & IN_MOVERIGHT))
				g_bActivity[client] = true;

			if(buttons & IN_USE)
			{
				if(g_Access[client][bAccessCustom] && g_iPlayerCustom[client][FUNCTION_KEY_USE] && !g_bCustomToggle[client][FUNCTION_KEY_USE])
				{
					g_bCustomToggle[client][FUNCTION_KEY_USE] = true;
					IssueCustomAction(client, g_iPlayerCustom[client][FUNCTION_KEY_USE]);
				}
			}
			else if(g_bCustomToggle[client][FUNCTION_KEY_USE])
				g_bCustomToggle[client][FUNCTION_KEY_USE] = false;

			if(g_bAlive[client])
			{
				if(buttons & IN_ATTACK && g_bCustomKnife[client] && (g_iPhase == PHASE_LEGACY && !g_bLegacyPhaseFighting || g_iPhase == PHASE_BUILD))
				{
					if(g_iZoneEditor[client][Step] == 0 && g_Access[client][bAccessCustom] && g_iPlayerCustom[client][FUNCTION_KEY_LEFT] && !g_bCustomToggle[client][FUNCTION_KEY_LEFT])
					{
						g_bCustomToggle[client][FUNCTION_KEY_LEFT] = true;
						IssueCustomAction(client, g_iPlayerCustom[client][FUNCTION_KEY_LEFT]);
					}
				}
				else if(g_bCustomToggle[client][FUNCTION_KEY_LEFT])
					g_bCustomToggle[client][FUNCTION_KEY_LEFT] = false;

				if(buttons & IN_ATTACK2 && g_bCustomKnife[client] && (g_iPhase == PHASE_LEGACY && !g_bLegacyPhaseFighting || g_iPhase == PHASE_BUILD))
				{
					if(g_iZoneEditor[client][Step] == 0 && g_Access[client][bAccessCustom] && g_iPlayerCustom[client][FUNCTION_KEY_RIGHT] && !g_bCustomToggle[client][FUNCTION_KEY_RIGHT])
					{
						g_bCustomToggle[client][FUNCTION_KEY_RIGHT] = true;
						IssueCustomAction(client, g_iPlayerCustom[client][FUNCTION_KEY_RIGHT]);
					}
				}
				else if(g_bCustomToggle[client][FUNCTION_KEY_RIGHT])
					g_bCustomToggle[client][FUNCTION_KEY_RIGHT] = false;

				if(g_bFlying[client])
				{
					if(buttons & IN_SPEED && !g_bFlyingPaused[client])
					{
						SetEntityMoveType(client, MOVETYPE_NONE);
						TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, g_fZeroVector);
						g_bFlyingPaused[client] = true;
					}
					else if(g_bFlyingPaused[client])
					{
						g_bFlyingPaused[client] = false;
						SetEntityMoveType(client, MOVETYPE_FLY);
					}
				}

				if(buttons & IN_DUCK)
				{
					if(g_iDisableCrouching && g_iDisableCrouching & g_iPhase && !(g_Access[client][bAccessCrouch]))
					{
						PrintHintText(client, "%t%t", "prefixHintMessage", "chatWarningBlockedCrouch");

						buttons &= ~IN_DUCK;
						return Plugin_Changed;
					}

					if(g_bCrouchSpeed && !g_bToggleCrouching[client])
					{
						g_bPlayerCrouching[client] = true;
						g_bToggleCrouching[client] = true;
						SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.5);
					}
				}
				else if(g_bCrouchSpeed)
				{
					g_bResetCrouching[client] = false;
					g_bPlayerCrouching[client] = false;
					if(g_bToggleCrouching[client])
					{
						g_bToggleCrouching[client] = false;
						SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
					}
				}

				if(g_bCrouchSpeed && g_bPlayerCrouching[client])
				{
					if(g_bFlying[client] || !(GetEntityFlags(client) & FL_ONGROUND))
					{
						SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
						g_bResetCrouching[client] = true;
					}
					else if(g_bResetCrouching[client])
					{
						SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.5);
						g_bResetCrouching[client] = false;
					}
				}
			}
		}
	}

	return Plugin_Continue;
}

ToggleThird(client, status)
{
	switch(status)
	{
		case STATE_AUTO:
		{
			if(g_bThirdPerson[client])
			{
				g_bThirdPerson[client] = false;
				SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", -1);
				SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
				SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
				SetEntProp(client, Prop_Send, "m_iFOV", 90);
			}
			else
			{
				g_bThirdPerson[client] = true;
				SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
				SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
				SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
				SetEntProp(client, Prop_Send, "m_iFOV", 120);
			}

		}
		case STATE_DISABLE:
		{
			g_bThirdPerson[client] = false;
			SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
			SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
			SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
			SetEntProp(client, Prop_Send, "m_iFOV", 120);
		}
	}
}

ToggleFlying(client, status)
{
	g_bFlyingPaused[client] = false;

	switch(status)
	{
		case STATE_AUTO:
		{
			if(g_bFlying[client])
			{
				SetEntityMoveType(client, MOVETYPE_WALK);
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, g_fZeroVector);
			}
			else
				SetEntityMoveType(client, MOVETYPE_FLY);

			g_bFlying[client] = !g_bFlying[client];
		}
		case STATE_DISABLE:
		{
			g_bFlying[client] = false;
			SetEntityMoveType(client, MOVETYPE_WALK);
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, g_fZeroVector);
		}
	}
}

IssueCustomAction(client, action)
{
	switch(action)
	{
		case FUNCTION_MAIN_MENU:
			Menu_Main(client);
		case FUNCTION_MODIFY_MENU:
		{
			if(!g_iPlayerGimp[client])
				Menu_Modify(client);
		}
		case FUNCTION_CONTROL_MENU:
		{
			if(!g_iPlayerGimp[client])
				Menu_Control(client);
		}
		case FUNCTION_SPAWN_PROP:
		{
			if(!g_iPlayerGimp[client] && g_iPlayerPrevious[client] != -1 && g_Access[client][bAccessProp])
				SpawnProp(client, 	g_iPlayerPrevious[client]);
		}
		case FUNCTION_CLONE_PROP:
		{
			if(!g_iPlayerGimp[client] && g_iPlayerControl[client] > 0 && g_Access[client][bAccessControl])
				SpawnClone(client, g_iPlayerControl[client]);
		}
		case FUNCTION_DELETE_PROP:
		{
			if(!g_iPlayerGimp[client] && Bool_DeleteAllowed(client, true) && Bool_DeleteValid(client, true) && g_Access[client][bAccessDelete])
				DeleteProp(client);
		}
		case FUNCTION_GRAB_PROP:
		{
			if(!g_iPlayerGimp[client] && g_Access[client][bAccessControl])
			{
				if(g_iPlayerControl[client] > 0)
					ClearClientControl(client);
				else if(Bool_ControlValid(client, true))
				{
					new iEnt = Trace_GetEntity(client, g_fGrabDistance);
					if(Entity_Valid(iEnt))
						IssueGrab(client, iEnt);

					Menu_Control(client);
				}
			}
		}
		case FUNCTION_CHECK_PROP:
		{
			if(!g_iPlayerGimp[client] && g_Access[client][bAccessCheck] && Bool_CheckValid(client, true))
				Action_CheckProp(client);
		}
		case FUNCTION_PHASE_PROP:
		{
			if(!g_iPlayerGimp[client] && g_Access[client][bAccessPhase] && Bool_PhaseValid(client, true))
				Action_PhaseProp(client);
		}
		case FUNCTION_TOGGLE_THIRD:
		{
			if(!g_iPlayerGimp[client] && g_Access[client][bAccessThird])
				ToggleThird(client, STATE_AUTO);
		}
		case FUNCTION_TOGGLE_FLYING:
		{
			if(!g_iPlayerGimp[client] && g_Access[client][bAccessFly])
				ToggleFlying(client, STATE_AUTO);
		}
	}
}

public Action:Timer_PostRoundEnd(Handle:timer, any:reason)
{
	new iSize = GetArraySize(g_hArray_WallEntity);
	if(iSize)
	{
		decl Float:fOrigin[3], String:sBuffer[64];
		for(new i = 0; i < iSize; i++)
		{
			new iTmpEnt = GetArrayCell(g_hArray_WallEntity, i, INDEX_ENTITY);

			GetArrayString(g_hArray_WallEntity, i, sBuffer, sizeof(sBuffer));
			DispatchKeyValue(iTmpEnt, "targetname", sBuffer);
			if(GetArrayCell(g_hArray_WallEntity, i, INDEX_MOVED))
			{
				GetEntPropVector(iTmpEnt, Prop_Send, "m_vecOrigin", fOrigin);
				fOrigin[2] += 15000.0;

				TeleportEntity(iTmpEnt, fOrigin, NULL_VECTOR, NULL_VECTOR);
			}
		}

		g_iWallEntities = 0;
		g_iCurrentDisable = g_iBuildDisable;
		ClearArray(g_hArray_WallEntity);

		FowardPhaseChange(PHASE_BUILD);
	}
	else
	{
		g_bLegacyPhaseFighting = false;
		g_iCurrentDisable = g_iLegacyDisable;

		FowardPhaseChange(PHASE_LEGACY);
	}

	if(g_bMaintainSize || (g_iScrambleRounds && CSRoundEndReason:reason != CSRoundEnd_GameStart))
	{
		if(g_iPlayersRed >= 1 && g_iPlayersBlue >= 1)
		{
			if(g_iScrambleRounds && g_iCurrentRound >= (g_iScrambleRounds + g_iLastScramble))
			{
				g_iLastScramble = g_iCurrentRound;

				new Handle:_hTemp = CreateArray();
				for(new i = 0; i < g_iPlayersRed; i++)
				{
					new client = Array_Grab(CS_TEAM_T, i);
					PushArrayCell(_hTemp, client);
				}
				for(new i = 0; i < g_iPlayersBlue; i++)
				{
					new client = Array_Grab(CS_TEAM_CT, i);
					PushArrayCell(_hTemp, client);
				}
				SortADTArray(_hTemp, Sort_Random, Sort_Integer);

				new bool:_bTemp;
				iSize = ((g_iPlayersRed + g_iPlayersBlue) - 1);
				for(new i = 0; i <= iSize; i++)
				{
					if(i == iSize && g_bAdvancingTeam && g_iPlayersRed == g_iPlayersBlue)
					{
						new client = GetArrayCell(_hTemp, i);
						if(g_iCurrentTeam[client] != g_iAdvancingTeam)
							Switch(client, g_iAdvancingTeam);
					}
					else
					{
						new client = GetArrayCell(_hTemp, i);
						if(_bTemp)
						{
							if(g_iCurrentTeam[client] != CS_TEAM_T)
								Switch(client, CS_TEAM_T);
						}
						else
						{
							if(g_iCurrentTeam[client] != CS_TEAM_CT)
								Switch(client, CS_TEAM_CT);
						}
					}

					_bTemp = !_bTemp;
				}

				CloseHandle(_hTemp);
			}

			if(g_bMaintainSize)
			{
				if(g_iPlayersRed > g_iPlayersBlue)
				{
					new _iDiff = g_iPlayersRed - g_iPlayersBlue;
					if(_iDiff > g_iLimitTeams)
					{
						_iDiff = (GetRandomInt(0, 1)) ? RoundToFloor(float(_iDiff) / 2.0) : RoundToCeil(float(_iDiff) / 2.0);
						for(new i = 1; i <= _iDiff; i++)
							Switch(Array_Grab(CS_TEAM_T, GetRandomInt(0, (g_iPlayersRed - 1))), CS_TEAM_CT);
					}
				}
				else if(g_iPlayersBlue > g_iPlayersRed)
				{
					new _iDiff = g_iPlayersBlue - g_iPlayersRed;
					if(_iDiff > g_iLimitTeams)
					{
						_iDiff = (GetRandomInt(0, 1)) ? RoundToFloor(float(_iDiff) / 2.0) : RoundToCeil(float(_iDiff) / 2.0);
						for(new i = 1; i <= _iDiff; i++)
							Switch(Array_Grab(CS_TEAM_CT, GetRandomInt(0, (g_iPlayersBlue - 1))), CS_TEAM_T);
					}
				}
			}
		}
	}
}

public Action:Timer_CheckSpawn(Handle:timer, any:client)
{
	g_hTimer_RespawnPlayer[client] = INVALID_HANDLE;
	if(!g_bAlive[client] && g_iCurrentTeam[client] >= CS_TEAM_T && g_iCurrentClass[client])
		CS_RespawnPlayer(client);
}

public Action:Timer_DeleteNotify(Handle:timer, any:iEnt)
{
	if(g_bEnding || !IsValidEntity(iEnt))
	{
		g_hPropDelete[iEnt] = INVALID_HANDLE;
		return Plugin_Stop;
	}

	g_fPropDelete[iEnt] += 1.0;
	if(g_fPropDelete[iEnt] >= g_fDeleteDelay)
	{
		g_hPropDelete[iEnt] = INVALID_HANDLE;

		new iOwner = GetClientOfUserId(g_iPropUser[iEnt]);
		if(iOwner && IsClientInGame(iOwner))
			DeleteClientProp(iOwner, iEnt);
		else
			Entity_DeleteProp(iEnt);

		return Plugin_Stop;
	}

	decl Float:fOrigin[3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fOrigin);
	for(new i = 0; i <= 2; i++)
	{
		fOrigin[2] += 10.0;
		TE_SetupBeamRingPoint(fOrigin, 10.0, 350.0, g_iBeamSprite, g_iHaloSprite, 0, 10, 1.0, 25.0, 1.0, {255, 255, 255, 255}, 15, 0);
		TE_SendToAll();
	}

	return Plugin_Continue;
}

IssueGrab(client, iEnt)
{
	new iOwner = GetClientOfUserId(g_iPropUser[iEnt]);

	if(g_Access[client][bAdmin])
	{
		for(new target = 1; target <= MaxClients; target++)
		{
			if(target != client && g_iPlayerControl[target] > 0 && g_iPlayerControl[target] == iEnt)
			{
				if(g_Access[target][bAdmin])
				{
					#if defined _colors_included
					CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserControlPropControlledAlready", g_Cfg_sPropNames[g_iPropType[iEnt]]);
					#else
					PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserControlPropControlledAlready", g_Cfg_sPropNames[g_iPropType[iEnt]]);
					#endif
					return;
				}
				else
				{
					#if defined _colors_included
					CPrintToChat(target, "%t%t", "prefixChatMessage", "chatNotifyUserControlPropUsurped", g_Cfg_sPropNames[g_iPropType[iEnt]]);
					CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserControlPropUsurping", g_Cfg_sPropNames[g_iPropType[iEnt]], g_sName[target]);
					#else
					PrintToChat(target, "%t%t", "prefixChatMessage", "chatNotifyUserControlPropUsurped", g_Cfg_sPropNames[g_iPropType[iEnt]]);
					PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserControlPropUsurping", g_Cfg_sPropNames[g_iPropType[iEnt]], g_sName[target]);
					#endif
					ClearClientControl(target);
				}
			}
		}
	}
	else
	{
		if(iOwner == client)
		{
			for(new target = 1; target <= MaxClients; target++)
			{
				if(target != client && g_iPlayerControl[target] > 0 && g_iPlayerControl[target] == iEnt)
				{
					#if defined _colors_included
					CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserControlPropControlled", g_Cfg_sPropNames[g_iPropType[iEnt]]);
					#else
					PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserControlPropControlled", g_Cfg_sPropNames[g_iPropType[iEnt]]);
					#endif
					return;
				}
			}
		}
		else
		{
			PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserControlPropWarningOwner", g_Cfg_sPropNames[g_iPropType[iEnt]], g_sPropOwner[iEnt]);
			return;
		}
	}

	GetEntPropVector(iEnt, Prop_Data, "m_angRotation", g_fConfigAxis[client]);
	g_fConfigAxis[client] = GetCleanAngles(g_fConfigAxis[client]);
	g_hTimer_Control[client] = CreateTimer(g_fGrabUpdate, Timer_Control, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerControl[client] = iEnt;

	g_iPropState[g_iPlayerControl[client]] |= STATE_GRABBED;
	SetPropColorAlpha(g_iPlayerControl[client], ALPHA_PROP_GRABBED);

	if(g_bGrabBlock)
		SetEntProp(g_iPlayerControl[client], Prop_Send, "m_CollisionGroup", 1);
}

ClearClientControl(client)
{
	if(g_hTimer_Control[client] != INVALID_HANDLE)
		CloseHandle(g_hTimer_Control[client]);

	if(g_iPlayerControl[client] != -1)
	{
		g_iPropState[g_iPlayerControl[client]] &= ~STATE_GRABBED;
		if(IsValidEntity(g_iPlayerControl[client]))
		{
			if(g_bWithinRestricted[g_iPlayerControl[client]])
				Entity_DeleteProp(g_iPlayerControl[client]);
			else
			{
				if(g_bBaseColors && g_iPropState[g_iPlayerControl[client]] & STATE_BASE)
					SetPropColorAlpha(g_iPlayerControl[client], ALPHA_PROP_NORMAL);
				else
					SetPropColorAlpha(g_iPlayerControl[client], g_iBaseColors[3]);

				if(g_bGrabBlock)
					SetEntProp(g_iPlayerControl[client], Prop_Send, "m_CollisionGroup", 0);
			}
		}

		g_iPlayerControl[client] = -1;
	}

	g_hTimer_Control[client] = INVALID_HANDLE;

	for(new i = 0; i <= 2; i++)
	{
		g_fConfigAxis[client][i] = 0.0;
		g_bLockedAxis[client][i] = g_bPlayerControl[client] ? true : false;
	}
}

ClearClientTeleport(client)
{
	if(g_hTimer_TeleportPlayer[client] != INVALID_HANDLE)
		CloseHandle(g_hTimer_TeleportPlayer[client]);

	g_hTimer_TeleportPlayer[client] = INVALID_HANDLE;
	g_bTeleporting[client] = false;
}

ClearClientRespawn(client)
{
	if(g_hTimer_RespawnPlayer[client] != INVALID_HANDLE)
		CloseHandle(g_hTimer_RespawnPlayer[client]);

	g_hTimer_RespawnPlayer[client] = INVALID_HANDLE;
}

ClearClientAfk(client)
{
	if(g_hTimer_AfkCheck[client] != INVALID_HANDLE)
		CloseHandle(g_hTimer_AfkCheck[client]);

	g_hTimer_AfkCheck[client] = INVALID_HANDLE;
	g_bAfk[client] = false;
}

ClearClientGimp(client)
{
	if(g_hTimer_ExpireGimp[client] != INVALID_HANDLE)
		CloseHandle(g_hTimer_ExpireGimp[client]);

	g_hTimer_ExpireGimp[client] = INVALID_HANDLE;
	g_iPlayerGimp[client] = 0;
}

public Action:Timer_Control(Handle:timer, any:client)
{
	if(client <= 0 || !IsClientInGame(client) || g_iPlayerControl[client] <= 0 || !(g_iPropState[g_iPlayerControl[client]] & STATE_VALID))
	{
		g_hTimer_Control[client] = INVALID_HANDLE;
		ClearClientControl(client);

		return Plugin_Stop;
	}

	decl Float:fDirection[3], Float:fPosition[3], Float:fOriginal[3], Float:fAngles[3];
	GetClientEyeAngles(client, fAngles);
	GetClientEyePosition(client, fPosition);
	GetAngleVectors(fAngles, fDirection, NULL_VECTOR, NULL_VECTOR);

	for(new i = 0; i <= 2; i++)
		fPosition[i] += fDirection[i] * g_fConfigDistance[client];

	if(g_Access[client][bAccessMove])
	{
		GetEntPropVector(g_iPlayerControl[client], Prop_Send, "m_vecOrigin", fOriginal);
		for(new i = 0; i <= 2; i++)
			fPosition[i] = g_bLockedAxis[client][i] ? fOriginal[i] : float(RoundToNearest(fPosition[i] / g_Cfg_fDefinedPositions[g_iPlayerPosition[client]])) * g_Cfg_fDefinedPositions[g_iPlayerPosition[client]];
	}

	new iZone = -1;
	if((iZone = GetBlockedZone(fPosition)) != -1)
	{
		g_bWithinRestricted[g_iPlayerControl[client]] = true;
		if(g_iCurrentTime > g_iLastDrawTime[client] || g_iLastDrawZone[client] != iZone)
		{
			g_iLastDrawZone[client] = iZone;
			g_iLastDrawTime[client] = g_iCurrentTime + 5;
			DrawMapZone(iZone, client);
		}

		PrintHintText(client, "%t", "chatWarningProximityControl");
	}
	else
	{
		if(g_bWithinRestricted[g_iPlayerControl[client]])
			g_bWithinRestricted[g_iPlayerControl[client]] = false;

		fPosition = GetCleanVector(fPosition);
		TeleportEntity(g_iPlayerControl[client], fPosition, g_fConfigAxis[client], NULL_VECTOR);
		PrintHintText(client, "%t", "menuEntryControlDetails", g_fConfigAxis[client][0], g_fConfigAxis[client][1], g_fConfigAxis[client][2], fPosition[0], fPosition[1], fPosition[2]);
	}
	return Plugin_Continue;
}

public Action:Timer_PhaseProp(Handle:timer, any:iEnt)
{
	g_hPropPhase[iEnt] = INVALID_HANDLE;

	if(IsValidEntity(iEnt) && !g_bEnding && g_iPropState[iEnt] & STATE_VALID)
	{
		g_iPropState[iEnt] &= ~STATE_PHASE;
		if(g_bBaseColors && g_iPropState[iEnt] & STATE_BASE)
			SetPropColorAlpha(iEnt, ALPHA_PROP_NORMAL);
		else
			SetPropColorAlpha(iEnt, ALPHA_PROP_NORMAL);

		SetEntProp(iEnt, Prop_Send, "m_CollisionGroup", 0);
	}
}

public Action:Timer_Update(Handle:timer)
{
	new bool:bInitial = false;
	if(g_iPlayersRed >= 1 && g_iPlayersBlue >= 1 || (g_iDebugMode == MODE_DEBUG || g_iDebugMode == MODE_IMITATE))
	{
		if(!g_iNumSeconds)
			bInitial = true;
		else if(bInitial)
			bInitial = false;

		g_iNumSeconds++;
		g_iCurrentTime = GetTime();
	}
	else if(g_iNumSeconds)
	{
		g_iNumSeconds = 0;

		if(StrEqual(g_sWallData, "") || !g_iBuildDuration)
		{
			g_bLegacyPhaseFighting = false;
			g_iCurrentDisable = g_iLegacyDisable;

			FowardPhaseChange(PHASE_LEGACY);
		}
		else
		{
			g_iCurrentDisable = g_iBuildDisable;

			FowardPhaseChange(PHASE_BUILD);
		}
	}

	new bool:bNextPhase;
	decl Float:fOrigin[3];
	g_iReadyTotal = g_iReadyCurrent = 0;
	for(new k = 1; k <= MaxClients; k++)
	{
		if(IsClientInGame(k) && CheckTeamAccess(k, g_iCurrentTeam[k]))
		{
			if((!g_iStuckBeacon || g_iStuckBeacon & g_iPhase) && g_bTeleported[k] || g_iPhase == PHASE_SUDDEN && g_iNumSeconds < g_iSuddenDuration)
			{
				if(g_bAlive[k] && g_iCurrentTeam[k] >= CS_TEAM_T)
				{
					GetClientAbsOrigin(k, fOrigin);

					fOrigin[2] += 10.0;
					for(new i = 0; i <= 2; i++)
					{
						fOrigin[2] += 10.0;
						if(g_iCurrentTeam[k] == CS_TEAM_T)
							TE_SetupBeamRingPoint(fOrigin, 10.0, 500.0, g_iBeamSprite, g_iHaloSprite, 0, 10, 1.0, 25.0, 1.0, g_iPropColoringTerrorist, 15, 0);
						else
							TE_SetupBeamRingPoint(fOrigin, 10.0, 500.0, g_iBeamSprite, g_iHaloSprite, 0, 10, 1.0, 25.0, 1.0, g_iPropColoringCounter, 15, 0);
						TE_SendToAll();
					}
				}
			}

			if(g_iWallEntities && g_iReadyPhase & g_iPhase && g_iCurrentTeam[k] >= CS_TEAM_T && (g_iPhase != PHASE_WAR || g_bAlive[k]))
			{
				g_iReadyTotal++;
				if(g_bReady[k])
					g_iReadyCurrent++;
			}
		}
	}

	g_iReadyNeeded = (g_iPhase == PHASE_WAR) ? (RoundToNearest(float(g_iReadyTotal) * g_fReadyAlive)) : (RoundToNearest(float(g_iReadyTotal) * g_fReadyPercent));
	if(g_iReadyNeeded < g_iReadyMinimum)
		g_iReadyNeeded = g_iReadyMinimum;

	switch(g_iPhase)
	{
		case PHASE_LEGACY:
		{
			if(!g_iLegacyDuration)
				return Plugin_Continue;

			if(g_iNumSeconds >= g_iLegacyDuration && !g_bLegacyPhaseFighting)
			{
				g_iNumSeconds = 0;
				g_iCurrentDisable = g_iWarDisable;
				g_bLegacyPhaseFighting = true;
				FowardPhaseChange(PHASE_WAR);

				for(new i = 1; i <= MaxClients; i++)
				{
					if(!IsClientInGame(i))
						continue;

					if(g_bAdvancingTeam)
					{
						if(g_iDebugMode == MODE_BUILD)
							continue;

						if(g_iCurrentTeam[i] == g_iAdvancingTeam)
						{
							#if defined _colors_included
							CPrintToChat(i, "%t%t", "prefixChatMessage", "chatNotifyWarPhaseStartAdvance");
							#else
							PrintToChat(i, "%t%t", "prefixChatMessage", "chatNotifyWarPhaseStartAdvance");
							#endif
						}
						else if(g_iCurrentTeam[i] == GetOppositeTeam(g_iAdvancingTeam))
						{
							#if defined _colors_included
							CPrintToChat(i, "%t%t", "prefixChatMessage", "chatNotifyWarPhaseStartDefend");
							#else
							PrintToChat(i, "%t%t", "prefixChatMessage", "chatNotifyWarPhaseStartDefend");
							#endif
						}
						else
						{
							#if defined _colors_included
							CPrintToChat(i, "%t%t", "prefixChatMessage", "chatNotifyWarPhaseStart");
							#else
							PrintToChat(i, "%t%t", "prefixChatMessage", "chatNotifyWarPhaseStart");
							#endif
						}
					}
					else
					{
						if(g_iDebugMode == MODE_BUILD)
							continue;

						#if defined _colors_included
						CPrintToChat(i, "%t%t", "prefixChatMessage", "chatNotifyWarPhaseStart");
						#else
						PrintToChat(i, "%t%t", "prefixChatMessage", "chatNotifyWarPhaseStart");
						#endif
					}

					if(CheckTeamAccess(i, g_iCurrentTeam[i]))
					{
						if(g_bCloseMenus)
							CancelClientMenu(i, true);

						if(g_iCurrentDisable & DISABLE_CONTROL)
							ClearClientControl(i);

						if(g_iDisableRadar && g_iDisableRadar & g_iPhase && !(g_Access[i][bAccessRadar]))
							ToggleRadar(i, STATE_DISABLE);
						else
							ToggleRadar(i, STATE_ENABLE);

						if(g_iDisableThirdPerson && g_iDisableThirdPerson & g_iPhase && g_bThirdPerson[i])
							ToggleThird(i, STATE_DISABLE);

						if(g_iDisableFlying && g_iDisableFlying & g_iPhase && g_bFlying[i])
							ToggleFlying(i, STATE_DISABLE);
					}
				}
			}
		}
		case PHASE_BUILD:
		{
			if(!g_bReadyInProgress && g_iBuildDuration && g_iNumSeconds >= g_iBuildDuration)
			{
				bNextPhase = true;
			}
			else if(g_bReadyInProgress || g_iWallEntities && g_iReadyPhase & g_iPhase && g_iReadyCurrent >= g_iReadyNeeded && g_iReadyTotal >= g_iReadyMinimum)
			{
				if(!g_iReadyDelay || !g_iReadyCountdown)
				{
					bNextPhase = true;
					g_bReadyInProgress = false;
				}
				else
				{
					if(!g_bReadyInProgress)
					{
						g_bReadyInProgress = true;
						g_iReadyCountdown = g_iReadyDelay;
						#if defined _colors_included
						CPrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyWarPhaseBegin", g_iReadyCountdown);
						#else
						PrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyWarPhaseBegin", g_iReadyCountdown);
						#endif
					}
					else
					{
						g_iReadyCountdown--;
					}
				}
			}

			if(bNextPhase)
			{
				g_iNumSeconds = 0;
				g_iCurrentDisable = g_iWarDisable;
				FowardPhaseChange(PHASE_WAR);

				new iSize = GetArraySize(g_hArray_WallEntity);
				for(new i = 0; i < iSize; i++)
				{
					new iTmpEnt = GetArrayCell(g_hArray_WallEntity, i, INDEX_ENTITY);
					GetEntPropVector(iTmpEnt, Prop_Send, "m_vecOrigin", fOrigin);

					SetArrayCell(g_hArray_WallEntity, i, 1, INDEX_MOVED);
					fOrigin[2] -= 15000.0;
					TeleportEntity(iTmpEnt, fOrigin, NULL_VECTOR, NULL_VECTOR);
				}

				for(new i = 1; i <= MaxClients; i++)
				{
					if(!IsClientInGame(i))
						continue;

					if(g_bAdvancingTeam)
					{
						if(g_iDebugMode == MODE_BUILD)
							continue;

						if(g_iCurrentTeam[i] == g_iAdvancingTeam)
						{
							#if defined _colors_included
							CPrintToChat(i, "%t%t", "prefixChatMessage", "chatNotifyWarPhaseStartAdvance");
							#else
							PrintToChat(i, "%t%t", "prefixChatMessage", "chatNotifyWarPhaseStartAdvance");
							#endif
						}
						else if(g_iCurrentTeam[i] == GetOppositeTeam(g_iAdvancingTeam))
						{
							#if defined _colors_included
							CPrintToChat(i, "%t%t", "prefixChatMessage", "chatNotifyWarPhaseStartDefend");
							#else
							PrintToChat(i, "%t%t", "prefixChatMessage", "chatNotifyWarPhaseStartDefend");
							#endif
						}
						else
						{
							#if defined _colors_included
							CPrintToChat(i, "%t%t", "prefixChatMessage", "chatNotifyWarPhaseStart");
							#else
							PrintToChat(i, "%t%t", "prefixChatMessage", "chatNotifyWarPhaseStart");
							#endif
						}
					}
					else
					{
						if(g_iDebugMode == MODE_BUILD)
							continue;

						#if defined _colors_included
						CPrintToChat(i, "%t%t", "prefixChatMessage", "chatNotifyWarPhaseStart");
						#else
						PrintToChat(i, "%t%t", "prefixChatMessage", "chatNotifyWarPhaseStart");
						#endif
					}

					if(CheckTeamAccess(i, g_iCurrentTeam[i]))
					{
						if(g_iReadyPhase & g_iPhase)
							g_bReady[i] = false;

						if(g_bCloseMenus)
							CancelClientMenu(i, true);

						if(g_iCurrentDisable & DISABLE_CONTROL)
							ClearClientControl(i);

						if(g_iDisableRadar && g_iDisableRadar & g_iPhase && !(g_Access[i][bAccessRadar]))
							ToggleRadar(i, STATE_DISABLE);
						else
							ToggleRadar(i, STATE_ENABLE);

						if(g_iDisableThirdPerson && g_iDisableThirdPerson & g_iPhase && g_bThirdPerson[i])
							ToggleThird(i, STATE_DISABLE);

						if(g_iDisableFlying && g_iDisableFlying & g_iPhase && g_bFlying[i])
							ToggleFlying(i, STATE_DISABLE);
					}
				}

				CreateTimer(0.1, Timer_PrepareProps, _, TIMER_FLAG_NO_MAPCHANGE);
			}

			if(g_iNotifyPhaseSoundsBegin && g_iNumSeconds < g_iNotifyPhaseSoundsBegin)
			{
				if(!g_bGlobalOffensive)
				{
					if(!g_bGlobalOffensive)
					{
						EmitSoundToAll(g_sNotifyPhaseSoundsBegin[g_iNumSeconds], SOUND_FROM_PLAYER, SNDCHAN_VOICE);
					}
				}
			}
		}
		case PHASE_WAR:
		{
			if(!g_bReadyInProgress && g_iWarDuration && g_iNumSeconds >= g_iWarDuration)
			{
				bNextPhase = true;
			}
			else if(g_bReadyInProgress || g_iWallEntities && g_iReadyPhase & g_iPhase && g_iReadyCurrent >= g_iReadyNeeded && g_iReadyTotal >= g_iReadyMinimum)
			{
				if(!g_iReadyDelay || !g_iReadyCountdown)
				{
					bNextPhase = true;
					g_bReadyInProgress = false;
				}
				else
				{
					if(!g_bReadyInProgress)
					{
						g_bReadyInProgress = true;
						g_iReadyCountdown = g_iReadyDelay;

						#if defined _colors_included
						CPrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyDeathPhaseBegin", g_iReadyCountdown);
						#else
						PrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyDeathPhaseBegin", g_iReadyCountdown);
						#endif
					}
					else
					{
						g_iReadyCountdown--;
					}
				}
			}

			if(bNextPhase)
			{
				if(!g_bSuddenDeath)
				{
					if(g_iPointsRed > g_iPointsBlue)
					{
						SetTeamScore(CS_TEAM_T, (GetTeamScore(CS_TEAM_T) + 1));
						CS_TerminateRound(g_fRoundRestart, CSRoundEnd_TerroristWin);
					}
					else if(g_iPointsBlue > g_iPointsRed)
					{
						SetTeamScore(CS_TEAM_CT, (GetTeamScore(CS_TEAM_CT) + 1));
						CS_TerminateRound(g_fRoundRestart, CSRoundEnd_CTWin);
					}
					else
					{
						SetTeamScore(CS_TEAM_T, (GetTeamScore(CS_TEAM_T) + 1));
						SetTeamScore(CS_TEAM_CT, (GetTeamScore(CS_TEAM_CT) + 1));
						CS_TerminateRound(g_fRoundRestart, CSRoundEnd_Draw);
					}

					return Plugin_Stop;
				}
				else
				{
					g_iNumSeconds = 0;
					g_iCurrentDisable = g_iSuddenDisable;
					FowardPhaseChange(PHASE_SUDDEN);

					g_iCurrentMode = GetRandomInt(0, (g_iNumModes - 1));
					g_iSuddenDuration = g_Cfg_iModeDuration[g_iCurrentMode];

					if(g_Cfg_bModeChat[g_iCurrentMode])
					{
						#if defined _colors_included
						CPrintToChatAll("%t%s", "prefixChatMessage", g_Cfg_sModesChat[g_iCurrentMode]);
						#else
						PrintToChatAll("%t%s", "prefixChatMessage", g_Cfg_sModesChat[g_iCurrentMode]);
						#endif
					}

					if(!g_bGlobalOffensive)
					{
						if(g_Cfg_bModeCenter[g_iCurrentMode])
						{
							PrintCenterTextAll("%t%s", "prefixCenterMessage", g_Cfg_sModesCenter[g_iCurrentMode]);
						}
					}

					for(new i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i) && CheckTeamAccess(i, g_iCurrentTeam[i]))
						{
							if(g_bCloseMenus)
								CancelClientMenu(i, true);

							if(g_iCurrentDisable & DISABLE_CONTROL)
								ClearClientControl(i);

							if(g_iDisableRadar && g_iDisableRadar & g_iPhase && !(g_Access[i][bAccessRadar]))
								ToggleRadar(i, STATE_DISABLE);
							else
								ToggleRadar(i, STATE_ENABLE);

							if(g_iDisableThirdPerson && g_iDisableThirdPerson & g_iPhase && g_bThirdPerson[i])
								ToggleThird(i, STATE_DISABLE);

							if(g_iDisableFlying && g_iDisableFlying & g_iPhase && g_bFlying[i])
								ToggleFlying(i, STATE_DISABLE);
						}
					}

					CreateTimer(0.1, Timer_PrepareProps, _, TIMER_FLAG_NO_MAPCHANGE);
					CreateTimer(0.2, Timer_ModeWeapons, _, TIMER_FLAG_NO_MAPCHANGE);
					CreateTimer(0.3, Timer_ModeExecute, 0, TIMER_FLAG_NO_MAPCHANGE);
				}
			}

			if(g_iNotifyPhaseSoundsBegin && g_iNumSeconds < g_iNotifyPhaseSoundsBegin)
			{
				if(!g_bGlobalOffensive)
				{
					EmitSoundToAll(g_sNotifyPhaseSoundsBegin[g_iNumSeconds], SOUND_FROM_PLAYER, SNDCHAN_VOICE);
				}
			}
		}
		case PHASE_SUDDEN:
		{
			if(g_iSuddenDuration && g_iNumSeconds >= g_iSuddenDuration)
			{
				g_hTimer_Update = INVALID_HANDLE;

				if(g_iPointsRed > g_iPointsBlue)
				{
					CS_TerminateRound(g_fRoundRestart, CSRoundEnd_TerroristWin);
					SetTeamScore(CS_TEAM_T, (GetTeamScore(CS_TEAM_T) + 1));
				}
				else if(g_iPointsBlue > g_iPointsRed)
				{
					CS_TerminateRound(g_fRoundRestart, CSRoundEnd_CTWin);
					SetTeamScore(CS_TEAM_CT, (GetTeamScore(CS_TEAM_CT) + 1));
				}
				else
				{
					CS_TerminateRound(g_fRoundRestart, CSRoundEnd_Draw);
					SetTeamScore(CS_TEAM_T, (GetTeamScore(CS_TEAM_T) + 1));
					SetTeamScore(CS_TEAM_CT, (GetTeamScore(CS_TEAM_CT) + 1));
				}

				return Plugin_Stop;
			}

			if(g_iNotifyPhaseSoundsBegin && g_iNumSeconds < g_iNotifyPhaseSoundsBegin)
			{
				if(!g_bGlobalOffensive)
				{
					EmitSoundToAll(g_sNotifyPhaseSoundsBegin[g_iNumSeconds], SOUND_FROM_PLAYER, SNDCHAN_VOICE);
				}
			}
		}
	}

	switch(g_iPhase)
	{
		case PHASE_BUILD:
		{
			if(g_bReadyInProgress)
			{
				new iIndex = g_iReadyCountdown - 1;
				if(g_iNotifyPhaseSoundsEnd && g_iReadyCountdown <= g_iNotifyPhaseSoundsEnd && StrContains(g_sNotifyPhaseSoundsEnd[iIndex], "?") == -1)
				{
					if(!g_bGlobalOffensive)
					{
						EmitSoundToAll(g_sNotifyPhaseSoundsEnd[iIndex], SOUND_FROM_PLAYER, SNDCHAN_VOICE);
					}
				}

				if(g_iNotifyPhaseChange && g_iReadyCountdown <= g_iNotifyPhaseChange)
				{
					if(!g_bGlobalOffensive)
					{
						decl String:sBuffer[192], String:sPhase[192];
						for(new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i))
							{
								Format(sPhase, sizeof(sPhase), "%T", "termBuildingPhase", i);
								Format(sBuffer, sizeof(sBuffer), "%T", "hintNotifyPhaseTitle", i);
								Format(sBuffer, sizeof(sBuffer), "%s%T", sBuffer, "hintNotifyPhaseEntry", i, sPhase);
								Format(sBuffer, sizeof(sBuffer), "%s%T", sBuffer, "hintNotifyPhaseEntryRemaining", i, 0, (g_iReadyCountdown <= 9) ? "0" : "", g_iReadyCountdown);

								new Handle:hMessage = StartMessageOne("KeyHintText", i);
								BfWriteByte(hMessage, 1);
								BfWriteString(hMessage, sBuffer);
								EndMessage();
							}
						}
					}
					else
					{
						#if defined _colors_included
						CPrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyBuildPhase", g_iReadyCountdown);
						#else
						PrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyBuildPhase", g_iReadyCountdown);
						#endif
					}
				}
			}
			else
			{
				decl String:sPhase[192];
				decl String:sBuffer[192];

				new iRemaining = (g_iBuildDuration - g_iNumSeconds);
				if(bInitial)
					iRemaining += 1;
				new iMinutes = iRemaining / 60;
				new iSeconds = iRemaining - (iMinutes * 60);

				if(iRemaining > 0)
				{
					if(g_iNotifyPhaseSoundsEnd && iRemaining <= g_iNotifyPhaseSoundsEnd && StrContains(g_sNotifyPhaseSoundsEnd[(iRemaining - 1)], "?") == -1)
					{
						if(!g_bGlobalOffensive)
						{
							EmitSoundToAll(g_sNotifyPhaseSoundsEnd[(iRemaining - 1)], SOUND_FROM_PLAYER, SNDCHAN_VOICE);
						}
					}
				}

				if(g_iNotifyPhaseChange && iRemaining <= g_iNotifyPhaseChange)
				{
					#if defined _colors_included
					CPrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyBuildPhase", iRemaining);
					#else
					PrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyBuildPhase", iRemaining);
					#endif
				}

				if(!g_bGlobalOffensive)
				{
					for(new i = 1; i <= MaxClients; i++)
					{
						if(!IsClientInGame(i))
							continue;

						Format(sPhase, sizeof(sPhase), "%T", "termBuildingPhase", i);
						Format(sBuffer, sizeof(sBuffer), "%T", "hintNotifyPhaseTitle", i);
						Format(sBuffer, sizeof(sBuffer), "%s%T", sBuffer, "hintNotifyPhaseEntry", i, sPhase);
						Format(sBuffer, sizeof(sBuffer), "%s%T", sBuffer, "hintNotifyPhaseEntryRemaining", i, iMinutes, (iSeconds <= 9) ? "0" : "", iSeconds);

						if(g_iReadyPhase & g_iPhase && g_iWallEntities && g_iReadyTotal >= g_iReadyNeeded)
						{
							Format(sBuffer, sizeof(sBuffer), "%s%T", sBuffer, "hintNotifyPhaseEntryReady", i, g_iReadyCurrent, g_iReadyNeeded);
						}

						if(g_bAdvancingTeam)
						{
							if(g_iAdvancingTeam == CS_TEAM_T)
								Format(sBuffer, sizeof(sBuffer), "%s%T", sBuffer, "hintNotifyPhaseEntryAdvancing", i, "  Ts", "CTs");
							else
								Format(sBuffer, sizeof(sBuffer), "%s%T", sBuffer, "hintNotifyPhaseEntryAdvancing", i, "CTs", " Ts");
						}

						new Handle:hMessage = StartMessageOne("KeyHintText", i);
						BfWriteByte(hMessage, 1);
						BfWriteString(hMessage, sBuffer);
						EndMessage();
					}
				}
				else if(g_iNumSeconds > 0 && ((g_iNumSeconds % g_iNotifyFrequency) == 0 || bInitial))
				{
					if(!g_iNotifyPhaseChange || iRemaining > g_iNotifyPhaseChange)
					{
						if(g_iReadyPhase & g_iPhase && g_iWallEntities && g_iReadyTotal >= g_iReadyNeeded)
						{
							#if defined _colors_included
							CPrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyBuildPhaseReady", iRemaining, g_iReadyCurrent, g_iReadyNeeded);
							#else
							PrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyBuildPhaseReady", iRemaining, g_iReadyCurrent, g_iReadyNeeded);
							#endif
						}
						else
						{
							#if defined _colors_included
							CPrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyBuildPhaseExtend", iMinutes, (iSeconds <= 9) ? "0" : "", iSeconds);
							#else
							PrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyBuildPhaseExtend", iMinutes, (iSeconds <= 9) ? "0" : "", iSeconds);
							#endif
						}
					}
				}
			}
		}
		case PHASE_WAR:
		{
			if(g_bReadyInProgress)
			{
				new iIndex = g_iReadyCountdown - 1;
				if(g_iNotifyPhaseSoundsEnd && g_iReadyCountdown <= g_iNotifyPhaseSoundsEnd && StrContains(g_sNotifyPhaseSoundsEnd[iIndex], "?") == -1)
				{
					if(!g_bGlobalOffensive)
					{
						EmitSoundToAll(g_sNotifyPhaseSoundsEnd[iIndex], SOUND_FROM_PLAYER, SNDCHAN_VOICE);
					}
				}

				if(g_iNotifyPhaseChange && g_iReadyCountdown <= g_iNotifyPhaseChange)
				{
					if(!g_bGlobalOffensive)
					{
						decl String:sBuffer[192], String:sPhase[192];
						for(new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i))
							{
								Format(sPhase, sizeof(sPhase), "%T", "termWarPhase", i);
								Format(sBuffer, sizeof(sBuffer), "%T", "hintNotifyPhaseTitle", i);
								Format(sBuffer, sizeof(sBuffer), "%s%T", sBuffer, "hintNotifyPhaseEntry", i, sPhase);
								Format(sBuffer, sizeof(sBuffer), "%s%T", sBuffer, "hintNotifyPhaseEntryRemaining", i, 0, (g_iReadyCountdown <= 9) ? "0" : "", g_iReadyCountdown);

								new Handle:hMessage = StartMessageOne("KeyHintText", i);
								BfWriteByte(hMessage, 1);
								BfWriteString(hMessage, sBuffer);
								EndMessage();
							}
						}
					}
					else
					{
						#if defined _colors_included
						CPrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyWarPhase", g_iReadyCountdown);
						#else
						PrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyWarPhase", g_iReadyCountdown);
						#endif
					}
				}
			}
			else
			{
				decl String:sPhase[192];
				decl String:sBuffer[192];

				new iRemaining = (g_iWarDuration - g_iNumSeconds);
				if(bInitial)
					iRemaining += 1;
				new iMinutes = iRemaining / 60;
				new iSeconds = iRemaining - (iMinutes * 60);

				if(iRemaining > 0)
				{
					if(g_iNotifyPhaseSoundsEnd && iRemaining <= g_iNotifyPhaseSoundsEnd && StrContains(g_sNotifyPhaseSoundsEnd[(iRemaining - 1)], "?") == -1)
					{
						if(!g_bGlobalOffensive)
						{
							EmitSoundToAll(g_sNotifyPhaseSoundsEnd[(iRemaining - 1)], SOUND_FROM_PLAYER, SNDCHAN_VOICE);
						}
					}
				}

				if(g_iNotifyPhaseChange && iRemaining <= g_iNotifyPhaseChange)
				{
					#if defined _colors_included
					CPrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyWarPhase", iRemaining);
					#else
					PrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyWarPhase", iRemaining);
					#endif
				}

				if(!g_bGlobalOffensive)
				{
					for(new i = 1; i <= MaxClients; i++)
					{
						if(!IsClientInGame(i))
							continue;

						Format(sPhase, sizeof(sPhase), "%T", "termWarPhase", i);
						Format(sBuffer, sizeof(sBuffer), "%T", "hintNotifyPhaseTitle", i);
						Format(sBuffer, sizeof(sBuffer), "%s%T", sBuffer, "hintNotifyPhaseEntry", i, sPhase);

						if(g_iWarDuration)
						{
							Format(sBuffer, sizeof(sBuffer), "%s%T", sBuffer, "hintNotifyPhaseEntryRemaining", i, iMinutes, (iSeconds <= 9) ? "0" : "", iSeconds);
						}

						if(g_iReadyPhase & g_iPhase && g_iWallEntities && g_iReadyTotal >= g_iReadyNeeded)
						{
							Format(sBuffer, sizeof(sBuffer), "%s%T", sBuffer, "hintNotifyPhaseEntryReady", i, g_iReadyCurrent, g_iReadyNeeded);
						}

						if(g_bAdvancingTeam)
						{
							if(g_iAdvancingTeam == CS_TEAM_T)
								Format(sBuffer, sizeof(sBuffer), "%s%T", sBuffer, "hintNotifyPhaseEntryAdvancing", i, "  Ts", "CTs");
							else
								Format(sBuffer, sizeof(sBuffer), "%s%T", sBuffer, "hintNotifyPhaseEntryAdvancing", i, "CTs", " Ts");
						}

						new Handle:hMessage = StartMessageOne("KeyHintText", i);
						BfWriteByte(hMessage, 1);
						BfWriteString(hMessage, sBuffer);
						EndMessage();
					}
				}
				else if(g_iNumSeconds > 0 && ((g_iNumSeconds % g_iNotifyFrequency) == 0 || bInitial))
				{
					if(!g_iNotifyPhaseChange || iRemaining > g_iNotifyPhaseChange)
					{
						if(g_iReadyPhase & g_iPhase && g_iWallEntities && g_iReadyTotal >= g_iReadyNeeded)
						{
							#if defined _colors_included
							CPrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyWarPhaseReady", iRemaining, g_iReadyCurrent, g_iReadyNeeded);
							#else
							PrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyWarPhaseReady", iRemaining, g_iReadyCurrent, g_iReadyNeeded);
							#endif
						}
						else
						{
							#if defined _colors_included
							CPrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyWarPhaseExtend", iMinutes, (iSeconds <= 9) ? "0" : "", iSeconds);
							#else
							PrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyWarPhaseExtend", iMinutes, (iSeconds <= 9) ? "0" : "", iSeconds);
							#endif
						}
					}
				}
			}
		}
		case PHASE_SUDDEN:
		{
			decl String:sPhase[192];
			decl String:sBuffer[192];

			new iRemaining = (g_iSuddenDuration - g_iNumSeconds);
			if(bInitial)
				iRemaining += 1;
			new iMinutes = iRemaining / 60;
			new iSeconds = iRemaining - (iMinutes * 60);

			if(iRemaining > 0)
			{
				if(g_iNotifyPhaseSoundsEnd && iRemaining <= g_iNotifyPhaseSoundsEnd && StrContains(g_sNotifyPhaseSoundsEnd[(iRemaining - 1)], "?") == -1)
				{
					if(!g_bGlobalOffensive)
					{
						EmitSoundToAll(g_sNotifyPhaseSoundsEnd[(iRemaining - 1)], SOUND_FROM_PLAYER, SNDCHAN_VOICE);
					}
				}
			}

			if(g_iNotifyPhaseChange && iRemaining <= g_iNotifyPhaseChange)
			{
				#if defined _colors_included
				CPrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyDeathPhase", iRemaining);
				#else
				PrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyDeathPhase", iRemaining);
				#endif
			}

			if(!g_bGlobalOffensive)
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(!IsClientInGame(i))
						continue;

					Format(sPhase, sizeof(sPhase), "%T", "termDeathPhase", i);
					Format(sBuffer, sizeof(sBuffer), "%T", "hintNotifyPhaseTitle", i);
					Format(sBuffer, sizeof(sBuffer), "%s%T", sBuffer, "hintNotifyPhaseEntry", i, sPhase);

					if(g_iSuddenDuration)
					{
						Format(sBuffer, sizeof(sBuffer), "%s%T", sBuffer, "hintNotifyPhaseEntryRemaining", i, iMinutes, (iSeconds <= 9) ? "0" : "", iSeconds);
					}

					new Handle:hMessage = StartMessageOne("KeyHintText", i);
					BfWriteByte(hMessage, 1);
					BfWriteString(hMessage, sBuffer);
					EndMessage();
				}
			}
			else if(g_iNumSeconds > 0 && ((g_iNumSeconds % g_iNotifyFrequency) == 0 || bInitial))
			{
				if(!g_iNotifyPhaseChange || iRemaining > g_iNotifyPhaseChange)
				{
					#if defined _colors_included
					CPrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyDeathPhaseExtend", iMinutes, (iSeconds <= 9) ? "0" : "", iSeconds);
					#else
					PrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyDeathPhaseExtend", iMinutes, (iSeconds <= 9) ? "0" : "", iSeconds);
					#endif
				}
			}
		}
	}

	return Plugin_Continue;
}

public Action:Timer_ModeWeapons(Handle:timer)
{
	decl String:sClassname[64];
	for(new i = (MaxClients + 1); i <= MAX_SERVER_ENTITIES; i++)
	{
		if(IsValidEdict(i) && IsValidEntity(i))
		{
			GetEdictClassname(i, sClassname, 64);
			if(StrContains(sClassname, "weapon_") != -1 && GetEntDataEnt2(i, g_iOwnerEntity) == -1)
				AcceptEntityInput(i, "Kill");
		}
	}
}

GetPhaseIndex(phase)
{
	switch(phase)
	{
		case PHASE_LEGACY:
			return 0;
		case PHASE_BUILD:
			return 1;
		case PHASE_WAR:
			return 2;
		case PHASE_SUDDEN:
			return 3;
	}

	return 0;
}

public Action:Timer_PrepareProps(Handle:timer)
{
	for(new i = MaxClients; i <= MAX_SERVER_ENTITIES; i++)
	{
		if(IsValidEntity(i))
		{
			if(g_iPropState[i] & STATE_VALID)
			{
				new _iHealth = g_Cfg_iPropHealth[g_iPropType[i]][GetPhaseIndex(g_iPhase)];
				if(g_iPhase == PHASE_SUDDEN)
				{
					switch(g_Cfg_iModeMethod[g_iCurrentMode])
					{
						case MODE_DEATHMATCH:
							Entity_DeleteProp(i, false);
						case MODE_ASSAULT:
						{
							SetPropHealth(i, _iHealth);
							SetPropColorAlpha(i, ALPHA_PROP_WAR);
						}
					}
				}
				else
					SetPropHealth(i, _iHealth);
			}

			if(g_iPropState[i] & STATE_BREAKABLE)
				SetEntProp(i, Prop_Data, "m_takedamage", (g_iDisableBreaking && g_iDisableBreaking & g_iPhase) ? 0 : 2);
		}
	}
}

SetPropHealth(iEnt, health)
{
	if(!health)
		SDKUnhook(iEnt, SDKHook_OnTakeDamage, Entity_OnTakeDamage);
	else
		SDKHook(iEnt, SDKHook_OnTakeDamage, Entity_OnTakeDamage);

	SetEntProp(iEnt, Prop_Data, "m_takedamage", health ? 2 : 0);
	SetEntProp(iEnt, Prop_Data, "m_iHealth", health);
}

public Action:Timer_ModeEquip(Handle:timer, Handle:pack)
{
	decl String:sBuffer[32], String:sWeapon[32];

	ResetPack(pack);
	new iTeam = ReadPackCell(pack);
	ReadPackString(pack, sWeapon, 32);

	Format(sBuffer, 32, "weapon_%s", sWeapon);
	for(new i = 1; i <= MaxClients; i++)
	{
		if(g_bAlive[i] && IsClientInGame(i) && (!iTeam || g_iCurrentTeam[i] == iTeam))
		{
			GivePlayerItem(i, sBuffer);
		}
	}
}

public Action:Timer_ModeExecute(Handle:timer, any:_bEnding)
{
	decl String:sTemp[MAX_CONFIG_OPERATIONS][64];
	decl String:sBuffer[MAX_CONFIG_OPERATIONS][64];
	new iOperations = ExplodeString(_bEnding ? g_Cfg_sModesEnd[g_iCurrentMode] : g_Cfg_sModesStart[g_iCurrentMode], ";", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]));

	for(new i = 0; i < iOperations; i++)
	{
		ExplodeString(sBuffer[i], " ", sTemp, sizeof(sTemp), sizeof(sTemp[]));

		new iTeam = StringToInt(sTemp[1]);
		if(StrEqual(sTemp[0], "strip"))
		{
			new bool:bKnife = bool:StringToInt(sTemp[2]);

			for(new j = 1; j <= MaxClients; j++)
			{
				if(g_bAlive[j] && IsClientInGame(j) && (!iTeam || g_iCurrentTeam[j] == iTeam))
				{
					for(new k = 0; k <= 128; k += 4)
					{
						new iEnt = GetEntDataEnt2(j, (g_iMyWeapons + k));
						if(iEnt > 0 && IsValidEdict(iEnt))
						{
							RemovePlayerItem(j, iEnt);
							AcceptEntityInput(iEnt, "Kill");
						}
					}

					if(bKnife)
					{
						GivePlayerItem(j, "weapon_knife");
						FakeClientCommandEx(j, "use weapon_knife");
					}
				}
			}
		}
		else if(StrEqual(sTemp[0], "equip"))
		{
			decl String:sWeapons[40][24];
			new iWeapons = ExplodeString(sTemp[2], ",", sWeapons, sizeof(sWeapons), sizeof(sWeapons[]));
			if(iWeapons >= 1)
			{
				iWeapons = GetRandomInt(0, (iWeapons - 1));
				Format(g_sModeWeapon, sizeof(g_sModeWeapon), "weapon_%s", sWeapons[iWeapons]);
				if(g_hWeaponRestrict != INVALID_HANDLE)
				{
					GetTrieValue(g_hTrie_RestrictIndex, sWeapons[iWeapons], g_iRestrictWeapon);

					if(g_bRestrictState[0][g_iRestrictWeapon])
					{
						g_bRestrictReturn[0][g_iRestrictWeapon] = true;
						SetConVarInt(g_hRestrictCvar[0][g_iRestrictWeapon], -1);
					}

					if(g_bRestrictState[1][g_iRestrictWeapon])
					{
						g_bRestrictReturn[1][g_iRestrictWeapon] = true;
						SetConVarInt(g_hRestrictCvar[1][g_iRestrictWeapon], -1);
					}
				}

				new Handle:hPack = INVALID_HANDLE;
				CreateDataTimer(0.1, Timer_ModeEquip, hPack);
				WritePackCell(hPack, iTeam);
				WritePackString(hPack, sWeapons[iWeapons]);
			}
		}
		else if(StrEqual(sTemp[0], "tele"))
		{
			for(new j = 1; j <= MaxClients; j++)
			{
				if(g_bAlive[j] && IsClientInGame(j) && (!iTeam || g_iCurrentTeam[j] == iTeam))
				{
					TeleportPlayer(j);
					ClearClientTeleport(j);
				}
			}
		}
		else if(StrEqual(sTemp[0], "speed"))
		{
			new Float:_fAmount = StringToFloat(sTemp[2]);
			if(_fAmount == -1.0)
			{
				new Float:_fMin = StringToFloat(sTemp[3]);
				new Float:_fMax = StringToFloat(sTemp[4]);
				_fAmount = GetRandomFloat(_fMin, _fMax);
			}

			for(new j = 1; j <= MaxClients; j++)
			{
				if(g_bAlive[j] && IsClientInGame(j) && (!iTeam || g_iCurrentTeam[j] == iTeam))
				{
					g_bResetSpeed[j] = true;
					SetEntPropFloat(j, Prop_Data, "m_flLaggedMovementValue", _fAmount);
				}
			}
		}
		else if(StrEqual(sTemp[0], "gravity"))
		{
			new Float:_fAmount = StringToFloat(sTemp[2]);
			if(_fAmount == -1.0)
			{
				new Float:_fMin = StringToFloat(sTemp[3]);
				new Float:_fMax = StringToFloat(sTemp[4]);
				_fAmount = GetRandomFloat(_fMin, _fMax);
			}

			for(new j = 1; j <= MaxClients; j++)
			{
				if(g_bAlive[j] && IsClientInGame(j) && (!iTeam || g_iCurrentTeam[j] == iTeam))
				{
					g_bResetGravity[j] = true;
					SetEntityGravity(j, _fAmount);
				}
			}
		}
		else if(StrEqual(sTemp[0], "health"))
		{
			new _iAmount = StringToInt(sTemp[2]);
			if(_iAmount == -1)
			{
				new iMinutes = StringToInt(sTemp[3]);
				new _iMax = StringToInt(sTemp[4]);
				_iAmount = GetRandomInt(iMinutes, _iMax);
			}

			for(new j = 1; j <= MaxClients; j++)
			{
				if(g_bAlive[j] && IsClientInGame(j) && (!iTeam || g_iCurrentTeam[j] == iTeam))
				{
					SetEntityHealth(j, _iAmount);
				}
			}
		}
		else if(StrEqual(sTemp[0], "grenades"))
		{
			g_iInfiniteGrenades = bool:StringToInt(sTemp[1]);
		}
		else
			ServerCommand("%s", sBuffer[i]);
	}
}

public Action:Timer_Teleport(Handle:timer, any:client)
{
	g_fTeleRemaining[client] -= 1.0;

	if(g_fTeleRemaining[client] <= 0.0)
	{
		g_bTeleporting[client] = false;
		g_hTimer_TeleportPlayer[client] = INVALID_HANDLE;

		if(g_bGlobalOffensive)
		{
			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserTeleportSuccess");
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserTeleportSuccess");
			#endif
		}
		else
		{
			PrintCenterText(client, "%t%t", "prefixCenterMessage", "chatNotifyUserTeleportSuccess");
		}

		TeleportPlayer(client);

		return Plugin_Stop;
	}

	if(g_bGlobalOffensive)
	{
		#if defined _colors_included
		CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserTeleportPending", g_fTeleRemaining[client]);
		#else
		PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserTeleportPending", g_fTeleRemaining[client]);
		#endif
	}
	else
	{
		PrintCenterText(client, "%t%t", "prefixCenterMessage", "chatNotifyUserTeleportPending", g_fTeleRemaining[client]);
	}

	return Plugin_Continue;
}

TeleportPlayer(client)
{
	switch(g_iCurrentTeam[client])
	{
		case 2:
		{
			TeleportEntity(client, g_fRedTeleports[GetRandomInt(0, g_iNumRedSpawns)], NULL_VECTOR, NULL_VECTOR);
			if(!g_iStuckBeacon || g_iStuckBeacon & g_iPhase)
				g_bTeleported[client] = true;
		}
		case 3:
		{
			TeleportEntity(client, g_fBlueTeleports[GetRandomInt(0, g_iNumBlueSpawns)], NULL_VECTOR, NULL_VECTOR);
			if(!g_iStuckBeacon || g_iStuckBeacon & g_iPhase)
				g_bTeleported[client] = true;
		}
	}
}

public Action:Timer_KillEntity(Handle:timer, any:ref)
{
	new iEnt = EntRefToEntIndex(ref);
	if(iEnt != INVALID_ENT_REFERENCE)
		AcceptEntityInput(iEnt, "Kill");
}

Trace_GetEntity(client, Float:_fDistance = 0.0)
{
	new Handle:_hTemp, iIndex = -1;
	decl Float:fOrigin[3], Float:fAngles[3];
	GetClientEyePosition(client, fOrigin);
	GetClientEyeAngles(client, fAngles);

	_hTemp = TR_TraceRayFilterEx(fOrigin, fAngles, MASK_OPAQUE, RayType_Infinite, Tracer_FilterPlayers, client);
	if(TR_DidHit(_hTemp))
	{
		iIndex = TR_GetEntityIndex(_hTemp);
		if(_fDistance)
		{
			GetEntPropVector(iIndex, Prop_Send, "m_vecOrigin", fAngles);
			if(GetVectorDistance(fAngles, fOrigin) > _fDistance)
			{
				if(IsValidEntity(iIndex) && g_iPropState[iIndex] & STATE_VALID)
					PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserControlPropWarningDistance", g_Cfg_sPropNames[g_iPropType[iIndex]]);
				CloseHandle(_hTemp);
				return -1;
			}
		}
	}

	if(_hTemp != INVALID_HANDLE)
		CloseHandle(_hTemp);

	return (iIndex > 0) ? iIndex : -1;
}

public bool:Tracer_FilterPlayers(iEnt, contentsMask, any:data)
{
	if(iEnt != data && iEnt > MaxClients)
		return true;

	return false;
}

public bool:Tracer_FilterBlocks(iEnt, contentsMask, any:data)
{
	if(iEnt > MaxClients && !(g_iPropState[iEnt] & STATE_GRABBED))
		return true;

	return false;
}

GetEntityIndex(client, iEnt)
{
	return FindValueInArray(g_hArray_PlayerProps[client], iEnt);
}

PerformTeleport(client)
{
	g_iPlayerTeleports[client]++;
	if(!g_Access[client][fStuckDelay])
	{
		if(g_Access[client][iTotalTeleports])
			PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserTeleportSuccessLimited", (g_Access[client][iTotalTeleports] - g_iPlayerTeleports[client]), g_Access[client][iTotalTeleports]);
		else
			PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserTeleportSuccessInfinite");

		TeleportPlayer(client);
	}
	else
	{
		if(g_Access[client][iTotalTeleports])
			PrintHintText(client, "%t%t", "prefixHintMessage", "chatNotifyUserTeleportPendingLimited", g_Access[client][fStuckDelay], (g_Access[client][iTotalTeleports] - g_iPlayerTeleports[client]), g_Access[client][iTotalTeleports]);
		else
			PrintHintText(client, "%t%t", "prefixHintMessage", "chatNotifyUserTeleportPendingInfinite", g_Access[client][fStuckDelay]);

		g_bTeleporting[client] = true;
		g_fTeleRemaining[client] = g_Access[client][fStuckDelay];

		if(g_bGlobalOffensive)
		{
			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserTeleportPending", g_fTeleRemaining[client]);
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserTeleportPending", g_fTeleRemaining[client]);
			#endif
		}
		else
			PrintCenterText(client, "%t%t", "prefixCenterMessage", "chatNotifyUserTeleportPending", g_fTeleRemaining[client]);
		g_hTimer_TeleportPlayer[client] = CreateTimer(1.0, Timer_Teleport, client, TIMER_REPEAT);
	}
}

ColorClientProps(client, index)
{
	new iSize = GetArraySize(g_hArray_PlayerProps[client]);
	for(new i = 0; i < iSize; i++)
	{
		new iEnt = GetArrayCell(g_hArray_PlayerProps[client], i);
		if(IsValidEdict(iEnt) && IsValidEntity(iEnt))
		{
			if(g_bBaseColors && g_iPropState[iEnt] & STATE_BASE)
				SetPropColor(iEnt, g_iBaseColors, true);
			else
			{
				new iColors[6] = { -1, ... };
				iColors[0] = g_Cfg_iColorArrays[index][0] == -1 ? GetRandomInt(0, 255) : g_Cfg_iColorArrays[index][0];
				iColors[1] = g_Cfg_iColorArrays[index][1] == -1 ? GetRandomInt(0, 255) : g_Cfg_iColorArrays[index][1];
				iColors[2] = g_Cfg_iColorArrays[index][2] == -1 ? GetRandomInt(0, 255) : g_Cfg_iColorArrays[index][2];
				iColors[3] = (!g_Cfg_bPropAlpha[g_iPropType[iEnt]]) ? 255 : (g_Cfg_iColorArrays[index][3] == -1 ? GetRandomInt(0, 255) : g_Cfg_iColorArrays[index][3]);

				SetPropColor(iEnt, iColors, true);
			}
		}
	}
}

Bool_ClearClientProps(client, bool:bDel = true, bool:bClr = false)
{
	new _iDeleted;
	if(bDel)
	{
		new iSize = GetArraySize(g_hArray_PlayerProps[client]);
		for(new i = 0; i < iSize; i++)
		{
			new iEnt = GetArrayCell(g_hArray_PlayerProps[client], i);
			if(IsValidEntity(iEnt))
			{
				Entity_DeleteProp(iEnt);
				_iDeleted++;
			}
		}

		switch(g_iCurrentTeam[client])
		{
			case CS_TEAM_T:
				g_iPointsRed += (_iDeleted * POINTS_DELETE);
			case CS_TEAM_CT:
				g_iPointsBlue += (_iDeleted * POINTS_DELETE);
		}
	}

	g_iPlayerProps[client] = 0;
	if(bClr)
		g_iPlayerDeletes[client] += _iDeleted;
	else
		g_iPlayerDeletes[client] = 0;

	ClearArray(g_hArray_PlayerProps[client]);

	if(g_bDatabaseFound && g_hSql_Database != INVALID_HANDLE)
		if(g_bPlayerBaseSpawned[client])
			g_bPlayerBaseSpawned[client] = false;

	return _iDeleted ? true : false;
}

bool:Entity_Valid(iEnt)
{
	if(iEnt > 0 && IsValidEntity(iEnt) && g_iPropState[iEnt] & STATE_VALID)
		return true;

	return false;
}

RevertPropColor(iEnt)
{
	SetEntityRenderColor(iEnt, g_iPropColor[iEnt][0], g_iPropColor[iEnt][1], g_iPropColor[iEnt][2], g_iPropColor[iEnt][3]);
}

SetPropColor(iEnt, colors[6], save = false)
{
	SetEntityRenderColor(iEnt, colors[0], colors[1], colors[2], colors[3]);

	if(colors[4] >= 0)
		SetEntityRenderFx(iEnt, RenderFx:colors[4]);

	if(colors[5] >= 0)
		SetEntityRenderMode(iEnt, RenderMode:colors[5]);

	if(save)
		g_iPropColor[iEnt] = colors;
}

SetPropColorAlpha(iEnt, alpha = -1)
{
	SetEntityRenderMode(iEnt, RenderMode:1);
	SetEntityRenderColor(iEnt, g_iPropColor[iEnt][0], g_iPropColor[iEnt][1], g_iPropColor[iEnt][2], (alpha == -1 ? g_iPropColor[iEnt][3] : alpha));
}

GetPropColor(iEnt)
{
	return g_iPropColor[iEnt];
}

Entity_ColorProp(client, iEnt)
{
	new iColors[4];

	if(g_Access[client][bAccessColor])
	{
		iColors[0] = g_Cfg_iColorArrays[g_iPlayerColor[client]][0] == -1 ? GetRandomInt(0, 255) : g_Cfg_iColorArrays[g_iPlayerColor[client]][0];
		iColors[1] = g_Cfg_iColorArrays[g_iPlayerColor[client]][1] == -1 ? GetRandomInt(0, 255) : g_Cfg_iColorArrays[g_iPlayerColor[client]][1];
		iColors[2] = g_Cfg_iColorArrays[g_iPlayerColor[client]][2] == -1 ? GetRandomInt(0, 255) : g_Cfg_iColorArrays[g_iPlayerColor[client]][2];
		iColors[3] = (!g_Cfg_bPropAlpha[g_iPropType[iEnt]]) ? 255 : (g_Cfg_iColorArrays[g_iPlayerColor[client]][3] == -1 ? GetRandomInt(0, 255) : g_Cfg_iColorArrays[g_iPlayerColor[client]][3]);
	}
	else
	{
		switch(g_iCurrentTeam[client])
		{
			case CS_TEAM_T:
				iColors = g_iPropColoringTerrorist;
			case CS_TEAM_CT:
				iColors = g_iPropColoringCounter;
			case CS_TEAM_SPECTATOR:
				iColors = g_iPropColoringSpec;
		}
	}

	g_iPropColor[iEnt] = iColors;
	SetEntityRenderMode(iEnt, RenderMode:1);
	SetEntityRenderColor(iEnt, iColors[0], iColors[1], iColors[2], iColors[3]);
}

Entity_SpawnProp(client, _iType, Float:fPosition[3], Float:fAngles[3])
{
	new iEnt = CreateEntityByName(g_sPropTypes[g_Cfg_iPropTypes[_iType]]);
	if(iEnt > 0)
	{
		g_iBaseIndex[iEnt] = -1;
		g_iPropType[iEnt] = _iType;
		g_iPropState[iEnt] |= STATE_VALID;
		g_iPropTeam[iEnt] = g_iCurrentTeam[client];
		g_iPropUser[iEnt] = GetClientUserId(client);
		strcopy(g_sPropOwner[iEnt], sizeof(g_sPropOwner[]), g_sName[client]);

		g_iUniqueProp++;
		decl String:sBuffer[32];
		Format(sBuffer, sizeof(sBuffer), "BuildWars:Prop:%d", g_iUniqueProp);
		DispatchKeyValue(iEnt, "targetname", sBuffer);
		DispatchKeyValue(iEnt, "model", g_Cfg_sPropPaths[_iType]);
		DispatchKeyValue(iEnt, "Solid", "6");
		DispatchKeyValue(iEnt, "disablereceiveshadows", "1");
		DispatchKeyValue(iEnt, "disableshadows", "1");
		DispatchSpawn(iEnt);

		SetPropHealth(iEnt, g_Cfg_iPropHealth[_iType][GetPhaseIndex(g_iPhase)]);

		TeleportEntity(iEnt, fPosition, fAngles, NULL_VECTOR);
	}

	g_iPlayerPrevious[client] = _iType;
	return iEnt;
}

Entity_SpawnBase(client, _iType, Float:fPosition[3], Float:fAngles[3], iIndex)
{
	new iEnt = CreateEntityByName(g_sPropTypes[g_Cfg_iPropTypes[_iType]]);
	if(iEnt > 0)
	{
		g_iBaseIndex[iEnt] = iIndex;
		g_iPropType[iEnt] = _iType;
		g_iPropState[iEnt] |= STATE_VALID;
		g_iPropState[iEnt] |= STATE_BASE;
		g_iPropTeam[iEnt] = g_iCurrentTeam[client];
		g_iPropUser[iEnt] = GetClientUserId(client);
		strcopy(g_sPropOwner[iEnt], sizeof(g_sPropOwner[]), g_sName[client]);

		g_iUniqueProp++;
		decl String:sBuffer[32];
		Format(sBuffer, sizeof(sBuffer), "BuildWars:Prop:%d", g_iUniqueProp);
		DispatchKeyValue(iEnt, "targetname", sBuffer);
		DispatchKeyValue(iEnt, "model", g_Cfg_sPropPaths[_iType]);
		DispatchKeyValue(iEnt, "Solid", "6");
		DispatchKeyValue(iEnt, "disablereceiveshadows", "1");
		DispatchKeyValue(iEnt, "disableshadows", "1");
		DispatchSpawn(iEnt);

		SetPropHealth(iEnt, g_Cfg_iPropHealth[_iType][GetPhaseIndex(g_iPhase)]);
		TeleportEntity(iEnt, fPosition, fAngles, NULL_VECTOR);
	}

	return iEnt;
}

Entity_RotateProp(iEnt, Float:_fValue[3], bool:_bReset)
{
	new Float:fAngles[3];
	if(!_bReset)
	{
		GetEntPropVector(iEnt, Prop_Data, "m_angRotation", fAngles);
		AddVectors(fAngles, _fValue, fAngles);
		fAngles = GetCleanAngles(fAngles);
	}

	TeleportEntity(iEnt, NULL_VECTOR, fAngles, NULL_VECTOR);
}

Entity_PositionProp(iEnt, Float:_fValue[3])
{
	decl Float:fOrigin[3];
	GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fOrigin);
	AddVectors(fOrigin, _fValue, fOrigin);
	fOrigin = GetCleanVector(fOrigin);

	TeleportEntity(iEnt, fOrigin, NULL_VECTOR, NULL_VECTOR);
}

Entity_DeleteProp(iEnt, bool:dissolve = true)
{
	if(!g_bGlobalOffensive && g_bDissolve && dissolve)
	{
		if(g_iCurEntities < g_iMaximumEntities)
		{
			new _iDissolve = CreateEntityByName("env_entity_dissolver");
			if(_iDissolve > 0)
			{
				g_iPropState[iEnt] = 0;

				decl String:sName[64];
				GetEntPropString(iEnt, Prop_Data, "m_iName", sName, 64);
				DispatchKeyValue(_iDissolve, "dissolvetype", g_sDissolve);
				DispatchKeyValue(_iDissolve, "target", sName);
				AcceptEntityInput(_iDissolve, "Dissolve");

				CreateTimer(1.0, Timer_KillEntity, EntIndexToEntRef(iEnt));
				CreateTimer(0.1, Timer_KillEntity, EntIndexToEntRef(_iDissolve));
				return;
			}
		}
	}

	g_iPropState[iEnt] = 0;
	AcceptEntityInput(iEnt, "Kill");
}

DeleteClientProp(client, iEnt)
{
	new iIndex = GetEntityIndex(client, iEnt);
	if(iIndex >= 0)
		RemoveFromArray(g_hArray_PlayerProps[client], iIndex);

	if(Entity_Valid(iEnt))
	{
		g_iPlayerProps[client]--;
		g_iPlayerDeletes[client]++;
		Entity_DeleteProp(iEnt);
	}
}

SetSpawns()
{
	decl _iNeeded, iEnt, Float:_fTemp[3];

	iEnt = -1;
	g_iNumRedSpawns = 0;
	while((iEnt = FindEntityByClassname(iEnt, "info_player_terrorist")) != -1)
	{
		if(g_iNumRedSpawns == MAX_SPAWN_POINTS)
			break;

		g_iRedTeleports[g_iNumRedSpawns] = iEnt;
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", g_fRedTeleports[g_iNumRedSpawns]);

		g_iNumRedSpawns++;
	}

	if(g_iNumRedSpawns)
	{
		if(g_bMaintainSpawns)
		{
			_iNeeded = RoundToCeil(float(MaxClients) / 2.0) - g_iNumRedSpawns;
			while(_iNeeded > 0)
			{
				_fTemp = g_fRedTeleports[GetRandomInt(0, g_iNumRedSpawns)];
				_fTemp[2] += 1.0;

				iEnt = CreateEntityByName("info_player_terrorist");
				DispatchSpawn(iEnt);
				TeleportEntity(iEnt, _fTemp, NULL_VECTOR, NULL_VECTOR);
				_iNeeded--;
			}
		}
		g_iNumRedSpawns--;
	}

	iEnt = -1;
	g_iNumBlueSpawns = 0;
	while((iEnt = FindEntityByClassname(iEnt, "info_player_counterterrorist")) != -1)
	{
		if(g_iNumBlueSpawns == MAX_SPAWN_POINTS)
			break;

		g_iBlueTeleports[g_iNumBlueSpawns] = iEnt;
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", g_fBlueTeleports[g_iNumBlueSpawns]);

		g_iNumBlueSpawns++;
	}

	if(g_iNumBlueSpawns)
	{
		if(g_bMaintainSpawns)
		{
			_iNeeded = RoundToCeil(float(MaxClients) / 2.0) - g_iNumBlueSpawns;
			while(_iNeeded > 0)
			{
				_fTemp = g_fBlueTeleports[GetRandomInt(0, g_iNumBlueSpawns)];
				_fTemp[2] += 1.0;

				iEnt = CreateEntityByName("info_player_counterterrorist");
				DispatchSpawn(iEnt);
				TeleportEntity(iEnt, _fTemp, NULL_VECTOR, NULL_VECTOR);
				_iNeeded--;
			}
		}
		g_iNumBlueSpawns--;
	}
}

SetDownloads()
{
	decl String:sBuffer[256];
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "configs/buildwars/buildwars.downloads.cfg");

	new Handle:_hTemp = OpenFile(sBuffer, "r");
	if(_hTemp != INVALID_HANDLE)
	{
		new iLength;
		while (ReadFileLine(_hTemp, sBuffer, sizeof(sBuffer)))
		{
			iLength = strlen(sBuffer);
			if(sBuffer[(iLength - 1)] == '\n')
				sBuffer[--iLength] = '\0';

			TrimString(sBuffer);
			if(!StrEqual(sBuffer, ""))
				ReadFileFolder(sBuffer);

			if(IsEndOfFile(_hTemp))
				break;
		}

		CloseHandle(_hTemp);
	}
}

ReadFileFolder(String:sPath[])
{
	new Handle:_hTemp = INVALID_HANDLE;
	new iLength, FileType:_iFileType = FileType_Unknown;
	decl String:sBuffer[256], String:_sLine[256];

	iLength = strlen(sPath);
	if(sPath[iLength-1] == '\n')
		sPath[--iLength] = '\0';

	TrimString(sPath);
	if(DirExists(sPath))
	{
		_hTemp = OpenDirectory(sPath);
		while(ReadDirEntry(_hTemp, sBuffer, sizeof(sBuffer), _iFileType))
		{
			iLength = strlen(sBuffer);
			if(sBuffer[iLength-1] == '\n')
				sBuffer[--iLength] = '\0';
			TrimString(sBuffer);

			if(!StrEqual(sBuffer, "") && !StrEqual(sBuffer, ".", false) && !StrEqual(sBuffer,"..",false))
			{
				strcopy(_sLine, sizeof(_sLine), sPath);
				StrCat(_sLine, sizeof(_sLine), "/");
				StrCat(_sLine, sizeof(_sLine), sBuffer);

				if(_iFileType == FileType_File)
					ReadItem(_sLine);
				else
					ReadFileFolder(_sLine);
			}
		}
	}
	else
		ReadItem(sPath);

	if(_hTemp != INVALID_HANDLE)
		CloseHandle(_hTemp);
}

ReadItem(String:sBuffer[])
{
	new String:sExt[16];
	new iDot = FindCharInString(sBuffer, '.', true);
	if(iDot == -1)
		return;

	strcopy(sExt, sizeof(sExt), sBuffer[iDot]);
	decl String:sPath[PLATFORM_MAX_PATH];
	if(!StrEqual(sBuffer, "") && StrContains(sBuffer, "//") != 0)
	{
		if(FileExists(sBuffer))
		{
			if(strcmp(sExt, ".wav") == 0 || strcmp(sExt, ".mp3") == 0)
			{
				PrecacheSound(sBuffer, true);
				Format(sPath, PLATFORM_MAX_PATH, "sound/%s", sBuffer);
				AddFileToDownloadsTable(sPath);
			}
			else if(strcmp(sExt, ".vtf") == 0 || strcmp(sExt, ".vmt") == 0)
			{
				PrecacheDecal(sBuffer, true);
				Format(sPath, PLATFORM_MAX_PATH, "materials/%s", sBuffer);
				AddFileToDownloadsTable(sBuffer);
			}
			else if(strcmp(sExt, ".mdl") == 0)
			{
				PrecacheModel(sBuffer, true);
				AddFileToDownloadsTable(sBuffer);
			}
			else
			{
				PrecacheGeneric(sBuffer, true);
				AddFileToDownloadsTable(sBuffer);
			}
		}
	}
}

bool:CheckTeamAccess(client, team, spec = false)
{
	switch(team)
	{
		case CS_TEAM_T:
			if(!g_bRedAccess)
				return false;
		case CS_TEAM_CT:
			if(!g_bBlueAccess)
				return false;
		case CS_TEAM_SPECTATOR:
			if(spec && !g_Access[client][bAccessSpec])
				return false;
	}

	return true;
}

Menu_Create(client, index = 0)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client], true))
		return;

	decl String:sTemp[4];
	new Handle:hMenu = CreateMenu(MenuHandler_CreateMenu);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	for(new i = 0; i < g_iNumProps; i++)
	{
		if(!g_Cfg_iPropAccess[i] || g_Access[client][iAccess] & g_Cfg_iPropAccess[i])
		{
			Format(sTemp, 4, "%d", i);
			AddMenuItem(hMenu, sTemp, g_Cfg_sPropNames[i]);
		}
	}

	DisplayMenuAtItem(hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_CreateMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Main(param1);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1], true))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);

			SpawnProp(param1, StringToInt(sOption), GetMenuSelectionPosition());
		}
	}
}

SpawnProp(client, type, slot = -1)
{
	if(Bool_SpawnAllowed(client, true) && Bool_SpawnValid(client, true, true))
	{
		decl Float:fOrigin[3], Float:fAngles[3], Float:fNormal[3];
		GetClientEyePosition(client, fOrigin);
		GetClientEyeAngles(client, fAngles);
		TR_TraceRayFilter(fOrigin, fAngles, MASK_SOLID, RayType_Infinite, Tracer_FilterBlocks, client);
		if(TR_DidHit(INVALID_HANDLE))
		{
			fAngles[0] = 0.0;
			fAngles[1] += 90.0;
			TR_GetEndPosition(fOrigin, INVALID_HANDLE);

			new iZone = -1;
			if((iZone = GetBlockedZone(fOrigin)) != -1)
			{
				if(g_iCurrentTime > g_iLastDrawTime[client] || g_iLastDrawZone[client] != iZone)
				{
					g_iLastDrawZone[client] = iZone;
					g_iLastDrawTime[client] = g_iCurrentTime + 5;
					DrawMapZone(iZone, client);
				}

				#if defined _colors_included
				CPrintToChat(client, "%t%t", "prefixChatMessage", "chatWarningProximitySpawn");
				#else
				PrintToChat(client, "%t%t", "prefixChatMessage", "chatWarningProximitySpawn");
				#endif
			}
			else
			{
				TR_GetPlaneNormal(INVALID_HANDLE, fNormal);
				decl Float:fVectorAngles[3];
				GetVectorAngles(fNormal, fVectorAngles);
				fVectorAngles[0] += 90.0;

				decl Float:_fCross[3], Float:_fTempAngles[3], Float:_fTempAngles2[3];
				GetAngleVectors(fAngles, _fTempAngles, NULL_VECTOR, NULL_VECTOR);
				_fTempAngles[2] = 0.0;
				GetAngleVectors(fVectorAngles, _fTempAngles2, NULL_VECTOR, NULL_VECTOR);
				GetVectorCrossProduct(_fTempAngles, fNormal, _fCross);
				new Float:_fYaw = GetAngleBetweenVectors(_fTempAngles2, _fCross, fNormal);
				RotateYaw(fVectorAngles, _fYaw);
				for(new i = 0; i <= 2; i++)
					fVectorAngles[i] = GetCleanAngle(float(RoundToNearest(fVectorAngles[i] / g_Cfg_fDefinedRotations[g_iPlayerRotation[client]])) * g_Cfg_fDefinedRotations[g_iPlayerRotation[client]]);

				fOrigin = GetCleanVector(fOrigin);
				new iEnt = Entity_SpawnProp(client, type, fOrigin, fVectorAngles);
				Entity_ColorProp(client, iEnt);
				if(g_fProximityDelay && Bool_PlayerProximity(client, fOrigin, iEnt))
				{
					g_iPropState[iEnt] |= STATE_PHASE;
					SetPropColorAlpha(iEnt, ALPHA_PROP_PHASED);
					SetEntProp(iEnt, Prop_Data, "m_CollisionGroup", 1);

					g_hPropPhase[iEnt] = CreateTimer(g_fProximityDelay, Timer_PhaseProp, iEnt, TIMER_FLAG_NO_MAPCHANGE);
				}

				PushArrayCell(g_hArray_PlayerProps[client], iEnt);
				g_iPlayerProps[client]++;
				switch(g_iCurrentTeam[client])
				{
					case CS_TEAM_T:
						g_iPointsRed += POINTS_BUILD;
					case CS_TEAM_CT:
						g_iPointsBlue += POINTS_BUILD;
				}

				if(g_bAdvancingTeam && g_iDebugMode != MODE_BUILD && g_iCurrentTeam[client] == g_iAdvancingTeam)
				{
					if(g_Access[client][bAdmin])
					{
						if(g_Access[client][iTotalPropsAdvance])
							PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropLimitedAdmin", g_Cfg_sPropNames[type], (g_Access[client][iTotalPropsAdvance] - g_iPlayerProps[client]), g_Access[client][iTotalPropsAdvance], iEnt, g_iCurEntities);
						else
							PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropUnlimitedAdmin", g_Cfg_sPropNames[type], iEnt, g_iCurEntities);
					}
					else
					{
						if(g_Access[client][iTotalPropsAdvance])
							PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropLimited", g_Cfg_sPropNames[type], (g_Access[client][iTotalPropsAdvance] - g_iPlayerProps[client]), g_Access[client][iTotalPropsAdvance]);
						else
							PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropUnlimited", g_Cfg_sPropNames[type]);
					}
				}
				else
				{
					if(g_Access[client][bAdmin])
					{
						if(g_Access[client][iTotalProps])
							PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropLimitedAdmin", g_Cfg_sPropNames[type], (g_Access[client][iTotalProps] - g_iPlayerProps[client]), g_Access[client][iTotalProps], iEnt, g_iCurEntities);
						else
							PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropUnlimitedAdmin", g_Cfg_sPropNames[type], iEnt, g_iCurEntities);
					}
					else
					{
						if(g_Access[client][iTotalProps])
							PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropLimited", g_Cfg_sPropNames[type], (g_Access[client][iTotalProps] - g_iPlayerProps[client]), g_Access[client][iTotalProps]);
						else
							PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropUnlimited", g_Cfg_sPropNames[type]);
					}
				}
			}
		}

		if(slot != -1)
			Menu_Create(client, slot);
		return;
	}
}

SpawnClone(client, iEnt)
{
	if(Bool_SpawnAllowed(client, true) && Bool_SpawnValid(client, true, true))
	{
		decl Float:fOrigin[3], Float:_fRotation[3];
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fOrigin);

		new iZone = -1;
		if((iZone = GetBlockedZone(fOrigin)) != -1)
		{
			if(g_iCurrentTime > g_iLastDrawTime[client] || g_iLastDrawZone[client] != iZone)
			{
				g_iLastDrawZone[client] = iZone;
				g_iLastDrawTime[client] = g_iCurrentTime + 5;
				DrawMapZone(iZone, client);
			}

			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatWarningProximitySpawn");
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatWarningProximitySpawn");
			#endif
		}
		else
		{
			GetEntPropVector(iEnt, Prop_Data, "m_angRotation", _fRotation);
			new _iType = g_iPropType[iEnt];
			_fRotation = GetCleanAngles(_fRotation);
			fOrigin = GetCleanVector(fOrigin);
			new iTmpEnt = Entity_SpawnProp(client, _iType, fOrigin, _fRotation);
			Entity_ColorProp(client, iTmpEnt);
			if(g_fProximityDelay && Bool_PlayerProximity(client, fOrigin, iTmpEnt))
			{
				g_iPropState[iTmpEnt] |= STATE_PHASE;
				SetPropColorAlpha(iTmpEnt, ALPHA_PROP_PHASED);
				SetEntProp(iTmpEnt, Prop_Data, "m_CollisionGroup", 1);

				g_hPropPhase[iTmpEnt] = CreateTimer(g_fProximityDelay, Timer_PhaseProp, iTmpEnt, TIMER_FLAG_NO_MAPCHANGE);
			}

			PushArrayCell(g_hArray_PlayerProps[client], iTmpEnt);
			g_iPlayerProps[client]++;

			switch(g_iCurrentTeam[client])
			{
				case CS_TEAM_T:
					g_iPointsRed += POINTS_BUILD;
				case CS_TEAM_CT:
					g_iPointsBlue += POINTS_BUILD;
			}

			if(g_bAdvancingTeam && g_iDebugMode != MODE_BUILD && g_iCurrentTeam[client] == g_iAdvancingTeam)
			{
				if(g_Access[client][bAdmin])
				{
					if(g_Access[client][iTotalPropsAdvance])
						PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropLimitedAdmin", g_Cfg_sPropNames[_iType], (g_Access[client][iTotalPropsAdvance] - g_iPlayerProps[client]), g_Access[client][iTotalPropsAdvance], iTmpEnt, g_iCurEntities);
					else
						PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropUnlimitedAdmin", g_Cfg_sPropNames[_iType], iTmpEnt, g_iCurEntities);
				}
				else
				{
					if(g_Access[client][iTotalPropsAdvance])
						PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropLimited", g_Cfg_sPropNames[_iType], (g_Access[client][iTotalPropsAdvance] - g_iPlayerProps[client]), g_Access[client][iTotalPropsAdvance]);
					else
						PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropUnlimited", g_Cfg_sPropNames[_iType]);
				}
			}
			else
			{
				if(g_Access[client][bAdmin])
				{
					if(g_Access[client][iTotalProps])
						PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropLimitedAdmin", g_Cfg_sPropNames[_iType], (g_Access[client][iTotalProps] - g_iPlayerProps[client]), g_Access[client][iTotalProps], iTmpEnt, g_iCurEntities);
					else
						PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropUnlimitedAdmin", g_Cfg_sPropNames[_iType], iTmpEnt, g_iCurEntities);
				}
				else
				{
					if(g_Access[client][iTotalProps])
						PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropLimited", g_Cfg_sPropNames[_iType], (g_Access[client][iTotalProps] - g_iPlayerProps[client]), g_Access[client][iTotalProps]);
					else
						PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropUnlimited", g_Cfg_sPropNames[_iType]);
				}
			}
		}
	}
}

SpawnChat(client, type)
{
	decl Float:fOrigin[3], Float:fAngles[3], Float:fNormal[3];
	GetClientEyePosition(client, fOrigin);
	GetClientEyeAngles(client, fAngles);
	TR_TraceRayFilter(fOrigin, fAngles, MASK_SOLID, RayType_Infinite, Tracer_FilterBlocks, client);
	if(TR_DidHit(INVALID_HANDLE))
	{
		fAngles[0] = 0.0;
		fAngles[1] += 90.0;
		TR_GetEndPosition(fOrigin, INVALID_HANDLE);

		new iZone = -1;
		if((iZone = GetBlockedZone(fOrigin)) != -1)
		{
			if(g_iCurrentTime > g_iLastDrawTime[client] || g_iLastDrawZone[client] != iZone)
			{
				g_iLastDrawZone[client] = iZone;
				g_iLastDrawTime[client] = g_iCurrentTime + 5;
				DrawMapZone(iZone, client);
			}

			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatWarningProximitySpawn");
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatWarningProximitySpawn");
			#endif
		}
		else
		{
			TR_GetPlaneNormal(INVALID_HANDLE, fNormal);
			decl Float:fVectorAngles[3];
			GetVectorAngles(fNormal, fVectorAngles);
			fVectorAngles[0] += 90.0;
			decl Float:_fCross[3], Float:_fTempAngles[3], Float:_fTempAngles2[3];
			GetAngleVectors(fAngles, _fTempAngles, NULL_VECTOR, NULL_VECTOR);
			_fTempAngles[2] = 0.0;
			GetAngleVectors(fVectorAngles, _fTempAngles2, NULL_VECTOR, NULL_VECTOR);
			GetVectorCrossProduct(_fTempAngles, fNormal, _fCross);
			new Float:_fYaw = GetAngleBetweenVectors(_fTempAngles2, _fCross, fNormal);
			RotateYaw(fVectorAngles, _fYaw);
			for(new i = 0; i <= 2; i++)
				fVectorAngles[i] = GetCleanAngle(float(RoundToNearest(fVectorAngles[i] / g_Cfg_fDefinedRotations[g_iPlayerRotation[client]])) * g_Cfg_fDefinedRotations[g_iPlayerRotation[client]]);

			GetCleanVector(fOrigin);
			new iEnt = Entity_SpawnProp(client, type, fOrigin, fVectorAngles);
			Entity_ColorProp(client, iEnt);
			if(g_fProximityDelay && Bool_PlayerProximity(client, fOrigin, iEnt))
			{
				g_iPropState[iEnt] |= STATE_PHASE;
				SetPropColorAlpha(iEnt, ALPHA_PROP_PHASED);
				SetEntProp(iEnt, Prop_Data, "m_CollisionGroup", 1);

				g_hPropPhase[iEnt] = CreateTimer(g_fProximityDelay, Timer_PhaseProp, iEnt, TIMER_FLAG_NO_MAPCHANGE);
			}
			PushArrayCell(g_hArray_PlayerProps[client], iEnt);
			g_iPlayerProps[client]++;

			switch(g_iCurrentTeam[client])
			{
				case CS_TEAM_T:
					g_iPointsRed += POINTS_BUILD;
				case CS_TEAM_CT:
					g_iPointsBlue += POINTS_BUILD;
			}

			if(g_bAdvancingTeam && g_iDebugMode != MODE_BUILD && g_iCurrentTeam[client] == g_iAdvancingTeam)
			{
				if(g_Access[client][bAdmin])
				{
					if(g_Access[client][iTotalPropsAdvance])
						PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropLimitedAdmin", g_Cfg_sPropNames[type], (g_Access[client][iTotalPropsAdvance] - g_iPlayerProps[client]), g_Access[client][iTotalPropsAdvance], iEnt, g_iCurEntities);
					else
						PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropUnlimitedAdmin", g_Cfg_sPropNames[type], iEnt, g_iCurEntities);
				}
				else
				{
					if(g_Access[client][iTotalPropsAdvance])
						PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropLimited", g_Cfg_sPropNames[type], (g_Access[client][iTotalPropsAdvance] - g_iPlayerProps[client]), g_Access[client][iTotalPropsAdvance]);
					else
						PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropUnlimited", g_Cfg_sPropNames[type]);
				}
			}
			else
			{
				if(g_Access[client][bAdmin])
				{
					if(g_Access[client][iTotalProps])
						PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropLimitedAdmin", g_Cfg_sPropNames[type], (g_Access[client][iTotalProps] - g_iPlayerProps[client]), g_Access[client][iTotalProps], iEnt, g_iCurEntities);
					else
						PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropUnlimitedAdmin", g_Cfg_sPropNames[type], iEnt, g_iCurEntities);
				}
				else
				{
					if(g_Access[client][iTotalProps])
						PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropLimited", g_Cfg_sPropNames[type], (g_Access[client][iTotalProps] - g_iPlayerProps[client]), g_Access[client][iTotalProps]);
					else
						PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserSpawnPropUnlimited", g_Cfg_sPropNames[type]);
				}

			}
		}
	}
}

DeleteProp(client, iEnt = 0)
{
	new iTmpEnt = (iEnt > 0) ? iEnt : Trace_GetEntity(client);
	if(Entity_Valid(iTmpEnt))
	{
		new iOwner = GetClientOfUserId(g_iPropUser[iTmpEnt]);
		if(!iOwner)
		{
			if(g_Access[client][bAccessAdminDelete] || CheckCommandAccess(client, "Bw_Access_Delete", ADMFLAG_RCON))
				Entity_DeleteProp(iTmpEnt);
			else
				PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserDeletePropWarningOwner", g_Cfg_sPropNames[g_iPropType[iTmpEnt]], g_sPropOwner[iTmpEnt]);
		}
		else
		{
			switch(g_iCurrentTeam[iOwner])
			{
				case CS_TEAM_T:
					g_iPointsRed += POINTS_DELETE;
				case CS_TEAM_CT:
					g_iPointsBlue += POINTS_DELETE;
			}

			if(g_Access[client][iTotalDeletes] && g_iPlayerDeletes[client] >= g_Access[client][iTotalDeletes])
			{
				#if defined _colors_included
				CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserDeletePropWarningLimit");
				#else
				PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserDeletePropWarningLimit");
				#endif
			}
			else
			{
				if(iOwner == client)
				{
					if(g_Access[client][iTotalDeletes])
						PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserDeletePropLimited", g_Cfg_sPropNames[g_iPropType[iTmpEnt]], (g_Access[client][iTotalDeletes] - (g_iPlayerDeletes[client] + 1)), g_Access[client][iTotalDeletes]);
					else
						PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserDeletePropUnlimited", g_Cfg_sPropNames[g_iPropType[iTmpEnt]]);

					if(g_iPropState[iTmpEnt] & STATE_SAVED)
					{
						#if defined _colors_included
						CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserDeletePropWarningSave", g_Cfg_sPropNames[g_iPropType[iTmpEnt]]);
						#else
						PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserDeletePropWarningSave", g_Cfg_sPropNames[g_iPropType[iTmpEnt]]);
						#endif
					}
					else if(g_iPropState[iTmpEnt] & STATE_DELETED)
					{
						#if defined _colors_included
						CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserDeletePropWarningPending", g_Cfg_sPropNames[g_iPropType[iTmpEnt]]);
						#else
						PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserDeletePropWarningPending", g_Cfg_sPropNames[g_iPropType[iTmpEnt]]);
						#endif
					}
					else
					{
						if((!g_iDeleteNotify || g_iDeleteNotify & g_iPhase) && g_fDeleteDelay > 1.0)
						{
							SetPropColorAlpha(iTmpEnt, ALPHA_PROP_DELETED);

							g_fPropDelete[iTmpEnt] = 0.0;
							g_iPropState[iTmpEnt] |= STATE_DELETED;
							g_hPropDelete[iTmpEnt] = CreateTimer(1.0, Timer_DeleteNotify, iTmpEnt, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
						}
						else
							DeleteClientProp(client, iTmpEnt);
					}
				}
				else if(g_Access[client][bAdmin])
				{
					PrintHintText(client, "%t%t", "prefixHintMessage", "chatNotifyUserDeletePropAdmin", g_Cfg_sPropNames[g_iPropType[iTmpEnt]], g_sName[iOwner]);

					if(g_iPropState[iTmpEnt] & STATE_SAVED)
					{
						#if defined _colors_included
						CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserDeletePropWarningSave", g_Cfg_sPropNames[g_iPropType[iTmpEnt]]);
						#else
						PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserDeletePropWarningSave", g_Cfg_sPropNames[g_iPropType[iTmpEnt]]);
						#endif
					}
					else
						DeleteClientProp(iOwner, iTmpEnt);
				}
				else
					PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserDeletePropWarningOwner", g_Cfg_sPropNames[g_iPropType[iTmpEnt]], g_sPropOwner[iTmpEnt]);
			}
		}
	}
}

public Action:Timer_GimpExpire(Handle:timer, any:client)
{
	g_hTimer_ExpireGimp[client] = INVALID_HANDLE;

	if(IsClientInGame(client))
	{
		g_iPlayerGimp[client] = 0;
		SetClientCookie(client, g_cCookieGimp, "0");

		#if defined _colors_included
		CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserGimpExpire");
		#else
		PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserGimpExpire");
		#endif
	}
}

Array_Push(client, team)
{
	switch(team)
	{
		case CS_TEAM_T:
		{
			PushArrayCell(g_hArray_RedPlayers, client);
			g_iPlayersRed++;
		}
		case CS_TEAM_CT:
		{
			PushArrayCell(g_hArray_BluePlayers, client);
			g_iPlayersBlue++;
		}
	}
}

Array_Empty(team)
{
	switch(team)
	{
		case CS_TEAM_T:
		{
			ClearArray(g_hArray_RedPlayers);
			g_iPlayersRed = 0;
		}
		case CS_TEAM_CT:
		{
			ClearArray(g_hArray_BluePlayers);
			g_iPlayersBlue = 0;
		}
	}
}

Array_Grab(team, index)
{
	switch(team)
	{
		case CS_TEAM_T:
			return GetArrayCell(g_hArray_RedPlayers, index);
		case CS_TEAM_CT:
			return GetArrayCell(g_hArray_BluePlayers, index);
	}

	return 0;
}

Array_Index(client, team)
{
	switch(team)
	{
		case CS_TEAM_T:
			return FindValueInArray(g_hArray_RedPlayers, client);
		case CS_TEAM_CT:
			return FindValueInArray(g_hArray_BluePlayers, client);
	}

	return 0;
}

Array_Remove(index, team)
{
	switch(team)
	{
		case CS_TEAM_T:
		{
			RemoveFromArray(g_hArray_RedPlayers, index);
			g_iPlayersRed--;
		}
		case CS_TEAM_CT:
		{
			RemoveFromArray(g_hArray_BluePlayers, index);
			g_iPlayersBlue--;
		}
	}
}

Switch(client, team)
{
	if(client > 0 && IsClientInGame(client) && g_iCurrentTeam[client] != team)
	{
		if(g_bAlive[client] && g_iCurrentTeam[client] == CS_TEAM_T)
		{
			new iEnt = GetPlayerWeaponSlot(client, CS_SLOT_C4);
			if(iEnt > 0)
			{
				RemovePlayerItem(client, iEnt);
				AcceptEntityInput(iEnt, "Kill");
			}
		}

		CS_SwitchTeam(client, team);
	}
}

ToggleRadar(client, status)
{
	switch(status)
	{
		case STATE_DISABLE:
		{
			SetEntDataFloat(client, g_iFlashDuration, 3600.0, true);
			SetEntDataFloat(client, g_iFlashAlpha, 0.5, true);
		}
		case STATE_ENABLE:
		{
			SetEntDataFloat(client, g_iFlashDuration, 0.5, true);
			SetEntDataFloat(client, g_iFlashAlpha, 0.5, true);
		}
	}
}

public Action:Timer_FlashEnd(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(IsClientInGame(client) && g_iCurrentTeam[client] >= CS_TEAM_T)
		if(g_iDisableRadar && g_iDisableRadar & g_iPhase && !(g_Access[client][bAccessRadar]))
			ToggleRadar(client, STATE_DISABLE);
}

public Action:Timer_AfkAutoSpec(Handle:timer, any:client)
{
	g_hTimer_AfkCheck[client] = INVALID_HANDLE;

	if(client > 0 && IsClientInGame(client) && !g_iCurrentTeam[client])
	{
		ChangeClientTeam(client, CS_TEAM_SPECTATOR);

		if(!g_Access[client][bAfkImmunity])
		{
			g_bAfk[client] = true;
			g_fAfkRemaining[client] = g_fAfkSpecKickDelay;
			g_hTimer_AfkCheck[client] = CreateTimer(1.0, Timer_SpecNotify, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action:Timer_CheckAfk(Handle:timer, any:client)
{
	g_hTimer_AfkCheck[client] = INVALID_HANDLE;
	if(client > 0 && IsClientInGame(client))
	{
		if(!g_bActivity[client])
		{
			ChangeClientTeam(client, CS_TEAM_SPECTATOR);

			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyAfkMove");
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyAfkMove");
			#endif

			if(g_bAfkAutoKick && !g_Access[client][bAfkImmunity])
			{
				g_bAfk[client] = true;
				g_fAfkRemaining[client] = g_fAfkAutoDelay;

				if(g_hTimer_AfkCheck[client] != INVALID_HANDLE)
					CloseHandle(g_hTimer_AfkCheck[client]);
				g_hTimer_AfkCheck[client] = CreateTimer(1.0, Timer_AfkNotify, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}

public Action:Timer_AfkNotify(Handle:timer, any:client)
{
	if(client > 0 && IsClientInGame(client))
	{
		g_fAfkRemaining[client] -= 1.0;
		if(g_fAfkRemaining[client] > 0.0)
		{
			if(g_bGlobalOffensive)
				PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyAfkPendingKick", g_fAfkRemaining[client]);
			else
				PrintCenterText(client, "%t%t", "prefixCenterMessage", "hintNotifyAfkPendingKick", g_fAfkRemaining[client]);
			return Plugin_Continue;
		}
		else
			KickClient(client, "%t", "hintNotifyAfkKickReason");
	}

	g_hTimer_AfkCheck[client] = INVALID_HANDLE;
	return Plugin_Stop;
}

public Action:Timer_SpecNotify(Handle:timer, any:client)
{
	if(client > 0 && IsClientInGame(client))
	{
		g_fAfkRemaining[client] -= 1.0;
		if(g_fAfkRemaining[client] > 0.0)
		{
			if(g_bGlobalOffensive)
				PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyAfkPendingKickSpec", g_fAfkRemaining[client]);
			else
				PrintCenterText(client, "%t%t", "prefixCenterMessage", "hintNotifyAfkPendingKickSpec", g_fAfkRemaining[client]);
			return Plugin_Continue;
		}
		else
			KickClient(client, "%t", "hintNotifyAfkKickReasonSpec");
	}

	g_hTimer_AfkCheck[client] = INVALID_HANDLE;
	return Plugin_Stop;
}

bool:Bool_DeleteAllowed(client, bool:_bMessage = false, bool:_bClear = false)
{
	if(!g_Access[client][iTotalDeletes])
		return true;
	else
	{
		if(_bClear)
		{
			if((g_iPlayerDeletes[client] + g_iPlayerProps[client]) < g_Access[client][iTotalDeletes])
				return true;
			else if(_bMessage)
			{
				#if defined _colors_included
				CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserClearPropWarningLimit");
				#else
				PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserClearPropWarningLimit");
				#endif
			}
		}
		else
		{
			if(g_iPlayerDeletes[client] < g_Access[client][iTotalDeletes])
				return true;
			else if(_bMessage)
			{
				#if defined _colors_included
				CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserDeletePropWarningLimit");
				#else
				PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserDeletePropWarningLimit");
				#endif
			}
		}
	}

	return false;
}

bool:Bool_DeleteValid(client, bool:_bMessage = false)
{
	if(g_bEnding || !g_bAlive[client] && !g_Access[client][bAdmin] || !CheckTeamAccess(client, g_iCurrentTeam[client], true))
		return false;
	else if(g_iCurrentDisable & (g_Access[client][bAdmin] ? DISABLE_ADMIN_DELETE : DISABLE_DELETE))
	{
		if(_bMessage)
		{
			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserDeleteRestricted");
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserDeleteRestricted");
			#endif
		}

		return false;
	}

	return true;
}

bool:Bool_ClearValid(client, bool:_bMessage = false)
{
	if(g_bEnding || !g_bAlive[client] && !g_Access[client][bAdmin] || !CheckTeamAccess(client, g_iCurrentTeam[client], true))
		return false;
	else if(g_iCurrentDisable & (g_Access[client][bAdmin] ? DISABLE_ADMIN_CLEAR : DISABLE_CLEAR))
	{
		if(_bMessage)
		{
			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserClearRestricted");
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserClearRestricted");
			#endif
		}

		return false;
	}

	return true;
}

bool:Bool_SpawnAllowed(client, bool:_bMessage = false)
{
	if(g_Access[client][bAccessProp])
	{
		if(g_bAdvancingTeam && g_iDebugMode != MODE_BUILD && g_iCurrentTeam[client] == g_iAdvancingTeam)
		{
			if(!g_Access[client][iTotalPropsAdvance])
				return true;
			else if(g_iPlayerProps[client] < g_Access[client][iTotalPropsAdvance])
				return true;
			else if(_bMessage)
			{
				#if defined _colors_included
				CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserSpawnPropWarningLimit");
				#else
				PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserSpawnPropWarningLimit");
				#endif
			}
		}
		else
		{
			if(!g_Access[client][iTotalProps])
				return true;
			else if(g_iPlayerProps[client] < g_Access[client][iTotalProps])
				return true;
			else if(_bMessage)
			{
				#if defined _colors_included
				CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserSpawnPropWarningLimit");
				#else
				PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserSpawnPropWarningLimit");
				#endif
			}
		}
	}

	return false;
}

bool:Bool_SpawnValid(client, bool:_bMessage = false, bool:_bEntity = false)
{
	if(_bEntity && g_iCurEntities >= g_iMaximumEntities)
	{
		if(_bMessage)
		{
			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatWarningEntityLimit", g_iCurEntities, g_iMaximumEntities);
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatWarningEntityLimit", g_iCurEntities, g_iMaximumEntities);
			#endif
		}

		return false;
	}

	if(g_bEnding || !g_bAlive[client] && !g_Access[client][bAdmin] || !CheckTeamAccess(client, g_iCurrentTeam[client], true))
		return false;
	else if(g_iCurrentDisable & (g_Access[client][bAdmin] ? DISABLE_ADMIN_SPAWN : DISABLE_SPAWN))
	{
		if(_bMessage)
		{
			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserPropRestricted");
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserPropRestricted");
			#endif
		}

		return false;
	}

	return true;
}

bool:Bool_PlayerProximity(client, Float:fOrigin[3], iEnt)
{
	decl Float:_fTemp[3];
	for(new i = 1; i <= MaxClients; i++)
	{
		if(i != client && g_bAlive[i] && g_iCurrentTeam[i] == g_iCurrentTeam[client] && IsClientInGame(i))
		{
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", _fTemp);
			if(Bool_CheckProximity(fOrigin, _fTemp, g_Cfg_fPropRadius[g_iPropType[iEnt]], true))
				return true;
		}
	}

	return false;
}

bool:Bool_RotateValid(client, bool:_bMessage = false)
{
	if(g_bEnding || !g_iCfg_TotalRotations || !g_bAlive[client] && !g_Access[client][bAdmin] || !CheckTeamAccess(client, g_iCurrentTeam[client], true))
		return false;
	else if(g_iCurrentDisable & (g_Access[client][bAdmin] ? DISABLE_ADMIN_ROTATE : DISABLE_ROTATE))
	{
		if(_bMessage)
		{
			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserRotateRestricted");
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserRotateRestricted");
			#endif
		}

		return false;
	}

	return true;
}

bool:Bool_MoveValid(client, bool:_bMessage = false)
{
	if(g_bEnding || !g_iCfg_TotalPositions || !g_bAlive[client] && !g_Access[client][bAdmin] || !CheckTeamAccess(client, g_iCurrentTeam[client], true))
		return false;
	else if(g_iCurrentDisable & (g_Access[client][bAdmin] ? DISABLE_ADMIN_MOVE : DISABLE_MOVE))
	{
		if(_bMessage)
		{
			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserPositionRestricted");
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserPositionRestricted");
			#endif
		}

		return false;
	}
	return true;
}

bool:Bool_PhaseValid(client, bool:_bMessage = false)
{
	if(g_bEnding || !g_bAlive[client] && !g_Access[client][bAdmin] || !CheckTeamAccess(client, g_iCurrentTeam[client], true))
		return false;
	else if(g_iCurrentDisable & (g_Access[client][bAdmin] ? DISABLE_ADMIN_PHASE : DISABLE_PHASE))
	{
		if(_bMessage)
		{
			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserPhaseRestricted");
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserPhaseRestricted");
			#endif
		}

		return false;
	}
	return true;
}

bool:Bool_ControlValid(client, bool:_bMessage = false)
{
	if(g_bEnding || !g_bAlive[client] && !g_Access[client][bAdmin] || !CheckTeamAccess(client, g_iCurrentTeam[client], true))
		return false;
	else if(g_iCurrentDisable & (g_Access[client][bAdmin] ? DISABLE_ADMIN_CONTROL : DISABLE_CONTROL))
	{
		if(_bMessage)
		{
			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserControlRestricted");
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserControlRestricted");
			#endif
		}

		return false;
	}

	return true;
}

bool:Bool_CheckValid(client, bool:_bMessage = false)
{
	if(g_bEnding || !CheckTeamAccess(client, g_iCurrentTeam[client]))
		return false;
	else if(g_iCurrentDisable & (g_Access[client][bAdmin] ? DISABLE_ADMIN_CHECK : DISABLE_CHECK))
	{
		if(_bMessage)
		{
			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserCheckRestricted");
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserCheckRestricted");
			#endif
		}

		return false;
	}

	return true;
}

bool:Bool_TeleportAllowed(client, bool:_bMessage = false)
{
	if(g_bTeleporting[client])
	{
		if(_bMessage)
		{
			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserTeleportWarningPending");
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserTeleportWarningPending");
			#endif
		}

		return false;
	}

	if(!g_Access[client][iTotalTeleports])
		return true;
	else if(g_iPlayerTeleports[client] < g_Access[client][iTotalTeleports])
		return true;
	else if(_bMessage)
	{
		#if defined _colors_included
		CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserTeleportWarningLimit");
		#else
		PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserTeleportWarningLimit");
		#endif
	}

	return false;
}

bool:Bool_TeleportValid(client, bool:_bMessage = false)
{
	if(g_bEnding || !g_bAlive[client] || g_bTeleporting[client] || !CheckTeamAccess(client, g_iCurrentTeam[client]))
		return false;
	else if(g_iCurrentDisable & (g_Access[client][bAdmin] ? DISABLE_ADMIN_TELE : DISABLE_TELE))
	{
		if(_bMessage)
		{
			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserTeleportRestricted");
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserTeleportRestricted");
			#endif
		}

		return false;
	}

	return true;
}

bool:Bool_ColorAllowed(client, bool:_bMessage = false)
{
	if(g_Access[client][bAccessColor])
	{
		if(!g_Access[client][iTotalColors])
			return true;
		else if(g_iPlayerColors[client] < g_Access[client][iTotalColors])
			return true;
		else if(_bMessage)
		{
			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserColorWarningLimit");
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserColorWarningLimit");
			#endif
		}
	}

	return false;
}

bool:Bool_ColorValid(client, bool:_bMessage = false)
{
	if(g_bEnding || !g_bAlive[client] && !g_Access[client][bAdmin] || !CheckTeamAccess(client, g_iCurrentTeam[client], true))
		return false;
	else if(g_iCurrentDisable & (g_Access[client][bAdmin] ? DISABLE_ADMIN_COLOR : DISABLE_COLOR))
	{
		if(_bMessage)
		{
			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserColorRestricted");
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserColorRestricted");
			#endif
		}

		return false;
	}

	return true;
}

Define_Settings()
{
	decl String:sPath[PLATFORM_MAX_PATH], String:sBuffer[64];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/buildwars/buildwars.settings.cfg");

	new iTemp, Handle:hKeyValues = CreateKeyValues("BuildWars_Settings");
	if(!FileToKeyValues(hKeyValues, sPath) || !KvGotoFirstSubKey(hKeyValues))
		SetFailState("BuildWars: Could not either locate or parse \"configs/buildwars/buildwars.settings.cfg\"");
	else
	{
		do
		{
			KvGetSectionName(hKeyValues, sPath, sizeof(sPath));
			if(StrEqual(sPath, "Rotations", false))
			{
				g_iCfg_TotalRotations = 0;
				g_iCfg_DefaultRotation = -1;

				KvGotoFirstSubKey(hKeyValues, false);
				do
				{
					KvGetSectionName(hKeyValues, sBuffer, sizeof(sBuffer));
					g_Cfg_fDefinedRotations[g_iCfg_TotalRotations] = StringToFloat(sBuffer);
					if((iTemp = KvGetNum(hKeyValues, NULL_STRING, 0)))
						g_iCfg_DefaultRotation = iTemp;

					g_iCfg_TotalRotations++;
				}
				while (KvGotoNextKey(hKeyValues, false));
				if(g_iCfg_DefaultRotation == -1)
					g_iCfg_DefaultRotation = GetRandomInt(0, (g_iCfg_TotalRotations - 1));

				KvGoBack(hKeyValues);
			}
			else if(StrEqual(sPath, "Positions", false))
			{
				g_iCfg_TotalPositions = 0;
				g_iCfg_DefaultPosition = -1;

				KvGotoFirstSubKey(hKeyValues, false);
				do
				{
					KvGetSectionName(hKeyValues, sBuffer, sizeof(sBuffer));
					g_Cfg_fDefinedPositions[g_iCfg_TotalPositions] = StringToFloat(sBuffer);
					if((iTemp = KvGetNum(hKeyValues, NULL_STRING, 0)))
						g_iCfg_DefaultPosition = iTemp;

					g_iCfg_TotalPositions++;
				}
				while (KvGotoNextKey(hKeyValues, false));
				if(g_iCfg_DefaultPosition == -1)
					g_iCfg_DefaultPosition = GetRandomInt(0, (g_iCfg_TotalPositions - 1));

				KvGoBack(hKeyValues);
			}
			else if(StrEqual(sPath, "Commands", false))
			{
				ClearTrie(g_hTrie_CfgDefinedCmds);

				KvGotoFirstSubKey(hKeyValues, false);
				do
				{
					KvGetSectionName(hKeyValues, sBuffer, sizeof(sBuffer));
					iTemp = KvGetNum(hKeyValues, NULL_STRING, 0);
					if(!StrContains(sBuffer, "sm_"))
					{
						strcopy(sPath, sizeof(sPath), sBuffer);
						ReplaceString(sPath, sizeof(sPath), "sm_", "!", false);
						SetTrieValue(g_hTrie_CfgDefinedCmds, sPath, iTemp);

						strcopy(sPath, sizeof(sPath), sBuffer);
						ReplaceString(sPath, sizeof(sPath), "sm_", "/", false);
						SetTrieValue(g_hTrie_CfgDefinedCmds, sPath, iTemp);
					}
					else
						SetTrieValue(g_hTrie_CfgDefinedCmds, sBuffer, iTemp);
				}
				while (KvGotoNextKey(hKeyValues, false));

				KvGoBack(hKeyValues);
			}
			else if(StrEqual(sPath, "Durations", false))
			{
				g_iCfg_TotalDurations = 0;

				KvGotoFirstSubKey(hKeyValues, false);
				do
				{
					KvGetSectionName(hKeyValues, g_Cfg_sGimpDisplays[g_iCfg_TotalDurations], sizeof(g_Cfg_sGimpDisplays[]));
					g_iCfg_GimpDurations[g_iCfg_TotalDurations] = KvGetNum(hKeyValues, NULL_STRING);

					g_iCfg_TotalDurations++;
				}
				while (KvGotoNextKey(hKeyValues, false));

				KvGoBack(hKeyValues);
			}
			else if(StrEqual(sPath, "Walls", false))
			{
				KvGotoFirstSubKey(hKeyValues, false);
				do
				{
					KvGetSectionName(hKeyValues, sBuffer, sizeof(sBuffer));
					SetTrieValue(g_hTrie_CfgWalls, sBuffer, 1);

					g_iCfg_TotalDurations++;
				}
				while (KvGotoNextKey(hKeyValues, false));

				KvGoBack(hKeyValues);
			}
		}
		while (KvGotoNextKey(hKeyValues));

		CloseHandle(hKeyValues);
	}
}

Define_Convars()
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/buildwars/buildwars.%s.convars.ini", g_bGlobalOffensive ? "csgo" : "css");

	if(g_hArray_CvarHandles == INVALID_HANDLE)
		g_hArray_CvarHandles = CreateArray(2);
	else
	{
		new iMax = GetArraySize(g_hArray_CvarHandles);
		for(new i = 0; i < iMax; i++)
		{
			new Handle:hTemp = Handle:GetArrayCell(g_hArray_CvarHandles, i, 0);
			CloseHandle(hTemp);
		}

		ClearArray(g_hArray_CvarHandles);
	}

	if(g_hArray_CvarProtected == INVALID_HANDLE)
		g_hArray_CvarProtected = CreateArray(13);
	else
		ClearArray(g_hArray_CvarProtected);

	if(g_hArray_CvarOriginal == INVALID_HANDLE)
		g_hArray_CvarOriginal = CreateArray(16);
	else
		ClearArray(g_hArray_CvarOriginal);

	if(g_hArray_CvarValues == INVALID_HANDLE)
		g_hArray_CvarValues = CreateArray(16);
	else
		ClearArray(g_hArray_CvarValues);

	new Handle:hKeyValues = CreateKeyValues("BuildWars_Convars");
	KvSetEscapeSequences(hKeyValues, true);
	if(FileToKeyValues(hKeyValues, sPath) && KvGotoFirstSubKey(hKeyValues))
	{
		new String:sBuffer[48], String:sValue[48], String:sTemp[48], Float:fBuffer, iBuffer;

		KvGotoFirstSubKey(hKeyValues, false);
		do
		{
			KvGetSectionName(hKeyValues, sBuffer, sizeof(sBuffer));
			new Handle:hTemp = FindConVar(sBuffer);
			if(hTemp != INVALID_HANDLE)
			{
				HookConVarChange(hTemp, OnRestrictChange);

				new iSize = GetArraySize(g_hArray_CvarProtected);
				ResizeArray(g_hArray_CvarProtected, iSize + 1);
				ResizeArray(g_hArray_CvarHandles, iSize + 1);
				ResizeArray(g_hArray_CvarOriginal, iSize + 1);
				ResizeArray(g_hArray_CvarValues, iSize + 1);

				SetArrayString(g_hArray_CvarProtected, iSize, sBuffer);

				KvGetString(hKeyValues, NULL_STRING, sTemp, sizeof(sTemp));
				if(StrContains(sTemp, ".") != -1)
				{
					SetArrayCell(g_hArray_CvarHandles, iSize, hTemp, 0);
					SetArrayCell(g_hArray_CvarHandles, iSize, cCastFloat, 1);

					KvGetString(hKeyValues, NULL_STRING, sValue, sizeof(sValue));
					fBuffer = StringToFloat(sValue);
					SetArrayCell(g_hArray_CvarValues, iSize, fBuffer);

					SetArrayCell(g_hArray_CvarProtected, iSize, cCastFloat, 12);
					SetArrayCell(g_hArray_CvarOriginal, iSize, GetConVarFloat(hTemp));

					if(g_iDebugMode != MODE_NORMAL)
						LogToFile(g_sPluginLog, "Defining.Float %s - Setting to %f", sBuffer, fBuffer);

					SetConVarFloat(hTemp, fBuffer);
				}
				else if(IsCharNumeric(sTemp[0]))
				{
					SetArrayCell(g_hArray_CvarHandles, iSize, hTemp, 0);
					SetArrayCell(g_hArray_CvarHandles, iSize, cCastInteger, 1);

					KvGetString(hKeyValues, NULL_STRING, sValue, sizeof(sValue));
					iBuffer = StringToInt(sValue);
					SetArrayCell(g_hArray_CvarValues, iSize, iBuffer);

					SetArrayCell(g_hArray_CvarProtected, iSize, cCastInteger, 12);
					SetArrayCell(g_hArray_CvarOriginal, iSize, GetConVarInt(hTemp));

					if(g_iDebugMode != MODE_NORMAL)
						LogToFile(g_sPluginLog, "Defining.Int %s - Setting to %d", sBuffer, iBuffer);

					SetConVarInt(hTemp, iBuffer);
				}
				else
				{
					SetArrayCell(g_hArray_CvarHandles, iSize, hTemp, 0);
					SetArrayCell(g_hArray_CvarHandles, iSize, cCastString, 1);

					KvGetString(hKeyValues, NULL_STRING, sValue, sizeof(sValue));
					SetArrayString(g_hArray_CvarValues, iSize, sValue);

					SetArrayCell(g_hArray_CvarProtected, iSize, cCastString, 12);
					SetArrayString(g_hArray_CvarOriginal, iSize, sValue);

					if(g_iDebugMode != MODE_NORMAL)
						LogToFile(g_sPluginLog, "Defining.String %s - Setting to %s", sBuffer, sValue);

					SetConVarString(hTemp, sValue);
				}
			}
		}
		while(KvGotoNextKey(hKeyValues, false));

		return true;
	}
	else
	{
		CloseHandle(hKeyValues);
		SetFailState("BuildWars: Could not locate \"configs/buildwars/buildwars.%s.convars.ini\"", g_bGlobalOffensive ? "csgo" : "css");
	}

	return false;
}

public OnRestrictChange(Handle:cvar, const String:oldvalue[], const String:newvalue[])
{
	decl String:sBuffer[64];
	new Float:fBuffer, iBuffer;
	new iSize = GetArraySize(g_hArray_CvarHandles);
	for(new i = 0; i < iSize; i++)
	{
		new Handle:hTemp = GetArrayCell(g_hArray_CvarHandles, i, 0);
		if(hTemp == cvar)
		{
			GetArrayString(g_hArray_CvarProtected, i, sBuffer, sizeof(sBuffer));
			if(g_iDebugMode != MODE_NORMAL)
				LogToFile(g_sPluginLog, "OnRestrictChange %s - Old:%s New:%s", sBuffer, oldvalue, newvalue);

			switch(GetArrayCell(g_hArray_CvarHandles, i, 1))
			{
				case cCastFloat:
				{
					fBuffer = Float:GetArrayCell(g_hArray_CvarValues, i);
					if(fBuffer != StringToFloat(newvalue))
					{
						if(g_iDebugMode != MODE_NORMAL)
							LogToFile(g_sPluginLog, "OnRestrictChange.Float %s - Reverting to %f", sBuffer, fBuffer);

						SetConVarFloat(hTemp, fBuffer);
					}
				}
				case cCastInteger:
				{
					iBuffer = GetArrayCell(g_hArray_CvarValues, i);
					if(iBuffer != StringToInt(newvalue))
					{
						if(g_iDebugMode != MODE_NORMAL)
							LogToFile(g_sPluginLog, "OnRestrictChange.Int %s - Reverting to %d", sBuffer, iBuffer);

						SetConVarInt(hTemp, iBuffer);
					}
				}
				case cCastString:
				{
					decl String:sValue[64];
					GetArrayString(g_hArray_CvarValues, i, sValue, sizeof(sValue));
					if(!StrEqual(sValue, sBuffer))
					{
						if(g_iDebugMode != MODE_NORMAL)
							LogToFile(g_sPluginLog, "OnRestrictChange.String %s - Reverting to %s", sBuffer, sValue);

						SetConVarString(hTemp, sValue);
					}
				}
			}

			break;
		}
	}
}

Define_Props()
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/buildwars/buildwars.%s.props.ini",g_bGlobalOffensive ? "csgo" : "css");

	for(new i = 0; i < g_iNumProps; i++)
		g_Cfg_iBaseToPropType[i] = 0;

	g_iNumProps = 0;
	new Handle:hKeyValues = CreateKeyValues("BuildWars_Props");
	if(FileToKeyValues(hKeyValues, sPath))
	{
		decl String:sBuffer[32];
		new String:_sArray[4][8];
		KvGotoFirstSubKey(hKeyValues);
		do
		{
			KvGetSectionName(hKeyValues, g_Cfg_sPropNames[g_iNumProps], sizeof(g_Cfg_sPropNames[]));
			KvGetString(hKeyValues, "path", g_Cfg_sPropPaths[g_iNumProps], sizeof(g_Cfg_sPropPaths[]));
			PrecacheModel(g_Cfg_sPropPaths[g_iNumProps]);

			g_Cfg_iBaseToPropType[KvGetNum(hKeyValues, "index")] = g_iNumProps;
			g_Cfg_iPropTypeToBase[g_iNumProps] = KvGetNum(hKeyValues, "index");
			g_Cfg_iPropTypes[g_iNumProps] = KvGetNum(hKeyValues, "type");
			g_Cfg_fPropRadius[g_iNumProps] = KvGetFloat(hKeyValues, "radius");
			g_Cfg_bPropAlpha[g_iNumProps] = KvGetNum(hKeyValues, "alpha") ? true : false;
			g_Cfg_iPropAccess[g_iNumProps] = KvGetNum(hKeyValues, "access");

			KvGetString(hKeyValues, "health", sBuffer, sizeof(sBuffer));
			ExplodeString(sBuffer, ",", _sArray, 4, 8);
			for(new i = 0; i <= 3; i++)
				g_Cfg_iPropHealth[g_iNumProps][i] = StringToInt(_sArray[i]);

			g_iNumProps++;
		}
		while (KvGotoNextKey(hKeyValues));
		CloseHandle(hKeyValues);
	}
	else
	{
		CloseHandle(hKeyValues);
		SetFailState("BuildWars: Could not locate \"configs/buildwars/buildwars.%s.props.ini\"", g_bGlobalOffensive ? "csgo" : "css");
	}
}

Define_Colors()
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/buildwars/buildwars.%s.colors.ini", g_bGlobalOffensive ? "csgo" : "css");

	g_iNumColors = 0;
	new Handle:hKeyValues = CreateKeyValues("BuildWars_Colors");
	if(FileToKeyValues(hKeyValues, sPath))
	{
		decl String:sTemp[64], String:sColors[4][4];
		KvGotoFirstSubKey(hKeyValues);
		do
		{
			KvGetSectionName(hKeyValues, g_Cfg_sColorNames[g_iNumColors], 64);
			g_Cfg_iColorAccess[g_iNumColors] = KvGetNum(hKeyValues, "access");

			KvGetString(hKeyValues, "colors", sTemp, sizeof(sTemp));
			ExplodeString(sTemp, " ", sColors, 4, 4);
			for(new i = 0; i <= 3; i++)
				g_Cfg_iColorArrays[g_iNumColors][i] = StringToInt(sColors[i]);

			g_iNumColors++;
		}
		while (KvGotoNextKey(hKeyValues));
		CloseHandle(hKeyValues);
	}
	else
	{
		CloseHandle(hKeyValues);
		SetFailState("BuildWars: Could not locate \"configs/buildwars/buildwars.%s.colors.ini\"", g_bGlobalOffensive ? "csgo" : "css");
	}
}

Define_Modes()
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/buildwars/buildwars.%s.modes.ini", g_bGlobalOffensive ? "csgo" : "css");

	g_iNumModes = 0;
	new Handle:hKeyValues = CreateKeyValues("BuildWars_Modes");
	if(FileToKeyValues(hKeyValues, sPath))
	{
		KvGotoFirstSubKey(hKeyValues);
		do
		{
			KvGetSectionName(hKeyValues, g_Cfg_sModes[g_iNumModes], 192);
			KvGetString(hKeyValues, "chat", g_Cfg_sModesChat[g_iNumModes], 192);
			g_Cfg_bModeChat[g_iNumModes] = !(StrEqual(g_Cfg_sModesChat[g_iNumModes], "")) ? true : false;
			KvGetString(hKeyValues, "center", g_Cfg_sModesCenter[g_iNumModes], 192);
			g_Cfg_bModeCenter[g_iNumModes] = !(StrEqual(g_Cfg_sModesCenter[g_iNumModes], "")) ? true : false;
			g_Cfg_iModeDuration[g_iNumModes] = KvGetNum(hKeyValues, "duration");
			g_Cfg_iModeMethod[g_iNumModes] = KvGetNum(hKeyValues, "method");
			KvGetString(hKeyValues, "start", g_Cfg_sModesStart[g_iNumModes], 512);
			KvGetString(hKeyValues, "end", g_Cfg_sModesEnd[g_iNumModes], 512);
			g_iNumModes++;
		}
		while (KvGotoNextKey(hKeyValues));
		CloseHandle(hKeyValues);
	}
	else
	{
		CloseHandle(hKeyValues);
		SetFailState("BuildWars: Could not locate \"configs/buildwars/buildwars.%s.modes.ini\"", g_bGlobalOffensive ? "csgo" : "css");
	}
}

Define_Configs()
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/buildwars/buildwars.access.cfg");

	g_iCfg_TotalAccess = 0;
	new Handle:hKeyValues = CreateKeyValues("BuildWars_Access");
	if(FileToKeyValues(hKeyValues, sPath))
	{
		decl String:sTemp[64];
		KvGotoFirstSubKey(hKeyValues);
		do
		{
			g_iAccessIdens[g_iCfg_TotalAccess] = KvGetNum(hKeyValues, "iden", 0);
			KvGetString(hKeyValues, "override", g_sAccessOverrides[g_iCfg_TotalAccess], sizeof(g_sAccessOverrides[]));
			KvGetString(hKeyValues, "flags", sTemp, sizeof(sTemp));
			g_iAccessFlags[g_iCfg_TotalAccess] = ReadFlagString(sTemp);

			g_bAccessAdmin[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "admin", 0);
			g_bAccessImmunity[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "afk_kick_immunity", 0);
			g_bAccessMove[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_move", 0);
			g_bAccessRotate[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_rotate", 0);
			g_bAccessCheck[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_check", 0);
			g_bAccessControl[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_control", 0);
			g_bAccessCrouch[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_crouch", 0);
			g_bAccessRadar[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_radar", 0);
			g_bAccessCustom[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_custom", 0);
			g_bAccessSpec[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_spec", 0);
			g_bAccessThird[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_third", 0);
			g_bAccessFly[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_fly", 0);
			g_bAccessPhase[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_phase", 0);
			g_bAccessProp[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_prop", 0);
			g_bAccessDelete[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_delete", 0);
			g_bAccessClear[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_clear", 0);
			g_bAccessTeleport[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_stuck", 0);
			g_bAccessColor[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_color", 0);
			g_bAccessBase[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_base", 0);
			g_bAccessSettings[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_client_menu", 0);
			g_bAccessAdminMenu[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_admin_menu", 0);
			g_bAccessAdminGimp[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_admin_gimp", 0);
			g_bAccessAdminDelete[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_admin_delete", 0);
			g_bAccessAdminClear[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_admin_clear", 0);
			g_bAccessAdminStuck[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_admin_stuck", 0);
			g_bAccessAdminColor[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_admin_color", 0);
			g_bAccessAdminBase[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_admin_base", 0);
			g_bAccessAdminTarget[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_admin_target", 0);
			g_bAccessAdminZone[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_admin_zone", 0);
			g_bAccessExplosives[g_iCfg_TotalAccess] = bool:KvGetNum(hKeyValues, "access_explosives", 0);

			g_iAccessTotalProps[g_iCfg_TotalAccess] = KvGetNum(hKeyValues, "total_prop", 0);
			g_iAccessTotalAdvanceProps[g_iCfg_TotalAccess] = KvGetNum(hKeyValues, "total_prop_adv", 0);
			g_iAccessTotalDeletes[g_iCfg_TotalAccess] = KvGetNum(hKeyValues, "total_delete", 0);
			g_iAccessTotalTeleports[g_iCfg_TotalAccess] = KvGetNum(hKeyValues, "total_stuck", 0);
			g_iAccessTotalColors[g_iCfg_TotalAccess] = KvGetNum(hKeyValues, "total_color", 0);
			g_iAccessTotalBases[g_iCfg_TotalAccess] = KvGetNum(hKeyValues, "total_base", 0);
			g_iAccessTotalBaseProps[g_iCfg_TotalAccess] = KvGetNum(hKeyValues, "base_props", 0);
			g_fAccessStuckDelay[g_iCfg_TotalAccess] = KvGetFloat(hKeyValues, "stuck_delay", 0.0);

			g_iCfg_TotalAccess++;
		}
		while (KvGotoNextKey(hKeyValues));
		CloseHandle(hKeyValues);
	}
	else
	{
		CloseHandle(hKeyValues);
		SetFailState("BuildWars: Could not locate \"configs/buildwars/buildwars.%s.configs.ini\"", g_bGlobalOffensive ? "csgo" : "css");
	}
}

public SQL_Connect_Database(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	ErrorCheck(owner, error, "SQL_Connect_Database.Owner");
	ErrorCheck(hndl, error, "SQL_Connect_Database.Handle");

	g_hSql_Database = hndl;
	decl String:sDriver[16];
	SQL_GetDriverIdent(owner, sDriver, sizeof(sDriver));

	g_iSqlLoadStep = 0;
	g_bSql = StrEqual(sDriver, "mysql", false);

	if(g_bSql)
	{
		SQL_TQuery(g_hSql_Database, CallBack_Names, "SET NAMES 'utf8'", _, DBPrio_High);

		SQL_TQuery(g_hSql_Database, CallBack_CreateBases, "CREATE TABLE IF NOT EXISTS `buildwars_bases` (`base_index` INTEGER PRIMARY KEY AUTO_INCREMENT NOT NULL default 1, `base_count` int(6) NOT NULL default 0, `steamid` varchar(32) NOT NULL default '')");
		SQL_TQuery(g_hSql_Database, CallBack_CreateProps, "CREATE TABLE IF NOT EXISTS `buildwars_props` (`prop_index` INTEGER PRIMARY KEY AUTO_INCREMENT NOT NULL default 1, `prop_base` int(6) NOT NULL default 0, `prop_type` int(6) NOT NULL default 0, `pos_x` float(6) NOT NULL default 0.0, `pos_y` float(6) NOT NULL default 0.0, `pos_z` float(6) NOT NULL default 0.0, `ang_x` float(6) NOT NULL default 0.0, `ang_y` float(6) NOT NULL default 0.0, `ang_z` float(6) NOT NULL default 0.0, `steamid` varchar(32) NOT NULL default '')");
		SQL_TQuery(g_hSql_Database, CallBack_CreateZones, "CREATE TABLE IF NOT EXISTS `buildwars_zones` (`id` int(11) NOT NULL AUTO_INCREMENT, `type` int(11) NOT NULL, `point1_x` float NOT NULL, `point1_y` float NOT NULL, `point1_z` float NOT NULL, `point2_x` float NOT NULL, `point2_y` float NOT NULL, `point2_z` float NOT NULL, `map` varchar(32) NOT NULL, PRIMARY KEY (`id`));");
		SQL_TQuery(g_hSql_Database, CallBack_CreateMaps, "CREATE TABLE IF NOT EXISTS `buildwars_maps` (`map` varchar(256) NOT NULL PRIMARY KEY, `wall` varchar(256) NOT NULL default '', `played` int(11) NOT NULL);", DBPrio_High);
	}
	else
	{
		SQL_TQuery(g_hSql_Database, CallBack_CreateBases, "CREATE TABLE IF NOT EXISTS `buildwars_bases` (`base_index` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL default 1, `base_count` INTEGER NOT NULL default 0, `steamid` varchar(32) NOT NULL default '');");
		SQL_TQuery(g_hSql_Database, CallBack_CreateProps, "CREATE TABLE IF NOT EXISTS `buildwars_props` (`prop_index` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL default 1, `prop_base` INTEGER NOT NULL default 0, `prop_type` INTEGER NOT NULL default 0, `pos_x` float NOT NULL default 0.0, `pos_y` float NOT NULL default 0.0, `pos_z` float NOT NULL default 0.0, `ang_x` float NOT NULL default 0.0, `ang_y` float NOT NULL default 0.0, `ang_z` float NOT NULL default 0.0, `steamid` varchar(32) NOT NULL default '')");
		SQL_TQuery(g_hSql_Database, CallBack_CreateZones, "CREATE TABLE IF NOT EXISTS `buildwars_zones` (`id` INTEGER PRIMARY KEY, `type` INTEGER NOT NULL, `point1_x` float NOT NULL, `point1_y` float NOT NULL, `point1_z` float NOT NULL, `point2_x` float NOT NULL, `point2_y` float NOT NULL, `point2_z` float NOT NULL, `map` varchar(32) NOT NULL);");
		SQL_TQuery(g_hSql_Database, CallBack_CreateMaps, "CREATE TABLE IF NOT EXISTS `buildwars_maps` (`map` varchar(256) NOT NULL PRIMARY KEY, `wall` varchar(256) NOT NULL default '', `played` INTEGER NOT NULL);", DBPrio_High);
	}
}

public CallBack_CreateMaps(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	ErrorCheck(hndl, error, "CallBack_CreateMaps");

	Define_Walls();
}

Define_Walls()
{
	decl String:sQuery[384];
	Format(sQuery, sizeof(sQuery), "SELECT `wall` FROM `buildwars_maps` WHERE `map` = '%s'", g_sCurrentMap, DBPrio_High);
	SQL_TQuery(g_hSql_Database, CallBack_MapConnect, sQuery);
}

public CallBack_MapConnect(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	ErrorCheck(owner, error, "CallBack_MapConnect");

	decl String:sQuery[384];
	if(hndl == INVALID_HANDLE || !SQL_GetRowCount(hndl))
	{
		Format(sQuery, sizeof(sQuery), "INSERT INTO `buildwars_maps` (`map`,`wall`,`played`) VALUES ('%s', '', 0)", g_sCurrentMap, DBPrio_High);
		SQL_TQuery(g_hSql_Database, CallBack_MapConnect, sQuery);
	}
	else if(SQL_FetchRow(hndl))
	{
		g_bMapDataLoaded = true;

		SQL_FetchString(hndl, 0, g_sWallData, sizeof(g_sWallData));
		if(StrEqual(g_sWallData, "") || !g_iBuildDuration)
		{
			g_bLegacyPhaseFighting = false;
			g_iCurrentDisable = g_iLegacyDisable;

			FowardPhaseChange(PHASE_LEGACY);
		}
		else
		{
			g_iCurrentDisable = g_iBuildDisable;

			FowardPhaseChange(PHASE_BUILD);
			DetectWallEntities();
		}

		Format(sQuery, sizeof(sQuery), "UPDATE `buildwars_maps` SET `played` = `played` + 1 WHERE map = '%s'", g_sCurrentMap);
		SQL_TQuery(g_hSql_Database, CallBack_MapUpdate, sQuery);
	}
}

public CallBack_Names(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	ErrorCheck(hndl, error, "CallBack_Names");
}

public CallBack_MapUpdate(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	ErrorCheck(owner, error, "CallBack_MapUpdate");
}

public CallBack_CreateProps(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	ErrorCheck(hndl, error, "CallBack_CreateProps");

	g_iSqlLoadStep++;
	if(g_iSqlLoadStep == 2 && g_bLateQuery)
	{
		for(new i = 1; i <= MaxClients; i++)
			if(IsClientInGame(i) && g_Access[i][bAccessBase])
				LoadClientBase(i);

		g_bLateQuery = false;
	}
}

public CallBack_CreateBases(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	ErrorCheck(hndl, error, "CallBack_CreateBases");

	g_iSqlLoadStep++;
	if(g_iSqlLoadStep == 2 && g_bLateQuery)
	{
		for(new i = 1; i <= MaxClients; i++)
			if(IsClientInGame(i) && g_Access[i][bAccessBase])
				LoadClientBase(i);

		g_bLateQuery = false;
	}
}

public CallBack_CreateZones(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	ErrorCheck(hndl, error, "CallBack_CreateZones");

	Define_Zones();
}

public SQL_QueryBaseLoad(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogToFile(g_sPluginLog, "SQL_QueryBaseLoad Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 && IsClientInGame(client))
		{
			decl String:_sQuery[256];
			new _iRows = SQL_GetRowCount(hndl);
			if(_iRows < g_Access[client][iTotalBases])
			{
				Format(_sQuery, sizeof(_sQuery), g_sSQL_BaseCreate, g_sAuthString[client]);
				SQL_TQuery(g_hSql_Database, SQL_QueryBaseCreate, _sQuery, userid);
			}
			else
			{
				if(g_Access[client][iTotalBases] == 1)
					g_iPlayerBaseCurrent[client] = 0;

				for(new i = 0; i < g_Access[client][iTotalBases]; i++)
				{
					SQL_FetchRow(hndl);
					g_iPlayerBase[client][i] = SQL_FetchInt(hndl, 0);
					g_iPlayerBaseCount[client][i] = SQL_FetchInt(hndl, 1);
					Format(_sQuery, sizeof(_sQuery), g_sSQL_PropCheck, g_iPlayerBase[client][i]);
					SQL_TQuery(g_hSql_Database, SQL_QueryPropCheck, _sQuery, userid);
				}
			}
		}
	}
}

public SQL_QueryPropCheck(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogToFile(g_sPluginLog, "SQL_QueryPropCheck Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 && IsClientInGame(client))
		{
			decl String:_sQuery[256];
			new _iCount = SQL_GetRowCount(hndl);
			if(_iCount != g_iPlayerBaseCount[client][g_iPlayerBaseLoading[client]])
			{
				g_iPlayerBaseQuery[client] += 1;
				g_iPlayerBaseCount[client][g_iPlayerBaseLoading[client]] = _iCount;

				Format(_sQuery, sizeof(_sQuery), g_sSQL_BaseUpdate, _iCount, g_iPlayerBase[client][g_iPlayerBaseLoading[client]]);
				SQL_TQuery(g_hSql_Database, SQL_QueryBaseUpdate, _sQuery, userid);
			}

			g_iPlayerBaseLoading[client]++;
			if(g_iPlayerBaseLoading[client] == g_Access[client][iTotalBases] && g_iPlayerBaseMenu[client] != -1)
			{
				QueryBuildMenu(client, MENU_BASE_MAIN);
				g_iPlayerBaseMenu[client] = -1;
			}
		}
	}
}

public SQL_QueryBaseCreate(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogToFile(g_sPluginLog, "SQL_QueryBaseCreate Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 && IsClientInGame(client))
		{
			decl String:_sQuery[256];
			Format(_sQuery, sizeof(_sQuery), g_sSQL_BaseLoad, g_sAuthString[client]);
			SQL_TQuery(g_hSql_Database, SQL_QueryBaseLoad, _sQuery, userid);
		}
	}
}

public SQL_QueryPropSaveMass(Handle:owner, Handle:hndl, const String:error[], any:ref)
{
	if(hndl == INVALID_HANDLE)
		LogToFile(g_sPluginLog, "SQL_QueryPropSave Error: %s", error);
	else
	{
		new iEnt = EntRefToEntIndex(ref);
		if(iEnt != INVALID_ENT_REFERENCE)
		{
			g_iPropState[iEnt] &= ~STATE_SAVED;
			g_iPropState[iEnt] |= STATE_BASE;
			g_iBaseIndex[iEnt] = SQL_GetInsertId(owner);

			new client = GetClientOfUserId(g_iPropUser[iEnt]);
			if(client > 0 && IsClientInGame(client))
			{
				g_iPlayerBaseQuery[client] -= 1;
				if(g_iPlayerBaseQuery[client] <= 0)
				{
					if(!g_iPlayerBaseFailed[client])
					{
						#if defined _colors_included
						CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSaveAllSuccess", g_sBaseNames[g_iPlayerBaseCurrent[client]]);
						#else
						PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSaveAllSuccess", g_sBaseNames[g_iPlayerBaseCurrent[client]]);
						#endif
					}
					else
					{
						#if defined _colors_included
						CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSaveAllFailed", g_sBaseNames[g_iPlayerBaseCurrent[client]], g_iPlayerBaseFailed[client]);
						#else
						PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSaveAllFailed", g_sBaseNames[g_iPlayerBaseCurrent[client]], g_iPlayerBaseFailed[client]);
						#endif
						g_iPlayerBaseFailed[client] = 0;
					}

					if(g_iPlayerBaseMenu[client] != -1)
					{
						QueryBuildMenu(client, MENU_BASE_MAIN);
						g_iPlayerBaseMenu[client] = -1;
					}
				}

				g_iPlayerBaseCount[client][g_iPlayerBaseCurrent[client]]++;
			}

			SetPropColor(iEnt, GetPropColor(iEnt));
		}
	}
}

public SQL_QueryPropSaveSingle(Handle:owner, Handle:hndl, const String:error[], any:ref)
{
	if(hndl == INVALID_HANDLE)
		LogToFile(g_sPluginLog, "SQL_QueryPropSave Error: %s", error);
	else
	{
		new iEnt = EntRefToEntIndex(ref);
		if(iEnt != INVALID_ENT_REFERENCE)
		{
			new _iTemp = g_iBaseIndex[iEnt];
			g_iPropState[iEnt] &= ~STATE_SAVED;
			g_iPropState[iEnt] |= STATE_BASE;
			g_iBaseIndex[iEnt] = SQL_GetInsertId(owner);

			new client = GetClientOfUserId(g_iPropUser[iEnt]);
			if(client > 0 && IsClientInGame(client))
			{
				g_iPlayerBaseQuery[client] -= 1;
				if(g_iPlayerBaseQuery[client] <= 0)
				{
					#if defined _colors_included
					CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSavePropSuccess", g_Cfg_sPropNames[g_iPropType[iEnt]], g_sBaseNames[g_iPlayerBaseCurrent[client]]);
					#else
					PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSavePropSuccess", g_Cfg_sPropNames[g_iPropType[iEnt]], g_sBaseNames[g_iPlayerBaseCurrent[client]]);
					#endif

					if(g_iPlayerBaseMenu[client] != -1)
					{
						QueryBuildMenu(client, MENU_BASE_MAIN);
						g_iPlayerBaseMenu[client] = -1;
					}
				}

				if(g_iBaseIndex[iEnt] != _iTemp)
					g_iPlayerBaseCount[client][g_iPlayerBaseCurrent[client]]++;
			}

			SetPropColor(iEnt, GetPropColor(iEnt));
		}
	}
}

public SQL_QueryPropDelete(Handle:owner, Handle:hndl, const String:error[], any:ref)
{
	if(hndl == INVALID_HANDLE)
		LogToFile(g_sPluginLog, "SQL_QueryPropDelete Error: %s", error);
	else
	{
		new iEnt = EntRefToEntIndex(ref);
		if(iEnt != INVALID_ENT_REFERENCE)
		{
			g_iPropState[iEnt] &= ~STATE_BASE;
			g_iBaseIndex[iEnt] = -1;

			new client = GetClientOfUserId(g_iPropUser[iEnt]);
			if(client > 0 && IsClientInGame(client))
			{
				g_iPlayerBaseQuery[client] -= 1;
				g_iPlayerBaseCount[client][g_iPlayerBaseCurrent[client]]--;
				if(g_iPlayerBaseQuery[client] <= 0)
				{
					#if defined _colors_included
					CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserBaseDeletePropSuccess", g_Cfg_sPropNames[g_iPropType[iEnt]], g_sBaseNames[g_iPlayerBaseCurrent[client]]);
					#else
					PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserBaseDeletePropSuccess", g_Cfg_sPropNames[g_iPropType[iEnt]], g_sBaseNames[g_iPlayerBaseCurrent[client]]);
					#endif

					if(g_iPlayerBaseMenu[client] != -1)
					{
						QueryBuildMenu(client, MENU_BASE_MAIN);
						g_iPlayerBaseMenu[client] = -1;
					}
				}
			}
		}
	}
}

public SQL_QueryBaseEmpty(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogToFile(g_sPluginLog, "SQL_QueryBaseEmpty Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 && IsClientInGame(client))
		{
			g_iPlayerBaseQuery[client] -= 1;
			g_iPlayerBaseCount[client][g_iPlayerBaseCurrent[client]] = 0;
			if(g_iPlayerBaseQuery[client] <= 0)
			{
				#if defined _colors_included
				CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserBaseDeleteAllSuccess", g_sBaseNames[g_iPlayerBaseCurrent[client]]);
				#else
				PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserBaseDeleteAllSuccess", g_sBaseNames[g_iPlayerBaseCurrent[client]]);
				#endif

				if(g_iPlayerBaseMenu[client] != -1)
				{
					QueryBuildMenu(client, MENU_BASE_MAIN);
					g_iPlayerBaseMenu[client] = -1;
				}
			}
		}
	}
}

public SQL_QueryBaseReadySave(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogToFile(g_sPluginLog, "SQL_QueryBaseReadySave Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 &&  IsClientInGame(client))
		{
			g_iPlayerBaseCount[client][g_iPlayerBaseCurrent[client]] = 0;

			new iSize = (GetArraySize(g_hArray_PlayerProps[client]) - 1);
			new Float:_fSaveDelay = 0.1;
			g_iPlayerBaseQuery[client] -= 1;
			g_bPlayerBaseSpawned[client] = true;

			for(new i = iSize; i >= 0; i--)
			{
				new iEnt = GetArrayCell(g_hArray_PlayerProps[client], i);
				if(IsValidEntity(iEnt))
				{
					SetPropColor(iEnt, {0, 0, 0, ALPHA_PROP_SAVED, -1, -1});

					g_iPropState[iEnt] |= STATE_SAVED;
					g_iPlayerBaseQuery[client] += 1;

					new Handle:hPack = INVALID_HANDLE;
					CreateDataTimer(_fSaveDelay, Timer_SaveBaseProps, hPack);
					WritePackCell(hPack, client);
					WritePackCell(hPack, iEnt);
					_fSaveDelay += 0.01;
				}
			}
		}
	}
}

public SQL_QueryBaseUpdate(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogToFile(g_sPluginLog, "SQL_QueryBaseUpdate Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 && IsClientInGame(client))
		{
			g_iPlayerBaseQuery[client] -= 1;
			if(g_iPlayerBaseQuery[client] <= 0 && g_iPlayerBaseMenu[client] != -1)
			{
				QueryBuildMenu(client, MENU_BASE_MAIN);
				g_iPlayerBaseMenu[client] = -1;
			}
		}
	}
}

public SQL_QueryBaseUpdatePost(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogToFile(g_sPluginLog, "SQL_QueryBaseUpdate Error: %s", error);
}

public SQL_QueryPropLoad(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogToFile(g_sPluginLog, "SQL_QueryPropLoad Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 && IsClientInGame(client))
		{
			new Float:_fSpawnDelay = 0.1;
			decl Float:fOrigin[3];
			while (SQL_FetchRow(hndl))
			{
				new Handle:hPack = INVALID_HANDLE;
				CreateDataTimer(_fSpawnDelay, Timer_SpawnBaseProps, hPack);
				WritePackCell(hPack, client);

				WritePackCell(hPack, SQL_FetchInt(hndl, 0));
				WritePackCell(hPack, g_Cfg_iBaseToPropType[SQL_FetchInt(hndl, 1)]);

				fOrigin[0] = SQL_FetchFloat(hndl, 2);
				fOrigin[1] = SQL_FetchFloat(hndl, 3);
				fOrigin[2] = SQL_FetchFloat(hndl, 4);
				AddVectors(fOrigin, g_fPlayerBasePosition[client], fOrigin);
				WritePackFloat(hPack, fOrigin[0]);
				WritePackFloat(hPack, fOrigin[1]);
				WritePackFloat(hPack, fOrigin[2]);

				WritePackFloat(hPack, SQL_FetchFloat(hndl, 5));
				WritePackFloat(hPack, (SQL_FetchFloat(hndl, 6) + 180.0));
				WritePackFloat(hPack, SQL_FetchFloat(hndl, 7));
				_fSpawnDelay += 0.025;
			}
		}
	}
}

public Action:Timer_SpawnBaseProps(Handle:timer, Handle:pack)
{
	decl Float:fOrigin[3], Float:fAngles[3];

	ResetPack(pack);
	new client = ReadPackCell(pack);
	new iIndex = ReadPackCell(pack);
	new _iType = ReadPackCell(pack);
	for(new i = 0; i <= 2; i++)
		fOrigin[i] = ReadPackFloat(pack);

	if(GetBlockedZone(fOrigin) != -1)
		g_iPlayerBaseQuery[client] -= 1;
	else
	{
		for(new i = 0; i <= 2; i++)
			fAngles[i] = ReadPackFloat(pack);

		new iEnt = Entity_SpawnBase(client, _iType, fOrigin, fAngles, iIndex);
		if(g_bBaseColors)
		{
			g_iPropColor[iEnt] = g_iBaseColors;
			SetPropColor(iEnt, g_iBaseColors, true);
		}
		else
			Entity_ColorProp(client, iEnt);
		if(g_fPhaseDelay)
		{
			g_iPropState[iEnt] |= STATE_PHASE;
			SetPropColorAlpha(iEnt, ALPHA_PROP_PHASED);
			SetEntProp(iEnt, Prop_Data, "m_CollisionGroup", 1);

			g_hPropPhase[iEnt] = CreateTimer(g_fPhaseDelay, Timer_PhaseProp, iEnt, TIMER_FLAG_NO_MAPCHANGE);
		}

		PushArrayCell(g_hArray_PlayerProps[client], iEnt);
		g_iPlayerProps[client]++;

		switch(g_iCurrentTeam[client])
		{
			case CS_TEAM_T:
				g_iPointsRed += POINTS_BUILD;
			case CS_TEAM_CT:
				g_iPointsBlue += POINTS_BUILD;
		}

		g_iPlayerBaseQuery[client] -= 1;
		if(g_iPlayerBaseQuery[client] <= 0)
		{
			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSpawn", g_sBaseNames[g_iPlayerBaseCurrent[client]]);
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSpawn", g_sBaseNames[g_iPlayerBaseCurrent[client]]);
			#endif

			if(g_iPlayerBaseMenu[client] != -1)
			{
				QueryBuildMenu(client, MENU_BASE_MAIN);
				g_iPlayerBaseMenu[client] = -1;
			}
		}
	}
}

QueryBuildMenu(client, menu)
{
	if(g_iPlayerBaseLoading[client] < g_Access[client][iTotalBases])
	{
		decl String:sBuffer[192];
		new Handle:hMenu = CreateMenu(MenuHandler_BaseLoading);
		SetMenuTitle(hMenu, g_sTitle);
		SetMenuExitButton(hMenu, true);
		SetMenuExitBackButton(hMenu, true);

		Format(sBuffer, sizeof(sBuffer), "%T", "MenuEntryBaseLoading", client);
		AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);

		Format(sBuffer, sizeof(sBuffer), "%T", "MenuEntryBaseWaiting", client);
		AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);

		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	}
	else if(g_iPlayerBaseQuery[client] > 0)
	{
		decl String:sBuffer[192];
		new Handle:hMenu = CreateMenu(MenuHandler_BaseQuery);
		SetMenuTitle(hMenu, g_sTitle);
		SetMenuExitButton(hMenu, true);
		SetMenuExitBackButton(hMenu, true);

		Format(sBuffer, sizeof(sBuffer), "%T", "MenuEntryBaseQuerying", client);
		AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);

		Format(sBuffer, sizeof(sBuffer), "%T", "MenuEntryBaseQueryWaiting", client);
		AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);

		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	}
	else
	{
		if(g_iPlayerBaseQuery[client] < 0)
			g_iPlayerBaseQuery[client] = 0;

		switch(menu)
		{
			case MENU_BASE_LEGACY:
			{
				#if defined _colors_included
				CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserBaseQuery");
				#else
				PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserBaseQuery");
				#endif
			}
			case MENU_BASE_MAIN:
			{
				Menu_BaseActions(client);
			}
			case MENU_BASE_MOVE:
			{
				Menu_BaseMove(client);
			}
			case MENU_BASE_ACTIVE:
			{
				Menu_BaseActivate(client);
			}
		}
	}
}

Menu_BaseActions(client)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client]))
		return;

	decl String:sBuffer[128];
	decl String:sBaseName[128];

	new Handle:hMenu = CreateMenu(MenuHandler_BaseActions);
	SetMenuTitle(hMenu, g_sTitle);
	if(g_bGlobalOffensive)
	{
		SetMenuPagination(hMenu, MENU_NO_PAGINATION);
		SetMenuExitButton(hMenu, true);
	}
	else
	{
		SetMenuExitButton(hMenu, true);
		SetMenuExitBackButton(hMenu, true);
	}

	if(g_iPlayerBaseCurrent[client] == -1)
	{
		Format(sBaseName, sizeof(sBaseName), "%T", "menuEntryBaseDefaultName", client);
		
		Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryBaseActivate", client);
		AddMenuItem(hMenu, "0", sBuffer);
	}
	else
	{
		Format(sBaseName, sizeof(sBaseName), "%s", g_sBaseNames[g_iPlayerBaseCurrent[client]]);
	
		Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryBaseCurrent", client, sBaseName, g_iPlayerBaseCount[client][g_iPlayerBaseCurrent[client]], g_Access[client][iTotalBaseProps]);
		AddMenuItem(hMenu, "0", sBuffer);
	}

	if(!g_bGlobalOffensive)
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "menuOptionSpacerSelection", client);
		if(!StrEqual(sBuffer, ""))
			AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
	}

	new iCurrentState = (g_iPlayerBaseCurrent[client] == -1) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
	if(g_bCurrentSave[client])
	{
		if(!g_bGlobalOffensive)
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryBaseSaveUpdate", client);
			AddMenuItem(hMenu, "2", sBuffer, iCurrentState);
		}
	
		Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryBaseSaveRemove", client);
		AddMenuItem(hMenu, "1", sBuffer, iCurrentState);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryBaseSavePlace", client);
		AddMenuItem(hMenu, "2", sBuffer, iCurrentState);
	}

	if(!g_bPlayerBaseSpawned[client])
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "MenuEntryBasePlace", client, sBaseName);
		AddMenuItem(hMenu, "3", sBuffer, iCurrentState);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "MenuEntryBaseClear", client, sBaseName);
		AddMenuItem(hMenu, "4", sBuffer, iCurrentState);
	}

	Format(sBuffer, sizeof(sBuffer), "%T", "MenuEntryBaseSaveAll", client, sBaseName);
	AddMenuItem(hMenu, "5", sBuffer, g_bCurrentSave[client] ? iCurrentState : ITEMDRAW_DISABLED);

	Format(sBuffer, sizeof(sBuffer), "%T", "MenuEntryBaseSaveTarget", client, sBaseName);
	AddMenuItem(hMenu, "6", sBuffer, g_bCurrentSave[client] ? iCurrentState : ITEMDRAW_DISABLED);

	Format(sBuffer, sizeof(sBuffer), "%T", "MenuEntryBaseDeleteTarget", client, sBaseName);
	AddMenuItem(hMenu, "7", sBuffer, g_bPlayerBaseSpawned[client] ? iCurrentState : ITEMDRAW_DISABLED);

	/*
	if(g_Access[client][bAccessMove])
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "MenuEntryBaseMoveAll", client, sBaseName);
		AddMenuItem(hMenu, "9", sBuffer, iCurrentState);
	}
	*/

	Format(sBuffer, sizeof(sBuffer), "%T", "MenuEntryBaseEmpty", client, sBaseName);
	AddMenuItem(hMenu, "8", sBuffer, iCurrentState);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_BaseActions(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Main(param1);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1]))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);
			new iMenuOption = StringToInt(sOption);

			switch(iMenuOption)
			{
				case 0:
				{
					g_iPlayerBaseMenu[param1] = MENU_BASE_ACTIVE;
					
					Menu_BaseActivate(param1);
				}
				case 1:
				{
					g_iPlayerBaseMenu[param1] = MENU_BASE_MAIN;
					
					if(!g_bEnding)
					{
						g_bCurrentSave[param1] = false;
						if(g_hTimer_CurrentSave[param1] != INVALID_HANDLE && CloseHandle(g_hTimer_CurrentSave[param1]))
							g_hTimer_CurrentSave[param1] = INVALID_HANDLE;

						#if defined _colors_included
						CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseLocationClear");
						#else
						PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseLocationClear");
						#endif
					}

					QueryBuildMenu(param1, MENU_BASE_MAIN);
				}
				case 2:
				{
					g_iPlayerBaseMenu[param1] = MENU_BASE_MAIN;
					
					if(!g_bEnding)
					{
						decl Float:fDestination[3], Float:fOrigin[3], Float:fAngles[3];
						GetClientAbsOrigin(param1, fOrigin);
						GetClientEyePosition(param1, fDestination);
						GetClientEyeAngles(param1, fAngles);

						TR_TraceRayFilter(fDestination, fAngles, MASK_SOLID, RayType_Infinite, Tracer_FilterPlayers, param1);
						if(TR_DidHit(INVALID_HANDLE))
						{
							TR_GetEndPosition(g_fCurrentSavePos[param1], INVALID_HANDLE);
							for(new i = 0; i <= 2; i++)
								g_fCurrentSavePos[param1][i] = float(RoundToNearest(g_fCurrentSavePos[param1][i]));

							if(g_bCurrentSave[param1])
							{
								#if defined _colors_included
								CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseLocationUpdate");
								#else
								PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseLocationUpdate");
								#endif
								CloseHandle(g_hTimer_CurrentSave[param1]);
							}
							else
							{
								#if defined _colors_included
								CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseLocationPlaced");
								#else
								PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseLocationPlaced");
								#endif
								g_bCurrentSave[param1] = true;
							}

							DisplaySaveLocation(param1);
							g_hTimer_CurrentSave[param1] = CreateTimer(1.0, Timer_DisplaySaveLocation, param1, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
						}
					}

					QueryBuildMenu(param1, MENU_BASE_MAIN);
				}
				case 3:
				{
					g_iPlayerBaseMenu[param1] = MENU_BASE_MAIN;
					
					if(!g_bEnding)
					{
						new _iCurrent = g_iPlayerProps[param1];
						if(!g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]])
						{
							#if defined _colors_included
							CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSpawnEmpty", g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
							#else
							PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSpawnEmpty", g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
							#endif

							QueryBuildMenu(param1, MENU_BASE_MAIN);
							return;
						}

						if(g_bAdvancingTeam && g_iDebugMode != MODE_BUILD && g_iCurrentTeam[param1] == g_iAdvancingTeam)
						{
							if(g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]] <= g_Access[param1][iTotalPropsAdvance])
							{
								if((g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]] + _iCurrent) > g_Access[param1][iTotalPropsAdvance])
								{
									new _iTemp = (g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]] + _iCurrent) - g_Access[param1][iTotalPropsAdvance];

									#if defined _colors_included
									CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSpawnInsufficient", g_sBaseNames[g_iPlayerBaseCurrent[param1]], _iTemp);
									#else
									PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSpawnInsufficient", g_sBaseNames[g_iPlayerBaseCurrent[param1]], _iTemp);
									#endif

									QueryBuildMenu(param1, MENU_BASE_MAIN);
									return;
								}
							}
						}
						else
						{
							if(g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]] <= g_Access[param1][iTotalProps])
							{
								if((g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]] + _iCurrent) > g_Access[param1][iTotalProps])
								{
									new _iTemp = (g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]] + _iCurrent) - g_Access[param1][iTotalProps];

									#if defined _colors_included
									CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSpawnInsufficient", g_sBaseNames[g_iPlayerBaseCurrent[param1]], _iTemp);
									#else
									PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSpawnInsufficient", g_sBaseNames[g_iPlayerBaseCurrent[param1]], _iTemp);
									#endif

									QueryBuildMenu(param1, MENU_BASE_MAIN);
									return;
								}
							}
						}

						if(Bool_SpawnAllowed(param1, true) && Bool_SpawnValid(param1, true, true))
						{
							decl Float:fDestination[3], Float:fOrigin[3], Float:fAngles[3];
							GetClientAbsOrigin(param1, fOrigin);
							GetClientEyePosition(param1, fDestination);
							GetClientEyeAngles(param1, fAngles);

							TR_TraceRayFilter(fDestination, fAngles, MASK_SOLID, RayType_Infinite, Tracer_FilterPlayers, param1);
							if(TR_DidHit(INVALID_HANDLE))
							{
								TR_GetEndPosition(g_fPlayerBasePosition[param1], INVALID_HANDLE);

								new iZone = -1;
								if((iZone = GetBlockedZone(g_fPlayerBasePosition[param1])) != -1)
								{
									if(g_iCurrentTime > g_iLastDrawTime[param1] || g_iLastDrawZone[param1] != iZone)
									{
										g_iLastDrawZone[param1] = iZone;
										g_iLastDrawTime[param1] = g_iCurrentTime + 5;
										DrawMapZone(iZone, param1);
									}

									#if defined _colors_included
									CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatWarningProximityBase");
									#else
									PrintToChat(param1, "%t%t", "prefixChatMessage", "chatWarningProximityBase");
									#endif
								}
								else
								{
									for(new i = 0; i <= 2; i++)
										g_fPlayerBasePosition[param1][i] = float(RoundToNearest(g_fPlayerBasePosition[param1][i]));

									g_fCurrentSavePos[param1] = g_fPlayerBasePosition[param1];
									if(!g_bCurrentSave[param1])
										g_bCurrentSave[param1] = true;
									else
										CloseHandle(g_hTimer_CurrentSave[param1]);

									DisplaySaveLocation(param1);
									g_hTimer_CurrentSave[param1] = CreateTimer(1.0, Timer_DisplaySaveLocation, param1, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

									g_bPlayerBaseSpawned[param1] = true;
									g_iPlayerBaseQuery[param1] += g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]];

									decl String:_sQuery[256];
									Format(_sQuery, sizeof(_sQuery), g_sSQL_PropLoad, g_iPlayerBase[param1][g_iPlayerBaseCurrent[param1]]);
									SQL_TQuery(g_hSql_Database, SQL_QueryPropLoad, _sQuery, GetClientUserId(param1));
								}
							}
						}
					}

					QueryBuildMenu(param1, MENU_BASE_MAIN);
				}
				case 4:
				{
					g_iPlayerBaseMenu[param1] = MENU_BASE_MAIN;
					
					if(!g_bEnding)
					{
						if(g_bPlayerBaseSpawned[param1] && Bool_DeleteValid(param1, true))
						{
							g_bPlayerBaseSpawned[param1] = false;

							new Float:_fWriteDelay = 0.1;
							new _iDeleted, _iArraySize = (GetArraySize(g_hArray_PlayerProps[param1]) - 1);
							for(new i = _iArraySize; i >= 0; i--)
							{
								new iEnt = GetArrayCell(g_hArray_PlayerProps[param1], i);
								if(IsValidEntity(iEnt) && g_iPropState[iEnt] & STATE_BASE)
								{
									_iDeleted++;
									g_iPlayerBaseQuery[param1] += 1;

									new Handle:hPack = INVALID_HANDLE;
									CreateDataTimer(_fWriteDelay, Timer_DeleteBaseProps, hPack);
									WritePackCell(hPack, param1);
									WritePackCell(hPack, iEnt);
									_fWriteDelay += 0.01;

									RemoveFromArray(g_hArray_PlayerProps[param1], i);
								}
							}

							g_iPlayerProps[param1] -= _iDeleted;
						}
					}

					QueryBuildMenu(param1, MENU_BASE_MAIN);
				}
				case 5:
				{
					g_iPlayerBaseMenu[param1] = MENU_BASE_MAIN;
					
					if(!g_bCurrentSave[param1])
					{
						#if defined _colors_included
						CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSaveMissing");
						#else
						PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSaveMissing");
						#endif

						QueryBuildMenu(param1, MENU_BASE_MAIN);
						return;
					}
					else
					{
						new iSize = GetArraySize(g_hArray_PlayerProps[param1]);
						if(iSize < 0)
						{
							#if defined _colors_included
							CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSaveAllFailedEmpty");
							#else
							PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSaveAllFailedEmpty");
							#endif

							QueryBuildMenu(param1, MENU_BASE_MAIN);
							return;
						}
						else
						{
							if(iSize > g_Access[param1][iTotalBaseProps])
							{
								#if defined _colors_included
								CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSaveAllFailedSize", g_Access[param1][iTotalBaseProps], g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
								#else
								PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSaveAllFailedSize", g_Access[param1][iTotalBaseProps], g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
								#endif

								QueryBuildMenu(param1, MENU_BASE_MAIN);
								return;
							}
						}

						Menu_BaseConfirmSave(param1);
						return;
					}
				}
				case 6:
				{
					g_iPlayerBaseMenu[param1] = MENU_BASE_MAIN;
					
					if(!g_bCurrentSave[param1])
					{
						#if defined _colors_included
						CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSaveMissing");
						#else
						PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSaveMissing");
						#endif

						QueryBuildMenu(param1, MENU_BASE_MAIN);
						return;
					}
					else
					{
						new iEnt = Trace_GetEntity(param1);
						if(Entity_Valid(iEnt))
						{
							new iOwner = GetClientOfUserId(g_iPropUser[iEnt]);
							if(iOwner == param1)
							{
								if(g_iBaseIndex[iEnt] == -1)
								{
									new iSize = g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]];
									if(iSize > g_Access[param1][iTotalBaseProps])
									{
										#if defined _colors_included
										CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSaveAllFailedSize", g_Access[param1][iTotalBaseProps], g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
										#else
										PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSaveAllFailedSize", g_Access[param1][iTotalBaseProps], g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
										#endif

										QueryBuildMenu(param1, MENU_BASE_MAIN);
										return;
									}
								}

								decl Float:fOrigin[3];
								GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fOrigin);

								if(Bool_CheckProximity(g_fCurrentSavePos[param1], fOrigin, g_fBaseDistance, false))
								{
									#if defined _colors_included
									CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSaveDistance", g_Cfg_sPropNames[g_iPropType[iEnt]]);
									#else
									PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSaveDistance", g_Cfg_sPropNames[g_iPropType[iEnt]]);
									#endif
								}
								else
								{
									decl String:_sQuery[512], Float:fAngles[3];
									GetEntPropVector(iEnt, Prop_Send, "m_angRotation", fAngles);
									SubtractVectors(g_fCurrentSavePos[param1], fOrigin, fOrigin);
									fOrigin[2] *= -1;

									if(!g_bPlayerBaseSpawned[param1])
										g_bPlayerBaseSpawned[param1] = true;

									SetPropColor(iEnt, {0, 0, 0, ALPHA_PROP_SAVED, -1, -1});

									g_iPropState[iEnt] |= STATE_SAVED;
									g_iPlayerBaseQuery[param1] += 1;
									if(g_iBaseIndex[iEnt] != -1)
									{
										Format(_sQuery, sizeof(_sQuery), g_sSQL_PropSaveIndex, g_iBaseIndex[iEnt], g_iPlayerBase[param1][g_iPlayerBaseCurrent[param1]], g_Cfg_iPropTypeToBase[g_iPropType[iEnt]], fOrigin[0], fOrigin[1], fOrigin[2], fAngles[0], fAngles[1], fAngles[2], g_sAuthString[param1]);
										SQL_TQuery(g_hSql_Database, SQL_QueryPropSaveSingle, _sQuery, EntIndexToEntRef(iEnt));
									}
									else
									{
										Format(_sQuery, sizeof(_sQuery), g_sSQL_PropSaveLegacy, g_iPlayerBase[param1][g_iPlayerBaseCurrent[param1]], g_Cfg_iPropTypeToBase[g_iPropType[iEnt]], fOrigin[0], fOrigin[1], fOrigin[2], fAngles[0], fAngles[1], fAngles[2], g_sAuthString[param1]);
										SQL_TQuery(g_hSql_Database, SQL_QueryPropSaveSingle, _sQuery, EntIndexToEntRef(iEnt));
									}
								}
							}
							else
							{
								#if defined _colors_included
								CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBasePhaseFail", g_Cfg_sPropNames[g_iPropType[iEnt]], g_sPropOwner[iEnt]);
								#else
								PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBasePhaseFail", g_Cfg_sPropNames[g_iPropType[iEnt]], g_sPropOwner[iEnt]);
								#endif
							}
						}
					}

					QueryBuildMenu(param1, MENU_BASE_MAIN);
				}
				case 7:
				{
					g_iPlayerBaseMenu[param1] = MENU_BASE_MAIN;
					
					if(!g_bEnding)
					{
						new iEnt = Trace_GetEntity(param1);
						if(Entity_Valid(iEnt))
						{
							new iOwner = GetClientOfUserId(g_iPropUser[iEnt]);
							if(iOwner == param1)
							{
								if(g_iBaseIndex[iEnt] != -1)
								{
									g_iPlayerBaseQuery[param1] += 1;

									decl String:_sQuery[256];
									Format(_sQuery, sizeof(_sQuery), g_sSQL_PropDelete, g_iBaseIndex[iEnt]);
									SQL_TQuery(g_hSql_Database, SQL_QueryPropDelete, _sQuery, EntIndexToEntRef(iEnt));
								}
								else
								{
									#if defined _colors_included
									CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseDeletePropMissing", g_Cfg_sPropNames[g_iPropType[iEnt]], g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
									#else
									PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseDeletePropMissing", g_Cfg_sPropNames[g_iPropType[iEnt]], g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
									#endif
								}
							}
							else
							{
								#if defined _colors_included
								CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBasePhaseFail", g_Cfg_sPropNames[g_iPropType[iEnt]], g_sPropOwner[iEnt]);
								#else
								PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBasePhaseFail", g_Cfg_sPropNames[g_iPropType[iEnt]], g_sPropOwner[iEnt]);
								#endif
							}
						}
					}

					QueryBuildMenu(param1, MENU_BASE_MAIN);
				}
				case 8:
				{
					g_iPlayerBaseMenu[param1] = MENU_BASE_MAIN;
					
					if(!g_bEnding)
					{
						new iSize = (GetArraySize(g_hArray_PlayerProps[param1]) - 1);
						for(new i = iSize; i >= 0; i--)
						{
							new iEnt = GetArrayCell(g_hArray_PlayerProps[param1], i);
							if(IsValidEntity(iEnt) && g_iPropState[iEnt] & STATE_BASE)
							{
								g_iPropState[iEnt] &= ~STATE_BASE;
								g_iBaseIndex[iEnt] = -1;
							}
						}

						Menu_BaseConfirmEmpty(param1);
						return;
					}

					QueryBuildMenu(param1, MENU_BASE_MAIN);
				}
				case 9:
				{
					QueryBuildMenu(param1, MENU_BASE_MOVE);
				}
			}
		}
	}
}

Menu_BaseActivate(client)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client]))
		return;

	decl String:sBuffer[128], String:sIndex[4];

	new Handle:hMenu = CreateMenu(MenuHandler_BaseActivate);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuPagination(hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(hMenu, true);

	for(new i = 0; i < g_Access[client][iTotalBases]; i++)
	{
		IntToString(i, sIndex, 4);
		Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryBaseAvailable", client, g_sBaseNames[i], g_iPlayerBaseCount[client][i], g_Access[client][iTotalBaseProps]);
		AddMenuItem(hMenu, sIndex, sBuffer);
	}

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_BaseActivate(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_BaseActions(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_BaseActions(param1);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1]))
				return;

			g_iPlayerBaseMenu[param1] = MENU_BASE_MAIN;
				
			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);

			new iSelectedBase = StringToInt(sOption);
			if(g_iPlayerBaseCurrent[param1] != iSelectedBase)
			{
				g_iPlayerBaseCurrent[param1] = iSelectedBase;

				if(!g_bEnding)
				{
					if(g_bPlayerBaseSpawned[param1])
					{
						new Float:fDelay = 0.1;
						new iDeleted, iSize = (GetArraySize(g_hArray_PlayerProps[param1]) - 1);
						for(new i = iSize; i >= 0; i--)
						{
							new iEnt = GetArrayCell(g_hArray_PlayerProps[param1], i);
							if(IsValidEntity(iEnt) && g_iPropState[iEnt] & STATE_BASE)
							{
								iDeleted++;
								g_iPlayerBaseQuery[param1] += 1;

								new Handle:hPack = INVALID_HANDLE;
								CreateDataTimer(fDelay, Timer_DeleteBaseProps, hPack);
								WritePackCell(hPack, param1);
								WritePackCell(hPack, iEnt);
								fDelay += 0.01;

								RemoveFromArray(g_hArray_PlayerProps[param1], i);
							}
						}

						g_iPlayerProps[param1] -= iDeleted;
						g_iPlayerDeletes[param1] += iDeleted;
						switch(g_iCurrentTeam[param1])
						{
							case CS_TEAM_T:
								g_iPointsRed += (iDeleted * POINTS_DELETE);
							case CS_TEAM_CT:
								g_iPointsBlue += (iDeleted * POINTS_DELETE);
						}
					}
				}

				g_bPlayerBaseSpawned[param1] = false;
			}

			QueryBuildMenu(param1, MENU_BASE_MAIN);
		}
	}
}

public MenuHandler_BaseLoading(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			g_iPlayerBaseMenu[param1] = -1;
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					QueryBuildMenu(param1, MENU_BASE_MAIN);
			}
		}
	}
}

public MenuHandler_BaseQuery(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			g_iPlayerBaseMenu[param1] = -1;
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					QueryBuildMenu(param1, MENU_BASE_MAIN);
			}
		}
	}
}

Menu_BaseConfirmSave(client)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client], true))
		return;

	decl String:sBuffer[128];

	new Handle:hMenu = CreateMenu(MenuHandler_BaseConfirmSave);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	Format(sBuffer, sizeof(sBuffer), "%T", "Menu_Base_Confirm_Save_Ask", client);
	AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);

	if(!g_bGlobalOffensive)
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "menuOptionSpacerSelection", client);
		if(!StrEqual(sBuffer, ""))
			AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
	}

	Format(sBuffer, sizeof(sBuffer), "%T", "Menu_Base_Confirm_Save_Yes", client);
	AddMenuItem(hMenu, "1", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%T", "Menu_Base_Confirm_Save_No", client);
	AddMenuItem(hMenu, "0", sBuffer);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_BaseConfirmSave(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					QueryBuildMenu(param1, MENU_BASE_MAIN);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1], true))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);

			if(StringToInt(sOption))
			{
				g_iPlayerBaseQuery[param1] += 1;
				g_iPlayerBaseFailed[param1] = 0;

				decl String:_sQuery[256];
				Format(_sQuery, sizeof(_sQuery), g_sSQL_PropEmpty, g_iPlayerBase[param1][g_iPlayerBaseCurrent[param1]], g_sAuthString[param1]);
				SQL_TQuery(g_hSql_Database, SQL_QueryBaseReadySave, _sQuery, GetClientUserId(param1));
			}

			QueryBuildMenu(param1, MENU_BASE_MAIN);
		}
	}
}

Menu_BaseConfirmEmpty(client)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client]))
		return;

	decl String:sBuffer[128];

	new Handle:hMenu = CreateMenu(MenuHandler_BaseConfirmEmpty);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	Format(sBuffer, sizeof(sBuffer), "%T", "Menu_Base_Confirm_Empty_Ask", client, g_sBaseNames[g_iPlayerBaseCurrent[client]]);
	AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);

	if(!g_bGlobalOffensive)
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "menuOptionSpacerSelection", client);
		if(!StrEqual(sBuffer, ""))
			AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
	}

	Format(sBuffer, sizeof(sBuffer), "%T", "Menu_Base_Confirm_Empty_Yes", client);
	AddMenuItem(hMenu, "1", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%T", "Menu_Base_Confirm_Empty_No", client);
	AddMenuItem(hMenu, "0", sBuffer);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_BaseConfirmEmpty(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					QueryBuildMenu(param1, MENU_BASE_MAIN);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1]))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);

			if(StringToInt(sOption))
			{
				g_iPlayerBaseQuery[param1] += 1;

				decl String:_sQuery[256];
				Format(_sQuery, sizeof(_sQuery), g_sSQL_PropEmpty, g_iPlayerBase[param1][g_iPlayerBaseCurrent[param1]], g_sAuthString[param1]);
				SQL_TQuery(g_hSql_Database, SQL_QueryBaseEmpty, _sQuery, GetClientUserId(param1));
			}

			QueryBuildMenu(param1, MENU_BASE_MAIN);
		}
	}
}

Menu_BaseMove(client)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client]))
		return;

	decl String:sBuffer[128];

	new Handle:hMenu = CreateMenu(MenuHandler_BaseMove);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	new _iState = Bool_MoveValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPositionAxisXInc", client, g_Cfg_fDefinedPositions[g_iPlayerPosition[client]]);
	AddMenuItem(hMenu, "1", sBuffer, _iState);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPositionAxisXDec", client, g_Cfg_fDefinedPositions[g_iPlayerPosition[client]]);
	AddMenuItem(hMenu, "2", sBuffer, _iState);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPositionAxisYInc", client, g_Cfg_fDefinedPositions[g_iPlayerPosition[client]]);
	AddMenuItem(hMenu, "3", sBuffer, _iState);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPositionAxisYDec", client, g_Cfg_fDefinedPositions[g_iPlayerPosition[client]]);
	AddMenuItem(hMenu, "4", sBuffer, _iState);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPositionAxisZInc", client, g_Cfg_fDefinedPositions[g_iPlayerPosition[client]]);
	AddMenuItem(hMenu, "5", sBuffer, _iState);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPositionAxisZDec", client, g_Cfg_fDefinedPositions[g_iPlayerPosition[client]]);
	AddMenuItem(hMenu, "6", sBuffer, _iState);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPositionDefault", client);
	AddMenuItem(hMenu, "0", sBuffer);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_BaseMove(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					QueryBuildMenu(param1, MENU_BASE_MAIN);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1]))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);

			new _iOption = StringToInt(sOption);
			if(!_iOption)
				Menu_DefaultBasePosition(param1);
			else
			{
				g_iPlayerBaseMenu[param1] = MENU_BASE_MOVE;

				new iSize = g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]];
				if(!iSize)
				{
					#if defined _colors_included
					CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseMoveFail");
					#else
					PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserBaseMoveFail");
					#endif

					QueryBuildMenu(param1, MENU_BASE_MAIN);
					return;
				}

				new Float:_fWriteDelay = 0.1;
				new _iArraySize = (GetArraySize(g_hArray_PlayerProps[param1]) - 1);
				for(new i = _iArraySize; i >= 0; i--)
				{
					new iEnt = GetArrayCell(g_hArray_PlayerProps[param1], i);
					if(IsValidEntity(iEnt) && g_iPropState[iEnt] & STATE_BASE)
					{
						g_iPlayerBaseQuery[param1] += 1;

						new Handle:hPack = INVALID_HANDLE;
						CreateDataTimer(_fWriteDelay, Timer_MoveBaseProps, hPack);
						WritePackCell(hPack, param1);
						WritePackCell(hPack, EntIndexToEntRef(iEnt));
						WritePackCell(hPack, _iOption);
						_fWriteDelay += 0.01;
					}
				}

				QueryBuildMenu(param1, MENU_BASE_MOVE);
			}
		}
	}
}

Menu_DefaultBasePosition(client, index = 0)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client]))
		return;

	decl String:sBuffer[128], String:sTemp[4];

	new Handle:hMenu = CreateMenu(MenuHandler_DefaultBasePosition);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	for(new i = 0; i < g_iCfg_TotalPositions; i++)
	{
		IntToString(i, sTemp, 4);
		Format(sBuffer, sizeof(sBuffer), "%s%T", (g_iPlayerPosition[client] == i) ? g_sPrefixSelect : g_sPrefixEmpty, "menuEntryPositionModify", client, g_Cfg_fDefinedPositions[i]);
		AddMenuItem(hMenu, sTemp, sBuffer);
	}

	DisplayMenuAtItem(hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_DefaultBasePosition(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_BaseMove(param1);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1]))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);
			g_iPlayerPosition[param1] = StringToInt(sOption);
			SetClientCookie(param1, g_cCookiePosition, sOption);

			#if defined _colors_included
			CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserPositionSettingSuccess", g_Cfg_fDefinedPositions[g_iPlayerPosition[param1]]);
			#else
			PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserPositionSettingSuccess", g_Cfg_fDefinedPositions[g_iPlayerPosition[param1]]);
			#endif

			Menu_DefaultBasePosition(param1, GetMenuSelectionPosition());
		}
	}
}

LoadClientBase(client)
{
	if(g_bDatabaseFound && g_hSql_Database != INVALID_HANDLE)
	{
		g_iPlayerBaseMenu[client] = -1;
		g_iPlayerBaseQuery[client] = 0;
		g_iPlayerBaseLoading[client] = 0;
		for(new i = 0; i < g_Access[client][iTotalBases]; i++)
		{
			g_iPlayerBase[client][i] = 0;
			g_iPlayerBaseCount[client][i] = 0;
		}

		decl String:_sQuery[256];
		Format(_sQuery, sizeof(_sQuery), g_sSQL_BaseLoad, g_sAuthString[client]);
		SQL_TQuery(g_hSql_Database, SQL_QueryBaseLoad, _sQuery, GetClientUserId(client));
	}
}

public Action:Timer_SaveBaseProps(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new iEnt = ReadPackCell(pack);

	decl Float:fOrigin[3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fOrigin);
	if(Bool_CheckProximity(g_fCurrentSavePos[client], fOrigin, g_fBaseDistance, true))
	{
		decl String:_sQuery[512], Float:fAngles[3];
		GetEntPropVector(iEnt, Prop_Send, "m_angRotation", fAngles);
		SubtractVectors(g_fCurrentSavePos[client], fOrigin, fOrigin);
		fOrigin[2] *= -1;

		if(g_iBaseIndex[iEnt] != -1)
		{
			Format(_sQuery, sizeof(_sQuery), g_sSQL_PropSaveIndex, g_iBaseIndex[iEnt], g_iPlayerBase[client][g_iPlayerBaseCurrent[client]], g_Cfg_iPropTypeToBase[g_iPropType[iEnt]], fOrigin[0], fOrigin[1], fOrigin[2], fAngles[0], fAngles[1], fAngles[2], g_sAuthString[client]);
			SQL_TQuery(g_hSql_Database, SQL_QueryPropSaveMass, _sQuery, EntIndexToEntRef(iEnt));
		}
		else
		{
			Format(_sQuery, sizeof(_sQuery), g_sSQL_PropSaveLegacy, g_iPlayerBase[client][g_iPlayerBaseCurrent[client]], g_Cfg_iPropTypeToBase[g_iPropType[iEnt]], fOrigin[0], fOrigin[1], fOrigin[2], fAngles[0], fAngles[1], fAngles[2], g_sAuthString[client]);
			SQL_TQuery(g_hSql_Database, SQL_QueryPropSaveMass, _sQuery, EntIndexToEntRef(iEnt));
		}
	}
	else
	{
		g_iPlayerBaseFailed[client]++;

		g_iPlayerBaseQuery[client] -= 1;
		if(g_iPlayerBaseQuery[client] <= 0 && g_iPlayerBaseMenu[client] != -1)
		{
			QueryBuildMenu(client, MENU_BASE_MAIN);
			g_iPlayerBaseMenu[client] = -1;
		}
	}

	if(g_iPlayerBaseFailed[client] == g_iPlayerProps[client])
	{
		#if defined _colors_included
		CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSaveAllFailed", g_sBaseNames[g_iPlayerBaseCurrent[client]], g_iPlayerBaseFailed[client]);
		#else
		PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserBaseSaveAllFailed", g_sBaseNames[g_iPlayerBaseCurrent[client]], g_iPlayerBaseFailed[client]);
		#endif
	}
}

public Action:Timer_MoveBaseProps(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new iEnt = EntRefToEntIndex(ReadPackCell(pack));
	new option = ReadPackCell(pack);

	g_iPlayerBaseQuery[client] -= 1;
	if(iEnt != INVALID_ENT_REFERENCE)
	{
		new Float:_fTemp[3];
		switch(option)
		{
			case 1:
				_fTemp[0] = g_Cfg_fDefinedPositions[g_iPlayerPosition[client]];
			case 2:
				_fTemp[0] = (g_Cfg_fDefinedPositions[g_iPlayerPosition[client]] * -1);
			case 3:
				_fTemp[1] = g_Cfg_fDefinedPositions[g_iPlayerPosition[client]];
			case 4:
				_fTemp[1] = (g_Cfg_fDefinedPositions[g_iPlayerPosition[client]] * -1);
			case 5:
				_fTemp[2] = g_Cfg_fDefinedPositions[g_iPlayerPosition[client]];
			case 6:
				_fTemp[2] = (g_Cfg_fDefinedPositions[g_iPlayerPosition[client]] * -1);
		}

		Entity_PositionProp(iEnt, _fTemp);
	}

	if(g_iPlayerBaseQuery[client] <= 0 && g_iPlayerBaseMenu[client] != -1)
	{
		QueryBuildMenu(client, MENU_BASE_MOVE);
		g_iPlayerBaseMenu[client] = -1;
	}
}

public Action:Timer_DeleteBaseProps(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new iEnt = ReadPackCell(pack);

	if(IsValidEntity(iEnt))
	{
		Entity_DeleteProp(iEnt);
		switch(g_iCurrentTeam[client])
		{
			case CS_TEAM_T:
				g_iPointsRed += POINTS_DELETE;
			case CS_TEAM_CT:
				g_iPointsBlue += POINTS_DELETE;
		}
	}

	g_iPlayerBaseQuery[client] -= 1;

	if(g_iPlayerBaseQuery[client] <= 0 && g_iPlayerBaseMenu[client] != -1)
	{
		QueryBuildMenu(client, MENU_BASE_MAIN);
		g_iPlayerBaseMenu[client] = -1;
	}
}

public Action:Timer_DisplaySaveLocation(Handle:timer, any:client)
{
	if(client <= 0 || !IsClientInGame(client))
		g_hTimer_CurrentSave[client] = INVALID_HANDLE;
	else
	{
		DisplaySaveLocation(client);
		return Plugin_Continue;
	}

	return Plugin_Stop;
}

DisplaySaveLocation(client)
{
	decl Float:_fTemp[3];
	_fTemp = g_fCurrentSavePos[client];
	_fTemp[2] += 1.5;

	TE_SetupGlowSprite(_fTemp, g_iGlowSprite, 1.0, 0.5, 255);
	TE_SendToClient(client);

	TE_SetupBeamRingPoint(_fTemp, 8.0, 40.0, g_iBeamSprite, g_iFlashSprite, 0, 10, 1.0, 16.0, 1.0, {200, 255, 200, 150}, 15, 0);
	TE_SendToClient(client);
}


Float:GetAngleBetweenVectors( const Float:vector1[3], const Float:vector2[3], const Float:direction[3] )
{
	decl Float:vector1_n[3], Float:vector2_n[3], Float:direction_n[3], Float:cross[3];
	NormalizeVector( direction, direction_n );
	NormalizeVector( vector1, vector1_n );
	NormalizeVector( vector2, vector2_n );
	new Float:degree = ArcCosine( GetVectorDotProduct( vector1_n, vector2_n ) ) * 57.29577951;   // 180/Pi
	GetVectorCrossProduct( vector1_n, vector2_n, cross );

	if( GetVectorDotProduct( cross, direction_n ) < 0.0 )
	{
		degree *= -1.0;
	}

	return degree;
}

RotateYaw( Float:angles[3], Float:degree )
{
	decl Float:direction[3], Float:normal[3];
	GetAngleVectors( angles, direction, NULL_VECTOR, normal );

	new Float:sin = Sine( degree * 0.01745328 );	 // Pi/180
	new Float:cos = Cosine( degree * 0.01745328 );
	new Float:a = normal[0] * sin;
	new Float:b = normal[1] * sin;
	new Float:c = normal[2] * sin;
	new Float:x = direction[2] * b + direction[0] * cos - direction[1] * c;
	new Float:y = direction[0] * c + direction[1] * cos - direction[2] * a;
	new Float:z = direction[1] * a + direction[2] * cos - direction[0] * b;
	direction[0] = x;
	direction[1] = y;
	direction[2] = z;

	GetVectorAngles( direction, angles );

	decl Float:up[3];
	GetVectorVectors( direction, NULL_VECTOR, up );

	new Float:roll = GetAngleBetweenVectors( up, normal, direction );
	angles[2] += roll;
}

AddCustomTag()
{
	decl String:sBuffer[128];
	GetConVarString(g_hServerTags, sBuffer, sizeof(sBuffer));
	if(StrContains(sBuffer, "buildwars", false) == -1)
	{
		Format(sBuffer, sizeof(sBuffer), "%s,buildwars", sBuffer);
		SetConVarString(g_hServerTags, sBuffer, true);
	}
	if(StrContains(sBuffer, "prop", false) == -1)
	{
		Format(sBuffer, sizeof(sBuffer), "%s,prop", sBuffer);
		SetConVarString(g_hServerTags, sBuffer, true);
	}
}

RemCustomTag()
{
	decl String:sBuffer[128];
	GetConVarString(g_hServerTags, sBuffer, sizeof(sBuffer));
	if(StrContains(sBuffer, "buildwars") != -1)
	{
		ReplaceString(sBuffer, sizeof(sBuffer), "buildwars", "", false);
		ReplaceString(sBuffer, sizeof(sBuffer), ",,", ",", false);
		SetConVarString(g_hServerTags, sBuffer, true);
	}
}

Float:GetCleanAngle(Float:x)
{
	while(x <= -360.0)
		x += 360.0;

	while(x >= 360.0)
		x -= 360.0;

	return float(RoundToNearest(x));
}

Float:GetCleanAngles(Float:x[3])
{
	for(new i = 0; i <= 2; i++)
	{
		while(x[i] <= -360.0)
			x[i] += 360.0;

		while(x[i] >= 360.0)
			x[i] -= 360.0;

		x[i] = float(RoundToNearest(x[i]));
	}

	return x;
}

Float:GetCleanVector(Float:x[3])
{
	for(new i = 0; i <= 2; i++)
		x[i] = float(RoundToNearest(x[i]));

	return x;
}

public Native_GetEntityState(Handle:hPlugin, iNumParams)
{
	new iEnt = GetNativeCell(1);
	if(0 < iEnt < MAX_SERVER_ENTITIES)
		return g_iPropState[iEnt];

	return 0;
}

public Native_GetPropTeam(Handle:hPlugin, iNumParams)
{
	new iEnt = GetNativeCell(1);
	if(0 < iEnt < MAX_SERVER_ENTITIES)
		return g_iPropTeam[iEnt];

	return 0;
}

public Native_GetPropOwner(Handle:hPlugin, iNumParams)
{
	new iEnt = GetNativeCell(1);
	if(0 < iEnt < MAX_SERVER_ENTITIES)
	{
		new String:sName[32];
		GetNativeString(2, sName, sizeof(sName));
		if(!StrEqual(sName, ""))
		{
			strcopy(sName, sizeof(sName), g_sPropOwner[iEnt]);
			SetNativeString(2, sName, sizeof(sName));
		}

		return g_iPropUser[iEnt];
	}

	return 0;
}

FowardPhaseChange(phase)
{
	if(g_iPhase == phase)
		return;

	g_iPhase = phase;
	Forward_OnPhaseChange();
}

public Forward_OnPhaseChange()
{
	Call_StartForward(g_hForwardPhaseChange);
	Call_PushCell(g_iPhase);
	Call_Finish();
}

//*****************************************************************************************
//* ||| 1| Events
//*****************************************************************************************
public Action:Event_OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		if(g_bMapDataLoaded)
			DetectWallEntities();

		if(g_bAdvancingTeam && (g_iDebugMode == MODE_NORMAL || g_iDebugMode == MODE_IMITATE))
		{
			if(g_iPlayersRed >= 1 && g_iPlayersBlue >= 1)
			{
				if(g_iAdvancingTeam == CS_TEAM_T)
				{
					#if defined _colors_included
					CPrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyRedAdvance");
					#else
					PrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyRedAdvance");
					#endif
				}
				else
				{
					#if defined _colors_included
					CPrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyBlueAdvance");
					#else
					PrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyBlueAdvance");
					#endif
				}
			}
			else
			{
				#if defined _colors_included
				CPrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyAllPending");
				#else
				PrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyAllPending");
				#endif
			}
		}

		g_bEnding = false;
		g_iUniqueProp = 0;
		g_iCurrentDisable = 0;

		if(g_bSpawningIgnore)
			SetConVarInt(g_hIgnoreRound, 1);

		for(new i = 1; i <= MaxClients; i++)
		{
			if(g_iCurrentTeam[i] >= CS_TEAM_T && !g_bAlive[i] && IsClientInGame(i))
			{
				if(!g_iCurrentClass[i])
					g_iCurrentClass[i] = g_iCurrentTeam[i] == CS_TEAM_T ? GetRandomInt(1, 4) : GetRandomInt(5, 8);

				if(!IsPlayerAlive(i))
					CS_RespawnPlayer(i);
			}
		}

		if(g_iDebugMode != MODE_BUILD)
		{
			if(g_hTimer_Update != INVALID_HANDLE && CloseHandle(g_hTimer_Update))
				g_hTimer_Update = INVALID_HANDLE;

			g_iNumSeconds = 0;
			g_hTimer_Update = CreateTimer(1.0, Timer_Update, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}

		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				Bool_ClearClientProps(i, false);

				if(g_bDatabaseFound && g_hSql_Database != INVALID_HANDLE)
				{
					if(g_Access[i][bAccessBase])
					{
						g_iPlayerBaseQuery[i] = 0;
						if(g_bPlayerBaseSpawned[i])
							g_bPlayerBaseSpawned[i] = false;

						if(g_bCurrentSave[i])
						{
							g_bCurrentSave[i] = false;
							if(g_hTimer_CurrentSave[i] != INVALID_HANDLE && CloseHandle(g_hTimer_CurrentSave[i]))
								g_hTimer_CurrentSave[i] = INVALID_HANDLE;
						}
					}
				}
			}
		}
	}

	return Plugin_Continue;
}

DetectWallEntities()
{
	if(StrEqual(g_sWallData, ""))
		return 0;

	decl String:sBuffer[64];
	new iSize = GetArraySize(g_hArray_WallEntity);
	if(iSize)
	{
		for(new i = 0; i < iSize; i++)
		{
			new iTmpEnt = GetArrayCell(g_hArray_WallEntity, i, INDEX_ENTITY);

			GetArrayString(g_hArray_WallEntity, i, sBuffer, sizeof(sBuffer));
			DispatchKeyValue(iTmpEnt, "targetname", sBuffer);
		}

		g_iWallEntities = 0;
		ClearArray(g_hArray_WallEntity);
	}

	new iWalls, iBuffer;
	if(FindCharInString(g_sWallData, ',') != -1)
	{
		decl String:sWalls[8][64];
		iWalls = ExplodeString(g_sWallData, ",", sWalls, sizeof(sWalls), sizeof(sWalls[]));

		for(new i = MaxClients + 1; i <= MAX_SERVER_ENTITIES; i++)
		{
			if(IsValidEntity(i))
			{
				GetEntityClassname(i, sBuffer, sizeof(sBuffer));
				if(!GetTrieValue(g_hTrie_CfgWalls, sBuffer, iBuffer))
					continue;

				GetEntPropString(i, Prop_Data, "m_iName", sBuffer, sizeof(sBuffer));
				for(new j = 0; j < iWalls; j++)
				{
					if(StrEqual(sBuffer, sWalls[j], false))
					{
						g_iWallEntities++;

						iSize = GetArraySize(g_hArray_WallEntity);
						ResizeArray(g_hArray_WallEntity, iSize + 1);

						SetArrayString(g_hArray_WallEntity, iSize, sBuffer);
						SetArrayCell(g_hArray_WallEntity, iSize, i, INDEX_ENTITY);
						SetArrayCell(g_hArray_WallEntity, iSize, false, INDEX_MOVED);

						Format(sBuffer, sizeof(sBuffer), "BuildWars:Wall");
						DispatchKeyValue(i, "targetname", sBuffer);
					}
				}
			}
		}
	}
	else
	{
		for(new i = MaxClients + 1; i <= MAX_SERVER_ENTITIES; i++)
		{
			if(IsValidEntity(i))
			{
				GetEntityClassname(i, sBuffer, sizeof(sBuffer));
				if(!GetTrieValue(g_hTrie_CfgWalls, sBuffer, iBuffer))
					continue;

				GetEntPropString(i, Prop_Data, "m_iName", sBuffer, sizeof(sBuffer));
				if(StrEqual(sBuffer, g_sWallData, false))
				{
					g_iWallEntities++;

					iSize = GetArraySize(g_hArray_WallEntity);
					ResizeArray(g_hArray_WallEntity, iSize + 1);

					SetArrayString(g_hArray_WallEntity, iSize, sBuffer);
					SetArrayCell(g_hArray_WallEntity, iSize, i, INDEX_ENTITY);
					SetArrayCell(g_hArray_WallEntity, iSize, false, INDEX_MOVED);

					Format(sBuffer, sizeof(sBuffer), "BuildWars:Wall");
					DispatchKeyValue(i, "targetname", sBuffer);
				}
			}
		}
	}

	return g_iWallEntities;
}


public Action:Event_OnPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(client <= 0 || !IsClientInGame(client))
			return Plugin_Continue;

		g_iCurrentTeam[client] = GetEventInt(event, "team");
		if(g_iCurrentTeam[client] == CS_TEAM_SPECTATOR)
			g_bAlive[client] = false;

		g_iLastTeam[client] = GetEventInt(event, "oldteam");
		if(g_iCurrentTeam[client] != g_iLastTeam[client])
		{
			Array_Remove(Array_Index(client, g_iLastTeam[client]), g_iLastTeam[client]);
			Array_Push(client, g_iCurrentTeam[client]);
		}

		if(g_iCurrentTeam[client] == CS_TEAM_SPECTATOR)
		{
			if(g_iDisableRadar)
				ToggleRadar(client, STATE_ENABLE);

			if(g_bThirdPerson[client])
				g_bThirdPerson[client] = false;

			if(g_bFlying[client])
				g_bFlying[client] = g_bFlyingPaused[client] = false;

			if(g_bSpawningIgnore)
			{
				new iRed, iBlue;
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && g_bAlive[i])
					{
						switch(g_iCurrentTeam[i])
						{
							case CS_TEAM_T:
								iRed++;
							case CS_TEAM_CT:
								iBlue++;
						}
					}
				}

				if(!iRed)
				{
					SetTeamScore(CS_TEAM_CT, (GetTeamScore(CS_TEAM_CT) + 1));
					CS_TerminateRound(g_fRoundRestart, CSRoundEnd_CTWin);
				}
				else if(!iBlue)
				{
					SetTeamScore(CS_TEAM_T, (GetTeamScore(CS_TEAM_T) + 1));
					CS_TerminateRound(g_fRoundRestart, CSRoundEnd_TerroristWin);
				}
			}
		}

		if(CheckTeamAccess(client, g_iCurrentTeam[client]))
		{
			if(g_iLastTeam[client] == CS_TEAM_NONE)
			{
				if(g_iCurrentTeam[client] > CS_TEAM_SPECTATOR)
				{
					ClearClientAfk(client);

					if(g_iPhase == PHASE_BUILD || g_iPhase == PHASE_LEGACY && !g_bLegacyPhaseFighting)
						g_hTimer_RespawnPlayer[client] = CreateTimer(0.1, Timer_CheckSpawn, client);

					if((g_bPersistentRounds && g_iLastTeam[client] != g_iCurrentTeam[client]))
						Bool_ClearClientProps(client);
				}
			}
			else if(g_iLastTeam[client] == CS_TEAM_SPECTATOR)
			{
				if(g_iPhase == PHASE_BUILD || g_iPhase == PHASE_LEGACY && !g_bLegacyPhaseFighting)
					g_hTimer_RespawnPlayer[client] = CreateTimer(0.1, Timer_CheckSpawn, client);

				if(!g_bEnding && g_bSpawningIgnore && g_iPlayersRed == 1 && g_iPlayersBlue == 1)
				{
					SetTeamScore(CS_TEAM_T, 0);
					SetTeamScore(CS_TEAM_CT, 0);
					for(new i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i))
						{
							SetEntProp(i, Prop_Data, "m_iFrags", 0);
							SetEntProp(i, Prop_Data, "m_iDeaths", 0);
						}
					}

					CS_TerminateRound(g_fRoundRestart, CSRoundEnd_GameStart);
					return Plugin_Handled;
				}
			}
			else
			{
				if(g_bResetSpeed[client])
				{
					g_bResetSpeed[client] = false;
					SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
				}

				if(g_bResetGravity[client])
				{
					g_bResetGravity[client] = false;
					SetEntityGravity(client, 1.0);
				}

				ClearClientControl(client);
				ClearClientTeleport(client);
				ClearClientRespawn(client);

				if(g_iCurrentTeam[client] != CS_TEAM_SPECTATOR)
				{
					if(g_bAfk[client] && g_bAfkReturn)
						g_bReturning[client] = true;

					ClearClientAfk(client);

					if(!g_bEnding && (!g_bPersistentRounds || (g_bPersistentRounds && g_iLastTeam[client] != g_iCurrentTeam[client])))
						Bool_ClearClientProps(client);
				}
				else
				{
					if(g_bAdvancingTeam)
					{
						if(g_iAdvancingTeam == CS_TEAM_T)
						{
							#if defined _colors_included
							CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyRedAdvance");
							#else
							PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyRedAdvance");
							#endif
						}
						else
						{
							#if defined _colors_included
							CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyBlueAdvance");
							#else
							PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyBlueAdvance");
							#endif
						}
					}

					if(!g_bPersistentRounds && !g_bEnding)
						Bool_ClearClientProps(client);

					if(g_iLastTeam[client] == CS_TEAM_T || g_iLastTeam[client] == CS_TEAM_CT)
						ClearClientAfk(client);
				}
			}
		}
	}

	return Plugin_Continue;
}

public Action:Event_OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(client <= 0 || !IsClientInGame(client) || g_iCurrentTeam[client] < CS_TEAM_T)
			return Plugin_Continue;

		g_bAlive[client] = true;
		if(g_bResetSpeed[client])
		{
			g_bResetSpeed[client] = false;
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
		}

		if(g_bResetGravity[client])
		{
			g_bResetGravity[client] = false;
			SetEntityGravity(client, 1.0);
		}

		if(g_iPhase == PHASE_BUILD)
		{
			FakeClientCommandEx(client, "use weapon_knife");
		}

		if(CheckTeamAccess(client, g_iCurrentTeam[client]))
		{
			if(g_bAfkEnable && (g_iPhase == PHASE_LEGACY && !g_bLegacyPhaseFighting || g_iPhase == PHASE_BUILD))
			{
				if(g_bReturning[client])
				{
					if(g_bGlobalOffensive)
					{
						#if defined _colors_included
						CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyAfkReturn", client);
						#else
						PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyAfkReturn", client);
						#endif
					}
					else
						PrintCenterText(client, "%t%t", "prefixCenterMessage", "chatNotifyAfkReturn", client);

					g_bReturning[client] = false;
				}

				g_bActivity[client] = false;
				if(g_hTimer_AfkCheck[client] != INVALID_HANDLE)
				{
					CloseHandle(g_hTimer_AfkCheck[client]);
					g_hTimer_AfkCheck[client] = INVALID_HANDLE;
				}

				if(!g_Access[client][bAfkImmunity])
					g_hTimer_AfkCheck[client] = CreateTimer(g_fAfkDelay, Timer_CheckAfk, client, TIMER_FLAG_NO_MAPCHANGE);
			}

			if((g_iDisableRadar && g_iDisableRadar & g_iPhase) && !(g_Access[client][bAccessRadar]))
				ToggleRadar(client, STATE_DISABLE);
			else
				ToggleRadar(client, STATE_ENABLE);

			if(g_bCrouchSpeed)
			{
				g_bResetCrouching[client] = false;
				g_bPlayerCrouching[client] = false;
				if(g_bToggleCrouching[client])
				{
					g_bToggleCrouching[client] = false;
					SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
				}
			}
		}
	}

	return Plugin_Continue;
}

public Event_PlayerBlind(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		if(g_iDisableRadar)
		{
			new userid = GetEventInt(event, "userid");
			new client = GetClientOfUserId(userid);
			if(client > 0 && IsClientInGame(client) && g_iCurrentTeam[client] >= CS_TEAM_T)
				CreateTimer(GetEntDataFloat(client, g_iFlashDuration), Timer_FlashEnd, userid, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action:Event_OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(client <= 0 || !IsClientInGame(client))
			return Plugin_Continue;

		g_bAlive[client] = false;
		new bool:bAccess = false;
		if((bAccess = CheckTeamAccess(client, g_iCurrentTeam[client])))
		{
			ClearClientControl(client);
			ClearClientTeleport(client);
			if(g_iDisableRadar)
				ToggleRadar(client, STATE_ENABLE);

			if(g_bThirdPerson[client])
				g_bThirdPerson[client] = false;

			if(g_bFlying[client])
				g_bFlying[client] = false;
		}

		switch(g_iPhase)
		{
			case PHASE_LEGACY:
			{
				if(!g_bLegacyPhaseFighting && g_iCurrentClass[client])
					g_hTimer_RespawnPlayer[client] = CreateTimer(0.1, Timer_CheckSpawn, client);
			}
			case PHASE_BUILD:
			{
				if(g_iCurrentClass[client])
					g_hTimer_RespawnPlayer[client] = CreateTimer(0.1, Timer_CheckSpawn, client);
			}
			case PHASE_WAR:
			{
				if(!bAccess)
					return Plugin_Continue;

				new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
				if(attacker && attacker <= MaxClients && attacker != client)
				{
					switch(g_iCurrentTeam[attacker])
					{
						case CS_TEAM_T:
							g_iPointsRed += POINTS_KILL;
						case CS_TEAM_CT:
							g_iPointsBlue += POINTS_KILL;
					}
				}

				switch(g_iCurrentTeam[client])
				{
					case CS_TEAM_T:
						g_iPointsRed += POINTS_DEATH;
					case CS_TEAM_CT:
						g_iPointsBlue += POINTS_DEATH;
				}

				if(g_bSpawningIgnore)
				{
					new iRed, iBlue;
					for(new i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i) && g_bAlive[i])
						{
							switch(g_iCurrentTeam[i])
							{
								case CS_TEAM_T:
									iRed++;
								case CS_TEAM_CT:
									iBlue++;
							}
						}
					}

					if(!iRed)
					{
						SetTeamScore(CS_TEAM_CT, (GetTeamScore(CS_TEAM_CT) + 1));
						CS_TerminateRound(g_fRoundRestart, CSRoundEnd_CTWin);
					}
					else if(!iBlue)
					{
						SetTeamScore(CS_TEAM_T, (GetTeamScore(CS_TEAM_T) + 1));
						CS_TerminateRound(g_fRoundRestart, CSRoundEnd_TerroristWin);
					}
				}
			}
			case PHASE_SUDDEN:
			{
				if(!bAccess)
					return Plugin_Continue;

				new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
				if(attacker && attacker <= MaxClients && attacker != client)
				{
					switch(g_iCurrentTeam[attacker])
					{
						case CS_TEAM_T:
							g_iPointsRed += POINTS_KILL;
						case CS_TEAM_CT:
							g_iPointsBlue += POINTS_KILL;
					}
				}
			}
		}
	}

	return Plugin_Continue;
}

public Action:Event_OnGrenadeExplode(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		new userid = GetEventInt(event, "userid");
		new client = GetClientOfUserId(userid);
		if(client <= 0 || !IsClientInGame(client))
			return Plugin_Continue;

		if(g_iInfiniteGrenades & GRENADE_HE)
		{
			new Handle:hPack = INVALID_HANDLE;
			CreateDataTimer(0.5, Timer_Supply, hPack);
			WritePackCell(hPack, userid);
			WritePackString(hPack, "weapon_hegrenade");
		}
	}

	return Plugin_Continue;
}

public Action:Event_OnSmokeExplode(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		new userid = GetEventInt(event, "userid");
		new client = GetClientOfUserId(userid);
		if(client <= 0 || !IsClientInGame(client))
			return Plugin_Continue;

		if(g_iInfiniteGrenades & GRENADE_SG)
		{
			new Handle:hPack = INVALID_HANDLE;
			CreateDataTimer(0.5, Timer_Supply, hPack);
			WritePackCell(hPack, userid);
			WritePackString(hPack, "weapon_smokegrenade");
		}
	}

	return Plugin_Continue;
}

public Action:Event_OnInspectWeapon(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		new userid = GetEventInt(event, "userid");
		new client = GetClientOfUserId(userid);
		if(client <= 0 || !IsClientInGame(client))
			return Plugin_Continue;

		if(g_bReadyInProgress)
		{
			return Plugin_Continue;
		}

		if(g_iPlayersRed >= 1 && g_iPlayersBlue >= 1 || g_iPhase != MODE_NORMAL)
		{
			switch(g_iPhase)
			{
				case PHASE_BUILD:
				{
					new iRemaining = (g_iBuildDuration - g_iNumSeconds);
					PrintHintText(client, "%t", "chatNotifyBuildPhase", iRemaining);
				}
				case PHASE_WAR:
				{
					new iRemaining = (g_iWarDuration - g_iNumSeconds);
					PrintHintText(client, "%t", "chatNotifyWarPhase", iRemaining);
				}
				case PHASE_SUDDEN:
				{
					new iRemaining = (g_iSuddenDuration - g_iNumSeconds);
					PrintHintText(client, "%t", "chatNotifyDeathPhase", iRemaining);
				}
			}
		}
		else
		{
			PrintHintText(client, "%t", "chatNotifyAllPending");
		}
	}

	return Plugin_Continue;
}

public Action:Event_OnMolotovExplode(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		new userid = GetEventInt(event, "userid");
		new client = GetClientOfUserId(userid);
		if(client <= 0 || !IsClientInGame(client))
			return Plugin_Continue;

		if(g_iInfiniteGrenades & GRENADE_MO)
		{
			new Handle:hPack = INVALID_HANDLE;
			CreateDataTimer(0.5, Timer_Supply, hPack);
			WritePackCell(hPack, userid);
			if(g_iCurrentTeam[client] == CS_TEAM_T)
				WritePackString(hPack, "weapon_molotov");
			else
				WritePackString(hPack, "weapon_incgrenade");
		}
	}

	return Plugin_Continue;
}

public Action:Event_OnDecoyExplode(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		new userid = GetEventInt(event, "userid");
		new client = GetClientOfUserId(userid);
		if(client <= 0 || !IsClientInGame(client))
			return Plugin_Continue;

		if(g_iInfiniteGrenades & GRENADE_DE)
		{
			new Handle:hPack = INVALID_HANDLE;
			CreateDataTimer(0.5, Timer_Supply, hPack);
			WritePackCell(hPack, userid);
			WritePackString(hPack, "weapon_decoy");
		}
	}

	return Plugin_Continue;
}

public Action:Event_OnFlashExplode(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		new userid = GetEventInt(event, "userid");
		new client = GetClientOfUserId(userid);
		if(client <= 0 || !IsClientInGame(client))
			return Plugin_Continue;

		if(g_iInfiniteGrenades & GRENADE_FB)
		{
			new Handle:hPack = INVALID_HANDLE;
			CreateDataTimer(0.5, Timer_Supply, hPack);
			WritePackCell(hPack, userid);
			WritePackString(hPack, "weapon_flashbang");
		}
	}

	return Plugin_Continue;
}

public Action:Timer_Supply(Handle:timer, any:pack)
{
	if(g_bEnabled)
	{
		decl String:sBuffer[32];

		ResetPack(pack);
		new client = GetClientOfUserId(ReadPackCell(pack));
		if(!g_bEnding && client > 0 && g_bAlive[client] && IsClientInGame(client))
		{
			ReadPackString(pack, sBuffer, sizeof(sBuffer));
			GivePlayerItem(client, sBuffer);
		}
	}
}

public Action:Event_OnPlayerName(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(client > 0 && IsClientInGame(client))
		{
			GetEventString(event, "newname", g_sName[client], 32);
			new iSize = GetArraySize(g_hArray_PlayerProps[client]);
			for(new i = 0; i < iSize; i++)
			{
				new iEnt = GetArrayCell(g_hArray_PlayerProps[client], i);
				if(IsValidEntity(iEnt))
					Format(g_sPropOwner[iEnt], 32, "%s", g_sName[client]);
			}
		}
	}

	return Plugin_Continue;
}

//*****************************************************************************************
//* ||| 2| Hooks
//*****************************************************************************************
public Action:CS_OnTerminateRound(&Float:delay, &CSRoundEndReason:reason)
{
	if(g_bEnabled)
	{
		if(g_iDebugMode == MODE_BUILD)
			return Plugin_Handled;

		if(g_bAdvancingTeam)
		{
			if(g_iAdvancingTeam == CS_TEAM_T)
				g_iAdvancingTeam = CS_TEAM_CT;
			else
				g_iAdvancingTeam = CS_TEAM_T;
		}

		if(g_bPersistentRounds)
		{
			if(g_hKvPlayerData == INVALID_HANDLE || g_hKvPlayerData != INVALID_HANDLE && CloseHandle(g_hKvPlayerData))
				g_hKvPlayerData = CreateKeyValues("BuildWars_Persistent");

			ClearArray(g_hArrayPropData);
		}

		g_bEnding = true;
		g_iCurrentRound++;
		g_bReadyInProgress = false;
		g_iPointsRed = g_iPointsBlue = g_iReadyCountdown = g_iInfiniteGrenades = 0;

		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				ClearClientControl(i);
				ClearClientTeleport(i);
				ClearClientRespawn(i);
				if(g_bThirdPerson[i])
					ToggleThird(i, STATE_DISABLE);
				if(g_bFlying[i])
					ToggleFlying(i, STATE_DISABLE);
				if(g_bCrouchSpeed)
				{
					g_bResetCrouching[i] = false;
					g_bPlayerCrouching[i] = false;
					if(g_bToggleCrouching[i])
					{
						g_bToggleCrouching[i] = false;
						SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 1.0);
					}
				}

				if(g_iCurrentTeam[i] >= CS_TEAM_T && g_hTimer_AfkCheck[i] != INVALID_HANDLE && CloseHandle(g_hTimer_AfkCheck[i]))
					g_hTimer_AfkCheck[i] = INVALID_HANDLE;

				g_bReady[i] = g_bTeleported[i] = g_bActivity[i] = false;
				g_iPlayerProps[i] = g_iPlayerDeletes[i] = g_iPlayerColors[i] = g_iPlayerTeleports[i] = 0;
			}
		}

		if(g_bSpawningIgnore)
			SetConVarInt(g_hIgnoreRound, 0);

		if(g_hTimer_Update != INVALID_HANDLE && CloseHandle(g_hTimer_Update))
			g_hTimer_Update = INVALID_HANDLE;

		if(g_iPhase == PHASE_SUDDEN)
		{
			if(g_hWeaponRestrict != INVALID_HANDLE)
			{
				if(g_bRestrictReturn[0][g_iRestrictWeapon])
				{
					g_bRestrictReturn[0][g_iRestrictWeapon] = false;
					SetConVarInt(g_hRestrictCvar[0][g_iRestrictWeapon], g_iRestrictOriginal[0][g_iRestrictWeapon]);
				}

				if(g_bRestrictReturn[1][g_iRestrictWeapon])
				{
					g_bRestrictReturn[1][g_iRestrictWeapon] = false;
					SetConVarInt(g_hRestrictCvar[1][g_iRestrictWeapon], g_iRestrictOriginal[1][g_iRestrictWeapon]);
				}
			}

			CreateTimer((delay * 0.1), Timer_ModeExecute, 1, TIMER_FLAG_NO_MAPCHANGE);
		}

		CreateTimer((delay * 0.5), Timer_PostRoundEnd, reason, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue;
}

public Action:Hook_OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(g_bEnabled)
	{
		if(g_iDebugMode == MODE_BUILD)
		{
			damage = 0.0;
			return Plugin_Changed;
		}
		else if(0 < client <= MaxClients)
		{
			if(g_bEnding)
			{
				damage = 0.0;
				return Plugin_Changed;
			}
			else if(damagetype & DMG_FALL)
			{
				if(g_iDisableFalling && g_iDisableFalling & g_iPhase)
				{
					if(!g_fFallDamage)
					{
						if(damage < float(GetClientHealth(client)))
						{
							damage = 0.0;
							return Plugin_Changed;
						}
					}
					else if(damage < g_fFallDamage)
					{
						damage = 0.0;
						return Plugin_Changed;
					}
				}
			}
			else if(0 < attacker < MaxClients)
			{
				if(g_iPhase == PHASE_BUILD  || g_iPhase == PHASE_LEGACY && !g_bLegacyPhaseFighting)
				{
					if(g_iCurrentTeam[client] != g_iCurrentTeam[attacker])
					{
						damage = 0.0;
						return Plugin_Changed;
					}
				}
			}
		}
	}

	return Plugin_Continue;
}

public Action:Entity_OnTakeDamage(iEnt, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(g_bEnabled)
	{
		if(g_iPropState[iEnt])
		{

		}
		else if(g_iPropState[iEnt] & STATE_VALID)
		{

		}
	}

	return Plugin_Continue;
}

public Hook_PreThinkPost(iEnt)
{
	if(g_bEnabled)
	{
		if(!g_bEnding && g_bAlive[iEnt])
		{
			if(g_iDisableSlowing && g_iDisableSlowing & g_iPhase)
				SetEntPropFloat(iEnt, Prop_Send, "m_flVelocityModifier", 1.0);
		}
	}
}

public Hook_PostThinkPost(iEnt)
{
	if(g_bEnabled)
	{
		if(!g_bEnding && g_bAlive[iEnt])
		{
			SetEntProp(iEnt, Prop_Send, "m_bInBuyZone", (!g_iAlwaysBuyzone || g_iAlwaysBuyzone & g_iPhase) ? 1 : 0);

			if(g_iDisableDrowning && g_iDisableDrowning & g_iPhase)
				if(GetEntProp(iEnt, Prop_Data, "m_nWaterLevel") == 3 && !(GetEntityFlags(iEnt) & FL_WATERJUMP))
					SetEntProp(iEnt, Prop_Send, "m_nWaterLevel", 2);
		}
	}
}

public Action:Hook_WeaponCanUse(client, weapon)
{
	if(g_bEnabled)
	{
		if(g_iPhase == PHASE_SUDDEN)
		{
			decl String:sBuffer[32];
			GetEdictClassname(weapon, sBuffer, 32);
			if(!StrEqual(sBuffer, g_sModeWeapon) && !StrEqual(sBuffer, "weapon_knife"))
				return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Hook_WeaponSwitchPost(client, weapon)
{
	if(g_bEnabled)
	{
		decl String:sBuffer[32];
		GetEdictClassname(weapon, sBuffer, 32);
		g_bCustomKnife[client] = StrEqual(sBuffer, "weapon_knife") ? true : false;
	}
}

public Hook_WeaponEquipPost(client, weapon)
{
	if(g_bEnabled)
	{
		decl String:sBuffer[32];
		GetEdictClassname(weapon, sBuffer, 32);
		g_bCustomKnife[client] = StrEqual(sBuffer, "weapon_knife") ? true : false;
	}
}

public Action:OnLevelInit(const String:mapName[], String:mapEntities[2097152])
{
	g_iCurEntities = 0;

	return Plugin_Continue;
}

public OnEntityCreated(iEnt, const String:classname[])
{
	if(iEnt >= 0)
	{
		g_iCurEntities++;
		g_iPropState[iEnt] = 0;
	}
}

public OnEntityDestroyed(iEnt)
{
	if(iEnt >= 0)
	{
		g_iCurEntities--;
		if(g_hPropPhase[iEnt] != INVALID_HANDLE && CloseHandle(g_hPropPhase[iEnt]))
			g_hPropPhase[iEnt] = INVALID_HANDLE;
		if(g_hPropDelete[iEnt] != INVALID_HANDLE && CloseHandle(g_hPropDelete[iEnt]))
			g_hPropDelete[iEnt] = INVALID_HANDLE;

		if(g_bWithinRestricted[iEnt])
			g_bWithinRestricted[iEnt] = false;

		if(g_iPropState[iEnt] & STATE_VALID)
		{
			g_iPropState[iEnt] = 0;
			if(!g_bEnding)
			{
				new client = GetClientOfUserId(g_iPropUser[iEnt]);
				if(client > 0 && IsClientInGame(client))
				{
					g_iPlayerProps[client]--;
					new iIndex = GetEntityIndex(client, iEnt);
					if(iIndex >= 0)
						RemoveFromArray(g_hArray_PlayerProps[client], iIndex);
				}
			}
		}
	}
}

//*****************************************************************************************
//* ||| 3| Commands
//*****************************************************************************************
public Action:Command_Say(client, const String:command[], argc)
{
	if(g_bEnabled)
	{
		if(g_bDisableConsoleChat && !client)
			return Plugin_Handled;
		else if(g_bEnding || client <= 0 || !IsClientInGame(client) || !CheckTeamAccess(client, g_iCurrentTeam[client]))
			return Plugin_Continue;
		else
		{
			new String:sTrigger[2][32];
			decl iIndex, String:sText[192];
			GetCmdArgString(sText, 192);
			StripQuotes(sText);

			ExplodeString(sText, " ", sTrigger, 2, 32);
			new iSize = strlen(sTrigger[0]);
			for (new i = 0; i < iSize; i++)
				if(IsCharAlpha(sTrigger[0][i]) && IsCharUpper(sTrigger[0][i]))
					sTrigger[0][i] = CharToLower(sTrigger[0][i]);

			if(GetTrieValue(g_hTrie_CfgDefinedCmds, sTrigger[0], iIndex))
			{
				if(iIndex != COMMAND_MAIN && iIndex != COMMAND_STUCK && g_iPlayerGimp[client])
					return Plugin_Handled;

				switch(iIndex)
				{
					case COMMAND_MAIN:
					{
						if(StrEqual(sTrigger[1], ""))
							Menu_Main(client);
						else
						{
							iIndex = StringToInt(sTrigger[1]);
							if(Bool_SpawnAllowed(client, true) && Bool_SpawnValid(client, true, true))
								if((iIndex >= 0 && iIndex < g_iNumProps) && (!g_Cfg_iPropAccess[iIndex] || g_Access[client][iAccess] & g_Cfg_iPropAccess[iIndex]))
									SpawnChat(client, iIndex);
						}
					}
					case COMMAND_ROTATION:
					{
						if(Bool_RotateValid(client, true))
							Menu_ModifyRotation(client);
					}
					case COMMAND_POSITION:
					{
						if(Bool_MoveValid(client, true))
							Menu_ModifyPosition(client);
					}
					case COMMAND_DELETE:
					{
						if(g_Access[client][bAccessAdminDelete] && !StrEqual(sTrigger[1], "") || CheckCommandAccess(client, "Bw_Access_Delete", ADMFLAG_RCON))
						{
							if(Bool_DeleteValid(client, false))
							{
								new iTmpEnt = (StringToInt(sTrigger[1]) > 0) ? StringToInt(sTrigger[1]) : Trace_GetEntity(client);
								if(iTmpEnt && Entity_Valid(iTmpEnt))
								{
									if(g_bGlobalOffensive)
										PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserDeletePropSuccess");
									else
										PrintCenterText(client, "%t%t", "prefixCenterMessage", "hintNotifyUserDeletePropSuccess");
									DeleteProp(client, iTmpEnt);

									return Plugin_Handled;
								}
							}
						}

						if(g_Access[client][bAccessDelete])
							if(Bool_DeleteAllowed(client, true) && Bool_DeleteValid(client, true))
								DeleteProp(client);
					}
					case COMMAND_CONTROL:
					{
						if(g_iPlayerControl[client] > 0)
						{
							if(!IsValidEntity(g_iPlayerControl[client]))
								ClearClientControl(client);
							else
								Menu_Control(client);
						}
						else if(Bool_ControlValid(client, true))
						{
							new iEnt = Trace_GetEntity(client, g_fGrabDistance);
							if(Entity_Valid(iEnt))
								IssueGrab(client, iEnt);

							Menu_Control(client);
						}
					}
					case COMMAND_CLONE:
					{
						if(g_iPlayerControl[client] > 0)
							SpawnClone(client, g_iPlayerControl[client]);
						else
						{
							#if defined _colors_included
							CPrintToChat(client, "%t%t", "prefixChatMessage", "hintNotifyUserControlPropWarningClone");
							#else
							PrintToChat(client, "%t%t", "prefixChatMessage", "hintNotifyUserControlPropWarningClone");
							#endif
						}
					}
					case COMMAND_CHECK:
					{
						if(Bool_CheckValid(client, true))
							Action_CheckProp(client);
					}
					case COMMAND_STUCK:
					{
						if(g_Access[client][bAccessAdminStuck] && !StrEqual(sTrigger[1], "") || CheckCommandAccess(client, "Bw_Access_Stuck", ADMFLAG_RCON))
						{
							new iTarget = FindTarget(client, sTrigger[1], true, true);
							if(iTarget <= 0 || !IsClientInGame(iTarget))
							{
								#if defined _colors_included
								CPrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
								#else
								PrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
								#endif
							}
							else if(!CanUserTarget(client, iTarget))
							{
								#if defined _colors_included
								CPrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetWarningTarget");
								#else
								PrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetWarningTarget");
								#endif
							}
							else
								Menu_AdminConfirmTeleport(client, TARGET_SINGLE, GetClientUserId(iTarget));

							return Plugin_Handled;
						}

						if(g_Access[client][bAccessTeleport])
							if(Bool_TeleportAllowed(client, true) && Bool_TeleportValid(client, true))
								PerformTeleport(client);
					}
					case COMMAND_HELP:
					{
						if(!StrEqual(g_sHelp, ""))
						{
							decl String:sBuffer[192];
							if(g_Access[client][bAdmin] && !StrEqual(sTrigger[1], ""))
							{
								new iTarget = FindTarget(client, sTrigger[1], true, true);
								if(iTarget <= 0 || !IsClientInGame(iTarget))
								{
									#if defined _colors_included
									CPrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
									#else
									PrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
									#endif
								}
								else if(!CanUserTarget(client, iTarget))
								{
									#if defined _colors_included
									CPrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetWarningTarget");
									#else
									PrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetWarningTarget");
									#endif
								}
								else
								{
									Format(sBuffer, 192, "%T", "chatCommandNotifyAdminHelpActivity", LANG_SERVER, iTarget);
									ShowActivity2(client, "[SM] ", sBuffer);

									Format(sBuffer, 192, "%T", "chatCommandLogHelpActivity", LANG_SERVER, client, iTarget);
									LogAction(client, iTarget, sBuffer);

									Format(sBuffer, 192, "%T", "motdHelpTitle", iTarget);
									ShowMOTDPanel(iTarget, sBuffer, g_sHelp, MOTDPANEL_TYPE_URL);

									#if defined _colors_included
									CPrintToChatAll("%t%t", "prefixChatMessage", "chatCommandNotifyUserHelp", client);
									#else
									PrintToChatAll("%t%t", "prefixChatMessage", "chatCommandNotifyUserHelp", client);
									#endif
								}

								return Plugin_Handled;
							}

							Format(sBuffer, 192, "%T", "motdHelpTitle", client);
							ShowMOTDPanel(client, sBuffer, g_sHelp, MOTDPANEL_TYPE_URL);
						}
					}
					case COMMAND_READY:
					{
						if(g_iDebugMode == MODE_NORMAL && g_iReadyPhase & g_iPhase && g_iWallEntities && !g_bReadyInProgress && g_iCurrentTeam[client] >= CS_TEAM_T)
						{
							if(!g_bReady[client])
							{
								if(!g_iReadyWait || g_iNumSeconds >= g_iReadyWait)
								{
									if(g_iReadyTotal >= g_iReadyMinimum)
									{
										if(g_iPhase == PHASE_WAR)
										{
											if(g_bAlive[client])
											{
												g_bReady[client] = true;

												#if defined _colors_included
												CPrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyReadyDeath", client);
												#else
												PrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyReadyDeath", client);
												#endif
											}
										}
										else
										{
											g_bReady[client] = true;

											#if defined _colors_included
											CPrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyReadyWar", client);
											#else
											PrintToChatAll("%t%t", "prefixChatMessage", "chatNotifyReadyWar", client);
											#endif
										}
									}
									else
									{
										#if defined _colors_included
										CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyReadyPopulation", g_iReadyMinimum);
										#else
										PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyReadyPopulation", g_iReadyMinimum);
										#endif
									}
								}
								else
								{
									#if defined _colors_included
									CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyReadyEarly", (g_iReadyWait - g_iNumSeconds));
									#else
									PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyReadyEarly", (g_iReadyWait - g_iNumSeconds));
									#endif
								}
							}
							else
							{
								#if defined _colors_included
								CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyReadyUser", g_iReadyCurrent, g_iReadyNeeded);
								#else
								PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyReadyUser", g_iReadyCurrent, g_iReadyNeeded);
								#endif
							}
						}
					}
					case COMMAND_CLEAR:
					{
						if(g_Access[client][bAccessAdminClear] && !StrEqual(sTrigger[1], "") || CheckCommandAccess(client, "Bw_Access_Clear", ADMFLAG_RCON))
						{
							new iTarget = FindTarget(client, sTrigger[1], true, true);
							if(iTarget <= 0 || !IsClientInGame(iTarget))
							{
								#if defined _colors_included
								CPrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
								#else
								PrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
								#endif
							}
							else if(!CanUserTarget(client, iTarget))
							{
								#if defined _colors_included
								CPrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetWarningTarget");
								#else
								PrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetWarningTarget");
								#endif
							}
							else
								Menu_AdminConfirmDelete(client, TARGET_SINGLE, GetClientUserId(iTarget));

							return Plugin_Handled;
						}

						if(g_Access[client][bAccessClear])
							if(Bool_DeleteAllowed(client, true, true) && Bool_ClearValid(client, true))
								Menu_ConfirmClear(client);
					}
					case COMMAND_THIRD:
					{
						if(g_Access[client][bAccessThird] && g_iCurrentTeam[client] >= CS_TEAM_T)
						{
							if(g_iDisableThirdPerson && g_iDisableThirdPerson & g_iPhase)
							{
								#if defined _colors_included
								CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserThirdRestricted");
								#else
								PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserThirdRestricted");
								#endif
							}
							else
								ToggleThird(client, STATE_AUTO);
						}
					}
					case COMMAND_FLY:
					{
						if(g_Access[client][bAccessFly] && g_iCurrentTeam[client] >= CS_TEAM_T)
						{
							if(g_iDisableFlying && g_iDisableFlying & g_iPhase)
							{
								#if defined _colors_included
								CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserFlyRestricted");
								#else
								PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyUserFlyRestricted");
								#endif
							}
							else
								ToggleFlying(client, STATE_AUTO);
						}
					}
					case COMMAND_PHASE:
					{
						if(Bool_PhaseValid(client, true))
							Action_PhaseProp(client);
					}
				}

				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

public Action:Command_Kill(client, const String:command[], argc)
{
	if(g_bEnabled && (g_iDisableSuicide && g_iDisableSuicide & g_iPhase))
	{
		if(g_bAlive[client] && client > 0 && IsClientInGame(client))
		{
			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatWarningBlockedSuicide");
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatWarningBlockedSuicide");
			#endif
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action:Command_Join(client, const String:command[], argc)
{
	if(g_bEnabled)
	{
		if(client > 0 && IsClientInGame(client))
		{
			decl String:sTemp[3];
			GetCmdArg(1, sTemp, sizeof(sTemp));

			if(g_iCurrentTeam[client])
			{
				if(StringToInt(sTemp) == g_iCurrentTeam[client])
					return Plugin_Handled;
			}
			else if(g_bNotifyNewbies && g_iConfigNewbie[client] > 0)
			{
				#if defined _colors_included
				CPrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyNewPlayers", client);
				#else
				PrintToChat(client, "%t%t", "prefixChatMessage", "chatNotifyNewPlayers", client);
				#endif
			}

			g_iCurrentClass[client] = 0;
		}
	}

	return Plugin_Continue;
}

public Action:Command_Class(client, const String:command[], argc)
{
	if(g_bEnabled)
	{
		if(client > 0 && IsClientInGame(client))
		{
			decl String:sTemp[3];
			GetCmdArg(1, sTemp, sizeof(sTemp));
			new _iTemp = StringToInt(sTemp);

			if(!g_iCurrentClass[client])
			{
				g_iCurrentClass[client] = (_iTemp > 0) ? _iTemp : (g_iCurrentTeam[client] == CS_TEAM_T) ? GetRandomInt(1, 4) : GetRandomInt(5, 8);
				if(!g_bEnding && g_bSpawningIgnore && g_iPlayersRed == 1 && g_iPlayersBlue == 1)
				{
					SetTeamScore(CS_TEAM_T, 0);
					SetTeamScore(CS_TEAM_CT, 0);
					for(new i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i))
						{
							SetEntProp(i, Prop_Data, "m_iFrags", 0);
							SetEntProp(i, Prop_Data, "m_iDeaths", 0);
						}
					}

					CS_TerminateRound(g_fRoundRestart, CSRoundEnd_GameStart);
					return Plugin_Handled;
				}

				switch(g_iPhase)
				{
					case PHASE_LEGACY:
					{
						if(!g_bLegacyPhaseFighting || g_bReturning[client])
							g_hTimer_RespawnPlayer[client] = CreateTimer(0.1, Timer_CheckSpawn, client);
					}
					case PHASE_BUILD:
					{
						g_hTimer_RespawnPlayer[client] = CreateTimer(0.1, Timer_CheckSpawn, client);
					}
					case PHASE_WAR:
					{
						if(g_bReturning[client])
							g_hTimer_RespawnPlayer[client] = CreateTimer(0.1, Timer_CheckSpawn, client);
					}
				}
			}
			else if(g_bAlive[client] && g_iDisableSuicide && g_iDisableSuicide & g_iPhase)
			{
				#if defined _colors_included
				CPrintToChat(client, "%t%t", "prefixChatMessage", "chatWarningBlockedSuicide");
				#else
				PrintToChat(client, "%t%t", "prefixChatMessage", "chatWarningBlockedSuicide");
				#endif
				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

public Action:Command_Spec(client, const String:command[], argc)
{
	if(g_bAfkEnable && g_bAfkSpecKick && !g_bAfk[client])
	{
		if(!g_Access[client][bAfkImmunity])
		{
			g_bAfk[client] = true;
			g_fAfkRemaining[client] = g_fAfkSpecKickDelay;

			if(g_hTimer_AfkCheck[client] != INVALID_HANDLE)
				CloseHandle(g_hTimer_AfkCheck[client]);
			g_hTimer_AfkCheck[client] = CreateTimer(1.0, Timer_SpecNotify, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
	}

	return Plugin_Continue;
}

public Action:Command_Radio(client, const String:command[], argc)
{
	if(g_bEnabled && g_iDisableRadio && g_iDisableRadio & g_iPhase)
	{
		if(client > 0 && IsClientInGame(client))
		{
			#if defined _colors_included
			CPrintToChat(client, "%t%t", "prefixChatMessage", "chatWarningBlockedRadio");
			#else
			PrintToChat(client, "%t%t", "prefixChatMessage", "chatWarningBlockedRadio");
			#endif
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

//*****************************************************************************************
//* ||| 4| Admin Comands
//*****************************************************************************************
public Action:Command_SetProtected(client, args)
{
	if(args < 2)
	{
		ReplyToCommand(client, "Usage: bw_setprotected <cvar> <value>");
		return Plugin_Handled;
	}

	new iBreak;
	decl String:sText[192], String:sBuffer[48], String:sValue[16], String:sCvar[48];
	GetCmdArgString(sText, sizeof(sText));
	if((iBreak = BreakString(sText, sCvar, sizeof(sCvar))) == -1)
	{
		ReplyToCommand(client, "Usage: bw_setprotected <cvar> <value>");
		return Plugin_Handled;
	}
	BreakString(sText[iBreak], sValue, sizeof(sValue));

	new iBuffer, Float:fBuffer;
	new bool:bFound, iSize = GetArraySize(g_hArray_CvarProtected);
	for(new i = 0; i < iSize; i++)
	{
		GetArrayString(g_hArray_CvarProtected, i, sBuffer, sizeof(sBuffer));
		if(!StrEqual(sCvar, sBuffer, false))
			continue;

		switch(GetArrayCell(g_hArray_CvarProtected, i, 12))
		{
			case cCastFloat:
			{
				fBuffer = StringToFloat(sValue);
				SetArrayCell(g_hArray_CvarValues, i, fBuffer);
				SetConVarFloat(GetArrayCell(g_hArray_CvarHandles, i, 0), fBuffer);

				ReplyToCommand(client, "[BuildWars] Protected ConVar %s has had its default value changed to %f.", sBuffer, fBuffer);
			}
			case cCastInteger:
			{
				iBuffer = StringToInt(sValue);
				SetArrayCell(g_hArray_CvarValues, i, iBuffer);
				SetConVarInt(GetArrayCell(g_hArray_CvarHandles, i, 0), iBuffer);

				ReplyToCommand(client, "[BuildWars] Protected ConVar %s has had its default value changed to %d.", sBuffer, iBuffer);
			}
			case cCastString:
			{
				iBuffer = StringToInt(sValue);
				SetArrayString(g_hArray_CvarValues, i, sValue);
				SetConVarInt(GetArrayCell(g_hArray_CvarHandles, i, 0), iBuffer);

				ReplyToCommand(client, "[BuildWars] Protected ConVar %s has had its default value changed to %s.", sBuffer, sValue);
			}
		}

		break;
	}

	if(!bFound)
	{
		new Handle:hTemp = FindConVar(sCvar);
		if(hTemp != INVALID_HANDLE)
		{
			ResizeArray(g_hArray_CvarProtected, iSize + 1);
			ResizeArray(g_hArray_CvarHandles, iSize + 1);
			ResizeArray(g_hArray_CvarValues, iSize + 1);
			ResizeArray(g_hArray_CvarOriginal, iSize + 1);

			SetArrayString(g_hArray_CvarProtected, iSize, sCvar);
			SetArrayCell(g_hArray_CvarHandles, iSize, hTemp, 0);
			if(StrContains(sValue, ".") != -1)
			{
				SetArrayCell(g_hArray_CvarHandles, iSize, cCastFloat, 1);

				fBuffer = StringToFloat(sValue);
				SetArrayCell(g_hArray_CvarValues, iSize, fBuffer);
				SetArrayCell(g_hArray_CvarProtected, iSize, cCastFloat, 12);

				SetArrayCell(g_hArray_CvarOriginal, iSize, GetConVarFloat(hTemp));
				SetConVarFloat(hTemp, fBuffer);

				ReplyToCommand(client, "[BuildWars] Added ConVar %s to the Protected array with a value of %f.", sCvar, fBuffer);
			}
			else if(IsCharNumeric(sValue[0]))
			{
				SetArrayCell(g_hArray_CvarHandles, iSize, cCastInteger, 1);

				iBuffer = StringToInt(sValue);
				SetArrayCell(g_hArray_CvarValues, iSize, iBuffer);
				SetArrayCell(g_hArray_CvarProtected, iSize, cCastInteger, 12);

				SetArrayCell(g_hArray_CvarOriginal, iSize, GetConVarInt(hTemp));
				SetConVarInt(hTemp, iBuffer);

				ReplyToCommand(client, "[BuildWars] Added ConVar %s to the Protected array with a value of %d.", sCvar, iBuffer);
			}
			else
			{
				SetArrayCell(g_hArray_CvarHandles, iSize, cCastString, 1);

				SetArrayString(g_hArray_CvarValues, iSize, sValue);
				SetArrayCell(g_hArray_CvarProtected, iSize, cCastString, 12);

				SetArrayString(g_hArray_CvarOriginal, iSize, sValue);
				SetConVarString(hTemp, sValue);

				ReplyToCommand(client, "[BuildWars] Added ConVar %s to the Protected array with a value of %s.", sCvar, sValue);
			}


			HookConVarChange(hTemp, OnRestrictChange);
		}
		else
			ReplyToCommand(client, "[BuildWars] Could not add ConVar %s to the Protected array as it doesn't exist in the engine!", sCvar);
	}

	return Plugin_Handled;
}

public Action:Command_RemProtected(client, args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "Usage: bw_remprotected <cvar>");
		return Plugin_Handled;
	}

	decl String:sText[192], String:sBuffer[48], String:sCvar[48];
	GetCmdArgString(sText, sizeof(sText));
	BreakString(sText, sCvar, sizeof(sCvar));

	new bool:bFound, iSize = GetArraySize(g_hArray_CvarProtected);
	for(new i = 0; i < iSize; i++)
	{
		GetArrayString(g_hArray_CvarProtected, i, sBuffer, sizeof(sBuffer));
		if(!StrEqual(sCvar, sBuffer, false))
			continue;

		bFound = true;
		new Handle:hTemp = Handle:GetArrayCell(g_hArray_CvarHandles, i, 0);
		UnhookConVarChange(hTemp, OnRestrictChange);

		switch(GetArrayCell(g_hArray_CvarProtected, i, 12))
		{
			case cCastFloat:
				SetConVarFloat(hTemp, Float:GetArrayCell(g_hArray_CvarOriginal, i));
			case cCastInteger:
				SetConVarInt(hTemp, GetArrayCell(g_hArray_CvarOriginal, i));
			case cCastString:
			{
				decl String:sValue[64];
				GetArrayString(g_hArray_CvarOriginal, i, sValue, sizeof(sValue));
				SetConVarString(hTemp, sValue);
			}
		}

		RemoveFromArray(g_hArray_CvarProtected, i);
		RemoveFromArray(g_hArray_CvarHandles, i);
		RemoveFromArray(g_hArray_CvarOriginal, i);
		RemoveFromArray(g_hArray_CvarValues, i);

		ReplyToCommand(client, "[BuildWars] Removed ConVar %s from the Protected array; it will no longer have its value reset!", sCvar);
		CloseHandle(hTemp);
		break;
	}

	if(!bFound)
		ReplyToCommand(client, "[BuildWars] Could not remove ConVar %s from the Protected array as it doesn't exist in the engine!", sCvar);

	return Plugin_Handled;
}

public Action:Command_Gimp(client, args)
{
	if(g_bEnabled)
	{
		if(args < 1)
		{
			ReplyToCommand(client, "%t", "chatCommandNotifyAdminGimpArguments");
			return Plugin_Handled;
		}

		new iMinutes, iTarget;
		decl String:sPattern[64], String:sBuffer[192];
		GetCmdArg(1, sPattern, 64);
		if(args >= 2)
		{
			decl String:sDuration[16];
			GetCmdArg(2, sDuration, sizeof(sDuration));
			iMinutes = StringToInt(sDuration);
		}

		if(args == 1 || iMinutes <= 0 || iMinutes > 2147483647)
			iMinutes = g_iGimpDefault;

		iTarget = FindTarget(client, sPattern, true, true);
		if(iTarget > 0 && IsClientInGame(iTarget))
		{
			if(g_hTimer_ExpireGimp[iTarget] != INVALID_HANDLE && CloseHandle(g_hTimer_ExpireGimp[iTarget]))
				g_hTimer_ExpireGimp[iTarget] = INVALID_HANDLE;

			new iEnding;
			GetMapTimeLeft(iEnding);
			iEnding += g_iCurrentTime;
			g_iPlayerGimp[iTarget] = (iMinutes * 60) + g_iCurrentTime;
			IntToString(g_iPlayerGimp[iTarget], sPattern, 64);
			SetClientCookie(iTarget, g_cCookieGimp, sPattern);

			Format(sBuffer, 192, "%T", "chatCommandNotifyAdminGimpActivity", LANG_SERVER, iTarget, iMinutes);
			ShowActivity2(client, "[SM] ", sBuffer);

			Format(sBuffer, 192, "%T", "chatCommandLogGimpActivity", LANG_SERVER, client, iTarget, iMinutes);
			LogAction(client, iTarget, sBuffer);

			#if defined _colors_included
			CPrintToChat(iTarget, "%t%t", "prefixChatMessage", "chatCommandNotifyUserGimp", iMinutes);
			CPrintToChat(iTarget, "%t%t", "prefixChatMessage", "chatCommandNotifyUserGimp2");
			#else
			PrintToChat(iTarget, "%t%t", "prefixChatMessage", "chatCommandNotifyUserGimp", iMinutes);
			PrintToChat(iTarget, "%t%t", "prefixChatMessage", "chatCommandNotifyUserGimp2");
			#endif

			if(iEnding > g_iPlayerGimp[iTarget])
				g_hTimer_ExpireGimp[iTarget] = CreateTimer(float(iEnding - g_iPlayerGimp[iTarget]), Timer_GimpExpire, iTarget, TIMER_FLAG_NO_MAPCHANGE);

			CancelClientMenu(iTarget, true);
			Menu_Main(iTarget);
		}
	}

	return Plugin_Handled;
}

public Action:Command_List(client, args)
{
	if(g_bEnabled)
	{
		if(!client)
		{
			decl String:sBuffer[192];
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i))
				{
					if(g_iPlayerGimp[i])
					{
						FormatTime(sBuffer, sizeof(sBuffer), NULL_STRING, g_iPlayerGimp[i]);
						ReplyToCommand(client, "%T%T", "prefixConsoleMessage", client, "Command_List_Gimped", client, i, sBuffer);
					}
					else
						ReplyToCommand(client, "%T%T", "prefixConsoleMessage", client, "Command_List_Not_Gimped", client, i);
				}
			}
		}
		else
		{
			Menu_List(client);
		}
	}

	return Plugin_Handled;
}

Menu_List(client, index = 0)
{
	decl String:sBuffer[192], String:sOption[8];
	new iGimped, Handle:hMenu = CreateMenu(MenuHandler_MenuList);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && g_iPlayerGimp[i])
		{
			iGimped++;
			Format(sOption, sizeof(sOption), "%d", GetClientUserId(i));
			Format(sBuffer, sizeof(sBuffer), "%T", "Menu_List_Player", client, i);
			AddMenuItem(hMenu, sOption, sBuffer);
		}
	}

	if(!iGimped)
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "Menu_List_None", client);
		AddMenuItem(hMenu, "0", sBuffer);
	}

	DisplayMenuAtItem(hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_MenuList(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Select:
		{
			decl String:sOption[32];
			GetMenuItem(menu, param2, sOption, sizeof(sOption));
			new target = StringToInt(sOption) > 0 ? GetClientOfUserId(StringToInt(sOption)) : 0;
			if(target > 0 && IsClientInGame(target))
			{
				FormatTime(sOption, sizeof(sOption), NULL_STRING, g_iPlayerGimp[target]);

				#if defined _colors_included
				CPrintToChat(param1, "%t%t", "prefixChatMessage", "Menu_List_Player_Info", target, sOption);
				#else
				PrintToChat(param1, "%t%t", "prefixChatMessage", "Menu_List_Player_Info", target, sOption);
				#endif
			}

			Menu_List(param1, GetMenuSelectionPosition());
		}
	}
}

public Action:Command_UnGimp(client, args)
{
	if(g_bEnabled)
	{
		if(args < 1)
		{
			ReplyToCommand(client, "%t", "chatCommandNotifyAdminDeGimpArguments");
			return Plugin_Handled;
		}

		new iTarget;
		decl String:sPattern[64], String:sBuffer[192];
		GetCmdArg(1, sPattern, 64);

		iTarget = FindTarget(client, sPattern, true, true);
		if(iTarget && IsClientInGame(iTarget))
		{
			if(g_hTimer_ExpireGimp[iTarget] != INVALID_HANDLE && CloseHandle(g_hTimer_ExpireGimp[iTarget]))
				g_hTimer_ExpireGimp[iTarget] = INVALID_HANDLE;

			if(g_iPlayerGimp[iTarget])
			{
				g_iPlayerGimp[iTarget] = 0;
				SetClientCookie(iTarget, g_cCookieGimp, "0");

				Format(sBuffer, 192, "%T", "chatCommandNotifyAdminDeGimpActivity", LANG_SERVER, iTarget);
				ShowActivity2(client, "[SM] ", sBuffer);

				Format(sBuffer, 192, "%T", "chatCommandLogDeGimpActivity", LANG_SERVER, client, iTarget);
				LogAction(client, iTarget, sBuffer);

				#if defined _colors_included
				CPrintToChat(iTarget, "%t%t", "prefixChatMessage", "chatCommandNotifyUserDeGimp");
				#else
				PrintToChat(iTarget, "%t%t", "prefixChatMessage", "chatCommandNotifyUserDeGimp");
				#endif
			}
			else
			{
				#if defined _colors_included
				CPrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminDeGimpWarning", iTarget);
				#else
				PrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminDeGimpWarning", iTarget);
				#endif
			}
		}
	}

	return Plugin_Handled;
}

public Action:Command_Update(client, args)
{
	if(g_bEnabled)
	{
		decl String:sBuffer[64];
		GetCmdArgString(sBuffer, 64);
		if(StrEqual(sBuffer, "3.4.0 Maps", false))
		{
			decl String:sPath[PLATFORM_MAX_PATH], String:sQuery[384];
			BuildPath(Path_SM, sPath, sizeof(sPath), "configs/buildwars/buildwars.maps.cfg");

			new Handle:hKeyValues = CreateKeyValues("BuildWars_Maps");
			if(!FileToKeyValues(hKeyValues, sPath) || !KvGotoFirstSubKey(hKeyValues, false))
				ReplyToCommand(client, "[BuildWars] Update Failure - Reason: \"configs/buildwars/buildwars.maps.cfg\" not found.");
			else
			{
				ReplyToCommand(client, "[BuildWars] Issuing Queries");
				do
				{
					KvGetSectionName(hKeyValues, sPath, sizeof(sPath));
					KvGetString(hKeyValues, NULL_STRING, sBuffer, sizeof(sBuffer));

					new Handle:hPack = CreateDataPack();
					WritePackCell(hPack, client ? GetClientUserId(client) : 0);
					WritePackString(hPack, sPath);
					WritePackString(hPack, sBuffer);

					Format(sQuery, sizeof(sQuery), "SELECT `wall` FROM `buildwars_maps` WHERE `map` = '%s'", sPath, DBPrio_High);
					SQL_TQuery(g_hSql_Database, CallBack_UpdateMapsQuery, sQuery, hPack);
				}
				while (KvGotoNextKey(hKeyValues, false));
			}
		}
	}

	return Plugin_Handled;
}

public CallBack_UpdateMapsQuery(Handle:owner, Handle:hndl, const String:error[], any:pack)
{
	ErrorCheck(owner, error, "CallBack_UpdateMaps");

	ResetPack(pack);
	ReadPackCell(pack);
	decl String:sTargetname[64], String:sMap[64];
	ReadPackString(pack, sMap, sizeof(sMap));
	ReadPackString(pack, sTargetname, sizeof(sTargetname));

	decl String:sQuery[384];
	if(!SQL_GetRowCount(hndl))
	{
		Format(sQuery, sizeof(sQuery), "INSERT INTO `buildwars_maps` (`map`,`wall`,`played`) VALUES ('%s', '%s', 0)", sMap, sTargetname);
		SQL_TQuery(g_hSql_Database, CallBack_UpdateMaps, sQuery, pack);
	}
	else if(SQL_FetchRow(hndl))
	{
		Format(sQuery, sizeof(sQuery), "UPDATE `buildwars_maps` SET `wall` = '%s' WHERE `map` = '%s'", sTargetname, sMap);
		SQL_TQuery(g_hSql_Database, CallBack_UpdateMaps, sQuery, pack);
	}
}

public CallBack_UpdateMaps(Handle:owner, Handle:hndl, const String:error[], any:pack)
{
	ErrorCheck(owner, error, "CallBack_UpdateMaps");

	ResetPack(pack);
	new iUser = ReadPackCell(pack);
	new iClient = iUser ? GetClientOfUserId(iUser) : 0;
	decl String:sTargetname[64], String:sMap[64];
	ReadPackString(pack, sMap, sizeof(sMap));
	ReadPackString(pack, sTargetname, sizeof(sTargetname));
	CloseHandle(pack);

	if(iUser && (!iClient || !IsClientInGame(iClient)))
		return;

	#if defined _colors_included
	CPrintToChatAll("%tMap '%s' has had its wall set to '%s'", "prefixChatMessage", sMap, sTargetname);
	#else
	PrintToChatAll("%tMap '%s' has had its wall set to '%s'", "prefixChatMessage", sMap, sTargetname);
	#endif
}

public Action:Command_Chat(args)
{
	if(g_bEnabled)
	{
		decl String:sBuffer[192];
		GetCmdArgString(sBuffer, 192);

		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				#if defined _colors_included
				CPrintToChat(i, "%t%s", "prefixChatMessage", sBuffer);
				#else
				PrintToChat(i, "%t%s", "prefixChatMessage", sBuffer);
				#endif
			}
		}
	}

	return Plugin_Handled;
}

public Action:Command_Hint(args)
{
	if(g_bEnabled)
	{
		decl String:sBuffer[192];
		GetCmdArgString(sBuffer, 192);

		for(new i = 1; i <= MaxClients; i++)
			if(IsClientInGame(i))
				PrintHintText(i, "%t%s", "prefixHintMessage", sBuffer);
	}

	return Plugin_Handled;
}

public Action:Command_Key(args)
{
	if(g_bEnabled)
	{
		decl String:sBuffer[192];
		GetCmdArgString(sBuffer, 192);
		Format(sBuffer, 192, "%T%s", "prefixKeyHintMessage", LANG_SERVER, sBuffer);

		if(g_bGlobalOffensive)
			PrintHintTextToAll(sBuffer);
		else
		{
			new Handle:hMessage = StartMessageAll("KeyHintText");
			BfWriteByte(hMessage, 1);
			BfWriteString(hMessage, sBuffer);
			EndMessage();
		}
	}

	return Plugin_Handled;
}

public Action:Command_Center(args)
{
	if(g_bEnabled)
	{
		decl String:sBuffer[192];
		GetCmdArgString(sBuffer, 192);

		for(new i = 1; i <= MaxClients; i++)
			if(IsClientInGame(i))
				PrintCenterText(i, "%t%s", "prefixCenterMessage", sBuffer);
	}

	return Plugin_Handled;
}

public Action:Command_Color(client, args)
{
	if(!client)
		return Plugin_Handled;

	if(args < 1)
	{
		ReplyToCommand(client, "%t", "chatCommandNotifyAdminColorArguments");
		return Plugin_Handled;
	}

	new iTmpEnt = GetClientAimTarget(client, false);
	if(iTmpEnt == -1 || !IsValidEntity(iTmpEnt) || iTmpEnt <= MaxClients)
	{
		ReplyToCommand(client, "%t", "chatCommandNotifyAdminTargetWarningEntity");
		return Plugin_Handled;
	}

	decl String:sClassname[64];
	GetEntityClassname(iTmpEnt, sClassname, sizeof(sClassname));
	if(StrContains(sClassname, "prop_", false) == -1 && StrContains(sClassname, "func_", false) == -1)
	{
		ReplyToCommand(client, "%t", "chatCommandNotifyAdminTargetWarningEntity");
		return Plugin_Handled;
	}

	decl String:sTargetname[64], String:sBuffer[192], String:sArray[4][4], iArray[4];
	GetEntPropString(iTmpEnt, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));
	GetCmdArgString(sBuffer, sizeof(sBuffer));
	new iArgs = ExplodeString(sBuffer, " ", sArray, sizeof(sArray), sizeof(sArray[]));
	for(new i = 0; i < iArgs; i++)
	{
		iArray[i] = StringToInt(sArray[i]);
		if(iArray[i] < 0 || iArray[i] > 255)
			iArray[i] = 255;
	}
	for(new i = iArgs; i <= 3; i++)
		iArray[i] = 255;

	SetEntityRenderColor(iTmpEnt, iArray[0], iArray[1], iArray[2], iArray[3]);

	Format(sBuffer, sizeof(sBuffer), "%T", "chatCommandNotifyAdminColorActivity", LANG_SERVER, iArray[0], iArray[1], iArray[2], iArray[3], sClassname, sTargetname, iTmpEnt);
	ShowActivity2(client, "[SM] ", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "chatCommandLogColorActivity", LANG_SERVER, iArray[0], iArray[1], iArray[2], iArray[3], sClassname, sTargetname, iTmpEnt, client);
	LogAction(client, -1, sBuffer);

	return Plugin_Handled;
}

public Action:Command_Fx(client, args)
{
	if(!client)
		return Plugin_Handled;

	if(args < 1)
	{
		ReplyToCommand(client, "%t", "chatCommandNotifyAdminModeArguments");
		return Plugin_Handled;
	}

	new iTmpEnt = GetClientAimTarget(client, false);
	if(iTmpEnt == -1 || !IsValidEntity(iTmpEnt) || iTmpEnt <= MaxClients)
	{
		ReplyToCommand(client, "%t", "chatCommandNotifyAdminTargetWarningEntity");
		return Plugin_Handled;
	}

	decl String:sClassname[64];
	GetEntityClassname(iTmpEnt, sClassname, sizeof(sClassname));
	if(StrContains(sClassname, "prop_", false) == -1 && StrContains(sClassname, "func_", false) == -1)
	{
		ReplyToCommand(client, "%t", "chatCommandNotifyAdminTargetWarningEntity");
		return Plugin_Handled;
	}

	decl String:sTargetname[64], String:sRender[4];
	GetEntPropString(iTmpEnt, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));
	new iRender = 0;
	GetCmdArg(1, sRender, sizeof(sRender));
	StringToIntEx(sRender, iRender);
	if(iRender < 0 || iRender > 25)
		iRender = 0;

	SetEntityRenderFx(iTmpEnt, RenderFx:iRender);

	decl String:sBuffer[192];
	Format(sBuffer, sizeof(sBuffer), "%T", "chatCommandNotifyAdminModeActivity", LANG_SERVER, iRender, sClassname, sTargetname, iTmpEnt);
	ShowActivity2(client, "[SM] ", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "chatCommandLogModeActivity", LANG_SERVER, iRender, sClassname, sTargetname, iTmpEnt, client);
	LogAction(client, -1, sBuffer);

	return Plugin_Handled;
}

public Action:Command_Wall(client, args)
{
	if(!client)
		return Plugin_Handled;

	new iTmpEnt = GetClientAimTarget(client, false);
	if(iTmpEnt <= 0 || !IsValidEntity(iTmpEnt) || iTmpEnt <= MaxClients)
	{
		#if defined _colors_included
		CPrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminWallWarning");
		#else
		PrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminWallWarning");
		#endif
		return Plugin_Handled;
	}

	new iValue;
	decl String:sClassname[64];
	GetEntityClassname(iTmpEnt, sClassname, sizeof(sClassname));
	if(!GetTrieValue(g_hTrie_CfgWalls, sClassname, iValue))
	{
		#if defined _colors_included
		CPrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminWallWarning");
		#else
		PrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminWallWarning");
		#endif
		return Plugin_Handled;
	}

	decl String:sTargetname[64], String:sNewWall[256];
	GetEntPropString(iTmpEnt, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));
	if(StrContains(g_sWallData, sTargetname) == -1 && !StrEqual(sTargetname, "BuildWars:Wall"))
	{
		Format(sNewWall, sizeof(sNewWall), "%s,%s", g_sWallData, sTargetname);
		new iPosition = FindCharInString(sNewWall, ',');
		if(iPosition == 0)
			strcopy(g_sWallData, sizeof(g_sWallData), sNewWall[1]);
	}
	else
	{
		#if defined _colors_included
		CPrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminWallExistsWarning");
		#else
		PrintToChat(client, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminWallExistsWarning");
		#endif
		return Plugin_Handled;
	}

	new Handle:hPack = CreateDataPack();
	WritePackCell(hPack, GetClientUserId(client));
	WritePackString(hPack, sTargetname);

	Format(sNewWall, sizeof(sNewWall), "UPDATE `buildwars_maps` SET `wall` = '%s' WHERE `map` = '%s'", g_sWallData, g_sCurrentMap);
	SQL_TQuery(g_hSql_Database, CallBack_AddWall, sNewWall, hPack);

	return Plugin_Handled;
}

public CallBack_AddWall(Handle:owner, Handle:hndl, const String:error[], any:pack)
{
	ErrorCheck(owner, error, "CallBack_AddWall");

	ResetPack(pack);
	new iClient = GetClientOfUserId(ReadPackCell(pack));
	decl String:sTargetname[64];
	ReadPackString(pack, sTargetname, sizeof(sTargetname));
	CloseHandle(pack);

	if(DetectWallEntities() && g_iBuildDuration)
	{
		g_iNumSeconds = 0;
		g_iCurrentDisable = g_iBuildDisable;
		FowardPhaseChange(PHASE_BUILD);
	}

	if(!iClient || !IsClientInGame(iClient))
		return;

	#if defined _colors_included
	CPrintToChat(iClient, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminWallSuccess", sTargetname);
	#else
	PrintToChat(iClient, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminWallSuccess", sTargetname);
	#endif
}

public Action:Command_Mode(client, args)
{
	if(!client)
		return Plugin_Handled;

	if(args < 1)
	{
		ReplyToCommand(client, "%t", "chatCommandNotifyAdminEffectArguments");
		return Plugin_Handled;
	}

	new iTmpEnt = GetClientAimTarget(client, false);
	if(iTmpEnt == -1 || !IsValidEntity(iTmpEnt) || iTmpEnt <= MaxClients)
	{
		ReplyToCommand(client, "%t", "chatCommandNotifyAdminTargetWarningEntity");
		return Plugin_Handled;
	}

	decl String:sClassname[64];
	GetEntityClassname(iTmpEnt, sClassname, sizeof(sClassname));
	if(StrContains(sClassname, "prop_", false) == -1 && StrContains(sClassname, "func_", false) == -1)
	{
		ReplyToCommand(client, "%t", "chatCommandNotifyAdminTargetWarningEntity");
		return Plugin_Handled;
	}

	decl String:sTargetname[64], String:sEffect[4];
	GetEntPropString(iTmpEnt, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));
	new iEffect = 0;
	GetCmdArg(1, sEffect, sizeof(sEffect));
	StringToIntEx(sEffect, iEffect);
	if(iEffect < 0 || iEffect > 11)
		iEffect = 0;

	SetEntityRenderMode(iTmpEnt, RenderMode:iEffect);

	decl String:sBuffer[192];
	Format(sBuffer, sizeof(sBuffer), "%T", "chatCommandNotifyAdminEffectActivity", LANG_SERVER, iEffect, sClassname, sTargetname, iTmpEnt);
	ShowActivity2(client, "[SM] ", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "chatCommandLogEffectActivity", LANG_SERVER, iEffect, sClassname, sTargetname, iTmpEnt, client);
	LogAction(client, -1, sBuffer);

	return Plugin_Handled;
}

public Action:Command_Info(client, args)
{
	if(!client)
		return Plugin_Handled;

	new iTmpEnt = GetClientAimTarget(client, false);
	if(iTmpEnt == -1 || !IsValidEntity(iTmpEnt) || iTmpEnt <= MaxClients)
	{
		ReplyToCommand(client, "%t", "chatCommandNotifyAdminTargetWarningEntity");
		return Plugin_Handled;
	}

	decl String:sClassname[64];
	GetEntityClassname(iTmpEnt, sClassname, sizeof(sClassname));
	if(StrContains(sClassname, "prop_", false) == -1 && StrContains(sClassname, "func_", false) == -1)
	{
		ReplyToCommand(client, "%t", "chatCommandNotifyAdminTargetWarningEntity");
		return Plugin_Handled;
	}

	decl String:sTargetname[64], Float:fArray[3];
	GetEntPropString(iTmpEnt, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

	ReplyToCommand(client, "Entity Info - Index (%d)", iTmpEnt);
	ReplyToCommand(client, "- Class Name: %s, Target Name: %s", sClassname, sTargetname);
	GetEntPropVector(iTmpEnt, Prop_Send, "m_vecOrigin", fArray);
	ReplyToCommand(client, "- Position: %f %f %f", fArray[0], fArray[1], fArray[2]);
	GetEntPropVector(iTmpEnt, Prop_Send, "m_angRotation", fArray);
	ReplyToCommand(client, "- Rotation: %f %f %f", fArray[0], fArray[1], fArray[2]);
	ReplyToCommand(client, "- Prop (%s), Base (%s), Grabbed (%s), Saving (%s), Deleting (%s), Phased (%s)", (g_iPropState[iTmpEnt] & STATE_VALID ? "Y" : "N"), (g_iPropState[iTmpEnt] & STATE_BASE ? "Y" : "N"), (g_iPropState[iTmpEnt] & STATE_GRABBED ? "Y" : "N"), (g_iPropState[iTmpEnt] & STATE_SAVED ? "Y" : "N"), (g_iPropState[iTmpEnt] & STATE_DELETED ? "Y" : "N"), (g_iPropState[iTmpEnt] & STATE_PHASE ? "Y" : "N"));

	return Plugin_Handled;
}

Menu_AdminZones(client)
{
	decl String:sBuffer[128];
	new Handle:hMenu = CreateMenu(MenuHandler_AdminZones);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuZonesTitle", client);
	SetMenuTitle(hMenu, sBuffer);

	if(CheckCommandAccess(client, "Bw_Access_Zone_Add", ADMFLAG_RCON))
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "menuZonesCreateZone", client);
		AddMenuItem(hMenu, "0", sBuffer);
	}

	if(CheckCommandAccess(client, "Bw_Access_Zone_Rem", ADMFLAG_RCON))
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "menuZonesRemoveZone", client);
		AddMenuItem(hMenu, "1", sBuffer);
	}

	if(CheckCommandAccess(client, "Bw_Access_Zone_View", ADMFLAG_RCON))
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "menuZonesViewZones", client);
		AddMenuItem(hMenu, "2", sBuffer);

		Format(sBuffer, sizeof(sBuffer), "%T", "menuZonesViewSpawns", client);
		AddMenuItem(hMenu, "4", sBuffer);
	}

	Format(sBuffer, sizeof(sBuffer), "%T", "menuZonesHelp", client);
	AddMenuItem(hMenu, "3", sBuffer);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminZones(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Admin(param1);
			}
		}
		case MenuAction_Select:
		{
			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);

			switch(StringToInt(sOption))
			{
				case 0:
				{
					RestartMapZoneEditor(param1);
					g_iZoneEditor[param1][Step] = 1;
					DisplaySelectPointMenu(param1, 1);
				}
				case 1:
				{
					DeleteMapZone(param1);
					Menu_AdminZones(param1);
				}
				case 2:
				{
					if(!g_iTotalZones)
					{
						#if defined _colors_included
						CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatZonesUndefined");
						#else
						PrintToChat(param1, "%t%t", "prefixChatMessage", "chatZonesUndefined");
						#endif
					}
					else
						DrawMapZones();
					Menu_AdminZones(param1);
				}
				case 3:
				{
					for(new i = 0; i < TOTAL_ZONE_HELP; i++)
					{
						#if defined _colors_included
						CPrintToChat(param1, "%t%s", "prefixChatMessage", g_sZoneHelp[i]);
						#else
						PrintToChat(param1, "%t%s", "prefixChatMessage", g_sZoneHelp[i]);
						#endif
					}
				}
				case 4:
				{
					DrawSpawnPoints(param1);
					Menu_AdminZones(param1);
				}
			}
		}
	}
}

//*****************************************************************************************
//* |||  | Client
//*****************************************************************************************
public OnClientConnected(client)
{
	if(g_bEnabled)
	{
		g_iCurrentClass[client] = 0;
		g_iLastTeam[client] = 0;
		g_iPlayerProps[client] = 0;
		g_iPlayerColors[client] = 0;
		g_iPlayerDeletes[client] = 0;
		g_iPlayerTeleports[client] = 0;
		g_iPlayerColors[client] = 0;
		g_iPlayerPrevious[client] = -1;

		g_bActivity[client] = false;
		g_bTeleported[client] = false;
		g_bResetSpeed[client] = false;
		g_bResetGravity[client] = false;
		g_bThirdPerson[client] = false;
		g_bFlying[client] = false;

		g_iPlayerBaseCurrent[client] = -1;

		ClearClientAccess(client);
	}
}

public OnClientPutInServer(client)
{
	if(g_bEnabled)
	{
		if(client > 0)
		{
			g_bCustomToggle[client][FUNCTION_KEY_USE] = false;
			g_bCustomToggle[client][FUNCTION_KEY_LEFT] = false;
			g_bCustomToggle[client][FUNCTION_KEY_RIGHT] = false;

			GetClientName(client, g_sName[client], 32);
			SDKHook(client, SDKHook_WeaponSwitchPost, Hook_WeaponSwitchPost);
			SDKHook(client, SDKHook_WeaponEquipPost, Hook_WeaponEquipPost);
			SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
			SDKHook(client, SDKHook_PostThinkPost, Hook_PostThinkPost);
			SDKHook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
			SDKHook(client, SDKHook_PreThinkPost, Hook_PreThinkPost);

			if(g_bAfkEnable && g_bAfkAutoSpec && !g_iCurrentTeam[client])
				g_hTimer_AfkCheck[client] = CreateTimer(g_fAfkForceSpecDelay, Timer_AfkAutoSpec, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public OnClientPostAdminCheck(client)
{
	if(g_bEnabled)
	{
		if(client > 0)
		{
			GetClientAuthId(client, AuthId_SteamID64, g_sAuthString[client], sizeof(g_sAuthString[]), true);
			LoadClientAccess(client);

			if(!g_bCookiesLoaded[client] && AreClientCookiesCached(client))
				LoadClientCookies(client);

			if(g_Access[client][bAccessBase])
				LoadClientBase(client);

			if(g_bPersistentRounds)
				LoadClientData(client);
		}
	}
}

public OnClientDisconnect(client)
{
	if(g_bEnabled)
	{
		if(g_bPersistentRounds)
			SaveClientData(client);
		else
			Bool_ClearClientProps(client);

		ClearClientControl(client);
		ClearClientTeleport(client);
		ClearClientRespawn(client);
		ClearClientAfk(client);
		ClearClientGimp(client);
		if(g_bDatabaseFound && g_hSql_Database != INVALID_HANDLE)
		{
			if(g_Access[client][bAccessBase])
			{
				decl String:_sQuery[256];
				for(new i = 0; i < g_Access[client][iTotalBases]; i++)
				{
					Format(_sQuery, sizeof(_sQuery), g_sSQL_BaseUpdate, g_iPlayerBaseCount[client][i], g_iPlayerBase[client][i]);
					SQL_TQuery(g_hSql_Database, SQL_QueryBaseUpdatePost, _sQuery, GetClientUserId(client));
				}

				if(g_bCurrentSave[client])
				{
					if(g_hTimer_CurrentSave[client] != INVALID_HANDLE && CloseHandle(g_hTimer_CurrentSave[client]))
						g_hTimer_CurrentSave[client] = INVALID_HANDLE;

					g_bCurrentSave[client] = false;
				}
			}
		}

		if(g_iCurrentTeam[client] >= CS_TEAM_T)
		{
			new iIndex = Array_Index(client, g_iCurrentTeam[client]);
			Array_Remove(iIndex, g_iCurrentTeam[client]);
		}

		g_iCurrentTeam[client] = 0;
		g_iLastDrawTime[client] = 0;
		g_iLastDrawZone[client] = -1;
		g_bAlive[client] = false;
		if(g_bReady[client] && g_bReadyInProgress && g_iReadyCurrent < g_iReadyNeeded)
			g_bReadyInProgress = false;
		g_bReady[client] = false;
		g_bCookiesLoaded[client] = false;
		g_bAccessLoaded[client] = false;

		if(g_bSpawningIgnore)
		{
			new iRed, iBlue;
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && g_bAlive[i])
				{
					switch(g_iCurrentTeam[i])
					{
						case CS_TEAM_T:
							iRed++;
						case CS_TEAM_CT:
							iBlue++;
					}
				}
			}

			if(!iRed)
			{
				SetTeamScore(CS_TEAM_CT, (GetTeamScore(CS_TEAM_CT) + 1));
				CS_TerminateRound(g_fRoundRestart, CSRoundEnd_CTWin);
			}
			else if(!iBlue)
			{
				SetTeamScore(CS_TEAM_T, (GetTeamScore(CS_TEAM_T) + 1));
				CS_TerminateRound(g_fRoundRestart, CSRoundEnd_TerroristWin);
			}
		}
	}
}

public OnClientCookiesCached(client)
{
	if(g_bEnabled)
	{
		if(!g_bCookiesLoaded[client] && g_bAccessLoaded[client])
			LoadClientCookies(client);
	}
}

LoadClientCookies(client)
{
	decl String:sTemp[32], String:sCookie[8] = "";
	GetClientCookie(client, g_cCookieVersion, sTemp, 32);

	if(StrEqual(sTemp, "", false))
	{
		SetClientCookie(client, g_cCookieVersion, PLUGIN_VERSION);
		SetClientCookie(client, g_cCookieGimp, "0");

		g_iPlayerRotation[client] = g_iCfg_DefaultRotation;
		IntToString(g_iPlayerRotation[client], sCookie, sizeof(sCookie));
		SetClientCookie(client, g_cCookieRotation, sCookie);

		g_iPlayerPosition[client] = g_iCfg_DefaultPosition;
		IntToString(g_iPlayerPosition[client], sCookie, sizeof(sCookie));
		SetClientCookie(client, g_cCookiePosition, sCookie);

		g_iPlayerColor[client] = GetRandomInt(0, g_iNumColors - 1);
		IntToString(g_iPlayerColor[client], sCookie, sizeof(sCookie));
		SetClientCookie(client, g_cCookieColor, sCookie);

		g_iPlayerCustom[client][FUNCTION_KEY_USE] = FUNCTION_DISABLED;
		g_iPlayerCustom[client][FUNCTION_KEY_LEFT] = FUNCTION_MAIN_MENU;
		g_iPlayerCustom[client][FUNCTION_KEY_RIGHT] = FUNCTION_MODIFY_MENU;
		Format(sTemp, sizeof(sTemp), "%d %d %d", FUNCTION_DISABLED, FUNCTION_MAIN_MENU, FUNCTION_MODIFY_MENU);
		SetClientCookie(client, g_cCookieCustom, sTemp);

		g_bPlayerControl[client] = false;
		SetClientCookie(client, g_cCookieControl, "0");

		g_fConfigDistance[client] = 150.0;
		FloatToString(g_fConfigDistance[client], sCookie, sizeof(sCookie));
		SetClientCookie(client, g_cCookieDistance, sCookie);

		g_iConfigNewbie[client] = 3;
		SetClientCookie(client, g_cCookieNewbie, "3");
	}
	else
	{
		GetClientCookie(client, g_cCookieGimp, sTemp, 32);
		g_iPlayerGimp[client] = StringToInt(sTemp);

		if(g_iPlayerGimp[client] > g_iCurrentTime)
		{
			new iEnding;
			GetMapTimeLeft(iEnding);
			iEnding += g_iCurrentTime;

			if(iEnding > g_iPlayerGimp[client])
				g_hTimer_ExpireGimp[client] = CreateTimer(float(iEnding - g_iPlayerGimp[client]), Timer_GimpExpire, client, TIMER_FLAG_NO_MAPCHANGE);
		}
		else if(g_iPlayerGimp[client])
		{
			g_iPlayerGimp[client] = 0;
			SetClientCookie(client, g_cCookieGimp, "0");
		}

		if(g_bNotifyNewbies)
		{
			GetClientCookie(client, g_cCookieNewbie, sCookie, sizeof(sCookie));
			g_iConfigNewbie[client] = StringToInt(sCookie);

			if(g_iConfigNewbie[client] > 0)
			{
				g_iConfigNewbie[client]--;

				IntToString(g_iConfigNewbie[client], sCookie, sizeof(sCookie));
				SetClientCookie(client, g_cCookieNewbie, sCookie);
			}
		}

		if(g_Access[client][bAccessRotate])
		{
			GetClientCookie(client, g_cCookieRotation, sCookie, sizeof(sCookie));
			g_iPlayerRotation[client] = StringToInt(sCookie);

			if(g_iPlayerRotation[client] >= g_iCfg_TotalRotations)
			{
				g_iPlayerRotation[client] = g_iCfg_DefaultRotation;
				IntToString(g_iPlayerRotation[client], sCookie, sizeof(sCookie));
				SetClientCookie(client, g_cCookieRotation, sCookie);
			}
		}

		if(g_Access[client][bAccessMove])
		{
			GetClientCookie(client, g_cCookiePosition, sCookie, sizeof(sCookie));
			g_iPlayerPosition[client] = StringToInt(sCookie);

			if(g_iPlayerPosition[client] >= g_iCfg_TotalPositions)
			{
				g_iPlayerPosition[client] = g_iCfg_DefaultPosition;
				IntToString(g_iPlayerPosition[client], sCookie, sizeof(sCookie));
				SetClientCookie(client, g_cCookiePosition, sCookie);
			}
		}

		if(!g_Access[client][bAccessColor])
		{
			GetClientCookie(client, g_cCookieColor, sCookie, sizeof(sCookie));
			g_iPlayerColor[client] = StringToInt(sCookie);

			if(g_iPlayerColor[client] >= g_iNumColors)
			{
				g_iPlayerColor[client] = GetRandomInt(0, g_iNumColors - 1);
				IntToString(g_iPlayerColor[client], sCookie, sizeof(sCookie));
				SetClientCookie(client, g_cCookieColor, sCookie);
			}
		}

		if(g_Access[client][bAccessControl])
		{
			GetClientCookie(client, g_cCookieDistance, sCookie, sizeof(sCookie));
			g_fConfigDistance[client] = StringToFloat(sCookie);

			if(g_fConfigDistance[client] < g_fGrabMinimum || g_fConfigDistance[client] > g_fGrabMaximum)
			{
				g_fConfigDistance[client] = 150.0;
				FloatToString(g_fConfigDistance[client], sCookie, sizeof(sCookie));
				SetClientCookie(client, g_cCookieDistance, sCookie);
			}

			GetClientCookie(client, g_cCookieControl, sCookie, sizeof(sCookie));
			g_bPlayerControl[client] = bool:StringToInt(sCookie);

			for(new i = 0; i <= 2; i++)
				g_bLockedAxis[client][i] = g_bPlayerControl[client] ? true : false;
		}

		if(g_Access[client][bAccessCustom])
		{
			decl String:_sFunctions[3][8];
			GetClientCookie(client, g_cCookieCustom, sTemp, 32);
			ExplodeString(sTemp, " ", _sFunctions, sizeof(_sFunctions), sizeof(_sFunctions[]));

			g_iPlayerCustom[client][FUNCTION_KEY_USE] = StringToInt(_sFunctions[0]);
			g_iPlayerCustom[client][FUNCTION_KEY_LEFT] = StringToInt(_sFunctions[1]);
			g_iPlayerCustom[client][FUNCTION_KEY_RIGHT] = StringToInt(_sFunctions[2]);
		}
	}

	g_bCookiesLoaded[client] = true;
}

//*****************************************************************************************
//* |||  | Zone Control
//*****************************************************************************************
public Native_GetAdvanceTeam(Handle:hPlugin, iNumParams)
{
	return g_bAdvancingTeam ? g_iAdvancingTeam : 0;
}

public Native_GetCurrentZone(Handle:hPlugin, iNumParams)
{
	new client = GetNativeCell(1);

	return GetCurrentZone(client);
}

GetCurrentZone(client)
{
	decl Float:vOrigin[3];
	GetClientAbsOrigin(client, vOrigin);

	new iZone = -1;
	for (new zone = 0; zone < g_iTotalZones; zone++)
	{
		if (IsInsideBox(vOrigin, g_iMapZone[zone][Point1][0], g_iMapZone[zone][Point1][1], g_iMapZone[zone][Point1][2], g_iMapZone[zone][Point2][0], g_iMapZone[zone][Point2][1], g_iMapZone[zone][Point2][2]))
		{
			iZone = zone;
			break;
		}
	}

	return iZone;
}

public Native_GetBlockedZone(Handle:hPlugin, iNumParams)
{
	decl Float:fArray[3];
	GetNativeArray(1, fArray, 3);

	return GetBlockedZone(fArray);
}

GetBlockedZone(Float:fArray[3])
{
	new iZone = -1;
	for (new zone = 0; zone < g_iTotalZones; zone++)
		if(g_iMapZone[zone][Type] == Block_Build && IsInsideBox(fArray, g_iMapZone[zone][Point1][0], g_iMapZone[zone][Point1][1], g_iMapZone[zone][Point1][2], g_iMapZone[zone][Point2][0], g_iMapZone[zone][Point2][1], g_iMapZone[zone][Point2][2]))
			iZone = zone;

	return iZone;
}

public CallBack_LoadZones(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	ErrorCheck(hndl, error, "CallBack_LoadZones");

	g_iTotalZones = 0;

	while (SQL_FetchRow(hndl))
	{
		strcopy(g_iMapZone[g_iTotalZones][Map], 32, g_sCurrentMap);

		g_iMapZone[g_iTotalZones][Id] = SQL_FetchInt(hndl, 0);
		g_iMapZone[g_iTotalZones][Type] = MapZoneType:SQL_FetchInt(hndl, 1);
		g_iMapZone[g_iTotalZones][Point1][0] = SQL_FetchFloat(hndl, 2);
		g_iMapZone[g_iTotalZones][Point1][1] = SQL_FetchFloat(hndl, 3);
		g_iMapZone[g_iTotalZones][Point1][2] = SQL_FetchFloat(hndl, 4);
		g_iMapZone[g_iTotalZones][Point2][0] = SQL_FetchFloat(hndl, 5);
		g_iMapZone[g_iTotalZones][Point2][1] = SQL_FetchFloat(hndl, 6);
		g_iMapZone[g_iTotalZones][Point2][2] = SQL_FetchFloat(hndl, 7);

		g_iTotalZones++;
	}
}

AddMapZone(String:map[], MapZoneType:type, Float:point1[3], Float:point2[3])
{
	decl String:sQuery[512];
	if(type != Block_Build)
	{
		new Handle:hPack = CreateDataPack();
		WritePackString(hPack, map);
		WritePackCell(hPack, _:type);
		WritePackCell(hPack, _:point1[0]);
		WritePackCell(hPack, _:point1[1]);
		WritePackCell(hPack, _:point1[2]);
		WritePackCell(hPack, _:point2[0]);
		WritePackCell(hPack, _:point2[1]);
		WritePackCell(hPack, _:point2[2]);

		FormatEx(sQuery, sizeof(sQuery), "DELETE FROM `buildwars_zones` WHERE `map` = '%s' AND `type` = %d;", map, type);
		SQL_TQuery(g_hSql_Database, CallBack_DeleteZone, sQuery, hPack, DBPrio_High);
	}
	else
	{
		FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `buildwars_zones` (`map`, `type`, `point1_x`, `point1_y`, `point1_z`, `point2_x`, `point2_y`, `point2_z`) VALUES ('%s', '%d', %f, %f, %f, %f, %f, %f);", map, type, point1[0], point1[1], point1[2], point2[0], point2[1], point2[2]);
		SQL_TQuery(g_hSql_Database, CallBack_InsertZone, sQuery, _, DBPrio_Normal);
	}
}

Define_Zones()
{
	decl String:sQuery[384];
	FormatEx(sQuery, sizeof(sQuery), "SELECT `id`, `type`, `point1_x`, `point1_y`, `point1_z`, `point2_x`, `point2_y`, `point2_z` FROM `buildwars_zones` WHERE `map` = '%s'", g_sCurrentMap);
	SQL_TQuery(g_hSql_Database, CallBack_LoadZones, sQuery, _, DBPrio_High);
}

public CallBack_DeleteZone(Handle:owner, Handle:hndl, const String:error[], any:pack)
{
	ErrorCheck(hndl, error, "CallBack_DeleteZone");

	ResetPack(pack);
	decl String:map[32], Float:point1[3], Float:point2[3];
	ReadPackString(pack, map, sizeof(map));
	new MapZoneType:type = MapZoneType:ReadPackCell(pack);
	for(new i = 0; i <= 2; i++)
		point1[i] = Float:ReadPackCell(pack);
	for(new i = 0; i <= 2; i++)
		point2[i] = Float:ReadPackCell(pack);

	CloseHandle(pack);

	decl String:sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `buildwars_zones` (`map`, `type`, `point1_x`, `point1_y`, `point1_z`, `point2_x`, `point2_y`, `point2_z`) VALUES ('%s', '%d', %f, %f, %f, %f, %f, %f);", map, type, point1[0], point1[1], point1[2], point2[0], point2[1], point2[2]);
	SQL_TQuery(g_hSql_Database, CallBack_InsertZone, sQuery, _, DBPrio_Normal);
}

public CallBack_InsertZone(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	ErrorCheck(hndl, error, "CallBack_InsertZone");

	Define_Zones();
}

DeleteMapZone(client)
{
	decl Float:vOrigin[3];
	GetClientAbsOrigin(client, vOrigin);

	for (new zone = 0; zone < g_iTotalZones; zone++)
	{
		if (IsInsideBox(vOrigin, g_iMapZone[zone][Point1][0], g_iMapZone[zone][Point1][1], g_iMapZone[zone][Point1][2], g_iMapZone[zone][Point2][0], g_iMapZone[zone][Point2][1], g_iMapZone[zone][Point2][2]))
		{
			decl String:sQuery[64];
			FormatEx(sQuery, sizeof(sQuery), "DELETE FROM `buildwars_zones` WHERE `id` = %d", g_iMapZone[zone][Id]);
			SQL_TQuery(g_hSql_Database, CallBack_DeleteZone2, sQuery, GetClientUserId(client), DBPrio_High);
			break;
		}
	}
}

DrawMapZones()
{
	for(new zone = 0; zone < g_iTotalZones; zone++)
		DrawMapZone(zone);
}

DrawMapZone(iZone, client = 0)
{
	decl Float:point1[3], Float:point2[3];
	Array_Copy(g_iMapZone[iZone][Point1], point1, 3);
	Array_Copy(g_iMapZone[iZone][Point2], point2, 3);

	if (g_iMapZone[iZone][Type] == Team_T)
		DrawBox(point1, point2, 5.0, {255, 0, 0, 255}, false, client);
	else if (g_iMapZone[iZone][Type] == Team_CT)
		DrawBox(point1, point2, 5.0, {0, 0, 255, 255}, false, client);
	else if(g_iMapZone[iZone][Type] == Team_None)
		DrawBox(point1, point2, 5.0, {255, 255, 255, 255}, false, client);
	else
		DrawBox(point1, point2, 5.0, {0, 255, 0, 255}, false, client);
}

DrawSpawnPoints(client)
{
	if(g_bGlobalOffensive)
	{
		for(new i = 0; i <= g_iNumRedSpawns; i++)
		{
			TE_SetupGlowSprite(g_fRedTeleports[i], g_iGlowSprite, 1.0, 0.5, 255);
			TE_SendToClient(client);

			TE_SetupBeamRingPoint(g_fRedTeleports[i], 10.0, 500.0, g_iBeamSprite, g_iHaloSprite, 0, 10, 1.0, 25.0, 1.0, g_iPropColoringTerrorist, 15, 0);
			TE_SendToClient(client);
		}
		for(new i = 0; i <= g_iNumBlueSpawns; i++)
		{
			TE_SetupGlowSprite(g_fBlueTeleports[i], g_iGlowSprite, 1.0, 0.5, 255);
			TE_SendToClient(client);

			TE_SetupBeamRingPoint(g_fBlueTeleports[i], 10.0, 500.0, g_iBeamSprite, g_iHaloSprite, 0, 10, 1.0, 25.0, 1.0, g_iPropColoringCounter, 15, 0);
			TE_SendToClient(client);
		}
	}
	else
	{
		for(new i = 0; i <= g_iNumRedSpawns; i++)
		{
			TE_SetupGlowSprite(g_fRedTeleports[i], g_iSpriteRed, 0.5, 4.0, 70);
			TE_SendToClient(client);
		}
		for(new i = 0; i <= g_iNumBlueSpawns; i++)
		{
			TE_SetupGlowSprite(g_fBlueTeleports[i], g_iSpriteBlue, 0.5, 4.0, 70);
			TE_SendToClient(client);
		}
	}
}

RestartMapZoneEditor(client)
{
	g_iZoneEditor[client][Step] = 0;

	for (new i = 0; i < 3; i++)
		g_iZoneEditor[client][Point1][i] = 0.0;

	for (new i = 0; i < 3; i++)
		g_iZoneEditor[client][Point2][i] = 0.0;
}

DisplaySelectPointMenu(client, n)
{
	new Handle:hPanel = CreatePanel();
	decl String:sMessage[255];

	decl String:sKey[32];
	if(g_iCurrentTeam[client] == CS_TEAM_SPECTATOR)
		Format(sKey, sizeof(sKey), "%T", "menuZonesPromptReload", client);
	else
		Format(sKey, sizeof(sKey), "%T", "menuZonesPromptClick", client);

	if(n == 1)
		Format(sMessage, sizeof(sMessage), "%T", "menuZonesCreateFirst", client, sKey);
	else
		Format(sMessage, sizeof(sMessage), "%T", "menuZonesCreateSecond", client, sKey);
	DrawPanelItem(hPanel, sMessage, ITEMDRAW_RAWLINE);

	Format(sMessage, sizeof(sMessage), "%T", "menuZonesPromptCancel", client);
	DrawPanelItem(hPanel, sMessage);

	SendPanelToClient(hPanel, client, PanelHandler_PointMenu, MENU_TIME_FOREVER);
	CloseHandle(hPanel);
}

public PanelHandler_PointMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Select:
			RestartMapZoneEditor(param1);
	}
}

DisplayPleaseWaitMenu(client)
{
	new Handle:hPanel = CreatePanel();

	decl String:sWait[64];
	FormatEx(sWait, sizeof(sWait), "%T", "menuZonesPending", client);
	DrawPanelItem(hPanel, sWait, ITEMDRAW_RAWLINE);

	SendPanelToClient(hPanel, client, PanelHandler_Wait, MENU_TIME_FOREVER);
	CloseHandle(hPanel);
}

public PanelHandler_Wait(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
	}
}

public Action:ChangeStep(Handle:timer, any:serial)
{
	new client = GetClientFromSerial(serial);

	g_iZoneEditor[client][Step] = 2;
	CreateTimer(0.1, DrawAdminBox, GetClientSerial(client), TIMER_REPEAT);

	DisplaySelectPointMenu(client, 2);
}

public Action:DrawAdminBox(Handle:timer, any:serial)
{
	new client = GetClientFromSerial(serial);

	if (g_iZoneEditor[client][Step] == 0)
		return Plugin_Stop;

	decl Float:a[3], Float:b[3];

	Array_Copy(g_iZoneEditor[client][Point1], b, 3);

	if (g_iZoneEditor[client][Step] == 3)
		Array_Copy(g_iZoneEditor[client][Point2], a, 3);
	else
		GetClientAbsOrigin(client, a);

	new color[4] = {255, 255, 255, 255};

	DrawBox(a, b, 0.1, color, false);
	return Plugin_Continue;
}

DisplaySelectZoneTypeMenu(client)
{
	new Handle:hMenu = CreateMenu(ZoneTypeSelect);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);
	SetMenuTitle(hMenu, "%T", "menuZonesTitleType", client);

	decl String:sText[64];
	FormatEx(sText, sizeof(sText), "%T", "menuZonesRed", client);
	AddMenuItem(hMenu, "0", sText);

	FormatEx(sText, sizeof(sText), "%T", "menuZonesBlue", client);
	AddMenuItem(hMenu, "1", sText);

	FormatEx(sText, sizeof(sText), "%T", "menuZonesNeutral", client);
	AddMenuItem(hMenu, "2", sText);

	FormatEx(sText, sizeof(sText), "%T", "menuZonesBlock", client);
	AddMenuItem(hMenu, "3", sText);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public ZoneTypeSelect(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
		{
			CloseHandle(menu);
			RestartMapZoneEditor(param1);
		}
		case MenuAction_Cancel:
			RestartMapZoneEditor(param1);
		case MenuAction_Select:
		{
			decl Float:point1[3];
			Array_Copy(g_iZoneEditor[param1][Point1], point1, 3);

			decl Float:point2[3];
			Array_Copy(g_iZoneEditor[param1][Point2], point2, 3);

			AddMapZone(g_sCurrentMap, MapZoneType:param2, point1, point2);
			RestartMapZoneEditor(param1);
			Define_Zones();

			Menu_AdminZones(param1);
		}
	}
}

public CallBack_DeleteZone2(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	ErrorCheck(hndl, error, "CallBack_DeleteZone2");

	Define_Zones();

	new client = GetClientOfUserId(userid);
	if(client && IsClientInGame(client))
	{
		#if defined _colors_included
		CPrintToChat(client, "%tThe rush zone you were currently within has been deleted", "prefixChatMessage");
		#else
		PrintToChat(client, "%tThe rush zone you were currently within has been deleted", "prefixChatMessage");
		#endif
	}
}

IsInsideBox(Float:fPCords[3], Float:fbsx, Float:fbsy, Float:fbsz, Float:fbex, Float:fbey, Float:fbez)
{
	new Float:fpx = fPCords[0];
	new Float:fpy = fPCords[1];
	new Float:fpz = fPCords[2];

	new bool:bX = false;
	new bool:bY = false;
	new bool:bZ = false;

	if (fbsx > fbex && fpx <= fbsx && fpx >= fbex)
		bX = true;
	else if (fbsx < fbex && fpx >= fbsx && fpx <= fbex)
		bX = true;

	if (fbsy > fbey && fpy <= fbsy && fpy >= fbey)
		bY = true;
	else if (fbsy < fbey && fpy >= fbsy && fpy <= fbey)
		bY = true;

	if (fbsz > fbez && fpz <= fbsz && fpz >= fbez)
		bZ = true;
	else if (fbsz < fbez && fpz >= fbsz && fpz <= fbez)
		bZ = true;

	if (bX && bY && bZ)
		return true;

	return false;
}

DrawBox(Float:fFrom[3], Float:fTo[3], Float:fLife, color[4], bool:flat, client = 0)
{
	decl Float:fLeftBottomFront[3];
	fLeftBottomFront[0] = fFrom[0];
	fLeftBottomFront[1] = fFrom[1];
	if(flat)
		fLeftBottomFront[2] = fTo[2]-2;
	else
		fLeftBottomFront[2] = fTo[2];

	decl Float:fRightBottomFront[3];
	fRightBottomFront[0] = fTo[0];
	fRightBottomFront[1] = fFrom[1];
	if(flat)
		fRightBottomFront[2] = fTo[2]-2;
	else
		fRightBottomFront[2] = fTo[2];

	decl Float:fLeftBottomBack[3];
	fLeftBottomBack[0] = fFrom[0];
	fLeftBottomBack[1] = fTo[1];
	if(flat)
		fLeftBottomBack[2] = fTo[2]-2;
	else
		fLeftBottomBack[2] = fTo[2];

	decl Float:fRightBottomBack[3];
	fRightBottomBack[0] = fTo[0];
	fRightBottomBack[1] = fTo[1];
	if(flat)
		fRightBottomBack[2] = fTo[2]-2;
	else
		fRightBottomBack[2] = fTo[2];

	decl Float:lefttopfront[3];
	lefttopfront[0] = fFrom[0];
	lefttopfront[1] = fFrom[1];
	if(flat)
		lefttopfront[2] = fFrom[2]+2;
	else
		lefttopfront[2] = fFrom[2];

	decl Float:righttopfront[3];
	righttopfront[0] = fTo[0];
	righttopfront[1] = fFrom[1];
	if(flat)
		righttopfront[2] = fFrom[2]+2;
	else
		righttopfront[2] = fFrom[2];

	decl Float:fLeftTopBack[3];
	fLeftTopBack[0] = fFrom[0];
	fLeftTopBack[1] = fTo[1];
	if(flat)
		fLeftTopBack[2] = fFrom[2]+2;
	else
		fLeftTopBack[2] = fFrom[2];

	decl Float:fRightTopBack[3];
	fRightTopBack[0] = fTo[0];
	fRightTopBack[1] = fTo[1];
	if(flat)
		fRightTopBack[2] = fFrom[2]+2;
	else
		fRightTopBack[2] = fFrom[2];

	TE_SetupBeamPoints(lefttopfront, righttopfront, g_iBeamSprite, 0, 0, 0, fLife, 3.0, 3.0, 10, 0.0, color, 0);
	if(client)
		TE_SendToClient(client);
	else
		TE_SendToAll(0.0);

	TE_SetupBeamPoints(lefttopfront, fLeftTopBack, g_iBeamSprite, 0, 0, 0, fLife, 3.0, 3.0, 10, 0.0, color, 0);
	if(client)
		TE_SendToClient(client);
	else
		TE_SendToAll(0.0);

	TE_SetupBeamPoints(fRightTopBack, fLeftTopBack, g_iBeamSprite, 0, 0, 0, fLife, 3.0, 3.0, 10, 0.0, color, 0);
	if(client)
		TE_SendToClient(client);
	else
		TE_SendToAll(0.0);

	TE_SetupBeamPoints(fRightTopBack, righttopfront, g_iBeamSprite, 0, 0, 0, fLife, 3.0, 3.0, 10, 0.0, color, 0);
	if(client)
		TE_SendToClient(client);
	else
		TE_SendToAll(0.0);

	if(!flat)
	{
		TE_SetupBeamPoints(fLeftBottomFront, fRightBottomFront, g_iBeamSprite, 0, 0, 0, fLife, 3.0, 3.0, 10, 0.0, color, 0);
		if(client)
			TE_SendToClient(client);
		else
			TE_SendToAll(0.0);

		TE_SetupBeamPoints(fLeftBottomFront, fLeftBottomBack, g_iBeamSprite, 0, 0, 0, fLife, 3.0, 3.0, 10, 0.0, color, 0);
		if(client)
			TE_SendToClient(client);
		else
			TE_SendToAll(0.0);

		TE_SetupBeamPoints(fLeftBottomFront, lefttopfront, g_iBeamSprite, 0, 0, 0, fLife, 3.0, 3.0, 10, 0.0, color, 0);
		if(client)
			TE_SendToClient(client);
		else
			TE_SendToAll(0.0);

		TE_SetupBeamPoints(fRightBottomBack, fLeftBottomBack, g_iBeamSprite, 0, 0, 0, fLife, 3.0, 3.0, 10, 0.0, color, 0);
		if(client)
			TE_SendToClient(client);
		else
			TE_SendToAll(0.0);

		TE_SetupBeamPoints(fRightBottomBack, fRightBottomFront, g_iBeamSprite, 0, 0, 0, fLife, 3.0, 3.0, 10, 0.0, color, 0);
		if(client)
			TE_SendToClient(client);
		else
			TE_SendToAll(0.0);

		TE_SetupBeamPoints(fRightBottomBack, fRightTopBack, g_iBeamSprite, 0, 0, 0, fLife, 3.0, 3.0, 10, 0.0, color, 0);
		if(client)
			TE_SendToClient(client);
		else
			TE_SendToAll(0.0);

		TE_SetupBeamPoints(fRightBottomFront, righttopfront, g_iBeamSprite, 0, 0, 0, fLife, 3.0, 3.0, 10, 0.0, color, 0);
		if(client)
			TE_SendToClient(client);
		else
			TE_SendToAll(0.0);

		TE_SetupBeamPoints(fLeftBottomBack, fLeftTopBack, g_iBeamSprite, 0, 0, 0, fLife, 3.0, 3.0, 10, 0.0, color, 0);
		if(client)
			TE_SendToClient(client);
		else
			TE_SendToAll(0.0);
	}
}

//*****************************************************************************************
//* |||  | Main Menu
//*****************************************************************************************
Menu_Main(client)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client]))
		return;

	decl String:sBuffer[128];
	new Handle:hMenu = CreateMenu(MenuHandler_Main);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuPagination(hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(hMenu, true);

	if(g_iPlayerGimp[client])
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "menuGimpNotifyStatus", client);
		AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);

		new _iDuration = (g_iPlayerGimp[client] - g_iCurrentTime);
		new iMinutes = RoundToFloor(float(_iDuration) / 60.0);
		new _iSeconds = _iDuration % 60;
		Format(sBuffer, sizeof(sBuffer), "%T", "menuGimpNotifyRemaining", client, iMinutes, _iSeconds);
		AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);

		Format(sBuffer, sizeof(sBuffer), "%T", "menuGimpNotify", client);
		AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);

		if(!g_bGlobalOffensive)
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuOptionSpacerSelection", client);
			if(!StrEqual(sBuffer, ""))
				AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
		}

		if(g_Access[client][bAccessTeleport])
		{
			if(!g_Access[client][iTotalTeleports])
				Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryTeleportInfinite", client);
			else
				Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryTeleportLimited", client, g_iPlayerTeleports[client], g_Access[client][iTotalTeleports]);

			AddMenuItem(hMenu, "-1", sBuffer, Bool_TeleportValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
	}
	else
	{
		if(g_bAdvancingTeam && g_iDebugMode != MODE_BUILD && g_iCurrentTeam[client] == g_iAdvancingTeam)
		{
			if(g_Access[client][bAccessProp])
			{
				if(!g_Access[client][iTotalPropsAdvance])
					Format(sBuffer, sizeof(sBuffer), "%T", "menuEntrySpawnInfinite", client);
				else
					Format(sBuffer, sizeof(sBuffer), "%T", "menuEntrySpawnLimited", client, g_iPlayerProps[client], g_Access[client][iTotalPropsAdvance]);

				AddMenuItem(hMenu, "0", sBuffer, Bool_SpawnValid(client, false, true) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
			}
		}
		else
		{
			if(g_Access[client][bAccessProp])
			{
				if(!g_Access[client][iTotalProps])
					Format(sBuffer, sizeof(sBuffer), "%T", "menuEntrySpawnInfinite", client);
				else
					Format(sBuffer, sizeof(sBuffer), "%T", "menuEntrySpawnLimited", client, g_iPlayerProps[client], g_Access[client][iTotalProps]);

				AddMenuItem(hMenu, "0", sBuffer, Bool_SpawnValid(client, false, true) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
			}
		}

		if(g_Access[client][bAccessDelete])
		{
			if(!g_Access[client][iTotalDeletes])
				Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryDeleteInfinite", client);
			else
				Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryDeleteLimited", client, g_iPlayerDeletes[client], g_Access[client][iTotalDeletes]);

			AddMenuItem(hMenu, "1", sBuffer, Bool_DeleteValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_Access[client][bAccessControl])
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryControl", client);

			AddMenuItem(hMenu, "2", sBuffer, Bool_ControlValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_Access[client][bAccessRotate] || g_Access[client][bAccessMove] || g_Access[client][bAccessColor] || g_Access[client][bAccessPhase])
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryModify", client);

			AddMenuItem(hMenu, "3", sBuffer, ITEMDRAW_DEFAULT);
		}

		if(!g_bGlobalOffensive)
		{
			if(g_Access[client][bAccessCheck])
			{
				Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryCheck", client);

				AddMenuItem(hMenu, "4", sBuffer, Bool_CheckValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
			}
		}

		if(g_Access[client][bAccessSettings])
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPlayerActions", client);

			AddMenuItem(hMenu, "5", sBuffer);
		}

		if(g_Access[client][bAccessBase] && g_Access[client][iTotalBases] > 0)
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryBaseActions", client);

			AddMenuItem(hMenu, "6", sBuffer, (g_bDatabaseFound && g_hSql_Database != INVALID_HANDLE) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_Access[client][bAccessAdminMenu] || CheckCommandAccess(client, "Bw_Access_Admin", ADMFLAG_RCON))
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryAdminActions", client);

			AddMenuItem(hMenu, "7", sBuffer);
		}
	}

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Main(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1]))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);
			switch(StringToInt(sOption))
			{
				case -1:
				{
					if(Bool_TeleportValid(param1, true))
						Menu_ConfirmTeleport(param1);
					else
						Menu_Main(param1);
				}
				case 0:
				{
					if(Bool_SpawnValid(param1, true, true))
						Menu_Create(param1);
					else
						Menu_Main(param1);
				}
				case 1:
				{
					if(Bool_DeleteValid(param1, true))
						DeleteProp(param1);

					Menu_Main(param1);
				}
				case 2:
				{
					if(Bool_ControlValid(param1, true))
						Menu_Control(param1);
				}
				case 3:
				{
					Menu_Modify(param1);
				}
				case 4:
				{
					if(Bool_CheckValid(param1, true))
						Action_CheckProp(param1);

					Menu_Main(param1);
				}
				case 5:
				{
					Menu_Actions(param1);
				}
				case 6:
				{
					QueryBuildMenu(param1, MENU_BASE_MAIN);
				}
				case 7:
				{
					if(!Menu_Admin(param1))
						Menu_Main(param1);
				}
			}
		}
	}
}

//*****************************************************************************************
//* |||  | Main Menu Functions
//*****************************************************************************************
Action_CheckProp(client, iEnt = 0)
{
	new iTmpEnt = (iEnt > 0) ? iEnt : Trace_GetEntity(client);
	if(Entity_Valid(iTmpEnt))
	{
		new iOwner = GetClientOfUserId(g_iPropUser[iTmpEnt]);
		if(g_Access[client][bAdmin])
			PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserCheckAdmin", g_Cfg_sPropNames[g_iPropType[iTmpEnt]], iOwner ? g_sName[iOwner] : g_sPropOwner[iTmpEnt], iTmpEnt, g_iCurEntities);
		else
			PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserCheck", g_Cfg_sPropNames[g_iPropType[iTmpEnt]], iOwner ? g_sName[iOwner] : g_sPropOwner[iTmpEnt]);
	}
}

//*****************************************************************************************
//* |||  | Modify Menu
//*****************************************************************************************
Menu_Modify(client)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client]))
		return;

	decl String:sBuffer[128];
	new Handle:hMenu = CreateMenu(MenuHandler_Modify);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, g_bGlobalOffensive ? false : true);

	if(g_bGlobalOffensive)
	{
		if(g_Access[client][bAccessCheck])
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryCheck", client);

			AddMenuItem(hMenu, "4", sBuffer, Bool_CheckValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
	}

	if(g_Access[client][bAccessRotate])
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryRotate", client);

		AddMenuItem(hMenu, "1", sBuffer, Bool_RotateValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	if(g_Access[client][bAccessMove])
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPosition", client);

		AddMenuItem(hMenu, "2", sBuffer, Bool_MoveValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	if(g_Access[client][bAccessPhase])
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPhase", client);

		AddMenuItem(hMenu, "3", sBuffer, Bool_PhaseValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	if(g_Access[client][bAccessClear])
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryClear", client);

		AddMenuItem(hMenu, "5", sBuffer, Bool_ClearValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	if(g_Access[client][bAccessColor])
	{
		if(!g_Access[client][iTotalColors])
			Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryColorInfinite", client);
		else
			Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryColorLimited", client, g_iPlayerColors[client], g_Access[client][iTotalColors]);

		AddMenuItem(hMenu, "6", sBuffer, Bool_ColorValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Modify(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Main(param1);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1]))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);
			switch(StringToInt(sOption))
			{
				case 1:
				{
					if(Bool_RotateValid(param1, true))
						Menu_ModifyRotation(param1);
					else
						Menu_Modify(param1);
				}
				case 2:
				{
					if(Bool_MoveValid(param1, true))
						Menu_ModifyPosition(param1);
					else
						Menu_Modify(param1);
				}
				case 3:
				{
					if(Bool_PhaseValid(param1, true))
						Action_PhaseProp(param1);

					Menu_Modify(param1);
				}
				case 4:
				{
					if(Bool_CheckValid(param1, true))
						Action_CheckProp(param1);

					Menu_Modify(param1);
				}
				case 5:
				{
					if(Bool_ClearValid(param1, true))
						Menu_ConfirmClear(param1);
					else
						Menu_Modify(param1);
				}
				case 6:
				{
					Menu_DefaultColors(param1);
				}
			}
		}
	}
}

Menu_ModifyRotation(client, iEnt = 0, index = 0)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client], true))
		return;

	decl String:sBuffer[128];
	new Handle:hMenu = CreateMenu(MenuHandler_ModifyRotation);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	if(!g_bGlobalOffensive)
	{
		if(g_Access[client][bAdmin])
		{
			if(iEnt)
			{
				decl Float:fAngles[3];
				GetEntPropVector(iEnt, Prop_Data, "m_angRotation", fAngles);

				Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryRotationDetails", client, fAngles[0], fAngles[1], fAngles[2]);
				AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
			}
			else
			{
				Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryRotationDetailsMissing", client);
				AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
			}
		}
	}

	new _iState = Bool_RotateValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryRotationAxisXInc", client, g_Cfg_fDefinedRotations[g_iPlayerRotation[client]]);
	AddMenuItem(hMenu, "1", sBuffer, _iState);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryRotationAxisXDec", client, g_Cfg_fDefinedRotations[g_iPlayerRotation[client]]);
	AddMenuItem(hMenu, "2", sBuffer, _iState);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryRotationAxisYInc", client, g_Cfg_fDefinedRotations[g_iPlayerRotation[client]]);
	AddMenuItem(hMenu, "3", sBuffer, _iState);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryRotationAxisYDec", client, g_Cfg_fDefinedRotations[g_iPlayerRotation[client]]);
	AddMenuItem(hMenu, "4", sBuffer, _iState);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryRotationAxisZInc", client, g_Cfg_fDefinedRotations[g_iPlayerRotation[client]]);
	AddMenuItem(hMenu, "5", sBuffer, _iState);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryRotationAxisZDec", client, g_Cfg_fDefinedRotations[g_iPlayerRotation[client]]);
	AddMenuItem(hMenu, "6", sBuffer, _iState);

	if(g_bGlobalOffensive)
	{
		if(g_Access[client][bAdmin])
		{
			if(iEnt)
			{
				decl Float:fAngles[3];
				GetEntPropVector(iEnt, Prop_Data, "m_angRotation", fAngles);

				Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryRotationDetails", client, fAngles[0], fAngles[1], fAngles[2]);
				AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
			}
			else
			{
				Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryRotationDetailsMissing", client);
				AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
			}
		}
	}

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryRotationReset", client);
	AddMenuItem(hMenu, "7", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryRotationDefault", client);
	AddMenuItem(hMenu, "0", sBuffer);

	DisplayMenuAtItem(hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_ModifyRotation(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Modify(param1);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1], true))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);
			new _iTemp = StringToInt(sOption);

			if(!_iTemp)
				Menu_DefaultRotation(param1);
			else
			{
				if(Bool_RotateValid(param1, true))
				{
					new iEnt = (g_iPlayerControl[param1] > 0) ? g_iPlayerControl[param1] : Trace_GetEntity(param1);
					if(Entity_Valid(iEnt))
					{
						new iOwner = GetClientOfUserId(g_iPropUser[iEnt]);
						if(iOwner == param1 || g_Access[param1][bAdmin])
						{
							new Float:_fTemp[3];
							if(_iTemp == 7)
							{
								if(g_Access[param1][bAdmin])
								{
									if(!iOwner || iOwner == param1)
										PrintHintText(param1, "%t%t", "prefixHintMessage", "hintNotifyUserRotatePropResetAdmin", g_Cfg_sPropNames[g_iPropType[iEnt]], iEnt, g_iCurEntities);
									else
										PrintHintText(param1, "%t%t", "prefixHintMessage", "hintNotifyUserRotateClientPropResetAdmin", g_Cfg_sPropNames[g_iPropType[iEnt]], g_sName[iOwner], iEnt, g_iCurEntities);
								}
								else
									PrintHintText(param1, "%t%t", "prefixHintMessage", "hintNotifyUserRotatePropReset", g_Cfg_sPropNames[g_iPropType[iEnt]]);
							}
							else
							{
								if(g_Access[param1][bAdmin])
								{
									if(!iOwner || iOwner == param1)
										PrintHintText(param1, "%t%t", "prefixHintMessage", "hintNotifyUserRotatePropAdmin", g_Cfg_sPropNames[g_iPropType[iEnt]], g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]], iEnt, g_iCurEntities);
									else
										PrintHintText(param1, "%t%t", "prefixHintMessage", "hintNotifyUserRotateClientPropAdmin", g_Cfg_sPropNames[g_iPropType[iEnt]], g_sName[iOwner], g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]], iEnt, g_iCurEntities);
								}
								else
									PrintHintText(param1, "%t%t", "prefixHintMessage", "hintNotifyUserRotateProp", g_Cfg_sPropNames[g_iPropType[iEnt]], g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]]);


								switch(_iTemp)
								{
									case 1:
										_fTemp[0] = g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]];
									case 2:
										_fTemp[0] = (g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]] * -1);
									case 3:
										_fTemp[1] = g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]];
									case 4:
										_fTemp[1] = (g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]] * -1);
									case 5:
										_fTemp[2] = g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]];
									case 6:
										_fTemp[2] = (g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]] * -1);
								}
							}

							Entity_RotateProp(iEnt, _fTemp, (_iTemp == 7) ? true : false);
							Menu_ModifyRotation(param1, iEnt, GetMenuSelectionPosition());
							return;
						}
						else
							PrintHintText(param1, "%t%t", "prefixHintMessage", "hintNotifyUserRotatePropWarningOwner", g_Cfg_sPropNames[g_iPropType[iEnt]], g_sPropOwner[iEnt]);
					}
				}

				Menu_ModifyRotation(param1, 0, GetMenuSelectionPosition());
			}
		}
	}
}

Menu_DefaultRotation(client, index = 0, menu = 1)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client]))
		return;

	decl String:sBuffer[128], String:sTemp[4];

	new Handle:hMenu;
	switch(menu)
	{
		case 1:
			hMenu = CreateMenu(MenuHandler_DefaultRotation);
		case 2:
			hMenu = CreateMenu(MenuHandler_DefaultRotationSettings);
		case 3:
			hMenu = CreateMenu(MenuHandler_DefaultRotationControl);
	}

	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	for(new i = 0; i < g_iCfg_TotalRotations; i++)
	{
		IntToString(i, sTemp, 4);
		Format(sBuffer, sizeof(sBuffer), "%s%T", (g_iPlayerRotation[client] == i) ? g_sPrefixSelect : g_sPrefixEmpty, "menuEntryRotationModify", client, g_Cfg_fDefinedRotations[i]);
		AddMenuItem(hMenu, sTemp, sBuffer);
	}

	DisplayMenuAtItem(hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_DefaultRotation(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_ModifyRotation(param1);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1]))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);
			g_iPlayerRotation[param1] = StringToInt(sOption);
			SetClientCookie(param1, g_cCookieRotation, sOption);

			#if defined _colors_included
			CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserRotateSettingSuccess", g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]]);
			#else
			PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserRotateSettingSuccess", g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]]);
			#endif
			Menu_DefaultRotation(param1, GetMenuSelectionPosition());
		}
	}
}

public MenuHandler_DefaultRotationSettings(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Actions(param1);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1]))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);
			g_iPlayerRotation[param1] = StringToInt(sOption);
			SetClientCookie(param1, g_cCookieRotation, sOption);

			#if defined _colors_included
			CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserRotateSettingSuccess", g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]]);
			#else
			PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserRotateSettingSuccess", g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]]);
			#endif
			Menu_DefaultRotation(param1, GetMenuSelectionPosition());
		}
	}
}

public MenuHandler_DefaultRotationControl(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_ControlRotation(param1);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1]))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);
			g_iPlayerRotation[param1] = StringToInt(sOption);
			SetClientCookie(param1, g_cCookieRotation, sOption);

			#if defined _colors_included
			CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserRotateSettingSuccess", g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]]);
			#else
			PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserRotateSettingSuccess", g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]]);
			#endif
			Menu_DefaultRotation(param1, GetMenuSelectionPosition());
		}
	}
}

Menu_ModifyPosition(client, iEnt = 0, index = 0)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client], true))
		return;

	decl String:sBuffer[128];
	new Handle:hMenu = CreateMenu(MenuHandler_ModifyPosition);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	if(!g_bGlobalOffensive)
	{
		if(g_Access[client][bAdmin])
		{
			if(iEnt)
			{
				decl Float:fOrigin[3];
				GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fOrigin);

				Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPositionDetails", client, fOrigin[0], fOrigin[1], fOrigin[2]);
				AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
			}
			else
			{
				Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPositionDetailsMissing", client);
				AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
			}
		}
	}

	new _iState = Bool_MoveValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPositionAxisXInc", client, g_Cfg_fDefinedPositions[g_iPlayerPosition[client]]);
	AddMenuItem(hMenu, "1", sBuffer, _iState);
	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPositionAxisXDec", client, g_Cfg_fDefinedPositions[g_iPlayerPosition[client]]);
	AddMenuItem(hMenu, "2", sBuffer, _iState);
	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPositionAxisYInc", client, g_Cfg_fDefinedPositions[g_iPlayerPosition[client]]);
	AddMenuItem(hMenu, "3", sBuffer, _iState);
	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPositionAxisYDec", client, g_Cfg_fDefinedPositions[g_iPlayerPosition[client]]);
	AddMenuItem(hMenu, "4", sBuffer, _iState);
	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPositionAxisZInc", client, g_Cfg_fDefinedPositions[g_iPlayerPosition[client]]);
	AddMenuItem(hMenu, "5", sBuffer, _iState);
	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPositionAxisZDec", client, g_Cfg_fDefinedPositions[g_iPlayerPosition[client]]);
	AddMenuItem(hMenu, "6", sBuffer, _iState);

	if(g_bGlobalOffensive)
	{
		if(g_Access[client][bAdmin])
		{
			if(iEnt)
			{
				decl Float:fOrigin[3];
				GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fOrigin);

				Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPositionDetails", client, fOrigin[0], fOrigin[1], fOrigin[2]);
				AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
			}
			else
			{
				Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPositionDetailsMissing", client);
				AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
			}
		}
	}

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryPositionDefault", client);
	AddMenuItem(hMenu, "0", sBuffer);

	DisplayMenuAtItem(hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_ModifyPosition(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Modify(param1);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1], true))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);
			new _iTemp = StringToInt(sOption);

			if(!_iTemp)
				Menu_DefaultPosition(param1);
			else
			{
				if(Bool_MoveValid(param1, true))
				{
					new iEnt = (g_iPlayerControl[param1] > 0) ? g_iPlayerControl[param1] : Trace_GetEntity(param1);
					if(Entity_Valid(iEnt))
					{
						new iOwner = GetClientOfUserId(g_iPropUser[iEnt]);
						if(iOwner == param1 || g_Access[param1][bAdmin])
						{
							new Float:_fTemp[3];
							switch(_iTemp)
							{
								case 1:
									_fTemp[0] = g_Cfg_fDefinedPositions[g_iPlayerPosition[param1]];
								case 2:
									_fTemp[0] = (g_Cfg_fDefinedPositions[g_iPlayerPosition[param1]] * -1);
								case 3:
									_fTemp[1] = g_Cfg_fDefinedPositions[g_iPlayerPosition[param1]];
								case 4:
									_fTemp[1] = (g_Cfg_fDefinedPositions[g_iPlayerPosition[param1]] * -1);
								case 5:
									_fTemp[2] = g_Cfg_fDefinedPositions[g_iPlayerPosition[param1]];
								case 6:
									_fTemp[2] = (g_Cfg_fDefinedPositions[g_iPlayerPosition[param1]] * -1);
							}

							if(g_Access[param1][bAdmin])
							{
								if(!iOwner || iOwner == param1)
									PrintHintText(param1, "%t%t", "prefixHintMessage", "hintNotifyUserMovePropAdmin", g_Cfg_sPropNames[g_iPropType[iEnt]], g_Cfg_fDefinedPositions[g_iPlayerPosition[param1]], iEnt, g_iCurEntities);
								else
									PrintHintText(param1, "%t%t", "prefixHintMessage", "hintNotifyUserMoveClientPropAdmin", g_Cfg_sPropNames[g_iPropType[iEnt]], g_sName[iOwner], g_Cfg_fDefinedPositions[g_iPlayerPosition[param1]], iEnt, g_iCurEntities);
							}
							else
								PrintHintText(param1, "%t%t", "prefixHintMessage", "hintNotifyUserMoveProp", g_Cfg_sPropNames[g_iPropType[iEnt]], g_Cfg_fDefinedPositions[g_iPlayerPosition[param1]]);

							Entity_PositionProp(iEnt, _fTemp);
							Menu_ModifyPosition(param1, iEnt, GetMenuSelectionPosition());
							return;
						}
						else
							PrintHintText(param1, "%t%t", "prefixHintMessage", "hintNotifyUserMovePropWarningOwner", g_Cfg_sPropNames[g_iPropType[iEnt]], g_sPropOwner[iEnt]);
					}
				}

				Menu_ModifyPosition(param1, 0, GetMenuSelectionPosition());
			}
		}
	}

	return;
}

Menu_DefaultPosition(client, index = 0, bool:settings = false)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client]))
		return;

	decl String:sBuffer[128], String:sTemp[4];
	new Handle:hMenu = settings ? CreateMenu(MenuHandler_DefaultPositionSettings) : CreateMenu(MenuHandler_DefaultPosition);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	for(new i = 0; i < g_iCfg_TotalPositions; i++)
	{
		IntToString(i, sTemp, 4);
		Format(sBuffer, sizeof(sBuffer), "%s%T", (g_iPlayerPosition[client] == i) ? g_sPrefixSelect : g_sPrefixEmpty, "menuEntryPositionModify", client, g_Cfg_fDefinedPositions[i]);
		AddMenuItem(hMenu, sTemp, sBuffer);
	}

	DisplayMenuAtItem(hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_DefaultPosition(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_ModifyPosition(param1, 0);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1]))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);
			g_iPlayerPosition[param1] = StringToInt(sOption);
			SetClientCookie(param1, g_cCookiePosition, sOption);

			#if defined _colors_included
			CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserPositionSettingSuccess", g_Cfg_fDefinedPositions[g_iPlayerPosition[param1]]);
			#else
			PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserPositionSettingSuccess", g_Cfg_fDefinedPositions[g_iPlayerPosition[param1]]);
			#endif
			Menu_DefaultPosition(param1, GetMenuSelectionPosition());
		}
	}
}

public MenuHandler_DefaultPositionSettings(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Actions(param1);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1]))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);
			g_iPlayerPosition[param1] = StringToInt(sOption);
			SetClientCookie(param1, g_cCookiePosition, sOption);

			#if defined _colors_included
			CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserPositionSettingSuccess", g_Cfg_fDefinedPositions[g_iPlayerPosition[param1]]);
			#else
			PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserPositionSettingSuccess", g_Cfg_fDefinedPositions[g_iPlayerPosition[param1]]);
			#endif
			Menu_DefaultPosition(param1, GetMenuSelectionPosition());
		}
	}
}

//*****************************************************************************************
//* |||  | Modify Menu Functions
//*****************************************************************************************
Action_PhaseProp(client, iEnt = 0)
{
	new iTmpEnt = (iEnt > 0) ? iEnt : Trace_GetEntity(client);
	if(Entity_Valid(iTmpEnt))
	{
		new iOwner = GetClientOfUserId(g_iPropUser[iTmpEnt]);
		if(iOwner == client || g_Access[client][bAdmin])
		{
			if(g_iPropState[iTmpEnt] & STATE_PHASE || g_hPropPhase[iTmpEnt] != INVALID_HANDLE)
				PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyPhaseAlready", g_Cfg_sPropNames[g_iPropType[iTmpEnt]]);
			else
			{
				g_iPropState[iTmpEnt] |= STATE_PHASE;
				SetPropColorAlpha(iTmpEnt, ALPHA_PROP_PHASED);
				SetEntProp(iTmpEnt, Prop_Data, "m_CollisionGroup", 1);
				g_hPropPhase[iTmpEnt] = CreateTimer(g_fPhaseDelay, Timer_PhaseProp, iTmpEnt, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		else
			PrintHintText(client, "%t%t", "prefixHintMessage", "hintNotifyUserPhasePropWarningOwner", g_Cfg_sPropNames[g_iPropType[iTmpEnt]], g_sPropOwner[iTmpEnt]);
	}
}

//*****************************************************************************************
//* |||  | Control Menu
//*****************************************************************************************
Menu_Control(client, index = 0)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client], true))
		return;

	decl String:sBuffer[128];
	new Handle:hMenu = CreateMenu(MenuHandler_Control);
	SetMenuTitle(hMenu, g_sTitle);
	if(g_bGlobalOffensive)
	{
		SetMenuPagination(hMenu, MENU_NO_PAGINATION);
		SetMenuExitButton(hMenu, true);
	}
	else
	{
		SetMenuExitButton(hMenu, true);
		SetMenuExitBackButton(hMenu, true);
	}

	if(g_iPlayerControl[client] > 0)
		Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryControlRelease", client);
	else
		Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryControlGrab", client);
	AddMenuItem(hMenu, "0", sBuffer, Bool_ControlValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	if(g_iPlayerControl[client] > 0)
		Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryControlClone", client, g_Cfg_sPropNames[g_iPropType[g_iPlayerControl[client]]]);
	else
		Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryControlCloneGrab", client);
	AddMenuItem(hMenu, "1", sBuffer, (g_iPlayerControl[client] > 0 && Bool_SpawnValid(client, false, true)) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	if(g_Access[client][bAccessMove])
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryControlDistance", client);
		AddMenuItem(hMenu, "2", sBuffer);
	}

	if(g_Access[client][bAccessRotate])
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryControlRotation", client);
		AddMenuItem(hMenu, "3", sBuffer);
	}

	Format(sBuffer, sizeof(sBuffer), "%s%T", (g_bLockedAxis[client][0]) ? g_sPrefixSelect : g_sPrefixEmpty, "menuEntryControlSettingLockAxisX", client);
	AddMenuItem(hMenu, "4", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%s%T", (g_bLockedAxis[client][1]) ? g_sPrefixSelect : g_sPrefixEmpty, "menuEntryControlSettingLockAxisY", client);
	AddMenuItem(hMenu, "5", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%s%T", (g_bLockedAxis[client][2]) ? g_sPrefixSelect : g_sPrefixEmpty, "menuEntryControlSettingLockAxisZ", client);
	AddMenuItem(hMenu, "6", sBuffer);

	DisplayMenuAtItem(hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_Control(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Main(param1);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1], true))
				return;

			decl _iOption, String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);
			_iOption = StringToInt(sOption);

			switch(_iOption)
			{
				case 0:
				{
					if(g_iPlayerControl[param1] > 0)
						ClearClientControl(param1);
					else
					{
						new iEnt = Trace_GetEntity(param1, g_fGrabDistance);
						if(Entity_Valid(iEnt))
							IssueGrab(param1, iEnt);
					}
				}
				case 1:
				{
					if(g_iPlayerControl[param1] > 0)
						SpawnClone(param1, g_iPlayerControl[param1]);

					if(g_bGlobalOffensive)
					{
						Menu_Control(param1, GetMenuSelectionPosition());
						return;
					}
				}
				case 2:
				{
					Menu_ControlDistance(param1);
					return;
				}
				case 3:
				{
					Menu_ControlRotation(param1);
					return;
				}
				case 4:
				{
					g_bLockedAxis[param1][0] = !g_bLockedAxis[param1][0];

					if(g_bLockedAxis[param1][0])
					{
						#if defined _colors_included
						CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlSuccessLock", g_sAxisDisplay[0]);
						#else
						PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlSuccessLock", g_sAxisDisplay[0]);
						#endif
					}
					else
					{
						#if defined _colors_included
						CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlSuccessFree", g_sAxisDisplay[0]);
						#else
						PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlSuccessFree", g_sAxisDisplay[0]);
						#endif
					}

				}
				case 5:
				{
					g_bLockedAxis[param1][1] = !g_bLockedAxis[param1][1];

					if(g_bLockedAxis[param1][1])
					{
						#if defined _colors_included
						CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlSuccessLock", g_sAxisDisplay[1]);
						#else
						PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlSuccessLock", g_sAxisDisplay[1]);
						#endif
					}
					else
					{
						#if defined _colors_included
						CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlSuccessFree", g_sAxisDisplay[1]);
						#else
						PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlSuccessFree", g_sAxisDisplay[1]);
						#endif
					}
				}
				case 6:
				{
					g_bLockedAxis[param1][2] = !g_bLockedAxis[param1][2];

					if(g_bLockedAxis[param1][2])
					{
						#if defined _colors_included
						CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlSuccessLock", g_sAxisDisplay[2]);
						#else
						PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlSuccessLock", g_sAxisDisplay[2]);
						#endif
					}
					else
					{
						#if defined _colors_included
						CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlSuccessFree", g_sAxisDisplay[2]);
						#else
						PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlSuccessFree", g_sAxisDisplay[2]);
						#endif
					}
				}
			}

			Menu_Control(param1);
		}
	}
}

Menu_ControlDistance(client)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client]))
		return;

	decl String:sBuffer[128];
	new Handle:hMenu = CreateMenu(MenuHandler_ControlDistance);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryControlSettingDistance", client, g_fConfigDistance[client]);
	AddMenuItem(hMenu, "0", sBuffer, ITEMDRAW_DISABLED);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryControlSettingDistanceInc", client);
	AddMenuItem(hMenu, "1", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryControlSettingDistanceDec", client);
	AddMenuItem(hMenu, "2", sBuffer);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_ControlDistance(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit, MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Control(param1);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1], true))
				return;

			decl _iOption, String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);
			_iOption = StringToInt(sOption);

			switch(_iOption)
			{
				case 1:
				{
					if(g_fConfigDistance[param1] < g_fGrabMaximum)
						g_fConfigDistance[param1] += g_fGrabInterval;
					else
						g_fConfigDistance[param1] = g_fGrabMinimum;

					#if defined _colors_included
					CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlDistanceSuccess", g_fConfigDistance[param1]);
					#else
					PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlDistanceSuccess", g_fConfigDistance[param1]);
					#endif
				}
				case 2:
				{
					if(g_fConfigDistance[param1] > g_fGrabMinimum)
						g_fConfigDistance[param1] -= g_fGrabInterval;
					else
						g_fConfigDistance[param1] = g_fGrabMaximum;

					#if defined _colors_included
					CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlDistanceSuccess", g_fConfigDistance[param1]);
					#else
					PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlDistanceSuccess", g_fConfigDistance[param1]);
					#endif
				}
			}

			Menu_ControlDistance(param1);
		}
	}
}

Menu_ControlRotation(client, index = 0)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client]))
		return;

	decl String:sBuffer[128];
	new Handle:hMenu = CreateMenu(MenuHandler_ControlRotation);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryControlDistanceAxisXInc", client, g_Cfg_fDefinedRotations[g_iPlayerRotation[client]]);
	AddMenuItem(hMenu, "1", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryControlDistanceAxisXDec", client, g_Cfg_fDefinedRotations[g_iPlayerRotation[client]]);
	AddMenuItem(hMenu, "2", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryControlDistanceAxisYInc", client, g_Cfg_fDefinedRotations[g_iPlayerRotation[client]]);
	AddMenuItem(hMenu, "3", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryControlDistanceAxisYDec", client, g_Cfg_fDefinedRotations[g_iPlayerRotation[client]]);
	AddMenuItem(hMenu, "4", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryControlDistanceAxisZInc", client, g_Cfg_fDefinedRotations[g_iPlayerRotation[client]]);
	AddMenuItem(hMenu, "5", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryControlDistanceAxisZDec", client, g_Cfg_fDefinedRotations[g_iPlayerRotation[client]]);
	AddMenuItem(hMenu, "6", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryRotationReset", client);
	AddMenuItem(hMenu, "7", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryRotationDefault", client);
	AddMenuItem(hMenu, "0", sBuffer);

	DisplayMenuAtItem(hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_ControlRotation(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit, MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Control(param1);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1], true))
				return;

			decl _iOption, String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);
			_iOption = StringToInt(sOption);

			switch(_iOption)
			{
				case 0:
					Menu_DefaultRotation(param1, _, 3);
				case 1:
				{
					g_fConfigAxis[param1][0] += g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]];

					#if defined _colors_included
					CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlRotationSuccessInc", g_sAxisDisplay[0], g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]]);
					#else
					PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlRotationSuccessInc", g_sAxisDisplay[0], g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]]);
					#endif
				}
				case 2:
				{
					g_fConfigAxis[param1][0] -= g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]];

					#if defined _colors_included
					CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlRotationSuccessDec", g_sAxisDisplay[0], g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]]);
					#else
					PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlRotationSuccessDec", g_sAxisDisplay[0], g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]]);
					#endif
				}
				case 3:
				{
					g_fConfigAxis[param1][1] += g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]];

					#if defined _colors_included
					CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlRotationSuccessInc", g_sAxisDisplay[1], g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]]);
					#else
					PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlRotationSuccessInc", g_sAxisDisplay[1], g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]]);
					#endif
				}
				case 4:
				{
					g_fConfigAxis[param1][1] -= g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]];

					#if defined _colors_included
					CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlRotationSuccessDec", g_sAxisDisplay[1], g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]]);
					#else
					PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlRotationSuccessDec", g_sAxisDisplay[1], g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]]);
					#endif
				}
				case 5:
				{
					g_fConfigAxis[param1][2] += g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]];

					#if defined _colors_included
					CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlRotationSuccessInc", g_sAxisDisplay[2], g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]]);
					#else
					PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlRotationSuccessInc", g_sAxisDisplay[2], g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]]);
					#endif
				}
				case 6:
				{
					g_fConfigAxis[param1][2] -= g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]];

					#if defined _colors_included
					CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlRotationSuccessDec", g_sAxisDisplay[2], g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]]);
					#else
					PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserControlRotationSuccessDec", g_sAxisDisplay[2], g_Cfg_fDefinedRotations[g_iPlayerRotation[param1]]);
					#endif
				}
				case 7:
				{
					g_fConfigAxis[param1][0] = g_fConfigAxis[param1][1] = g_fConfigAxis[param1][2] = 0.0;
				}
			}

			if(_iOption)
			{
				GetCleanAngles(g_fConfigAxis[param1]);
				Menu_ControlRotation(param1, GetMenuSelectionPosition());
			}
		}
	}
}

//*****************************************************************************************
//* |||  | Control Menu Functions
//*****************************************************************************************


//*****************************************************************************************
//* |||  | Action Menu
//*****************************************************************************************
Menu_Actions(client)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client]))
		return;

	decl String:sBuffer[128];

	new Handle:hMenu = CreateMenu(MenuHandler_Actions);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, g_bGlobalOffensive ? false : true);

	if(g_Access[client][bAccessTeleport])
	{
		if(!g_Access[client][iTotalTeleports])
			Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryTeleportInfinite", client);
		else
			Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryTeleportLimited", client, g_iPlayerTeleports[client], g_Access[client][iTotalTeleports]);

		AddMenuItem(hMenu, "1", sBuffer, Bool_TeleportValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	if(g_Access[client][bAccessCustom])
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryKeys", client);

		AddMenuItem(hMenu, "4", sBuffer);
	}

	if(g_Access[client][bAccessThird])
	{
		if(g_bThirdPerson[client])
			Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryThirdDisable", client);
		else
			Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryThirdEnable", client);

		AddMenuItem(hMenu, "2", sBuffer);
	}

	if(g_Access[client][bAccessFly])
	{
		if(g_bFlying[client])
			Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryFlyDisable", client);
		else
			Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryFlyEnable", client);

		AddMenuItem(hMenu, "3", sBuffer);
	}

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Actions(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Main(param1);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1]))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);
			switch(StringToInt(sOption))
			{
				case 1:
				{
					if(Bool_TeleportValid(param1, true))
						Menu_ConfirmTeleport(param1);
					else
						Menu_Actions(param1);
				}
				case 2:
				{
					if(g_iDisableThirdPerson && g_iDisableThirdPerson & g_iPhase)
					{
						#if defined _colors_included
						CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserThirdRestricted");
						#else
						PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserThirdRestricted");
						#endif
					}
					else
						ToggleThird(param1, STATE_AUTO);

					Menu_Actions(param1);
				}
				case 3:
				{
					if(g_iDisableFlying && g_iDisableFlying & g_iPhase)
					{
						#if defined _colors_included
						CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserFlyRestricted");
						#else
						PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserFlyRestricted");
						#endif
					}
					else
						ToggleFlying(param1, STATE_AUTO);

					Menu_Actions(param1);
				}
				case 4:
				{
					Menu_Custom(param1);
				}
				case 5:
				{
					Menu_DefaultRotation(param1, _, 2);
				}
				case 6:
				{
					Menu_DefaultPosition(param1, _, true);
				}
				case 7:
				{
					Menu_DefaultControl(param1);
				}
			}
		}
	}
}

Menu_DefaultControl(client)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client]))
		return;

	decl String:sBuffer[128];
	new Handle:hMenu = CreateMenu(MenuHandler_DefaultControl);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	Format(sBuffer, sizeof(sBuffer), "%s%T", (g_bPlayerControl[client] ? g_sPrefixSelect : g_sPrefixEmpty), "menuEntryControlSettingLocked", client);
	AddMenuItem(hMenu, "1", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%s%T", (!g_bPlayerControl[client] ? g_sPrefixSelect : g_sPrefixEmpty), "menuEntryControlSettingFree", client);
	AddMenuItem(hMenu, "0", sBuffer);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_DefaultControl(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Actions(param1);
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1]))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, sizeof(sOption));

			new bool:bOld = g_bPlayerControl[param1];
			g_bPlayerControl[param1] = bool:StringToInt(sOption);
			SetClientCookie(param1, g_cCookieControl, sOption);

			if(bOld != g_bPlayerControl[param1])
				for(new i = 0; i <= 2; i++)
					g_bLockedAxis[param1][i] = g_bPlayerControl[param1] ? true : false;

			Menu_DefaultControl(param1);
		}
	}
}

Menu_DefaultColors(client, index = 0)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client]))
		return;

	decl String:sTemp[4], String:sBuffer[128];

	new Handle:hMenu = CreateMenu(MenuHandler_DefaultColors);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	for(new i = 0; i < g_iNumColors; i++)
	{
		if(!g_Cfg_iColorAccess[i] || g_Access[client][iAccess] & g_Cfg_iColorAccess[i])
		{
			IntToString(i, sTemp, 4);
			Format(sBuffer, sizeof(sBuffer), "%s%s", (g_iPlayerColor[client] == i) ? g_sPrefixSelect : g_sPrefixEmpty, g_Cfg_sColorNames[i]);
			AddMenuItem(hMenu, sTemp, sBuffer);
		}
	}

	DisplayMenuAtItem(hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_DefaultColors(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Modify(param1);
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1]))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);

			new iOld = g_iPlayerColor[param1];
			g_iPlayerColor[param1] = StringToInt(sOption);
			SetClientCookie(param1, g_cCookieColor, sOption);

			#if defined _colors_included
			CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserColorSuccess", g_Cfg_sColorNames[g_iPlayerColor[param1]]);
			#else
			PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserColorSuccess", g_Cfg_sColorNames[g_iPlayerColor[param1]]);
			#endif

			if(iOld != g_iPlayerColor[param1] && Bool_ColorValid(param1, true) && Bool_ColorAllowed(param1, true))
			{
				g_iPlayerColors[param1]++;
				ColorClientProps(param1, g_iPlayerColor[param1]);
			}

			Menu_DefaultColors(param1, GetMenuSelectionPosition());
		}
	}
}

Menu_ConfirmClear(client)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client], true))
		return;

	decl String:sBuffer[128];

	new Handle:hMenu = CreateMenu(MenuHandler_ConfirmClear);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryClearPrompt", client);
	AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);

	if(!g_bGlobalOffensive)
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "menuOptionSpacerSelection", client);
		if(!StrEqual(sBuffer, ""))
			AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
	}

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryClearPromptYes", client);
	AddMenuItem(hMenu, "1", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryClearPromptNo", client);
	AddMenuItem(hMenu, "0", sBuffer);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_ConfirmClear(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Modify(param1);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1], true))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);

			if(StringToInt(sOption) && Bool_ClearValid(param1, true))
				Bool_ClearClientProps(param1, true, true);

			Menu_Actions(param1);
		}
	}
}

Menu_ConfirmTeleport(client)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client]))
		return;

	decl String:sBuffer[128];

	new Handle:hMenu = CreateMenu(MenuHandler_ConfirmTeleport);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryTeleportPrompt", client);
	AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);

	if(!g_bGlobalOffensive)
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "menuOptionSpacerSelection", client);
		if(!StrEqual(sBuffer, ""))
			AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
	}

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryTeleportPromptYes", client);
	AddMenuItem(hMenu, "1", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryTeleportPromptNo", client);
	AddMenuItem(hMenu, "0", sBuffer);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_ConfirmTeleport(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Actions(param1);
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1]))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);

			if(Bool_TeleportValid(param1, true))
			{
				if(StringToInt(sOption))
					PerformTeleport(param1);
				else
					Menu_Actions(param1);
			}
			else
				Menu_Actions(param1);
		}
	}
}

Menu_Custom(client)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client]))
		return;

	decl String:sBuffer[128];

	new Handle:hMenu = CreateMenu(MenuHandler_Custom);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryKeysActiveKey", client);
	AddMenuItem(hMenu, FUNCTION_KEY_USE_CHAR, sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryKeysLeftMouse", client);
	AddMenuItem(hMenu, FUNCTION_KEY_LEFT_CHAR, sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuEntryKeysRightMouse", client);
	AddMenuItem(hMenu, FUNCTION_KEY_RIGHT_CHAR, sBuffer);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Custom(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Actions(param1);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1]))
				return;

			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);
			Menu_CustomFunction(param1, StringToInt(sOption));
		}
	}

	return;
}

Menu_CustomFunction(client, key)
{
	if(!CheckTeamAccess(client, g_iCurrentTeam[client]))
		return;

	decl String:sBuffer[128], String:sTemp[8];

	new Handle:hMenu = CreateMenu(MenuHandler_CustomFunction);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	Format(sBuffer, sizeof(sBuffer), "%s%T", (g_iPlayerCustom[client][key] == FUNCTION_DISABLED) ? g_sPrefixSelect : g_sPrefixEmpty, "menuEntryKeysOptionDisable", client);
	Format(sTemp, 8, "%d %d", key, FUNCTION_DISABLED);
	AddMenuItem(hMenu, sTemp, sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%s%T", (g_iPlayerCustom[client][key] == FUNCTION_MAIN_MENU) ? g_sPrefixSelect : g_sPrefixEmpty, "menuEntryKeysOptionMenu", client);
	Format(sTemp, 8, "%d %d", key, FUNCTION_MAIN_MENU);
	AddMenuItem(hMenu, sTemp, sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%s%T", (g_iPlayerCustom[client][key] == FUNCTION_MODIFY_MENU) ? g_sPrefixSelect : g_sPrefixEmpty, "menuEntryKeysOptionModify", client);
	Format(sTemp, 8, "%d %d", key, FUNCTION_MODIFY_MENU);
	AddMenuItem(hMenu, sTemp, sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%s%T", (g_iPlayerCustom[client][key] == FUNCTION_CONTROL_MENU) ? g_sPrefixSelect : g_sPrefixEmpty, "menuEntryKeysOptionControl", client);
	Format(sTemp, 8, "%d %d", key, FUNCTION_CONTROL_MENU);
	AddMenuItem(hMenu, sTemp, sBuffer);

	if(g_Access[client][bAccessProp])
	{
		Format(sBuffer, sizeof(sBuffer), "%s%T", (g_iPlayerCustom[client][key] == FUNCTION_SPAWN_PROP) ? g_sPrefixSelect : g_sPrefixEmpty, "menuEntryKeysOptionSpawn", client);
		Format(sTemp, 8, "%d %d", key, FUNCTION_SPAWN_PROP);
		AddMenuItem(hMenu, sTemp, sBuffer);
	}

	if(g_Access[client][bAccessDelete])
	{
		Format(sBuffer, sizeof(sBuffer), "%s%T", (g_iPlayerCustom[client][key] == FUNCTION_DELETE_PROP) ? g_sPrefixSelect : g_sPrefixEmpty, "menuEntryKeysOptionDelete", client);
		Format(sTemp, 8, "%d %d", key, FUNCTION_DELETE_PROP);
		AddMenuItem(hMenu, sTemp, sBuffer);
	}

	if(g_Access[client][bAccessControl])
	{
		Format(sBuffer, sizeof(sBuffer), "%s%T", (g_iPlayerCustom[client][key] == FUNCTION_GRAB_PROP) ? g_sPrefixSelect : g_sPrefixEmpty, "menuEntryKeysOptionGrab", client);
		Format(sTemp, 8, "%d %d", key, FUNCTION_GRAB_PROP);
		AddMenuItem(hMenu, sTemp, sBuffer);

		Format(sBuffer, sizeof(sBuffer), "%s%T", (g_iPlayerCustom[client][key] == FUNCTION_CLONE_PROP) ? g_sPrefixSelect : g_sPrefixEmpty, "menuEntryKeysOptionClone", client);
		Format(sTemp, 8, "%d %d", key, FUNCTION_CLONE_PROP);
		AddMenuItem(hMenu, sTemp, sBuffer);
	}

	if(g_Access[client][bAccessCheck])
	{
		Format(sBuffer, sizeof(sBuffer), "%s%T", (g_iPlayerCustom[client][key] == FUNCTION_CHECK_PROP) ? g_sPrefixSelect : g_sPrefixEmpty, "menuEntryKeysOptionCheck", client);
		Format(sTemp, 8, "%d %d", key, FUNCTION_CHECK_PROP);
		AddMenuItem(hMenu, sTemp, sBuffer);
	}

	if(g_Access[client][bAccessPhase])
	{
		Format(sBuffer, sizeof(sBuffer), "%s%T", (g_iPlayerCustom[client][key] == FUNCTION_PHASE_PROP) ? g_sPrefixSelect : g_sPrefixEmpty, "menuEntryKeysOptionPhase", client);
		Format(sTemp, 8, "%d %d", key, FUNCTION_PHASE_PROP);
		AddMenuItem(hMenu, sTemp, sBuffer);
	}

	if(g_Access[client][bAccessThird])
	{
		Format(sBuffer, sizeof(sBuffer), "%s%T", (g_iPlayerCustom[client][key] == FUNCTION_TOGGLE_THIRD) ? g_sPrefixSelect : g_sPrefixEmpty, "menuEntryKeysOptionThirdPerson", client);
		Format(sTemp, 8, "%d %d", key, FUNCTION_TOGGLE_THIRD);
		AddMenuItem(hMenu, sTemp, sBuffer);
	}

	if(g_Access[client][bAccessFly])
	{
		Format(sBuffer, sizeof(sBuffer), "%s%T", (g_iPlayerCustom[client][key] == FUNCTION_TOGGLE_FLYING) ? g_sPrefixSelect : g_sPrefixEmpty, "menuEntryKeysOptionFly", client);
		Format(sTemp, 8, "%d %d", key, FUNCTION_TOGGLE_FLYING);
		AddMenuItem(hMenu, sTemp, sBuffer);
	}

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_CustomFunction(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Custom(param1);
			}
		}
		case MenuAction_Select:
		{
			if(!CheckTeamAccess(param1, g_iCurrentTeam[param1]))
				return;

			decl String:sOption[8], String:sBuffer[2][4], String:_sPhrase[192];
			GetMenuItem(menu, param2, sOption, 8);
			ExplodeString(sOption, " ", sBuffer, 2, 4);

			new _iKey = StringToInt(sBuffer[0]);
			g_iPlayerCustom[param1][_iKey] = StringToInt(sBuffer[1]);
			Format(_sPhrase, sizeof(_sPhrase), "%d %d %d", g_iPlayerCustom[param1][FUNCTION_KEY_USE], g_iPlayerCustom[param1][FUNCTION_KEY_LEFT], g_iPlayerCustom[param1][FUNCTION_KEY_RIGHT]);
			SetClientCookie(param1, g_cCookieCustom, _sPhrase);

			switch(_iKey)
			{
				case FUNCTION_KEY_USE:
					Format(_sPhrase, sizeof(_sPhrase), "%T", "menuEntryKeysDetailsActive", param1);
				case FUNCTION_KEY_LEFT:
					Format(_sPhrase, sizeof(_sPhrase), "%T", "menuEntryKeysDetailsLeftMouse", param1);
				case FUNCTION_KEY_RIGHT:
					Format(_sPhrase, sizeof(_sPhrase), "%T", "menuEntryKeysDetailsRightMouse", param1);
			}

			switch(g_iPlayerCustom[param1][_iKey])
			{
				case FUNCTION_MAIN_MENU:
					Format(_sPhrase, sizeof(_sPhrase), "%s%T", _sPhrase, "menuEntryKeysNotifyMenu", param1);
				case FUNCTION_MODIFY_MENU:
					Format(_sPhrase, sizeof(_sPhrase), "%s%T", _sPhrase, "menuEntryKeysNotifyModify", param1);
				case FUNCTION_CONTROL_MENU:
					Format(_sPhrase, sizeof(_sPhrase), "%s%T", _sPhrase, "menuEntryKeysNotifyControl", param1);
				case FUNCTION_SPAWN_PROP:
					Format(_sPhrase, sizeof(_sPhrase), "%s%T", _sPhrase, "menuEntryKeysNotifyPrevious", param1);
				case FUNCTION_CLONE_PROP:
					Format(_sPhrase, sizeof(_sPhrase), "%s%T", _sPhrase, "menuEntryKeysNotifyClone", param1);
				case FUNCTION_DELETE_PROP:
					Format(_sPhrase, sizeof(_sPhrase), "%s%T", _sPhrase, "menuEntryKeysNotifyDelete", param1);
				case FUNCTION_GRAB_PROP:
					Format(_sPhrase, sizeof(_sPhrase), "%s%T", _sPhrase, "menuEntryKeysNotifyGrab", param1);
				case FUNCTION_CHECK_PROP:
					Format(_sPhrase, sizeof(_sPhrase), "%s%T", _sPhrase, "menuEntryKeysNotifyCheck", param1);
				case FUNCTION_PHASE_PROP:
					Format(_sPhrase, sizeof(_sPhrase), "%s%T", _sPhrase, "menuEntryKeysNotifyPhase", param1);
				case FUNCTION_TOGGLE_THIRD:
					Format(_sPhrase, sizeof(_sPhrase), "%s%T", _sPhrase, "menuEntryKeysNotifyThird", param1);
				case FUNCTION_TOGGLE_FLYING:
					Format(_sPhrase, sizeof(_sPhrase), "%s%T", _sPhrase, "menuEntryKeysNotifyFly", param1);
				case FUNCTION_DISABLED:
					Format(_sPhrase, sizeof(_sPhrase), "%s%T", _sPhrase, "menuEntryKeysNotifyDisabled", param1);
			}

			if(_iKey != FUNCTION_KEY_USE && g_iPlayerCustom[param1][_iKey] != FUNCTION_DISABLED)
				Format(_sPhrase, sizeof(_sPhrase), "%s%T", _sPhrase, "menuEntryKeysDisables", param1);

			#if defined _colors_included
			CPrintToChat(param1, "%t%s", "prefixChatMessage", _sPhrase);
			#else
			PrintToChat(param1, "%t%s", "prefixChatMessage", _sPhrase);
			#endif
			Menu_Custom(param1);
		}
	}

	return;
}

//*****************************************************************************************
//* |||  | Action Menu Functions
//*****************************************************************************************

//*****************************************************************************************
//* |||  | Base Menu
//*****************************************************************************************

//*****************************************************************************************
//* |||  | Base Menu Functions
//*****************************************************************************************

//*****************************************************************************************
//* |||  | Admin Menu
//*****************************************************************************************
Menu_Admin(client)
{
	decl String:sBuffer[128];
	new iOptions, Handle:hMenu = CreateMenu(MenuHandler_Admin);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, g_bGlobalOffensive ? false : true);

	if(g_Access[client][bAccessAdminDelete] || CheckCommandAccess(client, "Bw_Access_Delete", ADMFLAG_ROOT))
	{
		iOptions++;
		Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminDelete", client);
		AddMenuItem(hMenu, "0", sBuffer);
	}

	if(g_Access[client][bAccessAdminStuck] || CheckCommandAccess(client, "Bw_Access_Stuck", ADMFLAG_ROOT))
	{
		iOptions++;
		Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminTeleport", client);
		AddMenuItem(hMenu, "1", sBuffer);
	}

	if(g_Access[client][bAccessAdminColor] || CheckCommandAccess(client, "Bw_Access_Color", ADMFLAG_ROOT))
	{
		iOptions++;
		Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminColor", client);
		AddMenuItem(hMenu, "2", sBuffer);
	}

	if(g_Access[client][bAccessAdminGimp] || CheckCommandAccess(client, "Bw_Access_Gimp", ADMFLAG_ROOT))
	{
		iOptions++;
		Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminGimp", client);
		AddMenuItem(hMenu, "3", sBuffer);
	}

	if(g_Access[client][bAccessBase] && (g_Access[client][bAccessAdminBase] || CheckCommandAccess(client, "Bw_Access_Base", ADMFLAG_ROOT)))
	{
		iOptions++;
		Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminBase", client);
		AddMenuItem(hMenu, "4", sBuffer, (g_bDatabaseFound && g_hSql_Database != INVALID_HANDLE) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	if(g_bZoneControl && (g_Access[client][bAccessAdminZone] || CheckCommandAccess(client, "Bw_Access_Zone", ADMFLAG_ROOT)))
	{
		iOptions++;
		Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminZones", client);
		AddMenuItem(hMenu, "5", sBuffer, (g_bDatabaseFound && g_hSql_Database != INVALID_HANDLE) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	if(iOptions)
	{
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	}

	return iOptions;
}

public MenuHandler_Admin(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Main(param1);
			}
		}
		case MenuAction_Select:
		{
			decl String:sOption[4];
			GetMenuItem(menu, param2, sOption, 4);
			new _iOption = StringToInt(sOption);

			switch(_iOption)
			{
				case ADMIN_MENU_GIMP:
					Menu_AdminSelectSingle(param1, ADMIN_MENU_GIMP);
				case ADMIN_MENU_BASE:
				{
					#if defined _colors_included
					CPrintToChat(param1, "%tThis feature is still in development, sorry!", "prefixChatMessage");
					#else
					PrintToChat(param1, "%tThis feature is still in development, sorry!", "prefixChatMessage");
					#endif
					Menu_Admin(param1);
				}
				case ADMIN_MENU_ZONE:
					Menu_AdminZones(param1);
				default:
					Menu_AdminSelect(param1, _iOption);
			}
		}
	}
}

Menu_AdminSelect(client, action)
{
	decl String:sBuffer[128], String:sTemp[16];
	new Handle:hMenu = CreateMenu(MenuHandler_AdminSelect);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminSelectSingle", client);
	Format(sTemp, 16, "%d %d", action, TARGET_SINGLE);
	AddMenuItem(hMenu, sTemp, sBuffer);

	if(g_Access[client][bAccessAdminTarget] || CheckCommandAccess(client, "Bw_Access_Target", ADMFLAG_RCON))
	{
		Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminSelectRed", client);
		Format(sTemp, 16, "%d %d", action, TARGET_RED);
		AddMenuItem(hMenu, sTemp, sBuffer);

		Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminSelectBlue", client);
		Format(sTemp, 16, "%d %d", action, TARGET_BLUE);
		AddMenuItem(hMenu, sTemp, sBuffer);

		Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminSelectMass", client);
		Format(sTemp, 16, "%d %d", action, TARGET_ALL);
		AddMenuItem(hMenu, sTemp, sBuffer);
	}

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminSelect(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Admin(param1);
			}
		}
		case MenuAction_Select:
		{
			decl String:sBuffer[16], String:sOption[2][8];
			GetMenuItem(menu, param2, sBuffer, 16);
			ExplodeString(sBuffer, " ", sOption, 2, 8);

			new _iGroup = StringToInt(sOption[1]);
			switch(StringToInt(sOption[0]))
			{
				case ADMIN_MENU_CLEAR:
				{
					if(_iGroup == TARGET_SINGLE)
						Menu_AdminSelectSingle(param1, ADMIN_MENU_CLEAR);
					else
						Menu_AdminConfirmDelete(param1, _iGroup);
				}
				case ADMIN_MENU_STUCK:
				{
					if(_iGroup == TARGET_SINGLE)
						Menu_AdminSelectSingle(param1, ADMIN_MENU_STUCK);
					else
						Menu_AdminConfirmTeleport(param1, _iGroup);
				}
				case ADMIN_MENU_COLOR:
				{
					if(_iGroup == TARGET_SINGLE)
						Menu_AdminSelectSingle(param1, ADMIN_MENU_COLOR);
					else
						Menu_AdminSelectColor(param1, _iGroup);
				}
			}
		}
	}
}

Menu_AdminSelectSingle(client, action)
{
	decl String:sTemp[16], String:sBuffer[128];
	new Handle:hMenu = CreateMenu(MenuHandler_AdminSelectSingle);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	switch(action)
	{
		case ADMIN_MENU_CLEAR:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && g_iPlayerProps[i] > 0)
				{
					Format(sTemp, 16, "%d %d", action, GetClientUserId(i));
					AddMenuItem(hMenu, sTemp, g_sName[i]);
				}
			}
		}
		case ADMIN_MENU_STUCK:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && g_bAlive[i])
				{
					Format(sTemp, 16, "%d %d", action, GetClientUserId(i));
					AddMenuItem(hMenu, sTemp, g_sName[i]);
				}
			}
		}
		case ADMIN_MENU_COLOR:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && g_iPlayerProps[i] > 0 && CheckTeamAccess(i, g_iCurrentTeam[i]))
				{
					Format(sTemp, 16, "%d %d", action, GetClientUserId(i));
					AddMenuItem(hMenu, sTemp, g_sName[i]);
				}
			}
		}
		case ADMIN_MENU_GIMP:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i))
				{
					Format(sTemp, 16, "%d %d", action, GetClientUserId(i));

					if(g_iPlayerGimp[i])
						Format(sBuffer, sizeof(sBuffer), "[G] %s", g_sName[i]);
					else
						Format(sBuffer, sizeof(sBuffer), "[  ] %s", g_sName[i]);

					AddMenuItem(hMenu, sTemp, sBuffer);
				}
			}
		}
	}

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminSelectSingle(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Admin(param1);
			}
		}
		case MenuAction_Select:
		{
			decl String:sBuffer[16], String:sOption[2][8];
			GetMenuItem(menu, param2, sBuffer, 16);
			ExplodeString(sBuffer, " ", sOption, 2, 8);

			new iTarget = GetClientOfUserId(StringToInt(sOption[1]));
			if(iTarget <= 0 || !IsClientInGame(iTarget))
			{
				#if defined _colors_included
				CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
				#else
				PrintToChat(param1, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
				#endif
			}
			else if(!CanUserTarget(param1, iTarget))
			{
				#if defined _colors_included
				CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetWarningTarget");
				#else
				PrintToChat(param1, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetWarningTarget");
				#endif
			}
			else
			{
				switch(StringToInt(sOption[0]))
				{
					case ADMIN_MENU_CLEAR:
						Menu_AdminConfirmDelete(param1, TARGET_SINGLE, StringToInt(sOption[1]));
					case ADMIN_MENU_STUCK:
						Menu_AdminConfirmTeleport(param1, TARGET_SINGLE, StringToInt(sOption[1]));
					case ADMIN_MENU_COLOR:
						Menu_AdminSelectColor(param1, TARGET_SINGLE, StringToInt(sOption[1]));
					case ADMIN_MENU_GIMP:
						Menu_AdminSelectDuration(param1, StringToInt(sOption[1]));
				}

				return;
			}

			Menu_Admin(param1);
		}
	}
}

Menu_AdminConfirmDelete(client, group, target = 0)
{
	decl String:sBuffer[128], String:sTemp[36];

	new Handle:hMenu = CreateMenu(MenuHandler_AdminConfirmDelete);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	switch(group)
	{
		case TARGET_SINGLE:
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminDeletePromptSingle", client, g_sName[GetClientOfUserId(target)]);
			AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_RED:
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminDeletePromptRed", client);
			AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_BLUE:
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminDeletePromptBlue", client);
			AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_ALL:
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminDeletePromptAll", client);
			AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
		}
	}

	Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminDeletePromptDeny", client);
	Format(sTemp, 36, "0 %d %d", group, target);
	AddMenuItem(hMenu, sTemp, sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminDeletePromptConfirm", client);
	Format(sTemp, 36, "1 %d %d",  group, target);
	AddMenuItem(hMenu, sTemp, sBuffer);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminConfirmDelete(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Admin(param1);
			}
		}
		case MenuAction_Select:
		{
			decl String:sOption[36], String:sBuffer[3][12], String:sTemp[192];
			GetMenuItem(menu, param2, sOption, 36);
			ExplodeString(sOption, " ", sBuffer, 3, 12);

			if(StringToInt(sBuffer[0]))
			{
				switch(StringToInt(sBuffer[1]))
				{
					case TARGET_SINGLE:
					{
						new iTarget = GetClientOfUserId(StringToInt(sBuffer[2]));
						if(iTarget <= 0 || !IsClientInGame(iTarget))
						{
							#if defined _colors_included
							CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
							#else
							PrintToChat(param1, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
							#endif
						}
						else
						{
							if(Bool_ClearClientProps(iTarget, true, true))
							{
								if(g_bGlobalOffensive)
								{
									#if defined _colors_included
									CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserClearPropSuccess");
									#else
									PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserClearPropSuccess");
									#endif
								}
								else
									PrintCenterText(param1, "%t%t", "prefixCenterMessage", "chatNotifyUserClearPropSuccess");
								Format(sTemp, 192, "%T", "activityAdminClear", LANG_SERVER, iTarget);
								ShowActivity2(param1, "[SM] ", sTemp);

								Format(sTemp, 192, "%T", "logAdminClear", LANG_SERVER, param1, iTarget);
								LogAction(param1, iTarget, sTemp);
							}
						}
					}
					case TARGET_RED:
					{
						new _iSucceed;
						for(new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && g_iPlayerProps[i] > 0 && g_iCurrentTeam[i] == CS_TEAM_T)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%t%t", "prefixConsoleMessage", "chatCommandNotifyAdminTargetWarningTarget");
								else
								{
									if(Bool_ClearClientProps(i, true, true))
									{
										_iSucceed++;
										Format(sTemp, 192, "%T", "activityAdminClear", LANG_SERVER, i);
										ShowActivity2(param1, "[SM] ", sTemp);

										Format(sTemp, 192, "%T", "logAdminClear", LANG_SERVER, param1, i);
										LogAction(param1, i, sTemp);
									}
								}
							}
						}

						if(_iSucceed)
						{
							if(g_bGlobalOffensive)
							{
								#if defined _colors_included
								CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserClearPropSuccess");
								#else
								PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserClearPropSuccess");
								#endif
							}
							else
								PrintCenterText(param1, "%t%t", "prefixCenterMessage", "centerAdminNotifyClearMultiple", _iSucceed);
						}
					}
					case TARGET_BLUE:
					{
						new _iSucceed;
						for(new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && g_iPlayerProps[i] > 0 && g_iCurrentTeam[i] == CS_TEAM_CT)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%t%t", "prefixConsoleMessage", "chatCommandNotifyAdminTargetWarningTarget");
								else
								{
									if(Bool_ClearClientProps(i, true, true))
									{
										_iSucceed++;
										Format(sTemp, 192, "%T", "activityAdminClear", LANG_SERVER, i);
										ShowActivity2(param1, "[SM] ", sTemp);

										Format(sTemp, 192, "%T", "logAdminClear", LANG_SERVER, param1, i);
										LogAction(param1, i, sTemp);
									}
								}
							}
						}

						if(_iSucceed)
						{
							if(g_bGlobalOffensive)
							{
								#if defined _colors_included
								CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserClearPropSuccess");
								#else
								PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserClearPropSuccess");
								#endif
							}
							else
								PrintCenterText(param1, "%t%t", "prefixCenterMessage", "centerAdminNotifyClearMultiple", _iSucceed);
						}
					}
					case TARGET_ALL:
					{
						new _iSucceed;
						for(new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && g_iPlayerProps[i] > 0)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%t%t", "prefixConsoleMessage", "chatCommandNotifyAdminTargetWarningTarget");
								else
								{
									if(Bool_ClearClientProps(i, true, true))
									{
										_iSucceed++;
										Format(sTemp, 192, "%T", "activityAdminClear", LANG_SERVER, i);
										ShowActivity2(param1, "[SM] ", sTemp);

										Format(sTemp, 192, "%T", "logAdminClear", LANG_SERVER, param1, i);
										LogAction(param1, i, sTemp);
									}
								}
							}
						}

						if(_iSucceed)
						{
							if(g_bGlobalOffensive)
							{
								#if defined _colors_included
								CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserClearPropSuccess");
								#else
								PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyUserClearPropSuccess");
								#endif
							}
							else
								PrintCenterText(param1, "%t%t", "prefixCenterMessage", "centerAdminNotifyClearMultiple", _iSucceed);
						}
					}
				}
			}

			Menu_Admin(param1);
		}
	}
}

Menu_AdminConfirmTeleport(client, group, target = 0)
{
	decl String:sBuffer[128], String:sTemp[36];

	new Handle:hMenu = CreateMenu(MenuHandler_AdminConfirmTele);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	switch(group)
	{
		case TARGET_SINGLE:
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminTeleportPromptSingle", client, g_sName[GetClientOfUserId(target)]);
			AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_RED:
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminTeleportPromptRed", client);
			AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_BLUE:
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminTeleportPromptBlue", client);
			AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_ALL:
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminTeleportPromptAll", client);
			AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
		}
	}

	Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminTeleportPromptDeny", client);
	Format(sTemp, 36, "0 %d %d", group, target);
	AddMenuItem(hMenu, sTemp, sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminTeleportPromptConfirm", client);
	Format(sTemp, 36, "1 %d %d",  group, target);
	AddMenuItem(hMenu, sTemp, sBuffer);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminConfirmTele(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Admin(param1);
			}
		}
		case MenuAction_Select:
		{
			decl String:sOption[36], String:sBuffer[3][12], String:sTemp[192];
			GetMenuItem(menu, param2, sOption, 36);
			ExplodeString(sOption, " ", sBuffer, 3, 12);

			if(StringToInt(sBuffer[0]))
			{
				switch(StringToInt(sBuffer[1]))
				{
					case TARGET_SINGLE:
					{
						new iTarget = GetClientOfUserId(StringToInt(sBuffer[2]));
						if(iTarget <= 0 || !IsClientInGame(iTarget))
						{
							#if defined _colors_included
							CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
							#else
							PrintToChat(param1, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
							#endif
						}
						else if(g_bAlive[iTarget])
						{
							TeleportPlayer(iTarget);
							ClearClientTeleport(iTarget);

							if(g_bGlobalOffensive)
							{
								#if defined _colors_included
								CPrintToChat(param1, "%t%t", "prefixChatMessage", "centerAdminNotifyTeleport");
								#else
								PrintToChat(param1, "%t%t", "prefixChatMessage", "centerAdminNotifyTeleport");
								#endif
							}
							else
								PrintCenterText(param1, "%t%t", "prefixCenterMessage", "centerAdminNotifyTeleport");
							Format(sTemp, 192, "%T", "activityAdminTeleport", LANG_SERVER, iTarget);
							ShowActivity2(param1, "[SM] ", sTemp);

							Format(sTemp, 192, "%T", "logAdminTeleport", LANG_SERVER, param1, iTarget);
							LogAction(param1, iTarget, sTemp);
						}
					}
					case TARGET_RED:
					{
						new _iSucceed;
						for(new i = 1; i <= MaxClients; i++)
						{
							if(g_bAlive[i] && IsClientInGame(i) && g_iCurrentTeam[i] == CS_TEAM_T)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%t%t", "prefixConsoleMessage", "chatCommandNotifyAdminTargetWarningTarget");
								else
								{
									TeleportPlayer(i);
									ClearClientTeleport(i);

									_iSucceed++;
									Format(sTemp, 192, "%T", "activityAdminTeleport", LANG_SERVER, i);
									ShowActivity2(param1, "[SM] ", sTemp);

									Format(sTemp, 192, "%T", "logAdminTeleport", LANG_SERVER, param1, i);
									LogAction(param1, i, sTemp);
								}
							}
						}

						if(_iSucceed)
						{
							if(g_bGlobalOffensive)
							{
								#if defined _colors_included
								CPrintToChat(param1, "%t%t", "prefixChatMessage", "centerAdminNotifyTeleport", _iSucceed);
								#else
								PrintToChat(param1, "%t%t", "prefixChatMessage", "centerAdminNotifyTeleport", _iSucceed);
								#endif
							}
							else
								PrintCenterText(param1, "%t%t", "prefixCenterMessage", "centerAdminNotifyTeleport", _iSucceed);
						}
					}
					case TARGET_BLUE:
					{
						new _iSucceed;
						for(new i = 1; i <= MaxClients; i++)
						{
							if(g_bAlive[i] && IsClientInGame(i) && g_iCurrentTeam[i] == CS_TEAM_CT)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%t%t", "prefixConsoleMessage", "chatCommandNotifyAdminTargetWarningTarget");
								else
								{
									TeleportPlayer(i);
									ClearClientTeleport(i);

									_iSucceed++;
									Format(sTemp, 192, "%T", "activityAdminTeleport", LANG_SERVER, i);
									ShowActivity2(param1, "[SM] ", sTemp);

									Format(sTemp, 192, "%T", "logAdminTeleport", LANG_SERVER, param1, i);
									LogAction(param1, i, sTemp);
								}
							}
						}

						if(_iSucceed)
						{
							if(g_bGlobalOffensive)
							{
								#if defined _colors_included
								CPrintToChat(param1, "%t%t", "prefixChatMessage", "centerAdminNotifyTeleport", _iSucceed);
								#else
								PrintToChat(param1, "%t%t", "prefixChatMessage", "centerAdminNotifyTeleport", _iSucceed);
								#endif
							}
							else
								PrintCenterText(param1, "%t%t", "prefixCenterMessage", "centerAdminNotifyTeleport", _iSucceed);
						}
					}
					case TARGET_ALL:
					{
						new _iSucceed;
						for(new i = 1; i <= MaxClients; i++)
						{
							if(g_bAlive[i] && IsClientInGame(i))
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%t%t", "prefixConsoleMessage", "chatCommandNotifyAdminTargetWarningTarget");
								else
								{
									TeleportPlayer(i);
									ClearClientTeleport(i);

									_iSucceed++;
									Format(sTemp, 192, "%T", "activityAdminTeleport", LANG_SERVER, i);
									ShowActivity2(param1, "[SM] ", sTemp);

									Format(sTemp, 192, "%T", "logAdminTeleport", LANG_SERVER, param1, i);
									LogAction(param1, i, sTemp);
								}
							}
						}

						if(_iSucceed)
						{
							if(g_bGlobalOffensive)
							{
								#if defined _colors_included
								CPrintToChat(param1, "%t%t", "prefixChatMessage", "centerAdminNotifyTeleport", _iSucceed);
								#else
								PrintToChat(param1, "%t%t", "prefixChatMessage", "centerAdminNotifyTeleport", _iSucceed);
								#endif
							}
							else
								PrintCenterText(param1, "%t%t", "prefixCenterMessage", "centerAdminNotifyTeleport", _iSucceed);
						}
					}
				}
			}

			Menu_Admin(param1);
		}
	}
}

Menu_AdminSelectColor(client, group, target = 0)
{
	decl String:sTemp[36];

	new Handle:hMenu = CreateMenu(MenuHandler_AdminSelectColor);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	for(new i = 0; i < g_iNumColors; i++)
	{
		if(!g_Cfg_iColorAccess[i] || g_Access[client][iAccess] & g_Cfg_iColorAccess[i])
		{
			Format(sTemp, 36, "%d %d %d", group, i, target);
			AddMenuItem(hMenu, sTemp, g_Cfg_sColorNames[i]);
		}
	}

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminSelectColor(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Admin(param1);
			}
		}
		case MenuAction_Select:
		{
			decl String:sOption[36], String:sBuffer[3][12];
			GetMenuItem(menu, param2, sOption, 36);
			ExplodeString(sOption, " ", sBuffer, 3, 12);

			new iTarget = StringToInt(sBuffer[2]);
			if(iTarget)
			{
				iTarget = GetClientOfUserId(iTarget);
				if(iTarget <= 0 || !IsClientInGame(iTarget))
				{
					#if defined _colors_included
					CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
					#else
					PrintToChat(param1, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
					#endif
				}
				else
					Menu_AdminConfirmColor(param1, StringToInt(sBuffer[0]), StringToInt(sBuffer[1]), StringToInt(sBuffer[2]));
			}
			else
				Menu_AdminConfirmColor(param1, StringToInt(sBuffer[0]), StringToInt(sBuffer[1]), iTarget);
		}
	}
}

Menu_AdminConfirmColor(client, group, color, target = 0)
{
	decl String:sBuffer[128], String:sTemp[40];

	new Handle:hMenu = CreateMenu(MenuHandler_AdminConfirmColor);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	switch(group)
	{
		case TARGET_SINGLE:
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminColorPromptSingle", client, g_sName[GetClientOfUserId(target)]);
			AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_RED:
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminColorPromptRed", client);
			AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_BLUE:
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminColorPromptBlue", client);
			AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_ALL:
		{
			Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminColorPromptAll", client);
			AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);
		}
	}

	Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminColorPromptDeny", client);
	Format(sTemp, 40, "0 %d %d %d", group, color, target);
	AddMenuItem(hMenu, sTemp, sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminColorPromptConfirm", client);
	Format(sTemp, 40, "1 %d %d %d",  group, color, target);
	AddMenuItem(hMenu, sTemp, sBuffer);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminConfirmColor(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Admin(param1);
			}
		}
		case MenuAction_Select:
		{
			decl String:sOption[40], String:sBuffer[4][10];
			GetMenuItem(menu, param2, sOption, 40);
			ExplodeString(sOption, " ", sBuffer, 4, 10);

			if(StringToInt(sBuffer[0]))
			{
				new iIndex = StringToInt(sBuffer[2]);
				switch(StringToInt(sBuffer[1]))
				{
					case TARGET_SINGLE:
					{
						new iTarget = GetClientOfUserId(StringToInt(sBuffer[3]));
						if(iTarget <= 0 || !IsClientInGame(iTarget))
						{
							#if defined _colors_included
							CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
							#else
							PrintToChat(param1, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
							#endif
						}
						else
							ColorClientProps(iTarget, iIndex);
					}
					case TARGET_RED:
					{
						for(new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && g_iPlayerProps[i] > 0 && g_iCurrentTeam[i] == CS_TEAM_T)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%t%t", "prefixConsoleMessage", "chatCommandNotifyAdminTargetWarningTarget");
								else
									ColorClientProps(i, iIndex);
							}
						}
					}
					case TARGET_BLUE:
					{
						for(new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && g_iPlayerProps[i] > 0 && g_iCurrentTeam[i] == CS_TEAM_CT)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%t%t", "prefixConsoleMessage", "chatCommandNotifyAdminTargetWarningTarget");
								else
									ColorClientProps(i, iIndex);
							}
						}
					}
					case TARGET_ALL:
					{
						for(new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && g_iPlayerProps[i] > 0)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%t%t", "prefixConsoleMessage", "chatCommandNotifyAdminTargetWarningTarget");
								else
									ColorClientProps(i, iIndex);
							}
						}
					}
				}
			}

			if(g_bGlobalOffensive)
			{
				#if defined _colors_included
				CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyAdminColorSuccess");
				#else
				PrintToChat(param1, "%t%t", "prefixChatMessage", "chatNotifyAdminColorSuccess");
				#endif
			}
			else
				PrintCenterText(param1, "%t%t", "prefixCenterMessage", "chatNotifyAdminColorSuccess");
			Menu_Admin(param1);
		}
	}
}

Menu_AdminConfirmGimp(client, duration, target)
{
	decl String:sBuffer[128], String:sTemp[36];

	new Handle:hMenu = CreateMenu(MenuHandler_AdminConfirmGimp);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	if(duration == -1)
		Format(sBuffer, sizeof(sBuffer), "%T", "Menu_Admin_Confirm_UnGimp_Single", client, g_sName[GetClientOfUserId(target)]);
	else
		Format(sBuffer, sizeof(sBuffer), "%T", "Menu_Admin_Confirm_Gimp_Single", client, g_sName[GetClientOfUserId(target)], g_iCfg_GimpDurations[duration]);
	AddMenuItem(hMenu, "", sBuffer, ITEMDRAW_DISABLED);

	Format(sBuffer, sizeof(sBuffer), "%T", "Menu_Admin_Confirm_Gimp_No", client);
	Format(sTemp, 36, "0 %d %d", duration, target);
	AddMenuItem(hMenu, sTemp, sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%T", "Menu_Admin_Confirm_Gimp_Yes", client);
	Format(sTemp, 36, "1 %d %d",  duration, target);
	AddMenuItem(hMenu, sTemp, sBuffer);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminConfirmGimp(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Admin(param1);
			}
		}
		case MenuAction_Select:
		{
			decl String:sOption[192], String:sBuffer[3][12];
			GetMenuItem(menu, param2, sOption, sizeof(sOption));
			ExplodeString(sOption, " ", sBuffer, 3, 12);

			if(StringToInt(sBuffer[0]))
			{
				new iTarget = GetClientOfUserId(StringToInt(sBuffer[2]));
				if(iTarget <= 0 || !IsClientInGame(iTarget))
				{
					#if defined _colors_included
					CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
					#else
					PrintToChat(param1, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
					#endif
				}
				else
				{
					if(StringToInt(sBuffer[1]) == -1)
					{
						if(g_hTimer_ExpireGimp[iTarget] != INVALID_HANDLE && CloseHandle(g_hTimer_ExpireGimp[iTarget]))
							g_hTimer_ExpireGimp[iTarget] = INVALID_HANDLE;

						if(g_iPlayerGimp[iTarget])
						{
							g_iPlayerGimp[iTarget] = 0;
							SetClientCookie(iTarget, g_cCookieGimp, "0");

							Format(sOption, 192, "%T", "chatCommandNotifyAdminDeGimpActivity", LANG_SERVER, iTarget);
							ShowActivity2(param1, "[SM] ", sOption);

							Format(sOption, 192, "%T", "chatCommandLogDeGimpActivity", LANG_SERVER, param1, iTarget);
							LogAction(param1, iTarget, sOption);

							#if defined _colors_included
							CPrintToChat(iTarget, "%t%t", "prefixChatMessage", "chatCommandNotifyUserDeGimp");
							#else
							PrintToChat(iTarget, "%t%t", "prefixChatMessage", "chatCommandNotifyUserDeGimp");
							#endif
						}
						else
						{
							#if defined _colors_included
							CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminDeGimpWarning", iTarget);
							#else
							PrintToChat(param1, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminDeGimpWarning", iTarget);
							#endif
						}
					}
					else
					{
						new iMinutes = g_iCfg_GimpDurations[StringToInt(sBuffer[1])];
						if(g_hTimer_ExpireGimp[iTarget] != INVALID_HANDLE && CloseHandle(g_hTimer_ExpireGimp[iTarget]))
							g_hTimer_ExpireGimp[iTarget] = INVALID_HANDLE;

						new iEnding;
						GetMapTimeLeft(iEnding);
						iEnding += g_iCurrentTime;
						g_iPlayerGimp[iTarget] = (iMinutes * 60) + g_iCurrentTime;
						IntToString(g_iPlayerGimp[iTarget], sOption, 64);
						SetClientCookie(iTarget, g_cCookieGimp, sOption);

						Format(sOption, 192, "%T", "chatCommandNotifyAdminGimpActivity", LANG_SERVER, iTarget, iMinutes);
						ShowActivity2(param1, "[SM] ", sOption);

						Format(sOption, 192, "%T", "chatCommandLogGimpActivity", LANG_SERVER, param1, iTarget, iMinutes);
						LogAction(param1, iTarget, sOption);

						#if defined _colors_included
						CPrintToChat(iTarget, "%t%t", "prefixChatMessage", "chatCommandNotifyUserGimp", iMinutes);
						CPrintToChat(iTarget, "%t%t", "prefixChatMessage", "chatCommandNotifyUserGimp2");
						#else
						PrintToChat(iTarget, "%t%t", "prefixChatMessage", "chatCommandNotifyUserGimp", iMinutes);
						PrintToChat(iTarget, "%t%t", "prefixChatMessage", "chatCommandNotifyUserGimp2");
						#endif

						if(iEnding > g_iPlayerGimp[iTarget])
							g_hTimer_ExpireGimp[iTarget] = CreateTimer(float(iEnding - g_iPlayerGimp[iTarget]), Timer_GimpExpire, iTarget, TIMER_FLAG_NO_MAPCHANGE);

						CancelClientMenu(iTarget, true);
						Menu_Main(iTarget);
					}
				}
			}

			Menu_Admin(param1);
		}
	}
}

Menu_AdminSelectDuration(client, target)
{
	decl String:sTemp[36], String:sBuffer[128];
	new Handle:hMenu = CreateMenu(MenuHandler_AdminSelectDuration);
	SetMenuTitle(hMenu, g_sTitle);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	if(g_iPlayerGimp[GetClientOfUserId(target)])
	{
		Format(sTemp, sizeof(sTemp), "-1 %d", target);
		Format(sBuffer, sizeof(sBuffer), "%T", "menuAdminRemoveGimp", client);
		AddMenuItem(hMenu, sTemp, sBuffer);
	}

	for(new i = 0; i < g_iCfg_TotalDurations; i++)
	{
		Format(sTemp, sizeof(sTemp), "%d %d", i, target);
		AddMenuItem(hMenu, sTemp, g_Cfg_sGimpDisplays[i]);
	}

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminSelectDuration(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			switch(param2)
			{
				case MenuCancel_Exit:
					Menu_Main(param1);
				case MenuCancel_NoDisplay, MenuCancel_Timeout, MenuCancel_ExitBack:
					Menu_Admin(param1);
			}
		}
		case MenuAction_Select:
		{
			decl String:sOption[36], String:sBuffer[2][12];
			GetMenuItem(menu, param2, sOption, 36);
			ExplodeString(sOption, " ", sBuffer, 2, 12);

			new iTarget = GetClientOfUserId(StringToInt(sBuffer[1]));
			if(iTarget <= 0 || !IsClientInGame(iTarget))
			{
				#if defined _colors_included
				CPrintToChat(param1, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
				#else
				PrintToChat(param1, "%t%t", "prefixChatMessage", "chatCommandNotifyAdminTargetLocate");
				#endif
			}
			else
				Menu_AdminConfirmGimp(param1, StringToInt(sBuffer[0]), StringToInt(sBuffer[1]));
		}
	}
}

//*****************************************************************************************
//* |||  | Admin Menu Functions
//*****************************************************************************************

//*****************************************************************************************
//* |||  | Convar Changes
//*****************************************************************************************
public OnSettingsChange(Handle:cvar, const String:oldvalue[], const String:newvalue[])
{
	if(cvar == g_hCvar[cPluginEnabled])
	{
		g_bEnabled = bool:StringToInt(newvalue);
		if(g_bEnabled)
		{
			if(!StringToInt(oldvalue))
			{
				AddCustomTag();
				Define_Settings();
				Define_Configs();
				Define_Props();
				Define_Colors();
				Define_Modes();
			}
		}
		else
		{
			if(StringToInt(oldvalue))
			{
				RemCustomTag();
			}
		}
	}
	else if(cvar == g_hCvar[cPluginDebug])
		g_iDebugMode = StringToInt(newvalue);
	else if(cvar == g_hCvar[cNotifyFrequency])
		g_iNotifyFrequency = StringToInt(newvalue);
	else if(cvar == g_hCvar[cDissolveProps])
	{
		g_bDissolve = StringToInt(newvalue) >= 0 ? true : false;
		Format(g_sDissolve, 8, "%s", newvalue);
	}
	else if(cvar == g_hCvar[cHelpUrl])
		Format(g_sHelp, 128, "%s", newvalue);
	else if(cvar == g_hCvar[cNotifyPhaseChange])
		g_iNotifyPhaseChange = StringToInt(newvalue);
	else if(cvar == g_hCvar[cNotifyPhaseEndSounds])
	{
		g_iNotifyPhaseSoundsEnd = ExplodeString(newvalue, ", ", g_sNotifyPhaseSoundsEnd, sizeof(g_sNotifyPhaseSoundsEnd), sizeof(g_sNotifyPhaseSoundsEnd[]));
		for(new i = 0; i < g_iNotifyPhaseSoundsEnd; i++)
			PrecacheSound(g_sNotifyPhaseSoundsEnd[i]);
	}
	else if(cvar == g_hCvar[cNotifyPhaseStartSounds])
	{
		g_iNotifyPhaseSoundsBegin = ExplodeString(newvalue, ", ", g_sNotifyPhaseSoundsBegin, sizeof(g_sNotifyPhaseSoundsBegin), sizeof(g_sNotifyPhaseSoundsBegin[]));
		for(new i = 0; i < g_iNotifyPhaseSoundsBegin; i++)
			PrecacheSound(g_sNotifyPhaseSoundsBegin[i]);
	}
	else if(cvar == g_hCvar[cMaximumEntities])
		g_iMaximumEntities = StringToInt(newvalue);
	else if(cvar == g_hCvar[cPropProximityFlagDelay])
		g_fProximityDelay = StringToFloat(newvalue);
	else if(cvar == g_hCvar[cPropPhaseFlagDelay])
		g_fPhaseDelay = StringToFloat(newvalue);
	else if(cvar == g_hCvar[cDisableRadio])
		g_iDisableRadio = StringToInt(newvalue);
	else if(cvar == g_hCvar[cDisableSuicide])
		g_iDisableSuicide = StringToInt(newvalue);
	else if(cvar == g_hCvar[cDisableFalling])
		g_iDisableFalling = StringToInt(newvalue);
	else if(cvar == g_hCvar[cDisableDrowning])
		g_iDisableDrowning = StringToInt(newvalue);
	else if(cvar == g_hCvar[cDisableBreaking])
		g_iDisableBreaking = StringToInt(newvalue);
	else if(cvar == g_hCvar[cDisableSlowing])
		g_iDisableSlowing = StringToInt(newvalue);
	else if(cvar == g_hCvar[cDisableCrouching])
		g_iDisableCrouching = StringToInt(newvalue);
	else if(cvar == g_hCvar[cDisableRadar])
		g_iDisableRadar = StringToInt(newvalue);
	else if(cvar == g_hCvar[cDisableThird])
		g_iDisableThirdPerson = StringToInt(newvalue);
	else if(cvar == g_hCvar[cDisableFlying])
		g_iDisableFlying = StringToInt(newvalue);
	else if(cvar == g_hCvar[cDurationLegacy])
		g_iLegacyDuration = StringToInt(newvalue);
	else if(cvar == g_hCvar[cDurationBuild])
		g_iBuildDuration = StringToInt(newvalue);
	else if(cvar == g_hCvar[cDurationWar])
		g_iWarDuration = StringToInt(newvalue);
	else if(cvar == g_hCvar[cEnableSudden])
		g_bSuddenDeath = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[cDisableLegacy])
	{
		g_iLegacyDisable = StringToInt(newvalue);
		if(g_iPhase == PHASE_LEGACY)
			g_iCurrentDisable = g_iLegacyDisable;
	}
	else if(cvar == g_hCvar[cDisableBuild])
	{
		g_iBuildDisable = StringToInt(newvalue);
		if(g_iPhase == PHASE_BUILD)
			g_iCurrentDisable = g_iBuildDisable;
	}
	else if(cvar == g_hCvar[cDisableWar])
	{
		g_iWarDisable = StringToInt(newvalue);
		if(g_iPhase == PHASE_WAR)
			g_iCurrentDisable = g_iWarDisable;
	}
	else if(cvar == g_hCvar[cDisableSudden])
	{
		g_iSuddenDisable = StringToInt(newvalue);
		if(g_iPhase == PHASE_SUDDEN)
			g_iCurrentDisable = g_iSuddenDisable;
	}
	else if(cvar == g_hCvar[cPhaseStuckBeacon])
		g_iStuckBeacon = StringToInt(newvalue);
	else if(cvar == g_hCvar[cPhasePropDeleteDelay])
		g_iDeleteNotify = StringToInt(newvalue);
	else if(cvar == g_hCvar[cPropDeleteDelay])
		g_fDeleteDelay = StringToFloat(newvalue);
	else if(cvar == g_hCvar[cPropColoringTerrorist])
	{
		decl String:_sColors1[4][4];
		ExplodeString(newvalue, " ", _sColors1, 4, 4);
		for(new i = 0; i <= 3; i++)
			g_iPropColoringTerrorist[i] = StringToInt(_sColors1[i]);
	}
	else if(cvar == g_hCvar[cPropColoringCounter])
	{
		decl String:_sColors2[4][4];
		ExplodeString(newvalue, " ", _sColors2, 4, 4);
		for(new i = 0; i <= 3; i++)
			g_iPropColoringCounter[i] = StringToInt(_sColors2[i]);
	}
	else if(cvar == g_hCvar[cPropColoringSpec])
	{
		decl String:_sColors3[4][4];
		ExplodeString(newvalue, " ", _sColors3, 4, 4);
		for(new i = 0; i <= 3; i++)
			g_iPropColoringSpec[i] = StringToInt(_sColors3[i]);
	}
	else if(cvar == g_hCvar[cCanRedAccess])
		g_bRedAccess = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[cCanBlueAccess])
		g_bBlueAccess = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[cControlDistance])
		g_fGrabDistance = StringToFloat(newvalue);
	else if(cvar == g_hCvar[cControlNonSolid])
		g_bGrabBlock = StringToFloat(newvalue) ? true : false;
	else if(cvar == g_hCvar[cControlRefreshRate])
		g_fGrabUpdate = StringToFloat(newvalue);
	else if(cvar == g_hCvar[cControlMinDistance])
		g_fGrabMinimum = StringToFloat(newvalue);
	else if(cvar == g_hCvar[cControlMaxDistance])
		g_fGrabMaximum = StringToFloat(newvalue);
	else if(cvar == g_hCvar[cControlChangeInterval])
		g_fGrabInterval = StringToFloat(newvalue);
	else if(cvar == g_hCvar[cIgnoreWinConditions])
		g_bSpawningIgnore = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[cPhaseReadyAllow])
		g_iReadyPhase = StringToInt(newvalue);
	else if(cvar == g_hCvar[cReadyBuildPercent])
		g_fReadyPercent = StringToFloat(newvalue);
	else if(cvar == g_hCvar[cReadyWarPercent])
		g_fReadyAlive = StringToFloat(newvalue);
	else if(cvar == g_hCvar[cReadyChangeDelay])
		g_iReadyDelay = StringToInt(newvalue);
	else if(cvar == g_hCvar[cReadyWaitDelay])
		g_iReadyWait = StringToInt(newvalue);
	else if(cvar == g_hCvar[cReadyMinimumPlayers])
		g_iReadyMinimum = StringToInt(newvalue);
	else if(cvar == g_hCvar[cMaintainTeamSizes])
		g_bMaintainSize = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[cMaintainTeamSpawns])
		g_bMaintainSpawns = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[cPersistentProps])
		g_bPersistentRounds = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[cPersistentPropColors])
	{
		g_bPersistentColors = StrEqual(newvalue, "") ? false : true;
		if(g_bPersistentColors)
		{
			decl String:_sColors4[4][4];
			ExplodeString(newvalue, " ", _sColors4, 4, 4);
			for(new i = 0; i <= 3; i++)
				g_iPersistentColors[i] = StringToInt(_sColors4[i]);
		}
	}
	else if(cvar == g_hCvar[cScrambleRounds])
		g_iScrambleRounds = StringToInt(newvalue);
	else if(cvar == g_hCvar[cEnableAntiAway])
		g_bAfkEnable = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[cAntiAwayDelay])
		g_fAfkDelay = StringToFloat(newvalue);
	else if(cvar == g_hCvar[cAntiAwayKick])
		g_bAfkAutoKick = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[cAntiAwayKickDelay])
		g_fAfkAutoDelay = StringToFloat(newvalue);
	else if(cvar == g_hCvar[cAntiAwayReturn])
		g_bAfkReturn = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[cAntiAwaySpec])
		g_bAfkSpecKick = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[cAntiAwaySpecDelay])
		g_fAfkSpecKickDelay = StringToFloat(newvalue);
	else if(cvar == g_hCvar[cAntiAwayForce])
		g_bAfkAutoSpec = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[cAntiAwayForceDelay])
		g_fAfkForceSpecDelay = StringToFloat(newvalue);
	else if(cvar == g_hCvar[cEnableAnywhereBuyzone])
		g_iAlwaysBuyzone = StringToInt(newvalue);
	else if(cvar == g_hCvar[cForceMenusClose])
		g_bCloseMenus = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[cPluginDatabase])
	{
		if(g_hSql_Database != INVALID_HANDLE && CloseHandle(g_hSql_Database))
			g_hSql_Database = INVALID_HANDLE;

		Format(g_sDatabase, sizeof(g_sDatabase), "%s", newvalue);
		SQL_TConnect(SQL_Connect_Database, (StrEqual(g_sDatabase, "") || !SQL_CheckConfig(g_sDatabase)) ? "storage-local" : g_sDatabase);
	}
	else if(cvar == g_hCvar[cBaseDistance])
		g_fBaseDistance = StringToFloat(newvalue);
	else if(cvar == g_hCvar[cBaseDefaultNames])
		ExplodeString(newvalue, ", ", g_sBaseNames, 7, 32);
	else if(cvar == g_hLimitTeams)
		g_iLimitTeams = StringToInt(newvalue);
	else if(cvar == g_hRoundRestart)
		g_fRoundRestart = StringToFloat(newvalue);
	else if(cvar == g_hCvar[cBaseDefaultColor])
	{
		g_bBaseColors = StrEqual(newvalue, "") ? false : true;
		if(g_bBaseColors)
		{
			decl String:_sColors5[4][4];
			ExplodeString(newvalue, " ", _sColors5, 4, 4);
			for(new i = 0; i <= 3; i++)
				g_iBaseColors[i] = StringToInt(_sColors5[i]);
		}
	}
	else if(cvar == g_hCvar[cDefaultGimpDuration])
		g_iGimpDefault = StringToInt(newvalue);
	else if(cvar == g_hCvar[cModifyFallDamage])
		g_fFallDamage = StringToFloat(newvalue);
	else if(cvar == g_hCvar[cNotifyNewPlayers])
		g_bNotifyNewbies = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[cModifyCrouchSpeed])
		g_bCrouchSpeed = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[cEnableZoneControl])
	{
		g_bZoneControl = bool:StringToInt(newvalue);
		if(g_bDatabaseFound && g_hSql_Database != INVALID_HANDLE && g_bZoneControl)
			Define_Zones();
	}
	else if(cvar == g_hCvar[cEnableAdvancingTeam])
		g_bAdvancingTeam = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[cDisableConsoleChat])
		g_bDisableConsoleChat = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[cConvarBounds])
	{
		if(StrEqual(newvalue, oldvalue))
			return;

		new String:sBoundsExplode[32][128], Float:fBuffer;
		new iCount = ExplodeString(newvalue, ",", sBoundsExplode, sizeof(sBoundsExplode), sizeof(sBoundsExplode[]));

		for(new i = 0; i < iCount; i++)
		{
			new Handle:hConvar = FindConVar(sBoundsExplode[i]);
			if(hConvar != INVALID_HANDLE)
			{
				if(GetConVarBounds(hConvar, ConVarBound_Lower, fBuffer))
					SetConVarBounds(hConvar, ConVarBound_Lower, false);

				if(GetConVarBounds(hConvar, ConVarBound_Upper, fBuffer))
					SetConVarBounds(hConvar, ConVarBound_Upper, false);

				CloseHandle(hConvar);
			}
		}
	}
}

//*****************************************************************************************
//* |||  | Stocks
//*****************************************************************************************
ClearClientAccess(client)
{
	g_Access[client][iAccess] = 0;

	g_Access[client][bAdmin] = false;

	g_Access[client][bAfkImmunity] = false;
	g_Access[client][bAccessMove] = false;
	g_Access[client][bAccessRotate] = false;
	g_Access[client][bAccessCheck] = false;
	g_Access[client][bAccessControl] = false;
	g_Access[client][bAccessCrouch] = false;
	g_Access[client][bAccessRadar] = false;
	g_Access[client][bAccessCustom] = false;
	g_Access[client][bAccessSpec] = false;
	g_Access[client][bAccessProp] = false;
	g_Access[client][bAccessDelete] = false;
	g_Access[client][bAccessClear] = false;
	g_Access[client][bAccessThird] = false;
	g_Access[client][bAccessFly] = false;
	g_Access[client][bAccessPhase] = false;
	g_Access[client][bAccessTeleport] = false;
	g_Access[client][bAccessBase] = false;
	g_Access[client][bAccessSettings] = false;
	g_Access[client][bAccessAdminMenu] = false;
	g_Access[client][bAccessAdminGimp] = false;
	g_Access[client][bAccessAdminDelete] = false;
	g_Access[client][bAccessAdminClear] = false;
	g_Access[client][bAccessAdminStuck] = false;
	g_Access[client][bAccessAdminColor] = false;
	g_Access[client][bAccessAdminBase] = false;
	g_Access[client][bAccessAdminTarget] = false;
	g_Access[client][bAccessAdminZone] = false;
	g_Access[client][bAccessColor] = false;
	g_Access[client][bAccessExplosives] = false;

	g_Access[client][iTotalProps] = -1;
	g_Access[client][iTotalPropsAdvance] = -1;
	g_Access[client][iTotalDeletes] = -1;
	g_Access[client][iTotalTeleports] = -1;
	g_Access[client][iTotalColors] = -1;
	g_Access[client][iTotalBases] = -1;
	g_Access[client][iTotalBaseProps] = -1;

	g_Access[client][fStuckDelay] = -1.0;
}

LoadClientAccess(client)
{
	for(new i = 0; i < g_iCfg_TotalAccess; i++)
	{
		if(StrEqual(g_sAccessOverrides[i], "") || CheckCommandAccess(client, g_sAccessOverrides[i], g_iAccessFlags[i]))
		{
			g_Access[client][iAccess] += g_iAccessIdens[i];

			if(!g_Access[client][bAdmin])
				g_Access[client][bAdmin] = g_bAccessAdmin[i];

			if(!g_Access[client][bAfkImmunity])
				g_Access[client][bAfkImmunity] = g_bAccessImmunity[i];

			if(!g_Access[client][bAccessMove])
				g_Access[client][bAccessMove] = g_bAccessMove[i];

			if(!g_Access[client][bAccessRotate])
				g_Access[client][bAccessRotate] = g_bAccessRotate[i];

			if(!g_Access[client][bAccessCheck])
				g_Access[client][bAccessCheck] = g_bAccessCheck[i];

			if(!g_Access[client][bAccessControl])
				g_Access[client][bAccessControl] = g_bAccessControl[i];

			if(!g_Access[client][bAccessCrouch])
				g_Access[client][bAccessCrouch] = g_bAccessCrouch[i];

			if(!g_Access[client][bAccessRadar])
				g_Access[client][bAccessRadar] = g_bAccessRadar[i];

			if(!g_Access[client][bAccessCustom])
				g_Access[client][bAccessCustom] = g_bAccessCustom[i];

			if(!g_Access[client][bAccessSpec])
				g_Access[client][bAccessSpec] = g_bAccessSpec[i];

			if(!g_Access[client][bAccessProp])
				g_Access[client][bAccessProp] = g_bAccessProp[i];

			if(!g_Access[client][bAccessDelete])
				g_Access[client][bAccessDelete] = g_bAccessDelete[i];

			if(!g_Access[client][bAccessClear])
				g_Access[client][bAccessClear] = g_bAccessClear[i];

			if(!g_Access[client][bAccessThird])
				g_Access[client][bAccessThird] = g_bAccessThird[i];

			if(!g_Access[client][bAccessFly])
				g_Access[client][bAccessFly] = g_bAccessFly[i];

			if(!g_Access[client][bAccessPhase])
				g_Access[client][bAccessPhase] = g_bAccessPhase[i];

			if(!g_Access[client][bAccessTeleport])
				g_Access[client][bAccessTeleport] = g_bAccessTeleport[i];

			if(!g_Access[client][bAccessColor])
				g_Access[client][bAccessColor] = g_bAccessColor[i];

			if(!g_Access[client][bAccessBase])
				g_Access[client][bAccessBase] = g_bAccessBase[i];

			if(!g_Access[client][bAccessSettings])
				g_Access[client][bAccessSettings] = g_bAccessSettings[i];

			if(!g_Access[client][bAccessAdminMenu])
				g_Access[client][bAccessAdminMenu] = g_bAccessAdminMenu[i];

			if(!g_Access[client][bAccessAdminGimp])
				g_Access[client][bAccessAdminGimp] = g_bAccessAdminGimp[i];

			if(!g_Access[client][bAccessAdminDelete])
				g_Access[client][bAccessAdminDelete] = g_bAccessAdminDelete[i];

			if(!g_Access[client][bAccessAdminClear])
				g_Access[client][bAccessAdminClear] = g_bAccessAdminClear[i];

			if(!g_Access[client][bAccessAdminStuck])
				g_Access[client][bAccessAdminStuck] = g_bAccessAdminStuck[i];

			if(!g_Access[client][bAccessAdminColor])
				g_Access[client][bAccessAdminColor] = g_bAccessAdminColor[i];

			if(!g_Access[client][bAccessAdminBase])
				g_Access[client][bAccessAdminBase] = g_bAccessAdminBase[i];

			if(!g_Access[client][bAccessAdminTarget])
				g_Access[client][bAccessAdminTarget] = g_bAccessAdminTarget[i];

			if(!g_Access[client][bAccessAdminZone])
				g_Access[client][bAccessAdminZone] = g_bAccessAdminZone[i];

			if(!g_Access[client][bAccessExplosives])
				g_Access[client][bAccessExplosives] = g_bAccessExplosives[i];

			if(g_Access[client][iTotalProps] < 0 || g_Access[client][iTotalProps] > 0 && g_Access[client][iTotalProps] < g_iAccessTotalProps[i])
				g_Access[client][iTotalProps] = g_iAccessTotalProps[i];

			if(g_Access[client][iTotalPropsAdvance] < 0 || g_Access[client][iTotalPropsAdvance] > 0 && g_Access[client][iTotalPropsAdvance] < g_iAccessTotalAdvanceProps[i])
				g_Access[client][iTotalPropsAdvance] = g_iAccessTotalAdvanceProps[i];

			if(g_Access[client][iTotalDeletes] < 0 || g_Access[client][iTotalDeletes] > 0 && g_Access[client][iTotalDeletes] < g_iAccessTotalDeletes[i])
				g_Access[client][iTotalDeletes] = g_iAccessTotalDeletes[i];

			if(g_Access[client][iTotalTeleports] < 0 || g_Access[client][iTotalTeleports] > 0 && g_Access[client][iTotalTeleports] < g_iAccessTotalTeleports[i])
				g_Access[client][iTotalTeleports] = g_iAccessTotalTeleports[i];

			if(g_Access[client][iTotalColors] < 0 || g_Access[client][iTotalColors] > 0 && g_Access[client][iTotalColors] < g_iAccessTotalColors[i])
				g_Access[client][iTotalColors] = g_iAccessTotalColors[i];

			if(g_Access[client][iTotalBases] < 0 || g_Access[client][iTotalBases] > 0 && g_Access[client][iTotalBases] < g_iAccessTotalBases[i])
				g_Access[client][iTotalBases] = g_iAccessTotalBases[i];

			if(g_Access[client][iTotalBaseProps] < 0 || g_Access[client][iTotalBaseProps] > 0 && g_Access[client][iTotalBaseProps] < g_iAccessTotalBaseProps[i])
				g_Access[client][iTotalBaseProps] = g_iAccessTotalBaseProps[i];

			if(g_Access[client][fStuckDelay] < 0.0 || g_Access[client][fStuckDelay] > 0.0 && g_Access[client][fStuckDelay] < g_fAccessStuckDelay[i])
				g_Access[client][fStuckDelay] = g_fAccessStuckDelay[i];
		}
	}
}

stock ErrorCheck(Handle:owner, const String:error[], const String:callback[] = "")
{
	if(owner == INVALID_HANDLE)
		SetFailState("[SM] FATAL SQL ERROR - %s, %s", callback, error);
	else if(g_iDebugMode == MODE_DEBUG && !StrEqual(error, ""))
		LogToFile(g_sPluginLog, "ErrorCheck: %s", error);
}

stock StringToLower(String:f_sInput[])
{
	new f_iSize = strlen(f_sInput);
	for(new i=0;i<f_iSize;i++)
	{
		f_sInput[i] = CharToLower(f_sInput[i]);
	}
}

stock Array_Copy(const any:array[], any:newArray[], size)
{
	for (new i=0; i < size; i++) {
		newArray[i] = array[i];
	}
}

bool:Bool_CheckProximity(Float:fOrigin[3], Float:_fLocation[3], Float:_fLimit, bool:_bWithin)
{
	if(_fLimit <= 0)
		return false;
	else
	{
		if(_bWithin)
		{
			if(GetVectorDistance(fOrigin, _fLocation) <= _fLimit)
				return true;
			else
				return false;
		}
		else
		{
			if(GetVectorDistance(fOrigin, _fLocation) > _fLimit)
				return true;
			else
				return false;
		}
	}
}

stock GetOppositeTeam(team)
{
	switch(team)
	{
		case CS_TEAM_T:
			return CS_TEAM_CT;
		case CS_TEAM_CT:
			return CS_TEAM_T;
	}

	return CS_TEAM_NONE;
}