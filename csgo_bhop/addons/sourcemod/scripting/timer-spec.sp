#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <smlib>
#include <timer>
#include <timer-mapzones>

public Plugin:myinfo ={
    name        = "[TIMER] Spectate",
    author      = "Zipcore, Jason Bourne, DR. API Improvements",
    description = "[Timer] Provides afk commands",
    version     = PL_VERSION,
    url         = "forums.alliedmods.net/showthread.php?p=2074699"
};

public OnPluginStart()
{	
	RegConsoleCmd("sm_spec", Command_spec, "sm_spec <target> - Spectates a player.");
	RegConsoleCmd("sm_spectate", Command_spec, "sm_spectate <target> - Spectates a player.");
	RegConsoleCmd("sm_specmost", Cmd_SpecMost);
	RegConsoleCmd("sm_speclist", Cmd_SpecList);
	RegConsoleCmd("sm_specfar", Cmd_SpecFar);
	LoadTranslations("common.phrases");
}

public Action:Command_spec(client, args)
{
	if (args == 0)
	{
		if (IsPlayerAlive(client) && IsClientInGame(client))
		{
			ChangeClientTeam(client, 1);
		}
	}
	if (args == 1)
	{
		if (IsPlayerAlive(client) && IsClientInGame(client))
		{
			ChangeClientTeam(client, 1);
		}
		new String:arg1[64];
		GetCmdArgString(arg1, sizeof(arg1));
		
		new target = FindTarget(client, arg1, true, true);
		if (target == -1) 
		{
			return Plugin_Handled;
		}
		if (IsClientInGame(target))
		{
			if (!IsPlayerAlive(target))
			{
				ReplyToCommand(client, "[SM] %t", "Target must be alive");
				return Plugin_Handled;
			}
			SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", target);
			SetEntProp(client, Prop_Send, "m_iObserverMode", 4);
		}
		if (!IsClientInGame(target)) ReplyToCommand(client, "[SM] %t", "Target is not in game");
	}
	return Plugin_Handled;
}

public Action:Cmd_SpecMost(client, args)
{
	new Mostspectators = 0, spectators = 0, target;

	for(new i = 1; i <= MaxClients; i++)
	{
		if(i == client)
			continue;
		
		spectators = 0;	
		
		if(Client_IsValid(i, true))
		{
			for(new x = 1; x <= MaxClients; x++)
			{
				if(!IsClientInGame(x) || !IsClientObserver(x))
				{
					continue;
				}
					
				new SpecMode = GetEntProp(x, Prop_Send, "m_iObserverMode");
				
				if(SpecMode == 4 || SpecMode == 5)
				{
					if(GetEntPropEnt(x, Prop_Send, "m_hObserverTarget") == target)
					{
						spectators++;
					}
				}
			}
			if(spectators >= Mostspectators)
			{
				target = i;
				spectators = Mostspectators;
			}
		}
	}

	ChangeClientTeam(client, 1);
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", target);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 4);

	return Plugin_Handled;
}

public Action:Cmd_SpecList(client, args)
{
	new spectators = 0, String:buffer[1024];

	for(new i = 1; i <= MaxClients; i++)
	{
		if(i == client)
			continue;
		
		if(Client_IsValid(i, true))
		{
			// missing check for IsClientInGame in Client_IsValid?
			if(IsClientInGame(i))
			{
				new SpecMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
				
				if(SpecMode == 4 || SpecMode == 5)
				{
					if(GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") == client)
					{
						spectators++;
						if(spectators > 1) Format(buffer, sizeof(buffer), "%s, %N", buffer, i);
						else Format(buffer, sizeof(buffer), "%N", i);
					}
				}
			}
		}
	}

	if(spectators > 0) 
	{
		PrintToChat(client, "[SPEC-LIST] You have %d spectators:", spectators);
		PrintToChat(client, "%s.", buffer);
	}
	else PrintToChat(client, "[SPEC-LIST] Nobody is spectating you.");

	return Plugin_Handled;
}

public Action:Cmd_SpecFar(client, args)
{
	new MaxLevel, Level, target, oldtarget;

	oldtarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(i == client)
			continue;
		
		if(i == oldtarget)
			continue;
		
		if(!Client_IsValid(i, true))
			continue;
		
		Level = Timer_GetClientLevel(i);
		
		if(Level > MaxLevel)
		{
			MaxLevel = Level;
			target = i;
		}
	}

	ChangeClientTeam(client, 1);
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", target);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 4);

	return Plugin_Handled;
}
