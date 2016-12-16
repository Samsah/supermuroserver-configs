/*****************************************************************


C O M P I L E   O P T I O N S


*****************************************************************/
// enforce semicolons after each code statement
#pragma semicolon 1

/*****************************************************************


P L U G I N   I N C L U D E S


*****************************************************************/
#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <smlib/pluginmanager>

/*****************************************************************


P L U G I N   I N F O


*****************************************************************/
#define PLUGIN_NAME				"Fix Map Lasers"
#define PLUGIN_TAG				"sm"
#define PLUGIN_AUTHOR			"Chanz"
#define PLUGIN_DESCRIPTION		"This fixes the damage of lasers since the orangebox update. Works for any map/game."
#define PLUGIN_VERSION 			"1.0.0"
#define PLUGIN_URL				"http://forums.alliedmods.net/showthread.php?p=1404208 OR http://www.mannisfunhouse.eu/"

public Plugin:myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
}

/*****************************************************************


		P L U G I N   D E F I N E S


*****************************************************************/


/*****************************************************************


		G L O B A L   V A R S


*****************************************************************/
//Use a good notation, constants for arrays, initialize everything that has nothing to do with clients!
//If you use something which requires client index init it within the function Client_InitVars (look below)
//Example: Bad: "decl servertime" Good: "new g_iServerTime = 0"
//Example client settings: Bad: "decl saveclientname[33][32] Good: "new g_szClientName[MAXPLAYERS+1][MAX_NAME_LENGTH];" -> later in Client_InitVars: GetClientName(client,g_szClientName,sizeof(g_szClientName));



/*****************************************************************


		F O R W A R D   P U B L I C S


*****************************************************************/
public OnPluginStart() {
	
	//Init for smlib
	SMLib_OnPluginStart(PLUGIN_NAME,PLUGIN_TAG,PLUGIN_VERSION,PLUGIN_AUTHOR,PLUGIN_DESCRIPTION,PLUGIN_URL);
	
	//Command Hooks (AddCommandListener) (If the command already exists, like the command kill, then hook it!)
	
	
	//Register New Commands (RegConsoleCmd) (If the command doesn't exist, hook it here)
	
	
	//Register Admin Commands (RegAdminCmd)
	
	
	//Cvars: Create a global handle variable.
	//Example: g_cvarEnable = CreateConVarEx("enable","1","example ConVar");
	
	
	//Set your ConVar runtime optimizers here
	//Example: g_iPlugin_Enable = GetConVarInt(g_cvarEnable);
	
	//Hook ConVar Change
	
	
	//Event Hooks
	PrintToServer("hooked round start: %d",HookEventEx("round_start",Event_Round_Start,EventHookMode_Post));
	
	//Auto Config (you should always use it)
	//Always with "plugin." prefix and the short name
	decl String:configName[MAX_PLUGIN_SHORTNAME_LENGTH+8];
	Format(configName,sizeof(configName),"plugin.%s",g_sPlugin_Short_Name);
	AutoExecConfig(true,configName);
	
	//Mind: this is only here for late load, since on map change or server start, there isn't any client.
	//Remove it if you don't need it.
	ClientAll_Init();
}

public OnMapStart() {
	
	// hax against valvefail (thx psychonic for fix)
	if(GuessSDKVersion() == SOURCE_SDK_EPISODE2VALVE){
		SetConVarString(g_cvarVersion, PLUGIN_VERSION);
	}
	
	if(g_iPlugin_Enable == 0){
		return;
	}
	
	Entity_FixLasers();
	Entity_FixBeams();
}

public OnConfigsExecuted(){
	
	ClientAll_Init();
}

public OnClientConnected(client){
	
	Client_Init(client);
}

public OnClientPostAdminCheck(client){
	
	Client_Init(client);
}

/****************************************************************


		C A L L B A C K   F U N C T I O N S


****************************************************************/
public Action:Event_Round_Start(Handle:event, const String:name[], bool:dontBroadcast){
	
	if(g_iPlugin_Enable == 0){
		return Plugin_Continue;
	}

	Entity_FixLasers();
	Entity_FixBeams();
	
	return Plugin_Continue;
}

/*****************************************************************


		P L U G I N   F U N C T I O N S


*****************************************************************/
Entity_FixLasers(){
	
	new entity = -1;
	new target = -1;
	new entitysParent = -1;
	new targetsParent = -1;
	
	new Float:entityOrigin[3];
	new Float:targetOrigin[3];
	new Float:wallHitPos[3];
	new Float:newOrigin[3];
	
	new String:laserTarget[MAX_TARGET_LENGTH];
	
	new Handle:trace = INVALID_HANDLE;
	
	
	while ((entity = FindEntityByClassname(entity, "env_laser")) != INVALID_ENT_REFERENCE) {
		
		//Get name of the LaserTarget out of our env_laser.
		GetEntPropString(entity,Prop_Data,"m_iszLaserTarget",laserTarget,sizeof(laserTarget));
		
		if(laserTarget[0] == '\0'){
			continue;
		}
		
		target = Edict_FindByName(laserTarget);
		
		if(target == -1){
			continue;
		}
		
		entitysParent = Entity_GetParent(entity);
		
		if(entitysParent != -1){
			
			Entity_RemoveParent(entity);
		}
		
		targetsParent = Entity_GetParent(target);
		
		if(targetsParent != -1){
			
			Entity_RemoveParent(target);
		}
		
		Entity_GetAbsOrigin(target,targetOrigin);
		Entity_GetAbsOrigin(entity,entityOrigin);
		
		//Find Middle
		//Two-Point-Form of our straight / Zwei-Punkte-Form einer Geraden formel.
		//Papula Mathe Band 1 (Auflage 11) Seite 100.
		Math_MoveVector(entityOrigin,targetOrigin,0.5,wallHitPos);
		
		//this will be the best pos for our laser!
		trace = TR_TraceRayEx(wallHitPos,entityOrigin,MASK_ALL,RayType_EndPoint);
		TR_GetEndPosition(wallHitPos,trace);
		CloseHandle(trace);
		
		//We want to scale (shrink) our vector. if we use lambda = 1.0 then newOrigin would be exactly the same as targetOrigin.
		//Two-Point-Form of our straight / Zwei-Punkte-Form einer Geraden formel.
		//Papula Mathe Band 1 (Auflage 11) Seite 100.
		Math_MoveVector(wallHitPos,targetOrigin,(1.0 / GetVectorDistance(wallHitPos,targetOrigin)),newOrigin);
		
		Entity_SetAbsOrigin(entity,newOrigin);
		
		if(entitysParent != -1){
			
			Entity_SetParent(entity,entitysParent);
		}
		
		if(targetsParent != -1){
			
			Entity_SetParent(target,targetsParent);
		}
	}
}

Entity_FixBeams(){
	
	
	
	new entity = -1;
	new start = -1;
	new end = -1;
	new startsParent = -1;
	new endsParent = -1;
	
	new Float:startOrigin[3];
	new Float:endOrigin[3];
	new Float:wallHitPos[3];
	new Float:newOrigin[3];
	
	new String:beamStart[MAX_TARGET_LENGTH];
	new String:beamEnd[MAX_TARGET_LENGTH];
	
	new Handle:trace = INVALID_HANDLE;
	
	while ((entity = FindEntityByClassname(entity, "env_beam")) != INVALID_ENT_REFERENCE) {
		
		//Get name of the start and end entity
		GetEntPropString(entity,Prop_Data,"m_iszStartEntity",beamStart,sizeof(beamStart));
		GetEntPropString(entity,Prop_Data,"m_iszEndEntity",beamEnd,sizeof(beamEnd));
		
		if((beamStart[0] == '\0') || (beamEnd[0] == '\0')){
			continue;
		}
		
		start = Edict_FindByName(beamStart);
		end = Edict_FindByName(beamEnd);
		
		if((start == -1) || (end == -1)){
			continue;
		}
		
		startsParent = Entity_GetParent(start);
		
		if(startsParent != -1){
			
			Entity_RemoveParent(start);
		}
		
		endsParent = Entity_GetParent(end);
		
		if(endsParent != -1){
			
			Entity_RemoveParent(end);
		}
		
		Entity_GetAbsOrigin(start,startOrigin);
		Entity_GetAbsOrigin(end,endOrigin);
		
		//Two-Point-Form of our straight / Zwei-Punkte-Form einer Geraden formel.
		//Papula Mathe Band 1 (Auflage 11) Seite 100.
		//Lets find the middle
		Math_MoveVector(startOrigin,endOrigin,0.5,wallHitPos);
		
		//this will be the best pos for our laser!
		trace = TR_TraceRayEx(wallHitPos,startOrigin,MASK_ALL,RayType_EndPoint);
		TR_GetEndPosition(wallHitPos,trace);
		CloseHandle(trace);
		
		//Two-Point-Form of our straight / Zwei-Punkte-Form einer Geraden formel.
		//Papula Mathe Band 1 (Auflage 11) Seite 100.
		//Move as close as possible:
		Math_MoveVector(wallHitPos,endOrigin,(1.0 / GetVectorDistance(wallHitPos,endOrigin)),newOrigin);
		
		Entity_SetAbsOrigin(start,newOrigin);
		
		if(startsParent != -1){
			
			Entity_SetParent(start,startsParent);
		}
		
		if(endsParent != -1){
			
			Entity_SetParent(end,endsParent);
		}
	}
}


stock ClientAll_Init(){
	
	for(new client=1;client<=MaxClients;client++){
		
		if(!IsClientInGame(client)){
			continue;
		}
		
		Client_Init(client);
	}
}

stock Client_Init(client){
	
	//Variables
	Client_InitVars(client);
	
	//Functions
}

stock Client_InitVars(client){
	
	//Plugin Client Vars
	
}


