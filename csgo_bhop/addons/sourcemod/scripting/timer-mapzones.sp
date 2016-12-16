#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <adminmenu>
#include <smlib>
#include <timer>
#include <timer-mapzones>
#include <timer-logging>
#include <timer-stocks>
#include <timer-logging>
#include <timer-mysql>
#include <timer-config_loader>

#undef REQUIRE_PLUGIN
#include <js_ljstats>
#include <timer-physics>
#include <timer-hide>
#include <timer-maptier>
#include <timer-teams>

#define WHITE 0x01
#define LIGHTRED 0x0F

new bool:g_timerPhysics = false;
new bool:g_timerTeams = false;
new bool:g_timerMapTier = false;
new bool:g_timerLjStats = false;

new g_ioffsCollisionGroup;

enum MapZoneEditor
{
	Step,
	Float:Point1[3],
	Float:Point2[3],
	Level_Id,
	MapZoneType:Type,
	String:Name[32]
}

new Handle:g_MapZoneDrawDelayTimer[2048];
new g_MapZoneEntityZID[2048];

/**
* Global Variables
*/
new Handle:g_hSQL;

new adminmode = 0;
new bool:g_bZonesLoaded = false;
new bool:g_bZone[2048][MAXPLAYERS+1];

new Float:g_fCord_Old[MAXPLAYERS+1][3];
new Float:g_fCord_New[MAXPLAYERS+1][3];

new g_iIgnoreEndTouchStart[MAXPLAYERS+1];

new g_iTargetNPC[MAXPLAYERS+1];

new Handle:g_PreSpeedStart = INVALID_HANDLE;
new g_bPreSpeedStart = true;
new Handle:g_PreSpeedBonusStart = INVALID_HANDLE;
new g_bPreSpeedBonusStart = true;

new Handle:g_BeamDefaultPath = INVALID_HANDLE;
new String:g_sBeamDefaultPath[256];


new Handle:Sound_TeleLast = INVALID_HANDLE;
new String:SND_TELE_LAST[MAX_FILE_LEN];
new Handle:Sound_TeleNext = INVALID_HANDLE;
new String:SND_TELE_NEXT[MAX_FILE_LEN];
new Handle:Sound_TimerStart = INVALID_HANDLE;
new String:SND_TIMER_START[MAX_FILE_LEN];

new String:g_currentMap[64];

new g_mapZones[128][MapZone];
new g_mapZonesCount = 0;

new Handle:hTopMenu = INVALID_HANDLE;
new TopMenuObject:oMapZoneMenu;

new g_mapZoneEditors[MAXPLAYERS+1][MapZoneEditor];

new precache_laser_default;

new g_iClientLastTrackZone[MAXPLAYERS+1]=0;

new Handle:g_OnMapZonesLoaded;
new Handle:g_OnMapZoneLoaded;

new Handle:g_OnClientStartTouchZoneType;
new Handle:g_OnClientEndTouchZoneType;

new Handle:g_OnClientStartTouchLevel;
new Handle:g_OnClientStartTouchBonusLevel;

new bool:g_bAllowRoundEnd = false;

new Float:g_fSpawnTime[MAXPLAYERS+1];

new bool:g_bTeleportersDisabled;

public Plugin:myinfo =
{
	name        = "[TIMER] MapZones",
	author      = "Zipcore, Credits: Alongub, DR. API Improvements",
	description = "[Timer] MapZones manager with trigger_multiple hooks",
	version     = PL_VERSION,
	url         = "forums.alliedmods.net/showthread.php?p=2074699"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegPluginLibrary("timer-mapzones");
	CreateNative("Timer_GetClientLevel", Native_GetClientLevel);
	CreateNative("Timer_GetClientLevelID", Native_GetClientLevelID);
	CreateNative("Timer_GetLevelName", Native_GetLevelName);
	CreateNative("Timer_SetClientLevel", Native_SetClientLevel);
	CreateNative("Timer_SetIgnoreEndTouchStart", Native_SetIgnoreEndTouchStart);
	CreateNative("Timer_IsPlayerTouchingZoneType", Native_IsPlayerTouchingZoneType);
	CreateNative("Timer_GetMapzoneCount", Native_GetMapzoneCount);
	CreateNative("Timer_ClientTeleportLevel", Native_ClientTeleportLevel);
	CreateNative("Timer_AddMapZone", Native_AddMapZone);
	
	CreateNative("Timer_ClientStart", Native_ClientStart);
	CreateNative("Timer_ClientRestart", Native_ClientRestart);
	CreateNative("Timer_ClientBonusRestart", Native_ClientBonusRestart);
	
	return APLRes_Success;
}

public OnPluginStart()
{
	LoadPhysics();
	LoadTimerSettings();

	g_timerPhysics = LibraryExists("timer-physics");
	g_timerTeams = LibraryExists("timer-teams");
	g_timerMapTier = LibraryExists("timer-maptier");
	g_timerLjStats = LibraryExists("timer-ljstats");
	
	FindCollisionGroup();
	
	g_PreSpeedStart = CreateConVar("timer_prespeed_start", "1", "Enable prespeed limit for start zone.", _, true, 0.0, true, 1.0);
	g_PreSpeedBonusStart = CreateConVar("timer_prespeed_bonusstart", "1", "Enable prespeed limit for bonus start zone.", _, true, 0.0, true, 1.0);
	
	g_BeamDefaultPath = CreateConVar("timer_beam_sprite_default", "materials/sprites/laserbeam", "The laser sprite for zones (default sprite).");
	
	Sound_TeleLast = CreateConVar("timer_sound_tele_last", "ui/freeze_cam.wav", "");
	Sound_TeleNext = CreateConVar("timer_sound_tele_next", "ui/freeze_cam.wav", "");
	Sound_TimerStart = CreateConVar("timer_sound_start", "ui/freeze_cam.wav", "");
	
	HookConVarChange(g_PreSpeedStart, Action_OnSettingsChange);
	HookConVarChange(g_PreSpeedBonusStart, Action_OnSettingsChange);
	
	HookConVarChange(Sound_TeleLast, Action_OnSettingsChange);
	HookConVarChange(Sound_TeleNext, Action_OnSettingsChange);
	HookConVarChange(Sound_TimerStart, Action_OnSettingsChange);
	
	HookConVarChange(g_BeamDefaultPath, Action_OnSettingsChange);
	
	AutoExecConfig(true, "timer/timer-mapzones");
	
	LoadTranslations("drapi/drapi_timer-mapzones.phrases");
	
	new Handle:topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
	
	RegAdminCmd("sm_zoneadminmode", Command_LevelAdminMode, ADMFLAG_RCON);
	RegAdminCmd("sm_zonename", Command_LevelName, ADMFLAG_RCON);
	RegAdminCmd("sm_zoneid", Command_LevelID, ADMFLAG_RCON);
	RegAdminCmd("sm_zonetype", Command_LevelType, ADMFLAG_RCON);
	RegAdminCmd("sm_zoneadd", Command_AddZone, ADMFLAG_RCON);
	RegAdminCmd("sm_zonereload", Command_ReloadZones, ADMFLAG_SLAY);
	RegAdminCmd("sm_npc_next", Command_NPC_Next, ADMFLAG_RCON);
	RegAdminCmd("sm_zone", Command_AdminZone, ADMFLAG_ROOT);
	RegAdminCmd("sm_zonedel", Command_AdminZoneDel, ADMFLAG_ROOT);
	RegAdminCmd("sm_toggle_tp", Command_ToggleTeleporters, ADMFLAG_RCON);
	
	RegConsoleCmd("sm_levels", Command_Levels);
	RegConsoleCmd("sm_stage", Command_Levels);
	
	if(g_Settings[RestartEnable])
	{
		RegConsoleCmd("sm_restart", Command_Restart);
		RegConsoleCmd("sm_r", Command_Restart);
	}
	
	if(g_Settings[StartEnable])
	{
		RegConsoleCmd("sm_start", Command_Start);
		RegConsoleCmd("sm_s", Command_Start);
		
		RegConsoleCmd("sm_bonusrestart", Command_BonusRestart);
		RegConsoleCmd("sm_bonusstart", Command_BonusRestart);
		RegConsoleCmd("sm_br", Command_BonusRestart);
		RegConsoleCmd("sm_b", Command_BonusRestart);
		RegConsoleCmd("sm_bonus", Command_BonusRestart);
		RegConsoleCmd("sm_b2", Command_Bonus2Restart);
		RegConsoleCmd("sm_bonus2", Command_Bonus2Restart);
		RegConsoleCmd("sm_b3", Command_Bonus3Restart);
		RegConsoleCmd("sm_bonus3", Command_Bonus3Restart);
		RegConsoleCmd("sm_b4", Command_Bonus4Restart);
		RegConsoleCmd("sm_bonus4", Command_Bonus4Restart);
		RegConsoleCmd("sm_b5", Command_Bonus5Restart);
		RegConsoleCmd("sm_bonus5", Command_Bonus5Restart);
	}
	
	if(g_Settings[StuckEnable]) RegConsoleCmd("sm_stuck", Command_Stuck);
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	AddNormalSoundHook(Hook_NormalSound);
	
	g_ioffsCollisionGroup = FindSendPropOffs("CBaseEntity", "m_CollisionGroup");
	
	g_OnMapZonesLoaded = CreateGlobalForward("OnMapZonesLoaded", ET_Event);
	g_OnMapZoneLoaded = CreateGlobalForward("OnMapZoneLoaded", ET_Event, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Float, Param_Float, Param_Float, Param_Float);
	
	g_OnClientStartTouchZoneType = CreateGlobalForward("OnClientStartTouchZoneType", ET_Event, Param_Cell,Param_Cell);
	g_OnClientEndTouchZoneType = CreateGlobalForward("OnClientEndTouchZoneType", ET_Event, Param_Cell,Param_Cell);
	
	g_OnClientStartTouchLevel = CreateGlobalForward("OnClientStartTouchLevel", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	g_OnClientStartTouchBonusLevel = CreateGlobalForward("OnClientStartTouchBonusLevel", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	
	//Check timeleft to enforce mapchange
	if(g_Settings[ForceMapEndEnable]) CreateTimer(1.0, CheckRemainingTime, INVALID_HANDLE, TIMER_REPEAT);
	
	//Fix rotation bugs
	CreateTimer(300.0, Timer_FixAngRotation, _, TIMER_REPEAT);
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "timer-physics"))
	{
		g_timerPhysics = true;
	}
	else if (StrEqual(name, "timer-teams"))
	{
		g_timerTeams = true;
	}
	else if (StrEqual(name, "timer-maptier"))
	{
		g_timerMapTier = true;
	}
	else if (StrEqual(name, "timer-ljstats"))
	{
		g_timerLjStats = true;
	}
}

public OnLibraryRemoved(const String:name[])
{	
	if (StrEqual(name, "timer-physics"))
	{
		g_timerPhysics = false;
	}
	else if (StrEqual(name, "timer-teams"))
	{
		g_timerTeams = false;
	}
	else if (StrEqual(name, "timer-maptier"))
	{
		g_timerMapTier = false;
	}
	else if (StrEqual(name, "timer-ljstats"))
	{
		g_timerLjStats = false;
	}
	else if (StrEqual(name, "adminmenu"))
	{
		hTopMenu = INVALID_HANDLE;
	}
}

public OnMapStart()
{
	g_bTeleportersDisabled = false;
	
	LoadPhysics();
	LoadTimerSettings();
	
	InitZoneSprites();
	
	g_bZonesLoaded = false;
	adminmode = 0;
	
	GetCurrentMap(g_currentMap, sizeof(g_currentMap));
	ConnectSQL();
	
	CreateTimer(4.0, CheckEntitysLoaded, _, TIMER_FLAG_NO_MAPCHANGE);
	
	for (new i = 1; i < MAXPLAYERS; i++)
	{
		g_iClientLastTrackZone[i] = 0;
	}
	
	PrecacheModel("models/props_junk/wood_crate001a.mdl", true);
}

//Saving current position of players to check for teleport cheating
public OnGameFrame()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client))
			continue;
		
		if(!IsPlayerAlive(client))
			continue;
		
		if(IsClientSourceTV(client))
			continue;
		
		g_fCord_Old[client][0] = g_fCord_New[client][0];
		g_fCord_Old[client][1] = g_fCord_New[client][1];
		g_fCord_Old[client][2] = g_fCord_New[client][2];
		
		GetClientAbsOrigin(client, g_fCord_New[client]);
	}
}

public OnTimerStarted(client)
{
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		if(GetClientHealth(client) < g_Physics[Timer_GetStyle(client)][StyleSpawnHealth])
		{
			SetEntityHealth(client, g_Physics[Timer_GetStyle(client)][StyleSpawnHealth]);
		}
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(buttons & IN_USE && IsPlayerTouchingZoneType(client, ZtBlockUse))
	{
		buttons &= ~IN_USE;
	}
	
	if(buttons & IN_DUCK && IsPlayerTouchingZoneType(client, ZtBlockDuck))
	{
		buttons &= ~IN_DUCK;
	}
	
	if(buttons & IN_ATTACK && IsPlayerTouchingZoneType(client, ZtBlockAttack))
	{
		buttons &= ~IN_ATTACK;
	}
	
	if(g_mapZoneEditors[client][Step] == 0)
		return Plugin_Continue;
	
	if (!IsPlayerAlive(client) || IsClientSourceTV(client))
		return Plugin_Continue;

	if (buttons & IN_ATTACK2)
	{
		if (g_mapZoneEditors[client][Step] == 1)
		{
			new Float:vec[3];			
			GetClientAbsOrigin(client, vec);
			g_mapZoneEditors[client][Point1] = vec;
			DisplayPleaseWaitMenu(client);
			CreateTimer(1.0, ChangeStep, GetClientSerial(client));
			return Plugin_Handled;
		}
		else if (g_mapZoneEditors[client][Step] == 2)
		{
			new Float:vec[3];
			GetClientAbsOrigin(client, vec);
			g_mapZoneEditors[client][Point2] = vec;
			g_mapZoneEditors[client][Point2][2] += 100.0;
			g_mapZoneEditors[client][Step] = 3;
			DisplayAdjustZoneMenu(client, 0);
			return Plugin_Handled;
		}		
	}
	else if (buttons & IN_ATTACK)
	{ 
		if (g_mapZoneEditors[client][Step] == 1)
		{
			new Float:vec[3];
			GetAimOrigin(client, vec);
			g_mapZoneEditors[client][Point1] = vec;
			DisplayPleaseWaitMenu(client);
			CreateTimer(1.0, ChangeStep, GetClientSerial(client));
			return Plugin_Handled;
		}
		else if (g_mapZoneEditors[client][Step] == 2)
		{
			new Float:vec[3];
			GetAimOrigin(client, vec);
			g_mapZoneEditors[client][Point2] = vec;
			g_mapZoneEditors[client][Step] = 3;
			DisplayAdjustZoneMenu(client, 0);
			return Plugin_Handled;
		}		
	}
	
	return Plugin_Continue;
}

DisplayAdjustZoneMenu(client, category)
{
	new Handle:menu = CreateMenu(ZoneAdjust);
	SetMenuTitle(menu, "%T", "Adjust zone", client);
	
	if(category == 0)
	{
		AddMenuItem(menu, "point1", "Adjust point 1");
		AddMenuItem(menu, "point2", "Adjust point 2");
		AddMenuItem(menu, "world", "Use world boundary");
		AddMenuItem(menu, "done", "Done (Select type)");
	}
	else if(category == 1)
	{
		AddMenuItem(menu, "point1_x+", "X+");
		AddMenuItem(menu, "point1_x-", "X-");
		AddMenuItem(menu, "point1_y+", "Y+");
		AddMenuItem(menu, "point1_y-", "Y-");
		AddMenuItem(menu, "point1_z+", "Z+");
		AddMenuItem(menu, "point1_z-", "Z-");
		AddMenuItem(menu, "back", "Back");
	}
	else if(category == 2)
	{
		AddMenuItem(menu, "point2_x+", "X+");
		AddMenuItem(menu, "point2_x-", "X-");
		AddMenuItem(menu, "point2_y+", "Y+");
		AddMenuItem(menu, "point2_y-", "Y-");
		AddMenuItem(menu, "point2_z+", "Z+");
		AddMenuItem(menu, "point2_z-", "Z-");
		AddMenuItem(menu, "back", "Back");
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 360);
}

new Float:g_fLastAdjust[MAXPLAYERS+1];

public ZoneAdjust(Handle:menu, MenuAction:action, client, itemNum)
{
	new Float:adjust_units = 1.0;
	
	if(GetGameTime()-g_fLastAdjust[client] < 1.0)
		adjust_units = 5.0;
	
	if ( action == MenuAction_Select )
	{
		decl String:info[100], String:info2[100];
		new bool:found = GetMenuItem(menu, itemNum, info, sizeof(info), _, info2, sizeof(info2));
		
		if(found)
		{
			if(StrEqual(info, "back"))
			{
				DisplayAdjustZoneMenu(client, 0);
			}
			else if(StrEqual(info, "world"))
			{
				decl Float:Mins[3];
				decl Float:Maxs[3];
				GetEntPropVector(0, Prop_Send, "m_WorldMins", Mins);
				GetEntPropVector(0, Prop_Send, "m_WorldMaxs", Maxs);
				
				g_mapZoneEditors[client][Point1][0] = Mins[0];
				g_mapZoneEditors[client][Point1][1] = Mins[1];
				g_mapZoneEditors[client][Point1][2] = Mins[2];
				g_mapZoneEditors[client][Point2][0] = Maxs[0];
				g_mapZoneEditors[client][Point2][1] = Maxs[1];
				g_mapZoneEditors[client][Point2][2] = Maxs[2];
				DisplayAdjustZoneMenu(client, 0);
			}
			else if(StrEqual(info, "done"))
			{
				DisplaySelectZoneTypeMenu(client, 0);
			}
			else if(StrEqual(info, "point1"))
			{
				DisplayAdjustZoneMenu(client, 1);
			}
			else if(StrEqual(info, "point2"))
			{
				DisplayAdjustZoneMenu(client, 2);
			}
			// Point 1
			else if(StrEqual(info, "point1_x+"))
			{
				g_mapZoneEditors[client][Point1][0] += adjust_units;
				g_fLastAdjust[client] = GetGameTime();
				DisplayAdjustZoneMenu(client, 1);
			}
			else if(StrEqual(info, "point1_x-"))
			{
				g_mapZoneEditors[client][Point1][0] -= adjust_units;
				g_fLastAdjust[client] = GetGameTime();
				DisplayAdjustZoneMenu(client, 1);
			}
			else if(StrEqual(info, "point1_y+"))
			{
				g_mapZoneEditors[client][Point1][1] += adjust_units;
				g_fLastAdjust[client] = GetGameTime();
				DisplayAdjustZoneMenu(client, 1);
			}
			else if(StrEqual(info, "point1_y-"))
			{
				g_mapZoneEditors[client][Point1][1] -= adjust_units;
				g_fLastAdjust[client] = GetGameTime();
				DisplayAdjustZoneMenu(client, 1);
			}
			else if(StrEqual(info, "point1_z+"))
			{
				g_mapZoneEditors[client][Point1][2] += adjust_units;
				g_fLastAdjust[client] = GetGameTime();
				DisplayAdjustZoneMenu(client, 1);
			}
			else if(StrEqual(info, "point1_z-"))
			{
				g_mapZoneEditors[client][Point1][2] -= adjust_units;
				g_fLastAdjust[client] = GetGameTime();
				DisplayAdjustZoneMenu(client, 1);
			}
			// Point 2
			else if(StrEqual(info, "point2_x+"))
			{
				g_mapZoneEditors[client][Point2][0] += adjust_units;
				g_fLastAdjust[client] = GetGameTime();
				DisplayAdjustZoneMenu(client, 2);
			}
			else if(StrEqual(info, "point2_x-"))
			{
				g_mapZoneEditors[client][Point2][0] -= adjust_units;
				g_fLastAdjust[client] = GetGameTime();
				DisplayAdjustZoneMenu(client, 2);
			}
			else if(StrEqual(info, "point2_y+"))
			{
				g_mapZoneEditors[client][Point2][1] += adjust_units;
				g_fLastAdjust[client] = GetGameTime();
				DisplayAdjustZoneMenu(client, 2);
			}
			else if(StrEqual(info, "point2_y-"))
			{
				g_mapZoneEditors[client][Point2][1] -= adjust_units;
				g_fLastAdjust[client] = GetGameTime();
				DisplayAdjustZoneMenu(client, 2);
			}
			else if(StrEqual(info, "point2_z+"))
			{
				g_mapZoneEditors[client][Point2][2] += adjust_units;
				g_fLastAdjust[client] = GetGameTime();
				DisplayAdjustZoneMenu(client, 2);
			}
			else if(StrEqual(info, "point2_z-"))
			{
				g_mapZoneEditors[client][Point2][2] -= adjust_units;
				g_fLastAdjust[client] = GetGameTime();
				DisplayAdjustZoneMenu(client, 2);
			}
		}
	}
	else if (action == MenuAction_End) 
	{
		CloseHandle(menu);
		ResetMapZoneEditor(client);
	} 
	else if (action == MenuAction_Cancel) 
	{
		if (itemNum == MenuCancel_Exit && hTopMenu != INVALID_HANDLE) 
		{
			DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
			ResetMapZoneEditor(client);
		}
	}
}

DisplaySelectZoneTypeMenu(client, category)
{
	new Handle:menu = CreateMenu(ZoneTypeSelect);
	SetMenuTitle(menu, "%T", "Select zone type", client);
	
	if(category == 0)
	{
		AddMenuItem(menu, "cat_timer", "Timer (Basic)");
		AddMenuItem(menu, "cat_timer_bonus", "Timer (Bonus)");
		AddMenuItem(menu, "cat_timer_other", "Timer (More)");
		AddMenuItem(menu, "cat_physics", "Physics");
		AddMenuItem(menu, "cat_teleport", "Teleport");
		AddMenuItem(menu, "cat_control", "Control");
		AddMenuItem(menu, "cat_speed", "Speed");
		AddMenuItem(menu, "cat_block", "Block Keys");
		AddMenuItem(menu, "cat_other", "Other");
		AddMenuItem(menu, "cat_timer_bonus2", "Timer (Bonus2)");
		AddMenuItem(menu, "cat_timer_bonus3", "Timer (Bonus3)");
		AddMenuItem(menu, "cat_timer_bonus4", "Timer (Bonus4)");
		AddMenuItem(menu, "cat_timer_bonus5", "Timer (Bonus5)");
		AddMenuItem(menu, "adjust", "Back");
	}
	else if(category == 1)
	{
		AddMenuItem(menu, "level", "Level");
		AddMenuItem(menu, "checkpoint", "Checkpoint");
		AddMenuItem(menu, "start", "Start");
		AddMenuItem(menu, "end", "End");
		AddMenuItem(menu, "back", "Back");
	}
	else if(category == 2)
	{
		AddMenuItem(menu, "bonuslevel", "Bonus Level");
		AddMenuItem(menu, "bonuscheckpoint", "Bonus Checkpoint");
		AddMenuItem(menu, "bonusstart", "Bonus Start");
		AddMenuItem(menu, "bonusend", "Bonus End");
		AddMenuItem(menu, "back", "Back");
	}
	else if(category == 3)
	{
		AddMenuItem(menu, "stop", "Stop");
		AddMenuItem(menu, "restart", "Restart");
		AddMenuItem(menu, "reset", "Reset");
		AddMenuItem(menu, "restart_normal", "Restart Normal Timer");
		AddMenuItem(menu, "restart_bonus", "Restart Bonus Timer");
		AddMenuItem(menu, "back", "Back");
	}
	else if(category == 4)
	{
		AddMenuItem(menu, "auto", "Enable Auto Bhop");
		AddMenuItem(menu, "noauto", "Disable Auto Bhop");
		AddMenuItem(menu, "nogravity", "No Gravity verwrite");
		AddMenuItem(menu, "noboost", "Disable Style Boost");
		AddMenuItem(menu, "block", "Toggle Noblock");
		AddMenuItem(menu, "antinoclip", "Anti Noclip");
		AddMenuItem(menu, "back", "Back");
	}
	else if(category == 5)
	{
		AddMenuItem(menu, "last", "Teleport Last");
		AddMenuItem(menu, "next", "Teleport Next");
		AddMenuItem(menu, "npc_next", "NPC Teleporter");
		AddMenuItem(menu, "npc_next_double", "NPC Double Teleporter");
		AddMenuItem(menu, "back", "Back");
	}
	else if(category == 6)
	{
		AddMenuItem(menu, "freestyle", "Freestyle");
		AddMenuItem(menu, "up", "Push Up");
		AddMenuItem(menu, "down", "Push Down");
		AddMenuItem(menu, "north", "Push North");
		AddMenuItem(menu, "south", "Push South");
		AddMenuItem(menu, "east", "Push East");
		AddMenuItem(menu, "west", "Push West");
		AddMenuItem(menu, "hover", "Hover");
		AddMenuItem(menu, "back", "Back");
	}
	else if(category == 7)
	{
		AddMenuItem(menu, "limit", "Speed Limit");
		AddMenuItem(menu, "booster", "Booster");
		AddMenuItem(menu, "fullbooster", "Fullbooster");
		AddMenuItem(menu, "back", "Back");
	}
	else if(category == 8)
	{
		AddMenuItem(menu, "blockuse", "Block Use");
		AddMenuItem(menu, "blockduck", "Block Duck");
		AddMenuItem(menu, "blockattack", "Block Attack");
		AddMenuItem(menu, "back", "Back");
	}
	else if(category == 9)
	{
		AddMenuItem(menu, "longjump", "Long Jump Stats");
		AddMenuItem(menu, "arena", "PvP Arena");
		AddMenuItem(menu, "jail", "Jail");
		AddMenuItem(menu, "bullettime", "Bullettime");
		//AddMenuItem(menu, "clip", "Clip");
		//AddMenuItem(menu, "bounceback", "Bounce Back");
		AddMenuItem(menu, "back", "Back");
	}
	else if(category == 10)
	{
		AddMenuItem(menu, "bonus2level", "Bonus2 Level");
		AddMenuItem(menu, "bonus2checkpoint", "Bonus2 Checkpoint");
		AddMenuItem(menu, "bonus2start", "Bonus2 Start");
		AddMenuItem(menu, "bonus2end", "Bonus2 End");
		AddMenuItem(menu, "back", "Back");
	}
	else if(category == 11)
	{
		AddMenuItem(menu, "bonus3level", "Bonus3 Level");
		AddMenuItem(menu, "bonus3checkpoint", "Bonus3 Checkpoint");
		AddMenuItem(menu, "bonus3start", "Bonus3 Start");
		AddMenuItem(menu, "bonus3end", "Bonus3 End");
		AddMenuItem(menu, "back", "Back");
	}
	else if(category == 12)
	{
		AddMenuItem(menu, "bonus4level", "Bonus4 Level");
		AddMenuItem(menu, "bonus4checkpoint", "Bonus4 Checkpoint");
		AddMenuItem(menu, "bonus4start", "Bonus4 Start");
		AddMenuItem(menu, "bonus4end", "Bonus4 End");
		AddMenuItem(menu, "back", "Back");
	}
	else if(category == 13)
	{
		AddMenuItem(menu, "bonus5level", "Bonus5 Level");
		AddMenuItem(menu, "bonus5checkpoint", "Bonus5 Checkpoint");
		AddMenuItem(menu, "bonus5start", "Bonus5 Start");
		AddMenuItem(menu, "bonus5end", "Bonus5 End");
		AddMenuItem(menu, "back", "Back");
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 360);
}

public ZoneTypeSelect(Handle:menu, MenuAction:action, client, itemNum)
{
	if ( action == MenuAction_Select )
	{
		decl String:info[100], String:info2[100];
		new bool:found = GetMenuItem(menu, itemNum, info, sizeof(info), _, info2, sizeof(info2));
		
		if(found)
		{
			new String:ZoneName[32];
			new LvlID;
			new bool:valid = false;
			new MapZoneType:zonetype;
			
			if(StrEqual(info, "adjust"))
			{
				DisplayAdjustZoneMenu(client, 0);
			}
			else if(StrEqual(info, "back"))
			{
				DisplaySelectZoneTypeMenu(client, 0);
			}
			else if(StrEqual(info, "cat_timer"))
			{
				DisplaySelectZoneTypeMenu(client, 1);
			}
			else if(StrEqual(info, "cat_timer_bonus"))
			{
				DisplaySelectZoneTypeMenu(client, 2);
			}
			else if(StrEqual(info, "cat_timer_other"))
			{
				DisplaySelectZoneTypeMenu(client, 3);
			}
			else if(StrEqual(info, "cat_physics"))
			{
				DisplaySelectZoneTypeMenu(client, 4);
			}
			else if(StrEqual(info, "cat_teleport"))
			{
				DisplaySelectZoneTypeMenu(client, 5);
			}
			else if(StrEqual(info, "cat_control"))
			{
				DisplaySelectZoneTypeMenu(client, 6);
			}
			else if(StrEqual(info, "cat_speed"))
			{
				DisplaySelectZoneTypeMenu(client, 7);
			}
			else if(StrEqual(info, "cat_block"))
			{
				DisplaySelectZoneTypeMenu(client, 8);
			}
			else if(StrEqual(info, "cat_other"))
			{
				DisplaySelectZoneTypeMenu(client, 9);
			}
			else if(StrEqual(info, "cat_timer_bonus2"))
			{
				DisplaySelectZoneTypeMenu(client, 10);
			}
			else if(StrEqual(info, "cat_timer_bonus3"))
			{
				DisplaySelectZoneTypeMenu(client, 11);
			}
			else if(StrEqual(info, "cat_timer_bonus4"))
			{
				DisplaySelectZoneTypeMenu(client, 12);
			}
			else if(StrEqual(info, "cat_timer_bonus5"))
			{
				DisplaySelectZoneTypeMenu(client, 13);
			}
			else if(StrEqual(info, "start"))
			{
				zonetype = ZtStart;
				ZoneName = "Start";
				LvlID = LEVEL_START;
				valid = true;
			}
			else if(StrEqual(info, "end"))
			{
				zonetype = ZtEnd;
				ZoneName = "End";
				LvlID = LEVEL_END;
				valid = true;
			}
			else if(StrEqual(info, "stop"))
			{
				zonetype = ZtStop;
				ZoneName = "Stop Timer";
				valid = true;
			}
			else if(StrEqual(info, "restart"))
			{
				zonetype = ZtRestart;
				ZoneName = "Restart Timer";
				valid = true;
			}
			else if(StrEqual(info, "last"))
			{
				zonetype = ZtLast;
				ZoneName = "Tele Last Level";
				valid = true;
			}
			else if(StrEqual(info, "next"))
			{
				zonetype = ZtNext;
				ZoneName = "Tele Next Level";
				valid = true;
			}
			else if(StrEqual(info, "level"))
			{
				zonetype = ZtLevel;
				new String:lvlbuffer[32];
				
				new hcount = LEVEL_START;
				for (new zone = 0; zone < g_mapZonesCount; zone++)
				{
					if(g_mapZones[zone][Type] != ZtLevel && g_mapZones[zone][Type] != ZtCheckpoint) continue;
					if(g_mapZones[zone][Level_Id] <= hcount) continue;
					hcount = g_mapZones[zone][Level_Id];
				}
				hcount++;
				
				FormatEx(lvlbuffer, sizeof(lvlbuffer), "Stage %d", hcount);
				
				LvlID = hcount;
				ZoneName = lvlbuffer;
				valid = true;
			}
			else if(StrEqual(info, "checkpoint"))
			{
				zonetype = ZtCheckpoint;
				new String:lvlbuffer[32];
				
				new hcount = LEVEL_START;
				for (new zone = 0; zone < g_mapZonesCount; zone++)
				{
					if(g_mapZones[zone][Type] != ZtLevel && g_mapZones[zone][Type] != ZtCheckpoint) continue;
					if(g_mapZones[zone][Level_Id] <= hcount) continue;
					hcount = g_mapZones[zone][Level_Id];
				}
				hcount++;
				
				FormatEx(lvlbuffer, sizeof(lvlbuffer), "Checkpoint %d", hcount);
				
				LvlID = hcount;
				ZoneName = lvlbuffer;
				valid = true;
			}
			else if(StrEqual(info, "bonusstart"))
			{
				zonetype = ZtBonusStart;
				ZoneName = "BonusStart";
				LvlID = LEVEL_BONUS_START;
				valid = true;
			}
			else if(StrEqual(info, "bonusend"))
			{
				zonetype = ZtBonusEnd;
				ZoneName = "BonusEnd";
				LvlID = LEVEL_BONUS_END;
				valid = true;
			}
			else if(StrEqual(info, "bonus2start"))
			{
				zonetype = ZtBonus2Start;
				ZoneName = "Bonus2Start";
				LvlID = LEVEL_BONUS2_START;
				valid = true;
			}
			else if(StrEqual(info, "bonus2end"))
			{
				zonetype = ZtBonus2End;
				ZoneName = "Bonus2End";
				LvlID = LEVEL_BONUS2_END;
				valid = true;
			}
			else if(StrEqual(info, "bonus3start"))
			{
				zonetype = ZtBonus3Start;
				ZoneName = "Bonus3Start";
				LvlID = LEVEL_BONUS3_START;
				valid = true;
			}
			else if(StrEqual(info, "bonus3end"))
			{
				zonetype = ZtBonus3End;
				ZoneName = "Bonus3End";
				LvlID = LEVEL_BONUS3_END;
				valid = true;
			}
			else if(StrEqual(info, "bonus4start"))
			{
				zonetype = ZtBonus4Start;
				ZoneName = "Bonus4Start";
				LvlID = LEVEL_BONUS4_START;
				valid = true;
			}
			else if(StrEqual(info, "bonus4end"))
			{
				zonetype = ZtBonus4End;
				ZoneName = "Bonus4End";
				LvlID = LEVEL_BONUS4_END;
				valid = true;
			}
			else if(StrEqual(info, "bonus5start"))
			{
				zonetype = ZtBonus5Start;
				ZoneName = "Bonus5Start";
				LvlID = LEVEL_BONUS5_START;
				valid = true;
			}
			else if(StrEqual(info, "bonus5end"))
			{
				zonetype = ZtBonus5End;
				ZoneName = "Bonus5End";
				LvlID = LEVEL_BONUS5_END;
				valid = true;
			}
			else if(StrEqual(info, "bonuscheckpoint"))
			{
				zonetype = ZtBonusCheckpoint;
				new String:lvlbuffer[32];
				
				new hcount = LEVEL_BONUS_START;
				for (new zone = 0; zone < g_mapZonesCount; zone++)
				{
					if(g_mapZones[zone][Type] != ZtBonusCheckpoint && g_mapZones[zone][Type] != ZtBonusLevel) continue;
					if(g_mapZones[zone][Level_Id] <= hcount) continue;
					hcount = g_mapZones[zone][Level_Id];
				}
				hcount++;
				
				FormatEx(lvlbuffer, sizeof(lvlbuffer), "Bonus-Checkpoint %d", hcount);
				
				LvlID = hcount;
				ZoneName = lvlbuffer;
				valid = true;
			}
			else if(StrEqual(info, "bonuslevel"))
			{
				zonetype = ZtBonusCheckpoint;
				new String:lvlbuffer[32];
				
				new hcount = LEVEL_BONUS_START;
				for (new zone = 0; zone < g_mapZonesCount; zone++)
				{
					if(g_mapZones[zone][Type] != ZtBonusCheckpoint && g_mapZones[zone][Type] != ZtBonusLevel) continue;
					if(g_mapZones[zone][Level_Id] <= hcount) continue;
					hcount = g_mapZones[zone][Level_Id];
				}
				hcount++;
				
				FormatEx(lvlbuffer, sizeof(lvlbuffer), "Bonus-Stage %d", hcount);
				
				LvlID = hcount;
				ZoneName = lvlbuffer;
				valid = true;
			}
			else if(StrEqual(info, "bonus2checkpoint"))
			{
				zonetype = ZtBonus2Checkpoint;
				new String:lvlbuffer[32];
				
				new hcount = LEVEL_BONUS2_START;
				for (new zone = 0; zone < g_mapZonesCount; zone++)
				{
					if(g_mapZones[zone][Type] != ZtBonus2Checkpoint && g_mapZones[zone][Type] != ZtBonus2Level) continue;
					if(g_mapZones[zone][Level_Id] <= hcount) continue;
					hcount = g_mapZones[zone][Level_Id];
				}
				hcount++;
				
				FormatEx(lvlbuffer, sizeof(lvlbuffer), "Bonus2-Checkpoint %d", hcount);
				
				LvlID = hcount;
				ZoneName = lvlbuffer;
				valid = true;
			}
			else if(StrEqual(info, "bonus2level"))
			{
				zonetype = ZtBonus2Checkpoint;
				new String:lvlbuffer[32];
				
				new hcount = LEVEL_BONUS2_START;
				for (new zone = 0; zone < g_mapZonesCount; zone++)
				{
					if(g_mapZones[zone][Type] != ZtBonus2Checkpoint && g_mapZones[zone][Type] != ZtBonus2Level) continue;
					if(g_mapZones[zone][Level_Id] <= hcount) continue;
					hcount = g_mapZones[zone][Level_Id];
				}
				hcount++;
				
				FormatEx(lvlbuffer, sizeof(lvlbuffer), "Bonus2-Stage %d", hcount);
				
				LvlID = hcount;
				ZoneName = lvlbuffer;
				valid = true;
			}
			else if(StrEqual(info, "bonus3checkpoint"))
			{
				zonetype = ZtBonus3Checkpoint;
				new String:lvlbuffer[32];
				
				new hcount = LEVEL_BONUS3_START;
				for (new zone = 0; zone < g_mapZonesCount; zone++)
				{
					if(g_mapZones[zone][Type] != ZtBonus3Checkpoint && g_mapZones[zone][Type] != ZtBonus3Level) continue;
					if(g_mapZones[zone][Level_Id] <= hcount) continue;
					hcount = g_mapZones[zone][Level_Id];
				}
				hcount++;
				
				FormatEx(lvlbuffer, sizeof(lvlbuffer), "Bonus3-Checkpoint %d", hcount);
				
				LvlID = hcount;
				ZoneName = lvlbuffer;
				valid = true;
			}
			else if(StrEqual(info, "bonus3level"))
			{
				zonetype = ZtBonus3Checkpoint;
				new String:lvlbuffer[32];
				
				new hcount = LEVEL_BONUS3_START;
				for (new zone = 0; zone < g_mapZonesCount; zone++)
				{
					if(g_mapZones[zone][Type] != ZtBonus3Checkpoint && g_mapZones[zone][Type] != ZtBonus3Level) continue;
					if(g_mapZones[zone][Level_Id] <= hcount) continue;
					hcount = g_mapZones[zone][Level_Id];
				}
				hcount++;
				
				FormatEx(lvlbuffer, sizeof(lvlbuffer), "Bonus3-Stage %d", hcount);
				
				LvlID = hcount;
				ZoneName = lvlbuffer;
				valid = true;
			}
			else if(StrEqual(info, "bonus4checkpoint"))
			{
				zonetype = ZtBonus4Checkpoint;
				new String:lvlbuffer[32];
				
				new hcount = LEVEL_BONUS4_START;
				for (new zone = 0; zone < g_mapZonesCount; zone++)
				{
					if(g_mapZones[zone][Type] != ZtBonus4Checkpoint && g_mapZones[zone][Type] != ZtBonus4Level) continue;
					if(g_mapZones[zone][Level_Id] <= hcount) continue;
					hcount = g_mapZones[zone][Level_Id];
				}
				hcount++;
				
				FormatEx(lvlbuffer, sizeof(lvlbuffer), "Bonus4-Checkpoint %d", hcount);
				
				LvlID = hcount;
				ZoneName = lvlbuffer;
				valid = true;
			}
			else if(StrEqual(info, "bonus4level"))
			{
				zonetype = ZtBonus4Checkpoint;
				new String:lvlbuffer[32];
				
				new hcount = LEVEL_BONUS4_START;
				for (new zone = 0; zone < g_mapZonesCount; zone++)
				{
					if(g_mapZones[zone][Type] != ZtBonus4Checkpoint && g_mapZones[zone][Type] != ZtBonus4Level) continue;
					if(g_mapZones[zone][Level_Id] <= hcount) continue;
					hcount = g_mapZones[zone][Level_Id];
				}
				hcount++;
				
				FormatEx(lvlbuffer, sizeof(lvlbuffer), "Bonus4-Stage %d", hcount);
				
				LvlID = hcount;
				ZoneName = lvlbuffer;
				valid = true;
			}
			else if(StrEqual(info, "bonus5checkpoint"))
			{
				zonetype = ZtBonus5Checkpoint;
				new String:lvlbuffer[32];
				
				new hcount = LEVEL_BONUS5_START;
				for (new zone = 0; zone < g_mapZonesCount; zone++)
				{
					if(g_mapZones[zone][Type] != ZtBonus5Checkpoint && g_mapZones[zone][Type] != ZtBonus5Level) continue;
					if(g_mapZones[zone][Level_Id] <= hcount) continue;
					hcount = g_mapZones[zone][Level_Id];
				}
				hcount++;
				
				FormatEx(lvlbuffer, sizeof(lvlbuffer), "Bonus5-Checkpoint %d", hcount);
				
				LvlID = hcount;
				ZoneName = lvlbuffer;
				valid = true;
			}
			else if(StrEqual(info, "bonus5level"))
			{
				zonetype = ZtBonus5Checkpoint;
				new String:lvlbuffer[32];
				
				new hcount = LEVEL_BONUS5_START;
				for (new zone = 0; zone < g_mapZonesCount; zone++)
				{
					if(g_mapZones[zone][Type] != ZtBonus5Checkpoint && g_mapZones[zone][Type] != ZtBonus5Level) continue;
					if(g_mapZones[zone][Level_Id] <= hcount) continue;
					hcount = g_mapZones[zone][Level_Id];
				}
				hcount++;
				
				FormatEx(lvlbuffer, sizeof(lvlbuffer), "Bonus5-Stage %d", hcount);
				
				LvlID = hcount;
				ZoneName = lvlbuffer;
				valid = true;
			}
			else if(StrEqual(info, "npcnext"))
			{
				FakeClientCommand(client, "sm_npc_next");
			}
			else if(StrEqual(info, "npcnext_double"))
			{
				FakeClientCommand(client, "sm_npc_next");
			}
			else if(StrEqual(info, "block"))
			{
				zonetype = ZtBlock;
				ZoneName = "Block";
				valid = true;
			}
			else if(StrEqual(info, "limit"))
			{
				zonetype = ZtLimitSpeed;
				ZoneName = "LimitSpeed";
				valid = true;
			}
			else if(StrEqual(info, "clip"))
			{
				zonetype = ZtPlayerClip;
				ZoneName = "PlayerClip";
				valid = true;
			}
			else if(StrEqual(info, "longjump"))
			{
				zonetype = ZtLongjump;
				ZoneName = "Longjump";
				valid = true;
			}
			else if(StrEqual(info, "booster"))
			{
				zonetype = ZtBooster;
				ZoneName = "Booster";
				valid = true;
			}
			else if(StrEqual(info, "fullbooster"))
			{
				zonetype = ZtFullBooster;
				ZoneName = "FullBooster";
				valid = true;
			}
			else if(StrEqual(info, "arena"))
			{
				zonetype = ZtArena;
				ZoneName = "Arena";
				valid = true;
			}
			else if(StrEqual(info, "bounceback"))
			{
				zonetype = ZtBounceBack;
				ZoneName = "BounceBack";
				valid = true;
			}
			else if(StrEqual(info, "jail"))
			{
				zonetype = ZtJail;
				ZoneName = "Jail";
				valid = true;
			}
			else if(StrEqual(info, "up"))
			{
				zonetype = ZtPushUp;
				ZoneName = "Push Up";
				valid = true;
			}
			else if(StrEqual(info, "down"))
			{
				zonetype = ZtPushDown;
				ZoneName = "Push Down";
				valid = true;
			}
			else if(StrEqual(info, "north"))
			{
				zonetype = ZtPushNorth;
				ZoneName = "Push North";
				valid = true;
			}
			else if(StrEqual(info, "south"))
			{
				zonetype = ZtPushSouth;
				ZoneName = "Push South";
				valid = true;
			}
			else if(StrEqual(info, "east"))
			{
				zonetype = ZtPushEast;
				ZoneName = "Push East";
				valid = true;
			}
			else if(StrEqual(info, "west"))
			{
				zonetype = ZtPushWest;
				ZoneName = "Push West";
				valid = true;
			}
			else if(StrEqual(info, "auto"))
			{
				zonetype = ZtAuto;
				ZoneName = "Enable Auto Bhop";
				valid = true;
			}
			else if(StrEqual(info, "noauto"))
			{
				zonetype = ZtNoAuto;
				ZoneName = "DisableAuto Bhop";
				valid = true;
			}
			else if(StrEqual(info, "bullettime"))
			{
				zonetype = ZtBulletTime;
				ZoneName = "Bullet Time";
				valid = true;
			}
			else if(StrEqual(info, "nogravity"))
			{
				zonetype = ZtNoGravityOverwrite;
				ZoneName = "No Gravity Overwrite";
				valid = true;
			}
			else if(StrEqual(info, "noboost"))
			{
				zonetype = ZtNoBoost;
				ZoneName = "No Boost";
				valid = true;
			}
			else if(StrEqual(info, "antinoclip"))
			{
				zonetype = ZtAntiNoclip;
				ZoneName = "Anti Noclip";
				valid = true;
			}
			else if(StrEqual(info, "restart_normal"))
			{
				zonetype = ZtRestartNormalTimer;
				ZoneName = "Restart Normal";
				valid = true;
			}
			else if(StrEqual(info, "restart_bonus"))
			{
				zonetype = ZtRestartBonusTimer;
				ZoneName = "Restart Bonust";
				valid = true;
			}
			else if(StrEqual(info, "reset"))
			{
				zonetype = ZtReset;
				ZoneName = "Reset Timer";
				valid = true;
			}
			else if(StrEqual(info, "hover"))
			{
				zonetype = ZtHover;
				ZoneName = "Hover";
				valid = true;
			}
			else if(StrEqual(info, "freestyle"))
			{
				zonetype = ZtFreeStyle;
				ZoneName = "Freestyle Zone";
				valid = true;
			}
			else if(StrEqual(info, "blockuse"))
			{
				zonetype = ZtBlockUse;
				ZoneName = "Block Use";
				valid = true;
			}
			else if(StrEqual(info, "blockduck"))
			{
				zonetype = ZtBlockDuck;
				ZoneName = "Block Duck";
				valid = true;
			}
			else if(StrEqual(info, "blockattack"))
			{
				zonetype = ZtBlockAttack;
				ZoneName = "Block Attack";
				valid = true;
			}
			
			if(valid)
			{
				new Float:point1[3];
				Array_Copy(g_mapZoneEditors[client][Point1], point1, 3);
				
				new Float:point2[3];
				Array_Copy(g_mapZoneEditors[client][Point2], point2, 3);
				
				if(!AddMapZone(g_currentMap, MapZoneType:zonetype, ZoneName, LvlID, point1, point2))
					PrintToChat(client, "[Timer] Can't save mapzone, no database connection.");
				ResetMapZoneEditor(client);
			}
		}
	}
	else if (action == MenuAction_End) 
	{
		CloseHandle(menu);
		ResetMapZoneEditor(client);
	} 
	else if (action == MenuAction_Cancel) 
	{
		if (itemNum == MenuCancel_Exit && hTopMenu != INVALID_HANDLE) 
		{
			DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
			ResetMapZoneEditor(client);
		}
	}
}

public Action:OnTouchTrigger(caller, activator)
{
	if(!g_bZonesLoaded)
		return;
	
	if(g_mapZonesCount < 1)
		return;
	
	if (activator < 1 || activator > MaxClients)
	{
		return;
	}
	
	if (!IsClientInGame(activator))
	{
		return;
	}
	
	if (!IsPlayerAlive(activator))
	{
		return;
	}
	
	new client = activator;
	
	ChangePlayerVelocity(client);
	
	return;
}

public Action:StartTouchTrigger(caller, activator)
{
	if(!g_bZonesLoaded)
		return;
	if(g_mapZonesCount < 1)
		return;
	
	if (activator < 1 || activator > MaxClients)
		return;
	
	if (!IsClientInGame(activator))
		return;
	
	new client = activator;
	
	new Float:vec[3];
	GetClientAbsOrigin(client, vec);
	
	new mate;
	if(g_timerTeams) mate = Timer_GetClientTeammate(client);
	
	new zone = g_MapZoneEntityZID[caller];
	
	if(zone < 0)
		return;
	
	decl String:TriggerName[32]; 
	GetEntPropString(caller, Prop_Data, "m_iName", TriggerName, sizeof(TriggerName));
	
	if(adminmode == 1 && Client_IsAdmin(client))
	{
		PrintCenterText(client, "ID: %d", zone);
		return;
	}
	
	Call_StartForward(g_OnClientStartTouchZoneType);
	Call_PushCell(client);
	Call_PushCell(g_mapZones[zone][Type]);
	Call_Finish();
	
	g_bZone[zone][client] = true;
	
	if (!IsPlayerAlive(activator))
		return;
	
	if (g_mapZones[zone][Type] == ZtReset)
	{
		Timer_Reset(client);
	}
	else if (g_mapZones[zone][Type] == ZtStart)
	{
		if(!g_Settings[NoblockEnable])
			SetPush(client);
		
		if(mate == 0)
		{
			g_iIgnoreEndTouchStart[client] = false;
			g_iClientLastTrackZone[client] = zone;
			
			Timer_Stop(client, false);
			Timer_SetTrack(client, TRACK_NORMAL);
		}
	}
	else if (g_mapZones[zone][Type] == ZtBonusStart)
	{
		g_iIgnoreEndTouchStart[client] = false;
		g_iClientLastTrackZone[client] = zone;
		
		Timer_Stop(client, false);
		Timer_SetTrack(client, TRACK_BONUS);
		
		if(g_timerLjStats) SetLJMode(client, false);
	}
	else if (g_mapZones[zone][Type] == ZtBonus2Start)
	{
		g_iIgnoreEndTouchStart[client] = false;
		g_iClientLastTrackZone[client] = zone;
		
		Timer_Stop(client, false);
		Timer_SetTrack(client, TRACK_BONUS2);
		
		if(g_timerLjStats) SetLJMode(client, false);
	}
	else if (g_mapZones[zone][Type] == ZtBonus3Start)
	{
		g_iIgnoreEndTouchStart[client] = false;
		g_iClientLastTrackZone[client] = zone;
		
		Timer_Stop(client, false);
		Timer_SetTrack(client, TRACK_BONUS3);
		
		if(g_timerLjStats) SetLJMode(client, false);
	}
	else if (g_mapZones[zone][Type] == ZtBonus4Start)
	{
		g_iIgnoreEndTouchStart[client] = false;
		g_iClientLastTrackZone[client] = zone;
		
		Timer_Stop(client, false);
		Timer_SetTrack(client, TRACK_BONUS4);
		
		if(g_timerLjStats) SetLJMode(client, false);
	}
	else if (g_mapZones[zone][Type] == ZtBonus5Start)
	{
		g_iIgnoreEndTouchStart[client] = false;
		g_iClientLastTrackZone[client] = zone;
		
		Timer_Stop(client, false);
		Timer_SetTrack(client, TRACK_BONUS5);
		
		if(g_timerLjStats) SetLJMode(client, false);
	}
	else if (g_mapZones[zone][Type] == ZtEnd)
	{
		if(!g_Settings[NoblockEnable])
			SetPush(client);
		
		if(mate == 0)
		{
			//has player noclip?
			if(GetEntProp(client, Prop_Send, "movetype", 1) == 8)
			{
				Timer_Stop(client, false);
			}
			else if(Timer_GetTrack(client) == TRACK_NORMAL)
			{
				g_iClientLastTrackZone[client] = zone;
				
				if (Timer_Stop(client, false))
				{
					new bool:enabled = false;
					new jumps = 0;
					new Float:time;
					new fpsmax;
					
					if (Timer_GetClientTimer(client, enabled, time, jumps, fpsmax))
					{
						new difficulty = 0;
						if (g_timerPhysics)
							difficulty = Timer_GetStyle(client);
						
						Timer_FinishRound(client, g_currentMap, time, jumps, difficulty, fpsmax, TRACK_NORMAL);
					}
				}
			}
		}
	}
	else if (g_mapZones[zone][Type] == ZtBonusEnd)
	{
		if(mate == 0)
		{
			//has player noclip?
			if(GetEntProp(client, Prop_Send, "movetype", 1) == 8)
			{
				Timer_Stop(client, false);
			}
			else if(Timer_GetTrack(client) == TRACK_BONUS)
			{
				g_iClientLastTrackZone[client] = zone;
				
				if (Timer_Stop(client, false))
				{
					new bool:enabled = false;
					new jumps = 0;
					new Float:time;
					new fpsmax;
					
					if (Timer_GetClientTimer(client, enabled, time, jumps, fpsmax))
					{
						new difficulty = 0;
						if (g_timerPhysics)
							difficulty = Timer_GetStyle(client);
						
						Timer_FinishRound(client, g_currentMap, time, jumps, difficulty, fpsmax, TRACK_BONUS);
					}
				}
			}
		}
	}
	else if (g_mapZones[zone][Type] == ZtBonus2End)
	{
		if(mate == 0)
		{
			//has player noclip?
			if(GetEntProp(client, Prop_Send, "movetype", 1) == 8)
			{
				Timer_Stop(client, false);
			}
			else if(Timer_GetTrack(client) == TRACK_BONUS2)
			{
				g_iClientLastTrackZone[client] = zone;
				
				if (Timer_Stop(client, false))
				{
					new bool:enabled = false;
					new jumps = 0;
					new Float:time;
					new fpsmax;
					
					if (Timer_GetClientTimer(client, enabled, time, jumps, fpsmax))
					{
						new difficulty = 0;
						if (g_timerPhysics)
							difficulty = Timer_GetStyle(client);
						
						Timer_FinishRound(client, g_currentMap, time, jumps, difficulty, fpsmax, TRACK_BONUS2);
					}
				}
			}
		}
	}
	else if (g_mapZones[zone][Type] == ZtBonus3End)
	{
		if(mate == 0)
		{
			//has player noclip?
			if(GetEntProp(client, Prop_Send, "movetype", 1) == 8)
			{
				Timer_Stop(client, false);
			}
			else if(Timer_GetTrack(client) == TRACK_BONUS3)
			{
				g_iClientLastTrackZone[client] = zone;
				
				if (Timer_Stop(client, false))
				{
					new bool:enabled = false;
					new jumps = 0;
					new Float:time;
					new fpsmax;
					
					if (Timer_GetClientTimer(client, enabled, time, jumps, fpsmax))
					{
						new difficulty = 0;
						if (g_timerPhysics)
							difficulty = Timer_GetStyle(client);
						
						Timer_FinishRound(client, g_currentMap, time, jumps, difficulty, fpsmax, TRACK_BONUS3);
					}
				}
			}
		}
	}
	else if (g_mapZones[zone][Type] == ZtBonus4End)
	{
		if(mate == 0)
		{
			//has player noclip?
			if(GetEntProp(client, Prop_Send, "movetype", 1) == 8)
			{
				Timer_Stop(client, false);
			}
			else if(Timer_GetTrack(client) == TRACK_BONUS4)
			{
				g_iClientLastTrackZone[client] = zone;
				
				if (Timer_Stop(client, false))
				{
					new bool:enabled = false;
					new jumps = 0;
					new Float:time;
					new fpsmax;
					
					if (Timer_GetClientTimer(client, enabled, time, jumps, fpsmax))
					{
						new difficulty = 0;
						if (g_timerPhysics)
							difficulty = Timer_GetStyle(client);
						
						Timer_FinishRound(client, g_currentMap, time, jumps, difficulty, fpsmax, TRACK_BONUS4);
					}
				}
			}
		}
	}
	else if (g_mapZones[zone][Type] == ZtBonus5End)
	{
		if(mate == 0)
		{
			//has player noclip?
			if(GetEntProp(client, Prop_Send, "movetype", 1) == 8)
			{
				Timer_Stop(client, false);
			}
			else if(Timer_GetTrack(client) == TRACK_BONUS5)
			{
				g_iClientLastTrackZone[client] = zone;
				
				if (Timer_Stop(client, false))
				{
					new bool:enabled = false;
					new jumps = 0;
					new Float:time;
					new fpsmax;
					
					if (Timer_GetClientTimer(client, enabled, time, jumps, fpsmax))
					{
						new difficulty = 0;
						if (g_timerPhysics)
							difficulty = Timer_GetStyle(client);
						
						Timer_FinishRound(client, g_currentMap, time, jumps, difficulty, fpsmax, TRACK_BONUS5);
					}
				}
			}
		}
	}
	else if (g_mapZones[zone][Type] == ZtStop)
	{
		Timer_Stop(client, true);
	}
	else if (g_mapZones[zone][Type] == ZtRestart)
	{
		if(Timer_GetTrack(client) == TRACK_BONUS) 
		{
			Tele_Level(client, LEVEL_BONUS_START);
		}
		else if(Timer_GetTrack(client) == TRACK_BONUS2) 
		{
			Tele_Level(client, LEVEL_BONUS2_START);
		}
		else if(Timer_GetTrack(client) == TRACK_BONUS3) 
		{
			Tele_Level(client, LEVEL_BONUS3_START);
		}
		else if(Timer_GetTrack(client) == TRACK_BONUS4) 
		{
			Tele_Level(client, LEVEL_BONUS4_START);
		}
		else if(Timer_GetTrack(client) == TRACK_BONUS5) 
		{
			Tele_Level(client, LEVEL_BONUS5_START);
		}
		else
		{
			Tele_Level(client, LEVEL_START);
		}
	}
	else if (g_mapZones[zone][Type] == ZtRestartNormalTimer)
	{
		if(Timer_GetTrack(client) == TRACK_NORMAL) 
		{
			Tele_Level(client, LEVEL_START);
		}
	}
	else if (g_mapZones[zone][Type] == ZtRestartBonusTimer)
	{
		if(Timer_GetTrack(client) == TRACK_BONUS) 
		{
			Tele_Level(client, LEVEL_BONUS_START);
		}
		else if(Timer_GetTrack(client) == TRACK_BONUS2) 
		{
			Tele_Level(client, LEVEL_BONUS2_START);
		}
		else if(Timer_GetTrack(client) == TRACK_BONUS3) 
		{
			Tele_Level(client, LEVEL_BONUS3_START);
		}
		else if(Timer_GetTrack(client) == TRACK_BONUS4) 
		{
			Tele_Level(client, LEVEL_BONUS4_START);
		}
		else if(Timer_GetTrack(client) == TRACK_BONUS5) 
		{
			Tele_Level(client, LEVEL_BONUS5_START);
		}
	}
	else if (g_mapZones[zone][Type] == ZtLast)
	{
		new lowestcheckpoint = g_mapZones[g_iClientLastTrackZone[client]][Level_Id];
		
		if(0 < mate && IsClientInGame(mate) && IsPlayerAlive(mate)) 
		{
			if(g_iClientLastTrackZone[client] > g_iClientLastTrackZone[mate]) lowestcheckpoint = g_mapZones[g_iClientLastTrackZone[mate]][Level_Id];
			
			Tele_Level(client, lowestcheckpoint);
			Tele_Level(mate, lowestcheckpoint);
			
			if(Client_IsValid(client, true)) EmitSoundToClient(client, SND_TELE_LAST);
			if(Client_IsValid(mate, true)) EmitSoundToClient(mate, SND_TELE_LAST);
		}
		else
		{
			if(Client_IsValid(client, true)) EmitSoundToClient(client, SND_TELE_LAST);
			Tele_Level(client, lowestcheckpoint);
		}
	}
	else if (g_mapZones[zone][Type] == ZtNext)
	{
		if(0 < mate && IsClientInGame(mate) && IsPlayerAlive(mate) && g_mapZones[g_iClientLastTrackZone[client]][Level_Id] == g_mapZones[g_iClientLastTrackZone[mate]][Level_Id])
		{
			Tele_Level(client, g_mapZones[g_iClientLastTrackZone[client]][Level_Id]+1);
			Tele_Level(mate, g_mapZones[g_iClientLastTrackZone[client]][Level_Id]+1);
			if(Client_IsValid(client, true)) EmitSoundToClient(client, SND_TELE_NEXT);
			if(Client_IsValid(mate, true)) EmitSoundToClient(mate, SND_TELE_NEXT);
		}
		else
		{
			Tele_Level(client, g_mapZones[g_iClientLastTrackZone[client]][Level_Id]+1);
			if(Client_IsValid(client, true)) EmitSoundToClient(client, SND_TELE_NEXT);
		}
		
	}
	else if (g_mapZones[zone][Type] == ZtLevel)
	{
		if(Timer_GetTrack(client) == TRACK_NORMAL)
		{
			new lastlevel = g_mapZones[g_iClientLastTrackZone[client]][Level_Id];
			g_iClientLastTrackZone[client] = zone;
			
			Call_StartForward(g_OnClientStartTouchLevel);
			Call_PushCell(client);
			Call_PushCell(g_mapZones[g_iClientLastTrackZone[client]][Level_Id]);
			Call_PushCell(lastlevel);
			Call_Finish();
		}
	}
	else if (g_mapZones[zone][Type] == ZtCheckpoint)
	{
		if(Timer_GetTrack(client) == TRACK_NORMAL)
		{
			new lastlevel = g_mapZones[g_iClientLastTrackZone[client]][Level_Id];
			g_iClientLastTrackZone[client] = zone;
			
			Call_StartForward(g_OnClientStartTouchLevel);
			Call_PushCell(client);
			Call_PushCell(g_mapZones[g_iClientLastTrackZone[client]][Level_Id]);
			Call_PushCell(lastlevel);
			Call_Finish();
		}
	}
	else if (g_mapZones[zone][Type] == ZtBonusLevel)
	{
		if(Timer_GetTrack(client) == TRACK_BONUS)
		{
			new lastlevel = g_mapZones[g_iClientLastTrackZone[client]][Level_Id];
			g_iClientLastTrackZone[client] = zone;
			
			Call_StartForward(g_OnClientStartTouchBonusLevel);
			Call_PushCell(client);
			Call_PushCell(g_mapZones[g_iClientLastTrackZone[client]][Level_Id]);
			Call_PushCell(lastlevel);
			Call_Finish();
		}
	}
	else if (g_mapZones[zone][Type] == ZtBonusCheckpoint)
	{
		if(Timer_GetTrack(client) == TRACK_BONUS)
		{
			new lastlevel = g_mapZones[g_iClientLastTrackZone[client]][Level_Id];
			g_iClientLastTrackZone[client] = zone;
			
			Call_StartForward(g_OnClientStartTouchBonusLevel);
			Call_PushCell(client);
			Call_PushCell(g_mapZones[g_iClientLastTrackZone[client]][Level_Id]);
			Call_PushCell(lastlevel);
			Call_Finish();
		}
	}
	else if (g_mapZones[zone][Type] == ZtBonus2Level)
	{
		if(Timer_GetTrack(client) == TRACK_BONUS2)
		{
			new lastlevel = g_mapZones[g_iClientLastTrackZone[client]][Level_Id];
			g_iClientLastTrackZone[client] = zone;
			
			Call_StartForward(g_OnClientStartTouchBonusLevel);
			Call_PushCell(client);
			Call_PushCell(g_mapZones[g_iClientLastTrackZone[client]][Level_Id]);
			Call_PushCell(lastlevel);
			Call_Finish();
		}
	}
	else if (g_mapZones[zone][Type] == ZtBonus2Checkpoint)
	{
		if(Timer_GetTrack(client) == TRACK_BONUS2)
		{
			new lastlevel = g_mapZones[g_iClientLastTrackZone[client]][Level_Id];
			g_iClientLastTrackZone[client] = zone;
			
			Call_StartForward(g_OnClientStartTouchBonusLevel);
			Call_PushCell(client);
			Call_PushCell(g_mapZones[g_iClientLastTrackZone[client]][Level_Id]);
			Call_PushCell(lastlevel);
			Call_Finish();
		}
	}
	else if (g_mapZones[zone][Type] == ZtBonus3Level)
	{
		if(Timer_GetTrack(client) == TRACK_BONUS3)
		{
			new lastlevel = g_mapZones[g_iClientLastTrackZone[client]][Level_Id];
			g_iClientLastTrackZone[client] = zone;
			
			Call_StartForward(g_OnClientStartTouchBonusLevel);
			Call_PushCell(client);
			Call_PushCell(g_mapZones[g_iClientLastTrackZone[client]][Level_Id]);
			Call_PushCell(lastlevel);
			Call_Finish();
		}
	}
	else if (g_mapZones[zone][Type] == ZtBonus3Checkpoint)
	{
		if(Timer_GetTrack(client) == TRACK_BONUS3)
		{
			new lastlevel = g_mapZones[g_iClientLastTrackZone[client]][Level_Id];
			g_iClientLastTrackZone[client] = zone;
			
			Call_StartForward(g_OnClientStartTouchBonusLevel);
			Call_PushCell(client);
			Call_PushCell(g_mapZones[g_iClientLastTrackZone[client]][Level_Id]);
			Call_PushCell(lastlevel);
			Call_Finish();
		}
	}
	else if (g_mapZones[zone][Type] == ZtBonus4Level)
	{
		if(Timer_GetTrack(client) == TRACK_BONUS4)
		{
			new lastlevel = g_mapZones[g_iClientLastTrackZone[client]][Level_Id];
			g_iClientLastTrackZone[client] = zone;
			
			Call_StartForward(g_OnClientStartTouchBonusLevel);
			Call_PushCell(client);
			Call_PushCell(g_mapZones[g_iClientLastTrackZone[client]][Level_Id]);
			Call_PushCell(lastlevel);
			Call_Finish();
		}
	}
	else if (g_mapZones[zone][Type] == ZtBonus4Checkpoint)
	{
		if(Timer_GetTrack(client) == TRACK_BONUS4)
		{
			new lastlevel = g_mapZones[g_iClientLastTrackZone[client]][Level_Id];
			g_iClientLastTrackZone[client] = zone;
			
			Call_StartForward(g_OnClientStartTouchBonusLevel);
			Call_PushCell(client);
			Call_PushCell(g_mapZones[g_iClientLastTrackZone[client]][Level_Id]);
			Call_PushCell(lastlevel);
			Call_Finish();
		}
	}
	else if (g_mapZones[zone][Type] == ZtBonus5Level)
	{
		if(Timer_GetTrack(client) == TRACK_BONUS5)
		{
			new lastlevel = g_mapZones[g_iClientLastTrackZone[client]][Level_Id];
			g_iClientLastTrackZone[client] = zone;
			
			Call_StartForward(g_OnClientStartTouchBonusLevel);
			Call_PushCell(client);
			Call_PushCell(g_mapZones[g_iClientLastTrackZone[client]][Level_Id]);
			Call_PushCell(lastlevel);
			Call_Finish();
		}
	}
	else if (g_mapZones[zone][Type] == ZtBonus5Checkpoint)
	{
		if(Timer_GetTrack(client) == TRACK_BONUS5)
		{
			new lastlevel = g_mapZones[g_iClientLastTrackZone[client]][Level_Id];
			g_iClientLastTrackZone[client] = zone;
			
			Call_StartForward(g_OnClientStartTouchBonusLevel);
			Call_PushCell(client);
			Call_PushCell(g_mapZones[g_iClientLastTrackZone[client]][Level_Id]);
			Call_PushCell(lastlevel);
			Call_Finish();
		}
	}
	else if (g_mapZones[zone][Type] == ZtBlock)
	{
		if(g_Settings[NoblockEnable])
			SetBlock(client);
		else SetNoBlock(client);
	}
	else if (g_mapZones[zone][Type] == ZtLongjump)
	{
		if(g_timerLjStats) SetLJMode(client, true);
	}
	else if (g_mapZones[zone][Type] == ZtBooster)
	{
		CheckVelocity(client, 3, 10000.0);
	}
	else if (g_mapZones[zone][Type] == ZtBounceBack)
	{
		CheckVelocity(client, 2, 10000.0);
	}
	else if (g_mapZones[zone][Type] == ZtBulletTime)
	{
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.7);
	}
	
	return;
}

public Action:EndTouchTrigger(caller, activator)
{
	if(!g_bZonesLoaded)
		return;
	
	if(g_mapZonesCount < 1)
		return;
	
	if (activator < 1 || activator > MaxClients)
		return;
	
	if (!IsClientInGame(activator))
		return;
	
	new client = activator;
	
	new Float:vec[3];
	GetClientAbsOrigin(client, vec);
	
	new mate;
	if(g_timerTeams) mate = Timer_GetClientTeammate(client);
	
	new zone = g_MapZoneEntityZID[caller];
	
	if(zone < 0)
		return;
	
	decl String:TriggerName[32]; 
	GetEntPropString(caller, Prop_Data, "m_iName", TriggerName, sizeof(TriggerName));
	
	if(adminmode == 1 && Client_IsAdmin(client))
	{
		if(GetGameMod() == MOD_CSGO)
		{
			PrintHintText(client, "ID: %d", zone);
		}
		else PrintCenterText(client, "ID: %d", zone);
		return;
	}
	
	Call_StartForward(g_OnClientEndTouchZoneType);
	Call_PushCell(client);
	Call_PushCell(g_mapZones[zone][Type]);
	Call_Finish();
	
	g_bZone[zone][client] = false;
	
	if (!IsPlayerAlive(activator))
		return;
	
	if(Timer_GetForceStyle() && !Timer_GetPickedStyle(client))
	{
		if(GetGameTime()-g_fSpawnTime[client] > 0.5)
			Tele_Level(client, LEVEL_START);
		
		FakeClientCommand(client, "sm_style");
		CPrintToChat(client, "%t", "Force Mode");
	}
	
	if(g_mapZones[zone][Type] == ZtEnd)
	{
		if(!g_Settings[NoblockEnable])
			SetBlock(client);
	}
	else if(g_mapZones[zone][Type] == ZtStart)
	{
		if(!g_Settings[NoblockEnable])
			SetBlock(client);
		
		if(mate == 0 && CheckIllegalTeleport(client))
		{
			if(Timer_IsPlayerTouchingZoneType(client, ZtStop))
				return;
			
			if(GetEntProp(client, Prop_Send, "movetype", 1) == 8)
				return;
			
			if(g_iIgnoreEndTouchStart[client])
			{
				g_iIgnoreEndTouchStart[client] = false;
				return;
			}
			
			if(IsClientConnected(client))
				EmitSoundToClient(client, SND_TIMER_START);
			
			Timer_Restart(client);
			Timer_SetTrack(client, TRACK_NORMAL);
		}
	}
	else if(g_mapZones[zone][Type] == ZtBonusStart)
	{
		if(Timer_IsPlayerTouchingZoneType(client, ZtStop) || !CheckIllegalTeleport(client))
			return;
		
		if(GetEntProp(client, Prop_Send, "movetype", 1) == 8)
			return;
		
		if(g_iIgnoreEndTouchStart[client])
		{
			g_iIgnoreEndTouchStart[client] = false;
			return;
		}
		if(IsClientConnected(client)) EmitSoundToClient(client, SND_TIMER_START);
		Timer_Restart(client);
		Timer_SetTrack(client, TRACK_BONUS);
	}
	else if(g_mapZones[zone][Type] == ZtBonus2Start)
	{
		if(Timer_IsPlayerTouchingZoneType(client, ZtStop) || !CheckIllegalTeleport(client))
			return;
		
		if(GetEntProp(client, Prop_Send, "movetype", 1) == 8)
			return;
		
		if(g_iIgnoreEndTouchStart[client])
		{
			g_iIgnoreEndTouchStart[client] = false;
			return;
		}
		if(IsClientConnected(client)) EmitSoundToClient(client, SND_TIMER_START);
		Timer_Restart(client);
		Timer_SetTrack(client, TRACK_BONUS2);
	}
	else if(g_mapZones[zone][Type] == ZtBonus3Start)
	{
		if(Timer_IsPlayerTouchingZoneType(client, ZtStop) || !CheckIllegalTeleport(client))
			return;
		
		if(GetEntProp(client, Prop_Send, "movetype", 1) == 8)
			return;
		
		if(g_iIgnoreEndTouchStart[client])
		{
			g_iIgnoreEndTouchStart[client] = false;
			return;
		}
		if(IsClientConnected(client)) EmitSoundToClient(client, SND_TIMER_START);
		Timer_Restart(client);
		Timer_SetTrack(client, TRACK_BONUS3);
	}
	else if(g_mapZones[zone][Type] == ZtBonus4Start)
	{
		if(Timer_IsPlayerTouchingZoneType(client, ZtStop) || !CheckIllegalTeleport(client))
			return;
		
		if(GetEntProp(client, Prop_Send, "movetype", 1) == 8)
			return;
		
		if(g_iIgnoreEndTouchStart[client])
		{
			g_iIgnoreEndTouchStart[client] = false;
			return;
		}
		if(IsClientConnected(client)) EmitSoundToClient(client, SND_TIMER_START);
		Timer_Restart(client);
		Timer_SetTrack(client, TRACK_BONUS4);
	}
	else if(g_mapZones[zone][Type] == ZtBonus5Start)
	{
		if(Timer_IsPlayerTouchingZoneType(client, ZtStop) || !CheckIllegalTeleport(client))
			return;
		
		if(GetEntProp(client, Prop_Send, "movetype", 1) == 8)
			return;
		
		if(g_iIgnoreEndTouchStart[client])
		{
			g_iIgnoreEndTouchStart[client] = false;
			return;
		}
		if(IsClientConnected(client)) EmitSoundToClient(client, SND_TIMER_START);
		Timer_Restart(client);
		Timer_SetTrack(client, TRACK_BONUS5);
	}
	else if (g_mapZones[zone][Type] == ZtBlock)
	{
		if(g_Settings[NoblockEnable])
			SetNoBlock(client);
		else SetBlock(client);
	}
	else if (g_mapZones[zone][Type] == ZtLongjump)
	{
		if(g_timerLjStats) SetLJMode(client, false);
	}
	else if (g_mapZones[zone][Type] == ZtJail)
	{
		Tele_Zone(client, zone);
	}
	else if (g_mapZones[zone][Type] == ZtBulletTime)
	{
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
	}
	
	return;
}  

public Action:NPC_Use(caller, activator)
{
	decl Float:camangle[3], Float:vecClient[3], Float:vecCaller[3];
	
	decl Float:vec[3];
	Entity_GetAbsOrigin(caller, vecCaller);
	GetClientAbsOrigin(activator, vecClient);   
	
	MakeVectorFromPoints(vecCaller, vecClient, vec);
	GetVectorAngles(vec, camangle);
	camangle[0] = 0.0;
	camangle[2] = 0.0;
	
	TeleportEntity(caller, NULL_VECTOR, camangle, NULL_VECTOR);
	
	for (new i = 0; i < g_mapZonesCount; i++)
	{
		if(g_mapZones[i][NPC] == caller)
		{
			g_iClientLastTrackZone[activator] = i;
			
			Menu_NPC_Next(activator, i);
			
			break;
		}
	}
	
	SetEntData(caller, g_ioffsCollisionGroup, 17, 4, true);
	CreateTimer(0.5, SetBlockable, caller, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Continue;
}

public OnConfigsExecuted()
{
	//Sounds
	CacheSounds();
	
	//Sprites
	GetConVarString(g_BeamDefaultPath, g_sBeamDefaultPath, sizeof(g_sBeamDefaultPath));
	
	InitZoneSprites();
}

CacheSounds()
{
	GetConVarString(Sound_TeleLast, SND_TELE_LAST, sizeof(SND_TELE_LAST));
	PrepareSound(SND_TELE_LAST);
	
	GetConVarString(Sound_TeleNext, SND_TELE_NEXT, sizeof(SND_TELE_NEXT));
	PrepareSound(SND_TELE_NEXT);
	
	GetConVarString(Sound_TimerStart, SND_TIMER_START, sizeof(SND_TIMER_START));
	PrepareSound(SND_TIMER_START);
}

public PrepareSound(String: sound[MAX_FILE_LEN])
{
	decl String:fileSound[MAX_FILE_LEN];
	
	FormatEx(fileSound, MAX_FILE_LEN, "sound/%s", sound);
	
	if (FileExists(fileSound))
	{
		PrecacheSound(sound, true);
		AddFileToDownloadsTable(fileSound);
	}
	else
	{
		PrintToServer("[Timer] ERROR: File '%s' not found!", fileSound);
	}
}

InitZoneSprites()
{
	new String:spritebuffer[256];
	
	//default sprite
	GetConVarString(g_BeamDefaultPath, g_sBeamDefaultPath, sizeof(g_sBeamDefaultPath));
	Format(spritebuffer, sizeof(spritebuffer), "%s.vmt", g_sBeamDefaultPath);
	
	precache_laser_default = PrecacheModel(spritebuffer);
	AddFileToDownloadsTable(spritebuffer);
	Format(spritebuffer, sizeof(spritebuffer), "%s.vtf", g_sBeamDefaultPath);
	AddFileToDownloadsTable(spritebuffer);
	
}

public Action:CheckEntitysLoaded(Handle:timer)
{
	if(GetZoneEntityCount() < g_mapZonesCount)
	{
		if (g_hSQL == INVALID_HANDLE)
			ConnectSQL();
		
		if (g_hSQL != INVALID_HANDLE)
		{
			Timer_LogInfo("No mapzone entitys spawned, reloading...");
			LoadMapZones();
		}
		
		CreateTimer(4.0, CheckEntitysLoaded, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	return Plugin_Stop;
}

public OnClientDisconnect_Post(client)
{
	g_iIgnoreEndTouchStart[client] = 0;
	g_iTargetNPC[client] = 0;
	Timer_Resume(client);
	Timer_Stop(client, false);
}

//Credits to 1NutWunDeR
public Action:CheckRemainingTime(Handle:timer)
{
	new Handle:hTmp;	
	hTmp = FindConVar("mp_timelimit");
	new iTimeLimit = GetConVarInt(hTmp);			
	if (hTmp != INVALID_HANDLE)
		CloseHandle(hTmp);	
	if (iTimeLimit > 0)
	{
		new timeleft;
		GetMapTimeLeft(timeleft);
		
		new tier;
		if(g_timerMapTier)
			tier = Timer_GetTier(TRACK_NORMAL);
		
		decl String:sTier[32];
		Format(sTier, sizeof(sTier), " Map Tier: %d", tier);
		
		if(GetEngineVersion() == Engine_CSGO)
		{
			switch(timeleft)
			{
				case 1800: 	{CPrintToChatAll("%t", "Current Map", g_currentMap); CPrintToChatAll("%t", "Time Remaining", 1800/60);}
				case 1200: 	{CPrintToChatAll("%t", "Current Map", g_currentMap); CPrintToChatAll("%t", "Time Remaining", 1200/60);}
				case 600: 	{CPrintToChatAll("%t", "Current Map", g_currentMap); CPrintToChatAll("%t", "Time Remaining", 600/60);}
				case 300: 	{CPrintToChatAll("%t", "Current Map", g_currentMap); CPrintToChatAll("%t", "Time Remaining", 300/60);}
				case 120: 	{CPrintToChatAll("%t", "Current Map", g_currentMap); CPrintToChatAll("%t", "Time Remaining", 120/60);}
				case 60: 	{CPrintToChatAll("%t", "Current Map", g_currentMap); CPrintToChatAll("%t", "Time Remaining2", 60);}
				case 30: 	{CPrintToChatAll("%t", "Current Map", g_currentMap); CPrintToChatAll("%t", "Time Remaining2", 30);}
				case 15: 	{CPrintToChatAll("%t", "Current Map", g_currentMap); CPrintToChatAll("%t", "Time Remaining2", 15);}
				case -1: 	CPrintToChatAll("[{GREEN}TIMER{NORMAL}] {PINK}3..");
				case -2: 	CPrintToChatAll("[{GREEN}TIMER{NORMAL}] {PINK}2..");
				case -3:
				{
					CPrintToChatAll("[{GREEN}TIMER{NORMAL}] {PINK}1..");
					CreateTimer(1.0, TerminateRoundTimer, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);				
				}
			}
		}
	}
}

public Action:TerminateRoundTimer(Handle:timer)
{
	// Force round end
	if(g_Settings[mp_ignore_round_win_conditions]) ServerCommand("mp_ignore_round_win_conditions 0");
	g_bAllowRoundEnd = true;
	if(Team_GetClientCount(CS_TEAM_CT))
		CS_TerminateRound(1.0, CSRoundEnd_CTWin, true);
	else if(Team_GetClientCount(CS_TEAM_T))
		CS_TerminateRound(1.0, CSRoundEnd_TerroristWin, true);
	else CS_TerminateRound(1.0, CSRoundEnd_Draw, true);
}

public Action:CS_OnTerminateRound(&Float:delay, &CSRoundEndReason:reason)
{
	// Allow round end this time
	if(g_bAllowRoundEnd)
	{
		g_bAllowRoundEnd = false;
		return Plugin_Continue;
	}
	
	// Block round end
	if(g_Settings[mp_ignore_round_win_conditions])
		return Plugin_Handled;
	
	// Let the round end
	return Plugin_Continue;
}

public Action:Event_RoundStart(Handle:event,const String:name[],bool:dontBroadcast)
{
	if (g_hSQL == INVALID_HANDLE)
		ConnectSQL();
	
	if (g_hSQL != INVALID_HANDLE)
		LoadMapZones();
	
	else CreateTimer(3.0, Timer_LoadMapzones, _ , TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_LoadMapzones(Handle:timer, any:data)
{
	if (g_hSQL == INVALID_HANDLE)
		ConnectSQL();
	
	if (g_hSQL != INVALID_HANDLE)
		LoadMapZones();
	
	else CreateTimer(3.0, Timer_LoadMapzones, _ , TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Stop;
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	g_iClientLastTrackZone[client] = 0;
	g_iIgnoreEndTouchStart[client] = 0;
	g_iTargetNPC[client] = 0;
	Timer_Resume(client);
	Timer_Stop(client, false);
	
	for (new i = 0; i <= 127; i++)
	{
		g_bZone[i][client] = false;
	}
	
	if(g_Settings[TeleportOnSpawn])
	{
		// Prevent infinite loop
		if(GetGameTime()-g_fSpawnTime[client] > 0.5)
			Tele_Level(client, LEVEL_START);
	}
	
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		if(g_Settings[NoblockEnable])
			SetNoBlock(client);
		else SetBlock(client);
	}
	
	g_fSpawnTime[client] = GetGameTime();
}

public Action_OnSettingsChange(Handle:cvar, const String:oldvalue[], const String:newvalue[])
{
	if (cvar == Sound_TeleLast)
	{
		FormatEx(SND_TELE_LAST, sizeof(SND_TELE_LAST) ,"%s", newvalue);
	}
	else if (cvar == Sound_TeleNext)
	{
		FormatEx(SND_TELE_NEXT, sizeof(SND_TELE_NEXT) ,"%s", newvalue);
	}
	else if (cvar == Sound_TimerStart)
	{
		FormatEx(SND_TIMER_START, sizeof(SND_TIMER_START) ,"%s", newvalue);
	}
	else if (cvar == g_PreSpeedStart)
	{
		g_bPreSpeedStart = GetConVarBool(g_PreSpeedStart);
	}
	else if (cvar == g_PreSpeedBonusStart)
	{
		g_bPreSpeedBonusStart = GetConVarBool(g_PreSpeedBonusStart);
	}
}

bool:AddMapZone(String:map[], MapZoneType:type, String:name[], level_id, Float:point1[3], Float:point2[3])
{
	if (g_hSQL == INVALID_HANDLE)
		ConnectSQL();
	
	if (g_hSQL != INVALID_HANDLE)
	{
		decl String:query[512];
		
		if ((type == ZtStart && !g_Settings[AllowMultipleStart])
		|| (type == ZtEnd && !g_Settings[AllowMultipleEnd])
		|| (type == ZtBonusStart && !g_Settings[AllowMultipleBonusStart])
		|| (type == ZtBonusEnd && !g_Settings[AllowMultipleBonusEnd]))
		{
			decl String:deleteQuery[256];
			FormatEx(deleteQuery, sizeof(deleteQuery), "DELETE FROM mapzone WHERE map = '%s' AND type = %d;", map, type);
			
			SQL_TQuery(g_hSQL, MapZoneChangedCallback, deleteQuery, _, DBPrio_High);	
		}
		
		//add new zone
		FormatEx(query, sizeof(query), "INSERT INTO mapzone (map, type, name, level_id, point1_x, point1_y, point1_z, point2_x, point2_y, point2_z) VALUES ('%s','%d','%s','%d', %f, %f, %f, %f, %f, %f);", map, type, name, level_id, point1[0], point1[1], point1[2], point2[0], point2[1], point2[2]);
		
		SQL_TQuery(g_hSQL, MapZoneChangedCallback, query, StrEqual(map, g_currentMap), DBPrio_Normal);
		
		return true;
	}
	
	return false;
}

public MapZoneChangedCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		Timer_LogError("SQL Error on AddMapZone: %s", error);
		return;
	}
	
	if(data)
	{
		if(g_timerMapTier)
		{
			Timer_UpdateStageCount(TRACK_NORMAL);
			Timer_UpdateStageCount(TRACK_BONUS);
			Timer_UpdateStageCount(TRACK_BONUS2);
			Timer_UpdateStageCount(TRACK_BONUS3);
			Timer_UpdateStageCount(TRACK_BONUS4);
			Timer_UpdateStageCount(TRACK_BONUS5);
		}
		LoadMapZones();
	}
}

bool:LoadMapZones()
{
	if (g_hSQL != INVALID_HANDLE)
	{
		decl String:query[512];
		FormatEx(query, sizeof(query), "SELECT * FROM mapzone WHERE map = '%s' ORDER BY level_id ASC;", g_currentMap);
		SQL_TQuery(g_hSQL, LoadMapZonesCallback, query, _, DBPrio_High);
		
		//LogMessage("LoadMapZones: %s", query);
		return true;
	}
	
	return false;
}


public LoadMapZonesCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	g_bZonesLoaded = false;
	
	if (hndl == INVALID_HANDLE)
	{
		Timer_LogError("SQL Error on LoadMapZones: %s", error);
		return;
	}
	
	g_mapZonesCount = 0;
	DeleteAllZoneEntitys();
	
	while (SQL_FetchRow(hndl))
	{
		strcopy(g_mapZones[g_mapZonesCount][Map], 64, g_currentMap);
		
		g_mapZones[g_mapZonesCount][Id] = SQL_FetchInt(hndl, 0);
		g_mapZones[g_mapZonesCount][Type] = MapZoneType:SQL_FetchInt(hndl, 1);
		g_mapZones[g_mapZonesCount][Level_Id] = SQL_FetchInt(hndl, 2);
		
		g_mapZones[g_mapZonesCount][Point1][0] = SQL_FetchFloat(hndl, 3);
		g_mapZones[g_mapZonesCount][Point1][1] = SQL_FetchFloat(hndl, 4);
		g_mapZones[g_mapZonesCount][Point1][2] = SQL_FetchFloat(hndl, 5);
		
		g_mapZones[g_mapZonesCount][Point2][0] = SQL_FetchFloat(hndl, 6);
		g_mapZones[g_mapZonesCount][Point2][1] = SQL_FetchFloat(hndl, 7);
		g_mapZones[g_mapZonesCount][Point2][2] = SQL_FetchFloat(hndl, 8);
		
		decl String:ZoneName[32];
		SQL_FetchString(hndl, 10, ZoneName, sizeof(ZoneName));
		FormatEx(g_mapZones[g_mapZonesCount][zName], 32, "%s", ZoneName);
		
		SpawnZoneEntitys(g_mapZonesCount);
		
		/* Forwards */
		Call_StartForward(g_OnMapZoneLoaded);
		Call_PushCell(g_mapZones[g_mapZonesCount][Type]);
		Call_PushCell(g_mapZones[g_mapZonesCount][Level_Id]);
		Call_PushFloat(g_mapZones[g_mapZonesCount][Point1][0]);
		Call_PushFloat(g_mapZones[g_mapZonesCount][Point1][1]);
		Call_PushFloat(g_mapZones[g_mapZonesCount][Point1][2]);
		Call_PushFloat(g_mapZones[g_mapZonesCount][Point2][0]);
		Call_PushFloat(g_mapZones[g_mapZonesCount][Point2][1]);
		Call_PushFloat(g_mapZones[g_mapZonesCount][Point2][2]);
		Call_Finish();
	
		g_mapZonesCount++;
		
		//LogMessage("LoadMapZonesCallback: [%i] - %s", g_mapZonesCount, ZoneName);
	}
	
	g_bZonesLoaded = true;
	
	/* Forwards */
	Call_StartForward(g_OnMapZonesLoaded);
	Call_Finish();
}

public OnTimerSqlConnected(Handle:sql)
{
	g_hSQL = sql;
	g_hSQL = INVALID_HANDLE;
	CreateTimer(0.1, Timer_SQLReconnect, _ , TIMER_FLAG_NO_MAPCHANGE);
}

public OnTimerSqlStop()
{
	g_hSQL = INVALID_HANDLE;
	CreateTimer(0.1, Timer_SQLReconnect, _ , TIMER_FLAG_NO_MAPCHANGE);
}

ConnectSQL()
{
	g_hSQL = Handle:Timer_SqlGetConnection();
	
	if (g_hSQL == INVALID_HANDLE)
		CreateTimer(0.1, Timer_SQLReconnect, _ , TIMER_FLAG_NO_MAPCHANGE);
	else
		LoadMapZones();
}

public Action:Timer_SQLReconnect(Handle:timer, any:data)
{
	ConnectSQL();
	return Plugin_Stop;
}

public OnAdminMenuReady(Handle:topmenu)
{
	// Block this from being called twice
	if (topmenu == hTopMenu) {
		return;
	}
	
	// Save the Handle
	hTopMenu = topmenu;
	
	if ((oMapZoneMenu = FindTopMenuCategory(topmenu, "Timer Zones")) == INVALID_TOPMENUOBJECT)
	{
		oMapZoneMenu = AddToTopMenu(hTopMenu,"Timer Zones",TopMenuObject_Category,AdminMenu_CategoryHandler,INVALID_TOPMENUOBJECT);
	}
	
	AddToTopMenu(hTopMenu, "timer_mapzones_add",TopMenuObject_Item,AdminMenu_AddMapZone,
	oMapZoneMenu,"timer_mapzones_add",ADMFLAG_RCON);
	
	AddToTopMenu(hTopMenu, "timer_mapzones_remove",TopMenuObject_Item,AdminMenu_RemoveMapZone,
	oMapZoneMenu,"timer_mapzones_remove",ADMFLAG_RCON);
	
	AddToTopMenu(hTopMenu, "timer_mapzones_remove_all",TopMenuObject_Item,AdminMenu_RemoveAllMapZones,
	oMapZoneMenu,"timer_mapzones_remove_all",ADMFLAG_RCON);
	
	AddToTopMenu(hTopMenu, "sm_npc_next",TopMenuObject_Item,AdminMenu_NPC,
	oMapZoneMenu,"sm_npc_next",ADMFLAG_RCON);
	
	AddToTopMenu(hTopMenu, "sm_zoneadminmode",TopMenuObject_Item,AdminMenu_AdminMode,
	oMapZoneMenu,"sm_zoneadminmode",ADMFLAG_CHANGEMAP);
	
	AddToTopMenu(hTopMenu, "sm_zonereload",TopMenuObject_Item,AdminMenu_Reload,
	oMapZoneMenu,"sm_zonereload",ADMFLAG_CHANGEMAP);
	
	AddToTopMenu(hTopMenu, "sm_zone",TopMenuObject_Item,AdminMenu_Teleport,
	oMapZoneMenu,"sm_zone",ADMFLAG_CHANGEMAP);
}

public AdminMenu_CategoryHandler(Handle:topmenu, 
			TopMenuAction:action,
			TopMenuObject:object_id,
			param,
			String:buffer[],
			maxlength)
{
	if (action == TopMenuAction_DisplayTitle) {
		FormatEx(buffer, maxlength, "Timer Zones");
	} else if (action == TopMenuAction_DisplayOption) {
		FormatEx(buffer, maxlength, "Timer Zones");
	}
}

public AdminMenu_AddMapZone(Handle:topmenu, 
			TopMenuAction:action,
			TopMenuObject:object_id,
			param,
			String:buffer[],
			maxlength)
{
	if (action == TopMenuAction_DisplayOption) {
		FormatEx(buffer, maxlength, "Add Map Zone");
	} else if (action == TopMenuAction_SelectOption)
		StartAddingZone(param);
}

StartAddingZone(client)
{
	ResetMapZoneEditor(client);
	g_mapZoneEditors[client][Step] = 1;
	DisplaySelectPointMenu(client, 1);
}

public AdminMenu_RemoveMapZone(Handle:topmenu, 
			TopMenuAction:action,
			TopMenuObject:object_id,
			param,
			String:buffer[],
			maxlength)
{
	if (action == TopMenuAction_DisplayOption) {
		FormatEx(buffer, maxlength, "Delete Zone");
	} else if (action == TopMenuAction_SelectOption) {
		DeleteMapZone(param);
	}
}

public AdminMenu_RemoveAllMapZones(Handle:topmenu, 
			TopMenuAction:action,
			TopMenuObject:object_id,
			param,
			String:buffer[],
			maxlength)
{
	if (action == TopMenuAction_DisplayOption) {
		FormatEx(buffer, maxlength, "Delete All Zones");
	} else if (action == TopMenuAction_SelectOption) 
	{
		if(param == 0)
			DeleteAllMapZones(param);
		else DeleteMapZonesMenu(param);
	}
}

public AdminMenu_NPC(Handle:topmenu, 
			TopMenuAction:action,
			TopMenuObject:object_id,
			param,
			String:buffer[],
			maxlength)
{
	if (action == TopMenuAction_DisplayOption) {
		FormatEx(buffer, maxlength, "Create NPC Teleporter");
	} else if (action == TopMenuAction_SelectOption) 
	{
		CreateNPC(param, 0);
	}
}

public AdminMenu_AdminMode(Handle:topmenu, 
			TopMenuAction:action,
			TopMenuObject:object_id,
			param,
			String:buffer[],
			maxlength)
{
	if (action == TopMenuAction_DisplayOption) {
		FormatEx(buffer, maxlength, "Toggle Admin Mode");
	} else if (action == TopMenuAction_SelectOption) 
	{
		if(adminmode == 0)
		{
			CPrintToChatAll("Adminmode enabled!");
			adminmode = 1;
		}
		else 
		{
			CPrintToChatAll("Adminmode disabled!");
			adminmode = 0;
		}
	}
}

public AdminMenu_Reload(Handle:topmenu, 
			TopMenuAction:action,
			TopMenuObject:object_id,
			param,
			String:buffer[],
			maxlength)
{
	if (action == TopMenuAction_DisplayOption) {
		FormatEx(buffer, maxlength, "Zone Reload");
	} else if (action == TopMenuAction_SelectOption) 
	{
		CPrintToChatAll("Zones Reloaded!");
		LoadMapZones();
	}
}

public AdminMenu_Teleport(Handle:topmenu, 
			TopMenuAction:action,
			TopMenuObject:object_id,
			param,
			String:buffer[],
			maxlength)
{
	if (action == TopMenuAction_DisplayOption) {
		FormatEx(buffer, maxlength, "Zone Teleport");
	} else if (action == TopMenuAction_SelectOption) 
	{
		AdminZoneTeleport(param);
	}
}

DeleteMapZonesMenu(client)
{
	if (0 < client < MaxClients)
	{
		new Handle:menu = CreateMenu(Handle_DeleteMapZonesMenu);
		
		SetMenuTitle(menu, "Are you sure!");
		
		AddMenuItem(menu, "no", "Oh no");		
		AddMenuItem(menu, "no", "Oh no");
		AddMenuItem(menu, "no", "Oh no");
		AddMenuItem(menu, "yes", "!!! YES DELETE ALL ZONES !!!");		
		AddMenuItem(menu, "no", "Oh no");
		AddMenuItem(menu, "no", "Oh no");
		AddMenuItem(menu, "no", "Oh no");
		
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
}

public Handle_DeleteMapZonesMenu(Handle:menu, MenuAction:action, client, itemNum)
{
	if ( action == MenuAction_Select )
	{
		decl String:info[100], String:info2[100];
		new bool:found = GetMenuItem(menu, itemNum, info, sizeof(info), _, info2, sizeof(info2));
		if(found)
		{
			if(StrEqual(info, "yes"))
			{
				decl String:map[32];
				GetCurrentMap(map, sizeof(map));
				DeleteAllMapZones(client);
			}
		}
	}
}

ResetMapZoneEditor(client)
{
	if(client)
	{
		g_mapZoneEditors[client][Step] = 0;
		
		for (new i = 0; i < 3; i++)
			g_mapZoneEditors[client][Point1][i] = 0.0;
		
		for (new i = 0; i < 3; i++)
			g_mapZoneEditors[client][Point1][i] = 0.0;
	}
}

DeleteMapZone(client)
{
	new Float:vec[3];
	GetClientAbsOrigin(client, vec);
	
	for (new zone = 0; zone < g_mapZonesCount; zone++)
	{
		if (IsInsideBox(vec, g_mapZones[zone][Point1][0], g_mapZones[zone][Point1][1], g_mapZones[zone][Point1][2], g_mapZones[zone][Point2][0], g_mapZones[zone][Point2][1], g_mapZones[zone][Point2][2]))
		{
			decl String:query[64];
			FormatEx(query, sizeof(query), "DELETE FROM mapzone WHERE id = %d", g_mapZones[zone][Id]);
			
			SQL_TQuery(g_hSQL, DeleteMapZoneCallback, query, client, DBPrio_Normal);	
			break;
		}
	}
}

DeleteAllMapZones(client)
{
	decl String:query[256];
	FormatEx(query, sizeof(query), "DELETE FROM mapzone WHERE map = '%s'", g_currentMap);
	
	SQL_TQuery(g_hSQL, DeleteMapZoneCallback, query, client, DBPrio_Normal);
}

public DeleteMapZoneCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		Timer_LogError("SQL Error on DeleteMapZone: %s", error);
		return;
	}
	
	LoadMapZones();
	
	if (IsClientInGame(data))
		CPrintToChat(data, "%t", "Map Zone Delete");
}

DisplaySelectPointMenu(client, n)
{
	new Handle:panel = CreatePanel();
	
	decl String:message[255];
	decl String:first[32], String:second[32];
	FormatEx(first, sizeof(first), "%T", "FIRST", client);
	FormatEx(second, sizeof(second), "%T", "SECOND", client);
	
	FormatEx(message, sizeof(message), "%T", "Point Select Panel", client, (n == 1) ? first : second);
	
	DrawPanelItem(panel, message, ITEMDRAW_RAWLINE);
	
	FormatEx(message, sizeof(message), "%T", "Cancel", client);
	DrawPanelItem(panel, message);
	
	SendPanelToClient(panel, client, PointSelect, 540);
	CloseHandle(panel);
}

DisplayPleaseWaitMenu(client)
{
	new Handle:panel = CreatePanel();
	
	decl String:wait[64];
	FormatEx(wait, sizeof(wait), "%t", "Please wait");
	DrawPanelItem(panel, wait, ITEMDRAW_RAWLINE);
	
	SendPanelToClient(panel, client, PointSelect, 540);
	CloseHandle(panel);
}

public PointSelect(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End) 
	{
		CloseHandle(menu);
	} 
	else if (action == MenuAction_Select) 
	{
		if (param2 == MenuCancel_Exit && hTopMenu != INVALID_HANDLE) 
		{
			DisplayTopMenu(hTopMenu, param1, TopMenuPosition_LastCategory);
		}
		
		ResetMapZoneEditor(param1);
	}
}

public Action:ChangeStep(Handle:timer, any:serial)
{
	new client = GetClientFromSerial(serial);
	
	g_mapZoneEditors[client][Step] = 2;
	CreateTimer(0.1, DrawAdminBox, GetClientSerial(client), TIMER_REPEAT);
	
	DisplaySelectPointMenu(client, 2);
}

stock TeleLastCheckpoint(client)
{
	Tele_Level(client, g_mapZones[g_iClientLastTrackZone[client]][Level_Id]);
}

stock CheckIllegalTeleport(client)
{
	if(GetVectorDistance(g_fCord_Old[client], g_fCord_New[client]) < 100.0)
	{
		return true;
	}
	
	return false;
}

stock CreateNPC(client, step, bool:doubleex = false)
{
	if (0 < client < MaxClients)
	{
		if(!IsClientInGame(client))
			return;
		
		if(step == 0)
		{
			new Float:vec[3];
			GetClientAbsOrigin(client, vec);
			g_mapZoneEditors[client][Point1] = vec;
			new Handle:menu = CreateMenu(Handle_Menu_NPC);
			
			SetMenuTitle(menu, "Timer Menu");
			
			AddMenuItem(menu, "npc_reset", "Reset NPC Point");
			AddMenuItem(menu, "dest", "Set Destination (Teammate)");
			AddMenuItem(menu, "dest_double", "Set Destination (Both Players)");
			
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		}
		else
		{
			new String:lvlbuffer[32];
			
			new hcount = LEVEL_START;
			for (new zone = 0; zone < g_mapZonesCount; zone++)
			{
				if(g_mapZones[zone][Type] != ZtNPC_Next) continue;
				if(g_mapZones[zone][Level_Id] <= hcount) continue;
				hcount = g_mapZones[zone][Level_Id];
			}
			
			hcount++;
			
			FormatEx(lvlbuffer, sizeof(lvlbuffer), "Level %d", hcount);
			
			new Float:vec[3];
			GetClientAbsOrigin(client, vec);
			g_mapZoneEditors[client][Point2] = vec;
			
			new Float:point1[3];
			Array_Copy(g_mapZoneEditors[client][Point1], point1, 3);
			
			new Float:point2[3];
			Array_Copy(g_mapZoneEditors[client][Point2], point2, 3);
			
			if(!doubleex)
			{
				if(!AddMapZone(g_currentMap, MapZoneType:ZtNPC_Next, lvlbuffer, hcount, point1, point2))
					PrintToChat(client, "[Timer] Can't save NPC, no database connection.");
			}
			else
			{
				if(!AddMapZone(g_currentMap, MapZoneType:ZtNPC_Next_Double, lvlbuffer, hcount, point1, point2))
					PrintToChat(client, "[Timer] Can't save NPC(double), no database connection.");
			}
		}
	}
}

public Handle_Menu_NPC(Handle:menu, MenuAction:action, client, itemNum)
{
	if ( action == MenuAction_Select )
	{
		decl String:info[100], String:info2[100];
		new bool:found = GetMenuItem(menu, itemNum, info, sizeof(info), _, info2, sizeof(info2));
		if(found)
		{
			if(StrEqual(info, "npc_reset"))
			{
				CreateNPC(client, 0);
			}
			else if(StrEqual(info, "dest"))
			{
				CreateNPC(client, 1, false);
			}
			else if(StrEqual(info, "dest_double"))
			{
				CreateNPC(client, 1, true);
			}
		}
	}
}

public Action:DrawAdminBox(Handle:timer, any:serial)
{
	new client = GetClientFromSerial(serial);
	
	if (g_mapZoneEditors[client][Step] == 0)
	{
		return Plugin_Stop;
	}
	
	new Float:a[3], Float:b[3];
	
	Array_Copy(g_mapZoneEditors[client][Point1], b, 3);
	
	if (g_mapZoneEditors[client][Step] == 3)
		Array_Copy(g_mapZoneEditors[client][Point2], a, 3);
	else
	GetClientAbsOrigin(client, a);
	
	new color[4] = {255, 255, 255, 255};
	
	DrawBox(a, b, 0.1, color, false);
	return Plugin_Continue;
}

public TraceToEntity(client)
{
	new Float:vecClientEyePos[3], Float:vecClientEyeAng[3];
	GetClientEyePosition(client, vecClientEyePos);
	GetClientEyeAngles(client, vecClientEyeAng);    
	
	TR_TraceRayFilter(vecClientEyePos, vecClientEyeAng, MASK_PLAYERSOLID, RayType_Infinite, TraceASDF, client);
	
	if (TR_DidHit(INVALID_HANDLE))
		return (TR_GetEntityIndex(INVALID_HANDLE));
	
	return (-1);
}

public bool:TraceASDF(entity, mask, any:data)
{
	return (data != entity);
}

bool:IsPlayerTouchingSpeedZone(client)
{
	if(g_bPreSpeedStart && Timer_IsPlayerTouchingZoneType(client, ZtStart))
		return true;
	if(g_bPreSpeedBonusStart && Timer_IsPlayerTouchingZoneType(client, ZtBonusStart))
		return true;
	if(Timer_IsPlayerTouchingZoneType(client, ZtLimitSpeed))
		return true;
	if(Timer_IsPlayerTouchingZoneType(client, ZtFullBooster))
		return true;
	if(Timer_IsPlayerTouchingZoneType(client, ZtBounceBack))
		return true;
	if(Timer_IsPlayerTouchingZoneType(client, ZtPushUp))
		return true;
	if(Timer_IsPlayerTouchingZoneType(client, ZtPushDown))
		return true;
	if(Timer_IsPlayerTouchingZoneType(client, ZtPushNorth))
		return true;
	if(Timer_IsPlayerTouchingZoneType(client, ZtPushSouth))
		return true;
	if(Timer_IsPlayerTouchingZoneType(client, ZtPushEast))
		return true;
	if(Timer_IsPlayerTouchingZoneType(client, ZtPushWest))
		return true;
	if(Timer_IsPlayerTouchingZoneType(client, ZtHover))
		return true;
	
	return false;
}

ChangePlayerVelocity(client)
{
	if(!g_timerPhysics)
		return;
	if(!g_bZonesLoaded)
		return;
	if(!IsClientInGame(client))
		return;
	if(!IsPlayerAlive(client))
		return;
	if(IsClientObserver(client))
		return;
	if(g_mapZonesCount < 1)
		return;
	
	new Float:vec[3];
	GetClientAbsOrigin(client, vec);
	
	new style = Timer_GetStyle(client);
	new Float:maxspeed = g_Physics[style][StyleBlockPreSpeeding];
	
	if(!IsPlayerTouchingSpeedZone(client))
		return;
	
	new Float:push_maxspeed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
	
	if (Timer_IsPlayerTouchingZoneType(client, ZtFullBooster))
	{
		CheckVelocity(client, 4, maxspeed);
	}
	else if (Timer_IsPlayerTouchingZoneType(client, ZtBounceBack))
	{
		CheckVelocity(client, 2, 10000.0);
	}
	else if (Timer_IsPlayerTouchingZoneType(client, ZtPushUp))
	{
		new Float:fVelocity[3];
		fVelocity[2] = push_maxspeed;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);
	}
	else if (Timer_IsPlayerTouchingZoneType(client, ZtPushDown))
	{
		new Float:fVelocity[3];
		fVelocity[2] = push_maxspeed*-1.0;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);
	}
	else if (Timer_IsPlayerTouchingZoneType(client, ZtPushNorth))
	{
		new Float:fVelocity[3];
		fVelocity[0] = push_maxspeed;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);
		Block_MovementControl(client);
	}
	else if (Timer_IsPlayerTouchingZoneType(client, ZtPushSouth))
	{
		new Float:fVelocity[3];
		fVelocity[0] = push_maxspeed*-1.0;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);
		Block_MovementControl(client);
	}
	else if (Timer_IsPlayerTouchingZoneType(client, ZtPushEast))
	{
		new Float:fVelocity[3];
		fVelocity[1] = push_maxspeed*-1;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);
		Block_MovementControl(client);
	}
	else if (Timer_IsPlayerTouchingZoneType(client, ZtPushWest))
	{
		new Float:fVelocity[3];
		fVelocity[1] = push_maxspeed;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);
		Block_MovementControl(client);
	}
	else if (Timer_IsPlayerTouchingZoneType(client, ZtHover))
	{
		new Float:fVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
		fVelocity[2] = -1.0;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);
	}
	else
	{
		CheckVelocity(client, 1, maxspeed);
	}
}

IsInsideBox(Float:fPCords[3], Float:fbsx, Float:fbsy, Float:fbsz, Float:fbex, Float:fbey, Float:fbez)
{
	new Float:fpx = fPCords[0];
	new Float:fpy = fPCords[1];
	new Float:fpz = fPCords[2]+30;
	
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

DrawBox(Float:fFrom[3], Float:fTo[3], Float:fLife, color[4], bool:flat, iSpriteIndex = 0)
{
	if(iSpriteIndex == 0)
		iSpriteIndex = precache_laser_default;
	
	if(g_Settings[ZoneSprites] || !flat)
	{
		//initialize tempoary variables bottom front
		decl Float:fLeftBottomFront[3];
		fLeftBottomFront[0] = fFrom[0];
		fLeftBottomFront[1] = fFrom[1];
		if(flat)
			fLeftBottomFront[2] = fTo[2]-g_Settings[ZoneBeamHeight];
		else
			fLeftBottomFront[2] = fTo[2];
		
		decl Float:fRightBottomFront[3];
		fRightBottomFront[0] = fTo[0];
		fRightBottomFront[1] = fFrom[1];
		if(flat)
			fRightBottomFront[2] = fTo[2]-g_Settings[ZoneBeamHeight];
		else
			fRightBottomFront[2] = fTo[2];
		
		//initialize tempoary variables bottom back
		decl Float:fLeftBottomBack[3];
		fLeftBottomBack[0] = fFrom[0];
		fLeftBottomBack[1] = fTo[1];
		if(flat)
			fLeftBottomBack[2] = fTo[2]-g_Settings[ZoneBeamHeight];
		else
			fLeftBottomBack[2] = fTo[2];
		
		decl Float:fRightBottomBack[3];
		fRightBottomBack[0] = fTo[0];
		fRightBottomBack[1] = fTo[1];
		if(flat)
			fRightBottomBack[2] = fTo[2]-g_Settings[ZoneBeamHeight];
		else
			fRightBottomBack[2] = fTo[2];
		
		//initialize tempoary variables top front
		decl Float:fLeftTopFront[3];
		fLeftTopFront[0] = fFrom[0];
		fLeftTopFront[1] = fFrom[1];
		if(flat)
			fLeftTopFront[2] = fFrom[2]+g_Settings[ZoneBeamHeight];
		else
			fLeftTopFront[2] = fFrom[2];
		decl Float:fRightTopFront[3];
		fRightTopFront[0] = fTo[0];
		fRightTopFront[1] = fFrom[1];
		if(flat)
			fRightTopFront[2] = fFrom[2]+g_Settings[ZoneBeamHeight];
		else
			fRightTopFront[2] = fFrom[2];
		
		//initialize tempoary variables top back
		decl Float:fLeftTopBack[3];
		fLeftTopBack[0] = fFrom[0];
		fLeftTopBack[1] = fTo[1];
		if(flat)
			fLeftTopBack[2] = fFrom[2]+g_Settings[ZoneBeamHeight];
		else
			fLeftTopBack[2] = fFrom[2];
		decl Float:fRightTopBack[3];
		fRightTopBack[0] = fTo[0];
		fRightTopBack[1] = fTo[1];
		if(flat)
			fRightTopBack[2] = fFrom[2]+g_Settings[ZoneBeamHeight];
		else
		fRightTopBack[2] = fFrom[2];
		
		new Float:width = g_Settings[ZoneBeamThickness];
		
		if(flat == false)
			width = 0.5;
		
		//create the box
		TE_SetupBeamPoints(fLeftTopFront,fRightTopFront,iSpriteIndex,0,0,0,0.99,width,width,10,0.0,color,10);TE_SendToAll(0.0);
		TE_SetupBeamPoints(fLeftTopBack,fLeftTopFront,iSpriteIndex,0,0,0,0.99,width,width,10,0.0,color,10);TE_SendToAll(0.0);
		TE_SetupBeamPoints(fRightTopBack,fLeftTopBack,iSpriteIndex,0,0,0,0.99,width,width,10,0.0,color,10);TE_SendToAll(0.0);
		TE_SetupBeamPoints(fRightTopFront,fRightTopBack,iSpriteIndex,0,0,0,0.99,width,width,10,0.0,color,10);TE_SendToAll(0.0);
		
		if(!flat)
		{
			TE_SetupBeamPoints(fRightBottomFront,fLeftBottomFront,iSpriteIndex,0,0,0,fLife,width,width,0,0.0,color,0);TE_SendToAll(0.0);
			TE_SetupBeamPoints(fLeftBottomBack,fLeftBottomFront,iSpriteIndex,0,0,0,fLife,width,width,0,0.0,color,0);TE_SendToAll(0.0);
			TE_SetupBeamPoints(fLeftTopFront,fLeftBottomFront,iSpriteIndex,0,0,0,fLife,width,width,0,0.0,color,0);TE_SendToAll(0.0);
			
			
			TE_SetupBeamPoints(fLeftBottomBack,fRightBottomBack,iSpriteIndex,0,0,0,fLife,width,width,0,0.0,color,0);TE_SendToAll(0.0);
			TE_SetupBeamPoints(fRightBottomFront,fRightBottomBack,iSpriteIndex,0,0,0,fLife,width,width,0,0.0,color,0);TE_SendToAll(0.0);
			TE_SetupBeamPoints(fRightTopBack,fRightBottomBack,iSpriteIndex,0,0,0,fLife,width,width,0,0.0,color,0);TE_SendToAll(0.0);
			
			TE_SetupBeamPoints(fRightTopFront,fRightBottomFront,iSpriteIndex,0,0,0,fLife,width,width,0,0.0,color,0);TE_SendToAll(0.0);
			TE_SetupBeamPoints(fLeftTopBack,fLeftBottomBack,iSpriteIndex,0,0,0,fLife,width,width,0,0.0,color,0);TE_SendToAll(0.0);
		}
	}
}

GetZoneEntityCount()
{
	new count;
	
	for (new i = MaxClients; i <= 2047; i++)
	{
		if(!IsValidEntity(i)) continue;
		
		new String:EntName[256];
		Entity_GetName(i, EntName, sizeof(EntName));
		
		new valid = StrContains(EntName, "#TIMER_");
		if(valid > -1)
		{
			count++;
		}
	}
	
	return count;
}

DeleteAllZoneEntitys()
{
	for (new i = MaxClients; i <= 2047; i++)
	{
		g_MapZoneDrawDelayTimer[i] = INVALID_HANDLE;
		g_MapZoneEntityZID[i] = -1;
		
		if(!IsValidEntity(i)) continue;
		
		new String:EntName[256];
		Entity_GetName(i, EntName, sizeof(EntName));
		
		if(StrContains(EntName, "#TIMER_NPC") != -1)
			SDKUnhook(i, SDKHook_StartTouch, NPC_Use);
		
		if(StrContains(EntName, "#TIMER_TRIGGER") != -1)
		{
			SDKUnhook(i, SDKHook_StartTouch, StartTouchTrigger);
			SDKUnhook(i, SDKHook_EndTouch, EndTouchTrigger);
			SDKUnhook(i, SDKHook_Touch, OnTouchTrigger);
		}
		
		if(StrContains(EntName, "#TIMER_") != -1)
			DeleteEntity(i);
		
		for (new client = 1; client <= MaxClients; client++)
			g_bZone[i][client] = false;
	}
}

DeleteEntity(entity)
{
	AcceptEntityInput(entity, "Kill");
}

SpawnZoneEntitys(zone)
{
	if(g_mapZones[zone][Point1][0] == 0.0 && g_mapZones[zone][Point1][1]  == 0.0 && g_mapZones[zone][Point1][2] == 0.0 )
	{
		// No valid zone
		return;
	}
	
	//Spawn debug entitys ine each corner
	if(adminmode == 1)
	{
		SpawnZoneDebugEntitys(zone);
	}
	
	//Spawn NPCs
	if(g_mapZones[zone][Type] == ZtNPC_Next || g_mapZones[zone][Type] == ZtNPC_Next_Double)
	{
		SpawnNPC(zone);
	}
	//Spawn PlayerClip
	else if(g_mapZones[zone][Type] == ZtPlayerClip)
	{
		//SpawnPlayerClip(zone);
	}
	//Spawn trigger_multiple
	else
	{
		SpawnZoneTrigger(zone);
	}
}

SpawnZoneTrigger(zone)
{
	// Center
	new Float:center[3];
	center[0] = (g_mapZones[zone][Point1][0] + g_mapZones[zone][Point2][0]) / 2.0;
	center[1] = (g_mapZones[zone][Point1][1] + g_mapZones[zone][Point2][1]) / 2.0;
	center[2] = g_mapZones[zone][Point1][2];
	
	// Min & max bounds
	new Float:minbounds[3]; 
	new Float:maxbounds[3]; 
	
	minbounds[0] = FloatAbs(g_mapZones[zone][Point1][0]-g_mapZones[zone][Point2][0]) / -2.0;
	minbounds[1] = FloatAbs(g_mapZones[zone][Point1][1]-g_mapZones[zone][Point2][1]) / -2.0;
	minbounds[2] = -1.0; // Just to be save it's not buggy like a defective contact
	
	maxbounds[0] = FloatAbs(g_mapZones[zone][Point1][0]-g_mapZones[zone][Point2][0]) / 2.0;
	maxbounds[1] = FloatAbs(g_mapZones[zone][Point1][1]-g_mapZones[zone][Point2][1]) / 2.0;
	maxbounds[2] = FloatAbs(g_mapZones[zone][Point1][2]-g_mapZones[zone][Point2][2]);
	
	// Resize trigger (by default it's set to 16.0).  A player is 32.0 unity wide, so we need to resize the trigger to have a touching border between the legs
	minbounds[0] += g_Settings[ZoneResize];
	minbounds[1] += g_Settings[ZoneResize];
	minbounds[2] += g_Settings[ZoneResize];
	maxbounds[0] -= g_Settings[ZoneResize];
	maxbounds[1] -= g_Settings[ZoneResize];
	maxbounds[2] -= g_Settings[ZoneResize];
	
	// Spawn trigger
	new entity = CreateEntityByName("trigger_multiple");
	if (entity > 0)
	{
		// Attach zoneID to the entity
		g_MapZoneEntityZID[entity] = zone;
		
		// Give our trigger_multiple a model (It's totally unimportant which one you are using)
		SetEntityModel(entity, "models/props_junk/wood_crate001a.mdl"); 
		
		if(IsValidEntity(entity))
		{
			// Spawnflags for "trigger_multiple"
			// 1 - only a player can trigger this by touch, makes it so a NPC cannot fire a trigger_multiple
			// 2 - Won't fire unless triggering ent's view angles are within 45 degrees of trigger's angles (in addition to any other conditions), so if you want the player to only be able to fire the entity at a 90 degree angle you would do ",angles,0 90 0," into your spawnstring.
			// 4 - Won't fire unless player is in it and pressing use button (in addition to any other conditions), you must make a bounding box,(max\mins) for this to work.
			// 8 - Won't fire unless player/NPC is in it and pressing fire button, you must make a bounding box,(max\mins) for this to work.
			// 16 - only non-player NPCs can trigger this by touch
			// 128 - Start off, has to be activated by a target_activate to be touchable/usable
			// 256 - multiple players can trigger the entity at the same time
			
			DispatchKeyValue(entity, "spawnflags", "257"); 
			
			DispatchKeyValue(entity, "StartDisabled", "0");
			
			// Give our entity a unique name tag, so we can delete it also if the plugins was reloaded without deleting them
			new String:EntName[256];
			FormatEx(EntName, sizeof(EntName), "#TIMER_Trigger_%d", g_mapZones[zone][Id]);
			DispatchKeyValue(entity, "targetname", EntName);
			
			if(DispatchSpawn(entity))
			{
				ActivateEntity(entity);
				
				// Set the size of our trigger_multiple box
				SetEntPropVector(entity, Prop_Send, "m_vecMins", minbounds);
				SetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxbounds);
				
				SetEntProp(entity, Prop_Send, "m_nSolidType", 2);
				SetEntProp(entity, Prop_Send, "m_fEffects", GetEntProp(entity, Prop_Send, "m_fEffects") | 32);
				
				TeleportEntity(entity, center, NULL_VECTOR, NULL_VECTOR);
				
				SDKHook(entity, SDKHook_StartTouch,  StartTouchTrigger);
				SDKHook(entity, SDKHook_EndTouch, EndTouchTrigger);
				SDKHook(entity, SDKHook_Touch, OnTouchTrigger);
			}
		}
	}
}

SpawnNPC(zone)
{
	new Float:vecNPC[3];
	vecNPC[0] = g_mapZones[zone][Point1][0];
	vecNPC[1] = g_mapZones[zone][Point1][1];
	vecNPC[2] = g_mapZones[zone][Point1][2];
	
	new Float:vecDestination[3];
	vecDestination[0] = g_mapZones[zone][Point2][0];
	vecDestination[1] = g_mapZones[zone][Point2][1];
	vecDestination[2] = g_mapZones[zone][Point2][2];
	
	new String:ModePath[256];
	if(g_mapZones[zone][Type] == ZtNPC_Next)
	{
		PrecacheModel(g_Settings[NPC_Path], true);
		FormatEx(ModePath, sizeof(ModePath), "%s", g_Settings[NPC_Path]);
	}
	else if(g_mapZones[zone][Type] == ZtNPC_Next_Double)
	{
		PrecacheModel(g_Settings[NPC_Double_Path], true);
		FormatEx(ModePath, sizeof(ModePath), "%s", g_Settings[NPC_Double_Path]);
	}
	
	decl String:EntName[256];
	FormatEx(EntName, sizeof(EntName), "#TIMER_NPC_%d", g_mapZones[zone][Id]);
	
	new String:Classname[] = "prop_physics_override";
	
	new entity1 = CreateEntityByName(Classname);
	SetEntityModel(entity1, ModePath);
	
	DispatchKeyValue(entity1, "targetname", EntName);
	
	DispatchSpawn(entity1);
	AcceptEntityInput(entity1, "DisableMotion");
	AcceptEntityInput(entity1, "DisableShadow");
	TeleportEntity(entity1, vecNPC, NULL_VECTOR, NULL_VECTOR);
	
	g_mapZones[zone][NPC] = entity1;
	
	SDKHook(entity1, SDKHook_StartTouch, NPC_Use);
}

// Showing to much sprites crashes the server to fast for much zones
// Showning props instead works better with performence
SpawnZoneDebugEntitys(zone)
{
	if(g_mapZones[zone][Type] == ZtNPC_Next || g_mapZones[zone][Type] == ZtNPC_Next_Double)
		return;
	
	new Float:fFrom[3];
	fFrom[0] = g_mapZones[zone][Point2][0];
	fFrom[1] = g_mapZones[zone][Point2][1];
	fFrom[2] = g_mapZones[zone][Point2][2];
	
	new Float:fTo[3];
	fTo[0] = g_mapZones[zone][Point1][0];
	fTo[1] = g_mapZones[zone][Point1][1];
	fTo[2] = g_mapZones[zone][Point1][2];
	
	//initialize tempoary variables bottom front
	decl Float:fLeftBottomFront[3];
	fLeftBottomFront[0] = fFrom[0];
	fLeftBottomFront[1] = fFrom[1];
	fLeftBottomFront[2] = fTo[2]+20;
	
	decl Float:fRightBottomFront[3];
	fRightBottomFront[0] = fTo[0];
	fRightBottomFront[1] = fFrom[1];
	fRightBottomFront[2] = fTo[2]+20;
	
	//initialize tempoary variables bottom back
	decl Float:fLeftBottomBack[3];
	fLeftBottomBack[0] = fFrom[0];
	fLeftBottomBack[1] = fTo[1];
	fLeftBottomBack[2] = fTo[2]+20;
	
	decl Float:fRightBottomBack[3];
	fRightBottomBack[0] = fTo[0];
	fRightBottomBack[1] = fTo[1];
	fRightBottomBack[2] = fTo[2]+20;
	
	PrecacheModel("models/props_junk/trafficcone001a.mdl", true);
	
	decl String:EntName[256];
	FormatEx(EntName, sizeof(EntName), "#TIMER_Zone_%d", g_mapZones[zone][Id]);
	
	new String:ModePath[] = "models/props_junk/trafficcone001a.mdl";
	new String:Classname[] = "prop_physics_override";
	
	new entity1 = CreateEntityByName(Classname);
	SetEntityModel(entity1, ModePath);
	SetEntProp(entity1, Prop_Data, "m_CollisionGroup", 1);
	SetEntProp(entity1, Prop_Send, "m_usSolidFlags", 12);
	SetEntProp(entity1, Prop_Send, "m_nSolidType", 6);
	SetEntityMoveType(entity1, MOVETYPE_NONE);		
	DispatchKeyValue(entity1, "targetname", EntName);
	DispatchSpawn(entity1);
	AcceptEntityInput(entity1, "DisableMotion");
	AcceptEntityInput(entity1, "DisableShadow");
	TeleportEntity(entity1, fRightBottomBack, NULL_VECTOR, NULL_VECTOR);
	
	new entity2 = CreateEntityByName(Classname);
	SetEntityModel(entity2, ModePath);
	SetEntProp(entity2, Prop_Data, "m_CollisionGroup", 1);
	SetEntProp(entity2, Prop_Send, "m_usSolidFlags", 12);
	SetEntProp(entity2, Prop_Send, "m_nSolidType", 6);
	SetEntityMoveType(entity2, MOVETYPE_NONE);
	DispatchKeyValue(entity2, "targetname", EntName);
	DispatchSpawn(entity2);
	AcceptEntityInput(entity2, "DisableMotion");
	AcceptEntityInput(entity2, "DisableShadow");
	TeleportEntity(entity2, fRightBottomFront, NULL_VECTOR, NULL_VECTOR);
	
	new entity3 = CreateEntityByName(Classname);
	SetEntityModel(entity3, ModePath);
	SetEntProp(entity3, Prop_Data, "m_CollisionGroup", 1);
	SetEntProp(entity3, Prop_Send, "m_usSolidFlags", 12);
	SetEntProp(entity3, Prop_Send, "m_nSolidType", 6);
	SetEntityMoveType(entity3, MOVETYPE_NONE);
	DispatchKeyValue(entity3, "targetname", EntName);
	DispatchSpawn(entity3);
	AcceptEntityInput(entity3, "DisableMotion");
	AcceptEntityInput(entity3, "DisableShadow");
	TeleportEntity(entity3, fLeftBottomFront, NULL_VECTOR, NULL_VECTOR);
	
	new entity4 = CreateEntityByName(Classname);
	SetEntityModel(entity4, ModePath);
	SetEntProp(entity4, Prop_Data, "m_CollisionGroup", 1);
	SetEntProp(entity4, Prop_Data, "m_CollisionGroup", 2, 4);
	SetEntProp(entity4, Prop_Send, "m_usSolidFlags", 12);
	SetEntProp(entity4, Prop_Send, "m_nSolidType", 6);
	SetEntityMoveType(entity4, MOVETYPE_NONE);
	DispatchKeyValue(entity4, "targetname", EntName);
	DispatchSpawn(entity4);
	AcceptEntityInput(entity4, "DisableMotion");
	AcceptEntityInput(entity4, "DisableShadow");
	TeleportEntity(entity4, fLeftBottomBack, NULL_VECTOR, NULL_VECTOR);
	
	if(g_mapZones[zone][Type] == ZtLevel || g_mapZones[zone][Type] == ZtStart || g_mapZones[zone][Type] == ZtEnd)
	{
		SetEntityRenderColor(entity1, 0, 255, 0, 200);
		SetEntityRenderColor(entity2, 0, 255, 0, 200);
		SetEntityRenderColor(entity3, 0, 255, 0, 200);
		SetEntityRenderColor(entity4, 0, 255, 0, 200);
	}
	else if(g_mapZones[zone][Type] == ZtBonusLevel || g_mapZones[zone][Type] == ZtBonusStart || g_mapZones[zone][Type] == ZtBonusEnd)
	{
		SetEntityRenderColor(entity1, 0, 0, 255, 200);
		SetEntityRenderColor(entity2, 0, 0, 255, 200);
		SetEntityRenderColor(entity3, 0, 0, 255, 200);
		SetEntityRenderColor(entity4, 0, 0, 255, 200);
	}
	else if(g_mapZones[zone][Type] == ZtStop)
	{
		SetEntityRenderColor(entity1, 138, 0, 180, 200);
		SetEntityRenderColor(entity2, 138, 0, 180, 200);
		SetEntityRenderColor(entity3, 138, 0, 180, 200);
		SetEntityRenderColor(entity4, 138, 0, 180, 200);
	}
	else if(g_mapZones[zone][Type] == ZtRestart)
	{
		SetEntityRenderColor(entity1, 255, 0, 0, 200);
		SetEntityRenderColor(entity2, 255, 0, 0, 200);
		SetEntityRenderColor(entity3, 255, 0, 0, 200);
		SetEntityRenderColor(entity4, 255, 0, 0, 200);
	}
	else if(g_mapZones[zone][Type] == ZtLast)
	{
		SetEntityRenderColor(entity1, 255, 255, 0, 200);
		SetEntityRenderColor(entity2, 255, 255, 0, 200);
		SetEntityRenderColor(entity3, 255, 255, 0, 200);
		SetEntityRenderColor(entity4, 255, 255, 0, 200);
	}
	else if(g_mapZones[zone][Type] == ZtNext)
	{
		SetEntityRenderColor(entity1, 0, 255, 255, 200);
		SetEntityRenderColor(entity2, 0, 255, 255, 200);
		SetEntityRenderColor(entity3, 0, 255, 255, 200);
		SetEntityRenderColor(entity4, 0, 255, 255, 200);
	}
}

public Action:SetBlockable(Handle:timer, any:entity)
{
	SetEntData(entity, g_ioffsCollisionGroup, 5, 4, true);
	return Plugin_Stop;
}

Menu_NPC_Next(client, zone)
{
	if (0 < client < MaxClients)
	{
		
		if(adminmode == 1 && Client_IsAdmin(client))
		{
			new Handle:menu = CreateMenu(Handle_Menu_NPC_Delete);
			
			SetMenuTitle(menu, "Delete this NPC?");
			
			AddMenuItem(menu, "yes", "Yes");
			AddMenuItem(menu, "no", "No!");
			
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
			
			g_iTargetNPC[client] = zone;
		}
		else if(g_Settings[NPCConfirm])
		{
			new Handle:menu = CreateMenu(Handle_Menu_NPC_Next);
			
			SetMenuTitle(menu, "Do you like to teleport?");
			
			AddMenuItem(menu, "yes", "Yes Please");
			AddMenuItem(menu, "no", "Not now!");
			
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		}
		else
		{
			if(g_iClientLastTrackZone[client] > 0 && client > 0 && g_bZonesLoaded)
			{
				new Float:velStop[3];
				new Float:vecDestination[3];
				vecDestination[0] = g_mapZones[g_iClientLastTrackZone[client]][Point2][0];
				vecDestination[1] = g_mapZones[g_iClientLastTrackZone[client]][Point2][1];
				vecDestination[2] = g_mapZones[g_iClientLastTrackZone[client]][Point2][2];
				
				if(Timer_IsPlayerTouchingZoneType(client, ZtStart)) Timer_SetIgnoreEndTouchStart(client, 1);
				
				new mate;
				if(g_timerTeams) mate = Timer_GetClientTeammate(client);
				
				if(mate > 0)
				{
					if(g_mapZones[zone][Type] == ZtNPC_Next_Double)
					{
						TeleportEntity(client, vecDestination, NULL_VECTOR, velStop);
						CreateTimer(1.5, SetBlockable, client, TIMER_FLAG_NO_MAPCHANGE);
						SetPush(client);
						
						TeleportEntity(mate, vecDestination, NULL_VECTOR, velStop);
						CreateTimer(1.5, SetBlockable, mate, TIMER_FLAG_NO_MAPCHANGE);
						SetPush(mate);
					}
					else if(Timer_GetCoopStatus(client))
					{
						TeleportEntity(Timer_GetClientTeammate(client), vecDestination, NULL_VECTOR, velStop);
					}
					else TeleportEntity(client, vecDestination, NULL_VECTOR, velStop);
				}
				else TeleportEntity(client, vecDestination, NULL_VECTOR, velStop);
			}
		}
	}
}

public Handle_Menu_NPC_Next(Handle:menu, MenuAction:action, client, itemNum)
{
	if ( action == MenuAction_Select )
	{
		decl String:info[100], String:info2[100];
		new bool:found = GetMenuItem(menu, itemNum, info, sizeof(info), _, info2, sizeof(info2));
		if(found)
		{
			if(StrEqual(info, "yes"))
			{
				if(g_iClientLastTrackZone[client] > 0 && client > 0 && g_bZonesLoaded)
				{
					new Float:velStop[3];
					new Float:vecDestination[3];
					vecDestination[0] = g_mapZones[g_iClientLastTrackZone[client]][Point2][0];
					vecDestination[1] = g_mapZones[g_iClientLastTrackZone[client]][Point2][1];
					vecDestination[2] = g_mapZones[g_iClientLastTrackZone[client]][Point2][2];
					
					if(Timer_IsPlayerTouchingZoneType(client, ZtStart)) Timer_SetIgnoreEndTouchStart(client, 1);
					
					new mate;
					if(g_timerTeams) mate= Timer_GetClientTeammate(client);
					
					if(mate > 0)
					{
						if(Timer_GetCoopStatus(client))
						{
							TeleportEntity(mate, vecDestination, NULL_VECTOR, velStop);
						}
						else TeleportEntity(client, vecDestination, NULL_VECTOR, velStop);
					}
					else TeleportEntity(client, vecDestination, NULL_VECTOR, velStop);
				}
			}
			else if(StrEqual(info, "no"))
			{
				
			}
		}
	}
}

public Handle_Menu_NPC_Delete(Handle:menu, MenuAction:action, client, itemNum)
{
	if ( action == MenuAction_Select )
	{
		decl String:info[100], String:info2[100];
		new bool:found = GetMenuItem(menu, itemNum, info, sizeof(info), _, info2, sizeof(info2));
		if(found)
		{
			if(StrEqual(info, "yes"))
			{
				new zone = g_iTargetNPC[client];
				
				decl String:query[64];
				FormatEx(query, sizeof(query), "DELETE FROM mapzone WHERE id = %d", g_mapZones[zone][Id]);
				
				SQL_TQuery(g_hSQL, DeleteMapZoneCallback, query, client, DBPrio_Normal);
			}
			else if(StrEqual(info, "no"))
			{
				
			}
		}
	}
}

stock bool:Tele_Level(client, level)
{
	if(LEVEL_BONUS5_END >= level >= LEVEL_START && client > 0 && g_bZonesLoaded)
	{
		for (new mapZone = 0; mapZone < g_mapZonesCount; mapZone++)
		{
			if(g_mapZones[mapZone][Level_Id] < LEVEL_START)
				continue;
			
			if (g_mapZones[mapZone][Level_Id] == level)
			{
				return Tele_Zone(client, mapZone);
			}
		}
	}
	
	return false;
}

stock bool:Tele_Zone(client, zone, bool:stopspeed = true, bool:overwrite_physics = true)
{
	if(!IsClientInGame(client))
		return false;
	
	// Don't teleport from inside a startzone to the same zone
	if(g_bZone[zone][client])
	{
		if(g_mapZones[zone][Type] == ZtStart)
		{
			CPrintToChat(client, "%t", "Already inside start zone");
			return false;
		}
		else if(g_mapZones[zone][Type] == ZtBonusStart)
		{
			CPrintToChat(client, "%t", "Already inside bonus start zone");
			return false;
		}
		else if(g_mapZones[zone][Type] == ZtBonus2Start)
		{
			CPrintToChat(client, "%t", "Already inside bonus2 start zone");
			return false;
		}
		else if(g_mapZones[zone][Type] == ZtBonus3Start)
		{
			CPrintToChat(client, "%t", "Already inside bonus3 start zone");
			return false;
		}
		else if(g_mapZones[zone][Type] == ZtBonus4Start)
		{
			CPrintToChat(client, "%t", "Already inside bonus4 start zone");
			return false;
		}
		else if(g_mapZones[zone][Type] == ZtBonus5Start)
		{
			CPrintToChat(client, "%t", "Already inside bonus5 start zone");
			return false;
		}
	}
	
	// Get zone center cords
	new Float:center[3];
	center[0] = (g_mapZones[zone][Point1][0] + g_mapZones[zone][Point2][0]) / 2.0;
	center[1] = (g_mapZones[zone][Point1][1] + g_mapZones[zone][Point2][1]) / 2.0;
	
	// Use static height
	if(g_Settings[UseZoneTeleportZ])
		center[2] = g_mapZones[zone][Point1][2] + g_Settings[ZoneTeleportZ];
	// Use center height
	else center[2] = (g_mapZones[zone][Point1][2] + g_mapZones[zone][Point2][2]) / 2.0;
	
	//If teleporting outside a startzone skip the next end touch output
	new bool:touchstart = (Timer_IsPlayerTouchingZoneType(client, ZtStart) || Timer_IsPlayerTouchingZoneType(client, ZtBonusStart) || Timer_IsPlayerTouchingZoneType(client, ZtBonus2Start) || Timer_IsPlayerTouchingZoneType(client, ZtBonus3Start) || Timer_IsPlayerTouchingZoneType(client, ZtBonus4Start) || Timer_IsPlayerTouchingZoneType(client, ZtBonus5Start));
	new bool:targetstart = (g_mapZones[zone][Type] != ZtStart && g_mapZones[zone][Type] != ZtBonusStart && g_mapZones[zone][Type] != ZtBonus2Start && g_mapZones[zone][Type] != ZtBonus3Start && g_mapZones[zone][Type] != ZtBonus4Start && g_mapZones[zone][Type] != ZtBonus5Start);
	
	if(touchstart && targetstart)
		Timer_SetIgnoreEndTouchStart(client, 1);
	
	// Stop speed before and after teleporting
	if(stopspeed)
	{
		//Stop speed in this and next tick
		new Float:zero[3];
		TeleportEntity(client, center, NULL_VECTOR, zero);
		CreateTimer(0.0, Timer_StopSpeed, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	else TeleportEntity(client, center, NULL_VECTOR, NULL_VECTOR);
	
	// Anti cheat
	if(overwrite_physics)
	{
		new style = Timer_GetStyle(client);
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_Physics[style][StyleTimeScale]);
		SetEntityGravity(client, g_Physics[style][StyleGravity]);
	}
	
	return true;
}

public Action:Timer_StopSpeed(Handle:timer, any:client)
{
	if(!IsClientInGame(client))
		return Plugin_Stop;
	
	if(!IsPlayerAlive(client))
		return Plugin_Stop;
	
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, Float:{0.0,0.0,-100.0});
	
	return Plugin_Stop;
}

public Action:Command_LevelAdminMode(client, args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_zoneadminmode [0/1]");
		return Plugin_Handled;	
	}
	if (args == 1)
	{
		decl String:name2[64];
		GetCmdArg(1,name2,sizeof(name2));
		adminmode = StringToInt(name2);
		
		if(adminmode == 1) 
		{
			CPrintToChat(client, "%t", "Adminmode Enabled");
		}
		else  
		{
			CPrintToChat(client, "%t", "Adminmode Disabled");
		}
	}
	return Plugin_Handled;	
}

public Action:Command_AddZone(client, args)
{
	StartAddingZone(client);
	return Plugin_Handled;
}

public Action:Command_ReloadZones(client, args)
{
	LoadMapZones();
	CPrintToChat(client, "%t", "Zones Reloaded");
	return Plugin_Handled;
}

public Action:Command_NPC_Next(client, args)
{
	CreateNPC(client, 0);
	return Plugin_Handled;
}

public Action:Command_LevelName(client, args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_zonename [name]");
		return Plugin_Handled;	
	}
	if (args == 1)
	{
		decl String:name2[64];
		GetCmdArg(1,name2,sizeof(name2));
		decl String:query[256];
		FormatEx(query, sizeof(query), "UPDATE mapzone SET name = '%s' WHERE id = %d", name2, g_mapZones[g_iClientLastTrackZone[client]][Id]);
		SQL_TQuery(g_hSQL, UpdateLevelCallback, query, client, DBPrio_Normal);	
		PrintToChat(client, "Set LevelName: %s for ZoneID: %d", name2, g_mapZones[g_iClientLastTrackZone[client]][Id]);
	}
	return Plugin_Handled;	
}

public Action:Command_LevelID(client, args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_zoneid [id]");
		return Plugin_Handled;	
	}
	if (args == 1)
	{
		decl String:name2[64];
		GetCmdArg(1, name2, sizeof(name2));
		
		decl String:query2[512];
		FormatEx(query2, sizeof(query2), "UPDATE mapzone SET level_id = '%s' WHERE id = %d", name2, g_mapZones[g_iClientLastTrackZone[client]][Id]);
		SQL_TQuery(g_hSQL, UpdateLevelCallback, query2, client, DBPrio_Normal);	
		PrintToChat(client, "Set LevelID: %s for ZoneID: %d", name2, g_mapZones[g_iClientLastTrackZone[client]][Id]);
	}
	return Plugin_Handled;	
}

public Action:Command_LevelType(client, args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_zonetype");
		return Plugin_Handled;	
	}
	if (args == 1)
	{
		decl String:name2[64];
		GetCmdArg(1, name2, sizeof(name2));
		
		decl String:query2[512];
		FormatEx(query2, sizeof(query2), "UPDATE mapzone SET type = '%s' WHERE id = %d", name2, g_mapZones[g_iClientLastTrackZone[client]][Id]);
		SQL_TQuery(g_hSQL, UpdateLevelCallback, query2, client, DBPrio_Normal);	
		PrintToChat(client, "Set Type: %s for ZoneID: %d", name2, g_mapZones[g_iClientLastTrackZone[client]][Id]);
	}
	return Plugin_Handled;	
}

public UpdateLevelCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		Timer_LogError("SQL Error on UpdateZone: %s", error);
		return;
	}
	
	LoadMapZones();
}

public Action:Command_Stuck(client, args)
{
	if(!g_Settings[StuckEnable])
		return Plugin_Handled;
	
	if(!IsClientInGame(client)) 
		return Plugin_Handled;
	
	if(!IsPlayerAlive(client)) 
		return Plugin_Handled;
	
	if(g_timerTeams)
	{
		if(Timer_GetChallengeStatus(client) == 1 || Timer_GetCoopStatus(client) == 1)
		{
			ConfirmAbortMenu(client, TRACK_NORMAL);
			return Plugin_Handled;
		}
	}
	
	if(Timer_GetStatus(client) && g_Settings[StuckPenaltyTime] > 0)
	{
		Timer_AddPenaltyTime(client, g_Settings[StuckPenaltyTime]);
		CPrintToChat(client, "%t", "Stuck", RoundToFloor(g_Settings[StuckPenaltyTime]));
	}
	
	TeleLastCheckpoint(client);
	
	return Plugin_Handled;
}

public Action:Command_Restart(client, args)
{
	if(!g_Settings[RestartEnable])
		return Plugin_Handled;
	
	if(!IsClientInGame(client)) 
		return Plugin_Handled;
		
	if(Timer_GetMapzoneCount(ZtStart) < 1)
		return Plugin_Handled;
	
	if(Timer_IsPlayerTouchingZoneType(client, ZtStart))
	{
		CPrintToChat(client, "%t", "Already inside start zone");
		return Plugin_Handled;
	}
	
	if(g_timerTeams)
	{
		if(Timer_GetChallengeStatus(client) == 1 || Timer_GetCoopStatus(client) == 1)
		{
			ConfirmAbortMenu(client, -1);
			return Plugin_Handled;
		}
	}

	if(!IsPlayerAlive(client)) 
	{
		CS_RespawnPlayer(client);
		return Plugin_Handled;
	}

	Client_Restart(client);
	
	return Plugin_Handled;
}

public Action:Command_Start(client, args)
{
	if(!g_Settings[StartEnable])
		return Plugin_Handled;
		
	decl String:slevel[64];
	GetCmdArg(1, slevel, sizeof(slevel));
	new level = StringToInt(slevel);
	
	if(level > 0)
	{
		if(g_timerTeams)
		{
			if(Timer_GetChallengeStatus(client) == 1 || Timer_GetCoopStatus(client) == 1)
			{
				ConfirmAbortMenu(client, TRACK_NORMAL);
				return Plugin_Handled;
			}
		}
		
		Timer_Reset(client);
		Tele_Level(client, level);
		return Plugin_Handled;
	}
	
	if(!IsClientInGame(client)) 
		return Plugin_Handled;
		
	if(Timer_GetMapzoneCount(ZtStart) < 1)
		return Plugin_Handled;
	
	if(g_timerTeams)
	{
		if(Timer_GetChallengeStatus(client) == 1 || Timer_GetCoopStatus(client) == 1)
		{
			ConfirmAbortMenu(client, TRACK_NORMAL);
			return Plugin_Handled;
		}
	}
	if(!IsPlayerAlive(client)) 
	{
		CS_RespawnPlayer(client);
	}
	
	Client_Start(client);
	
	return Plugin_Handled;
}

public Action:Command_BonusRestart(client, args)
{
	if(!g_Settings[StartEnable])
		return Plugin_Handled;
	
	if(!IsClientInGame(client)) 
		return Plugin_Handled;
	
	if(Timer_IsPlayerTouchingZoneType(client, ZtBonusStart))
	{
		CPrintToChat(client, "%t", "Already inside bonus start zone");
		return Plugin_Handled;
	}
		
	if(Timer_GetMapzoneCount(ZtBonusStart) < 1)
	{
		CPrintToChat(client, "%t", "There is no bonus in this map");
		return Plugin_Handled;
	}
	
	if(g_timerTeams)
	{
		if(Timer_GetChallengeStatus(client) == 1 || Timer_GetCoopStatus(client) == 1)
		{
			ConfirmAbortMenu(client, TRACK_BONUS);
			return Plugin_Handled;
		}
	}
	if(!IsPlayerAlive(client)) 
	{
		CS_RespawnPlayer(client);
	}
	Client_BonusRestart(client, TRACK_BONUS);
	
	return Plugin_Handled;
}

public Action:Command_Bonus2Restart(client, args)
{
	if(!g_Settings[StartEnable])
		return Plugin_Handled;
	
	if(!IsClientInGame(client)) 
		return Plugin_Handled;
	
	if(Timer_IsPlayerTouchingZoneType(client, ZtBonus2Start))
	{
		CPrintToChat(client, "%t", "Already inside bonus2 start zone");
		return Plugin_Handled;
	}
		
	if(Timer_GetMapzoneCount(ZtBonus2Start) < 1)
	{
		CPrintToChat(client, "%t", "There is no bonus2 in this map");
		return Plugin_Handled;
	}
	
	if(g_timerTeams)
	{
		if(Timer_GetChallengeStatus(client) == 1 || Timer_GetCoopStatus(client) == 1)
		{
			ConfirmAbortMenu(client, TRACK_BONUS2);
			return Plugin_Handled;
		}
	}
	if(!IsPlayerAlive(client)) 
	{
		CS_RespawnPlayer(client);
	}
	Client_BonusRestart(client, TRACK_BONUS2);
	
	return Plugin_Handled;
}

public Action:Command_Bonus3Restart(client, args)
{
	if(!g_Settings[StartEnable])
		return Plugin_Handled;
	
	if(!IsClientInGame(client)) 
		return Plugin_Handled;
	
	if(Timer_IsPlayerTouchingZoneType(client, ZtBonus3Start))
	{
		CPrintToChat(client, "%t", "Already inside bonus3 start zone");
		return Plugin_Handled;
	}
		
	if(Timer_GetMapzoneCount(ZtBonus3Start) < 1)
	{
		CPrintToChat(client, "%t", "There is no bonus3 in this map");
		return Plugin_Handled;
	}
	
	if(g_timerTeams)
	{
		if(Timer_GetChallengeStatus(client) == 1 || Timer_GetCoopStatus(client) == 1)
		{
			ConfirmAbortMenu(client, TRACK_BONUS3);
			return Plugin_Handled;
		}
	}
	if(!IsPlayerAlive(client)) 
	{
		CS_RespawnPlayer(client);
	}
	Client_BonusRestart(client, TRACK_BONUS3);
	
	return Plugin_Handled;
}

public Action:Command_Bonus4Restart(client, args)
{
	if(!g_Settings[StartEnable])
		return Plugin_Handled;
	
	if(!IsClientInGame(client)) 
		return Plugin_Handled;
	
	if(Timer_IsPlayerTouchingZoneType(client, ZtBonus4Start))
	{
		CPrintToChat(client, "%t", "Already inside bonus4 start zone");
		return Plugin_Handled;
	}
		
	if(Timer_GetMapzoneCount(ZtBonus4Start) < 1)
	{
		CPrintToChat(client, "%t", "There is no bonus4 in this map");
		return Plugin_Handled;
	}
	
	if(g_timerTeams)
	{
		if(Timer_GetChallengeStatus(client) == 1 || Timer_GetCoopStatus(client) == 1)
		{
			ConfirmAbortMenu(client, TRACK_BONUS4);
			return Plugin_Handled;
		}
	}
	if(!IsPlayerAlive(client)) 
	{
		CS_RespawnPlayer(client);
	}
	Client_BonusRestart(client, TRACK_BONUS4);
	
	return Plugin_Handled;
}

public Action:Command_Bonus5Restart(client, args)
{
	if(!g_Settings[StartEnable])
		return Plugin_Handled;
	
	if(!IsClientInGame(client)) 
		return Plugin_Handled;
	
	if(Timer_IsPlayerTouchingZoneType(client, ZtBonus5Start))
	{
		CPrintToChat(client, "%t", "Already inside bonus5 start zone");
		return Plugin_Handled;
	}
		
	if(Timer_GetMapzoneCount(ZtBonus5Start) < 1)
	{
		CPrintToChat(client, "%t", "There is no bonus5 in this map");
		return Plugin_Handled;
	}
	
	if(g_timerTeams)
	{
		if(Timer_GetChallengeStatus(client) == 1 || Timer_GetCoopStatus(client) == 1)
		{
			ConfirmAbortMenu(client, TRACK_BONUS5);
			return Plugin_Handled;
		}
	}
	if(!IsPlayerAlive(client)) 
	{
		CS_RespawnPlayer(client);
	}
	Client_BonusRestart(client, TRACK_BONUS5);
	
	return Plugin_Handled;
}

ConfirmAbortMenu(client, track)
{
	if (0 < client < MaxClients)
	{
		new Handle:menu = CreateMenu(Handle_ConfirmAbortMenu);
		
		new mate;
		if(g_timerTeams) mate = Timer_GetClientTeammate(client);
		
		if(mate > 0)
		{
			if(Timer_GetChallengeStatus(client) == 1)
			{
				char title[256];
				Format(title, sizeof(title), "%T", "Are you sure to quit the Challenge", client);
				SetMenuTitle(menu, title);
			}
			else if(Timer_GetCoopStatus(client) == 1)
			{
				char title[256];
				Format(title, sizeof(title), "%T", "Are you sure to quit the Coop", client);
				SetMenuTitle(menu, title);
			}
		}else 
		{
			char title[256];
			Format(title, sizeof(title), "%T", "Are you sure to quit", client);
			SetMenuTitle(menu, title);
		}
		
		decl String:info[8];
		IntToString(track, info, sizeof(info));
		
		char yes[256];
		Format(yes, sizeof(yes), "%T", "Yes", client);
		AddMenuItem(menu, info, yes);
		
		char no[256];
		Format(no, sizeof(no), "%T", "No", client);
		AddMenuItem(menu, "no", no);
		
		DisplayMenu(menu, client, 5);
	}
}

public Handle_ConfirmAbortMenu(Handle:menu, MenuAction:action, client, itemNum)
{
	if ( action == MenuAction_Select )
	{
		decl String:info[100], String:info2[100];
		new bool:found = GetMenuItem(menu, itemNum, info, sizeof(info), _, info2, sizeof(info2));
		
		if(found)
		{
			if(!StrEqual(info, "no", false))
			{
				if(StrEqual(info, "-1", false))
				{
					Client_Start(client);
					
				}
				else if(StrEqual(info, "0", false))
				{
					Client_Restart(client);
				}
				else
				{	
					new track = StringToInt(info);
					Client_BonusRestart(client, track);
				}
			}
		}
	}
}

bool:Client_Start(client)
{
	if(!IsClientInGame(client)) 
		return false;
	
	//Has player a valid team
	if(GetClientTeam(client) != CS_TEAM_CT && GetClientTeam(client) != CS_TEAM_T)
	{
		new validteam = CS_GetValidSpawnTeam();
		
		if(validteam != CS_TEAM_NONE)
		{
			CS_SwitchTeam(client, validteam);
		}
		else Timer_LogError("No spawn points for %s", g_currentMap);
	}
	
	new style = Timer_GetStyle(client);
	
	//Stop timer
	Timer_Reset(client);
	
	//Is player alive
	if(!IsPlayerAlive(client)) 
	{
		CS_RespawnPlayer(client);
	}
	else
	{
		//Anti-Chat
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_Physics[style][StyleTimeScale]);
		SetEntityGravity(client, g_Physics[style][StyleGravity]);
	}
	
	if(g_Settings[TeleportOnSpawn])
	{
		//Teleport player to starzone
		Tele_Level(client, LEVEL_START);
	}
	
	return true;
}

bool:Client_Restart(client, bool:teleport = true)
{	Timer_LogError("Restart called")
	if(!IsClientInGame(client)) 
		return false;
	
	//Has player a valid team
	if(GetClientTeam(client) != CS_TEAM_CT && GetClientTeam(client) != CS_TEAM_T)
	{
		new validteam = CS_GetValidSpawnTeam();
		
		if(validteam != CS_TEAM_NONE)
		{
			CS_SwitchTeam(client, validteam);
			Timer_LogError("Not valid team")
		}
		else Timer_LogError("No spawn points for %s", g_currentMap);
	}
	
	new style = Timer_GetStyle(client);
	
	//Stop timer
	Timer_Reset(client);
	Timer_LogError("Timer reseted")
	
	new bool:respawn = true;
	
	//Is player alive
	if(!IsPlayerAlive(client)) 
	{
		Timer_LogError("Player not alive")
		CS_RespawnPlayer(client);
		respawn = false;
	}
	else
	{
		//Anti-Chat
		Timer_LogError("Anti chat osio")
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_Physics[style][StyleTimeScale]);
		SetEntityGravity(client, g_Physics[style][StyleGravity]);
	}
	
	//Teleport player to starzone
	if(g_Settings[TeleportOnRestart] && teleport)
	{
		Timer_LogError("TP to start zone")
		Tele_Level(client, LEVEL_START);
	} 
	//Or just respawn him
	else if(respawn)
	{
		Timer_LogError("Respawn player at last if in zone")
		CS_RespawnPlayer(client);
	}
	
	return true;
}

bool:Client_BonusRestart(client, track)
{
	if(!IsClientInGame(client)) 
		return false;
	
	//Has player a valid team
	if(GetClientTeam(client) != CS_TEAM_CT && GetClientTeam(client) != CS_TEAM_T)
	{
		new validteam = CS_GetValidSpawnTeam();
		
		if(validteam != CS_TEAM_NONE)
		{
			CS_SwitchTeam(client, validteam);
		}
		else Timer_LogError("No spawn points for %s", g_currentMap);
	}
	
	new style = Timer_GetStyle(client);
	
	//Stop timer
	Timer_Reset(client);
	
	//Is player alive
	if(!IsPlayerAlive(client)) 
	{
		CS_RespawnPlayer(client);
	}
	else
	{
		//Anti-Chat
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_Physics[style][StyleTimeScale]);
		SetEntityGravity(client, g_Physics[style][StyleGravity]);
	}
	
	//Teleport player to bonus-starzone
	if(track == TRACK_BONUS)
		return Tele_Level(client, LEVEL_BONUS_START);
	else if(track == TRACK_BONUS2)
		return Tele_Level(client, LEVEL_BONUS2_START);
	else if(track == TRACK_BONUS3)
		return Tele_Level(client, LEVEL_BONUS3_START);
	else if(track == TRACK_BONUS4)
		return Tele_Level(client, LEVEL_BONUS4_START);
	else if(track == TRACK_BONUS5)
		return Tele_Level(client, LEVEL_BONUS5_START);
	
	return true;
}

public Action:Command_AdminZone(client, args)
{
	AdminZoneTeleport(client);
	return Plugin_Handled;
}

AdminZoneTeleport(client)
{
	new Handle:menu = CreateMenu(MenuHandlerAdminZone);
	SetMenuTitle(menu, "Zone Selection");
	
	for (new zone = 0; zone < g_mapZonesCount; zone++)
	{
		decl String:zone_name[32];
		FormatEx(zone_name, sizeof(zone_name), "%s", g_mapZones[zone][zName]);
		
		decl String:zone_id[32];
		FormatEx(zone_id,sizeof(zone_id), "%d", zone);
		AddMenuItem(menu, zone_id, zone_name);
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandlerAdminZone(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[100], String:info2[100];
		new bool:found = GetMenuItem(menu, param2, info, sizeof(info), _, info2, sizeof(info2));
		new zone = StringToInt(info);
		if(found)
		{
			Timer_Reset(client);
			Tele_Zone(client, zone);
		}
	}
}

public Action:Command_AdminZoneDel(client, args)
{
	AdminZoneDelete(client);
	return Plugin_Handled;
}

AdminZoneDelete(client)
{
	new Handle:menu = CreateMenu(MenuHandlerAdminZoneDelete);
	SetMenuTitle(menu, "Zone Selection");
	
	for (new zone = 0; zone < g_mapZonesCount; zone++)
	{
		decl String:zone_name[32];
		FormatEx(zone_name, sizeof(zone_name), "%s", g_mapZones[zone][zName]);
		
		decl String:zone_id[32];
		FormatEx(zone_id,sizeof(zone_id), "%d", zone);
		AddMenuItem(menu, zone_id, zone_name);
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandlerAdminZoneDelete(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[100], String:info2[100];
		new bool:found = GetMenuItem(menu, param2, info, sizeof(info), _, info2, sizeof(info2));
		new zone = StringToInt(info);
		if(found)
		{
			decl String:query[64];
			FormatEx(query, sizeof(query), "DELETE FROM mapzone WHERE id = %d", g_mapZones[zone][Id]);
			
			SQL_TQuery(g_hSQL, DeleteMapZoneCallback, query, client, DBPrio_Normal);
		}
	}
}

public Action:Command_Levels(client, args)
{
	if(!g_Settings[LevelTeleportEnable])
		return Plugin_Handled;

	decl String:slevel[64];
	GetCmdArg(1, slevel, sizeof(slevel));
	new level = StringToInt(slevel);
	
	if(level > 0)
	{
		if(g_timerTeams)
		{
			if(Timer_GetChallengeStatus(client) == 1 || Timer_GetCoopStatus(client) == 1)
			{
				ConfirmAbortMenu(client, TRACK_NORMAL);
				return Plugin_Handled;
			}
		}
		
		Timer_Reset(client);
		Tele_Level(client, level);
		return Plugin_Handled;
	}
	
	new Handle:menu = CreateMenu(MenuHandlerLevels);
	char title[256];
	Format(title, sizeof(title), "%T", "Stage Teleport Selection", client);
	SetMenuTitle(menu, title);
	
	for (new zone = 0; zone < g_mapZonesCount; zone++)
	{
		if(g_mapZones[zone][Level_Id] < 1)
		{
			continue;
		}
		
		decl String:zone_name[32];
		FormatEx(zone_name, sizeof(zone_name), "%s", g_mapZones[zone][zName]);
		
		decl String:zone_id[32];
		FormatEx(zone_id,sizeof(zone_id), "%d", zone);
		AddMenuItem(menu, zone_id, zone_name);
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 20);
	
	return Plugin_Handled;
}

public MenuHandlerLevels(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[100], String:info2[100];
		new bool:found = GetMenuItem(menu, param2, info, sizeof(info), _, info2, sizeof(info2));
		new zone = StringToInt(info);
		if(found)
		{
			Timer_Reset(client);
			Tele_Zone(client, zone);
		}
	}
}

public Native_ClientStart(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	Client_Start(client);
}

public Native_ClientRestart(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	Client_Restart(client);
}

public Native_ClientBonusRestart(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int track = GetNativeCell(2);
	Client_BonusRestart(client, track);
}

public Native_AddMapZone(Handle:plugin, numParams)
{
	decl String:map[32];
	GetNativeString(1, map, sizeof(map));
	
	new MapZoneType:type = GetNativeCell(2);	
	
	decl String:name[32];
	GetNativeString(1, name, sizeof(name));
	
	new level_id = GetNativeCell(2);
	
	new Float:point1[3];
	GetNativeArray(3, point1, sizeof(point1));
	
	new Float:point2[3];
	GetNativeArray(3, point2, sizeof(point2));
	
	AddMapZone(map, type, name, level_id, point1, point2);
}

public Native_ClientTeleportLevel(Handle:plugin, numParams)
{
	return Tele_Level(GetNativeCell(1), GetNativeCell(2));
}

public Native_GetClientLevel(Handle:plugin, numParams)
{
	return g_iClientLastTrackZone[GetNativeCell(1)];
}

public Native_SetClientLevel(Handle:plugin, numParams)
{
	g_iClientLastTrackZone[GetNativeCell(1)] = GetNativeCell(2);
}

public Native_GetClientLevelID(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if(client && Client_IsValid(client, true) && g_iClientLastTrackZone[client] >= 0)
	{
		return g_mapZones[g_iClientLastTrackZone[client]][Level_Id];
	}
	else return 0;
}

public Native_GetLevelName(Handle:plugin, numParams)
{
	new id = GetNativeCell(1);
	new nlen = GetNativeCell(3); 
	if (nlen <= 0)
		return false;
	
	for (new i = 0; i < g_mapZonesCount; i++)
	{
		if(g_mapZones[i][Level_Id] == id)
		{
			decl String:buffer[nlen];
			FormatEx(buffer, nlen, "%s", g_mapZones[id][zName]);
			if (SetNativeString(2, buffer, nlen, true) == SP_ERROR_NONE)
				return true;
		}
	}
	
	return false;
}

public Native_SetIgnoreEndTouchStart(Handle:plugin, numParams)
{
	g_iIgnoreEndTouchStart[GetNativeCell(1)] = GetNativeCell(2);
}

public OnEntityCreated(entity, const String:classname[])
{
	if(g_Settings[NoblockEnable])
	{
		if (StrEqual(classname, "hegrenade_projectile"))
		{
			SetNoBlock(entity);
		} else if (StrEqual(classname, "flashbang_projectile"))
		{
			SetNoBlock(entity);
		} else if (StrEqual(classname, "smokegrenade_projectile"))
		{
			SetNoBlock(entity);
		}
	}
}

public Native_IsPlayerTouchingZoneType(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new MapZoneType:type = GetNativeCell(2);
	
	return IsPlayerTouchingZoneType(client, type);
}

IsPlayerTouchingZoneType(client, MapZoneType:type)
{
	for (new i = 0; i < g_mapZonesCount; i++)
	{
		if(g_mapZones[i][Type] != type)
			continue;
		
		if(g_bZone[i][client])
			return 1;
	}
	
	return 0;
}

public Native_GetMapzoneCount(Handle:plugin, numParams)
{
	new MapZoneType:type = GetNativeCell(1);
	
	new count = 0;

	if(type == ZtLevel || type == ZtBonusLevel)
	{
		new LevelID[g_mapZonesCount];
		for (new mapZone = 0; mapZone < g_mapZonesCount; mapZone++)
		{
			if (g_mapZones[mapZone][Type] == type)
			{
				LevelID[mapZone] = g_mapZones[mapZone][Level_Id];
			}
		}
		
		SortIntegers(LevelID, g_mapZonesCount, Sort_Ascending);
		
		new lastlevel;
		
		for (new mapZone = 0; mapZone < g_mapZonesCount; mapZone++)
		{
			if (LevelID[mapZone] > lastlevel)
			{
				count++;
				lastlevel = LevelID[mapZone];
			}
		}
	}
	else
	{
		for (new mapZone = 0; mapZone < g_mapZonesCount; mapZone++)
		{
			if (g_mapZones[mapZone][Type] == type)
			{
				count++;
			}
		}
	}
	
	return count;
}

public bool:FilterOnlyPlayers(entity, contentsMask, any:data)
{
	if(entity != data && entity > 0 && entity <= MaxClients) 
		return true;
	return false;
}

stock FindCollisionGroup()
{
	g_ioffsCollisionGroup = FindSendPropOffs("CBaseEntity", "m_CollisionGroup");
}

// For Noblock
stock SetNoBlock(entity)
{
	SetEntData(entity, g_ioffsCollisionGroup, COLLISION_GROUP_DEBRIS_TRIGGER, 4, true);
}

// For Block
stock SetBlock(entity)
{
	SetEntData(entity, g_ioffsCollisionGroup, COLLISION_GROUP_PLAYER, 4, true);
}

// For Push
stock SetPush(entity)
{
	SetEntData(entity, g_ioffsCollisionGroup, COLLISION_GROUP_PUSHAWAY, 4, true);
}

public Action:Hook_NormalSound(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	if (g_Settings[DisableDoorSounds])
	if (StrContains(sample, "door") != -1)
		return Plugin_Stop;
	
	if (g_Settings[DisableButtonSounds])
	if (StrContains(sample, "button") != -1)
		return Plugin_Stop;
	
	return Plugin_Continue;
}

public Action:Command_ToggleTeleporters(client, args)
{
	ToggleTeleporters(client);
	
	return Plugin_Handled;	
}

stock ToggleTeleporters(client)
{
	if(g_bTeleportersDisabled)
	{
		g_bTeleportersDisabled = false;
		
		ReplyToCommand(client, "(Re-)Enabled all trigger_teleport entitys");
		
		new entity;
		decl String:targetname[256];
		
		while ((entity = FindEntityByClassname(entity, "info_teleport_destination")) != -1)
		{
			GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
			ReplaceString(targetname, sizeof(targetname), "_disabled", "", true);
			DispatchKeyValue(entity, "targetname", targetname);
		}
	}
	else
	{
		g_bTeleportersDisabled = true;
		
		ReplyToCommand(client, "Disabled all trigger_teleport entitys");
		
		new entity;
		decl String:targetname[256];
		
		while ((entity = FindEntityByClassname(entity, "info_teleport_destination")) != -1)
		{
			GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
			Format(targetname, sizeof(targetname), "%s_disabled", targetname);
			DispatchKeyValue(entity, "targetname", targetname);
		}
	}
}

public Action:Timer_FixAngRotation(Handle:timer)
{
	FixAngRotation();
	return Plugin_Continue;
}

stock FixAngRotation()
{
	new entity;
	while ((entity = FindEntityByClassname(entity, "func_rotating")) != -1)
	{
		new Float:ang[3];
		GetEntPropVector(entity, Prop_Send, "m_angRotation", ang);
		
		if(ang[0] > 360.0 || ang[1] > 360.0 || ang[2] > 360.0 || ang[0] < -360.0 || ang[1] < -360.0 || ang[2] < -360.0)
		{
			ang[0] = float(RoundToFloor(ang[0]) % 60);
			ang[1] = float(RoundToFloor(ang[1]) % 60);
			ang[2] = float(RoundToFloor(ang[2]) % 60);
			
			SetEntPropVector(entity, Prop_Send, "m_angRotation", ang);
		}
	}
}