#pragma semicolon 1
#include <sdktools>
#define PVERSION "1.3.2"

new Handle:gH_Enabled = INVALID_HANDLE;
new Handle:gH_LAW = INVALID_HANDLE;
new Handle:gH_Return = INVALID_HANDLE;

new bool:bEnabled = true;
new bool:bLAW = true;
new bool:bRtn = false;

public Plugin:myinfo =
{
	name = "Flashlight",
	author = "Mitch",
	description = "Replaces +lookatweapon with a toggleable flashlight. Also adds the command: sm_flashlight",
	version = PVERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=227224"
};

public OnPluginStart()
{
	gH_Enabled 		= CreateConVar("sm_flashlight_enabled", "1", 
					"0 = Disables flashlight; 1 = Enables flashlight", 		FCVAR_PLUGIN, true, 0.0, true, 1.0);
	gH_LAW 		= CreateConVar("sm_flashlight_lookatweapon", "1", 
					"0 = Doesn't use +lookatweapon; 1 = hooks +lookatweapon", 		FCVAR_PLUGIN, true, 0.0, true, 1.0);
	gH_Return 	= CreateConVar("sm_flashlight_return", "0", 
					"0 = Doesn't return blocking +look at weapon; 1 = Does return", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	HookConVarChange(gH_Enabled, ConVarChanged);
	HookConVarChange(gH_LAW, ConVarChanged);
	HookConVarChange(gH_Return, ConVarChanged);
	AutoExecConfig();

	CreateConVar("sm_flashlight_version", PVERSION, "CsGoFlashlight Version", FCVAR_DONTRECORD|FCVAR_NOTIFY);

	AddCommandListener(Command_LAW, "+lookatweapon");	//Hooks cs:go's flashlight replacement 'look at weapon'.
	RegConsoleCmd("sm_flashlight", Command_FlashLight); 	//Bindable Flashlight command
}

public ConVarChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	if(cvar == gH_Enabled)
		bEnabled = bool:StringToInt(newVal);
	if(cvar == gH_LAW)
		bLAW = bool:StringToInt(newVal);
	if(cvar == gH_Return)
		bRtn = bool:StringToInt(newVal);
}

public Action:Command_LAW(client, const String:command[], argc)
{
	if(!bLAW || !bEnabled) //Enable this hook?
		return Plugin_Continue;

	if(!IsClientInGame(client)) //If player is not in-game then ignore!
		return Plugin_Continue;

	if(!IsPlayerAlive(client)) //If player is not alive then continue the command.
		return Plugin_Continue;	

	SetEntProp(client, Prop_Send, "m_fEffects", GetEntProp(client, Prop_Send, "m_fEffects") ^ 4); 
	//Bacardi suggested this instead of adding a new variable.

	return (bRtn) ? Plugin_Continue : Plugin_Handled;
}

public Action:Command_FlashLight(client, args)
{
	if(!bEnabled)
		return Plugin_Handled;

	if (IsClientInGame(client) && IsPlayerAlive(client)) 
		SetEntProp(client, Prop_Send, "m_fEffects", GetEntProp(client, Prop_Send, "m_fEffects") ^ 4);

	return Plugin_Handled;
}