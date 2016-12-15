#include <sourcemod>
#include <sdkhooks>
#include <cstrike>
#include <sdktools_entinput>
#include <sdktools_functions>
#undef REQUIRE_PLUGIN
#include <lastrequest>
#define REQUIRE_PLUGIN

/***************************************************
 * PLUGIN STUFF
 **************************************************/

new bool:HostiesLoaded;

public Plugin:myinfo =
{
	name = "Always Weapon Skins",
	author = "Neuro Toxin",
	description = "Players always get their weapon skins!",
	version = "1.9",
	url = "https://forums.alliedmods.net/showthread.php?t=237114",
}

public OnPluginStart()
{
	CreateConvars();
	LoadWeaponInfo();

	new Handle:hVersion = CreateConVar("aws_version", "1.9");
	new flags = GetConVarFlags(hVersion);
	flags |= FCVAR_NOTIFY;
	SetConVarFlags(hVersion, flags);
}

/***************************************************
 * CONVAR STUFF
 **************************************************/

new Handle:WeaponsTrie = INVALID_HANDLE;
new Handle:hCvarEnable = INVALID_HANDLE;
new Handle:hCvarDelay = INVALID_HANDLE;
new Handle:hCvarAlwaysReplace = INVALID_HANDLE;
new Handle:hCvarSkipNamedWeapons = INVALID_HANDLE;
new Handle:hCvarDebugMessages = INVALID_HANDLE;

new String:ProcessingClientWeapons[MAXPLAYERS + 1][512];
new bool:CvarEnable = false;
new Float:CvarDelay = 0.0;
new bool:CvarAlwaysReplace = false;
new bool:CvarSkipNamedWeapons = true;
new bool:CvarDebugMessages = false;

stock CreateConvars()
{
	hCvarEnable = CreateConVar("aws_enable", "1", "Enables plugin");
	hCvarDelay = CreateConVar("aws_delay", "0.0", "Delay weapon respawning by x seconds");
	hCvarAlwaysReplace = CreateConVar("aws_alwaysreplace", "0", "Allows map weapons to be replaced");
	hCvarSkipNamedWeapons = CreateConVar("aws_skipnamedweapons", "1", "If a weapon is named it wont replace");
	hCvarDebugMessages = CreateConVar("aws_debugmessages", "0", "Display debug messages in client console");
	
	HookConVarChange(hCvarEnable, OnCvarChanged);
	HookConVarChange(hCvarDelay, OnCvarChanged);
	HookConVarChange(hCvarAlwaysReplace, OnCvarChanged);
	HookConVarChange(hCvarSkipNamedWeapons, OnCvarChanged);
	HookConVarChange(hCvarDebugMessages, OnCvarChanged);
}

stock LoadConvars()
{
	CvarEnable = GetConVarBool(hCvarEnable);
	CvarDelay = GetConVarFloat(hCvarDelay);
	CvarAlwaysReplace = GetConVarBool(hCvarAlwaysReplace);
	CvarSkipNamedWeapons = GetConVarBool(hCvarSkipNamedWeapons);
	CvarDebugMessages = GetConVarBool(hCvarDebugMessages);
}

public OnCvarChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	if (cvar == hCvarEnable)
		CvarEnable = StringToInt(newVal) == 0 ? false : true;
	else if (cvar == hCvarDelay)
		CvarDelay = StringToFloat(newVal);
	else if (cvar == hCvarAlwaysReplace)
		CvarAlwaysReplace = StringToInt(newVal) == 0 ? false : true;
	else if (cvar == hCvarSkipNamedWeapons)
		CvarSkipNamedWeapons = StringToInt(newVal) == 0 ? false : true;
	else if (cvar == hCvarDebugMessages)
		CvarDebugMessages = StringToInt(newVal) == 0 ? false : true;
}

/***************************************************
 * HOSTIES SUPPORT STUFF
 **************************************************/

public OnAllPluginsLoaded()
{
	HostiesLoaded = LibraryExists("lastrequest");
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "lastrequest"))
		HostiesLoaded = true;
}
 
public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "lastrequest"))
		HostiesLoaded = false;
}

/***************************************************
 * EVENT STUFF
 **************************************************/

public OnConfigsExecuted()
{
	LoadConvars();
}

public OnMapStart()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
			
		if (!IsClientAuthorized(client))
			continue;
			
		OnClientPutInServer(client);
	}
}

public OnClientPutInServer(client)
{
	ProcessingClientWeapons[client] = "";
	SDKHook(client, SDKHook_WeaponEquipPost, OnPostWeaponEquip);
}

public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_WeaponEquipPost, OnPostWeaponEquip);
}

public Action:OnPostWeaponEquip(client, weapon)
{
	// Skip processing if plugin is disabled
	if (!CvarEnable)
		return Plugin_Continue;
	
	// Skip processing if hosties is loaded and client is in last request
	if (HostiesLoaded)
		if (IsClientInLastRequest(client))
			return Plugin_Continue;
	
	// Get the weapons classname
	new String:classname[64];
	GetEdictClassname(weapon, classname, sizeof(classname));
	
	// Return if this weapon is not configured in 'alwaysweaponskins.txt'
	new weaponteam = GetWeaponTeam(classname);
	if (weaponteam == -2)
		return Plugin_Continue;
	
	// Get weapon index
	new weaponindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	new m_iEntityQuality = GetEntProp(weapon, Prop_Send, "m_iEntityQuality");
	new m_iItemIDHigh = GetEntProp(weapon, Prop_Send, "m_iItemIDHigh");
	new m_iItemIDLow = GetEntProp(weapon, Prop_Send, "m_iItemIDLow");
	new check = m_iEntityQuality + m_iItemIDHigh + m_iItemIDLow;
	
	if (CvarDebugMessages)
		PrintToConsole(client, "[SM] OnPostWeaponEquip(client=%d, weapon=%d, classname=%s, weaponindex=%d, weaponteam=%d)", client, weapon, classname, weaponindex, weaponteam);	
	
	// remake weapon string for m4a1_silencer, usp_silencer and cz75a
	switch (weaponindex)
	{
		case 60:
		{
			if (CvarDebugMessages)
				PrintToConsole(client, "[SM] -> Index 60: Classname reset to: weapon_m4a1_silencer from: %s", classname);
			classname = "weapon_m4a1_silencer";
			check -= 3;
		}
		case 61:
		{
			if (CvarDebugMessages)
				PrintToConsole(client, "[SM] -> Index 61: Classname reset to: weapon_usp_silencer from: %s", classname);
			classname = "weapon_usp_silencer";
			check -= 3;
		}
		case 63:
		{
			if (CvarDebugMessages)
				PrintToConsole(client, "[SM] -> Index 63: Classname reset to: weapon_cz75a from: %s", classname);
			classname = "weapon_cz75a";
			check -= 3;
		}
	}
	
	// Get the clients process list
	new String:processlist[512];
	processlist = ProcessingClientWeapons[client];
	
	// If the weapon is processing, clean it off the processing
	// list and stop processing
	new String:listname[66];
	Format(listname, sizeof(listname), ":%s:", classname);
	if (StrContains(processlist, listname) > -1)
	{
		ReplaceString(processlist, sizeof(processlist), listname, "");
		ProcessingClientWeapons[client] = processlist;
		return Plugin_Continue;
	}
	
	// Skip if previously owned or if the weapon is already a skinned weapon
	new m_hPrevOwner = GetEntProp(weapon, Prop_Send, "m_hPrevOwner");
	if (m_hPrevOwner > 0 || check > 4)
		return Plugin_Continue;
		
	// Skip if the weapon is named while CvarSkipNamedWeapons is enabled
	if (CvarSkipNamedWeapons)
	{
		new String:entname[4];
		GetEntPropString(weapon, Prop_Send, "m_iName", entname, sizeof(entname));
		if (!StrEqual(entname, ""))
			return Plugin_Continue;
	}
	
	// If the weapon doesn't require a different team then stop processing
	new playerteam = GetEntProp(client, Prop_Data, "m_iTeamNum");
	if (!CvarAlwaysReplace && (weaponteam == -1 || weaponteam == playerteam))
		return Plugin_Continue;
	
	// Debug logging
	if (CvarDebugMessages)
	{
		new String:teamname[32];
		if (weaponteam == -1)
			teamname = "Any";
		else
			GetTeamName(weaponteam, teamname, sizeof(teamname));
			
		PrintToConsole(client, "[WS] Respawning %s for team %s", classname, teamname);
	}
		
	// Update the process list with the new weapon
	Format(processlist, sizeof(processlist), "%s:%s:", processlist, classname);
	ProcessingClientWeapons[client] = processlist;
	
	if (strlen(processlist) >= sizeof(processlist) - 8)
	{
		ProcessingClientWeapons[client] = "";
		if (CvarDebugMessages)
			PrintToConsole(client, "[WS] Processlist has been reset from an overflow");
		return Plugin_Continue;
	}
	
	if (CvarDebugMessages)
		PrintToConsole(client, "[WS] Weapon Process List: %s", processlist);
	
	// Check if a delay is required
	if (CvarDelay > 0.0)
	{
		new Handle:pack = CreateDataPack();
		WritePackCell(pack, GetClientUserId(client));
		WritePackCell(pack, EntIndexToEntRef(weapon));
		WritePackString(pack, classname);
		WritePackCell(pack, weaponteam);
		CreateTimer(CvarDelay, OnSwitchDelay, pack);
		return Plugin_Handled;
	}
	
	// Processing weapon switch
	ProcessWeaponSwitch(client, weapon, classname, weaponteam, playerteam);
	return Plugin_Handled;
}

/***************************************************
 * ALWAYS WEAPON SKINS STUFF
 **************************************************/

public Action:OnSwitchDelay(Handle:timer, any:pack)
{
	ResetPack(pack);
	new userid = ReadPackCell(pack);
	new client = GetClientOfUserId(userid);
	
	// Ensure client is still connected
	if (client == 0)
	{
		CloseHandle(pack);
		return Plugin_Continue;
	}
	
	// Ensure client is still alive
	if (!IsPlayerAlive(client))
	{
		CloseHandle(pack);
		if (CvarDebugMessages)
			PrintToConsole(client, "[WS] -> Skipped: Player is not alive after delay");
		return Plugin_Continue;
	}
	
	// Ensure client is on a valid team
	new playerteam = GetEntProp(client, Prop_Data, "m_iTeamNum");
	if (playerteam != CS_TEAM_CT && playerteam != CS_TEAM_T)
	{
		CloseHandle(pack);
		if (CvarDebugMessages)
			PrintToConsole(client, "[WS] -> Skipped: Player is not on a valid team after delay");
		return Plugin_Continue;
	}
	
	// Ensure weapon is still valid (another plugin may have removed it)
	new weapon = EntRefToEntIndex(ReadPackCell(pack));
	if (weapon == INVALID_ENT_REFERENCE)
	{
		CloseHandle(pack);
		if (CvarDebugMessages)
			PrintToConsole(client, "[WS] -> Skipped: Weapon is not valid edict after delay");
		return Plugin_Continue;
	}
	
	// Get the last bits of info for weapon switch
	new String:classname[64]; ReadPackString(pack, classname, sizeof(classname));
	new weaponteam = ReadPackCell(pack);
	CloseHandle(pack);
	
	// Process weapon switch
	ProcessWeaponSwitch(client, weapon, classname, weaponteam, playerteam);
	return Plugin_Continue;
}

stock ProcessWeaponSwitch(client, weapon, const String:classname[], weaponteam, playerteam)
{
	// Remove current weapon from player
	AcceptEntityInput(weapon, "Kill");
	
	// Switch team if required
	if (weaponteam > -1)
		SetEntProp(client, Prop_Data, "m_iTeamNum", weaponteam);
	
	// Give player new weapon
	GivePlayerItem(client, classname);
	
	// Switch team back if required
	if (weaponteam > -1)
		SetEntProp(client, Prop_Data, "m_iTeamNum", playerteam);
}

/***************************************************
 * CONFIG STUFF
 **************************************************/

stock LoadWeaponInfo()
{
	WeaponsTrie = CreateTrie();
	decl String:fullpath[] = "cfg/sourcemod/alwaysweaponskins.txt";
	
	new Handle:file = OpenFile(fullpath, "r");
	if (file == INVALID_HANDLE)
	{
		PrintToServer("[AWS]: Unable to load file '%s'", fullpath);
		return;
	}
	
	new String:line[256];
	new String:explodedline[2][64];
	
	// Loop through each line
	while (ReadFileLine(file, line, sizeof(line)))
	{
		// Trim the line of the bat
		TrimString(line);
		
		// Continue if the line is empty or if line is commented out
		if (StrEqual(line, "") || StrContains(line, "//") == 0)
			continue;
		
		// Explode the string and trim the value
		ExplodeString(line, ",", explodedline, 2, 128, true);
		TrimString(explodedline[0]);
		TrimString(explodedline[1]);

		// Add weapon config info to Trie
		SetTrieValue(WeaponsTrie, explodedline[0], WeaponTeamToInt(explodedline[1]));
	}
	
	// Close the file handle
	CloseHandle(file);	
}

stock WeaponTeamToInt(String:team[])
{
	if (StrEqual(team, "T"))
		return CS_TEAM_T;
	else if (StrEqual(team, "CT"))
		return CS_TEAM_CT;
	else
		return -1;	
}

stock GetWeaponTeam(const String:classname[])
{
	new team;
	if (GetTrieValue(WeaponsTrie, classname, team))
		return team;
	else
		return -2;
}