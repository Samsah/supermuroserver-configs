/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *                               Ultimate Mapchooser - Random Cycle                              *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
 
#pragma semicolon 1

#include <sourcemod>
#include <umc-core>
#include <umc_utils>

#define NEXT_MAPGROUP_KEY "next_mapgroup"

//Plugin Information
public Plugin:myinfo =
{
    name        = "[UMC] Random Cycle",
    author      = "Steell",
    description = "Extends Ultimate Mapchooser to provide random selecting of the next map.",
    version     = PL_VERSION,
    url         = "http://forums.alliedmods.net/showthread.php?t=134190"
};

        ////----CONVARS-----/////
new Handle:cvar_filename        = INVALID_HANDLE;
new Handle:cvar_randnext        = INVALID_HANDLE;
new Handle:cvar_randnext_mem    = INVALID_HANDLE;
new Handle:cvar_randnext_catmem = INVALID_HANDLE;
        ////----/CONVARS-----/////

//Mapcycle KV
new Handle:map_kv = INVALID_HANDLE;   
new Handle:umc_mapcycle = INVALID_HANDLE;

//Memory queues
new Handle:randnext_mem_arr = INVALID_HANDLE;
new Handle:randnext_catmem_arr = INVALID_HANDLE;

//Stores the next category to randomly select a map from.
new String:next_rand_cat[MAP_LENGTH];

//Used to trigger the selection if the mode doesn't support the "game_end" event
new UserMsg:VGuiMenu;
new bool:intermission_called;

//Flag
new bool:setting_map; //Are we setting the nextmap at the end of this map?


//************************************************************************************************//
//                                        SOURCEMOD EVENTS                                        //
//************************************************************************************************//

//Called when the plugin is finished loading.
public OnPluginStart()
{
    cvar_randnext_catmem = CreateConVar(
        "sm_umc_randcycle_groupexclude",
        "0",
        "Specifies how many past map groups to exclude when picking a random map.",
        0, true, 0.0
    );
    
    cvar_randnext = CreateConVar(
        "sm_umc_randcycle_enabled",
        "1",
        "Enables random selection of the next map at the end of each map if a vote hasn't taken place.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_randnext_mem = CreateConVar(
        "sm_umc_randcycle_mapexclude",
        "4",
        "Specifies how many past maps to exclude when picking a random map. 1 = Current Map Only",
        0, true, 0.0
    );
    
    cvar_filename = CreateConVar(
        "sm_umc_randcycle_cyclefile",
        "umc_mapcycle.txt",
        "File to use for Ultimate Mapchooser's map rotation."
    );
    
    //Create the config if it doesn't exist, and then execute it.
    AutoExecConfig(true, "umc-randomcycle");
    
    //Admin commmand to pick a random nextmap.
    RegAdminCmd(
        "sm_umc_randcycle_picknextmapnow",
        Command_Random,
        ADMFLAG_CHANGEMAP,
        "Makes Ultimate Mapchooser pick a random nextmap."
    );
    
    //Hook end of game.
    HookEventEx("dod_game_over",      Event_GameEnd); //DoD
    HookEventEx("teamplay_game_over", Event_GameEnd); //TF2
    HookEventEx("game_newmap",        Event_GameEnd); //Insurgency
    
    //Hook intermission
    new String:game[20];
    GetGameFolderName(game, sizeof(game));
    if (!StrEqual(game, "tf", false) &&
        !StrEqual(game, "dod", false) &&
        !StrEqual(game, "insurgency", false))
    {
        LogMessage("SETUP: Hooking intermission...");
        VGuiMenu = GetUserMessageId("VGUIMenu");
        HookUserMessage(VGuiMenu, _VGuiMenu);
    }
    
    //Hook cvar change
    HookConVarChange(cvar_randnext_mem, Handle_RandNextMemoryChange);
    
    //Initialize our memory arrays
    new numCells = ByteCountToCells(MAP_LENGTH);
    randnext_mem_arr    = CreateArray(numCells);
    randnext_catmem_arr = CreateArray(numCells);
}


//************************************************************************************************//
//                                           GAME EVENTS                                          //
//************************************************************************************************//

//Called after all config files were executed.
public OnConfigsExecuted()
{
    intermission_called = false;
    setting_map = ReloadMapcycle();
    
    //Grab the name of the current map.
    decl String:mapName[MAP_LENGTH];
    GetCurrentMap(mapName, sizeof(mapName));
    
    decl String:groupName[MAP_LENGTH];
    UMC_GetCurrentMapGroup(groupName, sizeof(groupName));
    
    if (setting_map && StrEqual(groupName, INVALID_GROUP, false))
    {
        KvFindGroupOfMap(umc_mapcycle, mapName, groupName, sizeof(groupName));
    }
    
    SetupNextRandGroup(mapName, groupName);
    
    //Add the map to all the memory queues.
    new mapmem = GetConVarInt(cvar_randnext_mem);
    new catmem = GetConVarInt(cvar_randnext_catmem);
    AddToMemoryArray(mapName, randnext_mem_arr, mapmem);
    AddToMemoryArray(groupName, randnext_catmem_arr, (mapmem > catmem) ? mapmem : catmem);
    
    if (setting_map)
        RemovePreviousMapsFromCycle();
}


//Called when intermission window is active. Necessary for mods without "game_end" event.
public Action:_VGuiMenu(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable,
                        bool:init)
{
    //Do nothing if we have already seen the intermission.
    if(intermission_called)
        return;

    new String:type[10];
    BfReadString(bf, type, sizeof(type));

    if(strcmp(type, "scores", false) == 0)
    {
        if(BfReadByte(bf) == 1 && BfReadByte(bf) == 0)
        {
            intermission_called = true;
            Event_GameEnd(INVALID_HANDLE, "", false);
        }
    }
}


//Called when the game ends. Used to trigger random selection of the next map.
public Event_GameEnd(Handle:evnt, const String:name[], bool:dontBroadcast)
{
    //Select and change to a random map if...
    //    ...the cvar to do so is enabled AND
    //    ...we haven't completed an end-of-map vote AND
    //    ...we haven't completed an RTV.
    if (GetConVarBool(cvar_randnext) && setting_map)
        DoRandomNextMap();
}


//************************************************************************************************//
//                                              SETUP                                             //
//************************************************************************************************//

//Fetches the set next group for the given map and group in the mapcycle.
SetupNextRandGroup(const String:map[], const String:group[])
{
    decl String:gNextGroup[MAP_LENGTH];
    
    if (map_kv == INVALID_HANDLE || StrEqual(group, INVALID_GROUP, false))
    {
        strcopy(next_rand_cat, sizeof(next_rand_cat), INVALID_GROUP);
        return;
    }
    
    KvRewind(map_kv);
    if (KvJumpToKey(map_kv, group))
    {
        KvGetString(map_kv, NEXT_MAPGROUP_KEY, gNextGroup, sizeof(gNextGroup), INVALID_GROUP);
        if (KvJumpToKey(map_kv, map))
        {
            KvGetString(map_kv, NEXT_MAPGROUP_KEY, next_rand_cat, sizeof(next_rand_cat), gNextGroup);
            KvGoBack(map_kv);
        }
        KvGoBack(map_kv);   
    }
}


//Parses the mapcycle file and returns a KV handle representing the mapcycle.
Handle:GetMapcycle()
{
    //Grab the file name from the cvar.
    decl String:filename[PLATFORM_MAX_PATH];
    GetConVarString(cvar_filename, filename, sizeof(filename));
    
    //Get the kv handle from the file.
    new Handle:result = GetKvFromFile(filename, "umc_rotation");
    
    //Log an error and return empty handle if...
    //    ...the mapcycle file failed to parse.
    if (result == INVALID_HANDLE)
    {
        LogError("SETUP: Mapcycle failed to load!");
        return INVALID_HANDLE;
    }
    
    //Success!
    return result;
}


//Reloads the mapcycle. Returns true on success, false on failure.
bool:ReloadMapcycle()
{
    if (umc_mapcycle != INVALID_HANDLE)
    {
        CloseHandle(umc_mapcycle);
        umc_mapcycle = INVALID_HANDLE;
    }
    if (map_kv != INVALID_HANDLE)
    {
        CloseHandle(map_kv);
        map_kv = INVALID_HANDLE;
    }
    umc_mapcycle = GetMapcycle();
    
    return umc_mapcycle != INVALID_HANDLE;
}


//
RemovePreviousMapsFromCycle()
{
    map_kv = CreateKeyValues("umc_rotation");
    KvCopySubkeys(umc_mapcycle, map_kv);
    FilterMapcycleFromArrays(map_kv, randnext_mem_arr, randnext_catmem_arr,
                             GetConVarInt(cvar_randnext_catmem));
}


//************************************************************************************************//
//                                          CVAR CHANGES                                          //
//************************************************************************************************//

//Called when the number of excluded previous maps from random selection of the next map has
//changed.
public Handle_RandNextMemoryChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
    //Trim the memory array for random selection of the next map.
        //We pass 1 extra to the argument in order to account for the current map, which should 
        //always be excluded.
    TrimArray(randnext_mem_arr, StringToInt(newValue));
}


//************************************************************************************************//
//                                            COMMANDS                                            //
//************************************************************************************************//

//Called when the command to pick a random nextmap is called
public Action:Command_Random(client, args)
{
    if (setting_map || map_kv != INVALID_HANDLE)
        DoRandomNextMap();
    else
        ReplyToCommand(client, "\x03[UMC]\x01 Mapcycle is invalid, cannot pick a map.");
        
    return Plugin_Handled;
}


//************************************************************************************************//
//                                         RANDOM NEXTMAP                                         //
//************************************************************************************************//

//Sets a random next map. Returns true on success.
DoRandomNextMap() 
{    
    LogMessage("Attempting to set the next map to a random selection.");
    decl String:nextMap[MAP_LENGTH], String:nextGroup[MAP_LENGTH];
    if (UMC_GetRandomMap(map_kv, umc_mapcycle, next_rand_cat, nextMap, sizeof(nextMap), nextGroup,
                         sizeof(nextGroup), false, true))
    {
        DEBUG_MESSAGE("Random map: %s %s", nextMap, nextGroup)
        UMC_SetNextMap(map_kv, nextMap, nextGroup, ChangeMapTime_MapEnd);
    }
    else
    {
        LogMessage("Failed to find a suitable random map.");
    }
}


//************************************************************************************************//
//                                   ULTIMATE MAPCHOOSER EVENTS                                   //
//************************************************************************************************//

//Called when UMC has set a next map.
public UMC_OnNextmapSet(Handle:kv, const String:map[], const String:group[])
{
    setting_map = false;
}


//Called when UMC requests that the mapcycle should be reloaded.
public UMC_RequestReloadMapcycle()
{
    new bool:reloaded = ReloadMapcycle();
    if (reloaded)
        RemovePreviousMapsFromCycle();
    setting_map = reloaded && setting_map;
}

