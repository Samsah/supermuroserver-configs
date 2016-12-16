#include <cstrike>
#include <sdktools>
#include <colors>

#define MESS "\x03[Warden] \x01%t"
#define Commander_VERSION   "1.5"

new bool:commanderExist = false;
new commander;
new String:game[] = "NotAtGameAtAll";

public OnPluginStart() {
	LoadTranslations("Warden.phrases");
	RegAdminCmd("sm_rc", command_removewarden, ADMFLAG_GENERIC);
	RegConsoleCmd("sm_w", command_Warden);
	RegConsoleCmd("sm_warden", command_Warden);
	RegConsoleCmd("sm_uw", command_UnWarden);
	RegConsoleCmd("sm_unwarden", command_UnWarden);
	HookEvent("round_start", roundStart);
	HookEvent("player_death", playerDeath);
	HookEvent("player_disconnect", playerDisconnect);
	CreateConVar("sm_warden_version", "1.5", "Jail warden Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	RegConsoleCmd("say", Command_Say);
}

public Plugin:myinfo = {
	name = "Warden Jailbreak script",
	author = "ecca",
	description = "Jailbreak Warden script",
	version = Commander_VERSION,
	url = "ecca@hotmail.se"
};

public Action:command_Warden(client, args) 
{
	if(!commanderExist) {
	if(GetClientTeam(client) == CS_TEAM_CT && IsPlayerAlive(client)) {
	CPrintToChatAll(MESS, "BecomeWarden", client);
	CPrintToChatAll(MESS, "BecomeWarden", client);
	commanderExist = true;
	commander = client;
	SetEntityRenderColor(client, 0, 0, 255, 255);
	SetClientListeningFlags(client, VOICE_NORMAL);
	}
	else {
	CPrintToChatAll(MESS, "WrongTeamOrAlive", client);
		}
	}
	else {
	CPrintToChatAll(MESS, "WardenAlreadyExist", client);
	}
}

public Action:command_UnWarden(client, args) 
{
	if(commander == client) {
	CPrintToChatAll(MESS, "LeftWarden", client);
	commanderExist = false;
	commander = -1;
	SetEntityRenderColor(client, 255, 255, 255, 255);
	if(!StrEqual(game, "NoUn")) {
	game = "NotAtGameAtAll"
		}
	}
}

public Action:roundStart(Handle:event, const String:name[], bool:dontBroadcast) 
{
	commanderExist = false;
	commander = -1;
	for(new i = 1; i <= MaxClients; i++)
	{
	SetEntityRenderColor(i, 255, 255, 255, 255);
	}
	game = "NotAtGameAtAll";
}

public Action:playerDeath(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	if(client == commander) {
	CPrintToChatAll(MESS, "WardenDied", client);
	commanderExist = false;
	commander = -1;
	SetEntityRenderColor(client, 255, 255, 255, 255);
	if(!StrEqual(game, "NoUn")) {
	game = "NotAtGameAtAll"
		}
	}
}

public Action:playerDisconnect(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	if(client == commander) {
	CPrintToChatAll(MESS, "WardenDisconnected", client);
	commanderExist = false;
	commander = -1;
	SetEntityRenderColor(client, 255, 255, 255, 255);
	if(!StrEqual(game, "NoUn")) {
	game = "NotAtGameAtAll"
		}
	}
}

public Action:command_removewarden(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[Warden] Usage: sm_rw <player>");
		return Plugin_Handled;
	}
	
		
	decl String:arg[32];
	GetCmdArg(1, arg, sizeof(arg));
	
	new target = FindTarget(client, arg);
	
	if( target > 0 && target <= MaxClients )
	{
		new String:user[64];
		GetClientName(target,user,sizeof(user));
		
		decl String:steamid[64];
		GetClientAuthString(target, steamid, sizeof(steamid));
		
		new String:admin[64];
		GetClientName(client,admin,sizeof(user));
		
		decl String:adminsteamid[64];
		GetClientAuthString(target, adminsteamid, sizeof(steamid));
	
		CPrintToChatAll(MESS, "RemoveWarden", user, steamid, admin, adminsteamid);
		
		commanderExist = false;
		commander = -1;
	}
	return Plugin_Handled;
}

public Action:Command_Say(client, args) {
	decl String:steamid[64];
	GetClientAuthString(client, steamid, sizeof(steamid));
	if(commander == client) {
	new String:message[512];
	new String:name[50];
	GetClientName(client, name, 50);
	GetCmdArg(1, message, sizeof(message));
	if(message[0] == '/')
	return Plugin_Handled;
	if(!IsPlayerAlive(client) && GetClientTeam(client) == CS_TEAM_CT) {
	PrintToChatAll("\x03[Warden] \x01%s: %s", name, message);
	return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}