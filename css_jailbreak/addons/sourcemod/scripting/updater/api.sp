
/* API - Natives & Forwards */

new Handle:g_OnPluginChecking = INVALID_HANDLE;
new Handle:g_OnPluginDownloading = INVALID_HANDLE;
new Handle:g_OnPluginUpdating = INVALID_HANDLE;
new Handle:g_OnPluginUpdated = INVALID_HANDLE;

API_Init()
{
	CreateNative("Updater_AddPlugin", Native_AddPlugin);
	CreateNative("Updater_RemovePlugin", Native_RemovePlugin);
	CreateNative("Updater_ForceUpdate", Native_ForceUpdate);
	
	g_OnPluginChecking = CreateForward(ET_Event);
	g_OnPluginDownloading = CreateForward(ET_Event);
	g_OnPluginUpdating = CreateForward(ET_Ignore);
	g_OnPluginUpdated = CreateForward(ET_Ignore);
}

// native Updater_AddPlugin(const String:url[]);
public Native_AddPlugin(Handle:plugin, numParams)
{
	decl String:url[MAX_URL_LENGTH];
	GetNativeString(1, url, sizeof(url));
	
	Updater_AddPlugin(plugin, url);
}

// native Updater_RemovePlugin();
public Native_RemovePlugin(Handle:plugin, numParams)
{
	new index = PluginToIndex(plugin);
	
	if (index != -1)
	{
		Updater_QueueRemovePlugin(plugin);
	}
}

// native bool:Updater_ForceUpdate();
public Native_ForceUpdate(Handle:plugin, numParams)
{
	new index = PluginToIndex(plugin);
	
	if (index == -1)
	{
		ThrowNativeError(SP_ERROR_NOT_FOUND, "Plugin not found in updater.");
	}
	else if (Updater_GetStatus(index) == Status_Idle)
	{
		Updater_Check(index);
		return 1;
	}
	
	return 0;
}

// forward Action:Updater_OnPluginChecking();
Action:Fwd_OnPluginChecking(Handle:plugin)
{
	new Action:result = Plugin_Continue;
	new Function:func = GetFunctionByName(plugin, "Updater_OnPluginChecking");
	
	if (func != INVALID_FUNCTION && AddToForward(g_OnPluginChecking, plugin, func))
	{
		Call_StartForward(g_OnPluginChecking);
		Call_Finish(result);
		RemoveAllFromForward(g_OnPluginChecking, plugin);
	}
	
	return result;
}

// forward Action:Updater_OnPluginDownloading();
Action:Fwd_OnPluginDownloading(Handle:plugin)
{
	new Action:result = Plugin_Continue;
	new Function:func = GetFunctionByName(plugin, "Updater_OnPluginDownloading");
	
	if (func != INVALID_FUNCTION && AddToForward(g_OnPluginDownloading, plugin, func))
	{
		Call_StartForward(g_OnPluginDownloading);
		Call_Finish(result);
		RemoveAllFromForward(g_OnPluginDownloading, plugin);
	}
	
	return result;
}

// forward Updater_OnPluginUpdating();
Fwd_OnPluginUpdating(Handle:plugin)
{
	new Function:func = GetFunctionByName(plugin, "Updater_OnPluginUpdating");
	
	if (func != INVALID_FUNCTION && AddToForward(g_OnPluginUpdating, plugin, func))
	{
		Call_StartForward(g_OnPluginUpdating);
		Call_Finish();
		RemoveAllFromForward(g_OnPluginUpdating, plugin);
	}
}

// forward Updater_OnPluginUpdated();
Fwd_OnPluginUpdated(Handle:plugin)
{
	new Function:func = GetFunctionByName(plugin, "Updater_OnPluginUpdated");
	
	if (func != INVALID_FUNCTION && AddToForward(g_OnPluginUpdated, plugin, func))
	{
		Call_StartForward(g_OnPluginUpdated);
		Call_Finish();
		RemoveAllFromForward(g_OnPluginUpdated, plugin);
	}
}
