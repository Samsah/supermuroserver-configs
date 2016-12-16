/**
 * Slays losers on round timer end AND round end (default)
 * (didnt plant and time was up, didnt touch / rescue all hostage when time was up)
 * (bomb exploded or defused triggers this round end!)
 *
 * OR:
 *
 * Slay losers on objectives lost/completed ONLY
 * (such as bomb explode, defuse, and all hostages rescued)
 * If bomb wasnt planted then this will not do anything.
 *
 * Admins can be immune to the slay
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <colors>

#define PLUGIN_VERSION "1.1"

// Globals
new bool:g_bHostageTouched = false;

// Convars
new Handle:g_hCvarEnabled = INVALID_HANDLE;
new Handle:g_hCvarAdminsImmune = INVALID_HANDLE;
new Handle:g_hCvarSlayOnObjectives = INVALID_HANDLE;
new Handle:g_hCvarSlayOnRoundTimeUp = INVALID_HANDLE;
new Handle:g_hCvarDNSIfTouchHostage = INVALID_HANDLE; //DNS==Do Not Slay
new bool:g_bCvarEnabled = true;
new bool:g_bCvarAdminsImmune = true;
new bool:g_bCvarSlayOnObjectives = false;
new bool:g_bCvarSlayOnRoundTimeUp = true;
new bool:g_bCvarDNSIfTouchHostage = true; //DNS==Do Not Slay

public Plugin:myinfo = {
	name = "Slay Losers",
	author = "DarkEnergy - Ownz",
	description = "Slays losers on timer round end and or objectives lost",
	version = PLUGIN_VERSION,
	url = "www.ownageclan.com"
};

public OnPluginStart()
{
	LoadTranslations("slaylosers.phrases");
	
	HookEvent("round_start", EventRoundStart);
	HookEvent("round_end", EventRoundEnd);
	HookEvent("bomb_defused", EventBombDefused);
	HookEvent("bomb_exploded", EventBombExploded);
	HookEvent("hostage_rescued_all", EventAllHostagesRescued);
	HookEvent("hostage_follows", EventHostageTouched);
	
	CreateConVar("oc_slaylosers_version", PLUGIN_VERSION, "Slay Losers version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hCvarEnabled = CreateConVar("slaylosers_enabled", "1", "Is this plugin enabled, the master on off switch");
	g_hCvarAdminsImmune = CreateConVar("slaylosers_admin_immunity", "1", "Admins should not be slayed");
	g_hCvarSlayOnObjectives = CreateConVar("slaylosers_slay_objectives", "0", "Slay losers if an objective is completed (bomb, defuse, all hostages)");
	g_hCvarSlayOnRoundTimeUp = CreateConVar("slaylosers_slay_round_timer", "1", "Slay losers if round timer is up (didnt plant and time was up etc)");
	g_hCvarDNSIfTouchHostage = CreateConVar("slaylosers_skipiftouchedhostage", "1", "CTs should not be slayed if they touched a hostage");
	
	HookConVarChange(g_hCvarEnabled, OnConVarChange);
	HookConVarChange(g_hCvarAdminsImmune, OnConVarChange);
	HookConVarChange(g_hCvarSlayOnObjectives, OnConVarChange);
	HookConVarChange(g_hCvarSlayOnRoundTimeUp, OnConVarChange);
	HookConVarChange(g_hCvarDNSIfTouchHostage, OnConVarChange);
	
	AutoExecConfig(false, "slaylosers");
}

public Action:EventRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bHostageTouched = false;
}

public Action:EventRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bCvarEnabled && g_bCvarSlayOnRoundTimeUp)
	{
		new winner = GetEventInt(event, "winner");
		if (winner == CS_TEAM_CT || winner == CS_TEAM_T)
		{
			new bool:slay = true;
			if (winner == CS_TEAM_T && g_bHostageTouched && g_bCvarDNSIfTouchHostage) //do not slay CT if CTs touched a hostage
			{
				slay = false;
				SlayLosersPrintToChat("%t", "Counter Terrorists have been spared for touching at least one hostage");
			}
			if (slay)
			{
				CreateTimer(0.1, SlayTeam, winner == CS_TEAM_CT ? CS_TEAM_T : CS_TEAM_CT);
			}
		}
	}
}

public Action:EventBombDefused(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bCvarEnabled && g_bCvarSlayOnObjectives)
	{
		CreateTimer(0.1, SlayTeam, CS_TEAM_T);
	}
}

public Action:EventBombExploded(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bCvarEnabled && g_bCvarSlayOnObjectives)
	{
		CreateTimer(0.1, SlayTeam, CS_TEAM_CT);
	}
}
public Action:EventAllHostagesRescued(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bCvarEnabled && g_bCvarSlayOnObjectives)
	{
		CreateTimer(0.1, SlayTeam, CS_TEAM_T);
	}
}

public Action:EventHostageTouched(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bHostageTouched = true;
}

public Action:SlayTeam(Handle:t, any:team)
{
	new slayedcount = 0;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == team && !IsAdminImmunity(i))
		{
			ForcePlayerSuicide(i);
			//PrintToChat(i, "You have been slayed for not completing the objectives");
			slayedcount++;
		}
	}
	if (slayedcount > 0)
	{
		if (team == CS_TEAM_CT)
		{
			SlayLosersPrintToChat("%t", "Counter Terrorists have been slayed for not completing the objectives");
		}
		else if (team == CS_TEAM_T)
		{
			SlayLosersPrintToChat("%t", "Terrorists have been slayed for not completing the objectives");
		}
	}
}

bool:IsAdminImmunity(client)
{
    if (g_bCvarAdminsImmune)
    {
        return false;
    }
    new AdminId:admin = GetUserAdmin(client);
    if (admin == INVALID_ADMIN_ID)
    {
        return false;
    }
    return true;
}

public SlayLosersPrintToChat(const String:szMessage[], any:...)
{
	decl String:szBuffer[250];
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			SetGlobalTransTarget(i);
			VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
			Format(szBuffer, sizeof(szBuffer), "%T%s", "[Slay Losers]", i, szBuffer);
			CPrintToChat(i, szBuffer);
		}
	}
}

public OnConVarChange(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	GetConVars();
}

public OnConfigsExecuted()
{
	GetConVars();
}

public GetConVars()
{
	g_bCvarEnabled = GetConVarBool(g_hCvarEnabled);
	g_bCvarAdminsImmune = GetConVarBool(g_hCvarAdminsImmune);
	g_bCvarSlayOnObjectives = GetConVarBool(g_hCvarSlayOnObjectives);
	g_bCvarSlayOnRoundTimeUp = GetConVarBool(g_hCvarSlayOnRoundTimeUp);
	g_bCvarDNSIfTouchHostage = GetConVarBool(g_hCvarDNSIfTouchHostage);
}
