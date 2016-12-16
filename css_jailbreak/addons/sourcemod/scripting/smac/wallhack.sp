/*
	SourceMod Anti-Cheat Wallhack Module
	Copyright (C) 2011 GoD-Tony
	Copyright (C) 2011 Nicholas "psychonic" Hastings (nshastings@gmail.com)
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

#define POINT_ALMOST_VISIBLE 0.75
#define POINT_MID_VISIBLE 0.6
#define TEAM_UNASSIGNED 0
#define TEAM_SPECTATOR  1

// Note: if this gets re-enabled for Insurgency, spec team is different
#define PROCESS_PLAYER_TEAM(%1) (g_iPlayerTeam[%1] != TEAM_UNASSIGNED && g_iPlayerTeam[%1] != TEAM_SPECTATOR)

//- Global Variables -//

new bool:g_bAntiWall = false;
new Handle:g_hCVarAntiWall = INVALID_HANDLE;
new bool:g_bIsVisible[MAXPLAYERS+1][MAXPLAYERS+1];
new bool:g_bShouldProcess[MAXPLAYERS+1];
new bool:g_bHooked[MAXPLAYERS+1];
new bool:g_bTeamChangeHooked;
new g_iPlayerTeam[MAXPLAYERS+1];
new bool:g_bAntiWallDisabled = true;
new Float:g_vClientPos[MAXPLAYERS+1][3];
new Float:g_vClientEye[MAXPLAYERS+1][3];
new Float:g_vClientAngles[MAXPLAYERS+1][3];
new Float:g_fTickTime;
new g_iVelOff;
new g_iBaseVelOff;
new g_iWeaponOwner[MAX_EDICTS];

//- Plugin Functions -//

Wallhack_OnPluginStart()
{
	HookEvent("player_spawn", Wallhack_PlayerSpawn);
	
	if (g_Game == Game_GMOD)
		HookEvent("entity_killed", Wallhack_EntityKilled);
	else
		HookEvent("player_death", Wallhack_PlayerDeath);
		
	g_bTeamChangeHooked = HookEventEx("player_team", Wallhack_PlayerTeam);
	g_fTickTime = GetTickInterval();

	g_bAntiWallDisabled = false;

	g_hCVarAntiWall = CreateConVar("smac_wallhack", "0", "Enable Anti-Wallhack. This may have high CPU usage on large servers.", FCVAR_PLUGIN);

	Wallhack_AntiWallChange(g_hCVarAntiWall, "", "");
	HookConVarChange(g_hCVarAntiWall, Wallhack_AntiWallChange);	
}

//- Clients -//

Wallhack_OnClientPutInServer(client)
{
	if ( !g_bAntiWallDisabled && g_iVelOff < 1 )
	{
		g_iVelOff = GetEntSendPropOffs(client, "m_vecVelocity[0]");
		g_iBaseVelOff = GetEntSendPropOffs(client, "m_vecBaseVelocity");

		if ( g_iVelOff == -1 || g_iBaseVelOff == -1 )
		{
			g_bAntiWallDisabled = true;
			g_bAntiWall = false;
			LogError("Anti-Wallhack: Failed to find offsets for client %i", client);
		}
	}
}

//- Hooks -//

public Wallhack_AntiWallChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new bool:f_bEnabled = GetConVarBool(convar);

	if ( f_bEnabled == g_bAntiWall )
		return;

	if ( f_bEnabled )
	{
		if ( !g_bSDKHooksLoaded )
		{
			LogError("SDKHooks is not running.  Cannot enable Anti-Wall.");
			SetConVarInt(convar, 0);
			return;
		}
		
		if ( !g_bTeamChangeHooked )
		{
			LogError("Game has no player_team event.  Cannot enable Anti-Wall.");
			SetConVarInt(convar, 0);
			return;
		}
		
		if ( MaxClients > 24 )
			SMAC_Log("Warning: The Anti-Wallhack module can be very CPU intensive on servers with a large amount of players.");
			
		for(new i=1;i<=MaxClients;i++)
			if ( g_bInGame[i] && IsPlayerAlive(i) && PROCESS_PLAYER_TEAM(i) && !g_bHooked[i] )
				Wallhack_Hook(i);
	}
	else
	{
		for(new i=1;i<=MaxClients;i++)
			if ( g_bHooked[i] )
				Wallhack_Unhook(i);
	}
	g_bAntiWall = f_bEnabled;
}

public Wallhack_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if ( client && GetClientTeam(client) > 1 )
	{
		new bool:bProcessTeam = PROCESS_PLAYER_TEAM(client);
		if ( !g_bIsFake[client] && bProcessTeam )
			g_bShouldProcess[client] = true;
		if ( g_bAntiWall && !g_bHooked[client] && bProcessTeam )
			Wallhack_Hook(client);
	}
}

public Wallhack_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if ( client )
	{
		g_bShouldProcess[client] = false;
		if ( g_bAntiWall && g_bHooked[client] )
			Wallhack_Unhook(client);
	}
}

public Wallhack_EntityKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetEventInt(event, "entindex_killed");
	if ( 1 <= client <= MaxClients )
	{
		g_bShouldProcess[client] = false;
		if ( g_bAntiWall && g_bHooked[client] )
			Wallhack_Unhook(client);
	}
}

public Action:Wallhack_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if ( client )
	{
		g_iPlayerTeam[client] = GetEventInt(event, "team");
	}
}

// Weapon stuff

public OnEntityCreated(entity, const String:classname[])
{
	if ( !g_bAntiWallDisabled && entity > MaxClients && entity < MAX_EDICTS )
		g_iWeaponOwner[entity] = 0;
}

public OnEntityDestroyed(entity)
{
	if ( !g_bAntiWallDisabled && entity > MaxClients && entity < MAX_EDICTS )
		g_iWeaponOwner[entity] = 0;
}

public Action:Wallhack_WeaponTransmit(entity, client)
{
	if ( !g_bAntiWall || client < 1 || client > MaxClients || g_bIsVisible[g_iWeaponOwner[entity]][client] )
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action:Wallhack_Equip(client, weapon)
{
	if ( g_iWeaponOwner[weapon] == 0 )
	{
		g_iWeaponOwner[weapon] = client;
		SDKHook(weapon, SDKHook_SetTransmit, Wallhack_WeaponTransmit);
	}
}

public Action:Wallhack_Drop(client, weapon)
{
	if ( weapon > -1 && g_iWeaponOwner[weapon] != 0 )
	{
		g_iWeaponOwner[weapon] = 0;
		SDKUnhook(weapon, SDKHook_SetTransmit, Wallhack_WeaponTransmit);
	}
}

// Back to it.

Wallhack_OnPlayerRunCmd(client, Float:angles[3])
{
	if ( !g_bAntiWall )
		return;
	
	g_vClientAngles[client][0] = angles[0];
	g_vClientAngles[client][1] = angles[1];
	g_vClientAngles[client][2] = angles[2];
}

public OnGameFrame()
{
	if ( !g_bAntiWall )
		return;

	decl Float:f_vVelocity[3], Float:f_vTempVec[3];
	
	for(new i=1;i<=MaxClients;i++)
	{
		if ( g_bHooked[i] )
		{
			GetEntDataVector(i, g_iVelOff, f_vVelocity);
			if ( GetEntityFlags(i) & FL_BASEVELOCITY )
			{
				GetEntDataVector(i, g_iBaseVelOff, f_vTempVec);
				AddVectors(f_vVelocity, f_vTempVec, f_vVelocity);
			}
			ScaleVector(f_vVelocity, g_fTickTime);
			GetClientEyePosition(i, f_vTempVec);
			AddVectors(f_vTempVec, f_vVelocity, g_vClientEye[i]);
			GetClientAbsOrigin(i, f_vTempVec);
			AddVectors(f_vTempVec, f_vVelocity, g_vClientPos[i]);
			ChangeEdictState(i, g_iVelOff); // Mark as changed so we cause SetTransmit to be called but we don't cause a full update.
		}
	}
}

public Action:Wallhack_Transmit(entity, client)
{
	if ( client < 1 || client > MaxClients )
		return Plugin_Continue;

	if ( entity == client || !g_bShouldProcess[client] || g_iPlayerTeam[entity] == g_iPlayerTeam[client] )
	{
		g_bIsVisible[entity][client] = true;
		return Plugin_Continue;
	}

	decl Float:f_vEyePos[3], Float:f_vTargetOrigin[3];
	f_vEyePos = g_vClientEye[client];
	f_vTargetOrigin = g_vClientPos[entity];

	// Ignore all checks if the client is facing the opposite direction.
	if ( !IsInFieldOfView(f_vEyePos, g_vClientAngles[client], f_vTargetOrigin) )
	{
		g_bIsVisible[entity][client] = false;
		return Plugin_Handled;
	}
	
	if ( IsInRange(f_vEyePos, f_vTargetOrigin) )
	{
		// If origin is visible don't worry about doing the rest of the calculations.
		if ( TR_GetFraction() > POINT_MID_VISIBLE )
		{
			g_bIsVisible[entity][client] = true;
			return Plugin_Continue;
		}

		// Around Origin
		f_vTargetOrigin[0] += 60.0;

		if ( IsPointAlmostVisible(f_vEyePos, f_vTargetOrigin) )
		{
			g_bIsVisible[entity][client] = true;
			return Plugin_Continue;
		}

		f_vTargetOrigin[1] += 60.0;

		if ( IsPointAlmostVisible(f_vEyePos, f_vTargetOrigin) )
		{
			g_bIsVisible[entity][client] = true;
			return Plugin_Continue;
		}

		f_vTargetOrigin[0] -= 120.0;

		if ( IsPointAlmostVisible(f_vEyePos, f_vTargetOrigin) )
		{
			g_bIsVisible[entity][client] = true;
			return Plugin_Continue;
		}

		f_vTargetOrigin[1] -= 120.0;

		if ( IsPointAlmostVisible(f_vEyePos, f_vTargetOrigin) )
		{
			g_bIsVisible[entity][client] = true;
			return Plugin_Continue;
		}

		f_vTargetOrigin[1] += 90.0;

		// Top of head
		f_vTargetOrigin[2] += 90.0;

		if ( IsPointAlmostVisible(f_vEyePos, f_vTargetOrigin) )
		{
			g_bIsVisible[entity][client] = true;
			return Plugin_Continue;
		}

		// Around head
		f_vTargetOrigin[0] += 60.0;

		if ( IsPointAlmostVisible(f_vEyePos, f_vTargetOrigin) )
		{
			g_bIsVisible[entity][client] = true;
			return Plugin_Continue;
		}

		f_vTargetOrigin[1] += 60.0;

		if ( IsPointAlmostVisible(f_vEyePos, f_vTargetOrigin) )
		{
			g_bIsVisible[entity][client] = true;
			return Plugin_Continue;
		}

		f_vTargetOrigin[0] -= 120.0;

		if ( IsPointAlmostVisible(f_vEyePos, f_vTargetOrigin) )
		{
			g_bIsVisible[entity][client] = true;
			return Plugin_Continue;
		}

		f_vTargetOrigin[1] -= 120.0;

		if ( IsPointAlmostVisible(f_vEyePos, f_vTargetOrigin) )
		{
			g_bIsVisible[entity][client] = true;
			return Plugin_Continue;
		}

		f_vTargetOrigin[1] += 90.0;

		// Bottom of feet.
		f_vTargetOrigin[2] -= 180.0;

		if ( IsPointAlmostVisible(f_vEyePos, f_vTargetOrigin) )
		{
			g_bIsVisible[entity][client] = true;
			return Plugin_Continue;
		}
	}

	g_bIsVisible[entity][client] = false;
	return Plugin_Handled;
}

//- Trace Filter -//

public bool:Wallhack_TraceFilter(entity, mask)
{
	return entity > MaxClients;
}

//- Private Functions -//

stock bool:IsInFieldOfView(const Float:origin[3], const Float:angles[3], const Float:end[3])
{
	decl Float:normal[3], Float:plane[3];
	
	GetAngleVectors(angles, normal, NULL_VECTOR, NULL_VECTOR);
	SubtractVectors(end, origin, plane);
	ScaleVector(plane, (1.0 / GetVectorLength(plane)));
	
	if (GetVectorDotProduct(plane, normal) < 0)
		return false;
	
	return true;
}

stock bool:IsInRange(const Float:start[3], const Float:end[3])
{
	TR_TraceRayFilter(start, end, MASK_OPAQUE, RayType_EndPoint, Wallhack_TraceFilter);

	return TR_GetFraction() > 0.0;
}

stock bool:IsPointAlmostVisible(const Float:start[3], const Float:end[3])
{
	TR_TraceRayFilter(start, end, MASK_OPAQUE, RayType_EndPoint, Wallhack_TraceFilter);

	return TR_GetFraction() > POINT_ALMOST_VISIBLE;
}

stock bool:IsPointVisible(const Float:start[3], const Float:end[3])
{
	TR_TraceRayFilter(start, end, MASK_OPAQUE, RayType_EndPoint, Wallhack_TraceFilter);

	return TR_GetFraction() == 1.0;
}

Wallhack_Hook(client)
{
	g_bHooked[client] = true;
	SDKHook(client, SDKHook_SetTransmit, Wallhack_Transmit);
	SDKHook(client, SDKHook_WeaponEquip, Wallhack_Equip);
	SDKHook(client, SDKHook_WeaponDrop, Wallhack_Drop);
}

Wallhack_Unhook(client)
{
	g_bHooked[client] = false;
	SDKUnhook(client, SDKHook_SetTransmit, Wallhack_Transmit);
	SDKUnhook(client, SDKHook_WeaponEquip, Wallhack_Equip);
	SDKUnhook(client, SDKHook_WeaponDrop, Wallhack_Drop);
}
