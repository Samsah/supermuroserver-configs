#pragma semicolon 1

// Headers and includes.
#include <sourcemod>
#include <sdktools>
#include <cstrike>

#undef REQUIRE_PLUGIN
#include <sourcebans>

// Defines.
#define PLUGIN_VERSION "1.7.1"
#define ROUNDEND_CTS_WIN                                7        // Counter-Terrorists Win!
#define ROUNDEND_TERRORISTS_WIN                         8        // Terrorists Win!

// Global variables declaration.
new Handle:_active  = INVALID_HANDLE;
new Handle:_af		= INVALID_HANDLE;
new Handle:_ac		= INVALID_HANDLE;
new Handle:_rnd		= INVALID_HANDLE;
new Handle:_rpnum	= INVALID_HANDLE;
new Handle:_rpteam	= INVALID_HANDLE;
new Handle:_sc		= INVALID_HANDLE;
new Handle:_wcgsc	= INVALID_HANDLE;
new Handle:_scmax	= INVALID_HANDLE;
new Handle:_scnum	= INVALID_HANDLE;
new Handle:_b		= INVALID_HANDLE;
new Handle:_b_s		= INVALID_HANDLE;
new Handle:_b_g		= INVALID_HANDLE;
new Handle:_b_h		= INVALID_HANDLE;
new Handle:_b_m		= INVALID_HANDLE;
new Handle:_b_gr	= INVALID_HANDLE;
new Handle:_b_c		= INVALID_HANDLE;
new Handle:_svsc	= INVALID_HANDLE;
new Handle:_tb		= INVALID_HANDLE;
new Handle:_bt		= INVALID_HANDLE;
new Handle:_ar		= INVALID_HANDLE;
new Handle:_at		= INVALID_HANDLE;
new Handle:_terwin	= INVALID_HANDLE;
new Handle:_ffw		= INVALID_HANDLE;

new _scouts[MAXPLAYERS+1];
new Scoutsnum = 0;
new Float:gravity[2048];
new Float:speed[2048];
new health[2048];
new _color[2048][4];
new glow_effect[2048]	= 0;
new String:model[2048][255];
new bool:GlowTimerBool[65];
new GlowColor[65];
new scores[MAXPLAYERS+1];
new _respawn = 0;
new _respawn_i = 0;
new Handle:r_t;
new g_bSBAvailable = false;

// Information about plugin, don't  modify please.
public Plugin:myinfo = {
	name		= "Deathrun Manager",
	author		= "Vladislav Dolgov",
	description = "Deathrun manager for Counter-Strike Source.",
	version		= PLUGIN_VERSION,
	url			= "http://elistor.ru"
};

// OnPluginStart.
public OnPluginStart() {
	// Loading plugin translations.
	LoadTranslations("plugin.deathrun_manager");
	
	// Register configurable variables.
	CreateConVar("sm_deathrun_version", PLUGIN_VERSION, "Deathrun-manager version. Official Site: http://elistor.ru.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	_active   = CreateConVar("sm_deathrun_enabled", "1", "Enable or disable Deathrun Manager; 0 - disabled, 1 - enabled.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	_af		  = CreateConVar("sm_deathrun_autoforce", "1", "Enable or disable auto force players; 0 - disabled, 1 - enabled.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	_ac		  = CreateConVar("sm_deathrun_antisuicide", "1", "Enable or disable antisuicide for terrorists; 0 - disabled, 1 - enabled.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	_rnd	  = CreateConVar("sm_deathrun_randomizing", "1", "Enable or disable randomizing players; 0 - disabled, 1 - enabled.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	_rpnum	  = CreateConVar("sm_deathrun_randplayers", "1", "Number of randomizing players.", FCVAR_PLUGIN, true, 0.0, true, 64.0);
	_rpteam	  = CreateConVar("sm_deathrun_randplayersteam", "3", "Randomizing players from team; 0 - all, 2 - terrorists, 3 - couter-terrorists.", FCVAR_PLUGIN, true, 0.0, true, 3.0);
	_sc		  = CreateConVar("sm_deathrun_scouts", "1", "Enable or disable scouts module; 0 - disabled, 1 - enabled.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	_wcgsc	  = CreateConVar("sm_deathrun_scteam", "3", "Which team can get scouts?; 0 - all, 2 - terrorists, 3 - couter-terrorists.", FCVAR_PLUGIN, true, 0.0, true, 3.0);
	_scnum	  = CreateConVar("sm_deathrun_snum", "0", "Max scouts in round for all players; 0 - unlimited.", FCVAR_PLUGIN, true, 0.0, true, 64.0);
	_scmax	  = CreateConVar("sm_deathrun_smax", "1", "Max scouts in round per player; 0 - unlimited.", FCVAR_PLUGIN, true, 0.0, true, 16.0);
	_b		  = CreateConVar("sm_deathrun_bonuses", "1", "Enable or disable bonuses; 0 - disabled, 1 - enabled.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	_b_s	  = CreateConVar("sm_deathrun_bonuses_speed", "1", "Enable or disable bonus speed; 0 - disabled, 1 - enabled.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	_b_gr	  = CreateConVar("sm_deathrun_bonuses_gravity", "1", "Enable or disable bonus gravity; 0 - disabled, 1 - enabled.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	_b_h	  = CreateConVar("sm_deathrun_bonuses_health", "1", "Enable or disable bonus health; 0 - disabled, 1 - enabled.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	_b_m	  = CreateConVar("sm_deathrun_bonuses_model", "1", "Enable or disable bonus model; 0 - disabled, 1 - enabled.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	_b_g	  = CreateConVar("sm_deathrun_bonuses_glow", "1", "Enable or disable bonus glow; 0 - disabled, 1 - enabled.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	_b_c	  = CreateConVar("sm_deathrun_bonuses_color", "1", "Enable or disable bonus color; 0 - disabled, 1 - enabled.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	_svsc	  = CreateConVar("sm_deathrun_savescores", "1", "Enable or disable save scores; 0 - disabled, 1 - enabled.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	_tb		  = CreateConVar("sm_deathrun_autoban", "1", "Enable or disable auto banning terrorist for disconnect; 0 - disabled, 1 - enabled.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	_bt		  = CreateConVar("sm_deathrun_autoban_time", "60", "Time for ban terrorist, in minutes; 0 - permanent.", FCVAR_PLUGIN, true, 0.0, false);
	_ar		  = CreateConVar("sm_deathrun_autorespawn", "0", "Enable or disable autorespawn; 0 - disabled, 1 - enabled.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	_at		  = CreateConVar("sm_deathrun_autorespawn_time", "15", "Time for respawn after round start, in seconds.", FCVAR_PLUGIN, true, 0.0, false);
	_terwin	  = CreateConVar("sm_deathrun_winfrag", "1", "Enable or disable adding frags for winning commands; 0 - disabled, 1 - enabled.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	_ffw	  = CreateConVar("sm_deathrun_fragforwho", "2", "Which team can get frags when he wins?; 0 - all, 2 - terrorists, 3 - couter-terrorists.", FCVAR_PLUGIN, true, 0.0, true, 3.0);
	

	// Register console and chat commands.
	RegConsoleCmd("jointeam", cmd_jointeam);
	RegConsoleCmd("joinclass", cmd_suicide);
	RegConsoleCmd("spectate", cmd_spectate);
	RegConsoleCmd("kill", cmd_suicide);
	RegConsoleCmd("explode", cmd_suicide);
	RegConsoleCmd("scout", cmd_scout);
	
	// Hooking events.
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_disconnect", PlayerDisconnect_Event, EventHookMode_Pre);
	
}


public OnAllPluginsLoaded()
	if (LibraryExists("sourcebans"))
		g_bSBAvailable = true;

public OnLibraryAdded(const String:name[])
	if (StrEqual(name, "sourcebans"))
		g_bSBAvailable = true;

public OnLibraryRemoved(const String:name[])
	if (StrEqual(name, "sourcebans"))
		g_bSBAvailable = false;


public OnMapStart() {
	new ent = CreateEntityByName("func_hostage_rescue");
	if (ent > 0) {
		new Float:orign[3] = {-1000.0,...};
		DispatchKeyValue(ent, "targetname", "deathrun_roundend");
		DispatchKeyValueVector(ent, "orign", orign);
		DispatchSpawn(ent);
	}
}

public Action:PlayerDisconnect_Event(Handle:event, const String:name[], bool:dontBroadcast) {
	if (!GetConVarBool(_active) || !GetConVarBool(_tb))
		return Plugin_Continue;
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!client)
		return Plugin_Continue;
	
	if (IsClientInGame(client)) {
		if (GetClientTeam(client) == CS_TEAM_T) {
			if (GetTeamClientCount(CS_TEAM_CT) > 2) {
				decl String:reason[128], String:steamid[64], String:cname[32];
				GetEventString(event, "reason", reason, sizeof(reason));
				if (StrEqual(reason, "Disconnect by user.", false)) {
					GetEventString(event, "networkid", steamid, sizeof(steamid));
					if(!GetClientName(client, cname, sizeof(cname)))
						Format(cname, sizeof(cname), "Unconnected");
					
					if (g_bSBAvailable)
						SBBanPlayer(0, client, GetConVarInt(_bt), "Deathrun: Disconnected by terrorist");
					else
						BanClient(client, GetConVarInt(_bt), BANFLAG_AUTHID, "DEATHRUN: Terrorist can't disconnect", "DEATHRUN: Terrorist can't disconnect");
					PrintToChatAll("\x04%t \x01>\x03 %t", "deathrun", "terr disconnected", cname, GetConVarInt(_bt));
				}
			}
			PrintToChatAll("\x04%t \x01>\x03 %t", "deathrun", "selecting random terrorist");
			CreateTimer(2.0, select_rt);
		}
	}
	
	
	return Plugin_Continue;
}  

public OnClientPutInServer(client) {
	scores[client] = 0;
}

// Used when player use command "jointeam".
public Action:cmd_jointeam(client, args) {
	// Check for plugin active, check for autoforce, check for client in game.
	if (!GetConVarBool(_active) || !GetConVarBool(_af) || !IsClientInGame(client))
		return Plugin_Continue;
	
	// Get args.
	decl String:text[192];
	if (!GetCmdArgString(text, sizeof(text)))
		return Plugin_Handled;
	
	new startidx = 0;
	if(text[strlen(text)-1] == '"') {
		text[strlen(text)-1] = '\0';
		startidx = 1;
	}
	
	new team_num = StringToInt(text[startidx]);
	new team_old = GetClientTeam(client);
	
	if ((team_old != CS_TEAM_T) && (0 <= team_num <= 4)) {
		if (GetTeamClientCount(CS_TEAM_T) > 0) {
			ChangeClientTeam(client, CS_TEAM_CT);
			PrintToChat(client, "\x04%t \x01>\x03 %t \x02%t.", "deathrun", "auto force", "ct");
			return Plugin_Handled;
		} else {
			ChangeClientTeam(client, CS_TEAM_T);
			PrintToChat(client, "\x04%t \x01>\x03 %t \x02%t.", "deathrun", "auto force", "t");
			return Plugin_Handled;
		}
	} else if ((team_old == CS_TEAM_T) && _ac) {
		PrintToChat(client, "\x04%t \x01>\x03 %t", "deathrun", "terrorist suicide");
		return Plugin_Handled;
	} else {
		PrintToChat(client, "\x04%t \x01>\x03 %t", "deathrun", "only choosen can be a terrorist");
		return Plugin_Handled;
	}
}

public Action:cmd_suicide(client, args) {
	if (!GetConVarBool(_active) || !GetConVarBool(_ac) || !IsClientInGame(client))
		return Plugin_Continue;
	
	if (GetClientTeam(client) == CS_TEAM_T) {
		if (IsPlayerAlive(client)) {
			PrintToChat(client, "\x04%t \x01>\x03 %t", "deathrun", "terrorist suicide");
			return Plugin_Handled;		
		}
	}
	return Plugin_Continue;
}

public Action:cmd_spectate(client, args) {
	if (!GetConVarBool(_active) || !GetConVarBool(_ac) || !IsClientInGame(client))
		return Plugin_Continue;
	
	if (GetClientTeam(client) == CS_TEAM_T) {
		if (IsPlayerAlive(client)) {
			PrintToChat(client, "\x04%t \x01>\x03 %t", "deathrun", "terrorist suicide");
			return Plugin_Handled;		
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
	if (!GetConVarBool(_active))
		return Plugin_Continue;
	
	if (GetConVarBool(_rnd)) {
		PrintToChatAll("\x04%t \x01>\x03 %t", "deathrun", "selecting random terrorist");
		CreateTimer(2.0, select_rt);
	}
	
	if((GetEventInt(event, "reason") == ROUNDEND_TERRORISTS_WIN) && _terwin) {
		for (new i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i) && IsPlayerAlive(i) && (GetClientTeam(i) == CS_TEAM_T) && ((GetConVarInt(_ffw) == CS_TEAM_T) || !GetConVarInt(_ffw))) {
				scores[i]++;
			}
	} else if((GetEventInt(event, "reason") == ROUNDEND_CTS_WIN) && _terwin) {
		for (new i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i) && IsPlayerAlive(i) && (GetClientTeam(i) == CS_TEAM_CT) && ((GetConVarInt(_ffw) == CS_TEAM_CT) || !GetConVarInt(_ffw))) {
				scores[i]++;
			}
	}
	
	return Plugin_Continue;
}

public Action:select_rt(Handle:timer) {
	if (!GetConVarBool(_active) || !GetConVarBool(_rnd))
		return Plugin_Continue;
	
	new t_num = 1;
	
	if (GetConVarInt(_rpnum) > 0)
		t_num = GetConVarInt(_rpnum);
	else
		t_num = GetTeamClientCount(CS_TEAM_CT) / 2;
	
	new t = GetRandomPlayer();
	for (new i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i))
			continue;
		
		if (GetClientTeam(i) != CS_TEAM_T)
			continue;
		
		CS_SwitchTeam(i, CS_TEAM_CT);
	}
	
	if (t != -1) {
		for (new i = 1; i <= t_num; i++) {
			CS_SwitchTeam(t, CS_TEAM_T);
			SetEntProp(t, Prop_Data, "m_takedamage", 0, 1);
			PrintToChatAll("\x04%t \x01>\x03 %t", "deathrun", "player go to terrorists", t);
		}
	} else
		PrintToChatAll("\x04%t \x01>\x03 %t", "deathrun", "not people for random terrorist");
	return Plugin_Continue;
}

GetRandomPlayer() {
	new PlayerList[MaxClients];
	new PlayerCount;
	
	for (new i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i))
			continue;
		
		if ((GetClientTeam(i) != GetConVarInt(_rpteam)) && GetConVarInt(_rpteam) > 1)
			continue;
		
		PlayerList[PlayerCount++] = i;
	}
	
	if (PlayerCount == 0)
		return -1;
	
	return PlayerList[GetRandomInt(0, PlayerCount-1)];
}

public Action:cmd_scout(client, args) {
	if (!GetConVarBool(_active) || !IsClientInGame(client))
		return Plugin_Continue;
	
	new team = GetClientTeam(client);
	new wcgsc = GetConVarInt(_wcgsc);
	
	if (GetConVarBool(_sc)) {
		if (IsPlayerAlive(client)) {
			switch (team) {
				case 2: {
					if (!wcgsc)
						GiveScout(client);
					else if (wcgsc == team)
						GiveScout(client);
					else
						PrintToChat(client, "\x04%t \x01>\x03 %t", "deathrun", "only ct can get scout");
				}
				
				case 3: {
					if (wcgsc == 0)
						GiveScout(client);
					else if (wcgsc == team)
						GiveScout(client);
					else
						PrintToChat(client, "\x04%t \x01>\x03 %t", "deathrun", "only ct can get scout");
				}
				
				default:
					PrintToChat(client, "\x04%t \x01>\x03 %t", "deathrun", "only alive can get scout");
			}
		}
		else
			PrintToChat(client, "\x04%t \x01>\x03 %t", "deathrun", "only alive players");
	}
	else
		PrintToChat(client, "\x04%t \x01>\x03 %t", "deathrun", "scouts disabled");
		
	
	return Plugin_Continue;
}

public GiveScout(client) {
	if (Scoutsnum < GetConVarInt(_scnum) || !GetConVarInt(_scnum)) {
		if (_scouts[client] < GetConVarInt(_scmax) || !GetConVarInt(_scmax))
			MakeScout(client);
		else
			PrintToChat(client, "\x04%t \x01>\x03 %t", "deathrun", "1 scout to 1 player");
	}
	else
		PrintToChat(client, "\x04%t \x01>\x03 %t", "deathrun", "all scouts ended");
}

public MakeScout(client) {
	if (GetPlayerWeaponSlot(client, 0) == -1) {
		GivePlayerItem(client, "weapon_scout");
		SetEntData(client, (FindSendPropInfo("CCSPlayer", "m_iAmmo") + (2*4)), 0);
		SetEntData(GetPlayerWeaponSlot(client, 0), FindSendPropInfo("CBaseCombatWeapon", "m_iClip1"), 0, _, true);
		PrintToChat(client, "\x04%t \x01>\x03 %t", "deathrun", "get scout without ammo");
		_scouts[client]++;
		Scoutsnum++;
	}
	else
		PrintToChat(client, "\x04%t \x01>\x03 %t", "deathrun", "already have weapon");
}

// Reset Scouts function.
public ResetScouts() {
	// Reset scouts number for each player.
	for (new i=1; i<=MaxClients; i++)
		_scouts[i] = 0;
	// Reset scouts.
	Scoutsnum = 0;
}

// Round start event.
public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	// If plugin disabled do nothing.
	if (!GetConVarBool(_active))
		return Plugin_Continue;
	
	// If scouts module enabled reset scouts.
	if (GetConVarBool(_sc))
		ResetScouts();
	
	
	if (GetConVarBool(_ar)) {
		_respawn = 1;
		_respawn_i = GetConVarInt(_at);
		r_t = CreateTimer(1.0, respawn);
	}
	
	return Plugin_Continue;
}


public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
	// If plugin disabled do nothing.
	if (!GetConVarBool(_active))
		return Plugin_Continue;
	
	// Create victim and attacker variables.
	new victim_id	= GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker_id = GetClientOfUserId(GetEventInt(event, "attacker"));
		
	if(_svsc && attacker_id && victim_id && attacker_id != victim_id && GetClientTeam(attacker_id) != GetClientTeam(victim_id))
		scores[attacker_id]++;
	
	if (GetConVarBool(_ar) && _respawn && GetClientTeam(victim_id) == CS_TEAM_CT)
		CreateTimer(1.0, respawn_2, victim_id);
	
	return Plugin_Continue;
}

bool:GetBonusKeyValues() {
	decl String:path[255], String:buffer[255], String:buffer2[4][4];
	BuildPath(Path_SM, path, sizeof(path), "configs/deathrun/bonuses.cfg");
	new Handle:kv = CreateKeyValues("Bonuses");
	
	if (!FileToKeyValues(kv, path)) {
		LogError("[Elistor Deathrun] Keyvalue config file \"%s\" couldn't be loaded. Bonus can not loaded.", path);
		return false;
	}
	
	KvGotoFirstSubKey(kv);
	
	do {
		KvGetSectionName(kv, buffer, sizeof(buffer));
		new frags = StringToInt(buffer);
		
		gravity[frags] = KvGetFloat(kv, "gravity", 1.00);
		speed[frags] = KvGetFloat(kv, "speed", 1.00);
		health[frags] = KvGetNum(kv, "health", 100);
		glow_effect[frags] = KvGetNum(kv, "effects");
		
		KvGetString(kv, "color", buffer, sizeof(buffer));
		
		ExplodeString(buffer, ",", buffer2, sizeof(buffer2), sizeof(buffer2[]));
		
		for (new i = 0; i <= 3; i++) {
			_color[frags][i] = StringToInt(buffer2[i]);
		}
		
		KvGetString(kv, "model", buffer, sizeof(buffer));
		if (strcmp(buffer, "0", false)) {
			strcopy(model[frags], 255, buffer);
			PrecacheModel(model[frags], true);
		}
		
	} while (KvGotoNextKey(kv));
	KvRewind(kv);
	CloseHandle(kv);
	return true;
}

CheckBonus(client) {
	GetBonusKeyValues();
	new frags = GetClientFrags(client);
	
	if (glow_effect[frags] && GetConVarBool(_b_g))
		CreateTimer(0.02, GlowPlayer, client);
	
	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	
	if (GetConVarBool(_b_s) && speed[frags] > 0)
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", speed[frags]);
	if (GetConVarBool(_b_gr) && gravity[frags] > 0)
		SetEntityGravity(client, gravity[frags]);
	if (GetConVarBool(_b_h) && health[frags] > 0)
		SetEntityHealth(client, health[frags]);
	if (GetConVarBool(_b_c))
		SetEntityRenderColor(client, _color[frags][0], _color[frags][1], _color[frags][2], _color[frags][3]);
	if (strcmp(model[frags], "0", false) && strcmp(model[frags], "", false) && GetConVarBool(_b_m))
		SetEntityModel(client, model[frags]);
}

// Executes on player spawn.
public Action:Event_OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	// If plugin disabled do nothing.
	if (!GetConVarBool(_active))
		return Plugin_Continue;
	
	// Get clientid and client team.
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new team = GetClientTeam(client);
	
	// If scouts enabled.
	if (GetConVarBool(_sc)) {
		// Reset player scouts.
		_scouts[client] = 0;
		// If player can get scout printing instructions.
		if (GetConVarInt(_wcgsc) == 0 || GetConVarInt(_wcgsc) == team)
			PrintToChat(client, "\x04%t \x01>\x03 %t", "deathrun", "to get scout type this");
	}
	// Give nightvision for player at spawn.
	GivePlayerItem(client, "item_nvgs", 0);
	
	// If player team CT  and bonuses enabled check bonuses for him.
	if(_b && (team == CS_TEAM_CT)) {
		CheckBonus(client);
	}
	
	return Plugin_Continue;
}

// Many executes per menute.
public OnGameFrame() {
	// Execute this for all client slots.
	for (new i = 1; i <= MaxClients; i++) {
		// Check for plugin active, client in game and alive.
		if (GetConVarBool(_active) && IsClientInGame(i)) {
			if(GetConVarBool(_svsc))
				SetEntProp(i, Prop_Data, "m_iFrags", scores[i]);
			
			// Fix for gravity bug on ladders for CT.
			if (IsPlayerAlive(i) && (GetClientTeam(i) == CS_TEAM_CT)) {
				SetEntityGravity(i, gravity[scores[i]]);
			} else if (IsPlayerAlive(i)) {
				SetEntityGravity(i, 1.00);
			}
		}
	}
}

public Action:GlowPlayer(Handle:timer, any:client) {
	if(IsClientInGame(client) && IsPlayerAlive(client)) {
		if (GlowTimerBool[client]) {
			GlowColor[client] -= 11;
			if (GlowColor[client] < 0) {
				GlowColor[client] = 0;
				GlowTimerBool[client] = false;
			}
		} else {
			GlowColor[client] += 11;
			if (GlowColor[client] > 255) {
				GlowColor[client] = 255;
				GlowTimerBool[client] = true;
			}
		}
		
		SetEntityRenderColor(client, 255, 255, 255, GlowColor[client]);
		CreateTimer(0.02, GlowPlayer, client);
	}
}

public Action:respawn(Handle:timer) {
	if (GetConVarBool(_ar) && _respawn) {
		_respawn_i--;
		PrintHintTextToAll("%t", "auto-respawn", _respawn_i);
		
		if(_respawn_i <= 0)
			_respawn = false;
		
		if(r_t != INVALID_HANDLE)
			KillTimer(r_t);
		
		r_t = CreateTimer(1.0, respawn);
	}
}

public Action:respawn_2(Handle:timer, any:client) {
	CS_RespawnPlayer(client);
}




