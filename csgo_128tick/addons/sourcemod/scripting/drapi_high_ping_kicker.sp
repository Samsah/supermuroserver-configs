/*<DR.API HIGH PING KICKER> (c) by <De Battista Clint - (http://doyou.watch) */
/*                                                                           */
/*               <DR.API HIGH PING KICKER> is licensed under a               */
/* Creative Commons Attribution-NonCommercial-NoDerivs 4.0 Unported License. */
/*																			 */
/*      You should have received a copy of the license along with this       */
/*  work.  If not, see <http://creativecommons.org/licenses/by-nc-nd/4.0/>.  */
//***************************************************************************//
//***************************************************************************//
//*************************DR.API HIGH PING KICKER***************************//
//***************************************************************************//
//***************************************************************************//

#pragma semicolon 1 

//***********************************//
//*************DEFINE****************//
//***********************************//
#define TAG_HIGH_PING_KICKER_CSGO 				"[HIGH PING KICKER] - "
#define PLUGIN_VERSION_HIGH_PING_KICKER_CSGO	"1.0.1"
#define CVARS 									FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY
#define DEFAULT_FLAGS 							FCVAR_PLUGIN|FCVAR_NOTIFY
#define UMIN(%1,%2) (%1 < %2 ? %2 : %1)
#define CHECK_ADMIN_IMMUNITY(%1) 				(C_admin_flag == 0 ? GetUserFlagBits(%1)!=0 : (GetUserFlagBits(%1) & C_admin_flag || GetUserFlagBits(%1) & ADMFLAG_ROOT))

//***********************************//
//*************INCLUDE***************//
//***********************************//

#undef REQUIRE_PLUGIN
#include <sourcemod>
#include <autoexec>
#include <csgocolors>

#pragma newdecls required

//***********************************//
//***********PARAMETERS**************//
//***********************************//

//Handle
Handle cvar_active_high_ping_kicker_csgo;
Handle cvar_active_high_ping_kicker_csgo_dev;

Handle cvar_active_high_ping_kicker_max_ping_csgo;
Handle cvar_active_high_ping_kicker_max_checks_csgo;
Handle cvar_active_high_ping_kicker_start_check_csgo;
Handle cvar_active_high_ping_kicker_admin_immune_csgo;
Handle cvar_active_high_ping_kicker_immune_flag_csgo;

//Bool
bool B_active_high_ping_kicker_csgo 					= false;
bool B_active_high_ping_kicker_csgo_dev					= false;
bool B_active_high_ping_kicker_admin_immune_csgo		= false;

//Float
float F_active_high_ping_kicker_start_check_csgo		= 0.0;

//Customs
int C_active_high_ping_kicker_max_ping_csgo;
int C_active_high_ping_kicker_max_checks_csgo;

int C_client_failed[MAXPLAYERS+1];
int C_client_ping[MAXPLAYERS+1];
int C_admin_flag;

//Informations plugin
public Plugin myinfo =
{
	name = "DR.API HIGH PING KICKER",
	author = "Dr. Api",
	description = "DR.API HIGH PING KICKER by Dr. Api",
	version = PLUGIN_VERSION_HIGH_PING_KICKER_CSGO,
	url = "http://doyou.watch"
}
/***********************************************************/
/*********************** PLUGIN START **********************/
/***********************************************************/
public void OnPluginStart()
{
	AutoExecConfig_SetFile("drapi_high_ping_kicker", "sourcemod/drapi");
	LoadTranslations("drapi/drapi_high_ping_kicker.phrases");
	
	AutoExecConfig_CreateConVar("drapi_high_ping_kicker_version", PLUGIN_VERSION_HIGH_PING_KICKER_CSGO, "Version", CVARS);
	
	cvar_active_high_ping_kicker_csgo 					= AutoExecConfig_CreateConVar("drapi_active_high_ping_kicker",  				"1", 					"Enable/Disable Sounds Kill", 			DEFAULT_FLAGS, 		true, 0.0, 		true, 1.0);
	cvar_active_high_ping_kicker_csgo_dev				= AutoExecConfig_CreateConVar("drapi_active_high_ping_kicker_dev", 				"0", 					"Enable/Disable Sounds Kill Dev Mod", 	DEFAULT_FLAGS, 		true, 0.0, 		true, 1.0);
	
	cvar_active_high_ping_kicker_max_ping_csgo			= AutoExecConfig_CreateConVar("drapi_high_ping_kicker_max_ping", 				"250", 					"Max ping allowed", 					DEFAULT_FLAGS);
	cvar_active_high_ping_kicker_max_checks_csgo		= AutoExecConfig_CreateConVar("drapi_high_ping_kicker_max_checks", 				"10", 					"Number of max checks after kick", 		DEFAULT_FLAGS);
	cvar_active_high_ping_kicker_start_check_csgo		= AutoExecConfig_CreateConVar("drapi_high_ping_kicker_start_check", 			"15.0", 				"Time after timer start", 				DEFAULT_FLAGS);
	cvar_active_high_ping_kicker_admin_immune_csgo		= AutoExecConfig_CreateConVar("drapi_high_ping_kicker_admin_immune", 			"1", 					"Enable/Disable Admin immunity", 		DEFAULT_FLAGS);
	cvar_active_high_ping_kicker_immune_flag_csgo		= AutoExecConfig_CreateConVar("drapi_high_ping_kicker_immune_flag", 			"", 					"Admin flag for immunity, blank=any flag", 								DEFAULT_FLAGS);
	
	SetImmuneFlagCsgo(cvar_active_high_ping_kicker_immune_flag_csgo);
	
	HookEvents();
	
	AutoExecConfig_ExecuteFile();
	
}

/***********************************************************/
/******************** WHEN CVAR CHANGED ********************/
/***********************************************************/
void HookEvents()
{
	HookConVarChange(cvar_active_high_ping_kicker_csgo, 				Event_CvarChange);
	HookConVarChange(cvar_active_high_ping_kicker_csgo_dev, 			Event_CvarChange);
	
	HookConVarChange(cvar_active_high_ping_kicker_max_ping_csgo, 		Event_CvarChange);
	HookConVarChange(cvar_active_high_ping_kicker_max_checks_csgo, 		Event_CvarChange);
	HookConVarChange(cvar_active_high_ping_kicker_start_check_csgo, 	Event_CvarChange);
	HookConVarChange(cvar_active_high_ping_kicker_admin_immune_csgo, 	Event_CvarChange);
	HookConVarChange(cvar_active_high_ping_kicker_immune_flag_csgo, 	Event_CvarChange);
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
	B_active_high_ping_kicker_csgo 					= GetConVarBool(cvar_active_high_ping_kicker_csgo);
	B_active_high_ping_kicker_csgo_dev 				= GetConVarBool(cvar_active_high_ping_kicker_csgo_dev);
	B_active_high_ping_kicker_admin_immune_csgo 	= GetConVarBool(cvar_active_high_ping_kicker_admin_immune_csgo);
	
	C_active_high_ping_kicker_max_ping_csgo 		= GetConVarInt(cvar_active_high_ping_kicker_max_ping_csgo);
	C_active_high_ping_kicker_max_checks_csgo		= GetConVarInt(cvar_active_high_ping_kicker_max_checks_csgo);
	
	F_active_high_ping_kicker_start_check_csgo		= GetConVarFloat(cvar_active_high_ping_kicker_start_check_csgo);
	
	SetImmuneFlagCsgo(cvar_active_high_ping_kicker_immune_flag_csgo);
	
	if(B_active_high_ping_kicker_csgo)
	{
		CreateTimer(F_active_high_ping_kicker_start_check_csgo, Timer_CheckPingPlayerCsgo, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		
		for(int i = 1; i <= MaxClients; i++)
		{
			C_client_failed[i] 		= 0;
			C_client_ping[i] 		= 0;
		}
		
		//PrintToChatAll("%sTimer Started", TAG_HIGH_PING_KICKER_CSGO);
	}
}

/***********************************************************/
/******************* WHEN CONFIG EXECUTED ******************/
/***********************************************************/
public void OnConfigsExecuted()
{
	//UpdateState();
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
	if(B_active_high_ping_kicker_csgo)
	{
		C_client_failed[client] 		= 0;
		C_client_ping[client] 			= 0;
	}
}

/***********************************************************/
/******************** TIMER CHECK PING *********************/
/***********************************************************/
public Action Timer_CheckPingPlayerCsgo(Handle Timer)
{
	if(B_active_high_ping_kicker_csgo)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i) && !(B_active_high_ping_kicker_admin_immune_csgo == true && CHECK_ADMIN_IMMUNITY(i)))
			{
				UpdatePingStatus(i);
			}
		}
		KickHighPingers();
	}
	return Plugin_Continue;
}

/***********************************************************/
/******************* UPDATE STATUS PING ********************/
/***********************************************************/
void UpdatePingStatus(int client)
{
	char S_rate[32];
	GetClientInfo(client, "cl_cmdrate", S_rate, sizeof(S_rate));
	
	float F_ping = GetClientAvgLatency(client, NetFlow_Outgoing);
	float F_tick_rate = GetTickInterval();
	int C_cmd_rate = UMIN(StringToInt(S_rate), 20);

	F_ping -= ((0.5 / C_cmd_rate) + (F_tick_rate * 1.0));
	F_ping -= (F_tick_rate * 0.5);
	F_ping *= 1000.0;
	
	C_client_ping[client] = RoundToZero(F_ping);
	
	if(C_client_ping[client] > C_active_high_ping_kicker_max_ping_csgo)
	{
		C_client_failed[client]++;
		if(B_active_high_ping_kicker_csgo_dev)
		{
			PrintToChatAll("%sYour ping: %i, check: %i", TAG_HIGH_PING_KICKER_CSGO, C_client_ping[client], C_client_failed[client]);
		}
	}
	else
	{
		if(C_client_failed[client] > 0)
		{
			C_client_failed[client]--;
			if(B_active_high_ping_kicker_csgo_dev)
			{
				PrintToChatAll("%sCheck: %i", TAG_HIGH_PING_KICKER_CSGO, C_client_failed[client]);
			}
		}
	}
}

/***********************************************************/
/***************** KICK PLAYER HIGH PING *******************/
/***********************************************************/
void KickHighPingers()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
		{
			if(C_client_failed[i] >= C_active_high_ping_kicker_max_checks_csgo)
			{
				char S_client_name[MAX_NAME_LENGTH];
				GetClientName(i, S_client_name, MAX_NAME_LENGTH);
				
				if(!B_active_high_ping_kicker_csgo_dev)
				{
					KickClient(i, "%t", "High Ping Kicker Kick me", C_client_ping[i], C_active_high_ping_kicker_max_ping_csgo);
				}
				
				CPrintToChatAll("%t", "High Ping Kicker Kick", S_client_name, C_client_ping[i], C_active_high_ping_kicker_max_ping_csgo);
			}
		}
	}
}


/***********************************************************/
/********************** SET IMMUNE FLAG ********************/
/***********************************************************/
void SetImmuneFlagCsgo(Handle cvar=INVALID_HANDLE)
{
	char S_flags[4];
	AdminFlag C_flag;
	GetConVarString(cvar, S_flags, sizeof(S_flags));
	if (S_flags[0]!='\0' && FindFlagByChar(S_flags[0], C_flag))
	{
		 C_admin_flag = FlagToBit(C_flag);
	}
	else 
	{
		C_admin_flag = 0;
	}
}