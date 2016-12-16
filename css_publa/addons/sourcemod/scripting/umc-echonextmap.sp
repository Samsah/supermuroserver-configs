/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *                               Ultimate Mapchooser - Echo Nextmap                              *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
 
#pragma semicolon 1

#include <sourcemod>
#include <umc-core>
#include <umc_utils>

public Plugin:myinfo =
{
    name = "[UMC] Map Commands",
    author = "Steell",
    description = "Displays messages to the server when the next map is set.",
    version = PL_VERSION,
    url = "http://forums.alliedmods.net/showthread.php?t=134190"
}

//Cvars
new Handle:cvar_center = INVALID_HANDLE;
new Handle:cvar_hint   = INVALID_HANDLE;


//Called when the plugin loads.
public OnPluginStart()
{
    cvar_center = CreateConVar(
        "sm_umc_echonextmap_center",
        "1",
        "If enabled, a message will be displayed in the center of the screen when the next map is set.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_hint = CreateConVar(
        "sm_umc_exchonextmap_hint",
        "0",
        "If enabled, a message will be displayed in the hint box when the next map is set.",
        0, true, 0.0, true, 1.0
    );

    //Create the config if it doesn't exist, and then execute it.
    AutoExecConfig(true, "umc-echonextmap");
    
    //Load the translations file
    LoadTranslations("ultimate-mapchooser.phrases");
}


//Called when UMC has set the next map.
public UMC_OnNextmapSet(Handle:kv, const String:map[], const String:group[])
{
    if (GetConVarBool(cvar_center))
    {
        decl String:msg[256];
        Format(msg, sizeof(msg), "[UMC] %t", "Next Map", map);
        DisplayServerMessage(msg, "C");
        //PrintCenterTextAll("[UMC] %t", "Next Map", map);
    }
    if (GetConVarBool(cvar_hint))
    {
        PrintHintTextToAll("[UMC] %t", "Next Map", map);
    }
}


