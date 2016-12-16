#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <timer>
#include <timer-mysql>
#include <timer-config_loader>
#include <timer-stocks>

#undef REQUIRE_PLUGIN
#include <timer-logging>
#include <timer-mapzones>
#include <timer-teams>
#include <timer-physics>
#include <timer-strafes>
#include <timer-worldrecord>
#include <timer-scripter_db>
#define MAX_FILE_LEN 128

new bool:g_timerLogging = false;
new bool:g_timerPhysics = false;
new bool:g_timerStrafes = false;
new bool:g_timerScripterDB = false;
new bool:g_timerTeams = false;
new bool:g_timerWorldRecord = false;

/** 
 * Global Enums
 */
 
enum Timerex
{
	Enabled,
	Float:StartTime,
	Float:EndTime,
	Jumps,
	bool:IsPaused,
	Float:PauseStartTime,
	Float:PauseLastOrigin[3],
	Float:PauseLastVelocity[3],
	Float:PauseLastAngles[3],
	Float:PauseTotalTime,
	CurrentStyle,
	FpsMax,
	Track,
	String:ReplayFile[32]
}

enum BestTimeCacheEntity
{
	IsCached,
	Jumps,
	Float:Time
}

/**
 * Global Variables
 */
new Handle:g_hSQL;

new String:g_currentMap[64];

new g_GetPauseLevel[MAXPLAYERS+1];

new g_timers[MAXPLAYERS+1][Timerex];
new g_bestTimeCache[MAXPLAYERS+1][BestTimeCacheEntity];

new Handle:g_timerStartedForward;
new Handle:g_timerStoppedForward;
new Handle:g_timerRestartForward;
new Handle:g_timerPausedForward;
new Handle:g_timerResumedForward;

new Handle:g_timerWorldRecordForward;
new Handle:g_timerPersonalRecordForward;
new Handle:g_timerTop10RecordForward;
new Handle:g_timerFirstRecordForward;
new Handle:g_timerRecordForward;
new Handle:g_OnClientChangeStyle;

new g_iVelocity;

public Plugin:myinfo =
{
    name        = "[TIMER] Core",
    author      = "Zipcore, Credits: Alongub, DR. API Improvements",
    description = "Core component for [Timer]",
    version     = PL_VERSION,
    url         = "zipcore#googlemail.com"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegPluginLibrary("timer");
	
	CreateNative("Timer_Reset", Native_Reset);
	CreateNative("Timer_Start", Native_Start);
	CreateNative("Timer_Stop", Native_Stop);
	CreateNative("Timer_Pause", Native_Pause);
	CreateNative("Timer_Resume", Native_Resume);
	CreateNative("Timer_Restart", Native_Restart);
	CreateNative("Timer_FinishRound", Native_FinishRound);
	CreateNative("Timer_GetClientTimer", Native_GetClientTimer);
	CreateNative("Timer_GetStatus", Native_GetStatus);
	CreateNative("Timer_GetPauseStatus", Native_GetPauseStatus);
	CreateNative("Timer_SetStyle", Native_SetStyle);
	CreateNative("Timer_GetStyle", Native_GetStyle);
	CreateNative("Timer_IsStyleRanked", Native_IsStyleRanked);
	CreateNative("Timer_GetTrack", Native_GetTrack);
	CreateNative("Timer_SetTrack", Native_SetTrack);
	CreateNative("Timer_ForceClearCacheBest", Native_ForceClearCacheBest);
	CreateNative("Timer_AddPenaltyTime", Native_AddPenaltyTime);
	CreateNative("Timer_GetClientActiveReplayPath", Native_GetClientActiveReplayPath);
	CreateNative("Timer_GetClientActiveReplayFileName", Native_GetClientActiveReplayFileName);

	return APLRes_Success;
}

public OnPluginStart()
{
	ConnectSQL();
	LoadPhysics();
	LoadTimerSettings();
	
	CreateConVar("timer_version", PL_VERSION, "Timer Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	g_timerStartedForward = CreateGlobalForward("OnTimerStarted", ET_Event, Param_Cell);
	g_timerStoppedForward = CreateGlobalForward("OnTimerStopped", ET_Event, Param_Cell);
	g_timerRestartForward = CreateGlobalForward("OnTimerRestart", ET_Event, Param_Cell);
	g_timerPausedForward = CreateGlobalForward("OnTimerPaused", ET_Event, Param_Cell);
	g_timerResumedForward = CreateGlobalForward("OnTimerResumed", ET_Event, Param_Cell);
	
	g_timerWorldRecordForward = CreateGlobalForward("OnTimerWorldRecord", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_timerPersonalRecordForward = CreateGlobalForward("OnTimerPersonalRecord", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_timerTop10RecordForward = CreateGlobalForward("OnTimerTop10Record", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_timerFirstRecordForward = CreateGlobalForward("OnTimerFirstRecord", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_timerRecordForward = CreateGlobalForward("OnTimerRecord", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_OnClientChangeStyle = CreateGlobalForward("OnClientChangeStyle", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	
	g_iVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
	
	LoadTranslations("drapi/drapi_timer-core.phrases");
	
	RegConsoleCmd("sm_credit", Command_Credits);
	
	if(g_Settings[PauseEnable])
	{ 
		RegConsoleCmd("sm_pause", Command_Pause);
		RegConsoleCmd("sm_resume", Command_Resume);
	}

	RegAdminCmd("sm_droptable", Command_DropTable, ADMFLAG_ROOT);
	
	HookEvent("player_jump", Event_PlayerJump);
	HookEvent("player_death", Event_StopTimer);
	HookEvent("player_team", Event_StopTimer);
	HookEvent("player_spawn", Event_StopTimer);
	HookEvent("player_disconnect", Event_StopTimer);
	

	g_timerLogging = LibraryExists("timer-logging");
	g_timerPhysics = LibraryExists("timer-physics");
	g_timerStrafes = LibraryExists("timer-strafes");
	g_timerScripterDB = LibraryExists("timer-scripter_db");
	g_timerTeams = LibraryExists("timer-teams");
	g_timerWorldRecord = LibraryExists("timer-worldrecord");
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "timer-logging"))
	{
		g_timerLogging = true;
	}
	else if (StrEqual(name, "timer-physics"))
	{
		g_timerPhysics = true;
	}
	else if (StrEqual(name, "timer-strafes"))
	{
		g_timerStrafes = true;
	}
	else if (StrEqual(name, "timer-scripter_db"))
	{
		g_timerScripterDB = true;
	}
	else if (StrEqual(name, "timer-teams"))
	{
		g_timerTeams = true;
	}
	else if (StrEqual(name, "timer-worldrecord"))
	{
		g_timerWorldRecord = true;
	}
}

public OnLibraryRemoved(const String:name[])
{	
	if (StrEqual(name, "timer-logging"))
	{
		g_timerLogging = false;
	}
	else if (StrEqual(name, "timer-physics"))
	{
		g_timerPhysics = false;
	}
	else if (StrEqual(name, "timer-strafes"))
	{
		g_timerStrafes = false;
	}
	else if (StrEqual(name, "timer-scripter_db"))
	{
		g_timerScripterDB = false;
	}
	else if (StrEqual(name, "timer-teams"))
	{
		g_timerTeams = false;
	}
	else if (StrEqual(name, "timer-worldrecord"))
	{
		g_timerWorldRecord = false;
	}
}

public OnClientAuthorized(client, const String:auth[])
{
	if (g_hSQL == INVALID_HANDLE)
		ConnectSQL();
	
	if (g_hSQL != INVALID_HANDLE)
	{
		if(StrContains(auth, "STEAM", true) > -1)
		{
			if(Client_IsValid(client) && !IsFakeClient(client))
			{
				decl String:name[MAX_NAME_LENGTH];
				GetClientName(client, name, sizeof(name));
			
				decl String:safeName[2 * strlen(name) + 1];
				SQL_EscapeString(g_hSQL, name, safeName, 2 * strlen(name) + 1);
			
				decl String:query[256];
				FormatEx(query, sizeof(query), "UPDATE `round` SET name = '%s' WHERE auth = '%s'", safeName, auth);

				SQL_TQuery(g_hSQL, UpdateNameCallback, query, _, DBPrio_Normal);
			}
		}
		else if(!IsFakeClient(client) && IsClientSourceTV(client)) KickClient(client, "NO VALID STEAM ID");
	}
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

public OnMapStart()
{	
	GetCurrentMap(g_currentMap, sizeof(g_currentMap));
	ClearCache();
	
	LoadPhysics();
	LoadTimerSettings();
}
/**
 * Events
 */
public Action:Event_PlayerJump(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (g_timers[client][Enabled] && !g_timers[client][IsPaused])
		g_timers[client][Jumps]++;
	
	return Plugin_Continue;
}

public Action:Event_StopTimer(Handle:event, const String:name[], bool:dontBroadcast)
{
	StopTimer(GetClientOfUserId(GetEventInt(event, "userid")), false);
	return Plugin_Continue;
}

public Action:Event_StopTimerPaused(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(0 < client <= MaxClients) if (IsClientInGame(client)) StopTimer(client);
	return Plugin_Continue;
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(0 < client <= MaxClients)
	{
		if(IsClientInGame(client))
			StopTimer(client);
	}
}

public Action:Command_Stop(client, args)
{
	if (IsPlayerAlive(client))
		StopTimer(client, false);
		
	return Plugin_Handled;
}

public Action:Command_Pause(client, args)
{
	if (g_Settings[PauseEnable] && IsPlayerAlive(client))
		PauseTimer(client);
		
	return Plugin_Handled;
}

public Action:Command_Resume(client, args)
{
	if (g_Settings[PauseEnable] && IsPlayerAlive(client))
		ResumeTimer(client);
		
	return Plugin_Handled;
}

public Action:Command_DropTable(client, args)
{
	if (g_hSQL == INVALID_HANDLE)
		ConnectSQL();
	
	if (g_hSQL != INVALID_HANDLE)
	{
		decl String:query[64];
		FormatEx(query, sizeof(query), "DROP TABLE round");
		SQL_TQuery(g_hSQL, DropTable, query, _, DBPrio_Normal);
	}
	
	return Plugin_Handled;
}

public DropTable(Handle:owner, Handle:hndl, const String:error[], any:client)
{
	if (hndl == INVALID_HANDLE)
	{
		if(g_timerLogging) Timer_LogError("SQL Error on DropTable: %s", error);
	}
}

public FpsMaxCallback(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[])
{
	g_timers[client][FpsMax] = StringToInt(cvarValue);
}

/**
 * Core Functionality
 */
bool:ResetTimer(client)
{
	//Forward Timer_Stopped(client)
	Call_StartForward(g_timerStoppedForward);
	Call_PushCell(client);
	Call_Finish();
	
	//Stop mate
	if (g_timerTeams)
	{
		new mate = Timer_GetClientTeammate(client);
		if(0 < mate)
		{
			StopTimer(mate, false);
			Call_StartForward(g_timerStoppedForward);
			Call_PushCell(mate);
			Call_Finish();
		}
	}
	
	g_timers[client][Enabled] = false;
	g_timers[client][StartTime] = GetGameTime();
	g_timers[client][EndTime] = -1.0;
	g_timers[client][Jumps] = 0;
	g_timers[client][IsPaused] = false;
	g_timers[client][PauseStartTime] = 0.0;
	g_timers[client][PauseTotalTime] = 0.0;
	g_timers[client][ReplayFile][0] = '\0';
	
	if(g_timerPhysics) Timer_ResetAccuracy(client);
	
	return true;
}

bool:TimerPenalty(client, Float:penaltytime)
{
	g_timers[client][StartTime] -= penaltytime;
	
	return true;
}
 
bool:StartTimer(client)
{
	if(!IsValidClient(client))
		return false;
	if (g_timers[client][Enabled])
		return false;
	
	g_timers[client][Enabled] = true;
	g_timers[client][StartTime] = GetGameTime();
	g_timers[client][EndTime] = -1.0;
	g_timers[client][Jumps] = 0;
	g_timers[client][IsPaused] = false;
	g_timers[client][PauseStartTime] = 0.0;
	g_timers[client][PauseTotalTime] = 0.0;
	g_timers[client][ReplayFile][0] = '\0';
	
	if(g_timerPhysics) Timer_ResetAccuracy(client);
	
	//Check for custom settings
	QueryClientConVar(client, "fps_max", FpsMaxCallback, client);

	//Push Forward Timer_Started(client)
	Call_StartForward(g_timerStartedForward);
	Call_PushCell(client);
	Call_Finish();
	return true;
}

bool:StopTimer(client, bool:stopPaused = true)
{
	if(!IsValidClient(client))
		return false;
	if (!g_timers[client][Enabled])
		return false;
	
	//Already paused?
	if (!stopPaused && g_timers[client][IsPaused])
		return false;
	
	//EmitSoundToClient(client, SND_TIMER_STOP);
	
	//Get time
	g_timers[client][Enabled] = false;
	g_timers[client][EndTime] = GetGameTime();
	
	//Prevent Resume
	if (!stopPaused) g_timers[client][IsPaused] = false;
	
	//Forward Timer_Stopped(client)
	Call_StartForward(g_timerStoppedForward);
	Call_PushCell(client);
	Call_Finish();
	
	//Stop mate
	if (g_timerTeams)
	{
		new mate = Timer_GetClientTeammate(client);
		if(0 < mate)
		{
			StopTimer(mate, false);
			Call_StartForward(g_timerStoppedForward);
			Call_PushCell(mate);
			Call_Finish();
		}
	}
		
	return true;
}

bool:RestartTimer(client)
{
	if(!IsValidClient(client))
		return false;
	
	StopTimer(client, false);
	
	//Forward Timer_Restarted(client)
	Call_StartForward(g_timerRestartForward);
	Call_PushCell(client);
	Call_Finish();

	if (g_timerTeams)
	{
		new mate = Timer_GetClientTeammate(client);
		if(mate != 0) 
		{	
			StopTimer(mate, false);

			Call_StartForward(g_timerRestartForward);
			Call_PushCell(mate);
			Call_Finish();

			return StartTimer(client) && StartTimer(mate);
		}
	}

	return StartTimer(client);
}

bool:PauseTimer(client)
{
	if(!IsValidClient(client))
		return false;
	if (!g_timers[client][Enabled] || g_timers[client][IsPaused])
		return false;
	
	g_timers[client][IsPaused] = true;
	g_timers[client][PauseStartTime] = GetGameTime();
	g_GetPauseLevel[client] = Timer_GetClientLevel(client);
	
	CreateTimer(0.0, Timer_ValidatePause, client, TIMER_FLAG_NO_MAPCHANGE);
	
	CPrintToChat(client, "%t", "Pause Info");

	new Float:origin[3];
	GetClientAbsOrigin(client, origin);
	Array_Copy(origin, g_timers[client][PauseLastOrigin], 3);

	new Float:angles[3];
	GetClientAbsAngles(client, angles);
	Array_Copy(angles, g_timers[client][PauseLastAngles], 3);

	new Float:velocity[3];
	GetClientAbsVelocity(client, velocity);
	Array_Copy(velocity, g_timers[client][PauseLastVelocity], 3);

	Call_StartForward(g_timerPausedForward);
	Call_PushCell(client);
	Call_Finish();
	
	if(g_timerTeams) 
	{
		new mate = Timer_GetClientTeammate(client);
		if(0 < mate)
		{
			g_timers[mate][IsPaused] = true;
			g_timers[mate][PauseStartTime] = GetGameTime();
		
			CreateTimer(0.0, Timer_ValidatePause, mate, TIMER_FLAG_NO_MAPCHANGE);
		
			CPrintToChat(client, "%t", "Pause Info");
		
			new Float:origin2[3];
			GetClientAbsOrigin(mate, origin2);
			Array_Copy(origin2, g_timers[mate][PauseLastOrigin], 3);

			new Float:angles2[3];
			GetClientAbsAngles(mate, angles2);
			Array_Copy(angles2, g_timers[mate][PauseLastAngles], 3);

			new Float:velocity2[3];
			GetClientAbsVelocity(mate, velocity2);
			Array_Copy(velocity2, g_timers[mate][PauseLastVelocity], 3);

			Call_StartForward(g_timerPausedForward);
			Call_PushCell(mate);
			Call_Finish();
		}
	}

	return true;
}

public Action:Timer_ValidatePause(Handle:timer, any:client)
{
	if(CalculateTime(client) < 1.0)
	{
		ResetTimer(client);
	}
	
	return Plugin_Stop;
}

bool:ResumeTimer(client)
{
	if(!IsValidClient(client))
		return false;
	if (!g_timers[client][Enabled] || !g_timers[client][IsPaused])
		return false;

	new Float:origin[3];
	Array_Copy(g_timers[client][PauseLastOrigin], origin, 3);

	new Float:angles[3];
	Array_Copy(g_timers[client][PauseLastAngles], angles, 3);

	new Float:velocity[3];
	Array_Copy(g_timers[client][PauseLastVelocity], velocity, 3);

	//Disable NoClip: do not break the client timer
	if (GetEntityMoveType(client) == MOVETYPE_NOCLIP)
	{
		SetEntityMoveType(client, MOVETYPE_WALK);
	}
	
	TeleportEntity(client, origin, angles, velocity);
	
	g_timers[client][IsPaused] = false;
	g_timers[client][PauseTotalTime] += GetGameTime() - g_timers[client][PauseStartTime];
	
	Timer_SetClientLevel(client, g_GetPauseLevel[client]);

	Call_StartForward(g_timerResumedForward);
	Call_PushCell(client);
	Call_Finish();

	if(g_timerTeams)
	{
		new mate = Timer_GetClientTeammate(client);
		if(0 < mate)
		{
			new Float:origin2[3];
			Array_Copy(g_timers[mate][PauseLastOrigin], origin2, 3);

			new Float:angles2[3];
			Array_Copy(g_timers[mate][PauseLastAngles], angles2, 3);

			new Float:velocity2[3];
			Array_Copy(g_timers[mate][PauseLastVelocity], velocity2, 3);

			//Disable NoClip: do not break the mate timer
			if (GetEntityMoveType(mate) == MOVETYPE_NOCLIP)
			{
				SetEntityMoveType(mate, MOVETYPE_WALK);
			}
			
			TeleportEntity(mate, origin2, angles2, velocity2);

			g_timers[mate][IsPaused] = false;
			g_timers[mate][PauseTotalTime] += GetGameTime() - g_timers[mate][PauseStartTime];

			Call_StartForward(g_timerResumedForward);
			Call_PushCell(mate);
			Call_Finish();
		}
	}
	
	return true;
}

ClearCache()
{
	for (new client = 1; client <= MaxClients; client++)
		ClearClientCache(client);
}

ClearClientCache(client)
{
	g_bestTimeCache[client][IsCached] = false;
	g_bestTimeCache[client][Jumps] = 0;
	g_bestTimeCache[client][Time] = 0.0;	
}

FinishRound(client, const String:map[], Float:time, jumps, style, fpsmax, track)
{
	if (!IsClientInGame(client))
		return;
	if (IsFakeClient(client))
		return;
	
	decl String:auth[64];
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
	
	//ignore unranked
	if(g_timerPhysics) 
		if (g_Physics[style][StyleCategory] != MCategory_Ranked || !(bool:Timer_IsStyleRanked(style)))
			return;
	
	new flashbangcount; //TODO
	
	new stage;
	
	if(track == TRACK_NORMAL)
		stage = LEVEL_END;
	else if(track == TRACK_BONUS)
		stage = LEVEL_BONUS_END;
	else
		stage = Timer_GetClientLevel(client);
	
	if (time < 1.0)
	{
		if(g_timerLogging) Timer_Log(Timer_LogLevelWarning, "Detected illegal record by %N on %s [time:%.2f|style:%d|track:%d|jumps:%d] SteamID: %s", client, g_currentMap, time, style, track, jumps, auth);
		return;
	}
	
	if(g_timerScripterDB)
	{
		if (Timer_IsScripter(client))
		{
			if(g_timerLogging) Timer_Log(Timer_LogLevelWarning, "Detected scripter record by %N on %s [time:%.2f|style:%d|track:%d|jumps:%d] SteamID: %s", client, g_currentMap, time, style, track, jumps, auth);
			return;
		}
	}
	
	//Record Info
	new RecordId;
	new Float:RecordTime;
	new RankTotal;
	
	//Personal Record
	new currentrank, newrank;	
	if(g_timerWorldRecord) 
	{
		currentrank = Timer_GetStyleRank(client, track, style);	
		newrank = Timer_GetNewPossibleRank(style, track, time);
	}
	
	new Float:LastTime;
	new Float:LastTimeStatic;
	new LastJumps;
	decl String:TimeDiff[32];
	decl String:buffer[32];
	
	new bool:NewPersonalRecord = false;
	new bool:NewWorldRecord = false;
	new bool:FirstRecord = false;
	
	new Float:jumpacc;
	if(g_timerPhysics) Timer_GetJumpAccuracy(client, jumpacc);
	
	new strafes, strafes_boosted, Float:strafeacc;
	if(g_timerStrafes) 
	{
		strafes = Timer_GetStrafeCount(client);
		strafes_boosted = Timer_GetBoostedStrafeCount(client);
	
		if(strafes < 1)
		{
			strafes = 1;
		}
	
		strafeacc = 100.0-(100.0*(float(strafes_boosted)/float(strafes)));
	}	
	
	//get speed
	new Float:maxspeed, Float:currentspeed, Float:avgspeed;
	if(g_timerPhysics) 
	{	
		Timer_GetMaxSpeed(client, maxspeed);
		Timer_GetCurrentSpeed(client, currentspeed);
		Timer_GetAvgSpeed(client, avgspeed);
	}

	//Player Info

	decl String:name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	
	decl String:safeName[2 * strlen(name) + 1];

	if (g_hSQL == INVALID_HANDLE)
		ConnectSQL();
	
	if (g_hSQL != INVALID_HANDLE)
	{
		SQL_EscapeString(g_hSQL, name, safeName, 2 * strlen(name) + 1);
	}
	
	/* Get Personal Record */
	if(g_timerWorldRecord && Timer_GetBestRound(client, style, track, LastTime, LastJumps))
	{
		LastTimeStatic = LastTime;
		LastTime -= time;			
		if(LastTime < 0.0)
		{
			LastTime *= -1.0;
			Timer_SecondsToTime(LastTime, buffer, sizeof(buffer), 3);
			FormatEx(TimeDiff, sizeof(TimeDiff), "+%s", buffer);
		}
		else if(LastTime > 0.0)
		{
			Timer_SecondsToTime(LastTime, buffer, sizeof(buffer), 3);
			FormatEx(TimeDiff, sizeof(TimeDiff), "-%s", buffer);
		}
		else if(LastTime == 0.0)
		{
			Timer_SecondsToTime(LastTime, buffer, sizeof(buffer), 3);
			FormatEx(TimeDiff, sizeof(TimeDiff), "%s", buffer);
		}
	}
	else
	{
		//No personal record, this is his first record
		FirstRecord = true;
		LastTime = 0.0;
		Timer_SecondsToTime(LastTime, buffer, sizeof(buffer), 3);
		FormatEx(TimeDiff, sizeof(TimeDiff), "%s", buffer);
		RankTotal++;
	}

	/* Get World Record */
	if(g_timerWorldRecord) Timer_GetStyleRecordWRStats(style, track, RecordId, RecordTime, RankTotal);
	
	/* Detect Record Type */
	if(RecordTime == 0.0 || time < RecordTime)
	{
		NewWorldRecord = true;
	}
	
	if(LastTimeStatic == 0.0 || time < LastTimeStatic)
	{
		NewPersonalRecord = true;
	}
	
	/* Forwards */
	Call_StartForward(g_timerRecordForward);
	Call_PushCell(client);
	Call_PushCell(track);
	Call_PushCell(style);
	Call_PushCell(time);
	Call_PushCell(LastTimeStatic);
	Call_PushCell(currentrank);
	Call_PushCell(newrank);
	Call_Finish();
	
	if(NewWorldRecord)
	{
		Call_StartForward(g_timerWorldRecordForward);
		Call_PushCell(client);
		Call_PushCell(track);
		Call_PushCell(style);
		Call_PushCell(time);
		Call_PushCell(LastTimeStatic);
		Call_PushCell(currentrank);
		Call_PushCell(newrank);
		Call_Finish();
	}
	
	if(NewPersonalRecord)
	{
		Call_StartForward(g_timerPersonalRecordForward);
		Call_PushCell(client);
		Call_PushCell(track);
		Call_PushCell(style);
		Call_PushCell(time);
		Call_PushCell(LastTimeStatic);
		Call_PushCell(currentrank);
		Call_PushCell(newrank);
		Call_Finish();
	}
	
	if(newrank <= 10)
	{
		Call_StartForward(g_timerTop10RecordForward);
		Call_PushCell(client);
		Call_PushCell(track);
		Call_PushCell(style);
		Call_PushCell(time);
		Call_PushCell(LastTimeStatic);
		Call_PushCell(currentrank);
		Call_PushCell(newrank);
		Call_Finish();
	}
	
	if(FirstRecord)
	{
		Call_StartForward(g_timerFirstRecordForward);
		Call_PushCell(client);
		Call_PushCell(track);
		Call_PushCell(style);
		Call_PushCell(time);
		Call_PushCell(LastTimeStatic);
		Call_PushCell(currentrank);
		Call_PushCell(newrank);
		Call_Finish();
	}
	
	if (g_hSQL != INVALID_HANDLE)
	{
		if(FirstRecord || NewPersonalRecord)
		{
			//Save record
			decl String:query[2048];
			FormatEx(query, sizeof(query), "INSERT INTO round (map, auth, time, jumps, style, name, fpsmax, track, rank, jumpacc, maxspeed, avgspeed, finishspeed, finishcount, strafes, strafeacc, flashbangcount, stage, replaypath) VALUES ('%s', '%s', %f, %d, %d, '%s', %d, %d, %d, %f, %f, %f, %f, 1, %d, %f, %d, %d, '%s') ON DUPLICATE KEY UPDATE time = '%f', jumps = '%d', name = '%s', fpsmax = '%d', rank = '%d', jumpacc = '%f', maxspeed = '%f', avgspeed = '%f', finishspeed = '%f', finishcount = finishcount + 1, strafes = '%d', strafeacc = '%f', flashbangcount = '%d', stage = '%d', replaypath = '%s', date = CURRENT_TIMESTAMP();", map, auth, time, jumps, style, safeName, fpsmax, track, newrank, jumpacc, maxspeed, avgspeed, currentspeed, strafes, strafeacc, flashbangcount, stage, g_timers[client][ReplayFile], time, jumps, safeName, fpsmax, newrank, jumpacc, maxspeed, avgspeed, currentspeed, strafes, strafeacc, flashbangcount, stage, g_timers[client][ReplayFile]);
			SQL_TQuery(g_hSQL, FinishRoundCallback, query, client, DBPrio_High);
		}
		else
		{
			decl String:query[2048];
			FormatEx(query, sizeof(query), "INSERT INTO round (map, auth, time, jumps, style, name, fpsmax, track, rank, jumpacc, maxspeed, avgspeed, finishspeed, finishcount, strafes, strafeacc, flashbangcount, stage, replaypath) VALUES ('%s', '%s', %f, %d, %d, '%s', %d, %d, %d, %f, %f, %f, %f, 1, %d, %f, %d, %d, '%s') ON DUPLICATE KEY UPDATE name = '%s', finishcount = finishcount + 1;", map, auth, time, jumps, style, safeName, fpsmax, track, newrank, jumpacc, maxspeed, avgspeed, currentspeed, strafes, strafeacc, flashbangcount, stage, g_timers[client][ReplayFile], safeName);
			SQL_TQuery(g_hSQL, FinishRoundCallback, query, client, DBPrio_High);
		}
	}
}

public UpdateNameCallback(Handle:owner, Handle:hndl, const String:error[], any:param1)
{
	if (hndl == INVALID_HANDLE)
	{
		if(g_timerLogging) Timer_LogError("SQL Error on UpdateName: %s", error);
		return;
	}

	if (g_timerWorldRecord) 
	{
		Timer_ForceReloadCache();
	}
}

public DeletePlayersRecordCallback(Handle:owner, Handle:hndl, const String:error[], any:param1)
{
	if (hndl == INVALID_HANDLE)
	{
		if(g_timerLogging) Timer_LogError("SQL Error on DeletePlayerRecord: %s", error);
		return;
	}
}

public FinishRoundCallback(Handle:owner, Handle:hndl, const String:error[], any:client)
{
	if (hndl == INVALID_HANDLE)
	{
		if(g_timerLogging) Timer_LogError("SQL Error on FinishRound: %s", error);
		return;
	}

	g_bestTimeCache[client][IsCached] = false;
	
	if(g_timerWorldRecord) Timer_ForceReloadCache();
}

Float:CalculateTime(client)
{
	if (g_timers[client][Enabled] && g_timers[client][IsPaused])
		return g_timers[client][PauseStartTime] - g_timers[client][StartTime] - g_timers[client][PauseTotalTime];
	else
		return (g_timers[client][Enabled] ? GetGameTime() : g_timers[client][EndTime]) - g_timers[client][StartTime] - g_timers[client][PauseTotalTime];	
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
	else Timer_LogInfo("[Timer] MySQL connection established and conneted to timer-core.");
}

public Action:Timer_SQLReconnect(Handle:timer, any:data)
{
	ConnectSQL();
	return Plugin_Stop;
}

public Native_Reset(Handle:plugin, numParams)
{
	return ResetTimer(GetNativeCell(1));
}

public Native_Start(Handle:plugin, numParams)
{
	return StartTimer(GetNativeCell(1));
}

public Native_Stop(Handle:plugin, numParams)
{
	return StopTimer(GetNativeCell(1), bool:GetNativeCell(2));
}

public Native_Restart(Handle:plugin, numParams)
{
	return RestartTimer(GetNativeCell(1));
}

public Native_Resume(Handle:plugin, numParams)
{
	if(g_Settings[PauseEnable])
		return ResumeTimer(GetNativeCell(1));
	else
		return false;
}

public Native_Pause(Handle:plugin, numParams)
{
	if(g_Settings[PauseEnable])
		return PauseTimer(GetNativeCell(1));
	else
		return StopTimer(GetNativeCell(1));
}

public Native_GetClientTimer(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	SetNativeCellRef(2, g_timers[client][Enabled]);
	SetNativeCellRef(3, CalculateTime(client));
	SetNativeCellRef(4, g_timers[client][Jumps]);
	SetNativeCellRef(5, g_timers[client][FpsMax]);	

	return true;
}

public Native_FinishRound(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);

	decl String:map[32];
	GetNativeString(2, map, sizeof(map));
	
	new Float:time = GetNativeCell(3);
	new jumps = GetNativeCell(4);
	new style = GetNativeCell(5);
	new fpsmax = GetNativeCell(6);
	new track = GetNativeCell(7);
	
	FinishRound(client, map, time, jumps, style, fpsmax, track);
}

public Native_ForceClearCacheBest(Handle:plugin, numParams)
{
	ClearCache();
}

public Native_SetTrack(Handle:plugin, numParams)
{
	g_timers[GetNativeCell(1)][Track] = GetNativeCell(2);
}

public Native_GetTrack(Handle:plugin, numParams)
{
	return g_timers[GetNativeCell(1)][Track];
}

public Native_SetStyle(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new style = GetNativeCell(2);
	
	int isnewstyle = 0;
	if(style != g_timers[client][CurrentStyle])
	{
		isnewstyle = 1;
	}
	
	Call_StartForward(g_OnClientChangeStyle);
	Call_PushCell(client);
	Call_PushCell(g_timers[client][CurrentStyle]);
	Call_PushCell(style);
	Call_PushCell(isnewstyle);
	Call_Finish();
	
	g_timers[client][CurrentStyle] = style;
	
	if(g_timerPhysics) Timer_ApplyPhysics(client);
}

public Native_AddPenaltyTime(Handle:plugin, numParams)
{
	new Float:penaltytime = GetNativeCell(2);
	return TimerPenalty(GetNativeCell(1), penaltytime);
}

public Native_GetStyle(Handle:plugin, numParams)
{
	return g_timers[GetNativeCell(1)][CurrentStyle];
}

public Native_GetStatus(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	return (g_timers[client][Enabled] && !g_timers[client][IsPaused]);
}

public Native_GetPauseStatus(Handle:plugin, numParams)
{
	return (g_timers[GetNativeCell(1)][IsPaused]);
}

public Native_IsStyleRanked(Handle:plugin, numParams)
{
	return (g_Physics[GetNativeCell(1)][StyleCategory] == MCategory_Ranked);
}

public Native_GetClientActiveReplayPath(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	decl String:path[256], String:auth[64];
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
	Format(path, sizeof(path), "addons/sourcemod/data/botmimic/%d_%d/%s/%s/%s.rec", g_timers[client][CurrentStyle], g_timers[client][Track], g_currentMap, auth, g_timers[client][ReplayFile]);
	ReplaceString(path, sizeof(path), ":", "_", true);
	SetNativeString(2, path, 256);
}

public Native_GetClientActiveReplayFileName(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	SetNativeString(2, g_timers[client][ReplayFile], 32);
}

/**
 * Utils methods
 */
stock GetClientAbsVelocity(client, Float:vecVelocity[3])
{
	for (new x = 0; x < 3; x++)
	{
		vecVelocity[x] = GetEntDataFloat(client, g_iVelocity + (x*4));
	}
}

// CREDITS
public Action:Command_Credits(client, args)
{
	CreditsPanel(client);
	
	return Plugin_Handled;
}

public CreditsPanel(client)
{
	new Handle:panel = CreatePanel();
	SetPanelTitle(panel, "- Timer Credits -");
	
	SetPanelCurrentKey(panel, 8);
	
	DrawPanelText(panel, "     -- Page 1/4 --");
	DrawPanelText(panel, " ");
	DrawPanelText(panel, "Zipcore - Creator and main coder of this plugin");
	DrawPanelText(panel, "Dr.Api - Lot of Improvements and new third plugins");
	DrawPanelText(panel, "Alongub - Timer 1.x");
	DrawPanelText(panel, "Das D - Player Info, Timer Info");
	DrawPanelText(panel, "Panduh - Chatrank");
	DrawPanelText(panel, "Peace-Maker - bot mimic 2, backwards and much more");
	DrawPanelText(panel, "Shavit - Added new features and supported plugin");
	DrawPanelText(panel, "0wn3r - Many small improvements");
	DrawPanelText(panel, "eagle-vision.de - Rewriting advanced php stats");
	DrawPanelItem(panel, "- Next -");
	DrawPanelItem(panel, "- Exit -");
	SendPanelToClient(panel, client, CreditsHandler1, MENU_TIME_FOREVER);

	CloseHandle(panel);
}

public CreditsHandler1 (Handle:menu, MenuAction:action,param1, param2)
{
    if ( action == MenuAction_Select )
    {
		switch (param2)
		{
			case 8:
			{
				CreditsPanel2(param1);
			}
		}
    }
}

public CreditsPanel2(client)
{
	new Handle:panel = CreatePanel();
	SetPanelTitle(panel, "- Timer Credits -");
	
	SetPanelCurrentKey(panel, 7);
	
	DrawPanelText(panel, "     -- Page 2/4 --");
	DrawPanelText(panel, " ");
	DrawPanelText(panel, "DaFox - MP bunny hops");
	DrawPanelText(panel, "Justshoot - Long-Jump stats");
	DrawPanelText(panel, "DieterM75 - cPmod");
	DrawPanelText(panel, "Skippy - Trigger_multiple hooks");
	DrawPanelText(panel, "Miu - Strafe stats");
	DrawPanelText(panel, "Inami - Macrodox detection");
	DrawPanelText(panel, "SMAC Team - Auto jump trigger detection");
	DrawPanelText(panel, "fr3shz - CS:GO pack for surf map");
	DrawPanelItem(panel, "- Back -");
	DrawPanelItem(panel, "- Next -");
	DrawPanelItem(panel, "- Exit -");
	SendPanelToClient(panel, client, CreditsHandler2, MENU_TIME_FOREVER);

	CloseHandle(panel);
}

public CreditsHandler2 (Handle:menu, MenuAction:action,param1, param2)
{
    if ( action == MenuAction_Select )
    {
		switch (param2)
		{
			case 7:
			{
				CreditsPanel(param1);
			}
			case 8:
			{
				CreditsPanel3(param1);
			}
		}
		
    }
}

public CreditsPanel3(client)
{
	new Handle:panel = CreatePanel();
	SetPanelTitle(panel, "- Timer Credits -");
	
	SetPanelCurrentKey(panel, 7);
	
	DrawPanelText(panel, "     -- Page 3/4 --");
	DrawPanelText(panel, " ");
	DrawPanelText(panel, "Jason Bourne - Challenge, Custom-HUD");
	DrawPanelText(panel, "SWATr - Small fixes/changes");
	DrawPanelText(panel, "Smesh292 - No Jail and small fixes/changes");
	DrawPanelText(panel, "Dark Session - Code optimization");
	DrawPanelText(panel, "Mev - Autostrafe");
	DrawPanelText(panel, "1NutWunDeR - Mapchange enforcer");
	DrawPanelText(panel, "Pandora - German translation");
	DrawPanelItem(panel, "- Back -");
	DrawPanelItem(panel, "- Next -");
	DrawPanelItem(panel, "- Exit -");
	SendPanelToClient(panel, client, CreditsHandler3, MENU_TIME_FOREVER);

	CloseHandle(panel);
}

public CreditsHandler3 (Handle:menu, MenuAction:action,param1, param2)
{
    if ( action == MenuAction_Select )
    {
		switch (param2)
		{
			case 7:
			{
				CreditsPanel2(param1);
			}
			case 8:
			{
				CreditsPanel4(param1);
			}
		}
    }
}

public CreditsPanel4(client)
{
	new Handle:panel = CreatePanel();
	SetPanelTitle(panel, "- Timer Credits -");
	
	SetPanelCurrentKey(panel, 7);
	
	DrawPanelText(panel, "     -- Page 4/4 --");
	DrawPanelText(panel, "JKab - France translation");
	DrawPanelText(panel, "Rop - Dutch Translation & much more");
	DrawPanelText(panel, "");
	DrawPanelText(panel, "   ---- Special Thanks ----");
	DrawPanelText(panel, "Schoschy, .#IsKulT, Shadow^_^,");
	DrawPanelText(panel, "Joy. Extan, -XP.| Mr.loser ™.K.W.©,");
	DrawPanelText(panel, "");
	DrawPanelText(panel, " and many others.");
	DrawPanelText(panel, " ");
	DrawPanelItem(panel, "- Back -");
	DrawPanelItem(panel, "- Next -", ITEMDRAW_SPACER);
	DrawPanelItem(panel, "- Exit -");
	SendPanelToClient(panel, client, CreditsHandler4, MENU_TIME_FOREVER);

	CloseHandle(panel);
}

public CreditsHandler4 (Handle:menu, MenuAction:action,param1, param2)
{
    if ( action == MenuAction_Select )
    {
		switch (param2)
		{
			case 7:
			{
				CreditsPanel3(param1);
			}
		}
    }
}
