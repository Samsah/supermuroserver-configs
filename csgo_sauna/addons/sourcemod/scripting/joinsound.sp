#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#include <multicolors>
#include <emitsoundany>
#include <autoexecconfig>

#undef REQUIRE_PLUGIN
#tryinclude <updater>

#define JOINSOUND_VERSION "1.0.7"
#define UPDATE_URL "https://bara.in/update/joinsound.txt"

new Handle:g_hJoinSoundEnable = INVALID_HANDLE;
new Handle:g_hJoinSoundPath = INVALID_HANDLE;

new Handle:g_hJoinSoundStart = INVALID_HANDLE;
new Handle:g_hJoinSoundStartCommand = INVALID_HANDLE;
new String:g_sJoinSoundStartCommand[32];

new Handle:g_hJoinSoundStop = INVALID_HANDLE;
new Handle:g_hStopMessage = INVALID_HANDLE;
new Handle:g_hJoinSoundStopCommand = INVALID_HANDLE;
new String:g_sJoinSoundStopCommand[32];

new Handle:g_hJoinSoundVolume = INVALID_HANDLE;
new String:g_hJoinSoundName[PLATFORM_MAX_PATH];

new Handle:g_hMessageTime = INVALID_HANDLE;

new Handle:g_hAdminJoinSoundEnable = INVALID_HANDLE;
new Handle:g_hAdminJoinSoundChatEnable = INVALID_HANDLE;
new Handle:g_hAdminJoinSoundPath = INVALID_HANDLE;
new Handle:g_hAdminJoinSoundVolume = INVALID_HANDLE;
new String:g_hAdminJoinSoundName[PLATFORM_MAX_PATH];


public Plugin:myinfo =
{
	name = "Admin / Player - Joinsound",
	author = "Bara",
	description = "Plays a custom joinsound if admin or player joins the server",
	version = JOINSOUND_VERSION,
	url = "www.bara.in"
};

public OnPluginStart()
{
	CreateConVar("admin-joinsound_version", JOINSOUND_VERSION, "Joinsound", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	LoadTranslations("joinsound.phrases");

	AutoExecConfig_SetFile("plugin.joinsound");
	AutoExecConfig_SetCreateFile(true);

	g_hJoinSoundEnable = AutoExecConfig_CreateConVar("joinsound_enable", "1", "Enable joinsound?", _, true, 0.0, true, 1.0);
	g_hJoinSoundPath = AutoExecConfig_CreateConVar("joinsound_path", "ambient/blueoyster.mp3", "Which file sould be played? Path after cstrike/sound/ (JoinSound)");
	g_hJoinSoundStart = AutoExecConfig_CreateConVar("joinsound_start", "1", "Should '!start'-feature be enabled?", _, true, 0.0, true, 1.0);
	g_hJoinSoundStartCommand = AutoExecConfig_CreateConVar("joinsound_start_command", "start", "Command for start function");
	g_hJoinSoundStop = AutoExecConfig_CreateConVar("joinsound_stop", "1", "Should '!stop'-feature be enabled?", _, true, 0.0, true, 1.0);
	g_hStopMessage = AutoExecConfig_CreateConVar("joinsound_stop_message", "1", "Send a message?", _, true, 0.0, true, 1.0);
	g_hJoinSoundStopCommand = AutoExecConfig_CreateConVar("joinsound_stop_command", "stop", "Command for stop function");
	g_hJoinSoundVolume = AutoExecConfig_CreateConVar("joinsound_volume", "1.0", "Volume of joinsound (1 = default)");

	g_hMessageTime = AutoExecConfig_CreateConVar("joinsound_message_time", "5.0", "After how many seconds get a message after the beginning of the sound");

	g_hAdminJoinSoundEnable = AutoExecConfig_CreateConVar("admin_joinsound_enable", "1", "Enable admin joinsound?", _, true, 0.0, true, 1.0);
	g_hAdminJoinSoundChatEnable = AutoExecConfig_CreateConVar("admin_chat_enable", "1", "Enable admin joinmessage?", _, true, 0.0, true, 1.0);
	g_hAdminJoinSoundPath = AutoExecConfig_CreateConVar("admin_joinsound_path", "newsongformyserver/admin_joinsound.mp3", "Which file sould be played? Path after cstrike/sound/ (AdminJoinSound)");
	g_hAdminJoinSoundVolume = AutoExecConfig_CreateConVar("admin_joinsound_volume", "1.0", "Volume of admin joinsound (1 = default)");

	AutoExecConfig_CleanFile();
	AutoExecConfig_ExecuteFile();

	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}

public OnConfigsExecuted()
{
	if(GetConVarInt(g_hJoinSoundEnable))
	{
		GetConVarString(g_hJoinSoundPath, g_hJoinSoundName, PLATFORM_MAX_PATH);
		PrecacheSoundAny(g_hJoinSoundName, true);

		decl String:sBuffer[PLATFORM_MAX_PATH];
		Format(sBuffer, sizeof(sBuffer), "sound/%s", g_hJoinSoundName);
		AddFileToDownloadsTable(sBuffer);
	}

	if(GetConVarInt(g_hAdminJoinSoundEnable))
	{
		GetConVarString(g_hAdminJoinSoundPath, g_hAdminJoinSoundName, PLATFORM_MAX_PATH);
		PrecacheSoundAny(g_hAdminJoinSoundName, true);

		decl String:sBuffer[PLATFORM_MAX_PATH];
		Format(sBuffer, sizeof(sBuffer), "sound/%s", g_hAdminJoinSoundName);
		AddFileToDownloadsTable(sBuffer);
	}

	if(GetConVarInt(g_hJoinSoundStart))
	{
		decl String:sBuffer[32];
		GetConVarString(g_hJoinSoundStartCommand, g_sJoinSoundStartCommand, sizeof(g_sJoinSoundStartCommand));
		Format(sBuffer, sizeof(sBuffer), "sm_%s", g_sJoinSoundStartCommand);
		RegConsoleCmd(sBuffer, Command_StartSound);
	}

	if(GetConVarInt(g_hJoinSoundStop))
	{
		decl String:sBuffer[32];
		GetConVarString(g_hJoinSoundStopCommand, g_sJoinSoundStopCommand, sizeof(g_sJoinSoundStopCommand));
		Format(sBuffer, sizeof(sBuffer), "sm_%s", g_sJoinSoundStopCommand);
		RegConsoleCmd(sBuffer, Command_StopSound);
	}
}

public OnClientPostAdminCheck(client)
{
	if(GetConVarInt(g_hJoinSoundEnable))
	{
		if(IsClientValid(client))
		{
			EmitSoundToClientAny(client, g_hJoinSoundName, _, _, _, _, GetConVarFloat(g_hJoinSoundVolume));

			if(GetConVarInt(g_hStopMessage))
			{
				CreateTimer(GetConVarFloat(g_hMessageTime), Timer_Message, GetClientUserId(client));
			}
		}
	}

	if(GetConVarInt(g_hAdminJoinSoundEnable))
	{
		if(IsClientValid(client) && GetUserAdmin(client) != INVALID_ADMIN_ID)
		{
			EmitSoundToAllAny(g_hAdminJoinSoundName, _, _, _, _, GetConVarFloat(g_hAdminJoinSoundVolume));
			if(GetConVarInt(g_hAdminJoinSoundChatEnable))
			{
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientValid(i))
					{
						CPrintToChat(i, "%T", "AdminJoin", i, client);
					}
				}
			}
		}
	}
}

public Action:Timer_Message(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(client);

	if(IsClientValid(client))
	{
		CPrintToChat(client, "%T", "JoinStop", client, g_sJoinSoundStopCommand);
	}
}

public Action:Command_StopSound(client, args)
{
	if(GetConVarInt(g_hJoinSoundEnable) && GetConVarInt(g_hJoinSoundStop))
	{
		if(IsClientValid(client))
		{
			StopSoundAny(client, SNDCHAN_AUTO, g_hJoinSoundName);
		}
	}
}

public Action:Command_StartSound(client, args)
{
	if(GetConVarInt(g_hJoinSoundEnable) && GetConVarInt(g_hJoinSoundStart))
	{
		if(IsClientValid(client))
		{
			EmitSoundToClientAny(client, g_hJoinSoundName, _, _, _, _, GetConVarFloat(g_hJoinSoundVolume));

			if(GetConVarInt(g_hStopMessage))
			{
				CreateTimer(GetConVarFloat(g_hMessageTime), Timer_Message, GetClientUserId(client));
			}
		}
	}
}

stock bool:IsClientValid(client)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		return true;
	}
	return false;
}
