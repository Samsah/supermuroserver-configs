#define PLUGIN_VERSION "1.0.1"

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <adminmenu>
#include <clientprefs>
#include <colors>

//Cvars
#define CVAR_COUNT 3
#define CVAR_ENABLED 0
#define CVAR_SCOUT_HEADSHOT 1
#define CVAR_SCOUT_DAMAGE 2

//Random damage for the scout headshot nerf, divided by 4.0
#define SCOUT_MIN_DAMAGE 14.0
#define SCOUT_MAX_DAMAGE 19.75

//CS:S Hitgroups
#define HITGROUP_BODY 0
#define HITGROUP_HEAD 1
#define HITGROUP_CHEST 2
#define HITGROUP_STOMACH 3
#define HITGROUP_ARM_LEFT 4
#define HITGROUP_ARM_RIGHT 5
#define HITGROUP_LEG_LEFT 6
#define HITGROUP_LEG_RIGHT 7

new Handle:g_hCvar[CVAR_COUNT] = { INVALID_HANDLE, ... };
new bool:g_bLateLoad, bool:g_bScoutHeadshot;
new Float:g_fScoutDamage;

new bool:g_bScouted[MAXPLAYERS + 1];
new bool:g_bHeadshot[MAXPLAYERS + 1];
	
public Plugin:myinfo =
{
	name = "[SM] proppi Extras", 
	author = "", 
	description = "Provides custom gameplay features for BuildWars.",
	version = PLUGIN_VERSION, 
	url = "http://supermuroserver.com"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("sm_buildwars_v3.phrases");

	g_hCvar[CVAR_SCOUT_HEADSHOT] = CreateConVar("sm_buildwars_scout_nerf_headshot", "1", "If enabled, the scout will be unable to perform headshots (they will count as torso shots). (0 = Disabled, 1 = Enabled)", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_SCOUT_HEADSHOT], OnSettingsChange);
	g_hCvar[CVAR_SCOUT_DAMAGE] = CreateConVar("sm_buildwars_scout_nerf_damage", "0.8", "The percent nerf applied to all scout damage. (1.0 = 100 Attack, 0.5 = 50% Attack)", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvar[CVAR_SCOUT_DAMAGE], OnSettingsChange);

	HookEvent("player_hurt", Event_OnPlayerHurt, EventHookMode_Pre);
}

public OnMapStart()
{
	Void_SetDefaults();
}

public OnConfigsExecuted()
{
	if(g_bLateLoad)
	{
		Void_SetDefaults();
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				SDKHook(i, SDKHook_TraceAttack, Hook_OnTraceAttack);
			}
		}

		g_bLateLoad = false;
	}
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_TraceAttack, Hook_OnTraceAttack);
}

public Action:Event_OnPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client && IsClientInGame(client))
	{
		if(g_bScouted[client])
		{
			g_bScouted[client] = false;

			if(g_bHeadshot[client])
			{
				g_bHeadshot[client] = false;

				SetEventInt(event, "hitgroup", HITGROUP_CHEST);
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:Hook_OnTraceAttack(victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
	if(attacker && attacker <= MaxClients && IsClientInGame(attacker))
	{
		decl String:_sBuffer[64];
		new _iWeapon = GetEntPropEnt(attacker, Prop_Data, "m_hActiveWeapon");
		if(_iWeapon > 0)
		{
			GetEdictClassname(_iWeapon, _sBuffer, sizeof(_sBuffer));
			if(StrEqual(_sBuffer, "weapon_scout"))
			{
				g_bScouted[victim] = true;
				if(g_bScoutHeadshot && hitgroup == HITGROUP_HEAD)
				{
					g_bHeadshot[victim] = true;
					damage = GetRandomFloat(SCOUT_MIN_DAMAGE, SCOUT_MAX_DAMAGE);
				}

				if(g_fScoutDamage < 1.0)
					damage *= g_fScoutDamage;

				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

Void_SetDefaults()
{
	g_bScoutHeadshot = GetConVarInt(g_hCvar[CVAR_SCOUT_HEADSHOT]) ? true : false;
	g_fScoutDamage = GetConVarFloat(g_hCvar[CVAR_SCOUT_DAMAGE]);
}

public OnSettingsChange(Handle:cvar, const String:oldvalue[], const String:newvalue[])
{
	if(cvar == g_hCvar[CVAR_SCOUT_HEADSHOT])
		g_bScoutHeadshot = StringToInt(newvalue) ? true : false;
	else if(cvar == g_hCvar[CVAR_SCOUT_DAMAGE])
		g_fScoutDamage = StringToFloat(newvalue);
}