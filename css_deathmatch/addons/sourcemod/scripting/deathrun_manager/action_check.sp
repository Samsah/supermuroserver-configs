GetNumberOfTers()
{
	new iTeam = GetTeamClientCount(2) + GetTeamClientCount(3);
	if (GetConVarInt(dr_numberofters) == 3) {
		if (iTeam > GetConVarInt(dr_thirdter) && GetConVarInt(dr_thirdter) > 0 && GetConVarInt(dr_secondter) > 0)
		{
			return 3;
		}
		if (iTeam > GetConVarInt(dr_secondter) && GetConVarInt(dr_secondter) > 0)
		{
			return 2;
		}
		if (iTeam > 1)
		{
			return 1;
		}
	} else {
		if (GetConVarInt(dr_numberofters) == 2) {
			if (iTeam > GetConVarInt(dr_secondter))
			{
				return 2;
			}
			if (iTeam > 1)
			{
				return 1;
			}
		} else {
			if (iTeam > 1)
			{
				return 1;
			}
		}
	}
	return 0;
}

ResetTerList()
{
	for (new i = 1; i <= MaxClients; i++) {
		if (oldterrorist == i)
		{
			NoRandom[i] = true;
		} else {
			NoRandom[i] = false;
		}
	}
}


FillTheList(Handle:hPlayersToChoose) {
	new PlayerList[MaxClients];
	new PlayerCount;

	for (new i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != CS_TEAM_CT)
			continue;

		if (!NoRandom[i] && GetClientTeam(i) == CS_TEAM_CT) {
			PlayerList[PlayerCount++] = i;
			PushArrayCell(hPlayersToChoose, i);
		}
	}
	return GetArraySize(hPlayersToChoose++);
}

botSwitch()
{
	new mc = GetMaxClients();
	for( new i = 1; i < mc; i++ ){
		if( IsClientInGame(i) && IsFakeClient(i)){
			decl String:target_name[50];
			GetClientName( i, target_name, sizeof(target_name) );
			if(StrEqual(target_name, DrMaster)){
				MasterID = i;
				CS_SwitchTeam(MasterID, CS_TEAM_T);
			}
		}
	}
}

ClientGiveScout(client)
{
	if (IsPlayerAlive(client))
	{
		new team = GetClientTeam(client);
		switch (team)
		{
			case 2:
			{
				if (GetConVarBool(dr_scouts)) {
					if (GetConVarBool(dr_scoutster)) {
						GiveScout(client);
					} else {
						if (!dr_AntiSpam[client]) {
							if (GameEngine == 1)
								CPrintToChat(client, "{lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_SCOUTSTER");
							if (GameEngine == 2)
								CPrintToChat(client, "{default} {lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_SCOUTSTER");
							dr_AntiSpam[client] = true;
							CreateTimer(GetConVarFloat(dr_SpamTime), TimerAntiSpam, client);
						}
					}
				} else {
					if (!dr_AntiSpam[client]) {
						if (GameEngine == 1)
							CPrintToChat(client, "{lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_SCOUTDISABLED");
						if (GameEngine == 2)
							CPrintToChat(client, "{default} {lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_SCOUTDISABLED");
						dr_AntiSpam[client] = true;
						CreateTimer(GetConVarFloat(dr_SpamTime), TimerAntiSpam, client);
						CreateTimer(GetConVarFloat(dr_SpamTime), TimerAntiSpam, client);
					}
				}
			}
			case 3:
			{
				if (GetConVarBool(dr_scouts)) {
					GiveScout(client);
				} else {
					if (!dr_AntiSpam[client]) {
						if (GameEngine == 1)
							CPrintToChat(client, "{lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_SCOUTDISABLED");					
						if (GameEngine == 2)
							CPrintToChat(client, "{default} {lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_SCOUTDISABLED");
						dr_AntiSpam[client] = true;
						CreateTimer(GetConVarFloat(dr_SpamTime), TimerAntiSpam, client);
					}
				}
			}
		}
	}
}

public MakeScout(client) {
	if (GetPlayerWeaponSlot(client, 0) == -1) {
		if (GameEngine == 1)
			GivePlayerItem(client, "weapon_scout");
		if (GameEngine == 2)
			GivePlayerItem(client, "weapon_ssg08");
		
		SetEntData(client, (FindSendPropInfo("CCSPlayer", "m_iAmmo") + (2*4)), 0);
		SetEntData(GetPlayerWeaponSlot(client, 0), FindSendPropInfo("CBaseCombatWeapon", "m_iClip1"), 0, _, true);
		decl String:PlayerName[64];
		GetClientName(client, PlayerName, sizeof(PlayerName));
		SpawnedScout -= 1;
		ScoutNoGive[client] = true;
		for (new target = 1; target <= MaxClients; target++) {
			if (IsClientInGame(target))
			{
				if (client == target)
				{
					if (!dr_AntiSpam[client]) {
						if (GameEngine == 1)
							CPrintToChat(client, "{lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_GIVESCOUT");
						if (GameEngine == 2)
							CPrintToChat(client, "{default} {lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_GIVESCOUT");
						dr_AntiSpam[client] = true;
						CreateTimer(GetConVarFloat(dr_SpamTime), TimerAntiSpam, client);
					}
				} else {
					if (GetClientTeam(client) == CS_TEAM_CT) {
						if (GameEngine == 1)
							CPrintToChat(target, "{green}%t {default}%t {blue}%s {default}%t {lightgreen}%d", "LANG_DR_INFO", "LANG_DR_PLAYER", PlayerName, "LANG_DR_GIVEDSCOUT", SpawnedScout);
						if (GameEngine == 2)
							CPrintToChat(target, "{default} {green}%t {default}%t {blue}%s {default}%t {lightgreen}%d", "LANG_DR_INFO", "LANG_DR_PLAYER", PlayerName, "LANG_DR_GIVEDSCOUT", SpawnedScout);
					} else {
						if (GetClientTeam(client) == CS_TEAM_T && GetConVarBool(dr_scoutster)) {
							if (GameEngine == 1)
								CPrintToChat(target, "{green}%t {default}%t {red}%s {default}%t {lightgreen}%d", "LANG_DR_INFO", "LANG_DR_PLAYER", PlayerName, "LANG_DR_GIVEDSCOUT", SpawnedScout);
							if (GameEngine == 2)
								CPrintToChat(target, "{default} {green}%t {default}%t {red}%s {default}%t {lightgreen}%d", "LANG_DR_INFO", "LANG_DR_PLAYER", PlayerName, "LANG_DR_GIVEDSCOUT", SpawnedScout);
						}
					}
				
				}
				
			}
		}
		
	} else {
		if (!dr_AntiSpam[client]) {
			if (GameEngine == 1)
				CPrintToChat(client, "{lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_ALLREADYWEAPON");
			if (GameEngine == 2)
				CPrintToChat(client, "{default} {lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_ALLREADYWEAPON");
			dr_AntiSpam[client] = true;
			CreateTimer(GetConVarFloat(dr_SpamTime), TimerAntiSpam, client);
		}
	}
}

public GiveScout(client)
{
	if (SpawnedScout >= 1) {
		if (!ScoutNoGive[client]) {
			MakeScout(client);
		} else {
			if (!dr_AntiSpam[client]) {
				if (GameEngine == 1)
					CPrintToChat(client, "{lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_ROUNDSCOUT");
				if (GameEngine == 2)
					CPrintToChat(client, "{default} {lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_ROUNDSCOUT");
				dr_AntiSpam[client] = true;
				CreateTimer(GetConVarFloat(dr_SpamTime), TimerAntiSpam, client);
			}
		}
	} else {
		if (!dr_AntiSpam[client]) {
			if (GameEngine == 1)
				CPrintToChat(client, "{lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_SCOUTEND");
			if (GameEngine == 2)
				CPrintToChat(client, "{default} {lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_SCOUTEND");
			dr_AntiSpam[client] = true;
			CreateTimer(GetConVarFloat(dr_SpamTime), TimerAntiSpam, client);
		}
	}
}

public ResetScouts()
{
	if (GetConVarBool(dr_scoutsystem)) {
		new ScoutsForPlayers = GetTeamClientCount(CS_TEAM_CT) + GetTeamClientCount(CS_TEAM_T);
		if (ScoutsForPlayers <= 1) {
			SpawnedScout = 1;
		} else {
			if (ScoutsForPlayers / 2) {
				SpawnedScout = ScoutsForPlayers / 2;
			} else {
				SpawnedScout = (ScoutsForPlayers + 1) / 2;
			}
		}
	} else {
		if (!GetConVarBool(dr_scoutster)) {
			new ScoutsForPlayers = GetTeamClientCount(CS_TEAM_CT);
			SpawnedScout = ScoutsForPlayers;
		} else {
			new ScoutsForPlayers = GetTeamClientCount(CS_TEAM_CT) + GetTeamClientCount(CS_TEAM_T);
			SpawnedScout = ScoutsForPlayers;
		}
	}
	for (new i = 1; i <= MaxClients; i++) {
		ScoutNoGive[i] = false;
	}
}

bool:GetBonusKeyValues() {
	decl String:path[255], String:buffer[255], String:buffer2[4][4];
	BuildPath(Path_SM, path, sizeof(path), "configs/cyxx/deathrun/deathrun_bonuses.cfg");
	new Handle:kv = CreateKeyValues("Bonuses");
	
	if (!FileToKeyValues(kv, path)) {
		LogError("[Deathrun Manager] Keyvalue config file \"%s\" couldn't be loaded. Bonus can not loaded.", path);
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
		
		KvGetString(kv, "modelname", buffer, sizeof(buffer));
		if (strcmp(buffer, "0", false)) {
			strcopy(modelname[frags], 255, buffer);
		}
		
	} while (KvGotoNextKey(kv));
	KvRewind(kv);
	CloseHandle(kv);
	return true;
}

CheckBonus(client) {
	GetBonusKeyValues();
	new frags;
	if (GetClientFrags(client) > GetConVarInt(dr_maxfrags)) {
		frags = GetConVarInt(dr_maxfrags);
	} else {
		frags = GetClientFrags(client);
	}
	
	if (glow_effect[frags])
		CreateTimer(0.02, GlowPlayer, client);
	
	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	
	if (speed[frags] > 0)
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", speed[frags]);
	if (gravity[frags] > 0)
		SetEntityGravity(client, gravity[frags]);
	if (health[frags] > 0)
		SetEntityHealth(client, health[frags]);
		
	SetEntityRenderColor(client, _color[frags][0], _color[frags][1], _color[frags][2], _color[frags][3]);

	if (strcmp(model[frags], "0", false) && strcmp(model[frags], "", false))
		SetEntityModel(client, model[frags]);
}