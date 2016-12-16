#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <updater>

#define	UPDATE_URL	"http://dl.dropboxusercontent.com/u/101047078/sm_winordie/sm_winordie.txt"
#define PLUGIN_VERSION "1.2.5"
//Updates With 1.2.4: Added free passes

//CVARS
new Handle:sm_WoD_version	= INVALID_HANDLE;
new Handle:sm_WoD_Enabled	= INVALID_HANDLE;
new Handle:sm_WoD_Admin_Immunity	= INVALID_HANDLE;
new Handle:sm_WoD_C4_Delay	= INVALID_HANDLE;
new Handle:sm_WoD_FreePasses	= INVALID_HANDLE;

//Global vars
new bool:g_bSlayInProgress = false;
new bool:g_bRoundStarted = false;
new g_iFreePassesLeft[MAXPLAYERS+1];

//Info
public Plugin:myinfo =
{
	name = "Win or Die!",
	author = "sinsic",
	description = "Finish your mission or die!",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
};

public OnPluginStart()
{
	if (LibraryExists("updater")) 
	{
		Updater_AddPlugin(UPDATE_URL);
    }
	LoadTranslations("sm_winordie.phrases");
	
	//Convars
	sm_WoD_version = CreateConVar("sm_WoD_version", PLUGIN_VERSION, "Win or Die! version.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	sm_WoD_Enabled = CreateConVar("sm_WoD_Enabled", "1", "If plugin is enabled (0: Disable | 1: Enable)");
	sm_WoD_Admin_Immunity = CreateConVar("sm_WoD_Admin_Immunity", "0", "If admins get slayed or not (0: Slayed | 1: Not Slayed)");
	sm_WoD_C4_Delay = CreateConVar("sm_WoD_C4_Delay", "0", "Delay slay if the c4 exploded (0: Don't delay | 1: Delay)");
	sm_WoD_FreePasses	= CreateConVar("sm_WoD_FreePasses", "0", "How many free passes a person get before getting slayed");

	//Create  cfg file if one does not exist and execute it
	AutoExecConfig(true, "sm_WinOrDie");

	//Keep track if somebody changed the plugin_version
	SetConVarString(sm_WoD_version, PLUGIN_VERSION);
	HookConVarChange(sm_WoD_version, WoD_versionchange);
	
	//Hooks for c4 bug when bomb explodes 0.1s before new round when slay delay is active
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("round_start", Event_RoundStart);
}

public OnLibraryAdded(const String:name[])
{
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}

//If somebody changed the plugin version set it back to right one, otherwise they might not realize updates
public WoD_versionchange(Handle:convar, const String:oldValue[], const String:newValue[])
	{
	SetConVarString(convar, PLUGIN_VERSION);
}

public OnMapStart(){
	for(new i = 1; i <= MaxClients; ++i)
	{
		g_iFreePassesLeft[i] = GetConVarInt(sm_WoD_FreePasses);
	}
}

public OnClientConnected(client)
{
	g_iFreePassesLeft[client] = GetConVarInt(sm_WoD_FreePasses);
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	//These are to keep track if a delayed slay extended to new round which happens when c4 explodes 0.1s before the new round.
	if (g_bSlayInProgress)
	{
		g_bRoundStarted = true;
	}
}


public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarInt(sm_WoD_Enabled) == 1)
	{
		//On round end if WoD is enabled, get who is the winner and why the round ended
		//Depending on the reason set a slay message
		new String:sMessage[256] = "";
		new iWinner = GetEventInt(event, "winner");
		new bool:bC4Exploded = false;
		switch (GetEventInt(event, "reason"))
		{
			case 0:
			{
				sMessage = "Defuse the bomb";
				//if c4 is exploded we might need to add a slay delay
				bC4Exploded = true;
			}
			case 1:
			{
				sMessage = "Kill the VIP";
			}
			case 2:
			{
				sMessage = "Protect the VIP";
			}
			case 3:
			{
				sMessage = "Kill terrorists";
			}
			case 6:
			{
				sMessage = "Protect C4";
			}
			case 10:
			{
				sMessage = "Dont let hostages escape";
			}
			case 11:
			{
				sMessage = "Plant the bomb";
			}
			case 12:
			{
				sMessage = "Rescue the hostages";
			}
			case 14:
			{
				sMessage = "VIP should escape";
			}
			default:
			{
				//Round didn't end because of a mission related reason, so as far as this plugin is concerned nobody won
				iWinner = 1;
			}
		}
		
		//If round ended because of mission related reason other then c4 explosion or c4 exploded and c4 delay is not on, kill losers without delay
		if ((iWinner != 1) &&  !((bC4Exploded) && (GetConVarInt(sm_WoD_C4_Delay) == 1))) 
		{
			for(new i = 1; i <= MaxClients; ++i)
			{
				if(IsClientInGame(i))
				{
					//If client is not on the winning team and not immune kill the client
					if ((GetClientTeam(i) != iWinner) && IsPlayerAlive(i) && NotImmune(i))
						{
							if (g_iFreePassesLeft[i] < 1)
							{
								PrintToChat(i, "\x03[SM] \x01  %t", sMessage);
								ForcePlayerSuicide(i);
								g_iFreePassesLeft[i] = GetConVarInt(sm_WoD_FreePasses);
							} else
							{
								g_iFreePassesLeft[i] -= 1;
								PrintToChat(i, "\x03[SM] \x01  %t; %d", "Free Passes Left", g_iFreePassesLeft[i]);
							}
						}
				}
			}
			//Reset the round checking
			g_bSlayInProgress = false;
			g_bRoundStarted = false;
		}
		
		//If round ended because of c4 explosion and c4 delay is on kill losers with delay
		if (bC4Exploded && (GetConVarInt(sm_WoD_C4_Delay) == 1))
		{
			g_bSlayInProgress = true;
			CreateTimer(0.1, DelayedSlay);
		}
		
	}
}

public Action:DelayedSlay(Handle:timer)
	{
		for(new i = 1; i <= MaxClients; ++i)
		{
			if(IsClientInGame(i))
			{
				//Since this code only runs when C4 exploded, check if the client is CT and if not immune and kill the client
				if ((GetClientTeam(i) == 3) && IsPlayerAlive(i) && NotImmune(i))
				{
					if (g_iFreePassesLeft[i] < 1)
					{
						PrintToChat(i, "\x03[SM] \x01  %t", "Defuse the bomb");
						//If new round started stop killing loser team otherwise if bomb explodes 0.1 seconds before new round losers get slayed in new round
						if (g_bRoundStarted) break;
						ForcePlayerSuicide(i);
						g_iFreePassesLeft[i] = GetConVarInt(sm_WoD_FreePasses); 
					} else
					{
						g_iFreePassesLeft[i] -= 1;
						PrintToChat(i, "\x03[SM] \x01  %t; %d", "Free Passes Left", g_iFreePassesLeft[i]);
					}
				}
			}
		}
		//Reset the round checking
		g_bSlayInProgress = false;
		g_bRoundStarted = false;
}

bool:NotImmune(any:client)
{
	//If user has an admin flag and immunity is on this will return false.
    if ((GetUserAdmin(client) == INVALID_ADMIN_ID) || (GetConVarInt(sm_WoD_Admin_Immunity) == 0))
    {
        return true;
    } else
	{
    return false;
	}
}