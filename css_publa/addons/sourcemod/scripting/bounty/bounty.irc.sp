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
 *	File: scripting/bounty/bounty.irc.sp
 *	SVN ID: $Id: bounty.irc.sp 54 2007-07-16 07:12:20Z bugs $
 *
 **/

public Irc_ViewBounty()
{
	new bool:b = false;
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if (IsClientInGame(i))
		{
			new s = false;
			new c = false;
			if (KillingStreak[i] >= StreakMin)
			{
				b = true;
				s = true;
			}
			for (new o = 1; o <= GetMaxClients(); o++)
			{
				if (CustomBounty[i][o]) {
					b = true;
					c = true;
				}
			}
			if ((b) && ((c) || (s)))
			{
				new String:Line[255];
				new String:ClientName[255];
				GetClientName(i, ClientName, sizeof(ClientName));
				
				new RealBountyTotal = GetTotalBounty(i, BountyType_Streak);
				
				if (c)
				{
					new CustomBountyTotal = GetTotalBounty(i, BountyType_Custom);
					Format(Line, sizeof(Line), "%s %T $%i ($%i %T)", ClientName, "Bounty GUI worth", RealBountyTotal, CustomBountyTotal, "Bounty GUI custom service");
					
				}
				if (s) {
					Format(Line, sizeof(Line), "%s %T $%i", ClientName, "Bounty GUI worth", RealBountyTotal);
				}
				if ((BountyIRC) && (plugin_IrcRelay))
				{
					IrcMessage(CHAN_MASTER, Line);
				}	
			}
		}
	}
	if ((!b) && (BountyIRC) && (plugin_IrcRelay))
	{
		IrcMessage(CHAN_MASTER, "[BOUNTY] %T", "Bounty GUI no active Bounty");
	}
}