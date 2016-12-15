public void SQLCallback_SetBan(Database db, DBResultSet results, const char[] error, any userid)
{
	if(db == null || strlen(error) > 0)
	{
		if(GetLogLevel() >= view_as<int>(ERROR))
			TB_LogFile(ERROR,  "(SQLCallback_SetBan) Query failed: %s", error);
		return;
	}
	int client = GetClientOfUserId(userid);
	
	if (IsClientValid(client))
	{
		IsAndMoveClient(client, TeamBans_GetClientTeam(client));
		CheckTeamBans(client);
	}
}

public void SQLCallback_SetServerBan(Database db, DBResultSet results, const char[] error, any userid)
{
	if(db == null || strlen(error) > 0)
	{
		if(GetLogLevel() >= view_as<int>(ERROR))
			TB_LogFile(ERROR,  "(SQLCallback_SetBan) Query failed: %s", error);
		return;
	}
	int client = GetClientOfUserId(userid);
	
	if (IsClientValid(client))
		CheckTeamBans(client);
}

public void SQLCallback_DelBan(Database db, DBResultSet results, const char[] error, any userid)
{
	if(db == null || strlen(error) > 0)
	{
		if(GetLogLevel() >= view_as<int>(ERROR))
			TB_LogFile(ERROR,  "(SQLCallback_DelBan) Query failed: %s", error);
		return;
	}
	int client = GetClientOfUserId(userid);
	
	if(IsClientValid(client))
		ResetVars(client, false);
}

public void SQLCallback_BanCheck(Database db, DBResultSet results, const char[] error, any userid)
{
	if(db == null || strlen(error) > 0)
	{
		if(GetLogLevel() >= view_as<int>(ERROR))
			TB_LogFile(ERROR,  "(SQLCallback_BanCheck) Query failed: %s", error);
		return;
	}
}

public void SQLCallback_Create(Database db, DBResultSet results, const char[] error, any userid)
{
	if(db == null || strlen(error) > 0)
	{
		if(GetLogLevel() >= view_as<int>(ERROR))
			TB_LogFile(ERROR,  "(SQLCallback_Create) Query failed: %s", error);
		return;
	}
}

public void SQLCallback_OBan(Database db, DBResultSet results, const char[] error, any userid)
{
	if(db == null || strlen(error) > 0)
	{
		if(GetLogLevel() >= view_as<int>(ERROR))
			TB_LogFile(ERROR,  "(SQLCallback_OBan) Query failed: %s", error);
		return;
	}
}

public void SQLCallback_OUnBan(Database db, DBResultSet results, const char[] error, any userid)
{
	if(db == null || strlen(error) > 0)
	{
		if(GetLogLevel() >= view_as<int>(ERROR))
			TB_LogFile(ERROR,  "(SQLCallback_OUnBan) Query failed: %s", error);
		return;
	}
}

public void SQLCallback_UpdateServerTimeleft(Database db, DBResultSet results, const char[] error, any userid)
{
	if(db == null || strlen(error) > 0)
	{
		if(GetLogLevel() >= view_as<int>(ERROR))
			TB_LogFile(ERROR,  "(SQLCallback_UpdateServerTimeleft) Query failed: %s", error);
		return;
	}
}

