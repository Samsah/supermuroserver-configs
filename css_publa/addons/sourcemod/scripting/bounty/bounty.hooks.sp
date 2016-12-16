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
 *	File: scripting/bounty/bounty.hooks.sp
 *	SVN ID: $Id: bounty.hooks.sp 58 2007-07-16 20:01:27Z bugs $
 *
 **/

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarBool(g_Bounty))
	{
		new VictimUserid = GetEventInt(event, "userid");
		new AttackerUserid = GetEventInt(event, "attacker");
		
		new Victim = GetClientOfUserId(VictimUserid);
		new Attacker = GetClientOfUserId(AttackerUserid);
		
		new bool:Headshot = GetEventBool(event, "headshot");
		
		if ((!Victim) || (!Attacker))
		{
			return Plugin_Continue;
		}
	
		if ((GetClientTeam(Victim) != GetClientTeam(Attacker)) && (Victim != Attacker))
		{
			if (GetConVarBool(g_BountyCustom))
			{
				CheckCustomBounty(Victim, Attacker, Headshot);
			}
			
			if (HostageEnabled)
			{
				CheckHostageBounty(Victim, Attacker);
			}
			
			if (KillingStreak[Victim] >= StreakMin)
			{
				BountyMade(Attacker, Victim, Headshot);
			}
			
			KillingStreak[Victim] = 0;
			KillingStreak[Attacker]++;
			
			if (KillingStreak[Attacker] >= StreakMin)
			{
				if (KillingStreak[Attacker] == StreakMin)
				{
					AddOnToBounty(Attacker, BaseBounty, Bounty_New);
				} else {
					AddOnToBounty(Attacker, IncressedBounty, Bounty_Updated);
				}	
			}
		}
	}
	return Plugin_Continue;
}

public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarBool(g_Bounty))
	{
		new Userid = GetEventInt(event, "userid");
		new client = GetClientOfUserId(Userid);
		new NewTeamid = GetEventInt(event, "team");
		
		if (NewTeamid != 0)
		{
			if (PlayerOldTeam[client] != NewTeamid)
			{
				if (NewTeamid != 1)
				{
					ReturnCustomBounty(client);
				}
			}
			PlayerOldTeam[client] = NewTeamid;
		}
	}
}

public Action:Event_HostageKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarBool(g_Bounty))
	{
		new Userid = GetEventInt(event, "userid");
		new client = GetClientOfUserId(Userid);
		
		if (HostageEnabled)
		{
			HostageBountySet[client] = true;
			HostageBountyValue[client]++;
			
			AnnouceBounty(client, Bounty_Hostage);
			
		}
	}
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarBool(g_Bounty))
	{
		for (new i = 1; i <= GetMaxClients(); i++)
		{
			if ((IsClientInGame(i)) && (!IsClientObserver(i)))
			{
				TotalBounty = 0;
				if (KillingStreak[i] >= StreakMin)
				{
					AddOnToBounty(i, RoundIncressedBounty, Bounty_None);
					TotalBounty = GetTotalBounty(i, BountyType_Total);
				}
				if (GetConVarBool(g_BountyCustom))
				{
					if (TotalBounty > 0)
					{
						PrintToChat(i, "%c[BOUNTY]%c %t", GREEN, YELLOW, "Round ended with custom Bounty", TotalBounty);
					}
				} else {
					if (TotalBounty > 0)
					{
						PrintToChat(i, "%c[BOUNTY]%c %t", GREEN, YELLOW, "Round ended for Bounty", TotalBounty);
					}
				}
			}
		}
	}
}