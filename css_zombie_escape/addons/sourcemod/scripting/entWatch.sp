//=====================================================================================================================
// 
// Name: entWatch
// Author: Prometheum
// Description: Monitors entities.
// 
//=====================================================================================================================
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <clientprefs>

#include <morecolors>
#include <entWatchFuncs>

new Handle:hudCookie = INVALID_HANDLE;
new Handle:globalCooldowns = INVALID_HANDLE;

new bans[MAXPLAYERS+1] = 0; //0 = unchecked, 1 = not banned, 2 = temp ban, 3 = perm ban

//----------------------------------------------------------------------------------------------------------------------
// Purpose: Entity Data
//----------------------------------------------------------------------------------------------------------------------
enum entities
{
	String:ent_desc[32],
	String:ent_shortdesc[32],
	String:ent_color[32],
	String:ent_name[32],
	String:ent_realname[32],
	bool:ent_exactname[32],
	bool:ent_singleactivator[32],
	String:ent_type[32],
	String:ent_buttontype[32],
	bool:ent_chat[32],
	bool:ent_hud[32],
	ent_buttonid,
	ent_owner,
	ent_id,
	ent_mode,// 0 = Disabled, 1 = Cooldowns, 2 = Toggle, 3 = Limited uses, 4 = Limited uses with cooldowns, 5 = N/A
	ent_maxuses,
	ent_uses,
	ent_hammerid,
	Float:ent_cooldown,
	ent_cooldowncount,
	String:ent_using[32]
}

new entArray[32][ entities];
new arrayMax = 0;

//----------------------------------------------------------------------------------------------------------------------
// Purpose: Color Settings
//----------------------------------------------------------------------------------------------------------------------
new String:color_tag[12] = "E01B5D";
new String:color_name[12] = "EDEDED";
new String:color_steamid[12] = "B2B2B2";
new String:color_use[12] = "67ADDF";
new String:color_pickup[12] = "C9EF66";
new String:color_drop[12] = "E562BA";
new String:color_disconnect[12] = "F1B567";
new String:color_death[12] = "F1B567";
new String:color_warning[12] = "F16767";

//----------------------------------------------------------------------------------------------------------------------
// Purpose: Plugin Settings
//----------------------------------------------------------------------------------------------------------------------
new bool:configLoaded = false;
new Handle:configName;


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo =
{
	name = "entWatch",
	author = "Prometheum",
	description = "#ZOMG #YOLO | Finds entities and hooks events relating to them.",
	version = "2.1",
	url = "https://github.com/Prometheum/entWatch"
};


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public OnPluginStart()
{
	globalCooldowns = CreateConVar("entw_cooldowns", "1", "Turns cooldowns/off");
	configName = CreateConVar("entw_colorconfig", "colors_classic", "Sets color config");

	CreateConVar("sm_entW_version", "2.1", "Current version of entWatch", FCVAR_NOTIFY);
	
	RegConsoleCmd("hud", Command_HudToggle);
	RegConsoleCmd("amibanned", Command_CheckBan);
	RegAdminCmd("etransfer", Command_Transfer, ADMFLAG_KICK, "Transfers an entity");
	RegAdminCmd("etrans", Command_Transfer, ADMFLAG_KICK, "Transfers an entity");
	RegAdminCmd("eban", Command_Ban, ADMFLAG_KICK, "Bans a player");
	RegAdminCmd("eunban", Command_Unban, ADMFLAG_KICK, "Unbans a player");

	RegAdminCmd("entw_reloadcolors", Command_ReloadColors, ADMFLAG_KICK, "Reload Colors");
	RegAdminCmd("entw_reloadconfigs", Command_ReloadConfigs, ADMFLAG_KICK, "Reload Configs");
	RegAdminCmd("entw_testcolors", Command_TestColors, ADMFLAG_KICK, "Reload Configs");

	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);

	hudCookie = RegClientCookie("entWatch_displayhud", "EntWatch DisplayHud", CookieAccess_Protected);
	
	CreateTimer(1.0, Timer_DisplayHud, _, TIMER_REPEAT);
	CreateTimer(1.0, Timer_Cooldowns, _, TIMER_REPEAT);
	
	LoadTranslations("entwatch.phrases");
	
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public OnMapStart()
{	
	for(new i = 0; i < 32; i++)
	{
		strcopy( entArray[ i ][ ent_desc ], 32, "null" );
		strcopy( entArray[ i ][ ent_shortdesc ], 32, "" );
		strcopy( entArray[ i ][ ent_color ], 32, "null" );
		strcopy( entArray[ i ][ ent_name ], 32, "null" );
		strcopy( entArray[ i ][ ent_type ], 32, "null" );
		strcopy( entArray[ i ][ ent_buttontype ], 32, "null" );
		entArray[ i ][ ent_chat ] = false;
		entArray[ i ][ ent_hud ] = false;
		entArray[ i ][ ent_buttonid ] = -1;
		entArray[ i ][ ent_id ] = -1;
		entArray[ i ][ ent_mode ] = -1;
		entArray[ i ][ ent_hammerid ] = -1;
		entArray[ i ][ ent_owner ] = -1;
		entArray[ i ][ ent_uses ] = 0;
		entArray[ i ][ ent_maxuses ] = 1;
		entArray[ i ][ ent_cooldown ] = 2.0;
		entArray[ i ][ ent_cooldowncount ] = 0;
		entArray[ i ][ ent_exactname ] = false;
		entArray[ i ][ ent_singleactivator ] = false;
	}	

	//Load Colors
	LoadColors();
	//Load Map
	LoadMapConfigs();
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public Action:OnEntityUse(entity, activator, caller, UseType:type, Float:value)
{
	new String:clientBuffer[32];

	new i ;
	for(i= 0; i < arrayMax; i++)
	{
		if(entArray[ i ][ ent_buttonid ] == entity)
		{
			break;
		}
	}
	if(entArray[ i ][ ent_owner ] != caller && entArray[ i ][ ent_owner ] != activator )
		return Plugin_Handled;	

	GetClientAuthString(caller, clientBuffer, sizeof(clientBuffer));
	ReplaceString(clientBuffer, sizeof(clientBuffer), "STEAM_", "", true);
	
	strcopy(entArray[ i ][ ent_using ], 32, "U");
	if(entArray[ i ][ ent_singleactivator ] == true)
	{
		if( entArray[ i ][ ent_mode ] == 1 && entArray [ i ][ ent_cooldowncount ] == 0)
		{
			CPrintToChatAll("\x07%s[entWatch] \x07%s%N\x07%s(\x07%s%s\x07%s) \x07%s%t \x07%s%s", color_use, color_name, entArray[ i ][ ent_owner ], color_use, color_steamid, clientBuffer, color_use, color_use, "use", entArray[i][ent_color], entArray[i][ent_desc]);
			entArray[ i ][ ent_cooldowncount ] = RoundToNearest(entArray[i][ent_cooldown]);
			return Plugin_Continue;
		}
		else if(entArray[ i ][ ent_mode ] == 3  && entArray[ i ][ ent_uses ] != entArray[ i ][ ent_maxuses ] )
		{
			entArray[ i ][ ent_uses ]++;
			return Plugin_Continue;
		}
		else if(entArray[ i ][ ent_mode ] == 2 )
		{
			return Plugin_Continue;
		}		
		else if(entArray[ i ][ ent_mode ] == 4 && entArray[ i ][ ent_uses ] != entArray[ i ][ ent_maxuses ] && entArray [ i ][ ent_cooldowncount ] == 0)
		{
			entArray[ i ][ ent_uses ]++;
			entArray[ i ][ ent_cooldowncount ] = RoundToNearest(entArray[i][ent_cooldown]);
			CPrintToChatAll("\x07%s[entWatch] \x07%s%N\x07%s(\x07%s%s\x07%s) \x07%s%t \x07%s%s", color_use, color_name, entArray[ i ][ ent_owner ], color_use, color_steamid, clientBuffer, color_use, color_use, "use", entArray[i][ent_color], entArray[i][ent_desc]);
			return Plugin_Continue;
		}
	}
	else
	{
		if( entArray[ i ][ ent_mode ] == 1 && entArray [ i ][ ent_cooldowncount ] == 0)
		{
			CPrintToChatAll("\x07%s[entWatch] \x07%s%N\x07%s(\x07%s%s\x07%s) \x07%s%t \x07%s%s", color_use, color_name, entArray[ i ][ ent_owner ], color_use, color_steamid, clientBuffer, color_use, color_use, "use", entArray[i][ent_color], entArray[i][ent_desc]);
			entArray[ i ][ ent_cooldowncount ] = RoundToNearest(entArray[i][ent_cooldown]);
			return Plugin_Continue;
		}
		else if(entArray[ i ][ ent_mode ] == 2 )
		{
			return Plugin_Continue;
		}				
		else if(entArray[ i ][ ent_mode ] == 3  && entArray[ i ][ ent_uses ] != entArray[ i ][ ent_maxuses ] )
		{
			entArray[ i ][ ent_uses ]++;
			return Plugin_Continue;
		}
		else if(entArray[ i ][ ent_mode ] == 4 && entArray[ i ][ ent_uses ] != entArray[ i ][ ent_maxuses ] && entArray [ i ][ ent_cooldowncount ] == 0)
		{
			entArray[ i ][ ent_uses ]++;
			entArray[ i ][ ent_cooldowncount ] = RoundToNearest(entArray[i][ent_cooldown]);
			CPrintToChatAll("\x07%s[entWatch] \x07%s%N\x07%s(\x07%s%s\x07%s) \x07%s%t \x07%s%s", color_use, color_name, entArray[ i ][ ent_owner ], color_use, color_steamid, clientBuffer, color_use, color_use, "use", entArray[i][ent_color], entArray[i][ent_desc]);
			return Plugin_Continue;
		}			
	}
	return Plugin_Handled;	
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 0; i < arrayMax; i++)
	{
		SDKUnhook(entArray[i][ ent_id], SDKHook_Use, OnEntityUse);
		entArray[i][ ent_buttonid] = -1;
		entArray[i][ ent_id] = -1;
		entArray[i][ ent_owner] = -1;
		entArray[ i ][ ent_hammerid ] = -1;
		entArray[ i ][ ent_uses ] = 0;
		entArray [ i ][ ent_cooldowncount ] = 0;
		
	}
	
	if(configLoaded)
	{
		CPrintToChatAll("\x073600FF[entWatch]\x0701A8FF %t \x073600FFPrometheum", "welcome");
	}	
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public Action:OnWeaponCanUse(client, weapon)
{
	decl String:targetname[32];
	Entity_GetTargetName(weapon, targetname, sizeof(targetname));
	
	for (new i = 0; i < arrayMax; i++)
	{		
		if(entArray[i][ent_hammerid] != -1)
		{
			if(entArray[ i ][ ent_hammerid ] == Entity_GetHammerId(weapon))
			{
				if(getBanStatus(client) == 2)
					return Plugin_Handled;
					
				entArray[i][ ent_id] = weapon;
				return Plugin_Continue;
			}
		}
		else if (entArray[i][ent_id] == -1)
		{
			if(entArray[i][ent_exactname])
			{
				if(strcmp(targetname, entArray[i][ ent_name], false) == 0)
				{
					if(getBanStatus(client) == 2)
						return Plugin_Handled;
						
					entArray[i][ ent_id] = weapon;
					HookButton(i);	
					return Plugin_Continue;
				}
			}
			else if(!entArray[i][ent_exactname])
			{
				if(StrContains(targetname, entArray[i][ ent_name], false) != -1)
				{
					if(getBanStatus(client) == 2)
						return Plugin_Handled;				
				
					entArray[i][ ent_id] = weapon;
					HookButton(i);	
					return Plugin_Continue;
				}
				
			}
		}
	}
	return Plugin_Continue;
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public Action:OnWeaponEquip(client, weapon) 
{	
	for (new i = 0; i < arrayMax; i++)
	{
		if(entArray[i][ent_id] == weapon)
		{
			new String:clientBuffer[32];
	
			GetClientAuthString(client, clientBuffer, sizeof(clientBuffer));
			ReplaceString(clientBuffer, sizeof(clientBuffer), "STEAM_", "", true);
			entArray[ i ][ ent_owner] = client;
			if(entArray[i][ ent_chat])
				CPrintToChatAll("\x07%s[entWatch] \x07%s%N\x07%s(\x07%s%s\x07%s) %t \x07%s%s", color_pickup, color_name, client, color_pickup, color_steamid, clientBuffer, color_pickup, "pickup", entArray[i][ent_color], entArray[i][ent_desc]);
			break;
		}	
	}
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	for (new i = 0; i < arrayMax; i++)
	{
		if(entArray[i][ ent_owner] == client)
		{
			new String:clientBuffer[32];
	
			GetClientAuthString(client, clientBuffer, sizeof(clientBuffer));
			ReplaceString(clientBuffer, sizeof(clientBuffer), "STEAM_", "", true);

			if(entArray[i][ ent_chat])
				CPrintToChatAll("\x07%s[entWatch] \x07%s%N\x07%s(\x07%s%s\x07%s) %t \x07%s%s", color_death, color_name, client, color_death, color_steamid, clientBuffer, color_death, "death", entArray[i][ent_color], entArray[i][ent_desc]);
			entArray[ i ][ ent_hammerid ] = Entity_GetHammerId(entArray[ i ][ ent_id ]);
			entArray[ i ][ ent_owner] = -1;
			entArray[i][ ent_id] = -1;
			
			break;
		}	
	}
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public OnClientDisconnect(client)
{
	for (new i = 0; i < arrayMax; i++)
	{
		if(entArray[i][ ent_owner] == client)
		{
			new String:clientBuffer[32];
	
			GetClientAuthString(client, clientBuffer, sizeof(clientBuffer));
			ReplaceString(clientBuffer, sizeof(clientBuffer), "STEAM_", "", true);

			if(entArray[i][ ent_chat])
				CPrintToChatAll("\x07%s[entWatch] \x07%s%N\x07%s(\x07%s%s\x07%s) %t \x07%s%s", color_disconnect, color_name, client, color_disconnect, color_steamid, clientBuffer, color_disconnect, "disconnect", entArray[i][ent_color], entArray[i][ent_desc]);
			entArray[ i ][ ent_hammerid ] = Entity_GetHammerId(entArray[ i ][ ent_id ]);
			entArray[ i ][ ent_owner ] = -1;
			entArray[i][ ent_id] = -1;
			break;
		}	
	}
	if (IsClientInGame(client))
	{
		SDKUnhook(client, SDKHook_WeaponEquip, OnWeaponEquip);
		SDKUnhook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
	}
}  


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public Action:CS_OnCSWeaponDrop(client, weaponIndex)
{
	new i = FindEntityInLocalArray(weaponIndex);

	if(i != -1)
	{
		new String:clientBuffer[32];
	
		GetClientAuthString(client, clientBuffer, sizeof(clientBuffer));
		ReplaceString(clientBuffer, sizeof(clientBuffer), "STEAM_", "", true);

		if(entArray[i][ ent_chat])
			CPrintToChatAll("\x07%s[entWatch] \x07%s%N\x07%s(\x07%s%s\x07%s) %t \x07%s%s", color_drop, color_name, client, color_drop, color_steamid, clientBuffer, color_drop, "drop", entArray[i][ent_color], entArray[i][ent_desc]);
		entArray[ i ][ ent_hammerid ] = Entity_GetHammerId(entArray[ i ][ ent_id ]);
		entArray[ i ][ ent_owner ] = -1;
		entArray[i][ ent_id] = -1;
	}
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public Action:Command_HudToggle(client, args)
{
	decl String:buffer[32];
	GetClientCookie(client, hudCookie, buffer, sizeof(buffer));
	if(StrEqual(buffer, "0"))
	{
		SetClientCookie(client, hudCookie, "1");
	}
	else
	{
		SetClientCookie(client, hudCookie, "0");
	}
	return Plugin_Handled;
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public Action:Command_CheckBan(client, args)
{
	getBanStatus(client);
	if(bans[client] == 2)
	{
		CPrintToChat(client, "\x07%s[entWatch] \x07%sYou are banned!", color_tag, color_warning);
	}
	else
	{
		CPrintToChat(client, "\x07%s[entWatch] \x07%sYou are not banned!", color_tag, color_warning);
	}
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public Action:Command_Transfer(client, args)
{
	if (args < 2)
	{
		CPrintToChat(client, "\x07%s[entWatch] \x07%sUsage: etransfer <entity owner> <recepient>", color_tag, color_warning);
		return Plugin_Handled;
	}
 
	new String:name[32], target = -1;
	GetCmdArg(1, name, sizeof(name));
	new String:recepient[32], recep = -1;
	GetCmdArg(2, recepient, sizeof(recepient));	
 
	for (new i=1; i<=MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			decl String:other[32];
			GetClientName(i, other, sizeof(other));
			if (StrContains(other, name, false) != -1)
			{
				target = i;
			}
		}
	}

	for (new i=1; i<=MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			decl String:other[32];
			GetClientName(i, other, sizeof(other));
			if (StrContains(other, recepient, false) != -1)
			{
				recep = i;
			}
		}
	}
	
	new index;
	for (new i = 0; i < arrayMax; i++)
	{
		if(entArray[ i ][ ent_owner ] == target)
		{
			new entid = entArray[ i ][ ent_id ];
			index = i;
			new Float:vec[3];
			GetEntPropVector(recep, Prop_Send, "m_vecOrigin", vec);
			CS_DropWeapon(target, entArray[ i ][ ent_id ], false, true);
			entArray[ i ][ ent_hammerid ] = Entity_GetHammerId(entArray[ i ][ ent_id ]);
			entArray[ i ][ ent_owner ] = -1;
			entArray[i][ ent_id] = -1;			
			TeleportEntity(entid, vec, NULL_VECTOR, NULL_VECTOR);
		}
	}
	CPrintToChatAll("\x07%s[entWatch] \x07%s%N \x07%sis transferring \x07%s%s \x07%sfrom \x07%s%N \x07%sto \x07%s%N", color_tag, color_name, client, color_warning, entArray[ index ][ ent_color ], entArray[ index ][ ent_shortdesc ], color_warning, color_name, target, color_warning, color_name, recep);
	LogMessage("%N is transferring %s from %N to %N", client, entArray[ index ][ ent_shortdesc ], target, recep);
	return Plugin_Handled;
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public Action:Command_ReloadColors(client, args)
{
	LoadColors();
	return Plugin_Handled;
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public Action:Command_ReloadConfigs(client, args)
{
	LoadMapConfigs();
	return Plugin_Handled;
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public Action:Command_TestColors(client, args)
{
	new String:clientBuffer[32];

	GetClientAuthString(client, clientBuffer, sizeof(clientBuffer));
	ReplaceString(clientBuffer, sizeof(clientBuffer), "STEAM_", "", true);
	CPrintToChatAll("\x07%s[entWatch] \x07%s%N\x07%s(\x07%s%s\x07%s) %t \x07%s%s", color_use, color_name, client, color_use, color_steamid, clientBuffer, color_use, "use", "ff0000", "Fire Materia");
	CPrintToChatAll("\x07%s[entWatch] \x07%s%N\x07%s(\x07%s%s\x07%s) %t \x07%s%s", color_pickup, color_name, client, color_pickup, color_steamid, clientBuffer, color_pickup, "pickup", "ff0000", "Fire Materia");
	CPrintToChatAll("\x07%s[entWatch] \x07%s%N\x07%s(\x07%s%s\x07%s) %t \x07%s%s", color_death, color_name, client, color_death, color_steamid, clientBuffer, color_death, "death", "ff0000", "Fire Materia");
	CPrintToChatAll("\x07%s[entWatch] \x07%s%N\x07%s(\x07%s%s\x07%s) %t \x07%s%s", color_disconnect, color_name, client, color_disconnect, color_steamid, clientBuffer, color_disconnect, "disconnect", "ff0000", "Fire Materia");
	CPrintToChatAll("\x07%s[entWatch] \x07%s%N\x07%s(\x07%s%s\x07%s) %t \x07%s%s", color_drop, color_name, client, color_drop, color_steamid, clientBuffer, color_drop, "drop", "ff0000", "Fire Materia");

	return Plugin_Handled;
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public Action:Command_Ban(client, args)
{
	if (args < 2)
	{
		CPrintToChat(client, "\x07%s[entWatch] \x07%sUsage: eban <client> <type (perm/temp)>", color_tag, color_warning);
		return Plugin_Handled;
	}
 
	new String:name[32], String:type[5], target = -1;
	GetCmdArg(1, name, sizeof(name));	
	GetCmdArg(2, type, sizeof(type));	
 
	for (new i=1; i<=MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			decl String:other[32];
			GetClientName(i, other, sizeof(other));
			if (StrContains(other, name, false) != -1)
			{
				target = i;
			}
		}
	}
	if(bans[target] == 0)
	{
		getBanStatus(target);
	}	
	if(bans[target] == 2)
	{
		CPrintToChat(client, "\x07%s[entWatch] \x07%sAlready banned...", color_tag, color_warning);
		return Plugin_Handled;
	}
	if (StrEqual(type, "perm"))
	{
		bans[target] = 2;
		writeBan(target, client);
		CPrintToChat(client, "\x07%s[entWatch] \x07%sPerm Banning %N", color_tag, color_warning, target);
		LogMessage("%N is perm banning %N", client, target);		
	}
	if (StrEqual(type, "temp"))
	{
		bans[target] = 2;
		CPrintToChat(client, "\x07%s[entWatch] \x07%sTemp Banning %N", color_tag, color_warning, target);
		LogMessage("%N is temp banning %N", client, target);
	}
	return Plugin_Handled;
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public Action:Command_Unban(client, args)
{
	if (args < 1)
	{
		CPrintToChat(client, "\x07%s[entWatch] \x07%sUsage: eunban <client>", color_tag, color_warning);
		return Plugin_Handled;
	}
 
	new String:name[32], target = -1;
	GetCmdArg(1, name, sizeof(name));		
 
	for (new i=1; i<=MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			decl String:other[32];
			GetClientName(i, other, sizeof(other));
			if (StrContains(other, name, false) != -1)
			{
				target = i;
			}
		}
	}
	if(bans[target] != 2)
	{
		getBanStatus(target);
	}
	if(bans[target] != 2)
	{
		CPrintToChat(client, "\x07%s[entWatch] \x07%sNot banned..", color_tag, color_warning);
	}		
	if(bans[target] == 2)
	{
		removeBan(target);
		bans[target] = 1;
		CPrintToChat(client, "\x07%s[entWatch] \x07%sUnbanning %N", color_tag, color_warning, target);	
		LogMessage("%N is unbanning %N", client, target);		
		return Plugin_Handled;
	}

	return Plugin_Handled;
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public Action:Command_BanID(client, args)
{ 
	if (args < 2)
	{
		CPrintToChat(client, "\x07%s[entWatch] \x07%sUsage: eban <steamid> <type (perm/temp)>", color_tag, color_warning);
		return Plugin_Handled;
	}
	new String:steamid[32], String:type[5], target = -1;
	GetCmdArg(1, steamid, sizeof(steamid));	
	GetCmdArg(2, type, sizeof(type));	
 
	for (new i=1; i<=MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			decl String:other[32];
			GetClientAuthString(i, other, sizeof(other));
			if (StrContains(other, steamid, false) != -1)
			{
				target = i;
				
			}
		}
	}
	if(bans[target] == 0)
	{
		getBanStatus(target);
	}	
	if(bans[target] == 2)
	{
		CPrintToChat(client, "\x07%s[entWatch] \x07%sAlready banned...", color_tag, color_warning);
		return Plugin_Handled;
	}
	if (StrEqual(type, "perm"))
	{
		bans[target] = 2;
		writeBan(target, client);
		CPrintToChat(client, "\x07%s[entWatch] \x07%sPerm Banning %N", color_tag, color_warning, target);
		LogMessage("%N is perm banning %N", client, target);		
	}
	if (StrEqual(type, "temp"))
	{
		bans[target] = 2;
		CPrintToChat(client, "\x07%s[entWatch] \x07%sTemp Banning %N", color_tag, color_warning, target);
		LogMessage("%N is temp banning %N", client, target);
	}
	return Plugin_Handled;
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public Action:Timer_DisplayHud(Handle:timer)
{
	if(configLoaded)
	{
		new String:szText[254];
		new String:buffer[32];
		

		for (new x = 0; x < 32; x++)
		{
			new String:textBuffer[128];
			if(entArray[x][ ent_hud ]  && GetConVarInt(globalCooldowns) == 1 && entArray[x][ ent_owner ] != -1)
			{
				if(entArray[ x ][ ent_mode ] == 1)
				{
					if(entArray[x][ ent_cooldowncount] == 0)
						Format(textBuffer, sizeof(textBuffer), "%s[%s]: %N\n", entArray[x][ ent_shortdesc], "R", entArray[x][ ent_owner]);
					else
					{
						Format(textBuffer, sizeof(textBuffer), "%s[%d]: %N\n", entArray[x][ ent_shortdesc], entArray[x][ ent_cooldowncount], entArray[x][ ent_owner]);
					}
				}
				if(entArray[ x ][ ent_mode ] == 2)
				{
					Format(textBuffer, sizeof(textBuffer), "%s[%s]: %N\n", entArray[x][ ent_shortdesc], entArray[x][ ent_using], entArray[x][ ent_owner]);
				}
				if(entArray[ x ][ ent_mode ] == 3)
				{
					Format(textBuffer, sizeof(textBuffer), "%s[%d/%d]: %N\n", entArray[ x ][ ent_shortdesc ], entArray[ x ][ ent_uses ], entArray[ x ][ ent_maxuses ], entArray[x][ ent_owner] );
					if(entArray[ x ][ ent_maxuses ] == 1 && entArray[ x ][ ent_uses ] == 0)
						Format(textBuffer, sizeof(textBuffer), "%s[%s]: %N\n", entArray[ x ][ ent_shortdesc ], "R", entArray[x][ ent_owner]);
					if(entArray[ x ][ ent_maxuses ] == entArray[ x ][ ent_uses ])
						Format(textBuffer, sizeof(textBuffer), "%s[%s]: %N\n", entArray[ x ][ ent_shortdesc ], "D", entArray[x][ ent_owner] );
				}
				if(entArray[ x ][ ent_mode ] == 5)
				{
					Format(textBuffer, sizeof(textBuffer), "%s[%s]: %N\n", entArray[ x ][ ent_shortdesc ], "N/A", entArray[ x ][ ent_owner] );
				}				
				if(entArray[ x ][ ent_mode ] == 4)
				{
					Format(textBuffer, sizeof(textBuffer), "%s[%s]: %N\n", entArray[ x ][ ent_shortdesc ], "N/A", entArray[ x ][ ent_owner] );
					if(entArray[x][ ent_cooldowncount ] == 0)
					{
						if (entArray[ x ][ ent_maxuses ] == entArray[ x ][ ent_uses ])
						{
							Format(textBuffer, sizeof(textBuffer), "%s[%s]: %N\n", entArray[ x ][ ent_shortdesc ], "D", entArray[x][ ent_owner] );
						}
						else if (entArray[ x ][ ent_maxuses ] == 1)
						{
							Format(textBuffer, sizeof(textBuffer), "%s[%s]: %N\n", entArray[ x ][ ent_shortdesc ], "R", entArray[x][ ent_owner] );
						}
						if (entArray[ x ][ ent_uses ] > 1)
						{
							Format(textBuffer, sizeof(textBuffer), "%s[%d/%d]: %N\n", entArray[ x ][ ent_shortdesc ], entArray[ x ][ ent_uses ], entArray[ x ][ ent_maxuses ], entArray[ x ][ ent_owner] );
						}
					}
					else if(entArray[x][ ent_cooldowncount ] != 0)
					{
						if (entArray[ x ][ ent_maxuses ] == entArray[ x ][ ent_uses ])
						{
							Format(textBuffer, sizeof(textBuffer), "%s[%d/%d]: %N\n", entArray[ x ][ ent_shortdesc ], entArray[ x ][ ent_uses ], entArray[ x ][ ent_maxuses ], entArray[ x ][ ent_owner] );
						}
						else
						{
							Format(textBuffer, sizeof(textBuffer), "%s[%d]: %N\n", entArray[x][ ent_shortdesc], entArray[x][ ent_cooldowncount], entArray[x][ ent_owner]);
						}
					}
				}
			}
			StrCat(szText, sizeof(szText), textBuffer);
		}
		
		for (new i = 1; i < MaxClients; i++)
		{
			if (AreClientCookiesCached(i))
			{
				GetClientCookie(i, hudCookie, buffer, sizeof(buffer));
				if(StrEqual(buffer, "0") && IsClientConnected(i))
				{
					new Handle:hBuffer = StartMessageOne("KeyHintText", i);
					BfWriteByte(hBuffer, 1);
					BfWriteString(hBuffer, szText);
					EndMessage();
				}
				else if(StrEqual(buffer, "1"))
				{
				
				}
				else if(!StrEqual(buffer, "0") && !StrEqual(buffer, "1"))
				{
					SetClientCookie(i, hudCookie, "0");
				}
			}
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public Action:Timer_Cooldowns(Handle:timer)
{
	for (new i = 0; i < arrayMax; i++)
	{
		if(entArray[ i] [ ent_cooldowncount ] == 0)
		{
			strcopy(entArray[ i ][ ent_using ], 32, "R");
		}
		else
		{
			entArray[ i ][ ent_cooldowncount ] = entArray[i][ ent_cooldowncount] - 1;
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
	bans[client] = 0;
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public FindEntityInLocalArray(entity)
{
	for(new i = 0; i < arrayMax; i++)
	{
		if(entity == entArray[i][ ent_id])
		{
			return i;
		}
	}
	return -1;
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public HookButton(rootEntity)
{
	if(rootEntity == -1)
		return;

	if(entArray[rootEntity][ ent_buttonid ] != -1)
		return
	decl String:EntityClassname[32];
	decl String:EntityParent[32];
	decl String:EntityRealName[32];
	Entity_GetTargetName(entArray[rootEntity][ ent_id ], EntityRealName, sizeof(EntityRealName));
	for(new i=0; i < GetEntityCount(); i++)
	{
		if(IsValidEdict(i))
		{
			GetEntityClassname(i, EntityClassname, sizeof(EntityClassname));
			if(StrEqual(EntityClassname, entArray[rootEntity][ ent_buttontype]))
			{
				Entity_GetParentName(i, EntityParent, sizeof(EntityParent));
				if(StrEqual(EntityParent, EntityRealName))
				{
					entArray[rootEntity][ ent_buttonid] = i;
					SDKHook(i, SDKHook_Use, OnEntityUse);
				}
			}
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose: 0 = unchecked, 1 = not banned, 2 = ban
//----------------------------------------------------------------------------------------------------------------------
public getBanStatus(client)
{
	if(bans[client] != 0)
	{
		return bans[client];
	}
	if(isPermBan(client))
	{
		bans[client] = 2;
		return 2;
	}
	else
	{
		bans[client] = 1;
		return 1;
	}
}


//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public LoadColors()
{
	decl String:buff_temp[64];
	GetConVarString(configName, buff_temp, sizeof(buff_temp));
	new Handle:kv_colors = CreateKeyValues("colors");
	Format(buff_temp, sizeof(buff_temp), "cfg/sourcemod/entwatch/%s.txt", buff_temp);
	FileToKeyValues(kv_colors, buff_temp);

	KvRewind(kv_colors);

	KvJumpToKey(kv_colors, "colors")

	KvGetString(kv_colors, "color_tag", buff_temp, sizeof(buff_temp));
	strcopy(color_tag, 12, buff_temp);

	KvGetString(kv_colors, "color_name", buff_temp, sizeof(buff_temp));
	strcopy(color_name, 12, buff_temp);

	KvGetString(kv_colors, "color_steamid", buff_temp, sizeof(buff_temp));
	strcopy(color_steamid, 12, buff_temp);

	KvGetString(kv_colors, "color_use", buff_temp, sizeof(buff_temp));
	strcopy(color_use, 12, buff_temp);

	KvGetString(kv_colors, "color_pickup", buff_temp, sizeof(buff_temp));
	strcopy(color_pickup, 12, buff_temp);

	KvGetString(kv_colors, "color_drop", buff_temp, sizeof(buff_temp));
	strcopy(color_drop, 12, buff_temp);

	KvGetString(kv_colors, "color_disconnect", buff_temp, sizeof(buff_temp));
	strcopy(color_disconnect, 12, buff_temp);

	KvGetString(kv_colors, "color_death", buff_temp, sizeof(buff_temp));
	strcopy(color_death, 12, buff_temp);

	KvGetString(kv_colors, "color_warning", buff_temp, sizeof(buff_temp));
	strcopy(color_warning, 12, buff_temp);	

	CloseHandle(kv_colors);
}

//----------------------------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------------------------
public LoadMapConfigs()
{
	new String:buff_temp[64];
	new String:buff_mapname[64];

	GetCurrentMap(buff_mapname, sizeof(buff_mapname));
	
	Format(buff_temp, sizeof(buff_temp), "cfg/sourcemod/entwatch/%s.txt", buff_mapname);
	
	LogMessage("Loading %s", buff_temp);
	
	new Handle:kv = CreateKeyValues("entities");
	FileToKeyValues(kv, buff_temp);

	KvRewind(kv);
	if (!KvGotoFirstSubKey(kv))
	{
		LogMessage("Could not load %s", buff_temp);
	} 
	else
	{
		configLoaded = true;
		KvJumpToKey(kv, "0")
		for(new i = 0; i < 32; i++)
		{
			KvGetString(kv, "desc", buff_temp, sizeof(buff_temp));
			strcopy(entArray[i][ ent_desc ], 32, buff_temp);
			
			KvGetString(kv, "short_desc", buff_temp, sizeof(buff_temp));
			strcopy(entArray[i][ ent_shortdesc ], 32, buff_temp);
			
			KvGetString(kv, "color", buff_temp, sizeof(buff_temp));
			strcopy(entArray[i][ ent_color ], 32, buff_temp);
			
			KvGetString(kv, "name", buff_temp, sizeof(buff_temp));
			strcopy(entArray[i][ ent_name ], 32, buff_temp);
			
			KvGetString(kv, "type", buff_temp, sizeof(buff_temp));
			strcopy(entArray[i][ ent_type ], 32, buff_temp);
			
			KvGetString(kv, "button_type", buff_temp, sizeof(buff_temp));
			strcopy(entArray[i][ ent_buttontype ], 32, buff_temp);
			
			KvGetString(kv, "chat", buff_temp, sizeof(buff_temp));
			if(StrEqual(buff_temp, "true"))
				entArray[i][ ent_chat ] = true;
				
			KvGetString(kv, "hud", buff_temp, sizeof(buff_temp));
			if(StrEqual(buff_temp, "true"))
				entArray[i][ ent_hud ] = true;
			
			KvGetString(kv, "exactname", buff_temp, sizeof(buff_temp));
			if(StrEqual(buff_temp, "true"))
				entArray[i][ ent_exactname ] = true;

			KvGetString(kv, "singleactivator", buff_temp, sizeof(buff_temp));
			if(StrEqual(buff_temp, "true"))
				entArray[i][ ent_singleactivator ] = true;
			
			KvGetString(kv, "cooldown", buff_temp, sizeof(buff_temp));
			entArray[i][ ent_cooldown ] = StringToFloat(buff_temp);
			
			KvGetString(kv, "mode", buff_temp, sizeof(buff_temp));
			entArray[i][ ent_mode ] = StringToInt(buff_temp);
			
			KvGetString(kv, "maxuses", buff_temp, sizeof(buff_temp));
			entArray[i][ ent_maxuses ] = StringToInt(buff_temp);
			
			
			if(!KvGotoNextKey(kv))
			{
				arrayMax = i + 1;
				i = 32;
			}
		}
	}
	CloseHandle(kv);
}