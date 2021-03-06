#pragma semicolon 1

/* SM Includes */
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smac>
#undef REQUIRE_PLUGIN
#tryinclude <updater>

/* Plugin Info */
public Plugin:myinfo =
{
	name = "SMAC Eye Angle Test",
	author = SMAC_AUTHOR,
	description = "Detects eye angle violations used in cheats",
	version = SMAC_VERSION,
	url = SMAC_URL
};

/* Globals */
#define UPDATE_URL	"http://smac.sx/updater/smac_eyetest.txt"

enum ResetStatus {
	State_Okay = 0,
	State_Resetting,
	State_Reset
};

new GameType:g_Game = Game_Unknown;

new Handle:g_hCvarBan = INVALID_HANDLE;
new Handle:g_hCvarCompat = INVALID_HANDLE;
new Float:g_fDetectedTime[MAXPLAYERS+1];

new bool:g_bInMinigun[MAXPLAYERS+1];

new bool:g_bPrevAlive[MAXPLAYERS+1];
new g_iPrevButtons[MAXPLAYERS+1] = {-1, ...};
new g_iPrevCmdNum[MAXPLAYERS+1] = {-1, ...};
new g_iPrevTickCount[MAXPLAYERS+1] = {-1, ...};
new g_iCmdNumOffset[MAXPLAYERS+1] = {1, ...};

new ResetStatus:g_TickStatus[MAXPLAYERS+1];
new bool:g_bLateLoad = false;

// Arbitrary group names for the purpose of differentiating eye angle detections.
enum EngineGroup {
	Group_Ignore = 0,
	Group_EP1,
	Group_EP2V,
	Group_L4D2
};

new EngineVersion:g_EngineVersion = Engine_Unknown;
new EngineGroup:g_EngineGroup = Group_Ignore;

/* Plugin Functions */
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	LoadTranslations("smac.phrases");
	
	// Convars.
	g_hCvarBan = SMAC_CreateConVar("smac_eyetest_ban", "0", "Automatically ban players on eye test detections.", 0, true, 0.0, true, 1.0);
	g_hCvarCompat = SMAC_CreateConVar("smac_eyetest_compat", "0", "Enable compatibility mode with third-party plugins. This will disable some detection methods.", 0, true, 0.0, true, 1.0);
	
	// Cache engine version and game type.
	g_EngineVersion = GetEngineVersion();
	
	if (g_EngineVersion == Engine_Unknown)
	{
		decl String:sGame[64];
		GetGameFolderName(sGame, sizeof(sGame));
		SetFailState("Engine Version could not be determined for game: %s", sGame);
	}
	
	switch (g_EngineVersion)
	{
		case Engine_Original, Engine_DarkMessiah, Engine_SourceSDK2006, Engine_SourceSDK2007, Engine_BloodyGoodTime, Engine_EYE:
		{
			g_EngineGroup = Group_EP1;
		}
		case Engine_CSS, Engine_DODS, Engine_HL2DM, Engine_TF2:
		{
			g_EngineGroup = Group_EP2V;
		}
		case Engine_Left4Dead, Engine_Left4Dead2, Engine_NuclearDawn, Engine_CSGO:
		{
			g_EngineGroup = Group_L4D2;
		}
	}
	
	// Initialize.
	g_Game = SMAC_GetGameType();
	RequireFeature(FeatureType_Capability, FEATURECAP_PLAYERRUNCMD_11PARAMS, "This module requires a newer version of SourceMod.");
	
	// Check for existing minigun entities on late-load.
	if (g_bLateLoad && (g_Game == Game_L4D || g_Game == Game_L4D2))
	{
		decl String:sClassname[32];
		new maxEdicts = GetEntityCount();
		for (new i = MaxClients + 1; i < maxEdicts; i++)
		{
			if (IsValidEdict(i) && GetEdictClassname(i, sClassname, sizeof(sClassname)))
			{
				OnEntityCreated(i, sClassname);
			}
		}
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				g_bInMinigun[i] = true;
			}
		}
	}

#if defined _updater_included
	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
#endif
}

public OnLibraryAdded(const String:name[])
{
#if defined _updater_included
	if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
#endif
}

public OnClientDisconnect(client)
{
	// Clients don't actually disconnect on map change. They start sending the new cmdnums before _Post fires.
	g_bInMinigun[client] = false;
	g_bPrevAlive[client] = false;
	g_iPrevButtons[client] = -1;
	g_iPrevCmdNum[client] = -1;
	g_iPrevTickCount[client] = -1;
	g_iCmdNumOffset[client] = 1;
	g_TickStatus[client] = State_Okay;
}

public OnClientDisconnect_Post(client)
{
	g_fDetectedTime[client] = 0.0;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2])
{
	// Ignore bots
	if (IsFakeClient(client))
		return Plugin_Continue;
	
	// NULL commands
	if (cmdnum <= 0)
		return Plugin_Handled;
	
	// Block old cmds after a client resets their tickcount.
	if (tickcount <= 0)
		g_TickStatus[client] = State_Resetting;
	
	// Fixes issues caused by client timeouts.
	new bool:bAlive = IsPlayerAlive(client);
	if (!bAlive || !g_bPrevAlive[client] || GetGameTime() <= g_fDetectedTime[client])
	{
		g_bPrevAlive[client] = bAlive;
		g_iPrevButtons[client] = buttons;
		
		if (g_iPrevCmdNum[client] >= cmdnum)
		{
			if (g_TickStatus[client] == State_Resetting)
				g_TickStatus[client] = State_Reset;
		
			g_iCmdNumOffset[client]++;
		}
		else
		{
			if (g_TickStatus[client] == State_Reset)
				g_TickStatus[client] = State_Okay;
			
			g_iPrevCmdNum[client] = cmdnum;
			g_iCmdNumOffset[client] = 1;
		}
		
		g_iPrevTickCount[client] = tickcount;
		
		return Plugin_Continue;
	}
	
	// Check for valid cmd values being sent. The command number cannot decrement.
	if (g_iPrevCmdNum[client] > cmdnum)
	{
		if (g_TickStatus[client] != State_Okay)
		{
			g_TickStatus[client] = State_Reset;
			return Plugin_Handled;
		}
	
		g_fDetectedTime[client] = GetGameTime() + 30.0;
		
		new Handle:info = CreateKeyValues("");
		KvSetNum(info, "cmdnum", cmdnum);
		KvSetNum(info, "prevcmdnum", g_iPrevCmdNum[client]);
		KvSetNum(info, "tickcount", tickcount);
		KvSetNum(info, "prevtickcount", g_iPrevTickCount[client]);
		KvSetNum(info, "gametickcount", GetGameTickCount());
		
		if (SMAC_CheatDetected(client, Detection_UserCmdReuse, info) == Plugin_Continue)
		{
			SMAC_PrintAdminNotice("%t", "SMAC_EyetestDetected", client);
			
			if (GetConVarBool(g_hCvarBan))
			{
				SMAC_LogAction(client, "was banned for reusing old movement commands. CmdNum: %d PrevCmdNum: %d | [%d:%d:%d]", cmdnum, g_iPrevCmdNum[client], g_iPrevTickCount[client], tickcount, GetGameTickCount());
				SMAC_Ban(client, "Eye Test Violation");
			}
			else
			{
				SMAC_LogAction(client, "is suspected of reusing old movement commands. CmdNum: %d PrevCmdNum: %d | [%d:%d:%d]", cmdnum, g_iPrevCmdNum[client], g_iPrevTickCount[client], tickcount, GetGameTickCount());
			}
		}
		
		CloseHandle(info);
		return Plugin_Handled;
	}
	
	// Other than the incremented tickcount, nothing should have changed.
	if (g_iPrevCmdNum[client] == cmdnum)
	{
		if (g_TickStatus[client] != State_Okay)
		{
			g_TickStatus[client] = State_Reset;
			return Plugin_Handled;
		}
	
		// The tickcount should be incremented.
		// No longer true in CS:GO (https://forums.alliedmods.net/showthread.php?t=267559)
		if (g_iPrevTickCount[client] != tickcount && g_iPrevTickCount[client]+1 != tickcount)
		{
			g_fDetectedTime[client] = GetGameTime() + 30.0;
			
			new Handle:info = CreateKeyValues("");
			KvSetNum(info, "cmdnum", cmdnum);
			KvSetNum(info, "tickcount", tickcount);
			KvSetNum(info, "prevtickcount", g_iPrevTickCount[client]);
			KvSetNum(info, "gametickcount", GetGameTickCount());
			
			if (SMAC_CheatDetected(client, Detection_UserCmdTamperingTickcount, info) == Plugin_Continue)
			{
				SMAC_PrintAdminNotice("%t", "SMAC_EyetestDetected", client);
				
				if (GetConVarBool(g_hCvarBan))
				{
					SMAC_LogAction(client, "was banned for tampering with an old movement command (tickcount). CmdNum: %d | [%d:%d:%d]", cmdnum, g_iPrevTickCount[client], tickcount, GetGameTickCount());
					SMAC_Ban(client, "Eye Test Violation");
				}
				else
				{
					SMAC_LogAction(client, "is suspected of tampering with an old movement command (tickcount). CmdNum: %d | [%d:%d:%d]", cmdnum, g_iPrevTickCount[client], tickcount, GetGameTickCount());
				}
			}
			
			CloseHandle(info);
			return Plugin_Handled;
		}
		
		// Check for specific buttons in order to avoid compatibility issues with server-side plugins.
		if (!GetConVarBool(g_hCvarCompat) && ((g_iPrevButtons[client] ^ buttons) & (IN_FORWARD|IN_BACK|IN_MOVELEFT|IN_MOVERIGHT|IN_SCORE)))
		{
			g_fDetectedTime[client] = GetGameTime() + 30.0;
			
			new Handle:info = CreateKeyValues("");
			KvSetNum(info, "cmdnum", cmdnum);
			KvSetNum(info, "prevbuttons", g_iPrevButtons[client]);
			KvSetNum(info, "buttons", buttons);

			if (SMAC_CheatDetected(client, Detection_UserCmdTamperingButtons, info) == Plugin_Continue)
			{
				SMAC_PrintAdminNotice("%t", "SMAC_EyetestDetected", client);
				
				if (GetConVarBool(g_hCvarBan))
				{
					SMAC_LogAction(client, "was banned for tampering with an old movement command (buttons). CmdNum: %d | [%d:%d]", cmdnum, g_iPrevButtons[client], buttons);
					SMAC_Ban(client, "Eye Test Violation");
				}
				else
				{
					SMAC_LogAction(client, "is suspected of tampering with an old movement command (buttons). CmdNum: %d | [%d:%d]", cmdnum, g_iPrevButtons[client], buttons);
				}
			}
			
			CloseHandle(info);
			return Plugin_Handled;
		}
		
		// Track so we can predict the next cmdnum.
		g_iCmdNumOffset[client]++;
	}
	else
	{
		// Passively block cheats from skipping to desired seeds.
		if ((buttons & IN_ATTACK) && g_iPrevCmdNum[client] + g_iCmdNumOffset[client] != cmdnum && g_iPrevCmdNum[client] > 0)
		{
			seed = GetURandomInt();
		}
		
		g_iCmdNumOffset[client] = 1;
	}
	
	g_iPrevButtons[client] = buttons;
	g_iPrevCmdNum[client] = cmdnum;
	g_iPrevTickCount[client] = tickcount;
	
	if (g_TickStatus[client] == State_Reset)
	{
		g_TickStatus[client] = State_Okay;
	}
	
	// Check for valid eye angles.
	switch (g_EngineGroup)
	{
		case Group_L4D2:
		{
			// In L4D+ engines the client can alternate between ±180 and 0-360.
			if (angles[0] > -135.0 && angles[0] < 135.0 && angles[1] > -270.0 && angles[1] < 420.0)
			{
				g_bInMinigun[client] = false;
				return Plugin_Continue;
			}
			
			if (g_bInMinigun[client])
				return Plugin_Continue;
		}
		case Group_EP2V:
		{
			// ± normal limit * 1.5 as a buffer zone.
			// TF2 taunts conflict with yaw checks.
			if (angles[0] > -135.0 && angles[0] < 135.0 && (g_EngineVersion == Engine_TF2 || (angles[1] > -270.0 && angles[1] < 270.0)))
				return Plugin_Continue;
		}
		case Group_EP1:
		{
			// Older engine support.
			decl Float:vTemp[3];
			vTemp = angles;
			
			if (vTemp[0] > 180.0)
				vTemp[0] -= 360.0;
			
			if (vTemp[2] > 180.0)
				vTemp[2] -= 360.0;
			
			if (vTemp[0] >= -90.0 && vTemp[0] <= 90.0 && vTemp[2] >= -90.0 && vTemp[2] <= 90.0)
				return Plugin_Continue;
		}
		default:
		{
			// Ignore angles for this engine.
			return Plugin_Continue;
		}
	}
	
	// Game specific checks.
	switch (g_Game)
	{
		case Game_DODS:
		{
			// Ignore prone players.
			if (DODS_IsPlayerProne(client))
				return Plugin_Continue;
		}
		case Game_L4D:
		{
			// Only check survivors in first-person view.
			if (GetClientTeam(client) != 2 || L4D_IsSurvivorBusy(client))
				return Plugin_Continue;
		}
		case Game_L4D2:
		{
			// Only check survivors in first-person view.
			if (GetClientTeam(client) != 2 || L4D2_IsSurvivorBusy(client))
				return Plugin_Continue;
		}
		case Game_ND:
		{
			if (ND_IsPlayerCommander(client))
				return Plugin_Continue;
		}
	}
	
	// Ignore clients that are interacting with the map.
	new flags = GetEntityFlags(client);
	
	if (flags & FL_FROZEN || flags & FL_ATCONTROLS)
		return Plugin_Continue;
	
	// The client failed all checks.
	g_fDetectedTime[client] = GetGameTime() + 30.0;
	
	// Strict bot checking - https://bugs.alliedmods.net/show_bug.cgi?id=5294
	decl String:sAuthID[MAX_AUTHID_LENGTH];
	
	new Handle:info = CreateKeyValues("");
	KvSetVector(info, "angles", angles);
	
	if (GetClientAuthId(client, AuthId_Steam2, sAuthID, sizeof(sAuthID), false) && !StrEqual(sAuthID, "BOT") && SMAC_CheatDetected(client, Detection_Eyeangles, info) == Plugin_Continue)
	{
		SMAC_PrintAdminNotice("%t", "SMAC_EyetestDetected", client);
		
		if (GetConVarBool(g_hCvarBan))
		{
			SMAC_LogAction(client, "was banned for cheating with their eye angles. Eye Angles: %.0f %.0f %.0f", angles[0], angles[1], angles[2]);
			SMAC_Ban(client, "Eye Test Violation");
		}
		else
		{
			SMAC_LogAction(client, "is suspected of cheating with their eye angles. Eye Angles: %.0f %.0f %.0f", angles[0], angles[1], angles[2]);
		}
	}
	
	CloseHandle(info);
	return Plugin_Continue;
}

public OnEntityCreated(entity, const String:classname[])
{
	if (g_Game != Game_L4D && g_Game != Game_L4D2)
		return;
	
	if (StrEqual(classname, "prop_minigun") || 
		StrEqual(classname, "prop_minigun_l4d1") || 
		StrEqual(classname, "prop_mounted_machine_gun"))
	{
		SDKHook(entity, SDKHook_Use, Hook_MinigunUse);
	}
}

public Action:Hook_MinigunUse(entity, activator, caller, UseType:type, Float:value)
{
	// This will forward Use_Set on each tick, and then Use_Off when released.
	if (IS_CLIENT(activator) && type == Use_Set)
	{
		g_bInMinigun[activator] = true;
	}
	
	return Plugin_Continue;
}
