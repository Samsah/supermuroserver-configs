public Action:DR_Say_Commands(client, args)
{
	if (!GetConVarBool(dr_active) && IsFakeClient(client))
		return Plugin_Continue;
	
	if (!IsClientInGame(client))
		return Plugin_Continue;
	
	new String:text[192];
	GetCmdArgString(text, 192);
	new startidx;
	if (text[0] == '"') {
		startidx++;
		new len = strlen(text);
		if (text[len + -1] == '"') {
			text[len + -1] = 0;
		}
	}

	if (text[startidx] == '!' || text[startidx] == '/')  {
		startidx++;
	}

	if (StrEqual(text[startidx], "scout", true))
	{
		ClientGiveScout(client);
		return Plugin_Handled;
	}
	if (StrEqual(text[startidx], "resetscore", true) || StrEqual(text[startidx], "rs", true))
	{
		resetscore(client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}