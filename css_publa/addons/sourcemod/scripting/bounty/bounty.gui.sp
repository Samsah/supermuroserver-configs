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
 *	File: scripting/bounty/bounty.gui.sp
 *	SVN ID: $Id: bounty.gui.sp 22 2007-07-13 21:02:32Z bugs $
 *
 **/

public Show_CurrentBounty(client)
{
	new bool:b;
	new bool:s;
	new bool:c;
	
	new Handle:item = CreatePanel();
	
	new String:BountyGUI[255];
	
	Format(BountyGUI, sizeof(BountyGUI), "%t", "Bounty GUI header");
	
	SetPanelTitle(item, BountyGUI);
	
	b = false;
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if ((IsClientInGame(i)) && (GetClientTeam(i) != GetClientTeam(client)))
		{
			s = false;
			c = false;
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
				new RealBounty = GetTotalBounty(i, BountyType_Streak);
				if (c)
				{
					new CustomBountyTotal = GetTotalBounty(i, BountyType_Custom);
					Format(Line, sizeof(Line), "%s %t $%i ($%i %t)", ClientName, "Bounty GUI worth", RealBounty, CustomBountyTotal, "Bounty GUI custom service");
				}
				if (s) {
					Format(Line, sizeof(Line), "%s %t $%i", ClientName, "Bounty GUI worth", RealBounty);
				}
				DrawPanelText(item, Line);
				
			}
		}
	}
	
	if (b)
	{
		SendPanelToClient(item, client, PanelEmpty, 10);
		CloseHandle(item);
	} else {
		CloseHandle(item);
		PrintToChat(client, "%c[BOUNTY]%c %t", GREEN, YELLOW, "Bounty GUI no active Bounty");
	}
}

public PanelEmpty(Handle:menu, MenuAction:action, parm1, parm2)
{
	if (action == MenuAction_End)
	{
		//	Nothing... just an empty function.
	}	
}

/*
	ToDo:
		* Sourcemod Admin I/O GUI
*/