/*
	SourceMod Anti-Cheat Aimbot Module
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

/*
	The idea is to catch obvious aimbots that quickly snap and kill a player.
	Keep a small record of players' angles, and analyze it for snaps when they get a kill.
*/

#define AIM_RECORD_SIZE		32		// How many frames worth of angle data history to store
#define AIM_ANGLE_CHANGE	45.0	// Max angle change that a player should snap
#define AIM_BAN_MIN			4		// Minimum number of detections before an auto-ban is allowed

//- Global Variables -//

new Handle:g_hCVarAimbot = INVALID_HANDLE;
new Handle:g_hCVarAimbotBan = INVALID_HANDLE;

new bool:g_bAimbotEnabled;
new g_iAimbotBan;

new Float:g_fAimAngles[MAXPLAYERS+1][AIM_RECORD_SIZE][3];
new g_iAryIdx[MAXPLAYERS+1];

new g_iAimDetections[MAXPLAYERS+1];

new Handle:g_IgnoreWeapons;
new bool:g_bEntKillHooked;

//- Plugin Functions -//

Aimbot_OnPluginStart()
{
	g_hCVarAimbot = CreateConVar("smac_aimbot", "1", "Aimbot detection module", FCVAR_PLUGIN);
	g_hCVarAimbotBan = CreateConVar("smac_aimbot_ban", "0", "Number of aimbot detections before a player is banned. Minimum allowed is 4. (0 = Never ban)", FCVAR_PLUGIN);
	
	Aimbot_CvarChange(g_hCVarAimbot, "", "");
	Aimbot_BanCvarChange(g_hCVarAimbotBan, "", "");
	
	HookConVarChange(g_hCVarAimbot, Aimbot_CvarChange);
	HookConVarChange(g_hCVarAimbotBan, Aimbot_BanCvarChange);
	
	Aimbot_PopulateIgnoredWeapons();
}

Aimbot_PopulateIgnoredWeapons()
{
	g_IgnoreWeapons = CreateTrie();
	
	switch (g_Game)
	{
		case Game_CSS:
		{
			SetTrieValue(g_IgnoreWeapons, "weapon_knife", 1);
		}
		case Game_DOD:
		{	
			SetTrieValue(g_IgnoreWeapons, "weapon_spade", 1);
			SetTrieValue(g_IgnoreWeapons, "weapon_amerknife", 1);
		}
		case Game_TF2:
		{	
			SetTrieValue(g_IgnoreWeapons, "tf_weapon_bottle", 1);
			SetTrieValue(g_IgnoreWeapons, "tf_weapon_sword", 1);
			SetTrieValue(g_IgnoreWeapons, "tf_weapon_wrench", 1);
			SetTrieValue(g_IgnoreWeapons, "tf_weapon_robot_arm", 1);
			SetTrieValue(g_IgnoreWeapons, "tf_weapon_fists", 1);
			SetTrieValue(g_IgnoreWeapons, "tf_weapon_bonesaw", 1);
			SetTrieValue(g_IgnoreWeapons, "tf_weapon_fireaxe", 1);
			SetTrieValue(g_IgnoreWeapons, "tf_weapon_bat", 1);
			SetTrieValue(g_IgnoreWeapons, "tf_weapon_bat_wood", 1);
			SetTrieValue(g_IgnoreWeapons, "tf_weapon_bat_fish", 1);
			SetTrieValue(g_IgnoreWeapons, "tf_weapon_club", 1);
			SetTrieValue(g_IgnoreWeapons, "tf_weapon_shovel", 1);
			SetTrieValue(g_IgnoreWeapons, "tf_weapon_knife", 1);
		}
	}
}

Aimbot_OnClientPutInServer(client)
{
	/* Only clear a client's record if it's a new client, and not just a map change. */
	if (IsClientNew(client))
	{
		Aimbot_ClearAngles(client);
		g_iAimDetections[client] = 0;
	}
}

public Aimbot_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new bool:bNewValue = GetConVarBool(convar);

	if (bNewValue && !g_bAimbotEnabled)
		Aimbot_Enable();
	else if (!bNewValue && g_bAimbotEnabled)
		Aimbot_Disable();
}

public Aimbot_BanCvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	/* Anything lower than 4 will generate false positives. */
	new iNewValue = GetConVarInt(convar);
	
	if (iNewValue > 0 && iNewValue < AIM_BAN_MIN)
	{
		SetConVarInt(convar, AIM_BAN_MIN);
		return;
	}

	if (iNewValue <= 0)
		g_iAimbotBan = 0;
	else if (iNewValue <= AIM_BAN_MIN)
		g_iAimbotBan = AIM_BAN_MIN;
	else
		g_iAimbotBan = iNewValue;
}

public Aimbot_OnEntTeleport(const String:output[], caller, activator, Float:delay)
{
	/* A client is being teleported in the map. */
	if (1 <= activator <= MaxClients && g_bConnected[activator])
	{
		Aimbot_ClearAngles(activator);
		CreateTimer(0.1, Aimbot_ClearAnglesTimer, GetClientUserId(activator), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Aimbot_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	
	if (1 <= client <= MaxClients)
	{
		Aimbot_ClearAngles(client);
		CreateTimer(0.1, Aimbot_ClearAnglesTimer, userid, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:Aimbot_ClearAnglesTimer(Handle:timer, any:userid)
{
	/* Delayed because the clients' angles can sometimes "spin" after being teleported. */
	new client = GetClientOfUserId(userid);
	
	if (1 <= client <= MaxClients)
		Aimbot_ClearAngles(client);
	
	return Plugin_Stop;
}

public Action:Aimbot_DecreaseCount(Handle:timer, any:userid)
{
	/* Decrease the detection count by 1. */
	new client = GetClientOfUserId(userid);
	
	if (1 <= client <= MaxClients)
		g_iAimDetections[client]--;
	
	return Plugin_Stop;
}

public Aimbot_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Not all mods provide the weapon in this event.
	decl String:weapon[32];
	weapon[0] = '\0';
	
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	// Ignore the kill if one of the ignored weapons was used.
	new dummy;
	if (weapon[0] != '\0' && GetTrieValue(g_IgnoreWeapons, weapon, dummy))
		return;
		
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (1 <= victim <= MaxClients && 1 <= attacker <= MaxClients && victim != attacker)
		Aimbot_AnalyzeAngles(attacker);
}

public Aimbot_EntityKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	/* (OB Only) Use this event when possible for inflictor support. */
	new victim = GetEventInt(event, "entindex_killed");
	new attacker = GetEventInt(event, "entindex_attacker");
	new inflictor = GetEventInt(event, "entindex_inflictor");
	
	if (1 <= victim <= MaxClients && 1 <= attacker <= MaxClients && victim != attacker && inflictor == attacker)
	{
		decl String:weapon[32];
		GetClientWeapon(attacker, weapon, sizeof(weapon));
		
		new dummy;
		if (GetTrieValue(g_IgnoreWeapons, weapon, dummy))
			return;
		
		Aimbot_AnalyzeAngles(attacker);
	}
}

Aimbot_OnPlayerRunCmd(client, Float:angles[3])
{
	if (!g_bAimbotEnabled)
		return;
	
	CopyVector(angles, g_fAimAngles[client][g_iAryIdx[client]]);
	g_iAryIdx[client]++;
	
	if (g_iAryIdx[client] == AIM_RECORD_SIZE)
		g_iAryIdx[client] = 0;
}

Aimbot_AnalyzeAngles(client)
{
	/* Analyze the client to see if their angles snapped. */
	decl Float:vLastAngles[3], Float:vAngles[3], Float:fAngleDiff;
	new idx = g_iAryIdx[client];
	
	for (new i = 0; i < AIM_RECORD_SIZE; i++)
	{
		if (idx == AIM_RECORD_SIZE)
			idx = 0;
			
		if (IsVectorNull(g_fAimAngles[client][idx]))
			break;
		
		// Nothing to compare on the first iteration.
		if (i == 0)
		{
			CopyVector(g_fAimAngles[client][idx], vLastAngles);
			idx++;
			continue;
		}
		
		CopyVector(g_fAimAngles[client][idx], vAngles);
		fAngleDiff = GetVectorDistance(vLastAngles, vAngles);
		
		// If the difference is being reported higher than 180, get the 'real' value.
		if (fAngleDiff > 180)
			fAngleDiff = (fAngleDiff - 360) * -1;

		if (fAngleDiff > AIM_ANGLE_CHANGE)
		{
			Aimbot_Detected(client, fAngleDiff);
			break;
		}
		
		CopyVector(vAngles, vLastAngles);
		idx++;
	}
}

Aimbot_ClearAngles(client)
{
	/* Clear angle history and reset the index. */
	g_iAryIdx[client] = 0;
	
	for (new i = 0; i < AIM_RECORD_SIZE; i++)
		for (new j = 0; j < 3; j++)
			g_fAimAngles[client][i][j] = 0.0;
}

Aimbot_Detected(client, const Float:deviation)
{
	// Expire this detection after 10 minutes.
	g_iAimDetections[client]++;
	CreateTimer(600.0, Aimbot_DecreaseCount, GetClientUserId(client));
	
	// Ignore the first detection as it's just as likely to be a false positive.
	if (g_iAimDetections[client] <= 1)
		return;

	new String:f_sName[64], String:f_sAuthID[64], String:f_sIP[64];
	GetClientName(client, f_sName, sizeof(f_sName));
	GetClientAuthString(client, f_sAuthID, sizeof(f_sAuthID));
	GetClientIP(client, f_sIP, sizeof(f_sIP));
	
	SMAC_Log("%N (ID: %s | IP: %s) is suspected of using an aimbot. (Detection #%i) (Deviation: %.0f°)", client, f_sAuthID, f_sIP, g_iAimDetections[client], deviation);
	SMAC_PrintToChatAdmins("%t", SMAC_AIMBOTDETECTED, f_sName, g_iAimDetections[client], deviation);
	
	if (g_iAimbotBan && g_iAimDetections[client] >= g_iAimbotBan)
	{
		SMAC_Log("%N (ID: %s | IP: %s) was banned for using an aimbot.", client, f_sAuthID, f_sIP);
		SMAC_Ban(client, g_iBanDuration, SMAC_BANNED, "SMAC: Aimbot Detected");
	}
}

Aimbot_Enable()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		Aimbot_ClearAngles(i);
		g_iAimDetections[i] = 0;
	}
		
	g_bAimbotEnabled = true;
	HookEntityOutput("trigger_teleport", "OnEndTouch", Aimbot_OnEntTeleport);
	HookEvent("player_spawn", Aimbot_PlayerSpawn, EventHookMode_Post);
	
	g_bEntKillHooked = HookEventEx("entity_killed", Aimbot_EntityKilled, EventHookMode_Post);
	
	if (!g_bEntKillHooked)
		HookEvent("player_death", Aimbot_PlayerDeath, EventHookMode_Post);
}

Aimbot_Disable()
{
	g_bAimbotEnabled = false;
	UnhookEntityOutput("trigger_teleport", "OnEndTouch", Aimbot_OnEntTeleport);
	UnhookEvent("player_spawn", Aimbot_PlayerSpawn, EventHookMode_Post);
	
	if (g_bEntKillHooked)
		UnhookEvent("entity_killed", Aimbot_EntityKilled, EventHookMode_Post);
	else
		UnhookEvent("player_death", Aimbot_PlayerDeath, EventHookMode_Post);
}
