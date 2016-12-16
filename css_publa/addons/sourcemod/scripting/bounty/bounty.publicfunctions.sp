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
 * 	File: scripting/bounty/bounty.publicfunctions.sp
 *	SVN ID: $Id: bounty.publicfunctions.sp 55 2007-07-16 07:13:13Z bugs $
 *
 **/

public BountyMade(attacker, victim, bool:headshot)
{
	new String:AttackerName[255];
	new String:VictimName[255];
	GetClientName(attacker, AttackerName, sizeof(AttackerName));
	GetClientName(victim, VictimName, sizeof(VictimName));
	
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if ((IsClientInGame(i)) && (!IsFakeClient(i)))
		{
			TotalBounty = GetTotalBounty(victim, BountyType_Streak);
			if (i == attacker) {
				if (headshot)
				{
					PrintCenterText(i, "%T", "You have collected a Bounty via headshot", i, CalcHeadShot(TotalBounty, headshot), VictimName);
				} else {
					PrintCenterText(i, "%T", "You have collected a Bounty", i, TotalBounty, VictimName);
				}
			} else if (i == victim) {
				PrintCenterText(i, "%T", "The Bounty has been collected on you", i, TotalBounty, AttackerName);
			} else {
				PrintCenterText(i, "%T", "The Bounty has been made", i, AttackerName, TotalBounty, VictimName);
			}
		}
	}
	//	Money Givien to attacker
	new AttackerCash = GetPlayerCash(attacker);
	new NewCash = AttackerCash + CalcHeadShot(TotalBounty, headshot);
	SetPlayerCash(attacker, NewCash);
	CurrentBounty[victim] = 0;
}

public CheckHostageBounty(victim, attacker)
{
	if (HostageBountySet[victim])
	{
		new String:VictimName[255];
		GetClientName(victim, VictimName, sizeof(VictimName));
		
		TotalBounty = GetTotalBounty(victim, BountyType_Hostage);
		
		PrintCenterText(attacker, "%T", "You have collected a hostage Bounty", attacker, VictimName, TotalBounty);
	
		new AttackerCash = GetPlayerCash(attacker);
		new NewCash = AttackerCash + TotalBounty;
		SetPlayerCash(attacker, NewCash);
				
		HostageBountySet[victim] = false;
		HostageBountyValue[victim] = 0;
	}
}


public AnnouceBounty(client, Bounty:g_Type)
{
	new String:AttackerName[255];
	GetClientName(client, AttackerName, sizeof(AttackerName));

	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if ((IsClientInGame(i)) && (!IsFakeClient(i)))
		{
			if (g_Type == Bounty_Hostage)
			{
				TotalBounty = GetTotalBounty(client, BountyType_Hostage);
				if (i == client) {
				    PrintCenterText(i, "%T", "You have a hostage Bounty", i, TotalBounty, HostageBountyValue[client]);
				} else {
				    PrintCenterText(i, "%T", "There is a hostage Bounty", i, AttackerName, TotalBounty, HostageBountyValue[client]);
				}
			} else {
				TotalBounty = GetTotalBounty(client, BountyType_Streak);
				if (g_Type == Bounty_New)
				{
					if (i == client) {
					    PrintCenterText(i, "%T", "There is a new Bounty on your head", i, TotalBounty);
					} else {
					    PrintCenterText(i, "%T", "There is a new Bounty", i, AttackerName, TotalBounty);
					}
				}
				if (g_Type == Bounty_Updated)
				{
					if (i == client) {
						PrintCenterText(i, "%T", "Your Bounty has been updated", i, TotalBounty);
					} else {
						PrintCenterText(i, "%T", "The Bounty has been updated on this person", i, AttackerName, TotalBounty);
					}
				}
				if (g_Type == Bounty_Mega)
				{
					if (i != client) {
						PrintCenterText(i, "%T", "You have a mega Bounty", i, AttackerName, TotalBounty);
					}
				}
			}
		}
	}
}

//	There has got to be a better way to do this.
public CheckCustomBounty(client, attacker, bool:headshot)
{
	new bool:f = false;
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if ((IsClientInGame(i)) && (!IsFakeClient(i)))
		{
			if ((CustomBounty[client][i]) && (attacker != i))
			{
								
				new AttackerCash = GetPlayerCash(attacker);
				new NewCash;
							
				if (!HeadshotEnabledCustom)
				{
					NewCash = AttackerCash + CurrentCustomBounty[client][i];
				} else {
					NewCash = AttackerCash + CalcHeadShot(CurrentCustomBounty[client][i], headshot);
				}
				
				SetPlayerCash(attacker, NewCash);
				
				if (!f)
				{
					f = true;
					new String:VictimName[255];
					GetClientName(client, VictimName, sizeof(VictimName));
					PrintCenterText(attacker, "%T", "You collected the custom Bounty", attacker, GetTotalBounty(client, BountyType_Custom), VictimName);
				}
			
				CustomBounty[client][i] = false;
				CurrentCustomBounty[client][i] = 0;
				
			} else if ((CustomBounty[client][i]) && (attacker == i)) {
			
				new AttackerCash = GetPlayerCash(i);
				new NewCash = AttackerCash + CurrentCustomBounty[client][i];
				SetPlayerCash(i, NewCash);
				
				new String:VictimName[255];
				GetClientName(client, VictimName, sizeof(VictimName));
				PrintCenterText(attacker, "%T", "The custom Bounty you placed was returned", attacker, CurrentCustomBounty[client][i], VictimName);
				
				CustomBounty[client][i] = false;
				CurrentCustomBounty[client][i] = 0;
			}
	    }
    }
}

public GetTotalBounty(client, BountyType:g_Type)
{
	switch (g_Type)
	{
		case BountyType_Streak: {
						
			return CurrentBounty[client];	
		}	
		case BountyType_Custom: {
			new total;
			for (new i = 1; i <= GetMaxClients(); i++)
		    {
			    total = total + CurrentCustomBounty[client][i];
			}
			return total;
		}
		case BountyType_Hostage: {
			new total;
			total = HostageBountyValue[client]*HostageBounty;
			return total;				
		}
		case BountyType_Total: {
			new s = GetTotalBounty(client, BountyType_Streak);
			new c = GetTotalBounty(client, BountyType_Custom);
			return s+c;
		}
	}
	return 0;
}

public AddOnToBounty(client, value, Bounty:g_Type)
{
	if (CurrentBounty[client] >= 16000)
	{
		AnnouceBounty(client, Bounty_Mega);
		return false;
	}
	CurrentBounty[client] = CurrentBounty[client] + value;
	if (g_Type != Bounty_None)
	{	
		AnnouceBounty(client, g_Type);
	}
	return true;
}

public CalcHeadShot(value, bool:headshot)
{
	if (!HeadshotEnabled)
	{
		return value;
	}
	if (!headshot)
	{
		return value;	
	}
	new String:tempvalue[20];
	new Float:newvalue;
	
	IntToString(value, tempvalue, sizeof(tempvalue));
	newvalue = ((StringToFloat(tempvalue)*HeadshotBonus)+StringToFloat(tempvalue));
	FloatToString(newvalue, tempvalue, sizeof(tempvalue));
	
	return StringToInt(tempvalue);
}

public ReturnCustomBounty(client)
{
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if (IsClientInGame(i))
		{
			if (CustomBounty[client][i])
			{
				new ReturnCash = GetPlayerCash(i);
				BountyConsole_Debug("Current Cash: %i", ReturnCash); 
				new NewCash = ReturnCash + CurrentCustomBounty[client][i];
				BountyConsole_Debug("Math Op: %i + %i = %i", ReturnCash, CurrentCustomBounty[client][i], NewCash);
				
				SetPlayerCash(i, NewCash);
				
				new String:VictimName[255];
				GetClientName(client, VictimName, sizeof(VictimName));
				PrintCenterText(i, "%T", "The custom Bounty you placed was returned because it is now invaild", i, CurrentCustomBounty[client][i], VictimName);
			
				CustomBounty[client][i] = false;
				CurrentCustomBounty[client][i] = 0;		
			}
		}
	}	
}

public GetPlayerCash(entity)
{
	return GetEntData(entity, g_MoneyOffset);
}

public SetPlayerCash(entity, amount)
{
	if (amount > 16000)
	{
		SetEntData(entity, g_MoneyOffset, 16000, _, true);
	} else {
		SetEntData(entity, g_MoneyOffset, amount, _, true);
	}
}