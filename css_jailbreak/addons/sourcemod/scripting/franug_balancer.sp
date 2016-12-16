#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>


#define TEAMRATIO 2.0 // How much Ts for every CT



new bool:morect;
new bool:morett;

new Handle:gH_BanCookie = INVALID_HANDLE;

new bool:guard[MAXPLAYERS+1];

public Plugin:myinfo = 
{
	name = "SM franug team ratio balancer",
	author = "Franc1sco franug",
	description = "",
	version = "2.0",
	url = "http://steamcommunity.com/id/franug"
}


public OnPluginStart()
{
	HookEvent("round_end",Event_RoundEnded);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	gH_BanCookie = RegClientCookie("Banned_From_CT", "Tells if you are restricted from joining the CT team", CookieAccess_Protected);
	
	RegConsoleCmd("sm_guard", Guarda);
}

public Action:Guarda(client, args)
{
	if (AreClientCookiesCached(client))
	{
		decl String:cookie[5];
		GetClientCookie(client, gH_BanCookie, cookie, sizeof(cookie));
				
		if (StrEqual(cookie, "1")) 
		{
			PrintToChat(client, "You are banned from Counter-Terrorist");
			return Plugin_Handled;
		}
		
	}
	if(GetClientTeam(client) == CS_TEAM_CT)
	{
		PrintToChat(client, "You are already a guard.");
		return Plugin_Handled;
	}
	if(guard[client])
	{
		PrintToChat(client, "You are already in the queue.");
		return Plugin_Handled;
	}

	PrintToChat(client, "Added to the queue.");
	guard[client] = true;
	
	return Plugin_Handled;
}

public OnClientPutInServer(client)
{
	guard[client] = false;
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(GetClientTeam(client) == CS_TEAM_CT) guard[client] = false;
}


public Action:Event_RoundEnded(Handle:event, const String:name[], bool:dontBroadcast)
{
	morect = false;
	morett = false;
	
	new aleatorio;
	while(!Balanced())
	{
		aleatorio = 0;
		if(morect)
		{
			aleatorio = GetRandomPlayer2(CS_TEAM_T);
			if(aleatorio < 1)
			{
				aleatorio = GetRandomPlayer(CS_TEAM_T);
			}
			else 
			{
				PrintToChat(aleatorio, "Your request for a transfer to CT has been processed.");
			}
			
			if(aleatorio > 0) CS_SwitchTeam(aleatorio, CS_TEAM_CT);
			else break;
		}
		else if(morett)
		{
			aleatorio = GetRandomPlayer(CS_TEAM_CT);
			if(aleatorio > 0) CS_SwitchTeam(aleatorio, CS_TEAM_T);
			else break;
		}
	}
}

Balanced()
{
	new Float:CTs = float(GetTeamClientCount(CS_TEAM_CT));
	new Float:Ts = float(GetTeamClientCount(CS_TEAM_T));
	new Float:balancer = (Ts / CTs);
	if(balancer == TEAMRATIO) return true;
	if(balancer < TEAMRATIO)
	{
		if(morect) return true;
		morett = true;
		morect = false;
	}
	else
	{
		if(morett) return true;
		morett = false;
		morect = true;	
	}
	return false;
}

GetRandomPlayer(team)
{
	new clients[MaxClients+1], clientCount;
	for (new i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && GetClientTeam(i) == team)
			if(AreClientCookiesCached(i))
			{
				decl String:cookie[5];
				GetClientCookie(i, gH_BanCookie, cookie, sizeof(cookie));
				
				if (StrEqual(cookie, "1")) continue;
				else clients[clientCount++] = i;
			}
			else clients[clientCount++] = i;
		
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
} 

GetRandomPlayer2(team)
{
	new clients[MaxClients+1], clientCount;
	for (new i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && GetClientTeam(i) == team && guard[i])
			if(AreClientCookiesCached(i))
			{
				decl String:cookie[5];
				GetClientCookie(i, gH_BanCookie, cookie, sizeof(cookie));
				
				if (StrEqual(cookie, "1")) continue;
				else clients[clientCount++] = i;
			}
			else clients[clientCount++] = i;
			
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
} 