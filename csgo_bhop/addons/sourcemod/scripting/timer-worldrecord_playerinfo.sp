#include <sourcemod>
#include <timer>
#include <timer-mysql>
#include <timer-stocks>
#include <timer-config_loader>

new Handle:g_hSQL = INVALID_HANDLE;

enum eTarget
{
	bool:eTarget_Active = false,
    String:eTarget_Name[256],
    String:eTarget_SteamID[32],
	eTarget_Style,
	Handle:eTarget_MainMenu,
	Handle:eTarget_MapMenu
}

new String:g_MapName[32];
new g_PointRowCount[MAXPLAYERS+1];
new g_TargetData[MAXPLAYERS+1][eTarget];

new g_iMapCount[2];
new g_iMapCountComplete[MAXPLAYERS+1];
new Handle:g_hMaps[2] = {INVALID_HANDLE, ...};

new g_MenuPos[MAXPLAYERS+1];

new String:sql_QueryPlayerName[] = "SELECT name, auth FROM round WHERE name LIKE \"%%%s%%\" ORDER BY `round`.`name` ASC, `round`.`auth` ASC;";
new String:sql_selectSingleRecord[] = "SELECT auth, name, jumps, time, date, rank, finishcount, avgspeed, maxspeed, finishspeed FROM round WHERE auth LIKE '%s' AND map = '%s' AND track = '0' AND `style` = '%d';";
new String:sql_selectPlayer_Points[] = "SELECT auth, lastname, points FROM ranks WHERE auth LIKE '%s' AND points NOT LIKE '0';";
new String:sql_selectPlayerPRowCount[] = "SELECT lastname FROM ranks WHERE points >= (SELECT points FROM ranks WHERE auth = '%s' AND points NOT LIKE '0') AND points NOT LIKE '0' ORDER BY points;";

new String:sql_selectPlayerMaps[] = "SELECT time, map, auth FROM round WHERE auth LIKE '%s' AND track = '0' AND `style` = '%d' ORDER BY map ASC;";
new String:sql_selectPlayerMapsBonus[] = "SELECT time, map, auth FROM round WHERE auth LIKE '%s' AND track = '1' AND `style` = '%d' ORDER BY map ASC;";

new String:sql_selectMaps[] = "SELECT map FROM mapzone WHERE type = 0 GROUP BY map ORDER BY map;";
new String:sql_selectMapsBonus[] = "SELECT map FROM mapzone WHERE type = 7 GROUP BY map ORDER BY map;";

new String:sql_selectPlayerWRs[] = "SELECT * FROM (SELECT * FROM (SELECT `time`,`map`,`auth` FROM `round` WHERE `track` = '0' AND `style` = '%d' GROUP BY `round`.`map`, `round`.`time`) AS temp GROUP BY LOWER(`map`)) AS temp2 WHERE `auth` = '%s';";
new String:sql_selectPlayerWRsBonus[] = "SELECT * FROM (SELECT * FROM (SELECT `time`,`map`,`auth` FROM `round` WHERE `track` = '1' AND `style` = '%d' GROUP BY `round`.`map`, `round`.`time`) AS temp GROUP BY LOWER(`map`)) AS temp2 WHERE `auth` = '%s';";
new String:sql_selectPlayerMapRecord[] = "SELECT auth, name, jumps, time, date, rank, finishcount, avgspeed, maxspeed, finishspeed FROM round WHERE auth LIKE '%s' AND map = '%s' AND track = '%i' AND `style` = '%d';";

public Plugin:myinfo = 
{
	name = "[TIMER] Worldrecord - PlayerInfo",
	author = "Zipcore, Credits: Das D, DR. API Improvements",
	description = "[Timer] Shows advanced stats for a player.",
	version = PL_VERSION,
	url = "forums.alliedmods.net/showthread.php?p=2074699"
};

public OnPluginStart()
{
	RegConsoleCmd("sm_playerinfo", Client_PlayerInfo, "playerinfo");
	
	LoadPhysics();
	LoadTimerSettings();
	
	if (g_hSQL == INVALID_HANDLE)
	{
		ConnectSQL();
	}
}

public OnMapStart()
{
	LoadPhysics();
	LoadTimerSettings();
	
	GetCurrentMap(g_MapName, 32);
	
	if (g_hSQL == INVALID_HANDLE)
	{
		ConnectSQL();
	}
	else
	{
		countmaps();
		countbonusmaps();
	}
}

public OnTimerSqlConnected(Handle:sql)
{
	g_hSQL = sql;
	g_hSQL = INVALID_HANDLE;
	CreateTimer(0.1, Timer_SQLReconnect, _ , TIMER_FLAG_NO_MAPCHANGE);
}

public OnTimerSqlStop()
{
	g_hSQL = INVALID_HANDLE;
	CreateTimer(0.1, Timer_SQLReconnect, _ , TIMER_FLAG_NO_MAPCHANGE);
}

ConnectSQL()
{
	g_hSQL = Handle:Timer_SqlGetConnection();
	
	if (g_hSQL == INVALID_HANDLE)
		CreateTimer(0.1, Timer_SQLReconnect, _ , TIMER_FLAG_NO_MAPCHANGE);
	else 
	{
		countmaps();
		countbonusmaps();
	}
}

public Action:Timer_SQLReconnect(Handle:timer, any:data)
{
	ConnectSQL();
	return Plugin_Stop;
}

public countmaps()
{
	decl String:Query[255];
	Format(Query, 255, sql_selectMaps);
	SQL_TQuery(g_hSQL, SQL_CountMapCallback, Query, false);
}

public countbonusmaps()
{
	decl String:Query[255];
	Format(Query, 255, sql_selectMapsBonus);
	SQL_TQuery(g_hSQL, SQL_CountMapCallback, Query, true);
}

public SQL_CountMapCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		return;
	}
	
	if(SQL_GetRowCount(hndl))
	{
		new track = data;
		g_iMapCount[track] = 0;
		
		new String:sMap[128];
		new Handle:Kv = CreateKeyValues("data");
		
		while(SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, sMap, sizeof(sMap));
			
			KvJumpToKey(Kv, sMap, true);
			KvRewind(Kv);
			
			g_iMapCount[track]++;
		}
		
		g_hMaps[track] = CloneHandle(Kv);
	}
}

public Action:Client_PlayerInfo(client, args)
{
	if(args < 1)
	{
		#if SOURCEMOD_V_MAJOR >= 1 && SOURCEMOD_V_MINOR >= 7
			GetClientAuthId(client, AuthId_Steam2,g_TargetData[client][eTarget_SteamID], 32);
		#else
			GetClientAuthString(client, g_TargetData[client][eTarget_SteamID], 32);
		#endif
		GetClientName(client, g_TargetData[client][eTarget_Name], 256);
		
		g_TargetData[client][eTarget_Style] = g_StyleDefault;
		
		g_TargetData[client][eTarget_Active] = true;
		
		if(g_Settings[MultimodeEnable]) StylePanel(client);
		else Menu_PlayerInfo(client);
	}
	else if(args >= 1)
	{
		ClearClient(client);
		
		decl String:NameBuffer[256];
		GetCmdArgString(NameBuffer, sizeof(NameBuffer));
		new startidx = 0;
		new len = strlen(NameBuffer);
		
		if ((NameBuffer[0] == '"') && (NameBuffer[len-1] == '"'))
		{
			startidx = 1;
			NameBuffer[len-1] = '\0';
		}
		
		Format(g_TargetData[client][eTarget_Name], 256, "%s", NameBuffer[startidx]);
		
		g_TargetData[client][eTarget_Active] = false;
		
		if(g_Settings[MultimodeEnable])
		{
			StylePanel(client);
		}
		else
		{
			g_TargetData[client][eTarget_Style] = g_StyleDefault;
			QueryPlayerName(client, g_TargetData[client][eTarget_Name]);
		}
	}
	return Plugin_Handled;
}

StylePanel(client)
{
	if(0 < client < MaxClients)
	{
		new Handle:menu = CreateMenu(MenuHandler_StylePanel);

		SetMenuTitle(menu, "Select Style", client);
		
		SetMenuExitButton(menu, true);

		for(new i = 0; i < MAX_STYLES-1; i++) 
		{
			if(!g_Physics[i][StyleEnable])
				continue;
			if(g_Physics[i][StyleCategory] != MCategory_Ranked)
				continue;
			
			new String:buffer[8];
			IntToString(i, buffer, sizeof(buffer));
				
			AddMenuItem(menu, buffer, g_Physics[i][StyleName]);
		}
		
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
}

public MenuHandler_StylePanel(Handle:menu, MenuAction:action, client, itemNum)
{
	if (action == MenuAction_Select) 
	{
		decl String:info[8];		
		GetMenuItem(menu, itemNum, info, sizeof(info));
		
		g_TargetData[client][eTarget_Style] = StringToInt(info);
		
		if(g_TargetData[client][eTarget_Active])
		{
			Menu_PlayerInfo(client);
		}
		else QueryPlayerName(client, g_TargetData[client][eTarget_Name]);
	}
}

public QueryPlayerName(client, String:QueryPlayerName[])
{
	decl String:Query[255];
	decl String:szName[MAX_NAME_LENGTH*2+1];
	SQL_QuoteString(g_hSQL, QueryPlayerName, szName, MAX_NAME_LENGTH*2+1);
	
	Format(Query, 255, sql_QueryPlayerName, szName);
	
	SQL_TQuery(g_hSQL, SQL_QueryPlayerNameCallback, Query, client);
}

new Handle:g_hPlayerSearch[MAXPLAYERS+1] = {INVALID_HANDLE, ...};

public SQL_QueryPlayerNameCallback(Handle:owner, Handle:hndl, const String:error[], any:data){
	if(hndl == INVALID_HANDLE)
		LogError("Error loading playername (%s)", error);
		
	new client = data;
	decl String:PlayerName[256];
	decl String:SteamID[32];
	decl String:PlayerSteam[256];
	decl String:PlayerChkDup[256];
	PlayerChkDup = "zero";
	
	new Handle:menu = CreateMenu(Menu_PlayerSearch);
	SetMenuTitle(menu, "Playersearch\n ");
	
	g_hPlayerSearch[client] = CreateKeyValues("data");
	
	if(SQL_HasResultSet(hndl))
	{
		
		new i = 0;
		while (SQL_FetchRow(hndl))
		{
			if (i <= 99)
			{
				SQL_FetchString(hndl, 0, PlayerName, 256);
				SQL_FetchString(hndl, 1, SteamID, 256);
				Format(PlayerSteam, 256, "%s - %s",PlayerName, SteamID);
				if(!StrEqual(PlayerChkDup, SteamID, false))
				{
					KvJumpToKey(g_hPlayerSearch[client], SteamID, true);
					
					KvSetString(g_hPlayerSearch[client], "name", PlayerName);
					
					KvRewind(g_hPlayerSearch[client]);
					
					AddMenuItem(menu, SteamID, PlayerSteam);
					
					Format(PlayerChkDup, 256, "%s",SteamID);
					i++;
				}
				else
				{
					Format(PlayerChkDup, 256, "%s",SteamID);
				}
			}
		}
		if((i == 0))
		{
			AddMenuItem(menu, "nope", "No Player found...", ITEMDRAW_DISABLED);
		}
		if(i > 99)
		{
			AddMenuItem(menu, "many", "More than 100 Players found.", ITEMDRAW_DISABLED);
			AddMenuItem(menu, "speci", "Please be more specific.", ITEMDRAW_DISABLED);
		}
	}
	else{
		AddMenuItem(menu, "nope", "No Player found...", ITEMDRAW_DISABLED);
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Menu_PlayerInfo(client)
{
	g_TargetData[client][eTarget_Active] = true;
	
	g_TargetData[client][eTarget_MainMenu] = CreateMenu(Menu_PlayerInfo_Handler);
	SetMenuTitle(g_TargetData[client][eTarget_MainMenu], "%s's Overview\n(%s)\n ", g_TargetData[client][eTarget_Name], g_TargetData[client][eTarget_SteamID]);
	
	AddMenuItem(g_TargetData[client][eTarget_MainMenu], "view_rank", "View Record/Rank (current Map)");
	AddMenuItem(g_TargetData[client][eTarget_MainMenu], "view_prank", "View Points/Rank");
	AddMenuItem(g_TargetData[client][eTarget_MainMenu], "view_records", "View all Records");
	AddMenuItem(g_TargetData[client][eTarget_MainMenu], "view_b_records", "View all Records (Bonus)");
	AddMenuItem(g_TargetData[client][eTarget_MainMenu], "view_wr", "View all WRs");
	AddMenuItem(g_TargetData[client][eTarget_MainMenu], "view_bwr", "View all WRs (Bonus)");
	AddMenuItem(g_TargetData[client][eTarget_MainMenu], "view_incomplete", "View Incomplete Maps");
	AddMenuItem(g_TargetData[client][eTarget_MainMenu], "view_b_incomplete", "View Incomplete Maps (Bonus)");
	
	if(g_Settings[MultimodeEnable]) 
	{
		decl String:buffer[512];
		Format(buffer, sizeof(buffer), "Change style [current: %s]", g_Physics[g_TargetData[client][eTarget_Style]][StyleName]);
		AddMenuItem(g_TargetData[client][eTarget_MainMenu], "style", buffer);
	}
	SetMenuExitButton(g_TargetData[client][eTarget_MainMenu], true);
	DisplayMenu(g_TargetData[client][eTarget_MainMenu], client, MENU_TIME_FOREVER);
}

public SQL_ViewSingleRecordCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
		LogError("Error loading single record (%s)", error);
	
	new Handle:pack = data;
	ResetPack(pack);
	
	new client = ReadPackCell(pack);
	decl String:MapName[32];
	ReadPackString(pack, MapName, 32);
	
	CloseHandle(pack);
	pack = INVALID_HANDLE;
	
	new Handle:menu = CreateMenu(Menu_Stock_Handler);
	SetMenuTitle(menu, "Record Info\n ");
	
	if(SQL_HasResultSet(hndl) && SQL_FetchRow(hndl)){
	
		decl String:SteamId[32];
		decl String:PlayerName[MAX_NAME_LENGTH];
		decl String:Date[20];
		new rank;
		new finishcount;
		
		SQL_FetchString(hndl, 0, SteamId, 32);
		SQL_FetchString(hndl, 1, PlayerName, MAX_NAME_LENGTH);
		SQL_FetchString(hndl, 4, Date, 20);
		rank = SQL_FetchInt(hndl, 5);
		finishcount = SQL_FetchInt(hndl, 6);
		new Float:avgspeed = SQL_FetchFloat(hndl, 7);
		new Float:maxspeed = SQL_FetchFloat(hndl, 8);
		new Float:finishspeed = SQL_FetchFloat(hndl, 9);
		
		decl String:LineDate[32];
		Format(LineDate, 32, "Date: %s", Date);
		decl String:LinePLSteam[128];
		Format(LinePLSteam, 128, "Player: %s (%s)", PlayerName, SteamId);
		decl String:LineRank[128];
		Format(LineRank, 128, "Rank: #%i on %s [Count: %i]", rank, MapName, finishcount);
		decl String:LineTime[128];
		decl String:Time[32];		
		Timer_SecondsToTime(SQL_FetchFloat(hndl, 3), Time, 16, 2);
		Format(LineTime, 128, "Time: %s", Time);
		decl String:LineSpeed[128];
		Format(LineSpeed, 128, "Speed [Avg: %.2f | Max: %.2f | Fin: %.2f]", avgspeed, maxspeed, finishspeed);
		
		AddMenuItem(menu, "1", LineDate);
		AddMenuItem(menu, "2", LinePLSteam);
		AddMenuItem(menu, "3", LineRank);
		AddMenuItem(menu, "4", LineTime);
		AddMenuItem(menu, "5", LineSpeed);
		
		SetMenuExitButton(menu, true);
		SetMenuExitBackButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	else{
		AddMenuItem(menu, "nope", "No record found...");
		SetMenuExitButton(menu, true);
		SetMenuExitBackButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
}

public SQL_ViewPlayerMapRecordCallback(Handle:owner, Handle:hndl, const String:error[], any:data){
	if(hndl == INVALID_HANDLE)
		LogError("Error loading single record (%s)", error);
	
	new Handle:pack = data;
	ResetPack(pack);
	
	new client = ReadPackCell(pack);
	decl String:MapName[32];
	ReadPackString(pack, MapName, 32);
	decl String:SteamID[256];
	ReadPackString(pack, SteamID, 256);
	new track = ReadPackCell(pack);
	
	CloseHandle(pack);
	pack = INVALID_HANDLE;
	
	new Handle:menu = CreateMenu(Menu_Stock_Handler2);
	if(!track)
	{
		SetMenuTitle(menu, "Record Info\n ");
	}
	else
	{
		SetMenuTitle(menu, "Bonus Record Info\n ");
	}
	
	if(SQL_HasResultSet(hndl) && SQL_FetchRow(hndl)){
	
		decl String:SteamId[32];
		decl String:PlayerName[MAX_NAME_LENGTH];
		decl String:Date[20];
		new rank;
		new finishcount;
		
		SQL_FetchString(hndl, 0, SteamId, 32);
		SQL_FetchString(hndl, 1, PlayerName, MAX_NAME_LENGTH);
		SQL_FetchString(hndl, 4, Date, 20);
		rank = SQL_FetchInt(hndl, 5);
		finishcount = SQL_FetchInt(hndl, 6);
		new Float:avgspeed = SQL_FetchFloat(hndl, 7);
		new Float:maxspeed = SQL_FetchFloat(hndl, 8);
		new Float:finishspeed = SQL_FetchFloat(hndl, 9);
		
		decl String:LineDate[32];
		Format(LineDate, 32, "Date: %s", Date);
		decl String:LinePLSteam[128];
		Format(LinePLSteam, 128, "Player: %s (%s)", PlayerName, SteamId);
		decl String:LineRank[128];
		Format(LineRank, 128, "Rank: #%i on %s [Count: %i]", rank, MapName, finishcount);
		decl String:LineTime[128];
		decl String:Time[32];		
		Timer_SecondsToTime(SQL_FetchFloat(hndl, 3), Time, 16, 2);
		Format(LineTime, 128, "Time: %s", Time);
		decl String:LineSpeed[128];
		Format(LineSpeed, 128, "Speed [Avg: %.2f | Max: %.2f | Fin: %.2f]", avgspeed, maxspeed, finishspeed);
		
		AddMenuItem(menu, "1", LineDate);
		AddMenuItem(menu, "2", LinePLSteam);
		AddMenuItem(menu, "3", LineRank);
		AddMenuItem(menu, "4", LineTime);
		AddMenuItem(menu, "5", LineSpeed);
		
		SetMenuExitButton(menu, true);
		SetMenuExitBackButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	else{
		AddMenuItem(menu, "nope", "No record found...");
		SetMenuExitButton(menu, true);
		SetMenuExitBackButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
}

public SQL_PRowCountCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
		LogError("Error viewing player point rowcount (%s)", error);
	
	new Handle:pack = data;
	ResetPack(pack);
	
	new client = ReadPackCell(pack);
	
	if(SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		g_PointRowCount[client] = SQL_GetRowCount(hndl);
	}
}

public SQL_PlayerPointsCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
		LogError("Error loading player points (%s)", error);
	
	new Handle:pack = data;
	ResetPack(pack);
	
	new client = ReadPackCell(pack);
	
	CloseHandle(pack);
	pack = INVALID_HANDLE;
	
	new Handle:menu = CreateMenu(Menu_Stock_Handler);
	SetMenuTitle(menu, "Points Info\n ");
	
	if(SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		decl String:SteamId[32];
		decl String:Name[128];
		decl String:Points[64];
		new points;
		
		SQL_FetchString(hndl, 0, SteamId, 32);
		SQL_FetchString(hndl, 1, Name, 128);
		SQL_FetchString(hndl, 2, Points, 64);
		points = SQL_FetchInt(hndl, 2);
		
		decl String:LineName[128];
		decl String:LinePoints[64];
		decl String:LinePointRank[64];
		Format(LineName, 128, "Player: %s (%s)", Name, SteamId);
		Format(LinePoints, 64, "Points: %i", points);
		Format(LinePointRank, 64, "Rank: #%i", g_PointRowCount[client]);
		
		AddMenuItem(menu, "1", LineName);
		AddMenuItem(menu, "2", LinePoints);
		AddMenuItem(menu, "3", LinePointRank);
		SetMenuExitButton(menu, true);
		SetMenuExitBackButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
}

public SQL_ViewPlayerMapsCallback(Handle:owner, Handle:hndl, const String:error[], any:data){
	if(hndl == INVALID_HANDLE)
		LogError("[Timer] Error loading playerinfo (%s)", error);
	
	new Handle:pack = data;
	ResetPack(pack);
	
	new client = ReadPackCell(pack);
	new track = ReadPackCell(pack);
	
	CloseHandle(pack);
	pack = INVALID_HANDLE;

	decl String:szValue[64];
	decl String:szMapName[32];
	decl String:szVrTime[16];
	decl String:SteamID[256];
	decl String:buffer[512];
	
	// Begin Menu
	g_TargetData[client][eTarget_MapMenu] = CreateMenu(MapMenu_Stock_Handler);
	
	new mapscomplete = 0;
	if(SQL_HasResultSet(hndl))
	{
		mapscomplete = SQL_GetRowCount(hndl);
	}
	/// Calc Percent
	new Float: mapcom_fl = float(mapscomplete);
	new Float: mapcou_fl;
	if(!track)
	{
		mapcou_fl = float(g_iMapCount[0]);
	}
	else
	{
		mapcou_fl = float(g_iMapCount[1]);
	}
	new Float: Com_Per_fl = (mapcom_fl/mapcou_fl)*100;
	
	if(!track)
	{
		SetMenuTitle(g_TargetData[client][eTarget_MapMenu], "%i of %i (%.2f%%) Maps completed\nRecords:\n ", mapscomplete, g_iMapCount[0], Com_Per_fl);
	}
	else
	{
		SetMenuTitle(g_TargetData[client][eTarget_MapMenu], "%i of %i (%.2f%%) Bonuses completed\nRecords:\n ", mapscomplete, g_iMapCount[1], Com_Per_fl);
	}
	
	if(SQL_HasResultSet(hndl))
	{
		new i = 1;
		// Loop over
		while (SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 1, szMapName, 32);
			SQL_FetchString(hndl, 2, SteamID, 256);
			Timer_SecondsToTime(SQL_FetchFloat(hndl, 0), szVrTime, 16, 2);
			Format(szValue, 64, "%s - %s",szMapName, szVrTime);
			
			new Handle:pack2 = CreateDataPack();
			WritePackCell(pack2, client);
			WritePackString(pack2, szMapName);
			WritePackString(pack2, SteamID);
			WritePackCell(pack2, track);
			Format(buffer, sizeof(buffer), "%d", pack2);
			
			CloseHandle(pack2);
			pack2 = INVALID_HANDLE;
			
			AddMenuItem(g_TargetData[client][eTarget_MapMenu], buffer, szValue);
			i++;
		}
		if(i == 1)
		{
			AddMenuItem(g_TargetData[client][eTarget_MapMenu], "nope", "No Record found...");
		}
	}
	
	SetMenuExitBackButton(g_TargetData[client][eTarget_MapMenu], true);
	DisplayMenu(g_TargetData[client][eTarget_MapMenu], client, MENU_TIME_FOREVER);
}

public Menu_PlayerSearch(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:SteamID[256];
		GetMenuItem(menu, param2, SteamID, sizeof(SteamID));
		
		if(!StrEqual(SteamID, "nope") && !StrEqual(SteamID, "many") && !StrEqual(SteamID, "speci"))
		{
			Format(g_TargetData[client][eTarget_SteamID], 32, "%s", SteamID);
			KvJumpToKey(g_hPlayerSearch[client], SteamID, false);
			KvGetString(g_hPlayerSearch[client], "name", g_TargetData[client][eTarget_Name], 256, "Unknown");
			
			Menu_PlayerInfo(client);
		}
		
		if(g_hPlayerSearch[client] != INVALID_HANDLE)
		{
			CloseHandle(g_hPlayerSearch[client]);
			g_hPlayerSearch[client] = INVALID_HANDLE;
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Menu_PlayerInfo_Handler(Handle:menu, MenuAction:action, client, param2)
{
	if ( action == MenuAction_Select )
	{
		new first_item = GetMenuSelectionPosition();
		DisplayMenuAtItem(menu, client, first_item, MENU_TIME_FOREVER); 

		switch (param2)
		{
			case 0:
			{
				decl String:Query[255];
				Format(Query, 255, sql_selectSingleRecord, g_TargetData[client][eTarget_SteamID], g_MapName, g_TargetData[client][eTarget_Style]);

				new Handle:pack2 = CreateDataPack();
				WritePackCell(pack2, client);
				WritePackString(pack2, g_MapName);
				
				SQL_TQuery(g_hSQL, SQL_ViewSingleRecordCallback, Query, pack2);
			}
			case 1:
			{
				decl String:szQuery[255];
				Format(szQuery, 255, sql_selectPlayer_Points, g_TargetData[client][eTarget_SteamID]);
				decl String:Query2[255];
				Format(Query2, 255, sql_selectPlayerPRowCount, g_TargetData[client][eTarget_SteamID]);

				new Handle:pack3 = CreateDataPack();
				WritePackCell(pack3, client);

				SQL_TQuery(g_hSQL, SQL_PRowCountCallback, Query2, pack3);
				SQL_TQuery(g_hSQL, SQL_PlayerPointsCallback, szQuery, pack3);
			}
			case 2:
			{
				new bool: track = false;
				new Handle:pack4 = CreateDataPack();
				WritePackCell(pack4, client);
				WritePackCell(pack4, track);
				
				
				decl String:szQuery[255];
				Format(szQuery, 255, sql_selectPlayerMaps, g_TargetData[client][eTarget_SteamID], g_TargetData[client][eTarget_Style]);
				SQL_TQuery(g_hSQL, SQL_ViewPlayerMapsCallback, szQuery, pack4);
			}
			case 3:
			{
				new bool: track = true;
				new Handle:pack5 = CreateDataPack();
				WritePackCell(pack5, client);
				WritePackCell(pack5, track);
				
				decl String:szQuery[255];
				Format(szQuery, 255, sql_selectPlayerMapsBonus, g_TargetData[client][eTarget_SteamID], g_TargetData[client][eTarget_Style]);
				SQL_TQuery(g_hSQL, SQL_ViewPlayerMapsCallback, szQuery, pack5);
			}
			case 4:
			{
				new bool: track = false;
				new Handle:pack5 = CreateDataPack();
				WritePackCell(pack5, client);
				WritePackCell(pack5, track);
				
				decl String:szQuery[255];
				Format(szQuery, 255, sql_selectPlayerWRs, g_TargetData[client][eTarget_Style], g_TargetData[client][eTarget_SteamID]);
				SQL_TQuery(g_hSQL, SQL_ViewPlayerMapsCallback, szQuery, pack5);
			}
			case 5:
			{
				new bool: track = true;
				new Handle:pack5 = CreateDataPack();
				WritePackCell(pack5, client);
				WritePackCell(pack5, track);
				
				decl String:szQuery[255];
				Format(szQuery, 255, sql_selectPlayerWRsBonus, g_TargetData[client][eTarget_Style], g_TargetData[client][eTarget_SteamID]);
				SQL_TQuery(g_hSQL, SQL_ViewPlayerMapsCallback, szQuery, pack5);
			}
			case 6:
			{
				GetIncompleteMaps(client, g_TargetData[client][eTarget_SteamID], 0, g_TargetData[client][eTarget_Style]);
			}
			case 7:
			{
				GetIncompleteMaps(client, g_TargetData[client][eTarget_SteamID], 1, g_TargetData[client][eTarget_Style]);
			}
			case 8:
			{
				StylePanel(client);
			}
		}
	}
}

public Menu_Stock_Handler(Handle:menu, MenuAction:action, client, param2)
{
	if ( action == MenuAction_Select )
	{
		new first_item = GetMenuSelectionPosition();
		DisplayMenuAtItem(menu, client, first_item, MENU_TIME_FOREVER); 
	}
	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		DisplayMenu(g_TargetData[client][eTarget_MainMenu], client, MENU_TIME_FOREVER);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Menu_Stock_Handler2(Handle:menu, MenuAction:action, client, param2)
{
	if ( action == MenuAction_Select )
	{
		new first_item = GetMenuSelectionPosition();
		DisplayMenuAtItem(menu, client, first_item, MENU_TIME_FOREVER); 
	}
	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		DisplayMenuAtItem(g_TargetData[client][eTarget_MapMenu], client, g_MenuPos[client], MENU_TIME_FOREVER);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public MapMenu_Stock_Handler(Handle:menu, MenuAction:action, client, param2)
{
	if ( action == MenuAction_Select )
	{
		g_MenuPos[client] = GetMenuSelectionPosition();
		DisplayMenuAtItem(menu, client, g_MenuPos[client], MENU_TIME_FOREVER); 
		
		decl String:data[512];
		GetMenuItem(menu, param2, data, sizeof(data));
		new Handle:pack = Handle:StringToInt(data); 
		ResetPack(pack);
		ReadPackCell(pack);
		decl String:MapName[256];
		ReadPackString(pack, MapName, 256);
		decl String:SteamID[256];
		ReadPackString(pack, SteamID, 256);
		new track = ReadPackCell(pack);
		
		decl String:szQuery[255];
		Format(szQuery, 255, sql_selectPlayerMapRecord, g_TargetData[client][eTarget_SteamID], MapName, track, g_TargetData[client][eTarget_Style]);
		
		SQL_TQuery(g_hSQL, SQL_ViewPlayerMapRecordCallback, szQuery, pack);
	}
	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		DisplayMenu(g_TargetData[client][eTarget_MainMenu], client, MENU_TIME_FOREVER);
	}
}

GetIncompleteMaps(client, String:auth[], track, style)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackString(pack, auth);
	WritePackCell(pack, track);
	WritePackCell(pack, style);
	
	decl String:sQuery[255];
	if(style > -1)
		Format(sQuery, sizeof(sQuery), "SELECT DISTINCT map FROM round WHERE bonus = %d AND auth = '%s' AND style = %d ORDER BY map", track, auth, style);
	else
		Format(sQuery, sizeof(sQuery), "SELECT DISTINCT map FROM round WHERE bonus = %d AND auth = '%s' ORDER BY map", track, auth);
	SQL_TQuery(g_hSQL, CallBack_IncompleteMaps, sQuery, pack, DBPrio_Low);
}

public CallBack_IncompleteMaps(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		return;
	}
	
	if(!SQL_GetRowCount(hndl))
	{
		LogError("No startzone found.");
	}
	else
	{
		new Handle:pack = data;
		
		ResetPack(pack);
		new client = ReadPackCell(pack);
		decl String:sAuth[64];
		ReadPackString(pack, sAuth, sizeof(sAuth));
		new track = ReadPackCell(pack);
		new style = ReadPackCell(pack);
		CloseHandle(pack);
		pack = INVALID_HANDLE;
		
		new String:sMap[128];
		new Handle:Kv = CreateKeyValues("data");
		
		while(SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, sMap, sizeof(sMap));
			
			KvJumpToKey(Kv, sMap, true);
			KvRewind(Kv);
			
			g_iMapCountComplete[client]++;
		}
		
		new iCountIncomplete;
		
		new Handle:menu = CreateMenu(MenuHandler_Incompelte);
		
		KvRewind(g_hMaps[track]);
		KvGotoFirstSubKey(g_hMaps[track], true);
		do
		{
			KvGetSectionName(g_hMaps[track], sMap, sizeof(sMap));
			if(!KvJumpToKey(Kv, sMap, false))
			{
				iCountIncomplete++;
				AddMenuItem(menu, "", sMap);
			}
			KvRewind(Kv);
        } while (KvGotoNextKey(g_hMaps[track], false));
		
		if(iCountIncomplete == 0)
			AddMenuItem(menu, "", "All maps compelte, awesome!");
		
		if(track == TRACK_BONUS)
		{
			if(style == -1 || !g_Settings[MultimodeEnable])
				SetMenuTitle(menu, "%i of %i (%.2f%%) Bonus Maps incomplete\n ", iCountIncomplete, g_iMapCount[track], 100.0*(float(iCountIncomplete)/float(g_iMapCount[track])));
			else
				SetMenuTitle(menu, "%i of %i (%.2f%%) Bonus Maps incomplete\nStyle: %s\n ", iCountIncomplete, g_iMapCount[track], 100.0*(float(iCountIncomplete)/float(g_iMapCount[track])), g_Physics[style][StyleName]);
		}
		else if(track == TRACK_NORMAL)
		{
			if(style == -1 || !g_Settings[MultimodeEnable])
				SetMenuTitle(menu, "%i of %i (%.2f%%) Maps incomplete\n ", iCountIncomplete, g_iMapCount[track], 100.0*(float(iCountIncomplete)/float(g_iMapCount[track])));
			else
				SetMenuTitle(menu, "%i of %i (%.2f%%) Maps incomplete\nStyle: %s\n ", iCountIncomplete, g_iMapCount[track], 100.0*(float(iCountIncomplete)/float(g_iMapCount[track])), g_Physics[style][StyleName]);
		}
		
		SetMenuExitButton(menu, true);
		SetMenuExitBackButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
}

public MenuHandler_Incompelte(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_Select)
	{
		if(g_TargetData[client][eTarget_MainMenu] != INVALID_HANDLE) Menu_PlayerInfo(client);
	}
	else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		DisplayMenu(g_TargetData[client][eTarget_MainMenu], client, MENU_TIME_FOREVER);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public OnClientDisconnect(client)
{
	ClearClient(client);
}

ClearClient(client)
{
	if(g_TargetData[client][eTarget_MainMenu] != INVALID_HANDLE)
	{
		CloseHandle(g_TargetData[client][eTarget_MainMenu]);
		g_TargetData[client][eTarget_MainMenu] = INVALID_HANDLE;
	}
	
	if(g_TargetData[client][eTarget_MapMenu] != INVALID_HANDLE)
	{
		CloseHandle(g_TargetData[client][eTarget_MapMenu]);
		g_TargetData[client][eTarget_MapMenu] = INVALID_HANDLE;
	}
}