/*
	SourceMod Anti-Cheat Speedhack Module
	Copyright (C) 2011 GoD-Tony

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

//- Global Variables -//

new Handle:g_hCVarSpeedhack = INVALID_HANDLE;
new Handle:g_hCVarFutureTicks = INVALID_HANDLE;
new bool:g_bSpeedEnabled, bool:g_bCheckTicks;

new Handle:g_hTickLoop = INVALID_HANDLE;
new g_iTickRate, g_iTickCount[MAXPLAYERS+1];

//- Plugin Functions -//

Speedhack_OnPluginStart()
{
	g_hCVarSpeedhack = CreateConVar("smac_speedhack", "1", "Prevent speedhacks from working on your server.", FCVAR_PLUGIN);
	g_hCVarFutureTicks = FindConVar("sv_max_usercmd_future_ticks");
	
	Speedhack_CvarChange(g_hCVarSpeedhack, "", "");
	HookConVarChange(g_hCVarSpeedhack, Speedhack_CvarChange);
	
	// The server's tickrate * 1.25 as a buffer zone.
	g_iTickRate = RoundToCeil(1.0 / GetTickInterval() * 1.25);
}

public Speedhack_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new bool:bNewValue = GetConVarBool(convar);
	
	if (bNewValue && !g_bSpeedEnabled)
		Speedhack_Enable();
	else if (!bNewValue && g_bSpeedEnabled)
		Speedhack_Disable();
}

public Speedhack_TickCvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (GetConVarInt(convar) != 1)
		SetConVarInt(convar, 1);
}

public Action:Speedhack_ResetTicks(Handle:timer)
{
	for (new i = 1; i <= MaxClients; i++)
		g_iTickCount[i] = 0;
	
	return Plugin_Continue;
}

Action:Speedhack_OnPlayerRunCmd(client)
{
	if (!g_bCheckTicks)
		return Plugin_Continue;
	
	if (g_iTickCount[client]++ > g_iTickRate) // Speedhack detected.
		return Plugin_Handled; 
	
	return Plugin_Continue;
}

Speedhack_Enable()
{
	g_bSpeedEnabled = true;
	
	if (g_hCVarFutureTicks != INVALID_HANDLE)
	{
		Speedhack_TickCvarChange(g_hCVarFutureTicks, "", "");
		HookConVarChange(g_hCVarFutureTicks, Speedhack_TickCvarChange);
	}
	else if (g_hTickLoop == INVALID_HANDLE)
	{
		g_bCheckTicks = true;
		g_hTickLoop = CreateTimer(1.0, Speedhack_ResetTicks, _, TIMER_REPEAT);
	}
}

Speedhack_Disable()
{
	g_bSpeedEnabled = false;
	
	if (g_hCVarFutureTicks != INVALID_HANDLE)
	{
		UnhookConVarChange(g_hCVarFutureTicks, Speedhack_TickCvarChange);
	}
	else if (g_hTickLoop != INVALID_HANDLE)
	{
		g_bCheckTicks = false;
		KillTimer(g_hTickLoop);
		g_hTickLoop = INVALID_HANDLE;
	}
}
