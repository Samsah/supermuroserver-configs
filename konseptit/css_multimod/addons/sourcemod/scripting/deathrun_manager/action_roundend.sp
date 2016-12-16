public Action:DR_Action_RoundEnd(Handle:event, String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(dr_active))
		return Plugin_Continue;

	if (GetConVarBool(dr_scouts))
		ResetScouts();

	RespawnTime = false;
	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && dgsteam[i]) {
			dgsteam[i] = false;
		}
	}

	if (GetConVarBool(dr_active) && GetConVarBool(dr_chooseter)) {
		CreateTimer(1.0, ChooseTerrorist);
	}
	
	if (GetTeamClientCount(CS_TEAM_CT) < 2)
		return Plugin_Continue;
	
	if (GetEventInt(event, "reason") == 9) {
		if (GetConVarBool(dr_fragtimeout)) {
			if (!NoGiveFragT) {
				for (new i = 1; i <= MaxClients; i++) {
					if (IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_T)
						SetEntProp(i, Prop_Data, "m_iFrags", GetClientFrags(i) + 1);
				}
				if (GameEngine == 1)
					CPrintToChatAll("{lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_TER_TIMEOUT");
				if (GameEngine == 2)
					CPrintToChatAll("{default} {lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_TER_TIMEOUT");
			} else {
				if (GameEngine == 1)
					CPrintToChatAll("{lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_TIMEOUT");
				if (GameEngine == 2)
					CPrintToChatAll("{default} {lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_TIMEOUT");
			}
		}
		for (new i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i))
				EmitSoundToClient(i, TimeOutSound);
		}
	} else {
		if (GetEventInt(event, "reason") == 8) {
			if (GetConVarBool(dr_fragt)) {
				if (!NoGiveFragT) {
					for (new i = 1; i <= MaxClients; i++) {
						if (IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_T)
							SetEntProp(i, Prop_Data, "m_iFrags", GetClientFrags(i) + 1);
					}
					if (GameEngine == 1)
						CPrintToChatAll("{lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_TERWIN");
					if (GameEngine == 2)
						CPrintToChatAll("{default} {lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_TERWIN");
				} else {
					if (GameEngine == 1)
						CPrintToChatAll("{green}%t {default}%t {red}%t", "LANG_DR_INFO", "LANG_DR_WIN_NOFRAG", "LANG_DR_TERRORIST");
					if (GameEngine == 2)
						CPrintToChatAll("{default} {green}%t {default}%t {red}%t", "LANG_DR_INFO", "LANG_DR_WIN_NOFRAG", "LANG_DR_TERRORIST");
				}
			}
			for (new i = 1; i <= MaxClients; i++) {
				if (IsClientInGame(i))
					EmitSoundToClient(i, TWinSound);
			}
		} else {
			if (GetEventInt(event, "reason") == 7) {
				if (GetConVarBool(dr_fragct)) {
					if (!NoGiveFragCT) {
						for (new i = 1; i <= MaxClients; i++) {
							if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_CT)
								SetEntProp(i, Prop_Data, "m_iFrags", GetClientFrags(i) + 1);
						}
						if (GameEngine == 1)
							CPrintToChatAll("{lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_CTWIN");
						if (GameEngine == 2)
							CPrintToChatAll("{default} {lightgreen}%t {green}%t", "LANG_DR_INFO", "LANG_DR_CTWIN");
					} else {
						if (GameEngine == 1)
							CPrintToChatAll("{green}%t {default}%t {blue}%t", "LANG_DR_INFO", "LANG_DR_WIN_NOFRAG", "LANG_DR_CTERRORIST");
						if (GameEngine == 2)
							CPrintToChatAll("{default} {green}%t {default}%t {blue}%t", "LANG_DR_INFO", "LANG_DR_WIN_NOFRAG", "LANG_DR_CTERRORIST");
					}
				}
				for (new i = 1; i <= MaxClients; i++) {
					if (IsClientInGame(i))
						EmitSoundToClient(i, CTWinSound);
				}
			}
		}
	}
	
	NoGiveFragT	= false;
	NoGiveFragCT = false;
	
	if (GetConVarBool(dr_antisuicide)) {
		for (new i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && IsPlayerAlive(i)) {
				SetEntProp(i, Prop_Data, "m_takedamage", 0, 1);
			}
		}
	}
	return Plugin_Continue;
}