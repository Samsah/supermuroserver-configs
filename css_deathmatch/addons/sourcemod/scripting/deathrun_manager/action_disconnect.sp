public Action:DR_Action_Disconnect(Handle:event, const String:name[], bool:dontBroadcast) {
	if (!GetConVarBool(dr_active))
		return Plugin_Continue;
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsClientInGame(client) && GetConVarBool(dr_autoban) && client) {
		if (GetClientTeam(client) == CS_TEAM_T) {
			LeaveTer--;
			if (GetTeamClientCount(CS_TEAM_CT) > 3) {
				decl String:reason[128], String:steamid[64], String:cname[32];
				GetEventString(event, "reason", reason, sizeof(reason));
				if (StrEqual(reason, "Disconnect by user.", false)) {
					GetEventString(event, "networkid", steamid, sizeof(steamid));
					if(!GetClientName(client, cname, sizeof(cname)))
						Format(cname, sizeof(cname), "Unconnected");
					
					if (g_bSBAvailable)
						SBBanPlayer(0, client, GetConVarInt(dr_bantime), "Deathrun: Disconnected by terrorist");
					else
						BanClient(client, GetConVarInt(dr_bantime), BANFLAG_AUTHID, "DEATHRUN: Terrorist can't disconnect", "DEATHRUN: Terrorist can't disconnect");
				}
			}
		}
	}
	if (GetConVarBool(dr_norestart) && LeaveTer <= 0) {
		botSwitch();
		CS_TerminateRound(2.0, CSRoundEndReason:0);
	}
	return Plugin_Continue;
}  