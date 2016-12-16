#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <adminmenu>
#include <clientprefs>
#include <colors>
	
/*
	- Ability to restrict building in areas of a map based on x/y/z location and radius
	- Finish the Manage feature
	- Ready support for the War phase
	- cvar to stop automatic menu closing and message at start of war

	Revisions: v3.1.3
	--------------------
	BUG FIXES:
		- Added support to prevent a very rare and harmless memory leak from occuring if sm_buildwars_display is enabled.
		- Removed a leftover bit of code that prompted users to use their knife to spawn props.
		- Fixed an issue which caused restricted weapons not to be automatically unrestricted in Sudden Death.
	CHANGES:
	TRANSLATIONS
		REMOVED:
			- Spawn_Prop_Controls
*/

/*
	Overrides:
	- bw_access_admin - required to access the "admin" benefits provided by Build Wars. ("Default: 'e')
	- bw_access_supporter - required to access the "supporter" benefits provided of Build Wars. ("Default: 'r')

	Restrictions:
	- bw_admin_delete - Allows the user to delete props belonging to other individuals. ("Default: 'b')
	- bw_admin_teleport - Allows the user to teleport other individuals. ("Default: 'b')
	- bw_admin_color - Allows the user to color props belonging to other individuals. ("Default: 'b')
	- bw_admin_target - Allows the user to target @t/@ct/@all with delete/teleport/color. ("Default: 'e')
	- bw_admin_manage - Allows the user access to the cvar management portion of the admin menu. ("Default: 'z')
*/

/*
	Finish the "Manage" system for cvars (bw_admin_manage override) - allows admins with access to modify any cvar related to BuildWars via a menu.
	Add support for "sm_home", which allows players to set their spawning location, with restrictions to either public/vip/admin/combination
	Add support for "Menu" spawning, where players will not automatically respawn and instead will pick their respawn location after their duration is up.
		- Provides players a menu upon their death of where to respawn
		- Obeys other spawning modes, just removes automatic respawning.
			- Own Home 
			- Spawn
			- Player X's Home
			- With Player X
	Add support for "Spies" or players who change teams after x seconds after the start of a new round. Spies will always appear on the radar of the opposing team.
	Ready support for the Sudden Death phase (during war, end war sooner)
	Admin command to force the current phase to end and the next phase to start - sm_forcephase
*/

#define PLUGIN_VERSION "3.1.3"

//Hardcoded limit to the number of props available in the configuration file (saves memory, increase to allow more).
#define MAX_CONFIG_PROPS 128

//Hardcoded limit to the number of colors available in the configuration file (saves memory, increase to allow more).
#define MAX_CONFIG_COLORS 64

//Hardcoded limit to the number of degrees available in the configuration file (saves memory, increase to allow more).
#define MAX_CONFIG_ROTATIONS 16

//Hardcoded limit to the number of positions available in the configuration file (saves memory, increase to allow more).
#define MAX_CONFIG_POSITIONS 16

//Hardcoded limit to the number of commands available in the configuration file (saves memory, increase to allow more).
#define MAX_CONFIG_COMMANDS 32

//Hardcoded limit to the number of maps allowed in sm_buildwars_maps.ini  (saves memory, increase to allow more).
#define MAX_CONFIG_MAPS 128

//Hardcoded limit to the number of modes allowed in sm_buildwars_modes.ini (saves memory, increase to allow more).
#define MAX_CONFIG_MODES 64

//Hardcoded limit to the number of operations allowed in sm_buildwars_modes.ini (saves memory, increase to allow more).
#define MAX_CONFIG_OPERATIONS 24

//Hardcoded limit to the number of spawn points available for maps in build wars  (saves memory, increase to allow more).
#define MAX_SPAWN_POINTS 32

//Hardcoded limit to the number of teleport destinations available for maps in build wars (saves memory, increase to allow more).
#define MAX_TELEPORT_ENDS 64

//Hardcoded limit of sounds available to signify the ending of a phase (saves memory, increase to allow more).
#define MAX_PHASE_SOUNDS 16

//The maximum amount of entities the 2009 Source Engine will support, used for global entity arrays.
#define MaxEntities 2048

//Cvars
#define CVAR_COUNT 100
#define CVAR_ENABLED 0
#define CVAR_DISPLAY 1
#define CVAR_DISSOLVE 2
#define CVAR_HELP 3
#define CVAR_ADVERT 4
#define CVAR_SOUNDS 5
#define CVAR_MAX_ENTITIES 6
#define CVAR_DISABLE_RADIO 7
#define CVAR_DISABLE_SUICIDE 8
#define CVAR_DISABLE_FALLING 9
#define CVAR_DISABLE_DROWNING 10
#define CVAR_DISABLE_CROUCHING 11
#define CVAR_DISABLE_RADAR 12
#define CVAR_DURATION_BUILD 13
#define CVAR_DURATION_WAR 14
#define CVAR_SUDDEN_DEATH 15
#define CVAR_LIMIT_WAR 16
#define CVAR_LIMIT_SUDDEN 17
#define CVAR_DEFAULT_COLOR 18
#define CVAR_DEFAULT_ROTATION 19
#define CVAR_DEFAULT_POSITION 20
#define CVAR_DEFAULT_CONTROL 21
#define CVAR_DEFAULT_DEGREE 22
#define CVAR_DEFAULT_MOVE 23
#define CVAR_DEFAULT_QUICK 24
#define CVAR_PUBLIC_PROPS 25
#define CVAR_SUPPORTER_PROPS 26
#define CVAR_ADMIN_PROPS 27
#define CVAR_DISPLAY_INDEX 28
#define CVAR_PUBLIC_DELETES 29
#define CVAR_SUPPORTER_DELETES 30
#define CVAR_ADMIN_DELETES 31
#define CVAR_PUBLIC_TELES 32
#define CVAR_SUPPORTER_TELES 33
#define CVAR_ADMIN_TELES 34
#define CVAR_PUBLIC_DELAY 35
#define CVAR_SUPPORTER_DELAY 36
#define CVAR_ADMIN_DELAY 37
#define CVAR_PUBLIC_COLORING 38
#define CVAR_SUPPORTER_COLORING 39
#define CVAR_ADMIN_COLORING 40
#define CVAR_PUBLIC_COLOR 41
#define CVAR_SUPPORTER_COLOR 42
#define CVAR_ADMIN_COLOR 43
#define CVAR_COLOR_RED 44
#define CVAR_COLOR_BLUE 45
#define CVAR_ACCESS_SPEC 46
#define CVAR_ACCESS_RED 47
#define CVAR_ACCESS_BLUE 48
#define CVAR_ACCESS_CHECK 49
#define CVAR_ACCESS_GRAB 50
#define CVAR_ACCESS_SETTINGS 51
#define CVAR_ACCESS_MANAGE 52
#define CVAR_ACCESS_CROUCH 53
#define CVAR_ACCESS_RADAR 54
#define CVAR_ACCESS_QUICK 55
#define CVAR_GRAB_SOLID 56
#define CVAR_GRAB_DISTANCE 57
#define CVAR_GRAB_REFRESH 58
#define CVAR_GRAB_MINIMUM 59
#define CVAR_GRAB_MAXIMUM 60
#define CVAR_GRAB_INTERVAL 61
#define CVAR_SPAWNING_MODE 62
#define CVAR_SPAWNING_BUILD 63
#define CVAR_SPAWNING_DELAY 64
#define CVAR_SPAWNING_FACTOR 65
#define CVAR_SPAWNING_IGNORE 66
#define CVAR_SPAWNS_APPEAR 67
#define CVAR_SPAWNS_REFRESH 68
#define CVAR_SPAWNS_RED 69
#define CVAR_SPAWNS_BLUE 70
#define CVAR_PROXIMITY_SPAWNS 71
#define CVAR_PROXIMITY_PLAYERS 72
#define CVAR_READY_ENABLE 73
#define CVAR_READY_PERCENT 74
#define CVAR_READY_DELAY 75
#define CVAR_READY_WAIT 76
#define CVAR_READY_MINIMUM 77
#define CVAR_SCRAMBLE_ROUNDS 78
#define CVAR_MAINTAIN_TEAMS 79
#define CVAR_MAINTAIN_SPAWNS 80
#define CVAR_PERSISTENT_ROUNDS 81
#define CVAR_PERSISTENT_COLORS 82
#define CVAR_PERSISTENT_EFFECT 83
#define CVAR_AFK_ENABLE 84
#define CVAR_AFK_DELAY 85
#define CVAR_AFK_KICK 86
#define CVAR_AFK_KICK_DELAY 87
#define CVAR_AFK_RETURN 88
#define CVAR_AFK_SPEC 89
#define CVAR_AFK_SPEC_DELAY 90
#define CVAR_AFK_FORCE 91
#define CVAR_AFK_FORCE_DELAY 92
#define CVAR_AFK_IMMUNITY 93
#define CVAR_LIMIT_BUILD 94
#define CVAR_LIMIT_NONE 95
#define CVAR_TELE_BEACON 96
#define CVAR_SPAWNING_DURATION 97
#define CVAR_GAME_DESCRIPTION 98
#define CVAR_ALWAYS_BUYZONE 99

//Manage Indexes...
#define TYPE_INT 0
#define TYPE_BOOL 1
#define TYPE_FLOAT 2
#define TYPE_STRING 3

//Teams...
#define TEAM_NONE 0
#define TEAM_SPEC 1
#define TEAM_RED 2
#define TEAM_BLUE 3

//Command Indexes...
#define COMMAND_MENU 0
#define COMMAND_ROTATION 1
#define COMMAND_POSITION 2
#define COMMAND_DELETE 3
#define COMMAND_CONTROL 4
#define COMMAND_CHECK 5
#define COMMAND_TELE 6
#define COMMAND_HELP 7
#define COMMAND_READY 8
#define COMMAND_CLEAR 9

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

//Auth Flags...
#define ACCESS_PUBLIC 1
#define ACCESS_SUPPORTER 2
#define ACCESS_ADMIN 4

//Admin Flags...
#define ADMIN_NONE 0
#define ADMIN_DELETE 1
#define ADMIN_TELEPORT 2
#define ADMIN_COLOR 4
#define ADMIN_TARGET 8
#define ADMIN_MANAGE 16
#define ADMIN_PHASE 32

//Spawn Modes...
#define SPAWNING_DISABLED 0
#define SPAWNING_TEAMS 1
#define SPAWNING_SINGLES 2
#define SPAWNING_TIMED 3

//Round Phases...
#define PHASE_NONE 0
#define PHASE_BUILD 1
#define PHASE_WAR 2
#define PHASE_SUDDEN 4

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

//Quick Access...
#define QUICK_DISABLE 0
#define QUICK_MENU 1
#define QUICK_DELETE 2
#define QUICK_CLONE 3

//Modifcation Axis...
#define ROTATION_AXIS_X 0
#define ROTATION_AXIS_Y 1
#define POSITION_AXIS_X 2
#define POSITION_AXIS_Y 3
#define POSITION_AXIS_Z 4
#define AXIS_TOTAL 5

//Menu Indexes
#define MENU_MAIN 0
#define MENU_CREATE 1
#define MENU_ROTATE 2
#define MENU_MOVE 3
#define MENU_CONTROL 4
#define MENU_COLOR 5
#define MENU_ACTION 6
#define MENU_ADMIN 7

//Auth Defaults
#define AUTH_SUPPORTER ADMFLAG_CUSTOM4
#define AUTH_ADMIN ADMFLAG_UNBAN
#define AUTH_DELETE ADMFLAG_GENERIC
#define AUTH_TELEPORT ADMFLAG_GENERIC
#define AUTH_COLOR ADMFLAG_GENERIC
#define AUTH_TARGET ADMFLAG_UNBAN
#define AUTH_MANAGE ADMFLAG_ROOT

//Restrictions...
#define RESTRICTION_WEAPONS 27
#define RESTRICTION_RED 0
#define RESTRICTION_BLUE 1
#define RESTRICTION_TOTAL 2

//Axis Characters
new String:g_sAxisDisplay[][] = {"X", "Y", "X", "Y", "Z"};

//Phases
new String:g_sPhaseDisplay[][] = { "", "_Build", "_War", "", "_Sudden" };

//Prop Types
new String:g_sPropTypes[][] = { "prop_dynamic", "prop_dynamic_override", "prop_physics_multiplayer", "prop_physics_override" };

new g_iNumProps, g_iNumColors, g_iNumRotations, g_iNumPositions, g_iNumModes, g_iNumMaps;
new String:g_sDefinedPropNames[MAX_CONFIG_PROPS][64];
new String:g_sDefinedPropPaths[MAX_CONFIG_PROPS][256];
new g_iDefinedPropTypes[MAX_CONFIG_PROPS];
new g_iDefinedPropAccess[MAX_CONFIG_PROPS];
new g_iDefinedPropHealth[MAX_CONFIG_PROPS];
new String:g_sDefinedColorNames[MAX_CONFIG_COLORS][64];
new g_iDefinedColorArrays[MAX_CONFIG_COLORS][4];
new Float:g_fDefinedRotations[MAX_CONFIG_ROTATIONS];
new Float:g_fDefinedPositions[MAX_CONFIG_POSITIONS];
new String:g_sDefinedMapIdens[MAX_CONFIG_MAPS][128];
new String:g_sDefinedMapTypes[MAX_CONFIG_MAPS][32];
new bool:g_bDefinedModeChat[MAX_CONFIG_MODES];
new String:g_sDefinedModeChat[MAX_CONFIG_MODES][192];
new bool:g_bDefinedModeCenter[MAX_CONFIG_MODES];
new String:g_sDefinedModeCenter[MAX_CONFIG_MODES][192];
new g_iDefinedModeDuration[MAX_CONFIG_MODES];
new g_iDefinedModeMethod[MAX_CONFIG_MODES];
new String:g_sDefinedModeStart[MAX_CONFIG_MODES][512];
new String:g_sDefinedModeEnd[MAX_CONFIG_MODES][512];

new bool:g_bPropGrab[MaxEntities + 1];
new g_iPropUser[MaxEntities + 1];
new g_iPropType[MaxEntities + 1];
new bool:g_bProp[MaxEntities + 1];
new String:g_sPropOwner[MaxEntities + 1][32];

new g_iRestrictOriginal[RESTRICTION_TOTAL][RESTRICTION_WEAPONS];
new bool:g_bRestrictReturn[RESTRICTION_TOTAL][RESTRICTION_WEAPONS];
new bool:g_bRestrictState[RESTRICTION_TOTAL][RESTRICTION_WEAPONS];
new Handle:g_hRestrictCvar[RESTRICTION_TOTAL][RESTRICTION_WEAPONS] = { { INVALID_HANDLE, ... }, { INVALID_HANDLE, ... } };

//Data for the clients
new g_iTeam[MAXPLAYERS + 1];
new g_iLastTeam[MAXPLAYERS + 1];
new g_iClass[MAXPLAYERS + 1];
new g_iPlayerAccess[MAXPLAYERS + 1];
new g_iAdminAccess[MAXPLAYERS + 1];
new g_iPlayerTeleports[MAXPLAYERS + 1];
new g_iPlayerDeletes[MAXPLAYERS + 1];
new g_iPlayerProps[MAXPLAYERS + 1];
new g_iPlayerColors[MAXPLAYERS + 1];
new g_iPlayerControl[MAXPLAYERS + 1];
new g_iPlayerSpawns[MAXPLAYERS + 1];
new Float:g_fConfigDistance[MAXPLAYERS + 1];
new g_iConfigRotation[MAXPLAYERS + 1];
new g_iConfigPosition[MAXPLAYERS + 1];
new g_iConfigColor[MAXPLAYERS + 1];
new g_iConfigQuick[MAXPLAYERS + 1];
new bool:g_bTeleporting[MAXPLAYERS + 1];
new bool:g_bTeleported[MAXPLAYERS + 1];
new bool:g_bAfk[MAXPLAYERS + 1];
new bool:g_bLoaded[MAXPLAYERS + 1];
new bool:g_bReturning[MAXPLAYERS + 1];
new bool:g_bAlive[MAXPLAYERS + 1];
new bool:g_bReady[MAXPLAYERS + 1];
new bool:g_bResetSpeed[MAXPLAYERS + 1];
new bool:g_bResetGravity[MAXPLAYERS + 1];
new bool:g_bQuickToggle[MAXPLAYERS + 1];
new bool:g_bConfigAxis[MAXPLAYERS + 1][AXIS_TOTAL];
new bool:g_bPlayerSpawned[MAXPLAYERS + 1];
new bool:g_bActivity[MAXPLAYERS + 1];
new Float:g_fAfkRemaining[MAXPLAYERS + 1];
new Float:g_fTeleRemaining[MAXPLAYERS + 1];
new Float:g_fSpawningRemaining[MAXPLAYERS + 1];
new String:g_sSteam[MAXPLAYERS + 1][32];
new String:g_sName[MAXPLAYERS + 1][32];
new Handle:g_hArray_PlayerProps[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };
new Handle:g_hTimer_TeleportPlayer[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };
new Handle:g_hTimer_UpdateControl[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };
new Handle:g_hTimer_RespawnPlayer[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };
new Handle:g_hTimer_AfkCheck[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };

//Configuration / opimization / etc

new Handle:g_hCvar[CVAR_COUNT] = { INVALID_HANDLE, ... };
new Handle:g_hTimer_Update = INVALID_HANDLE;
new Handle:g_hTimer_StopSpawning = INVALID_HANDLE;
new Handle:g_hArray_RedPlayers = INVALID_HANDLE;
new Handle:g_hArray_BluePlayers = INVALID_HANDLE;
new Handle:g_hArray_MapEntities = INVALID_HANDLE;
new Handle:g_hArray_Repository = INVALID_HANDLE;
new Handle:g_hKV_Repository = INVALID_HANDLE;

new Handle:g_cBuildVersion = INVALID_HANDLE;
new Handle:g_cConfigRotation = INVALID_HANDLE;
new Handle:g_cConfigPosition = INVALID_HANDLE;
new Handle:g_cConfigColor = INVALID_HANDLE;
new Handle:g_cConfigLocks = INVALID_HANDLE;
new Handle:g_cConfigDistance = INVALID_HANDLE;
new Handle:g_cConfigQuick = INVALID_HANDLE;

new Handle:g_hTrie_PlayerCommands = INVALID_HANDLE;
new Handle:g_hTrie_ModeWeapons = INVALID_HANDLE;
new Handle:g_hTrie_MapConfigurations = INVALID_HANDLE;
new Handle:g_hTrie_RestrictIndex = INVALID_HANDLE;

new Handle:g_hWeaponRestrict = INVALID_HANDLE;
new Handle:g_hLimitTeams = INVALID_HANDLE;
new Handle:g_hIgnoreRound = INVALID_HANDLE;
new Handle:g_hRoundRestart = INVALID_HANDLE;

new String:g_sRestrictWeapons[RESTRICTION_WEAPONS][16] = {	
	"glock", "usp", "p228", "deagle", "elite", "fiveseven", "m3",
	"xm1014", "galil", "ak47", "scout", "sg552", "awp", "g3sg1",
	"famas", "m4a1", "aug", "sg550", "mac10", "tmp", "mp5navy",
	"ump45", "p90", "m249", "flashbang", "hegrenade", "smokegrenade" };

new bool:g_bGrabBlock, bool:g_bAfkSpecKick, bool:g_bAfkAutoSpec, bool:g_bPersistentRounds, bool:g_bAfkEnable, bool:g_bAfkReturn, bool:g_bAfkAutoKick, bool:g_bMaintainSize, bool:g_bMaintainSpawns,
bool:g_bReadyProceed, bool:g_bReadyEnable, bool:g_bHelp, bool:g_bEnabled, bool:g_bLateLoad, bool:g_bEnding, bool:g_bDissolve, bool:g_bRotationAllowed, bool:g_bPositionAllowed, bool:g_bColorAllowed, bool:g_bControlAllowed,
bool:g_bAccessAdmin, bool:g_bAccessSettings, bool:g_bSpawningBuild, bool:g_bSpawningAllowed, bool:g_bDisplay, bool:g_bSpawningIgnore, bool:g_bHasAccess[4] = { false, false, false, false }, bool:g_bSpawningAppear,
bool:g_bPosSnapAllowed, bool:g_bRotSnapAllowed, bool:g_bInfiniteGrenades, bool:g_bPersistentColors, bool:g_bQuickAllowed, bool:g_bShowIndex, bool:g_bTeleBeacon, bool:g_bGameDescription, bool:g_bNewMap, bool:g_bAlwaysBuyzone,
bool:g_bSuddenDeath, bool:g_bLoadedRestrictions;
new g_iFlashDuration, g_iFlashAlpha, g_iMaxEntities, g_iCurEntities, g_iCurrentRound, g_iLastScramble, g_iLimitTeams, g_iScrambleRounds, g_iReadyMinimum, g_iBuildDuration, g_iWarDuration, g_iSuddenDuration, g_iNumSounds,
g_iOwnerEntity, g_iReadyWait, g_iCurrentMap, g_iWallEntities, g_iRedTeleports[MAX_SPAWN_POINTS], g_iBlueTeleports[MAX_SPAWN_POINTS], g_iBeamSprite, g_iHaloSprite, g_iAfkImmunity,
g_iPersistentColors[4], g_iPersistentEffect, g_iColorRed[4], g_iColorBlue[4], g_iReadyDelay, g_iReadySeconds, g_iDisableRadar, g_iDisableCrouching, g_iReadyAmount, g_iQuickAccess, g_iRadarAccess, g_iCrouchAccess,
g_iPropPublic, g_iPropSupporter, g_iPropAdmin, g_iDeletePublic, g_iDeleteSupporter, g_iDeleteAdmin, g_iTeleportPublic, g_iTeleportSupporter, g_iTeleportAdmin, g_iDefaultColor, g_iDefaultRotation, g_iDefaultPosition,
g_iColoringPublic, g_iColoringSupporter, g_iColoringAdmin, g_iColorPublic, g_iColorSupporter, g_iColorAdmin, g_iControlAccess, g_iCheckAccess, g_iCurrentDisable, g_iWarDisable, g_iSuddenDisable, g_iUniqueProp, g_iSpawningMode,
g_iRedSpawns, g_iBlueSpawns, g_iTotalSpawns, g_iRedReady, g_iBlueReady, g_iNumSeconds, g_iPlayersRed, g_iPlayersBlue, g_iPointsRed, g_iPointsBlue, g_iNumRedSpawns, g_iNumBlueSpawns, g_iSpriteRed, g_iSpriteBlue,
g_iSpawningRefresh, g_iPhase, g_iDefaultMoveSnap, g_iDefaultDegreeSnap, g_iMyWeapons, g_iCurrentMode, g_iDisableSuicide, g_iDisableFalling, g_iDisableRadio, g_iDisableDrowning, g_iDefaultQuick, g_iBuildDisable, g_iNoneDisable,
g_iRestrictWeapon;
new Float:g_fProximitySpawns, Float:g_fProximityPlayers, Float:g_fDefaultControl, Float:g_fGrabMinimum, Float:g_fGrabMaximum, Float:g_fGrabInterval, Float:g_fAfkForceSpecDelay, Float:g_fAfkSpecKickDelay,
Float:g_fAfkDelay, Float:g_fAfkAutoDelay, Float:g_fSpawningRefresh, Float:g_fReadyPercent, Float:g_fAdvert, Float:g_fTeleportPublicDelay, Float:g_fTeleportSupporterDelay, Float:g_fTeleportAdminDelay,
Float:g_fGrabDistance, Float:g_fGrabUpdate, Float:g_fSpawningDelay, Float:g_fRoundRestart, Float:g_fRedTeleports[MAX_SPAWN_POINTS][3], Float:g_fBlueTeleports[MAX_SPAWN_POINTS][3], Float:g_fSpawnDuration, Float:g_fSpawnRemaining;
new String:g_sPrefixSelect[16], String:g_sPrefixEmpty[16], String:g_sSounds[MAX_PHASE_SOUNDS][128], String:g_sCurrentMap[64], String:g_sDissolve[8],
String:g_sTitle[128], String:g_sHelp[128], String:g_sPrefixChat[32], String:g_sPrefixHint[32], String:g_sPrefixKey[32], String:g_sPrefixConsole[32], String:g_sPrefixCenter[32], String:g_sSpawnsRed[128], 
String:g_sSpawnsBlue[128], String:g_sGameDescription[64], String:g_sModeWeapon[32];

public Plugin:myinfo =
{
	name = "Proppisota", 
	author = "Twisted|Panda", 
	description = "Provides custom gameplay functionality for various communities.",
	version = PLUGIN_VERSION, 
	url = "http://Supermuroserver.com"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("sm_buildwars_v3.phrases");

	CreateConVar("sm_buildwars_version", PLUGIN_VERSION, "BuildWars: Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hCvar[CVAR_ENABLED] = CreateConVar("sm_buildwars_enable", "1", "Enables/disables all features of the plugin. (0 = Disabled, 1 = Enabled)", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_ENABLED], OnSettingsChange);
	g_hCvar[CVAR_DISPLAY] = CreateConVar("sm_buildwars_display", "1", "If enabled, information will be sent to all players pertaining to the current phase and various features.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_DISPLAY], OnSettingsChange);	
	g_hCvar[CVAR_DISSOLVE] = CreateConVar("sm_buildwars_dissolve", "3", "The dissolve effect to be used for removing props. (-1 = Disabled, 0 = Energy, 1 = Light, 2 = Heavy, 3 = Core)", FCVAR_NONE, true, -1.0, true, 3.0);
	HookConVarChange(g_hCvar[CVAR_DISSOLVE], OnSettingsChange);
	g_hCvar[CVAR_HELP] = CreateConVar("sm_buildwars_help", "http://ominousgaming.com/cstrike/help_buildwars.html", "The page that appears when a user types the help command into chat (\"\" = Disabled)", FCVAR_NONE);
	HookConVarChange(g_hCvar[CVAR_HELP], OnSettingsChange);
	g_hCvar[CVAR_ADVERT] = CreateConVar("sm_buildwars_advert", "5.0", "The number of seconds after a player joins an initial team for sm_buildwars_advert to be sent to the player. (-1 = Disabled)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_ADVERT], OnSettingsChange);
	g_hCvar[CVAR_SOUNDS] = CreateConVar("sm_buildwars_sounds", "npc/attack_helicopter/aheli_damaged_alarm1.wav, npc/overwatch/radiovoice/one.wav, npc/overwatch/radiovoice/two.wav, npc/overwatch/radiovoice/three.wav, npc/overwatch/radiovoice/four.wav, npc/overwatch/radiovoice/five.wav", "Sequential sounds that are played (from last to first) to signify the ending of a phase. Separate multiple sounds with \", \", with the first sound being the \"zero\" sound. Disable sound slots with \"?\", such as \"sound, ?, sound\"", FCVAR_NONE);
	HookConVarChange(g_hCvar[CVAR_SOUNDS], OnSettingsChange);
	g_hCvar[CVAR_MAX_ENTITIES] = CreateConVar("sm_buildwars_max_entities", "2000", "Disables the plugin's ability to create new entities if the current entity count is greater than or equal to this amount, to prevent entity-related crashes. (0 = Disabled)", FCVAR_NONE, true, 0.0, true, 2048.0);
	HookConVarChange(g_hCvar[CVAR_MAX_ENTITIES], OnSettingsChange);

	g_hCvar[CVAR_PROXIMITY_SPAWNS] = CreateConVar("sm_buildwars_proximity_spawns", "75", "Prevents players from building any props this many game units near a friendly spawn point. (0 = Disabled)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_PROXIMITY_SPAWNS], OnSettingsChange);
	g_hCvar[CVAR_PROXIMITY_PLAYERS] = CreateConVar("sm_buildwars_proximity_players", "75", "Prevents players from building any props this many game units near a friendly players. (0 = Disabled)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_PROXIMITY_PLAYERS], OnSettingsChange);

	g_hCvar[CVAR_PERSISTENT_ROUNDS] = CreateConVar("sm_buildwars_persistent_rounds", "1", "If enabled, player props will remain until the end of the round, allowing ownership to be returned if the player reconnects.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_PERSISTENT_ROUNDS], OnSettingsChange);
	g_hCvar[CVAR_PERSISTENT_COLORS] = CreateConVar("sm_buildwars_persistent_colors", "", "The RGBA color combination that player props will be turned if they disconnect during persistent rounds. (\"\" = Disabled)", FCVAR_NONE);
	HookConVarChange(g_hCvar[CVAR_PERSISTENT_COLORS], OnSettingsChange);
	g_hCvar[CVAR_PERSISTENT_EFFECT] = CreateConVar("sm_buildwars_persistent_effect", "-1", "The RGBA color combination that player props will be turned if they disconnect during persistent rounds. (-1 = Disabled)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_PERSISTENT_EFFECT], OnSettingsChange);

	g_hCvar[CVAR_DISABLE_RADIO] = CreateConVar("sm_buildwars_disable_radio", "7", "If enabled, clients will be unable to issue any radio commands during the configured phases. Add values together for multiple phases. (0 = Disabled, 1 = Build, 2 = War, 4 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_DISABLE_RADIO], OnSettingsChange);
	g_hCvar[CVAR_DISABLE_SUICIDE] = CreateConVar("sm_buildwars_disable_suicide", "7", "If enabled, players will be unable to commit suicide via \"kill\", \"explode\", and \"jointeam\" during the configured phases. Add values together for multiple phases. (0 = Disabled, 1 = Build, 2 = War, 4 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_DISABLE_SUICIDE], OnSettingsChange);	
	g_hCvar[CVAR_DISABLE_FALLING] = CreateConVar("sm_buildwars_disable_falling", "5", "If enabled, will not take any falling damage during the configured phases. Add values together for multiple phases. (0 = Disabled, 1 = Build, 2 = War, 4 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_DISABLE_FALLING], OnSettingsChange);	
	g_hCvar[CVAR_DISABLE_DROWNING] = CreateConVar("sm_buildwars_disable_drowning", "3", "If enabled, clients will not take drowning during the configured phases. Add values together for multiple phases. (0 = Disabled, 1 = Build, 2 = War, 4 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_DISABLE_DROWNING], OnSettingsChange);	
	g_hCvar[CVAR_DISABLE_CROUCHING] = CreateConVar("sm_buildwars_disable_crouching", "1", "If enabled, clients will not be able to crouch during the configured phases. Add values together for multiple phases. (0 = Disabled, 1 = Build, 2 = War, 4 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_DISABLE_CROUCHING], OnSettingsChange);	
	g_hCvar[CVAR_DISABLE_RADAR] = CreateConVar("sm_buildwars_disable_radar", "0", "If enabled, clients will not be able to use radar during the configured phases. Add values together for multiple phases. (0 = Disabled, 1 = Build, 2 = War, 4 = Sudden Death)", FCVAR_NONE, true, 0.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_DISABLE_RADAR], OnSettingsChange);	

	g_hCvar[CVAR_DEFAULT_COLOR] = CreateConVar("sm_buildwars_default_color", "0", "The default prop color that players will spawn with. (# = Index, -1 = No Color Options)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_DEFAULT_COLOR], OnSettingsChange);
	g_hCvar[CVAR_DEFAULT_ROTATION] = CreateConVar("sm_buildwars_default_rotation", "3", "The default degree value that players will spawn with. (# = Index, -1 = No Rotation Options)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_DEFAULT_ROTATION], OnSettingsChange);
	g_hCvar[CVAR_DEFAULT_POSITION] = CreateConVar("sm_buildwars_default_position", "4", "The default position value that players will spawn with. (# = Index, -1 = No Position Options)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_DEFAULT_POSITION], OnSettingsChange);
	g_hCvar[CVAR_DEFAULT_DEGREE] = CreateConVar("sm_buildwars_default_snap_rotation", "0", "The default rotational snap that players will spawn with. (# = Index, -1 = No Rotation Snap Options)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_DEFAULT_DEGREE], OnSettingsChange);	
	g_hCvar[CVAR_DEFAULT_MOVE] = CreateConVar("sm_buildwars_default_snap_position", "0", "The default positional snap that players will spawn with. (# = Index, -1 = No Position Snap Options)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_DEFAULT_MOVE], OnSettingsChange);	
	g_hCvar[CVAR_DEFAULT_CONTROL] = CreateConVar("sm_buildwars_default_control", "150", "The default control distance that players will spawn with. (#.# = Interval, -1 = No Control Options)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_DEFAULT_CONTROL], OnSettingsChange);
	g_hCvar[CVAR_DEFAULT_QUICK] = CreateConVar("sm_buildwars_default_quick_key", "1", "The default usage of the USE key that players will spawn with. (-1 = No Quick Options, 0 = Disabled, 1 = Prop Menu, 2 = Delete Prop, 3 = Copy/Paste Prop)", FCVAR_NONE, true, -1.0, true, 4.0);
	HookConVarChange(g_hCvar[CVAR_DEFAULT_QUICK], OnSettingsChange);

	g_hCvar[CVAR_DURATION_BUILD] = CreateConVar("sm_buildwars_duration_build", "240", "The number of seconds after the start of the round that the building phase ends and the war phase begins. (0 = Disabled)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_DURATION_BUILD], OnSettingsChange);
	g_hCvar[CVAR_DURATION_WAR] = CreateConVar("sm_buildwars_duration_war", "240", "The number of seconds after the start of the war phase that the war phase ends. If disabled, the round will continue until players stop respawning. (0 = Disabled)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_DURATION_WAR], OnSettingsChange);
	g_hCvar[CVAR_SUDDEN_DEATH] = CreateConVar("sm_buildwars_sudden_death", "1", "If enabled, Sudden Death will activate after the end of the War phase, if sm_buildwars_duration_war is set.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_SUDDEN_DEATH], OnSettingsChange);

	g_hCvar[CVAR_LIMIT_NONE] = CreateConVar("sm_buildwars_disable", "0", "Features to be disabled if map integration is not supported. Add values together for multiple feature disable. (0 = Disabled, 1 = Building, 2 = Deleting, 4 = Rotating, 8 = Moving, 16 = Grabbing, 32 = Checking, 64 = Teleporting, 128 = Coloring, 256 = Clearing)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_LIMIT_NONE], OnSettingsChange);	
	g_hCvar[CVAR_LIMIT_BUILD] = CreateConVar("sm_buildwars_disable_build", "0", "Features to be disabled during the build phase. Add values together for multiple feature disable. (0 = Disabled, 1 = Building, 2 = Deleting, 4 = Rotating, 8 = Moving, 16 = Grabbing, 32 = Checking, 64 = Teleporting, 128 = Coloring, 256 = Clearing)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_LIMIT_BUILD], OnSettingsChange);
	g_hCvar[CVAR_LIMIT_WAR] = CreateConVar("sm_buildwars_disable_war", "413", "Features to be disabled during the war phase. Add values together for multiple feature disable. (0 = Disabled, 1 = Building, 2 = Deleting, 4 = Rotating, 8 = Moving, 16 = Grabbing, 32 = Checking, 64 = Teleporting, 128 = Coloring, 256 = Clearing)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_LIMIT_WAR], OnSettingsChange);
	g_hCvar[CVAR_LIMIT_SUDDEN] = CreateConVar("sm_buildwars_disable_sudden", "447", "Features to be disabled durring Sudden Death. Add values together for multiple feature disable. (0 = Disabled, 1 = Building, 2 = Deleting, 4 = Rotating, 8 = Moving, 16 = Grabbing, 32 = Checking, 128 = Coloring) (Note: Teleport always disabled, do not add 64)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_LIMIT_SUDDEN], OnSettingsChange);	

	g_hCvar[CVAR_PUBLIC_PROPS] = CreateConVar("sm_buildwars_prop_public", "85", "The maximum amount of props public players are allowed to build. (0 = Infinite, -1 = No Building)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_PUBLIC_PROPS], OnSettingsChange);
	g_hCvar[CVAR_SUPPORTER_PROPS] = CreateConVar("sm_buildwars_prop_supporter", "100", "The maximum amount of props administrative players are allowed to build. (0 = Infinite, -1 = No Building)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_SUPPORTER_PROPS], OnSettingsChange);
	g_hCvar[CVAR_ADMIN_PROPS] = CreateConVar("sm_buildwars_prop_admin", "100", "The maximum amount of props supporter players are allowed to build. (0 = Infinite, -1 = No Building)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_ADMIN_PROPS], OnSettingsChange);	
	g_hCvar[CVAR_DISPLAY_INDEX] = CreateConVar("sm_buildwars_prop_show_index", "0", "If enabled, the index for all spawnable props will be shown in the create menu, for manual building", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_DISPLAY_INDEX], OnSettingsChange);	
	
	g_hCvar[CVAR_PUBLIC_DELETES] = CreateConVar("sm_buildwars_delete_public", "0", "The maximum amount of props public players are allowed to delete. (0 = Infinite, -1 = No Deleting)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_PUBLIC_DELETES], OnSettingsChange);
	g_hCvar[CVAR_SUPPORTER_DELETES] = CreateConVar("sm_buildwars_delete_supporter", "0", "The maximum amount of props supporter players are allowed to delete. (0 = Infinite, -1 = No Deleting)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_SUPPORTER_DELETES], OnSettingsChange);
	g_hCvar[CVAR_ADMIN_DELETES] = CreateConVar("sm_buildwars_delete_admin", "0", "The maximum amount of props administrative players are allowed to delete. (0 = Infinite, -1 = No Deleting)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_ADMIN_DELETES], OnSettingsChange);	
	
	g_hCvar[CVAR_PUBLIC_TELES] = CreateConVar("sm_buildwars_tele_public", "0", "The maximum amount of teleports public players are allowed to use. (0 = Infinite, -1 = No Teleporting)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_PUBLIC_TELES], OnSettingsChange);
	g_hCvar[CVAR_SUPPORTER_TELES] = CreateConVar("sm_buildwars_tele_supporter", "0", "The maximum amount of teleports supporter players are allowed to use. (0 = Infinite, -1 = No Teleporting)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_SUPPORTER_TELES], OnSettingsChange);
	g_hCvar[CVAR_ADMIN_TELES] = CreateConVar("sm_buildwars_tele_admin", "0", "The maximum amount of teleports administrative players are allowed to use. (0 = Infinite, -1 = No Teleporting)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_ADMIN_TELES], OnSettingsChange);
	g_hCvar[CVAR_PUBLIC_DELAY] = CreateConVar("sm_buildwars_tele_public_delay", "10", "The number of seconds public players must wait before their teleport is processed. (0 = Instant)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_PUBLIC_DELAY], OnSettingsChange);
	g_hCvar[CVAR_SUPPORTER_DELAY] = CreateConVar("sm_buildwars_tele_supporter_delay", "5", "The number of seconds supporters must wait before their teleport is processed. (0 = Instant)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_SUPPORTER_DELAY], OnSettingsChange);
	g_hCvar[CVAR_ADMIN_DELAY] = CreateConVar("sm_buildwars_tele_admin_delay", "0", "The number of seconds admins must wait before their teleport is processed. (0 = Instant)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_ADMIN_DELAY], OnSettingsChange);
	g_hCvar[CVAR_TELE_BEACON] = CreateConVar("sm_buildwars_tele_war_beacon", "1", "If enabled, players who teleport during the war phase will be beaconed until death or the end of the round.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_TELE_BEACON], OnSettingsChange);
	
	g_hCvar[CVAR_PUBLIC_COLOR] = CreateConVar("sm_buildwars_color_public", "15", "If the player's coloring scheme is set to Selection, this is the number of times they're allowed to color their props. (0 = Infinite, -1 = No Coloring)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_PUBLIC_COLOR], OnSettingsChange);
	g_hCvar[CVAR_SUPPORTER_COLOR] = CreateConVar("sm_buildwars_color_supporter", "30", "If the supporter's coloring scheme is set to Selection, this is the number of times they're allowed to color their props. (0 = Infinite, -1 = No Coloring)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_SUPPORTER_COLOR], OnSettingsChange);
	g_hCvar[CVAR_ADMIN_COLOR] = CreateConVar("sm_buildwars_color_admin", "0", "If the admin's coloring scheme is set to Selection, this is the number of times they're allowed to color their props. (0 = Infinite, -1 = No Coloring)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_ADMIN_COLOR], OnSettingsChange);
	g_hCvar[CVAR_COLOR_RED] = CreateConVar("sm_buildwars_coloring_red", "255 0 0 255", "The defined color for players on the Terrorist team when colors are forced.", FCVAR_NONE);
	HookConVarChange(g_hCvar[CVAR_COLOR_RED], OnSettingsChange);
	g_hCvar[CVAR_COLOR_BLUE] = CreateConVar("sm_buildwars_coloring_blue", "0 0 255 255", "The defined color for players on the Terrorist team when colors are forced.", FCVAR_NONE);
	HookConVarChange(g_hCvar[CVAR_COLOR_BLUE], OnSettingsChange);	
	g_hCvar[CVAR_PUBLIC_COLORING] = CreateConVar("sm_buildwars_coloring_mode_public", "0", "Determines how props will be colored for public players. (0 = Selection, 1 = Forced Random, 2 = Forced Team Colored, 3 = Forced Default)", FCVAR_NONE, true, 0.0, true, 3.0);
	HookConVarChange(g_hCvar[CVAR_PUBLIC_COLORING], OnSettingsChange);
	g_hCvar[CVAR_SUPPORTER_COLORING] = CreateConVar("sm_buildwars_coloring_mode_supporter", "0", "Determines how props will be colored for supporters. (0 = Selection, 1 = Forced Random, 2 = Forced Team Colored, 3 = Forced Default)", FCVAR_NONE, true, 0.0, true, 3.0);
	HookConVarChange(g_hCvar[CVAR_SUPPORTER_COLORING], OnSettingsChange);
	g_hCvar[CVAR_ADMIN_COLORING] = CreateConVar("sm_buildwars_coloring_mode_admin", "0", "Determines how props will be colored for admins. (0 = Selection, 1 = Forced Random, 2 = Forced Team Colored, 3 = Forced Default)", FCVAR_NONE, true, 0.0, true, 3.0);
	HookConVarChange(g_hCvar[CVAR_ADMIN_COLORING], OnSettingsChange);	

	g_hCvar[CVAR_ACCESS_SPEC] = CreateConVar("sm_buildwars_access_team_spec", "1", "Controls whether or not Spectators have access to any features provided by Build Wars.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_SPEC], OnSettingsChange);
	g_hCvar[CVAR_ACCESS_RED] = CreateConVar("sm_buildwars_access_team_red", "1", "Controls whether or not Terrorists have access to any features provided by Build Wars.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_RED], OnSettingsChange);
	g_hCvar[CVAR_ACCESS_BLUE] = CreateConVar("sm_buildwars_access_team_blue", "1", "Controls whether or not Counter-Terrorists have access to any features provided by Build Wars.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_BLUE], OnSettingsChange);
	g_hCvar[CVAR_ACCESS_SETTINGS] = CreateConVar("sm_buildwars_access_settings", "1", "If enabled, players will be able to access the Actions / Settings menu in Build Wars.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_SETTINGS], OnSettingsChange);
	g_hCvar[CVAR_ACCESS_MANAGE]  = CreateConVar("sm_buildwars_access_features", "1", "If enabled, admins will be able to access the Admin Actions menu in Build Wars", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_MANAGE], OnSettingsChange);	
	g_hCvar[CVAR_ACCESS_CHECK] = CreateConVar("sm_buildwars_access_check", "7", "Controls access to the check prop feature.  Add values together for multiple group access. (0 = Disabled, 1 = Normal, 2 = Supporters, 4 = Admins)", FCVAR_NONE, true, 0.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_CHECK], OnSettingsChange);
	g_hCvar[CVAR_ACCESS_GRAB] = CreateConVar("sm_buildwars_access_grab", "7", "Controls access to the grab feature. Add values together for multiple group access. (0 = Disabled, 1 = Normal, 2 = Supporters, 4 = Admins)", FCVAR_NONE, true, 0.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_GRAB], OnSettingsChange);
	g_hCvar[CVAR_ACCESS_CROUCH] = CreateConVar("sm_buildwars_access_crouch", "6", "Controls access to crouching, if it has been disabled via sm_buildwars_disable_crouching. Add values together for multiple group access. (0 = Disabled, 1 = Normal, 2 = Supporters, 4 = Admins)", FCVAR_NONE, true, 0.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_CROUCH], OnSettingsChange);
	g_hCvar[CVAR_ACCESS_RADAR] = CreateConVar("sm_buildwars_access_radar", "0", "Controls access to radar, if it has been disabled via sm_buildwars_disable_radar. Add values together for multiple group access. (0 = Disabled, 1 = Normal, 2 = Supporters, 4 = Admins)", FCVAR_NONE, true, 0.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_RADAR], OnSettingsChange);
	g_hCvar[CVAR_ACCESS_QUICK] = CreateConVar("sm_buildwars_access_quick", "7", "Controls access to quick key feature. (0 = Disabled, 1 = Normal, 2 = Supporters, 4 = Admins)", FCVAR_NONE, true, 0.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_QUICK], OnSettingsChange);

	g_hCvar[CVAR_GRAB_DISTANCE] = CreateConVar("sm_buildwars_grab_distance", "768", "The maximum distance at which props can be grabbed from. (0 = No Maximum)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_GRAB_DISTANCE], OnSettingsChange);
	g_hCvar[CVAR_GRAB_REFRESH] = CreateConVar("sm_buildwars_grab_update", "0.1", "The frequency at which grabbed objects will update.", FCVAR_NONE, true, 0.1);
	HookConVarChange(g_hCvar[CVAR_GRAB_REFRESH], OnSettingsChange);
	g_hCvar[CVAR_GRAB_MINIMUM] = CreateConVar("sm_buildwars_grab_minimum", "50", "The distance players can decrease their grab distance to.", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_GRAB_MINIMUM], OnSettingsChange);
	g_hCvar[CVAR_GRAB_MAXIMUM] = CreateConVar("sm_buildwars_grab_maximum", "300", "The distance players can increase their grab distance to.", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_GRAB_MAXIMUM], OnSettingsChange);
	g_hCvar[CVAR_GRAB_INTERVAL] = CreateConVar("sm_buildwars_grab_interval", "10", "The interval at which a players grab distance will increase/decrease.", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_GRAB_INTERVAL], OnSettingsChange);
	g_hCvar[CVAR_GRAB_SOLID] = CreateConVar("sm_buildwars_grab_non_solid", "1", "If enabled, controlled props will be given no-block status while they're being controlled", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_GRAB_SOLID], OnSettingsChange);
	
	g_hCvar[CVAR_SPAWNING_MODE] = CreateConVar("sm_buildwars_spawning_mode", "0", "Determines how the spawning module functions. (0 = Disabled, 1 = Team Spawns, 2 = Single Spawns, 3 = Timed Spawns)", FCVAR_NONE, true, 0.0, true, 3.0);
	HookConVarChange(g_hCvar[CVAR_SPAWNING_MODE], OnSettingsChange);
	g_hCvar[CVAR_SPAWNING_BUILD] = CreateConVar("sm_buildwars_spawning_build", "1", "If enabled, all clients that connect and die during the building phase will be spawned.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_SPAWNING_BUILD], OnSettingsChange);
	g_hCvar[CVAR_SPAWNING_DELAY] = CreateConVar("sm_buildwars_spawning_delay", "5", "The number of seconds after a player dies that they will be respawned, if applicable.", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_SPAWNING_DELAY], OnSettingsChange);
	g_hCvar[CVAR_SPAWNING_FACTOR] = CreateConVar("sm_buildwars_spawning_spawns", "3", "The number of respawns to be given per each player: (Team Spawns: (Factor * Players), Single Spawns: (Factor))", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_SPAWNING_FACTOR], OnSettingsChange);
	g_hCvar[CVAR_SPAWNING_IGNORE] = CreateConVar("sm_buildwars_spawning_ignore", "0", "If enabled, the plugin will control mp_ignore_round_win_conditions to keep the round from ending prematurely.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_SPAWNING_IGNORE], OnSettingsChange);
	g_hCvar[CVAR_SPAWNING_DURATION] = CreateConVar("sm_buildwars_spawning_time", "0", "The number of seconds to allow spawning, if sm_buildwars_spawning_mode 3. (0 = Disabled, # = Duration | Combine Build + War Durations, if map integration is used)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_SPAWNING_DURATION], OnSettingsChange);

	g_hCvar[CVAR_SPAWNS_APPEAR] = CreateConVar("sm_buildwars_spawnpoints_appear", "1", "If enabled, players will be able to see their team's spawn points.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_SPAWNS_APPEAR], OnSettingsChange);
	g_hCvar[CVAR_SPAWNS_REFRESH] = CreateConVar("sm_buildwars_spawnpoints_refresh", "5", "How often the spawn point sprites are refreshed to all team members, in seconds.", FCVAR_NONE, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_SPAWNS_REFRESH], OnSettingsChange);
	g_hCvar[CVAR_SPAWNS_RED] = CreateConVar("sm_buildwars_spawnpoints_sprite_red", "sprites/redglow2.vmt", "The sprite to be used for the spawn point display, for Terrorists.", FCVAR_NONE);
	HookConVarChange(g_hCvar[CVAR_SPAWNS_RED], OnSettingsChange);
	g_hCvar[CVAR_SPAWNS_BLUE] = CreateConVar("sm_buildwars_spawnpoints_sprite_blue", "sprites/blueglow2.vmt", "The sprite to be used for the spawn point display, for Counter-Terrorists.", FCVAR_NONE);
	HookConVarChange(g_hCvar[CVAR_SPAWNS_BLUE], OnSettingsChange);

	g_hCvar[CVAR_READY_ENABLE] = CreateConVar("sm_buildwars_ready_enable", "1", "If enabled, players will be able to flag \"ready\", potentially allowing the dividing wall to fall early.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_READY_ENABLE], OnSettingsChange);
	g_hCvar[CVAR_READY_PERCENT] = CreateConVar("sm_buildwars_ready_percent", "0.70", "The percent of players needed to flag \"ready\" for the dividing wall to fall early.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_READY_PERCENT], OnSettingsChange);
	g_hCvar[CVAR_READY_DELAY] = CreateConVar("sm_buildwars_ready_delay", "5", "The number of seconds to wait before starting the war phase if triggered by ready.", FCVAR_NONE, true, 0.0, true, 60.0);
	HookConVarChange(g_hCvar[CVAR_READY_DELAY], OnSettingsChange);
	g_hCvar[CVAR_READY_WAIT] = CreateConVar("sm_buildwars_ready_wait", "20", "The number of seconds after the round starts before ready becomes active.", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_READY_WAIT], OnSettingsChange);
	g_hCvar[CVAR_READY_MINIMUM] = CreateConVar("sm_buildwars_ready_minimum", "2", "The minimum number of players needed before ready becomes active.", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_READY_MINIMUM], OnSettingsChange);

	g_hCvar[CVAR_MAINTAIN_TEAMS] = CreateConVar("sm_buildwars_maintain_size", "1", "If enabled, team sizes will be checked upon player deaths and round endings to maintain mp_limitteams.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_MAINTAIN_TEAMS], OnSettingsChange);	
	g_hCvar[CVAR_MAINTAIN_SPAWNS] = CreateConVar("sm_buildwars_maintain_spawns", "1", "If enabled, spawn points will be maintained to ensure that there always (MaxClients / 2) spawns available for each team.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_MAINTAIN_SPAWNS], OnSettingsChange);
	g_hCvar[CVAR_SCRAMBLE_ROUNDS] = CreateConVar("sm_buildwars_scramble_rounds", "1", "The number of rounds required before teams are scrambled.", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_SCRAMBLE_ROUNDS], OnSettingsChange);

	g_hCvar[CVAR_AFK_ENABLE] = CreateConVar("sm_buildwars_afk_enable", "1", "If enabled, public players will be checked for afk status at the start of each round.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_AFK_ENABLE], OnSettingsChange);
	g_hCvar[CVAR_AFK_DELAY] = CreateConVar("sm_buildwars_afk_delay", "150", "The number of seconds after the start of the round that public players are checked for being afk.", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_AFK_DELAY], OnSettingsChange);
	g_hCvar[CVAR_AFK_KICK] = CreateConVar("sm_buildwars_afk_auto_kick", "1", "If enabled, public players who are found to be afk are automatically added to a kick query.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_AFK_KICK], OnSettingsChange);
	g_hCvar[CVAR_AFK_KICK_DELAY] = CreateConVar("sm_buildwars_afk_auto_kick_delay", "150", "The number of seconds after a player is found to be afk that they are removed from the server.", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_AFK_KICK_DELAY], OnSettingsChange);	
	g_hCvar[CVAR_AFK_SPEC] = CreateConVar("sm_buildwars_afk_spec_kick", "1", "If enabled, public players who manually join spectate are automatically added to a kick query.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_AFK_SPEC], OnSettingsChange);
	g_hCvar[CVAR_AFK_SPEC_DELAY] = CreateConVar("sm_buildwars_afk_spec_kick_delay", "300", "The number of seconds after a public player joins spectate that they are removed from the game.", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_AFK_SPEC_DELAY], OnSettingsChange);	
	g_hCvar[CVAR_AFK_FORCE] = CreateConVar("sm_buildwars_afk_force_spec", "1", "If enabled, all players are automatically thrown into spectate x seconds after connecting if they have not yet joined a team (to trigger spectator kicking, if non-admin).", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_AFK_FORCE], OnSettingsChange);	
	g_hCvar[CVAR_AFK_FORCE_DELAY] = CreateConVar("sm_buildwars_afk_force_spec_delay", "180", "The number of seconds after a player connects that they are thrown into spectate if not on a team.", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_AFK_FORCE_DELAY], OnSettingsChange);	
	g_hCvar[CVAR_AFK_RETURN] = CreateConVar("sm_buildwars_afk_return", "1", "If enabled, players who have been marked for afk and thrown into spectate will be able to return at any time up until the build phase ends.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_AFK_RETURN], OnSettingsChange);
	g_hCvar[CVAR_AFK_IMMUNITY] = CreateConVar("sm_buildwars_afk_immunity", "6", "Controls immunity to the anti afk system. Add values together for multiple groups. (0 = Disabled, 2 = Supporter, 4 = Admin)", FCVAR_NONE, true, 0.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_AFK_IMMUNITY], OnSettingsChange);

	g_hCvar[CVAR_GAME_DESCRIPTION] = CreateConVar("sm_buildwars_game_description", "BuildWars {VERSION}", "The \"Game\" to be displayed within the CS:S server browser. Use {VERSION} to get the current game version.", FCVAR_NONE);
	HookConVarChange(g_hCvar[CVAR_GAME_DESCRIPTION], OnSettingsChange);
	g_hCvar[CVAR_ALWAYS_BUYZONE] = CreateConVar("sm_buildwars_buyzones", "1", "If enabled, players are always considered in a buyzone, and thus always able to get a weapon, during the Build phase.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_ALWAYS_BUYZONE], OnSettingsChange);
	AutoExecConfig(true, "sm_buildwars_v3");
	
	g_hLimitTeams = FindConVar("mp_limitteams");
	HookConVarChange(g_hLimitTeams, OnSettingsChange);
	g_hRoundRestart = FindConVar("mp_round_restart_delay");
	HookConVarChange(g_hRoundRestart, OnSettingsChange);
	g_hIgnoreRound = FindConVar("mp_ignore_round_win_conditions");

	HookEvent("round_end", Event_OnRoundEnd);
	HookEvent("round_start", Event_OnRoundStart);
	HookEvent("player_team", Event_OnPlayerTeam, EventHookMode_Pre);
	HookEvent("player_spawn", Event_OnPlayerSpawn, EventHookMode_Pre);
	HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Pre);	
	HookEvent("hegrenade_detonate", Event_OnGrenadeExplode, EventHookMode_Pre);
	HookEvent("player_changename", Event_OnPlayerName, EventHookMode_Pre);
	HookEvent("player_blind", Event_PlayerBlind, EventHookMode_Post);

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

	RegAdminCmd("sm_showhelp", Command_Help, ADMFLAG_GENERIC, "Build Wars: Forces the client to type !help");
	RegServerCmd("sm_buildwars_chat", Command_Chat, "Build Wars: Command for utilizing the chat translation prefix in a chat message to all players. Usage: sm_buildwars_chat <string:message>");
	RegServerCmd("sm_buildwars_hint", Command_Hint, "Build Wars: Command for utilizing the hint translation prefix in a hint message to all players. Usage: sm_buildwars_hint <string:message>");
	RegServerCmd("sm_buildwars_key", Command_Key, "Build Wars: Command for utilizing the key-hint translation prefix in a key hint message to all players. Usage: sm_buildwars_key <string:message>");
	RegServerCmd("sm_buildwars_center", Command_Center, "Build Wars: Command for utilizing the center translation prefix in a center message to all players. Usage: sm_buildwars_center <string:message>");

	g_cBuildVersion = RegClientCookie("BuildWars_ClientVersion", "The version string from which the client was authenticated.", CookieAccess_Private);
	g_cConfigRotation = RegClientCookie("BuildWars_ConfigRotation", "The client's configuration value for rotation intervals.", CookieAccess_Private);
	g_cConfigPosition = RegClientCookie("BuildWars_ConfigPosition", "The client's configuration value for position intervals.", CookieAccess_Private);
	g_cConfigColor = RegClientCookie("BuildWars_ConfigColor", "The client's configuration value for prop colors.", CookieAccess_Private);
	g_cConfigLocks = RegClientCookie("BuildWars_ConfigLocks", "The client's configuration value for positional and rotational locking.", CookieAccess_Private);
	g_cConfigDistance = RegClientCookie("BuildWars_ConfigGrab", "The client's configuration value for grab distance.", CookieAccess_Private);
	g_cConfigQuick = RegClientCookie("BuildWars_ConfigQuick", "The client's configuration value for quick key usage.", CookieAccess_Private);

	g_hKV_Repository = CreateKeyValues("BuildWars_PropRepository");
	g_hArray_Repository = CreateArray();
	g_hTrie_PlayerCommands = CreateTrie();
	g_hTrie_ModeWeapons = CreateTrie();	
	g_hTrie_MapConfigurations = CreateTrie();
	g_hArray_MapEntities = CreateArray();
	g_hArray_RedPlayers = CreateArray();
	g_hArray_BluePlayers = CreateArray();
	
	g_iMyWeapons = FindSendPropOffs("CBaseCombatCharacter", "m_hMyWeapons");
	g_iOwnerEntity = FindSendPropOffs("CBaseCombatWeapon", "m_hOwnerEntity");
	g_iFlashDuration = FindSendPropOffs("CCSPlayer", "m_flFlashDuration");
	g_iFlashAlpha = FindSendPropOffs("CCSPlayer", "m_flFlashMaxAlpha");
	
	Define_Props();
	Define_Rotations();
	Define_Positions();
	Define_Colors();
	Define_Commands();
	Define_Modes();
	Define_Maps();
	Void_SetDefaults();
}

public OnPluginEnd()
{
	if(g_bEnabled)
	{
		ClearTrie(g_hTrie_PlayerCommands);
		ClearTrie(g_hTrie_ModeWeapons);
		ClearTrie(g_hTrie_MapConfigurations);
		ClearArray(g_hArray_MapEntities);
		ClearArray(g_hArray_RedPlayers);
		ClearArray(g_hArray_BluePlayers);

		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				if(g_iDisableRadar)
					Void_ShowRadar(i);
				Bool_ClearClientProps(i);
				Void_ClearClientControl(i);
				Void_ClearClientTeleport(i);
				Void_ClearClientRespawn(i);
			}
		}
		
		new _iRepository = GetArraySize(g_hArray_Repository);
		if(_iRepository)
		{
			for(new i = 0; i < _iRepository; i++)
			{
				new entity = GetArrayCell(g_hArray_Repository, i);
				if(IsValidEntity(entity) && g_bProp[entity])
					Entity_DeleteProp(entity);
			}
		}
		
		ClearArray(g_hArray_Repository);

		if(g_iPhase == PHASE_SUDDEN)
		{
			if(g_hTrie_RestrictIndex != INVALID_HANDLE)
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

public OnAllPluginsLoaded()
{
	if(g_bEnabled)
	{
		if(!g_bLoadedRestrictions)
			Void_DefineRestrictions();
	}
}

Void_DefineRestrictions()
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
		
		decl String:_sBuffer[32], String:_sTeam[][] = { "t", "ct" };
		for(new i = 0; i < RESTRICTION_WEAPONS; i++)
		{
			SetTrieValue(g_hTrie_RestrictIndex, g_sRestrictWeapons[i], i);
			
			for(new j = 0; j < RESTRICTION_TOTAL; j++)
			{
				Format(_sBuffer, sizeof(_sBuffer), "sm_restrict_%s_%s", g_sRestrictWeapons[i], _sTeam[j]);
				
				if(g_hRestrictCvar[j][i] == INVALID_HANDLE)
					g_hRestrictCvar[j][i] = FindConVar(_sBuffer);
					
				g_iRestrictOriginal[j][i] = GetConVarInt(g_hRestrictCvar[j][i]);
				g_bRestrictState[j][i] = (g_iRestrictOriginal[j][i] == -1) ? false : true;
			}
		}
	}
}

public Action:OnGetGameDescription(String:gameDesc[64])
{
	if (g_bGameDescription && g_bNewMap)
	{
		strcopy(gameDesc, sizeof(gameDesc), g_sGameDescription);
		ReplaceString(gameDesc, sizeof(gameDesc), "{VERSION}", PLUGIN_VERSION, false);
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public OnMapStart()
{
	g_bNewMap = true;
	g_iCurEntities = 0;
	for(new i = 1; i <= MaxEntities; i++)
		if(IsValidEntity(i))
			g_iCurEntities++;

	Void_SetDefaults();
	if(g_bEnabled)
	{
		Void_SetDownloads();
		new entity = -1;
		while((entity = FindEntityByClassname(entity, "shadow_control")) != -1)
			AcceptEntityInput(entity, "Kill");
	
		for(new i = 1; i <= MaxClients; i++)
			if(g_hArray_PlayerProps[i] == INVALID_HANDLE)
				g_hArray_PlayerProps[i] = CreateArray();

		g_iCurrentRound = g_iLastScramble = 0;
		
		g_iPhase = PHASE_NONE;
		g_iSpriteRed = PrecacheModel(g_sSpawnsRed);
		g_iSpriteBlue = PrecacheModel(g_sSpawnsBlue);
		g_iBeamSprite = PrecacheModel("materials/sprites/laser.vmt");
		g_iHaloSprite = PrecacheModel("materials/sprites/halo01.vmt");
		for(new i = 0; i < g_iNumProps; i++)
			PrecacheModel(g_sDefinedPropPaths[i]);
		
		if(g_bPersistentRounds)
		{
			if(g_hKV_Repository == INVALID_HANDLE || g_hKV_Repository != INVALID_HANDLE && CloseHandle(g_hKV_Repository))
				g_hKV_Repository = CreateKeyValues("BuildWars_PropRepository");
			
			ClearArray(g_hArray_Repository);
		}

		CreateTimer(0.1, Timer_OnMapStart);
	}
}

public Action:Timer_OnMapStart(Handle:timer)
{
	Void_SetSpawns();
	
	Define_Maps();
	g_iCurrentMap = -1;
	GetCurrentMap(g_sCurrentMap, 64);
	StripQuotes(g_sCurrentMap);
	TrimString(g_sCurrentMap);
	GetTrieValue(g_hTrie_MapConfigurations, g_sCurrentMap, g_iCurrentMap);
	
	if(g_iCurrentMap != -1)
		g_iPhase = PHASE_BUILD;
}

public OnMapEnd()
{
	g_bEnding = true;
	g_bNewMap = false;
	if(g_bEnabled)
	{
		Array_Empty(TEAM_RED);
		Array_Empty(TEAM_BLUE);
		if(g_hTimer_Update != INVALID_HANDLE && CloseHandle(g_hTimer_Update))
			g_hTimer_Update = INVALID_HANDLE;

		if(g_iSpawningMode == SPAWNING_TIMED)
			if(g_hTimer_StopSpawning != INVALID_HANDLE && CloseHandle(g_hTimer_StopSpawning))
				g_hTimer_StopSpawning= INVALID_HANDLE;

		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				Bool_ClearClientProps(i);
				Void_ClearClientControl(i);
				Void_ClearClientTeleport(i);
				Void_ClearClientRespawn(i);
			}
		}
	}
}

public OnConfigsExecuted()
{
	if(g_bEnabled)
	{
		Void_DefineRestrictions();
		Format(g_sTitle, 128, "%T", "Main_Menu_Title", LANG_SERVER);
		Format(g_sPrefixChat, 32, "%T", "Prefix_Chat", LANG_SERVER);
		Format(g_sPrefixHint, 32, "%T", "Prefix_Hint", LANG_SERVER);
		Format(g_sPrefixKey, 32, "%T", "Prefix_KeyHint", LANG_SERVER);
		Format(g_sPrefixCenter, 32, "%T", "Prefix_Center", LANG_SERVER);
		Format(g_sPrefixConsole, 32, "%T", "Prefix_Console", LANG_SERVER);
		Format(g_sPrefixSelect, 16, "%T", "Menu_Option_Selected", LANG_SERVER);
		Format(g_sPrefixEmpty, 16, "%T", "Menu_Option_Empty", LANG_SERVER);

		if(g_bLateLoad)
		{
			Void_SetDefaults();
			CreateTimer(0.1, Timer_OnMapStart);
	
			for(new i = 1; i <= MaxClients; i++)
			{
				g_iPlayerAccess[i] = ACCESS_PUBLIC;

				if(IsClientInGame(i))
				{
					g_iTeam[i] = GetClientTeam(i);
					g_bAlive[i] = IsPlayerAlive(i) ? true : false;
					GetClientAuthString(i, g_sSteam[i], 32);	
					GetClientName(i, g_sName[i], 32);

					g_iPlayerProps[i] = 0;
					g_iPlayerDeletes[i] = 0;
					g_iPlayerColors[i] = 0;
					g_iPlayerTeleports[i] = 0;
					g_iPlayerControl[i] = -1;
					g_iPlayerSpawns[i] = g_iTotalSpawns;

					Void_AuthClient(i);
					switch(g_iTeam[i])
					{
						case CS_TEAM_T:
						{
							Array_Push(i, g_iTeam[i]);
							g_iClass[i] = GetRandomInt(1, 4);
						}
						case CS_TEAM_CT:
						{
							Array_Push(i, g_iTeam[i]);
							g_iClass[i] = GetRandomInt(5, 8);
						}
					}

					if(!g_bLoaded[i] && AreClientCookiesCached(i))
						Void_LoadCookies(i);
					
					SDKHook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
					SDKHook(i, SDKHook_PostThinkPost, Hook_PostThinkPost);
					SDKHook(i, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
				}
			}

			g_iCurrentRound = 1;
			g_iSpriteRed = PrecacheModel(g_sSpawnsRed);
			g_iSpriteBlue = PrecacheModel(g_sSpawnsBlue);

			g_bLateLoad = false;
		}
	}
}

public OnClientPutInServer(client)
{
	if(g_bEnabled)
	{
		SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
		SDKHook(client, SDKHook_PostThinkPost, Hook_PostThinkPost);
		SDKHook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);

		g_iPlayerProps[client] = 0;
		g_iPlayerColors[client] = 0;
		g_iPlayerDeletes[client] = 0;
		g_iPlayerTeleports[client] = 0;
		g_bResetSpeed[client] = false;
		g_bResetGravity[client] = false;
		
		if(g_bAfkEnable && g_bAfkAutoSpec && !g_iTeam[client])
			g_hTimer_AfkCheck[client] = CreateTimer(g_fAfkForceSpecDelay, Timer_AfkAutoSpec, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public OnClientPostAdminCheck(client)
{
	if(g_bEnabled)
	{
		if(IsClientInGame(client))
		{
			g_iPlayerAccess[client] = ACCESS_PUBLIC;
			GetClientAuthString(client, g_sSteam[client], 32);		
			GetClientName(client, g_sName[client], 32);
			
			Void_AuthClient(client);

			if(!g_bLoaded[client] && AreClientCookiesCached(client))
				Void_LoadCookies(client);
			
			if(g_bPersistentRounds)
				Void_LoadClientData(client);
		}
	}
}

Void_SaveClientData(client)
{
	new _iSize = GetArraySize(g_hArray_PlayerProps[client]);
	for(new i = 0; i < _iSize; i++)
	{
		new entity = GetArrayCell(g_hArray_PlayerProps[client], i);
		if(IsValidEntity(entity))
		{
			PushArrayCell(g_hArray_Repository, entity);

			if(g_bPersistentColors)
				SetEntityRenderColor(entity, g_iPersistentColors[0], g_iPersistentColors[1], g_iPersistentColors[2], g_iPersistentColors[3]);
			if(g_iPersistentEffect != -1)
				SetEntityRenderFx(entity, RenderFx:g_iPersistentEffect);
			ChangeEdictState(entity, FL_EDICT_CHANGED);
		}
	}
	ClearArray(g_hArray_PlayerProps[client]);

	if(KvJumpToKey(g_hKV_Repository, g_sSteam[client], true))
	{
		if(g_iPlayerProps[client] > 0)
		{
			KvSetNum(g_hKV_Repository, "UserId", GetClientUserId(client));
			KvSetNum(g_hKV_Repository, "Team", g_iTeam[client]);
		}

		if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
		{
			if(g_iDeletePublic > 0)
				KvSetNum(g_hKV_Repository, "Delete", g_iPlayerDeletes[client]);
				
			if(g_iTeleportPublic > 0)
				KvSetNum(g_hKV_Repository, "Teleport", g_iPlayerTeleports[client]);
				
			if(g_iColorPublic > 0)
				KvSetNum(g_hKV_Repository, "Color", g_iPlayerColors[client]);
		}
		else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
		{
			if(g_iDeleteAdmin > 0)
				KvSetNum(g_hKV_Repository, "Delete", g_iPlayerDeletes[client]);
				
			if(g_iTeleportAdmin > 0)
				KvSetNum(g_hKV_Repository, "Teleport", g_iPlayerTeleports[client]);
				
			if(g_iColorAdmin > 0)
				KvSetNum(g_hKV_Repository, "Color", g_iPlayerColors[client]);
		}
		else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
		{
			if(g_iDeleteSupporter > 0)
				KvSetNum(g_hKV_Repository, "Delete", g_iPlayerDeletes[client]);
				
			if(g_iTeleportSupporter > 0)
				KvSetNum(g_hKV_Repository, "Teleport", g_iPlayerTeleports[client]);
				
			if(g_iColorSupporter > 0)
				KvSetNum(g_hKV_Repository, "Color", g_iPlayerColors[client]);
		}
		KvGoBack(g_hKV_Repository);
	}
}

Void_LoadClientData(client)
{
	if (!KvGotoFirstSubKey(g_hKV_Repository))
		return;

	decl String:_sBuffer[32];
	do
	{
		KvGetSectionName(g_hKV_Repository, _sBuffer, sizeof(_sBuffer));
		if (StrEqual(_sBuffer, g_sSteam[client]))
		{
			new _iUserId = KvGetNum(g_hKV_Repository, "UserId", 0);
			g_iLastTeam[client] = KvGetNum(g_hKV_Repository, "Team", 0);

			if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
			{
				if(g_iDeletePublic > 0)	
					g_iPlayerDeletes[client] = KvGetNum(g_hKV_Repository, "Delete", 0);

				if(g_iTeleportPublic > 0)
					g_iPlayerTeleports[client] = KvGetNum(g_hKV_Repository, "Teleport", 0);

				if(g_iTeleportPublic > 0)
					g_iPlayerColors[client] = KvGetNum(g_hKV_Repository, "Color", 0);
			}
			else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
			{
				if(g_iDeleteAdmin > 0)
					g_iPlayerDeletes[client] = KvGetNum(g_hKV_Repository, "Delete", 0);
					
				if(g_iTeleportAdmin > 0)
					g_iPlayerTeleports[client] = KvGetNum(g_hKV_Repository, "Teleport", 0);
					
				if(g_iColorAdmin > 0)
					g_iPlayerColors[client] = KvGetNum(g_hKV_Repository, "Color", 0);
			}
			else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
			{
				if(g_iDeleteSupporter > 0)
					g_iPlayerDeletes[client] = KvGetNum(g_hKV_Repository, "Delete", 0);
					
				if(g_iTeleportSupporter > 0)
					g_iPlayerTeleports[client] = KvGetNum(g_hKV_Repository, "Teleport", 0);
					
				if(g_iColorAdmin > 0)
					g_iPlayerColors[client] = KvGetNum(g_hKV_Repository, "Color", 0);
			}

			if(_iUserId)
			{
				new _iStart = GetArraySize(g_hArray_Repository);
				if(_iStart)
				{
					_iStart -= 1;
					new _iCurrent = GetClientUserId(client);
					for(new i = _iStart; i >= 0; i--)
					{
						new entity = GetArrayCell(g_hArray_Repository, i);
						if(g_bProp[entity] && g_iPropUser[entity] == _iUserId)
						{
							RemoveFromArray(g_hArray_Repository, i);
							if(g_iPersistentEffect != -1)
							{
								SetEntityRenderFx(entity, RenderFx:0);
								ChangeEdictState(entity, FL_EDICT_CHANGED);
							}

							g_iPropUser[entity] = _iCurrent;
							PushArrayCell(g_hArray_PlayerProps[client], entity);
						}
					}
					
					g_iPlayerProps[client] = GetArraySize(g_hArray_PlayerProps[client]);
					if(g_iPlayerProps[client] && g_bPersistentColors)
						Void_ColorClientProps(client, g_iConfigColor[client]);
				}
			}

			KvDeleteThis(g_hKV_Repository);
		}
	} 
	while (KvGotoNextKey(g_hKV_Repository));
}

public OnClientDisconnect(client)
{
	if(g_bEnabled)
	{
		if(g_bPersistentRounds)
			Void_SaveClientData(client);
		else
			Bool_ClearClientProps(client);

		Void_ClearClientControl(client);
		Void_ClearClientTeleport(client);
		Void_ClearClientRespawn(client);
		Void_ClearClientAfk(client);
		
		if(g_iTeam[client] >= TEAM_RED)
		{
			new _iIndex = Array_Index(client, g_iTeam[client]);
			Array_Remove(_iIndex, g_iTeam[client]);
		}

		g_iTeam[client] = 0;
		g_iClass[client] = 0;
		g_iLastTeam[client] = 0;
		g_bAlive[client] = false;
		g_bReady[client] = false;
		g_bLoaded[client] = false;
		g_bActivity[client] = false;
		g_bQuickToggle[client] = false;
		g_bPlayerSpawned[client] = false;
		g_bTeleported[client] = false;
	}
}

public OnClientCookiesCached(client)
{
	if(g_bEnabled)
	{
		if(!g_bLoaded[client])
			Void_LoadCookies(client);
	}
}

public Action:OnLevelInit(const String:mapName[], String:mapEntities[2097152])
{
	g_iCurEntities = 0;
	return Plugin_Continue;
}

public OnEntityCreated(entity, const String:classname[])
{
	if(entity >= 0)
	{
		g_bProp[entity] = false;
		g_bPropGrab[entity] = false;
		g_iPropUser[entity] = 0;
		g_iCurEntities++;
	}
}

public OnEntityDestroyed(entity)
{
	if(entity >= 0)
	{
		if(g_bProp[entity])
		{
			g_bProp[entity] = false;
			if(!g_bEnding)
			{
				new client = GetClientOfUserId(g_iPropUser[entity]);
				if(client)
				{
					g_iPlayerProps[client]--;
					new _iIndex = GetEntityIndex(client, entity);
					if(_iIndex >= 0)
						RemoveFromArray(g_hArray_PlayerProps[client], _iIndex);
				}
			}
		}

		g_bPropGrab[entity] = false;
		g_iPropUser[entity] = 0;
		g_iCurEntities--;
	}
}

public OnGameFrame()
{
	if(g_bEnabled && !g_bEnding)
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(g_bHasAccess[g_iTeam[i]] && g_iConfigQuick[i] && g_iPlayerAccess[i] & g_iQuickAccess && IsClientInGame(i))
			{
				if(GetClientButtons(i) & IN_USE)
				{
					if(!g_bQuickToggle[i])
					{
						g_bQuickToggle[i] = true;
						
						switch(g_iConfigQuick[i])
						{
							case QUICK_MENU:
								Menu_Main(i);
							case QUICK_DELETE:
							{
								if(Bool_DeleteAllowed(i, true) && Bool_DeleteValid(i, true))
									Void_DeleteProp(i);
							}
							case QUICK_CLONE:
							{
								if(g_iPlayerControl[i] > 0)
									Void_SpawnClone(i, g_iPlayerControl[i]);
							}
						}
					}
				}
				else if(g_bQuickToggle[i])
					g_bQuickToggle[i] = false;	
			}
		}
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(g_bEnabled)
	{
		if(Bool_CheckAction(client))
		{
			if(!g_bActivity[client])
				if(buttons & IN_ATTACK || buttons & IN_ATTACK2 || buttons & IN_FORWARD || buttons & IN_BACK || buttons & IN_USE || buttons & IN_MOVERIGHT)
					g_bActivity[client] = true;

			if(buttons & IN_DUCK && g_iDisableCrouching & g_iPhase && !(g_iPlayerAccess[client] & g_iCrouchAccess))
			{
				PrintHintText(client, "%s%t", g_sPrefixHint, "Prevent_Player_Crouch");

				buttons &= ~IN_DUCK;
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:Event_OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		if(g_bPersistentRounds)
		{
			if(g_hKV_Repository == INVALID_HANDLE || g_hKV_Repository != INVALID_HANDLE && CloseHandle(g_hKV_Repository))
				g_hKV_Repository = CreateKeyValues("BuildWars_PropRepository");
			
			ClearArray(g_hArray_Repository);
		}
	
		g_bEnding = true;
		g_iCurrentRound++;
		g_iRedReady = 0;
		g_iBlueReady = 0;
		g_iPointsRed = 0;
		g_iPointsBlue = 0;
		g_iReadySeconds = 0;
		g_bReadyProceed = false;
		g_bInfiniteGrenades = false;

		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				Void_ClearClientControl(i);
				Void_ClearClientTeleport(i);
				Void_ClearClientRespawn(i);
				Bool_ClearClientProps(i, false);
				
				if(g_iTeam[i] == CS_TEAM_T || g_iTeam[i] == CS_TEAM_CT)
					if(g_hTimer_AfkCheck[i] != INVALID_HANDLE && CloseHandle(g_hTimer_AfkCheck[i]))
						g_hTimer_AfkCheck[i] = INVALID_HANDLE;

				g_bReady[i] = false;
				g_iPlayerProps[i] = 0;
				g_iPlayerDeletes[i] = 0;
				g_iPlayerColors[i] = 0;
				g_iPlayerTeleports[i] = 0;
				g_bPlayerSpawned[i] = false;
				g_bTeleported[i] = false;
				g_bActivity[i] = false;
			}
		}
			
		if(g_iSpawningMode != SPAWNING_DISABLED)
		{
			if(g_bSpawningIgnore)
				SetConVarInt(g_hIgnoreRound, 0);
				
			if(g_iSpawningMode == SPAWNING_TIMED)
				if(g_hTimer_StopSpawning != INVALID_HANDLE && CloseHandle(g_hTimer_StopSpawning))
					g_hTimer_StopSpawning= INVALID_HANDLE;
		}
	
		if(g_hTimer_Update != INVALID_HANDLE && CloseHandle(g_hTimer_Update))
			g_hTimer_Update = INVALID_HANDLE;

		if(g_iPhase == PHASE_SUDDEN)
		{
			if(g_hTrie_RestrictIndex != INVALID_HANDLE)
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

		if(g_bMaintainSize || (g_iScrambleRounds && GetEventInt(event, "reason") != 15))
			CreateTimer((g_fRoundRestart * 0.5), Timer_PostRoundEnd, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	return Plugin_Continue;
}

public Action:Timer_PostRoundEnd(Handle:timer)
{
	if(g_iPlayersRed && g_iPlayersBlue && ((g_iPlayersRed + g_iPlayersBlue) > 2))
	{
		if(g_iScrambleRounds && g_iCurrentRound >= (g_iScrambleRounds + g_iLastScramble))
		{
			g_iLastScramble = g_iCurrentRound;

			new Handle:_hTemp = CreateArray();
			for(new i = 0; i < g_iPlayersRed; i++)
			{
				new client = Array_Grab(TEAM_RED, i);
				PushArrayCell(_hTemp, client);
			}
			for(new i = 0; i < g_iPlayersBlue; i++)
			{
				new client = Array_Grab(TEAM_BLUE, i);
				PushArrayCell(_hTemp, client);
			}
			SortADTArray(_hTemp, Sort_Random, Sort_Integer);
			
			new bool:_bTemp, _iTemp = ((g_iPlayersRed + g_iPlayersBlue) - 1);
			for(new i = 0; i <= _iTemp; i++)
			{
				new client = GetArrayCell(_hTemp, i);
				if(_bTemp)
				{
					if(g_iTeam[client] != TEAM_RED)
						Void_Switch(client, TEAM_RED);
				}
				else
				{
					if(g_iTeam[client] != TEAM_BLUE)
						Void_Switch(client, TEAM_BLUE);
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
						Void_Switch(Array_Grab(TEAM_RED, GetRandomInt(0, (g_iPlayersRed - 1))), TEAM_BLUE);
				} 
			}
			else if(g_iPlayersBlue > g_iPlayersRed)
			{
				new _iDiff = g_iPlayersBlue - g_iPlayersRed;
				if(_iDiff > g_iLimitTeams)
				{
					_iDiff = (GetRandomInt(0, 1)) ? RoundToFloor(float(_iDiff) / 2.0) : RoundToCeil(float(_iDiff) / 2.0);
					for(new i = 1; i <= _iDiff; i++)
						Void_Switch(Array_Grab(TEAM_BLUE, GetRandomInt(0, (g_iPlayersBlue - 1))), TEAM_RED);
				}
			}
		}
	}
}

public Action:Event_OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		g_bEnding = false;
		g_iNumSeconds = 0;
		g_iUniqueProp = 0;
		g_iCurrentDisable = 0;
		g_bSpawningAllowed = true;
		
		if(g_iSpawningMode != SPAWNING_DISABLED)
		{
			if(g_bSpawningIgnore)
				SetConVarInt(g_hIgnoreRound, 1);

			if(g_iSpawningMode == SPAWNING_TIMED)
			{
				g_fSpawnRemaining = 0.0;
				g_hTimer_StopSpawning = CreateTimer(1.0, Timer_StopSpawning, _, TIMER_REPEAT);
			}

			for(new i = 1; i <= MaxClients; i++)
			{
				if(g_iTeam[i] >= TEAM_RED && !g_bAlive[i] && IsClientInGame(i))
				{
					if(!g_iClass[i])
						g_iClass[i] = g_iTeam[i] == TEAM_RED ? GetRandomInt(1, 4) : GetRandomInt(5, 8);

					CS_RespawnPlayer(i);
				}
			}
		}
			
		g_hTimer_Update = CreateTimer(1.0, Timer_Update, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		if(g_iCurrentMap != -1)
		{
			g_iPhase = PHASE_BUILD;
			g_iCurrentDisable = g_iBuildDisable;

			g_iWallEntities = 0;
			ClearArray(g_hArray_MapEntities);

			decl String:_sName[64];			
			for(new i = MaxClients; i <= MaxEntities; i++)
			{
				if(IsValidEntity(i) && IsValidEdict(i))
				{
					GetEntPropString(i, Prop_Data, "m_iName", _sName, 64);
					if(StrEqual(_sName, g_sDefinedMapIdens[g_iCurrentMap], false))
					{
						g_iWallEntities++;

						PushArrayCell(g_hArray_MapEntities, i);
						if(StrEqual(g_sDefinedMapTypes[g_iCurrentMap], "Disable", false))
							AcceptEntityInput(i, "Enable");
					}
				}
			}
		}
		else
		{
			g_iPhase = PHASE_NONE;
			g_iCurrentDisable = g_iNoneDisable;
		}
	}

	return Plugin_Continue;
}

public Action:Timer_StopSpawning(Handle:timer)
{
	g_fSpawnRemaining += 1.0;
	if(g_fSpawnRemaining > g_fSpawnDuration)
	{
		g_hTimer_StopSpawning = INVALID_HANDLE;
		g_bSpawningAllowed = false;
		
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action:Event_OnPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(!client || !IsClientInGame(client))
			return Plugin_Continue;
		
		g_iTeam[client] = GetEventInt(event, "team");
		if(g_iTeam[client] == TEAM_SPEC)
		{
			if(g_iDisableRadar)
				Void_ShowRadar(client);

			g_bAlive[client] = false;
		}

		if(g_bHasAccess[g_iTeam[client]])
		{
			new _iOld = GetEventInt(event, "oldteam");
			if(g_iTeam[client] != _iOld)
			{
				Array_Remove(Array_Index(client, _iOld), _iOld);
				Array_Push(client, g_iTeam[client]);
			}
		
			if(_iOld == TEAM_NONE)
			{
				if(g_fAdvert >= 0.0)
					CreateTimer(g_fAdvert, Timer_Announce, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

				if(g_iTeam[client] > TEAM_SPEC)
				{
					Void_ClearClientAfk(client);

					if(g_iPhase == PHASE_BUILD && (g_bSpawningBuild || g_iSpawningMode) && g_bSpawningAllowed)
						g_hTimer_RespawnPlayer[client] = CreateTimer(g_fSpawningDelay, Timer_SpawnPlayer, client);

					if((g_bPersistentRounds && g_iLastTeam[client] != g_iTeam[client]))
						Bool_ClearClientProps(client);
				}
			}
			else
			{
				Void_ClearClientControl(client);
				Void_ClearClientTeleport(client);
				Void_ClearClientRespawn(client);

				if(g_iTeam[client] != TEAM_SPEC)
				{
					if(g_bAfk[client] && g_bAfkReturn)
						g_bReturning[client] = true;

					Void_ClearClientAfk(client);

					if(!g_bPersistentRounds || (g_bPersistentRounds && g_iLastTeam[client] != g_iTeam[client]))
						Bool_ClearClientProps(client);
				}
				else
				{
					g_iLastTeam[client] = _iOld;
					if(!g_bPersistentRounds)
						Bool_ClearClientProps(client);
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
		if(!client || !IsClientInGame(client) || g_iTeam[client] < TEAM_RED)
			return Plugin_Continue;

		g_bAlive[client] = true;
		if(g_bHasAccess[g_iTeam[client]])
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
			
			if(g_iSpawningMode == SPAWNING_SINGLES && !g_bPlayerSpawned[client])
			{
				g_bPlayerSpawned[client] = true;
				g_iPlayerSpawns[client] = g_iTotalSpawns;
			}

			if(g_bAfkEnable && (g_iPhase == PHASE_NONE || g_iPhase == PHASE_BUILD))
			{
				if(g_bReturning[client])
				{
					PrintCenterText(client, "%s%t", g_sPrefixCenter, "Afk_Notify_Return", client);
					g_bReturning[client] = false;
				}

				g_bActivity[client] = false;
				if(g_hTimer_AfkCheck[client] != INVALID_HANDLE)
				{
					CloseHandle(g_hTimer_AfkCheck[client]);
					g_hTimer_AfkCheck[client] = INVALID_HANDLE;
				}

				g_hTimer_AfkCheck[client] = CreateTimer(g_fAfkDelay, Timer_CheckAfk, client, TIMER_FLAG_NO_MAPCHANGE);
			}

			if(g_iDisableRadar)
			{
				if(g_iDisableRadar & g_iPhase && !(g_iPlayerAccess[client] & g_iRadarAccess))
					Void_HideRadar(client);
				else
					Void_ShowRadar(client);
			}
		}
	}
		
	return Plugin_Continue;
}

public Action:Timer_CheckSpawn(Handle:timer, any:client)
{
	if(g_bAlive[client])
		g_hTimer_RespawnPlayer[client] = INVALID_HANDLE;
	else
	{
		if(g_fSpawningDelay)
		{
			g_fSpawningRemaining[client] = g_fSpawningDelay;
			PrintCenterText(client, "%t", "Spawning_Delay_Notify", g_fSpawningRemaining[client]);

			g_hTimer_RespawnPlayer[client] = CreateTimer(1.0, Timer_SpawnNotify, client, TIMER_REPEAT);
		}
		else
			Void_SpawnPlayer(client);
	}
}

Void_SpawnPlayer(client)
{
	if(g_bSpawningAllowed && !g_bAlive[client] && g_iTeam[client] >= TEAM_RED)
		CS_RespawnPlayer(client);
}

public Action:Timer_SpawnNotify(Handle:timer, any:client)
{
	if(g_bAlive[client])
		g_hTimer_RespawnPlayer[client] = INVALID_HANDLE;
	else
	{
		g_fSpawningRemaining[client] -= 1.0;
		if(g_fSpawningRemaining[client] <= 0.0)
		{
			g_hTimer_RespawnPlayer[client] = INVALID_HANDLE;
			Void_SpawnPlayer(client);
		}
		else
		{
			PrintCenterText(client, "%t", "Spawning_Delay_Notify", g_fSpawningRemaining[client]);
			return Plugin_Continue;
		}
	}

	return Plugin_Stop;
}

public Action:Event_OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(!client || !IsClientInGame(client))
			return Plugin_Continue;

		g_bAlive[client] = false;
		if(!g_bEnding && g_bHasAccess[g_iTeam[client]])
		{
			Void_ClearClientControl(client);
			Void_ClearClientTeleport(client);
			if(g_iDisableRadar)
				Void_ShowRadar(client);

			switch(g_iPhase)
			{
				case PHASE_BUILD:
				{
					if(g_bSpawningAllowed && (g_bSpawningBuild || g_iSpawningMode) && g_iClass[client])
						g_hTimer_RespawnPlayer[client] = CreateTimer(0.1, Timer_CheckSpawn, client);
				}
				case PHASE_WAR:
				{
					new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
					if(attacker && attacker <= MaxClients)
					{
						switch(g_iTeam[attacker])
						{
							case TEAM_RED:
								g_iPointsRed += POINTS_KILL;
							case TEAM_BLUE:
								g_iPointsBlue += POINTS_KILL;
						}
					}

					switch(g_iSpawningMode)
					{
						case SPAWNING_TEAMS:
						{
							switch(g_iTeam[client])
							{
								case TEAM_RED:
								{
									g_iPointsRed += POINTS_DEATH;
									if(g_bSpawningAllowed)
									{
										g_iRedSpawns--;
										if(g_iRedSpawns > 0 && g_iClass[client])
											g_hTimer_RespawnPlayer[client] = CreateTimer(0.1, Timer_CheckSpawn, client);
									}									
								}
								case TEAM_BLUE:
								{
									g_iPointsBlue += POINTS_DEATH;
									if(g_bSpawningAllowed)
									{
										g_iBlueSpawns--;
										if(g_bSpawningAllowed && g_iBlueSpawns > 0 && g_iClass[client])
											g_hTimer_RespawnPlayer[client] = CreateTimer(0.1, Timer_CheckSpawn, client);
									}
								}
							}
						}
						case SPAWNING_SINGLES:
						{
							switch(g_iTeam[client])
							{
								case TEAM_RED:
								{
									g_iPointsRed += POINTS_DEATH;
									if(g_bSpawningAllowed)
										g_iRedSpawns--;
								}
								case TEAM_BLUE:
								{
									g_iPointsBlue += POINTS_DEATH;
									if(g_bSpawningAllowed)
										g_iBlueSpawns--;
								}
							}

							if(g_bSpawningAllowed)
							{
								g_iPlayerSpawns[client]--;
								if(g_iPlayerSpawns[client] > 0 && g_iClass[client])
									g_hTimer_RespawnPlayer[client] = CreateTimer(0.1, Timer_CheckSpawn, client);
							}
						}
						case SPAWNING_TIMED:
						{
							if(g_bSpawningAllowed && g_iClass[client])
								g_hTimer_RespawnPlayer[client] = CreateTimer(0.1, Timer_CheckSpawn, client);
						}
					}
				}
				case PHASE_SUDDEN:
				{
					new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
					if(attacker && attacker <= MaxClients)
					{
						switch(g_iTeam[attacker])
						{
							case TEAM_RED:
								g_iPointsRed += POINTS_KILL;
							case TEAM_BLUE:
								g_iPointsBlue += POINTS_KILL;
						}
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
		if(!g_bEnding && g_bInfiniteGrenades)
		{
			new userid = GetEventInt(event,"userid");
			CreateTimer(0.5, Timer_InfiniteGrenades, userid, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action:Timer_InfiniteGrenades(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(!g_bEnding && g_bAlive[client] && IsClientInGame(client))
	{
		GivePlayerItem(client, "weapon_hegrenade");
	}
}

public Action:Event_OnPlayerName(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(client && IsClientInGame(client))
		{
			GetEventString(event, "newname", g_sName[client], 32);
			new _iSize = GetArraySize(g_hArray_PlayerProps[client]);
			for(new i = 0; i < _iSize; i++)
			{
				new entity = GetArrayCell(g_hArray_PlayerProps[client], i);
				if(IsValidEntity(entity))
					Format(g_sPropOwner[entity], 32, "%s", g_sName[client]);
			}
		}
	}
}

public Event_PlayerBlind(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		if(g_iDisableRadar)
		{
			new userid = GetEventInt(event, "userid");
			new client = GetClientOfUserId(userid);
			if(client && IsClientInGame(client) && g_iTeam[client] >= TEAM_RED)
				CreateTimer(GetEntDataFloat(client, g_iFlashDuration), Timer_FlashEnd, userid, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action:Command_Say(client, const String:command[], argc)
{
	if(g_bEnabled)
	{
		if(!client || !IsClientInGame(client) || !g_bHasAccess[g_iTeam[client]])
			return Plugin_Handled;
		else if(!g_bEnding)
		{
			new String:_sTrigger[2][64];
			decl _iIndex, String:_sText[192];
			GetCmdArgString(_sText, 192);
			StripQuotes(_sText);
			TrimString(_sText);
			
			ExplodeString(_sText, " ", _sTrigger, 2, 64);
			new _iSize = strlen(_sTrigger[0]);
			for (new i = 0; i < _iSize; i++)
				if (IsCharAlpha(_sTrigger[0][i]) && IsCharUpper(_sTrigger[0][i]))
					_sTrigger[0][i] = CharToLower(_sTrigger[0][i]);

			if(GetTrieValue(g_hTrie_PlayerCommands, _sTrigger[0], _iIndex))
			{
				switch(_iIndex)
				{
					case COMMAND_MENU:
					{
						if(StrEqual(_sTrigger[1], ""))
							Menu_Main(client);
						else
						{
							if(Bool_SpawnAllowed(client, true) && Bool_SpawnValid(client, true, true))
							{
								new _iProp = StringToInt(_sTrigger[1]);
								if((_iProp >= 0 || _iProp < g_iNumProps) && g_iDefinedPropAccess[_iProp] & g_iPlayerAccess[client])
									Void_SpawnChat(client, _iProp);
							}
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
						if(!StrEqual(_sTrigger[1], "") && g_iAdminAccess[client] & ADMIN_DELETE)
						{
							new _iEntity = (StringToInt(_sTrigger[1]) > 0) ? StringToInt(_sTrigger[1]) : Trace_GetEntity(client);
							if(_iEntity && Entity_Valid(_iEntity))
							{
								PrintCenterText(client, "%s%t", g_sPrefixCenter, "Notify_Succeed_Delete");
								Void_DeleteProp(client, _iEntity);
							}

							return Plugin_Handled;
						}
						else if(Bool_DeleteAllowed(client, true) && Bool_DeleteValid(client, true))
							Void_DeleteProp(client);
					}
					case COMMAND_CONTROL:
					{
						if(g_iPlayerControl[client] > 0)
							Void_ClearClientControl(client);
						else if(Bool_ControlValid(client, true))
						{
							new entity = Trace_GetEntity(client, g_fGrabDistance);
							if(Entity_Valid(entity))
								Void_IssueGrab(client, entity);

							Menu_Control(client);
						}
					}
					case COMMAND_CHECK:
					{
						if(Bool_CheckValid(client, true))
							Void_CheckProp(client);
					}
					case COMMAND_TELE:
					{
						if(!StrEqual(_sTrigger[1], "") && g_iAdminAccess[client] & ADMIN_TELEPORT)
						{
							new _iTarget = FindTarget(client, _sTrigger[1], true, true);
							if(!_iTarget || !IsClientInGame(_iTarget))
								CPrintToChat(client, "%s%t", g_sPrefixChat, "Admin_Locate_Failure");
							else if(!CanUserTarget(client, _iTarget))
								CPrintToChat(client, "%s%t", g_sPrefixChat, "Admin_Target_Failure");
							else
								Menu_AdminConfirmTeleport(client, TARGET_SINGLE, GetClientUserId(_iTarget));

							return Plugin_Handled;
						}
						else if(Bool_TeleportAllowed(client, true) && Bool_TeleportValid(client, true))
							Void_PerformTeleport(client);
					}
					case COMMAND_HELP:
					{
						if(g_bHelp)
						{
							decl String:_sBuffer[192];
							Format(_sBuffer, 192, "%T", "Command_Help_Url_Title", client);
							ShowMOTDPanel(client, _sBuffer, g_sHelp, MOTDPANEL_TYPE_URL);
						}
					}
					case COMMAND_READY:
					{
						if(g_bReadyEnable && g_iTeam[client] >= TEAM_RED && g_iPhase == PHASE_BUILD)
						{
							if(!g_bReady[client])
							{
								if(!g_iReadyWait || g_iNumSeconds >= g_iReadyWait)
								{
									if((g_iPlayersRed + g_iPlayersBlue) >= g_iReadyMinimum)
									{
										g_bReady[client] = true;

										if(g_iTeam[client] == TEAM_RED)
											g_iRedReady++;
										else
											g_iBlueReady++;
										
										CPrintToChatAll("%s%T", g_sPrefixChat, "Ready_Notify_Chat", LANG_SERVER, client);
									}
									else
										CPrintToChat(client, "%s%t", g_sPrefixChat, "Ready_Player_Lacking", g_iReadyMinimum);
								}
								else
									CPrintToChat(client, "%s%t", g_sPrefixChat, "Ready_Must_Wait", (g_iReadyWait - g_iNumSeconds));
							}
							else
								CPrintToChat(client, "%s%t", g_sPrefixChat, "Ready_Notify_Ready", (g_iRedReady + g_iBlueReady), g_iReadyAmount);
						}
					}
					case COMMAND_CLEAR:
					{
						if(!StrEqual(_sTrigger[1], "") && g_iAdminAccess[client] & ADMIN_DELETE)
						{
							new _iTarget = FindTarget(client, _sTrigger[1], true, true);
							if(!_iTarget || !IsClientInGame(_iTarget))
								CPrintToChat(client, "%s%t", g_sPrefixChat, "Admin_Locate_Failure");
							else if(!CanUserTarget(client, _iTarget))
								CPrintToChat(client, "%s%t", g_sPrefixChat, "Admin_Target_Failure");
							else
								Menu_AdminConfirmDelete(client, TARGET_SINGLE, GetClientUserId(_iTarget));

							return Plugin_Handled;
						}
						else if(Bool_DeleteAllowed(client, true, true) && Bool_ClearValid(client, true))
							Menu_ConfirmDelete(client);
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
	if(g_bEnabled && g_iDisableSuicide & g_iPhase)
	{
		if(g_bAlive[client] && client && IsClientInGame(client))
		{
			CPrintToChat(client, "%s%t", g_sPrefixChat, "Prevent_Player_Suicide");
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action:Command_Join(client, const String:command[], argc)
{
	if(g_bEnabled)
	{
		if(client && IsClientInGame(client))
		{
			decl String:_sTemp[3];
			GetCmdArg(1, _sTemp, sizeof(_sTemp));
			new _iTemp = StringToInt(_sTemp);

			if(!_iTemp || _iTemp == g_iTeam[client])
				return Plugin_Handled;
			else
				g_iClass[client] = 0;
		}
	}
	
	return Plugin_Continue;
}

public Action:Command_Class(client, const String:command[], argc)
{
	if(g_bEnabled && client && IsClientInGame(client))
	{
		if(client && IsClientInGame(client))
		{
			decl String:_sTemp[3];
			GetCmdArg(1, _sTemp, sizeof(_sTemp));
			new _iTemp = StringToInt(_sTemp);
			
			if(!g_iClass[client])
			{
				g_iClass[client] = (_iTemp > 0) ? _iTemp : (g_iTeam[client] == CS_TEAM_T) ? GetRandomInt(1, 4) : GetRandomInt(5, 8);
				
				if(!g_bEnding && g_iSpawningMode != SPAWNING_DISABLED)
				{
					if(g_bSpawningIgnore && g_iPlayersRed == 1 && g_iPlayersBlue == 1)
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

				if(g_bSpawningAllowed)
				{
					switch(g_iPhase)
					{
						case PHASE_BUILD:
						{
							if(g_bSpawningBuild || g_iSpawningMode || g_bReturning[client])
								g_hTimer_RespawnPlayer[client] = CreateTimer(0.1, Timer_CheckSpawn, client);
						}
						case PHASE_WAR:
						{
							switch(g_iSpawningMode)
							{
								case SPAWNING_TEAMS:
								{
									switch(g_iTeam[client])
									{
										case TEAM_RED:
										{
											if(g_iRedSpawns > 0)
												g_hTimer_RespawnPlayer[client] = CreateTimer(0.1, Timer_CheckSpawn, client);											
										}
										case TEAM_BLUE:
										{
											if(g_iBlueSpawns > 0)
												g_hTimer_RespawnPlayer[client] = CreateTimer(0.1, Timer_CheckSpawn, client);
										}
									}
								}
								case SPAWNING_SINGLES:
								{
									if(g_iPlayerSpawns[client] > 0)
										g_hTimer_RespawnPlayer[client] = CreateTimer(0.1, Timer_CheckSpawn, client);
								}
								case SPAWNING_TIMED:
								{
									g_hTimer_RespawnPlayer[client] = CreateTimer(0.1, Timer_CheckSpawn, client);
								}
							}
						}
					}
				}
			}
			else if(g_bAlive[client] && g_iDisableSuicide & g_iPhase)
			{
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Prevent_Suicide");
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
		if(!g_iAfkImmunity || !(g_iPlayerAccess[client] & g_iAfkImmunity))
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
	if(g_bEnabled && g_iDisableRadio & g_iPhase)
	{
		if(client && IsClientInGame(client))
		{
			CPrintToChat(client, "%s%t", g_sPrefixChat, "Prevent_Player_Radio");
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action:Entity_OnTakeDamage(entity, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(g_bEnabled)
	{
		if(g_bProp[entity] && g_iPhase == PHASE_SUDDEN)
		{
		
		}
		else
			SDKUnhook(entity, SDKHook_OnTakeDamage, Entity_OnTakeDamage);
	}
	
	return Plugin_Continue;
}

public Action:Hook_OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(g_bEnabled)
	{
		if(0 < client <= MaxClients)
		{
			if(damagetype == DMG_FALL)
			{
				if(g_iDisableFalling & g_iPhase)
				{
					damage = 0.0;
					return Plugin_Changed;
				}
			}
			else if(0 < attacker < MaxClients)
			{
				if(g_iPhase == PHASE_NONE || g_iPhase == PHASE_BUILD)
				{
					if(g_iTeam[client] != g_iTeam[attacker])
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

public Hook_PostThinkPost(entity)
{
	if(g_bEnabled)
	{
		if(Bool_CheckAction(entity))
		{
			if(g_iPhase == PHASE_BUILD)
			{
				if(g_bAlwaysBuyzone)
					SetEntProp(entity, Prop_Send, "m_bInBuyZone", 1);
			}
			else
				SetEntProp(entity, Prop_Send, "m_bInBuyZone", 0);

			if(g_iDisableDrowning & g_iPhase)
			{
				if(GetEntProp(entity, Prop_Data, "m_nWaterLevel"))
				{
					SetEntityFlags(entity, GetEntityFlags(entity) &~ FL_INWATER);
					SetEntProp(entity, Prop_Send, "m_nWaterLevel", 1);
				}
			}
		}
	}
}

public Action:Hook_WeaponCanUse(client, weapon)
{
	if(g_bEnabled)
	{
		if(g_iPhase == PHASE_SUDDEN)
		{
			decl String:_sBuffer[32];
			GetEdictClassname(weapon, _sBuffer, 32);
			if(!StrEqual(_sBuffer, g_sModeWeapon) && !StrEqual(_sBuffer, "weapon_knife"))
				return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

Void_IssueGrab(client, entity)
{
	new _iOwner = GetClientOfUserId(g_iPropUser[entity]);
	if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
	{
		if(_iOwner && _iOwner == client)
		{
			for(new target = 1; target <= MaxClients; target++)
			{
				if(target != client && g_iPlayerControl[target] > 0 && g_iPlayerControl[target] == entity)
				{
					CPrintToChat(client, "%s%t", g_sPrefixChat, "Control_Prop_Taken", g_sDefinedPropNames[g_iPropType[entity]]);
					return;
				}
			}
		}
		else
		{
			PrintHintText(client, "%s%t", g_sPrefixHint, "Control_Prop_Failure", g_sDefinedPropNames[g_iPropType[entity]], g_sPropOwner[entity]);
			return;
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
	{
		for(new target = 1; target <= MaxClients; target++)
		{
			if(target != client && g_iPlayerControl[target] > 0 && g_iPlayerControl[target] == entity)
			{
				if(g_iPlayerAccess[target] & ACCESS_ADMIN)
				{
					CPrintToChat(client, "%s%t", g_sPrefixChat, "Control_Prop_Taken_Already", g_sDefinedPropNames[g_iPropType[entity]]);
					return;
				}
				else
				{
					CPrintToChat(target, "%s%t", g_sPrefixChat, "Control_Prop_Take_Away", g_sDefinedPropNames[g_iPropType[entity]]);
					CPrintToChat(client, "%s%t", g_sPrefixChat, "Control_Prop_Taken_Away", g_sDefinedPropNames[g_iPropType[entity]], g_sName[target]);
					Void_ClearClientControl(target);
				}
			}
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
	{
		if(_iOwner && _iOwner == client)
		{
			for(new target = 1; target <= MaxClients; target++)
			{
				if(target != client && g_iPlayerControl[target] > 0 && g_iPlayerControl[target] == entity)
				{
					CPrintToChat(target, "%s%t", g_sPrefixChat, "Control_Prop_Taken", g_sDefinedPropNames[g_iPropType[entity]]);
					return;
				}
			}
		}
		else
		{
			PrintHintText(client, "%s%t", g_sPrefixHint, "Control_Prop_Failure", g_sDefinedPropNames[g_iPropType[entity]], g_sPropOwner[entity]);
			return;
		}
	}

	g_hTimer_UpdateControl[client] = CreateTimer(g_fGrabUpdate, Timer_UpdateControl, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerControl[client] = entity;

	g_bPropGrab[g_iPlayerControl[client]] = true;
	if(g_bGrabBlock)
	{
		SetEntityRenderFx(g_iPlayerControl[client], RenderFx:4);
		SetEntProp(g_iPlayerControl[client], Prop_Data, "m_CollisionGroup", 1);
		ChangeEdictState(g_iPlayerControl[client], FL_EDICT_CHANGED);
	}
}

Void_ClearClientControl(client)
{
	if(g_iPlayerControl[client] != -1)
	{
		g_bPropGrab[g_iPlayerControl[client]] = false;
		if(g_bGrabBlock && IsValidEntity(g_iPlayerControl[client]))
		{
			SetEntityRenderFx(g_iPlayerControl[client], RenderFx:0);
			SetEntProp(g_iPlayerControl[client], Prop_Data, "m_CollisionGroup", 5);
			ChangeEdictState(g_iPlayerControl[client], FL_EDICT_CHANGED);
		}

		g_iPlayerControl[client] = -1;
	}

	if(g_hTimer_UpdateControl[client] != INVALID_HANDLE && CloseHandle(g_hTimer_UpdateControl[client]))
		g_hTimer_UpdateControl[client] = INVALID_HANDLE;
}

Void_ClearClientTeleport(client)
{
	g_bTeleporting[client] = false;
	if(g_hTimer_TeleportPlayer[client] != INVALID_HANDLE && CloseHandle(g_hTimer_TeleportPlayer[client]))
		g_hTimer_TeleportPlayer[client] = INVALID_HANDLE;
}

Void_ClearClientRespawn(client)
{
	if(g_hTimer_RespawnPlayer[client] != INVALID_HANDLE && CloseHandle(g_hTimer_RespawnPlayer[client]))
		g_hTimer_RespawnPlayer[client] = INVALID_HANDLE;
}

Void_ClearClientAfk(client)
{
	g_bAfk[client] = false;
	if(g_hTimer_AfkCheck[client] != INVALID_HANDLE && CloseHandle(g_hTimer_AfkCheck[client]))
		g_hTimer_AfkCheck[client] = INVALID_HANDLE;
}

public Action:Timer_UpdateControl(Handle:timer, any:client)
{
	if(!IsClientInGame(client) || g_iPlayerControl[client] <= 0 || !g_bProp[g_iPlayerControl[client]])
	{
		g_hTimer_UpdateControl[client] = INVALID_HANDLE;
		Void_ClearClientControl(client);

		return Plugin_Stop;
	}
	
	decl Float:g_fDirection[3], Float:_fPosition[3], Float:_fAngles[3], Float:_fOriginal[3];
	GetClientEyeAngles(client, _fAngles);
	GetClientEyePosition(client, _fPosition);
	GetAngleVectors(_fAngles, g_fDirection, NULL_VECTOR, NULL_VECTOR);

	_fPosition[0] += g_fDirection[0] * g_fConfigDistance[client];
	_fPosition[1] += g_fDirection[1] * g_fConfigDistance[client];
	_fPosition[2] += g_fDirection[2] * g_fConfigDistance[client];

	if(g_bPosSnapAllowed)
	{
		GetEntPropVector(g_iPlayerControl[client], Prop_Send, "m_vecOrigin", _fOriginal);
		_fPosition[0] = g_bConfigAxis[client][POSITION_AXIS_X] ? _fOriginal[0] : float(RoundToNearest(_fPosition[0] / g_fDefinedPositions[g_iConfigPosition[client]])) * g_fDefinedPositions[g_iConfigPosition[client]];
		_fPosition[1] = g_bConfigAxis[client][POSITION_AXIS_Y] ? _fOriginal[1] : float(RoundToNearest(_fPosition[1] / g_fDefinedPositions[g_iConfigPosition[client]])) * g_fDefinedPositions[g_iConfigPosition[client]];
		_fPosition[2] = g_bConfigAxis[client][POSITION_AXIS_Z] ? _fOriginal[2] : float(RoundToNearest(_fPosition[2] / g_fDefinedPositions[g_iConfigPosition[client]])) * g_fDefinedPositions[g_iConfigPosition[client]];
	}
	
	GetEntPropVector(g_iPlayerControl[client], Prop_Data, "m_angRotation", _fOriginal);	
	if(g_bRotSnapAllowed)
	{
		_fAngles[0] = g_bConfigAxis[client][ROTATION_AXIS_X] ? _fOriginal[0] : float(RoundToNearest(_fAngles[0] / g_fDefinedRotations[g_iConfigRotation[client]])) * g_fDefinedRotations[g_iConfigRotation[client]];
		_fAngles[1] = g_bConfigAxis[client][ROTATION_AXIS_Y] ? _fOriginal[1] : float(RoundToNearest(_fAngles[1] / g_fDefinedRotations[g_iConfigRotation[client]])) * g_fDefinedRotations[g_iConfigRotation[client]];
		_fAngles[2] = _fOriginal[2];
	}
	else
	{			
		_fAngles[0] = _fOriginal[0];
		_fAngles[1] = _fOriginal[1];
		_fAngles[2] = _fOriginal[2];
	}
	
	TeleportEntity(g_iPlayerControl[client], _fPosition, _fAngles, NULL_VECTOR);
	return Plugin_Continue;
}

public Action:Timer_Announce(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(client && IsClientInGame(client))
		CPrintToChat(client, "%s%t", g_sPrefixChat, "Welcome_Advert", g_sName[client]);
	
	return Plugin_Handled;
}

public Action:Timer_Update(Handle:timer)
{
	if(g_iPlayersRed >= 1 && g_iPlayersBlue >= 1)
		g_iNumSeconds++;
	else
	{
		g_iNumSeconds = 0;
		g_iPhase = PHASE_BUILD;
	}

	new bool:_bPhaseReady = false;
	switch(g_iPhase)
	{
		case PHASE_BUILD:
		{
			if(g_iSpawningMode != SPAWNING_DISABLED)
			{
				switch(g_iSpawningMode)
				{
					case SPAWNING_TEAMS:
					{
						new _iRedBuffer = (g_iTotalSpawns * g_iPlayersRed);
						if(_iRedBuffer > g_iRedSpawns)
							g_iRedSpawns = (g_iPlayersRed >= 1) ? _iRedBuffer : g_iTotalSpawns;

						new _iBlueBuffer = (g_iTotalSpawns * g_iPlayersBlue);
						if(_iBlueBuffer > g_iBlueSpawns)
							g_iBlueSpawns = (g_iPlayersBlue >= 1) ? _iBlueBuffer : g_iTotalSpawns;
					}
					case SPAWNING_SINGLES:
					{
						new _iRedBuffer = (g_iTotalSpawns * g_iPlayersRed);
						if(_iRedBuffer > g_iRedSpawns)
							g_iRedSpawns = (g_iPlayersRed >= 1) ? _iRedBuffer : 0;

						new _iBlueBuffer = (g_iTotalSpawns * g_iPlayersBlue);
						if(_iBlueBuffer > g_iBlueSpawns)
							g_iBlueSpawns = (g_iPlayersBlue >= 1) ? _iBlueBuffer : 0;
					}
				}
			}
			
			if(g_bSpawningAppear && !(g_iNumSeconds % g_iSpawningRefresh))
			{
				for(new i = 0; i <= g_iNumRedSpawns; i++)
				{
					for(new j = 1; j <= MaxClients; j++)
					{
						if((g_iTeam[j] == TEAM_RED || g_iTeam[j] == TEAM_SPEC) && IsClientInGame(j))
						{
							TE_SetupGlowSprite(g_fRedTeleports[i], g_iSpriteRed, g_fSpawningRefresh, 1.0, 255);
							TE_SendToClient(j);
						}
					}
				}

				for(new i = 0; i <= g_iNumBlueSpawns; i++)
				{
					for(new j = 1; j <= MaxClients; j++)
					{
						if((g_iTeam[j] == TEAM_BLUE || g_iTeam[j] == TEAM_SPEC) && IsClientInGame(j))
						{
							TE_SetupGlowSprite(g_fBlueTeleports[i], g_iSpriteBlue, g_fSpawningRefresh, 1.0, 255);
							TE_SendToClient(j);
						}
					}
				}
			}

			if(g_bReadyEnable && g_iWallEntities)
			{
				new _iTotal = (g_iPlayersRed + g_iPlayersBlue);
				g_iReadyAmount = _iTotal >= 1 ? RoundToNearest(float(_iTotal) * g_fReadyPercent) : MaxClients;
				if(g_iReadyAmount < g_iReadyMinimum)
					g_iReadyAmount = g_iReadyMinimum;

				if((g_iBlueReady + g_iRedReady) >= g_iReadyAmount && _iTotal >= g_iReadyMinimum)
				{
					if(!g_iReadyDelay)
						_bPhaseReady = true;
					else
					{
						if(!g_iReadySeconds)
						{
							if(!g_bReadyProceed)
							{
								g_bReadyProceed = true;
								g_iReadySeconds = g_iReadyDelay;
								CPrintToChatAll("%s%T", g_sPrefixChat, "Ready_Notify_Begin", LANG_SERVER, g_iReadyDelay);
							}
							else
								_bPhaseReady = true;
						}
						else
							g_iReadySeconds--;
					}
				}
			}

			if(g_iBuildDuration && g_iNumSeconds > g_iBuildDuration)
				_bPhaseReady = true;

			if(_bPhaseReady)
			{
				g_iNumSeconds = 0;
				if(g_iWallEntities && g_iCurrentMap != -1)
					for(new i = 0; i < g_iWallEntities; i++)
						AcceptEntityInput(GetArrayCell(g_hArray_MapEntities, i), g_sDefinedMapTypes[g_iCurrentMap]);

				g_iPhase = PHASE_WAR;
				g_iCurrentDisable = g_iWarDisable;
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i))
					{					
						CPrintToChat(i, "%s%t", g_sPrefixChat, "War_Start_Notice_Chat");
						PrintCenterText(i, "%s%t", g_sPrefixCenter, "War_Start_Notice_Center");
						
						if(g_iDisableRadar)
						{
							if(g_iDisableRadar & g_iPhase && !(g_iPlayerAccess[i] & g_iRadarAccess))
								Void_HideRadar(i);
							else
								Void_ShowRadar(i);
						}

						CancelClientMenu(i, true);

						if(!(g_iPlayerAccess[i] & ACCESS_ADMIN) && (!Bool_CheckAction(i) || g_iCurrentDisable & COMMAND_CONTROL))
							Void_ClearClientControl(i);
					}
				}
			}
		}
		case PHASE_WAR:
		{
			if(g_bSpawningIgnore && g_iSpawningMode != SPAWNING_DISABLED && g_iSpawningMode != SPAWNING_TIMED)
			{
				g_hTimer_Update = INVALID_HANDLE;
				
				if(g_iPointsRed > g_iPointsBlue)
				{
					CS_TerminateRound(g_fRoundRestart, CSRoundEnd_TerroristWin);
					SetTeamScore(TEAM_RED, (GetTeamScore(TEAM_RED) + 1));
				}
				else if(g_iPointsBlue > g_iPointsRed)
				{
					CS_TerminateRound(g_fRoundRestart, CSRoundEnd_CTWin);
					SetTeamScore(TEAM_BLUE, (GetTeamScore(TEAM_BLUE) + 1));
				}
				else
				{
					CS_TerminateRound(g_fRoundRestart, CSRoundEnd_Draw);
					SetTeamScore(TEAM_RED, (GetTeamScore(TEAM_RED) + 1));
					SetTeamScore(TEAM_BLUE, (GetTeamScore(TEAM_BLUE) + 1));
				}

				return Plugin_Stop;
			}

			if(g_iWarDuration && g_iNumSeconds > g_iWarDuration && g_bSuddenDeath)
				_bPhaseReady = true;

			if(_bPhaseReady)
			{
				g_iNumSeconds = 0;
				g_iPhase = PHASE_SUDDEN;
				g_iCurrentDisable = g_iSuddenDisable;
				
				g_bSpawningAllowed = false;
				g_bInfiniteGrenades = false;
				g_iCurrentMode = GetRandomInt(0, (g_iNumModes - 1));
				g_iSuddenDuration = g_iDefinedModeDuration[g_iCurrentMode];
				
				if(g_bDefinedModeChat[g_iCurrentMode])
					CPrintToChatAll("%s%s", g_sPrefixChat, g_sDefinedModeChat[g_iCurrentMode]);
					
				if(g_bDefinedModeCenter[g_iCurrentMode])
					PrintCenterTextAll("%s%s", g_sPrefixCenter, g_sDefinedModeCenter[g_iCurrentMode]);
					
				if(g_iDisableRadar)
				{
					if(g_iDisableRadar & g_iPhase)
					{
						for(new i = 1; i <= MaxClients; i++)
							if(IsClientInGame(i) && !(g_iPlayerAccess[i] & g_iRadarAccess))
								Void_HideRadar(i);
					}
					else
					{
						for(new i = 1; i <= MaxClients; i++)
							if(IsClientInGame(i))
								Void_ShowRadar(i);
					}
				}
				
				CreateTimer(0.1, Timer_ModeWeapons, _, TIMER_FLAG_NO_MAPCHANGE);
				CreateTimer(0.2, Timer_ModePrepare, _, TIMER_FLAG_NO_MAPCHANGE);
				CreateTimer(0.3, Timer_ModeExecute, 0, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}

	switch(g_iPhase)
	{
		case PHASE_BUILD:
		{
			if(g_bReadyProceed)
			{
				if(g_iNumSounds >= 0 && g_iReadySeconds <= g_iNumSounds)
					if(!(StrEqual(g_sSounds[g_iReadySeconds], "?")))
						EmitSoundToAll(g_sSounds[g_iReadySeconds], SOUND_FROM_PLAYER, SNDCHAN_VOICE);

				if(g_bDisplay)
				{
					decl String:_sBuffer[128];
					Format(_sBuffer, 128, "%T", "Phase_Build_Display_Title", LANG_SERVER);
					Format(_sBuffer, 128, "%s%T", _sBuffer, "Phase_Ready_Remaining", LANG_SERVER, (g_iReadySeconds <= 9) ? "0" : "", g_iReadySeconds);

					new Handle:_hMessage = StartMessageAll("KeyHintText");
					BfWriteByte(_hMessage, 1);
					BfWriteString(_hMessage, _sBuffer); 
					EndMessage();
				}
			}
			else
			{
				if(g_iBuildDuration)
				{
					new _iRemaining = (g_iBuildDuration - g_iNumSeconds);
					if(g_iNumSounds >= 0 && _iRemaining <= g_iNumSounds && g_iNumSeconds <= g_iBuildDuration)
						if(!(StrEqual(g_sSounds[_iRemaining], "?")))
							EmitSoundToAll(g_sSounds[_iRemaining], SOUND_FROM_PLAYER, SNDCHAN_VOICE);
					
					if(g_bDisplay)
					{
						decl String:_sBuffer[128];
						new _iMin = _iRemaining / 60;
						new _iSec = _iRemaining - (_iMin * 60);

						Format(_sBuffer, 128, "%T", "Phase_Build_Display_Title", LANG_SERVER);
						Format(_sBuffer, 128, "%s%T", _sBuffer, "Phase_Build_Remaining", LANG_SERVER, _iMin, (_iSec <= 9) ? "0" : "", _iSec);
						if(g_bReadyEnable && g_iWallEntities)
							Format(_sBuffer, 128, "%s%T", _sBuffer, "Phase_Build_Ready", LANG_SERVER, (g_iBlueReady + g_iRedReady), g_iReadyAmount);

						new Handle:_hMessage = StartMessageAll("KeyHintText");
						BfWriteByte(_hMessage, 1);
						BfWriteString(_hMessage, _sBuffer); 
						EndMessage();
					}
				}
				else
				{
					if(g_bDisplay)
					{
						decl String:_sBuffer[128];
						Format(_sBuffer, 128, "%T", "Phase_Build_Display_Title", LANG_SERVER);
						if(g_bReadyEnable && g_iWallEntities)
							Format(_sBuffer, 128, "%s%T", _sBuffer, "Phase_Build_Ready", LANG_SERVER, (g_iBlueReady + g_iRedReady), g_iReadyAmount);

						new Handle:_hMessage = StartMessageAll("KeyHintText");
						BfWriteByte(_hMessage, 1);
						BfWriteString(_hMessage, _sBuffer); 
						EndMessage();
					}
				}
			}
		}
		case PHASE_WAR:
		{
			if(g_iWarDuration)
			{
				new _iRemaining = (g_iWarDuration - g_iNumSeconds);
				if(g_iNumSounds >= 0 && _iRemaining <= g_iNumSounds && g_iNumSeconds <= g_iWarDuration)
					if(!(StrEqual(g_sSounds[_iRemaining], "?")))
						EmitSoundToAll(g_sSounds[_iRemaining], SOUND_FROM_PLAYER, SNDCHAN_VOICE);

				if(g_bDisplay)
				{
					decl String:_sBuffer[128];
					new _iMin = _iRemaining / 60;
					new _iSec = _iRemaining - (_iMin * 60);

					Format(_sBuffer, 128, "%T", "Phase_War_Title_Display", LANG_SERVER);
					Format(_sBuffer, 128, "%s%T", _sBuffer, "Phase_War_Remaining", LANG_SERVER, _iMin, (_iSec <= 9) ? "0" : "", _iSec);
					if(g_iSpawningMode == SPAWNING_TEAMS || g_iSpawningMode == SPAWNING_SINGLES)
						Format(_sBuffer, 128, "%s%T", _sBuffer, "Phase_War_Spawns", LANG_SERVER, g_iRedSpawns, g_iBlueSpawns);							
	
					new Handle:_hMessage = StartMessageAll("KeyHintText");
					BfWriteByte(_hMessage, 1);
					BfWriteString(_hMessage, _sBuffer); 
					EndMessage();
				}
			}
			else
			{
				if(g_bDisplay)
				{
					decl String:_sBuffer[128];
					Format(_sBuffer, 128, "%T", "Phase_War_Title_Display", LANG_SERVER);

					if(g_iSpawningMode != SPAWNING_DISABLED)
					{
						switch(g_iSpawningMode)
						{
							case SPAWNING_TEAMS:
							{
								Format(_sBuffer, 128, "%s%T", _sBuffer, "Phase_War_Spawns", LANG_SERVER, g_iRedSpawns, g_iBlueSpawns);
							}
							case SPAWNING_SINGLES:
							{
								Format(_sBuffer, 128, "%s%T", _sBuffer, "Phase_War_Spawns", LANG_SERVER, g_iRedSpawns, g_iBlueSpawns);							
							}
							case SPAWNING_TIMED:
							{
								if(g_fSpawnDuration)
								{
									new Float:_fMin = (g_fSpawnDuration - g_fSpawnRemaining) / 60;
									new Float:_fSec = (g_fSpawnDuration - g_fSpawnRemaining) - (_fMin * 60);

									if(_fSec >= 0.0)
										Format(_sBuffer, 128, "%s%T", _sBuffer, "Phase_War_Timed", LANG_SERVER, _fMin, (_fSec <= 9.0) ? "0" : "", _fSec);
								}
							}
						}
					}

					new Handle:_hMessage = StartMessageAll("KeyHintText");
					BfWriteByte(_hMessage, 1);
					BfWriteString(_hMessage, _sBuffer); 
					EndMessage();
				}
			}

			if(g_bTeleBeacon)
			{
				decl Float:_fOrigin[3];
				for(new i = 1; i <= MaxClients; i++)
				{
					if(g_bAlive[i] && g_iTeam[i] >= TEAM_RED && g_bTeleported[i])
					{
						GetClientAbsOrigin(i, _fOrigin);
						
						_fOrigin[2] += 10;
						for(new j = 0; j <= 2; j++)
						{
							_fOrigin[2] += 10;
							if(g_iTeam[i] == TEAM_RED)
								TE_SetupBeamRingPoint(_fOrigin, 10.0, 500.0, g_iBeamSprite, g_iHaloSprite, 0, 10, 1.0, 25.0, 1.0, g_iColorRed, 15, 0);
							else
								TE_SetupBeamRingPoint(_fOrigin, 10.0, 500.0, g_iBeamSprite, g_iHaloSprite, 0, 10, 1.0, 25.0, 1.0, g_iColorBlue, 15, 0);
							TE_SendToAll();
						}
					}
				}
			}
		}
		case PHASE_SUDDEN:
		{
			new _iRemaining = (g_iSuddenDuration - g_iNumSeconds);
			if(g_iNumSounds >= 0 && _iRemaining <= g_iNumSounds && g_iNumSeconds <= g_iSuddenDuration)
				if(!(StrEqual(g_sSounds[_iRemaining], "?")))
					EmitSoundToAll(g_sSounds[_iRemaining], SOUND_FROM_PLAYER, SNDCHAN_VOICE);
					
			if(g_bDisplay)
			{
				decl String:_sBuffer[128];
				new _iMin = _iRemaining / 60;
				new _iSec = _iRemaining - (_iMin * 60);

				if(_iSec >= 0)
				{
					Format(_sBuffer, 128, "%T", "Phase_Sudden_Title_Display", LANG_SERVER);
					Format(_sBuffer, 128, "%s%T", _sBuffer, "Phase_Sudden_Remaining", LANG_SERVER, _iMin, (_iSec <= 9) ? "0" : "", _iSec);

					new Handle:_hMessage = StartMessageAll("KeyHintText");
					BfWriteByte(_hMessage, 1);
					BfWriteString(_hMessage, _sBuffer); 
					EndMessage();
				}
			}
			
			if(g_iNumSeconds > g_iSuddenDuration)
			{
				g_hTimer_Update = INVALID_HANDLE;
				if(g_iPointsRed > g_iPointsBlue)
				{
					CS_TerminateRound(g_fRoundRestart, CSRoundEnd_TerroristWin);
					SetTeamScore(TEAM_RED, (GetTeamScore(TEAM_RED) + 1));
				}
				else if(g_iPointsBlue > g_iPointsRed)
				{
					CS_TerminateRound(g_fRoundRestart, CSRoundEnd_CTWin);
					SetTeamScore(TEAM_BLUE, (GetTeamScore(TEAM_BLUE) + 1));
				}
				else
				{
					CS_TerminateRound(g_fRoundRestart, CSRoundEnd_Draw);
					SetTeamScore(TEAM_RED, (GetTeamScore(TEAM_RED) + 1));
					SetTeamScore(TEAM_BLUE, (GetTeamScore(TEAM_BLUE) + 1));
				}
				
				return Plugin_Stop;
			}
			else
			{
				decl Float:_fOrigin[3];
				for(new i = 1; i <= MaxClients; i++)
				{
					if(g_bAlive[i] && g_iTeam[i] >= TEAM_RED)
					{
						GetClientAbsOrigin(i, _fOrigin);
						
						_fOrigin[2] += 10;
						for(new j = 0; j <= 2; j++)
						{
							_fOrigin[2] += 10;
							if(g_iTeam[i] == TEAM_RED)
								TE_SetupBeamRingPoint(_fOrigin, 10.0, 500.0, g_iBeamSprite, g_iHaloSprite, 0, 10, 1.0, 25.0, 1.0, g_iColorRed, 15, 0);
							else
								TE_SetupBeamRingPoint(_fOrigin, 10.0, 500.0, g_iBeamSprite, g_iHaloSprite, 0, 10, 1.0, 25.0, 1.0, g_iColorBlue, 15, 0);
							TE_SendToAll();
						}
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:Timer_ModeWeapons(Handle:timer)
{					
	decl String:_sClassname[64];
	for(new i = (MaxClients + 1); i <= MaxEntities; i++)
	{ 
		if(IsValidEdict(i) && IsValidEntity(i))
		{
			GetEdictClassname(i, _sClassname, 64);
			if(StrContains(_sClassname, "weapon_") != -1 && GetEntDataEnt2(i, g_iOwnerEntity) == -1)
				AcceptEntityInput(i, "Kill");
		}
	}
}

public Action:Timer_ModePrepare(Handle:timer)
{
	switch(g_iDefinedModeMethod[g_iCurrentMode])
	{
		case 1:
		{
			for(new i = (MaxClients + 1); i <= MaxEntities; i++)
				if(g_bProp[i] && IsValidEntity(i))
					Entity_DeleteProp(i, false);		
		}
		case 2:
		{
			for(new i = (MaxClients + 1); i <= MaxEntities; i++)
			{
				if(g_bProp[i] && IsValidEntity(i))
				{
					SDKHook(i, SDKHook_OnTakeDamage, Entity_OnTakeDamage);
					SetEntProp(i, Prop_Data, "m_takedamage", 2);
					SetEntProp(i, Prop_Data, "m_iHealth", g_iDefinedPropHealth[g_iPropType[i]], 1);
				}
			}
		}
	}
}

public Action:Timer_ModeEquip(Handle:timer, Handle:pack)
{
	decl String:_sBuffer[32], String:_sWeapon[32];
	
	ResetPack(pack);
	new _iTeam = ReadPackCell(pack);
	ReadPackString(pack, _sWeapon, 32);
	if(StrEqual(_sWeapon, "hegrenade"))
		g_bInfiniteGrenades = true;
 
	Format(_sBuffer, 32, "weapon_%s", _sWeapon);
	for(new i = 1; i <= MaxClients; i++)
	{
		if(g_bAlive[i] && IsClientInGame(i) && (!_iTeam || g_iTeam[i] == _iTeam))
		{
			GivePlayerItem(i, _sBuffer);
		}
	}
}

public Action:Timer_ModeExecute(Handle:timer, any:_bEnding)
{
	decl _iOperations, String:_sBuffer[MAX_CONFIG_OPERATIONS][64], String:_sTemp[MAX_CONFIG_OPERATIONS][64];

	if(_bEnding)
		_iOperations = ExplodeString(g_sDefinedModeEnd[g_iCurrentMode], ";", _sBuffer, MAX_CONFIG_OPERATIONS, 64);	
	else
		_iOperations = ExplodeString(g_sDefinedModeStart[g_iCurrentMode], ";", _sBuffer, MAX_CONFIG_OPERATIONS, 64);

	for(new i = 0; i < _iOperations; i++)
	{
		ExplodeString(_sBuffer[i], " ", _sTemp, MAX_CONFIG_OPERATIONS, 64);
		
		new _iTeam = StringToInt(_sTemp[1]);
		if(StrEqual(_sTemp[0], "strip"))
		{
			new bool:_bKnife = StringToInt(_sTemp[2]) ? true : false;
			for(new j = 1; j <= MaxClients; j++)
			{
				if(g_bAlive[j] && IsClientInGame(j) && (!_iTeam || g_iTeam[j] == _iTeam))
				{
					for(new k = 0; k <= 128; k += 4)
					{
						new entity = GetEntDataEnt2(j, (g_iMyWeapons + k));
						if(entity > 0 && IsValidEdict(entity))
						{
							RemovePlayerItem(j, entity);
							AcceptEntityInput(entity, "Kill");
						}
					}
					
					if(_bKnife)
					{
						GivePlayerItem(j, "weapon_knife");
						FakeClientCommandEx(j, "use weapon_knife");
					}
				}
			}
		}
		else if(StrEqual(_sTemp[0], "equip"))
		{
			decl String:_sWeapons[MAX_CONFIG_OPERATIONS][16];
			new _iWeapons = ExplodeString(_sTemp[2], ",", _sWeapons, MAX_CONFIG_OPERATIONS, 16);
			if(_iWeapons >= 1)
			{
				_iWeapons = GetRandomInt(0, (_iWeapons - 1));
				Format(g_sModeWeapon, 32, "weapon_%s", _sWeapons[_iWeapons]);
				if(g_hTrie_RestrictIndex != INVALID_HANDLE)
				{
					GetTrieValue(g_hTrie_RestrictIndex, g_sModeWeapon, g_iRestrictWeapon);
					
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

				new Handle:_hPack = INVALID_HANDLE;
				CreateDataTimer(0.1, Timer_ModeEquip, _hPack);
				WritePackCell(_hPack, _iTeam);
				WritePackString(_hPack, _sWeapons[_iWeapons]);
			}
		}
		else if(StrEqual(_sTemp[0], "tele"))
		{
			for(new j = 1; j <= MaxClients; j++)
			{
				if(g_bAlive[j] && IsClientInGame(j) && (!_iTeam || g_iTeam[j] == _iTeam))
				{
					Void_TeleportPlayer(j);
					Void_ClearClientTeleport(j);
				}
			}
		}
		else if(StrEqual(_sTemp[0], "speed"))
		{
			new Float:_fAmount = StringToFloat(_sTemp[2]);
			if(_fAmount == -1.0)
			{
				new Float:_fMin = StringToFloat(_sTemp[3]);
				new Float:_fMax = StringToFloat(_sTemp[4]);
				_fAmount = GetRandomFloat(_fMin, _fMax);
			}

			for(new j = 1; j <= MaxClients; j++)
			{
				if(g_bAlive[j] && IsClientInGame(j) && (!_iTeam || g_iTeam[j] == _iTeam))
				{
					g_bResetSpeed[j] = true;
					SetEntPropFloat(j, Prop_Data, "m_flLaggedMovementValue", _fAmount);
				}
			}
		}
		else if(StrEqual(_sTemp[0], "gravity"))
		{
			new Float:_fAmount = StringToFloat(_sTemp[2]);
			if(_fAmount == -1.0)
			{
				new Float:_fMin = StringToFloat(_sTemp[3]);
				new Float:_fMax = StringToFloat(_sTemp[4]);
				_fAmount = GetRandomFloat(_fMin, _fMax);
			}

			for(new j = 1; j <= MaxClients; j++)
			{
				if(g_bAlive[j] && IsClientInGame(j) && (!_iTeam || g_iTeam[j] == _iTeam))
				{
					g_bResetGravity[j] = true;
					SetEntityGravity(j, _fAmount);
				}
			}
		}
		else if(StrEqual(_sTemp[0], "health"))
		{
			new _iAmount = StringToInt(_sTemp[2]);
			if(_iAmount == -1)
			{
				new _iMin = StringToInt(_sTemp[3]);
				new _iMax = StringToInt(_sTemp[4]);
				_iAmount = GetRandomInt(_iMin, _iMax);
			}

			for(new j = 1; j <= MaxClients; j++)
			{
				if(g_bAlive[j] && IsClientInGame(j) && (!_iTeam || g_iTeam[j] == _iTeam))
				{
					SetEntityHealth(j, _iAmount);
				}
			}
		}
		else
			ServerCommand("%s", _sBuffer[i]);
	}
}

public Action:Timer_SpawnPlayer(Handle:timer, any:client)
{
	g_hTimer_RespawnPlayer[client] = INVALID_HANDLE;

	if(g_bSpawningAllowed && !g_bAlive[client] && g_iTeam[client] >= TEAM_RED)
		CS_RespawnPlayer(client);
}

public Action:Timer_Teleport(Handle:timer, any:client)
{
	g_fTeleRemaining[client] -= 1.0;
	if(g_fTeleRemaining[client] <= 0.0)
	{
		g_bTeleporting[client] = false;
		g_hTimer_TeleportPlayer[client] = INVALID_HANDLE;
	
		PrintCenterText(client, "%s%t", g_sPrefixCenter, "Teleport_Notify");
		Void_TeleportPlayer(client);
		return Plugin_Stop;
	}

	PrintCenterText(client, "%s%t", g_sPrefixCenter, "Teleport_Delay_Notify", g_fTeleRemaining[client]);
	return Plugin_Continue;
}

Void_TeleportPlayer(client)
{
	switch(g_iTeam[client])
	{
		case 2:
		{
			TeleportEntity(client, g_fRedTeleports[GetRandomInt(0, g_iNumRedSpawns)], NULL_VECTOR, NULL_VECTOR);
			if(g_bTeleBeacon && g_iPhase == PHASE_WAR)
				g_bTeleported[client] = true;
		}
		case 3:
		{
			TeleportEntity(client, g_fBlueTeleports[GetRandomInt(0, g_iNumBlueSpawns)], NULL_VECTOR, NULL_VECTOR);
			if(g_bTeleBeacon && g_iPhase == PHASE_WAR)
				g_bTeleported[client] = true;
		}
	}
}

public Action:Timer_KillEntity(Handle:timer, any:ref)
{
	new entity = EntRefToEntIndex(ref);
	if(entity != INVALID_ENT_REFERENCE)
		AcceptEntityInput(entity, "Kill");
}

Trace_GetEntity(client, Float:_fDistance = 0.0)
{
	new Handle:_hTemp, _iIndex = -1;
	decl Float:_fOrigin[3], Float:_fAngles[3];
	GetClientEyePosition(client, _fOrigin);
	GetClientEyeAngles(client, _fAngles);

	_hTemp = TR_TraceRayFilterEx(_fOrigin, _fAngles, MASK_OPAQUE, RayType_Infinite, Tracer_FilterPlayers, client);
	if(TR_DidHit(_hTemp))
	{
		_iIndex = TR_GetEntityIndex(_hTemp);
		if(_fDistance)
		{
			GetEntPropVector(_iIndex, Prop_Send, "m_vecOrigin", _fAngles);
			if(GetVectorDistance(_fAngles, _fOrigin) > _fDistance)
			{
				if(IsValidEntity(_iIndex) && g_bProp[_iIndex])
					PrintHintText(client, "%s%t", g_sPrefixHint, "Control_Prop_Distance", g_sDefinedPropNames[g_iPropType[_iIndex]]);
				CloseHandle(_hTemp);
				return -1;
			}
		}
	}

	if(_hTemp != INVALID_HANDLE)
		CloseHandle(_hTemp);

	return (_iIndex > 0) ? _iIndex : -1;
}

bool:Bool_ProximityCheck(Float:ori[3], Float:loc[3], Float:dist)
{
	return (!dist || GetVectorDistance(ori, loc) > dist) ? true : false;
}

public bool:Tracer_FilterPlayers(entity, contentsMask, any:data)
{
	if(entity > MaxClients)
		return true;

	return false;
}

public bool:Tracer_FilterBlocks(entity, contentsMask, any:data)
{
	if(entity > MaxClients && !g_bPropGrab[entity])
		return true;

	return false;
}

bool:Bool_CheckAction(client, bool:alive = true)
{
	if(!g_bEnding && g_bHasAccess[g_iTeam[client]] && (alive && g_bAlive[client]))
		return true;

	return false;
}

GetEntityIndex(client, entity)
{
	return FindValueInArray(g_hArray_PlayerProps[client], entity);
}

Void_PerformTeleport(client)
{
	if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
	{
		g_iPlayerTeleports[client]++;
		if(!g_fTeleportPublicDelay)
		{
			if(g_iTeleportPublic)
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Limited", (g_iTeleportPublic - g_iPlayerTeleports[client]), g_iTeleportPublic);
			else
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Infinite");
		
			Void_TeleportPlayer(client);
		}
		else
		{
			if(g_iTeleportPublic)
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Delay_Limited", g_fTeleportPublicDelay, g_iPlayerTeleports[client], g_iTeleportPublic);
			else
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Delay_Infinite", g_fTeleportPublicDelay);
			
			g_bTeleporting[client] = true;
			g_fTeleRemaining[client] = g_fTeleportPublicDelay;
			PrintCenterText(client, "%s%t", g_sPrefixCenter, "Teleport_Delay_Notify", g_fTeleRemaining[client]);
			g_hTimer_TeleportPlayer[client] = CreateTimer(1.0, Timer_Teleport, client, TIMER_REPEAT);
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
	{
		g_iPlayerTeleports[client]++;
		if(!g_fTeleportAdminDelay)
		{
			if(g_iTeleportAdmin)
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Limited", (g_iTeleportAdmin - g_iPlayerTeleports[client]), g_iTeleportAdmin);
			else
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Infinite");
		
			Void_TeleportPlayer(client);
		}
		else
		{
			if(g_iTeleportAdmin)
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Delay_Limited", g_fTeleportAdminDelay, (g_iTeleportAdmin - g_iPlayerTeleports[client]), g_iTeleportAdmin);
			else
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Delay_Infinite", g_fTeleportAdminDelay);
		
			g_bTeleporting[client] = true;
			g_fTeleRemaining[client] = g_fTeleportAdminDelay;
			PrintCenterText(client, "%s%t", g_sPrefixCenter, "Teleport_Delay_Notify", g_fTeleRemaining[client]);
			g_hTimer_TeleportPlayer[client] = CreateTimer(1.0, Timer_Teleport, client, TIMER_REPEAT);
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
	{
		g_iPlayerTeleports[client]++;
		if(!g_fTeleportSupporterDelay)
		{
			if(g_iTeleportSupporter)
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Limited", (g_iTeleportSupporter - g_iPlayerTeleports[client]), g_iTeleportSupporter);
			else
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Infinite");
		
			Void_TeleportPlayer(client);
		}
		else
		{
			if(g_iTeleportSupporter)
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Delay_Limited", g_fTeleportSupporterDelay, g_iPlayerTeleports[client], g_iTeleportSupporter);
			else
				PrintHintText(client, "%s%t", g_sPrefixHint, "Teleport_Delay_Infinite", g_fTeleportSupporterDelay);
			
			g_bTeleporting[client] = true;
			g_fTeleRemaining[client] = g_fTeleportSupporterDelay;
			PrintCenterText(client, "%s%t", g_sPrefixCenter, "Teleport_Delay_Notify", g_fTeleRemaining[client]);
			g_hTimer_TeleportPlayer[client] = CreateTimer(1.0, Timer_Teleport, client, TIMER_REPEAT);
		}
	}
}

Void_ColorClientProps(client, index)
{
	new _iSize = GetArraySize(g_hArray_PlayerProps[client]);
	for(new i = 0; i < _iSize; i++)
	{
		new entity = GetArrayCell(g_hArray_PlayerProps[client], i);
		if(IsValidEdict(entity) && IsValidEntity(entity))
		{
			if(g_iDefinedColorArrays[index][3] == -1)
				SetEntityRenderColor(entity, GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255));
			else
				SetEntityRenderColor(entity, g_iDefinedColorArrays[index][0], g_iDefinedColorArrays[index][1], g_iDefinedColorArrays[index][2], g_iDefinedColorArrays[index][3]);
		}
	}
}

Bool_ClearClientProps(client, bool:delete = true, bool:clear = false)
{
	new _iDeleted;
	if(delete)
	{
		new _iSize = GetArraySize(g_hArray_PlayerProps[client]);
		for(new i = 0; i < _iSize; i++)
		{
			new entity = GetArrayCell(g_hArray_PlayerProps[client], i);
			if(IsValidEntity(entity))
			{
				Entity_DeleteProp(entity);					
				_iDeleted++;
			}
		}

		switch(g_iTeam[client])
		{
			case TEAM_RED:
				g_iPointsRed += (_iDeleted * POINTS_DELETE);
			case TEAM_BLUE:
				g_iPointsBlue += (_iDeleted * POINTS_DELETE);
		}
	}

	g_iPlayerProps[client] = 0;
	if(clear)
		g_iPlayerDeletes[client] += _iDeleted;
	else
		g_iPlayerDeletes[client] = 0;

	ClearArray(g_hArray_PlayerProps[client]);
	return _iDeleted ? true : false;
}

bool:Entity_Valid(entity)
{
	if(entity > 0 && IsValidEntity(entity) && g_bProp[entity])
		return true;

	return false;
}

Entity_SpawnProp(client, _iType, Float:_fPosition[3], Float:_fAngles[3])
{
	new entity = CreateEntityByName(g_sPropTypes[g_iDefinedPropTypes[_iType]]);
	if(entity > 0)
	{
		g_bProp[entity] = true;
		g_iPropUser[entity] = GetClientUserId(client);
		g_iPropType[entity] = _iType;
		Format(g_sPropOwner[entity], 32, "%s", g_sName[client]);

		g_iUniqueProp++;
		decl String:_sBuffer[24];
		Format(_sBuffer, 24, "BuildWars:%d", g_iUniqueProp);
		DispatchKeyValue(entity, "targetname", _sBuffer);
		DispatchKeyValue(entity, "model", g_sDefinedPropPaths[_iType]);
		DispatchKeyValue(entity, "disablereceiveshadows", "1");
		DispatchKeyValue(entity, "disableshadows", "1");
		DispatchKeyValue(entity, "Solid", "6");
		DispatchSpawn(entity);
		if(g_bColorAllowed)
		{
			new _iTemp;
			if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
				_iTemp = g_iColoringPublic;
			else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
				_iTemp = g_iColoringAdmin;
			else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
				_iTemp = g_iColoringSupporter;

			switch(_iTemp)
			{
				case 0:
				{
					if(g_iDefinedColorArrays[g_iConfigColor[client]][3] == -1)
						SetEntityRenderColor(entity, GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), 255);
					else
						SetEntityRenderColor(entity, g_iDefinedColorArrays[g_iConfigColor[client]][0], g_iDefinedColorArrays[g_iConfigColor[client]][1], g_iDefinedColorArrays[g_iConfigColor[client]][2], g_iDefinedColorArrays[g_iConfigColor[client]][3]);
				}
				case 1:
				{
					SetEntityRenderColor(entity, GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), 255);
				}
				case 2:
				{
					switch(g_iTeam[client])
					{
						case TEAM_RED:
							SetEntityRenderColor(entity, g_iColorRed[0], g_iColorRed[1], g_iColorRed[2], g_iColorRed[3]);
						case TEAM_BLUE:
							SetEntityRenderColor(entity, g_iColorBlue[0], g_iColorBlue[1], g_iColorBlue[2], g_iColorBlue[3]);
						default:
							SetEntityRenderColor(entity, 255, 255, 255, 255);
					}
				}
				case 3:
				{
					SetEntityRenderColor(entity, 255, 255, 255, 255);
				}
			}
		}
		else
			SetEntityRenderColor(entity, 255, 255, 255, 255);

		TeleportEntity(entity, _fPosition, _fAngles, NULL_VECTOR);
		return entity;
	}
	
	return 0;
}

Entity_RotateProp(entity, Float:_fValue[3], bool:_bReset)
{
	new Float:_fAngles[3];
	if(!_bReset)
	{
		GetEntPropVector(entity, Prop_Data, "m_angRotation", _fAngles);
		AddVectors(_fAngles, _fValue, _fAngles);
		for(new i = 0; i <= 2; i++)
		{			
			while(_fAngles[i] < 0.0)
				_fAngles[i] += 360.0;

			while(_fAngles[i] > 360.0)
				_fAngles[i] -= 360.0;
		}
		TeleportEntity(entity, NULL_VECTOR, _fAngles, NULL_VECTOR);
	}
	else
		TeleportEntity(entity, NULL_VECTOR, _fAngles, NULL_VECTOR);
}

Entity_PositionProp(entity, Float:_fValue[3])
{
	decl Float:_fOrigin[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", _fOrigin);

	AddVectors(_fOrigin, _fValue, _fOrigin);
	TeleportEntity(entity, _fOrigin, NULL_VECTOR, NULL_VECTOR);
}

Entity_DeleteProp(entity, bool:dissolve = true)
{
	if(g_bDissolve && dissolve)
	{
		if(g_iCurEntities < g_iMaxEntities)
		{
			new _iDissolve = CreateEntityByName("env_entity_dissolver");
			if(_iDissolve > 0)
			{
				g_bProp[entity] = false;

				decl String:_sName[64];
				GetEntPropString(entity, Prop_Data, "m_iName", _sName, 64);
				DispatchKeyValue(_iDissolve, "dissolvetype", g_sDissolve);
				DispatchKeyValue(_iDissolve, "target", _sName);
				AcceptEntityInput(_iDissolve, "Dissolve");
				
				CreateTimer(1.0, Timer_KillEntity, EntIndexToEntRef(entity));
				CreateTimer(0.1, Timer_KillEntity, EntIndexToEntRef(_iDissolve));
				return;
			}
		}
	}

	g_bProp[entity] = false;
	AcceptEntityInput(entity, "Kill");
}

Void_DeleteClientProp(client, entity)
{
	new _iIndex = GetEntityIndex(client, entity);
	if(_iIndex >= 0)
		RemoveFromArray(g_hArray_PlayerProps[client], _iIndex);

	if(Entity_Valid(entity))
	{
		g_iPlayerProps[client]--;
		g_iPlayerDeletes[client]++;
		Entity_DeleteProp(entity);
	}
}

Void_SetSpawns()
{
	decl _iNeeded, entity, Float:_fTemp[3];

	entity = -1;
	g_iNumRedSpawns = 0;
	while((entity = FindEntityByClassname(entity, "info_player_terrorist")) != -1)
	{
		if(g_iNumRedSpawns == MAX_SPAWN_POINTS)
			break;

		g_iRedTeleports[g_iNumRedSpawns] = entity;
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", g_fRedTeleports[g_iNumRedSpawns]);
		
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
				
				entity = CreateEntityByName("info_player_terrorist");
				DispatchSpawn(entity);
				TeleportEntity(entity, _fTemp, NULL_VECTOR, NULL_VECTOR);
				_iNeeded--;
			}
		}
		g_iNumRedSpawns--;
	}

	entity = -1;
	g_iNumBlueSpawns = 0;
	while((entity = FindEntityByClassname(entity, "info_player_counterterrorist")) != -1)
	{
		if(g_iNumBlueSpawns == MAX_SPAWN_POINTS)
			break;

		g_iBlueTeleports[g_iNumBlueSpawns] = entity;
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", g_fBlueTeleports[g_iNumBlueSpawns]);

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

				entity = CreateEntityByName("info_player_counterterrorist");
				DispatchSpawn(entity);
				TeleportEntity(entity, _fTemp, NULL_VECTOR, NULL_VECTOR);
				_iNeeded--;
			}
		}
		g_iNumBlueSpawns--;
	}
}

Void_SetDownloads()
{
	new String:_sBuffer[256];
	BuildPath(Path_SM, _sBuffer, sizeof(_sBuffer), "configs/buildwars/sm_buildwars_downloads.ini");
	new Handle:_hTemp = OpenFile(_sBuffer, "r");

	if(_hTemp != INVALID_HANDLE) 
	{
		new _iLength;
		while (ReadFileLine(_hTemp, _sBuffer, sizeof(_sBuffer)))
		{	
			_iLength = strlen(_sBuffer);
			if (_sBuffer[(_iLength - 1)] == '\n')
				_sBuffer[--_iLength] = '\0';

			TrimString(_sBuffer);
			if (!StrEqual(_sBuffer, "", false))
				Void_ReadFileFolder(_sBuffer);

			if (IsEndOfFile(_hTemp))
				break;
		}

		CloseHandle(_hTemp);
	}
}

Void_ReadFileFolder(String:_sPath[])
{
	new Handle:_hTemp = INVALID_HANDLE;
	new _iLength, FileType:_iFileType = FileType_Unknown;
	decl String:_sBuffer[256], String:_sLine[256];
	
	_iLength = strlen(_sPath);
	if (_sPath[_iLength-1] == '\n')
		_sPath[--_iLength] = '\0';

	TrimString(_sPath);
	if(DirExists(_sPath))
	{
		_hTemp = OpenDirectory(_sPath);
		while(ReadDirEntry(_hTemp, _sBuffer, sizeof(_sBuffer), _iFileType))
		{
			_iLength = strlen(_sBuffer);
			if (_sBuffer[_iLength-1] == '\n')
				_sBuffer[--_iLength] = '\0';
			TrimString(_sBuffer);

			if (!StrEqual(_sBuffer, "") && !StrEqual(_sBuffer, ".", false) && !StrEqual(_sBuffer,"..",false))
			{
				strcopy(_sLine, sizeof(_sLine), _sPath);
				StrCat(_sLine, sizeof(_sLine), "/");
				StrCat(_sLine, sizeof(_sLine), _sBuffer);

				if(_iFileType == FileType_File)
					Void_ReadItem(_sLine);
				else
					Void_ReadFileFolder(_sLine);
			}
		}
	}
	else
		Void_ReadItem(_sPath);

	if(_hTemp != INVALID_HANDLE)
		CloseHandle(_hTemp);
}

Void_ReadItem(String:_sBuffer[])
{
	decl String:_sTemp[3];
	new _iLength = strlen(_sBuffer);
	if (_sBuffer[_iLength-1] == '\n')
		_sBuffer[--_iLength] = '\0';
	TrimString(_sBuffer);

	strcopy(_sTemp, sizeof(_sTemp), _sBuffer);
	if(!StrEqual(_sBuffer, "") && StrContains(_sBuffer, "//") == -1)
	{
		if (FileExists(_sBuffer))
		{
			if((StrContains(_sBuffer, ".wav") >= 0) || (StrContains(_sBuffer, ".mp3") >= 0))
				PrecacheSound(_sBuffer);
			else if(StrContains(_sBuffer, ".mdl") >= 0)
				PrecacheModel(_sBuffer);

			AddFileToDownloadsTable(_sBuffer);
		}
	}
}

Void_SetDefaults()
{
	decl _iTemp, String:_sSounds[2048], String:_sTemp[32], String:_sColors[4][4];	

	g_bEnding = false;
	g_bSpawningAllowed = true;

	g_bEnabled = GetConVarInt(g_hCvar[CVAR_ENABLED]) ? true : false;
	g_bDisplay = GetConVarInt(g_hCvar[CVAR_DISPLAY]) ? true : false;	
	GetConVarString(g_hCvar[CVAR_DISSOLVE], g_sDissolve, 8);
	g_bDissolve = GetConVarInt(g_hCvar[CVAR_DISSOLVE]) >= 0 ? true : false;
	GetConVarString(g_hCvar[CVAR_HELP], g_sHelp, 128);
	g_bHelp = StrEqual(g_sHelp, "") ? false : true;
	g_fAdvert = GetConVarFloat(g_hCvar[CVAR_ADVERT]);
	GetConVarString(g_hCvar[CVAR_SOUNDS], _sSounds, 2048);
	g_iNumSounds = ((ExplodeString(_sSounds, ", ", g_sSounds, MAX_PHASE_SOUNDS, 128)) - 1);
	if(g_iNumSounds >= 0)
		for(new i = 0; i <= g_iNumSounds; i++)
			PrecacheSound(g_sSounds[i]);
	g_iMaxEntities = GetConVarInt(g_hCvar[CVAR_MAX_ENTITIES]);
	
	g_fProximitySpawns = GetConVarFloat(g_hCvar[CVAR_PROXIMITY_SPAWNS]);
	g_fProximityPlayers = GetConVarFloat(g_hCvar[CVAR_PROXIMITY_PLAYERS]);
	
	g_iDisableRadio = GetConVarInt(g_hCvar[CVAR_DISABLE_RADIO]);
	g_iDisableSuicide = GetConVarInt(g_hCvar[CVAR_DISABLE_SUICIDE]);
	g_iDisableFalling = GetConVarInt(g_hCvar[CVAR_DISABLE_FALLING]);
	g_iDisableDrowning = GetConVarInt(g_hCvar[CVAR_DISABLE_DROWNING]);
	g_iDisableCrouching = GetConVarInt(g_hCvar[CVAR_DISABLE_CROUCHING]);
	g_iDisableRadar = GetConVarInt(g_hCvar[CVAR_DISABLE_RADAR]);

	g_iDefaultColor = GetConVarInt(g_hCvar[CVAR_DEFAULT_COLOR]);
	g_bColorAllowed = g_iDefaultColor != -1 ? true : false;
	g_iDefaultRotation = GetConVarInt(g_hCvar[CVAR_DEFAULT_ROTATION]);
	g_bRotationAllowed = g_iDefaultRotation != -1 ? true : false;
	g_iDefaultPosition = GetConVarInt(g_hCvar[CVAR_DEFAULT_POSITION]);
	g_bPositionAllowed = g_iDefaultPosition != -1 ? true : false;
	g_fDefaultControl = GetConVarFloat(g_hCvar[CVAR_DEFAULT_CONTROL]);
	g_bControlAllowed = g_fDefaultControl != -1.0 ? true : false;
	g_iDefaultDegreeSnap = GetConVarInt(g_hCvar[CVAR_DEFAULT_DEGREE]);
	g_bRotSnapAllowed = g_iDefaultDegreeSnap != -1 ? true : false;
	g_iDefaultMoveSnap = GetConVarInt(g_hCvar[CVAR_DEFAULT_MOVE]);
	g_bPosSnapAllowed = g_iDefaultMoveSnap != -1 ? true : false;
	g_iDefaultQuick = GetConVarInt(g_hCvar[CVAR_DEFAULT_QUICK]);
	g_bQuickAllowed = g_iDefaultQuick != -1 ? true : false;
	
	g_iBuildDuration = GetConVarInt(g_hCvar[CVAR_DURATION_BUILD]);
	g_iWarDuration = GetConVarInt(g_hCvar[CVAR_DURATION_WAR]);
	g_bSuddenDeath = GetConVarInt(g_hCvar[CVAR_SUDDEN_DEATH]) ? true : false;

	g_iNoneDisable = GetConVarInt(g_hCvar[CVAR_LIMIT_NONE]);
	g_iBuildDisable = GetConVarInt(g_hCvar[CVAR_LIMIT_BUILD]);
	g_iWarDisable = GetConVarInt(g_hCvar[CVAR_LIMIT_WAR]);	
	g_iSuddenDisable = GetConVarInt(g_hCvar[CVAR_LIMIT_SUDDEN]) + DISABLE_TELE;
	
	g_iPropPublic = GetConVarInt(g_hCvar[CVAR_PUBLIC_PROPS]);
	g_iPropSupporter = GetConVarInt(g_hCvar[CVAR_SUPPORTER_PROPS]);
	g_iPropAdmin = GetConVarInt(g_hCvar[CVAR_ADMIN_PROPS]);
	g_bShowIndex = GetConVarInt(g_hCvar[CVAR_DISPLAY_INDEX]) ? true : false;
	
	g_iDeletePublic = GetConVarInt(g_hCvar[CVAR_PUBLIC_DELETES]);
	g_iDeleteSupporter = GetConVarInt(g_hCvar[CVAR_SUPPORTER_DELETES]);
	g_iDeleteAdmin = GetConVarInt(g_hCvar[CVAR_ADMIN_DELETES]);
	
	g_iTeleportPublic = GetConVarInt(g_hCvar[CVAR_PUBLIC_TELES]);
	g_iTeleportSupporter = GetConVarInt(g_hCvar[CVAR_SUPPORTER_TELES]);
	g_iTeleportAdmin = GetConVarInt(g_hCvar[CVAR_ADMIN_TELES]);
	g_fTeleportPublicDelay = GetConVarFloat(g_hCvar[CVAR_PUBLIC_DELAY]);
	g_fTeleportSupporterDelay = GetConVarFloat(g_hCvar[CVAR_SUPPORTER_DELAY]);
	g_fTeleportAdminDelay = GetConVarFloat(g_hCvar[CVAR_ADMIN_DELAY]);
	g_bTeleBeacon = GetConVarInt(g_hCvar[CVAR_TELE_BEACON]) ? true : false;

	g_iColoringPublic = GetConVarInt(g_hCvar[CVAR_PUBLIC_COLORING]);
	g_iColoringSupporter = GetConVarInt(g_hCvar[CVAR_SUPPORTER_COLORING]);
	g_iColoringAdmin = GetConVarInt(g_hCvar[CVAR_ADMIN_COLORING]);
	g_iColorPublic = GetConVarInt(g_hCvar[CVAR_PUBLIC_COLOR]);
	g_iColorSupporter = GetConVarInt(g_hCvar[CVAR_SUPPORTER_COLOR]);
	g_iColorAdmin = GetConVarInt(g_hCvar[CVAR_ADMIN_COLOR]);
	GetConVarString(g_hCvar[CVAR_COLOR_RED], _sTemp, 32);
	ExplodeString(_sTemp, " ", _sColors, 4, 4);
	for(new i = 0; i <= 3; i++)
		g_iColorRed[i] = StringToInt(_sColors[i]);
	GetConVarString(g_hCvar[CVAR_COLOR_BLUE], _sTemp, 32);
	ExplodeString(_sTemp, " ", _sColors, 4, 4);
	for(new i = 0; i <= 3; i++)
		g_iColorBlue[i] = StringToInt(_sColors[i]);

	g_bHasAccess[TEAM_SPEC] = GetConVarInt(g_hCvar[CVAR_ACCESS_SPEC]) ? true : false;
	g_bHasAccess[TEAM_RED] = GetConVarInt(g_hCvar[CVAR_ACCESS_RED]) ? true : false;
	g_bHasAccess[TEAM_BLUE] = GetConVarInt(g_hCvar[CVAR_ACCESS_BLUE]) ? true : false;
	g_iCheckAccess = GetConVarInt(g_hCvar[CVAR_ACCESS_CHECK]);
	g_iControlAccess = GetConVarInt(g_hCvar[CVAR_ACCESS_GRAB]);
	g_bAccessSettings = GetConVarInt(g_hCvar[CVAR_ACCESS_SETTINGS]) ? true : false;
	g_bAccessAdmin = GetConVarInt(g_hCvar[CVAR_ACCESS_MANAGE]) ? true : false;
	g_iCrouchAccess = GetConVarInt(g_hCvar[CVAR_ACCESS_CROUCH]);
	g_iRadarAccess = GetConVarInt(g_hCvar[CVAR_ACCESS_RADAR]);
	g_iQuickAccess = GetConVarInt(g_hCvar[CVAR_ACCESS_QUICK]);

	g_fGrabDistance = GetConVarFloat(g_hCvar[CVAR_GRAB_DISTANCE]);
	g_fGrabUpdate = GetConVarFloat(g_hCvar[CVAR_GRAB_REFRESH]);
	g_fGrabMinimum = GetConVarFloat(g_hCvar[CVAR_GRAB_MINIMUM]);
	g_fGrabMaximum = GetConVarFloat(g_hCvar[CVAR_GRAB_MAXIMUM]);
	g_fGrabInterval = GetConVarFloat(g_hCvar[CVAR_GRAB_INTERVAL]);
	g_bGrabBlock = GetConVarInt(g_hCvar[CVAR_GRAB_SOLID]) ? true : false;

	g_iSpawningMode = GetConVarInt(g_hCvar[CVAR_SPAWNING_MODE]);
	g_bSpawningBuild = GetConVarInt(g_hCvar[CVAR_SPAWNING_BUILD]) ? true : false;
	g_fSpawningDelay = GetConVarFloat(g_hCvar[CVAR_SPAWNING_DELAY]);
	g_bSpawningIgnore = GetConVarInt(g_hCvar[CVAR_SPAWNING_IGNORE]) ? true : false;
	_iTemp = GetConVarInt(g_hCvar[CVAR_SPAWNING_FACTOR]);
	g_iTotalSpawns = _iTemp;
	g_iRedSpawns = _iTemp;
	g_iBlueSpawns = _iTemp;
	g_fSpawnDuration = GetConVarFloat(g_hCvar[CVAR_SPAWNING_DURATION]);

	g_bSpawningAppear = GetConVarInt(g_hCvar[CVAR_SPAWNS_APPEAR]) ? true : false;
	g_iSpawningRefresh = GetConVarInt(g_hCvar[CVAR_SPAWNS_REFRESH]);
	g_fSpawningRefresh = float(g_iSpawningRefresh);
	GetConVarString(g_hCvar[CVAR_SPAWNS_RED], g_sSpawnsRed, 32);
	GetConVarString(g_hCvar[CVAR_SPAWNS_BLUE], g_sSpawnsBlue, 32);

	g_bReadyEnable = GetConVarInt(g_hCvar[CVAR_READY_ENABLE]) ? true : false;
	g_fReadyPercent = GetConVarFloat(g_hCvar[CVAR_READY_PERCENT]);
	g_iReadyDelay = GetConVarInt(g_hCvar[CVAR_READY_DELAY]);
	g_iReadyWait = GetConVarInt(g_hCvar[CVAR_READY_WAIT]);
	g_iReadyMinimum = GetConVarInt(g_hCvar[CVAR_READY_MINIMUM]);

	g_bMaintainSize = GetConVarInt(g_hCvar[CVAR_MAINTAIN_TEAMS]) ? true : false;
	g_bMaintainSpawns = GetConVarInt(g_hCvar[CVAR_MAINTAIN_SPAWNS]) ? true : false;
	g_bPersistentRounds = GetConVarInt(g_hCvar[CVAR_PERSISTENT_ROUNDS]) ? true : false;
	g_iPersistentEffect = GetConVarInt(g_hCvar[CVAR_PERSISTENT_EFFECT]);
	GetConVarString(g_hCvar[CVAR_PERSISTENT_COLORS], _sTemp, 32);
	g_bPersistentColors = StrEqual(_sTemp, "") ? false : true;
	if(g_bPersistentColors)
	{
		ExplodeString(_sTemp, " ", _sColors, 4, 4);
		for(new i = 0; i <= 3; i++)
			g_iPersistentColors[i] = StringToInt(_sColors[i]);
	}

	g_iScrambleRounds = GetConVarInt(g_hCvar[CVAR_SCRAMBLE_ROUNDS]);

	g_bAfkEnable = GetConVarInt(g_hCvar[CVAR_AFK_ENABLE]) ? true : false;
	g_fAfkDelay = GetConVarFloat(g_hCvar[CVAR_AFK_DELAY]);
	g_bAfkAutoKick = GetConVarInt(g_hCvar[CVAR_AFK_KICK]) ? true : false;
	g_fAfkAutoDelay = GetConVarFloat(g_hCvar[CVAR_AFK_KICK_DELAY]);
	g_bAfkReturn = GetConVarInt(g_hCvar[CVAR_AFK_RETURN])? true : false;
	g_bAfkSpecKick = GetConVarInt(g_hCvar[CVAR_AFK_SPEC]) ? true : false;
	g_fAfkSpecKickDelay = GetConVarFloat(g_hCvar[CVAR_AFK_SPEC_DELAY]);
	g_bAfkAutoSpec = GetConVarInt(g_hCvar[CVAR_AFK_FORCE])? true : false;
	g_fAfkForceSpecDelay = GetConVarFloat(g_hCvar[CVAR_AFK_FORCE_DELAY]);
	g_iAfkImmunity = GetConVarInt(g_hCvar[CVAR_AFK_IMMUNITY]);

	GetConVarString(g_hCvar[CVAR_GAME_DESCRIPTION], g_sGameDescription, sizeof(g_sGameDescription));
	g_bGameDescription = StrEqual(g_sGameDescription, "") ? false : true;
	g_bAlwaysBuyzone = GetConVarFloat(g_hCvar[CVAR_ALWAYS_BUYZONE]) ? true : false;
	
	g_iLimitTeams = GetConVarInt(g_hLimitTeams);
	g_fRoundRestart = GetConVarFloat(g_hRoundRestart);
}

public OnSettingsChange(Handle:cvar, const String:oldvalue[], const String:newvalue[])
{
	if(cvar == g_hCvar[CVAR_ENABLED])
	{
		g_bEnabled = StringToInt(newvalue) ? true : false;
		if(g_bEnabled && !StringToInt(oldvalue))
		{
			Define_Props();
			Define_Rotations();
			Define_Positions();
			Define_Colors();
			Define_Commands();
			Define_Modes();
		}
	}
	else if(cvar == g_hCvar[CVAR_DISPLAY])
		g_bDisplay = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_DISSOLVE])
	{
		g_bDissolve = StringToInt(newvalue) >= 0 ? true : false;
		Format(g_sDissolve, 8, "%s", newvalue);
	}
	else if(cvar == g_hCvar[CVAR_HELP])
	{
		g_bHelp = StrEqual(newvalue, "") ? false : true;
		Format(g_sHelp, 128, "%s", newvalue);
	}
	else if(cvar == g_hCvar[CVAR_ADVERT])
		g_fAdvert = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_SOUNDS])
	{
		g_iNumSounds = ((ExplodeString(newvalue, ", ", g_sSounds, MAX_PHASE_SOUNDS, 128)) - 1);
		if(g_iNumSounds >= 0)
			for(new i = 0; i <= g_iNumSounds; i++)
				PrecacheSound(g_sSounds[i]);
	}
	else if(cvar == g_hCvar[CVAR_MAX_ENTITIES])
		g_iMaxEntities = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_PROXIMITY_SPAWNS])
		g_fProximitySpawns = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_PROXIMITY_PLAYERS])
		g_fProximityPlayers = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_DISABLE_RADIO])
		g_iDisableRadio = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_DISABLE_SUICIDE])
		g_iDisableSuicide = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_DISABLE_FALLING])	
		g_iDisableFalling = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_DISABLE_DROWNING])
		g_iDisableDrowning = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_DISABLE_CROUCHING])
		g_iDisableCrouching = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_DISABLE_RADAR])
		g_iDisableRadar = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_DURATION_BUILD])
		g_iBuildDuration = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_DURATION_WAR])
		g_iWarDuration = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_SUDDEN_DEATH])
		g_bSuddenDeath = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_LIMIT_NONE])
	{
		g_iNoneDisable = StringToInt(newvalue);
		if(g_iPhase == PHASE_NONE)
			g_iCurrentDisable = g_iSuddenDisable;
	}
	else if(cvar == g_hCvar[CVAR_LIMIT_BUILD])
	{
		g_iBuildDisable = StringToInt(newvalue);
		if(g_iPhase == PHASE_BUILD)
			g_iCurrentDisable = g_iSuddenDisable;
	}
	else if(cvar == g_hCvar[CVAR_LIMIT_WAR])
	{
		g_iWarDisable = StringToInt(newvalue);
		if(g_iPhase == PHASE_WAR)
			g_iCurrentDisable = g_iSuddenDisable;
	}
	else if(cvar == g_hCvar[CVAR_LIMIT_SUDDEN])
	{
		g_iSuddenDisable = StringToInt(newvalue) + DISABLE_TELE;
		if(g_iPhase == PHASE_SUDDEN)
			g_iCurrentDisable = g_iSuddenDisable;
	}
	else if(cvar == g_hCvar[CVAR_DEFAULT_COLOR])
	{
		g_iDefaultColor = StringToInt(newvalue);
		g_bColorAllowed = g_iDefaultColor != -1 ? true : false;
		Define_Colors();
	}
	else if(cvar == g_hCvar[CVAR_DEFAULT_ROTATION])
	{
		g_iDefaultRotation = StringToInt(newvalue);
		g_bRotationAllowed = g_iDefaultRotation != -1 ? true : false;
		Define_Rotations();
	}
	else if(cvar == g_hCvar[CVAR_DEFAULT_POSITION])
	{
		g_iDefaultPosition = StringToInt(newvalue);
		g_bPositionAllowed = g_iDefaultPosition != -1 ? true : false;
		Define_Positions();
	}
	else if(cvar == g_hCvar[CVAR_DEFAULT_CONTROL])
	{
		g_fDefaultControl = StringToFloat(newvalue);
		g_bControlAllowed = g_fDefaultControl != -1 ? true : false;
	}
	else if(cvar == g_hCvar[CVAR_DEFAULT_DEGREE])
	{
		g_iDefaultDegreeSnap = StringToInt(newvalue);
		g_bRotSnapAllowed = g_iDefaultDegreeSnap != -1 ? true : false;
	}
	else if(cvar == g_hCvar[CVAR_DEFAULT_MOVE])
	{
		g_iDefaultMoveSnap = StringToInt(newvalue);
		g_bPosSnapAllowed = g_iDefaultMoveSnap != -1 ? true : false;
	}
	else if(cvar == g_hCvar[CVAR_DEFAULT_QUICK])
	{
		g_iDefaultQuick = StringToInt(newvalue);
		g_bQuickAllowed = g_iDefaultQuick != -1 ? true : false;
	}
	else if(cvar == g_hCvar[CVAR_PUBLIC_PROPS])
		g_iPropPublic = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_SUPPORTER_PROPS])
		g_iPropSupporter = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ADMIN_PROPS])
		g_iPropAdmin = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_DISPLAY_INDEX])
		g_bShowIndex = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_PUBLIC_DELETES])
		g_iDeletePublic = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_SUPPORTER_DELETES])
		g_iDeleteSupporter = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ADMIN_DELETES])
		g_iDeleteAdmin = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_PUBLIC_TELES])
		g_iTeleportPublic = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_SUPPORTER_TELES])
		g_iTeleportSupporter = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ADMIN_TELES])
		g_iTeleportAdmin = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_PUBLIC_DELAY])
		g_fTeleportPublicDelay = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_SUPPORTER_DELAY])
		g_fTeleportSupporterDelay = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_ADMIN_DELAY])
		g_fTeleportAdminDelay = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_TELE_BEACON])
		g_bTeleBeacon = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_PUBLIC_COLORING])
		g_iColoringPublic = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_SUPPORTER_COLORING])
		g_iColoringSupporter = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ADMIN_COLORING])
		g_iColoringAdmin = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_PUBLIC_COLOR])
		g_iColorPublic = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_SUPPORTER_COLOR])
		g_iColorSupporter = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ADMIN_COLOR])
		g_iColorAdmin = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_COLOR_RED])
	{
		decl String:_sColors1[4][4];
		ExplodeString(newvalue, " ", _sColors1, 4, 4);
		for(new i = 0; i <= 3; i++)
			g_iColorRed[i] = StringToInt(_sColors1[i]);
	}
	else if(cvar == g_hCvar[CVAR_COLOR_BLUE])
	{
		decl String:_sColors2[4][4];
		ExplodeString(newvalue, " ", _sColors2, 4, 4);
		for(new i = 0; i <= 3; i++)
			g_iColorBlue[i] = StringToInt(_sColors2[i]);
	}
	else if(cvar == g_hCvar[CVAR_ACCESS_SPEC])
		g_bHasAccess[TEAM_SPEC] = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_ACCESS_RED])
		g_bHasAccess[TEAM_RED] = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_ACCESS_BLUE])
		g_bHasAccess[TEAM_BLUE] = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_ACCESS_CHECK])
		g_iCheckAccess = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ACCESS_GRAB])
		g_iControlAccess = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ACCESS_SETTINGS])
		g_bAccessSettings = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_ACCESS_MANAGE])
		g_bAccessAdmin = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_ACCESS_CROUCH])
		g_iCrouchAccess = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ACCESS_RADAR])
		g_iRadarAccess = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ACCESS_QUICK])
		g_iQuickAccess = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_GRAB_DISTANCE])
		g_fGrabDistance = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_GRAB_SOLID])
		g_bGrabBlock = StringToFloat(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_GRAB_REFRESH])
		g_fGrabUpdate = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_GRAB_MINIMUM])
		g_fGrabMinimum = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_GRAB_MAXIMUM])
		g_fGrabMaximum = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_GRAB_INTERVAL])
		g_fGrabInterval = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_SPAWNING_MODE])
		g_iSpawningMode = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_SPAWNING_BUILD])
		g_bSpawningBuild = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_SPAWNING_DELAY])
		g_fSpawningDelay = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_SPAWNING_IGNORE])
		g_bSpawningIgnore = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_SPAWNING_FACTOR])
	{
		new _iBuffer = StringToInt(newvalue);
		g_iTotalSpawns = _iBuffer;
		g_iRedSpawns = _iBuffer;
		g_iBlueSpawns = _iBuffer;
	}
	else if(cvar == g_hCvar[CVAR_SPAWNING_DURATION])
		g_fSpawnDuration = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_SPAWNS_APPEAR])
		g_bSpawningAppear = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_SPAWNS_REFRESH])
	{
		g_iSpawningRefresh = StringToInt(newvalue);
		g_fSpawningRefresh = float(g_iSpawningRefresh);
	}
	else if(cvar == g_hCvar[CVAR_SPAWNS_RED])
		Format(g_sSpawnsRed, 32, "%s", newvalue);
	else if(cvar == g_hCvar[CVAR_SPAWNS_BLUE])
		Format(g_sSpawnsBlue, 32, "%s", newvalue);
	else if(cvar == g_hCvar[CVAR_READY_ENABLE])
		g_bReadyEnable = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_READY_PERCENT])
		g_fReadyPercent = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_READY_DELAY])
		g_iReadyDelay = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_READY_WAIT])
		g_iReadyWait = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_READY_MINIMUM])
		g_iReadyMinimum = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_MAINTAIN_TEAMS])
		g_bMaintainSize = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_MAINTAIN_SPAWNS])
		g_bMaintainSpawns = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_PERSISTENT_ROUNDS])
		g_bPersistentRounds = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_PERSISTENT_EFFECT])
		g_iPersistentEffect = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_PERSISTENT_COLORS])
	{
		g_bPersistentColors = StrEqual(newvalue, "") ? false : true;
		if(g_bPersistentColors)
		{
			decl String:_sColors3[4][4];
			ExplodeString(newvalue, " ", _sColors3, 4, 4);
			for(new i = 0; i <= 3; i++)
				g_iPersistentColors[i] = StringToInt(_sColors3[i]);
		}
	}
	else if(cvar == g_hCvar[CVAR_SCRAMBLE_ROUNDS])
		g_iScrambleRounds = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_AFK_ENABLE])
		g_bAfkEnable = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_AFK_DELAY])
		g_fAfkDelay = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_AFK_KICK])
		g_bAfkAutoKick = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_AFK_KICK_DELAY])
		g_fAfkAutoDelay = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_AFK_RETURN])
		g_bAfkReturn = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_AFK_SPEC])
		g_bAfkSpecKick = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_AFK_SPEC_DELAY])
		g_fAfkSpecKickDelay = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_AFK_FORCE])
		g_bAfkAutoSpec = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_AFK_FORCE_DELAY])
		g_fAfkForceSpecDelay = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_AFK_IMMUNITY])
		g_iAfkImmunity = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_GAME_DESCRIPTION])
	{
		Format(g_sGameDescription, sizeof(g_sGameDescription), "%s", newvalue);
		g_bGameDescription = StrEqual(g_sGameDescription, "") ? false : true;
	}
	else if(cvar == g_hCvar[CVAR_ALWAYS_BUYZONE])
		g_bAlwaysBuyzone = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hLimitTeams)
		g_iLimitTeams = StringToInt(newvalue);
	else if(cvar == g_hRoundRestart)
		g_fRoundRestart = StringToFloat(newvalue);
}

Menu_Main(client)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:_sBuffer[128];
	new Handle:_hMenu = CreateMenu(MenuHandler_Main);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuPagination(_hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(_hMenu, true);

	if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
	{
		if(g_iPropPublic != -1)
		{
			if(!g_iPropPublic)
				Format(_sBuffer, 128, "%T", "Menu_Spawn_Prop_Infinite", client);
			else
				Format(_sBuffer, 128, "%T", "Menu_Spawn_Prop_Limited", client, g_iPlayerProps[client], g_iPropPublic);

			AddMenuItem(_hMenu, "0", _sBuffer, Bool_SpawnValid(client, false, true) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		
		if(g_bRotationAllowed)
		{
			Format(_sBuffer, 128, "%T", "Menu_Rotate_Prop", client);
			AddMenuItem(_hMenu, "1", _sBuffer, Bool_RotateValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_bPositionAllowed)
		{
			Format(_sBuffer, 128, "%T", "Menu_Position_Prop", client);
			AddMenuItem(_hMenu, "2", _sBuffer, Bool_MoveValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		
		if(g_iDeletePublic != -1)
		{
			if(!g_iDeletePublic)
				Format(_sBuffer, 128, "%T", "Menu_Delete_Prop_Infinite", client);
			else
				Format(_sBuffer, 128, "%T", "Menu_Delete_Prop_Limited", client, g_iPlayerDeletes[client], g_iDeletePublic);

			AddMenuItem(_hMenu, "3", _sBuffer, Bool_DeleteValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		
		if(g_bControlAllowed && g_iControlAccess & ACCESS_PUBLIC)
		{
			Format(_sBuffer, 128, "%T", "Menu_Control_Prop", client);
			AddMenuItem(_hMenu, "4", _sBuffer, Bool_ControlValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_iCheckAccess & ACCESS_PUBLIC)
		{
			Format(_sBuffer, 128, "%T", "Menu_Check_Prop", client);
			AddMenuItem(_hMenu, "7", _sBuffer, Bool_CheckValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		
		if(g_bAccessSettings)
		{
			Format(_sBuffer, 128, "%T", "Menu_Player_Actions", client);
			AddMenuItem(_hMenu, "5", _sBuffer);
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
	{
		if(g_iPropAdmin != -1)
		{
			if(!g_iPropAdmin)
				Format(_sBuffer, 128, "%T", "Menu_Spawn_Prop_Infinite", client);
			else
				Format(_sBuffer, 128, "%T", "Menu_Spawn_Prop_Limited", client, g_iPlayerProps[client], g_iPropAdmin);

			AddMenuItem(_hMenu, "0", _sBuffer, Bool_SpawnValid(client, false, true) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		
		if(g_bRotationAllowed)
		{
			Format(_sBuffer, 128, "%T", "Menu_Rotate_Prop", client);
			AddMenuItem(_hMenu, "1", _sBuffer);
		}

		if(g_bPositionAllowed)
		{
			Format(_sBuffer, 128, "%T", "Menu_Position_Prop", client);
			AddMenuItem(_hMenu, "2", _sBuffer);
		}
		
		if(g_iDeleteAdmin != -1)
		{
			if(!g_iDeleteAdmin)
				Format(_sBuffer, 128, "%T", "Menu_Delete_Prop_Infinite", client);
			else
				Format(_sBuffer, 128, "%T", "Menu_Delete_Prop_Limited", client, g_iPlayerDeletes[client], g_iDeleteAdmin);

			AddMenuItem(_hMenu, "3", _sBuffer);
		}
		
		if(g_bControlAllowed && g_iControlAccess & ACCESS_ADMIN)
		{
			Format(_sBuffer, 128, "%T", "Menu_Control_Prop", client);	
			AddMenuItem(_hMenu, "4", _sBuffer);
		}
		
		if(g_iCheckAccess & ACCESS_ADMIN)
		{
			Format(_sBuffer, 128, "%T", "Menu_Check_Prop", client);
			AddMenuItem(_hMenu, "7", _sBuffer);
		}

		if(g_bAccessSettings)
		{
			Format(_sBuffer, 128, "%T", "Menu_Player_Actions", client);
			AddMenuItem(_hMenu, "5", _sBuffer);
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
	{
		if(g_iPropSupporter != -1)
		{
			if(!g_iPropSupporter)
				Format(_sBuffer, 128, "%T", "Menu_Spawn_Prop_Infinite", client);
			else
				Format(_sBuffer, 128, "%T", "Menu_Spawn_Prop_Limited", client, g_iPlayerProps[client], g_iPropSupporter);

			AddMenuItem(_hMenu, "0", _sBuffer, Bool_SpawnValid(client, false, true) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		
		if(g_bRotationAllowed)
		{
			Format(_sBuffer, 128, "%T", "Menu_Rotate_Prop", client);
			AddMenuItem(_hMenu, "1", _sBuffer, Bool_RotateValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_bPositionAllowed)
		{
			Format(_sBuffer, 128, "%T", "Menu_Position_Prop", client);
			AddMenuItem(_hMenu, "2", _sBuffer, Bool_MoveValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		
		if(g_iDeleteSupporter != -1)
		{
			if(!g_iDeleteSupporter)
				Format(_sBuffer, 128, "%T", "Menu_Delete_Prop_Infinite", client);
			else
				Format(_sBuffer, 128, "%T", "Menu_Delete_Prop_Limited", client, g_iPlayerDeletes[client], g_iDeleteSupporter);

			AddMenuItem(_hMenu, "3", _sBuffer, Bool_DeleteValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		
		if(g_bControlAllowed && g_iControlAccess & ACCESS_SUPPORTER)
		{
			Format(_sBuffer, 128, "%T", "Menu_Control_Prop", client);
			AddMenuItem(_hMenu, "4", _sBuffer, Bool_ControlValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		
		if(g_iCheckAccess & ACCESS_SUPPORTER)
		{
			Format(_sBuffer, 128, "%T", "Menu_Check_Prop", client);
			AddMenuItem(_hMenu, "7", _sBuffer, Bool_CheckValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_bAccessSettings)
		{
			Format(_sBuffer, 128, "%T", "Menu_Player_Actions", client);
			AddMenuItem(_hMenu, "5", _sBuffer);
		}	
	}

	if(g_bAccessAdmin && (g_iAdminAccess[client] & ADMIN_DELETE || g_iAdminAccess[client] & ADMIN_TELEPORT || g_iAdminAccess[client] & ADMIN_COLOR))
	{
		Format(_sBuffer, 128, "%T", "Menu_Admin_Actions", client);
		AddMenuItem(_hMenu, "6", _sBuffer);
	}

	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Main(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Select:
		{
			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);

			switch(StringToInt(_sOption))
			{
				case 0:
				{
					if(Bool_SpawnValid(param1, true, true, MENU_MAIN))
						Menu_Create(param1);
				}
				case 1:
				{
					if(Bool_RotateValid(param1, true, MENU_MAIN))
						Menu_ModifyRotation(param1);
				}
				case 2:
				{
					if(Bool_MoveValid(param1, true, MENU_MAIN))
						Menu_ModifyPosition(param1);
				}
				case 3:
				{
					if(Bool_DeleteValid(param1, true, MENU_MAIN))
					{
						Void_DeleteProp(param1);
						Menu_Main(param1);
					}
				}
				case 4:
				{
					if(Bool_MoveValid(param1, true, MENU_MAIN))
						Menu_Control(param1);
				}
				case 5:
				{
					Menu_PlayerActions(param1);
					return;
				}
				case 6:
				{
					if(!Menu_Admin(param1))
						Menu_Main(param1);

					return;
				}
				case 7:
				{
					if(Bool_CheckValid(param1, true, MENU_MAIN))
					{
						Void_CheckProp(param1);
						Menu_Main(param1);
					}
				}
			}
		}
	}
}

Menu_Create(client, index = 0)
{
	decl String:_sTemp[4], String:_sBuffer[128];
	new Handle:_hMenu = CreateMenu(MenuHandler_CreateMenu);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	for(new i = 0; i < g_iNumProps; i++)
	{
		if(g_iDefinedPropAccess[i] & g_iPlayerAccess[client])
		{
			Format(_sTemp, 4, "%d", i);
			if(g_bShowIndex)
			{
				Format(_sBuffer, 128, "[%s%d] %s", (i <= 9) ? "  " : "", i, g_sDefinedPropNames[i]);
				AddMenuItem(_hMenu, _sTemp, _sBuffer);
			}
			else
				AddMenuItem(_hMenu, _sTemp, g_sDefinedPropNames[i]);
		}
	}

	DisplayMenuAtItem(_hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_CreateMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Main(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			
			Void_SpawnProp(param1, StringToInt(_sOption), GetMenuSelectionPosition());
		}
	}
}

Void_SpawnProp(client, type, slot)
{
	if(Bool_SpawnAllowed(client, true) && Bool_SpawnValid(client, true, true, MENU_MAIN))
	{
		decl Float:_fOrigin[3], Float:_fAngles[3], Float:_fDirection[3];
		GetClientEyePosition(client, _fOrigin);
		GetClientEyeAngles(client, _fAngles);
		_fDirection = _fAngles;
		TR_TraceRayFilter(_fOrigin, _fDirection, MASK_SOLID, RayType_Infinite, Tracer_FilterBlocks, client);
		if(TR_DidHit(INVALID_HANDLE))
		{
			TR_GetEndPosition(_fOrigin, INVALID_HANDLE);
			if(Bool_SpawnProximity(client, _fOrigin))
			{
			
				TR_GetPlaneNormal(INVALID_HANDLE, _fAngles);
				new bool:_bTemp = (!FloatAbs(_fAngles[0]) && !FloatAbs(_fAngles[1])) ? true : false;

				GetVectorAngles(_fAngles, _fAngles);
				if(g_bPosSnapAllowed)
				{
					_fOrigin[0] = float(RoundToFloor(_fOrigin[0] / g_fDefinedPositions[g_iConfigPosition[client]])) * g_fDefinedPositions[g_iConfigPosition[client]];
					_fOrigin[1] = float(RoundToFloor(_fOrigin[1] / g_fDefinedPositions[g_iConfigPosition[client]])) * g_fDefinedPositions[g_iConfigPosition[client]];
					_fOrigin[2] = float(RoundToFloor(_fOrigin[2]));
				}
				else
				{
					_fOrigin[0] = float(RoundToFloor(_fOrigin[0]));
					_fOrigin[1] = float(RoundToFloor(_fOrigin[1]));
					_fOrigin[2] = float(RoundToFloor(_fOrigin[2]));
				}

				if(g_bRotSnapAllowed && _bTemp)
					_fAngles[1] = float(RoundToNearest(_fDirection[1] / g_fDefinedRotations[g_iConfigRotation[client]])) * g_fDefinedRotations[g_iConfigRotation[client]];
				_fAngles[0] += 90.0;

				new entity = Entity_SpawnProp(client, type, _fOrigin, _fAngles);
				PushArrayCell(g_hArray_PlayerProps[client], entity);
				g_iPlayerProps[client]++;
			
				switch(g_iTeam[client])
				{
					case TEAM_RED:
						g_iPointsRed += POINTS_BUILD;
					case TEAM_BLUE:
						g_iPointsBlue += POINTS_BUILD;
				}

				new _iMax = Int_SpawnMaximum(client);
				if(g_iPlayerAccess[client] & ACCESS_ADMIN)
				{
					if(_iMax)
						PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Limited_Admin", g_sDefinedPropNames[type], (_iMax - g_iPlayerProps[client]), _iMax, entity, g_iCurEntities);
					else
						PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Infinite_Admin", g_sDefinedPropNames[type], entity, g_iCurEntities);
				}
				else
				{
					if(_iMax)
						PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Limited", g_sDefinedPropNames[type], (_iMax - g_iPlayerProps[client]), _iMax);
					else
						PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Infinite", g_sDefinedPropNames[type]);
				}
			}
		}

		Menu_Create(client, slot);
		return;
	}
}

Void_SpawnClone(client, entity)
{
	if(Bool_SpawnAllowed(client, true) && Bool_SpawnValid(client, true, true))
	{
		decl Float:_fOrigin[3], Float:_fRotation[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", _fOrigin);
		if(Bool_SpawnProximity(client, _fOrigin))
		{		
			GetEntPropVector(entity, Prop_Data, "m_angRotation", _fRotation);
			new _iType = g_iPropType[entity];
			new _iEnt = Entity_SpawnProp(client, _iType, _fOrigin, _fRotation);
			PushArrayCell(g_hArray_PlayerProps[client], _iEnt);
			g_iPlayerProps[client]++;
				
			switch(g_iTeam[client])
			{
				case TEAM_RED:
					g_iPointsRed += POINTS_BUILD;
				case TEAM_BLUE:
					g_iPointsBlue += POINTS_BUILD;
			}

			new _iMax = Int_SpawnMaximum(client);
			if(g_iPlayerAccess[client] & ACCESS_ADMIN)
			{
				if(_iMax)
					PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Limited_Admin", g_sDefinedPropNames[_iType], (_iMax - g_iPlayerProps[client]), _iMax, _iEnt, g_iCurEntities);
				else
					PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Infinite_Admin", g_sDefinedPropNames[_iType], _iEnt, g_iCurEntities);
			}
			else
			{
				if(_iMax)
					PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Limited", g_sDefinedPropNames[_iType], (_iMax - g_iPlayerProps[client]), _iMax);
				else
					PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Infinite", g_sDefinedPropNames[_iType]);
			}
		}
	}
}

Void_SpawnChat(client, type)
{
	decl Float:_fOrigin[3], Float:_fAngles[3], Float:_fDirection[3];
	GetClientEyePosition(client, _fOrigin);
	GetClientEyeAngles(client, _fAngles);
	GetClientEyeAngles(client, _fDirection);
	TR_TraceRayFilter(_fOrigin, _fDirection, MASK_SOLID, RayType_Infinite, Tracer_FilterBlocks, client);
	if(TR_DidHit(INVALID_HANDLE))
	{
		TR_GetEndPosition(_fOrigin, INVALID_HANDLE);
		if(Bool_SpawnProximity(client, _fOrigin))
		{
			new bool:_bTemp = false;
			TR_GetPlaneNormal(INVALID_HANDLE, _fAngles);
			if(!FloatAbs(_fAngles[0]) && !FloatAbs(_fAngles[1]))
				_bTemp = true;

			GetVectorAngles(_fAngles, _fAngles);
			if(g_bPosSnapAllowed)
			{
				_fOrigin[0] = float(RoundToNearest(_fOrigin[0] / g_fDefinedPositions[g_iConfigPosition[client]])) * g_fDefinedPositions[g_iConfigPosition[client]];
				_fOrigin[1] = float(RoundToNearest(_fOrigin[1] / g_fDefinedPositions[g_iConfigPosition[client]])) * g_fDefinedPositions[g_iConfigPosition[client]];
				_fOrigin[2] = float(RoundToNearest(_fOrigin[2]));
			}
			else
			{
				_fOrigin[0] = float(RoundToNearest(_fOrigin[0]));
				_fOrigin[1] = float(RoundToNearest(_fOrigin[1]));
				_fOrigin[2] = float(RoundToNearest(_fOrigin[2]));
			}

			if(g_bRotSnapAllowed && _bTemp)
				_fAngles[1] = float(RoundToNearest(_fDirection[1] / g_fDefinedRotations[g_iConfigRotation[client]])) * g_fDefinedRotations[g_iConfigRotation[client]];
			_fAngles[0] += 90.0;
			
			new entity = Entity_SpawnProp(client, type, _fOrigin, _fAngles);
			PushArrayCell(g_hArray_PlayerProps[client], entity);
			g_iPlayerProps[client]++;
			
			switch(g_iTeam[client])
			{
				case TEAM_RED:
					g_iPointsRed += POINTS_BUILD;
				case TEAM_BLUE:
					g_iPointsBlue += POINTS_BUILD;
			}

			new _iMax = Int_SpawnMaximum(client);
			if(g_iPlayerAccess[client] & ACCESS_ADMIN)
			{
				if(_iMax)
					PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Limited_Admin", g_sDefinedPropNames[type], (_iMax - g_iPlayerProps[client]), _iMax, entity, g_iCurEntities);
				else
					PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Infinite_Admin", g_sDefinedPropNames[type], entity, g_iCurEntities);
			}
			else
			{
				if(_iMax)
					PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Limited", g_sDefinedPropNames[type], (_iMax - g_iPlayerProps[client]), _iMax);
				else
					PrintHintText(client, "%s%t", g_sPrefixHint, "Spawn_Prop_Infinite", g_sDefinedPropNames[type]);
			}
		}
	}
}

Void_DeleteProp(client, entity = 0)
{
	new _iEnt = (entity > 0) ? entity : Trace_GetEntity(client);
	if(Entity_Valid(_iEnt))
	{
		new _iOwner = GetClientOfUserId(g_iPropUser[_iEnt]);
		if(!_iOwner)
		{
			if(g_iAdminAccess[client] & ADMIN_DELETE)
				Entity_DeleteProp(_iEnt);
			else
				PrintHintText(client, "%s%t", g_sPrefixHint, "Delete_Prop_Failure", g_sDefinedPropNames[g_iPropType[_iEnt]], g_sPropOwner[_iEnt]);
		}
		else
		{
			switch(g_iTeam[_iOwner])
			{
				case TEAM_RED:
					g_iPointsRed += POINTS_DELETE;
				case TEAM_BLUE:
					g_iPointsBlue += POINTS_DELETE;
			}

			new _iDelete;
			if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
				_iDelete = g_iDeletePublic;
			else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
				_iDelete = g_iDeleteAdmin;
			else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
				_iDelete = g_iDeleteSupporter;
			
			if(_iDelete && g_iPlayerDeletes[client] >= _iDelete)
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Reached");
			else
			{								
				if(_iOwner == client)
				{
					if(_iDelete)
						PrintHintText(client, "%s%t", g_sPrefixHint, "Delete_Prop_Limited", g_sDefinedPropNames[g_iPropType[_iEnt]], (_iDelete - (g_iPlayerDeletes[client] + 1)), _iDelete);
					else
						PrintHintText(client, "%s%t", g_sPrefixHint, "Delete_Prop_Infinite", g_sDefinedPropNames[g_iPropType[_iEnt]]);
						
					Void_DeleteClientProp(client, _iEnt);
				}
				else
				{
					if(g_iPlayerAccess[client] & ACCESS_ADMIN)
					{
						PrintHintText(client, "%s%t", g_sPrefixHint, "Delete_Prop_Admin", g_sDefinedPropNames[g_iPropType[_iEnt]], g_sName[_iOwner]);
						Void_DeleteClientProp(_iOwner, _iEnt);
					}
					else
						PrintHintText(client, "%s%t", g_sPrefixHint, "Delete_Prop_Failure", g_sDefinedPropNames[g_iPropType[_iEnt]], g_sPropOwner[_iEnt]);
				}
			}
		}
	}
}

Menu_ModifyRotation(client, entity = 0)
{
	decl String:_sBuffer[128];
	new Handle:_hMenu = CreateMenu(MenuHandler_ModifyRotation);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuPagination(_hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	if(entity)
	{
		decl Float:_fAngles[3];
		GetEntPropVector(entity, Prop_Data, "m_angRotation", _fAngles);

		Format(_sBuffer, 128, "%T", "Menu_Rotation_Info", client, _fAngles[0], _fAngles[1], _fAngles[2]);
		AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
	}
	else
	{
		Format(_sBuffer, 128, "%T", "Menu_Rotation_Info_Missing", client);
		AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
	}
	
	new _iState = Bool_RotateValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
	Format(_sBuffer, 128, "%T", "Menu_Rotation_X_Plus", client, g_fDefinedRotations[g_iConfigRotation[client]]);
	AddMenuItem(_hMenu, "1", _sBuffer, _iState);
	Format(_sBuffer, 128, "%T", "Menu_Rotation_X_Minus", client, g_fDefinedRotations[g_iConfigRotation[client]]);
	AddMenuItem(_hMenu, "2", _sBuffer, _iState);
	Format(_sBuffer, 128, "%T", "Menu_Rotation_Y_Plus", client, g_fDefinedRotations[g_iConfigRotation[client]]);
	AddMenuItem(_hMenu, "3", _sBuffer, _iState);
	Format(_sBuffer, 128, "%T", "Menu_Rotation_Y_Minus", client, g_fDefinedRotations[g_iConfigRotation[client]]);
	AddMenuItem(_hMenu, "4", _sBuffer, _iState);
	Format(_sBuffer, 128, "%T", "Menu_Rotation_Z_Plus", client, g_fDefinedRotations[g_iConfigRotation[client]]);
	AddMenuItem(_hMenu, "5", _sBuffer, _iState);
	Format(_sBuffer, 128, "%T", "Menu_Rotation_Z_Minus", client, g_fDefinedRotations[g_iConfigRotation[client]]);
	AddMenuItem(_hMenu, "6", _sBuffer, _iState);
	Format(_sBuffer, 128, "%T", "Menu_Rotation_Reset", client);
	AddMenuItem(_hMenu, "7", _sBuffer);
	Format(_sBuffer, 128, "%T", "Menu_Rotation_Default", client);
	AddMenuItem(_hMenu, "0", _sBuffer);
		
	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_ModifyRotation(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Main(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			new _iTemp = StringToInt(_sOption);
			
			if(!_iTemp)
				Menu_DefaultRotation(param1);
			else
			{
				if(Bool_RotateValid(param1, true, MENU_ROTATE))
				{
					new entity = (g_iPlayerControl[param1] > 0) ? g_iPlayerControl[param1] : Trace_GetEntity(param1);
					if(Entity_Valid(entity))
					{
						new _iOwner = GetClientOfUserId(g_iPropUser[entity]);
						if(_iOwner == param1 || g_iPlayerAccess[param1] & ACCESS_ADMIN)
						{
							new bool:_bTemp, Float:_fTemp[3];
							switch(_iTemp)
							{
								case 1:
									_fTemp[0] = g_fDefinedRotations[g_iConfigRotation[param1]];
								case 2:
									_fTemp[0] = (g_fDefinedRotations[g_iConfigRotation[param1]] * -1);
								case 3:
									_fTemp[1] = g_fDefinedRotations[g_iConfigRotation[param1]];
								case 4:
									_fTemp[1] = (g_fDefinedRotations[g_iConfigRotation[param1]] * -1);
								case 5:
									_fTemp[2] = g_fDefinedRotations[g_iConfigRotation[param1]];
								case 6:
									_fTemp[2] = (g_fDefinedRotations[g_iConfigRotation[param1]] * -1);
								case 7:
									_bTemp = true;
							}

							if(g_iPlayerAccess[param1] & ACCESS_ADMIN)
							{
								if(_bTemp)
								{
									if(!_iOwner || _iOwner == param1)
										PrintHintText(param1, "%s%t", g_sPrefixHint, "Rotate_Prop_Reset_Admin", g_sDefinedPropNames[g_iPropType[entity]], entity, g_iCurEntities);
									else
										PrintHintText(param1, "%s%t", g_sPrefixHint, "Rotate_Prop_Reset_Client_Admin", g_sDefinedPropNames[g_iPropType[entity]], g_sName[_iOwner], entity, g_iCurEntities);
								}
								else
								{
									if(!_iOwner || _iOwner == param1)
										PrintHintText(param1, "%s%t", g_sPrefixHint, "Rotate_Prop_Admin", g_sDefinedPropNames[g_iPropType[entity]], g_fDefinedRotations[g_iConfigRotation[param1]], entity, g_iCurEntities);
									else
										PrintHintText(param1, "%s%t", g_sPrefixHint, "Rotate_Prop_Client_Admin", g_sDefinedPropNames[g_iPropType[entity]], g_sName[_iOwner], g_fDefinedRotations[g_iConfigRotation[param1]], entity, g_iCurEntities);
								}
							}
							else
							{
								if(_bTemp)
									PrintHintText(param1, "%s%t", g_sPrefixHint, "Rotate_Prop_Reset_Client", g_sDefinedPropNames[g_iPropType[entity]]);
								else
									PrintHintText(param1, "%s%t", g_sPrefixHint, "Rotate_Prop_Client", g_sDefinedPropNames[g_iPropType[entity]], g_fDefinedRotations[g_iConfigRotation[param1]]);
							}

							Entity_RotateProp(entity, _fTemp, _bTemp);
							Menu_ModifyRotation(param1, entity);
							return;
						}
						else
							PrintHintText(param1, "%s%t", g_sPrefixHint, "Rotate_Prop_Failure", g_sDefinedPropNames[g_iPropType[entity]], g_sPropOwner[entity]);
					}

					Menu_ModifyRotation(param1, 0);
				}
			}
		}
	}
}

Menu_DefaultRotation(client, index = 0)
{
	decl String:_sBuffer[128], String:_sTemp[4];

	new Handle:_hMenu = CreateMenu(MenuHandler_DefaultRotation);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	for(new i = 0; i < g_iNumRotations; i++)
	{
		IntToString(i, _sTemp, 4);
		Format(_sBuffer, 128, "%s%T", (g_iConfigRotation[client] == i) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Rotation_Option", client, g_fDefinedRotations[i]);
		AddMenuItem(_hMenu, _sTemp, _sBuffer);
	}

	DisplayMenuAtItem(_hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_DefaultRotation(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_ModifyRotation(param1, 0);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			g_iConfigRotation[param1] = StringToInt(_sOption);
			SetClientCookie(param1, g_cConfigRotation, _sOption);
			
			CPrintToChat(param1, "%s%t", g_sPrefixChat, "Settings_Rotation", g_fDefinedRotations[g_iConfigRotation[param1]]);
			Menu_DefaultRotation(param1, GetMenuSelectionPosition());
		}
	}
}

Menu_ModifyPosition(client, entity = 0)
{
	decl String:_sBuffer[128];
	new Handle:_hMenu = CreateMenu(MenuHandler_ModifyPosition);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuPagination(_hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	if(entity)
	{
		decl Float:_fOrigin[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", _fOrigin);

		Format(_sBuffer, 128, "%T", "Menu_Position_Info", client, _fOrigin[0], _fOrigin[1], _fOrigin[2]);
		AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
	}
	else
	{
		Format(_sBuffer, 128, "%T", "Menu_Position_Info_Missing", client);
		AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
	}

	new _iState = Bool_MoveValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
	Format(_sBuffer, 128, "%T", "Menu_Position_X_Plus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(_hMenu, "1", _sBuffer, _iState);
	Format(_sBuffer, 128, "%T", "Menu_Position_X_Minus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(_hMenu, "2", _sBuffer, _iState);
	Format(_sBuffer, 128, "%T", "Menu_Position_Y_Plus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(_hMenu, "3", _sBuffer, _iState);
	Format(_sBuffer, 128, "%T", "Menu_Position_Y_Minus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(_hMenu, "4", _sBuffer, _iState);
	Format(_sBuffer, 128, "%T", "Menu_Position_Z_Plus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(_hMenu, "5", _sBuffer, _iState);
	Format(_sBuffer, 128, "%T", "Menu_Position_Z_Minus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(_hMenu, "6", _sBuffer, _iState);
	Format(_sBuffer, 128, "%T", "Menu_Position_Default", client);
	AddMenuItem(_hMenu, "0", _sBuffer);

	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_ModifyPosition(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Main(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			new _iTemp = StringToInt(_sOption);
				
			if(!_iTemp)
				Menu_DefaultPosition(param1);
			else
			{
				if(Bool_MoveValid(param1, true, MENU_MOVE))
				{
					new entity = (g_iPlayerControl[param1] > 0) ? g_iPlayerControl[param1] : Trace_GetEntity(param1);
					if(Entity_Valid(entity))
					{
						new _iOwner = GetClientOfUserId(g_iPropUser[entity]);
						if(_iOwner == param1 || g_iPlayerAccess[param1] & ACCESS_ADMIN)
						{
							new Float:_fTemp[3];
							switch(_iTemp)
							{
								case 1:
									_fTemp[0] = g_fDefinedPositions[g_iConfigPosition[param1]];
								case 2:
									_fTemp[0] = (g_fDefinedPositions[g_iConfigPosition[param1]] * -1);
								case 3:
									_fTemp[1] = g_fDefinedPositions[g_iConfigPosition[param1]];
								case 4:
									_fTemp[1] = (g_fDefinedPositions[g_iConfigPosition[param1]] * -1);
								case 5:
									_fTemp[2] = g_fDefinedPositions[g_iConfigPosition[param1]];
								case 6:
									_fTemp[2] = (g_fDefinedPositions[g_iConfigPosition[param1]] * -1);
							}
							
							if(g_iPlayerAccess[param1] & ACCESS_ADMIN)
							{
								if(!_iOwner || _iOwner == param1)
									PrintHintText(param1, "%s%t", g_sPrefixHint, "Position_Own_Prop_Admin", g_sDefinedPropNames[g_iPropType[entity]], g_fDefinedPositions[g_iConfigPosition[param1]], entity, g_iCurEntities);
								else
									PrintHintText(param1, "%s%t", g_sPrefixHint, "Position_Other_Prop_Admin", g_sDefinedPropNames[g_iPropType[entity]], g_sName[_iOwner], g_fDefinedPositions[g_iConfigPosition[param1]], entity, g_iCurEntities);
							}
							else
								PrintHintText(param1, "%s%t", g_sPrefixHint, "Position_Own_Prop", g_sDefinedPropNames[g_iPropType[entity]], g_fDefinedPositions[g_iConfigPosition[param1]]);

							Entity_PositionProp(entity, _fTemp);
							Menu_ModifyPosition(param1, entity);
							return;
						}
						else
							PrintHintText(param1, "%s%t", g_sPrefixHint, "Position_Prop_Failure", g_sDefinedPropNames[g_iPropType[entity]], g_sPropOwner[entity]);
					}

					Menu_ModifyPosition(param1, 0);
				}
			}
		}
	}
	
	return;
}

Menu_DefaultPosition(client, index = 0)
{
	decl String:_sBuffer[128], String:_sTemp[4];

	new Handle:_hMenu = CreateMenu(MenuHandler_DefaultPosition);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	for(new i = 0; i < g_iNumPositions; i++)
	{
		IntToString(i, _sTemp, 4);
		Format(_sBuffer, 128, "%s%T", (g_iConfigPosition[client] == i) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Action_Position_Option", client, g_fDefinedPositions[i]);
		AddMenuItem(_hMenu, _sTemp, _sBuffer);
	}

	DisplayMenuAtItem(_hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_DefaultPosition(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_ModifyPosition(param1, 0);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			g_iConfigPosition[param1] = StringToInt(_sOption);
			SetClientCookie(param1, g_cConfigPosition, _sOption);
			
			CPrintToChat(param1, "%s%t", g_sPrefixChat, "Settings_Position", g_fDefinedPositions[g_iConfigPosition[param1]]);
			Menu_DefaultPosition(param1, GetMenuSelectionPosition());
		}
	}
}

Void_CheckProp(client, entity = 0)
{
	new _iEnt = (entity > 0) ? entity : Trace_GetEntity(client);
	if(Entity_Valid(_iEnt))
	{
		new _iOwner = GetClientOfUserId(g_iPropUser[_iEnt]);
		if(g_iPlayerAccess[client] & ACCESS_ADMIN)
			PrintHintText(client, "%s%t", g_sPrefixHint, "Check_Prop_Admin", g_sDefinedPropNames[g_iPropType[_iEnt]], _iOwner ? g_sName[_iOwner] : g_sPropOwner[_iEnt], _iEnt, g_iCurEntities);
		else
			PrintHintText(client, "%s%t", g_sPrefixHint, "Check_Prop", g_sDefinedPropNames[g_iPropType[_iEnt]], _iOwner ? g_sName[_iOwner] : g_sPropOwner[_iEnt]);
	}
}

Menu_Control(client)
{
	decl String:_sBuffer[128];
	new Handle:_hMenu = CreateMenu(MenuHandler_Grab);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuPagination(_hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	if(g_iPlayerControl[client] > 0)
		Format(_sBuffer, 128, "%T", "Menu_Control_Release", client);
	else
		Format(_sBuffer, 128, "%T", "Menu_Control_Issue", client);
	AddMenuItem(_hMenu, "0", _sBuffer, Bool_ControlValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	Format(_sBuffer, 128, "%T", "Menu_Control_Increase", client);
	AddMenuItem(_hMenu, "1", _sBuffer);

	Format(_sBuffer, 128, "%T", "Menu_Control_Decrease", client);
	AddMenuItem(_hMenu, "2", _sBuffer);

	if(g_iPlayerControl[client] > 0)
		Format(_sBuffer, 128, "%T", "Menu_Control_Clone", client, g_sDefinedPropNames[g_iPropType[g_iPlayerControl[client]]]);
	else
		Format(_sBuffer, 128, "%T", "Menu_Control_Empty", client);
	AddMenuItem(_hMenu, "3", _sBuffer, (g_iPlayerControl[client] > 0 && Bool_SpawnValid(client, false, true)) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	if(g_bRotSnapAllowed)
	{
		Format(_sBuffer, 128, "%s%T", (g_bConfigAxis[client][ROTATION_AXIS_X]) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Control_Rotation_Lock_X", client);
		AddMenuItem(_hMenu, "4", _sBuffer);

		Format(_sBuffer, 128, "%s%T", (g_bConfigAxis[client][ROTATION_AXIS_Y]) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Control_Rotation_Lock_Y", client);
		AddMenuItem(_hMenu, "5", _sBuffer);
	}
	
	if(g_bPosSnapAllowed)
	{
		Format(_sBuffer, 128, "%s%T", (g_bConfigAxis[client][POSITION_AXIS_X]) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Control_Position_Lock_X", client);
		AddMenuItem(_hMenu, "6", _sBuffer);

		Format(_sBuffer, 128, "%s%T", (g_bConfigAxis[client][POSITION_AXIS_Y]) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Control_Position_Lock_Y", client);
		AddMenuItem(_hMenu, "7", _sBuffer);
		
		Format(_sBuffer, 128, "%s%T", (g_bConfigAxis[client][POSITION_AXIS_Z]) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Control_Position_Lock_Z", client);
		AddMenuItem(_hMenu, "8", _sBuffer);
	}

	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Grab(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Main(param1);
		}
		case MenuAction_Select:
		{
			decl _iOption, String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			_iOption = StringToInt(_sOption);

			switch(_iOption)
			{
				case 0:
				{
					if(g_iPlayerControl[param1] > 0)
						Void_ClearClientControl(param1);
					else
					{
						new entity = Trace_GetEntity(param1, g_fGrabDistance);
						if(Entity_Valid(entity))
							Void_IssueGrab(param1, entity);
					}
				}
				case 1:
				{
					if(g_fConfigDistance[param1] < g_fGrabMaximum)
						g_fConfigDistance[param1] += g_fGrabInterval;
					else
						g_fConfigDistance[param1] = g_fGrabMinimum;

					PrintHintText(param1, "%s%t", g_sPrefixHint, "Settings_Cycle_Change", g_fConfigDistance[param1]);
				}
				case 2:
				{
					if(g_fConfigDistance[param1] > g_fGrabMinimum)
						g_fConfigDistance[param1] -= g_fGrabInterval;
					else
						g_fConfigDistance[param1] = g_fGrabMaximum;
						
					PrintHintText(param1, "%s%t", g_sPrefixHint, "Settings_Cycle_Change", g_fConfigDistance[param1]);
				}
				case 3:
				{
					if(g_iPlayerControl[param1] > 0)
						Void_SpawnClone(param1, g_iPlayerControl[param1]);
				}
				default:
				{
					_iOption -= 4;
					g_bConfigAxis[param1][_iOption] = !g_bConfigAxis[param1][_iOption];
					
					decl String:_sAxis[16] = "";
					for(new i = 0; i < AXIS_TOTAL; i++)
						Format(_sAxis, 16, "%s%s ", _sAxis, g_bConfigAxis[param1][i] ? "1" : "0");
					SetClientCookie(param1, g_cConfigLocks, _sAxis);
					
					if(_iOption >= ROTATION_AXIS_X && _iOption <= ROTATION_AXIS_Y)
					{
						if(g_bConfigAxis[param1][_iOption])
							PrintHintText(param1, "%s%t", g_sPrefixHint, "Settings_Rotation_Lock", g_sAxisDisplay[_iOption]);
						else
							PrintHintText(param1, "%s%t", g_sPrefixHint, "Settings_Rotation_Unlock", g_sAxisDisplay[_iOption]);
					}
					else if(_iOption >= POSITION_AXIS_X && _iOption <= POSITION_AXIS_Z)
					{
						if(g_bConfigAxis[param1][_iOption])
							PrintHintText(param1, "%s%t", g_sPrefixHint, "Settings_Position_Lock", g_sAxisDisplay[_iOption]);
						else
							PrintHintText(param1, "%s%t", g_sPrefixHint, "Settings_Position_Unlock", g_sAxisDisplay[_iOption]);
					}
				}
			}

			Menu_Control(param1);
		}
	}
}

Menu_PlayerActions(client)
{
	decl String:_sBuffer[128];
	
	new Handle:_hMenu = CreateMenu(MenuHandler_PlayerActions);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
	{
		if(g_iColorPublic != -1 && !g_iColoringPublic && g_bColorAllowed)
		{
			if(!g_iColorPublic)
				Format(_sBuffer, 128, "%T", "Menu_Action_Color_Infinite", client);
			else
				Format(_sBuffer, 128, "%T", "Menu_Action_Color_Limited", client, g_iPlayerColors[client], g_iColorPublic);
			AddMenuItem(_hMenu, "1", _sBuffer, Bool_ColorValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_iTeleportPublic != -1)
		{
			if(!g_iTeleportPublic)
				Format(_sBuffer, 128, "%T", "Menu_Action_Teleport_Infinite", client);
			else
				Format(_sBuffer, 128, "%T", "Menu_Action_Teleport_Limited", client, g_iPlayerTeleports[client], g_iTeleportPublic);
			AddMenuItem(_hMenu, "2", _sBuffer, Bool_TeleportValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		
		if(g_iDeletePublic != -1)
		{
			Format(_sBuffer, 128, "%T", "Menu_Action_Delete", client);
			AddMenuItem(_hMenu, "3", _sBuffer, Bool_ClearValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
	{
		if(g_iColorAdmin != -1 && !g_iColoringAdmin && g_bColorAllowed)
		{
			if(!g_iColorAdmin)
				Format(_sBuffer, 128, "%T", "Menu_Action_Color_Infinite", client);
			else
				Format(_sBuffer, 128, "%T", "Menu_Action_Color_Limited", client, g_iPlayerColors[client], g_iColorAdmin);
			AddMenuItem(_hMenu, "1", _sBuffer);
		}

		if(g_iTeleportAdmin != -1)
		{
			if(!g_iTeleportAdmin)
				Format(_sBuffer, 128, "%T", "Menu_Action_Teleport_Infinite", client);
			else
				Format(_sBuffer, 128, "%T", "Menu_Action_Teleport_Limited", client, g_iPlayerTeleports[client], g_iTeleportAdmin);
			AddMenuItem(_hMenu, "2", _sBuffer);
		}

		if(g_iDeleteAdmin != -1)
		{
			Format(_sBuffer, 128, "%T", "Menu_Action_Delete", client);
			AddMenuItem(_hMenu, "3", _sBuffer);
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
	{
		if(g_iColorSupporter != -1 && !g_iColoringSupporter && g_bColorAllowed)
		{
			if(!g_iColorSupporter)
				Format(_sBuffer, 128, "%T", "Menu_Action_Color_Infinite", client);
			else
				Format(_sBuffer, 128, "%T", "Menu_Action_Color_Limited", client, g_iPlayerColors[client], g_iColorSupporter);
			AddMenuItem(_hMenu, "1", _sBuffer, Bool_ColorValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_iTeleportSupporter != -1)
		{
			if(!g_iTeleportSupporter)
				Format(_sBuffer, 128, "%T", "Menu_Action_Teleport_Infinite", client);
			else
				Format(_sBuffer, 128, "%T", "Menu_Action_Teleport_Limited", client, g_iPlayerTeleports[client], g_iTeleportSupporter);
			AddMenuItem(_hMenu, "2", _sBuffer, Bool_TeleportValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_iDeleteSupporter != -1)
		{
			Format(_sBuffer, 128, "%T", "Menu_Action_Delete", client);
			AddMenuItem(_hMenu, "3", _sBuffer, Bool_ClearValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
	}
	
	if(g_bRotSnapAllowed)
	{
		Format(_sBuffer, 128, "%T", "Menu_Rotation_Default", client);
		AddMenuItem(_hMenu, "4", _sBuffer);
	}
	
	if(g_bPosSnapAllowed)
	{
		Format(_sBuffer, 128, "%T", "Menu_Position_Default", client);
		AddMenuItem(_hMenu, "5", _sBuffer);
	}
	
	if(g_bQuickAllowed && g_iPlayerAccess[client] & g_iQuickAccess)
	{
		Format(_sBuffer, 128, "%T", "Menu_Action_Quick", client);
		AddMenuItem(_hMenu, "6", _sBuffer);
	}

	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_PlayerActions(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Main(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			switch(StringToInt(_sOption))
			{
				case 1:
				{
					Menu_DefaultColors(param1);
				}
				case 2:
				{
					if(Bool_TeleportValid(param1, true, MENU_ACTION))
						Menu_ConfirmTeleport(param1);
				}
				case 3:
				{
					if(Bool_ClearValid(param1, true, MENU_ACTION))
						Menu_ConfirmDelete(param1);
				}
				case 4:
				{
					Menu_DefaultRotation(param1);
				}
				case 5:
				{
					Menu_DefaultPosition(param1);
				}
				case 6:
				{
					Menu_DefaultQuick(param1);
				}
			}
		}
	}
}

Menu_DefaultColors(client, index = 0)
{
	decl String:_sTemp[4], String:_sBuffer[128];

	new Handle:_hMenu = CreateMenu(MenuHandler_DefaultColors);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	for(new i = 0; i < g_iNumColors; i++)
	{
		IntToString(i, _sTemp, 4);
		Format(_sBuffer, 128, "%s%s", (g_iConfigColor[client] == i) ? g_sPrefixSelect : g_sPrefixEmpty, g_sDefinedColorNames[i]);
		AddMenuItem(_hMenu, _sTemp, _sBuffer);
	}

	DisplayMenuAtItem(_hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_DefaultColors(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_PlayerActions(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			g_iConfigColor[param1] = StringToInt(_sOption);
			SetClientCookie(param1, g_cConfigColor, _sOption);

			CPrintToChat(param1, "%s%t", g_sPrefixChat, "Settings_Color", g_sDefinedColorNames[g_iConfigColor[param1]]);
			if((g_iPlayerAccess[param1] & ACCESS_ADMIN) || (Bool_CheckAction(param1) && !(g_iCurrentDisable & DISABLE_COLOR)))
			{
				if(g_iPlayerProps[param1] > 0)
				{
					new _iMax;
					if(g_iPlayerAccess[param1] == ACCESS_PUBLIC)
						_iMax = g_iColorPublic;
					else if(g_iPlayerAccess[param1] & ACCESS_ADMIN)
						_iMax = g_iColorAdmin;
					else if(g_iPlayerAccess[param1] & ACCESS_SUPPORTER)
						_iMax = g_iColorSupporter;

					if(_iMax && g_iPlayerColors[param1] >= _iMax)
					{
						CPrintToChat(param1, "%s%t", g_sPrefixChat, "Color_Prop_Limit_Reached");
						Menu_PlayerActions(param1);
						return;
					}
					else
					{
						g_iPlayerColors[param1]++;
						Void_ColorClientProps(param1, g_iConfigColor[param1]);
					}
				}
			}

			Menu_DefaultColors(param1, GetMenuSelectionPosition());
		}
	}
}

Menu_ConfirmTeleport(client)
{
	decl String:_sBuffer[128];

	new Handle:_hMenu = CreateMenu(MenuHandler_ConfirmTeleport);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	Format(_sBuffer, 128, "%T", "Menu_Action_Confirm_Teleport_Ask", client);
	AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
	Format(_sBuffer, 128, "%T", "Menu_Action_Confirm_Teleport_Yes", client);
	AddMenuItem(_hMenu, "1", _sBuffer);
	Format(_sBuffer, 128, "%T", "Menu_Action_Confirm_Teleport_No", client);
	AddMenuItem(_hMenu, "0", _sBuffer);
	
	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_ConfirmTeleport(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_PlayerActions(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);

			if(Bool_TeleportValid(param1, true, MENU_ACTION))
			{
				if(StringToInt(_sOption))
					Void_PerformTeleport(param1);
				else
					Menu_PlayerActions(param1);
			}
		}
	}
}

Menu_ConfirmDelete(client)
{
	decl String:_sBuffer[128];

	new Handle:_hMenu = CreateMenu(MenuHandler_ConfirmDelete);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	Format(_sBuffer, 128, "%T", "Menu_Action_Confirm_Delete_Ask", client);
	AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
	Format(_sBuffer, 128, "%T", "Menu_Action_Confirm_Delete_Yes", client);
	AddMenuItem(_hMenu, "1", _sBuffer);
	Format(_sBuffer, 128, "%T", "Menu_Action_Confirm_Delete_No", client);
	AddMenuItem(_hMenu, "0", _sBuffer);
	
	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_ConfirmDelete(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_PlayerActions(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);

			if(StringToInt(_sOption) && Bool_ClearValid(param1, true, MENU_ACTION))
				Bool_ClearClientProps(param1, true, true);
			else
				Menu_PlayerActions(param1);
		}
	}
}

Menu_DefaultQuick(client)
{
	decl String:_sBuffer[128];

	new Handle:_hMenu = CreateMenu(MenuHandler_DefaultQuick);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	Format(_sBuffer, 128, "%s%T", (g_iConfigQuick[client] == QUICK_DISABLE) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Action_Quick_Disabled", client);
	AddMenuItem(_hMenu, "0", _sBuffer);
	
	Format(_sBuffer, 128, "%s%T", (g_iConfigQuick[client] == QUICK_MENU) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Action_Quick_Menu", client);
	AddMenuItem(_hMenu, "1", _sBuffer);

	if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
	{
		if(g_iDeletePublic != -1)
		{
			Format(_sBuffer, 128, "%s%T", (g_iConfigQuick[client] == QUICK_DELETE) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Action_Quick_Delete", client);
			AddMenuItem(_hMenu, "2", _sBuffer);
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
	{
		if(g_iDeleteAdmin != -1)
		{
			Format(_sBuffer, 128, "%s%T", (g_iConfigQuick[client] == QUICK_DELETE) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Action_Quick_Delete", client);
			AddMenuItem(_hMenu, "2", _sBuffer);
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
	{
		if(g_iDeleteSupporter != -1)
		{
			Format(_sBuffer, 128, "%s%T", (g_iConfigQuick[client] == QUICK_DELETE) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Action_Quick_Delete", client);
			AddMenuItem(_hMenu, "2", _sBuffer);
		}
	}

	if(g_iPlayerAccess[client] & g_iControlAccess)
	{
		Format(_sBuffer, 128, "%s%T", (g_iConfigQuick[client] == QUICK_CLONE) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Action_Quick_Clone", client);
		AddMenuItem(_hMenu, "3", _sBuffer);
	}
	
	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_DefaultQuick(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_PlayerActions(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			g_iConfigQuick[param1] = StringToInt(_sOption);
			SetClientCookie(param1, g_cConfigQuick, _sOption);

			switch(g_iConfigQuick[param1])
			{
				case QUICK_DISABLE:
					CPrintToChat(param1, "%s%t", g_sPrefixChat, "Settings_Action_Quick_Disabled");
				case QUICK_MENU:
					CPrintToChat(param1, "%s%t", g_sPrefixChat, "Settings_Action_Quick_Menu");
				case QUICK_DELETE:
					CPrintToChat(param1, "%s%t", g_sPrefixChat, "Settings_Action_Quick_Delete");
				case QUICK_CLONE:
					CPrintToChat(param1, "%s%t", g_sPrefixChat, "Settings_Action_Quick_Clone");
			}
			Menu_DefaultQuick(param1);
		}
	}
	
	return;
}

Menu_Admin(client)
{
	decl String:_sBuffer[128];
	new _iOptions, Handle:_hMenu = CreateMenu(MenuHandler_Admin);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	if(g_iAdminAccess[client] & ADMIN_DELETE)
	{
		_iOptions++;
		Format(_sBuffer, 128, "%T", "Menu_Admin_Delete", client);
		AddMenuItem(_hMenu, "0", _sBuffer);
	}
	
	if(g_iAdminAccess[client] & ADMIN_TELEPORT)
	{
		_iOptions++;
		Format(_sBuffer, 128, "%T", "Menu_Admin_Teleport", client);
		AddMenuItem(_hMenu, "1", _sBuffer);
	}

	if(g_iAdminAccess[client] & ADMIN_COLOR)
	{
		_iOptions++;
		Format(_sBuffer, 128, "%T", "Menu_Admin_Color", client);
		AddMenuItem(_hMenu, "2", _sBuffer);
	}

	if(g_iAdminAccess[client] & ADMIN_MANAGE)
	{
		_iOptions++;
		Format(_sBuffer, 128, "%T", "Menu_Admin_Manage", client);
		AddMenuItem(_hMenu, "3", _sBuffer);
	}
	
	if(_iOptions)
		DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
		
	return _iOptions;
}

public MenuHandler_Admin(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Main(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			
			new _iOption = StringToInt(_sOption);
			if(_iOption == 3)
				Menu_AdminManage(param1);
			else
				Menu_AdminSelect(param1, _iOption);
		}
	}
}

Menu_AdminManage(client, index = 0)
{
	decl String:_sBuffer[128], String:_sTemp[4];
	new Handle:_hMenu = CreateMenu(MenuHandler_AdminManage);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	for(new i = 0; i < CVAR_COUNT; i++)
	{
		Format(_sTemp, 4, "%d", i);

		GetConVarName(g_hCvar[i], _sBuffer, 128);
		AddMenuItem(_hMenu, _sTemp, _sBuffer);
	}

	DisplayMenuAtItem(_hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_AdminManage(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Admin(param1);
		}
		case MenuAction_Select:
		{
			/*
			decl String:_sOption[4], String:_sBuffer[128];
			GetMenuItem(menu, param2, _sOption, 4);
			new _iOption = StringToInt(_sOption);
			
			GetConVarString(g_hCvar[_iOption], _sBuffer, 128);
			new _iType = TYPE_INT;
			if(!IsCharAlpha(_sBuffer[0]))
				_iType = TYPE_STRING;
			else if(FindCharInString(_sBuffer, '.'))
				_iType = TYPE_FLOAT;
			else
			{
				decl Float:_fUpper, Float:_fLower, bool:_bUpper, bool:_bLower;
				_bUpper = GetConVarBounds(g_hCvar[_iOption], ConVarBound_Upper, _fUpper);
				_bLower = GetConVarBounds(g_hCvar[_iOption], ConVarBound_Lower, _fLower);
				
				if((_bUpper && _fUpper == 1.0) && (_bLower && _fLower == 0.0))
					_iType = TYPE_BOOL;
			}
			*/
			
			//if(_iType == TYPE_STRING)
			//{
			//	GetConVarName(g_hCvar[_iOption], _sBuffer, 128);
			//	CPrintToChat(param1, "%s%t", g_sPrefixChat, "Menu_Admin_Manage_String", _sBuffer);
			Menu_AdminManage(param1, GetMenuSelectionPosition());
			//}
			//else
			//	Menu_AdminManageModify(param1, index = 0, GetMenuSelectionPosition(), _iOption, _iType);
		}
	}
}

/*
Menu_AdminManageModify(client, index = 0, previous = 0, cvar, type)
{
	decl String:_sBuffer[128], String:_sTemp[32];
	new Handle:_hMenu = CreateMenu(MenuHandler_AdminManageModify);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	switch(type)
	{
		case TYPE_INT:
		{
			decl Float:_fUpper, Float:_fLower, bool:_bUpper, bool:_bLower;
			_bUpper = GetConVarBounds(g_hCvar[_iOption], ConVarBound_Upper, _fUpper);
			_bLower = GetConVarBounds(g_hCvar[_iOption], ConVarBound_Lower, _fLower);
			
			if(_bUpper)
			{
				//Must be a lower
			}
			else if(_bLower)
			{
			
			}
			else
			{
			
			}
		}
		case TYPE_BOOL:
		{
			decl String:_sName[128];
			GetConVarName(g_hCvar[cvar], _sName, 128);
			new bool:_bTemp = GetConVarInt(g_hCvar[cvar]) ? true : false;

			Format(_sBuffer, 128, "%t%s", "Menu_Admin_Manage_Enable", _sName);
			Format(_sTemp, 32, "%d %d %d %b", i, previous, cvar, type, false);
			AddMenuItem(_hMenu, _sTemp, _sBuffer, _bTemp ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

			Format(_sBuffer, 128, "%t%s", "Menu_Admin_Manage_Disable", _sName);
			Format(_sTemp, 32, "%d %d %d %b", i, previous, cvar, type, true);
			AddMenuItem(_hMenu, _sTemp, _sBuffer, !_bTemp ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		}
		case TYPE_FLOAT:
		{
		
		}
	}
	
	for(new i = 0; i < CVAR_COUNT; i++)
	{
		Format(_sTemp, 32, "%d", i);

		AddMenuItem(_hMenu, _sTemp, _sBuffer);
	}

	DisplayMenuAtItem(_hMenu, client, index, MENU_TIME_FOREVER);
}
*/

Menu_AdminSelect(client, action)
{
	decl String:_sBuffer[128], String:_sTemp[16];
	new Handle:_hMenu = CreateMenu(MenuHandler_AdminSelect);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	Format(_sBuffer, 128, "%T", "Menu_Admin_Select_Single", client);
	Format(_sTemp, 16, "%d %d", action, TARGET_SINGLE);
	AddMenuItem(_hMenu, _sTemp, _sBuffer);
	
	if(g_iAdminAccess[client] & ADMIN_TARGET)
	{
		Format(_sBuffer, 128, "%T", "Menu_Admin_Select_Red", client);
		Format(_sTemp, 16, "%d %d", action, TARGET_RED);
		AddMenuItem(_hMenu, _sTemp, _sBuffer);
		
		Format(_sBuffer, 128, "%T", "Menu_Admin_Select_Blue", client);
		Format(_sTemp, 16, "%d %d", action, TARGET_BLUE);
		AddMenuItem(_hMenu, _sTemp, _sBuffer);

		Format(_sBuffer, 128, "%T", "Menu_Admin_Select_Mass", client);
		Format(_sTemp, 16, "%d %d", action, TARGET_ALL);
		AddMenuItem(_hMenu, _sTemp, _sBuffer);
	}

	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminSelect(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Admin(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sBuffer[16], String:_sOption[2][8];
			GetMenuItem(menu, param2, _sBuffer, 16);
			ExplodeString(_sBuffer, " ", _sOption, 2, 8);
			
			new _iGroup = StringToInt(_sOption[1]);
			switch(StringToInt(_sOption[0]))
			{
				case 0:
				{
					if(_iGroup == TARGET_SINGLE)
						Menu_AdminSelectSingle(param1, 0);
					else
						Menu_AdminConfirmDelete(param1, _iGroup);
				}
				case 1:
				{
					if(_iGroup == TARGET_SINGLE)
						Menu_AdminSelectSingle(param1, 1);
					else
						Menu_AdminConfirmTeleport(param1, _iGroup);
				}
				case 2:
				{
					if(_iGroup == TARGET_SINGLE)
						Menu_AdminSelectSingle(param1, 2);
					else
						Menu_AdminSelectColor(param1, _iGroup);
				}
			}
		}
	}
}

Menu_AdminSelectSingle(client, action)
{
	decl String:_sTemp[16];
	new Handle:_hMenu = CreateMenu(MenuHandler_AdminSelectSingle);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	switch(action)
	{
		case 0:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && g_iPlayerProps[i] > 0)
				{
					Format(_sTemp, 16, "%d %d", action, GetClientUserId(i));
					AddMenuItem(_hMenu, _sTemp, g_sName[i]);
				}
			}
		}
		case 1:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && g_bAlive[i])
				{
					Format(_sTemp, 16, "%d %d", action, GetClientUserId(i));
					AddMenuItem(_hMenu, _sTemp, g_sName[i]);
				}
			}
		}
		case 2:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && g_iPlayerProps[i] > 0)
				{
					Format(_sTemp, 16, "%d %d", action, GetClientUserId(i));
					AddMenuItem(_hMenu, _sTemp, g_sName[i]);
				}
			}
		}
	}

	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminSelectSingle(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Admin(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sBuffer[16], String:_sOption[2][8];
			GetMenuItem(menu, param2, _sBuffer, 16);
			ExplodeString(_sBuffer, " ", _sOption, 2, 8);
			
			new _iTarget = GetClientOfUserId(StringToInt(_sOption[1]));
			if(!_iTarget || !IsClientInGame(_iTarget))
				CPrintToChat(param1, "%s%t", g_sPrefixChat, "Admin_Locate_Failure");
			else if(!CanUserTarget(param1, _iTarget))
				CPrintToChat(param1, "%s%t", g_sPrefixChat, "Admin_Target_Failure");
			else
			{
				switch(StringToInt(_sOption[0]))
				{
					case 0:
						Menu_AdminConfirmDelete(param1, TARGET_SINGLE, StringToInt(_sOption[1]));
					case 1:
						Menu_AdminConfirmTeleport(param1, TARGET_SINGLE, StringToInt(_sOption[1]));
					case 2:
						Menu_AdminSelectColor(param1, TARGET_SINGLE, StringToInt(_sOption[1]));
				}

				return;
			}
			
			Menu_Admin(param1);
		}
	}
}

Menu_AdminConfirmDelete(client, group, target = 0)
{
	decl String:_sBuffer[128], String:_sTemp[36];

	new Handle:_hMenu = CreateMenu(MenuHandler_AdminConfirmDelete);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);
	
	switch(group)
	{
		case TARGET_SINGLE:
		{
			Format(_sBuffer, 128, "%T", "Menu_Admin_Confirm_Delete_Single", client, g_sName[GetClientOfUserId(target)]);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_RED:
		{
			Format(_sBuffer, 128, "%T", "Menu_Admin_Confirm_Delete_Red", client);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}		
		case TARGET_BLUE:
		{
			Format(_sBuffer, 128, "%T", "Menu_Admin_Confirm_Delete_Blue", client);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}		
		case TARGET_ALL:
		{
			Format(_sBuffer, 128, "%T", "Menu_Admin_Confirm_Delete_Mass", client);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}		
	}

	Format(_sBuffer, 128, "%T", "Menu_Admin_Confirm_Delete_No", client);
	Format(_sTemp, 36, "0 %d %d", group, target);
	AddMenuItem(_hMenu, _sTemp, _sBuffer);

	Format(_sBuffer, 128, "%T", "Menu_Admin_Confirm_Delete_Yes", client);
	Format(_sTemp, 36, "1 %d %d",  group, target);
	AddMenuItem(_hMenu, _sTemp, _sBuffer);
	
	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminConfirmDelete(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Admin(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[36], String:_sBuffer[3][12], String:_sTemp[192];
			GetMenuItem(menu, param2, _sOption, 36);
			ExplodeString(_sOption, " ", _sBuffer, 3, 12);
			
			if(StringToInt(_sBuffer[0]))
			{
				switch(StringToInt(_sBuffer[1]))
				{
					case TARGET_SINGLE:
					{
						new _iTarget = GetClientOfUserId(StringToInt(_sBuffer[2]));
						if(!_iTarget || !IsClientInGame(_iTarget))
							CPrintToChat(param1, "%s%t", g_sPrefixChat, "Admin_Locate_Failure");
						else
						{
							if(Bool_ClearClientProps(_iTarget, true, true))
							{
								PrintCenterText(param1, "%s%t", g_sPrefixCenter, "Notify_Succeed_Clear");
								Format(_sTemp, 192, "%T", "Notify_Activity_Clear", LANG_SERVER, _iTarget);
								ShowActivity2(param1, "[SM] ", _sTemp);
								
								Format(_sTemp, 192, "%T", "Log_Action_Clear", LANG_SERVER, param1, _iTarget);
								LogAction(param1, _iTarget, _sTemp);
							}
						}
					}
					case TARGET_RED:
					{
						new _iSucceed;
						for(new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && g_iPlayerProps[i] > 0 && g_iTeam[i] == TEAM_RED)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%s%t", g_sPrefixConsole, "Admin_Target_Failure");
								else
								{
									if(Bool_ClearClientProps(i, true, true))
									{
										_iSucceed++;
										Format(_sTemp, 192, "%T", "Notify_Activity_Clear", LANG_SERVER, i);
										ShowActivity2(param1, "[SM] ", _sTemp);
										
										Format(_sTemp, 192, "%T", "Log_Action_Clear", LANG_SERVER, param1, i);
										LogAction(param1, i, _sTemp);
									}
								}
							}
						}
						
						if(_iSucceed)
							PrintCenterText(param1, "%s%t", g_sPrefixCenter, "Notify_Succeed_Clear_Multiple", _iSucceed);
					}		
					case TARGET_BLUE:
					{
						new _iSucceed;
						for(new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && g_iPlayerProps[i] > 0 && g_iTeam[i] == TEAM_BLUE)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%s%t", g_sPrefixConsole, "Admin_Target_Failure");
								else
								{
									if(Bool_ClearClientProps(i, true, true))
									{
										_iSucceed++;
										Format(_sTemp, 192, "%T", "Notify_Activity_Clear", LANG_SERVER, i);
										ShowActivity2(param1, "[SM] ", _sTemp);
										
										Format(_sTemp, 192, "%T", "Log_Action_Clear", LANG_SERVER, param1, i);
										LogAction(param1, i, _sTemp);
									}
								}
							}
						}
						
						if(_iSucceed)
							PrintCenterText(param1, "%s%t", g_sPrefixCenter, "Notify_Succeed_Clear_Multiple", _iSucceed);
					}		
					case TARGET_ALL:
					{
						new _iSucceed;
						for(new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && g_iPlayerProps[i] > 0)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%s%t", g_sPrefixConsole, "Admin_Target_Failure");
								else
								{
									if(Bool_ClearClientProps(i, true, true))
									{
										_iSucceed++;
										Format(_sTemp, 192, "%T", "Notify_Activity_Clear", LANG_SERVER, i);
										ShowActivity2(param1, "[SM] ", _sTemp);
										
										Format(_sTemp, 192, "%T", "Log_Action_Clear", LANG_SERVER, param1, i);
										LogAction(param1, i, _sTemp);
									}
								}
							}
						}
						
						if(_iSucceed)
							PrintCenterText(param1, "%s%t", g_sPrefixCenter, "Notify_Succeed_Clear_Multiple", _iSucceed);
					}
				}
			}

			Menu_Admin(param1);
		}
	}
}

Menu_AdminConfirmTeleport(client, group, target = 0)
{
	decl String:_sBuffer[128], String:_sTemp[36];

	new Handle:_hMenu = CreateMenu(MenuHandler_AdminConfirmTele);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);
	
	switch(group)
	{
		case TARGET_SINGLE:
		{
			Format(_sBuffer, 128, "%T", "Menu_Admin_Confirm_Teleport_Single", client, g_sName[GetClientOfUserId(target)]);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_RED:
		{
			Format(_sBuffer, 128, "%T", "Menu_Admin_Confirm_Teleport_Red", client);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}		
		case TARGET_BLUE:
		{
			Format(_sBuffer, 128, "%T", "Menu_Admin_Confirm_Teleport_Blue", client);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}		
		case TARGET_ALL:
		{
			Format(_sBuffer, 128, "%T", "Menu_Admin_Confirm_Teleport_Mass", client);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}		
	}

	Format(_sBuffer, 128, "%T", "Menu_Admin_Confirm_Teleport_No", client);
	Format(_sTemp, 36, "0 %d %d", group, target);
	AddMenuItem(_hMenu, _sTemp, _sBuffer);

	Format(_sBuffer, 128, "%T", "Menu_Admin_Confirm_Teleport_Yes", client);
	Format(_sTemp, 36, "1 %d %d",  group, target);
	AddMenuItem(_hMenu, _sTemp, _sBuffer);
	
	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminConfirmTele(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Admin(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[36], String:_sBuffer[3][12], String:_sTemp[192];
			GetMenuItem(menu, param2, _sOption, 36);
			ExplodeString(_sOption, " ", _sBuffer, 3, 12);
			
			if(StringToInt(_sBuffer[0]))
			{
				switch(StringToInt(_sBuffer[1]))
				{
					case TARGET_SINGLE:
					{
						new _iTarget = GetClientOfUserId(StringToInt(_sBuffer[2]));
						if(!_iTarget || !IsClientInGame(_iTarget))
							CPrintToChat(param1, "%s%t", g_sPrefixChat, "Admin_Locate_Failure");
						else if(g_bAlive[_iTarget])
						{
							Void_TeleportPlayer(_iTarget);
							Void_ClearClientTeleport(_iTarget);
							
							PrintCenterText(param1, "%s%t", g_sPrefixCenter, "Notify_Succeed_Tele");
							Format(_sTemp, 192, "%T", "Notify_Activity_Tele", LANG_SERVER, _iTarget);
							ShowActivity2(param1, "[SM] ", _sTemp);
							
							Format(_sTemp, 192, "%T", "Log_Action_Tele", LANG_SERVER, param1, _iTarget);
							LogAction(param1, _iTarget, _sTemp);
						}
					}
					case TARGET_RED:
					{
						new _iSucceed;
						for(new i = 1; i <= MaxClients; i++)
						{
							if(g_bAlive[i] && IsClientInGame(i) && g_iTeam[i] == TEAM_RED)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%s%t", g_sPrefixConsole, "Admin_Target_Failure");
								else
								{
									Void_TeleportPlayer(i);
									Void_ClearClientTeleport(i);
									
									_iSucceed++;
									Format(_sTemp, 192, "%T", "Notify_Activity_Tele", LANG_SERVER, i);
									ShowActivity2(param1, "[SM] ", _sTemp);
									
									Format(_sTemp, 192, "%T", "Log_Action_Tele", LANG_SERVER, param1, i);
									LogAction(param1, i, _sTemp);
								}
							}
						}
						
						if(_iSucceed)
							PrintCenterText(param1, "%s%t", g_sPrefixCenter, "Notify_Succeed_Tele", _iSucceed);
					}		
					case TARGET_BLUE:
					{
						new _iSucceed;
						for(new i = 1; i <= MaxClients; i++)
						{
							if(g_bAlive[i] && IsClientInGame(i) && g_iTeam[i] == TEAM_BLUE)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%s%t", g_sPrefixConsole, "Admin_Target_Failure");
								else
								{
									Void_TeleportPlayer(i);
									Void_ClearClientTeleport(i);
									
									_iSucceed++;
									Format(_sTemp, 192, "%T", "Notify_Activity_Tele", LANG_SERVER, i);
									ShowActivity2(param1, "[SM] ", _sTemp);
									
									Format(_sTemp, 192, "%T", "Log_Action_Tele", LANG_SERVER, param1, i);
									LogAction(param1, i, _sTemp);
								}
							}
						}
						
						if(_iSucceed)
							PrintCenterText(param1, "%s%t", g_sPrefixCenter, "Notify_Succeed_Tele", _iSucceed);
					}		
					case TARGET_ALL:
					{
						new _iSucceed;
						for(new i = 1; i <= MaxClients; i++)
						{
							if(g_bAlive[i] && IsClientInGame(i))
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%s%t", g_sPrefixConsole, "Admin_Target_Failure");
								else
								{
									Void_TeleportPlayer(i);
									Void_ClearClientTeleport(i);
									
									_iSucceed++;
									Format(_sTemp, 192, "%T", "Notify_Activity_Tele", LANG_SERVER, i);
									ShowActivity2(param1, "[SM] ", _sTemp);
									
									Format(_sTemp, 192, "%T", "Log_Action_Tele", LANG_SERVER, param1, i);
									LogAction(param1, i, _sTemp);
								}
							}
						}
						
						if(_iSucceed)
							PrintCenterText(param1, "%s%t", g_sPrefixCenter, "Notify_Succeed_Tele", _iSucceed);
					}		
				}
			}

			Menu_Admin(param1);
		}
	}
}

Menu_AdminSelectColor(client, group, target = 0)
{
	decl String:_sTemp[36];

	new Handle:_hMenu = CreateMenu(MenuHandler_AdminSelectColor);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	for(new i = 0; i < g_iNumColors; i++)
	{
		Format(_sTemp, 36, "%d %d %d", group, i, target);
		AddMenuItem(_hMenu, _sTemp, g_sDefinedColorNames[i]);
	}

	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminSelectColor(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Admin(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[36], String:_sBuffer[3][12];
			GetMenuItem(menu, param2, _sOption, 36);
			ExplodeString(_sOption, " ", _sBuffer, 3, 12);

			Menu_AdminConfirmColor(param1, StringToInt(_sBuffer[0]), StringToInt(_sBuffer[1]), StringToInt(_sBuffer[2]));
		}
	}
}

Menu_AdminConfirmColor(client, group, color, target = 0)
{
	decl String:_sBuffer[128], String:_sTemp[40];

	new Handle:_hMenu = CreateMenu(MenuHandler_AdminConfirmColor);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);
	
	switch(group)
	{
		case TARGET_SINGLE:
		{
			Format(_sBuffer, 128, "%T", "Menu_Admin_Confirm_Color_Single", client, g_sName[GetClientOfUserId(target)]);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_RED:
		{
			Format(_sBuffer, 128, "%T", "Menu_Admin_Confirm_Color_Red", client);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}		
		case TARGET_BLUE:
		{
			Format(_sBuffer, 128, "%T", "Menu_Admin_Confirm_Color_Blue", client);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}		
		case TARGET_ALL:
		{
			Format(_sBuffer, 128, "%T", "Menu_Admin_Confirm_Color_Mass", client);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}		
	}

	Format(_sBuffer, 128, "%T", "Menu_Admin_Confirm_Color_No", client);
	Format(_sTemp, 40, "0 %d %d %d", group, color, target);
	AddMenuItem(_hMenu, _sTemp, _sBuffer);

	Format(_sBuffer, 128, "%T", "Menu_Admin_Confirm_Color_Yes", client);
	Format(_sTemp, 40, "1 %d %d %d",  group, color, target);
	AddMenuItem(_hMenu, _sTemp, _sBuffer);
	
	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminConfirmColor(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_Admin(param1);
		}
		case MenuAction_Select:
		{
			decl String:_sOption[40], String:_sBuffer[4][10];
			GetMenuItem(menu, param2, _sOption, 40);
			ExplodeString(_sOption, " ", _sBuffer, 4, 10);
			
			if(StringToInt(_sBuffer[0]))
			{
				new _iIndex = StringToInt(_sBuffer[2]);
				switch(StringToInt(_sBuffer[1]))
				{
					case TARGET_SINGLE:
					{
						new _iTarget = GetClientOfUserId(StringToInt(_sBuffer[3]));
						if(!_iTarget || !IsClientInGame(_iTarget))
							CPrintToChat(param1, "%s%t", g_sPrefixChat, "Admin_Locate_Failure");
						else
							Void_ColorClientProps(_iTarget, _iIndex);
					}
					case TARGET_RED:
					{
						for(new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && g_iPlayerProps[i] > 0 && g_iTeam[i] == TEAM_RED)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%s%t", g_sPrefixConsole, "Admin_Target_Failure");
								else
									Void_ColorClientProps(i, _iIndex);
							}
						}
					}		
					case TARGET_BLUE:
					{
						for(new i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && g_iPlayerProps[i] > 0 && g_iTeam[i] == TEAM_BLUE)
							{
								if(i != param1 && !CanUserTarget(param1, i))
									PrintToConsole(param1, "%s%t", g_sPrefixConsole, "Admin_Target_Failure");
								else
									Void_ColorClientProps(i, _iIndex);
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
									PrintToConsole(param1, "%s%t", g_sPrefixConsole, "Admin_Target_Failure");
								else
									Void_ColorClientProps(i, _iIndex);
							}
						}
					}
				}
			}

			PrintCenterText(param1, "%s%t", g_sPrefixCenter, "Admin_Color_Succeed");
			Menu_Admin(param1);
		}
	}
}

Void_LoadCookies(client)
{
	decl String:_sTemp[32], String:_sCookie[4] = "";
	GetClientCookie(client, g_cBuildVersion, _sTemp, 32);

	if(StrEqual(_sTemp, "", false))
	{
		SetClientCookie(client, g_cBuildVersion, PLUGIN_VERSION);
		
		g_iConfigRotation[client] = g_iDefaultRotation;
		IntToString(g_iConfigRotation[client], _sCookie, 4);
		SetClientCookie(client, g_cConfigRotation, _sCookie);

		g_iConfigPosition[client] = g_iDefaultPosition;
		IntToString(g_iConfigPosition[client], _sCookie, 4);
		SetClientCookie(client, g_cConfigPosition, _sCookie);

		g_iConfigColor[client] = g_iDefaultColor;
		IntToString(g_iConfigColor[client], _sCookie, 4);
		SetClientCookie(client, g_cConfigColor, _sCookie);

		g_iConfigQuick[client] = g_iDefaultQuick == -1 ? 0 : g_iDefaultQuick;
		IntToString(g_iConfigQuick[client], _sCookie, 4);
		SetClientCookie(client, g_cConfigQuick, _sCookie);
		
		for(new i = 0; i < AXIS_TOTAL; i++)
			g_bConfigAxis[client][i]  = false;
		SetClientCookie(client, g_cConfigLocks, "0 0 0 0 0");

		g_fConfigDistance[client] = g_fDefaultControl;
		FloatToString(g_fConfigDistance[client], _sCookie, 4);
		SetClientCookie(client, g_cConfigDistance, _sCookie);
	}
	else
	{
		if(g_bRotationAllowed)
		{
			GetClientCookie(client, g_cConfigRotation, _sCookie, 4);
			g_iConfigRotation[client] = StringToInt(_sCookie);

			if(g_iConfigRotation[client] >= g_iNumRotations)
			{
				g_iConfigRotation[client] = g_iDefaultRotation;
				IntToString(g_iConfigRotation[client], _sCookie, 4);
				SetClientCookie(client, g_cConfigRotation, _sCookie);
			}
		}
		
		if(g_bPositionAllowed)
		{
			GetClientCookie(client, g_cConfigPosition, _sCookie, 4);
			g_iConfigPosition[client] = StringToInt(_sCookie);

			if(g_iConfigPosition[client] >= g_iNumPositions)
			{
				g_iConfigPosition[client] = g_iDefaultPosition;
				IntToString(g_iConfigPosition[client], _sCookie, 4);
				SetClientCookie(client, g_cConfigPosition, _sCookie);
			}
		}

		if(g_bColorAllowed)
		{
			GetClientCookie(client, g_cConfigColor, _sCookie, 4);
			g_iConfigColor[client] = StringToInt(_sCookie);
			
			if(g_iConfigColor[client] >= g_iNumColors)
			{
				g_iConfigColor[client] = g_iDefaultColor;
				IntToString(g_iConfigColor[client], _sCookie, 4);
				SetClientCookie(client, g_cConfigColor, _sCookie);
			}
		}

		if(g_bControlAllowed)
		{
			GetClientCookie(client, g_cConfigDistance, _sCookie, 4);
			g_fConfigDistance[client] = StringToFloat(_sCookie);
			
			if(g_fConfigDistance[client] < g_fGrabMinimum || g_fConfigDistance[client] > g_fGrabMaximum)
			{
				g_fConfigDistance[client] = g_fDefaultControl;
				FloatToString(g_fConfigDistance[client], _sCookie, 4);
				SetClientCookie(client, g_cConfigDistance, _sCookie);
			}
		}
			
		if(g_bQuickAllowed)
		{
			GetClientCookie(client, g_cConfigQuick, _sCookie, 4);
			g_iConfigQuick[client] = StringToInt(_sCookie);
		}

		if(g_bRotSnapAllowed || g_bPosSnapAllowed)
		{
			decl String:_sBuffer[AXIS_TOTAL][4];
			GetClientCookie(client, g_cConfigLocks, _sTemp, 32);

			ExplodeString(_sTemp, " ", _sBuffer, AXIS_TOTAL, 4);
			for(new i = 0; i < AXIS_TOTAL; i++)
				g_bConfigAxis[client][i] = StrEqual(_sBuffer[i], "0", false) ? false : true;
		}
	}

	g_bLoaded[client] = true;
}

public Action:Command_Help(client, args)
{
	if(g_bEnabled && g_bHelp)
	{
		if(args < 1)
		{
			ReplyToCommand(client, "%t", "Command_Show_Help_Failure");
			return Plugin_Handled;
		}

		new _iTargets[MAXPLAYERS + 1], bool:_bTemp;
		decl String:_sPattern[64], String:_sBuffer[192];
		GetCmdArg(1, _sPattern, 64);
		new _iCount = ProcessTargetString(_sPattern, client, _iTargets, sizeof(_iTargets), COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED, _sBuffer, sizeof(_sBuffer), _bTemp);
		if(_iCount)
		{
			for(new i = 0; i < _iCount; i++)
			{
				if(IsClientInGame(_iTargets[i]))
				{
					Format(_sBuffer, 192, "%T", "Command_Show_Help_Show_Activity", LANG_SERVER, _iTargets[i]);
					ShowActivity2(client, "[SM] ", _sBuffer);
					
					Format(_sBuffer, 192, "%T", "Command_Show_Help_Log_Message", LANG_SERVER, client, _iTargets[i]);
					LogAction(client, _iTargets[i], _sBuffer);

					Format(_sBuffer, 192, "%T", "Command_Help_Url_Title", LANG_SERVER);
					ShowMOTDPanel(_iTargets[i], _sBuffer, g_sHelp, MOTDPANEL_TYPE_URL);
				}
			}
		}
	}

	return Plugin_Handled;
}

public Action:Command_Chat(args)
{
	if(g_bEnabled)
	{
		decl String:_sBuffer[192];
		GetCmdArgString(_sBuffer, 192);
		
		for(new i = 1; i <= MaxClients; i++)
			if(IsClientInGame(i))
				CPrintToChat(i, "%s%s", g_sPrefixChat, _sBuffer);
	}

	return Plugin_Handled;
}

public Action:Command_Hint(args)
{
	if(g_bEnabled)
	{
		decl String:_sBuffer[192];
		GetCmdArgString(_sBuffer, 192);
		
		for(new i = 1; i <= MaxClients; i++)
			if(IsClientInGame(i))
				PrintHintText(i, "%s%s", g_sPrefixHint, _sBuffer);
	}

	return Plugin_Handled;
}

public Action:Command_Key(args)
{
	if(g_bEnabled)
	{
		decl String:_sBuffer[192];
		GetCmdArgString(_sBuffer, 192);
		
		new Handle:_hMessage = StartMessageAll("KeyHintText");
		Format(_sBuffer, 192, "%s%s", g_sPrefixKey, _sBuffer); 
		BfWriteByte(_hMessage, 1);
		BfWriteString(_hMessage, _sBuffer); 
		EndMessage();	
	}

	return Plugin_Handled;
}

public Action:Command_Center(args)
{
	if(g_bEnabled)
	{
		decl String:_sBuffer[192];
		GetCmdArgString(_sBuffer, 192);
		
		for(new i = 1; i <= MaxClients; i++)
			if(IsClientInGame(i))
				PrintCenterText(i, "%s%s", g_sPrefixCenter, _sBuffer);
	}

	return Plugin_Handled;
}

Array_Push(client, team)
{
	switch(team)
	{
		case TEAM_RED:
		{
			PushArrayCell(g_hArray_RedPlayers, client);
			g_iPlayersRed++;
		}
		case TEAM_BLUE:
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
		case TEAM_RED:
		{
			ClearArray(g_hArray_RedPlayers);
			g_iPlayersRed = 0;
		}
		case TEAM_BLUE:
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
		case TEAM_RED:
			return GetArrayCell(g_hArray_RedPlayers, index);
		case TEAM_BLUE:
			return GetArrayCell(g_hArray_BluePlayers, index);
	}
	
	return 0;
}

Array_Index(client, team)
{
	switch(team)
	{
		case TEAM_RED:
			return FindValueInArray(g_hArray_RedPlayers, client);
		case TEAM_BLUE:
			return FindValueInArray(g_hArray_BluePlayers, client);
	}
	
	return 0;
}

Array_Remove(index, team)
{
	switch(team)
	{
		case TEAM_RED:
		{
			RemoveFromArray(g_hArray_RedPlayers, index);
			g_iPlayersRed--;
		}
		case TEAM_BLUE:
		{
			RemoveFromArray(g_hArray_BluePlayers, index);
			g_iPlayersBlue--;
		}
	}
}

Void_Switch(client, team)
{
	if(IsClientInGame(client) && g_iTeam[client] != team)
	{
		if(g_bAlive[client] && g_iTeam[client] == TEAM_RED)
		{
			new entity = GetPlayerWeaponSlot(client, CS_SLOT_C4);
			if(entity > 0)
			{
				RemovePlayerItem(client, entity);
				AcceptEntityInput(entity, "Kill");
			}
		}

		CS_SwitchTeam(client, team);
	}
}

Void_HideRadar(client)
{
	SetEntDataFloat(client, g_iFlashDuration, 3600.0, true);
	SetEntDataFloat(client, g_iFlashAlpha, 0.5, true);
}

Void_ShowRadar(client)
{
	SetEntDataFloat(client, g_iFlashDuration, 0.5, true);
	SetEntDataFloat(client, g_iFlashAlpha, 0.5, true);
}

public Action:Timer_FlashEnd(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(g_iDisableRadar & g_iPhase && !(g_iPlayerAccess[client] & g_iRadarAccess))
	{
		if (client && g_iTeam[client] >= TEAM_RED && IsClientInGame(client))
			Void_HideRadar(client);
	}
}

public Action:Timer_AfkAutoSpec(Handle:timer, any:client)
{
	g_hTimer_AfkCheck[client] = INVALID_HANDLE;

	if(!g_iTeam[client] && IsClientInGame(client))
	{
		ChangeClientTeam(client, TEAM_SPEC);

		if(!g_iAfkImmunity || !(g_iPlayerAccess[client] & g_iAfkImmunity))
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
	if(IsClientInGame(client))
	{
		if(!g_bActivity[client])
		{
			ChangeClientTeam(client, TEAM_SPEC);
			CPrintToChat(client, "%s%t", g_sPrefixChat, "Afk_Notify_Move");
			
			if(g_bAfkAutoKick && (!g_iAfkImmunity || !(g_iPlayerAccess[client] & g_iAfkImmunity)))
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
	if(IsClientInGame(client))
	{
		g_fAfkRemaining[client] -= 1.0;
		if(g_fAfkRemaining[client] > 0.0)
		{
			PrintCenterText(client, "%s%t", g_sPrefixCenter, "Afk_Notify_Kick", g_fAfkRemaining[client]);
			return Plugin_Continue;
		}
		else
			KickClient(client, "%t", "Afk_Kick_Reason");
	}
	
	g_hTimer_AfkCheck[client] = INVALID_HANDLE;
	return Plugin_Stop;
}

public Action:Timer_SpecNotify(Handle:timer, any:client)
{
	if(IsClientInGame(client))
	{
		g_fAfkRemaining[client] -= 1.0;
		if(g_fAfkRemaining[client] > 0.0)
		{
			PrintCenterText(client, "%s%t", g_sPrefixCenter, "Afk_Notify_Spec", g_fAfkRemaining[client]);
			return Plugin_Continue;
		}
		else
			KickClient(client, "%t", "Afk_Spec_Reason");
	}

	g_hTimer_AfkCheck[client] = INVALID_HANDLE;
	return Plugin_Stop;
}

Void_AuthClient(client)
{
	g_iPlayerAccess[client] = ACCESS_PUBLIC;
	if(CheckCommandAccess(client, "bw_access_supporter", AUTH_SUPPORTER))
		g_iPlayerAccess[client] += ACCESS_SUPPORTER;
	
	if(CheckCommandAccess(client, "bw_access_admin", AUTH_ADMIN))
		g_iPlayerAccess[client] += ACCESS_ADMIN;
	
	g_iAdminAccess[client] = ADMIN_NONE;
	if(CheckCommandAccess(client, "bw_admin_delete", AUTH_DELETE))
		g_iAdminAccess[client] += ADMIN_DELETE;
	
	if(CheckCommandAccess(client, "bw_admin_teleport", AUTH_TELEPORT))
		g_iAdminAccess[client] += ADMIN_TELEPORT;
	
	if(CheckCommandAccess(client, "bw_admin_color", AUTH_COLOR))
		g_iAdminAccess[client] += ADMIN_COLOR;
	
	if(CheckCommandAccess(client, "bw_admin_target", AUTH_TARGET))
		g_iAdminAccess[client] += ADMIN_TARGET;

	if(CheckCommandAccess(client, "bw_admin_manage", AUTH_MANAGE))
		g_iAdminAccess[client] += ADMIN_MANAGE;
}

Void_ReturnToMenu(client, _iMenu, _iSlot = 0)
{
	switch(_iMenu)
	{
		case MENU_MAIN:
		{
			Menu_Main(client);
		}
		case MENU_CREATE:
		{
			Menu_Create(client, _iSlot);
		}
		case MENU_ROTATE:
		{
			Menu_ModifyRotation(client);
		}
		case MENU_MOVE:
		{
			Menu_ModifyPosition(client);
		}
		case MENU_CONTROL:
		{
			Menu_Control(client);
		}
		case MENU_COLOR:
		{
			Menu_DefaultColors(client);
		}
		case MENU_ACTION:
		{
			Menu_PlayerActions(client);
		}
		case MENU_ADMIN:
		{
			if(!Menu_Admin(client))
				Menu_Main(client);
		}
	}
}

bool:Bool_DeleteAllowed(client, bool:_bMessage = false, bool:_bClear = false)
{
	if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
	{
		if(g_iDeletePublic != -1)
		{
			if(!g_iDeletePublic)
				return true;
			else
			{
				if(_bClear)
				{
					if((g_iPlayerDeletes[client] + g_iPlayerProps[client]) < g_iDeletePublic)
						return true;
					else if(_bMessage)
						CPrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Insufficient");
				}
				else
				{
					if(g_iPlayerDeletes[client] < g_iDeletePublic)
						return true;
					else if(_bMessage)
						CPrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Reached");
				}
			}
		}
		
		return false;
	}
	else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
	{
		if(g_iDeleteAdmin != -1)
		{
			if(!g_iDeleteAdmin)
				return true;
			else
			{
				if(_bClear)
				{
					if((g_iPlayerDeletes[client] + g_iPlayerProps[client]) < g_iDeleteAdmin)
						return true;
					else if(_bMessage)
						CPrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Insufficient");
				}
				else
				{
					if(g_iPlayerDeletes[client] < g_iDeleteAdmin)
						return true;
					else if(_bMessage)
						CPrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Reached");
				}
			}
		}

		return false;
	}
	else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
	{
		if(g_iDeleteSupporter != -1)
		{
			if(!g_iDeleteSupporter)
				return true;
			else
			{
				if(_bClear)
				{
					if((g_iPlayerDeletes[client] + g_iPlayerProps[client]) < g_iDeleteSupporter)
						return true;
					else if(_bMessage)
						CPrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Insufficient");
				}
				else
				{
					if(g_iPlayerDeletes[client] < g_iDeleteSupporter)
						return true;
					else if(_bMessage)
						CPrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Limit_Reached");
				}
			}
		}

		return false;
	}

	return false;
}

bool:Bool_DeleteValid(client, bool:_bMessage = false, _iReturn = 0, _iSlot = 0)
{
	if(!(g_iPlayerAccess[client] & ACCESS_ADMIN))
	{
		if(!Bool_CheckAction(client))
		{
			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_iCurrentDisable & DISABLE_DELETE)
		{
			if(_bMessage)
			{
				decl String:_sBuffer[192];
				Format(_sBuffer, 192, "Delete_Prop_Restricted%s", g_sPhaseDisplay[g_iPhase]);
				CPrintToChat(client, "%s%t", g_sPrefixChat, _sBuffer);
			}

			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);
			
			return false;
		}
	}
	
	return true;
}

bool:Bool_ClearValid(client, bool:_bMessage = false, _iReturn = 0, _iSlot = 0)
{
	if(!(g_iPlayerAccess[client] & ACCESS_ADMIN))
	{
		if(!Bool_CheckAction(client))
		{
			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_iCurrentDisable & DISABLE_CLEAR)
		{
			if(_bMessage)
			{
				decl String:_sBuffer[192];
				Format(_sBuffer, 192, "Clear_Prop_Restricted%s", g_sPhaseDisplay[g_iPhase]);
				CPrintToChat(client, "%s%t", g_sPrefixChat, _sBuffer);
			}

			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);
			
			return false;
		}
	}
	
	return true;
}

bool:Bool_SpawnAllowed(client, bool:_bMessage = false)
{
	if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
	{
		if(g_iPropPublic != -1)
		{
			if(!g_iPropPublic)
				return true;
			else if(g_iPlayerProps[client] < g_iPropPublic)
				return true;
			else if(_bMessage)
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Spawn_Prop_Limit_Reached");
		}
		
		return false;
	}
	else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
	{
		if(g_iPropAdmin != -1)
		{
			if(!g_iPropAdmin)
				return true;
			else if(g_iPlayerProps[client] < g_iPropAdmin)
				return true;
			else if(_bMessage)
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Spawn_Prop_Limit_Reached");
		}

		return false;
	}
	else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
	{
		if(g_iPropSupporter != -1)
		{
			if(!g_iPropSupporter)
				return true;
			else if(g_iPlayerProps[client] < g_iPropSupporter)
				return true;
			else if(_bMessage)
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Spawn_Prop_Limit_Reached");
		}

		return false;
	}

	return false;
}

bool:Bool_SpawnValid(client, bool:_bMessage = false, bool:_bEntity = false, _iReturn = 0, _iSlot = 0)
{
	if(_bEntity && g_iCurEntities >= g_iMaxEntities)
	{
		if(_bMessage)
			CPrintToChat(client, "%s%t", g_sPrefixChat, "Entity_Maximum_Reached");

		if(_iReturn)
			Void_ReturnToMenu(client, _iReturn, _iSlot);

		return false;
	}

	if(!(g_iPlayerAccess[client] & ACCESS_ADMIN))
	{
		if(!Bool_CheckAction(client))
		{
			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_iCurrentDisable & DISABLE_SPAWN)
		{
			if(_bMessage)
			{
				decl String:_sBuffer[192];
				Format(_sBuffer, 192, "Spawn_Prop_Restricted%s", g_sPhaseDisplay[g_iPhase]);
				CPrintToChat(client, "%s%t", g_sPrefixChat, _sBuffer);
			}

			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);
			
			return false;
		}
	}
	
	return true;
}

bool:Bool_SpawnProximity(client, Float:_fOrigin[3], _iReturn = 0, _iSlot = 0)
{
	if(!(g_iPlayerAccess[client] & ACCESS_ADMIN))
	{
		if(g_fProximityPlayers)
		{
			decl Float:_fTemp[3];
			for(new i = 1; i <= MaxClients; i++)
			{
				if(i != client && g_bAlive[i] && g_iTeam[i] == g_iTeam[client] && IsClientInGame(i))
				{
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", _fTemp);
					if(!Bool_ProximityCheck(_fOrigin, _fTemp, g_fProximityPlayers))
					{
						PrintHintText(client, "%s%t", g_sPrefixHint, "Proximity_Players_Builder", g_sName[i]);
						PrintHintText(i, "%s%t", g_sPrefixHint, "Proximity_Players_Other", g_sName[client]);
						if(_iReturn)
							Void_ReturnToMenu(client, _iReturn, _iSlot);

						return false;
					}
				}
			}
		}

		if(g_fProximitySpawns)
		{
			switch(g_iTeam[client])
			{
				case TEAM_RED:
				{
					if(g_iNumRedSpawns)
					{
						for(new i = 0; i <= g_iNumRedSpawns; i++)
						{
							if(!Bool_ProximityCheck(_fOrigin, g_fRedTeleports[i], g_fProximitySpawns))
							{
								PrintHintText(client, "%s%t", g_sPrefixHint, "Proximity_Spawns");
								if(_iReturn)
									Void_ReturnToMenu(client, _iReturn, _iSlot);

								return false;
							}
						}
					}
				}
				case TEAM_BLUE:
				{
					if(g_iNumBlueSpawns)
					{
						for(new i = 0; i <= g_iNumBlueSpawns; i++)
						{
							if(!Bool_ProximityCheck(_fOrigin, g_fBlueTeleports[i], g_fProximitySpawns))
							{
								PrintHintText(client, "%s%t", g_sPrefixHint, "Proximity_Spawns");
								if(_iReturn)
									Void_ReturnToMenu(client, _iReturn, _iSlot);

								return false;
							}
						}
					}
				}
			}
		}
	}
	
	return true;
}

Int_SpawnMaximum(client)
{
	if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
		return g_iPropPublic;
	else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
		return g_iPropAdmin;
	else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
		return g_iPropSupporter;
		
	return 0;
}

bool:Bool_RotateValid(client, bool:_bMessage = false, _iReturn = 0, _iSlot = 0)
{
	if(!g_bRotationAllowed)
		return false;
	else if(!(g_iPlayerAccess[client] & ACCESS_ADMIN))
	{
		if(!Bool_CheckAction(client))
		{
			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_iCurrentDisable & DISABLE_ROTATE)
		{
			if(_bMessage)
			{
				decl String:_sBuffer[192];
				Format(_sBuffer, 192, "Rotate_Prop_Restricted%s", g_sPhaseDisplay[g_iPhase]);
				CPrintToChat(client, "%s%t", g_sPrefixChat, _sBuffer);
			}

			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);
			
			return false;
		}
	}
	
	return true;
}

bool:Bool_MoveValid(client, bool:_bMessage = false, _iReturn = 0, _iSlot = 0)
{
	if(!g_bPositionAllowed)
		return false;
	else if(!(g_iPlayerAccess[client] & ACCESS_ADMIN))
	{
		if(!Bool_CheckAction(client))
		{
			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_iCurrentDisable & DISABLE_MOVE)
		{
			if(_bMessage)
			{
				decl String:_sBuffer[192];
				Format(_sBuffer, 192, "Position_Prop_Restricted%s", g_sPhaseDisplay[g_iPhase]);
				CPrintToChat(client, "%s%t", g_sPrefixChat, _sBuffer);
			}

			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);
			
			return false;
		}
	}
	
	return true;
}

bool:Bool_ControlValid(client, bool:_bMessage = false, _iReturn = 0, _iSlot = 0)
{
	if(!g_bControlAllowed)
		return false;
	else if(!(g_iPlayerAccess[client] & ACCESS_ADMIN))
	{
		if(!Bool_CheckAction(client))
		{
			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_iCurrentDisable & DISABLE_CONTROL)
		{
			if(_bMessage)
			{
				decl String:_sBuffer[192];
				Format(_sBuffer, 192, "Control_Prop_Restricted%s", g_sPhaseDisplay[g_iPhase]);
				CPrintToChat(client, "%s%t", g_sPrefixChat, _sBuffer);
			}

			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);
			
			return false;
		}
	}
	
	return true;
}

bool:Bool_CheckValid(client, bool:_bMessage = false, _iReturn = 0, _iSlot = 0)
{
	if(!g_bControlAllowed)
		return false;
	else if(!(g_iPlayerAccess[client] & ACCESS_ADMIN))
	{
		if(!Bool_CheckAction(client))
		{
			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_iCurrentDisable & DISABLE_CHECK)
		{
			if(_bMessage)
			{
				decl String:_sBuffer[192];
				Format(_sBuffer, 192, "Check_Prop_Restricted%s", g_sPhaseDisplay[g_iPhase]);
				CPrintToChat(client, "%s%t", g_sPrefixChat, _sBuffer);
			}

			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);
			
			return false;
		}
	}
	
	return true;
}

bool:Bool_TeleportAllowed(client, bool:_bMessage = false)
{
	if(g_bTeleporting[client])
	{
		if(_bMessage)
			CPrintToChat(client, "%s%t", g_sPrefixChat, "Teleport_In_Progress");
		return false;
	}
	
	if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
	{
		if(g_iTeleportPublic != -1)
		{
			if(!g_iTeleportPublic)
				return true;
			else if(g_iPlayerTeleports[client] < g_iTeleportPublic)
				return true;
			else if(_bMessage)
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Teleport_Limit_Reached");
		}
		
		return false;
	}
	else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
	{
		if(g_iTeleportAdmin != -1)
		{
			if(!g_iTeleportAdmin)
				return true;
			else if(g_iPlayerTeleports[client] < g_iTeleportAdmin)
				return true;
			else if(_bMessage)
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Teleport_Limit_Reached");
		}

		return false;
	}
	else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
	{
		if(g_iTeleportSupporter != -1)
		{
			if(!g_iTeleportSupporter)
				return true;
			else if(g_iPlayerTeleports[client] < g_iTeleportSupporter)
				return true;
			else if(_bMessage)
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Teleport_Limit_Reached");
		}

		return false;
	}

	return false;
}

bool:Bool_TeleportValid(client, bool:_bMessage = false, _iReturn = 0, _iSlot = 0)
{
	if(!(g_iPlayerAccess[client] & ACCESS_ADMIN))
	{
		if(!Bool_CheckAction(client))
		{
			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_iCurrentDisable & DISABLE_TELE)
		{
			if(_bMessage)
			{
				decl String:_sBuffer[192];
				Format(_sBuffer, 192, "Teleport_Restricted%s", g_sPhaseDisplay[g_iPhase]);
				CPrintToChat(client, "%s%t", g_sPrefixChat, _sBuffer);
			}

			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);
			
			return false;
		}
	}
	
	return true;
}

bool:Bool_ColorValid(client, bool:_bMessage = false, _iReturn = 0, _iSlot = 0)
{
	if(!Bool_CheckAction(client))
	{
		if(_iReturn)
			Void_ReturnToMenu(client, _iReturn, _iSlot);

		return false;
	}
	else if(g_iCurrentDisable & DISABLE_COLOR)
	{
		if(_bMessage)
		{
			decl String:_sBuffer[192];
			Format(_sBuffer, 192, "Color_Prop_Restricted%s", g_sPhaseDisplay[g_iPhase]);
			CPrintToChat(client, "%s%t", g_sPrefixChat, _sBuffer);
		}

		if(_iReturn)
			Void_ReturnToMenu(client, _iReturn, _iSlot);
		
		return false;
	}
	
	return true;
}

Define_Props()
{
	g_iNumProps = 0;
	decl String:_sPath[256];
	new Handle:_hKV = CreateKeyValues("BuildWars_Props");
	BuildPath(Path_SM, _sPath, 256, "configs/buildwars/sm_buildwars_props.ini");
	if(FileToKeyValues(_hKV, _sPath))
	{
		KvGotoFirstSubKey(_hKV);
		do
		{
			KvGetSectionName(_hKV, g_sDefinedPropNames[g_iNumProps], 64);
			KvGetString(_hKV, "path", g_sDefinedPropPaths[g_iNumProps], 256);
			PrecacheModel(g_sDefinedPropPaths[g_iNumProps]);

			g_iDefinedPropTypes[g_iNumProps] = KvGetNum(_hKV, "type");
			g_iDefinedPropAccess[g_iNumProps] = KvGetNum(_hKV, "access");
			g_iDefinedPropHealth[g_iNumProps] = KvGetNum(_hKV, "health");
			g_iNumProps++;
		}
		while (KvGotoNextKey(_hKV));
		CloseHandle(_hKV);
	}
	else
	{
		CloseHandle(_hKV);
		SetFailState("BuildWars: Could not locate \"configs/buildwars/sm_buildwars_props.ini\"");
	}
}

Define_Colors()
{
	g_iNumColors = 0;
	decl String:_sPath[256], String:_sTemp[64];
	new Handle:_hKV = CreateKeyValues("BuildWars_Colors");
	BuildPath(Path_SM, _sPath, 256, "configs/buildwars/sm_buildwars_colors.ini");
	if(FileToKeyValues(_hKV, _sPath))
	{
		decl String:_sValues[][] = { "Red", "Green", "Blue", "Alpha" };
		KvGotoFirstSubKey(_hKV);
		do
		{
			KvGetSectionName(_hKV, g_sDefinedColorNames[g_iNumColors], 64);

			for(new i = 0; i <= 3; i++)
			{
				KvGetString(_hKV, _sValues[i], _sTemp, 64);
				g_iDefinedColorArrays[g_iNumColors][i] = StringToInt(_sTemp);
			}

			g_iNumColors++;
		}
		while (KvGotoNextKey(_hKV));
		CloseHandle(_hKV);
	}
	else
	{
		CloseHandle(_hKV);
		SetFailState("BuildWars: Could not locate \"configs/buildwars/sm_buildwars_colors.ini\"");
	}
}

Define_Rotations()
{
	g_iNumRotations = 0;
	new Handle:_hKV = CreateKeyValues("BuildWars_Rotations");
	decl String:_sPath[256], String:_sTemp[64];
	BuildPath(Path_SM, _sPath, 256, "configs/buildwars/sm_buildwars_rotations.ini");
	if(FileToKeyValues(_hKV, _sPath))
	{
		KvGotoFirstSubKey(_hKV);
		do
		{
			KvGetString(_hKV, "value", _sTemp, 64);
			g_fDefinedRotations[g_iNumRotations] = StringToFloat(_sTemp);

			g_iNumRotations++;
		}
		while (KvGotoNextKey(_hKV));
		CloseHandle(_hKV);
	}
	else
	{
		CloseHandle(_hKV);
		SetFailState("BuildWars: Could not locate \"configs/buildwars/sm_buildwars_rotations.ini\"");
	}
}

Define_Positions()
{
	g_iNumPositions = 0;
	decl String:_sPath[256], String:_sTemp[64];
	new Handle:_hKV = CreateKeyValues("BuildWars_Positions");
	BuildPath(Path_SM, _sPath, 256, "configs/buildwars/sm_buildwars_positions.ini");
	if(FileToKeyValues(_hKV, _sPath))
	{
		KvGotoFirstSubKey(_hKV);
		do
		{
			KvGetString(_hKV, "value", _sTemp, 64);
			g_fDefinedPositions[g_iNumPositions] = StringToFloat(_sTemp);

			g_iNumPositions++;
		}
		while (KvGotoNextKey(_hKV));
		CloseHandle(_hKV);
	}
	else
	{
		CloseHandle(_hKV);
		SetFailState("BuildWars: Could not locate \"configs/buildwars/sm_buildwars_positions.ini\"");
	}
}

Define_Commands()
{
	decl String:_sPath[256], String:_sTemp[128], String:_sBuffer[128];
	new Handle:_hKV = CreateKeyValues("BuildWars_Commands");
	BuildPath(Path_SM, _sPath, 256, "configs/buildwars/sm_buildwars_cmds.ini");
	if(FileToKeyValues(_hKV, _sPath))
	{
		KvGotoFirstSubKey(_hKV);
		do
		{
			KvGetSectionName(_hKV, _sBuffer, 128);
			if(StrEqual(_sBuffer, "Commands_Menu", false))
			{
				for(new i = 0; i < MAX_CONFIG_COMMANDS; i++)
				{
					Format(_sTemp, 128, "%d", i);
					KvGetString(_hKV, _sTemp, _sBuffer, 128);
					if(!StrEqual(_sBuffer, "", false))
						SetTrieValue(g_hTrie_PlayerCommands, _sBuffer, COMMAND_MENU);
				}
			}
			else if(StrEqual(_sBuffer, "Commands_Rotate", false))
			{
				for(new i = 0; i < MAX_CONFIG_COMMANDS; i++)
				{
					Format(_sTemp, 128, "%d", i);
					KvGetString(_hKV, _sTemp, _sBuffer, 128);
					if(!StrEqual(_sBuffer, "", false))
						SetTrieValue(g_hTrie_PlayerCommands, _sBuffer, COMMAND_ROTATION);
				}
			}
			else if(StrEqual(_sBuffer, "Commands_Position", false))
			{
				for(new i = 0; i < MAX_CONFIG_COMMANDS; i++)
				{
					Format(_sTemp, 128, "%d", i);
					KvGetString(_hKV, _sTemp, _sBuffer, 128);
					if(!StrEqual(_sBuffer, "", false))
						SetTrieValue(g_hTrie_PlayerCommands, _sBuffer, COMMAND_POSITION);
				}
			}
			else if(StrEqual(_sBuffer, "Commands_Delete", false))
			{
				for(new i = 0; i < MAX_CONFIG_COMMANDS; i++)
				{
					Format(_sTemp, 128, "%d", i);
					KvGetString(_hKV, _sTemp, _sBuffer, 128);
					if(!StrEqual(_sBuffer, "", false))
						SetTrieValue(g_hTrie_PlayerCommands, _sBuffer, COMMAND_DELETE);
				}
			}
			else if(StrEqual(_sBuffer, "Commands_Grab", false))
			{
				for(new i = 0; i < MAX_CONFIG_COMMANDS; i++)
				{
					Format(_sTemp, 128, "%d", i);
					KvGetString(_hKV, _sTemp, _sBuffer, 128);
					if(!StrEqual(_sBuffer, "", false))
						SetTrieValue(g_hTrie_PlayerCommands, _sBuffer, COMMAND_CONTROL);
				}
			}
			else if(StrEqual(_sBuffer, "Commands_Check", false))
			{
				for(new i = 0; i < MAX_CONFIG_COMMANDS; i++)
				{
					Format(_sTemp, 128, "%d", i);
					KvGetString(_hKV, _sTemp, _sBuffer, 128);
					if(!StrEqual(_sBuffer, "", false))
						SetTrieValue(g_hTrie_PlayerCommands, _sBuffer, COMMAND_CHECK);
				}
			}
			else if(StrEqual(_sBuffer, "Commands_Tele", false))
			{
				for(new i = 0; i < MAX_CONFIG_COMMANDS; i++)
				{
					Format(_sTemp, 128, "%d", i);
					KvGetString(_hKV, _sTemp, _sBuffer, 128);
					if(!StrEqual(_sBuffer, "", false))
						SetTrieValue(g_hTrie_PlayerCommands, _sBuffer, COMMAND_TELE);
				}
			}
			else if(StrEqual(_sBuffer, "Commands_Help", false))
			{
				for(new i = 0; i < MAX_CONFIG_COMMANDS; i++)
				{
					Format(_sTemp, 128, "%d", i);
					KvGetString(_hKV, _sTemp, _sBuffer, 128);
					if(!StrEqual(_sBuffer, "", false))
						SetTrieValue(g_hTrie_PlayerCommands, _sBuffer, COMMAND_HELP);
				}
			}
			else if(StrEqual(_sBuffer, "Commands_Ready", false))
			{
				for(new i = 0; i < MAX_CONFIG_COMMANDS; i++)
				{
					Format(_sTemp, 128, "%d", i);
					KvGetString(_hKV, _sTemp, _sBuffer, 128);
					if(!StrEqual(_sBuffer, "", false))
						SetTrieValue(g_hTrie_PlayerCommands, _sBuffer, COMMAND_READY);
				}
			}
			else if(StrEqual(_sBuffer, "Commands_DeleteAll", false))
			{
				for(new i = 0; i < MAX_CONFIG_COMMANDS; i++)
				{
					Format(_sTemp, 128, "%d", i);
					KvGetString(_hKV, _sTemp, _sBuffer, 128);
					if(!StrEqual(_sBuffer, "", false))
						SetTrieValue(g_hTrie_PlayerCommands, _sBuffer, COMMAND_CLEAR);
				}
			}
		}
		while (KvGotoNextKey(_hKV));
		CloseHandle(_hKV);
	}
	else
	{
		CloseHandle(_hKV);
		SetFailState("BuildWars: Could not locate \"configs/buildwars/sm_buildwars_cmds.ini\"");
	}
}

Define_Modes()
{
	g_iNumModes = 0;
	decl String:_sPath[256];
	new Handle:_hKV = CreateKeyValues("BuildWars_Modes");
	BuildPath(Path_SM, _sPath, 256, "configs/buildwars/sm_buildwars_modes.ini");
	if(FileToKeyValues(_hKV, _sPath))
	{
		KvGotoFirstSubKey(_hKV);
		do
		{
			KvGetString(_hKV, "chat", g_sDefinedModeChat[g_iNumModes], 192);
			g_bDefinedModeChat[g_iNumModes] = !(StrEqual(g_sDefinedModeChat[g_iNumModes], "")) ? true : false;
			KvGetString(_hKV, "center", g_sDefinedModeCenter[g_iNumModes], 192);
			g_bDefinedModeCenter[g_iNumModes] = !(StrEqual(g_sDefinedModeCenter[g_iNumModes], "")) ? true : false;
			g_iDefinedModeDuration[g_iNumModes] = KvGetNum(_hKV, "duration");
			g_iDefinedModeMethod[g_iNumModes] = KvGetNum(_hKV, "method");
			KvGetString(_hKV, "start", g_sDefinedModeStart[g_iNumModes], 512);
			KvGetString(_hKV, "end", g_sDefinedModeEnd[g_iNumModes], 512);
			g_iNumModes++;
		}
		while (KvGotoNextKey(_hKV));
		CloseHandle(_hKV);
	}
	else
	{
		CloseHandle(_hKV);
		SetFailState("BuildWars: Could not locate \"configs/buildwars/sm_buildwars_modes.ini\"");
	}
}

Define_Maps()
{
	g_iNumMaps = 0;
	decl String:_sPath[256], String:_sBuffer[64];
	new Handle:_hKV = CreateKeyValues("BuildWars_Maps");
	BuildPath(Path_SM, _sPath, 256, "configs/buildwars/sm_buildwars_maps.ini");
	if(FileToKeyValues(_hKV, _sPath))
	{
		KvGotoFirstSubKey(_hKV);
		do
		{
			KvGetSectionName(_hKV, _sBuffer, 64);
			SetTrieValue(g_hTrie_MapConfigurations, _sBuffer, g_iNumMaps);
			
			KvGetString(_hKV, "iden", g_sDefinedMapIdens[g_iNumMaps], 128);
			KvGetString(_hKV, "type", g_sDefinedMapTypes[g_iNumMaps], 32);

			g_iNumMaps++;
		}
		while (KvGotoNextKey(_hKV));
		CloseHandle(_hKV);
	}
	else
	{
		CloseHandle(_hKV);
		SetFailState("BuildWars: Could not locate \"configs/buildwars/sm_buildwars_maps.ini\"");
	}
}