#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <smlib>
#include <timer>
#include <timer-teams>
#include <timer-rankings>

#include <timer-mapzones>
#include <timer-logging>
#include <timer-stocks>
#include <timer-config_loader>

#undef REQUIRE_PLUGIN
#include <timer-hide>

new String:g_currentMap[64];

new g_clientTeammate[MAXPLAYERS+1]=0;

new bool:g_bClientCoop[MAXPLAYERS+1];
new g_iCoopCountdown[MAXPLAYERS+1];

new bool:g_bClientChallenge[MAXPLAYERS+1];
new g_iChallengeCountdown[MAXPLAYERS+1];

new g_iBet[MAXPLAYERS+1];
new g_iTarget[MAXPLAYERS+1];

new Float:g_fIgnoreTime[MAXPLAYERS+1];
new Float:g_fStartTime[MAXPLAYERS+1];

new Handle:Sound_ChallengeStart = INVALID_HANDLE;
new String:SND_CHALLENGE_START[MAX_FILE_LEN];
new Handle:Sound_TimerOwned = INVALID_HANDLE;
new String:SND_TIMER_OWNED[MAX_FILE_LEN];

new Handle:g_OnChallengeStart;
new Handle:g_OnChallengeConfirm;
new Handle:g_OnChallengeWin;
new Handle:g_OnChallengeForceEnd;

new Handle:g_OnCoopStart;
new Handle:g_OnCoopConfirm;
new Handle:g_OnCoopWin;
new Handle:g_OnCoopForceEnd;

new Float:g_fLastRun[MAXPLAYERS+1];

new bool:g_timerPhysics = false;

public Plugin:myinfo =
{
	name		= "[TIMER] Teams",
	author		= "Zipcore, Jason Bourne, DR. API Improvements",
	description = "[Timer] Team manager",
	version		= PL_VERSION,
	url			= "forums.alliedmods.net/showthread.php?p=2074699"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegPluginLibrary("timer-teams");
	CreateNative("Timer_GetChallengeStatus", Native_GetChallengeStatus);
	CreateNative("Timer_GetCoopStatus", Native_GetCoopStatus);
	
	CreateNative("Timer_GetClientTeammate", Native_GetClientTeammate);
	CreateNative("Timer_SetClientTeammate", Native_SetClientTeammate);
	
	return APLRes_Success;
}

public OnPluginStart()
{
	g_timerPhysics = LibraryExists("timer-physics");
	
	LoadPhysics();
	LoadTimerSettings();
	
	LoadTranslations("drapi/drapi_timer-teams.phrases");

	if(g_Settings[ChallengeEnable]) RegConsoleCmd("sm_challenge", Command_Challenge);
	//if(g_Settings[CoopEnable]) RegConsoleCmd("sm_coop", Command_Coop);

	Sound_ChallengeStart = CreateConVar("timer_sound_challenge_start", "ui/freeze_cam.wav", "");
	Sound_TimerOwned = CreateConVar("timer_sound_owned", "ui/freeze_cam.wav", "");
	
	HookConVarChange(Sound_ChallengeStart, Action_OnSettingsChange);
	HookConVarChange(Sound_TimerOwned, Action_OnSettingsChange);

	g_OnChallengeConfirm = CreateGlobalForward("OnChallengeConfirm", ET_Event, Param_Cell,Param_Cell,Param_Cell,Param_Cell);
	g_OnChallengeStart = CreateGlobalForward("OnChallengeStart", ET_Event, Param_Cell,Param_Cell);
	g_OnChallengeWin = CreateGlobalForward("OnChallengeWin", ET_Event, Param_Cell,Param_Cell);
	g_OnChallengeForceEnd = CreateGlobalForward("OnChallengeForceEnd", ET_Event, Param_Cell,Param_Cell, Param_Cell);
	
	g_OnCoopConfirm = CreateGlobalForward("OnCoopConfirm", ET_Event, Param_Cell,Param_Cell,Param_Cell);
	g_OnCoopStart = CreateGlobalForward("OnCoopStart", ET_Event, Param_Cell,Param_Cell);
	g_OnCoopWin = CreateGlobalForward("OnCoopWin", ET_Event, Param_Cell,Param_Cell);
	g_OnCoopForceEnd = CreateGlobalForward("OnCoopForceEnd", ET_Event, Param_Cell,Param_Cell);
	
	AutoExecConfig(true, "timer/timer-teams");
	
	HookEvent("player_spawn", Event_Reset);
	HookEvent("player_connect", Event_Reset);
	HookEvent("player_disconnect", Event_Reset);
	HookEvent("player_death", Event_Reset);
	HookEvent("player_team", Event_Reset);
}

public OnMapStart()
{
	GetCurrentMap(g_currentMap, sizeof(g_currentMap));
	
	LoadPhysics();
	LoadTimerSettings();
	
	for (new i = 1; i <= MaxClients; i++)
	{
		g_clientTeammate[i] = 0;
		g_fIgnoreTime[i] = 0.0;
		g_fStartTime[i] = 0.0;
	}
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "timer-physics"))
	{
		g_timerPhysics = true;
	}
}

public OnLibraryRemoved(const String:name[])
{	
	if (StrEqual(name, "timer-physics"))
	{
		g_timerPhysics = false;
	}
}

public OnConfigsExecuted()
{
	CacheSounds();
}

public CacheSounds()
{
	GetConVarString(Sound_ChallengeStart, SND_CHALLENGE_START, sizeof(SND_CHALLENGE_START));
	PrepareSound(SND_CHALLENGE_START);
	
	GetConVarString(Sound_TimerOwned, SND_TIMER_OWNED, sizeof(SND_TIMER_OWNED));
	PrepareSound(SND_TIMER_OWNED);
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

public Action_OnSettingsChange(Handle:cvar, const String:oldvalue[], const String:newvalue[])
{
	if (cvar == Sound_ChallengeStart)
		FormatEx(SND_CHALLENGE_START, sizeof(SND_CHALLENGE_START) ,"%s", newvalue);
	else if (cvar == Sound_TimerOwned)
		FormatEx(SND_TIMER_OWNED, sizeof(SND_TIMER_OWNED) ,"%s", newvalue);
}

public Event_Reset(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_clientTeammate[g_clientTeammate[client]] = 0;
	g_bClientChallenge[g_clientTeammate[client]] = false;
	g_bClientCoop[g_clientTeammate[client]] = false;
	g_fIgnoreTime[g_clientTeammate[client]] = 0.0;

	g_clientTeammate[client] = 0;
	g_bClientChallenge[client] = false;
	g_bClientCoop[client] = false;
	g_fIgnoreTime[client] = 0.0;
}

public OnClientStartTouchZoneType(client, MapZoneType:type)
{
	if(!client)
		return;
	
	new mate = Timer_GetClientTeammate(client);
	
	if(!mate)
		return;
	
	if(!g_bClientChallenge[client] && !g_bClientCoop[client])
		return;
		
	if (type == ZtEnd)
	{
		if(g_bClientChallenge[client]) 
		{
			EndChallenge(client, 0);
		}
		else if (g_bClientCoop[client] && Timer_IsPlayerTouchingZoneType(mate, ZtEnd)) 
			EndCoop(client, 0);
	}
}

public OnClientEndTouchZoneType(client, MapZoneType:type)
{
	if(!client)
		return;
	
	new mate = Timer_GetClientTeammate(client);
	
	if(!mate)
		return;
	
	if(!g_bClientChallenge[client] && !g_bClientCoop[client])
		return;
		
	if (type == ZtStart)
	{
		if(g_Settings[CoopOnly])
		{
			if(!g_bClientCoop[client])
			{
				FakeClientCommand(client, "sm_restart");
				CPrintToChat(client, "%t", "Choose your teammate");
			}
		}
	}
}

public Action:Command_Challenge(client, args)
{
	if(!client)
		return Plugin_Handled;
	
	if(g_bClientCoop[client])
	{
		CPrintToChat(client, "%t", "You are already challenging");
	}
	else if(g_bClientCoop[client])
	{
		CPrintToChat(client, "%t", "You are already in coop mode");
	}
	else 
	{
		new Handle:menu = CreateMenu(Handle_PointSelectMenu);
		
		char title[256];
		Format(title, sizeof(title), "%T", "BetMenuTitle", client);
		SetMenuTitle(menu, title);
		
		decl String:buffer[32];
		
		char verylow[256];
		Format(verylow, sizeof(verylow), "%T", "Very Low", client, g_Settings[ChallengeBet1]);
		FormatEx(buffer, sizeof(buffer), "%d", g_Settings[ChallengeBet1]);
		AddMenuItem(menu, buffer, verylow);
		
		
		char low[256];
		Format(low, sizeof(low), "%T", "Low", client, g_Settings[ChallengeBet2]);
		FormatEx(buffer, sizeof(buffer), "%d", g_Settings[ChallengeBet2]);
		AddMenuItem(menu, buffer, low);
		
		
		char mid[256];
		Format(mid, sizeof(mid), "%T", "Mid", client, g_Settings[ChallengeBet3]);
		FormatEx(buffer, sizeof(buffer), "%d", g_Settings[ChallengeBet3]);
		AddMenuItem(menu, buffer, mid);
		
		
		char pro[256];
		Format(pro, sizeof(pro), "%T", "Pro", client, g_Settings[ChallengeBet4]);
		FormatEx(buffer, sizeof(buffer), "%d", g_Settings[ChallengeBet4]);
		AddMenuItem(menu, buffer, pro);
		
		
		char match[256];
		Format(match, sizeof(match), "%T", "Match", client, g_Settings[ChallengeBet5]);
		FormatEx(buffer, sizeof(buffer), "%d", g_Settings[ChallengeBet5]);
		AddMenuItem(menu, buffer, match);
		
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
		
	return Plugin_Handled;
}
	
public Handle_PointSelectMenu(Handle:menu, MenuAction:action, client, itemNum)
{
	if ( action == MenuAction_Select )
	{
		decl String:info[100], String:info2[100];
		new bool:found = GetMenuItem(menu, itemNum, info, sizeof(info), _, info2, sizeof(info2));
		if(found)
		{
			g_iBet[client] = StringToInt(info);
			Menu_SelectChallengeMate(client);
		}
	}
}

Menu_SelectChallengeMate(client)
{	
	new Handle:menu = CreateMenu(MenuHandlerChallenge);
	char title[256];
	Format(title, sizeof(title), "%T", "Select your opponent", client);
	SetMenuTitle(menu, title);
	
	new iCount = 0;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if(!Client_IsValid(i))
		{
			continue;
		}
		
		if(IsFakeClient(i))
		{
			continue;
		}
		
		if(client == i)
		{
			continue;
		}
		
		if(g_bClientCoop[i])
		{
			continue;
		}
		
		if(g_bClientChallenge[i])
		{
			continue;
		}
		
		if(GetGameTime() < g_fIgnoreTime[i])
		{
			continue;
		}
		
		decl String:name2[32];
		FormatEx(name2, sizeof(name2), "%N", i);
		decl String:zone2[32];
		FormatEx(zone2,sizeof(zone2),"%d", i);
		AddMenuItem(menu, zone2, name2);
		
		iCount++;
	}

	if(iCount == 0)
	{
		CPrintToChat(client, "%t", "No Target found");
		return;
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 20);
}

public MenuHandlerChallenge(Handle:menu, MenuAction:action, creator, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[100], String:info2[100];
		new bool:found = GetMenuItem(menu, param2, info, sizeof(info), _, info2, sizeof(info2));
		new client = StringToInt(info);
		
		if(IsFakeClient(client))
		{
			StartChallenge(client, creator);
			
			Call_StartForward(g_OnChallengeConfirm);
			Call_PushCell(client);
			Call_PushCell(creator);
			Call_PushCell(g_iBet[creator]);
			Call_Finish();
		}
		
		if(found)
		{
			if(IsClientInGame(client))
			{
				new Handle:menu2 = CreateMenu(MenuHandlerChallengeConfirm);
				if(g_Settings[MultimodeEnable])
				{
					char title[256];
					Format(title, sizeof(title), "%T", "Confirm challenge style", client, creator, g_Physics[Timer_GetStyle(creator)][StyleName], g_iBet[creator]);
					SetMenuTitle(menu2, title);
				}
				else 
				{
					char title[256];
					Format(title, sizeof(title), "%T", "Confirm challenge", client, creator, g_iBet[creator]);
					SetMenuTitle(menu2, title);
				}
			
				decl String:name[32];
				FormatEx(name, sizeof(name),"%d", creator);
				g_iTarget[client] = creator;
				
				char yes[256];
				Format(yes, sizeof(yes), "%T", "Yes", client, creator);
				AddMenuItem(menu2, name, yes);
				
				char no[256];
				Format(no, sizeof(no), "%T", "No", client, creator);
				AddMenuItem(menu2, "no", no);
			
				SetMenuExitButton(menu, true);
				DisplayMenu(menu2, client, 20);
			}
		}
	}
}

public MenuHandlerChallengeConfirm(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[100], String:info2[100];
		new bool:found = GetMenuItem(menu, param2, info, sizeof(info), _, info2, sizeof(info2));
		new target = g_iTarget[client];
		
		if(!target || target <= 0)
		{
			CPrintToChat(client, "%t", "Invalid target");
			return;
		}
		
		if(StrEqual(info, "no"))
		{
			if(IsClientInGame(target)) 
			{
				if(g_Settings[ChallengeIgnoreCooldown] > 0) 
				{
					CPrintToChat(target, "%t", "Rejected your challenge request", client, RoundToFloor(g_Settings[ChallengeIgnoreCooldown]));
				}
				else 
				{
					CPrintToChat(target, "%t", "Rejected your challenge request2", client);
				}
			}
		}
		else if(found)
		{
			g_fIgnoreTime[client] = GetGameTime() + g_Settings[ChallengeIgnoreCooldown];
			if(g_Settings[ChallengeIgnoreCooldown] > 0) 
			{
				CPrintToChat(client, "%t", "You can't be challenged next", RoundToFloor(g_Settings[ChallengeIgnoreCooldown]));
			}	
			g_iBet[client] = g_iBet[target];
			StartChallenge(client, target);
			
			Call_StartForward(g_OnChallengeConfirm);
			Call_PushCell(client);
			Call_PushCell(target);
			Call_PushCell(g_iBet[target]);
			Call_Finish();
		}
	}
}

StartChallenge(client, target)
{
	FakeClientCommand(client, "sm_start");
	FakeClientCommand(target, "sm_start");
	
	Timer_SetClientTeammate(client, target, 1);
	Timer_SetStyle(client, Timer_GetStyle(target));
	
	SetEntityMoveType(client, MOVETYPE_NONE);
	SetEntityMoveType(target, MOVETYPE_NONE);
	
	Timer_SetClientHide(client, 1);
	Timer_SetClientHide(target, 1);
	
	g_iChallengeCountdown[client] = 5;
	g_iChallengeCountdown[target] = 5;
	
	g_fLastRun[client] = 0.0;
	g_fLastRun[target] = 0.0;
	
	Timer_SetTrack(client, TRACK_NORMAL);
	Timer_SetTrack(target, TRACK_NORMAL);
	
	g_bClientChallenge[client] = true;
	g_bClientChallenge[target] = true;

	CreateTimer(1.0, ChallengeCountdown, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(1.0, ChallengeCountdown, target, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:ChallengeCountdown(Handle:timer, any:client)
{
	if(!IsClientInGame(client))
		return Plugin_Stop;
	
	PrintCenterText(client, "%d", g_iChallengeCountdown[client]);
	
	g_iChallengeCountdown[client]--;
	
	if(g_iChallengeCountdown[client] <= 0)
	{
		PrintCenterText(client, "GO GO GO !!!");
		EmitSoundToClient(client, SND_CHALLENGE_START);
		SetEntityMoveType(client, MOVETYPE_WALK);
		new mate = Timer_GetClientTeammate(client);
		
		Call_StartForward(g_OnChallengeStart);
		Call_PushCell(client);
		Call_PushCell(mate);
		Call_Finish();
		
		Timer_Start(client);
		Timer_Start(mate);
		
		new Float:time = GetGameTime();
		
		g_fStartTime[client] = time;
		g_fStartTime[mate] = time;
		
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action:Command_Coop(client, args)
{
	new Handle:menu = CreateMenu(MenuHandlerCoop);
	char title[256];
	Format(title, sizeof(title), "%T", "CoopMenuTitle", client);
	SetMenuTitle(menu, title);
	//new bool:isadmin = Client_IsAdmin(client);
	
	new iCount = 0;
	
	//show rest
	for (new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
		{
			continue;
		}
		if(client == i)
		{
			continue;
		}
		if(g_bClientCoop[i])
		{
			continue;
		}
		if(g_bClientChallenge[i])
		{
			continue;
		}
		
		decl String:name2[32];
		FormatEx(name2, sizeof(name2), "%N", i);
		decl String:zone2[32];
		FormatEx(zone2,sizeof(zone2),"%d", i);
		AddMenuItem(menu, zone2, name2);
		
		iCount++;
	}
	
	if(iCount == 0)
	{
		CPrintToChat(client, "%t", "No Target found");
		return Plugin_Handled;
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 20);
	 
	return Plugin_Handled;
}

public MenuHandlerCoop(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[100], String:info2[100];
		new bool:found = GetMenuItem(menu, param2, info, sizeof(info), _, info2, sizeof(info2));
		new target = StringToInt(info);
		if(found)
		{
			if(IsClientInGame(target))
			{
				if(IsFakeClient(target))
				{
					StartCoop(client, target);
				}
				else
				{
					new Handle:menu2 = CreateMenu(MenuHandlerCoopConfirm);
					char title[256];
					Format(title, sizeof(title), "%T", "Confirm Coop", client, client);
					SetMenuTitle(menu2, title);
					//new bool:isadmin = Client_IsAdmin(client);
				
					decl String:xclient[32];
					FormatEx(xclient, sizeof(xclient),"%d", client);
					
					char yes[256];
					Format(yes, sizeof(yes), "%T", "Yes", client);
					AddMenuItem(menu2, xclient, yes);
					
					char no[256];
					Format(no, sizeof(no), "%T", "No", client);
					AddMenuItem(menu2, "no", no);
				
					SetMenuExitButton(menu, true);
					DisplayMenu(menu2, target, 20);
				}
			}
		}
	}
}

public MenuHandlerCoopConfirm(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[100], String:info2[100];
		new bool:found = GetMenuItem(menu, param2, info, sizeof(info), _, info2, sizeof(info2));
		new target = StringToInt(info);
		if(StrEqual(info, "no"))
		{
			
		}
		else if(found)
		{	
			if(!target || target <= 0)
			{
			}
			else
			{
				StartCoop(client, target);
			}
		}
		
		Call_StartForward(g_OnCoopConfirm);
		Call_PushCell(client);
		Call_PushCell(target);
		Call_PushCell(found);
		Call_Finish();
	}
}

StartCoop(client, target)
{
	Timer_SetClientTeammate(client, target, 1);
	Timer_SetTrack(client, Timer_GetTrack(target));
	
	SetEntityMoveType(client, MOVETYPE_NONE);
	SetEntityMoveType(target, MOVETYPE_NONE);
	
	g_iCoopCountdown[client] = 5;
	g_iCoopCountdown[target] = 5;
	
	Timer_SetTrack(client, TRACK_NORMAL);
	Timer_SetTrack(target, TRACK_NORMAL);
	
	g_bClientCoop[client] = false;
	g_bClientCoop[target] = false;

	CreateTimer(1.0, CoopCountdown, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(1.0, CoopCountdown, target, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:CoopCountdown(Handle:timer, any:client)
{
	if(!IsClientInGame(client))
		return Plugin_Stop;
	
	PrintCenterText(client, "%d", g_iCoopCountdown[client]);
	
	g_iCoopCountdown[client]--;
	
	SetEntityMoveType(client, MOVETYPE_NONE);
	Timer_ClientTeleportLevel(client, LEVEL_START);
	
	if(g_iCoopCountdown[client] <= 0)
	{
		PrintCenterText(client, "GO GO GO !!!");
		SetEntityMoveType(client, MOVETYPE_WALK);
		new mate = Timer_GetClientTeammate(client);
		
		g_bClientCoop[client] = true;
		g_bClientCoop[mate] = true;
		
		g_bClientCoop[client] = true;
		g_bClientCoop[mate] = true;
		
		Call_StartForward(g_OnCoopStart);
		Call_PushCell(client);
		Call_PushCell(mate);
		Call_Finish();
		
		Timer_Start(client);
		Timer_Start(mate);
		
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

new Float:g_fLastFail[MAXPLAYERS+1];

public Action:EndChallenge(client, force)
{
	new mate = Timer_GetClientTeammate(client);
	new Float:fTime = GetGameTime();
	new bool:fake_death = false;
	
	if(g_bClientChallenge[client] && g_bClientChallenge[mate])
	{
		//Failed?
		if (force == 1 && fTime-g_fLastRun[client] > 1.0)
		{
			if(fTime - g_fLastFail[client] > 1.0)
			{
				g_fLastFail[client] = fTime;
				
				int reason = 0;
				if(fTime - g_fStartTime[mate] > g_Settings[ChallengeAbortTime])
				{
					CPrintToChat(client, "%t", "You have surrendered this challenge");
					CPrintToChat(mate, "%t", "Has surrendered this challenge", client);
					
					reason = 1;
				}
				else
				{
					CPrintToChat(client, "%t", "You have aborted this challenge");
					CPrintToChat(mate, "%t", "Has aborted this challenge", client);
					
					reason = 2;
				}
				
				Call_StartForward(g_OnChallengeForceEnd);
				Call_PushCell(client);
				Call_PushCell(mate);
				Call_PushCell(reason);
				Call_Finish();
			}
			else
			{
				
			}
		}
		//We have a winner
		else if(force == 0)
		{
			decl String:pname[32], String:pname2[32];	
			
			FormatEx(pname, sizeof(pname), "%N", client);
			FormatEx(pname2, sizeof(pname2), "%N", mate);
			
			//Play sounds
			EmitSoundToClient(client, SND_TIMER_OWNED);
			EmitSoundToClient(mate, SND_TIMER_OWNED);
			
			new bool:enabled = false;
			new jumps = 0;
			new Float:time;
			new fpsmax;
			
			if (g_Settings[ChallengeSaveRecords] && Timer_GetClientTimer(client, enabled, time, jumps, fpsmax))
			{
				if(fTime - g_fStartTime[client] > 1.0 || fTime - g_fStartTime[mate] > 1.0)
				{
					new style = 0;
					if (g_timerPhysics)
					{
						style = Timer_GetStyle(client);
					}
					
					Timer_FinishRound(client, g_currentMap, time, jumps, style, fpsmax, 0);
				}
			}
			
			//Forward
			Call_StartForward(g_OnChallengeWin);
			Call_PushCell(client);
			Call_PushCell(mate);
			Call_Finish();
			
			fake_death = true;
		}
	}
	
	//end challenge
	g_bClientChallenge[client] = false;
	g_bClientChallenge[mate] = false;
	
	//dissolve team
	Timer_SetClientTeammate(client, 0, 0);
	Timer_SetClientTeammate(mate, 0, 0);
	
	//Reset hide
	Timer_SetClientHide(client, 0);
	Timer_SetClientHide(mate, 0);
	
	g_fLastRun[client] = fTime;
	
	if(fake_death)
	{
		//Fake death event
		new Handle:event = CreateEvent("player_death");
		if (event != INVALID_HANDLE)
		{
			SetEventInt(event, "userid", GetClientUserId(mate));
			SetEventInt(event, "attacker", GetClientUserId(client));
			SetEventString(event, "weapon", "weapon_challenge");
			FireEvent(event, false);
		}
	}
	
	Timer_Reset(client);
	Timer_Reset(mate);
}

public Action:EndCoop(client, force)
{
	new mate = Timer_GetClientTeammate(client);
	
	if(g_bClientCoop[client] && g_bClientCoop[mate])
	{
		decl String:pname[32], String:pname2[32];	
			
		FormatEx(pname, sizeof(pname), "%N", client);
		FormatEx(pname2, sizeof(pname2), "%N", mate);
			
		if (force == 1)
		{
			CPrintToChatAll("%t", "Coop Fail", pname, pname2);
			
			Call_StartForward(g_OnCoopForceEnd);
			Call_PushCell(client);
			Call_PushCell(mate);
			Call_Finish();
		}
		else if (force == 0)
		{
			CPrintToChatAll("%t", "Coop Win", pname, pname2);
			
			Call_StartForward(g_OnCoopWin);
			Call_PushCell(client);
			Call_PushCell(mate);
			Call_Finish();
			
			new bool:enabled; //tier running
			new jumps; //current jump count
			new fpsmax; //fps settings
			new bool:track = false; //track timer running
			new Float:time; //current time
			
			new style = Timer_GetStyle(client);
			
			Timer_GetClientTimer(client, enabled, time, jumps, fpsmax);
			
			Timer_FinishRound(client, g_currentMap, time, jumps, style, fpsmax, track);
			Timer_FinishRound(mate, g_currentMap, time, jumps, style, fpsmax, track);
		}
	}
	
	g_bClientCoop[client] = false;
	g_bClientCoop[mate] = false;
	
	Timer_Reset(client);
	Timer_Reset(mate);
	
	Timer_SetClientTeammate(client, 0, 0);
	Timer_SetClientTeammate(mate, 0, 0);
}

public OnTimerStopped(client)
{
	ForceEnd(client);
}

public OnTimerRestart(client)
{
	ForceEnd(client);
}

public OnTimerPaused(client)
{
	ForceEnd(client);
}

public OnTimerReseted(client)
{
	ForceEnd(client);
}

ForceEnd(client)
{
	new mate = Timer_GetClientTeammate(client);
	
	if(mate != 0)
	{
		if(g_bClientChallenge[client])	
		{
			EndChallenge(client,1);
		}
		else if (g_bClientCoop[client])
		{
			EndCoop(client,1);
		}
	}
}

public Native_GetClientTeammate(Handle:plugin, numParams)
{
	return g_clientTeammate[GetNativeCell(1)];
}

public Native_SetClientTeammate(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new mate = GetNativeCell(2);
	new bool:teleport = bool:GetNativeCell(2);
	
	if(0 < client)
	{
		//Make sure there are no issues with other mates
		new oldcmate = g_clientTeammate[client];
		new oldmmate = g_clientTeammate[mate];
		
		g_clientTeammate[oldcmate] = 0;
		g_clientTeammate[oldmmate] = 0;
		g_clientTeammate[client] = 0;
		g_clientTeammate[mate] = 0;
		
		if(0 < mate)
		{
			g_clientTeammate[client] = mate;
			g_clientTeammate[mate] = client;
		}
		
		if(teleport)
		{
			Timer_ClientTeleportLevel(client, LEVEL_START);
			Timer_ClientTeleportLevel(mate, LEVEL_START);
			
			if(oldcmate && oldcmate != mate)
				Timer_ClientTeleportLevel(oldcmate, LEVEL_START);
			
			if(oldmmate && oldmmate != client)
				Timer_ClientTeleportLevel(oldmmate, LEVEL_START);
		}
	}
}

public Native_GetChallengeStatus(Handle:plugin, numParams)
{
	return g_bClientChallenge[GetNativeCell(1)];
}

public Native_GetCoopStatus(Handle:plugin, numParams)
{
	return g_bClientCoop[GetNativeCell(1)];
}