#include <sourcemod>
#include <multicolors>
#define PLUGIN_VERSION "1.1"
 
new Handle:gH_CvarMin = INVALID_HANDLE;
new Handle:gH_CvarMax = INVALID_HANDLE;
new Handle:gH_CvarShowRoll = INVALID_HANDLE;
new Handle:gH_CvarPlayerAlive = INVALID_HANDLE;
new Handle:gA_TopRollPlayers = INVALID_HANDLE;
new Handle:gA_PlayerRolled = INVALID_HANDLE;
new bool:g_bStartRoll;
new g_iBestRoll;
 
public Plugin:myinfo =
{
    name = "Roll Giveaway",
    author = "sim242",
    description = "Enables admins to initiate dice rolls for giveaways or other events.",
    version = PLUGIN_VERSION,
    url = "httpe://www.last-resistance.co.uk/"
}
 
public OnPluginStart()
{
    CreateConVar("roll_giveaway_version", PLUGIN_VERSION, "Roll Giveaway plugin version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    gH_CvarMin = CreateConVar("roll_min", "1", "The minimum number a player can roll.");
    gH_CvarMax = CreateConVar("roll_max", "100", "The maximum number a player can roll.");
    gH_CvarShowRoll = CreateConVar("roll_show", "0", "Should players rolls be shown to everyone? 0 = Shown to client | 1 = Shown to everyone");
    gH_CvarPlayerAlive = CreateConVar("roll_playeralive", "0", "Should only alive players be able to roll a dice? 0 = Everyone | 1 = Only alive"); 
 
    gA_TopRollPlayers = CreateArray();
    gA_PlayerRolled = CreateArray();
 
    RegConsoleCmd("sm_rolldice", command_roll, "Roll to generate a number.");
    RegAdminCmd("sm_startroll", command_startroll, ADMFLAG_ROOT, "Starts a roll giveaway.");
    RegAdminCmd("sm_stoproll", command_stoproll, ADMFLAG_ROOT, "Stops a roll giveaway.");
   
    AutoExecConfig(true, "roll_giveaway");
    LoadTranslations("Roll_Giveaway.phrases");
}

public Action:command_roll(client, args)
{
    new iMin = GetConVarInt(gH_CvarMin);
    new iMax = GetConVarInt(gH_CvarMax);
    new bool:bShowRoll = GetConVarBool(gH_CvarShowRoll);
    new bool:bPlayerAlive = GetConVarBool(gH_CvarPlayerAlive);
    
    if(bPlayerAlive)
    {
        if(IsPlayerAlive(client))
        {
            if(g_bStartRoll)
            {
                if(FindValueInArray(gA_PlayerRolled, client) == -1)
                {
                    PushArrayCell(gA_PlayerRolled, client);
                    
                    new IntStore = GetRandomInt(iMin, iMax);
                    if(IntStore > g_iBestRoll)
                    {
                        ClearArray(gA_TopRollPlayers);
                        PushArrayCell(gA_TopRollPlayers, client);
                        g_iBestRoll = IntStore;
                    }
                    else if(IntStore == g_iBestRoll)
                        PushArrayCell(gA_TopRollPlayers, client);
   
                    if(bShowRoll)
                        CPrintToChatAll("%t", "RollResponseAll", client, IntStore);
                    else
                        CReplyToCommand(client, "%t", "RollResponseClient", IntStore);
       
                    return Plugin_Handled;
                }
                else
                {
                    CReplyToCommand(client, "%t", "Rolled");
                    return Plugin_Handled;
                }
            }
        }
        else
        {
            CReplyToCommand(client, "%t", "NotAlive"); 
            return Plugin_Handled;
        }   
    }
    else if(g_bStartRoll)
    {
        if(FindValueInArray(gA_PlayerRolled, client) == -1)
        {
            PushArrayCell(gA_PlayerRolled, client);
        
            new IntStore = GetRandomInt(iMin, iMax);
            if(IntStore > g_iBestRoll)
            {
                ClearArray(gA_TopRollPlayers);
                PushArrayCell(gA_TopRollPlayers, client);
                g_iBestRoll = IntStore;
            }
            else if(IntStore == g_iBestRoll)
                PushArrayCell(gA_TopRollPlayers, client);
   
            if(bShowRoll)
                CPrintToChatAll("%t", "RollResponseAll", client, IntStore);
            else
                CReplyToCommand(client, "%t", "RollResponseClient", IntStore);
       
            return Plugin_Handled;
        }
        else
        {
            CReplyToCommand(client, "%t", "Rolled");
            return Plugin_Handled;
        }
    }
   
    CReplyToCommand(client, "%t", "AdminStart");
    return Plugin_Handled;
}
 
public Action:command_startroll(client, args)
{
    g_iBestRoll = 0;
    g_bStartRoll = true;
    CPrintToChatAll("%t", "StartGiveaway");
    return Plugin_Handled;
}
 
public OnClientDisconnect(client)
{
    new iArrayIndex = FindValueInArray(gA_TopRollPlayers, client);
    if(iArrayIndex != -1)
        RemoveFromArray(gA_TopRollPlayers, iArrayIndex);
}
 
public Action:command_stoproll(client, args)
{
    g_bStartRoll = false;
   
    new iArraySize = GetArraySize(gA_TopRollPlayers);
    if(iArraySize == 1)
        CPrintToChatAll("%t", "StopGiveaway", GetArrayCell(gA_TopRollPlayers, 0), g_iBestRoll);
    else
    {
        CPrintToChatAll("%t", "StopGiveaway", GetArrayCell(gA_TopRollPlayers, GetRandomInt(0, iArraySize-1)), g_iBestRoll);
    }
 
    ClearArray(gA_TopRollPlayers);
    ClearArray(gA_PlayerRolled);
    return Plugin_Handled;
}