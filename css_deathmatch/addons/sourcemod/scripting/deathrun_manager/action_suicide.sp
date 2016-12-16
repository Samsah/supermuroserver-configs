public Action:OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (GetClientTeam(client) == 2)
	{
		if (damagetype & 32)
		{
			if (!dr_AntiSpam[client]) {
				if (GameEngine == 1)
					CPrintToChat(client, "{green}%t {default}%t", "LANG_DR_INFO", "LANG_DR_SUICIDE");
				if (GameEngine == 2)
					CPrintToChat(client, "{default} {green}%t {default}%t", "LANG_DR_INFO", "LANG_DR_SUICIDE");
				dr_AntiSpam[client] = true;
				CreateTimer(GetConVarFloat(dr_SpamTime), TimerAntiSpam, client);
			}
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action:DR_Player_Spectate(client, args)
{
	if (GetConVarBool(dr_antisuicide))
	{
		if (IsPlayerAlive(client))
		{
			if (!dr_AntiSpam[client]) {
				if (GameEngine == 1)
					CPrintToChat(client, "{green}%t {default}%t", "LANG_DR_INFO", "LANG_DR_SUICIDE");
				if (GameEngine == 2)
					CPrintToChat(client, "{default} {green}%t {default}%t", "LANG_DR_INFO", "LANG_DR_SUICIDE");
				dr_AntiSpam[client] = true;
				CreateTimer(GetConVarFloat(dr_SpamTime), TimerAntiSpam, client);
			}
			return Plugin_Handled;
		} else {
			if (GetClientTeam(client) == 2) {
				if (!dr_AntiSpam[client]) {
					if (GameEngine == 1)
						CPrintToChat(client, "{green}%t {default}%t", "LANG_DR_INFO", "LANG_DR_SUICIDE2");
					if (GameEngine == 2)
						CPrintToChat(client, "{default} {green}%t {default}%t", "LANG_DR_INFO", "LANG_DR_SUICIDE2");
					dr_AntiSpam[client] = true;
					CreateTimer(GetConVarFloat(dr_SpamTime), TimerAntiSpam, client);
				}
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

public Action:DR_BlockSuicide(client, args)
{
	if (GetConVarBool(dr_antisuicide))
	{
		if (IsPlayerAlive(client))
		{
			if (!dr_AntiSpam[client]) {
				if (GameEngine == 1)
					CPrintToChat(client, "{green}%t {default}%t", "LANG_DR_INFO", "LANG_DR_SUICIDE2");
				if (GameEngine == 2)
					CPrintToChat(client, "{default} {green}%t {default}%t", "LANG_DR_INFO", "LANG_DR_SUICIDE2");
				dr_AntiSpam[client] = true;
				CreateTimer(GetConVarFloat(dr_SpamTime), TimerAntiSpam, client);
			}
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action:DR_Player_JoinTeam(client, args) {
	if (!GetConVarBool(dr_antisuicide))
		return Plugin_Continue;

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

	if (GetTeamClientCount(CS_TEAM_T) + GetTeamClientCount(CS_TEAM_CT) == 0) {
		return Plugin_Continue;
	} else {
		if (GetTeamClientCount(CS_TEAM_T) == 0 && GetTeamClientCount(CS_TEAM_CT) >= 1) {
			ChangeClientTeam(client, CS_TEAM_T);
			return Plugin_Handled;
		}
		if (GetTeamClientCount(CS_TEAM_CT) == 0 && GetTeamClientCount(CS_TEAM_T) >= 1) {
			ChangeClientTeam(client, CS_TEAM_CT);
			return Plugin_Handled;
		}
		if (team_old != CS_TEAM_T && team_num != 0 && team_num != 2) {
			if (!IsPlayerAlive(client)) {
				return Plugin_Continue;
			} else {
				CPrintToChat(client, "{green}%t {default}%t", "LANG_DR_INFO", "LANG_DR_SUICIDE2");
				return Plugin_Handled;
			}
		}
		if (team_old == CS_TEAM_T) {
			if (!dr_AntiSpam[client]) {
				if (GameEngine == 1)
					CPrintToChat(client, "{green}%t {default}%t", "LANG_DR_INFO", "LANG_DR_SUICIDE");
				if (GameEngine == 2)
					CPrintToChat(client, "{default} {green}%t {default}%t", "LANG_DR_INFO", "LANG_DR_SUICIDE");
				dr_AntiSpam[client] = true;
				CreateTimer(GetConVarFloat(dr_SpamTime), TimerAntiSpam, client);
		}
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}