// Header to go here

/*
    SourceMod Anti-Cheat
	Copyright (C) 2011 Nicholas "psychonic" Hastings (nshastings@gmail.com)
    Copyright (C) 2007-2011 CodingDirect LLC

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

//- Pre-processor Defines -//
#define PLUGIN_VERSION "0.0.6.2"
#define PLUGIN_BUILD 1

//#define DEBUG
#if defined DEBUG
	#undef PLUGIN_VERSION
	#define PLUGIN_VERSION "Debug Build"
#endif

//#define NO_SOCKETS
#if defined NO_SOCKETS
	#undef PLUGIN_VERSION
	#define PLUGIN_VERSION "No-Socket Unofficial Build"
#endif

enum SMACGame {
	Game_Other,
	Game_CSS,
	Game_TF2,
	Game_DOD,
	Game_INS,
	Game_L4D,
	Game_L4D2,
	Game_HL2DM,
	Game_FOF,
	Game_GMOD,
};

//- SM Includes -//
#include <sourcemod>
#include <sdktools>
#include <colors>
#undef REQUIRE_EXTENSIONS
#include <sdkhooks>
#define REQUIRE_EXTENSIONS

//- Natives -//
native SBBanPlayer(client, target, time, String:reason[]);
#define SOURCEBANS_AVAILABLE() (GetFeatureStatus(FeatureType_Native, "SBBanPlayer") == FeatureStatus_Available)

//- Global Variables -//
new bool:g_bConnected[MAXPLAYERS+1] = {false, ...};	// I use these instead of the natives because they are cheaper to call
new bool:g_bAuthorized[MAXPLAYERS+1] = {false, ...};	// when I need to check on a client's state.  Natives are very taxing on
new bool:g_bInGame[MAXPLAYERS+1] = {false, ...};	// system resources as compared to these. - Kigen
new bool:g_bIsFake[MAXPLAYERS+1] = {false, ...};
new bool:g_bMapStarted = false;
new bool:g_bSDKHooksLoaded = false;
new bool:g_bWelcomeMsg = false;
new g_iBanDuration = 0;
new Handle:g_hValidateTimer[MAXPLAYERS+1] = {INVALID_HANDLE, ...};
new Handle:g_hDenyArray = INVALID_HANDLE;
new Handle:g_hCVarVersion = INVALID_HANDLE;
new Handle:g_hCVarWelcomeMsg = INVALID_HANDLE;
new Handle:g_hCVarBanDuration = INVALID_HANDLE;
new Handle:g_hCVarLogMode = INVALID_HANDLE;
new SMACGame:g_Game = Game_Other; // Game identifier.

//- SMAC Modules -// Note: The ordering of these includes are imporant.
#include "smac/constants.sp"		// Constants - NEEDED FIRST
#include "smac/client.sp"			// Client Module
#include "smac/commands.sp"			// Commands Module
#include "smac/cvars.sp"			// CVar Module
#include "smac/eyetest.sp"			// Eye Test Module
#include "smac/wallhack.sp"			// Wallhack Module

#if !defined NO_SOCKETS
#include "smac/network.sp"			// Network Module
#endif

#include "smac/rcon.sp"				// RCON Module
#include "smac/cstrike/antiflash.sp"	// CS:S Anti-Flash Module
#include "smac/cstrike/antismoke.sp"	// CS:S Anti-Smoke Module
#include "smac/cstrike/antirejoin.sp"	// CS:S Anti-Rejoin Module
#include "smac/spinhack.sp"			// SpinHack Module
#include "smac/aimbot.sp"			// Aimbot Module
#include "smac/speedhack.sp"		// Speedhack Module


public Plugin:myinfo =
{
    name = "SourceMod Anti-Cheat",
    author = "psychonic, GoD-Tony, CodingDirect LLC", 
    description = "Open Source Anti-Cheat plugin for SourceMod", 
    version = PLUGIN_VERSION, 
    url = "http://forums.alliedmods.net/forumdisplay.php?f=133"
};

//- Plugin Functions -//

// SourceMod 1.3 uses the new native AskPluginLoad2 so that APLRes can be used.
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
#if !defined NO_SOCKETS
	Network_AskPluginLoad();
#endif
	MarkNativeAsOptional("SBBanPlayer");
	MarkNativeAsOptional("Steam_SetRule");
	MarkNativeAsOptional("SDKHook");
	MarkNativeAsOptional("SDKUnhook");
	return APLRes_Success;
}

public OnPluginStart()
{
	LoadTranslations("smac.phrases");
	
	decl String:f_sGame[64];

	g_hDenyArray = CreateTrie();

//- Identify the game -//
	GetGameFolderName(f_sGame, sizeof(f_sGame));
	if ( StrEqual(f_sGame, "cstrike") )
		g_Game = Game_CSS;
	else if ( StrEqual(f_sGame, "dod") )
		g_Game = Game_DOD;
	else if ( StrEqual(f_sGame, "tf") )
		g_Game = Game_TF2;
	else if ( StrEqual(f_sGame, "insurgency") )
		g_Game = Game_INS;
	else if ( StrEqual(f_sGame, "left4dead") )
		g_Game = Game_L4D;
	else if ( StrEqual(f_sGame, "left4dead2") )
		g_Game = Game_L4D2;
	else if ( StrEqual(f_sGame, "hl2mp") )
		g_Game = Game_HL2DM;
	else if ( StrEqual(f_sGame, "fistful_of_frags") )
		g_Game = Game_FOF;
	else if ( StrEqual(f_sGame, "garrysmod") )
		g_Game = Game_GMOD;

	g_bSDKHooksLoaded = LibraryExists("sdkhooks");

//- Module Calls -//
	Client_OnPluginStart()
	Commands_OnPluginStart();
	CVars_OnPluginStart();
	Eyetest_OnPluginStart();
	Wallhack_OnPluginStart();
#if !defined NO_SOCKETS
	Network_OnPluginStart();
#endif
	RCON_OnPluginStart();
	AntiFlash_OnPluginStart();
	AntiSmoke_OnPluginStart();
	AntiRejoin_OnPluginStart();
	SpinHack_OnPluginStart();
	Aimbot_OnPluginStart();
	Speedhack_OnPluginStart();

	CreateTimer(14400.0, SMAC_ClearTimer, _, TIMER_REPEAT); // Clear the Deny Array every 4 hours.

	g_hCVarVersion = CreateConVar(SMAC_VERSION_CVNAME, PLUGIN_VERSION, "SMAC version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hCVarWelcomeMsg = CreateConVar("smac_welcomemsg", "1", "Display a chat message saying that your server is protected.", FCVAR_PLUGIN);
	g_hCVarBanDuration = CreateConVar("smac_ban_duration", "0", "The duration in minutes used for automatic bans. (0 = Permanent)", FCVAR_PLUGIN, true, 0.0);
	g_hCVarLogMode = CreateConVar("smac_log_mode", "1", "Determines how SMAC logging should be handled. (0 = One log file, 1 = Daily log files)", FCVAR_PLUGIN, true, 0.0);
	
	VersionChange(g_hCVarVersion, "", "");
	WelcomeChange(g_hCVarWelcomeMsg, "", "");
	BanChange(g_hCVarBanDuration, "", "");
	
	HookConVarChange(g_hCVarVersion, VersionChange);
	HookConVarChange(g_hCVarWelcomeMsg, WelcomeChange);
	HookConVarChange(g_hCVarBanDuration, BanChange);
	
	AutoExecConfig(true, "smac");

	PrintToServer("SourceMod Anti-Cheat %s has been loaded successfully.", PLUGIN_VERSION);
}

public OnAllPluginsLoaded()
{
	decl String:f_sReason[256], String:f_sAuthID[64];

//- Module Calls -//
	Commands_OnAllPluginsLoaded();

//- Late load stuff -//
	for(new i=1;i<=MaxClients;i++)
	{
		if ( IsClientConnected(i) )
		{
			if ( !OnClientConnect(i, f_sReason, sizeof(f_sReason)) )
			{
				KickClient(i, "%s", f_sReason);
				continue;
			}
			else
				OnClientConnected(i);
			
			if ( IsClientAuthorized(i) && GetClientAuthString(i, f_sAuthID, sizeof(f_sAuthID)) )
				OnClientAuthorized(i, f_sAuthID);
			
			if ( IsClientInGame(i) )
				OnClientPutInServer(i);
		}
	}
}

public OnPluginEnd()
{
	RCON_OnPluginEnd();
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "sdkhooks"))
		g_bSDKHooksLoaded = true;
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "sdkhooks"))
		g_bSDKHooksLoaded = false;
}

//- Map Functions -//

public OnMapStart()
{
	g_bMapStarted = true;
	CVars_CreateNewOrder();
	RCON_OnMap();
}

public OnMapEnd()
{
	g_bMapStarted = false;
	Client_OnMapEnd();
	RCON_OnMap();
	AntiSmoke_OnMapEnd();
	AntiRejoin_OnMapEnd();
}

//- Client Functions -//

public bool:OnClientConnect(client, String:rejectmsg[], size)
{
	if ( IsFakeClient(client) )
	{
		g_bIsFake[client] = true;
		return true;
	}

	return Client_OnClientConnect(client, rejectmsg, size);
}

public OnClientConnected(client)
{
	g_bConnected[client] = true;	
}

public OnClientAuthorized(client, const String:auth[])
{
	if ( g_bIsFake[client] )
		return;

	decl Handle:f_hTemp, String:f_sReason[256];

	if ( GetTrieString(g_hDenyArray, auth, f_sReason, sizeof(f_sReason)) )
	{
		KickClient(client, "%s", f_sReason);
		OnClientDisconnect(client);
		return;
	}

	g_bAuthorized[client] = true;

	if ( g_bInGame[client] )
		g_hPeriodicTimer[client] = CreateTimer(0.1, CVars_PeriodicTimer, client);

	f_hTemp = g_hValidateTimer[client];
	g_hValidateTimer[client] = INVALID_HANDLE;
	if ( f_hTemp != INVALID_HANDLE )
		CloseHandle(f_hTemp);
}

public OnClientPutInServer(client)
{
	g_bInGame[client] = true;
	
	Wallhack_OnClientPutInServer(client);
	Client_OnClientPutInServer(client);
	Aimbot_OnClientPutInServer(client);
	
	if ( g_bIsFake[client] )
		return;
		
	if ( g_bWelcomeMsg )
		CreateTimer(5.0, SMAC_WelcomeMsg, GetClientUserId(client));

	if ( !g_bAuthorized[client] ) // Not authorized yet?!?
		g_hValidateTimer[client] = CreateTimer(10.0, SMAC_ValidateTimer, client);
	else	
		g_hPeriodicTimer[client] = CreateTimer(0.1, CVars_PeriodicTimer, client);
}

public OnClientDisconnect(client)
{
	// if ( IsFake aww, screw it. :P
	decl Handle:f_hTemp;

	g_bConnected[client] = false;
	g_bAuthorized[client] = false;
	g_bInGame[client] = false;
	g_bShouldProcess[client] = false;
	g_bHooked[client] = false;
	
	f_hTemp = g_hValidateTimer[client];
	g_hValidateTimer[client] = INVALID_HANDLE;
	if ( f_hTemp != INVALID_HANDLE )
		CloseHandle(f_hTemp);

	CVars_OnClientDisconnect(client);
#if !defined NO_SOCKETS
	Network_OnClientDisconnect(client);
#endif
	AntiFlash_OnClientDisconnect(client);
	AntiSmoke_OnClientDisconnect(client);
	SpinHack_OnClientDisconnect(client);
}

public OnClientDisconnect_Post(client)
{
	g_bIsFake[client] = false;
	
	Eyetest_OnClientDisconnect_Post(client);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if ( g_bIsFake[client] )
		return Plugin_Continue;
		
	SpinHack_OnPlayerRunCmd(client, buttons, angles);
	Aimbot_OnPlayerRunCmd(client, angles);
	Eyetest_OnPlayerRunCmd(client, angles);
	Wallhack_OnPlayerRunCmd(client, angles);
	return Speedhack_OnPlayerRunCmd(client);
}

//- Timers -//

public Action:SMAC_ValidateTimer(Handle:timer, any:client)
{
	g_hValidateTimer[client] = INVALID_HANDLE;

	if ( !g_bInGame[client] || g_bAuthorized[client] )
		return Plugin_Stop;

	KickClient(client, "%t", SMAC_FAILEDAUTH);
	
	return Plugin_Stop;
}

public Action:SMAC_ClearTimer(Handle:timer, any:nothing)
{
	ClearTrie(g_hDenyArray);
}

public Action:SMAC_WelcomeMsg(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	
	if ( client && IsClientInGame(client) )
		CPrintToChat(client, "%t%t", SMAC_TAG, SMAC_WELCOMEMSG);
		
	return Plugin_Stop;
}

//- ConVar Hook -//

public VersionChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if ( !StrEqual(newValue, PLUGIN_VERSION) )
		SetConVarString(g_hCVarVersion, PLUGIN_VERSION);
}

public WelcomeChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_bWelcomeMsg = GetConVarBool(convar);
}

public BanChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iBanDuration = GetConVarInt(convar);
}

//- Global Private Functions -//

SMAC_Log(const String:format[], any:...)
{
	decl String:f_sBuffer[256], String:f_sPath[256];
	VFormat(f_sBuffer, sizeof(f_sBuffer), format, 2);
	
	switch (GetConVarInt(g_hCVarLogMode))
	{
		case 1: // Daily log files.
		{
			decl String:f_sDateTime[16];
			FormatTime(f_sDateTime, sizeof(f_sDateTime), "%Y%m%d");
			BuildPath(Path_SM, f_sPath, sizeof(f_sPath), "logs/SMAC_%s.log", f_sDateTime);
		}
		
		default: // One log file.
		{
			BuildPath(Path_SM, f_sPath, sizeof(f_sPath), "logs/SMAC.log");
		}
	}
	
	LogToFileEx(f_sPath, "%s", f_sBuffer);
}

#if defined DEBUG
SMAC_DebugLog(const String:format[], any:...)
{
	decl String:f_sBuffer[256], String:f_sPath[256];
	VFormat(f_sBuffer, sizeof(f_sBuffer), format, 2);
	BuildPath(Path_SM, f_sPath, sizeof(f_sPath), "logs/SMAC_Debug.log");
	LogToFileEx(f_sPath, "%s", f_sBuffer);
}
#endif

SMAC_Ban(client, time, const String:sKickPhrase[]="", const String:format[], any:...)
{
	decl String:f_sBuffer[256];
	VFormat(f_sBuffer, sizeof(f_sBuffer), format, 5);
	if ( SOURCEBANS_AVAILABLE() )
	{
		SBBanPlayer(0, client, time, f_sBuffer);
	}
	else if (sKickPhrase[0] != '\0')
	{
		decl String:sKickReason[256];
		Format(sKickReason, sizeof(sKickReason), "%T", sKickPhrase, client);
		BanClient(client, time, BANFLAG_AUTO, f_sBuffer, sKickReason, "SMAC");
	}
	else
	{
		BanClient(client, time, BANFLAG_AUTO, f_sBuffer, f_sBuffer, "SMAC");
	}
	OnClientDisconnect(client); // Bashats!
}

SMAC_PrintToChatAdmins(const String:format[], any:...)
{
	decl String:buffer[192];
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (CheckCommandAccess(i, "smac_admin_notices", ADMFLAG_GENERIC, true))
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 2);
			CPrintToChat(i, "%t%s", SMAC_TAG, buffer);
		}
	}
}

//- End of File -//
