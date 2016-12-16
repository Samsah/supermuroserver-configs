/*<DR.API SMOKEGRENADE COLORS>(c) by <De Battista Clint -(http://doyou.watch)*/
/*																			 */
/*			  <DR.API SMOKEGRENADE COLORS> is licensed under a				 */
/* Creative Commons Attribution-NonCommercial-NoDerivs 4.0 Unported License. */
/*																			 */
/*		You should have received a copy of the license along with this		 */
/*	work.  If not, see <http://creativecommons.org/licenses/by-nc-nd/4.0/>.	 */
//***************************************************************************//
//***************************************************************************//
//*************************DR.API SMOKEGRENADE COLORS************************//
//***************************************************************************//
//***************************************************************************//

#pragma semicolon 1

//***********************************//
//*************DEFINE****************//
//***********************************//
#define PLUGIN_VERSION					"1.3.5"
#define CVARS							FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY
#define DEFAULT_FLAGS					FCVAR_PLUGIN|FCVAR_NOTIFY
#define TAG_CHAT						"[SMOKEGRENADE COLORS] -"
#define MAX_SMOKE_COLORS				50
#define MAX_SMOKE_COLORS_STEAMID		25
#define MAX_SMOKE_THROW					5000

//***********************************//
//*************INCLUDE***************//
//***********************************//

#undef REQUIRE_PLUGIN
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <autoexec>
#include <csgocolors>


#pragma newdecls required

//***********************************//
//***********PARAMETERS**************//
//***********************************//

//Handle
Handle cvar_active_smokegrenade_colors_dev;

Handle cvar_smokegrenade_colors_min_alpha;
Handle cvar_smokegrenade_colors_max_alpha;

Handle cvar_smokegrenade_colors_mod;

Handle H_TimerScreenEffect[MAX_SMOKE_THROW];
Handle CookieSmokeColors;
Handle CookieSmokeColorsConnect;
Handle Array_MultiSmokeColors[MAXPLAYERS + 1];

//Bool
bool B_active_smokegrenade_colors_dev					= false;

bool B_SmokeColors_SteamID[MAXPLAYERS+1][MAX_SMOKE_COLORS];
bool B_OriginalSmoke[MAX_SMOKE_THROW] 					= false;

//Strings
char S_smokecolorsparticlefile[MAX_SMOKE_COLORS][PLATFORM_MAX_PATH];
char S_smokecolorsparticlename[MAX_SMOKE_COLORS][PLATFORM_MAX_PATH];
char S_smokecolorsparticlecolor[MAX_SMOKE_COLORS][PLATFORM_MAX_PATH];
char S_smokecolorsflag[MAX_SMOKE_COLORS][64];
char S_smokecolorssteamid[MAX_SMOKE_COLORS][MAX_SMOKE_COLORS_STEAMID][64];
														  
//Customs
int C_smokegrenade_colors_min_alpha;
int C_smokegrenade_colors_max_alpha;
int C_smokegrenade_colors_mod;

int C_color_smoke[MAXPLAYERS + 1];
int C_getcolor[MAX_SMOKE_THROW][MAXPLAYERS + 1];
int C_CountDown[MAX_SMOKE_THROW];
int smoke_count 										= 0;
int max_smoke_colors;
int max_smoke_colors_steamid[MAX_SMOKE_COLORS];

//int LaserMaterial;
//int HaloMaterial;

//Informations plugin
public Plugin myinfo =
{
	name = "DR.API SMOKEGRENADE COLORS",
	author = "Dr. Api",
	description = "DR.API SMOKEGRENADE COLORS by Dr. Api",
	version = PLUGIN_VERSION,
	url = "http://zombie4ever.eu"
}
/***********************************************************/
/*********************** PLUGIN START **********************/
/***********************************************************/
public void OnPluginStart()
{
	LoadTranslations("drapi/drapi_smokegrenade_colors.phrases");
	AutoExecConfig_SetFile("drapi_smokegrenade_colors", "sourcemod/drapi");
	
	AutoExecConfig_CreateConVar("drapi_smokegrenade_colors_version", PLUGIN_VERSION, "Version", CVARS);
	
	cvar_active_smokegrenade_colors_dev			= AutoExecConfig_CreateConVar("drapi_active_smokegrenade_colors_dev",		"0",				"Enable/Disable Dev Mod",								DEFAULT_FLAGS,		true, 0.0,		true, 1.0);
	
	cvar_smokegrenade_colors_min_alpha			= AutoExecConfig_CreateConVar("drapi_smokegrenade_colors_min_alpha",		"180.0",			"Min. Alpha overlay (transparency)",					DEFAULT_FLAGS);
	cvar_smokegrenade_colors_max_alpha			= AutoExecConfig_CreateConVar("drapi_smokegrenade_colors_max_alpha",		"255.0",			"Max. Alpha overlay (transparency)",					DEFAULT_FLAGS);
	
	cvar_smokegrenade_colors_mod				= AutoExecConfig_CreateConVar("drapi_smokegrenade_colors_mod",				"0",				"0=Access Flag / 1=Random Colors",						DEFAULT_FLAGS);
		
	HookEvent("round_start",	Event_RoundStart);
	HookEvent("smokegrenade_detonate", Event_SmokeDetonate, EventHookMode_Pre);
	
	AddTempEntHook("EffectDispatch", TE_EffectDispatch);
	
	HookEventsCvars();
	
	AutoExecConfig_ExecuteFile();
	
	RegConsoleCmd("sm_sc",		Command_BuildMenuSmokeColors);
	RegConsoleCmd("sm_retry",	Command_Retry);
	
	RegAdminCmd("sm_entities", 	Command_Entities, ADMFLAG_CHANGEMAP, "");
	RegAdminCmd("sm_smoke", 	Command_Smoke, ADMFLAG_CHANGEMAP, "");
	RegAdminCmd("sm_csm", 		Command_ClearCookies, ADMFLAG_CHANGEMAP, "");
	RegAdminCmd("sm_sf", 		Command_ForceSmoke, ADMFLAG_CHANGEMAP, "");
	
	RegAdminCmd("sm_dumpstringtables", Cmd_DumpStringtables, ADMFLAG_CHANGEMAP, "");
	RegAdminCmd("sm_dumpdispatcheffect", Cmd_DumpDispatchEffect, ADMFLAG_CHANGEMAP, "");
	RegAdminCmd("sm_dumpparticleeffectname", Cmd_DumpParticleEffectName, ADMFLAG_CHANGEMAP, "");
	RegAdminCmd("sm_dumpextraparticlefilestable", Cmd_DumpExtraParticleFilesTable, ADMFLAG_CHANGEMAP, "");
	RegAdminCmd("sm_dumpgeneric", Cmd_DumpGenericPrecache, ADMFLAG_CHANGEMAP, "");
	RegAdminCmd("sm_dumpuser", Cmd_DumpUser, ADMFLAG_CHANGEMAP, "");
	RegAdminCmd("sm_dumpdownload", Cmd_DumpDownload, ADMFLAG_CHANGEMAP, "");
	
		
	AddCommandListener(Event_Say, "say");
	AddCommandListener(Event_Say, "say_team");
	
	CookieSmokeColors					= RegClientCookie("CookieSmokeColors", "", CookieAccess_Private);
	CookieSmokeColorsConnect			= RegClientCookie("CookieSmokeColorsConnect", "", CookieAccess_Private);
	
	int info;
	SetCookieMenuItem(SmokeColorsCookieHandler, info, "Smoke Colors");
	
	int i = 1;
	while(i <= MaxClients)
	{
		if(IsClientInGame(i))
		{
			if(Array_MultiSmokeColors[i] == INVALID_HANDLE)
			{
				Array_MultiSmokeColors[i] = CreateArray(3);
			}
			
			if(AreClientCookiesCached(i))
			{
				OnClientCookiesCached(i);
			}
		}
		i++;
	}
	
	//LaserMaterial 	= PrecacheModel("materials/sprites/laserbeam.vmt");
	//HaloMaterial 	= PrecacheModel("materials/sprites/halo.vmt");
}

/***********************************************************/
/************************ PLUGIN END ***********************/
/***********************************************************/
public void OnPluginEnd()
{
	RemoveTempEntHook("EffectDispatch", TE_EffectDispatch);
	
	for(int i = 0; i < smoke_count; i++)
	{
		if(H_TimerScreenEffect[i] != INVALID_HANDLE)
		{
			ClearTimer(H_TimerScreenEffect[i]);
		}
		B_OriginalSmoke[smoke_count] = false;
	}
	
	int i = 1;
	while (i <= MaxClients)
	{
		if(IsClientInGame(i))
		{
			if(Array_MultiSmokeColors[i] != INVALID_HANDLE)
			{
				CloseHandle(Array_MultiSmokeColors[i]);
				Array_MultiSmokeColors[i] = INVALID_HANDLE;
			}
		}
		i++;
	}
	smoke_count = 0;
}

/***********************************************************/
/******************** WHEN CVAR CHANGED ********************/
/***********************************************************/
void HookEventsCvars()
{
	HookConVarChange(cvar_active_smokegrenade_colors_dev,				Event_CvarChange);
	
	HookConVarChange(cvar_smokegrenade_colors_min_alpha,				Event_CvarChange);
	HookConVarChange(cvar_smokegrenade_colors_max_alpha,				Event_CvarChange);
	
	HookConVarChange(cvar_smokegrenade_colors_mod,						Event_CvarChange);
}

/***********************************************************/
/******************** WHEN CVARS CHANGE ********************/
/***********************************************************/
public void Event_CvarChange(Handle cvar, const char[] oldValue, const char[] newValue)
{
	UpdateState();
}

/***********************************************************/
/*********************** UPDATE STATE **********************/
/***********************************************************/
void UpdateState()
{
	B_active_smokegrenade_colors_dev									= GetConVarBool(cvar_active_smokegrenade_colors_dev);
	
	C_smokegrenade_colors_min_alpha										= GetConVarInt(cvar_smokegrenade_colors_min_alpha);
	C_smokegrenade_colors_max_alpha										= GetConVarInt(cvar_smokegrenade_colors_max_alpha);
	
	C_smokegrenade_colors_mod											= GetConVarInt(cvar_smokegrenade_colors_mod);
}

/***********************************************************/
/********************* WHEN MAP START **********************/
/***********************************************************/
public void OnMapStart()
{
	LoadSettings();
	
	for(int i = 0; i < max_smoke_colors; i++)
	{
		if(i > 0)
		{
			char S_path[PLATFORM_MAX_PATH];
			Format(S_path, PLATFORM_MAX_PATH, "particles/%s.pcf", S_smokecolorsparticlefile[i]);
			
			AddFileToDownloadsTable(S_path);
			
			PrecacheGeneric(S_path, true);
			PrecacheEffect("ParticleEffect");
			PrecacheParticleEffect(S_smokecolorsparticlename[i]);			
		}
	}
	smoke_count = 0;
	
	UpdateState();
}

/***********************************************************/
/**************** WHEN CLIENT PUT IN SERVER ****************/
/***********************************************************/
public void OnClientPostAdminCheck(int client)
{
	SaveCookies(client, false);
}

/***********************************************************/
/***************** WHEN CLIENT DISCONNECT ******************/
/***********************************************************/
public void OnClientDisconnect(int client)
{
	if(Array_MultiSmokeColors[client] != INVALID_HANDLE)
	{
		CloseHandle(Array_MultiSmokeColors[client]);
		Array_MultiSmokeColors[client] = INVALID_HANDLE;
	}
}

/***********************************************************/
/**************** ON CLIENT COOKIE CACHED ******************/
/***********************************************************/
public void OnClientCookiesCached(int client)
{
	char value[16];
	
	GetClientCookie(client, CookieSmokeColors, value, sizeof(value));
	if(strlen(value) > 0) 
	{
		C_color_smoke[client] = StringToInt(value);
	}
	else 
	{
		if(IsFakeClient(client))
		{
			C_color_smoke[client] = 100;
		}
		else
		{
			C_color_smoke[client] = 0;
		}
	}
}

/***********************************************************/
/********************* SAVE COOKIES ************************/
/***********************************************************/
void SaveCookies(int client, bool clear)
{
	char value[PLATFORM_MAX_PATH], cookie[PLATFORM_MAX_PATH];
	
	GetClientCookie(client, CookieSmokeColorsConnect, value, sizeof(value));
	
	char cookie_explode[MAX_SMOKE_THROW][PLATFORM_MAX_PATH];
	ExplodeString(value, ";", cookie_explode, max_smoke_colors, PLATFORM_MAX_PATH);
	
	for(int i = 0; i < max_smoke_colors - 1; i++)
	{
		
		char cookie_value[2][PLATFORM_MAX_PATH];
		ExplodeString(cookie_explode[i], ":", cookie_value, 2, PLATFORM_MAX_PATH);
		
		char S_info[PLATFORM_MAX_PATH];
		strcopy(S_info, PLATFORM_MAX_PATH, S_smokecolorsparticlename[i+1]);
		
		int connect = StringToInt(cookie_value[1]);
		if(connect > 1) connect = 1;
		if(i == 0)
		{
			ReplaceString(S_info, PLATFORM_MAX_PATH, "explosion_smokegrenade_base_", "");
			if(!clear)
			{
				Format(cookie, sizeof(cookie), "%s:%i", S_info, connect + 1);
			}
			else
			{
				Format(cookie, sizeof(cookie), "%s:%i", S_info, 0);
			}
		}
		else
		{
			ReplaceString(S_info, PLATFORM_MAX_PATH, "explosion_smokegrenade_base_", "");
			if(!clear)
			{
				Format(cookie, sizeof(cookie), "%s;%s:%i", cookie, S_info, connect + 1);
			}
			else
			{
				Format(cookie, sizeof(cookie), "%s;%s:%i", cookie, S_info, 0);
			}
		}
	}
	
	SetClientCookie(client, CookieSmokeColorsConnect, cookie);
}

/***********************************************************/
/*********************** EVENT SAY *************************/
/***********************************************************/
public Action Event_Say(int client, const char[] command, int args)
{
	char text[PLATFORM_MAX_PATH];
	GetCmdArgString(text, sizeof(text));
	
	StripQuotes(text);
	TrimString(text);
	if(!text[0])
	{
		return Plugin_Handled;
	}
	
	for(int i = 0; i < max_smoke_colors; i++)
	{
		char S_info[PLATFORM_MAX_PATH];
		strcopy(S_info, PLATFORM_MAX_PATH, S_smokecolorsparticlename[i]);
		if(i ==0)
		{
			ReplaceString(S_info, PLATFORM_MAX_PATH, "explosion_smokegrenade", "smokegray");
		}
		else
		{
			ReplaceString(S_info, PLATFORM_MAX_PATH, "explosion_smokegrenade_base_", "smoke");
		}
		
		ReplaceString(S_info, PLATFORM_MAX_PATH, "_", "");
		
		char style1[PLATFORM_MAX_PATH], style2[PLATFORM_MAX_PATH];
		Format(style1, sizeof(style1), "!%s", S_info);
		Format(style2, sizeof(style2), "/%s", S_info);
		
		if(StrEqual(text, S_info, false) || StrEqual(text, style1, false) && style1[1] || StrEqual(text, style2, false) && style2[1])
		{
			C_color_smoke[client] = i;
			char S_color[3];
			IntToString(i, S_color, sizeof(S_color));
			SetClientCookie(client, CookieSmokeColors, S_color);
			
			char S_translate[PLATFORM_MAX_PATH];
			Format(S_translate, sizeof(S_translate), "%t", S_smokecolorsparticlename[i], client);
			
			CPrintToChat(client, "%t", "Say Color", S_translate);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}
/***********************************************************/
/********************** MENU SETTINGS **********************/
/***********************************************************/
public void SmokeColorsCookieHandler(int client, CookieMenuAction action, any info, char [] buffer, int maxlen)
{
	BuildMenuSmokeColors(client);
}

/***********************************************************/
/******************** MENU SMOKE COLORS ********************/
/***********************************************************/
public Action Command_BuildMenuSmokeColors(int client, int args)
{
	BuildMenuSmokeColors(client);
	return Plugin_Handled;
}

/***********************************************************/
/**************** BUILD MENU SMOKE COLORS ******************/
/***********************************************************/
void BuildMenuSmokeColors(int client)
{
	char title[40];
	
	char S_steamid[64];
	Menu menu = CreateMenu(MenuSmokeColorsAction);
	
	GetClientAuthId(client, AuthId_Steam2, S_steamid, sizeof(S_steamid));
	
	if(Array_MultiSmokeColors[client] == INVALID_HANDLE)
	{
		Array_MultiSmokeColors[client] = CreateArray(3);
	}
	ClearArray(Array_MultiSmokeColors[client]);
	
	
	for(int colors = 0; colors < max_smoke_colors; ++colors)
	{
		for(int steamid = 0; steamid < max_smoke_colors_steamid[colors]; ++steamid)
		{
			
			if(StrEqual(S_smokecolorssteamid[colors][steamid], S_steamid ,false))
			{
				B_SmokeColors_SteamID[client][colors] = true;
			}
		}
		
		if((B_SmokeColors_SteamID[client][colors] == true && StrEqual(S_smokecolorsflag[colors], "steamid", false)) 
		|| (IsAdminEx(client) && StrEqual(S_smokecolorsflag[colors], "admin", false) || B_SmokeColors_SteamID[client][colors] == true) 
		|| ((IsVip(client)|| IsAdminEx(client)) && StrEqual(S_smokecolorsflag[colors], "vip", false) || B_SmokeColors_SteamID[client][colors] == true) 
		|| StrEqual(S_smokecolorsflag[colors], "public", false))																								
		{
			char S_colors[3];
			IntToString(colors, S_colors, sizeof(S_colors));
			char menu_color[40];
			Format(menu_color, sizeof(menu_color), "%T", S_smokecolorsparticlename[colors], client);
			AddMenuItem(menu, S_colors, menu_color);
			PushArrayCell(Array_MultiSmokeColors[client], colors);
		}
	}

	int ArrayMultiSmokeColors = GetArraySize(Array_MultiSmokeColors[client]);
	
	if(ArrayMultiSmokeColors > 1)
	{
		char menu_color_multi[40];
		Format(menu_color_multi, sizeof(menu_color_multi), "%T", "Multi Colors", client);
		AddMenuItem(menu, "100", menu_color_multi);
	}
	
	Format(title, sizeof(title), "%T", "MenuSmokeColors_TITLE", client);
	menu.SetTitle(title);
	SetMenuExitBackButton(menu, true);
	menu.Display(client, MENU_TIME_FOREVER);
}

/***********************************************************/
/*************** MENU ACTION SMOKE COLORS ******************/
/***********************************************************/
public int MenuSmokeColorsAction(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
		{
			CloseHandle(menu);	
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{	
				FakeClientCommand(param1, "sm_settings");
			}
		}
		case MenuAction_Select:
		{
			char menu1[56];
			menu.GetItem(param2, menu1, sizeof(menu1));
			int color = StringToInt(menu1);
			
			C_color_smoke[param1] = color;
			
			SetClientCookie(param1, CookieSmokeColors, menu1);
			
			BuildMenuSmokeColors(param1);
		}
	}
}

/***********************************************************/
/******************** WHEN ROUND START *********************/
/***********************************************************/
public void Event_RoundStart(Handle event, char[] name, bool dontBroadcast)
{
	for(int i = 0; i < smoke_count; i++)
	{
		if(H_TimerScreenEffect[i] != INVALID_HANDLE)
		{
			ClearTimer(H_TimerScreenEffect[i]);
		}
		B_OriginalSmoke[smoke_count] = false;
	}
	smoke_count = 0;
}

/***********************************************************/
/****************** WHEN SMOKE DETONATE ********************/
/***********************************************************/
public void Event_SmokeDetonate(Handle event, char[] name, bool dontBroadcast)
{
	if(smoke_count < MAX_SMOKE_THROW && B_OriginalSmoke[smoke_count])
	{
		float smoke_origin[3], projectile_origin[3];
		smoke_origin[0] = GetEventFloat(event, "x");
		smoke_origin[1] = GetEventFloat(event, "y");
		smoke_origin[2] = GetEventFloat(event, "z");
	
		int index;
		while((index = FindEntityByClassname(index, "smokegrenade_projectile")) != -1)
		{
			GetEntPropVector(index, Prop_Send, "m_vecOrigin", projectile_origin);
			if(projectile_origin[0] == smoke_origin[0] && projectile_origin[1] == smoke_origin[1] && projectile_origin[2] == smoke_origin[2])
			{
				for(int i = 1; i <= MaxClients; ++i)
				{
					if(IsClientInGame(i))
					{
						C_getcolor[smoke_count][i] = GetTheColor(i);
						TE_SetupEffect_SmokeColors(i, projectile_origin, projectile_origin, smoke_count, S_smokecolorsparticlename[C_getcolor[smoke_count][i]]);
					}
				}
				
				C_CountDown[smoke_count] = 0;
				Handle dataPackHandle;
				H_TimerScreenEffect[smoke_count] = CreateDataTimer(0.0, TimerData_ScreenEffect, dataPackHandle, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
				WritePackCell(dataPackHandle, smoke_count);
				WritePackFloat(dataPackHandle, projectile_origin[0]);
				WritePackFloat(dataPackHandle, projectile_origin[1]);
				WritePackFloat(dataPackHandle, projectile_origin[2]);
				
				//You have to kill the projectile otherwise you will see the gray overlay.
				//AcceptEntityInput(index, "Kill");
				
				B_OriginalSmoke[smoke_count] = false;
				smoke_count++;			
			}
		}
	}
}

/***********************************************************/
/******************** EFFECT DISPATCH **********************/
/***********************************************************/
public Action TE_EffectDispatch(const char[] te_name, const int[] Players, int numClients, float delay)
{
	int iEffectIndex = TE_ReadNum("m_iEffectName");
	
	char sEffectName[64];
	GetEffectName(iEffectIndex, sEffectName, sizeof(sEffectName));
	
	int nHitBox = TE_ReadNum("m_nHitBox");
	
	if(StrEqual(sEffectName, "ParticleEffect"))
	{
		char sParticleEffectName[64];
		GetParticleEffectName(nHitBox, sParticleEffectName, sizeof(sParticleEffectName));

		if(StrEqual(sParticleEffectName, "explosion_smokegrenade", false) && !B_OriginalSmoke[smoke_count])
		{
			if(smoke_count < MAX_SMOKE_THROW)
			{
				B_OriginalSmoke[smoke_count] = true;
				return Plugin_Handled;
			}
		}
	}
	
	return Plugin_Continue;
}

/***********************************************************/
/************ TIMER DATA ON POST WEAPON EQUIP **************/
/***********************************************************/
public Action TimerData_ScreenEffect(Handle timer, Handle dataPackHandle)
{	
	ResetPack(dataPackHandle);
	int index		= ReadPackCell(dataPackHandle);
	
	float pos[3], molotov_explosion_origin[3];
	pos[0]			= ReadPackFloat(dataPackHandle);
	pos[1]			= ReadPackFloat(dataPackHandle);
	pos[2]			= ReadPackFloat(dataPackHandle);
			
	char explode[3][10];
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			ExplodeString(S_smokecolorsparticlecolor[C_getcolor[index][i]], ", ", explode, 3, 10, true);
			
			float cpos[3];
			GetClientAbsOrigin(i, cpos);
			float distance = GetVectorDistance(cpos, pos);
			
			//Thx to Miumiu (not the pokemon) for the map part. 
			float alpha;
			if(distance > 0 && distance < 160)
			{
				alpha = C_smokegrenade_colors_max_alpha - (distance - 0) / (160 - 0) * (C_smokegrenade_colors_max_alpha - C_smokegrenade_colors_min_alpha);
			}
			else if(distance > 160 && distance < 170)
			{
				alpha = C_smokegrenade_colors_max_alpha - (distance - 160) / (170 - 160) * (C_smokegrenade_colors_min_alpha - 0);
			}
			else
			{
				alpha = 0.0;
			}

			if(alpha < 0) alpha = 0.0;
			if(alpha > C_smokegrenade_colors_max_alpha) alpha = float(C_smokegrenade_colors_max_alpha);
			
			if(distance < 170 && C_getcolor[index][i] != 0)
			{
				ScreenEffect(i, 10, 100, 100, StringToInt(explode[0]), StringToInt(explode[1]), StringToInt(explode[2]), RoundFloat(alpha));
			}
			
			if(B_active_smokegrenade_colors_dev)
			{
				//PrintToChat(i, "[%i]: %i| color: %i %i %i | %f, %f", index, C_CountDown[index], StringToInt(explode[0]), StringToInt(explode[1]), StringToInt(explode[2]), distance, alpha);
			}
		}
	}
	
	int inferno;
	while((inferno = FindEntityByClassname(inferno, "inferno")) != -1)
	{
		GetEntPropVector(inferno, Prop_Send, "m_vecOrigin", molotov_explosion_origin);
		float distance = GetVectorDistance(molotov_explosion_origin, pos);
		
		if(distance < 160)
		{
			AcceptEntityInput(inferno, "Kill");
		}
	}	
	
	if(C_CountDown[index] >= 175)
	{
		ClearTimer(H_TimerScreenEffect[index]);
	}
	C_CountDown[index]++;
}

/***********************************************************/
/******************* GET THE COLOR MOD *********************/
/***********************************************************/
int GetTheColor(int client)
{
	int color = 0;

	if(C_smokegrenade_colors_mod == 1)
	{
		color = GetRandomInt(1, max_smoke_colors - 1);
		if(!CheckInvisibleSmoke(client, color))
		{
			color = 0;
		}
	}
	else if(C_smokegrenade_colors_mod == 0)
	{
		color = CheckAccessSmokeColors(client, C_color_smoke[client]);
	}
	
	return color;
}

/***********************************************************/
/*************** CHECK ACCESS SMOKE COLORS *****************/
/***********************************************************/
int CheckAccessSmokeColors(int client, int color)
{
	if(IsClientAuthorized(client))
	{
		char S_steamid[64];
		GetClientAuthId(client, AuthId_Steam2, S_steamid, sizeof(S_steamid));
		
		if(color < 100 && color > 0)
		{
			if(CheckInvisibleSmoke(client, color))
			{
				for(int steamid = 0; steamid < max_smoke_colors_steamid[color]; ++steamid)
				{
					
					if(StrEqual(S_smokecolorssteamid[color][steamid], S_steamid ,false))
					{
						B_SmokeColors_SteamID[client][color] = true;
					}
				}
				
				if((B_SmokeColors_SteamID[client][color] == true && StrEqual(S_smokecolorsflag[color], "steamid", false)) 
				|| (IsAdminEx(client) && StrEqual(S_smokecolorsflag[color], "admin", false) || B_SmokeColors_SteamID[client][color] == true) 
				|| ((IsVip(client)|| IsAdminEx(client)) && StrEqual(S_smokecolorsflag[color], "vip", false) || B_SmokeColors_SteamID[client][color] == true) 
				|| StrEqual(S_smokecolorsflag[color], "public", false))																								
				{
					return color;
				}
				else
				{
					return 0;
				}
			}
		}
		else if(color == 100)
		{
				if(Array_MultiSmokeColors[client] == INVALID_HANDLE)
				{
					Array_MultiSmokeColors[client] = CreateArray(3);
				}
				ClearArray(Array_MultiSmokeColors[client]);
				
				
				for(int colors = 0; colors < max_smoke_colors; ++colors)
				{
					for(int steamid = 0; steamid < max_smoke_colors_steamid[colors]; ++steamid)
					{
						
						if(StrEqual(S_smokecolorssteamid[colors][steamid], S_steamid ,false))
						{
							B_SmokeColors_SteamID[client][colors] = true;
						}
					}
					
					if((B_SmokeColors_SteamID[client][colors] == true && StrEqual(S_smokecolorsflag[colors], "steamid", false)) 
					|| (IsAdminEx(client) && StrEqual(S_smokecolorsflag[colors], "admin", false) || B_SmokeColors_SteamID[client][colors] == true) 
					|| ((IsVip(client)|| IsAdminEx(client)) && StrEqual(S_smokecolorsflag[colors], "vip", false) || B_SmokeColors_SteamID[client][colors] == true)	
					|| StrEqual(S_smokecolorsflag[colors], "public", false))																							
					{
						char S_colors[3];
						IntToString(colors, S_colors, sizeof(S_colors));
						PushArrayCell(Array_MultiSmokeColors[client], colors);
						
					}
					
				}
					
				int ArrayMultiSmokeColors = GetArraySize(Array_MultiSmokeColors[client]);
				if(ArrayMultiSmokeColors > 1)
				{
					int num = GetRandomInt(0, ArrayMultiSmokeColors - 1);
					color = GetArrayCell(Array_MultiSmokeColors[client], num);
					if(CheckInvisibleSmoke(client, color))
					{
						return color;
					}
					else
					{
						return 0;
					}
				}
				else
				{
					return 0;
				}	
		}
	}
	return 0;
}

/***********************************************************/
/**************** CHECK INVISIBLE SMOKE ********************/
/***********************************************************/
bool CheckInvisibleSmoke(int client, int color)
{
	char value[PLATFORM_MAX_PATH], cookie[PLATFORM_MAX_PATH];

	GetClientCookie(client, CookieSmokeColorsConnect, value, sizeof(value));
	
	char cookie_explode[MAX_SMOKE_THROW][PLATFORM_MAX_PATH];
	ExplodeString(value, ";", cookie_explode, max_smoke_colors, PLATFORM_MAX_PATH);
	
	for(int i = 0; i < max_smoke_colors - 1; i++)
	{
		
		char cookie_value[2][PLATFORM_MAX_PATH];
		ExplodeString(cookie_explode[i], ":", cookie_value, 2, PLATFORM_MAX_PATH);
		
		char S_info[PLATFORM_MAX_PATH];
		strcopy(S_info, PLATFORM_MAX_PATH, S_smokecolorsparticlename[color]);
		ReplaceString(S_info, PLATFORM_MAX_PATH, "explosion_smokegrenade_base_", "");
		
		if(StrEqual(S_info, cookie_value[0]))
		{
			if(StringToInt(cookie_value[1]) > 1)
			{
				return true;
			}
		}
		
	}
	return false;
}

stock void TE_SendBeamBoxToClient(int client, const float upc[3], const float btc[3], int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, const float Life, const float Width, const float EndWidth, int FadeLength, const float Amplitude, const int Color[4], int Speed)
{
	// Create the additional corners of the box
	float tc1[] = {0.0, 0.0, 0.0};
	float tc2[] = {0.0, 0.0, 0.0};
	float tc3[] = {0.0, 0.0, 0.0};
	float tc4[] = {0.0, 0.0, 0.0};
	float tc5[] = {0.0, 0.0, 0.0};
	float tc6[] = {0.0, 0.0, 0.0};

	AddVectors(tc1, upc, tc1);
	AddVectors(tc2, upc, tc2);
	AddVectors(tc3, upc, tc3);
	AddVectors(tc4, btc, tc4);
	AddVectors(tc5, btc, tc5);
	AddVectors(tc6, btc, tc6);

	tc1[0] = btc[0];
	tc2[1] = btc[1];
	tc3[2] = btc[2];
	tc4[0] = upc[0];
	tc5[1] = upc[1];
	tc6[2] = upc[2];

	// Draw all the edges
	TE_SetupBeamPoints(upc, tc1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(upc, tc2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(upc, tc3, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(tc6, tc1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(tc6, tc2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(tc6, btc, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(tc4, btc, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(tc5, btc, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(tc5, tc1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(tc5, tc3, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(tc4, tc3, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
	TE_SetupBeamPoints(tc4, tc2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToClient(client);
}
/***********************************************************/
/********************* SCREEN EFFECT ***********************/
/***********************************************************/
stock void ScreenEffect(int client, int duration, int hold_time, int flag, int red, int green, int blue, int alpha)
{
	Handle hFade = INVALID_HANDLE;
	
	if(client)
	{
	   hFade = StartMessageOne("Fade", client);
	}
	else
	{
	   hFade = StartMessageAll("Fade");
	}
	
	if(hFade != INVALID_HANDLE)
	{
		if(GetUserMessageType() == UM_Protobuf)
		{
			int clr[4];
			clr[0]=red;
			clr[1]=green;
			clr[2]=blue;
			clr[3]=alpha;
			PbSetInt(hFade, "duration", duration);
			PbSetInt(hFade, "hold_time", hold_time);
			PbSetInt(hFade, "flags", flag);
			PbSetColor(hFade, "clr", clr);
		}
		else
		{
			BfWriteShort(hFade, duration);
			BfWriteShort(hFade, hold_time);
			BfWriteShort(hFade, flag);
			BfWriteByte(hFade, red);
			BfWriteByte(hFade, green);
			BfWriteByte(hFade, blue);	
			BfWriteByte(hFade, alpha);
		}
		EndMessage();
	}
}

/***********************************************************/
/********************** LOAD SETTINGS **********************/
/***********************************************************/
public void LoadSettings()
{
	char hc[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, hc, sizeof(hc), "configs/drapi/smokegrenade_colors.cfg");
	
	Handle kv = CreateKeyValues("SmokeColors");
	FileToKeyValues(kv, hc);
	
	max_smoke_colors		= 0;
	int max_color			= 0;
	if(KvGotoFirstSubKey(kv))
	{
		do
		{
			if(KvJumpToKey(kv, "SmokeColors"))
			{
				char S_info[MAX_SMOKE_COLORS][PLATFORM_MAX_PATH];
				for(int i = 0; i <= MAX_SMOKE_COLORS; ++i)
				{
					char key[64];
					IntToString(i, key, 64);
					
					if(KvGetString(kv, key, S_info[i], PLATFORM_MAX_PATH) && strlen(S_info[i]))
					{
						char explode[3][PLATFORM_MAX_PATH];
						ExplodeString(S_info[i], " | ", explode, 3, PLATFORM_MAX_PATH, true);
						
						S_smokecolorsparticlefile[i]		= explode[0];
						S_smokecolorsparticlename[i]		= explode[1];
						S_smokecolorsparticlecolor[i]		= explode[2];
						
						//LogMessage("%s - [%i] %s", TAG_CHAT, i, S_smokecolorsparticlename[i]);
						max_smoke_colors++;
					}
					else
					{
						break;
					}
					
				}
				KvGoBack(kv);
			}
			
			if(KvJumpToKey(kv, "SmokeColorsAccess"))
			{
				if(KvGotoFirstSubKey(kv))
				{
					do
					{
						char S_info[3];
						if(KvGetSectionName(kv, S_info, 3))
						{
							KvGetString(kv, "flags", S_smokecolorsflag[max_color], 64);
							
							max_smoke_colors_steamid[max_color] = 0;
							
							if(KvJumpToKey(kv, "SteamIDs"))
							{
								for(int i = 0; i <= MAX_SMOKE_COLORS_STEAMID; ++i)
								{
									char key[3];
									IntToString(i, key, 3);
									
									if(KvGetString(kv, key, S_smokecolorssteamid[max_color][i], 64) && strlen(S_smokecolorssteamid[max_color][i]))
									{
										//LogMessage("%s [%i] - ID: %i, STEAMID: %s", TAG_CHAT, max_color, i, S_smokecolorssteamid[max_color][i]);
										max_smoke_colors_steamid[max_color]++;
									}
									else
									{
										break;
									}
									
								}
								KvGoBack(kv);
							}
							
							//LogMessage("%s, %s", S_info, S_smokecolorsflag[max_color]);
							max_color++;
						}
					}
					while (KvGotoNextKey(kv));
				}
			}
			
		}
		while (KvGotoNextKey(kv));
	}
	CloseHandle(kv);
	
}

/***********************************************************/
/********************** CLEAR TIMER ************************/
/***********************************************************/
stock void ClearTimer(Handle &timer)
{
	if (timer != INVALID_HANDLE)
	{
		KillTimer(timer);
		timer = INVALID_HANDLE;
	}	  
}

/***********************************************************/
/******************** CHECK IF IS A VIP ********************/
/***********************************************************/
stock bool IsVip(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_CUSTOM1 
	|| GetUserFlagBits(client) & ADMFLAG_CUSTOM2 
	|| GetUserFlagBits(client) & ADMFLAG_CUSTOM3 
	|| GetUserFlagBits(client) & ADMFLAG_CUSTOM4 
	|| GetUserFlagBits(client) & ADMFLAG_CUSTOM5 
	|| GetUserFlagBits(client) & ADMFLAG_CUSTOM6)
	{
		return true;
	}
	return false;
}

/***********************************************************/
/****************** CHECK IF IS AN ADMIN *******************/
/***********************************************************/
stock bool IsAdminEx(int client)
{
	if(
	/*|| GetUserFlagBits(client) & ADMFLAG_RESERVATION*/
	GetUserFlagBits(client) & ADMFLAG_GENERIC
	|| GetUserFlagBits(client) & ADMFLAG_KICK
	|| GetUserFlagBits(client) & ADMFLAG_BAN
	|| GetUserFlagBits(client) & ADMFLAG_UNBAN
	|| GetUserFlagBits(client) & ADMFLAG_SLAY
	|| GetUserFlagBits(client) & ADMFLAG_CHANGEMAP
	|| GetUserFlagBits(client) & ADMFLAG_CONVARS
	|| GetUserFlagBits(client) & ADMFLAG_CONFIG
	|| GetUserFlagBits(client) & ADMFLAG_CHAT
	|| GetUserFlagBits(client) & ADMFLAG_VOTE
	|| GetUserFlagBits(client) & ADMFLAG_PASSWORD
	|| GetUserFlagBits(client) & ADMFLAG_RCON
	|| GetUserFlagBits(client) & ADMFLAG_CHEATS
	|| GetUserFlagBits(client) & ADMFLAG_ROOT)
	{
		return true;
	}
	return false;
}

/***********************************************************/
/******************** IS VALID ENTITY **********************/
/***********************************************************/
stock bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}

/***********************************************************/
/********************** FORCE SMOKE ************************/
/***********************************************************/
public Action Command_ForceSmoke(int client, int args)
{
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count; 
	bool tn_is_ml;
	if((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, COMMAND_FILTER_NO_BOTS, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		SaveCookies(target_list[i], true);
	}
	return Plugin_Handled;
}

/***********************************************************/
/******************** CMD CLEAR COOKIES ********************/
/***********************************************************/
public Action Command_ClearCookies(int client, int args)
{
	SaveCookies(client, true);
	return Plugin_Handled;
}

/***********************************************************/
/************************ CMD RETRY ************************/
/***********************************************************/
public Action Command_Retry(int client, int args)
{
	ReconnectClient(client);
	return Plugin_Handled;
}

/***********************************************************/
/************************ CMD SMOKE ************************/
/***********************************************************/
public Action Command_Smoke(int client, int args)
{
	GivePlayerItem(client, "weapon_smokegrenade");
	ClientCommand(client, "slot4");
	return Plugin_Handled;
}

/***********************************************************/
/********************** CMD ENTITIES ***********************/
/***********************************************************/
public Action Command_Entities(int client, int args)
{
	int _iMax = GetMaxEntities();
	for(int i = MaxClients + 1; i <= _iMax; i++)
	{
		if(IsValidEntity(i) && IsValidEdict(i))
		{
			char _sBuffer[64];
			GetEdictClassname(i, _sBuffer, sizeof(_sBuffer));
			LogMessage("%s", _sBuffer);
		}
	}
	return Plugin_Handled;
}

public Action Cmd_DumpStringtables(int client, int args)
{
	int iNum = GetNumStringTables();
	ReplyToCommand(client, "Listing %d stringtables:", iNum);
	char sName[64];
	for(int i=0;i<iNum;i++)
	{
		GetStringTableName(i, sName, sizeof(sName));
		ReplyToCommand(client, "%d. %s (%d/%d strings)", i, sName, GetStringTableNumStrings(i), GetStringTableMaxStrings(i));
	}
	return Plugin_Handled;
}

public Action Cmd_DumpDispatchEffect(int client, int args)
{
	int table = FindStringTable("EffectDispatch");
	if(table == INVALID_STRING_TABLE)
	{
		ReplyToCommand(client, "Couldn't find EffectDispatch stringtable.");
		return Plugin_Handled;
	}
	
	int iNum = GetStringTableNumStrings(table);
	char sName[64];
	for(int i=0;i<iNum;i++)
	{
		ReadStringTable(table, i, sName, sizeof(sName));
		ReplyToCommand(client, "%d. %s", i, sName);
	}
	return Plugin_Handled;
}

public Action Cmd_DumpParticleEffectName(int client, int args)
{
	int table = FindStringTable("ParticleEffectNames");
	if(table == INVALID_STRING_TABLE)
	{
		ReplyToCommand(client, "Couldn't find ParticleEffectNames stringtable.");
		return Plugin_Handled;
	}
	
	int iNum = GetStringTableNumStrings(table);
	char sName[64];
	for(int i=0;i<iNum;i++)
	{
		ReadStringTable(table, i, sName, sizeof(sName));
		ReplyToCommand(client, "%d. %s", i, sName);
		LogMessage("%d. %s", i, sName);
	}
	return Plugin_Handled;
}

public Action Cmd_DumpExtraParticleFilesTable(int client, int args)
{
	int table = FindStringTable("ExtraParticleFilesTable");
	if(table == INVALID_STRING_TABLE)
	{
		ReplyToCommand(client, "Couldn't find ExtraParticleFilesTable stringtable.");
		return Plugin_Handled;
	}
	
	int iNum = GetStringTableNumStrings(table);
	char sName[64];
	for(int i=0;i<iNum;i++)
	{
		ReadStringTable(table, i, sName, sizeof(sName));
		ReplyToCommand(client, "%d. %s", i, sName);
	}
	return Plugin_Handled;
}

public Action Cmd_DumpGenericPrecache(int client, int args)
{
	int table = FindStringTable("genericprecache");
	if(table == INVALID_STRING_TABLE)
	{
		ReplyToCommand(client, "Couldn't find genericprecache stringtable.");
		return Plugin_Handled;
	}
	
	int iNum = GetStringTableNumStrings(table);
	char sName[64];
	for(int i=0;i<iNum;i++)
	{
		ReadStringTable(table, i, sName, sizeof(sName));
		ReplyToCommand(client, "%d. %s", i, sName);
	}
	return Plugin_Handled;
}

public Action Cmd_DumpUser(int client, int args)
{
	int table = FindStringTable("userinfo");
	if(table == INVALID_STRING_TABLE)
	{
		ReplyToCommand(client, "Couldn't find userinfo stringtable.");
		return Plugin_Handled;
	}
	
	int iNum = GetStringTableNumStrings(table);
	char sName[64];
	for(int i=0;i<iNum;i++)
	{
		ReadStringTable(table, i, sName, sizeof(sName));
		ReplyToCommand(client, "%d. %s", i, sName);
	}
	return Plugin_Handled;
}

public Action Cmd_DumpDownload(int client, int args)
{
	int table = FindStringTable("downloadables");
	if(table == INVALID_STRING_TABLE)
	{
		ReplyToCommand(client, "Couldn't find downloadables stringtable.");
		return Plugin_Handled;
	}
	
	int iNum = GetStringTableNumStrings(table);
	char sName[64];
	for(int i=0;i<iNum;i++)
	{
		ReadStringTable(table, i, sName, sizeof(sName));
		ReplyToCommand(client, "%d. %s", i, sName);
	}
	return Plugin_Handled;
}

/***********************************************************/
/****************** SETUPE SMOKE COLORS ********************/
/***********************************************************/
stock void TE_SetupEffect_SmokeColors(int client, const float origin[3], const float angle[3], int entindex, char[] effect)
{
	TE_Start("EffectDispatch");

	TE_WriteNum("m_nHitBox", GetParticleEffectIndex(effect));
	
	TE_WriteFloat("m_vOrigin.x", origin[0]);
	TE_WriteFloat("m_vOrigin.y", origin[1]);
	TE_WriteFloat("m_vOrigin.z", origin[2]);
	
	TE_WriteFloat("m_vStart.x", angle[0]);
	TE_WriteFloat("m_vStart.y", angle[1]);
	TE_WriteFloat("m_vStart.z", angle[2]);
				
	TE_WriteNum("entindex", entindex);
	
	TE_WriteNum("m_fFlags", 0);
	TE_WriteNum("m_nAttachmentIndex", 0);
	
	TE_WriteNum("m_iEffectName", GetEffectIndex("ParticleEffect"));
		
	TE_SendToClient(client);
}

/***********************************************************/
/******************** PRECACHE EFFECT **********************/
/***********************************************************/
stock void PrecacheEffect(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
	{
		table = FindStringTable("EffectDispatch");
	}
	
	bool save = LockStringTables(false);
	AddToStringTable(table, sEffectName);
	LockStringTables(save);
}

/***********************************************************/
/******************* GET EFFECT INDEX **********************/
/***********************************************************/
stock int GetEffectIndex(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
	{
		table = FindStringTable("EffectDispatch");
	}
	
	int iIndex = FindStringIndex(table, sEffectName);
	if(iIndex != INVALID_STRING_INDEX)
		return iIndex;
	
	// This is the invalid string index
	return 0;
}

/***********************************************************/
/******************** GET EFFECT NAME **********************/
/***********************************************************/
stock void GetEffectName(int index, char[] sEffectName, int maxlen)
{
	static int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
	{
		table = FindStringTable("EffectDispatch");
	}
	
	ReadStringTable(table, index, sEffectName, maxlen);
}

/***********************************************************/
/*************** PRECACHE PARTICLE EFFECT ******************/
/***********************************************************/
stock void PrecacheParticleEffect(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
	{
		table = FindStringTable("ParticleEffectNames");
	}
	
	bool save = LockStringTables(false);
	AddToStringTable(table, sEffectName);
	LockStringTables(save);
}

/***********************************************************/
/************** GET PARTICLE EFFECT INDEX ******************/
/***********************************************************/
stock int GetParticleEffectIndex(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
	{
		table = FindStringTable("ParticleEffectNames");
	}
	
	int iIndex = FindStringIndex(table, sEffectName);
	if(iIndex != INVALID_STRING_INDEX)
		return iIndex;
	
	// This is the invalid string index
	return 0;
}

/***********************************************************/
/*************** GET PARTICLE EFFECT NAME ************* *****/
/***********************************************************/
stock void GetParticleEffectName(int index, char[] sEffectName, int maxlen)
{
	static int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
	{
		table = FindStringTable("ParticleEffectNames");
	}
	
	ReadStringTable(table, index, sEffectName, maxlen);
}