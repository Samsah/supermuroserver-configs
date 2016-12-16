/*
	SourceMod Anti-Cheat AntiRejoin Module
	Copyright (C) 2011 GoD-Tony
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

//- Global Variables -//

new Handle:g_hCVarAntiRespawn = INVALID_HANDLE;
new bool:g_bAntiRespawn = false;
new Handle:g_hClientSpawned = INVALID_HANDLE;
new g_iClientClass[MAXPLAYERS+1] = {-1, ...};
new bool:g_bClientMapStarted = false;

//- Plugin Functions -//

AntiRejoin_OnPluginStart()
{
	if (g_Game != Game_CSS)
		return;
		
	g_hCVarAntiRespawn = CreateConVar("smac_css_antirejoin", "0", "(CS:S Only) This will prevent people from leaving the game then rejoining to respawn.", FCVAR_PLUGIN);
	g_bAntiRespawn = GetConVarBool(g_hCVarAntiRespawn);

	g_hClientSpawned = CreateTrie();

	HookConVarChange(g_hCVarAntiRespawn, AntiRejoin_AntiRespawnChange);

	HookEvent("player_spawn", AntiRejoin_PlayerSpawn);
	HookEvent("player_death", AntiRejoin_PlayerDeath);
	HookEvent("round_start", AntiRejoin_RoundStart);
	HookEvent("round_end", AntiRejoin_CleanEvent);

	AddCommandListener(AntiRejoin_JoinClass, "joinclass");
}

AntiRejoin_OnMapEnd()
{
	if (g_Game != Game_CSS)
		return;
		
	g_bClientMapStarted = false;
	AntiRejoin_CleanEvent(INVALID_HANDLE, "", false);
}

public Action:AntiRejoin_JoinClass(client, const String:command[], args)
{
	if ( !g_bAntiRespawn || !g_bClientMapStarted || !client || g_bIsFake[client] || GetClientTeam(client) < 2 )
		return Plugin_Continue;

	new String:f_sAuthID[64], String:f_sTemp[64], f_iTemp;
	if ( !GetClientAuthString(client, f_sAuthID, sizeof(f_sAuthID)) )
		return Plugin_Continue;

	if ( !GetTrieValue(g_hClientSpawned, f_sAuthID, f_iTemp) )
		return Plugin_Continue;

	GetCmdArgString(f_sTemp, sizeof(f_sTemp));

	g_iClientClass[client] = StringToInt(f_sTemp);
	if ( g_iClientClass[client] < 0 )
		g_iClientClass[client] = 0;

	FakeClientCommandEx(client, "spec_mode");
	return Plugin_Handled;
}

public Action:AntiRejoin_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if ( !g_bAntiRespawn )
		return Plugin_Continue;

	new client = GetClientOfUserId(GetEventInt(event, "userid")), String:f_sAuthID[64];
	if ( !client || GetClientTeam(client) < 2 || !GetClientAuthString(client, f_sAuthID, sizeof(f_sAuthID)) )
		return Plugin_Continue;
	
	RemoveFromTrie(g_hClientSpawned, f_sAuthID);

	return Plugin_Continue
}

public Action:AntiRejoin_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if ( !g_bAntiRespawn )
		return Plugin_Continue;

	new client = GetClientOfUserId(GetEventInt(event, "userid")), String:f_sAuthID[64];
	if ( !client || !GetClientAuthString(client, f_sAuthID, sizeof(f_sAuthID)) )
		return Plugin_Continue;
	
	SetTrieValue(g_hClientSpawned, f_sAuthID, true);

	return Plugin_Continue
}

public Action:AntiRejoin_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bClientMapStarted = true;
}

public Action:AntiRejoin_CleanEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	CloseHandle(g_hClientSpawned);
	g_hClientSpawned = CreateTrie();

	for(new i=1;i<=MaxClients;i++)
	{
		if ( g_bInGame[i] && g_iClientClass[i] != -1 )
		{
			FakeClientCommandEx(i, "joinclass %d", g_iClientClass[i]);
			g_iClientClass[i] = -1;
		}
	}
}

public AntiRejoin_AntiRespawnChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_bAntiRespawn = GetConVarBool(convar);
}
