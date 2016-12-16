//-----------------------------------------------------------------------------
// Purpose:
//-----------------------------------------------------------------------------
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <clientprefs>
#include <morecolors>

new Handle:g_hDropWeapon;

enum entities
{
	String:ent_desc[32],
	String:ent_shortdesc[32],
	String:ent_color[32],
	String:ent_name[32],
	String:ent_originalname[32],
	bool:ent_exactname[32],
	bool:ent_singleactivator[32],
	String:ent_type[32],
	String:ent_buttontype[32],
	bool:ent_chat[32],
	bool:ent_hud[32],
	String:ent_ownername[32],
	ent_buttonid,
	ent_owner,
	ent_id,
	ent_maxuses,
	ent_uses,
	Float:ent_cooldown,
	bool:ent_hudcooldown,
	ent_cooldowncount,
	ent_canuse
}

// Now we need a variable that holds the player info
new entArray[ 32 ][ entities ];
new arrayMax = 0;

new bool:configLoaded;
new Handle:hudCookie;
new Handle:global_cooldowns;

public Plugin:myinfo =
{
	name = "entWatch",
	author = "Prometheum",
	description = "#ZOMG #YOLO | Finds entities and hooks events relating to them.",
	version = "1.5",
	url = "https://github.com/Prometheum/entWatch"
};

//-----------------------------------------------------------------------------
// Purpose:
//-----------------------------------------------------------------------------
public OnPluginStart()
{
	global_cooldowns = CreateConVar("entW_cooldowns", "1", "Turns cooldowns/off");

	CreateConVar("sm_entW_version", "1.5", "Current version of entWatch", FCVAR_NOTIFY);
	
	RegConsoleCmd("entW_find", Command_FindEnts, "Finds Entitys matching an argument", ADMFLAG_KICK);
	RegConsoleCmd("entW_dumpmap", Command_dumpmap, "Finds Entitys matching an argument", ADMFLAG_KICK);
	RegConsoleCmd("hud", Command_dontannoyme);
	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);	
	HookEvent("item_pickup", OnItemPickup);
	
	hudCookie = RegClientCookie("entWatch_displayhud", "EntWatch DisplayHud", CookieAccess_Protected);
	
	CreateTimer(1.0, Timer_DisplayHud, _, TIMER_REPEAT);
	CreateTimer(1.0, Timer_Cooldowns, _, TIMER_REPEAT);
	
	LoadTranslations("entwatch.phrases");
	
	new Handle:hGameConf = LoadGameConfigFile("entwatch.games");
	if (hGameConf == INVALID_HANDLE)
	{
		SetFailState("Unable to load gamedata file entwatch.games.txt");
	}

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CSWeaponDrop");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_hDropWeapon = EndPrepSDKCall();	
}

//-----------------------------------------------------------------------------
// Purpose:
//-----------------------------------------------------------------------------
public OnMapStart()
{
	decl String:buff_mapname[64];
	decl String:buff_temp[64];
	
	decl String:buff_desc[32];
	decl String:buff_shortdesc[32];
	decl String:buff_color[32];
	decl String:buff_name[32];
	decl String:buff_exactname[32];
	decl String:buff_singleactivator[32];
	decl String:buff_type[32];
	decl String:buff_buttontype[32];
	decl String:buff_chat[32];
	decl String:buff_hud[32];
	decl String:buff_cooldown[32];
	decl String:buff_hudcooldown[32];
	decl String:buff_maxuses[32];
	
	configLoaded = false;
	
	GetCurrentMap(buff_mapname, sizeof(buff_mapname));
	
	arrayMax = 0;
	
	for (new i = 0; i < 32; i++)
	{
		strcopy( entArray[ i ][ ent_desc ], 32, "null" );
		strcopy( entArray[ i ][ ent_shortdesc ], 32, "" );
		strcopy( entArray[ i ][ ent_color ], 32, "null" );
		strcopy( entArray[ i ][ ent_name ], 32, "null" );
		strcopy( entArray[ i ][ ent_type ], 32, "null" );
		strcopy( entArray[ i ][ ent_buttontype ], 32, "null" );
		entArray[ i ][ ent_chat ] = false;
		entArray[ i ][ ent_hud ] = false;
		strcopy( entArray[ i ][ ent_ownername ], 32, "" );
		entArray[i][ent_buttonid] = -1;
		entArray[i][ent_id] = -1;
		entArray[i][ent_owner] = -1;
		entArray[i][ent_maxuses] = 0;
		entArray[i][ent_uses] = 0;
		entArray[i][ent_cooldown] = 2.0;
		entArray[i][ent_hudcooldown] = true;
		entArray[i][ent_cooldowncount] = 0;
		entArray[i][ent_canuse] = 1;
		entArray[i][ent_exactname] = false;
		entArray[i][ent_singleactivator] = false;
	}	
	
	strcopy(buff_temp, sizeof(buff_temp), "cfg/sourcemod/entWatch/");
	StrCat(buff_temp, sizeof(buff_temp), buff_mapname);
	StrCat(buff_temp, sizeof(buff_temp), ".txt");
	
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
		KvJumpToKey(kv, "0")
		configLoaded = true;
		for(new i = 0; i < 32; i++)
		{

			KvGetString(kv, "desc", buff_desc, sizeof(buff_desc));
			KvGetString(kv, "short_desc", buff_shortdesc, sizeof(buff_shortdesc));
			KvGetString(kv, "color", buff_color, sizeof(buff_color));
			KvGetString(kv, "name", buff_name, sizeof(buff_name));
			KvGetString(kv, "exactname", buff_exactname, sizeof(buff_exactname));
			KvGetString(kv, "singleactivator", buff_singleactivator, sizeof(buff_singleactivator));
			KvGetString(kv, "type", buff_type, sizeof(buff_type));
			KvGetString(kv, "button_type", buff_buttontype, sizeof(buff_buttontype));
			KvGetString(kv, "chat", buff_chat, sizeof(buff_chat));
			KvGetString(kv, "hud", buff_hud, sizeof(buff_hud));
			KvGetString(kv, "maxuses", buff_maxuses, sizeof(buff_maxuses));
			KvGetString(kv, "cooldown", buff_cooldown, sizeof(buff_cooldown));
			KvGetString(kv, "cooldown_hud", buff_hudcooldown, sizeof(buff_hudcooldown));
			
			strcopy(entArray[i][ent_desc], 32, buff_desc);
			strcopy(entArray[i][ent_shortdesc], 32, buff_shortdesc);
			strcopy(entArray[i][ent_color], 32, buff_color);
			strcopy(entArray[i][ent_name], 32, buff_name);
			strcopy(entArray[i][ent_originalname], 32, buff_name);
			strcopy(entArray[i][ent_type], 32, buff_type);
			strcopy(entArray[i][ent_buttontype], 32, buff_buttontype);

			if(StrEqual(buff_hudcooldown, "false"))
				entArray[i][ent_hudcooldown] = false;
			else
				entArray[i][ent_hudcooldown] = true;	
			
			if(StrEqual(buff_chat, "false"))
				entArray[i][ent_chat] = false;
			else
				entArray[i][ent_chat] = true;	
			if(StrEqual(buff_hud, "false"))
				entArray[i][ent_hud] = false;
			else
				entArray[i][ent_hud] = true;	
				
			if(StrEqual(buff_exactname, "false"))
				entArray[i][ent_exactname] = false;
			else
				entArray[i][ent_exactname] = true;	
				
			if(StrEqual(buff_singleactivator, "true"))
				entArray[i][ent_singleactivator] = true;
			else
				entArray[i][ent_singleactivator] = false;			
			
			entArray[i][ent_maxuses] = StringToInt(buff_maxuses);
			entArray[i][ent_cooldown] = StringToFloat(buff_cooldown);
				
			if(!KvGotoNextKey(kv))
			{
				arrayMax = i + 1;
				i = 32;
			}
		}
	}
	CloseHandle(kv);
}

//-----------------------------------------------------------------------------
// Purpose:
//-----------------------------------------------------------------------------
public OnEntityCreated(entity, const String:classname[])
{
	if(configLoaded)
	{
		if(StrContains(classname, "weapon", false) != -1)
		{
			SDKHook(entity, SDKHook_StartTouch, OnEntityTouch);		
		}
	}
}

//-----------------------------------------------------------------------------
// Purpose:
//-----------------------------------------------------------------------------
public Action:OnEntityTouch(entity, Client)
{
	new b;
	new bool:recordExists=false;
	
	if(Entity_IsPlayer(Client))
	{
		for(new i = 0; i < arrayMax; i++)
		{
			if(entArray[i][ent_id] == entity)
			{
				recordExists=true;
			}
		}
		
		if(!recordExists)
		{
			b = FindEntityByName(entity);
			if(b!=-1)
			HookButton(b);
		}
	}
}

//-----------------------------------------------------------------------------
// Purpose:
//-----------------------------------------------------------------------------
public Action:OnEntityUse(entity, activator, caller, UseType:type, Float:value)
{
	for(new i = 0; i < arrayMax; i++)
	{
		if(entArray[i][ent_singleactivator] == true)
		{
			if(entArray[i][ent_buttonid] == entity && entArray[i][ent_canuse] == 1 && entArray[i][ent_owner] == activator && entArray[i][ent_uses] < entArray[i][ent_maxuses] && entArray[i][ent_cooldowncount] == 0)
			{
				PrintToChatAll("\x072570A5[entWatch] \x0700DA00%N \x072570A5%t \x07%s%s", caller, "use", entArray[i][ent_color], entArray[i][ent_desc]);
				entArray[i][ent_uses]++;
				entArray[i][ent_cooldowncount] = RoundToNearest(entArray[i][ent_cooldown]);		
			}			
		}
		else if(entArray[i][ent_singleactivator] == false)
		{
			if(entArray[i][ent_buttonid] == entity && entArray[i][ent_canuse] == 1 && entArray[i][ent_uses] < entArray[i][ent_maxuses] && entArray[i][ent_cooldowncount] == 0)
			{
				PrintToChatAll("\x072570A5[entWatch] \x0700DA00%N \x072570A5%t \x07%s%s", caller, "use", entArray[i][ent_color], entArray[i][ent_desc]);
				entArray[i][ent_uses]++;
				entArray[i][ent_cooldowncount] = RoundToNearest(entArray[i][ent_cooldown]);				
			}			
		}		
	}
}

//-----------------------------------------------------------------------------
// Purpose:
//-----------------------------------------------------------------------------
public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 0; i < arrayMax; i++)
	{
		strcopy( entArray[ i ][ ent_name ], 32, entArray[ i ][ent_originalname] );
		strcopy( entArray[ i ][ ent_ownername ], 32, "" );
		entArray[i][ent_buttonid] = -1;
		entArray[i][ent_id] = -1;
		entArray[i][ent_owner] = -1;
		entArray[i][ent_uses] = 0;
		entArray[i][ent_canuse] = 1;
	}
	
	if(configLoaded)
	{
		CPrintToChatAll("\x073600FF[entWatch]\x0701A8FF %t \x073600FFPrometheum & Bauxe", "welcome");
	}	
}

//-----------------------------------------------------------------------------
// Purpose:
//-----------------------------------------------------------------------------
public Action:OnItemPickup(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:playername[32];	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	GetClientName(client, playername, sizeof(playername))
	
	new iWeaponEnt = -1;
	for(new iSlot=0; iSlot<5; iSlot++)
	{
		iWeaponEnt = GetPlayerWeaponSlot(client, iSlot); 
		for (new i = 0; i < arrayMax; i++)
		{
			if(entArray[i][ent_chat] && entArray[i][ent_id] == iWeaponEnt && entArray[i][ent_id] != -1 && IsPlayerAlive(client) && entArray[i][ent_owner] != client)
			{
				CPrintToChatAll("\x07FFFF00[entWatch] \x0700DA00%s \x07FFFF00%t \x07%s%s", playername, "pickup", entArray[ i ][ ent_color ], entArray[ i ][ ent_desc ]);
				entArray[ i ][ ent_owner ] = client;
				strcopy(entArray[i][ent_ownername], 32, playername);
				i=arrayMax;
				iSlot=5;				
			}	
		}
	}
}

//-----------------------------------------------------------------------------
// Purpose:
//-----------------------------------------------------------------------------
public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	for (new i = 0; i < arrayMax; i++)
	{
		if(entArray[i][ent_chat] && entArray[i][ent_owner] == client)
		{
			CPrintToChatAll("\x0784289E[entWatch] \x0700DA00%N \x0784289E%t \x07%s%s", client, "death", entArray[ i ][ ent_color ], entArray[ i ][ ent_desc ]);
			entArray[ i ][ ent_owner ] = -1;
			strcopy(entArray[i][ent_ownername], 32, "");
			SDKCall(g_hDropWeapon, client, entArray[ i ][ ent_id ], false, false);
			i=arrayMax;
		}	
	}
}

public OnClientDisconnect(client)
{
	for (new i = 0; i < arrayMax; i++)
	{
		if(entArray[i][ent_chat] && entArray[i][ent_owner] == client)
		{
			CPrintToChatAll("\x07A67CB2[entWatch] \x0700DA00%N \x07A67CB2%t \x07%s%s!", client, "disconnect", entArray[ i ][ ent_color ], entArray[ i ][ ent_desc ]);
			entArray[ i ][ ent_owner ] = -1;
			strcopy(entArray[i][ent_ownername], 32, "");
		}	
	}
}  

//-----------------------------------------------------------------------------
// Purpose:
//-----------------------------------------------------------------------------
public Action:CS_OnCSWeaponDrop(client, weaponIndex)
{
	if(IsClientConnected(client))
	{
		decl String:playername[32];
		GetClientName(client, playername, sizeof(playername))	
		for (new i = 0; i < arrayMax; i++)
		{
			if(entArray[i][ent_owner] == client && entArray[i][ent_chat] && entArray[i][ent_id] == weaponIndex && IsPlayerAlive(client))
			{
				CPrintToChatAll("\x079E0000[entWatch] \x0700DA00%N \x079E0000%t \x07%s%s", client, "drop", entArray[ i ][ ent_color ], entArray[ i ][ ent_desc ]);
				playername="";
				strcopy(entArray[i][ent_ownername], 32, playername);
				entArray[ i ][ ent_owner ] = -1;
			}
		}
	}
}

//-----------------------------------------------------------------------------
// Purpose:
//-----------------------------------------------------------------------------
public Action:Command_FindEnts(client, args)
{
	new String:namea[32];
	new String:namebuf[32];
	
	new String: arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1) );
	for (new i=0; i<=GetEntityCount(); i++)
	{
		if(IsValidEdict(i))
		{
			GetEdictClassname(i, namea, sizeof(namea))
			GetEntPropString(i, Prop_Data, "m_iName", namebuf, sizeof(namebuf));
			
			if(StrEqual(namea, arg1))
			{
				PrintToConsole(client, "%d |  Name: %s, Type: %s", i, namebuf, namea);
			}
		}
	}
}

//-----------------------------------------------------------------------------
// Purpose:
//-----------------------------------------------------------------------------
public Action:Command_dumpmap(client, args)
{
	PrintToConsole(client, "\n[entWatch]\nIf the ID is -1 it can't find the ent\n");
	for (new i = 0; i < arrayMax; i++)
	{
		CPrintToChatAll("\n");
		CPrintToChatAll("%d | %s", i, entArray[i][ent_desc]);
		CPrintToChatAll("%d | %s", i, entArray[i][ent_shortdesc]);
		CPrintToChatAll("%d | %s", i, entArray[i][ent_color]);
		CPrintToChatAll("%d | %s", i, entArray[i][ent_name]);
		CPrintToChatAll("%d | %s", i, entArray[i][ent_type]);
		CPrintToChatAll("%d | %s", i, entArray[i][ent_ownername]);
		CPrintToChatAll("%d | %d", i, entArray[i][ent_id]);
		CPrintToChatAll("%d | %d", i, entArray[i][ent_owner]);
	}
}

//-----------------------------------------------------------------------------
// Purpose:
//-----------------------------------------------------------------------------
public Action:Command_dontannoyme(client, args)
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
}

//-----------------------------------------------------------------------------
// Purpose:
//-----------------------------------------------------------------------------
public Action:Timer_DisplayHud(Handle:timer)
{
	if(configLoaded)
	{
		decl String:szText[254];
		decl String:buffer[32];
		decl String:temp[32];
		
		for (new i = 1; i < MaxClients; i++)
		{
			if (AreClientCookiesCached(i))
			{
				szText[0] = '\0';
				GetClientCookie(i, hudCookie, buffer, sizeof(buffer));
				if(StrEqual(buffer, "0") && IsClientConnected(i))
				{
					for (new x = 0; x < 16; x++)
					{
						if(entArray[x][ent_hud] && !StrEqual(entArray[x][ent_ownername], "") )
						{
							StrCat(szText, sizeof(szText), entArray[x][ent_shortdesc]);
							if(GetConVarInt(global_cooldowns) == 1)
							{
								StrCat(szText, sizeof(szText), "[");
								if(entArray[x][ent_hudcooldown] && entArray[x][ent_uses] < entArray[x][ent_maxuses])
								{
									if(entArray[x][ent_cooldowncount] == 0)
										StrCat(szText, sizeof(szText), "R");
									else
									{
										IntToString(entArray[x][ent_cooldowncount], temp, sizeof(temp));
										StrCat(szText, sizeof(szText), temp);
									}
								}
								else
								{
									StrCat(szText, sizeof(szText), "N/A");
								}
								StrCat(szText, sizeof(szText), "]");	
							}							
							StrCat(szText, sizeof(szText), ": ");
							StrCat(szText, sizeof(szText), entArray[x][ent_ownername]);
							
							StrCat(szText, sizeof(szText), "\n");						
						}
					}
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

//-----------------------------------------------------------------------------
// Purpose:
//-----------------------------------------------------------------------------
public Action:Timer_Cooldowns(Handle:timer)
{
	for (new i = 0; i < arrayMax; i++)
	{
		if(entArray[i][ent_cooldowncount] == 0)
		{
		
		}
		else
		{
			entArray[i][ent_cooldowncount] = entArray[i][ent_cooldowncount] - 1;
		}
	}
}

//-----------------------------------------------------------------------------
// Purpose: Entity Functions
//-----------------------------------------------------------------------------
public FindEntityByName(entity)
{
	decl String:targetname[32];
	Entity_GetTargetName(entity, targetname, sizeof(targetname));
	decl String:temp[32];
	for(new i = 0; i < arrayMax; i++)
	{ 
		if(entArray[i][ent_id] == -1)
		{
			strcopy( temp, 32, entArray[i][ent_name]);
			if(!entArray[i][ent_exactname])
			{
				if(StrContains(targetname, temp, false) != -1)
				{
					entArray[i][ent_id] = entity;
					strcopy(entArray[i][ent_name], 32, targetname);
					return i;
				}
			}
			else
			{
				if(strcmp(targetname, temp, false) == 0)
				{
					entArray[i][ent_id] = entity;
					strcopy(entArray[i][ent_name], 32, targetname);
					return i;
				}
			}					
		}
	}
	return -1;
}

public HookButton(rootEntity)
{
	decl String:tempA[32];
	decl String:tempB[32];
	for(new i=0; i < GetEntityCount(); i++)
	{
		if(IsValidEdict(i))
		{
			GetEntityClassname(i, tempA, sizeof(tempA));
			if(StrEqual(tempA, entArray[rootEntity][ent_buttontype]))
			{
				Entity_GetParentName(i, tempB, sizeof(tempB));
				if(StrEqual(tempB, entArray[rootEntity][ent_name]))
				{
					entArray[rootEntity][ent_buttonid] = i;
					SDKHook(i, SDKHook_Use, OnEntityUse);	
				}
			}
		}
	}
}


//-----------------------------------------------------------------------------
// Purpose: SMLib
//-----------------------------------------------------------------------------
stock bool:Entity_IsPlayer(entity)
{
	if (entity < 1 || entity > MaxClients) {
		return false;
	}
	
	return true;
}

stock Entity_GetTargetName(entity, String:buffer[], size)
{
	return GetEntPropString(entity, Prop_Data,  "m_iName", buffer, size);
}

stock Entity_GetParentName(entity, String:buffer[], size)
{
	return GetEntPropString(entity, Prop_Data, "m_iParent", buffer, size);
}

stock Entity_SetParentName(entity, const String:name[], any:...)
{
	decl String:format[128];
	VFormat(format, sizeof(format), name, 3);

	return DispatchKeyValue(entity, "parentname", format);
}
