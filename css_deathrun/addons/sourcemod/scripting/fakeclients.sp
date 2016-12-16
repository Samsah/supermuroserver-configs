#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PL_VERSION "1.1"

new Handle:g_hCount;
new Handle:g_hDelay;
new Handle:g_hNames;

public Plugin:myinfo = {
  name        = "FakeClients",
  author      = "Tsunami",
  description = "Put fake clients in server",
  version     = PL_VERSION,
  url         = "http://tsunami-productions.nl"
};

public OnPluginStart() {
	CreateConVar("sm_fakeclients_version", PL_VERSION, "Put fake clients in server", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_hCount = CreateConVar("sm_fakeclients_players", "8",   "Number of players to simulate", _, true, 0.0, true, 64.0);
	g_hDelay = CreateConVar("sm_fakeclients_delay",   "120", "Delay after map change before fake clients join (seconds)");
	g_hNames = CreateArray(64);
}

public OnMapStart()    {
	ParseNames();
	
	CreateTimer(GetConVarInt(g_hDelay) * 1.0, Timer_CreateFakeClients);
}

public OnClientPutInServer(client) {
	if (!IsFakeClient(client)) {
		for (new i = 1, c = GetClientCount(); i <= c; i++) {
			if (IsClientConnected(i) && IsFakeClient(i))  {
				new Handle:hTVName = FindConVar("tv_name"), String:sName[MAX_NAME_LENGTH], String:sTVName[MAX_NAME_LENGTH];
				GetClientName(i, sName, sizeof(sName));
				
				if (hTVName != INVALID_HANDLE) {
					GetConVarString(hTVName, sTVName, sizeof(sTVName));
				}
				
				if (!StrEqual(sName, sTVName)) {
					KickClient(i, "Slot reserved");
					break;
				}
			}
		}
	}
}

public OnClientDisconnect(client)  {
	CreateTimer(1.0,   Timer_CreateFakeClient);
}

public Action:Timer_CreateFakeClient(Handle:timer)  {
	new iBots = 0, iClients = GetClientCount(true), iMaxBots = GetConVarInt(g_hCount), iMaxClients = GetMaxClients();
	
	if (iClients < iMaxClients) {
		for (new i = 1; i <= iMaxClients; i++){
			if (IsClientConnected(i) && IsFakeClient(i))  {
				iBots++;
			}
		}
		
		if (iBots    < iMaxBots &&
				iClients < iMaxBots) {
			decl iTargets[MAXPLAYERS], bool:tn_is_ml, String:sName[MAX_NAME_LENGTH], String:sTarget[MAX_TARGET_LENGTH];
			GetArrayString(g_hNames,   GetRandomInt(0, GetArraySize(g_hNames) - 1), sName, sizeof(sName));
			
			while (ProcessTargetString(sName,
			                           0,
			                           iTargets,
			                           MAXPLAYERS,
			                           COMMAND_FILTER_NO_MULTI,
			                           sTarget,
			                           MAX_TARGET_LENGTH,
			                           tn_is_ml) == 1 && IsFakeClient(iTargets[0])) {
				GetArrayString(g_hNames, GetRandomInt(0, GetArraySize(g_hNames) - 1), sName, sizeof(sName));
			}
			
			CreateFakeClient(sName);
		}
	}
	
	return Plugin_Handled;
}

public Action:Timer_CreateFakeClients(Handle:timer) {
	for (new i = 1, c = GetConVarInt(g_hCount); i <= c; i++) {
		CreateTimer(i * 1.0, Timer_CreateFakeClient);
	}
}

ParseNames() {
	decl String:sBuffer[256];
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "configs/fakeclients.txt");
	
	new Handle:hConfig = OpenFile(sBuffer, "r");
	
	if (hConfig != INVALID_HANDLE) {
		ClearArray(g_hNames);
		
		while (ReadFileLine(hConfig, sBuffer, sizeof(sBuffer))) {
			TrimString(sBuffer);
			
			if (strlen(sBuffer) > 0) {
				PushArrayString(g_hNames, sBuffer);
			}
		}
		
		CloseHandle(hConfig);
	}
}