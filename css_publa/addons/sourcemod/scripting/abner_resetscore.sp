#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <colors>

#pragma semicolon 1

#define PLUGIN_VERSION "1.4"
#define RESETSCORE_ADMINFLAG ADMFLAG_SLAY

new Handle:hPluginEnable;
new Handle:hPublic;
new bool:CSS = false;
new bool:CSGO = false;

public Plugin:myinfo =
{
        name = "AbNeR ResetScore",
        author = "AbNeR_CSS",
        description = "Type !resetscore to reset your score",
        version = PLUGIN_VERSION,
        url = "www.tecnohardclan.com"
};

public OnPluginStart()
{  
		RegConsoleCmd("resetscore", CommandResetScore);
		RegConsoleCmd("rs", CommandResetScore);
		RegAdminCmd("sm_resetplayer", CommandResetPlayer, RESETSCORE_ADMINFLAG);
		RegAdminCmd("sm_setscore", CommandSetScore, RESETSCORE_ADMINFLAG);
		RegAdminCmd("sm_setstars", CommandSetStars, RESETSCORE_ADMINFLAG);
		
		LoadTranslations("common.phrases");
		LoadTranslations("abner_resetscore.phrases");
		
		ServerCommand("mp_backup_round_file \"\"");
		ServerCommand("mp_backup_round_file_last \"\"");
		ServerCommand("mp_backup_round_file_pattern \"\"");
		ServerCommand("mp_backup_round_auto 0");
				
		decl String:theFolder[40];
		GetGameFolderName(theFolder, sizeof(theFolder));
		
		if(StrEqual(theFolder, "cstrike"))
		{
			CSS = true;
		}
		else if(StrEqual(theFolder, "csgo"))
		{
			CSGO = true;
			RegAdminCmd("sm_setassists", CommandSetAssists, RESETSCORE_ADMINFLAG);
		}
		AutoExecConfig();
		CreateConVar("abner_resetscore_version", PLUGIN_VERSION, "Resetscore Version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED);
		hPluginEnable = CreateConVar("sm_resetscore", "1", "Enable or Disable the Plugin", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED);
		hPublic = CreateConVar("sm_resetscore_public", "1", "Enable or disable the messages when player reset her score", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED);
        
}

public OnMapStart()
{
	ServerCommand("mp_backup_round_file \"\"");
	ServerCommand("mp_backup_round_file_last \"\"");
	ServerCommand("mp_backup_round_file_pattern \"\"");
	ServerCommand("mp_backup_round_auto 0");
}  


public Action:CommandResetScore(id, args)
{                        
				new String:name[MAX_NAME_LENGTH];
				GetClientName(id, name, sizeof(name));
				
				if(CSS)
				{			
					if(!id)
					{
						//PrintToServer("[ResetScore] The server cannot reset his score");
						PrintToServer("[AbNeR ResetScore] %t", "Server Reset");
						return Plugin_Handled;
					}
				
					if(GetConVarInt(hPluginEnable) == 0)
					{
						PrintToChat(id, "\x04[AbNeR ResetScore] \x01%t", "Plugin Disabled");
						//PrintToChat(id, "\x01\x04[ResetScore]\x01 The plugin is disabled.");
						return Plugin_Handled;
					}
					
					if(GetClientDeaths(id) == 0 && GetClientFrags(id) == 0 && CS_GetMVPCount(id) == 0)
					{
						//PrintToChat(id, "\x01\x04[ResetScore]\x01 Your Score is already 0");
						PrintToChat(id, "\x04[AbNeR ResetScore] \x01%t", "Score 0");
						return Plugin_Handled;
					}
					SetClientFrags(id, 0);
					SetClientDeaths(id, 0);
					CS_SetMVPCount(id, 0);
					if(GetConVarInt(hPublic) == 1)
					{
						//PrintToChatAll("\x01\x04\x04[ResetScore]\x01 Player\x03 %s\x01 has just reseted his score.", name);
						if(GetClientTeam(id) == 2)
						{
							CPrintToChatAll("\x04[AbNeR ResetScore] \x01%t", "Player Reset Red", name);
						}
						if(GetClientTeam(id) == 3)
						{
							CPrintToChatAll("\x04[AbNeR ResetScore] \x01%t", "Player Reset Blue", name);
						}
						if(GetClientTeam(id) != 2 && GetClientTeam(id) != 3)
						{
							CPrintToChatAll("\x04[AbNeR ResetScore] \x01%t", "Player Reset Normal", name);
						}
                    }
					else
					{
						//PrintToChat(id, "\x01\x04[ResetScore]\x01 You reseted your score !.");
						PrintToChat(id, "\x04[AbNeR ResetScore] \x01%t", "You Reset");
					}
				}
				
				if(CSGO)
				{			
					if(!id)
					{
						//PrintToServer("[ResetScore] The server cannot reset his score.");
						PrintToServer("[AbNeR ResetScore] %t", "Server Reset");
						return Plugin_Handled;
					}
				
					if(GetConVarInt(hPluginEnable) == 0)
					{
						//PrintToChat(id, "|\x01\x0B\x04[ResetScore]\x09 The plugin is disabled.");
						CPrintToChat(id, "\x04[AbNeR ResetScore] \x01%t", "Plugin Disabled");
						return Plugin_Handled;
					}
					
					if(GetClientDeaths(id) == 0 && GetClientFrags(id) == 0 && CS_GetMVPCount(id) == 0 && CS_GetClientAssists(id) == 0)
					{
						//PrintToChat(id, "|\x01\x0B\x04[ResetScore]\x09 Your Score is already 0.");
						CPrintToChat(id, "\x04[AbNeR ResetScore] \x01%t", "Score 0");
						return Plugin_Handled;
					}
					SetClientFrags(id, 0);
					SetClientDeaths(id, 0);
					CS_SetMVPCount(id, 0);
					CS_SetClientAssists(id, 0);
					CS_SetClientContributionScore(id, 0);
					if(GetConVarInt(hPublic) == 1)
					{
						//PrintToChatAll("|\x01\x0B\x04[ResetScore]\x09 Player\x07 %s\x09 has just reseted his score.", name);
						if(GetClientTeam(id) == 2)
						{
							CPrintToChatAll("\x04[AbNeR ResetScore] \x01%t", "Player Reset Red", name);
						}
						if(GetClientTeam(id) == 3)
						{
							CPrintToChatAll("\x04[AbNeR ResetScore] \x01%t", "Player Reset Blue", name);
						}
						if(GetClientTeam(id) != 2 && GetClientTeam(id) != 3)
						{
							CPrintToChatAll("\x04[AbNeR ResetScore] \x01%t", "Player Reset Normal", name);
						}
                    }
					else
					{
						//PrintToChat(id, "|\x01\x0B\x04[ResetScore]\x09 You reseted your score !");
						CPrintToChat(id, "\x04[AbNeR ResetScore] \x01%t", "You Reset");
					}
				}
				return Plugin_Handled;
}

stock SetClientFrags(index, frags)
{
        SetEntProp(index, Prop_Data, "m_iFrags", frags);
        return 1;
}
stock SetClientDeaths(index, deaths)
{
        SetEntProp(index, Prop_Data, "m_iDeaths", deaths);
        return 1;
}

	
public Action:CommandResetPlayer(client, args)
{                           
	new String:arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
                     	
	if (args != 1)
	{
		//ReplyToCommand(client, "\x01[AbNeR ResetScore] Usage: sm_setscore <name or #userid> <Kills> <Deaths>");
		ReplyToCommand(client, "\x01[AbNeR ResetScore] %t", "Command RS");
		return Plugin_Handled;
	}
 	
	decl String:target_name[MAX_TARGET_LENGTH];
	new String:nameadm[MAX_NAME_LENGTH];
	GetClientName(client, nameadm, sizeof(nameadm));
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
	if ((target_count = ProcessTargetString(
	arg1,
	client,
	target_list,
	MAXPLAYERS,
	COMMAND_TARGET_NONE,
	target_name,
	sizeof(target_name),
	tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}


  	for (new i = 0; i < target_count; i++)
	{
		SetEntProp(target_list[i], Prop_Data, "m_iFrags", 0);
		SetEntProp(target_list[i], Prop_Data, "m_iDeaths", 0);
		CS_SetClientContributionScore(target_list[i], 0);
		CS_SetMVPCount(target_list[i], 0);
		if(CSGO)
		{
			CS_SetClientAssists(target_list[i], 0);
		}
	}
	
	if (tn_is_ml)
	{
		//ShowActivity2(client, "[ResetScore] ", "reset score of %s", nameadm, target_name);
		ShowActivity2(client, "[AbNeR ResetScore] ", "%t", "Reset Score of", target_name);
	}
	else
	{
		//ShowActivity2(client, "[ResetScore] ", "reset score of %s", target_name);
		ShowActivity2(client, "[AbNeR ResetScore] ", "%t", "Reset Score of", target_name);
	}
	return Plugin_Handled;
}
public Action:CommandSetScore(client, args)
{                           
        
	new String:arg1[32], String:arg2[20], String:arg3[20];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	new kills = StringToInt(arg2);
	new deaths = StringToInt(arg3);
                     	
	if (args != 3)
	{
		//ReplyToCommand(client, "\x01[ResetScore] Usage: sm_setscore <name or #userid> <Kills> <Deaths>");
		ReplyToCommand(client, "\x01[AbNeR ResetScore] %t", "Command SetScore");
		return Plugin_Handled;
	}
 	
	decl String:target_name[MAX_TARGET_LENGTH];
	new String:nameadm[MAX_NAME_LENGTH];
	GetClientName(client, nameadm, sizeof(nameadm));
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
	if ((target_count = ProcessTargetString(
	arg1,
	client,
	target_list,
	MAXPLAYERS,
	COMMAND_TARGET_NONE,
	target_name,
	sizeof(target_name),
	tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}


  	for (new i = 0; i < target_count; i++)
	{
		SetEntProp(target_list[i], Prop_Data, "m_iFrags", kills);
		SetEntProp(target_list[i], Prop_Data, "m_iDeaths", deaths);
	}
	
	if (tn_is_ml)
	{
		//ShowActivity2(client, "[ResetScore] ", "set score of %s to %d/%d.", target_name, kills, deaths);
		ShowActivity2(client, "[AbNeR ResetScore] ", "%t", "Set Score of", target_name, kills, deaths);
	}
	else
	{
		//ShowActivity2(client, "[ResetScore] ", "set score of %s to %d/%d.", target_name, kills, deaths);
		ShowActivity2(client, "[AbNeR ResetScore] ", "%t", "Set Score of", target_name, kills, deaths);
	}

	return Plugin_Handled;
}

public Action:CommandSetAssists(client, args)
{                           
        
	new String:arg1[32], String:arg2[20];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	new assists = StringToInt(arg2);
                     	
	if (args != 2)
	{
		//ReplyToCommand(client, "\x01[ResetScore] Usage: sm_setassists <name or #userid> <assists>");
		ReplyToCommand(client, "\x01[AbNeR ResetScore] %t", "Command SetAssists");
		return Plugin_Handled;
	}
 	
	decl String:target_name[MAX_TARGET_LENGTH];
	new String:nameadm[MAX_NAME_LENGTH];
	GetClientName(client, nameadm, sizeof(nameadm));
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
	if ((target_count = ProcessTargetString(
	arg1,
	client,
	target_list,
	MAXPLAYERS,
	COMMAND_TARGET_NONE,
	target_name,
	sizeof(target_name),
	tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}


  	for (new i = 0; i < target_count; i++)
	{   
		CS_SetClientAssists(target_list[i], assists);
	}

	if (tn_is_ml)
	{
		//ShowActivity2(client, "[ResetScore] ", "set assists of %s to %d.", target_name, assists);
		ShowActivity2(client, "[AbNeR ResetScore] ", "%t", "Set Assists of", target_name, assists);
	}
	else
	{
		//ShowActivity2(client, "[ResetScore] ", "set assists of %s to %d.", target_name, assists);
		ShowActivity2(client, "[AbNeR ResetScore] ", "%t", "Set Assists of", target_name, assists);
	}

	return Plugin_Handled;
}

public Action:CommandSetStars(client, args)
{                           
        
	new String:arg1[32], String:arg2[20];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	new stars = StringToInt(arg2);
                     	
	if (args != 2)
	{
		//ReplyToCommand(client, "\x01[ResetScore] Usage: sm_setstars <name or #userid> <stars>");
		ReplyToCommand(client, "\x01[AbNeR ResetScore] %t", "Command SetStars");
		return Plugin_Handled;
	}
 	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
	if ((target_count = ProcessTargetString(
	arg1,
	client,
	target_list,
	MAXPLAYERS,
	COMMAND_TARGET_NONE,
	target_name,
	sizeof(target_name),
	tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

  	for (new i = 0; i < target_count; i++)
	{
		CS_SetMVPCount(target_list[i], stars);
	}
	
	if (tn_is_ml)
	{
		//ShowActivity2(client, "[ResetScore] ", "set stars of %s to %d.", target_name, stars);
		ShowActivity2(client, "[AbNeR ResetScore] ", "%t", "Set Stars of", target_name, stars);
	}
	else
	{
		//ShowActivity2(client, "[ResetScore] ", "set stars of %s to %d.", target_name, stars);
		ShowActivity2(client, "[AbNeR ResetScore] ", "%t", "Set Stars of", target_name, stars);
	}

	return Plugin_Handled;
}