/*
    SourceMod Anti-Cheat Client Module
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

#define CLIENT

#define MAX_CONNECTIONS 100

new Handle:g_hCVarClientNameProtect = INVALID_HANDLE;
new Handle:g_hCVarClientAntiSpamConnect = INVALID_HANDLE;
new bool:g_bClientNameProtect = true;
new Float:g_fClientAntiSpamConnect = 0.0;
new String:g_sClientConnections[MAX_CONNECTIONS][64];

new Handle:g_hNameTimer = INVALID_HANDLE;
new g_iNameChanges[MAXPLAYERS+1];


//- Plugin Functions -//

Client_OnPluginStart()
{
	g_hCVarClientNameProtect = CreateConVar("smac_client_nameprotect", "1", "This will protect the server from name crashes and hacks.", FCVAR_PLUGIN);
	Client_NameProtectChange(g_hCVarClientNameProtect, "", "");

	g_hCVarClientAntiSpamConnect = CreateConVar("smac_client_antispamconnect", "0", "Seconds to prevent someone from restablishing a connection. 0 to disable.", FCVAR_PLUGIN);
	Client_AntiSpamConnectChange(g_hCVarClientAntiSpamConnect, "", "");

	HookConVarChange(g_hCVarClientNameProtect, Client_NameProtectChange);
	HookConVarChange(g_hCVarClientAntiSpamConnect, Client_AntiSpamConnectChange);
	
	AddCommandListener(Client_Autobuy, "autobuy");
}

//- Commands -//

public Action:Client_Autobuy(client, const String:command[], args)
{
	if ( !client )
		return Plugin_Continue;

	decl String:f_sAutobuy[256], String:f_sArg[64], i, t;
	GetClientInfo(client, "cl_autobuy", f_sAutobuy, sizeof(f_sAutobuy));
	
	if ( strlen(f_sAutobuy) > 255 )
		return Plugin_Stop;

	i = 0;
	t = BreakString(f_sAutobuy, f_sArg, sizeof(f_sArg));
	while ( t != -1 )
	{
		if ( strlen(f_sArg) > 30 )
			return Plugin_Stop;

		i += t;
		t = BreakString(f_sAutobuy[i], f_sArg, sizeof(f_sArg));
	}

	if ( strlen(f_sArg) > 30 )
		return Plugin_Stop;

	return Plugin_Continue;
}

//- Map -//

Client_OnMapEnd()
{
	for(new i=0;i<MAX_CONNECTIONS;i++)
		strcopy(g_sClientConnections[i], 64, "");
}

//- Timers -//

public Action:Client_AntiSpamConnectTimer(Handle:timer, any:i)
{
	strcopy(g_sClientConnections[i], 64, "");
	return Plugin_Stop;
}


//- Hooks -//

bool:Client_OnClientConnect(client, String:rejectmsg[], size)
{
	if ( g_fClientAntiSpamConnect > 0.0 )
	{
		new String:f_sClientIP[64];

		GetClientIP(client, f_sClientIP, sizeof(f_sClientIP));

		for(new i=0;i<MAX_CONNECTIONS;i++)
		{
			if ( StrEqual(g_sClientConnections[i], f_sClientIP) )
			{
				Format(rejectmsg, size, "Please wait one minute before retrying to connect");
				BanIdentity(f_sClientIP, 1, BANFLAG_IP, "Spam Connecting"); // We do not want this hooked, so no source.
				return false;
			}
		}

		for(new i=0;i<MAX_CONNECTIONS;i++)
		{
			if ( g_sClientConnections[i][0] == '\0' )
			{
				strcopy(g_sClientConnections[i], 64, f_sClientIP);
				CreateTimer(g_fClientAntiSpamConnect, Client_AntiSpamConnectTimer, i);
				break;
			}
		}
	}

	if ( g_bClientNameProtect && !Client_HasValidName(client) )
	{
		Format(rejectmsg, size, "%T", SMAC_CHANGENAME, client);
		return false;
	}

	return true;
}

public OnClientSettingsChanged(client)
{
	if ( g_bClientNameProtect && !g_bIsFake[client] && !Client_HasValidName(client) )
		KickClient(client, "%t", SMAC_CHANGENAME);
}

public Client_PlayerChangeName(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (client && g_iNameChanges[client]++ >= 5)
	{
		decl String:f_sAuthID[64], String:f_sIP[64];
		GetClientAuthString(client, f_sAuthID, sizeof(f_sAuthID));
		GetClientIP(client, f_sIP, sizeof(f_sIP));
		
		SMAC_Log("%N (ID: %s | IP: %s) was kicked for name change spam.", client, f_sAuthID, f_sIP);
		KickClient(client, "Name change spam");
	}
}

public Action:Client_DecreaseCount(Handle:timer)
{
	for (new i = 1; i <= MaxClients; i++)
		if (g_iNameChanges[i])
			g_iNameChanges[i]--;
	
	return Plugin_Continue;
}

bool:Client_HasValidName(client)
{
	new String:f_sName[64], String:f_cChar, f_iSize, bool:f_bWhiteSpace = true;
	GetClientName(client, f_sName, sizeof(f_sName));

	f_iSize = strlen(f_sName);

	if ( f_iSize < 1 || f_sName[0] == '&' )
		return false;

	for(new i=0;i<f_iSize;i++)
	{
		f_cChar = f_sName[i];
		if ( !IsCharSpace(f_cChar) )
			f_bWhiteSpace = false;

		if ( IsCharMB(f_cChar) )
		{
			i++;
			if ( f_cChar == 194 && f_sName[i] == 160 )
				return false;
		}
		else if ( f_cChar < 32 || f_cChar == '%' )
		{
			return false;
		}
	}

	if ( f_bWhiteSpace )
		return false;
	
	return true;
}

public Client_NameProtectChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_bClientNameProtect = GetConVarBool(convar);
	
	if (g_bClientNameProtect && g_hNameTimer == INVALID_HANDLE)
	{
		HookEvent("player_changename", Client_PlayerChangeName, EventHookMode_Post);
		g_hNameTimer = CreateTimer(5.0, Client_DecreaseCount, _, TIMER_REPEAT);
	}
	else if (!g_bClientNameProtect && g_hNameTimer != INVALID_HANDLE)
	{
		UnhookEvent("player_changename", Client_PlayerChangeName, EventHookMode_Post);
		KillTimer(g_hNameTimer);
		g_hNameTimer = INVALID_HANDLE;
	}
}

public Client_AntiSpamConnectChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_fClientAntiSpamConnect = GetConVarFloat(convar);
}

//- EoF -//
