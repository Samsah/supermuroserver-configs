/*  <DR.API BOTS NAMES> (c) by <De Battista Clint - (http://doyou.watch)     */
/*                                                                           */
/*                 <DR.API BOTS NAMES> is licensed under a                   */
/* Creative Commons Attribution-NonCommercial-NoDerivs 4.0 Unported License. */
/*																			 */
/*      You should have received a copy of the license along with this       */
/*  work.  If not, see <http://creativecommons.org/licenses/by-nc-nd/4.0/>.  */
//***************************************************************************//
//***************************************************************************//
//*****************************DR.API BOTS NAMES*****************************//
//***************************************************************************//
//***************************************************************************//

#pragma semicolon 1 

//***********************************//
//*************DEFINE****************//
//***********************************//
#define TAG_BOT_NAMES_CSGO 				"[BOTS NAMES] - "
#define BOT_NAMES						64
#define PLUGIN_VERSION 					"1.0.1"
#define CVARS 							FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY
#define DEFAULT_FLAGS 					FCVAR_PLUGIN|FCVAR_NOTIFY

//***********************************//
//*************INCLUDE***************//
//***********************************//

#undef REQUIRE_PLUGIN
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <autoexec>

#pragma newdecls required

//***********************************//
//***********PARAMETERS**************//
//***********************************//

//Handle
Handle cvar_active_bots_names;
Handle cvar_active_bots_names_dev;
Handle cvar_active_bots_names_ping;

Handle cvar_bots_names_clan;
Handle cvar_bots_names_min_ping;
Handle cvar_bots_names_max_ping;
Handle cvar_bots_names_interval_ping;

//Bool
bool B_active_bots_names 							= false;
bool B_active_bots_names_dev						= false;
bool B_active_bots_names_ping						= false;

//String
char S_bots_names_clan[MAX_NAME_LENGTH];
char S_bots_names_name[BOT_NAMES][MAX_NAME_LENGTH];

//Float
float F_timer_interval								= 0.0;

//Customs
int C_bots_names_min_ping							= 0;
int C_bots_names_max_ping							= 0;
int C_bots_names_interval_ping						= 0;

UserMsg TextMsgBotsNames;
UserMsg SayTextBotsNames; 
UserMsg SayText2BotsNames;
//UserMsg RadioTextBotsNames;

int total_bot_name_csgo								= 0;
int C_cs_player_manager								= 0;
int C_ping											= -1;
int C_max_clients									= 0;

//Informations plugin
public Plugin myinfo =
{
	name = "DR.API BOTS NAMES",
	author = "Dr. Api",
	description = "DR.API BOTS NAMES by Dr. Api",
	version = PLUGIN_VERSION,
	url = "http://doyou.watch"
}
/***********************************************************/
/*********************** PLUGIN START **********************/
/***********************************************************/
public void OnPluginStart()
{
	AutoExecConfig_SetFile("drapi_bots_names", "sourcemod/drapi");
	
	AutoExecConfig_CreateConVar("drapi_bots_names_version", PLUGIN_VERSION, "Version", CVARS);
	
	cvar_active_bots_names 								= AutoExecConfig_CreateConVar("drapi_active_bots_names",  					"1", 					"Enable/Disable Bot Names", 			DEFAULT_FLAGS, 		true, 0.0, 		true, 1.0);
	cvar_active_bots_names_ping 						= AutoExecConfig_CreateConVar("drapi_active_bots_names_ping",  				"1", 					"Enable/Disable Bot Names Ping", 		DEFAULT_FLAGS, 		true, 0.0, 		true, 1.0);
	cvar_active_bots_names_dev							= AutoExecConfig_CreateConVar("drapi_active_bots_names_dev", 				"0", 					"Enable/Disable Bot Names Dev Mod", 	DEFAULT_FLAGS, 		true, 0.0, 		true, 1.0);
	cvar_bots_names_clan								= AutoExecConfig_CreateConVar("drapi_bots_names_clan", 						"Zombie4Ever.eu", 		"Clan name", 							DEFAULT_FLAGS);
	cvar_bots_names_min_ping							= AutoExecConfig_CreateConVar("drapi_bots_names_min_ping", 					"35", 					"Fake ping bots min", 					DEFAULT_FLAGS);
	cvar_bots_names_max_ping							= AutoExecConfig_CreateConVar("drapi_bots_names_max_ping", 					"55", 					"Fake ping bots max", 					DEFAULT_FLAGS);
	cvar_bots_names_interval_ping						= AutoExecConfig_CreateConVar("drapi_bots_names_interval_ping", 			"3", 					"Fake ping bots interval", 				DEFAULT_FLAGS);
	
	HookEvents();
	
	TextMsgBotsNames  		= GetUserMessageId("TextMsg");
	SayTextBotsNames 		= GetUserMessageId("SayText");
	SayText2BotsNames 		= GetUserMessageId("SayText2");
	//RadioTextBotsNames 	= GetUserMessageId("RadioText");
	HookUserMessage(TextMsgBotsNames,  		UserMessagesHook, true);
	HookUserMessage(SayTextBotsNames,  		UserMessagesHook, true);
	HookUserMessage(SayText2BotsNames, 		UserMessagesHook, true);
	//HookUserMessage(RadioTextBotsNames, 	UserMessagesHook, true);
	
	C_ping	= FindSendPropOffs("CPlayerResource", "m_iPing");
	AutoExecConfig_ExecuteFile();
}

/***********************************************************/
/******************** WHEN CVAR CHANGED ********************/
/***********************************************************/
void HookEvents()
{
	HookConVarChange(cvar_active_bots_names, 					Event_CvarChange);
	HookConVarChange(cvar_active_bots_names_ping, 				Event_CvarChange);
	HookConVarChange(cvar_active_bots_names_dev, 				Event_CvarChange);
	
	HookConVarChange(cvar_bots_names_clan, 						Event_CvarChange);
	HookConVarChange(cvar_bots_names_min_ping, 					Event_CvarChange);
	HookConVarChange(cvar_bots_names_max_ping, 					Event_CvarChange);
	HookConVarChange(cvar_bots_names_interval_ping, 			Event_CvarChange);
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
	B_active_bots_names 					= GetConVarBool(cvar_active_bots_names);
	B_active_bots_names_ping 				= GetConVarBool(cvar_active_bots_names_ping);
	B_active_bots_names_dev 				= GetConVarBool(cvar_active_bots_names_dev);
	
	C_bots_names_min_ping					= GetConVarInt(cvar_bots_names_min_ping);
	C_bots_names_max_ping					= GetConVarInt(cvar_bots_names_max_ping);
	C_bots_names_interval_ping				= GetConVarInt(cvar_bots_names_interval_ping);
	
	GetConVarString(cvar_bots_names_clan, S_bots_names_clan, sizeof(S_bots_names_clan));
	
	C_max_clients 		= GetMaxClients();
	C_cs_player_manager = FindEntityByClassname(C_max_clients + 1, "cs_player_manager");
	F_timer_interval	= 0.0;
}

/***********************************************************/
/******************* WHEN CONFIG EXECUTED ******************/
/***********************************************************/
public void OnConfigsExecuted()
{
	LoadBotsNames();
}

/***********************************************************/
/********************* WHEN MAP START **********************/
/***********************************************************/
public void OnMapStart()
{
	UpdateState();
}

/***********************************************************/
/**************** WHEN CLIENT PUT IN SERVER ****************/
/***********************************************************/
public void OnClientPutInServer(int client)
{
	if(B_active_bots_names)
	{
		if(Client_IsValid(client) && IsFakeClient(client))
		{
			CS_SetClientClanTag(client, S_bots_names_clan);
			
	
			int userid = GetClientUserId(client);
			int id = GetClientOfUserId(userid);

			if(strlen(S_bots_names_name[id]))
			{
				SetClientName(client, S_bots_names_name[id]);
			}
			
			if(B_active_bots_names_dev)
			{
				LogMessage("%sTotal names: %i, Userid:%i", TAG_BOT_NAMES_CSGO, total_bot_name_csgo, id);
			}
			
		}
	}
}

/***********************************************************/
/********************** ON GAME FRAME **********************/
/***********************************************************/
public void OnGameFrame()
{
	if(B_active_bots_names && B_active_bots_names_ping)
	{
		if(F_timer_interval < GetGameTime() - C_bots_names_interval_ping)
		{
			F_timer_interval = GetGameTime();
			
			if(C_cs_player_manager == -1 || C_ping == -1)
			{
				return;
			}

			for(int i = 1; i <= C_max_clients; i++)
			{
				if(!IsValidEdict(i) || !IsClientInGame(i) || !IsFakeClient(i))
				{
					continue;
				}

				SetEntData(C_cs_player_manager, C_ping + (i * 4), GetRandomInt(C_bots_names_min_ping, C_bots_names_max_ping));
			}
		}
	}
}

/***********************************************************/
/******************* WHEN PLAYER MESSAGE *******************/
/***********************************************************/
public Action UserMessagesHook(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if(B_active_bots_names)
	{
		if(Client_IsIngame(playersNum) && IsFakeClient(playersNum))
		{
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

/***********************************************************/
/**************** LOAD FILE SETTING BOT NAMES **************/
/***********************************************************/
public void LoadBotsNames()
{
	char hc[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, hc, sizeof(hc), "configs/drapi/bots_names.cfg");
	
	Handle kv = CreateKeyValues("BotNames");
	FileToKeyValues(kv, hc);
	
	if(KvGotoFirstSubKey(kv))
	{
		do
		{
			for(int i = 1; i < BOT_NAMES; ++i)
			{
				char key[64];
				IntToString(i, key, 64);
				KvGetString(kv, key, S_bots_names_name[i], MAX_NAME_LENGTH);
				
				if(strlen(S_bots_names_name[i]))
				{
					total_bot_name_csgo = i;
					if(B_active_bots_names_dev)
					{
						LogMessage("%sBot names: %s", TAG_BOT_NAMES_CSGO, S_bots_names_name[i]);
					}
				}
			}
		}
		while (KvGotoNextKey(kv));
	}
	CloseHandle(kv);
}

/***********************************************************/
/********************* IS VALID CLIENT *********************/
/***********************************************************/
stock bool Client_IsValid(int client, bool checkConnected=true)
{
	if (client > 4096) 
	{
		client = EntRefToEntIndex(client);
	}

	if (client < 1 || client > MaxClients) 
	{
		return false;
	}

	if (checkConnected && !IsClientConnected(client)) 
	{
		return false;
	}
	
	return true;
}

/***********************************************************/
/******************** IS CLIENT IN GAME ********************/
/***********************************************************/
stock bool Client_IsIngame(int client)
{
	if (!Client_IsValid(client, false)) 
	{
		return false;
	}

	return IsClientInGame(client);
} 