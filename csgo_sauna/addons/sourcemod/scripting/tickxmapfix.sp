/***************************************************************************************

	Copyright (C) 2012 BCServ (plugins@bcserv.eu)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
	
***************************************************************************************/

/***************************************************************************************


	C O M P I L E   O P T I O N S


***************************************************************************************/
// enforce semicolons after each code statement
#pragma semicolon 1

/***************************************************************************************


	P L U G I N   I N C L U D E S


***************************************************************************************/
#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <smlib/pluginmanager>


/***************************************************************************************


	P L U G I N   I N F O


***************************************************************************************/
public Plugin:myinfo = {
	name 						= "Tick X Map Fix",
	author 						= "Chanz",
	description 				= "This is a SourceMod plugin, it improves maps which are made only for tick 66 servers to work better on servers with a differnt tickrate",
	version 					= "3.1",
	url 						= "http://forums.alliedmods.net/showthread.php?p=1528146"
}

/***************************************************************************************


	P L U G I N   D E F I N E S


***************************************************************************************/

/***************************************************************************************


	G L O B A L   V A R S


***************************************************************************************/
// Server Variables


// Plugin Internal Variables


// Console Variables
new Handle:g_cvarEnable 					= INVALID_HANDLE;
new Handle:g_cvarDoors_Speed_Elevator 		= INVALID_HANDLE;
new Handle:g_cvarDoors_Speed 				= INVALID_HANDLE;
new Handle:g_cvarDoors_Speed_Prop 			= INVALID_HANDLE;

// Console Variables: Runtime Optimizers
new g_iPlugin_Enable 					= 1;
new Float:g_flPlugin_Doors_Speed_Elevator 	= -1.0;
new Float:g_flPlugin_Doors_Speed 			= -1.0;
new Float:g_flPlugin_Doors_Speed_Prop 		= -1.0;

// Timers


// Library Load Checks


// Game Variables


// Map Variables
//Doors
enum DoorsTypeTracked {
	
	DoorsTypeTracked_None = -1,
	DoorsTypeTracked_Func_Door = 0,
	DoorsTypeTracked_Func_Door_Rotating = 1,
	DoorsTypeTracked_Func_MoveLinear = 2,
	DoorsTypeTracked_Prop_Door = 3,
	DoorsTypeTracked_Prop_Door_Rotating = 4
	
};
new String:g_szDoors_Type_Tracked[][MAX_NAME_LENGTH] = {
	
	"func_door",
	"func_door_rotating",
	"func_movelinear",
	"prop_door",
	"prop_door_rotating"
};

enum DoorsData {
	
	DoorsTypeTracked:DoorsData_Type,
	Float:DoorsData_Speed,
	Float:DoorsData_BlockDamage,
	bool:DoorsData_ForceClose
}

new Float:g_ddDoors[2048][DoorsData];
new bool:g_bDoors_HasChangedValues = false;

// Client Variables


// M i s c


/***************************************************************************************


	F O R W A R D   P U B L I C S


***************************************************************************************/
public OnPluginStart()
{
	// Initialization for SMLib (don't execute AutoConfig, since we handle it in AutoConfigManagement)
	PluginManager_Initialize("tickxmapfix", "[SM] ", false, false);
	AutoConfigManagement();
	
	// Translations
	// LoadTranslations("common.phrases");
	
	
	// Command Hooks (AddCommandListener) (If the command already exists, like the command kill, then hook it!)
	
	
	// Register New Commands (PluginManager_RegConsoleCmd) (If the command doesn't exist, hook it here)
	
	
	// Register Admin Commands (PluginManager_RegAdminCmd)
	

	// Cvars: Create a global handle variable.
	g_cvarEnable = PluginManager_CreateConVar("enable", "1", "Enables or disables this plugin");
	g_cvarDoors_Speed_Elevator 		= PluginManager_CreateConVar("doors_speed_elevator", 	"1.05", "Sets the speed of all func_door entities used as elevators on a map.\nEx: 1.05 means +5% speed", FCVAR_PLUGIN);
	g_cvarDoors_Speed 				= PluginManager_CreateConVar("doors_speed", 			"2.00", "Sets the speed of all func_door entities that are not elevators on a map.\nEx: 2.00 means +100% speed", FCVAR_PLUGIN);
	g_cvarDoors_Speed_Prop			= PluginManager_CreateConVar("doors_speed_prop", 		"2.00", "Sets the speed of all prop_door entities on a map.\nEx: 2.00 means +100% speed", FCVAR_PLUGIN);
	
	
	// Hook ConVar Change
	HookConVarChange(g_cvarEnable, ConVarChange_Enable);
	HookConVarChange(g_cvarEnable,					ConVarChange_Enable);
	HookConVarChange(g_cvarDoors_Speed_Elevator,	ConVarChange_Doors_Speed_Elevator);
	HookConVarChange(g_cvarDoors_Speed,				ConVarChange_Doors_Speed);
	HookConVarChange(g_cvarDoors_Speed_Prop,		ConVarChange_Doors_Speed_Prop);
	
	// Event Hooks
	HookEvent("round_start",Event_Round_Start,EventHookMode_Post);
	
	// Library
	
	
	/* Features
	if(CanTestFeatures()){
		
	}
	*/
	
	// Create ADT Arrays
	
	
	// Timers
	
}

public OnPluginEnd()
{
	if(g_bDoors_HasChangedValues){
		Door_ResetSettingsAll();
	}
}

public OnMapStart()
{
	SetConVarString(Plugin_VersionCvar, Plugin_Version);
	Door_ClearSettingsAll();
}

public OnConfigsExecuted()
{
	// Set your ConVar runtime optimizers here
	g_iPlugin_Enable = GetConVarInt(g_cvarEnable);
	g_flPlugin_Doors_Speed_Elevator 	= GetConVarFloat(g_cvarDoors_Speed_Elevator);
	g_flPlugin_Doors_Speed 				= GetConVarFloat(g_cvarDoors_Speed);
	g_flPlugin_Doors_Speed_Prop 		= GetConVarFloat(g_cvarDoors_Speed_Prop);
	
	// Mind: this is only here for late load, since on map change or server start, there isn't any client.
	// Remove it if you don't need it.
	Client_InitializeAll();

	if(g_iPlugin_Enable != 0){
		
		Door_GetSettingsAll();
		Door_SetSettingsAll();
	}
}

public OnClientPutInServer(client)
{
	Client_Initialize(client);
}

public OnClientPostAdminCheck(client)
{
	Client_Initialize(client);
}

/**************************************************************************************


	C A L L B A C K   F U N C T I O N S


**************************************************************************************/
/**************************************************************************************

	C O N  V A R  C H A N G E

**************************************************************************************/
/* Example Callback Con Var Change*/
public ConVarChange_Enable(Handle:cvar, const String:szOldVal[], const String:szNewVal[]){
	
	new oldVal = StringToInt(szOldVal);
	new newVal = StringToInt(szNewVal);
	
	if(oldVal == newVal){
		return;
	}
	
	if(g_bDoors_HasChangedValues) {
		
		Door_ResetSettingsAll();
	}
	
	if(newVal == 1){
		
		Door_ClearSettingsAll();
		Door_GetSettingsAll();
		Door_SetSettingsAll();
	}
}

public ConVarChange_Doors_Speed_Elevator(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	g_flPlugin_Doors_Speed_Elevator = StringToFloat(newVal);
	
	if(g_iPlugin_Enable != 0){
		Door_SetSettingsAll();
	}
}

public ConVarChange_Doors_Speed(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	g_flPlugin_Doors_Speed = StringToFloat(newVal);
	
	if(g_iPlugin_Enable != 0){
		Door_SetSettingsAll();
	}
}

public ConVarChange_Doors_Speed_Prop(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	g_flPlugin_Doors_Speed_Prop = StringToFloat(newVal);
	
	if(g_iPlugin_Enable != 0){
		Door_SetSettingsAll();
	}
}

/**************************************************************************************

	C O M M A N D S

**************************************************************************************/
/**************************************************************************************

	E V E N T S

**************************************************************************************/
public Action:Event_Round_Start(Handle:event, const String:name[], bool:dontBroadcast){
	
	if(g_iPlugin_Enable != 0){
		
		Door_ClearSettingsAll();
		Door_GetSettingsAll();
		Door_SetSettingsAll();
	}
	return Plugin_Continue;
}

/***************************************************************************************


	P L U G I N   F U N C T I O N S


***************************************************************************************/
AutoConfigManagement()
{
	//Auto Config (you should always use it)
	//Always with "plugin." prefix and the short name
	new tick = RoundToFloor(1.0/GetTickInterval());
	
	new String:path[PLATFORM_MAX_PATH];
	Format(path,sizeof(path),"cfg/sourcemod/tickxmapfix");
	
	if(!DirExists(path)){
		
		//0775
		if(!CreateDirectory(path,
			FPERM_U_READ|	FPERM_U_WRITE|	FPERM_U_EXEC|
			FPERM_G_READ|	FPERM_G_WRITE|	FPERM_G_EXEC|
			FPERM_O_READ|					FPERM_O_EXEC
		)) {
			SetFailState("directory %s is missing and can't be created.",path);
		}
	}

	decl String:configName[PLATFORM_MAX_PATH];
	Format(configName,sizeof(configName),"tickxmapfix/tickrate-%d",tick);
	AutoExecConfig(true,configName);
}

Door_SetSettingsAll(){
	
	g_bDoors_HasChangedValues = true;
	
	new countEnts=0;
	new entity = -1;
	
	for(new i=0;i<sizeof(g_szDoors_Type_Tracked);i++){
		
		while ((entity = FindEntityByClassname(entity, g_szDoors_Type_Tracked[i])) != INVALID_ENT_REFERENCE){
			
			Door_SetSettings(entity);
			countEnts++;
		}
		
		entity = -1;
	}
}

Door_SetSettings(entity){
	
	if(g_ddDoors[entity][DoorsData_Type] == DoorsTypeTracked_None){
		return;
	}
	
	if(g_ddDoors[entity][DoorsData_Type] != DoorsTypeTracked_Func_MoveLinear) {
		
		Entity_SetForceClose(entity,false);
	}
	
	if(
		g_ddDoors[entity][DoorsData_Type] == DoorsTypeTracked_Prop_Door ||
		g_ddDoors[entity][DoorsData_Type] == DoorsTypeTracked_Prop_Door_Rotating
	) {
		
		Entity_SetSpeed(entity,g_ddDoors[entity][DoorsData_Speed]*g_flPlugin_Doors_Speed_Prop);
	}
	else {
		
		new Float:moveDir[3];
		Entity_GetMoveDirection(entity,moveDir);
		Entity_SetSpeed(entity,g_ddDoors[entity][DoorsData_Speed]*((moveDir[2] == 1.0) ? g_flPlugin_Doors_Speed_Elevator : g_flPlugin_Doors_Speed));
		
		Entity_SetBlockDamage(entity,0.0);
	}
}

Door_ResetSettingsAll(){
	
	new countEnts=0;
	new entity = -1;
	
	for(new i=0;i<sizeof(g_szDoors_Type_Tracked);i++){
		
		while ((entity = FindEntityByClassname(entity, g_szDoors_Type_Tracked[i])) != INVALID_ENT_REFERENCE){
			
			Door_ResetSettings(entity);
			countEnts++;
		}
		
		entity = -1;
	}
}

Door_ResetSettings(entity){
	
	if(g_ddDoors[entity][DoorsData_Type] == DoorsTypeTracked_None){
		return;
	}
	
	if(g_ddDoors[entity][DoorsData_Type] != DoorsTypeTracked_Func_MoveLinear) {
		
		Entity_SetForceClose(entity,g_ddDoors[entity][DoorsData_ForceClose]);
	}
	
	if(
		g_ddDoors[entity][DoorsData_Type] != DoorsTypeTracked_Prop_Door &&
		g_ddDoors[entity][DoorsData_Type] != DoorsTypeTracked_Prop_Door_Rotating
	) {
		Entity_SetBlockDamage(entity,g_ddDoors[entity][DoorsData_BlockDamage]);
	}
	
	Entity_SetSpeed(entity,g_ddDoors[entity][DoorsData_Speed]);
}

Door_GetSettingsAll(){
	
	new countEnts=0;
	new entity = -1;
	
	for(new i=0;i<sizeof(g_szDoors_Type_Tracked);i++){
		
		while ((entity = FindEntityByClassname(entity, g_szDoors_Type_Tracked[i])) != INVALID_ENT_REFERENCE){
			
			Door_GetSettings(entity,DoorsTypeTracked:i);
			countEnts++;
		}
		
		entity = -1;
	} 
}

Door_GetSettings(entity,DoorsTypeTracked:type){
	
	g_ddDoors[entity][DoorsData_Type] = type;
	
	if(g_ddDoors[entity][DoorsData_Type] != DoorsTypeTracked_Func_MoveLinear) {
		
		g_ddDoors[entity][DoorsData_ForceClose] = Entity_GetForceClose(entity);
	}
	
	if(
		g_ddDoors[entity][DoorsData_Type] != DoorsTypeTracked_Prop_Door &&
		g_ddDoors[entity][DoorsData_Type] != DoorsTypeTracked_Prop_Door_Rotating
	) {
		
		g_ddDoors[entity][DoorsData_BlockDamage] = Entity_GetBlockDamage(entity);
	}
	
	g_ddDoors[entity][DoorsData_Speed] = Entity_GetSpeed(entity);
}

Door_ClearSettingsAll(){
	
	g_bDoors_HasChangedValues = false;
	
	for(new i=0;i<sizeof(g_ddDoors);i++){
		
		g_ddDoors[i][DoorsData_Type] = DoorsTypeTracked_None;
		g_ddDoors[i][DoorsData_Speed] = 0.0;
		g_ddDoors[i][DoorsData_BlockDamage] = 0.0;
		g_ddDoors[i][DoorsData_ForceClose] = false;
	}
}

/***************************************************************************************

	S T O C K

***************************************************************************************/
stock Client_InitializeAll()
{
	LOOP_CLIENTS (client, CLIENTFILTER_ALL) {
		
		Client_Initialize(client);
	}
}

stock Client_Initialize(client)
{
	// Variables
	Client_InitializeVariables(client);
	
	
	// Functions
	
	
	/* Functions where the player needs to be in game 
	if(!IsClientInGame(client)){
		return;
	}
	*/
}

stock Client_InitializeVariables(client)
{
	// Client Variables
}

