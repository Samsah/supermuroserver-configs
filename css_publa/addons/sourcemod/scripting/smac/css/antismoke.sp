/*
	SourceMod Anti-Cheat AntiSmoke Module
	Copyright (C) 2011 GoD-Tony
	Copyright (C) 2007-2011 CodingDirect LLC

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#define SMOKE_FADETIME	15.0	// Seconds until a smoke begins to fade away
#define SMOKE_RADIUS	2500	// (50^2) Radius to check for a player inside a smoke cloud

//- Global Variables -//

new Handle:g_hCVarAntiSmoke = INVALID_HANDLE;
new bool:g_bSmokeEnabled;
new bool:g_bSmokeHooked;

new Handle:g_hSmokeLoop = INVALID_HANDLE;
new Handle:g_hSmokes = INVALID_HANDLE;
new bool:g_bIsInSmoke[MAXPLAYERS+1];

//- Plugin Functions -//

AntiSmoke_OnPluginStart()
{
	if (g_Game != Game_CSS)
		return;
		
	g_hCVarAntiSmoke = CreateConVar("smac_css_antismoke", "1", "(CS:S Only) Prevent No-Smoke cheats from working when a player is immersed in smoke");
	
	AntiSmoke_CvarChange(g_hCVarAntiSmoke, "", "");
	HookConVarChange(g_hCVarAntiSmoke, AntiSmoke_CvarChange);
}

AntiSmoke_OnMapEnd()
{
	if (g_bSmokeHooked)
		AntiSmoke_UnhookAll();
}

AntiSmoke_OnClientDisconnect(client)
{
	g_bIsInSmoke[client] = false;
}

public AntiSmoke_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new bool:bNewValue = GetConVarBool(convar);

	if (bNewValue && !g_bSmokeEnabled)
	{
		if (!g_bSDKHooksLoaded)
		{
			LogError("SDKHooks is not running. Cannot enable CS:S Anti-Smoke.");
			SetConVarBool(convar, false);
			return;
		}
		
		AntiSmoke_Enable();
	}
	else if (!bNewValue && g_bSmokeEnabled)
	{
		AntiSmoke_Disable();
	}
}

public AntiSmoke_SmokeDetonate(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl Float:vSmoke[3];
	vSmoke[0] = GetEventFloat(event, "x");
	vSmoke[1] = GetEventFloat(event, "y");
	vSmoke[2] = GetEventFloat(event, "z");
	
	PushArrayArray(g_hSmokes, vSmoke);
	
	if (!g_bSmokeHooked)
		AntiSmoke_HookAll();
	
	CreateTimer(SMOKE_FADETIME, AntiSmoke_SmokeEndTimer);
}

public AntiSmoke_RoundEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	/* Smokes disappear when a round starts or ends. */
	if (g_bSmokeHooked)
		AntiSmoke_UnhookAll();
	
	ClearArray(g_hSmokes);
}

public Action:AntiSmoke_SmokeEndTimer(Handle:timer)
{
	/* If this was the last active smoke, unhook everything. */
	if (GetArraySize(g_hSmokes))
		RemoveFromArray(g_hSmokes, 0);
	
	if (!GetArraySize(g_hSmokes) && g_bSmokeHooked)
		AntiSmoke_UnhookAll();
	
	return Plugin_Stop;
}

public Action:AntiSmoke_Loop(Handle:timer)
{
	/**
	* Check if a player is immersed in a smoke.
	* This may look intense, but it's only running <10% of the time compared to OnGameFrame.
	*/
	decl Float:vClient[3], Float:vSmoke[3], Float:fDistance;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (g_bInGame[i] && !g_bIsFake[i] && IsPlayerAlive(i))
		{
			GetClientAbsOrigin(i, vClient);
			
			for (new idx = 0; idx < GetArraySize(g_hSmokes); idx++)
			{
				GetArrayArray(g_hSmokes, idx, vSmoke);
				fDistance = GetVectorDistance(vClient, vSmoke, true);
				
				if (fDistance < SMOKE_RADIUS)
				{
					g_bIsInSmoke[i] = true;
					break;
				}
				
				g_bIsInSmoke[i] = false;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:AntiSmoke_Transmit(entity, client)
{
	/* Don't send client data to players that are immersed in smoke. */
	if (client < 1 || client > MaxClients || entity == client)
		return Plugin_Continue;
	
	if (g_bIsInSmoke[client])
		return Plugin_Handled;
	
	return Plugin_Continue;
}

AntiSmoke_Enable()
{
	g_bSmokeEnabled = true;
	g_hSmokes = CreateArray(3);
	HookEvent("smokegrenade_detonate", AntiSmoke_SmokeDetonate, EventHookMode_Post);
	HookEvent("round_start", AntiSmoke_RoundEvent, EventHookMode_PostNoCopy);
	HookEvent("round_end", AntiSmoke_RoundEvent, EventHookMode_PostNoCopy);
}

AntiSmoke_Disable()
{
	g_bSmokeEnabled = false;
	CloseHandle(g_hSmokes);
	UnhookEvent("smokegrenade_detonate", AntiSmoke_SmokeDetonate, EventHookMode_Post);
	UnhookEvent("round_start", AntiSmoke_RoundEvent, EventHookMode_PostNoCopy);
	UnhookEvent("round_end", AntiSmoke_RoundEvent, EventHookMode_PostNoCopy);
}

AntiSmoke_HookAll()
{
	g_bSmokeHooked = true;
	
	if (g_hSmokeLoop == INVALID_HANDLE)
		g_hSmokeLoop = CreateTimer(0.1, AntiSmoke_Loop, _, TIMER_REPEAT);
	
	for (new i = 1; i <= MaxClients; i++)
		if (g_bInGame[i])
			SDKHook(i, SDKHook_SetTransmit, AntiSmoke_Transmit);
}

AntiSmoke_UnhookAll()
{
	g_bSmokeHooked = false;
	
	if (g_hSmokeLoop != INVALID_HANDLE)
	{
		KillTimer(g_hSmokeLoop);
		g_hSmokeLoop = INVALID_HANDLE;
	}

	for (new i = 1; i <= MaxClients; i++)
		if (g_bInGame[i])
			SDKUnhook(i, SDKHook_SetTransmit, AntiSmoke_Transmit);
}

//- EoF -//
