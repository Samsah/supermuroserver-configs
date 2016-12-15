public Action Command_JoinTeam(int client, const char[] command, int args)
{
	if (!IsClientValid(client) || !g_iPlayer[client][clientReady])
		return Plugin_Continue;

	char sTeam[3];
	GetCmdArg(1, sTeam, sizeof(sTeam));
	int iTeam = StringToInt(sTeam);
	
	if(IsAndMoveClient(client, TeamBans_GetClientTeam(client), iTeam))
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action Command_TeamBans(int client, int args)
{
	if (IsClientValid(client))
	{
		Menu menu = CreateMenu(Menu_Block);
		char sTitle[256];
		Format(sTitle, sizeof(sTitle), "%T", "TeamBansList", client);
		menu.SetTitle(sTitle);

		int count = 0;

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientValid(i))
			{
				if (HasClientTeamBan(i))
				{
					char sUserID[128];
					IntToString(GetClientUserId(i), sUserID, sizeof(sUserID));

					char sName[MAX_NAME_LENGTH], sTeam[TEAMBANS_TEAMNAME_SIZE];
					
					TeamBans_GetTeamNameByNumber(TeamBans_GetClientTeam(i), sTeam, sizeof(sTeam), client);
					
					if(g_iPlayer[i][banLength] > 0)
						Format(sName, sizeof(sName), "%T", "TeamBansListPlayer", client, sTeam, i, g_iPlayer[i][banTimeleft], g_iPlayer[i][banLength]);
					else if(g_iPlayer[i][banLength] == 0)
						Format(sName, sizeof(sName), "%T", "TeamBansListPlayerPerma", client, sTeam, i);
					
					menu.AddItem(sUserID, sName);

					count++;
				}
			}
		}

		if(count == 0)
		{
			char sBuffer[64];
			Format(sBuffer, sizeof(sBuffer), "%T", "NoPlayers", client);
			menu.AddItem("", sBuffer, ITEMDRAW_DISABLED);
		}

		menu.ExitButton = true;
		menu.Display(client, 30);
	}
}

public int Menu_Block(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select)
	{
		char sUserID[64];
		menu.GetItem(param, sUserID, sizeof(sUserID));
		int userid = StringToInt(sUserID);
		int target = GetClientOfUserId(userid);

		if (IsClientValid(target))
		{
			char sTeam[TEAMBANS_TEAMNAME_SIZE];
			
			TeamBans_GetTeamNameByNumber(TeamBans_GetClientTeam(target), sTeam, sizeof(sTeam), client);

			if(g_iPlayer[target][banLength] > 0)
				CPrintToChat(client, "%T", "TeamBansInfo", client, g_sTag, target, g_iPlayer[target][banLength], g_iPlayer[target][banTimeleft], g_iPlayer[target][banReason], sTeam);
			else if(g_iPlayer[target][banLength] == 0)
				CPrintToChat(client, "%T", "TeamBansInfoPerma", client, g_sTag, target, g_iPlayer[target][banReason], sTeam);
		}

		Command_TeamBans(client, 0);
		delete menu;
	}
}

public Action Command_Ban(int client, int args)
{
	if(!g_iCvar[enableCTBan].BoolValue)
	{
		CReplyToCommand(client, "%T", "CommandDisabled", client, g_sTag);
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		CReplyToCommand(client, "%T", "BanSyntax", client, g_sTag);
		return Plugin_Handled;
	}
	
	// Get client
	char sArg1[MAX_NAME_LENGTH];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	
	// Get team
	char sTeam[TEAMBANS_TEAMNAME_SIZE];
	GetCmdArg(2, sTeam, sizeof(sTeam));
	int iTeam = TeamBans_GetTeamNumberByName(sTeam);
	
	// Get Length
	char sLength[12];
	GetCmdArg(3, sLength, sizeof(sLength));
	
	int iLength;
	
	if(args == 1)
	{
		char sDLength[12];
		g_iCvar[defaultBanLength].GetString(sDLength, sizeof(sDLength));
		iLength = StringToInt(sDLength);
	}
	else
		iLength = StringToInt(sLength);
	
	if(iLength < 0)
	{
		CReplyToCommand(client, "%T", "BanSyntax", client, g_sTag);
		return Plugin_Handled;
	}
	
	// Get Reason
	char sReason[128], sBuffer[128];
	if(args <= 3)
	{
		char sTBuffer[32];
		g_iCvar[defaultBanReason].GetString(sTBuffer, sizeof(sTBuffer));
		Format(sReason, sizeof(sReason), "%T", sTBuffer, LANG_SERVER);
	}
	else 
	{
		for (int i = 4; i <= args; i++)
		{
			GetCmdArg(i, sBuffer, sizeof(sBuffer));
			Format(sReason, sizeof(sReason), "%s %s", sReason , sBuffer);
		}
	}
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(sArg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		int target = target_list[i];
		
		if (!IsClientValid(target))
		{
			CReplyToCommand(client, "%T", "Invalid", client);
			return Plugin_Handled;
		}
		
		char sCommunityID[64], sACommunityID[64];
 		if(!GetClientAuthId(target, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
 			return Plugin_Handled;
 		
 		if(client > 0)
 		{
 			if(!GetClientAuthId(client, AuthId_SteamID64, sACommunityID, sizeof(sACommunityID)))
 				Format(sACommunityID, sizeof(sACommunityID), "0");
 		}
 		else
 			Format(sACommunityID, sizeof(sACommunityID), "0");
 		
 		if(GetLogLevel() >= view_as<int>(INFO))
			TB_LogFile(INFO, "[TeamBans] (Command_SetCTBan) Admin: \"%L\" %s - Player: \"%L\" %s - Length: %d - Team: %s - Reason: %s", client, sACommunityID, target, sCommunityID, iLength, sTeam, sReason);
		
		// TODO: Add both team support 
		if (iTeam == TEAMBANS_SERVER || (iTeam > TEAMBANS_SERVER && !HasClientTeamBan(target)))
			SetTeamBan(client, target, iTeam, iLength, iLength, sReason);
		else if(HasClientTeamBan(target))
		{
			if(GetClientBanTeam(target) == iTeam)
			{
				CReplyToCommand(client, "%T", "IsAlready%sBanned", sTeam, client, g_sTag);
				return Plugin_Handled;
			}
			
			iTeam = TEAMBANS_SERVER;
			SetTeamBan(client, target, iTeam, iLength, iLength, sReason);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action Command_UnBan(int client, int args)
{
	if (args != 1)
	{
		CReplyToCommand(client, "%T", "UnBanSyntax", client, g_sTag);
		return Plugin_Handled;
	}

	char player[MAX_NAME_LENGTH];
	GetCmdArg(1, player, sizeof(player));
	
	char sTeam[TEAMBANS_TEAMNAME_SIZE];
	GetCmdArg(2, sTeam, sizeof(sTeam));
	int iTeam = TeamBans_GetTeamNumberByName(sTeam);
	
	if(iTeam == TEAMBANS_SERVER)
	{
		CReplyToCommand(client, "%T", "UnbanServerOnline", client, g_sTag);
		return Plugin_Handled;
	}

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(player, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		int target = target_list[i];
		
		char sCommunityID[64], sACommunityID[64];
 		if(!GetClientAuthId(target, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
 			return Plugin_Handled;
 		
 		if(!GetClientAuthId(client, AuthId_SteamID64, sACommunityID, sizeof(sACommunityID)))
 			return Plugin_Handled;
 		
 		if(GetLogLevel() >= view_as<int>(INFO))
			TB_LogFile(INFO, "[TeamBans] (Command_UnBan) Admin: \"%L\" %s - Player: \"%L\" %s - Team: %s", client, sACommunityID, target, sCommunityID, sTeam);

		if (!IsClientValid(target))
		{
			CReplyToCommand(client, "%T", "Invalid", client);
			return Plugin_Handled;
		}

		if (HasClientTeamBan(target) && GetClientBanTeam(client) == iTeam)
			DelTeamBan(client, target);
		else
		{
			char sTranslations[18];
			Format(sTranslations, sizeof(sTranslations), "Isnt%sBanned", g_sTeams[iTeam]);
			CReplyToCommand(client, "%T", sTranslations, client, g_sTag);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action Command_OBan(int client, int args)
{
	if(!g_iCvar[enableTBan].BoolValue)
	{
		CReplyToCommand(client, "%T", "CommandDisabled", client, g_sTag);
		return Plugin_Handled;
	}
	
	if(client == 0 || !IsClientValid(client))
		client = 0;
	
	if (args < 2)
	{
		CReplyToCommand(client, "%T", "OBanSyntax", client, g_sTag);
		return Plugin_Handled;
	}
	
	// Get communityid
	char target[18];
	GetCmdArg(1, target, sizeof(target));
	
	// Get team
	char team[TEAMBANS_TEAMNAME_SIZE];
	GetCmdArg(2, team, sizeof(team));
	
	int iTeam = TeamBans_GetTeamNumberByName(team);
	
	int iLength;
	
	// Get length
	if(args <= 2)
	{
		char sDLength[12];
		g_iCvar[defaultBanLength].GetString(sDLength, sizeof(sDLength));
		iLength = StringToInt(sDLength);
	}
	else
	{
		char length[12];
		GetCmdArg(3, length, sizeof(length));
		iLength = StringToInt(length);
	}
	
	if(iLength < 0 && IsClientInGame(client))
	{
		CReplyToCommand(client, "%T", "OBanSyntax", client, g_sTag);
		return Plugin_Handled;
	}
	
	// Get Reason
	char sReason[128], sBuffer[128];
	if(args <= 3)
	{
		char sTBuffer[32];
		g_iCvar[defaultBanReason].GetString(sTBuffer, sizeof(sTBuffer));
		Format(sReason, sizeof(sReason), "%T", sTBuffer, LANG_SERVER);
	}
	else 
	{
		for (int i = 4; i <= args; i++)
		{
			GetCmdArg(i, sBuffer, sizeof(sBuffer));
			Format(sReason, sizeof(sReason), "%s %s", sReason , sBuffer);
		}
	}
	
	CheckOfflineBans(client, target, iTeam, iLength, sReason);
	return Plugin_Continue;
}

public Action Command_OUnBan(int client, int args)
{
	if(!g_iCvar[enableTBan].BoolValue)
	{
		CReplyToCommand(client, "%T", "CommandDisabled", client, g_sTag);
		return Plugin_Handled;
	}
	
	if(client == 0 || !IsClientValid(client))
		client = 0;
	
	if (args < 2)
	{
		CReplyToCommand(client, "%T", "OUnBanSyntax", client, g_sTag);
		return Plugin_Handled;
	}
	
	// Get communityid
	char target[18];
	GetCmdArg(1, target, sizeof(target));
	
	// Get team
	char team[TEAMBANS_TEAMNAME_SIZE];
	GetCmdArg(2, team, sizeof(team));
	int iTeam = TeamBans_GetTeamNumberByName(team);
	
	// Get Reason
	char sReason[128], sBuffer[128];
	if(args <= 2)
	{
		char sTBuffer[32];
		g_iCvar[defaultBanReason].GetString(sTBuffer, sizeof(sTBuffer));
		Format(sReason, sizeof(sReason), "%T", sTBuffer, LANG_SERVER);
	}
	else 
	{
		for (int i = 3; i <= args; i++)
		{
			GetCmdArg(i, sBuffer, sizeof(sBuffer));
			Format(sReason, sizeof(sReason), "%s %s", sReason , sBuffer);
		}
	}
	
	CheckOfflineUnBan(client, target, iTeam, sReason);
	return Plugin_Continue;
}
