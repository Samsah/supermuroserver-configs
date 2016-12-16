#include <sourcemod>
#include <sdktools>
public OnPluginStart()
{
    // Hook the player_spawn event
    HookEvent("player_spawn", Event_PlayerSpawn);
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    //Get the client of the event
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
     // Check if the client is in game, alive and that the client has the Custom1 flag (o)
    if (IsClientInGame(client) && IsPlayerAlive(client) && GetAdminFlag(GetUserAdmin(client), Admin_Custom1))
    {
        // Give the items...
        GivePlayerItem(client, "weapon_hegrenade");
        GivePlayerItem(client, "weapon_flashbang");
        GivePlayerItem(client, "weapon_smokegrenade");
    }

    return Plugin_Continue;
} 
