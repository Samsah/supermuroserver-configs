#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

float g_TagChangedTime[MAXPLAYERS+1];

public void OnClientConnected(int client)
{
    g_TagChangedTime[client] = 0.0;
}

public Action OnClientCommandKeyValues(int client, KeyValues kv)
{
    char sCmd[64];
    
    if (kv.GetSectionName(sCmd, sizeof(sCmd)) && StrEqual(sCmd, "ClanTagChanged", false))
    {
        if (g_TagChangedTime[client] && GetGameTime() - g_TagChangedTime[client] <= 60.0)
            return Plugin_Handled;
        
        g_TagChangedTime[client] = GetGameTime();
    }
    
    return Plugin_Continue;
}  