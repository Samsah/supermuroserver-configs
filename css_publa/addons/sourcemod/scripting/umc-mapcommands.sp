/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *                               Ultimate Mapchooser - Map Commands                              *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
 
#pragma semicolon 1

#include <sourcemod>
#include <umc-core>

public Plugin:myinfo =
{
    name = "[UMC] Map Commands",
    author = "Steell",
    description = "Allows users to specify commands to be executed for maps and map groups.",
    version = PL_VERSION,
    url = "http://forums.alliedmods.net/showthread.php?t=134190"
}

#define COMMAND_KEY     "command"
#define PRE_COMMAND_KEY "pre-command"

/* Globals */
new String:group_command[256], String:map_command[256];

//Execute commands after all configs have been executed.
public OnConfigsExecuted()
{
    if (strlen(group_command) > 0)
    {
        LogMessage("SETUP: Executing map group command: '%s'", group_command);
        ServerCommand(group_command);
        strcopy(group_command, sizeof(group_command), "");
    }
    
    if (strlen(map_command) > 0)
    {
        LogMessage("SETUP: Executing map command: '%s'", map_command);
        ServerCommand(map_command);
        strcopy(map_command, sizeof(map_command), "");
    }
}


//Called when UMC has set the next map.
public UMC_OnNextmapSet(Handle:kv, const String:map[], const String:group[])
{
    if (kv == INVALID_HANDLE)
        return;
    
    decl String:gPreCommand[256], String:mPreCommand[256];

    KvRewind(kv);
    KvJumpToKey(kv, group);
    
    KvGetString(kv, COMMAND_KEY, group_command, sizeof(group_command), "");
    KvGetString(kv, PRE_COMMAND_KEY, gPreCommand, sizeof(gPreCommand), "");
    
    if (strlen(gPreCommand) > 0)
        ServerCommand(gPreCommand);
        
    KvJumpToKey(kv, map);
    
    KvGetString(kv, COMMAND_KEY, map_command, sizeof(map_command), "");
    KvGetString(kv, PRE_COMMAND_KEY, mPreCommand, sizeof(mPreCommand), "");
    
    if (strlen(mPreCommand) > 0)
        ServerCommand(mPreCommand);
        
    KvRewind(kv);
}