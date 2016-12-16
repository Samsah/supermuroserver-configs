/**
* Jointeam Control by Root
*
* Description:
*   Adds more feautres to default 'jointeam' command.
*
* Version 1.0
* Changelog & more info at http://goo.gl/4nKhJ
*/

// Due to usage of ChangeClientTeam native
#include <sdktools_functions>

// ====[ CONSTANTS ]=======================================================================
#define PLUGIN_NAME    "Jointeam Control"
#define PLUGIN_VERSION "1.0"
#define TEAM_SPECTATOR 1

// ====[ VARIABLES ]=======================================================================
new	Handle:mp_limitteams     = INVALID_HANDLE,
	Handle:jointeam_immunity = INVALID_HANDLE,
	Handle:jointeam_silent   = INVALID_HANDLE,
	jointeam_override, bool:IsChangedTeam[MAXPLAYERS + 1];

// ====[ PLUGIN ]==========================================================================
public Plugin:myinfo =
{
	name        = PLUGIN_NAME,
	author      = "Root",
	description = "Adds more feautres to default 'jointeam' command",
	version     = PLUGIN_VERSION,
	url         = "forums.alliedmods.net/showthread.php?p=1911371"
}


/* OnPluginStart()
 *
 * When the plugin starts up.
 * ---------------------------------------------------------------------------------------- */
public OnPluginStart()
{
	// Create console variables
	CreateConVar("sm_jointeam_control", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);
	jointeam_immunity = CreateConVar("sm_jointeam_immunity", "z", "If flag is specified (a-z), users with that flag will able to change team without any restrictions",       FCVAR_PLUGIN);
	jointeam_silent   = CreateConVar("sm_jointeam_silent",   "0", "Whether or not suppress a message when player changed team (ex. 'Player is joining the Terrorist force')", FCVAR_PLUGIN, true, 0.0, true, 1.0);

	// Since 'jointeam' command is exists in most games, use AddCommandListener instead of Reg*Cmd
	AddCommandListener(OnJoinTeam, "jointeam");

	// Retrieve default console variable
	mp_limitteams = FindConVar("mp_limitteams");

	// Hook events
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);
	HookEvent("player_team",  OnTeamChange,  EventHookMode_Pre);

	AutoExecConfig();
}

/* OnClientDisconnect(client)
 *
 * When a client disconnects from the server.
 * ---------------------------------------------------------------------------------------- */
public OnClientDisconnect_Post(client)
{
	// Reset boolean when player disconnects from server
	IsChangedTeam[client] = false;
}

/* OnJoinTeam()
 *
 * Called when player is changing his team.
 * ---------------------------------------------------------------------------------------- */
public Action:OnJoinTeam(client, const String:command[], numArgs)
{
	if (IsClientInGame(client) && numArgs >= 1)
	{
		// Get desired team using argument and retrieve the flag from "sm_jointeam_immunity" cvar
		decl String:arg[8], String:admflag[AdminFlags_TOTAL];
		GetCmdArg(1, arg, sizeof(arg));
		GetConVarString(jointeam_immunity, admflag, sizeof(admflag));

		// Converts a string of flag characters to a bit string
		jointeam_override = ReadFlagString(admflag);

		// Since 'jointeam' args is only a values, make it safer anyway
		new desiredTeam = StringToInt(arg);

		// We want to allow admins to avoid any restrictions - so check access
		if (jointeam_override != 0 && CheckCommandAccess(client, "jointeam_override", jointeam_override, true))
		{
			// mp_limitteams restriction? more players in desired team? unlimited amount of team changes? No please
			ChangeClientTeam(client, desiredTeam);
			IsChangedTeam[client] = false;
		}

		// Auto assign team index is 0, so ignore team changing
		if (desiredTeam < TEAM_SPECTATOR) return Plugin_Continue;

		// Block if opposite team has more players (or same) than in your team + value of mp_limitteams ConVar
		if (GetTeamClientCount(desiredTeam) >= GetTeamClientCount(GetOtherTeam(desiredTeam)) + GetProperValue(client))
			return Plugin_Handled;

		// Since spectators can change teams more than once, block team change
		if (bool:IsChangedTeam[client] == true
		&& GetClientTeam(client) > TEAM_SPECTATOR)
		{
			// Notify client when team was changed previously until respawn
			PrintCenterText(client, "Only 1 team change is allowed");
			return Plugin_Handled;
		}
		else if (desiredTeam != GetClientTeam(client))
		{
			// Change client's team and dont allow to change it again until new respawn (shitty cooldown)
			ChangeClientTeam(client, desiredTeam);
			IsChangedTeam[client] = true;
		}
	}

	return Plugin_Handled;
}

/* OnPlayerSpawn()
 *
 * Called after a player spawns.
 * ---------------------------------------------------------------------------------------- */
public OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Let allow client to change teams again
	IsChangedTeam[GetClientOfUserId(GetEventInt(event, "userid"))] = false;
}

/* OnTeamChange()
 *
 * Called when a player changes team.
 * ---------------------------------------------------------------------------------------- */
public Action:OnTeamChange(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarBool(jointeam_silent)) SetEventBroadcast(event, true);
}

/* GetOtherTeam()
 *
 * Retrieves another team index.
 * ---------------------------------------------------------------------------------------- */
GetOtherTeam(team)
{
	// Returns team index as 3 if opposite team is 2, otherwise it returns 2
	return team == 2 ? 3 : 2;
}

/* GetProperValue()
 *
 * Gets proper value for simulate mp_limitteams.
 * ---------------------------------------------------------------------------------------- */
GetProperValue(client)
{
	// If player is not a spectator, divide himself from 'current team mates count' to calculate mp_limitteams stuff
	return (GetClientTeam(client) > TEAM_SPECTATOR) ? (GetConVarInt(mp_limitteams) - 1) : GetConVarInt(mp_limitteams);
}