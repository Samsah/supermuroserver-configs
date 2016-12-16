//Fakesay: by Arg!

/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/
public SetupFakeSay()
{
	RegAdminCmd("sm_fakesay", Command_Fakesay, ADMFLAG_SLAY, "sm_fakesay <#userid|name> \"text\" - Specified client appears to say text");
}

/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/
public Action:Command_Fakesay(client,args)
{

	decl String:target[65];
	decl String:text[129];
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS];
	decl target_count;
	decl bool:tn_is_ml;
	
	if (args < 2)
	{
		ReplyToCommand(client, "sm_fakesay <#userid|name> \"text\"");
		return Plugin_Handled;
	}
	
	GetCmdArg(1, target, sizeof(target));
	GetCmdArg(2, text, sizeof(text) );	
	
	if ((target_count = ProcessTargetString(
			target,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_MULTI | COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	FakeClientCommandEx( target_list[0], "say %s", text );
	
	ReplyToCommand(client, "Made %s say '%s'", target_name[0], text);
	
	return Plugin_Handled; 
}