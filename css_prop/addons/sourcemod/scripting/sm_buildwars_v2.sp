/*
	Revision: v2.0.7
	--------------------
	Fixed an issue with calculating saving base size which prevented saving equal counts, such has 85 with a maximum limit of 85.
	Saving single props to a base will now trigger the player having spawned a base, if there is not one already spawned.
	Removing spawned base props will now only remove the base props from the map, not all spawned props.
	Removing spawned base props has been load balanced to prevent any spikes from large base removals.
	Plugin now modifies sv_tags to include the phrase "buildwars", to help locate BuildWars servers.
	Improved detection for valid player access / valid action checks.
	Clients without access will no longer appear in admin menus for spawning props / coloring props.
	Added an optional override to access solely to the base feature, bw_access_base, which defaults to the 'r' flag
		- Basically if a client doesn't have access to the base as a public/supporter/admin, it checks for that flag.

	Revision: v2.0.8
	--------------------
	Impliemented a few features from v3 of BuildWars
	- Config files, and their elements within the plugin, are now updated each map if they've been modified.
	- Modified the method used to load chat commands to be a tad more efficient.
*/

/*
	Overrides:
	--------------------
	- bw_access_admin - required to access the "admin" benefits provided by Build Wars. ("Default: 'e')
	- bw_access_supporter - required to access the "supporter" benefits provided of Build Wars. ("Default: 'r')
	- bw_access_base - required to access the base feature provided by Build Wars. ("Default: 'r')

	Restrictions:
	--------------------
	- bw_admin_delete - Allows the user to delete props belonging to other individuals. ("Default: 'b')
	- bw_admin_teleport - Allows the user to teleport other individuals. ("Default: 'b')
	- bw_admin_color - Allows the user to color props belonging to other individuals. ("Default: 'b')
	- bw_admin_target - Allows the user to target @t/@ct/@all with delete/teleport/color. ("Default: 'e')
*/

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <adminmenu>
#include <clientprefs>
#include <colors>

#define PLUGIN_VERSION "2.0.8"

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

//Hardcoded limit to the number of teleport destinations available for maps in build wars (saves memory, increase to allow more).
#define MAX_TELEPORT_ENDS 64

//The maximum amount of entities the current Source Engine will support, used for global entity arrays.
#define MaxEntities 2048

//Cvars
#define CVAR_COUNT 50
#define CVAR_ENABLED 0
#define CVAR_DISSOLVE 1
#define CVAR_HELP 2
#define CVAR_ADVERT 3
#define CVAR_DEFAULT_COLOR 4
#define CVAR_DEFAULT_ROTATION 5
#define CVAR_DEFAULT_POSITION 6
#define CVAR_DEFAULT_CONTROL 7
#define CVAR_DISABLE 8
#define CVAR_QUICK 9
#define CVAR_PUBLIC_PROPS 10
#define CVAR_SUPPORTER_PROPS 11
#define CVAR_ADMIN_PROPS 12
#define CVAR_PUBLIC_DELETES 13
#define CVAR_SUPPORTER_DELETES 14
#define CVAR_ADMIN_DELETES 15
#define CVAR_PUBLIC_TELES 16
#define CVAR_SUPPORTER_TELES 17
#define CVAR_ADMIN_TELES 18
#define CVAR_PUBLIC_DELAY 19
#define CVAR_SUPPORTER_DELAY 20
#define CVAR_ADMIN_DELAY 21
#define CVAR_PUBLIC_COLORING 22
#define CVAR_SUPPORTER_COLORING 23
#define CVAR_ADMIN_COLORING 24
#define CVAR_PUBLIC_COLOR 25
#define CVAR_SUPPORTER_COLOR 26
#define CVAR_ADMIN_COLOR 27
#define CVAR_COLOR_RED 28
#define CVAR_COLOR_BLUE 29
#define CVAR_ACCESS_SPEC 30
#define CVAR_ACCESS_RED 31
#define CVAR_ACCESS_BLUE 32
#define CVAR_ACCESS_CHECK 33
#define CVAR_ACCESS_GRAB 34
#define CVAR_DISABLE_DELAY 35
#define CVAR_ACCESS_SETTINGS 36
#define CVAR_ACCESS_ADMIN 37
#define CVAR_GRAB_DISTANCE 38
#define CVAR_GRAB_REFRESH 39
#define CVAR_GRAB_MINIMUM 40
#define CVAR_GRAB_MAXIMUM 41
#define CVAR_GRAB_INTERVAL 42
#define CVAR_ACCESS_BASE 43
#define CVAR_BASE_DATABASE 44
#define CVAR_BASE_DISTANCE 45
#define CVAR_BASE_GROUPS 46
#define CVAR_BASE_ENABLED 47
#define CVAR_BASE_NAMES 48
#define CVAR_BASE_LIMIT 49

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
#define COMMAND_CLEAR 8

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
#define ACCESS_BASE 8

//Admin Flags...
#define ADMIN_NONE 0
#define ADMIN_DELETE 1
#define ADMIN_TELEPORT 2
#define ADMIN_COLOR 4
#define ADMIN_TARGET 8

//Admin Targeting...
#define TARGET_SINGLE 0
#define TARGET_RED 1
#define TARGET_BLUE 2
#define TARGET_ALL 3

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

//Base Menu Indexes
#define MENU_BASE_NULL -1
#define MENU_BASE_MAIN 8
#define MENU_BASE_CURRENT 9
#define MENU_BASE_MOVE 10

//Auth Defaults
#define AUTH_SUPPORTER ADMFLAG_CUSTOM4
#define AUTH_ADMIN ADMFLAG_UNBAN
#define AUTH_BASE ADMFLAG_CUSTOM4
#define AUTH_DELETE ADMFLAG_GENERIC
#define AUTH_TELEPORT ADMFLAG_GENERIC
#define AUTH_COLOR ADMFLAG_GENERIC
#define AUTH_TARGET ADMFLAG_UNBAN

//Sprites...
#define BEAM_SPRITE 0
#define GLOW_SPRITE 1
#define FLASH_SPRITE 2

//Axis Characters
new String:g_sAxisDisplay[][] = {"X", "Y", "X", "Y", "Z"};

//Prop Types
new String:g_sPropTypes[][] = { "prop_dynamic", "prop_dynamic_override", "prop_physics_multiplayer", "prop_physics_override", "prop_physics" };

//Sprites
new String:g_sSprites[][] = { "materials/sprites/laser.vmt", "sprites/strider_blackball.vmt", "materials/sprites/muzzleflash4.vmt" };

//Queries
new String:g_sSQL_CreateBaseTable[] = { "CREATE TABLE IF NOT EXISTS buildwars_bases (base_index INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL default 1, base_count int(6) NOT NULL default 0, steamid varchar(32) NOT NULL default '')" };
new String:g_sSQL_CreatePropTable[] = { "CREATE TABLE IF NOT EXISTS buildwars_props (prop_index INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL default 1, prop_base int(6) NOT NULL default 0, prop_type int(6) NOT NULL default 0, pos_x float(6) NOT NULL default 0.0, pos_y float(6) NOT NULL default 0.0, pos_z float(6) NOT NULL default 0.0, ang_x float(6) NOT NULL default 0.0, ang_y float(6) NOT NULL default 0.0, ang_z float(6) NOT NULL default 0.0, steamid varchar(32) NOT NULL default '')" } ;
new String:g_sSQL_BaseLoad[] = { "SELECT base_index, base_count FROM buildwars_bases WHERE steamid = '%s'" };
new String:g_sSQL_BaseCreate[] = { "INSERT INTO buildwars_bases (steamid, base_index) VALUES ('%s', NULL)" };
new String:g_sSQL_BaseUpdate[] = { "UPDATE buildwars_bases SET base_count = %d WHERE base_index = '%d'" };
new String:g_sSQL_PropLoad[] = { "SELECT prop_index, prop_type, pos_x, pos_y, pos_z, ang_x, ang_y, ang_z FROM buildwars_props WHERE prop_base = %d" };
new String:g_sSQL_PropSaveIndex[] = { "REPLACE INTO buildwars_props (prop_index, prop_base, prop_type, pos_x, pos_y, pos_z, ang_x, ang_y, ang_z, steamid) VALUES (%d, %d, %d, %.2f, %.2f, %.2f, %.2f, %.2f, %.2f, '%s')" };
new String:g_sSQL_PropSaveNull[] = { "REPLACE INTO buildwars_props (prop_index, prop_base, prop_type, pos_x, pos_y, pos_z, ang_x, ang_y, ang_z, steamid) VALUES (NULL, %d, %d, %.2f, %.2f, %.2f, %.2f, %.2f, %.2f, '%s')" };
new String:g_sSQL_PropDelete[] = { "DELETE FROM buildwars_props WHERE prop_index = %d" };
new String:g_sSQL_PropEmpty[] = { "DELETE FROM buildwars_props WHERE prop_base = %d AND steamid = '%s'" };
new String:g_sSQL_PropCheck[] = { "SELECT prop_index FROM buildwars_props WHERE prop_base = %d" };

new g_iNumProps, g_iNumColors, g_iNumRotations, g_iNumPositions;
new String:g_sDefinedPropNames[MAX_CONFIG_PROPS][64];
new String:g_sDefinedPropPaths[MAX_CONFIG_PROPS][256];
new g_iDefinedPropTypes[MAX_CONFIG_PROPS];
new g_iDefinedPropAccess[MAX_CONFIG_PROPS];
new String:g_sDefinedColorNames[MAX_CONFIG_COLORS][64];
new g_iDefinedColorArrays[MAX_CONFIG_COLORS][4];
new Float:g_fDefinedRotations[MAX_CONFIG_ROTATIONS];
new Float:g_fDefinedPositions[MAX_CONFIG_POSITIONS];

new bool:g_bValidProp[MaxEntities + 1];
new bool:g_bValidGrab[MaxEntities + 1];
new bool:g_bValidBase[MaxEntities + 1];
new g_iPropUser[MaxEntities + 1];
new g_iPropType[MaxEntities + 1];
new g_iBaseIndex[MaxEntities + 1];
new String:g_sPropOwner[MaxEntities + 1][32];

//Data for the clients
new g_iTeam[MAXPLAYERS + 1];
new g_iPlayerAccess[MAXPLAYERS + 1];
new g_iAdminAccess[MAXPLAYERS + 1];
new g_iPlayerTeleports[MAXPLAYERS + 1];
new g_iPlayerDeletes[MAXPLAYERS + 1];
new g_iPlayerProps[MAXPLAYERS + 1];
new g_iPlayerColors[MAXPLAYERS + 1];
new g_iPlayerControl[MAXPLAYERS + 1];
new Float:g_fConfigDistance[MAXPLAYERS + 1];
new g_iConfigRotation[MAXPLAYERS + 1];
new g_iConfigPosition[MAXPLAYERS + 1];
new g_iConfigColor[MAXPLAYERS + 1];
new bool:g_bTeleporting[MAXPLAYERS + 1];
new bool:g_bTeleported[MAXPLAYERS + 1];
new bool:g_bLoaded[MAXPLAYERS + 1];
new bool:g_bAlive[MAXPLAYERS + 1];
new bool:g_bQuickToggle[MAXPLAYERS + 1];
new bool:g_bConfigAxis[MAXPLAYERS + 1][AXIS_TOTAL];
new Float:g_fTeleRemaining[MAXPLAYERS + 1];
new String:g_sSteam[MAXPLAYERS + 1][32];
new String:g_sName[MAXPLAYERS + 1][32];
new Handle:g_hArray_PlayerProps[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };
new Handle:g_hTimer_TeleportPlayer[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };
new Handle:g_hTimer_UpdateControl[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };

new bool:g_bSaveLocation[MAXPLAYERS + 1];			//The client's save location state
new Handle:g_hSaveLocation[MAXPLAYERS + 1];		//The client's handle to repeating timer
new Float:g_fSaveLocation[MAXPLAYERS + 1][3];		//The client's save location origin
new g_iPlayerBaseMenu[MAXPLAYERS + 1] = { -1, ... };
new g_iPlayerBaseQuery[MAXPLAYERS + 1];
new g_iPlayerBaseLoading[MAXPLAYERS + 1];
new g_iPlayerBase[MAXPLAYERS + 1][7];	//The client's base index
new g_iPlayerBaseCount[MAXPLAYERS + 1][7];	//The client's base prop count
new bool:g_bPlayerBaseSpawned[MAXPLAYERS + 1] = { false, ... };	//True if the client currently has a base spawned.
new g_iPlayerBaseCurrent[MAXPLAYERS + 1] = { -1, ... };		//The client's current base
new Float:g_fPlayerBaseLocation[MAXPLAYERS + 1][3];	//The client's intended spawn location.

new Handle:g_hCvar[CVAR_COUNT] = { INVALID_HANDLE, ... };
new Handle:g_hTimer_Update = INVALID_HANDLE;
new Handle:g_hTrieCommands = INVALID_HANDLE;
new Handle:g_hSql_Database = INVALID_HANDLE;
new Handle:g_cConfigVersion = INVALID_HANDLE;
new Handle:g_cConfigRotation = INVALID_HANDLE;
new Handle:g_cConfigPosition = INVALID_HANDLE;
new Handle:g_cConfigColor = INVALID_HANDLE;
new Handle:g_cConfigLocks = INVALID_HANDLE;
new Handle:g_cConfigDistance = INVALID_HANDLE;
new Handle:g_hServerTags = INVALID_HANDLE;
new Handle:g_hTrieCommandConfig = INVALID_HANDLE;

new bool:g_bHelp, bool:g_bEnabled, bool:g_bLateLoad, bool:g_bEnding, bool:g_bDissolve, bool:g_bRotationAllowed, bool:g_bPositionAllowed, bool:g_bColorAllowed, bool:g_bControlAllowed,
	bool:g_bAccessAdmin, bool:g_bAccessSettings, bool:g_bHasAccess[4] = { false, false, false, false }, bool:g_bQuickMenu, bool:g_bDisableFeatures, bool:g_bBaseEnabled, bool:g_bLateBase;
new g_iCurEntities, g_iColorRed[4], g_iColorBlue[4], g_iPropPublic, g_iPropSupporter, g_iPropAdmin, g_iDeletePublic, g_iDeleteSupporter, g_iDeleteAdmin, g_iTeleportPublic, g_iTeleportSupporter, 
	g_iTeleportAdmin, g_iDefaultColor, g_iDefaultRotation, g_iDefaultPosition, g_iColoringPublic, g_iColoringSupporter, g_iColoringAdmin, g_iColorPublic, g_iColorSupporter, g_iColorAdmin, 
	g_iControlAccess, g_iCheckAccess, g_iCurrentDisable, g_iUniqueProp, g_iNumRedSpawns, g_iNumBlueSpawns, g_iDisableDelay, g_iNumSeconds, g_iBaseGroups, g_iGlowSprite, g_iFlashSprite, 
	g_iBaseLimit, g_iBaseAccess, g_iBeamSprite, g_iLoadProps, g_iLoadColors, g_iLoadRotations, g_iLoadPositions, g_iLoadCommands;
new Float:g_fDefaultControl, Float:g_fGrabMinimum, Float:g_fGrabMaximum, Float:g_fGrabInterval, Float:g_fAdvert, Float:g_fTeleportPublicDelay, Float:g_fTeleportSupporterDelay, Float:g_fTeleportAdminDelay,
	Float:g_fGrabDistance, Float:g_fGrabUpdate, Float:g_fRedTeleports[32][3], Float:g_fBlueTeleports[32][3], Float:g_fBaseDistance;
new String:g_sPrefixSelect[128], String:g_sPrefixEmpty[128], String:g_sDissolve[8], String:g_sTitle[128], String:g_sHelp[128], String:g_sPrefixChat[128], String:g_sPrefixHint[128], 
	String:g_sPrefixConsole[128], String:g_sPrefixCenter[128], String:g_sBaseDatabase[32], String:g_sBaseNames[7][32];

public Plugin:myinfo =
{
	name = "Build Wars (v2)", 
	author = "Twisted|Panda", 
	description = "Provides the custom gameplay known as BuildWars with advanced configuration and functionality.",
	version = PLUGIN_VERSION, 
	url = "http://ominousgaming.com"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	g_bLateLoad = g_bLateBase = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("sm_buildwars_v2.phrases");

	CreateConVar("sm_buildwars_version", PLUGIN_VERSION, "BuildWars: Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_CHEAT|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hCvar[CVAR_ENABLED] = CreateConVar("sm_buildwars_enable", "1", "Enables/disables all features of the plugin. (0 = Disabled, 1 = Enabled)", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_ENABLED], OnSettingsChange);
	g_hCvar[CVAR_DISSOLVE] = CreateConVar("sm_buildwars_dissolve", "3", "The dissolve effect to be used for removing props. (-1 = Disabled, 0 = Energy, 1 = Light, 2 = Heavy, 3 = Core)", FCVAR_NONE, true, -1.0, true, 3.0);
	HookConVarChange(g_hCvar[CVAR_DISSOLVE], OnSettingsChange);
	g_hCvar[CVAR_HELP] = CreateConVar("sm_buildwars_help", "", "The page that appears when a user types the help command into chat (\"\" = Disabled)", FCVAR_NONE);
	HookConVarChange(g_hCvar[CVAR_HELP], OnSettingsChange);
	g_hCvar[CVAR_ADVERT] = CreateConVar("sm_buildwars_advert", "5.0", "The number of seconds after a player joins an initial team for sm_buildwars_advert to be sent to the player. (-1 = Disabled)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_ADVERT], OnSettingsChange);
	g_hCvar[CVAR_QUICK] = CreateConVar("sm_buildwars_quick_menu", "1.0", "If enabled, clients will be able to open the Build Wars menu by pressing their USE key.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_QUICK], OnSettingsChange);
	
	g_hCvar[CVAR_DEFAULT_COLOR] = CreateConVar("sm_buildwars_default_color", "0", "The default prop color that players will spawn with. (# = Index, -1 = No Color Options)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_DEFAULT_COLOR], OnSettingsChange);
	g_hCvar[CVAR_DEFAULT_ROTATION] = CreateConVar("sm_buildwars_default_rotation", "3", "The default degree value that players will spawn with. (# = Index, -1 = No Rotation Options)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_DEFAULT_ROTATION], OnSettingsChange);
	g_hCvar[CVAR_DEFAULT_POSITION] = CreateConVar("sm_buildwars_default_position", "4", "The default position value that players will spawn with. (# = Index, -1 = No Position Options)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_DEFAULT_POSITION], OnSettingsChange);
	g_hCvar[CVAR_DEFAULT_CONTROL] = CreateConVar("sm_buildwars_default_distance", "150", "The default control distance that players will spawn with. (#.# = Interval, -1 = No Control Options)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_DEFAULT_CONTROL], OnSettingsChange);

	g_hCvar[CVAR_DISABLE] = CreateConVar("sm_buildwars_disable", "0", "Add values together for multiple feature disable. (0 = Disabled, 1 = Building, 2 = Deleting, 4 = Rotating, 8 = Moving, 16 = Grabbing, 32 = Checking, 64 = Teleporting, 128 = Coloring, 256 = Clearing)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_DISABLE], OnSettingsChange);	
	g_hCvar[CVAR_DISABLE_DELAY] = CreateConVar("sm_buildwars_disable_delay", "0", "The number of seconds after the start of the round for sm_buildwars_disable to be executed, restricting the defined features.", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_DISABLE_DELAY], OnSettingsChange);	

	g_hCvar[CVAR_PUBLIC_PROPS] = CreateConVar("sm_buildwars_prop_public", "85", "The maximum amount of props public players are allowed to build. (0 = Infinite, -1 = No Building)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_PUBLIC_PROPS], OnSettingsChange);
	g_hCvar[CVAR_SUPPORTER_PROPS] = CreateConVar("sm_buildwars_prop_supporter", "100", "The maximum amount of props administrative players are allowed to build. (0 = Infinite, -1 = No Building)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_SUPPORTER_PROPS], OnSettingsChange);
	g_hCvar[CVAR_ADMIN_PROPS] = CreateConVar("sm_buildwars_prop_admin", "100", "The maximum amount of props supporter players are allowed to build. (0 = Infinite, -1 = No Building)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_ADMIN_PROPS], OnSettingsChange);	

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

	g_hCvar[CVAR_PUBLIC_COLOR] = CreateConVar("sm_buildwars_color_public", "15", "If the player's coloring scheme is set to Selection, this is the number of times they're allowed to color their props. (0 = Infinite, -1 = No Coloring)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_PUBLIC_COLOR], OnSettingsChange);
	g_hCvar[CVAR_SUPPORTER_COLOR] = CreateConVar("sm_buildwars_color_supporter", "30", "If the supporter's coloring scheme is set to Selection, this is the number of times they're allowed to color their props. (0 = Infinite, -1 = No Coloring)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_SUPPORTER_COLOR], OnSettingsChange);
	g_hCvar[CVAR_ADMIN_COLOR] = CreateConVar("sm_buildwars_color_admin", "0", "If the admin's coloring scheme is set to Selection, this is the number of times they're allowed to color their props. (0 = Infinite, -1 = No Coloring)", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_ADMIN_COLOR], OnSettingsChange);
	g_hCvar[CVAR_PUBLIC_COLORING] = CreateConVar("sm_buildwars_coloring_mode_public", "0", "Determines how props will be colored for public players. (0 = Selection, 1 = Forced Random, 2 = Forced Team Colored, 3 = Forced Default)", FCVAR_NONE, true, 0.0, true, 3.0);
	HookConVarChange(g_hCvar[CVAR_PUBLIC_COLORING], OnSettingsChange);
	g_hCvar[CVAR_SUPPORTER_COLORING] = CreateConVar("sm_buildwars_coloring_mode_supporter", "0", "Determines how props will be colored for supporters. (0 = Selection, 1 = Forced Random, 2 = Forced Team Colored, 3 = Forced Default)", FCVAR_NONE, true, 0.0, true, 3.0);
	HookConVarChange(g_hCvar[CVAR_SUPPORTER_COLORING], OnSettingsChange);
	g_hCvar[CVAR_ADMIN_COLORING] = CreateConVar("sm_buildwars_coloring_mode_admin", "0", "Determines how props will be colored for admins. (0 = Selection, 1 = Forced Random, 2 = Forced Team Colored, 3 = Forced Default)", FCVAR_NONE, true, 0.0, true, 3.0);
	HookConVarChange(g_hCvar[CVAR_ADMIN_COLORING], OnSettingsChange);	
	g_hCvar[CVAR_COLOR_RED] = CreateConVar("sm_buildwars_coloring_red", "255 0 0 255", "The defined color for players on the Terrorist team when colors are forced.", FCVAR_NONE);
	HookConVarChange(g_hCvar[CVAR_COLOR_RED], OnSettingsChange);
	g_hCvar[CVAR_COLOR_BLUE] = CreateConVar("sm_buildwars_coloring_blue", "0 0 255 255", "The defined color for players on the Terrorist team when colors are forced.", FCVAR_NONE);
	HookConVarChange(g_hCvar[CVAR_COLOR_BLUE], OnSettingsChange);	

	g_hCvar[CVAR_ACCESS_SPEC] = CreateConVar("sm_buildwars_access_team_spec", "1", "Controls whether or not Spectators have access to any features provided by Build Wars.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_SPEC], OnSettingsChange);
	g_hCvar[CVAR_ACCESS_RED] = CreateConVar("sm_buildwars_access_team_red", "1", "Controls whether or not Terrorists have access to any features provided by Build Wars.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_RED], OnSettingsChange);
	g_hCvar[CVAR_ACCESS_BLUE] = CreateConVar("sm_buildwars_access_team_blue", "1", "Controls whether or not Counter-Terrorists have access to any features provided by Build Wars.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_BLUE], OnSettingsChange);
	g_hCvar[CVAR_ACCESS_SETTINGS] = CreateConVar("sm_buildwars_access_settings", "1", "If enabled, players will be able to access the Actions / Settings menu in Build Wars.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_SETTINGS], OnSettingsChange);
	g_hCvar[CVAR_ACCESS_ADMIN]  = CreateConVar("sm_buildwars_access_admin", "1", "If enabled, admins will be able to access the Admin Actions menu in Build Wars", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_ADMIN], OnSettingsChange);	
	g_hCvar[CVAR_ACCESS_CHECK] = CreateConVar("sm_buildwars_access_check", "7", "Controls access to the check prop feature.  Add values together for multiple group access. (0 = Disabled, 1 = Normal, 2 = Supporters, 4 = Admins)", FCVAR_NONE, true, 0.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_CHECK], OnSettingsChange);
	g_hCvar[CVAR_ACCESS_GRAB] = CreateConVar("sm_buildwars_access_grab", "7", "Controls access to the grab feature. Add values together for multiple group access. (0 = Disabled, 1 = Normal, 2 = Supporters, 4 = Admins)", FCVAR_NONE, true, 0.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_GRAB], OnSettingsChange);
	g_hCvar[CVAR_ACCESS_BASE] = CreateConVar("sm_buildwars_access_base", "6", "Controls access to the base feature, if it is enabled. Add values together for multiple group access. (0 = Disabled, 1 = Normal, 2 = Supporters, 4 = Admins)", FCVAR_NONE, true, 0.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_ACCESS_BASE], OnSettingsChange);

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
	
	g_hCvar[CVAR_BASE_ENABLED] = CreateConVar("sm_buildwars_base_enabled", "1", "If enabled, players with appropriate access will be able to access the Base feature, which allows saving/spawning multiple props.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_BASE_ENABLED], OnSettingsChange);
	g_hCvar[CVAR_BASE_DATABASE] = CreateConVar("sm_buildwars_base_database", "", "The sqlite database located within databases.cfg. (\"\" = sourcemod-local.sql)", FCVAR_NONE);
	HookConVarChange(g_hCvar[CVAR_BASE_DATABASE], OnSettingsChange);
	g_hCvar[CVAR_BASE_DISTANCE] = CreateConVar("sm_buildwars_base_distance", "1000", "Props greater than this distance from the origin of the base location will not be saved, to prevent corruption. (0.0 = Disabled)", FCVAR_NONE, true, 0.0);
	HookConVarChange(g_hCvar[CVAR_BASE_DISTANCE], OnSettingsChange);
	g_hCvar[CVAR_BASE_GROUPS] = CreateConVar("sm_buildwars_base_groups", "3", "The number of bases available to clients with appropriate access. Limit of 7 bases per client.", FCVAR_NONE, true, 1.0, true, 7.0);
	HookConVarChange(g_hCvar[CVAR_BASE_GROUPS], OnSettingsChange);
	g_hCvar[CVAR_BASE_NAMES] = CreateConVar("sm_buildwars_base_names", "Alpha, Beta, Gamma, Delta, Epsilon, Zeta, Eta", "The names to be assigned to the client bases. Separate values with \", \".", FCVAR_NONE);
	HookConVarChange(g_hCvar[CVAR_BASE_NAMES], OnSettingsChange);
	g_hCvar[CVAR_BASE_LIMIT] = CreateConVar("sm_buildwars_base_limit", "0", "The maximum limit of props each base can hold. Use 0 to limit the number of props to the client's maximum, otherwise use -1 to disable this feature.", FCVAR_NONE, true, -1.0);
	HookConVarChange(g_hCvar[CVAR_BASE_LIMIT], OnSettingsChange);
	AutoExecConfig(true, "sm_buildwars_v2");
	
	g_hServerTags = FindConVar("sv_tags");
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
	HookEvent("round_end", Event_OnRoundEnd);
	HookEvent("round_start", Event_OnRoundStart);
	HookEvent("player_team", Event_OnPlayerTeam, EventHookMode_Pre);
	HookEvent("player_spawn", Event_OnPlayerSpawn, EventHookMode_Pre);
	HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Pre);	
	HookEvent("player_changename", Event_OnPlayerName, EventHookMode_Pre);

	RegAdminCmd("sm_showhelp", Command_Help, ADMFLAG_GENERIC, "Build Wars: Forces the client to type !help");
	RegConsoleCmd("sm_buildwars_reset", Command_Reset, "Provides the ability to delete all props at once from outside the Build Wars script. <Target> parameter optional.");
	g_cConfigVersion = RegClientCookie("BuildWars_ClientVersion", "The version string from which the client was authenticated.", CookieAccess_Private);
	g_cConfigRotation = RegClientCookie("BuildWars_ConfigRotation", "The client's configuration value for rotation intervals.", CookieAccess_Private);
	g_cConfigPosition = RegClientCookie("BuildWars_ConfigPosition", "The client's configuration value for position intervals.", CookieAccess_Private);
	g_cConfigColor = RegClientCookie("BuildWars_ConfigColor", "The client's configuration value for prop colors.", CookieAccess_Private);
	g_cConfigLocks = RegClientCookie("BuildWars_ConfigLocks", "The client's configuration value for positional and rotational locking.", CookieAccess_Private);
	g_cConfigDistance = RegClientCookie("BuildWars_ConfigGrab", "The client's configuration value for grab distance.", CookieAccess_Private);

	Define_Defaults();
	AddCustomTag();
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
				Bool_ClearClientProps(i);
				Void_ClearClientControl(i);
				Void_ClearClientTeleport(i);
			}
		}
	}
}

public OnMapStart()
{
	g_iCurEntities = 0;
	for(new i = 1; i <= MaxEntities; i++)
		if(IsValidEntity(i))
			g_iCurEntities++;

	if(g_bEnabled)
	{
		if(g_hTrieCommands == INVALID_HANDLE)
			g_hTrieCommands = CreateTrie();

		for(new i = 1; i <= MaxClients; i++)
			if(g_hArray_PlayerProps[i] == INVALID_HANDLE)
				g_hArray_PlayerProps[i] = CreateArray();

		Define_Props();
		Define_Rotations();
		Define_Positions();
		Define_Colors();
		Define_Commands();
	
		Void_SetSpawns();

		for(new i = 0; i < g_iNumProps; i++)
			PrecacheModel(g_sDefinedPropPaths[i]);
			
		g_iBeamSprite = PrecacheModel(g_sSprites[BEAM_SPRITE]);
		g_iGlowSprite = PrecacheModel(g_sSprites[GLOW_SPRITE]);
		g_iFlashSprite = PrecacheModel(g_sSprites[FLASH_SPRITE]);
	}
}

public OnMapEnd()
{
	g_bEnding = true;
	if(g_bEnabled)
	{
		if(g_hTimer_Update != INVALID_HANDLE && CloseHandle(g_hTimer_Update))
			g_hTimer_Update = INVALID_HANDLE;

		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				Bool_ClearClientProps(i);
				Void_ClearClientControl(i);
				Void_ClearClientTeleport(i);
			}
		}
	}
}

public OnConfigsExecuted()
{
	if(g_bEnabled)
	{
		if(g_hSql_Database == INVALID_HANDLE)
			SQL_TConnect(SQL_ConnectCall, StrEqual(g_sBaseDatabase, "") ? "storage-local" : g_sBaseDatabase);

		Format(g_sTitle, 128, "%T", "Main_Menu_Title", LANG_SERVER);
		Format(g_sPrefixChat, 128, "%T", "Prefix_Chat", LANG_SERVER);
		Format(g_sPrefixHint, 128, "%T", "Prefix_Hint", LANG_SERVER);
		Format(g_sPrefixCenter, 128, "%T", "Prefix_Center", LANG_SERVER);
		Format(g_sPrefixConsole, 128, "%T", "Prefix_Console", LANG_SERVER);
		Format(g_sPrefixSelect, 128, "%T", "Menu_Option_Selected", LANG_SERVER);
		Format(g_sPrefixEmpty, 128, "%T", "Menu_Option_Empty", LANG_SERVER);

		if(g_bLateLoad)
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				g_iPlayerAccess[i] = ACCESS_PUBLIC;

				if(IsClientInGame(i))
				{
					g_iTeam[i] = GetClientTeam(i);
					g_bAlive[i] = IsPlayerAlive(i);
					GetClientAuthString(i, g_sSteam[i], 32);	
					GetClientName(i, g_sName[i], 32);

					g_iPlayerProps[i] = 0;
					g_iPlayerDeletes[i] = 0;
					g_iPlayerColors[i] = 0;
					g_iPlayerTeleports[i] = 0;
					g_iPlayerControl[i] = -1;

					Void_AuthClient(i);
					if(AreClientCookiesCached(i))
						Void_LoadCookies(i);
				}
			}

			g_bLateLoad = false;
		}
	}
}

public OnClientPutInServer(client)
{
	if(g_bEnabled)
	{
		g_iPlayerProps[client] = 0;
		g_iPlayerColors[client] = 0;
		g_iPlayerDeletes[client] = 0;
		g_iPlayerTeleports[client] = 0;
	}
}

public OnClientPostAdminCheck(client)
{
	if(g_bEnabled)
	{
		if(client > 0 && IsClientInGame(client))
		{
			g_iPlayerAccess[client] = ACCESS_PUBLIC;
			GetClientAuthString(client, g_sSteam[client], 32);		
			GetClientName(client, g_sName[client], 32);
			
			Void_AuthClient(client);

			if(!g_bLoaded[client] && AreClientCookiesCached(client))
				Void_LoadCookies(client);

			if(g_bBaseEnabled && (g_iPlayerAccess[client] & g_iBaseAccess || g_iPlayerAccess[client] & ACCESS_BASE))
				Void_LoadClientBase(client);
		}
	}
}

public OnClientDisconnect(client)
{
	if(g_bEnabled)
	{
		Bool_ClearClientProps(client);
		Void_ClearClientControl(client);
		Void_ClearClientTeleport(client);
		
		if(g_hSql_Database != INVALID_HANDLE)
		{
			if(g_bBaseEnabled && (g_iPlayerAccess[client] & g_iBaseAccess || g_iPlayerAccess[client] & ACCESS_BASE))
			{
				decl String:_sQuery[256];
				for(new i = 0; i < g_iBaseGroups; i++)
				{
					Format(_sQuery, sizeof(_sQuery), g_sSQL_BaseUpdate, g_iPlayerBaseCount[client][i], g_iPlayerBase[client][i]);
					SQL_TQuery(g_hSql_Database, SQL_QueryBaseUpdatePost, _sQuery, GetClientUserId(client));
				}

				if(g_bSaveLocation[client])
				{
					g_bSaveLocation[client] = false;
					if(g_hSaveLocation[client] != INVALID_HANDLE && CloseHandle(g_hSaveLocation[client]))
						g_hSaveLocation[client] = INVALID_HANDLE;
				}

				g_iPlayerBaseCurrent[client] = -1;
			}
		}

		g_iTeam[client] = 0;
		g_bAlive[client] = false;
		g_bLoaded[client] = false;
		g_bQuickToggle[client] = false;
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
	if(g_bEnabled)
	{
		g_iCurEntities = 0;
	}

	return Plugin_Continue;
}

public OnEntityCreated(entity, const String:classname[])
{
	if(entity >= 0)
	{
		if(g_bEnabled)
		{
			g_bValidProp[entity] = false;
			g_bValidGrab[entity] = false;
			g_iPropUser[entity] = 0;
		}

		g_iCurEntities++;
	}
}

public OnEntityDestroyed(entity)
{
	if(entity >= 0)
	{
		if(g_bEnabled)
		{
			if(g_bValidProp[entity])
			{
				g_bValidProp[entity] = false;
				if(!g_bEnding)
				{
					new client = GetClientOfUserId(g_iPropUser[entity]);
					if(client > 0)
					{
						g_iPlayerProps[client]--;
						new _iIndex = GetEntityIndex(client, entity);
						if(_iIndex >= 0)
							RemoveFromArray(g_hArray_PlayerProps[client], _iIndex);
					}
				}
			}

			g_bValidGrab[entity] = false;
			g_iPropUser[entity] = 0;
		}

		g_iCurEntities--;
	}
}

public OnGameFrame()
{
	if(g_bEnabled && !g_bEnding && g_bQuickMenu)
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				if(GetClientButtons(i) & IN_USE)
				{
					if(!g_bQuickToggle[i])
					{
						g_bQuickToggle[i] = true;
						Menu_Main(i);
					}
				}
				else if(g_bQuickToggle[i])
					g_bQuickToggle[i] = false;
			}
		}
	}
}

public Action:Event_OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		g_bEnding = true;	
		if(g_hTimer_Update != INVALID_HANDLE && CloseHandle(g_hTimer_Update))
			g_hTimer_Update = INVALID_HANDLE;

		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				Void_ClearClientControl(i);
				Void_ClearClientTeleport(i);
				Bool_ClearClientProps(i, false);

				if(g_hSql_Database != INVALID_HANDLE)
				{				
					if(g_bBaseEnabled && (g_iPlayerAccess[i] & g_iBaseAccess || g_iPlayerAccess[i] & ACCESS_BASE))
					{
						g_iPlayerBaseQuery[i] = 0;
						if(g_bPlayerBaseSpawned[i])
							g_bPlayerBaseSpawned[i] = false;

						if(g_bSaveLocation[i])
						{
							g_bSaveLocation[i] = false;
							if(g_hSaveLocation[i] != INVALID_HANDLE && CloseHandle(g_hSaveLocation[i]))
								g_hSaveLocation[i] = INVALID_HANDLE;
						}
					}
				}

				g_iPlayerProps[i] = 0;
				g_iPlayerDeletes[i] = 0;
				g_iPlayerColors[i] = 0;
				g_iPlayerTeleports[i] = 0;
				g_bTeleported[i] = false;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:Event_OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		g_bEnding = false;
		g_bDisableFeatures = false;
		g_iUniqueProp = 0;
		g_iNumSeconds = 0;

		g_hTimer_Update = CreateTimer(1.0, Timer_Update, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue;
}

public Action:Timer_Update(Handle:timer)
{
	if(GetClientCount() >= 2)
		g_iNumSeconds++;
	else
	{
		g_iNumSeconds = 0;
		g_bDisableFeatures = false;
	}

	if(g_iDisableDelay && g_iCurrentDisable)
	{
		if(g_iNumSeconds >= g_iDisableDelay)
		{
			if(!g_bDisableFeatures)
				g_bDisableFeatures = true;
		}
		else if(g_bDisableFeatures)
			g_bDisableFeatures = false;
	}
}

public Action:Event_OnPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(client <= 0 || !IsClientInGame(client))
			return Plugin_Continue;
		
		g_iTeam[client] = GetEventInt(event, "team");
		if(g_iTeam[client] == TEAM_SPEC)
			g_bAlive[client] = false;

		if(g_bHasAccess[g_iTeam[client]])
		{
			if(GetEventInt(event, "oldteam") == TEAM_NONE)
			{
				if(g_fAdvert >= 0.0)
					CreateTimer(g_fAdvert, Timer_Announce, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			}
			else
			{
				Void_ClearClientControl(client);
				Void_ClearClientTeleport(client);

				if(g_iTeam[client] != TEAM_SPEC)
					Bool_ClearClientProps(client);
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
		if(client <= 0 || !IsClientInGame(client) || g_iTeam[client] < TEAM_RED)
			return Plugin_Continue;

		g_bAlive[client] = true;
	}
		
	return Plugin_Continue;
}

public Action:Event_OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(client <= 0 || !IsClientInGame(client))
			return Plugin_Continue;

		g_bAlive[client] = false;
		if(!g_bEnding && g_bHasAccess[g_iTeam[client]])
		{
			Void_ClearClientControl(client);
			Void_ClearClientTeleport(client);
		}
	}
		
	return Plugin_Continue;
}

public Action:Event_OnPlayerName(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bEnabled)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(client > 0 && IsClientInGame(client) && g_bHasAccess[g_iTeam[client]])
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

public Action:Command_Say(client, const String:command[], argc)
{
	if(g_bEnabled)
	{
		if(g_bEnding || client <= 0 || !IsClientInGame(client) || !g_bHasAccess[g_iTeam[client]])
			return Plugin_Continue;
		else
		{
			new String:_sTrigger[2][32];
			decl _iIndex, String:_sText[192];
			GetCmdArgString(_sText, 192);
			StripQuotes(_sText);
			TrimString(_sText);
			
			ExplodeString(_sText, " ", _sTrigger, sizeof(_sTrigger), sizeof(_sTrigger[]));
			new _iSize = strlen(_sTrigger[0]);
			for (new i = 0; i < _iSize; i++)
				if(IsCharAlpha(_sTrigger[0][i]) && IsCharUpper(_sTrigger[0][i]))
					_sTrigger[0][i] = CharToLower(_sTrigger[0][i]);

			if(GetTrieValue(g_hTrieCommands, _sTrigger[0], _iIndex))
			{
				switch(_iIndex)
				{
					case COMMAND_MENU:
					{
						if(StrEqual(_sTrigger[1], ""))
							Menu_Main(client);
						else
						{
							if(Bool_SpawnAllowed(client, true) && Bool_SpawnValid(client, true))
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

	g_bValidGrab[g_iPlayerControl[client]] = true;
}

Void_ClearClientControl(client)
{
	if(g_iPlayerControl[client] != -1)
	{
		g_bValidGrab[g_iPlayerControl[client]] = false;
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

public Action:Timer_UpdateControl(Handle:timer, any:client)
{
	if(!IsClientInGame(client) || g_iPlayerControl[client] <= 0 || !g_bValidProp[g_iPlayerControl[client]])
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

	GetEntPropVector(g_iPlayerControl[client], Prop_Send, "m_vecOrigin", _fOriginal);
	_fPosition[0] = g_bConfigAxis[client][POSITION_AXIS_X] ? _fOriginal[0] : float(RoundToNearest(_fPosition[0] / g_fDefinedPositions[g_iConfigPosition[client]])) * g_fDefinedPositions[g_iConfigPosition[client]];
	_fPosition[1] = g_bConfigAxis[client][POSITION_AXIS_Y] ? _fOriginal[1] : float(RoundToNearest(_fPosition[1] / g_fDefinedPositions[g_iConfigPosition[client]])) * g_fDefinedPositions[g_iConfigPosition[client]];
	_fPosition[2] = g_bConfigAxis[client][POSITION_AXIS_Z] ? _fOriginal[2] : float(RoundToNearest(_fPosition[2] / g_fDefinedPositions[g_iConfigPosition[client]])) * g_fDefinedPositions[g_iConfigPosition[client]];

	GetEntPropVector(g_iPlayerControl[client], Prop_Data, "m_angRotation", _fOriginal);	
	_fAngles[0] = g_bConfigAxis[client][ROTATION_AXIS_X] ? _fOriginal[0] : float(RoundToNearest(_fAngles[0] / g_fDefinedRotations[g_iConfigRotation[client]])) * g_fDefinedRotations[g_iConfigRotation[client]];
	_fAngles[1] = g_bConfigAxis[client][ROTATION_AXIS_Y] ? _fOriginal[1] : float(RoundToNearest(_fAngles[1] / g_fDefinedRotations[g_iConfigRotation[client]])) * g_fDefinedRotations[g_iConfigRotation[client]];
	_fAngles[2] = _fOriginal[2];
	
	TeleportEntity(g_iPlayerControl[client], _fPosition, _fAngles, NULL_VECTOR);
	return Plugin_Continue;
}

public Action:Timer_Announce(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(client > 0 && IsClientInGame(client))
		CPrintToChat(client, "%s%t", g_sPrefixChat, "Welcome_Advert", g_sName[client]);
	
	return Plugin_Handled;
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
			TeleportEntity(client, g_fRedTeleports[GetRandomInt(0, g_iNumRedSpawns)], NULL_VECTOR, NULL_VECTOR);
		case 3:
			TeleportEntity(client, g_fBlueTeleports[GetRandomInt(0, g_iNumBlueSpawns)], NULL_VECTOR, NULL_VECTOR);
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
				if(IsValidEntity(_iIndex) && g_bValidProp[_iIndex])
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

public bool:Tracer_FilterPlayers(entity, contentsMask, any:data)
{
	if(entity > MaxClients)
		return true;

	return false;
}

public bool:Tracer_FilterBlocks(entity, contentsMask, any:data)
{
	if(entity > MaxClients && !g_bValidGrab[entity])
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
	}

	g_iPlayerProps[client] = 0;
	if(clear)
		g_iPlayerDeletes[client] += _iDeleted;
	else
		g_iPlayerDeletes[client] = 0;

	ClearArray(g_hArray_PlayerProps[client]);

	if(g_bBaseEnabled)
		if(g_bPlayerBaseSpawned[client])
			g_bPlayerBaseSpawned[client] = false;

	return _iDeleted ? true : false;
}

bool:Entity_Valid(entity)
{
	if(entity > 0 && IsValidEntity(entity) && g_bValidProp[entity])
		return true;

	return false;
}

Entity_SpawnProp(client, _iType, Float:_fPosition[3], Float:_fAngles[3])
{
	new entity = CreateEntityByName(g_sPropTypes[g_iDefinedPropTypes[_iType]]);
	if(entity > 0)
	{
		g_bValidProp[entity] = true;
		g_bValidBase[entity] = false;
		g_iBaseIndex[entity] = -1;
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

Entity_SpawnBase(client, _iType, Float:_fPosition[3], Float:_fAngles[3], _iIndex)
{
	new entity = CreateEntityByName(g_sPropTypes[g_iDefinedPropTypes[_iType]]);
	if(entity > 0)
	{
		g_bValidProp[entity] = true;
		g_bValidBase[entity] = true;
		g_iBaseIndex[entity] = _iIndex;
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
		new _iDissolve = CreateEntityByName("env_entity_dissolver");
		if(_iDissolve > 0)
		{
			g_bValidProp[entity] = false;

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

	g_bValidProp[entity] = false;
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
	new entity = -1;
	g_iNumRedSpawns = 0;
	while((entity = FindEntityByClassname(entity, "info_player_terrorist")) != -1)
	{
		if(g_iNumRedSpawns >= 32)
			break;

		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", g_fRedTeleports[g_iNumRedSpawns]);
		g_iNumRedSpawns++;
	}

	if(g_iNumRedSpawns)
		g_iNumRedSpawns--;

	entity = -1;
	g_iNumBlueSpawns = 0;
	while((entity = FindEntityByClassname(entity, "info_player_counterterrorist")) != -1)
	{
		if(g_iNumBlueSpawns >= 32)
			break;

		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", g_fBlueTeleports[g_iNumBlueSpawns]);
		g_iNumBlueSpawns++;
	}

	if(g_iNumBlueSpawns)
		g_iNumBlueSpawns--;
}

Define_Defaults()
{
	g_hTrieCommandConfig = CreateTrie();
	SetTrieValue(g_hTrieCommandConfig, "Commands_Menu", COMMAND_MENU);
	SetTrieValue(g_hTrieCommandConfig, "Commands_Rotate", COMMAND_ROTATION);
	SetTrieValue(g_hTrieCommandConfig, "Commands_Position", COMMAND_POSITION);
	SetTrieValue(g_hTrieCommandConfig, "Commands_Delete", COMMAND_DELETE);
	SetTrieValue(g_hTrieCommandConfig, "Commands_Grab", COMMAND_CONTROL);
	SetTrieValue(g_hTrieCommandConfig, "Commands_Check", COMMAND_CHECK);
	SetTrieValue(g_hTrieCommandConfig, "Commands_Tele", COMMAND_TELE);
	SetTrieValue(g_hTrieCommandConfig, "Commands_Help", COMMAND_HELP);
	SetTrieValue(g_hTrieCommandConfig, "Commands_DeleteAll", COMMAND_CLEAR);

	decl String:_sTemp[32], String:_sColors[4][4];	

	g_bEnabled = GetConVarInt(g_hCvar[CVAR_ENABLED]) ? true : false;
	GetConVarString(g_hCvar[CVAR_DISSOLVE], g_sDissolve, 8);
	g_bDissolve = GetConVarInt(g_hCvar[CVAR_DISSOLVE]) >= 0 ? true : false;
	GetConVarString(g_hCvar[CVAR_HELP], g_sHelp, 128);
	g_bHelp = StrEqual(g_sHelp, "") ? false : true;
	g_fAdvert = GetConVarFloat(g_hCvar[CVAR_ADVERT]);
	g_bQuickMenu = GetConVarInt(g_hCvar[CVAR_QUICK]) ? true : false;

	g_iDefaultColor = GetConVarInt(g_hCvar[CVAR_DEFAULT_COLOR]);
	g_bColorAllowed = g_iDefaultColor != -1 ? true : false;
	g_iDefaultRotation = GetConVarInt(g_hCvar[CVAR_DEFAULT_ROTATION]);
	g_bRotationAllowed = g_iDefaultRotation != -1 ? true : false;
	g_iDefaultPosition = GetConVarInt(g_hCvar[CVAR_DEFAULT_POSITION]);
	g_bPositionAllowed = g_iDefaultPosition != -1 ? true : false;
	g_fDefaultControl = GetConVarFloat(g_hCvar[CVAR_DEFAULT_CONTROL]);
	g_bControlAllowed = g_fDefaultControl != -1.0 ? true : false;
	
	g_iCurrentDisable = GetConVarInt(g_hCvar[CVAR_DISABLE]);
	g_iDisableDelay = GetConVarInt(g_hCvar[CVAR_DISABLE_DELAY]);

	g_iPropPublic = GetConVarInt(g_hCvar[CVAR_PUBLIC_PROPS]);
	g_iPropSupporter = GetConVarInt(g_hCvar[CVAR_SUPPORTER_PROPS]);
	g_iPropAdmin = GetConVarInt(g_hCvar[CVAR_ADMIN_PROPS]);

	g_iDeletePublic = GetConVarInt(g_hCvar[CVAR_PUBLIC_DELETES]);
	g_iDeleteSupporter = GetConVarInt(g_hCvar[CVAR_SUPPORTER_DELETES]);
	g_iDeleteAdmin = GetConVarInt(g_hCvar[CVAR_ADMIN_DELETES]);
	
	g_iTeleportPublic = GetConVarInt(g_hCvar[CVAR_PUBLIC_TELES]);
	g_iTeleportSupporter = GetConVarInt(g_hCvar[CVAR_SUPPORTER_TELES]);
	g_iTeleportAdmin = GetConVarInt(g_hCvar[CVAR_ADMIN_TELES]);
	g_fTeleportPublicDelay = GetConVarFloat(g_hCvar[CVAR_PUBLIC_DELAY]);
	g_fTeleportSupporterDelay = GetConVarFloat(g_hCvar[CVAR_SUPPORTER_DELAY]);
	g_fTeleportAdminDelay = GetConVarFloat(g_hCvar[CVAR_ADMIN_DELAY]);

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
	g_bAccessAdmin = GetConVarInt(g_hCvar[CVAR_ACCESS_ADMIN]) ? true : false;
	g_iBaseAccess = GetConVarInt(g_hCvar[CVAR_ACCESS_BASE]);

	g_fGrabDistance = GetConVarFloat(g_hCvar[CVAR_GRAB_DISTANCE]);
	g_fGrabUpdate = GetConVarFloat(g_hCvar[CVAR_GRAB_REFRESH]);
	g_fGrabMinimum = GetConVarFloat(g_hCvar[CVAR_GRAB_MINIMUM]);
	g_fGrabMaximum = GetConVarFloat(g_hCvar[CVAR_GRAB_MAXIMUM]);
	g_fGrabInterval = GetConVarFloat(g_hCvar[CVAR_GRAB_INTERVAL]);
	
	decl String:_sBuffer[256];
	g_bBaseEnabled = GetConVarInt(g_hCvar[CVAR_BASE_ENABLED]) ? true : false;
	GetConVarString(g_hCvar[CVAR_BASE_DATABASE], g_sBaseDatabase, sizeof(g_sBaseDatabase));
	g_fBaseDistance = GetConVarFloat(g_hCvar[CVAR_BASE_DISTANCE]);
	g_iBaseGroups = GetConVarInt(g_hCvar[CVAR_BASE_GROUPS]);
	GetConVarString(g_hCvar[CVAR_BASE_NAMES], _sBuffer, sizeof(_sBuffer));
	ExplodeString(_sBuffer, ", ", g_sBaseNames, 7, 32);
	g_iBaseLimit = GetConVarInt(g_hCvar[CVAR_BASE_LIMIT]);
}

public OnSettingsChange(Handle:cvar, const String:oldvalue[], const String:newvalue[])
{
	if(cvar == g_hCvar[CVAR_ENABLED])
	{
		g_bEnabled = bool:StringToInt(newvalue);
		if(g_bEnabled)
		{
			if(!StringToInt(oldvalue))
			{
				AddCustomTag();
				Define_Props();
				Define_Rotations();
				Define_Positions();
				Define_Colors();
				Define_Commands();
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
	else if(cvar == g_hCvar[CVAR_QUICK])
		g_bQuickMenu = StringToInt(newvalue) >= 0 ? true : false;
	else if(cvar == g_hCvar[CVAR_DISABLE])
	{
		g_iCurrentDisable = StringToInt(newvalue);
		if(g_iDisableDelay && g_iDisableDelay > g_iNumSeconds)
			g_bDisableFeatures = true;
		else
			g_bDisableFeatures = false;
	}
	else if(cvar == g_hCvar[CVAR_DISABLE_DELAY])
		g_iDisableDelay = StringToInt(newvalue);
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

	else if(cvar == g_hCvar[CVAR_PUBLIC_PROPS])
		g_iPropPublic = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_SUPPORTER_PROPS])
		g_iPropSupporter = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ADMIN_PROPS])
		g_iPropAdmin = StringToInt(newvalue);
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
		g_bHasAccess[TEAM_SPEC] = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ACCESS_RED])
		g_bHasAccess[TEAM_RED] = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ACCESS_BLUE])
		g_bHasAccess[TEAM_BLUE] = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ACCESS_CHECK])
		g_iCheckAccess = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ACCESS_GRAB])
		g_iControlAccess = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ACCESS_SETTINGS])
		g_bAccessSettings = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ACCESS_ADMIN])
		g_bAccessAdmin = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_ACCESS_BASE])
		g_iBaseAccess = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_GRAB_DISTANCE])
		g_fGrabDistance = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_GRAB_REFRESH])
		g_fGrabUpdate = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_GRAB_MINIMUM])
		g_fGrabMinimum = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_GRAB_MAXIMUM])
		g_fGrabMaximum = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_GRAB_INTERVAL])
		g_fGrabInterval = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_BASE_ENABLED])
		g_bBaseEnabled = bool:StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_BASE_DATABASE])
	{
		if(g_hSql_Database != INVALID_HANDLE && CloseHandle(g_hSql_Database))
			g_hSql_Database = INVALID_HANDLE;

		Format(g_sBaseDatabase, sizeof(g_sBaseDatabase), "%s", newvalue);
		SQL_TConnect(SQL_ConnectCall, StrEqual(g_sBaseDatabase, "") ? "storage-local" : g_sBaseDatabase);
	}
	else if(cvar == g_hCvar[CVAR_BASE_DISTANCE])
		g_fBaseDistance = StringToFloat(newvalue);
	else if(cvar == g_hCvar[CVAR_BASE_GROUPS])
		g_iBaseGroups = StringToInt(newvalue);
	else if(cvar == g_hCvar[CVAR_BASE_NAMES])
		ExplodeString(newvalue, ", ", g_sBaseNames, 7, 32);
	else if(cvar == g_hCvar[CVAR_BASE_LIMIT])
		g_iBaseLimit = StringToInt(newvalue);
}

AddCustomTag()
{
	decl String:_sBuffer[128];
	GetConVarString(g_hServerTags, _sBuffer, sizeof(_sBuffer));
	if(StrContains(_sBuffer, "buildwars", false) == -1)
	{
		Format(_sBuffer, sizeof(_sBuffer), "%s,buildwars", _sBuffer);
		SetConVarString(g_hServerTags, _sBuffer, true);	
	}
}

RemCustomTag()
{
	decl String:_sBuffer[128];
	GetConVarString(g_hServerTags, _sBuffer, sizeof(_sBuffer));
	if(StrContains(_sBuffer, "buildwars") != -1)
	{
		ReplaceString(_sBuffer, sizeof(_sBuffer), "buildwars", "", false);
		ReplaceString(_sBuffer, sizeof(_sBuffer), ",,", ",", false);
		SetConVarString(g_hServerTags, _sBuffer, true);	
	}
}

Menu_Main(client)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:_sBuffer[192];
	new Handle:_hMenu = CreateMenu(MenuHandler_Main);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuPagination(_hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(_hMenu, true);

	if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
	{
		if(g_iPropPublic != -1)
		{
			if(!g_iPropPublic)
				Format(_sBuffer, 192, "%T", "Menu_Spawn_Prop_Infinite", client);
			else
				Format(_sBuffer, 192, "%T", "Menu_Spawn_Prop_Limited", client, g_iPlayerProps[client], g_iPropPublic);

			AddMenuItem(_hMenu, "0", _sBuffer, Bool_SpawnValid(client, false) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		
		if(g_bRotationAllowed)
		{
			Format(_sBuffer, 192, "%T", "Menu_Rotate_Prop", client);
			AddMenuItem(_hMenu, "1", _sBuffer, Bool_RotateValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_bPositionAllowed)
		{
			Format(_sBuffer, 192, "%T", "Menu_Position_Prop", client);
			AddMenuItem(_hMenu, "2", _sBuffer, Bool_MoveValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		
		if(g_iDeletePublic != -1)
		{
			if(!g_iDeletePublic)
				Format(_sBuffer, 192, "%T", "Menu_Delete_Prop_Infinite", client);
			else
				Format(_sBuffer, 192, "%T", "Menu_Delete_Prop_Limited", client, g_iPlayerDeletes[client], g_iDeletePublic);

			AddMenuItem(_hMenu, "3", _sBuffer, Bool_DeleteValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		
		if(g_bControlAllowed && g_iControlAccess & ACCESS_PUBLIC)
		{
			Format(_sBuffer, 192, "%T", "Menu_Control_Prop", client);
			AddMenuItem(_hMenu, "4", _sBuffer, Bool_ControlValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_iCheckAccess & ACCESS_PUBLIC)
		{
			Format(_sBuffer, 192, "%T", "Menu_Check_Prop", client);
			AddMenuItem(_hMenu, "7", _sBuffer, Bool_CheckValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
	{
		if(g_iPropAdmin != -1)
		{
			if(!g_iPropAdmin)
				Format(_sBuffer, 192, "%T", "Menu_Spawn_Prop_Infinite", client);
			else
				Format(_sBuffer, 192, "%T", "Menu_Spawn_Prop_Limited", client, g_iPlayerProps[client], g_iPropAdmin);

			AddMenuItem(_hMenu, "0", _sBuffer, Bool_SpawnValid(client, false) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		
		if(g_bRotationAllowed)
		{
			Format(_sBuffer, 192, "%T", "Menu_Rotate_Prop", client);
			AddMenuItem(_hMenu, "1", _sBuffer);
		}

		if(g_bPositionAllowed)
		{
			Format(_sBuffer, 192, "%T", "Menu_Position_Prop", client);
			AddMenuItem(_hMenu, "2", _sBuffer);
		}
		
		if(g_iDeleteAdmin != -1)
		{
			if(!g_iDeleteAdmin)
				Format(_sBuffer, 192, "%T", "Menu_Delete_Prop_Infinite", client);
			else
				Format(_sBuffer, 192, "%T", "Menu_Delete_Prop_Limited", client, g_iPlayerDeletes[client], g_iDeleteAdmin);

			AddMenuItem(_hMenu, "3", _sBuffer);
		}
		
		if(g_bControlAllowed && g_iControlAccess & ACCESS_ADMIN)
		{
			Format(_sBuffer, 192, "%T", "Menu_Control_Prop", client);	
			AddMenuItem(_hMenu, "4", _sBuffer);
		}
		
		if(g_iCheckAccess & ACCESS_ADMIN)
		{
			Format(_sBuffer, 192, "%T", "Menu_Check_Prop", client);
			AddMenuItem(_hMenu, "7", _sBuffer);
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
	{
		if(g_iPropSupporter != -1)
		{
			if(!g_iPropSupporter)
				Format(_sBuffer, 192, "%T", "Menu_Spawn_Prop_Infinite", client);
			else
				Format(_sBuffer, 192, "%T", "Menu_Spawn_Prop_Limited", client, g_iPlayerProps[client], g_iPropSupporter);

			AddMenuItem(_hMenu, "0", _sBuffer, Bool_SpawnValid(client, false) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		
		if(g_bRotationAllowed)
		{
			Format(_sBuffer, 192, "%T", "Menu_Rotate_Prop", client);
			AddMenuItem(_hMenu, "1", _sBuffer, Bool_RotateValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_bPositionAllowed)
		{
			Format(_sBuffer, 192, "%T", "Menu_Position_Prop", client);
			AddMenuItem(_hMenu, "2", _sBuffer, Bool_MoveValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		
		if(g_iDeleteSupporter != -1)
		{
			if(!g_iDeleteSupporter)
				Format(_sBuffer, 192, "%T", "Menu_Delete_Prop_Infinite", client);
			else
				Format(_sBuffer, 192, "%T", "Menu_Delete_Prop_Limited", client, g_iPlayerDeletes[client], g_iDeleteSupporter);

			AddMenuItem(_hMenu, "3", _sBuffer, Bool_DeleteValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		
		if(g_bControlAllowed && g_iControlAccess & ACCESS_SUPPORTER)
		{
			Format(_sBuffer, 192, "%T", "Menu_Control_Prop", client);
			AddMenuItem(_hMenu, "4", _sBuffer, Bool_ControlValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		
		if(g_iCheckAccess & ACCESS_SUPPORTER)
		{
			Format(_sBuffer, 192, "%T", "Menu_Check_Prop", client);
			AddMenuItem(_hMenu, "7", _sBuffer, Bool_CheckValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
	}

	if(g_bBaseEnabled && (g_iPlayerAccess[client] & g_iBaseAccess || g_iPlayerAccess[client] & ACCESS_BASE))
	{
		if(g_hSql_Database != INVALID_HANDLE)
		{
			Format(_sBuffer, 192, "%T", "Menu_Base_Actions", client);
			AddMenuItem(_hMenu, "8", _sBuffer);
		}
	}

	if(g_bAccessSettings)
	{
		Format(_sBuffer, 192, "%T", "Menu_Player_Actions", client);
		AddMenuItem(_hMenu, "5", _sBuffer);
	}	

	if(g_bAccessAdmin && (g_iAdminAccess[client] & ADMIN_DELETE || g_iAdminAccess[client] & ADMIN_TELEPORT || g_iAdminAccess[client] & ADMIN_COLOR))
	{
		Format(_sBuffer, 192, "%T", "Menu_Admin_Actions", client);
		AddMenuItem(_hMenu, "6", _sBuffer);
	}

	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Main(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Select:
		{
			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			if(!g_bHasAccess[g_iTeam[param1]])
				return;
			
			switch(StringToInt(_sOption))
			{
				case 0:
				{
					if(Bool_SpawnValid(param1, true, MENU_MAIN))
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
				case 8:
				{
					QueryBuildMenu(param1, MENU_BASE_MAIN);
				}
			}
		}
	}
}

Menu_Create(client, index = 0)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;
				
	decl String:_sTemp[4];
	new Handle:_hMenu = CreateMenu(MenuHandler_CreateMenu);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	for(new i = 0; i < g_iNumProps; i++)
	{
		if(g_iDefinedPropAccess[i] & g_iPlayerAccess[client])
		{
			Format(_sTemp, 4, "%d", i);
			AddMenuItem(_hMenu, _sTemp, g_sDefinedPropNames[i]);
		}
	}

	DisplayMenuAtItem(_hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_CreateMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
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
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			Void_SpawnProp(param1, StringToInt(_sOption), GetMenuSelectionPosition());
		}
	}
}

Void_SpawnProp(client, type, slot)
{
	if(Bool_SpawnAllowed(client, true) && Bool_SpawnValid(client, true, MENU_MAIN))
	{
		decl Float:_fOrigin[3], Float:_fAngles[3], Float:_fNormal[3];
		GetClientEyePosition(client, _fOrigin);
		GetClientEyeAngles(client, _fAngles);
		TR_TraceRayFilter(_fOrigin, _fAngles, MASK_SOLID, RayType_Infinite, Tracer_FilterBlocks, client);
		if(TR_DidHit(INVALID_HANDLE))
		{
			_fAngles[0] = 0.0;
			_fAngles[1] += 90.0;
			TR_GetEndPosition(_fOrigin, INVALID_HANDLE);
			TR_GetPlaneNormal(INVALID_HANDLE, _fNormal);
			decl Float:_fVectorAngles[3];
			GetVectorAngles(_fNormal, _fVectorAngles);
			_fVectorAngles[0] += 90.0;
			decl Float:_fCross[3], Float:_fTempAngles[3], Float:_fTempAngles2[3];
			GetAngleVectors(_fAngles, _fTempAngles, NULL_VECTOR, NULL_VECTOR);
			_fTempAngles[2] = 0.0;
			GetAngleVectors(_fVectorAngles, _fTempAngles2, NULL_VECTOR, NULL_VECTOR);
			GetVectorCrossProduct( _fTempAngles, _fNormal, _fCross );
			new Float:_fYaw = GetAngleBetweenVectors(_fTempAngles2, _fCross, _fNormal);
			RotateYaw(_fVectorAngles, _fYaw);
			for(new i = 0; i <= 2; i++)
				_fVectorAngles[i] = float(RoundToNearest(_fVectorAngles[i] / g_fDefinedRotations[g_iConfigRotation[client]])) * g_fDefinedRotations[g_iConfigRotation[client]];
			
			new entity = Entity_SpawnProp(client, type, _fOrigin, _fVectorAngles);
			PushArrayCell(g_hArray_PlayerProps[client], entity);
			g_iPlayerProps[client]++;

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

		Menu_Create(client, slot);
		return;
	}
}

Void_SpawnClone(client, entity)
{
	if(Bool_SpawnAllowed(client, true) && Bool_SpawnValid(client, true))
	{
		decl Float:_fOrigin[3], Float:_fRotation[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", _fOrigin);
		GetEntPropVector(entity, Prop_Data, "m_angRotation", _fRotation);
		new _iType = g_iPropType[entity];
		new _iEnt = Entity_SpawnProp(client, _iType, _fOrigin, _fRotation);
		PushArrayCell(g_hArray_PlayerProps[client], _iEnt);
		g_iPlayerProps[client]++;

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

Void_SpawnChat(client, type)
{
	decl Float:_fOrigin[3], Float:_fAngles[3], Float:_fNormal[3];
	GetClientEyePosition(client, _fOrigin);
	GetClientEyeAngles(client, _fAngles);
	TR_TraceRayFilter(_fOrigin, _fAngles, MASK_SOLID, RayType_Infinite, Tracer_FilterBlocks, client);
	if(TR_DidHit(INVALID_HANDLE))
	{
		_fAngles[0] = 0.0;
		_fAngles[1] += 90.0;
		TR_GetEndPosition(_fOrigin, INVALID_HANDLE);
		TR_GetPlaneNormal(INVALID_HANDLE, _fNormal);
		decl Float:_fVectorAngles[3];
		GetVectorAngles(_fNormal, _fVectorAngles);
		_fVectorAngles[0] += 90.0;
		decl Float:_fCross[3], Float:_fTempAngles[3], Float:_fTempAngles2[3];
		GetAngleVectors(_fAngles, _fTempAngles, NULL_VECTOR, NULL_VECTOR);
		_fTempAngles[2] = 0.0;
		GetAngleVectors(_fVectorAngles, _fTempAngles2, NULL_VECTOR, NULL_VECTOR);
		GetVectorCrossProduct( _fTempAngles, _fNormal, _fCross );
		new Float:_fYaw = GetAngleBetweenVectors(_fTempAngles2, _fCross, _fNormal);
		RotateYaw(_fVectorAngles, _fYaw);
		for(new i = 0; i <= 2; i++)
			_fVectorAngles[i] = float(RoundToNearest(_fVectorAngles[i] / g_fDefinedRotations[g_iConfigRotation[client]])) * g_fDefinedRotations[g_iConfigRotation[client]];
		
		new entity = Entity_SpawnProp(client, type, _fOrigin, _fVectorAngles);
		PushArrayCell(g_hArray_PlayerProps[client], entity);
		g_iPlayerProps[client]++;

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
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:_sBuffer[192];
	new Handle:_hMenu = CreateMenu(MenuHandler_ModifyRotation);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuPagination(_hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	if(entity)
	{
		decl Float:_fAngles[3];
		GetEntPropVector(entity, Prop_Data, "m_angRotation", _fAngles);

		Format(_sBuffer, 192, "%T", "Menu_Rotation_Info", client, _fAngles[0], _fAngles[1], _fAngles[2]);
		AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
	}
	else
	{
		Format(_sBuffer, 192, "%T", "Menu_Rotation_Info_Missing", client);
		AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
	}
	
	new _iState = Bool_RotateValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
	Format(_sBuffer, 192, "%T", "Menu_Rotation_X_Plus", client, g_fDefinedRotations[g_iConfigRotation[client]]);
	AddMenuItem(_hMenu, "1", _sBuffer, _iState);
	Format(_sBuffer, 192, "%T", "Menu_Rotation_X_Minus", client, g_fDefinedRotations[g_iConfigRotation[client]]);
	AddMenuItem(_hMenu, "2", _sBuffer, _iState);
	Format(_sBuffer, 192, "%T", "Menu_Rotation_Y_Plus", client, g_fDefinedRotations[g_iConfigRotation[client]]);
	AddMenuItem(_hMenu, "3", _sBuffer, _iState);
	Format(_sBuffer, 192, "%T", "Menu_Rotation_Y_Minus", client, g_fDefinedRotations[g_iConfigRotation[client]]);
	AddMenuItem(_hMenu, "4", _sBuffer, _iState);
	Format(_sBuffer, 192, "%T", "Menu_Rotation_Z_Plus", client, g_fDefinedRotations[g_iConfigRotation[client]]);
	AddMenuItem(_hMenu, "5", _sBuffer, _iState);
	Format(_sBuffer, 192, "%T", "Menu_Rotation_Z_Minus", client, g_fDefinedRotations[g_iConfigRotation[client]]);
	AddMenuItem(_hMenu, "6", _sBuffer, _iState);
	Format(_sBuffer, 192, "%T", "Menu_Rotation_Reset", client);
	AddMenuItem(_hMenu, "7", _sBuffer);
	Format(_sBuffer, 192, "%T", "Menu_Rotation_Default", client);
	AddMenuItem(_hMenu, "0", _sBuffer);
		
	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_ModifyRotation(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
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
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

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
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:_sBuffer[192], String:_sTemp[4];

	new Handle:_hMenu = CreateMenu(MenuHandler_DefaultRotation);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	for(new i = 0; i < g_iNumRotations; i++)
	{
		IntToString(i, _sTemp, 4);
		Format(_sBuffer, 192, "%s%T", (g_iConfigRotation[client] == i) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Rotation_Option", client, g_fDefinedRotations[i]);
		AddMenuItem(_hMenu, _sTemp, _sBuffer);
	}

	DisplayMenuAtItem(_hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_DefaultRotation(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
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
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

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
	if(!g_bHasAccess[g_iTeam[client]])
		return;
		
	decl String:_sBuffer[192];
	new Handle:_hMenu = CreateMenu(MenuHandler_ModifyPosition);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuPagination(_hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	if(entity)
	{
		decl Float:_fOrigin[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", _fOrigin);

		Format(_sBuffer, 192, "%T", "Menu_Position_Info", client, _fOrigin[0], _fOrigin[1], _fOrigin[2]);
		AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
	}
	else
	{
		Format(_sBuffer, 192, "%T", "Menu_Position_Info_Missing", client);
		AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
	}

	new _iState = Bool_MoveValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
	Format(_sBuffer, 192, "%T", "Menu_Position_X_Plus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(_hMenu, "1", _sBuffer, _iState);
	Format(_sBuffer, 192, "%T", "Menu_Position_X_Minus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(_hMenu, "2", _sBuffer, _iState);
	Format(_sBuffer, 192, "%T", "Menu_Position_Y_Plus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(_hMenu, "3", _sBuffer, _iState);
	Format(_sBuffer, 192, "%T", "Menu_Position_Y_Minus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(_hMenu, "4", _sBuffer, _iState);
	Format(_sBuffer, 192, "%T", "Menu_Position_Z_Plus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(_hMenu, "5", _sBuffer, _iState);
	Format(_sBuffer, 192, "%T", "Menu_Position_Z_Minus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(_hMenu, "6", _sBuffer, _iState);
	Format(_sBuffer, 192, "%T", "Menu_Position_Default", client);
	AddMenuItem(_hMenu, "0", _sBuffer);

	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_ModifyPosition(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
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
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

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
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:_sBuffer[192], String:_sTemp[4];
	new Handle:_hMenu = CreateMenu(MenuHandler_DefaultPosition);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	for(new i = 0; i < g_iNumPositions; i++)
	{
		IntToString(i, _sTemp, 4);
		Format(_sBuffer, 192, "%s%T", (g_iConfigPosition[client] == i) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Action_Position_Option", client, g_fDefinedPositions[i]);
		AddMenuItem(_hMenu, _sTemp, _sBuffer);
	}

	DisplayMenuAtItem(_hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_DefaultPosition(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
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
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

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
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:_sBuffer[192];
	new Handle:_hMenu = CreateMenu(MenuHandler_Grab);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuPagination(_hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	if(g_iPlayerControl[client] > 0)
		Format(_sBuffer, 192, "%T", "Menu_Control_Release", client);
	else
		Format(_sBuffer, 192, "%T", "Menu_Control_Issue", client);
	AddMenuItem(_hMenu, "0", _sBuffer, Bool_ControlValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	Format(_sBuffer, 192, "%T", "Menu_Control_Increase", client);
	AddMenuItem(_hMenu, "1", _sBuffer);

	Format(_sBuffer, 192, "%T", "Menu_Control_Decrease", client);
	AddMenuItem(_hMenu, "2", _sBuffer);

	if(g_iPlayerControl[client] > 0)
		Format(_sBuffer, 192, "%T", "Menu_Control_Clone", client, g_sDefinedPropNames[g_iPropType[g_iPlayerControl[client]]]);
	else
		Format(_sBuffer, 192, "%T", "Menu_Control_Empty", client);
	AddMenuItem(_hMenu, "3", _sBuffer, (g_iPlayerControl[client] > 0 && Bool_SpawnValid(client, false)) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	if(g_bRotationAllowed)
	{
		Format(_sBuffer, 192, "%s%T", (g_bConfigAxis[client][ROTATION_AXIS_X]) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Control_Rotation_Lock_X", client);
		AddMenuItem(_hMenu, "4", _sBuffer);

		Format(_sBuffer, 192, "%s%T", (g_bConfigAxis[client][ROTATION_AXIS_Y]) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Control_Rotation_Lock_Y", client);
		AddMenuItem(_hMenu, "5", _sBuffer);
	}
	
	if(g_bPositionAllowed)
	{
		Format(_sBuffer, 192, "%s%T", (g_bConfigAxis[client][POSITION_AXIS_X]) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Control_Position_Lock_X", client);
		AddMenuItem(_hMenu, "6", _sBuffer);

		Format(_sBuffer, 192, "%s%T", (g_bConfigAxis[client][POSITION_AXIS_Y]) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Control_Position_Lock_Y", client);
		AddMenuItem(_hMenu, "7", _sBuffer);
		
		Format(_sBuffer, 192, "%s%T", (g_bConfigAxis[client][POSITION_AXIS_Z]) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Control_Position_Lock_Z", client);
		AddMenuItem(_hMenu, "8", _sBuffer);
	}

	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Grab(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
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
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

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
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:_sBuffer[192];
	
	new Handle:_hMenu = CreateMenu(MenuHandler_PlayerActions);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	if(g_iPlayerAccess[client] == ACCESS_PUBLIC)
	{
		if(g_iColorPublic != -1 && !g_iColoringPublic && g_bColorAllowed)
		{
			if(!g_iColorPublic)
				Format(_sBuffer, 192, "%T", "Menu_Action_Color_Infinite", client);
			else
				Format(_sBuffer, 192, "%T", "Menu_Action_Color_Limited", client, g_iPlayerColors[client], g_iColorPublic);
			AddMenuItem(_hMenu, "1", _sBuffer, Bool_ColorValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_iTeleportPublic != -1)
		{
			if(!g_iTeleportPublic)
				Format(_sBuffer, 192, "%T", "Menu_Action_Teleport_Infinite", client);
			else
				Format(_sBuffer, 192, "%T", "Menu_Action_Teleport_Limited", client, g_iPlayerTeleports[client], g_iTeleportPublic);
			AddMenuItem(_hMenu, "2", _sBuffer, Bool_TeleportValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		
		if(g_iDeletePublic != -1)
		{
			Format(_sBuffer, 192, "%T", "Menu_Action_Delete", client);
			AddMenuItem(_hMenu, "3", _sBuffer, Bool_ClearValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_ADMIN)
	{
		if(g_iColorAdmin != -1 && !g_iColoringAdmin && g_bColorAllowed)
		{
			if(!g_iColorAdmin)
				Format(_sBuffer, 192, "%T", "Menu_Action_Color_Infinite", client);
			else
				Format(_sBuffer, 192, "%T", "Menu_Action_Color_Limited", client, g_iPlayerColors[client], g_iColorAdmin);
			AddMenuItem(_hMenu, "1", _sBuffer);
		}

		if(g_iTeleportAdmin != -1)
		{
			if(!g_iTeleportAdmin)
				Format(_sBuffer, 192, "%T", "Menu_Action_Teleport_Infinite", client);
			else
				Format(_sBuffer, 192, "%T", "Menu_Action_Teleport_Limited", client, g_iPlayerTeleports[client], g_iTeleportAdmin);
			AddMenuItem(_hMenu, "2", _sBuffer);
		}

		if(g_iDeleteAdmin != -1)
		{
			Format(_sBuffer, 192, "%T", "Menu_Action_Delete", client);
			AddMenuItem(_hMenu, "3", _sBuffer);
		}
	}
	else if(g_iPlayerAccess[client] & ACCESS_SUPPORTER)
	{
		if(g_iColorSupporter != -1 && !g_iColoringSupporter && g_bColorAllowed)
		{
			if(!g_iColorSupporter)
				Format(_sBuffer, 192, "%T", "Menu_Action_Color_Infinite", client);
			else
				Format(_sBuffer, 192, "%T", "Menu_Action_Color_Limited", client, g_iPlayerColors[client], g_iColorSupporter);
			AddMenuItem(_hMenu, "1", _sBuffer, Bool_ColorValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_iTeleportSupporter != -1)
		{
			if(!g_iTeleportSupporter)
				Format(_sBuffer, 192, "%T", "Menu_Action_Teleport_Infinite", client);
			else
				Format(_sBuffer, 192, "%T", "Menu_Action_Teleport_Limited", client, g_iPlayerTeleports[client], g_iTeleportSupporter);
			AddMenuItem(_hMenu, "2", _sBuffer, Bool_TeleportValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(g_iDeleteSupporter != -1)
		{
			Format(_sBuffer, 192, "%T", "Menu_Action_Delete", client);
			AddMenuItem(_hMenu, "3", _sBuffer, Bool_ClearValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
	}
	
	Format(_sBuffer, 192, "%T", "Menu_Rotation_Default", client);
	AddMenuItem(_hMenu, "4", _sBuffer);

	Format(_sBuffer, 192, "%T", "Menu_Position_Default", client);
	AddMenuItem(_hMenu, "5", _sBuffer);

	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_PlayerActions(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
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
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

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
			}
		}
	}
}

Menu_DefaultColors(client, index = 0)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:_sTemp[4], String:_sBuffer[192];

	new Handle:_hMenu = CreateMenu(MenuHandler_DefaultColors);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	for(new i = 0; i < g_iNumColors; i++)
	{
		IntToString(i, _sTemp, 4);
		Format(_sBuffer, 192, "%s%s", (g_iConfigColor[client] == i) ? g_sPrefixSelect : g_sPrefixEmpty, g_sDefinedColorNames[i]);
		AddMenuItem(_hMenu, _sTemp, _sBuffer);
	}

	DisplayMenuAtItem(_hMenu, client, index, MENU_TIME_FOREVER);
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
				Menu_PlayerActions(param1);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			g_iConfigColor[param1] = StringToInt(_sOption);
			SetClientCookie(param1, g_cConfigColor, _sOption);

			CPrintToChat(param1, "%s%t", g_sPrefixChat, "Settings_Color", g_sDefinedColorNames[g_iConfigColor[param1]]);
			if(!g_bEnding)
			{
				if((g_iPlayerAccess[param1] & ACCESS_ADMIN) || !(g_bDisableFeatures && g_iCurrentDisable & DISABLE_COLOR))
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
			}

			Menu_DefaultColors(param1, GetMenuSelectionPosition());
		}
	}
}

Menu_ConfirmTeleport(client)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:_sBuffer[192];
	new Handle:_hMenu = CreateMenu(MenuHandler_ConfirmTeleport);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	Format(_sBuffer, 192, "%T", "Menu_Action_Confirm_Teleport_Ask", client);
	AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
	Format(_sBuffer, 192, "%T", "Menu_Action_Confirm_Teleport_Yes", client);
	AddMenuItem(_hMenu, "1", _sBuffer);
	Format(_sBuffer, 192, "%T", "Menu_Action_Confirm_Teleport_No", client);
	AddMenuItem(_hMenu, "0", _sBuffer);
	
	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
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
				Menu_PlayerActions(param1);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

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
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:_sBuffer[192];
	new Handle:_hMenu = CreateMenu(MenuHandler_ConfirmDelete);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	Format(_sBuffer, 192, "%T", "Menu_Action_Confirm_Delete_Ask", client);
	AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
	Format(_sBuffer, 192, "%T", "Menu_Action_Confirm_Delete_Yes", client);
	AddMenuItem(_hMenu, "1", _sBuffer);
	Format(_sBuffer, 192, "%T", "Menu_Action_Confirm_Delete_No", client);
	AddMenuItem(_hMenu, "0", _sBuffer);
	
	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_ConfirmDelete(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
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
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);

			if(StringToInt(_sOption) && Bool_ClearValid(param1, true, MENU_ACTION))
				Bool_ClearClientProps(param1, true, true);
			else
				Menu_PlayerActions(param1);
		}
	}
}

Menu_Admin(client)
{
	decl String:_sBuffer[192];
	new _iOptions, Handle:_hMenu = CreateMenu(MenuHandler_Admin);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	if(g_iAdminAccess[client] & ADMIN_DELETE)
	{
		_iOptions++;
		Format(_sBuffer, 192, "%T", "Menu_Admin_Delete", client);
		AddMenuItem(_hMenu, "0", _sBuffer);
	}
	
	if(g_iAdminAccess[client] & ADMIN_TELEPORT)
	{
		_iOptions++;
		Format(_sBuffer, 192, "%T", "Menu_Admin_Teleport", client);
		AddMenuItem(_hMenu, "1", _sBuffer);
	}

	if(g_iAdminAccess[client] & ADMIN_COLOR)
	{
		_iOptions++;
		Format(_sBuffer, 192, "%T", "Menu_Admin_Color", client);
		AddMenuItem(_hMenu, "2", _sBuffer);
	}

	if(_iOptions)
		DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
		
	return _iOptions;
}

public MenuHandler_Admin(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
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

			Menu_AdminSelect(param1, StringToInt(_sOption));
		}
	}
}

Menu_AdminSelect(client, action)
{
	decl String:_sBuffer[192], String:_sTemp[16];
	new Handle:_hMenu = CreateMenu(MenuHandler_AdminSelect);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	Format(_sBuffer, 192, "%T", "Menu_Admin_Select_Single", client);
	Format(_sTemp, 16, "%d %d", action, TARGET_SINGLE);
	AddMenuItem(_hMenu, _sTemp, _sBuffer);
	
	if(g_iAdminAccess[client] & ADMIN_TARGET)
	{
		Format(_sBuffer, 192, "%T", "Menu_Admin_Select_Red", client);
		Format(_sTemp, 16, "%d %d", action, TARGET_RED);
		AddMenuItem(_hMenu, _sTemp, _sBuffer);
		
		Format(_sBuffer, 192, "%T", "Menu_Admin_Select_Blue", client);
		Format(_sTemp, 16, "%d %d", action, TARGET_BLUE);
		AddMenuItem(_hMenu, _sTemp, _sBuffer);

		Format(_sBuffer, 192, "%T", "Menu_Admin_Select_Mass", client);
		Format(_sTemp, 16, "%d %d", action, TARGET_ALL);
		AddMenuItem(_hMenu, _sTemp, _sBuffer);
	}

	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminSelect(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
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
				if(IsClientInGame(i) && g_iPlayerProps[i] > 0 && g_bHasAccess[g_iTeam[i]])
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
				if(IsClientInGame(i) && g_iPlayerProps[i] > 0 && g_bHasAccess[g_iTeam[i]])
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
	switch(action)
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
	decl String:_sBuffer[192], String:_sTemp[36];

	new Handle:_hMenu = CreateMenu(MenuHandler_AdminConfirmDelete);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);
	
	switch(group)
	{
		case TARGET_SINGLE:
		{
			Format(_sBuffer, 192, "%T", "Menu_Admin_Confirm_Delete_Single", client, g_sName[GetClientOfUserId(target)]);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_RED:
		{
			Format(_sBuffer, 192, "%T", "Menu_Admin_Confirm_Delete_Red", client);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}		
		case TARGET_BLUE:
		{
			Format(_sBuffer, 192, "%T", "Menu_Admin_Confirm_Delete_Blue", client);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}		
		case TARGET_ALL:
		{
			Format(_sBuffer, 192, "%T", "Menu_Admin_Confirm_Delete_Mass", client);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}		
	}

	Format(_sBuffer, 192, "%T", "Menu_Admin_Confirm_Delete_No", client);
	Format(_sTemp, 36, "0 %d %d", group, target);
	AddMenuItem(_hMenu, _sTemp, _sBuffer);

	Format(_sBuffer, 192, "%T", "Menu_Admin_Confirm_Delete_Yes", client);
	Format(_sTemp, 36, "1 %d %d",  group, target);
	AddMenuItem(_hMenu, _sTemp, _sBuffer);
	
	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminConfirmDelete(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
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
	decl String:_sBuffer[192], String:_sTemp[36];

	new Handle:_hMenu = CreateMenu(MenuHandler_AdminConfirmTele);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);
	
	switch(group)
	{
		case TARGET_SINGLE:
		{
			Format(_sBuffer, 192, "%T", "Menu_Admin_Confirm_Teleport_Single", client, g_sName[GetClientOfUserId(target)]);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_RED:
		{
			Format(_sBuffer, 192, "%T", "Menu_Admin_Confirm_Teleport_Red", client);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}		
		case TARGET_BLUE:
		{
			Format(_sBuffer, 192, "%T", "Menu_Admin_Confirm_Teleport_Blue", client);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}		
		case TARGET_ALL:
		{
			Format(_sBuffer, 192, "%T", "Menu_Admin_Confirm_Teleport_Mass", client);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}		
	}

	Format(_sBuffer, 192, "%T", "Menu_Admin_Confirm_Teleport_No", client);
	Format(_sTemp, 36, "0 %d %d", group, target);
	AddMenuItem(_hMenu, _sTemp, _sBuffer);

	Format(_sBuffer, 192, "%T", "Menu_Admin_Confirm_Teleport_Yes", client);
	Format(_sTemp, 36, "1 %d %d",  group, target);
	AddMenuItem(_hMenu, _sTemp, _sBuffer);
	
	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminConfirmTele(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
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
	switch(action)
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
	decl String:_sBuffer[192], String:_sTemp[40];

	new Handle:_hMenu = CreateMenu(MenuHandler_AdminConfirmColor);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);
	
	switch(group)
	{
		case TARGET_SINGLE:
		{
			Format(_sBuffer, 192, "%T", "Menu_Admin_Confirm_Color_Single", client, g_sName[GetClientOfUserId(target)]);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}
		case TARGET_RED:
		{
			Format(_sBuffer, 192, "%T", "Menu_Admin_Confirm_Color_Red", client);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}		
		case TARGET_BLUE:
		{
			Format(_sBuffer, 192, "%T", "Menu_Admin_Confirm_Color_Blue", client);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}		
		case TARGET_ALL:
		{
			Format(_sBuffer, 192, "%T", "Menu_Admin_Confirm_Color_Mass", client);
			AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		}		
	}

	Format(_sBuffer, 192, "%T", "Menu_Admin_Confirm_Color_No", client);
	Format(_sTemp, 40, "0 %d %d %d", group, color, target);
	AddMenuItem(_hMenu, _sTemp, _sBuffer);

	Format(_sBuffer, 192, "%T", "Menu_Admin_Confirm_Color_Yes", client);
	Format(_sTemp, 40, "1 %d %d %d",  group, color, target);
	AddMenuItem(_hMenu, _sTemp, _sBuffer);
	
	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AdminConfirmColor(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
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
	GetClientCookie(client, g_cConfigVersion, _sTemp, 32);

	if(StrEqual(_sTemp, "", false))
	{
		SetClientCookie(client, g_cConfigVersion, PLUGIN_VERSION);
		
		g_iConfigRotation[client] = g_iDefaultRotation;
		IntToString(g_iConfigRotation[client], _sCookie, 4);
		SetClientCookie(client, g_cConfigRotation, _sCookie);

		g_iConfigPosition[client] = g_iDefaultPosition;
		IntToString(g_iConfigPosition[client], _sCookie, 4);
		SetClientCookie(client, g_cConfigPosition, _sCookie);

		g_iConfigColor[client] = g_iDefaultColor;
		IntToString(g_iConfigColor[client], _sCookie, 4);
		SetClientCookie(client, g_cConfigColor, _sCookie);

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


public Action:Command_Reset(client, args)
{
	if(g_bEnabled)
	{
		if(!g_bEnding && (!client || (IsClientInGame(client) && !(g_iAdminAccess[client] & ADMIN_DELETE))))
		{
			if(args)
			{
				decl String:_sBuffer[64];
				GetCmdArg(1, _sBuffer, sizeof(_sBuffer));
				new _iTarget = FindTarget(client, _sBuffer, false, true);

				if(_iTarget > 0)
					Bool_ClearClientProps(_iTarget, false);
			}
			else
			{
				for(new i = 1; i <= MaxClients; i++)
					if(IsClientInGame(i))
						Bool_ClearClientProps(i, false);
			}
		}
	}
	
	return Plugin_Handled;
}

Void_AuthClient(client)
{
	g_iPlayerAccess[client] = ACCESS_PUBLIC;
	if(CheckCommandAccess(client, "bw_access_supporter", AUTH_SUPPORTER))
		g_iPlayerAccess[client] += ACCESS_SUPPORTER;
	
	if(CheckCommandAccess(client, "bw_access_admin", AUTH_ADMIN))
		g_iPlayerAccess[client] += ACCESS_ADMIN;

	if(CheckCommandAccess(client, "bw_access_base", AUTH_BASE))
		g_iPlayerAccess[client] += ACCESS_BASE;
	
	g_iAdminAccess[client] = ADMIN_NONE;
	if(CheckCommandAccess(client, "bw_admin_delete", AUTH_DELETE))
		g_iAdminAccess[client] += ADMIN_DELETE;
	
	if(CheckCommandAccess(client, "bw_admin_teleport", AUTH_TELEPORT))
		g_iAdminAccess[client] += ADMIN_TELEPORT;
	
	if(CheckCommandAccess(client, "bw_admin_color", AUTH_COLOR))
		g_iAdminAccess[client] += ADMIN_COLOR;
	
	if(CheckCommandAccess(client, "bw_admin_target", AUTH_TARGET))
		g_iAdminAccess[client] += ADMIN_TARGET;
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
		case MENU_BASE_MAIN:
		{
			Menu_BaseActions(client);
		}
		case MENU_BASE_CURRENT:
		{
			if(_iSlot == -1)
				_iSlot = g_iPlayerBaseCurrent[client];

			Menu_BaseCurrent(client, _iSlot);
		}
		case MENU_BASE_MOVE:
		{
			Menu_BaseMove(client);
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
		if(g_bEnding || !g_bAlive[client])
		{
			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_bDisableFeatures && g_iCurrentDisable & DISABLE_DELETE)
		{
			if(_bMessage)
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Delete_Prop_Restricted");

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
		if(g_bEnding || !g_bAlive[client])
		{
			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_bDisableFeatures && g_iCurrentDisable & DISABLE_CLEAR)
		{
			if(_bMessage)
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Clear_Prop_Restricted");

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

bool:Bool_SpawnValid(client, bool:_bMessage = false, _iReturn = 0, _iSlot = 0)
{
	if(!(g_iPlayerAccess[client] & ACCESS_ADMIN))
	{
		if(g_bEnding || !g_bAlive[client])
		{
			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_bDisableFeatures && g_iCurrentDisable & DISABLE_SPAWN)
		{
			if(_bMessage)
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Spawn_Prop_Restricted");

			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);
			
			return false;
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
		if(g_bEnding || !g_bAlive[client])
		{
			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_bDisableFeatures && g_iCurrentDisable & DISABLE_ROTATE)
		{
			if(_bMessage)
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Rotate_Prop_Restricted");

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
		if(g_bEnding || !g_bAlive[client])
		{
			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_bDisableFeatures && g_iCurrentDisable & DISABLE_MOVE)
		{
			if(_bMessage)
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Position_Prop_Restricted");

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
		if(g_bEnding || !g_bAlive[client])
		{
			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_bDisableFeatures && g_iCurrentDisable & DISABLE_CONTROL)
		{
			if(_bMessage)
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Control_Prop_Restricted");

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
		if(g_bEnding || !g_bAlive[client])
		{
			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_bDisableFeatures && g_iCurrentDisable & DISABLE_CHECK)
		{
			if(_bMessage)
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Check_Prop_Restricted");

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
		if(g_bEnding || !g_bAlive[client])
		{
			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);

			return false;
		}
		else if(g_bDisableFeatures && g_iCurrentDisable & DISABLE_TELE)
		{
			if(_bMessage)
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Teleport_Restricted");

			if(_iReturn)
				Void_ReturnToMenu(client, _iReturn, _iSlot);
			
			return false;
		}
	}
	
	return true;
}

bool:Bool_ColorValid(client, bool:_bMessage = false, _iReturn = 0, _iSlot = 0)
{
	if(g_bEnding || !g_bAlive[client])
	{
		if(_iReturn)
			Void_ReturnToMenu(client, _iReturn, _iSlot);

		return false;
	}
	else if(g_bDisableFeatures && g_iCurrentDisable & DISABLE_COLOR)
	{
		if(_bMessage)
			CPrintToChat(client, "%s%t", g_sPrefixChat, "Color_Prop_Restricted");

		if(_iReturn)
			Void_ReturnToMenu(client, _iReturn, _iSlot);
		
		return false;
	}
	
	return true;
}

Define_Props()
{
	decl String:_sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, _sPath, PLATFORM_MAX_PATH, "configs/buildwars/sm_buildwars_props.ini");
	
	new _iCurrent = GetFileTime(_sPath, FileTime_LastChange);
	if(_iCurrent < g_iLoadProps)
		return;
	else
		g_iLoadProps = _iCurrent;

	g_iNumProps = 0;
	new Handle:_hKV = CreateKeyValues("BuildWars_Props");
	if(FileToKeyValues(_hKV, _sPath))
	{
		KvGotoFirstSubKey(_hKV);
		do
		{
			KvGetSectionName(_hKV, g_sDefinedPropNames[g_iNumProps], 64);
			KvGetString(_hKV, "path", g_sDefinedPropPaths[g_iNumProps], PLATFORM_MAX_PATH);
			PrecacheModel(g_sDefinedPropPaths[g_iNumProps]);

			g_iDefinedPropTypes[g_iNumProps] = KvGetNum(_hKV, "type");
			g_iDefinedPropAccess[g_iNumProps] = KvGetNum(_hKV, "access");
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
	decl String:_sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, _sPath, PLATFORM_MAX_PATH, "configs/buildwars/sm_buildwars_colors.ini");

	new _iCurrent = GetFileTime(_sPath, FileTime_LastChange);
	if(_iCurrent < g_iLoadColors)
		return;
	else
		g_iLoadColors = _iCurrent;

	g_iNumColors = 0;
	new Handle:_hKV = CreateKeyValues("BuildWars_Colors");
	if(FileToKeyValues(_hKV, _sPath))
	{
		decl String:_sTemp[64], String:_sValues[][] = { "Red", "Green", "Blue", "Alpha" };
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
	decl String:_sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, _sPath, PLATFORM_MAX_PATH, "configs/buildwars/sm_buildwars_rotations.ini");

	new _iCurrent = GetFileTime(_sPath, FileTime_LastChange);
	if(_iCurrent < g_iLoadRotations)
		return;
	else
		g_iLoadRotations = _iCurrent;

	g_iNumRotations = 0;
	new Handle:_hKV = CreateKeyValues("BuildWars_Rotations");
	if(FileToKeyValues(_hKV, _sPath))
	{
		decl String:_sTemp[64];
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
{	decl String:_sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, _sPath, PLATFORM_MAX_PATH, "configs/buildwars/sm_buildwars_positions.ini");

	new _iCurrent = GetFileTime(_sPath, FileTime_LastChange);
	if(_iCurrent < g_iLoadPositions)
		return;
	else
		g_iLoadPositions = _iCurrent;

	g_iNumPositions = 0;
	new Handle:_hKV = CreateKeyValues("BuildWars_Positions");
	if(FileToKeyValues(_hKV, _sPath))
	{
		decl String:_sTemp[64];
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
	decl String:_sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, _sPath, PLATFORM_MAX_PATH, "configs/buildwars/sm_buildwars_cmds.ini");

	new _iCurrent = GetFileTime(_sPath, FileTime_LastChange);
	if(_iCurrent < g_iLoadCommands)
		return;
	else
		g_iLoadCommands = _iCurrent;

	ClearTrie(g_hTrieCommands);
	new Handle:_hKV = CreateKeyValues("BuildWars_Commands");
	if(FileToKeyValues(_hKV, _sPath))
	{
		decl _iIndex, String:_sTemp[4], String:_sBuffer[32];
		KvGotoFirstSubKey(_hKV);
		do
		{
			KvGetSectionName(_hKV, _sBuffer, sizeof(_sBuffer));
			GetTrieValue(g_hTrieCommandConfig, _sBuffer, _iIndex);
			for(new i = 0; i < MAX_CONFIG_COMMANDS; i++)
			{
				IntToString(i, _sTemp, sizeof(_sTemp));
				KvGetString(_hKV, _sTemp, _sBuffer, sizeof(_sBuffer));
				if(!StrEqual(_sBuffer, ""))
					SetTrieValue(g_hTrieCommands, _sBuffer, _iIndex);
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


public SQL_ConnectCall(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_ConnectCall Error: %s", error);
	else
	{
		SQL_LockDatabase(hndl);
		if(!SQL_FastQuery(hndl, g_sSQL_CreateBaseTable))
		{
			decl String:_sError[512];
			SQL_GetError(hndl, _sError, 512);
			LogError("SQL_ConnectCall: Unable to create buildwars_bases!");
			LogError("SQL_ConnectCall: Error: %s", _sError);
			CloseHandle(hndl);
			return;
		}

		if(!SQL_FastQuery(hndl, g_sSQL_CreatePropTable))
		{
			decl String:_sError[512];
			SQL_GetError(hndl, _sError, 512);
			LogError("SQL_ConnectCall: Unable to create buildwars_props!");
			LogError("SQL_ConnectCall: Error: %s", _sError);
			CloseHandle(hndl);
			return;
		}
		SQL_UnlockDatabase(hndl);

		g_hSql_Database = hndl;
		if(g_bLateBase)
		{
			if(g_bBaseEnabled)
				for(new i = 1; i <= MaxClients; i++)
					if(IsClientInGame(i))
						if((g_iPlayerAccess[i] & g_iBaseAccess || g_iPlayerAccess[i] & ACCESS_BASE))
							Void_LoadClientBase(i);
						
			g_bLateBase = false;
		}
	}
}

public SQL_QueryBaseLoad(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryBaseLoad Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 && IsClientInGame(client))
		{
			decl String:_sQuery[256];
			new _iRows = SQL_GetRowCount(hndl);
			if(_iRows < g_iBaseGroups)
			{
				Format(_sQuery, sizeof(_sQuery), g_sSQL_BaseCreate, g_sSteam[client]);
				SQL_TQuery(g_hSql_Database, SQL_QueryBaseCreate, _sQuery, userid);
			}
			else
			{
				for(new i = 0; i < g_iBaseGroups; i++)
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
		LogError("SQL_QueryPropCheck Error: %s", error);
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
			if(g_iPlayerBaseLoading[client] == g_iBaseGroups && g_iPlayerBaseMenu[client] != -1)
			{
				QueryBuildMenu(client, MENU_BASE_CURRENT);
				g_iPlayerBaseMenu[client] = -1;
			}
		}
	}
}

public SQL_QueryBaseCreate(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryBaseCreate Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 && IsClientInGame(client))
		{
			decl String:_sQuery[256];
			Format(_sQuery, sizeof(_sQuery), g_sSQL_BaseLoad, g_sSteam[client]);
			SQL_TQuery(g_hSql_Database, SQL_QueryBaseLoad, _sQuery, userid);
		}
	}
}

public SQL_QueryPropSaveMass(Handle:owner, Handle:hndl, const String:error[], any:ref)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryPropSave Error: %s", error);
	else
	{
		new entity = EntRefToEntIndex(ref);
		if(entity != INVALID_ENT_REFERENCE)
		{
			g_bValidBase[entity] = true;
			g_iBaseIndex[entity] = SQL_GetInsertId(owner);

			new client = GetClientOfUserId(g_iPropUser[entity]);
			if(client > 0 && IsClientInGame(client))
			{
				g_iPlayerBaseQuery[client] -= 1;
				if(!g_iPlayerBaseQuery[client])
				{
					CPrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Props_All", g_sBaseNames[g_iPlayerBaseCurrent[client]]);

					if(g_iPlayerBaseMenu[client] != -1)
					{
						QueryBuildMenu(client, MENU_BASE_CURRENT);
						g_iPlayerBaseMenu[client] = -1;
					}
				}
				
				g_iPlayerBaseCount[client][g_iPlayerBaseCurrent[client]]++;
			}
		}
	}
}

public SQL_QueryPropSaveSingle(Handle:owner, Handle:hndl, const String:error[], any:ref)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryPropSave Error: %s", error);
	else
	{
		new entity = EntRefToEntIndex(ref);
		if(entity != INVALID_ENT_REFERENCE)
		{
			new _iTemp = g_iBaseIndex[entity];
			g_bValidBase[entity] = true;
			g_iBaseIndex[entity] = SQL_GetInsertId(owner);

			new client = GetClientOfUserId(g_iPropUser[entity]);
			if(client > 0 && IsClientInGame(client))
			{
				g_iPlayerBaseQuery[client] -= 1;
				if(!g_iPlayerBaseQuery[client])
				{										
					CPrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Props", g_sDefinedPropNames[g_iPropType[entity]], g_sBaseNames[g_iPlayerBaseCurrent[client]]);

					if(g_iPlayerBaseMenu[client] != -1)
					{
						QueryBuildMenu(client, MENU_BASE_CURRENT);
						g_iPlayerBaseMenu[client] = -1;
					}
				}
				
				if(g_iBaseIndex[entity] != _iTemp)
					g_iPlayerBaseCount[client][g_iPlayerBaseCurrent[client]]++;
			}
		}
	}
}

public SQL_QueryPropDelete(Handle:owner, Handle:hndl, const String:error[], any:ref)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryPropDelete Error: %s", error);
	else
	{
		new entity = EntRefToEntIndex(ref);
		if(entity != INVALID_ENT_REFERENCE)
		{
			g_bValidBase[entity] = false;
			g_iBaseIndex[entity] = -1;

			new client = GetClientOfUserId(g_iPropUser[entity]);
			if(client > 0 && IsClientInGame(client))
			{
				g_iPlayerBaseQuery[client] -= 1;
				g_iPlayerBaseCount[client][g_iPlayerBaseCurrent[client]]--;
				if(!g_iPlayerBaseQuery[client])
				{
					CPrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Remove_Props", g_sDefinedPropNames[g_iPropType[entity]], g_sBaseNames[g_iPlayerBaseCurrent[client]]);

					if(g_iPlayerBaseMenu[client] != -1)
					{
						QueryBuildMenu(client, MENU_BASE_CURRENT);
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
		LogError("SQL_QueryBaseEmpty Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 && IsClientInGame(client))
		{
			g_iPlayerBaseQuery[client] -= 1;
			g_iPlayerBaseCount[client][g_iPlayerBaseCurrent[client]] = 0;
			if(!g_iPlayerBaseQuery[client])
			{						
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Remove_Props_All", g_sBaseNames[g_iPlayerBaseCurrent[client]]);

				if(g_iPlayerBaseMenu[client] != -1)
				{
					QueryBuildMenu(client, MENU_BASE_CURRENT);
					g_iPlayerBaseMenu[client] = -1;
				}
			}
		}
	}
}

public SQL_QueryBaseReadySave(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryBaseReadySave Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 && IsClientInGame(client))
		{
			g_iPlayerBaseCount[client][g_iPlayerBaseCurrent[client]] = 0;

			new _iSize = (GetArraySize(g_hArray_PlayerProps[client]) - 1);
			new Float:_fSaveDelay = 0.1;
			g_iPlayerBaseQuery[client] -= 1;
			g_bPlayerBaseSpawned[client] = true;

			for(new i = _iSize; i >= 0; i--)
			{
				new entity = GetArrayCell(g_hArray_PlayerProps[client], i);
				if(IsValidEntity(entity))
				{
					g_iPlayerBaseQuery[client] += 1;

					new Handle:_hPack = INVALID_HANDLE;
					CreateDataTimer(_fSaveDelay, Timer_SaveBaseProps, _hPack);
					WritePackCell(_hPack, client);
					WritePackCell(_hPack, entity);
					_fSaveDelay += 0.01;
				}
			}
		}
	}
}

public SQL_QueryBaseUpdate(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryBaseUpdate Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 && IsClientInGame(client))
		{
			g_iPlayerBaseQuery[client] -= 1;
			if(!g_iPlayerBaseQuery[client] && g_iPlayerBaseMenu[client] != -1)
			{
				QueryBuildMenu(client, MENU_BASE_CURRENT);
				g_iPlayerBaseMenu[client] = -1;
			}
		}
	}
}

public SQL_QueryBaseUpdatePost(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryBaseUpdate Error: %s", error);
}

public SQL_QueryPropLoad(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogError("SQL_QueryPropLoad Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(client > 0 && IsClientInGame(client))
		{
			new Float:_fSpawnDelay = 0.1;
			decl Float:_fOrigin[3];
			while (SQL_FetchRow(hndl))
			{
				new Handle:_hPack = INVALID_HANDLE;
				CreateDataTimer(_fSpawnDelay, Timer_SpawnBaseProps, _hPack);
				WritePackCell(_hPack, client);

				WritePackCell(_hPack, SQL_FetchInt(hndl, 0));
				WritePackCell(_hPack, SQL_FetchInt(hndl, 1));

				_fOrigin[0] = SQL_FetchFloat(hndl, 2);
				_fOrigin[1] = SQL_FetchFloat(hndl, 3);
				_fOrigin[2] = SQL_FetchFloat(hndl, 4);
				AddVectors(_fOrigin, g_fPlayerBaseLocation[client], _fOrigin);
				WritePackFloat(_hPack, _fOrigin[0]);
				WritePackFloat(_hPack, _fOrigin[1]);
				WritePackFloat(_hPack, _fOrigin[2]);

				WritePackFloat(_hPack, SQL_FetchFloat(hndl, 5));
				WritePackFloat(_hPack, (SQL_FetchFloat(hndl, 6) + 180.0));
				WritePackFloat(_hPack, SQL_FetchFloat(hndl, 7));
				_fSpawnDelay += 0.025;
			}
		}
	}
}

public Action:Timer_SpawnBaseProps(Handle:timer, Handle:pack)
{
	decl Float:_fOrigin[3], Float:_fAngles[3];
	
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new _iIndex = ReadPackCell(pack);
	new _iType = ReadPackCell(pack);
	for(new i = 0; i <= 2; i++)
		_fOrigin[i] = ReadPackFloat(pack);
	for(new i = 0; i <= 2; i++)
		_fAngles[i] = ReadPackFloat(pack);

	new entity = Entity_SpawnBase(client, _iType, _fOrigin, _fAngles, _iIndex);
	PushArrayCell(g_hArray_PlayerProps[client], entity);
	g_iPlayerProps[client]++;

	g_iPlayerBaseQuery[client] -= 1;
	if(!g_iPlayerBaseQuery[client])
	{
		CPrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Place_Props", g_sBaseNames[g_iPlayerBaseCurrent[client]]);

		if(g_iPlayerBaseMenu[client] != -1)
		{
			QueryBuildMenu(client, MENU_BASE_CURRENT);
			g_iPlayerBaseMenu[client] = -1;
		}
	}
}

QueryBuildMenu(client, menu, group = -1)
{
	if(g_iPlayerBaseLoading[client] < g_iBaseGroups)
	{
		decl String:_sBuffer[192];
		new Handle:_hMenu = CreateMenu(MenuHandler_BaseLoading);
		SetMenuTitle(_hMenu, g_sTitle);
		SetMenuPagination(_hMenu, MENU_NO_PAGINATION);
		SetMenuExitButton(_hMenu, true);
		SetMenuExitBackButton(_hMenu, false);

		Format(_sBuffer, 192, "%T", "Menu_Base_Loading", client);
		AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);

		Format(_sBuffer, 192, "%T", "Menu_Base_Loading_Wait", client);
		AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		
		DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
	}
	else if(g_iPlayerBaseQuery[client] > 0)
	{
		decl String:_sBuffer[192];
		new Handle:_hMenu = CreateMenu(MenuHandler_BaseQuery);
		SetMenuTitle(_hMenu, g_sTitle);
		SetMenuPagination(_hMenu, MENU_NO_PAGINATION);
		SetMenuExitButton(_hMenu, true);
		SetMenuExitBackButton(_hMenu, false);

		Format(_sBuffer, 192, "%T", "Menu_Base_Query", client);
		AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);

		Format(_sBuffer, 192, "%T", "Menu_Base_Query_Wait", client);
		AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
		
		DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
	}
	else
	{
		switch(menu)
		{
			case MENU_BASE_NULL:
			{
				CPrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Query_Completed");
			}
			case MENU_BASE_MAIN:
			{
				Menu_BaseActions(client);
			}
			case MENU_BASE_CURRENT:
			{
				if(group == -1)
					group = g_iPlayerBaseCurrent[client];

				Menu_BaseCurrent(client, group);
			}
			case MENU_BASE_MOVE:
			{
				Menu_BaseMove(client);
			}
		}
	}
}

Menu_BaseActions(client)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:_sBuffer[192], String:_sIndex[4];
	new Handle:_hMenu = CreateMenu(MenuHandler_BaseActions);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuPagination(_hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	for(new i = 0; i < g_iBaseGroups; i++)
	{
		IntToString(i, _sIndex, 4);
		Format(_sBuffer, 192, "%T", "Menu_Base_Option", client, g_sBaseNames[i]);
		Format(_sBuffer, 192, "%s%T", _sBuffer, "Menu_Base_Option_Props", client, g_iPlayerBaseCount[client][i]);
		if(g_iBaseGroups > 1 && g_iPlayerBaseCurrent[client] == i)
			Format(_sBuffer, 192, "%s%T", _sBuffer, "Menu_Base_Current", client);

		AddMenuItem(_hMenu, _sIndex, _sBuffer);
	}
	
	Format(_sBuffer, 192, "%T", "Menu_Base_Spacer", client);
	if(!StrEqual(_sBuffer, ""))
		AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
	
	if(g_bSaveLocation[client])
	{
		Format(_sBuffer, 192, "%T", "Menu_Base_Update_Location", client);
		AddMenuItem(_hMenu, "7", _sBuffer);

		Format(_sBuffer, 192, "%T", "Menu_Base_Clear_Location", client);
		AddMenuItem(_hMenu, "8", _sBuffer);
	}
	else
	{
		Format(_sBuffer, 192, "%T", "Menu_Base_Set_Location", client);
		AddMenuItem(_hMenu, "7", _sBuffer);

		Format(_sBuffer, 192, "%T", "Menu_Base_Clear_Location", client);
		AddMenuItem(_hMenu, "8", _sBuffer, ITEMDRAW_DISABLED);
	}

	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_BaseActions(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
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
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			new _iOption = StringToInt(_sOption);
			
			if(_iOption >= 0 && _iOption <= 6)
				QueryBuildMenu(param1, MENU_BASE_CURRENT, _iOption);
			else if(_iOption == 7)
			{
				if(!g_bEnding)
				{
					decl Float:_fDestination[3], Float:_fOrigin[3], Float:_fAngles[3];
					GetClientAbsOrigin(param1, _fOrigin);
					GetClientEyePosition(param1, _fDestination);
					GetClientEyeAngles(param1, _fAngles);

					TR_TraceRayFilter(_fDestination, _fAngles, MASK_SOLID, RayType_Infinite, Tracer_FilterPlayers, param1);
					if(TR_DidHit(INVALID_HANDLE))
					{
						TR_GetEndPosition(g_fSaveLocation[param1], INVALID_HANDLE);
						if(g_bSaveLocation[param1])
						{
							CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Update");
							CloseHandle(g_hSaveLocation[param1]);
						}
						else
						{
							CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Issue");
							g_bSaveLocation[param1] = true;
						}
						
						Void_DisplaySaveLocation(param1);
						g_hSaveLocation[param1] = CreateTimer(1.0, Timer_DisplaySaveLocation, param1, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
					}
				}
				
				QueryBuildMenu(param1, MENU_BASE_MAIN);
			}
			else if(_iOption == 8)
			{
				if(!g_bEnding)
				{
					g_bSaveLocation[param1] = false;
					if(g_hSaveLocation[param1] != INVALID_HANDLE && CloseHandle(g_hSaveLocation[param1]))
						g_hSaveLocation[param1] = INVALID_HANDLE;

					CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Cancel");
				}

				QueryBuildMenu(param1, MENU_BASE_MAIN);
			}
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
			if(param2 <= MenuCancel_Exit)
			{
				g_iPlayerBaseMenu[param1] = -1;
				Menu_Main(param1);
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
			if(param2 <= MenuCancel_Exit)
			{
				g_iPlayerBaseMenu[param1] = -1;
				Menu_Main(param1);
			}
		}
	}
}

Menu_BaseCurrent(client, group)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:_sBuffer[192], String:_sTemp[32];
	new Handle:_hMenu = CreateMenu(MenuHandler_BaseCurrent);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	if(g_iBaseGroups > 1)
	{
		if(g_iPlayerBaseCurrent[client] != -1)
		{
			Format(_sBuffer, 192, "%T", "Menu_Base_Current_Base", client, g_sBaseNames[g_iPlayerBaseCurrent[client]]);
			AddMenuItem(_hMenu, "0", _sBuffer, ITEMDRAW_DISABLED);
		}
	
		if(g_iPlayerBaseCurrent[client] != group)
		{
			Format(_sTemp, 32, "%d 1", group);
			Format(_sBuffer, 192, "%T", "Menu_Base_Current_Select", client, g_sBaseNames[group]);
			AddMenuItem(_hMenu, _sTemp, _sBuffer, ITEMDRAW_DEFAULT);
		}
		else
		{
			if(g_iPlayerBaseCurrent[client] != -1)
			{
				Format(_sBuffer, 192, "%T", "Menu_Base_Spacer", client);
				if(!StrEqual(_sBuffer, ""))
					AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
			}
		}
	}
	
	new _iState = g_iPlayerBaseCurrent[client] != group ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
	if(!g_bPlayerBaseSpawned[client] || g_iPlayerBaseCurrent[client] != group)
	{
		Format(_sTemp, 32, "%d 2", group);
		Format(_sBuffer, 192, "%T", "Menu_Base_Current_Spawn", client);
		AddMenuItem(_hMenu,_sTemp, _sBuffer, _iState);
	}
	else
	{
		Format(_sTemp, 32, "%d 3", group);
		Format(_sBuffer, 192, "%T", "Menu_Base_Current_Delete", client);
		AddMenuItem(_hMenu, _sTemp, _sBuffer, _iState);
	}

	Format(_sTemp, 32, "%d 4", group);
	Format(_sBuffer, 192, "%T", "Menu_Base_Current_Save_Target", client);
	AddMenuItem(_hMenu, _sTemp, _sBuffer, _iState);

	Format(_sTemp, 32, "%d 5", group);
	Format(_sBuffer, 192, "%T", "Menu_Base_Current_Clear_Target", client);
	AddMenuItem(_hMenu, _sTemp, _sBuffer, _iState);

	Format(_sTemp, 32, "%d 6", group);
	Format(_sBuffer, 192, "%T", "Menu_Base_Current_Save_All", client);
	AddMenuItem(_hMenu, _sTemp, _sBuffer, _iState);

	Format(_sTemp, 32, "%d 7", group);
	Format(_sBuffer, 192, "%T", "Menu_Base_Current_Clear_All", client);
	AddMenuItem(_hMenu, _sTemp, _sBuffer, _iState);

	if(g_bPositionAllowed)
	{
		Format(_sTemp, 32, "%d 8", group);
		Format(_sBuffer, 192, "%T", "Menu_Base_Current_Move_All", client);
		AddMenuItem(_hMenu, _sTemp, _sBuffer, _iState);
	}

	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_BaseCurrent(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				QueryBuildMenu(param1, MENU_BASE_MAIN);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			g_iPlayerBaseMenu[param1] = MENU_BASE_CURRENT;

			decl String:_sOption[8], String:_sBuffer[2][4];
			GetMenuItem(menu, param2, _sOption, 8);
			ExplodeString(_sOption, " ", _sBuffer, 2, 4);

			new _iGroup = StringToInt(_sBuffer[0]);
			switch(StringToInt(_sBuffer[1]))
			{
				case 1:
				{
					if(g_iPlayerBaseCurrent[param1] != _iGroup)
					{
						g_iPlayerBaseCurrent[param1] = _iGroup;

						if(g_bPlayerBaseSpawned[param1])
							g_bPlayerBaseSpawned[param1] = false;

						if(!g_bEnding && Bool_DeleteValid(param1, false))
							Bool_ClearClientBase(param1, false);
					}
					
					QueryBuildMenu(param1, MENU_BASE_CURRENT);
				}
				case 2:
				{
					if(!g_bEnding)
					{
						new _iCurrent = g_iPlayerProps[param1];
						if(!g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]])
						{
							CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Place_Props_Empty", g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
							
							QueryBuildMenu(param1, MENU_BASE_CURRENT);
							return;
						}

						new _iMax = Int_SpawnMaximum(param1);
						if(g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]] <= _iMax)
						{
							if((g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]] + _iCurrent) > _iMax)
							{
								new _iTemp = (g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]] + _iCurrent) - _iMax;
								CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Place_Props_Insufficient", g_sBaseNames[g_iPlayerBaseCurrent[param1]], _iTemp);

								QueryBuildMenu(param1, MENU_BASE_CURRENT);
								return;
							}
						}
						
						if(Bool_SpawnAllowed(param1, true) && Bool_SpawnValid(param1, true, MENU_BASE_CURRENT))
						{
							decl Float:_fDestination[3], Float:_fOrigin[3], Float:_fAngles[3];
							GetClientAbsOrigin(param1, _fOrigin);
							GetClientEyePosition(param1, _fDestination);
							GetClientEyeAngles(param1, _fAngles);
							TR_TraceRayFilter(_fDestination, _fAngles, MASK_SOLID, RayType_Infinite, Tracer_FilterPlayers, param1);
							if(TR_DidHit(INVALID_HANDLE))
							{
								TR_GetEndPosition(g_fPlayerBaseLocation[param1], INVALID_HANDLE);

								g_fSaveLocation[param1] = g_fPlayerBaseLocation[param1];
								if(!g_bSaveLocation[param1])
									g_bSaveLocation[param1] = true;
								else
									CloseHandle(g_hSaveLocation[param1]);

								Void_DisplaySaveLocation(param1);
								g_hSaveLocation[param1] = CreateTimer(1.0, Timer_DisplaySaveLocation, param1, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

								g_bPlayerBaseSpawned[param1] = true;
								g_iPlayerBaseQuery[param1] += g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]];

								decl String:_sQuery[256];
								Format(_sQuery, sizeof(_sQuery), g_sSQL_PropLoad, g_iPlayerBase[param1][g_iPlayerBaseCurrent[param1]]);
								SQL_TQuery(g_hSql_Database, SQL_QueryPropLoad, _sQuery, GetClientUserId(param1));
							}

							QueryBuildMenu(param1, MENU_BASE_CURRENT);
						}
					}
				}
				case 3:
				{
					if(!g_bEnding && Bool_DeleteValid(param1, true, MENU_BASE_CURRENT))
					{			
						if(g_bPlayerBaseSpawned[param1])
						{
							g_bPlayerBaseSpawned[param1] = false;
							new Float:_fWriteDelay = 0.1;
							new _iDeleted, _iArraySize = (GetArraySize(g_hArray_PlayerProps[param1]) - 1);
							for(new i = _iArraySize; i >= 0; i--)
							{
								new entity = GetArrayCell(g_hArray_PlayerProps[param1], i);
								if(IsValidEntity(entity) && g_bValidBase[entity])
								{
									_iDeleted++;
									g_bValidProp[entity] = false;
									g_bValidBase[entity] = false;
									g_iPlayerBaseQuery[param1] += 1;

									new Handle:_hPack = INVALID_HANDLE;
									CreateDataTimer(_fWriteDelay, Timer_DeleteBaseProps, _hPack);
									WritePackCell(_hPack, param1);
									WritePackCell(_hPack, entity);
									_fWriteDelay += 0.01;
									
									RemoveFromArray(g_hArray_PlayerProps[param1], i);
								}
							}
							
							g_iPlayerProps[param1] -= _iDeleted;
						}
					}
					
					QueryBuildMenu(param1, MENU_BASE_CURRENT);
				}
				case 4:
				{
					if(!g_bSaveLocation[param1])
					{
						CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Location_Missing");
						QueryBuildMenu(param1, MENU_BASE_MAIN);
						return;
					}
					else
					{
						new entity = Trace_GetEntity(param1);
						if(Entity_Valid(entity))
						{
							new _iOwner = GetClientOfUserId(g_iPropUser[entity]);
							if(_iOwner == param1)
							{
								if(g_iBaseLimit != -1 && g_iBaseIndex[entity] == -1)
								{
									new _iSize = g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]];
									new _iAllowed = (!g_iBaseLimit) ? Int_SpawnMaximum(param1) : g_iBaseLimit;
									if((_iSize + 1) > _iAllowed)
									{
										CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Props_All_Size", _iAllowed, g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
										QueryBuildMenu(param1, MENU_BASE_CURRENT);
										return;
									}
								}
							
								decl Float:_fOrigin[3];
								GetEntPropVector(entity, Prop_Send, "m_vecOrigin", _fOrigin);

								if(Bool_CheckProximity(g_fSaveLocation[param1], _fOrigin, g_fBaseDistance, false))
									CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Location", g_sDefinedPropNames[g_iPropType[entity]]);
								else
								{
									decl String:_sQuery[512], Float:_fAngles[3], Float:_fTemp;
									GetEntPropVector(entity, Prop_Send, "m_angRotation", _fAngles);
									_fTemp = _fOrigin[2];
									
									SubtractVectors(g_fSaveLocation[param1], _fOrigin, _fOrigin);
									if(g_fSaveLocation[param1][2] >= 0 && _fTemp >= 2 && _fOrigin[2] < 0)
										_fOrigin[2] *= -1;

									if(!g_bPlayerBaseSpawned[param1])
										g_bPlayerBaseSpawned[param1] = true;

									g_iPlayerBaseQuery[param1] += 1;
									if(g_iBaseIndex[entity] != -1)
									{
										Format(_sQuery, sizeof(_sQuery), g_sSQL_PropSaveIndex, g_iBaseIndex[entity], g_iPlayerBase[param1][g_iPlayerBaseCurrent[param1]], g_iPropType[entity], _fOrigin[0], _fOrigin[1], _fOrigin[2], _fAngles[0], _fAngles[1], _fAngles[2], g_sSteam[param1]);
										SQL_TQuery(g_hSql_Database, SQL_QueryPropSaveSingle, _sQuery, EntIndexToEntRef(entity));
									}
									else
									{
										Format(_sQuery, sizeof(_sQuery), g_sSQL_PropSaveNull, g_iPlayerBase[param1][g_iPlayerBaseCurrent[param1]], g_iPropType[entity], _fOrigin[0], _fOrigin[1], _fOrigin[2], _fAngles[0], _fAngles[1], _fAngles[2], g_sSteam[param1]);
										SQL_TQuery(g_hSql_Database, SQL_QueryPropSaveSingle, _sQuery, EntIndexToEntRef(entity));
									}								
								}
							}
							else
							{
								CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Ownership", g_sDefinedPropNames[g_iPropType[entity]], g_sPropOwner[entity]);
							}
						}
					}

					QueryBuildMenu(param1, MENU_BASE_CURRENT);
				}
				case 5:
				{
					if(!g_bEnding)
					{
						new entity = Trace_GetEntity(param1);
						if(Entity_Valid(entity))
						{
							new _iOwner = GetClientOfUserId(g_iPropUser[entity]);
							if(_iOwner == param1)
							{
								if(g_iBaseIndex[entity] != -1)
								{
									g_iPlayerBaseQuery[param1] += 1;

									decl String:_sQuery[256];
									Format(_sQuery, sizeof(_sQuery), g_sSQL_PropDelete, g_iBaseIndex[entity]);
									SQL_TQuery(g_hSql_Database, SQL_QueryPropDelete, _sQuery, EntIndexToEntRef(entity));
								}
								else
								{
									CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Remove_Props_Missing", g_sDefinedPropNames[g_iPropType[entity]], g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
								}
							}
							else
							{
								CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Ownership", g_sDefinedPropNames[g_iPropType[entity]], g_sPropOwner[entity]);
							}
						}
					}

					QueryBuildMenu(param1, MENU_BASE_CURRENT);
				}
				case 6:
				{
					if(!g_bSaveLocation[param1])
					{
						CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Location_Missing");
						QueryBuildMenu(param1, MENU_BASE_MAIN);
						return;
					}
					else
					{
						if(g_iBaseLimit != -1)
						{
							new _iSize = GetArraySize(g_hArray_PlayerProps[param1]);

							if(_iSize < 0)
							{
								CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Props_All_Empty");
								QueryBuildMenu(param1, MENU_BASE_CURRENT);
								return;
							}
							else
							{
								new _iAllowed = (!g_iBaseLimit) ? Int_SpawnMaximum(param1) : g_iBaseLimit;
								if(_iSize > _iAllowed)
								{
									CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Props_All_Size", _iAllowed, g_sBaseNames[g_iPlayerBaseCurrent[param1]]);
									QueryBuildMenu(param1, MENU_BASE_CURRENT);
									return;
								}
							}
						}

						Menu_BaseConfirmSave(param1);
						return;
					}
				}
				case 7:
				{
					if(!g_bEnding)
					{
						new _iSize = (GetArraySize(g_hArray_PlayerProps[param1]) - 1);
						for(new i = _iSize; i >= 0; i--)
						{
							new entity = GetArrayCell(g_hArray_PlayerProps[param1], i);
							if(IsValidEntity(entity) && g_bValidBase[entity])
							{
								g_bValidBase[entity] = false;
								g_iBaseIndex[entity] = -1;
							}
						}
					
						Menu_BaseConfirmEmpty(param1);
						return;
					}

					QueryBuildMenu(param1, MENU_BASE_CURRENT);
				}
				case 8:
				{
					QueryBuildMenu(param1, MENU_BASE_MOVE);
				}
			}
		}
	}
}

Menu_BaseConfirmSave(client)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:_sBuffer[192];
	new Handle:_hMenu = CreateMenu(MenuHandler_BaseConfirmSave);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuPagination(_hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	Format(_sBuffer, 192, "%T", "Menu_Base_Confirm_Save_Ask", client);
	AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
	
	Format(_sBuffer, 192, "%T", "Menu_Base_Spacer", client);
	if(!StrEqual(_sBuffer, ""))
		AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);

	Format(_sBuffer, 192, "%T", "Menu_Base_Confirm_Save_Yes", client);
	AddMenuItem(_hMenu, "1", _sBuffer);
	Format(_sBuffer, 192, "%T", "Menu_Base_Confirm_Save_No", client);
	AddMenuItem(_hMenu, "0", _sBuffer);
	
	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_BaseConfirmSave(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				QueryBuildMenu(param1, MENU_BASE_CURRENT);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			
			if(StringToInt(_sOption))
			{
				g_iPlayerBaseQuery[param1] += 1;

				decl String:_sQuery[256];
				Format(_sQuery, sizeof(_sQuery), g_sSQL_PropEmpty, g_iPlayerBase[param1][g_iPlayerBaseCurrent[param1]], g_sSteam[param1]);
				SQL_TQuery(g_hSql_Database, SQL_QueryBaseReadySave, _sQuery, GetClientUserId(param1));
			}

			QueryBuildMenu(param1, MENU_BASE_CURRENT);
		}
	}
}

Menu_BaseConfirmEmpty(client)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:_sBuffer[192];
	new Handle:_hMenu = CreateMenu(MenuHandler_BaseConfirmEmpty);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuPagination(_hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	Format(_sBuffer, 192, "%T", "Menu_Base_Confirm_Empty_Ask", client, g_sBaseNames[g_iPlayerBaseCurrent[client]]);
	AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);
	
	Format(_sBuffer, 192, "%T", "Menu_Base_Spacer", client);
	if(!StrEqual(_sBuffer, ""))
		AddMenuItem(_hMenu, "", _sBuffer, ITEMDRAW_DISABLED);

	Format(_sBuffer, 192, "%T", "Menu_Base_Confirm_Empty_Yes", client);
	AddMenuItem(_hMenu, "1", _sBuffer);
	Format(_sBuffer, 192, "%T", "Menu_Base_Confirm_Empty_No", client);
	AddMenuItem(_hMenu, "0", _sBuffer);
	
	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_BaseConfirmEmpty(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				QueryBuildMenu(param1, MENU_BASE_CURRENT);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			
			if(StringToInt(_sOption))
			{
				g_iPlayerBaseQuery[param1] += 1;
			
				decl String:_sQuery[256];
				Format(_sQuery, sizeof(_sQuery), g_sSQL_PropEmpty, g_iPlayerBase[param1][g_iPlayerBaseCurrent[param1]], g_sSteam[param1]);
				SQL_TQuery(g_hSql_Database, SQL_QueryBaseEmpty, _sQuery, GetClientUserId(param1));
			}

			QueryBuildMenu(param1, MENU_BASE_CURRENT);
		}
	}
}

Menu_BaseMove(client)
{
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:_sBuffer[192];

	new Handle:_hMenu = CreateMenu(MenuHandler_BaseMove);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuPagination(_hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);
	
	new _iState = Bool_MoveValid(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
	Format(_sBuffer, 192, "%T", "Menu_Position_X_Plus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(_hMenu, "1", _sBuffer, _iState);
	
	Format(_sBuffer, 192, "%T", "Menu_Position_X_Minus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(_hMenu, "2", _sBuffer, _iState);
	
	Format(_sBuffer, 192, "%T", "Menu_Position_Y_Plus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(_hMenu, "3", _sBuffer, _iState);
	
	Format(_sBuffer, 192, "%T", "Menu_Position_Y_Minus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(_hMenu, "4", _sBuffer, _iState);

	Format(_sBuffer, 192, "%T", "Menu_Position_Z_Plus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(_hMenu, "5", _sBuffer, _iState);

	Format(_sBuffer, 192, "%T", "Menu_Position_Z_Minus", client, g_fDefinedPositions[g_iConfigPosition[client]]);
	AddMenuItem(_hMenu, "6", _sBuffer, _iState);

	Format(_sBuffer, 192, "%T", "Menu_Position_Default", client);
	AddMenuItem(_hMenu, "0", _sBuffer);
	
	DisplayMenu(_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_BaseMove(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				QueryBuildMenu(param1, MENU_BASE_CURRENT);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			
			new _iOption = StringToInt(_sOption);
			if(!_iOption)
				Menu_DefaultBasePosition(param1);
			else
			{
				g_iPlayerBaseMenu[param1] = MENU_BASE_MOVE;

				new _iSize = g_iPlayerBaseCount[param1][g_iPlayerBaseCurrent[param1]];
				if(!_iSize)
				{
					CPrintToChat(param1, "%s%t", g_sPrefixChat, "Phrase_Base_Save_Move_All_Empty");
					QueryBuildMenu(param1, MENU_BASE_CURRENT);
					return;
				}
				
				new Float:_fWriteDelay = 0.1;
				new _iArraySize = (GetArraySize(g_hArray_PlayerProps[param1]) - 1);
				for(new i = _iArraySize; i >= 0; i--)
				{
					new entity = GetArrayCell(g_hArray_PlayerProps[param1], i);
					if(IsValidEntity(entity) && g_bValidBase[entity])
					{
						g_iPlayerBaseQuery[param1] += 1;

						new Handle:_hPack = INVALID_HANDLE;
						CreateDataTimer(_fWriteDelay, Timer_MoveBaseProps, _hPack);
						WritePackCell(_hPack, param1);
						WritePackCell(_hPack, entity);
						WritePackCell(_hPack, _iOption);
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
	if(!g_bHasAccess[g_iTeam[client]])
		return;

	decl String:_sBuffer[192], String:_sTemp[4];

	new Handle:_hMenu = CreateMenu(MenuHandler_DefaultBasePosition);
	SetMenuTitle(_hMenu, g_sTitle);
	SetMenuExitButton(_hMenu, true);
	SetMenuExitBackButton(_hMenu, false);

	for(new i = 0; i < g_iNumPositions; i++)
	{
		IntToString(i, _sTemp, 4);
		Format(_sBuffer, 192, "%s%T", (g_iConfigPosition[client] == i) ? g_sPrefixSelect : g_sPrefixEmpty, "Menu_Action_Position_Option", client, g_fDefinedPositions[i]);
		AddMenuItem(_hMenu, _sTemp, _sBuffer);
	}

	DisplayMenuAtItem(_hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_DefaultBasePosition(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if(param2 <= MenuCancel_Exit)
				Menu_BaseMove(param1);
		}
		case MenuAction_Select:
		{
			if(!g_bHasAccess[g_iTeam[param1]])
				return;

			decl String:_sOption[4];
			GetMenuItem(menu, param2, _sOption, 4);
			g_iConfigPosition[param1] = StringToInt(_sOption);
			SetClientCookie(param1, g_cConfigPosition, _sOption);
			
			CPrintToChat(param1, "%s%t", g_sPrefixChat, "Settings_Position", g_fDefinedPositions[g_iConfigPosition[param1]]);
			Menu_DefaultBasePosition(param1, GetMenuSelectionPosition());
		}
	}
}

Bool_ClearClientBase(client, bool:message = true)
{
	new _iDeleted, _iSize = (GetArraySize(g_hArray_PlayerProps[client]) - 1);
	for(new i = _iSize; i >= 0; i--)
	{
		new entity = GetArrayCell(g_hArray_PlayerProps[client], i);
		if(IsValidEntity(entity) && g_bValidBase[entity])
		{
			Entity_DeleteProp(entity);
			RemoveFromArray(g_hArray_PlayerProps[client], i);			
			_iDeleted++;
		}
	}

	g_iPlayerProps[client] -= _iDeleted;
	g_iPlayerDeletes[client] += _iDeleted;
	
	if(message)
		CPrintToChat(client, "%s%t", g_sPrefixChat, "Phrase_Base_Clear_Props", g_sBaseNames[g_iPlayerBaseCurrent[client]]);
	return _iDeleted ? true : false;
}

Void_LoadClientBase(client)
{
	if(g_hSql_Database != INVALID_HANDLE)
	{
		g_iPlayerBaseCurrent[client] = (g_iBaseGroups == 1) ? 0 : -1;
		g_iPlayerBaseMenu[client] = -1;
		g_iPlayerBaseQuery[client] = 0;
		g_iPlayerBaseLoading[client] = 0;
		for(new i = 0; i < g_iBaseGroups; i++)
		{
			g_iPlayerBase[client][i] = 0;
			g_iPlayerBaseCount[client][i] = 0;
		}

		decl String:_sQuery[256];
		Format(_sQuery, sizeof(_sQuery), g_sSQL_BaseLoad, g_sSteam[client]);
		SQL_TQuery(g_hSql_Database, SQL_QueryBaseLoad, _sQuery, GetClientUserId(client));
	}
}

public Action:Timer_SaveBaseProps(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new entity = ReadPackCell(pack);

	decl Float:_fOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", _fOrigin);
	if(Bool_CheckProximity(g_fSaveLocation[client], _fOrigin, g_fBaseDistance, true))
	{
		decl String:_sQuery[512], Float:_fAngles[3], Float:_fTemp;
		GetEntPropVector(entity, Prop_Send, "m_angRotation", _fAngles);
		_fTemp = _fOrigin[2];
		
		SubtractVectors(g_fSaveLocation[client], _fOrigin, _fOrigin);
		if(g_fSaveLocation[client][2] >= 0 && _fTemp >= 2 && _fOrigin[2] < 0)
			_fOrigin[2] *= -1;

		if(g_iBaseIndex[entity] != -1)
		{
			Format(_sQuery, sizeof(_sQuery), g_sSQL_PropSaveIndex, g_iBaseIndex[entity], g_iPlayerBase[client][g_iPlayerBaseCurrent[client]], g_iPropType[entity],	_fOrigin[0], _fOrigin[1], _fOrigin[2], _fAngles[0], _fAngles[1], _fAngles[2], g_sSteam[client]);
			SQL_TQuery(g_hSql_Database, SQL_QueryPropSaveMass, _sQuery, EntIndexToEntRef(entity));
		}
		else
		{
			Format(_sQuery, sizeof(_sQuery), g_sSQL_PropSaveNull, g_iPlayerBase[client][g_iPlayerBaseCurrent[client]], g_iPropType[entity], _fOrigin[0], _fOrigin[1], _fOrigin[2], _fAngles[0], _fAngles[1], _fAngles[2], g_sSteam[client]);
			SQL_TQuery(g_hSql_Database, SQL_QueryPropSaveMass, _sQuery, EntIndexToEntRef(entity));
		}
	}
	else
	{
		g_iPlayerBaseQuery[client] -= 1;
		if(!g_iPlayerBaseQuery[client] && g_iPlayerBaseMenu[client] != -1)
		{
			QueryBuildMenu(client, MENU_BASE_CURRENT);
			g_iPlayerBaseMenu[client] = -1;
		}
	}
}

public Action:Timer_MoveBaseProps(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new entity = ReadPackCell(pack);
	new option = ReadPackCell(pack);
	
	new Float:_fTemp[3];
	switch(option)
	{
		case 1:
			_fTemp[0] = g_fDefinedPositions[g_iConfigPosition[client]];
		case 2:
			_fTemp[0] = (g_fDefinedPositions[g_iConfigPosition[client]] * -1);
		case 3:
			_fTemp[1] = g_fDefinedPositions[g_iConfigPosition[client]];
		case 4:
			_fTemp[1] = (g_fDefinedPositions[g_iConfigPosition[client]] * -1);
		case 5:
			_fTemp[2] = g_fDefinedPositions[g_iConfigPosition[client]];
		case 6:
			_fTemp[2] = (g_fDefinedPositions[g_iConfigPosition[client]] * -1);
	}
	
	g_iPlayerBaseQuery[client] -= 1;
	Entity_PositionProp(entity, _fTemp);
	
	if(!g_iPlayerBaseQuery[client] && g_iPlayerBaseMenu[client] != -1)
	{
		QueryBuildMenu(client, MENU_BASE_MOVE);
		g_iPlayerBaseMenu[client] = -1;
	}
}

public Action:Timer_DeleteBaseProps(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new entity = ReadPackCell(pack);

	if(IsValidEntity(entity))
		Entity_DeleteProp(entity);					
	
	g_iPlayerBaseQuery[client] -= 1;
	if(!g_iPlayerBaseQuery[client] && g_iPlayerBaseMenu[client] != -1)
	{
		QueryBuildMenu(client, MENU_BASE_CURRENT);
		g_iPlayerBaseMenu[client] = -1;
	}
}

public Action:Timer_DisplaySaveLocation(Handle:timer, any:client)
{
	if(!IsClientInGame(client))
		g_hSaveLocation[client] = INVALID_HANDLE;
	else
	{
		Void_DisplaySaveLocation(client);
		return Plugin_Continue;
	}

	return Plugin_Stop;
}

Void_DisplaySaveLocation(client)
{
	decl Float:_fTemp[3];
	_fTemp = g_fSaveLocation[client];
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
	new Float:degree = ArcCosine( GetVectorDotProduct( vector1_n, vector2_n ) ) * 57.29577951;
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
	
	new Float:sin = Sine( degree * 0.01745328 );
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

bool:Bool_CheckProximity(Float:_fOrigin[3], Float:_fLocation[3], Float:_fLimit, bool:_bWithin)
{
	if(_fLimit <= 0)
		return false;
	else
	{
		if(_bWithin)
		{
			if(GetVectorDistance(_fOrigin, _fLocation) <= _fLimit)
				return true;
			else
				return false;
		}
		else
		{
			if(GetVectorDistance(_fOrigin, _fLocation) > _fLimit)
				return true;
			else
				return false;
		}
	}
}