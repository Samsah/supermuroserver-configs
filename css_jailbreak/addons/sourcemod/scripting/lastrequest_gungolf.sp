/*
 * Gun Golf, requires SM_Hosties 2.1.0+.
 */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <menus>
// Make certain the lastrequest.inc is last on the list
#include <hosties>
#include <lastrequest>

#pragma semicolon 1

#define PLUGIN_VERSION "1.0.0"

// Game types
#define Game_CSS 0
#define Game_CSGO 1

// Menus handlers
new Handle:g_WepSelect = INVALID_HANDLE;
new Handle:g_PointSelect = INVALID_HANDLE;

// Timers handles
new Handle:gH_Timer_Point_Beam = INVALID_HANDLE;
new Handle:gH_Timer_GunGolf_Details = INVALID_HANDLE;
new Handle:gH_Timer_GunGolf = INVALID_HANDLE;

// Effects
new BeamSprite = -1;
new HaloSprite = -1;
new LaserSprite = -1;
new LaserHalo = -1;
new greenColor[] = {0, 255, 0, 255};
new redColor[] = {255, 0, 0, 255};
new blueColor[] = {0, 0, 255, 255};
new greyColor[] = {128, 128, 128, 255};

// Offsets
new g_Offset_Clip1 = -1;
new g_Offset_Ammo = -1;

// This global will store the index number for the new Last Request
new g_LREntryNum;

// LR type
new g_This_LR_Type;

// Prisoner & Guard
new g_LR_Player_Prisoner;
new g_LR_Player_Guard;

// Weapons for Prisoner & Guard
new g_Pistol_Prisoner;
new g_Pistol_Guard;
new g_WeaponSelected = -1;

// Game detection
new g_Game = -1;

// LR name
new String:g_sLR_Name[64];

// GunGolf states
new bool:g_bGunGolfRunning = false;
new bool:g_bPistol_Prisoner_Dropped = false;
new bool:g_bPistol_Prisoner_Done = false;
new bool:g_bPistol_Guard_Dropped = false;
new bool:g_bPistol_Guard_Done = false;

// Origins
new Float:g_fPistol_Prisoner_Origin[3];
new Float:g_fPistol_Guard_Origin[3];
new Float:g_fPoint_Origin[3];
new Float:g_fPistol_Prisoner_Last_Origin[3];
new Float:g_fPistol_Guard_Last_Origin[3];

// Distance
new Float:g_fPistol_Prisoner_Distance = 0.0;
new Float:g_fPistol_Guard_Distance = 0.0;

public Plugin:myinfo =
{
	name = "Last Request: Gun Golf",
	author = "CoMaNdO",
	description = "Gun Golf last request for SM_Hosties 2.1.0+",
	version = PLUGIN_VERSION,
	url = "http:\\alliedmods.com"
};

enum Weapons
{
	Pistol_Deagle = 0,
	Pistol_P228,
	Pistol_Glock,
	Pistol_FiveSeven,
	Pistol_Dualies,
	Pistol_USP,
	Pistol_Tec9
};

public OnPluginStart()
{
	// Load translations
	LoadTranslations("LR.GunGolf.phrases");
	
	// LR's name
	Format(g_sLR_Name, sizeof(g_sLR_Name), "%t", "GunGolf", LANG_SERVER);
	
	// Detect game
	decl String:gdir[PLATFORM_MAX_PATH];
	GetGameFolderName(gdir,sizeof(gdir));
	if (StrEqual(gdir,"cstrike",false) || StrEqual(gdir,"cstrike_beta",false))		g_Game = Game_CSS;	else
	if (StrEqual(gdir,"csgo",false))			g_Game = Game_CSGO;
	
	// Menus
	decl String:sSubTypeName[64];
	decl String:sDataField[16];
	
	// Weapon Select
	g_WepSelect = CreateMenu(WeaponMenuHandler);
	SetMenuTitle(g_WepSelect, "%t", "Weapon Selection Menu"); // Title
	
	Format(sDataField, sizeof(sDataField), "%d", Pistol_Deagle);
	Format(sSubTypeName, sizeof(sSubTypeName), "%t", "Pistol_Deagle");
	AddMenuItem(g_WepSelect, sDataField, sSubTypeName); // Deagle
	
	Format(sDataField, sizeof(sDataField), "%d", Pistol_P228);
	if(g_Game == Game_CSS)
		Format(sSubTypeName, sizeof(sSubTypeName), "%t", "Pistol_P228");
	else if(g_Game == Game_CSGO)
		Format(sSubTypeName, sizeof(sSubTypeName), "%t", "Pistol_P250");
	AddMenuItem(g_WepSelect, sDataField, sSubTypeName); // P228 / P250
	
	Format(sDataField, sizeof(sDataField), "%d", Pistol_Glock);
	Format(sSubTypeName, sizeof(sSubTypeName), "%t", "Pistol_Glock");
	AddMenuItem(g_WepSelect, sDataField, sSubTypeName); // Glock
	
	Format(sDataField, sizeof(sDataField), "%d", Pistol_FiveSeven);
	Format(sSubTypeName, sizeof(sSubTypeName), "%t", "Pistol_FiveSeven");
	AddMenuItem(g_WepSelect, sDataField, sSubTypeName); // FiveSeven
	
	Format(sDataField, sizeof(sDataField), "%d", Pistol_Dualies);
	Format(sSubTypeName, sizeof(sSubTypeName), "%t", "Pistol_Dualies");
	AddMenuItem(g_WepSelect, sDataField, sSubTypeName); // Dualies
	
	Format(sDataField, sizeof(sDataField), "%d", Pistol_USP);
	if(g_Game == Game_CSS)
		Format(sSubTypeName, sizeof(sSubTypeName), "%t", "Pistol_USP");
	else if(g_Game == Game_CSGO)
		Format(sSubTypeName, sizeof(sSubTypeName), "%t", "Pistol_P2000");
	AddMenuItem(g_WepSelect, sDataField, sSubTypeName); // USP / P2000
	
	if(g_Game == Game_CSGO)
	{
		Format(sDataField, sizeof(sDataField), "%d", Pistol_Tec9);
		Format(sSubTypeName, sizeof(sSubTypeName), "%t", "Pistol_Tec9");
		AddMenuItem(g_WepSelect, sDataField, sSubTypeName); // Tec 9
	}
	SetMenuExitButton(g_WepSelect, true);
	
	// Point Select
	g_PointSelect = CreateMenu(PointMenuHandler);
	SetMenuTitle(g_PointSelect, "%t", "Point Selection Menu"); // Title
	Format(sSubTypeName, sizeof(sSubTypeName), "%t", "Point_Selection");
	AddMenuItem(g_PointSelect, "0", sSubTypeName); // Deagle
	SetMenuExitButton(g_PointSelect, true);
	
	g_Offset_Clip1 = FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
	if (g_Offset_Clip1 == -1)
	{
		SetFailState("Unable to find offset for clip.");
	}
	g_Offset_Ammo = FindSendPropInfo("CCSPlayer", "m_iAmmo");
	if (g_Offset_Ammo == -1)
	{
		SetFailState("Unable to find offset for ammo.");
	}
	
	for (new i = 1; i <= MaxClients ; i++)
	{
		if (IsClientInGame(i))
		{
			SDKHook(i, SDKHook_WeaponDrop, OnWeaponDrop);
			SDKHook(i, SDKHook_WeaponEquip, OnWeaponEquip);
		}
	}
}

public OnMapStart()
{
	// Precache any materials needed
	if(g_Game == Game_CSS)
	{
		BeamSprite = PrecacheModel("materials/sprites/laser.vmt");
		HaloSprite = PrecacheModel("materials/sprites/halo01.vmt");
		LaserSprite = PrecacheModel("materials/sprites/lgtning.vmt");
		LaserHalo = PrecacheModel("materials/sprites/plasmahalo.vmt");
	}
	else if(g_Game == Game_CSGO)
	{
		BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
		HaloSprite = PrecacheModel("materials/sprites/glow01.vmt");
		LaserSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
		LaserHalo = PrecacheModel("materials/sprites/light_glow02.vmt");
	}
}

public OnConfigsExecuted()
{
	static bool:bAddedGunGolf = false;
	if (!bAddedGunGolf)
	{
		g_LREntryNum = AddLastRequestToList(GunGolf_Start, GunGolf_Stop, g_sLR_Name, false);
		bAddedGunGolf = true;
	}	
}

public PointMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		if(param2 == 0)
		{
			if((GetEntityFlags(param1) & FL_ONGROUND))
			{
				if(!IsClientTooNearObstacle(param1))
				{
					GetClientAbsOrigin(param1, g_fPoint_Origin);
					g_bGunGolfRunning = true;
					if(gH_Timer_Point_Beam == INVALID_HANDLE)
					{
						gH_Timer_Point_Beam = CreateTimer(0.5, Timer_Point_Beam, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
					}
					StripAllWeapons(g_LR_Player_Prisoner);
					StripAllWeapons(g_LR_Player_Guard);
					switch(g_WeaponSelected)
					{
						case Pistol_Deagle:
						{
							g_Pistol_Prisoner = GivePlayerItem(g_LR_Player_Prisoner, "weapon_deagle");
							g_Pistol_Guard = GivePlayerItem(g_LR_Player_Guard, "weapon_deagle");
						}
						case Pistol_P228:
						{
							if (g_Game == Game_CSS)
							{
								g_Pistol_Prisoner = GivePlayerItem(g_LR_Player_Prisoner, "weapon_p228");
								g_Pistol_Guard = GivePlayerItem(g_LR_Player_Guard, "weapon_p228");
							}
							else if (g_Game == Game_CSGO)
							{
								g_Pistol_Prisoner = GivePlayerItem(g_LR_Player_Prisoner, "weapon_p250");
								g_Pistol_Guard = GivePlayerItem(g_LR_Player_Guard, "weapon_p250");
							}
						}
						case Pistol_Glock:
						{
							g_Pistol_Prisoner = GivePlayerItem(g_LR_Player_Prisoner, "weapon_glock");
							g_Pistol_Guard = GivePlayerItem(g_LR_Player_Guard, "weapon_glock");
						}
						case Pistol_FiveSeven:
						{
							g_Pistol_Prisoner = GivePlayerItem(g_LR_Player_Prisoner, "weapon_fiveseven");
							g_Pistol_Guard = GivePlayerItem(g_LR_Player_Guard, "weapon_fiveseven");
						}
						case Pistol_Dualies:
						{
							g_Pistol_Prisoner = GivePlayerItem(g_LR_Player_Prisoner, "weapon_elite");
							g_Pistol_Guard = GivePlayerItem(g_LR_Player_Guard, "weapon_elite");
						}
						case Pistol_USP:
						{
							if(g_Game == Game_CSS)
							{
								g_Pistol_Prisoner = GivePlayerItem(g_LR_Player_Prisoner, "weapon_usp");
								g_Pistol_Guard = GivePlayerItem(g_LR_Player_Guard, "weapon_usp");
							}
							else if(g_Game == Game_CSGO)
							{
								g_Pistol_Prisoner = GivePlayerItem(g_LR_Player_Prisoner, "weapon_hkp2000");
								g_Pistol_Guard = GivePlayerItem(g_LR_Player_Guard, "weapon_hkp2000");
							}
						}
						case Pistol_Tec9:
						{
							g_Pistol_Prisoner = GivePlayerItem(g_LR_Player_Prisoner, "weapon_tec9");
							g_Pistol_Guard = GivePlayerItem(g_LR_Player_Guard, "weapon_tec9");
						}
					}
					GivePlayerItem(g_LR_Player_Prisoner, "weapon_knife");
					GivePlayerItem(g_LR_Player_Guard, "weapon_knife");
					new iAmmoType = GetEntProp(g_Pistol_Prisoner, Prop_Send, "m_iPrimaryAmmoType");
					SetEntData(g_LR_Player_Guard, g_Offset_Ammo+(iAmmoType*4), 0, _, true);
					SetEntData(g_LR_Player_Prisoner, g_Offset_Ammo+(iAmmoType*4), 0, _, true);
					SetEntData(g_Pistol_Prisoner, g_Offset_Clip1, 0);
					SetEntData(g_Pistol_Guard, g_Offset_Clip1, 0);
					if(gH_Timer_GunGolf == INVALID_HANDLE)
					{
						gH_Timer_GunGolf = CreateTimer(0.1, Timer_GunGolf, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
					}
					PrintToChatAll(CHAT_BANNER, "GG Start", g_LR_Player_Prisoner, g_LR_Player_Guard);
					InitializeLR(param1);
				}
				else
				{
					PrintToChat(param1, CHAT_BANNER, "Obstacle");
					DisplayMenu(g_PointSelect, param1, 0);
				}
			}
			else
			{
				PrintToChat(param1, CHAT_BANNER, "On Ground");
				DisplayMenu(g_PointSelect, param1, 0);
			}
		}
	}
	if (action == MenuAction_Cancel)
	{
		g_bGunGolfRunning = false;
		g_WeaponSelected = 0;
		CleanupLR(param1);
	}
}

public Action:Timer_Point_Beam(Handle:timer)
{
	if(!g_bGunGolfRunning)
	{
		gH_Timer_Point_Beam = INVALID_HANDLE;
		return Plugin_Stop;
	}
	decl Float:f_Origin[3];
	f_Origin[0] = g_fPoint_Origin[0];
	f_Origin[1] = g_fPoint_Origin[1];
	f_Origin[2] = g_fPoint_Origin[2] + 10;
	TE_SetupBeamRingPoint(f_Origin, 60.0, 150.0, BeamSprite, HaloSprite, 0, 15, 0.6, 5.0, 0.0, greyColor, 10, 0);
	TE_SendToAll();
	TE_SetupBeamRingPoint(f_Origin, 149.9, 150.0, BeamSprite, HaloSprite, 0, 10, 0.6, 10.0, 0.5, greenColor, 10, 0);
	TE_SendToAll();
	return Plugin_Continue;
}

public WeaponMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case Pistol_Deagle:
			{
				g_WeaponSelected = 0;
			}
			case Pistol_P228:
			{
				g_WeaponSelected = 1;
			}
			case Pistol_Glock:
			{
				g_WeaponSelected = 2;
			}
			case Pistol_FiveSeven:
			{
				g_WeaponSelected = 3;
			}
			case Pistol_Dualies:
			{
				g_WeaponSelected = 4;
			}
			case Pistol_USP:
			{
				g_WeaponSelected = 5;
			}
			case Pistol_Tec9:
			{
				g_WeaponSelected = 6;
			}
			default:
			{
				LogError("hit default S4S");
				g_WeaponSelected = 0;
			}
		}
		DisplayMenu(g_PointSelect, param1, 0);
	}
	if (action == MenuAction_Cancel)
	{
		g_bGunGolfRunning = false;
		g_WeaponSelected = 0;
		CleanupLR(param1);
	}
}

public Action:Timer_GunGolf(Handle:timer)
{
	if(!g_bGunGolfRunning)
	{
		gH_Timer_GunGolf = INVALID_HANDLE;
		return Plugin_Stop;
	}
	if(IsValidEntity(g_Pistol_Prisoner))
	{
		if(g_bPistol_Prisoner_Dropped)
		{
			if(!g_bPistol_Prisoner_Done)
			{
				GetEntPropVector(g_Pistol_Prisoner, Prop_Data, "m_vecOrigin", g_fPistol_Prisoner_Origin);
				g_fPistol_Prisoner_Distance = GetVectorDistance(g_fPoint_Origin, g_fPistol_Prisoner_Origin);
				TE_SetupBeamPoints(g_fPistol_Prisoner_Origin, g_fPoint_Origin, LaserSprite, LaserHalo, 1, 1, 0.2, 2.0, 2.0, 0, 10.0, redColor, 255);			
				TE_SendToAll();
				TE_SetupBeamPoints(g_fPoint_Origin, g_fPistol_Prisoner_Origin, LaserSprite, LaserHalo, 1, 1, 0.2, 2.0, 2.0, 0, 10.0, redColor, 255);			
				TE_SendToAll();
			}
			else
			{
				g_fPistol_Prisoner_Distance = GetVectorDistance(g_fPoint_Origin, g_fPistol_Prisoner_Last_Origin);
				TE_SetupBeamPoints(g_fPistol_Prisoner_Last_Origin, g_fPoint_Origin, LaserSprite, LaserHalo, 1, 1, 0.2, 2.0, 2.0, 0, 10.0, redColor, 255);			
				TE_SendToAll();
				TE_SetupBeamPoints(g_fPoint_Origin, g_fPistol_Prisoner_Last_Origin, LaserSprite, LaserHalo, 1, 1, 0.2, 2.0, 2.0, 0, 10.0, redColor, 255);			
				TE_SendToAll();
			}
		}
	}
	if(IsValidEntity(g_Pistol_Guard))
	{
		if(g_bPistol_Guard_Dropped)
		{
			if(!g_bPistol_Guard_Done)
			{
				GetEntPropVector(g_Pistol_Guard, Prop_Data, "m_vecOrigin", g_fPistol_Guard_Origin);
				g_fPistol_Guard_Distance = GetVectorDistance(g_fPoint_Origin, g_fPistol_Guard_Origin);
				TE_SetupBeamPoints(g_fPistol_Guard_Origin, g_fPoint_Origin, LaserSprite, LaserHalo, 1, 1, 0.2, 2.0, 2.0, 0, 10.0, blueColor, 255);			
				TE_SendToAll();
				TE_SetupBeamPoints(g_fPoint_Origin, g_fPistol_Guard_Origin, LaserSprite, LaserHalo, 1, 1, 0.2, 2.0, 2.0, 0, 10.0, blueColor, 255);			
				TE_SendToAll();
			}
			else
			{
				g_fPistol_Guard_Distance = GetVectorDistance(g_fPoint_Origin, g_fPistol_Guard_Last_Origin);
				TE_SetupBeamPoints(g_fPistol_Guard_Last_Origin, g_fPoint_Origin, LaserSprite, LaserHalo, 1, 1, 0.2, 2.0, 2.0, 0, 10.0, blueColor, 255);			
				TE_SendToAll();
				TE_SetupBeamPoints(g_fPoint_Origin, g_fPistol_Guard_Last_Origin, LaserSprite, LaserHalo, 1, 1, 0.2, 2.0, 2.0, 0, 10.0, blueColor, 255);			
				TE_SendToAll();
			}
		}
	}
	return Plugin_Continue;
}

public Action:Timer_GunGolf_Details(Handle:timer)
{
	if(!g_bGunGolfRunning)
	{
		gH_Timer_GunGolf_Details = INVALID_HANDLE;
		return Plugin_Stop;
	}
	if(g_bPistol_Prisoner_Dropped || g_bPistol_Guard_Dropped)
	{
		if (g_Game == Game_CSS)
		{
			if(IsClientInGame(g_LR_Player_Prisoner))
				PrintHintText(g_LR_Player_Prisoner, "%t\n \n%N: %3.1f \n%N: %3.1f", "Distance Meter", g_LR_Player_Prisoner, g_fPistol_Prisoner_Distance, g_LR_Player_Guard, g_fPistol_Guard_Distance);
			if(IsClientInGame(g_LR_Player_Guard))
				PrintHintText(g_LR_Player_Guard, "%t\n \n%N: %3.1f \n%N: %3.1f", "Distance Meter", g_LR_Player_Prisoner, g_fPistol_Prisoner_Distance, g_LR_Player_Guard, g_fPistol_Guard_Distance);
		}
		else if (g_Game == Game_CSGO)
		{
			if(IsClientInGame(g_LR_Player_Prisoner))
				PrintHintText(g_LR_Player_Prisoner, "%t\n%N: %3.1f \n%N: %3.1f", "Distance Meter", g_LR_Player_Prisoner, g_fPistol_Prisoner_Distance, g_LR_Player_Guard, g_fPistol_Guard_Distance);
			if(IsClientInGame(g_LR_Player_Guard))
				PrintHintText(g_LR_Player_Guard, "%t\n%N: %3.1f \n%N: %3.1f", "Distance Meter", g_LR_Player_Prisoner, g_fPistol_Prisoner_Distance, g_LR_Player_Guard, g_fPistol_Guard_Distance);
		}
		if(!g_bPistol_Prisoner_Done)
		{
			if(g_fPistol_Prisoner_Last_Origin[0] != 0.0)
			{
				new Float:fPistol_Prisoner_Distance = GetVectorDistance(g_fPistol_Prisoner_Last_Origin, g_fPistol_Prisoner_Origin);
				if(fPistol_Prisoner_Distance < 3.0)
				{
					g_bPistol_Prisoner_Done = true;
				}
				else
				{
					g_fPistol_Prisoner_Last_Origin[0] = g_fPistol_Prisoner_Origin[0];
					g_fPistol_Prisoner_Last_Origin[1] = g_fPistol_Prisoner_Origin[1];
					g_fPistol_Prisoner_Last_Origin[2] = g_fPistol_Prisoner_Origin[2];
				}
			}
			else
			{
				g_fPistol_Prisoner_Last_Origin[0] = g_fPistol_Prisoner_Origin[0];
				g_fPistol_Prisoner_Last_Origin[1] = g_fPistol_Prisoner_Origin[1];
				g_fPistol_Prisoner_Last_Origin[2] = g_fPistol_Prisoner_Origin[2];
			}
		}
		if(!g_bPistol_Guard_Done)
		{
			if(g_fPistol_Guard_Last_Origin[0] != 0.0)
			{
				new Float:fPistol_Guard_Distance = GetVectorDistance(g_fPistol_Guard_Last_Origin, g_fPistol_Guard_Origin);
				if(fPistol_Guard_Distance < 3.0)
				{
					g_bPistol_Guard_Done = true;
				}
				else
				{
					g_fPistol_Guard_Last_Origin[0] = g_fPistol_Guard_Origin[0];
					g_fPistol_Guard_Last_Origin[1] = g_fPistol_Guard_Origin[1];
					g_fPistol_Guard_Last_Origin[2] = g_fPistol_Guard_Origin[2];
				}
			}
			else
			{
				g_fPistol_Guard_Last_Origin[0] = g_fPistol_Guard_Origin[0];
				g_fPistol_Guard_Last_Origin[1] = g_fPistol_Guard_Origin[1];
				g_fPistol_Guard_Last_Origin[2] = g_fPistol_Guard_Origin[2];
			}
		}
	}
	return Plugin_Continue;
}

public Action:OnWeaponEquip(client, weapon)
{
	if(g_This_LR_Type == g_LREntryNum)
	{
		if(g_bGunGolfRunning)
		{
			if(client == g_LR_Player_Prisoner && weapon == g_Pistol_Prisoner && g_bPistol_Prisoner_Dropped && !g_bPistol_Prisoner_Done)
			{
				g_bPistol_Prisoner_Done = true;
			}
			else if(client == g_LR_Player_Guard && weapon == g_Pistol_Guard && g_bPistol_Guard_Dropped && !g_bPistol_Guard_Done)
			{
				g_bPistol_Guard_Done = true;
			}
		}
	}
}

public Action:OnWeaponDrop(client, weapon)
{
	if(g_This_LR_Type == g_LREntryNum)
	{
		if(g_bGunGolfRunning)
		{
			if(client == g_LR_Player_Prisoner || client == g_LR_Player_Guard)
			{
				if(weapon == g_Pistol_Prisoner || weapon == g_Pistol_Guard)
				{
					if(!g_bPistol_Prisoner_Dropped || !g_bPistol_Guard_Dropped)
					{
						if(g_Game == Game_CSS)
						{
							if(gH_Timer_GunGolf_Details == INVALID_HANDLE)
							{
								gH_Timer_GunGolf_Details = CreateTimer(0.1, Timer_GunGolf_Details, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
							}
						}
						else if(g_Game == Game_CSGO)
						{
							if(gH_Timer_GunGolf_Details == INVALID_HANDLE)
							{
								gH_Timer_GunGolf_Details = CreateTimer(1.0, Timer_GunGolf_Details, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
							}
						}
						
						if(client == g_LR_Player_Prisoner)
						{
							if(IsValidEntity(g_Pistol_Prisoner))
							{
								if(weapon == g_Pistol_Prisoner)
								{
									SetEntData(g_Pistol_Prisoner, g_Offset_Clip1, 100);
									g_bPistol_Prisoner_Dropped = true;
								}
							}
						}
						else if(client == g_LR_Player_Guard)
						{
							if(IsValidEntity(g_Pistol_Guard))
							{
								if(weapon == g_Pistol_Guard)
								{
									SetEntData(g_Pistol_Guard, g_Offset_Clip1, 100);
									g_bPistol_Guard_Dropped = true;
								}
							}
						}
					}
				}
			}
		}
	}
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
	SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
}

// The plugin should remove any LRs it loads when it's unloaded
public OnPluginEnd()
{
	RemoveLastRequestFromList(GunGolf_Start, GunGolf_Stop, g_sLR_Name);
}

public GunGolf_Start(Handle:LR_Array, iIndexInArray)
{
	g_This_LR_Type = GetArrayCell(LR_Array, iIndexInArray, _:Block_LRType); // get this lr from selection
	if (g_This_LR_Type == g_LREntryNum)
	{
		g_LR_Player_Prisoner = GetArrayCell(LR_Array, iIndexInArray, _:Block_Prisoner); // get prisoner's id
		g_LR_Player_Guard = GetArrayCell(LR_Array, iIndexInArray, _:Block_Guard); // get guard's id
		
		// check datapack value
		new LR_Pack_Value = GetArrayCell(LR_Array, iIndexInArray, _:Block_Global1);	
		switch (LR_Pack_Value)
		{
			case -1:
			{
				PrintToServer("no info included");
			}
		}
		DisplayMenu(g_WepSelect, g_LR_Player_Prisoner, 0);
	}
}

public GunGolf_Stop(Type, Prisoner, Guard)
{
	if(Type == g_LREntryNum)
	{
		if (IsClientInGame(Prisoner) && IsClientInGame(Guard))
		{
			if (IsPlayerAlive(Prisoner) && IsPlayerAlive(Guard))
			{
				SetEntityHealth(Prisoner, 100);
				StripAllWeapons(Prisoner);
				GivePlayerItem(Prisoner, "weapon_knife");
				SetEntityHealth(Guard, 100);
				StripAllWeapons(Guard);
				GivePlayerItem(Guard, "weapon_knife");
				PrintToChatAll(CHAT_BANNER, "GG Stopped");
			}
			else if(IsPlayerAlive(Prisoner))
			{
				SetEntityHealth(Prisoner, 100);
				StripAllWeapons(Prisoner);
				GivePlayerItem(Prisoner, "weapon_knife");
				PrintToChatAll(CHAT_BANNER, "GG Winner", Prisoner);
			}
			else if (IsPlayerAlive(Guard))
			{
				SetEntityHealth(Guard, 100);
				StripAllWeapons(Guard);
				GivePlayerItem(Guard, "weapon_knife");
				PrintToChatAll(CHAT_BANNER, "GG Winner", Guard);
			}
		}
		else if (IsClientInGame(Prisoner))
		{
			if (IsPlayerAlive(Prisoner))
			{
				SetEntityHealth(Prisoner, 100);
				StripAllWeapons(Prisoner);
				GivePlayerItem(Prisoner, "weapon_knife");
				PrintToChatAll(CHAT_BANNER, "GG Winner", Prisoner);
			}
		}
		else if (IsClientInGame(Guard))
		{
			if (IsPlayerAlive(Guard))
			{
				SetEntityHealth(Guard, 100);
				StripAllWeapons(Guard);
				GivePlayerItem(Guard, "weapon_knife");
				PrintToChatAll(CHAT_BANNER, "GG Winner", Guard);
			}
		}
		g_bGunGolfRunning = false;
		g_fPistol_Prisoner_Last_Origin[0] = 0.0;
		g_fPistol_Prisoner_Last_Origin[1] = 0.0;
		g_fPistol_Prisoner_Last_Origin[2] = 0.0;
		g_fPistol_Guard_Last_Origin[0] = 0.0;
		g_fPistol_Guard_Last_Origin[1] = 0.0;
		g_fPistol_Guard_Last_Origin[2] = 0.0;
		g_fPistol_Prisoner_Origin[0] = 0.0;
		g_fPistol_Prisoner_Origin[1] = 0.0;
		g_fPistol_Prisoner_Origin[2] = 0.0;
		g_fPistol_Guard_Origin[0] = 0.0;
		g_fPistol_Guard_Origin[1] = 0.0;
		g_fPistol_Guard_Origin[2] = 0.0;
		g_fPistol_Prisoner_Distance = 0.0;
		g_fPistol_Guard_Distance = 0.0;
		g_bPistol_Prisoner_Dropped = false;
		g_bPistol_Prisoner_Done = false;
		g_bPistol_Guard_Dropped = false;
		g_bPistol_Guard_Done = false;
		g_WeaponSelected = -1;
	}
}