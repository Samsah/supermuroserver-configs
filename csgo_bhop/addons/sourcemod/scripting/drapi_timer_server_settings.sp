/*         <DR.API TIMER SERVER SETTINGS> (c) by <De Battista Clint          */
/*                                                                           */
/*              <DR.API TIMER SERVER SETTINGS> is licensed under             */
/*                        GNU General Public License                         */
/*																			 */
/*      You should have received a copy of the license along with this       */
/*            work.  If not, see <http://www.gnu.org/licenses/>.             */
//***************************************************************************//
//***************************************************************************//
//***********************DR.API TIMER SERVER SETTINGS************************//
//***************************************************************************//
//***************************************************************************//

#pragma semicolon 1 

//***********************************//
//*************DEFINE****************//
//***********************************//
#define CVARS 							FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY
#define DEFAULT_FLAGS 					FCVAR_PLUGIN|FCVAR_NOTIFY
#define TAG_CHAT						"[TIMER SERVER SETTINGS] -"

//***********************************//
//*************INCLUDE***************//
//***********************************//

#undef REQUIRE_PLUGIN
#include <sourcemod>
#include <autoexec>
#include <timer>
#include <timer-config_loader>

#pragma newdecls required

//***********************************//
//***********PARAMETERS**************//
//***********************************//

//Handle
Handle cvar_active_base_dev;

//Bool
bool B_active_base_dev					= false;

//Informations plugin
public Plugin myinfo =
{
	name = "[TIMER] DR.API TIMER SERVER SETTINGS",
	author = "Dr. Api",
	description = "DR.API TIMER SERVER SETTINGS by Dr. Api",
	version = PL_VERSION,
	url = "http://zombie4ever.eu"
}
/***********************************************************/
/*********************** PLUGIN START **********************/
/***********************************************************/
public void OnPluginStart()
{
	LoadPhysics();
	LoadTimerSettings();
	
	AutoExecConfig_SetFile("drapi_base", "sourcemod/drapi");
	
	AutoExecConfig_CreateConVar("drapi_base_version", PL_VERSION, "Version", CVARS);
	
	cvar_active_base_dev			= AutoExecConfig_CreateConVar("drapi_active_base_dev", 			"0", 					"Enable/Disable Dev Mod", 				DEFAULT_FLAGS, 		true, 0.0, 		true, 1.0);
	
	HookEventsCvars();
	
	HookEvent("server_cvar", 	Event_Cvar, 			EventHookMode_Pre);
	
	AutoExecConfig_ExecuteFile();
}

/***********************************************************/
/******************** WHEN CVAR CHANGED ********************/
/***********************************************************/
void HookEventsCvars()
{
	HookConVarChange(cvar_active_base_dev, 				Event_CvarChange);
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
	B_active_base_dev 					= GetConVarBool(cvar_active_base_dev);
}

/***********************************************************/
/******************** WHEN CVARS CHANGE ********************/
/***********************************************************/
public Action Event_Cvar(Handle event, const char[] name, bool dontBroadcast)
{
	char S_ConvarName[64];
	GetEventString(event, "cvarname", S_ConvarName, sizeof(S_ConvarName));
	
	char S_ConvarValue[64];
	GetEventString(event, "cvarvalue", S_ConvarValue, sizeof(S_ConvarValue));
	
	SetEventBroadcast(event, true);
	
	CPrintToChatAll("[{GREEN}TIMER{NORMAL}] {BLUE}%s{NORMAL}: {RED}%s{NORMAL}", S_ConvarName, S_ConvarValue);
	return Plugin_Continue;
}

/***********************************************************/
/********************* WHEN MAP START **********************/
/***********************************************************/
public void OnMapStart()
{
	UpdateState();
	
	LoadPhysics();
	LoadTimerSettings();
	
	if(g_Settings[EnableCvars])
	{
		ServerCommand("mp_autokick %i", g_Settings[mp_autokick]);
		ServerCommand("mp_autoteambalance %i", g_Settings[mp_autoteambalance]);
		ServerCommand("mp_endmatch_votenextleveltime %i", g_Settings[mp_endmatch_votenextleveltime]);
		ServerCommand("mp_endmatch_votenextmap %i", g_Settings[mp_endmatch_votenextmap]);
		ServerCommand("sm_cvar mp_falldamage %i", g_Settings[mp_autokick]);
		ServerCommand("mp_freezetime %i", g_Settings[mp_freezetime]);
		ServerCommand("mp_join_grace_time %i", g_Settings[mp_join_grace_time]);
		ServerCommand("mp_limitteams %i", g_Settings[mp_limitteams]);
		ServerCommand("mp_match_can_clinch %i", g_Settings[mp_match_can_clinch]);
		ServerCommand("mp_match_end_changelevel %i", g_Settings[mp_match_end_changelevel]);
		ServerCommand("mp_match_end_restart %i", g_Settings[mp_match_end_restart]);
		ServerCommand("mp_match_restart_delay %i", g_Settings[mp_match_restart_delay]);
		ServerCommand("mp_maxrounds %i", g_Settings[mp_maxrounds]);
		ServerCommand("mp_playercashawards %i", g_Settings[mp_playercashawards]);
		ServerCommand("mp_teamcashawards %i", g_Settings[mp_teamcashawards]);
		ServerCommand("mp_timelimit %i", g_Settings[mp_timelimit]);
		ServerCommand("sm_cvar mp_warmuptime %i", g_Settings[mp_warmuptime]);
		
		ServerCommand("sm_cvar phys_pushscale %i", g_Settings[phys_pushscale]);
		
		ServerCommand("sm_cvar sv_accelerate %f", g_Settings[sv_accelerate]);
		ServerCommand("sm_cvar sv_airaccelerate %i", g_Settings[sv_airaccelerate]);
		ServerCommand("sv_gravity %i", g_Settings[sv_gravity]);
		ServerCommand("sm_cvar sv_maxvelocity %i", g_Settings[sv_maxvelocity]);
		ServerCommand("sm_cvar sv_pushaway_force %i", g_Settings[sv_pushaway_force]);
		ServerCommand("sm_cvar sv_pushaway_max_force %i", g_Settings[sv_pushaway_max_force]);
		ServerCommand("sm_cvar sv_pushaway_min_player_speed %i", g_Settings[sv_pushaway_min_player_speed]);
		ServerCommand("sv_staminajumpcost %i", g_Settings[sv_staminajumpcost]);
		ServerCommand("sv_staminalandcost %i", g_Settings[sv_staminalandcost]);
		ServerCommand("sv_staminamax %i", g_Settings[sv_staminamax]);
		ServerCommand("sm_cvar sv_turbophysics %i", g_Settings[sv_turbophysics]);
		ServerCommand("sm_cvar sv_wateraccelerate %i", g_Settings[sv_wateraccelerate]);
	
	
	
		if(g_Settings[mp_death_drop_gun]) 
		{
			ServerCommand("mp_death_drop_gun 1");
		}
		else 
		{
			ServerCommand("mp_death_drop_gun 0");
		}

		if(g_Settings[mp_do_warmup_period]) 
		{
			ServerCommand("mp_do_warmup_period 0");
		}

		if(g_Settings[mp_ignore_round_win_conditions]) 
		{
			ServerCommand("mp_ignore_round_win_conditions 1");
		}
		else 
		{
			ServerCommand("mp_ignore_round_win_conditions 0");
		}
		
		if(g_Settings[sv_enablebunnyhopping]) 
		{
			ServerCommand("sm_cvar sv_enablebunnyhopping 1");
		}
		else 
		{
			ServerCommand("sm_cvar sv_enablebunnyhopping 0");
		}
	}
	
	if(strlen(g_Settings[TeamNameT]) > 0) 
	{
		ServerCommand("sm_teamname_t %s", g_Settings[TeamNameT]);
	}
	if(strlen(g_Settings[TeamNameCT]) > 0) 
	{
		ServerCommand("sm_teamname_ct %s", g_Settings[TeamNameCT]);
	}
}