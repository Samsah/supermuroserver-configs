/*
    SourceMod Anti-Cheat Network Module
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

#define NETWORK

// Old Network version, to be replaced soon.

//- Global Variables -//
new Handle:g_hCVarCheckKigenBanlist = INVALID_HANDLE;
new Handle:g_hSocket = INVALID_HANDLE;
new Handle:g_hTimer = INVALID_HANDLE;
new bool:g_bChecked[MAXPLAYERS+1] = {false, ...};
new bool:g_bCheckKigenBanlist = false;
new bool:g_bBypassKigenBanlistCVHook = false;
new g_iInError = 0;

#undef REQUIRE_EXTENSIONS
#include <socket>
#define REQUIRE_EXTENSIONS

//- Plugin Functions -//

Network_AskPluginLoad()
{
	/*
	 * These should really be done in an __ext_smsock_SetNTVOptional()
	 * in socket.inc if REQUIRE_EXTENSIONS isn't defined, but that 
	 * function doesn't exist...
	 */
	MarkNativeAsOptional("SocketCreate");
	MarkNativeAsOptional("SocketSetArg");
	MarkNativeAsOptional("SocketConnect");
	MarkNativeAsOptional("SocketIsConnected");
	MarkNativeAsOptional("SocketDisconnect");
	MarkNativeAsOptional("SocketSend");
}

Network_OnPluginStart()
{
	RegAdminCmd("smac_net_status", Network_Checked, ADMFLAG_GENERIC, "Reports who has been checked");
	g_hCVarCheckKigenBanlist = CreateConVar(
		"smac_use_kac_banlist", "0",
		"If enabled, checks players against the KAC Global Banlist and removes them from the server if banned. Requires Socket extension. 0 - Disabled (default). 1 - Enabled.",
		FCVAR_PLUGIN,
		true, 0.0, true, 1.0);
	
	// this could already exist and be set to non-default if plugin was reloaded.
	g_bCheckKigenBanlist = GetConVarBool(g_hCVarCheckKigenBanlist);
	if (g_bCheckKigenBanlist)
	{
		g_bCheckKigenBanlist = Network_EnableChecks();
	}
	
	HookConVarChange(g_hCVarCheckKigenBanlist, Network_OnKACBanlistChanged);
}

//- Client Functions -//

Network_OnClientDisconnect(client)
{
	g_bChecked[client] = false;
}

//- Commands -//

public Action:Network_Checked(client, args)
{
	if ( args )
	{
		new String:f_sArg[64];
		GetCmdArg(1, f_sArg, sizeof(f_sArg));
		if ( StrEqual(f_sArg, "revalidate") )
		{
			for(new i=1;i<=MaxClients;i++)
				if ( g_bInGame[i] && !g_bChecked[i] )
				{
					ReplyToCommand(client, "%t", SMAC_CANNOTREVAL);
					return Plugin_Handled;
				}
			for(new i=1;i<=MaxClients;i++)
				g_bChecked[i] = false;
			
			ReplyToCommand(client, "%t", SMAC_FORCEDREVAL);
			return Plugin_Handled;
		}
	}

	new String:f_sAuthID[64];
	for(new i=1;i<=MaxClients;i++)
		if ( g_bInGame[i] && GetClientAuthString(i, f_sAuthID, sizeof(f_sAuthID)) )
			ReplyToCommand(client, "%N (%s): %s", i, f_sAuthID, (g_bChecked[i]) ? "Checked" : "Waiting");

	return Plugin_Handled;
}

//- Timer Functions -//

bool:Network_EnableChecks()
{
	if (GetFeatureStatus(FeatureType_Native, "SocketCreate") != FeatureStatus_Available)
	{
		g_bBypassKigenBanlistCVHook = true;
		SetConVarBool(g_hCVarCheckKigenBanlist, false);
		LogError("Tried to enable smac_use_kac_banlist, but Socket extension missing; ignoring.");
		return false;
	}
	
	g_hTimer = CreateTimer(5.0, Network_Timer, _, TIMER_REPEAT);
	return true;
}

Network_DisableChecks()
{
	if ( g_hTimer != INVALID_HANDLE )
	{
		KillTimer(g_hTimer);
		g_hTimer = INVALID_HANDLE;
	}
	if ( g_hSocket != INVALID_HANDLE )
	{
		CloseHandle(g_hSocket);
	}
}

public Action:Network_Timer(Handle:timer, any:we)
{
	if ( g_iInError > 0 )
	{
		g_iInError--;
		return Plugin_Continue;
	}

	decl Handle:f_hTemp;
	f_hTemp = g_hSocket;
	if ( f_hTemp != INVALID_HANDLE )
	{
		g_hSocket = INVALID_HANDLE;
		CloseHandle(f_hTemp);
	}

	for(new i=1;i<=MaxClients;i++)
	{
		if ( g_bAuthorized[i] && !g_bChecked[i] )
		{
			g_iInError = 1;
			g_hSocket = SocketCreate(SOCKET_TCP, Network_OnSocketError);
			SocketSetArg(g_hSocket, i);
			SocketConnect(g_hSocket, Network_OnSocketConnect, Network_OnSocketReceive, Network_OnSocketDisconnect, "master.kigenac.com", 9652);
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

//- Socket Functions -//

public Network_OnSocketConnect(Handle:socket, any:client)
{
	if ( !SocketIsConnected(socket) )
		return;

	decl String:f_sAuthID[64];
	if ( !g_bAuthorized[client] || !GetClientAuthString(client, f_sAuthID, sizeof(f_sAuthID)) )
		SocketDisconnect(socket);
	else
		SocketSend(socket, f_sAuthID, strlen(f_sAuthID)+1); // Send that \0! - Kigen
	return;
}

public Network_OnSocketDisconnect(Handle:socket, any:client)
{
	if ( socket == g_hSocket )
		g_hSocket = INVALID_HANDLE;
	CloseHandle(socket);
	return;
}

public Network_OnSocketReceive(Handle:socket, String:data[], const size, any:client) 
{
	if ( socket == INVALID_HANDLE || !g_bAuthorized[client] )
		return;

	g_bChecked[client] = true;
	if ( StrEqual(data, "_BAN") )
	{
		decl String:f_sAuthID[64], String:f_sBuffer[256];
		GetClientAuthString(client, f_sAuthID, sizeof(f_sAuthID));
		Format(f_sBuffer, sizeof(f_sBuffer), "%T", SMAC_GBANNED, client);
		SetTrieString(g_hDenyArray, f_sAuthID, f_sBuffer);
		SMAC_Log("%N (%s) is on the KAC global banlist.", client, f_sAuthID);
		KickClient(client, "%t", SMAC_GBANNED);
	}
	else if ( StrEqual(data, "_OK") )
	{
		// sigh here.
	}
	else
	{
		decl String:f_sAuthID[64];
		GetClientAuthString(client, f_sAuthID, sizeof(f_sAuthID));
		g_bChecked[client] = false;
		SMAC_Log("%N (%s) got unknown reply from KAC master server. Data: %s", f_sAuthID, data);
	}
	if ( SocketIsConnected(socket) )
		SocketDisconnect(socket);
}

public Network_OnSocketError(Handle:socket, const errorType, const errorNum, any:client)
{
	if ( socket == INVALID_HANDLE )
		return;

	// LogError("Socket Error: eT: %d, eN, %d, c, %d", errorType, errorNum, client);
	if ( g_hSocket == socket )
		g_hSocket = INVALID_HANDLE;
	LogError("Network: Unable to contact the KAC Master Server.");
	CloseHandle(socket);
}

public Network_OnKACBanlistChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (g_bBypassKigenBanlistCVHook)
	{
		g_bBypassKigenBanlistCVHook = false;
		return;
	}
	
	new bool:bNewValue = GetConVarBool(convar);
	
	// it was enabled, turn it off
	if (!bNewValue && g_bCheckKigenBanlist)
	{
		Network_DisableChecks();
	}
	
	// it wasn't enabled, but now trying to
	else if (bNewValue && !g_bCheckKigenBanlist)
	{
		g_bCheckKigenBanlist = Network_EnableChecks();
	}
	
	// else no /real/ change, ie. 0.1 - 0.0, both false
}
