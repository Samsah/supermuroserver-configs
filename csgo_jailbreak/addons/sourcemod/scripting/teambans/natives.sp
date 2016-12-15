void CreateNatives()
{
	CreateNative("TeamBans_IsClientBanned", Native_IsClientBanned);
	
	CreateNative("TeamBans_GetClientTeam", Native_GetClientTeam);
	CreateNative("TeamBans_GetClientLength", Native_GetClientLength);
	CreateNative("TeamBans_GetClientTimeleft", Native_GetClientTimeleft);
	CreateNative("TeamBans_GetClientReason", Native_GetClientReason);
	
	CreateNative("TeamBans_SetClientBan", Native_SetClientBan);
	// CreateNative("TeamBans_DelClientBan", Native_DelClientBan); // TODO
	
	CreateNative("TeamBans_GetTeamNameByNumber", Native_GetTeamName);
	CreateNative("TeamBans_GetTeamNumberByName", Native_GetTeamNumber);
}

void CreateForwards()
{
	g_iForwards[hOnPreBan] = CreateGlobalForward("TeamBans_OnClientBan_Pre", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
	g_iForwards[hOnPostBan] = CreateGlobalForward("TeamBans_OnClientBan_Post", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
	g_iForwards[hOnPreOBan] = CreateGlobalForward("TeamBans_OnClientOfflineBan_Pre", ET_Hook, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell, Param_String);
	g_iForwards[hOnPostOBan] = CreateGlobalForward("TeamBans_OnClientOfflineBan_Post", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell, Param_String);
	g_iForwards[hOnPreUnBan] = CreateGlobalForward("TeamBans_OnClientUnban_Pre", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
	g_iForwards[hOnPostUnBan] = CreateGlobalForward("TeamBans_OnClientUnban_Post", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
	g_iForwards[hOnPreOUnBan] = CreateGlobalForward("TeamBans_OnClientOfflineUnban_Pre", ET_Hook, Param_Cell, Param_String, Param_Cell, Param_String);
	g_iForwards[hOnPostOUnBan] = CreateGlobalForward("TeamBans_OnClientOfflineUnban_Post", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_String);
}

public int Native_IsClientBanned(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	return g_iPlayer[client][clientBanned];
}

public int Native_GetClientTeam(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if(IsClientValid(client))
	{
		if(g_iPlayer[client][clientBanned])
			return g_iPlayer[client][banTeam];
	}
	else
		ThrowNativeError(SP_ERROR_NATIVE, "Client (%d) is invalid!", client);
	
	return 0;
}

public int Native_GetClientLength(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if(IsClientValid(client))
	{
		if(g_iPlayer[client][clientBanned])
			return g_iPlayer[client][banLength];
	}
	else
		ThrowNativeError(SP_ERROR_NATIVE, "Client (%d) is invalid!", client);
	
	return 0;
}

public int Native_GetClientTimeleft(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if(IsClientValid(client))
	{
		if(g_iPlayer[client][clientBanned])
			return g_iPlayer[client][banTimeleft];
	}
	else
		ThrowNativeError(SP_ERROR_NATIVE, "Client (%d) is invalid!", client);
	
	return 0;
}

public int Native_GetClientReason(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if(IsClientValid(client))
	{
		if(g_iPlayer[client][clientBanned])
		{
			int length = GetNativeCell(3);
			
			char sBuffer[TEAMBANS_REASON_LENGTH];
			
			strcopy(sBuffer, length, g_iPlayer[client][banReason]);
			
			SetNativeString(2, sBuffer, length);
		}
	}
	else
		ThrowNativeError(SP_ERROR_NATIVE, "Client (%d) is invalid!", client);
	
	return 0;
}

public int Native_SetClientBan(Handle plugin, int numParams)
{
	char reason[TEAMBANS_REASON_LENGTH];
	
	int admin = GetNativeCell(1);
	int client = GetNativeCell(2);
	int team = GetNativeCell(3);
	int length = GetNativeCell(4);
	int timeleft = GetNativeCell(5);
	GetNativeString(6, reason, TEAMBANS_REASON_LENGTH);
	
	if(team == TEAMBANS_CT && g_iCvar[enableCTBan].BoolValue)
		ThrowNativeError(SP_ERROR_NATIVE, "CT-Ban disabled!", client);
	
	if(team == TEAMBANS_T && !g_iCvar[enableTBan].BoolValue)
		ThrowNativeError(SP_ERROR_NATIVE, "T-Ban disabled!", client);
	
	if(team == TEAMBANS_SERVER && !g_iCvar[enableServerBan].BoolValue)
		ThrowNativeError(SP_ERROR_NATIVE, "Server-Ban disabled!", client);
	
	if(IsClientValid(client))
	{
		char sCommunityID[64], sACommunityID[64];
 		if(!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
 			ThrowNativeError(SP_ERROR_NATIVE, "Client (%d) is invalid!", client);
 		
 		if(admin > 0)
 		{
 			if(!GetClientAuthId(admin, AuthId_SteamID64, sACommunityID, sizeof(sACommunityID)))
 				Format(sACommunityID, sizeof(sACommunityID), "0");
 		}
 		else
 			Format(sACommunityID, sizeof(sACommunityID), "0");
 		
		if(GetLogLevel() >= view_as<int>(INFO))
			TB_LogFile(INFO, "[TeamBans] (Native_SetClientBan) Admin: \"%L\" %s - Player: \"%L\" %s - Length: %d - Reason: %s", admin, sACommunityID, client, sCommunityID, length, reason);
		
		if (g_iPlayer[client][clientBanned] && g_iPlayer[client][banTeam] > TEAMBANS_SERVER && g_iPlayer[client][banTeam] == team)
		{
			char sTeam[TEAMBANS_TEAMNAME_SIZE], sTranslation[64], sBuffer[256];
			
			TeamBans_GetTeamNameByNumber(team, sTeam, sizeof(sTeam), LANG_SERVER);
			
			Format(sTranslation, sizeof(sTranslation), "IsAlready%sBanned", sTeam);
			Format(sBuffer, sizeof(sBuffer), "%T", sTranslation, admin);
			C_RemoveTags(sBuffer, sizeof(sBuffer));
			ThrowNativeError(SP_ERROR_NATIVE, sBuffer);
			
		}
		else
			SetTeamBan(admin, admin, team, length, timeleft, reason);
	}
	else
		ThrowNativeError(SP_ERROR_NATIVE, "Client (%d) is invalid!", client);
}

public int Native_GetTeamName(Handle plugin, int numParams)
{
	int team = GetNativeCell(1);
	int client = GetNativeCell(4);
	
	if(team >= TEAMBANS_SERVER && team <= TEAMBANS_CT)
	{
		int length = GetNativeCell(3);
		char[] sBuffer = new char[length];
		
		if(IsClientValid(client) && client != LANG_SERVER)
		{
			if(team == TEAMBANS_CT)
				Format(sBuffer, length, "%T", g_sTeams[TEAMBANS_CT], client);
			else if(team == TEAMBANS_T)
				Format(sBuffer, length, "%T", g_sTeams[TEAMBANS_T], client);
			else if (team == TEAMBANS_SERVER)
				Format(sBuffer, length, "%T", g_sTeams[TEAMBANS_SERVER], client);
		}
		else
		{
			if(team == TEAMBANS_CT)
				Format(sBuffer, length, "%T", g_sTeams[TEAMBANS_CT], LANG_SERVER);
			else if(team == TEAMBANS_T)
				Format(sBuffer, length, "%T", g_sTeams[TEAMBANS_T], LANG_SERVER);
			else if (team == TEAMBANS_SERVER)
				Format(sBuffer, length, "%T", g_sTeams[TEAMBANS_SERVER], LANG_SERVER);
		}
		
		SetNativeString(2, sBuffer, length);
	}
	else
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid team!");
	
	return 0;
}

public int Native_GetTeamNumber(Handle plugin, int numParams)
{
	char sTeam[TEAMBANS_TEAMNAME_SIZE];
	GetNativeString(1, sTeam, sizeof(sTeam));
	
	if(StrEqual(sTeam, g_sTeams[TEAMBANS_SERVER], false))
		return TEAMBANS_SERVER;
	else if(StrEqual(sTeam, g_sTeams[TEAMBANS_CT], false))
		return TEAMBANS_CT;
	else if(StrEqual(sTeam, g_sTeams[TEAMBANS_T], false))
		return TEAMBANS_T;
	return 0;
}
