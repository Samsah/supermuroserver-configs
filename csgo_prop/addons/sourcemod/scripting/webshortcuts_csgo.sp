#include <sourcemod>

#pragma semicolon 1

#define PLUGIN_VERSION				"2.21"

public Plugin:myinfo = 
{
	name = "Web Shortcuts CS:GO version",
	author = "Narry (Danne2), Franc1sco franug and James \"sslice\" Gray",
	description = "Provides chat-triggered web shortcuts",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/narrygewman/"
};

new Handle:g_Shortcuts;
new Handle:g_Titles;
new Handle:g_Links;
//new Handle:g_cvScriptURL;

new String:g_ServerIp [32];
new String:g_ServerPort [16];


public OnPluginStart()
{
	CreateConVar( "sm_webshortcutscsgo_version", PLUGIN_VERSION, "Plugin Version", FCVAR_NOTIFY|FCVAR_REPLICATED );
	CreateConVar( "sm_webshortcutscsgo_scripturl", "http://example.com/webshortcuts.php", "The URL where your redirect script is hosted", FCVAR_PLUGIN | FCVAR_ARCHIVE | FCVAR_NOTIFY, true);	

	RegConsoleCmd( "say", OnSay );
	RegConsoleCmd( "say_team", OnSay );
	
	RegAdminCmd("sm_web", Command_Web, ADMFLAG_GENERIC,"Open URL for target");
	
	g_Shortcuts = CreateArray( 32 );
	g_Titles = CreateArray( 64 );
	g_Links = CreateArray( 512 );
	//g_cvScriptURL = CreateArray( 128 );
	
	new Handle:cvar = FindConVar( "hostip" );
	new hostip = GetConVarInt( cvar );
	FormatEx( g_ServerIp, sizeof(g_ServerIp), "%u.%u.%u.%u",
		(hostip >> 24) & 0x000000FF, (hostip >> 16) & 0x000000FF, (hostip >> 8) & 0x000000FF, hostip & 0x000000FF );
	
	cvar = FindConVar( "hostport" );
	GetConVarString( cvar, g_ServerPort, sizeof(g_ServerPort) );
	AutoExecConfig(true,"plugin.webshortcuts_csgo");
	LoadWebshortcuts();
}
 
public OnMapEnd()
{
	LoadWebshortcuts();
}
 
public Action:OnSay( client, args )
{
	if(!client) return Plugin_Continue;	
	
	
	decl String:text [512];
	GetCmdArgString( text, sizeof(text) );
	
	new start;
	new len = strlen(text);
	if ( text[len-1] == '"' )
	{
		text[len-1] = '\0';
		start = 1;
	}
	
	decl String:shortcut [32];
	BreakString( text[start], shortcut, sizeof(shortcut) );
	
	new size = GetArraySize( g_Shortcuts );
	for (new i; i != size; ++i)
	{
		GetArrayString( g_Shortcuts, i, text, sizeof(text) );
		
		if ( strcmp( shortcut, text, false ) == 0 )
		{
			QueryClientConVar(client, "cl_disablehtmlmotd", ConVarQueryFinished:ClientConVar, client);
			
			decl String:title [64];
			decl String:steamId [64];
			decl String:userId [16];
			decl String:name [64];
			decl String:clientIp [32];
			decl String:scripturl2 [256];


			new Handle:cvar = FindConVar( "sm_webshortcutscsgo_scripturl" );
			GetConVarString( cvar, scripturl2, sizeof(scripturl2) );
			
			GetArrayString( g_Titles, i, title, sizeof(title) );
			GetArrayString( g_Links, i, text, sizeof(text) );
			//GetArrayString( g_cvScriptURL, i, scripturl2, sizeof(scripturl2) ); 
			
			//GetClientAuthString( client, steamId, sizeof(steamId) );
			GetClientAuthId(client, AuthId_Steam2,  steamId, sizeof(steamId) );
			FormatEx( userId, sizeof(userId), "%u", GetClientUserId( client ) );
			GetClientName( client, name, sizeof(name) );
			GetClientIP( client, clientIp, sizeof(clientIp) );
			
/* 			ReplaceString( title, sizeof(title), "{SERVER_IP}", g_ServerIp);
			ReplaceString( title, sizeof(title), "{SERVER_PORT}", g_ServerPort);
			ReplaceString( title, sizeof(title), "{STEAM_ID}", steamId);
			ReplaceString( title, sizeof(title), "{USER_ID}", userId);
			ReplaceString( title, sizeof(title), "{NAME}", name);
			ReplaceString( title, sizeof(
			), "{IP}", clientIp); */
			
			
			ReplaceString( title, sizeof(title), "width", "&width");
			ReplaceString( title, sizeof(title), "height", "&height");
			
			ReplaceString( text, sizeof(text), "{SERVER_IP}", g_ServerIp);
			ReplaceString( text, sizeof(text), "{SERVER_PORT}", g_ServerPort);
			ReplaceString( text, sizeof(text), "{STEAM_ID}", steamId);
			ReplaceString( text, sizeof(text), "{USER_ID}", userId);
			ReplaceString( text, sizeof(text), "{NAME}", name);
			ReplaceString( text, sizeof(text), "{IP}", clientIp);
			
			if (StrEqual(scripturl2, "http://example.com/webshortcuts.php", false))
			{
				PrintToConsole(client, "You haven't set a URL for the PHP script! You need to change 'sm_webshortcutscsgo_scripturl' to point to the script! Make sure to set it in the config.");
			}
			else
			{
				if(StrEqual(title, "none", false))
				{
					StreamPanel("Webshortcuts", text, client);
				}
				else if(StrEqual(title, "full", false))
				{
					FixMotdCSGO_fullsize(text, scripturl2);
					ShowMOTDPanel( client, "Script by Narry because Franc1sco wouldn't release his for some stupid reason and sent me a mean PM when I released one <3", text, MOTDPANEL_TYPE_URL );
				}
				else
				{
					FixMotdCSGO(text, scripturl2, title);
					ShowMOTDPanel( client, "Script by Narry because Franc1sco wouldn't release his for some stupid reason and sent me a mean PM when I released one <3", text, MOTDPANEL_TYPE_URL );
					//PrintToConsole(client, text);
					//PrintToConsole(client, scripturl2);
					//PrintToConsole(client, title);
				}
			}
		}
	}
	
	return Plugin_Continue;	
}
 
LoadWebshortcuts()
{
	decl String:buffer [1024];
	BuildPath( Path_SM, buffer, sizeof(buffer), "configs/webshortcuts.txt" );
	
	if ( !FileExists( buffer ) )
	{
		return;
	}
 
	new Handle:f = OpenFile( buffer, "r" );
	if ( f == INVALID_HANDLE )
	{
		LogError( "[SM] Could not open file: %s", buffer );
		return;
	}
	
	ClearArray( g_Shortcuts );
	ClearArray( g_Titles );
	ClearArray( g_Links );
	
	decl String:shortcut [32];
	decl String:title [64];
	decl String:link [512];
	while ( !IsEndOfFile( f ) && ReadFileLine( f, buffer, sizeof(buffer) ) )
	{
		TrimString( buffer );
		if ( buffer[0] == '\0' || buffer[0] == ';' || ( buffer[0] == '/' && buffer[1] == '/' ) )
		{
			continue;
		}
		
		new pos = BreakString( buffer, shortcut, sizeof(shortcut) );
		if ( pos == -1 )
		{
			continue;
		}
		
		new linkPos = BreakString( buffer[pos], title, sizeof(title) );
		if ( linkPos == -1 )
		{
			continue;
		}
		
		strcopy( link, sizeof(link), buffer[linkPos+pos] );
		TrimString( link );
		
		PushArrayString( g_Shortcuts, shortcut );
		PushArrayString( g_Titles, title );
		PushArrayString( g_Links, link );
	}
	
	CloseHandle( f );
}

public Action:Command_Web(client, args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_web <target> <url>");
		return Plugin_Handled;
	}
	decl String:pattern[96], String:buffer[64], String:url[512];
	GetCmdArg(1, pattern, sizeof(pattern));
	GetCmdArg(2, url, sizeof(url));
	new targets[129], bool:ml = false;
	

	new count = ProcessTargetString(pattern, client, targets, sizeof(targets), 0, buffer, sizeof(buffer), ml);

	decl String:scripturl2 [256];
	new Handle:cvar = FindConVar( "sm_webshortcutscsgo_scripturl" );
	GetConVarString( cvar, scripturl2, sizeof(scripturl2) );

	
	if(StrContains(url, "http://", false) != 0) Format(url, sizeof(url), "http://%s", url);
	FixMotdCSGO(url, scripturl2, "&width=960&height=720");
	
	if (count <= 0) ReplyToCommand(client, "Bad target");
	else for (new i = 0; i < count; i++)
	{
		ShowMOTDPanel(targets[i], "Web Shortcuts", url, MOTDPANEL_TYPE_URL);
	}
	return Plugin_Handled;
}

public StreamPanel(String:title[], String:url[], client) {
	new Handle:Radio = CreateKeyValues("data");
	KvSetString(Radio, "title", title);
	KvSetString(Radio, "type", "2");
	KvSetString(Radio, "msg", url);
	ShowVGUIPanel(client, "info", Radio, false);
	CloseHandle(Radio);
}

stock FixMotdCSGO(String:web[512], String:scripturl2[256], String:title[64])
{
	Format(web, sizeof(web), "%s?web=%s&%s", scripturl2,web,title);
}

stock FixMotdCSGO_fullsize(String:web[512], String:scripturl2[256])
{
	Format(web, sizeof(web), "%s?web=%s&fullsize=1", scripturl2,web);
}


public ClientConVar(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[])
{
	if (StringToInt(cvarValue) > 0)
	{
		PrintToChat(client, "---------------------------------------------------------------");
		PrintToChat(client, "You have cl_disablehtmlmotd to 1 and for that reason webshortcuts plugin dont work for you");
		PrintToChat(client, "Please, put this in your console: cl_disablehtmlmotd 0");
		PrintToChat(client, "---------------------------------------------------------------");
	}
}
