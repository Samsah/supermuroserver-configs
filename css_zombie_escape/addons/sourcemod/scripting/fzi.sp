#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <zombiereloaded>

#define DATA "v1.0"

new siguiente = 0;
new Handle:g_CVarAdmFlag;
new Handle:cvar_chance;
new g_AdmFlag;
new i_chance;

public Plugin:myinfo =
{
	name = "ZR First Zombie Inmunity",
	author = "Franc1sco Steam: franug",
	description = "I hate to be the first zombie :p",
	version = DATA,
	url = "www.servers-cfg.foroactivo.com"
};

public OnPluginStart()
{
	HookEvent("round_start", InicioRonda);
	
	g_CVarAdmFlag = CreateConVar("zr_firstzombieinmunity_adminflag", "z", "Admin flag for get inmunity to be the first zombie. Can use a b c ....");
	cvar_chance = CreateConVar("zr_firstzombieinmunity_chance", "80", "Probability to get inmunity when you has been selected to be the first zombie");
	g_AdmFlag = ReadFlagString("z");
	i_chance = 80;
	CreateConVar("zr_firstzombieinmunity", DATA, "version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY);
	HookConVarChange(g_CVarAdmFlag, CVarChange);
	HookConVarChange(cvar_chance, CVarChange2);
}

public CVarChange(Handle:convar, const String:oldValue[], const String:newValue[]) {

	g_AdmFlag = ReadFlagString(newValue);
}

public CVarChange2(Handle:convar, const String:oldValue[], const String:newValue[]) {

	i_chance = StringToInt(newValue);
}

public Action:InicioRonda(Handle:event, const String:name[], bool:dontBroadcast)
{
	siguiente = 0;
}

public Action:ZR_OnClientInfect(&client, &attacker, &bool:motherInfect, &bool:respawnOverride, &bool:respawn)
{
	if(motherInfect && CheckCommandAccess(client, "sm_firstzombieinmunity_override", g_AdmFlag, true) && GetRandomInt(0, 100) <= i_chance)
	{
		++siguiente;
		new Handle:pack;
		CreateDataTimer(siguiente * 0.1, Pasado, pack);
		WritePackCell(pack, client);
		WritePackCell(pack, respawnOverride);
		WritePackCell(pack, respawn);
		
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:Pasado(Handle:timer, Handle:pack)
{
	new client;
	new respawnOverride;
	new respawn;
	
	ResetPack(pack);
	client = ReadPackCell(pack);
	respawnOverride = ReadPackCell(pack);
	respawn = ReadPackCell(pack);
	if(!IsClientInGame(client)) return;
	new aleatorio = ObtenerClienteAleatorio(client);
	if(aleatorio) 
	{
		ZR_InfectClient(aleatorio, -1, true, bool:respawnOverride, bool:respawn);
		PrintToChat(client, "[FZI] you are saved from being the first zombie and %N has been infected in your place", aleatorio);
	}
}

stock ObtenerClienteAleatorio(client)
{
	new clients[MaxClients+1], clientCount;
	for (new i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && IsPlayerAlive(i) && ZR_IsClientHuman(i) && i != client && !CheckCommandAccess(i, "sm_firstzombieinmunity_override", g_AdmFlag, true))
		clients[clientCount++] = i;
	return (clientCount == 0) ? 0 : clients[GetRandomInt(0, clientCount-1)];
} 