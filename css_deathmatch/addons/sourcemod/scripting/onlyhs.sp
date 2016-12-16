#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <autoexecconfig>

#undef REQUIRE_PLUGIN
#include <updater>

#define ONLYHS_VERSION "1.3.2"

#define UPDATE_URL    "https://bara.in/update/onlyhs.txt"

#define DMG_HEADSHOT (1 << 30)

new Handle:g_hEnablePlugin = INVALID_HANDLE,
	Handle:g_hEnableOneShot = INVALID_HANDLE,
	Handle:g_hEnableWeapon = INVALID_HANDLE,
	Handle:g_hAllowGrenade = INVALID_HANDLE,
	Handle:g_hAllowWorld = INVALID_HANDLE,
	Handle:g_hAllowMelee = INVALID_HANDLE,
	Handle:g_hAllowedWeapon = INVALID_HANDLE;

new String:g_sAllowedWeapon[32],
	String:g_sGrenade[32],
	String:g_sWeapon[32];

public Plugin:myinfo = 
{
	name = "Headshot Only",
	author = "Bara",
	description = "Only Headshot Plugin for CSS and CSGO",
	version = ONLYHS_VERSION,
	url = "www.bara.in"
}

public OnPluginStart()
{
	CreateConVar("onlyhs_version", ONLYHS_VERSION, "Only Headshot", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	if(GetEngineVersion() != Engine_CSS && GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("Only CSS and CSGO Support");
	}

	AutoExecConfig_SetFile("plugin.onlyhs", "sourcemod");
	AutoExecConfig_SetCreateFile(true);

	g_hEnablePlugin = AutoExecConfig_CreateConVar("onlyhs_enable", "1", "Enable / Disalbe Only HeadShot Plugin", _, true, 0.0, true, 1.0);
	g_hEnableOneShot = AutoExecConfig_CreateConVar("onlyhs_oneshot", "0", "Enable / Disable kill enemy with one shot", _, true, 0.0, true, 1.0);
	g_hEnableWeapon = AutoExecConfig_CreateConVar("onlyhs_oneweapon", "1", "Enable / Disalbe Only One Weapon Damage", _, true, 0.0, true, 1.0);
	g_hAllowGrenade = AutoExecConfig_CreateConVar("onlyhs_allow_grenade", "0", "Enable / Disalbe Grenade Damage", _, true, 0.0, true, 1.0);
	g_hAllowWorld = AutoExecConfig_CreateConVar("onlyhs_allow_world", "0", "Enable / Disalbe World Damage", _, true, 0.0, true, 1.0);
	g_hAllowMelee = AutoExecConfig_CreateConVar("onlyhs_allow_knife", "0", "Enable / Disalbe Knife Damage", _, true, 0.0, true, 1.0);
	g_hAllowedWeapon = AutoExecConfig_CreateConVar("onlyhs_allow_weapon", "deagle", "Which weapon should be permitted ( Without 'weapon_' )?");

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}

	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}

public OnClientPutInServer(i)
{
	SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if(GetConVarInt(g_hEnablePlugin))
	{
		if(IsClientValid(victim))
		{
			if(damagetype & DMG_FALL || attacker == 0)
			{
				if(GetConVarInt(g_hAllowWorld))
				{
					return Plugin_Continue;
				}
				else
				{
					return Plugin_Handled;
				}
			}

			if(IsClientValid(attacker))
			{
				GetEdictClassname(inflictor, g_sGrenade, sizeof(g_sGrenade));
				GetClientWeapon(attacker, g_sWeapon, sizeof(g_sWeapon));

				if(damagetype & DMG_HEADSHOT)
				{
					if(GetConVarInt(g_hEnableWeapon))
					{
						GetConVarString(g_hAllowedWeapon, g_sAllowedWeapon, sizeof(g_sAllowedWeapon));

						if(!StrEqual(g_sWeapon[7], g_sAllowedWeapon))
						{
							return Plugin_Handled;
						}
					}

					if(GetConVarInt(g_hEnableOneShot))
					{
						damage = float(GetClientHealth(victim));

						return Plugin_Changed;
					}

					return Plugin_Continue;
				}
				else
				{
					if(GetConVarInt(g_hAllowMelee))
					{
						if(StrEqual(g_sWeapon, "weapon_knife"))
						{
							return Plugin_Continue;
						}
					}

					if(GetConVarInt(g_hAllowGrenade))
					{
						if(GetEngineVersion() == Engine_CSS)
						{
							if(StrEqual(g_sGrenade, "hegrenade_projectile"))
							{
								return Plugin_Continue;
							}
						}
						else if(GetEngineVersion() == Engine_CSGO)
						{
							if(StrEqual(g_sGrenade, "hegrenade_projectile") || StrEqual(g_sGrenade, "decoy_projectile") || StrEqual(g_sGrenade, "molotov_projectile"))
							{
								return Plugin_Continue;
							}
						}
					}
					return Plugin_Handled;
				}
			}
			else
			{
				return Plugin_Handled;
			}
		}
		else
		{
			return Plugin_Handled;
		}
	}
	else
	{
		return Plugin_Continue;
	}
}

stock bool:IsClientValid(client)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		return true;
	}
	return false;
}