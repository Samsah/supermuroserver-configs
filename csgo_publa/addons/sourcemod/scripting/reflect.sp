#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.3"


public Plugin:myinfo = {
	name = "Reflect team damage",
	author = "mad_hamster, modified by Snake 60 & Geel9",
	description = "A very simple plugin to reflect team damage (hp and armor)",
	version = PLUGIN_VERSION,
	url = "http://pro-css.co.il"
};


static Handle:h_slap         = INVALID_HANDLE;
static Handle:h_damage       = INVALID_HANDLE;
static Handle:h_reportinchat = INVALID_HANDLE;

static slap;
static damage;
static reportinchat;


public OnPluginStart() {
	HookEvent("player_hurt", Event_PlayerHurt);

	CreateConVar("reflect_ver", PLUGIN_VERSION, "", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	h_slap         = CreateConVar ("sm_reflect_slap", "1", "Whether or not to slap TKers. 1 - slap TKers; 0 - don't");
	h_damage       = CreateConVar ("sm_reflect_damage", "-1", "If -1, it will reduce users HP & armor for however much damage they did. Otherwise, it will reduce HP & armor for the amount specified in the convar.");
	h_reportinchat = CreateConVar ("sm_reflect_report_in_chat", "1", "Report in chat about damage done. 1 - report, 0 - not");

	HookConVarChange(h_slap,         refresh_cvars);
	HookConVarChange(h_damage,       refresh_cvars);
	HookConVarChange(h_reportinchat, refresh_cvars);
	refresh_cvars(INVALID_HANDLE, "", "");

	AutoExecConfig();

	LoadTranslations("reflect.phrases");
}



public refresh_cvars(Handle:cvar, const String:oldval[], const String:newval[]) {
	slap         = GetConVarInt(h_slap);
	damage       = GetConVarInt(h_damage);
	reportinchat = GetConVarInt(h_reportinchat);
}



public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast) {
	new victim   = GetClientOfUserId(GetEventInt(event,"userid"));
	new attacker = GetClientOfUserId(GetEventInt(event,"attacker"));

	if(   attacker > 0
		&& victim > 0
		&& IsClientInGame(attacker)
		&& IsClientInGame(victim)
		&& GetClientTeam(attacker) == GetClientTeam(victim)
		&& IsPlayerAlive(attacker)
		&& victim != attacker)
	{
		// Slap player if needed
		if (slap == 1)
			SlapPlayer(attacker, 0, true);

		// How much damage do we need to reflect?
		new reflect_hp_dmg;
		new reflect_armor_dmg;
		if (damage != -1) {
			reflect_hp_dmg    = damage;
			reflect_armor_dmg = damage;
		}
		else {
			reflect_hp_dmg    = GetEventInt(event, "dmg_health");
			reflect_armor_dmg = GetEventInt(event, "dmg_armor");
		}

		// Reflect damage, possibly killing attacker
		new attacker_hp    = GetClientHealth(attacker);
		new attacker_armor = GetClientArmor (attacker);

		if (reflect_hp_dmg >= attacker_hp)
			CreateTimer(0.0, Slay, attacker, TIMER_FLAG_NO_MAPCHANGE);
		else {
			SetEntityHealth(attacker, attacker_hp - reflect_hp_dmg);
			if (reflect_armor_dmg >= attacker_armor)
				SetEntProp(attacker, Prop_Send, "m_ArmorValue", 0, 1);
			else SetEntProp(attacker, Prop_Send, "m_ArmorValue", attacker_armor - reflect_armor_dmg, 1);
		}

		// Print warning in chat if needed
		if (reportinchat == 1)
			PrintToChat(attacker, "\x01\x0B\x04[\x01SM\x04] %T. %T",
				"Beware",   LANG_SERVER, GetEventInt(event, "dmg_health"), GetEventInt(event, "dmg_armor"),
				"You lost", LANG_SERVER, reflect_hp_dmg, reflect_armor_dmg);
	}
}
public Action:Slay(Handle:timer, any:client)
{
	ForcePlayerSuicide(client);
}