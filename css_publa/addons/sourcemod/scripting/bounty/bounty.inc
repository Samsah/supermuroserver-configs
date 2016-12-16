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
 *  				FlyingMongoose - Started the Sourcemod script/Idea man
 *					stoic - Worked on what FlyingMongoose started
 *
 *	Credit: #sourcemod on irc.gamesurge.com (teame06, Olly)
 *	Original Idea and concepts of Bounty made by:	firesnake´s Bounty Mod 
 *													Pascal257 Remake of firesnake's
 *
 *
 * 	File: scripting/bounty/bounty.inc
 *	SVN ID: $Id: bounty.inc 64 2007-07-22 17:18:19Z bugs $
 *
 **/

#define YELLOW               0x01
#define NAME_TEAMCOLOR       0x02
#define TEAMCOLOR            0x03
#define GREEN                0x04

enum Bounty
{
	Bounty_None = 0,
	Bounty_New = 1,
	Bounty_Updated = 2,
	Bounty_Mega = 3,
	Bounty_Hostage = 4,
};

enum BountyType
{
	BountyType_Streak = 0,
	BountyType_Custom = 1,
	BountyType_Hostage = 2,
	BountyType_Total = 3,
};

enum State
{
	CONFIG_STATE_NONE,
	CONFIG_STATE_CONFIG,
};

new g_MoneyOffset;

new Handle:g_Bounty;
new Handle:g_BountyCustom;
new Handle:g_BountyBuild;
new Handle:g_BountyVersion;

new Handle:ConfigParser = INVALID_HANDLE;
new Handle:FwdNewSection = INVALID_HANDLE;
new Handle:FwdKeyValue = INVALID_HANDLE;
new Handle:FwdEnd = INVALID_HANDLE;

new State:ConfigState;

new ConfigCount;
new ParseCount;

new KillingStreak[MAXPLAYERS + 1];
new CurrentBounty[MAXPLAYERS + 1];

new bool:CustomBounty[MAXPLAYERS + 1][MAXPLAYERS + 1];
new CurrentCustomBounty[MAXPLAYERS + 1][MAXPLAYERS + 1];
new bool:HostageBountySet[MAXPLAYERS + 1];
new HostageBountyValue[MAXPLAYERS + 1];

new PlayerOldTeam[MAXPLAYERS + 1];

new bool:BountyIRC;
new bool:BountyIRCLoaded;
new StreakMin;
new BaseBounty;
new IncressedBounty;
new RoundIncressedBounty;
new TotalBounty;
new bool:HeadshotEnabled;
new bool:HeadshotEnabledCustom;
new bool:HostageEnabled;
new HostageBounty;
new Float:HeadshotBonus;
new bool:BountyAds;
new bool:EnabledBountyDebug;


new bool:plugin_Ads;
new bool:plugin_IrcRelay;