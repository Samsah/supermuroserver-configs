stock void Cvar_OnPluginStart()
{
	CreateConVar("teambans_version", TEAMBANS_PLUGIN_VERSION, TEAMBANS_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD);
	
	g_iCvar[pluginDebug] = CreateConVar("teambans_enable_debug", "1", "Enable debugging?", _, true, 0.0, true, 1.0);
	
	g_iCvar[enableTBan] = CreateConVar("teambans_enable_tban", "1", "Enable 'T'-Ban?", _, true, 0.0, true, 1.0);
	g_iCvar[enableCTBan] = CreateConVar("teambans_enable_ctban", "1", "Enable 'CT'-Ban?", _, true, 0.0, true, 1.0);
	g_iCvar[enableServerBan] = CreateConVar("teambans_enable_serverban", "1", "Enable 'Server'-Ban?", _, true, 0.0, true, 1.0);
	g_iCvar[pluginTag] = CreateConVar("teambans_plugin_tag", "{green}[TeamBans] {lightgreen}", "Choose the plugin tag for this plugin");
	g_iCvar[logLevel] = CreateConVar("teambans_log_level", "1", "0 - Trace, 1 - Debug, 2 - Default, 3 - Info, 4 - Warning, 5 - Error", _, true, 0.0, true, 5.0);
	g_iCvar[playerChecks] = CreateConVar("teambans_player_checks", "3.0", "Check clients every x seconds");
	g_iCvar[defaultBanLength] = CreateConVar("teambans_default_ban_length", "30", "Default ban length in minutes");
	g_iCvar[defaultBanReason] = CreateConVar("teambans_default_ban_reason", "DefaultReason", "Default ban reason phrase (Attention! Changes at your own risk!)");
	
	AutoExecConfig(true, "teambans");
	
	g_iCvar[pluginTag].AddChangeHook(OnCvarChange);
}

public void OnCvarChange(ConVar convar, char[] oldValue, char[] newValue)
{
	if(convar == g_iCvar[pluginTag])
		Format(g_sTag, sizeof(g_sTag), newValue);
}

public void OnConfigsExecuted()
{
	CreateTimer(g_iCvar[playerChecks].FloatValue, Timer_CheckClients, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	g_iCvar[pluginTag].GetString(g_sTag, sizeof(g_sTag));
	
	TopMenu tTopMenu;
	if (LibraryExists("adminmenu") && ((tTopMenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(tTopMenu);
}
