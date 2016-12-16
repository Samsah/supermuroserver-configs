public Action:DR_Action_RoundStart(Handle:event, String:name[], bool:dontBroadcast)
{
	if (GetConVarBool(dr_active)) {
		if (GetConVarBool(dr_scouts))
			ResetScouts();

		if (GetConVarBool(dr_respawn) && GetConVarInt(dr_respawn) > 0) {
			CreateTimer(GetConVarFloat(dr_respawn), EndRespawnTimer);
			RespawnTime = true;
		}
		for (new i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && i > 0 && GetClientTeam(i) == CS_TEAM_SPEC) {
				if (GameEngine == 1) {
					CPrintToChat(i, "{lightgreen}%t {green}Deathrun Manager by cyxapuk", "LANG_DR_INFO");
					CPrintToChat(i, "{lightgreen}%t {green}My Steam: http://steamcommunity.com/id/cyxapuk", "LANG_DR_INFO");
				}
				if (GameEngine == 2) {
					CPrintToChat(i, "{default} {lightgreen}%t \x07Deathrun Manager by cyxapuk", "LANG_DR_INFO");
					CPrintToChat(i, "{default} {lightgreen}%t \x07My Steam: http://steamcommunity.com/id/cyxapuk", "LANG_DR_INFO");
				}
			}
			if (IsFakeClient(i))
			{
				ChangeClientTeam(i, 1);
			}
		}
	}
}