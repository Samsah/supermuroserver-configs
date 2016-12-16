/************************************************************************
*************************************************************************
Simple Plugins
Description:
	Included file for core plugin in the Simple Plugins project
*************************************************************************
*************************************************************************
This file is part of Simple Plugins project.

This plugin is free software: you can redistribute 
it and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the License, or
later version. 

This plugin is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this plugin.  If not, see <http://www.gnu.org/licenses/>.
*************************************************************************
*************************************************************************
File Information
$Id: simple-plugins.inc 58 2009-11-03 02:46:32Z antithasys $
$Author: antithasys $
$Revision: 58 $
$Date: 2009-11-02 20:46:32 -0600 (Mon, 02 Nov 2009) $
$LastChangedBy: antithasys $
$LastChangedDate: 2009-11-02 20:46:32 -0600 (Mon, 02 Nov 2009) $
$URL: https://svn.simple-plugins.com/svn/simpleplugins/trunk/Simple%20Plugins%20Core/addons/sourcemod/scripting/include/simple-plugins.inc $
$Copyright: (c) Simple Plugins 2008-2009$
*************************************************************************
*************************************************************************/

#if defined _simpleplugin_included
  #endinput
#endif

#define _simpleplugin_included

#define CORE_INC_VERSION "1.1.$Rev: 58 $"

#pragma semicolon 1
#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <adminmenu>
#define REQUIRE_PLUGIN
#undef REQUIRE_EXTENSIONS
#undef AUTOLOAD_EXTENSIONS
#tryinclude <cstrike>
#tryinclude <tf2>
#tryinclude <tf2_stocks>
#define AUTOLOAD_EXTENSIONS
#define REQUIRE_EXTENSIONS

enum e_SupportedMods
{
	GameType_Unknown,
	GameType_AOC,
	GameType_CSS,
	GameType_DOD,
	GameType_FF,
	GameType_HIDDEN,
	GameType_HL2DM,
	GameType_INS,
	GameType_L4D,
	GameType_L4D2,
	GameType_NEO,
	GameType_SGTLS,
	GameType_TF,
	GameType_ZPS
};

enum e_Teams
{
	Unknown,
	Spectator,
	Team1,
	Team2
};

new g_aCurrentTeams[e_Teams];
new e_SupportedMods:g_CurrentMod;
new String:g_sGameName[e_SupportedMods][32] = {	"Unknown",
																							"Age of Chivalry",
																							"Counter Strike",
																							"Day Of Defeat",
																							"Fortress Forever",
																							"Hidden: Source",
																							"Half Life 2: Deathmatch",
																							"Insurgency",
																							"Left 4 Dead",
																							"Left 4 Dead 2",
																							"Neotokyo",
																							"Stargate TLS",
																							"Team Fortress 2",
																							"Zombie Panic: Source"
																						};

public SharedPlugin:_pl_simpleplugin = 
{
	name = "simple-plugins",
	file = "simple-plugins.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public _pl_simpleplugin_SetNTVOptional()
{
	MarkNativeAsOptional("SM_MovePlayer");
	MarkNativeAsOptional("SM_SetForcedTeam");
	MarkNativeAsOptional("SM_GetForcedTeam");
	MarkNativeAsOptional("SM_ClearForcedTeam");
	MarkNativeAsOptional("SM_GetForcedPlayer");
	MarkNativeAsOptional("SM_AssignBuddy");
	MarkNativeAsOptional("SM_SearchBuddy");
	MarkNativeAsOptional("SM_LockBuddy");
	MarkNativeAsOptional("SM_IsBuddyLocked");
	MarkNativeAsOptional("SM_ClearBuddy");
	MarkNativeAsOptional("SM_IsValidAdmin");
	MarkNativeAsOptional("SM_IsValidTeam");
	MarkNativeAsOptional("SM_IsValidClient");
}
#endif

/**********************************************************************
 * When a player has to moved
 *
 * @param 		plugin		Plugin that initiated the move
 * @param 		client		The client index of the player that was moved
 * @param 		team		The team index the player was moved to
 * @noreturn		
 **********************************************************************/
forward SM_OnPlayerMoved(Handle:plugin, client, team);

/**********************************************************************
 * Move a player to the supplied team
 *
 * @param 		client		The client index of the player to be moved
 * @param 		team		The team to move the player to
 * @param 		respawn	Repsawn the player
 * @noreturn
 * @error							Invalid client or team index
 **********************************************************************/
native SM_MovePlayer(client, team, bool:respawn = true);

/**********************************************************************
 * Move a player to the supplied team
 *
 * @param 		client		The client index of the player to set
 * @param 		team		The team to move the to set
 * @param 		override	Whether or not to override another plugin
 * @return						True if successful, false if not
 * @error							Invalid client or team index
 **********************************************************************/
native SM_SetForcedTeam(client, team, bool:override = false);

/**********************************************************************
 * Gets the client's forced team index
 *
 * @param 		client		The client index of the player to check
 * @param 		plugin		Optional: The plugin handle of the plugin
										that set the team
 * @return						The team index of the forced team
										Zero if no forced team
 * @error							Invalid client index
 **********************************************************************/
native SM_GetForcedTeam(client, &Handle:plugin = INVALID_HANDLE);

/**********************************************************************
 * Clears a client's forced team
 *
 * @param 		client		The client index of the player to check
 * @return						True if successful, false if not
 * @error							Invalid client index
 **********************************************************************/
native SM_ClearForcedTeam(client);

/**********************************************************************
 * Gets a forced player on the wrong that is currently on the wrong team
 * This will only return a player if the calling plugin assigned the team
 *
 * @param 		team		The team index the player should be on
 * @return						The client index of the player
										Zero if no player found
 * @error							Invalid client index
 **********************************************************************/
native SM_GetForcedPlayer(team);

/**********************************************************************
 * Assign a players buddy
 *
 * @param 		client		The client index of the player to assign
 * @param 		player		The player index of the player to assign
 * @param 		override	Whether or not to override a player lock
 * @return						True if successful, false if not
 * @error							Invalid client or player index
 **********************************************************************/
native bool:SM_AssignBuddy(client, player, bool:override = false);

/**********************************************************************
 * Rturns the client's buddy
 *
 * @param 		client		The client index of the player to assign
 * @return						The client index of the player's buddy
										Zero if no buddy
 * @error							Invalid client index
 **********************************************************************/
native SM_GetClientBuddy(client);

/**********************************************************************
 * Set the buddy lock setting for a client
 *
 * @param 		client		The client index of the player to assign
 * @param 		setting		Setting to set, True or False
 * @return						True if successful, false if not
 * @error							Invalid client index
 **********************************************************************/
native bool:SM_LockBuddy(client, bool:setting);

/**********************************************************************
 * Returns the buddy lock setting for a client
 *
 * @param 		client		The client index of the player to assign
 * @return						True if locked, false if not
 * @error							Invalid client index
 **********************************************************************/
native bool:SM_IsBuddyLocked(client);

/**********************************************************************
 * Clear a players buddy
 *
 * @param 		client		The client index of the player to clear
 * @param 		override	Whether or not to override a player lock
 * @return						True if successful, false if not
 * @error							Invalid client index
 **********************************************************************/
native bool:SM_ClearBuddy(client, bool:override = false);

/**********************************************************************
 * Determine if the player has the supplied flags
 * ADMFLAG_ROOT will always return true
 *
 * @param 		client		The client index of the player to assign
 * @param 		flags			The char flag(s) to check against
 * @return						True if valid, false if not
 **********************************************************************/
native bool:SM_IsValidAdmin(client, const String:flags[]);


/**********************************************************************
 * Determine if the team is a valid team
 *
 * @param 		team		The team index to determine if valid for
										currently installed/supported mod
 * @return						True if valid, false if not
 **********************************************************************/
native bool:SM_IsValidTeam(team);

/**********************************************************************
 * Determine if the client is a valid connected and in game client
 *
 * @param 		client		The client index
 * @return						True if valid, false if not
 **********************************************************************/
native bool:SM_IsValidClient(client);


public e_SupportedMods:GetCurrentMod()
{
	new String:sGameType[64];
	GetGameFolderName(sGameType, sizeof(sGameType));
	
	if (StrEqual(sGameType, "aoc", false))
	{
		return GameType_AOC;
	}
	if (StrEqual(sGameType, "cstrike", false))
	{
		return GameType_CSS;
	}
	if (StrEqual(sGameType, "dod", false))
	{
		return GameType_DOD;
	}
	if (StrEqual(sGameType, "ff", false))
	{
		return GameType_FF;
	}
	if (StrEqual(sGameType, "hidden", false))
	{
		return GameType_HIDDEN;
	}
	if (StrEqual(sGameType, "hl2mp", false))
	{
		return GameType_FF;
	}
	if (StrEqual(sGameType, "insurgency", false) || StrEqual(sGameType, "ins", false))
	{
		return GameType_INS;
	}
	if (StrEqual(sGameType, "left4dead", false))
	{
		return GameType_L4D;
	}
	if (StrEqual(sGameType, "left4dead2", false))
	{
		return GameType_L4D2;
	}
	if (StrEqual(sGameType, "nts", false))
	{
		return GameType_NEO;
	}
	if (StrEqual(sGameType, "sgtls", false))
	{
		return GameType_SGTLS;
	}
	if (StrEqual(sGameType, "tf", false))
	{
		return GameType_TF;
	}
	if (StrEqual(sGameType, "zps", false))
	{
		return GameType_ZPS;
	}
	return GameType_Unknown;
}

public LoadCurrentTeams()
{
	switch (g_CurrentMod)
	{
		case GameType_INS:
		{
			g_aCurrentTeams[Unknown] = 0;
			g_aCurrentTeams[Spectator] = 3;
			g_aCurrentTeams[Team1] = 1;
			g_aCurrentTeams[Team2] = 2;
		}
		default:
		{
			g_aCurrentTeams[Unknown] = 0;
			g_aCurrentTeams[Spectator] = 1;
			g_aCurrentTeams[Team1] = 2;
			g_aCurrentTeams[Team2] = 3;
		}
	}
}
