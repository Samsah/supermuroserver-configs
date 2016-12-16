#include <sourcemod>
#include <sdktools>

new const String:SNOW_MODEL[] = "particle/snow.vmt";
new g_SnowEntity[MAXPLAYERS+1] = {-1,...};

public Plugin:myinfo = 
{
    name = "Winter Wonderland (sm_snow)",
    author = "BlueRaja",
    description = "Make it snow!!",
    version = "1.0",
    url = "www.blueraja.com/blog"

}

public OnPluginStart()
{
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
}

public OnMapStart()
{
    PrecacheModel(SNOW_MODEL);
}

public OnMapEnd()
{
    for(new i=0; i<MaxClients; i++)
    {
        KillSnow(i);
    }
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new userid = GetEventInt(event, "userid");
    new client = GetClientOfUserId(userid);
    
    KillSnow(client);
    CreateTimer(1.0, TimerCallback_CreateSnow, client);

}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new userid = GetEventInt(event, "userid");
    new client = GetClientOfUserId(userid);
    
    KillSnow(client);
}

public Action:TimerCallback_CreateSnow(Handle:timerInstance, any:client)
{
    if(IsClientInGame(client) && IsPlayerAlive(client))
	    CreateSnow(client);
}

CreateSnow(client)
{
    new Float:eyePosition[3];
    GetClientEyePosition(client, eyePosition);
    
    g_SnowEntity[client] = CreateEntityByName("env_smokestack");
    if(g_SnowEntity[client] != -1)
    {
        DispatchKeyValueVector(g_SnowEntity[client],"Origin", eyePosition);
        DispatchKeyValueFloat(g_SnowEntity[client],"BaseSpread", 800.0);
        DispatchKeyValue(g_SnowEntity[client],"SpreadSpeed", "200");
        DispatchKeyValue(g_SnowEntity[client],"Speed", "25");
        DispatchKeyValueFloat(g_SnowEntity[client],"StartSize", 1.0);
        DispatchKeyValueFloat(g_SnowEntity[client],"EndSize", 1.0);
        DispatchKeyValue(g_SnowEntity[client],"Rate", "125");
        DispatchKeyValue(g_SnowEntity[client],"JetLength", "400");
        DispatchKeyValueFloat(g_SnowEntity[client],"Twist", 1.0);
        DispatchKeyValue(g_SnowEntity[client],"RenderColor", "255 255 255");
        DispatchKeyValue(g_SnowEntity[client],"RenderAmt", "400");
        DispatchKeyValue(g_SnowEntity[client],"RenderMode", "18");
        DispatchKeyValue(g_SnowEntity[client],"SmokeMaterial", "particle/snow");
        DispatchKeyValue(g_SnowEntity[client],"Angles", "180 0 0");
        
        DispatchSpawn(g_SnowEntity[client]);
        ActivateEntity(g_SnowEntity[client]);
        
        eyePosition[2] += 50;
        TeleportEntity(g_SnowEntity[client], eyePosition, NULL_VECTOR, NULL_VECTOR);
        
        SetVariantString("!activator");
        AcceptEntityInput(g_SnowEntity[client], "SetParent", client);
        
        AcceptEntityInput(g_SnowEntity[client], "TurnOn");
    }
}

KillSnow(client)
{
    if(IsValidEntity(g_SnowEntity[client]))
    {
        AcceptEntityInput(g_SnowEntity[client], "Kill");
        g_SnowEntity[client] = -1;
    }
}