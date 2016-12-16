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
 *	File: scripting/bounty/bounty.hl2overides.sp
 *	SVN ID: $Id: bounty.hl2overides.sp 22 2007-07-13 21:02:32Z bugs $
 *
 **/

public OnClientPutInServer(client)
{
	HostageBountySet[client] = false;
	HostageBountyValue[client] = 0;
	for (new i = 1; i <= GetMaxClients(); i++)
    {
		CustomBounty[client][i] = false;
		CurrentCustomBounty[client][i] = 0;
    }
	KillingStreak[client] = 0;
	CurrentBounty[client] = 0;
}


public OnMapEnd()
{
	for (new i = 1; i <= GetMaxClients(); i++)
    {
		HostageBountySet[i] = false;
		HostageBountyValue[i] = 0;
		for (new o = 1; o <= GetMaxClients(); o++)
	    {
			CustomBounty[i][o] = false;
			CurrentCustomBounty[i][o] = 0;
	    }
    }
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		KillingStreak[i] = 0;
		CurrentBounty[i] = 0;
	}
}

public OnClientDisconnect(client)
{
	ReturnCustomBounty(client);
	KillingStreak[client] = 0;
	CurrentBounty[client] = 0;
}