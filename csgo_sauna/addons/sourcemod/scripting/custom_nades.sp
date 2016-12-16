#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
new Handle:g_hCustomHe = INVALID_HANDLE;
new bool:g_bCustomHe;
new Handle:g_hCustomFlash = INVALID_HANDLE;
new bool:g_bCustomFlash;
new Handle:g_hCustomSmoke = INVALID_HANDLE;
new bool:g_bCustomSmoke;
new Handle:g_hCustomDecoy = INVALID_HANDLE;
new bool:g_bCustomDecoy;
new Handle:g_hAdminOnly = INVALID_HANDLE;
new bool:g_bAdminOnly;

new String:customhegrenade[255];
new String:customflashgrenade[255];
new String:customsmokegrenade[255];
new String:customdecoygrenade[255];

new String:customhesize[255];
new String:customflashsize[255];
new String:customsmokesize[255];
new String:customdecoysize[255];

#define PLUGIN_VERSION "1.2"
public Plugin:myinfo =
{
    name    =  "Custom Nade Models",
    author    =  "TonyBaretta",
    description  =  "Change Nade Model",
    version    =  PLUGIN_VERSION,
    url      =  "http://www.wantedgov.it"
};
public OnPluginStart()
{
	g_hAdminOnly = CreateConVar("sm_cnade_admin_only", "0", "Enable / Disable");
	g_bAdminOnly = GetConVarBool(g_hAdminOnly);
	g_hCustomHe = CreateConVar("sm_custom_he", "1", "Enable / Disable");
	g_bCustomHe = GetConVarBool(g_hCustomHe);
	g_hCustomHe = CreateConVar("sm_custom_he", "1", "Enable / Disable");
	g_bCustomHe = GetConVarBool(g_hCustomHe);
	g_hCustomFlash = CreateConVar("sm_custom_flash", "1", "Enable / Disable");
	g_bCustomFlash = GetConVarBool(g_hCustomFlash);
	g_hCustomSmoke = CreateConVar("sm_custom_smoke", "1", "Enable / Disable");
	g_bCustomSmoke = GetConVarBool(g_hCustomSmoke);
	g_hCustomDecoy = CreateConVar("sm_custom_decoy", "1", "Enable / Disable");
	g_bCustomDecoy = GetConVarBool(g_hCustomDecoy);
	AutoExecConfig(true, "custom_nade_settings");
	CreateConVar("nademodels_version", PLUGIN_VERSION, "Custom Nade Models version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_DONTRECORD|FCVAR_NOTIFY);
	new Handle:kv = CreateKeyValues("NadeModel");
	if (!FileToKeyValues(kv,"cfg/sourcemod/custom_nade_model.cfg"))
	{
		return;
	}
	if (KvJumpToKey(kv, "Settings"))
	{
		KvGetString(kv,"he",customhegrenade, sizeof(customhegrenade));
		KvGetString(kv,"hesize",customhesize, sizeof(customhesize));
		KvGetString(kv,"flash",customflashgrenade, sizeof(customflashgrenade));
		KvGetString(kv,"flashsize",customflashsize, sizeof(customflashsize));
		KvGetString(kv,"smoke",customsmokegrenade, sizeof(customsmokegrenade));
		KvGetString(kv,"smokesize",customsmokesize, sizeof(customsmokesize));
		KvGetString(kv,"decoy",customdecoygrenade, sizeof(customdecoygrenade));
		KvGetString(kv,"decoysize",customdecoysize, sizeof(customdecoysize));
		KvGoBack(kv);
	}
	
	CloseHandle(kv);
}
public OnMapStart()
{
	decl String:file[256];
	BuildPath(Path_SM, file, 255, "configs/custom_nades.ini");
	new Handle:fileh = OpenFile(file, "r");
	if (fileh != INVALID_HANDLE)
	{
		decl String:buffer[256];
		decl String:buffer_full[PLATFORM_MAX_PATH];

		while(ReadFileLine(fileh, buffer, sizeof(buffer)))
		{
			TrimString(buffer);
			if ( (StrContains(buffer, "//") == -1) && (!StrEqual(buffer, "")) )
			{
				PrintToServer("Reading downloads line :: %s", buffer);
				Format(buffer_full, sizeof(buffer_full), "%s", buffer);
				if (FileExists(buffer_full))
				{
					PrintToServer("Precaching %s", buffer);
					PrecacheDecal(buffer, true);
					AddFileToDownloadsTable(buffer_full);
				}
			}
		}
	}
	PrecacheModel(customhegrenade);
	PrecacheModel(customflashgrenade);
	PrecacheModel(customsmokegrenade);
	PrecacheModel(customdecoygrenade);
}

public OnEntityCreated(entity, const String:classname[])
{
	if(IsValidEntity(entity)) SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawned);
}

public OnEntitySpawned(entity)
{
	g_bAdminOnly = GetConVarBool(g_hAdminOnly);
	g_bCustomHe = GetConVarBool(g_hCustomHe);
	g_bCustomFlash = GetConVarBool(g_hCustomFlash);
	g_bCustomSmoke = GetConVarBool(g_hCustomSmoke);
	g_bCustomDecoy = GetConVarBool(g_hCustomDecoy);
	decl String:class_name[32];
	GetEntityClassname(entity, class_name, 32);
	new ownernade = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");	
	if(StrContains(class_name, "projectile") != -1 && IsValidEntity(entity) && IsClientInGame(ownernade) && !g_bAdminOnly)
	{
		if(StrContains(class_name, "hegrenade") != -1 && g_bCustomHe){
			SetEntityModel(entity, customhegrenade);
			DispatchKeyValue(entity, "modelscale", customhesize);
		}
		else 
		if(StrContains(class_name, "flashbang") != -1 && g_bCustomFlash){
				SetEntityModel(entity, customflashgrenade);
				DispatchKeyValue(entity, "modelscale", customflashsize);
		}
		else 
		if(StrContains(class_name, "smoke") != -1 && g_bCustomSmoke){
				SetEntityModel(entity, customsmokegrenade);
				DispatchKeyValue(entity, "modelscale", customsmokesize);
		}
		else 
		if(StrContains(class_name, "decoy") != -1 && g_bCustomDecoy){
				SetEntityModel(entity, customdecoygrenade);
				DispatchKeyValue(entity, "modelscale", customdecoysize);
		}
	}else
	if((StrContains(class_name, "projectile") != -1 && IsValidEntity(entity) && IsClientInGame(ownernade) && g_bAdminOnly) && (CheckCommandAccess(ownernade, "", ADMFLAG_KICK) || CheckCommandAccess(ownernade, "", ADMFLAG_CUSTOM1)))
	{
		if(StrContains(class_name, "hegrenade") != -1 && g_bCustomHe){
			SetEntityModel(entity, customhegrenade);
			DispatchKeyValue(entity, "modelscale", customhesize);
		}
		else 
		if(StrContains(class_name, "flashbang") != -1 && g_bCustomFlash){
				SetEntityModel(entity, customflashgrenade);
				DispatchKeyValue(entity, "modelscale", customflashsize);
		}
		else 
		if(StrContains(class_name, "smoke") != -1 && g_bCustomSmoke){
				SetEntityModel(entity, customsmokegrenade);
				DispatchKeyValue(entity, "modelscale", customsmokesize);
		}
		else 
		if(StrContains(class_name, "decoy") != -1 && g_bCustomDecoy){
			SetEntityModel(entity, customdecoygrenade);
			DispatchKeyValue(entity, "modelscale", customdecoysize);
		}
	}
}