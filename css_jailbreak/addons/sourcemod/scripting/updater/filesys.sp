
/* File System Parsers */

// Strip filename from path.
StripPathFilename(String:path[])
{
	strcopy(path, FindCharInString(path, '/', true) + 1, path);
}

// Return the filename and extension from a given path.
GetPathBasename(String:path[], String:buffer[], maxlength)
{
	new check = -1;
	if ((check = FindCharInString(path, '/', true)) != -1 ||
		(check = FindCharInString(path, '\\', true)) != -1)
	{
		strcopy(buffer, maxlength, path[check+1]);
	}
	else
	{
		strcopy(buffer, maxlength, path);
	}
}

// Add http protocol to url if it's missing.
PrefixURL(String:buffer[], maxlength, const String:url[])
{
	if (strncmp(url, "http://", 7) != 0)
	{
		FormatEx(buffer, maxlength, "http://%s", url);
	}
	else
	{
		strcopy(buffer, maxlength, url);
	}
}

// Split URL into hostname, location, and filename. No trailing slashes.
ParseURL(const String:url[], String:host[], maxHost, String:location[], maxLoc, String:filename[], maxName)
{
	// Strip url prefix.
	new idx = StrContains(url, "://");
	idx = (idx != -1) ? idx + 3 : 0;
	
	decl String:dirs[16][64];
	new total = ExplodeString(url[idx], "/", dirs, sizeof(dirs), sizeof(dirs[]));
	
	// host
	Format(host, maxHost, "%s", dirs[0]);
	
	// location
	location[0] = '\0';
	for (new i = 1; i < total - 1; i++)
	{
		Format(location, maxLoc, "%s/%s", location, dirs[i]);
	}
	
	// filename
	Format(filename, maxName, "%s", dirs[total-1]);
}

// Converts Updater KV file paths into paths relative to the game folder.
ParseKVPathForLocal(const String:path[], String:buffer[], maxlength)
{
	decl String:dirs[16][64];
	new total = ExplodeString(path, "/", dirs, sizeof(dirs), sizeof(dirs[]));
	
	if (StrEqual(dirs[0], "Path_SM"))
	{
		BuildPath(Path_SM, buffer, maxlength, "");
	}
	else // Path_Mod
	{
		buffer[0] = '\0';
	}
	
	// Construct the path and create directories if needed.
	for (new i = 1; i < total - 1; i++)
	{
		Format(buffer, maxlength, "%s%s/", buffer, dirs[i]);

		if(!DirExists(buffer))
		{
			CreateDirectory(buffer, 511);
		}
	}
	
	// Add the filename to the end of the path.
	Format(buffer, maxlength, "%s%s", buffer, dirs[total-1]);
}

// Converts Updater KV file paths into paths relative to the plugin's update URL.
ParseKVPathForDownload(const String:path[], String:buffer[], maxlength)
{
	decl String:dirs[16][64];
	new total = ExplodeString(path, "/", dirs, sizeof(dirs), sizeof(dirs[]));
	
	// Construct the path.
	buffer[0] = '\0';
	for (new i = 1; i < total; i++)
	{
		Format(buffer, maxlength, "%s/%s", buffer, dirs[i]);
	}
}

// Parses a plugin's update file.
// Logs update notes and begins download if required.
// Returns true if an update was available.
bool:ParseUpdateFile(index, const String:path[])
{
	/* Return true if an update was available. */
	new Handle:kv = CreateKeyValues("Updater");
	
	if (!FileToKeyValues(kv, path))
	{
		CloseHandle(kv);
		return false;
	}
	
	decl String:kvLatestVersion[16], String:kvPrevVersion[16], String:sBuffer[MAX_URL_LENGTH];
	new bool:bUpdate = false;
	
	new Handle:hNotes = CreateArray(192);
	new Handle:hPlugin = IndexToPlugin(index);
	new Handle:hFiles = Updater_GetFiles(index);
	ClearArray(hFiles);
	
	// Get update information.
	if (KvJumpToKey(kv, "Information"))
	{
		// Version info.
		if (KvJumpToKey(kv, "Version"))
		{
			KvGetString(kv, "Latest", kvLatestVersion, sizeof(kvLatestVersion));
			KvGetString(kv, "Previous", kvPrevVersion, sizeof(kvPrevVersion));
			KvGoBack(kv);
		}
		
		// Update notes.
		if (KvGotoFirstSubKey(kv, false))
		{
			do
			{
				KvGetSectionName(kv, sBuffer, sizeof(sBuffer));
				
				if (StrEqual(sBuffer, "Notes"))
				{
					KvGetString(kv, NULL_STRING, sBuffer, sizeof(sBuffer));
					PushArrayString(hNotes, sBuffer);				
				}
				
			} while (KvGotoNextKey(kv, false));
			KvGoBack(kv);
		}
		
		KvGoBack(kv);
	}
	else
	{
		CloseHandle(hNotes);
		CloseHandle(kv);
		return false;
	}
	
	// Check if we have the latest version.
	decl String:sCurrentVersion[16], String:sFilename[64];
	GetPluginInfo(hPlugin, PlInfo_Version, sCurrentVersion, sizeof(sCurrentVersion));
	
	if (!StrEqual(sCurrentVersion, kvLatestVersion))
	{
		decl String:sName[64];
		GetPluginFilename(hPlugin, sFilename, sizeof(sFilename));
		GetPluginInfo(hPlugin, PlInfo_Name, sName, sizeof(sName));
		
		Updater_Log("Update available for \"%s\" (%s). Current: %s - Latest: %s", sName, sFilename, sCurrentVersion, kvLatestVersion);
		
		new maxNotes = GetArraySize(hNotes);
		for (new i = 0; i < maxNotes; i++)
		{
			GetArrayString(hNotes, i, sBuffer, sizeof(sBuffer));
			Updater_Log("  [%i]  %s", i, sBuffer);
		}
		
		bUpdate = true;
	}
	
	// Log update notes, save file list, and begin downloading.
	if (bUpdate && g_bGetDownload && Fwd_OnPluginDownloading(hPlugin) == Plugin_Continue)
	{
		// Prepare URL
		decl String:urlprefix[MAX_URL_LENGTH], String:url[MAX_URL_LENGTH], String:dest[PLATFORM_MAX_PATH];
		Updater_GetURL(index, urlprefix, sizeof(urlprefix));
		StripPathFilename(urlprefix);
		
		// Get all files needed for download.
		KvJumpToKey(kv, "Files");
		
		// Check if we only need the patch files.
		if (StrEqual(sCurrentVersion, kvPrevVersion))
		{
			KvJumpToKey(kv, "Patch");
		}
		
		if (KvGotoFirstSubKey(kv, false))
		{
			do
			{
				KvGetSectionName(kv, sBuffer, sizeof(sBuffer));
				
				if (StrEqual(sBuffer, "Plugin") || (g_bGetSource && StrEqual(sBuffer, "Source")))
				{
					KvGetString(kv, NULL_STRING, sBuffer, sizeof(sBuffer));
					
					// Merge url.
					ParseKVPathForDownload(sBuffer, url, sizeof(url));
					Format(url, sizeof(url), "%s%s", urlprefix, url);
					
					// Make sure the current plugin path matches the update.
					ParseKVPathForLocal(sBuffer, dest, sizeof(dest));
					
					decl String:sLocalBase[64], String:sPluginBase[64];
					GetPathBasename(dest, sLocalBase, sizeof(sLocalBase));
					GetPathBasename(sFilename, sPluginBase, sizeof(sPluginBase));
					
					if (StrEqual(sLocalBase, sPluginBase))
					{
						StripPathFilename(dest);
						Format(dest, sizeof(dest), "%s/%s", dest, sFilename);
					}
					
					// Save the file location for later.
					PushArrayString(hFiles, dest);
					
					// Add temporary file extension.
					Format(dest, sizeof(dest), "%s.%s", dest, TEMP_FILE_EXT);
					
					// Begin downloading file.
					AddToDownloadQueue(index, url, dest);
				}
				
			} while (KvGotoNextKey(kv, false));
		}
		
		Updater_SetStatus(index, Status_Downloading);
	}
	else if (bUpdate)
	{
		// We don't want to spam the logs with the same update notification.
		Updater_SetStatus(index, Status_Updated);
	}
	
	CloseHandle(hNotes);
	CloseHandle(kv);
	
	return bUpdate;
}
