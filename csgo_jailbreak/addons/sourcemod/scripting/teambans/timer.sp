public Action Timer_CheckClients(Handle timer, any userid)
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientValid(i) && g_iPlayer[i][clientReady])
			IsAndMoveClient(i, TeamBans_GetClientTeam(i));
}

public Action Timer_BanCheck(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (IsClientValid(client) && GetClientTeam(client) == TEAMBANS_T)
	{
		if (g_iPlayer[client][banTimeleft] == 1)
		{
			DelTeamBan(0, client);
			g_iPlayer[client][banCheck] = null;
			return Plugin_Stop;
		}
		else if (g_iPlayer[client][banTimeleft] > 1)
		{
			g_iPlayer[client][banTimeleft]--;
			
			char sCommunityID[64];
		 	if(!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
		 		return Plugin_Continue;
		 	
			char sQuery[1024];
			Format(sQuery, sizeof(sQuery), QUERY_UPDATE_BAN, g_iPlayer[client][banTimeleft], sCommunityID, g_iPlayer[client][banID]);
			
			if(IsDebug() && GetLogLevel() >= view_as<int>(DEBUG))
				TB_LogFile(DEBUG, "[TeamBans] (Timer_BanCheck) %s", sQuery);
			
			g_dDB.Query(SQLCallback_BanCheck, sQuery, _, DBPrio_High);

			return Plugin_Continue;
		}
	}
	g_iPlayer[client][banCheck] = null;
	return Plugin_Stop;
}

public Action Timer_SQLConnect(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if (IsClientValid(client))
		IsAndMoveClient(client, TeamBans_GetClientTeam(client));
}
