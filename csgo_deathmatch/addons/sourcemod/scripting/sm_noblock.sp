public Plugin:myinfo = {
	name = "[CS:GO] Noblock",
	author = "www.neatek.ru",
	description = "",
	version = "1.0",
	url = "http://www.neatek.ru/"
};

bool g_bNoblock;
ConVar g_hNoblock, g_hVersion;

public OnPluginStart() 
{
	g_hNoblock = CreateConVar("sm_noblock", "0", "Set noblock at spawn");
	g_hVersion = CreateConVar("sm_noblock_csgo_version", "1.0", "Version of plugin");
	
	HookConVarChange(g_hVersion, HookConVar_Changed);
	HookConVarChange(g_hNoblock, HookConVar_Changed);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	AutoExecConfig(true);
}

public OnPluginEnd() {
	UnhookEvent("player_spawn", Event_PlayerSpawn);
}

public OnConfigsExecuted() 
{
	g_bNoblock = GetConVarBool(g_hNoblock);
	SetConVarString(g_hVersion, "1.0", true, true);
}

public HookConVar_Changed(ConVar convar, char[] oldValue, char[] newValue)
{
	if(convar == g_hNoblock) if(StringToInt(newValue, 0) > 0) g_bNoblock = true; else g_bNoblock = false;
	SetConVarString(g_hVersion, "1.0", true, true);
}

public bool:ClientValid(client)
{
	if(0 < client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client)) return true; return false;
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(g_bNoblock && ClientValid(client) && GetClientTeam(client) > 1 && IsPlayerAlive(client)) SetEntProp(client, Prop_Data, "m_CollisionGroup", 17);
}