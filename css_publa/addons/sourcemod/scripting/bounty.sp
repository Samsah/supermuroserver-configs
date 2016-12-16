/**
 * ===============================================================
 * Bounty: A Comprehensive Bounty Script, Copyright (C) 2007
 * All rights reserved.
 * ===============================================================
 *
 *	This program is free software; you can redistribute it and/or
 *	modify it under the terms of the GNU General Public License
 *	as published by the Free Software Foundation; either version 2
 *	of the License, or (at your option) any later version.

 *	This program is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; w1ithout even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with this program; if not, write to the Free Software
 *	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 *	To view the latest information, see: http://forums.alliedmods.net/showthread.php?t=56939
 *		Author(s):	Shane A. ^BuGs^ Froebel - Current maintainer
 *					FlyingMongoose - Started the Sourcemod script/Idea man
 *					stoic - Worked on what FlyingMongoose started
 *
 *	Credit: #sourcemod on irc.gamesurge.com (teame06, Olly)
 *	Original Idea and concepts of Bounty made by:	firesnake´s Bounty Mod 
 *													Pascal257 Remake of firesnake's
 *	
 *	About:
 *
 *	This script will set a bounty on a player or bot
 *	if they keep killing without them dieing. You as a player
 *	can also set a bounty on any player on the oppisiate team,
 *	including bots. Bot can not set a custom bounty on users, yet.
 *	
 *	If you set a bounty on someone and you kill them,
 *	you get your bounty back in full. If you kill someone that has
 *	more than one bounty, you get all of the bounties and if you set one,
 *	yours will still be returned. You must have money to
 *	set a custom bounty. It must be a vaild non-float number: 1 through 16000 
 *	
 *	E.g.:	100.50 is not vaild
 *			1000.34 is not vaild
 *			5632 is vaild
 *			0 is not vaild
 *			16001 is not vaild
 *	
 *	
 *	If a user switchs a team, you get your 	money back also.
 *	However, a streak bounty is not reset.
 *	
 *	If you kill someone who has a bounty and it's a headshot,
 *	you get the full bounty plus what ever percent of that total bounty
 *	was for.
 *	
 *	You can still only get max to $16,000. No more.
 *	
 *	These are the default coded settings:
 *	
 *	Streak: 4 kills
 *	Base Bounty: $1,000
 *	Increased After base: $250
 *	Round Increased Bounty: $500
 *	Hostage Bounty: Off
 *	Hostage Bounty Ammount per Hostage: $500
 *	
 *	Head shot bouns: 30%
 *	
 *	CVARS:
 *
 *	sm_bounty_status - 1/0 - To Enable/Disable the whole script
 *	sm_bounty_custom - 1/0 - To Enable/Disable Custom Bounty's
 *
 *
 *	ATTENTION TRANSLATORS:
 *	
 *	Submit translations to the bug reporting site. Thanks. Do not
 *	post them in the forums.	
 *	
 *	Use at your OWN risk! Please submit your changes of this
 *	script to Shane. Known issues/Submit bug reports at:
 *	
 *		http://bugs.alliedmods.net/?project=9&do=index
 *	
 *	Thanks...                 
 *		-- Shane A. Froebel
 *		-- FlyingMongoose
 *		-- stoic
 *              
 *
 *	sm_bounty [#userid|name] <amount>
 *	sm_bounty - Bring up GUI to show all current bounties you can get.
 *
 *	File: scripting/bounty.sp
 *	SVN ID: $Id: bounty.sp 64 2007-07-22 17:18:19Z bugs $
 *		
 **/

#pragma semicolon 1
#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <ads>
#include <ircrelay>

#define BOUNTY_VERSION "1.0.9.0"
#define BUILDD __DATE__
#define BUILDT __TIME__

#include "bounty/bounty.inc"
#include "bounty/bounty.config.sp"
#include "bounty/bounty.hl2overides.sp"
#include "bounty/bounty.gui.sp"
#include "bounty/bounty.commands.sp"
#include "bounty/bounty.hooks.sp"
#include "bounty/bounty.publicfunctions.sp"
#include "bounty/bounty.irc.sp"

/*****************************************************************
*                      BASE INFORMATION                          * 
******************************************************************/

public Plugin:myinfo =
{
	name = "Bounty",
	author = "Shane A. ^BuGs^ Froebel, FlyingMongoose, and stoic",
	description = "A Comprehensive Bounty Script",
	version = BOUNTY_VERSION,
	url = "http://bugssite.org"
}

public OnPluginStart() 
{
	LoadTranslations("common.phrases");
	LoadTranslations("plugin.bounty");
	
	g_Bounty = CreateConVar("sm_bounty_status", "1", "Enabled/Disabled Bounty Plugin.", FCVAR_PLUGIN);
	g_BountyCustom = CreateConVar("sm_bounty_custom", "1", "Enabled/Disabled Custom Bounty.", FCVAR_PLUGIN);
	g_BountyBuild = CreateConVar("sm_bounty_buildversion", SOURCEMOD_VERSION, "The version of 'Bounty' was built on.", FCVAR_PLUGIN);
	g_BountyVersion = CreateConVar("sm_bounty_version", BOUNTY_VERSION, "The version of 'Bounty' running.", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	HookConVarChange(g_Bounty, BountyChange);
	
	g_MoneyOffset = FindSendPropOffs("CCSPlayer","m_iAccount");
	
	if (g_MoneyOffset == -1)
	{
		decl String:Error[PLATFORM_MAX_PATH + 64];
		FormatEx(Error, sizeof(Error), "[BOUNTY] FATAL *** ERROR *** Can not find m_iAccount.");
		SetFailState(Error);
	}
	
	FwdNewSection = CreateGlobalForward("_ConfigNewSection", ET_Ignore, Param_String);
	FwdKeyValue = CreateGlobalForward("_ConfigKeyValue", ET_Ignore, Param_String, Param_String);
	FwdEnd = CreateGlobalForward("_ConfigEnd", ET_Ignore);
	
	RegConsoleCmd("sm_bounty", Command_Bounty, "sm_bounty [#userid|name] <amount>");
	
	CreateTimer(1.0, OnPluginStart_Delayed);
	
}

public Action:OnPluginStart_Delayed(Handle:timer)
{
	if(!HookEventEx("player_death", Event_PlayerDeath, EventHookMode_Pre))
	{
		decl String:Error[PLATFORM_MAX_PATH + 64];
		FormatEx(Error, sizeof(Error), "[BOUNTY] FATAL *** ERROR *** Could not load hook: player_death");
		SetFailState(Error);
	}
	if(!HookEventEx("player_team", Event_PlayerTeam, EventHookMode_Pre))
	{
		decl String:Error[PLATFORM_MAX_PATH + 64];
		FormatEx(Error, sizeof(Error), "[BOUNTY] FATAL *** ERROR *** Could not load hook: player_team");
		SetFailState(Error);
	}
	if(!HookEventEx("hostage_killed", Event_HostageKilled, EventHookMode_Pre))
	{
		decl String:Error[PLATFORM_MAX_PATH + 64];
		FormatEx(Error, sizeof(Error), "[BOUNTY] FATAL *** ERROR *** Could not load hook: hostage_killed");
		SetFailState(Error);
	}
	if(!HookEventEx("round_end", Event_RoundEnd, EventHookMode_Pre))
	{
		decl String:Error[PLATFORM_MAX_PATH + 64];
		FormatEx(Error, sizeof(Error), "[BOUNTY] FATAL *** ERROR *** Could not load hook: round_end");
		SetFailState(Error);
	}
}

public BountyChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(GetConVarInt(g_Bounty) != 1)
	{
		BountyConsole_Server("Bounty turned off.");
	} else {
		BountyConsole_Server("Bounty turned on.");
	}
}

public CustomBountyChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(GetConVarInt(g_BountyCustom) != 1)
	{
		BountyConsole_Server("Custom Bounty turned off.");
	} else {
		BountyConsole_Server("Custom Bounty turned on.");
	}
}


public BountyConsole_Debug(String:text[], any:...)
{
	if (EnabledBountyDebug)
	{
		new String:message[255];
		VFormat(message, sizeof(message), text, 2);
		PrintToServer("[BOUNTY DEBUG] %s", message);
	}	
}

public BountyConsole_Server(String:text[], any:...)
{
	new String:message[255];
	VFormat(message, sizeof(message), text, 2);
	PrintToServer("[BOUNTY] %s", message);
}