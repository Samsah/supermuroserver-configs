public Action:ChooseTerrorist(Handle:timer)
{
	decl String:sMessage[256];
	new iTerNumber = GetNumberOfTers();
	new iTerNumber2 = iTerNumber;
	LeaveTer = iTerNumber;
	if (iTerNumber > 0 && GetConVarBool(dr_active) && GetConVarBool(dr_chooseter))
	{
		if (iTerNumber2 == 1) {
			Format(sMessage, 256, "%t", "LANG_DR_ONETER");
		}
		else {
			Format(sMessage, 256, "%t", "LANG_DR_MORETER");
		}
		for (new i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i))
			{
				if (GetClientTeam(i) == 2)
				{
					if (IsFakeClient(i))
					{
						ChangeClientTeam(i, 1);
					}
					CS_SwitchTeam(i, 3);
					oldterrorist = i;
				}
			}
		}
		new Handle:hPlayersToChoose = CreateArray();
		while (iTerNumber > 0)
		{
			FillTheList(hPlayersToChoose);
			if (GetArraySize(hPlayersToChoose) < iTerNumber)
			{
				ResetTerList();
				FillTheList(hPlayersToChoose);
			}
			new iTer = GetArrayCell(hPlayersToChoose, GetRandomInt(0, GetArraySize(hPlayersToChoose) + -1));
			NoRandom[iTer] = true;
			CS_SwitchTeam(iTer, 2);
			decl String:sName[64];
			GetClientName(iTer, sName, sizeof(sName));
			if (iTerNumber2 == 1)
			{
				if (GameEngine == 1) {
					Format(sMessage, 256, "{default}%s {red}%s", sMessage, sName);
				}
				if (GameEngine == 2) {
					Format(sMessage, 256, "{default}%s {red}%s", sMessage, sName);
				}
			} else {
				if (iTerNumber == iTerNumber2)
				{
					if (GameEngine == 1) {
						Format(sMessage, 256, "{default}%s {red}%s {default}%t", sMessage, sName, "LANG_DR_AND");
					}
					if (GameEngine == 2) {
						Format(sMessage, 256, "{default}%s {red}%s {default}%t", sMessage, sName, "LANG_DR_AND");
					}
				} else {
					if (GameEngine == 1) {
						Format(sMessage, 256, "{default}%s {red}%s", sMessage, sName);
					}
					if (GameEngine == 2) {
						Format(sMessage, 256, "{default}%s {red}%s", sMessage, sName);
					}
				}
			}
			iTerNumber--;
		}
		new Handle:save;
		CreateDataTimer(0.1, TTerMSG, save, 0);
		WritePackString(save, sMessage);
		CloseHandle(hPlayersToChoose);
		
	} else {
		if (GameEngine == 1) {
			CPrintToChatAll("{green}%t {default}%t", "LANG_DR_INFO", "LANG_DR_NOTERRORISTS");
		}
		if (GameEngine == 2) {
			CPrintToChatAll("{default} {green}%t {default}%t", "LANG_DR_INFO", "LANG_DR_NOTERRORISTS");
		}
	}
}

public Action:TTerMSG(Handle:timer, Handle:save)
{
	decl String:str[128];
	ResetPack(save, false);
	ReadPackCell(save);
	ReadPackString(save, str, 128);
	CPrintToChatAll("%s", str);
}

public Action:RespawnPlayer(Handle:timer, any:client) {
	if (dr_PlayerLoaded[client] && GetClientTeam(client) == CS_TEAM_CT && RespawnTime && !IsPlayerAlive(client)) {
		CS_RespawnPlayer(client);
		if (GameEngine == 1) {
			CPrintToChat(client, "{lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_AUTORESPAWN");
		}
		if (GameEngine == 2) {
			CPrintToChat(client, "{default} {lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_AUTORESPAWN");
		}
		EmitSoundToClient(client, ResSound);
	}
}

public Action:EndRespawnTimer(Handle:timer) {
	RespawnTime = false;
}

public Action:CreateMaster(Handle:timer)
{
	CreateFakeClient(DrMaster);
}

public Action:FixGravity(Handle:timer, any:client)
{
	new frags = GetClientFrags(client);
	for (new i = 1; i <= MaxClients; i++) {
		if (GetClientTeam(i) == CS_TEAM_CT && IsPlayerAlive(i) ) {
			if (GetClientFrags(i) > 0) {
				SetEntityGravity(i, gravity[frags]);
			} else {
				SetEntityGravity(i, 1.00);
			}
		} else {
			SetEntityGravity(i, 1.00);
		}
	}
}

dgssteam(client)
{
	new iWeapKnife = GetPlayerWeaponSlot(client, 2);
	if (iWeapKnife == -1)
	{
		return 0;
	}
	new EffEnv = CreateEntityByName("env_steam", -1);
	new EffKnife = CreateEntityByName("weapon_knife", -1);
	if (IsValidEntity(EffEnv))
	{
		if (dgsteam[client])
		{
			
		} else {
			new Float:vecKnifeOrigin[3];
			new Float:vecTrailOrigin[3];
			decl String:strKnifeName[28];
			Format(strKnifeName, 25, "Knife_%d_%d_%d", client, GetRandomInt(1, 100), GetRandomInt(1, 100));
			DispatchKeyValue(EffKnife, "targetname", strKnifeName);
			DispatchKeyValue(EffKnife, "spawnflags", "1");
			DispatchSpawn(EffKnife);
			GetEntPropVector(EffKnife, PropType:0, "m_vecOrigin", vecKnifeOrigin, 0);
			DispatchKeyValue(EffEnv, "parentname", strKnifeName);
			DispatchKeyValue(EffEnv, "endsize", "15");
			DispatchKeyValue(EffEnv, "initialstate", "1");
			DispatchKeyValue(EffEnv, "jetlength", "15");
			DispatchKeyValue(EffEnv, "rate", "10");
			DispatchKeyValue(EffEnv, "renderamt", "255");
			DispatchKeyValue(EffEnv, "rendercolor", "0 0 0");
			DispatchKeyValue(EffEnv, "rollspeed", "8");
			DispatchKeyValue(EffEnv, "speed", "20");
			DispatchKeyValue(EffEnv, "spreadspeed", "18");
			DispatchKeyValue(EffEnv, "startsize", "5");
			DispatchSpawn(EffEnv);
			vecTrailOrigin[0] = vecKnifeOrigin[0];
			vecTrailOrigin[1] = vecKnifeOrigin[1];
			vecTrailOrigin[2] = vecKnifeOrigin[2] - 20;
			TeleportEntity(EffEnv, vecTrailOrigin, NULL_VECTOR, NULL_VECTOR);
			SetVariantString(strKnifeName);
			AcceptEntityInput(EffEnv, "SetParent", -1, -1, 0);
			dgsteam[client] = true;
			if (AcceptEntityInput(iWeapKnife, "KillHierarchy", -1, -1, 0))
			{
				decl Float:vecClientOrig[3];
				GetClientAbsOrigin(client, vecClientOrig);
				TeleportEntity(EffKnife, vecClientOrig, NULL_VECTOR, NULL_VECTOR);
			} else {
				AcceptEntityInput(EffKnife, "KillHierarchy", -1, -1, 0);
			}
		}
	}
	return 0;
}

public Action:GlowPlayer(Handle:timer, any:client) {
	if(IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == CS_TEAM_CT) {
		
		if (GameEngine == 1) {
			if (dgsteam[client]) {
				dgssteam(client);
			}
		}
		
		if (NextGlowR[client]) {
			GlowColorR[client] += 15;
			GlowColorB[client] -= 15;
			if (GlowColorR[client] >= 255) {
				NextGlowG[client] = true;
				NextGlowR[client] = false;
			}
		}
		if (NextGlowG[client]) {
			GlowColorG[client] += 15;
			GlowColorR[client] -= 15;
			if (GlowColorG[client] >= 255) {
				NextGlowG[client] = false;
				NextGlowB[client] = true;
			}
		}
		if (NextGlowB[client]) {
			GlowColorB[client] += 15;
			GlowColorG[client] -= 15;
			if (GlowColorG[client] >= 255) {
				NextGlowB[client] = false;
				NextGlowR[client] = true;
			}
		}

		SetEntityRenderColor(client, GlowColorR[client], GlowColorG[client], GlowColorB[client], 255);
		CreateTimer(0.02, GlowPlayer, client);
	}
}

public Action:banmsg(Handle:Timer)
{
	if (GameEngine == 1) {
		CPrintToChatAll("{lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_BANTEXT");
		CPrintToChatAll("{lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_BANTEXT2");
	}
	if (GameEngine == 2) {
		CPrintToChatAll("{default} {lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_BANTEXT");
		CPrintToChatAll("{default} {lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_BANTEXT2");
	}

	if (dr_banmessagetimer) {
		KillTimer(dr_banmessagetimer);
		dr_banmessagetimer = INVALID_HANDLE;
	}
	dr_banmessagetimer = CreateTimer(GetConVarFloat(dr_banmessage), banmsg);
}

public Action:TimerAntiSpam(Handle:timer, any:client) {
	if (IsClientInGame(client)) {
		dr_AntiSpam[client] = false;
	}
}