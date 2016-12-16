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
 *	File: scripting/bounty/bounty.commands.sp
 *	SVN ID: $Id: bounty.commands.sp 22 2007-07-13 21:02:32Z bugs $
 *
 **/

public Action:Command_Bounty(client, args)
{
	if (client == 0)
	{
		return Plugin_Handled;	
	}
	
	if (!GetConVarBool(g_BountyCustom))
	{
		ReplyToCommand(client, "%c[BOUNTY]%c %t", GREEN, YELLOW, "Custom Bounty turned off");
		return Plugin_Handled;
	}
	
	if (args > 2)
	{
		ReplyToCommand(client, "%c[BOUNTY]%c Usage: sm_bounty [#userid|name] <amount>", GREEN, YELLOW);
		return Plugin_Handled;
	}
	if (args == 0) {
		Show_CurrentBounty(client);
		return Plugin_Handled;
	} else {
			
		new String:Amount[20];
		GetCmdArg(2, Amount, sizeof(Amount));
		
		new NewAmount;
		StringToIntEx(Amount, NewAmount);
		if ((NewAmount <= 0) || (NewAmount > 16000))
		{
			ReplyToCommand(client, "%c[BOUNTY]%c Usage: sm_bounty [#userid|name] <amount>", GREEN, YELLOW);
			return Plugin_Handled;
		}
		
		new String:User[50];
		GetCmdArg(1, User, sizeof(User));
			
		new Clients[2];
		new numClients = SearchForClients(User, Clients, 2);
		
		if (numClients == 0)
		{
			ReplyToCommand(client, "%c[BOUNTY]%c %t", GREEN, YELLOW, "No matching client");
			return Plugin_Handled;
		} else if (numClients > 1) {
			ReplyToCommand(client, "%c[BOUNTY]%c %t", GREEN, YELLOW, "More than one client matches");
			return Plugin_Handled;
		} else if (Clients[0] == client) {
			ReplyToCommand(client, "%c[BOUNTY]%c %t", GREEN, YELLOW, "Can not set Bounty on self");
			return Plugin_Handled;
		}
		
		new BountyUserId = Clients[0];
		
		if (GetClientTeam(BountyUserId) == GetClientTeam(client))
		{
			ReplyToCommand(client, "%c[BOUNTY]%c %t", GREEN, YELLOW, "Can not set Bounty on teammates");
			return Plugin_Handled;
		}
		
		new String:VictimName[255];
		new String:AttackerName[255];
		
		GetClientName(BountyUserId, VictimName, sizeof(VictimName));
		GetClientName(client, AttackerName, sizeof(AttackerName));
		
		new AttackerCash = GetPlayerCash(client);
		if (NewAmount > AttackerCash)
		{
			ReplyToCommand(client, "%c[BOUNTY]%c %t", GREEN, YELLOW, "Not enough cash for Bounty", NewAmount);
			return Plugin_Handled;
		}
		
		if (!CustomBounty[BountyUserId][client])
		{
			new NewCash = AttackerCash - NewAmount;
			SetPlayerCash(client, NewCash);
			
			CustomBounty[BountyUserId][client] = true;
			CurrentCustomBounty[BountyUserId][client] = NewAmount;
			
			for (new i = 1; i <= GetMaxClients(); i++)
		    {
			    if ((IsClientInGame(i)) && (!IsFakeClient(i)))
			    {
				    if (i == client) {
					    PrintCenterText(i, "%T", "You placed a custom Bounty", i, CurrentCustomBounty[BountyUserId][client], VictimName);
				    } else if (i == BountyUserId) {
					    PrintCenterText(i, "%T", "You have a custom Bounty on your head", i, AttackerName, CurrentCustomBounty[BountyUserId][client]);
				    } else {
					    PrintCenterText(i, "%T", "There was a custom Bounty placed", i, AttackerName, VictimName, CurrentCustomBounty[BountyUserId][client]);
				    }
				}
			}
		} else {
			new NewCash = AttackerCash - NewAmount;
			SetPlayerCash(client, NewCash);
			
			CurrentCustomBounty[BountyUserId][client] = CurrentCustomBounty[BountyUserId][client] + NewAmount;
			
			for (new i = 1; i <= GetMaxClients(); i++)
		    {
			    if ((IsClientInGame(i)) && (!IsFakeClient(i)))
			    {
				    if (i == client) {
					    PrintCenterText(i, "%T", "The custom Bounty was updated", i, CurrentCustomBounty[BountyUserId][client], VictimName);
				    } else if (i == BountyUserId) {
					    PrintCenterText(i, "%T", "The custom Bounty on your head was updated", i, AttackerName, CurrentCustomBounty[BountyUserId][client]);
				    } else {
					    PrintCenterText(i, "%T", "Someone updated the custom Bounty", i, AttackerName, VictimName, GetTotalBounty(BountyUserId, BountyType_Custom));
				    }
				}
			}
			
		}
	}
	return Plugin_Handled;
}