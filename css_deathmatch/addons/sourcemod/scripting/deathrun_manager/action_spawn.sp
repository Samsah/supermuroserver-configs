public Action:DR_Action_Spawn(Handle:event, String:name[], bool:dontBroadcast)
{
	if (GetConVarBool(dr_active)) {
		
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		
		if (GetClientFrags(client) < 0) {
			SetEntProp(client, Prop_Data, "m_iFrags", 0);
		}
		if (GetConVarBool(dr_nighvision) && !IsFakeClient(client)) {
			GivePlayerItem(client, "item_nvgs", 0);
		}
	
		if (GetConVarBool(dr_bonuses)) {
			if (GetClientFrags(client) > 0 && GetClientTeam(client) == CS_TEAM_CT) {
				CheckBonus(client);
				new frags = GetClientFrags(client);
				if (GameEngine == 1)
					CPrintToChat(client, "{green}%t {default}%t {lightgreen}%i {default}%t!", "LANG_DR_INFO", "LANG_DR_BONUSES", frags, "LANG_DR_FRAG");
				if (GameEngine == 2)
					CPrintToChat(client, "{default} {green}%t {default}%t {lightgreen}%i {default}%t!", "LANG_DR_INFO", "LANG_DR_BONUSES", frags, "LANG_DR_FRAG");
				if (strcmp(model[frags], "0", false)) {
					if (GameEngine == 1)
						CPrintToChat(client, "{green}%t {default}%t {lightgreen}%i{default}, {default}%t {lightgreen}%f%%{default}, {default}%t {lightgreen}%f%%{default}!", "LANG_DR_INFO", "LANG_DR_HEALTH", health[frags], "LANG_DR_SPEED", speed[frags], "LANG_DR_GRAVITY", gravity[frags]);
					if (GameEngine == 2)
						CPrintToChat(client, "{default} {green}%t {default}%t {green}%i{default}, {default}%t {green}%f%%{default}, {default}%t {green}%f%%{default}!", "LANG_DR_INFO", "LANG_DR_HEALTH", health[frags], "LANG_DR_SPEED", speed[frags], "LANG_DR_GRAVITY", gravity[frags]);
				} else {
					if (GameEngine == 1)
						CPrintToChat(client, "{green}%t {default}%t {lightgreen}%i{default}, {default}%t {lightgreen}%f%%{default}, {default}%t {lightgreen}%f%%{default}, {default}%t {lightgreen}%i{default}!", "LANG_DR_INFO", "LANG_DR_HEALTH", health[frags], "LANG_DR_SPEED", speed[frags], "LANG_DR_GRAVITY", gravity[frags], "LANG_DR_MODEL", modelname[frags]);
					if (GameEngine == 2)
						CPrintToChat(client, "{default} {green}%t {default}%t {green}%i{default}, {default}%t {green}%f%%{default}, {default}%t {green}%f%%{default}, {default}%t {green}%i{default}!", "LANG_DR_INFO", "LANG_DR_HEALTH", health[frags], "LANG_DR_SPEED", speed[frags], "LANG_DR_GRAVITY", gravity[frags], "LANG_DR_MODEL", modelname[frags]);

				}
			} else {
				SetEntityGravity(client, 1.00);
			}
		}
		
		if (GetConVarBool(dr_antisuicide)) {
			if (GetClientTeam(client) == 2) {
				SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}
		
		if (GetConVarBool(dr_scouts))
		{
			if (GetClientTeam(client) == CS_TEAM_CT)
			{
				if (GameEngine == 1) {
					CPrintToChat(client, "{green}%t {default}%t {lightgreen}!scout", "LANG_DR_INFO", "LANG_DR_SCOUT");
					CPrintToChat(client, "{green}%t {default}%t {lightgreen}%i", "LANG_DR_INFO", "LANG_DR_NUMBERSCOUT", SpawnedScout);
				}
				if (GameEngine == 2) {
					CPrintToChat(client, "{default} {green}%t {default}%t {lightgreen}!scout", "LANG_DR_INFO", "LANG_DR_SCOUT");
					CPrintToChat(client, "{default} {green}%t {default}%t {lightgreen}%i", "LANG_DR_INFO", "LANG_DR_NUMBERSCOUT", SpawnedScout);
				}
			} else {
				if (GetClientTeam(client) == CS_TEAM_T) {
					if (GetConVarBool(dr_scoutster)) {
						if (GameEngine == 1) {
							CPrintToChat(client, "{green}%t {default}%t {lightgreen}!scout", "LANG_DR_INFO", "LANG_DR_SCOUT");
							CPrintToChat(client, "{green}%t {default}%t {lightgreen}%i", "LANG_DR_INFO", "LANG_DR_NUMBERSCOUT", SpawnedScout);
						}
						if (GameEngine == 2) {
							CPrintToChat(client, "{default} {green}%t {default}%t {lightgreen}!scout", "LANG_DR_INFO", "LANG_DR_SCOUT");
							CPrintToChat(client, "{default} {green}%t {default}%t {lightgreen}%i", "LANG_DR_INFO", "LANG_DR_NUMBERSCOUT", SpawnedScout);
						}
					}
				}
			}
		}
	}
}