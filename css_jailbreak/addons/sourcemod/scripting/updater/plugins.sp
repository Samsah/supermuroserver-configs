
/* PluginPack Helpers */

GetMaxPlugins()
{
	return GetArraySize(g_hPluginPacks);
}

bool:IsValidPlugin(Handle:plugin)
{
	/* Check if the plugin handle is pointing to a valid plugin. */
	new Handle:hIterator = GetPluginIterator();
	new bool:bIsValid = false;
	
	while (MorePlugins(hIterator))
	{
		if (plugin == ReadPlugin(hIterator))
		{
			bIsValid = true;
			break;
		}
	}
	
	CloseHandle(hIterator);
	return bIsValid;
}

PluginToIndex(Handle:plugin)
{
	new Handle:hPluginPack = INVALID_HANDLE;
	
	new maxPlugins = GetMaxPlugins();
	for (new i = 0; i < maxPlugins; i++)
	{
		hPluginPack = GetArrayCell(g_hPluginPacks, i);
		ResetPack(hPluginPack);
		
		if (plugin == Handle:ReadPackCell(hPluginPack))
		{
			return i;
		}
	}
	
	return -1;
}

Handle:IndexToPlugin(index)
{
	new Handle:hPluginPack = GetArrayCell(g_hPluginPacks, index);
	ResetPack(hPluginPack);
	return Handle:ReadPackCell(hPluginPack);
}

Updater_AddPlugin(Handle:plugin, const String:url[])
{	
	new index = PluginToIndex(plugin);
	
	if (index != -1)
	{
		// Remove plugin from removal queue.
		new maxPlugins = GetArraySize(g_hRemoveQueue);
		for (new i = 0; i < maxPlugins; i++)
		{
			if (plugin == GetArrayCell(g_hRemoveQueue, i))
			{
				RemoveFromArray(g_hRemoveQueue, i);
				break;
			}
		}
		
		// Update the url.
		Updater_SetURL(index, url);
	}
	else
	{
		new Handle:hPluginPack = CreateDataPack();
		new Handle:hFiles = CreateArray(PLATFORM_MAX_PATH);
		
		WritePackCell(hPluginPack, _:plugin);
		WritePackCell(hPluginPack, _:hFiles);
		WritePackCell(hPluginPack, _:Status_Idle);
		WritePackString(hPluginPack, url);
		
		PushArrayCell(g_hPluginPacks, hPluginPack);
	}
}

Updater_QueueRemovePlugin(Handle:plugin)
{
	/* Flag a plugin for removal. */
	new maxPlugins = GetArraySize(g_hRemoveQueue);
	for (new i = 0; i < maxPlugins; i++)
	{
		// Make sure it wasn't previously flagged.
		if (plugin == GetArrayCell(g_hRemoveQueue, i))
		{
			return;
		}
	}
	
	PushArrayCell(g_hRemoveQueue, plugin);
	Updater_FreeMemory();
}

Updater_RemovePlugin(index)
{
	/* Warning: Removing a plugin will shift indexes. */
	CloseHandle(Updater_GetFiles(index)); // hFiles
	CloseHandle(GetArrayCell(g_hPluginPacks, index)); // hPluginPack
	RemoveFromArray(g_hPluginPacks, index);
}

Handle:Updater_GetFiles(index)
{
	new Handle:hPluginPack = GetArrayCell(g_hPluginPacks, index);
	SetPackPosition(hPluginPack, 8);
	return Handle:ReadPackCell(hPluginPack);
}

UpdateStatus:Updater_GetStatus(index)
{
	new Handle:hPluginPack = GetArrayCell(g_hPluginPacks, index);
	SetPackPosition(hPluginPack, 16);
	return UpdateStatus:ReadPackCell(hPluginPack);
}

Updater_SetStatus(index, UpdateStatus:status)
{
	new Handle:hPluginPack = GetArrayCell(g_hPluginPacks, index);
	SetPackPosition(hPluginPack, 16);
	WritePackCell(hPluginPack, _:status);
}

Updater_GetURL(index, String:buffer[], size)
{
	new Handle:hPluginPack = GetArrayCell(g_hPluginPacks, index);
	SetPackPosition(hPluginPack, 24);
	ReadPackString(hPluginPack, buffer, size);
}

Updater_SetURL(index, const String:url[])
{
	new Handle:hPluginPack = GetArrayCell(g_hPluginPacks, index);
	SetPackPosition(hPluginPack, 24);
	WritePackString(hPluginPack, url);
}

/* Stocks */
stock ReloadPlugin(Handle:plugin=INVALID_HANDLE)
{
	decl String:filename[64];
	GetPluginFilename(plugin, filename, sizeof(filename));
	ServerCommand("sm plugins reload %s", filename);
}

stock UnloadPlugin(Handle:plugin=INVALID_HANDLE)
{
	decl String:filename[64];
	GetPluginFilename(plugin, filename, sizeof(filename));
	ServerCommand("sm plugins unload %s", filename);
}

stock DisablePlugin(Handle:plugin=INVALID_HANDLE)
{
	decl String:filename[64] String:path_disabled[PLATFORM_MAX_PATH], String:path_plugin[PLATFORM_MAX_PATH];
	
	GetPluginFilename(plugin, filename, sizeof(filename));
	BuildPath(Path_SM, path_disabled, sizeof(path_disabled), "plugins/disabled/%s", filename);
	BuildPath(Path_SM, path_plugin, sizeof(path_plugin), "plugins/%s", filename);
	
	if (FileExists(path_disabled))
	{
		DeleteFile(path_disabled);
	}
	
	if (!RenameFile(path_disabled, path_plugin))
	{
		DeleteFile(path_plugin);
	}
	
	ServerCommand("sm plugins unload %s", filename);
}
