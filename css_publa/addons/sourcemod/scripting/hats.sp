#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <regex>
#include <smlib>

#define PLUGIN_VERSION "1.0"

new g_Attachments[MAXPLAYERS+1] = { 0, ... };

new Handle:hatsName = INVALID_HANDLE;
new Handle:hatsModel = INVALID_HANDLE;
new Handle:hatsOffset = INVALID_HANDLE;
new Handle:hatsangles = INVALID_HANDLE;
new Handle:hatsFlags = INVALID_HANDLE;
new Handle:hatsSkins = INVALID_HANDLE;

new Handle:skinsOrig = INVALID_HANDLE;
new Handle:skinsRepl = INVALID_HANDLE;
new Handle:skinsWForward = INVALID_HANDLE;
new Handle:skinsWoForward = INVALID_HANDLE;

new Handle:hatcookie = INVALID_HANDLE;

new Handle:g_ctmodel = INVALID_HANDLE;
new Handle:g_tmodel = INVALID_HANDLE;
new Handle:g_show = INVALID_HANDLE;

new Handle:offsetRegex = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "Custom Hats Plugin",
	author = "Zephyrus",
	description = "Privately coded plugin.",
	version = PLUGIN_VERSION,
	url = ""
}

public OnPluginStart()
{
	g_ctmodel = CreateConVar("sm_hats_ctmodel", "models/player/ct_urban.mdl");
	g_tmodel = CreateConVar("sm_hats_tmodel", "models/player/t_leet.mdl");
	
	g_show = CreateConVar("sm_hats_show", "0");
	
	hatcookie = RegClientCookie("hat", "Hat ID", CookieAccess_Private);

	HookEvent("player_spawn", Event_Spawn);
	HookEvent("player_death", Event_Death);
	
	offsetRegex = CompileRegex("([^ ]*) ([^ ]*) ([^ ]*)");
	
	RegConsoleCmd("sm_hats", Show_HatMenu);
	
	skinsWForward = CreateArray(256);
	skinsWoForward = CreateArray(256);
}

public OnMapStart()
{
	new String:model[256];
	new String:model2[256];
	new String:name[32];
	new String:offset[32];
	new String:angles[32];
	new String:flags[40];
	new String:file[256];
	
	BuildPath(Path_SM, file, 255, "configs/hats.txt");
	
	new Handle:kv = CreateKeyValues("Hats");
	
	FileToKeyValues(kv, file);
	
	if (!KvGotoFirstSubKey(kv))
	{
		SetFailState("Errors with hats.txt");
		return;
	}
	
	hatsName = CreateArray(32);
	hatsModel = CreateArray(256);
	hatsOffset = CreateArray(32);
	hatsangles = CreateArray(32);
	hatsFlags = CreateArray(40);
	hatsSkins = CreateArray(11);
	skinsOrig = CreateArray(256);
	skinsRepl = CreateArray(256);
	
	new i = 0;
	
	do
	{
		ResizeArray(hatsName, GetArraySize(hatsName)+1);
		ResizeArray(hatsModel, GetArraySize(hatsModel)+1);
		ResizeArray(hatsOffset, GetArraySize(hatsOffset)+1);
		ResizeArray(hatsangles, GetArraySize(hatsangles)+1);
		ResizeArray(hatsFlags, GetArraySize(hatsFlags)+1);
		ResizeArray(hatsSkins, GetArraySize(hatsSkins)+1);
		KvGetSectionName(kv, name, sizeof(name));
		KvGetString(kv, "model", model, sizeof(model));
		KvGetString(kv, "offset", offset, sizeof(offset));
		KvGetString(kv, "angles", angles, sizeof(angles));
		KvGetString(kv, "flags", flags, sizeof(flags));
		
		SetArrayString(hatsName, i, name); 
		SetArrayString(hatsModel, i, model); 
		SetArrayString(hatsOffset, i, offset); 
		SetArrayString(hatsangles, i, angles);
		SetArrayString(hatsFlags, i, flags);
		SetArrayCell(hatsSkins, i, KvGetNum(kv, "skin", 0));
		
		PrecacheModel(model);
		++i;
	} while (KvGotoNextKey(kv));
	
	BuildPath(Path_SM, file, 255, "configs/skins.txt");
	
	kv = CreateKeyValues("Skins");
	FileToKeyValues(kv, file);
	
	if (!KvGotoFirstSubKey(kv))
	{
		PrintToServer("No first subkey");
		return;
	}
	
	i = 0;
	
	do
	{
		ResizeArray(skinsOrig, GetArraySize(skinsOrig)+1);
		ResizeArray(skinsRepl, GetArraySize(skinsRepl)+1);
		KvGetString(kv, "original", model, sizeof(model));
		KvGetString(kv, "replacement", model2, sizeof(model2));
		SetArrayString(skinsOrig, i, model); 
		SetArrayString(skinsRepl, i, model2);
		++i;
	} while (KvGotoNextKey(kv));
	
	CloseHandle(kv);
}

public bool:HasPermission(client, const String:flags[])
{
	if(GetUserFlagBits(client) & ReadFlagString(flags) || Client_HasAdminFlags(client, ADMFLAG_ROOT) || strcmp(flags, "")==0)
		return true;
	return false;
}

public Action:Show_HatMenu(client, args)
{
	new String:name[32];
	new String:flags[40];
	
	new Handle:menu = CreateMenu(HatHandler);
	SetMenuTitle(menu, "Hats");
	SetMenuExitButton(menu, true);
	
	new String:id[8];
	new hats=0;
	
	for(new i = 0;i<GetArraySize(hatsName);++i)
	{
		GetArrayString(hatsName, i, name, sizeof(name));
		GetArrayString(hatsFlags, i, flags, sizeof(flags));

		if(HasPermission(client, flags))
		{
			IntToString(i, id, sizeof(id));
			AddMenuItem(menu, id, name);
			hats++;
		}
	}
	
	if(hats == 0)
	{
		PrintToChat(client, "\x04[HATS]\x01 Sorry, there isn't any public hat.");
	}
	else
	{
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	
	return Plugin_Handled;
}

public HatHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:id[8];
		new String:model[256];
		new String:offset[32];
		new String:name[32];
		GetMenuItem(menu, param2, id, sizeof(id));

		GetArrayString(hatsModel, StringToInt(id), model, sizeof(model));
		GetArrayString(hatsOffset, StringToInt(id), offset, sizeof(offset));
		GetArrayString(hatsName, StringToInt(id), name, sizeof(name));

		new String:player[32];
		GetClientName(param1, player, sizeof(player));
		
		if(strcmp(model, "reset")==0)
		{
			id = "";
			if(IsValidEdict(EntRefToEntIndex(g_Attachments[param1])) && g_Attachments[param1] != 0)
			{
				SDKUnhook(EntRefToEntIndex(g_Attachments[param1]), SDKHook_SetTransmit, ShouldHide);
				AcceptEntityInput(EntRefToEntIndex(g_Attachments[param1]), "Kill");
				g_Attachments[param1] = 0;
			}
		}
			
		SetClientCookie(param1, hatcookie, id);
		
		if(IsPlayerAlive(param1) && GetEntProp(param1, Prop_Send, "m_lifeState") != 1)
			SpawnClientHat(param1);		
	}
	else if (action == MenuAction_Cancel)
	{
		
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public SpawnClientHat(client)
{
	new String:id[8] = "";
	
	GetClientCookie(client, hatcookie, id, sizeof(id));
	
	if(strcmp(id, "") != 0)
	{
		new String:model[256];
		new String:offset[32];
		new String:angles[32];
		
		new String:offsetx[10];
		new String:offsety[10];
		new String:offsetz[10];
		new String:angx[10];
		new String:angy[10];
		new String:angz[10];
		new skin = GetArrayCell(hatsSkins, StringToInt(id));
		
		GetArrayString(hatsModel, StringToInt(id), model, sizeof(model));
		GetArrayString(hatsOffset, StringToInt(id), offset, sizeof(offset));
		GetArrayString(hatsangles, StringToInt(id), angles, sizeof(angles));

		MatchRegex(offsetRegex, offset);
		
		GetRegexSubString(offsetRegex, 1, offsetx, sizeof(offsetx));
		GetRegexSubString(offsetRegex, 2, offsety, sizeof(offsety));
		GetRegexSubString(offsetRegex, 3, offsetz, sizeof(offsetz));
		
		MatchRegex(offsetRegex, angles);
		
		GetRegexSubString(offsetRegex, 1, angx, sizeof(angx));
		GetRegexSubString(offsetRegex, 2, angy, sizeof(angy));
		GetRegexSubString(offsetRegex, 3, angz, sizeof(angz));
			
		AddHat(client, model, StringToFloat(offsetx), StringToFloat(offsety), StringToFloat(offsetz), StringToFloat(angx), StringToFloat(angy), StringToFloat(angz), skin);
	}
}

public AddHat(client, String:model[], Float:offsetx, Float:offsety, Float:offsetz, Float:angx, Float:angy, Float:angz, skin)
{
	new Float:or[3];
	new Float:ang[3];
	new Float:fForward[3];
	new Float:fRight[3];
	new Float:fUp[3];
	GetClientAbsOrigin(client,or);
	GetClientAbsAngles(client,ang);
	
	ang[0] += angx;
	ang[1] += angy;
	ang[2] += angz;

	new Float:fOffset[3] = {0.0, 0.0, 0.0};
	fOffset[0] = offsetx;
	fOffset[1] = offsety;
	fOffset[2] = offsetz;

	GetAngleVectors(ang, fForward, fRight, fUp);

	or[0] += fRight[0]*fOffset[0]+fForward[0]*fOffset[1]+fUp[0]*fOffset[2];
	or[1] += fRight[1]*fOffset[0]+fForward[1]*fOffset[1]+fUp[1]*fOffset[2];
	or[2] += fRight[2]*fOffset[0]+fForward[2]*fOffset[1]+fUp[2]*fOffset[2];
	
	if(!IsModelPrecached(model))
	{
		PrintToConsole(client, "Model \"%s\" is not precached, preventing server crash.", model);
		return;
	}
	
	new ent = CreateEntityByName("prop_dynamic_override");
	
	new String:targetname[16];
	Format(targetname, sizeof(targetname), "attachment%i", client);
	DispatchKeyValue(ent, "targetname", targetname);
	DispatchKeyValue(ent, "model", model);
	DispatchKeyValue(ent, "spawnflags", "256");
	DispatchKeyValue(ent, "solid", "0");
	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);
	
	DispatchSpawn(ent);	
	AcceptEntityInput(ent, "TurnOn", ent, ent, 0);
	
	if(g_Attachments[client] != 0 && IsValidEdict(EntRefToEntIndex(g_Attachments[client])))
	{
		SDKUnhook(EntRefToEntIndex(g_Attachments[client]), SDKHook_SetTransmit, ShouldHide);
		AcceptEntityInput(EntRefToEntIndex(g_Attachments[client]), "Kill");
		g_Attachments[client] = 0;
	}
	
	g_Attachments[client] = EntIndexToEntRef(ent);
	
	SDKHook(ent, SDKHook_SetTransmit, ShouldHide);
	
	TeleportEntity(ent, or, ang, NULL_VECTOR); 
	
	new String:clientname[16];
	Format(clientname, sizeof(clientname), "target%i", client);
	DispatchKeyValue(client, "targetname", clientname);
	
	SetVariantString(clientname);
	AcceptEntityInput(ent, "SetParent", ent, ent, 0);
	
	new bool:replace = false;
	
	new String:cmodel[256];
	GetClientModel(client, cmodel, sizeof(cmodel));
	
	if(FindStringInArray(skinsWoForward, cmodel) == -1 && FindStringInArray(skinsWForward, cmodel) == -1)
	{		
		new String:file[FileSize(cmodel)];
		
		new ff[] = {'f', 'o', 'r', 'w', 'a', 'r', 'd'};
		
		new Handle:hfile = OpenFile(cmodel, "rb");
		ReadFileString(hfile, file, FileSize(cmodel), FileSize(cmodel));
		CloseHandle(hfile);
		
		new p = 0;
		
		for (new i = 0; i < FileSize(cmodel); i++)
		{
			if(file[i] == ff[p])
			{
				if(p<6)
				{
					p++;
					if(p==6)
						break;
				}
			}
			else
			{
				p=0;
			}
		}

		if(p!=6)
		{
			replace = true;
			ResizeArray(skinsWoForward, GetArraySize(skinsWoForward)+1);
			SetArrayString(skinsWoForward, GetArraySize(skinsWoForward)-1, cmodel); 
		}
		else
		{
			replace = false;
			ResizeArray(skinsWForward, GetArraySize(skinsWForward)+1);
			SetArrayString(skinsWForward, GetArraySize(skinsWForward)-1, cmodel); 
		}
	}
	else
	{
		if(FindStringInArray(skinsWoForward, cmodel) != -1)
			replace = true;
	}
	
	if(replace)
	{
		new String:vmodel[256];
		new index = FindStringInArray(skinsOrig, cmodel);
		if(index == -1)
		{
			if(GetClientTeam(client) == 2)
			{
				GetConVarString(g_tmodel, vmodel, sizeof(vmodel));
			} else if(GetClientTeam(client) == 3)
			{
				GetConVarString(g_ctmodel, vmodel, sizeof(vmodel));
			}
		}
		else
		{
			GetArrayString(skinsRepl, index, vmodel, sizeof(vmodel));
		}
		
		SetEntityModel(client, vmodel);
	}

	SetVariantString("forward");
	AcceptEntityInput(ent, "SetParentAttachmentMaintainOffset", ent, ent, 0);
	SetEntProp(ent, Prop_Send, "m_nSkin", skin);
}

public Action:Event_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	new String:id[8] = "";
	GetClientCookie(client, hatcookie, id, sizeof(id));
	
	if(IsValidEdict(EntRefToEntIndex(g_Attachments[client])) && g_Attachments[client] != 0)
	{
		SDKUnhook(EntRefToEntIndex(g_Attachments[client]), SDKHook_SetTransmit, ShouldHide);
		AcceptEntityInput(EntRefToEntIndex(g_Attachments[client]), "Kill");
	}
	
	g_Attachments[client] = 0;
	
	if(strcmp(id, "") != 0)
	{
		if(StringToInt(id) < GetArraySize(hatsFlags))
		{
			if(IsClientInGame(client))
			{
				if(IsValidEdict(client))
				{
					if(IsPlayerAlive(client))
					{
						new String:flags[40];
						GetArrayString(hatsFlags, StringToInt(id), flags, sizeof(flags));
						if(HasPermission(client, flags))
						{
							CreateTimer(0.1, SpawnHat, client);
						}
					}
				}
			}
		}
		else
		{
			SetClientCookie(client, hatcookie, "");
		}
	}
	return Plugin_Continue
}

public Action:SpawnHat(Handle:timer, any:client)
{
	if(IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_lifeState") != 1)
		SpawnClientHat(client);
	return Plugin_Stop;
}

public Action:Event_Death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidEdict(EntRefToEntIndex(g_Attachments[client])) && g_Attachments[client] != 0)
	{
		SDKUnhook(EntRefToEntIndex(g_Attachments[client]), SDKHook_SetTransmit, ShouldHide);
		AcceptEntityInput(EntRefToEntIndex(g_Attachments[client]), "Kill");
		g_Attachments[client] = 0;
	}
	return Plugin_Continue
}

public Action:ShouldHide(ent, client)
{
	for(new i=0;i<=MaxClients;++i)
	{
		if(g_Attachments[i] == ent)
		{
			if(!IsPlayerAlive(i))
			{
				SDKUnhook(EntRefToEntIndex(g_Attachments[client]), SDKHook_SetTransmit, ShouldHide);
				AcceptEntityInput(EntRefToEntIndex(g_Attachments[client]), "Kill");
				g_Attachments[client] = 0;
				return Plugin_Continue;
			}
		}
	}
	if((ent == EntRefToEntIndex(g_Attachments[client]) || (GetEntProp(client, Prop_Send, "m_iObserverMode") == 4 && ent == EntRefToEntIndex(g_Attachments[GetEntPropEnt(client, Prop_Send, "m_hObserverTarget")]))) && !GetConVarBool(g_show) )
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}