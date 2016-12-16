#include <sourcemod>

#define TEAM_AUTOSELECT    0
#define TEAM_SPECTATOR    1
#define TEAM_TERROR    2
#define TEAM_CT        3

public Plugin:myinfo = 
{
    name = "Force Autojoin",
    author = "some",
    description = "Forces autojoin to all players",
    version = "0.1",
    url = "https://forums.alliedmods.net/showthread.php?t=198438"
}

public OnPluginStart()
{
    RegConsoleCmd("jointeam", Cmd_JoinTeam);
}

public Action:Cmd_JoinTeam(client, args)
{
    decl String:teamstring[3];
    GetCmdArg(1, teamstring, sizeof(teamstring));
    new team = StringToInt(teamstring);

    if(team != TEAM_AUTOSELECT && team != TEAM_SPECTATOR)
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}