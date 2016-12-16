#include <sourcemod>
#include <cstrike>
#include <sdkhooks>
#include <smlib>
#include <timer>
#include <timer-mapzones>
#include <timer-physics>
#include <timer-config_loader>

new Handle:g_hFF;

new bool:g_bHeadshot[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name        = "[TIMER] MapZones - Damage Controller",
	author      = "Zipcore, Credits: Alongub, DR. API Improvements",
	description = "[Timer] Damage controller with pvp zones",
	version     = PL_VERSION,
	url         = "forums.alliedmods.net/showthread.php?p=2074699"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegPluginLibrary("timer-mapzones_damage_controller");
	
	return APLRes_Success;
}

public OnPluginStart()
{
	LoadTimerSettings();
	LoadPhysics();
	
	g_hFF = FindConVar("mp_friendlyfire");
	
	HookEvent("player_death", Event_Player_Death, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn);
}

/***********************************************************/
/************************ PLUGIN END ***********************/
/***********************************************************/
public void OnPluginEnd()
{
	int i = 1;
	while(i <= MaxClients)
	{
		if(IsClientInGame(i))
		{
			SDKUnhook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
			SDKUnhook(i, SDKHook_TraceAttack, Hook_OnTraceAttack);
		}
		i++;
	}
}

public OnMapStart()
{
	LoadTimerSettings();
	LoadPhysics();	
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	SDKHook(client, SDKHook_TraceAttack, Hook_OnTraceAttack);
}

public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	SDKUnhook(client, SDKHook_TraceAttack, Hook_OnTraceAttack);
}


public Action:Hook_OnTraceAttack(victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
	if(victim && victim <= MaxClients)
		g_bHeadshot[victim] = (hitgroup == 1) ? true : false;
	
	return Plugin_Continue;
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	g_bHeadshot[client] = false;
}

public Action:Event_Player_Death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if(!attacker || attacker == client)
		return Plugin_Changed;

	if (g_bHeadshot[client])
	{
		decl String:weapon[64];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		
		new Handle:new_event = CreateEvent("player_death");
		if (new_event == INVALID_HANDLE)
		{
			return Plugin_Continue;
		}
		
		SetEventInt(new_event, "userid", GetClientUserId(client));
		SetEventInt(new_event, "attacker", GetClientUserId(attacker));
		SetEventString(new_event, "weapon", weapon);
		SetEventBool(new_event, "headshot", true);
		g_bHeadshot[client] = false;
		FireEvent(new_event);
		return Plugin_Changed;
	}
	return Plugin_Continue;
} 

public Action:Hook_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	new style_victim = Timer_GetStyle(victim);

	//World damage
	if (attacker == 0 || attacker >= MaxClients)
	{
		new style = Timer_GetStyle(victim);

		//Allow world damage
		if(g_Physics[style][StyleAllowWorldDamage])
			return Plugin_Continue;

		//Remove punsish angle and prevent damage
		RemovePunchAngle(victim);
		return Plugin_Handled;
	}

	//Player vs. player damage
	if(Client_IsValid(attacker, true) && IsClientInGame(attacker) && IsPlayerAlive(attacker))
	{
		new style_attacker = Timer_GetStyle(attacker);

		//Allow damage for PvP styles
		if(g_Physics[style_victim][StylePvP] && g_Physics[style_attacker][StylePvP])
			return Plugin_Continue;

		//Allow damage inside PvP zones
		if(Timer_IsPlayerTouchingZoneType(victim, ZtArena) && Timer_IsPlayerTouchingZoneType(attacker, ZtArena))
			return Plugin_Continue;
	}

	//Godmode
	if (g_Settings[Godmode])
	{
		//Remove punsish angle and prevent damage
		RemovePunchAngle(victim);
		return Plugin_Handled;
	}

	//Friendly fire
	if(GetClientTeam(victim) == GetClientTeam(attacker))
	{
		if(GetConVarBool(g_hFF))
			return Plugin_Continue;

		//Remove punsish angle and prevent damage
		RemovePunchAngle(victim);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

stock RemovePunchAngle(client)
{
	if(GetGameMod() == MOD_CSS)
	{
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngle", NULL_VECTOR);
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngleVel", NULL_VECTOR);
	}
}
