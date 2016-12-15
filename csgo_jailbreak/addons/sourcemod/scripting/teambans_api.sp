#pragma semicolon 1

// Core
#include <sourcemod>

#pragma newdecls required

// Includes
#include <teambans>

public Plugin myinfo =
{
	name = TEAMBANS_PLUGIN_NAME,
	author = TEAMBANS_PLUGIN_AUTHOR,
	version = TEAMBANS_PLUGIN_VERSION,
	description = TEAMBANS_PLUGIN_DESCRIPTION,
	url = TEAMBANS_PLUGIN_URL
};

public void OnPluginStart()
{
	HookEvent("weapon_fire", Event_WeaponFire);
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (IsClientInGame(client) && IsPlayerAlive(client))
	{
		if(TeamBans_IsClientBanned(client))
		{
			char sReason[TEAMBANS_REASON_LENGTH];
			TeamBans_GetClientReason(client, sReason, sizeof(sReason));
			
			PrintToChat(client, "Client: %d", client);
			PrintToChat(client, "Status: %d", TeamBans_IsClientBanned(client));
			PrintToChat(client, "Team: %d", TeamBans_GetClientTeam(client));
			PrintToChat(client, "Length: %d", TeamBans_GetClientLength(client));
			PrintToChat(client, "Timeleft: %d", TeamBans_GetClientTimeleft(client));
			PrintToChat(client, "Reason: %s", sReason);
		}
		else
		{
			PrintToChat(client, "Client: %d", client);
			PrintToChat(client, "Status: %d", TeamBans_IsClientBanned(client));
		}
	}
}

public void TeamBans_OnClientBan_Pre(int admin, int client, int team, int length, int timeleft, const char[] reason)
{
	PrintToChat(admin, "TeamBans_OnClientBan_Pre");
	PrintToChat(admin, "Admin: %d", admin);
	PrintToChat(admin, "Client: %d", client);
	PrintToChat(admin, "Team: %d", team);
	PrintToChat(admin, "Length: %d", length);
	PrintToChat(admin, "Timeleft: %d", timeleft);
	PrintToChat(admin, "Reason: %s", reason);
}

public void TeamBans_OnClientBan_Post(int admin, int client, int team, int length, int timeleft, const char[] reason)
{
	PrintToChat(admin, "TeamBans_OnClientBan_Post");
	PrintToChat(admin, "Admin: %d", admin);
	PrintToChat(admin, "Client: %d", client);
	PrintToChat(admin, "Team: %d", team);
	PrintToChat(admin, "Length: %d", length);
	PrintToChat(admin, "Timeleft: %d", timeleft);
	PrintToChat(admin, "Reason: %s", reason);
}

public void TeamBans_OnClientOfflineBan_Pre(int admin, const char[] communityid, int team, int length, int timeleft, const char[] reason)
{
	PrintToChat(admin, "TeamBans_OnClientOfflineBan_Pre");
	PrintToChat(admin, "Admin: %d", admin);
	PrintToChat(admin, "Spieler CommunityID: %s", communityid);
	PrintToChat(admin, "Team: %d", team);
	PrintToChat(admin, "Length: %d", length);
	PrintToChat(admin, "Timeleft: %d", timeleft);
	PrintToChat(admin, "Reason: %s", reason);
}

public void TeamBans_OnClientOfflineBan_Post(int admin, const char[] communityid, int team, int length, int timeleft, const char[] reason)
{
	PrintToChat(admin, "TeamBans_OnClientOfflineBan_Post");
	PrintToChat(admin, "Admin: %d", admin);
	PrintToChat(admin, "Spieler CommunityID: %s", communityid);
	PrintToChat(admin, "Team: %d", team);
	PrintToChat(admin, "Length: %d", length);
	PrintToChat(admin, "Reason: %s", reason);
}

public void TeamBans_OnClientUnban_Pre(int admin, int client, int team, int length, const char[] reason)
{
	PrintToChat(admin, "TeamBans_OnClientUnban_Pre");
	PrintToChat(admin, "Admin: %d", admin);
	PrintToChat(admin, "Client: %d", client);
	PrintToChat(admin, "Team: %d", team);
	PrintToChat(admin, "Length: %d", length);
	PrintToChat(admin, "Reason: %s", reason);
}

public void TeamBans_OnClientUnban_Post(int admin, int client, int team, int length, const char[] reason)
{
	PrintToChat(admin, "TeamBans_OnClientUnban_Post");
	PrintToChat(admin, "Admin: %d", admin);
	PrintToChat(admin, "Client: %d", client);
	PrintToChat(admin, "Team: %d", team);
	PrintToChat(admin, "Length: %d", length);
	PrintToChat(admin, "Reason: %s", reason);
}
