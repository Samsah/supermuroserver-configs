#if defined _extendedcomm_included
  #endinput
#endif
#define _extendedcomm_included

public SharedPlugin:__pl_extendecomm = 
{
	name = "ExtendedComm",
	file = "sm_extendedcomm.smx",
	required = 0
};

public __pl_extendecomm_SetNTVOptional()
{
	MarkNativeAsOptional("ExtendedComm_GetMuteType");
	MarkNativeAsOptional("ExtendedComm_GetMuteLength");
	MarkNativeAsOptional("ExtendedComm_GetMuteStart");
	MarkNativeAsOptional("ExtendedComm_GetMuteExpire");
	MarkNativeAsOptional("ExtendedComm_GetGagType");
	MarkNativeAsOptional("ExtendedComm_GetGagLength");
	MarkNativeAsOptional("ExtendedComm_GetGagStart");
	MarkNativeAsOptional("ExtendedComm_GetGagExpire");
}

/*********************************************************
 * Returns the client's mute type
 *
 * @param client	The client index of the player to check mute status
 * @return          The client's current mute index.
 *********************************************************/
native ExtendedComm_GetMuteType(client);

/*********************************************************
 * Returns the duration of a client's mute.
 *
 * @param client	The client index of the player to check mute status
 * @return          The number of seconds of a client's mute
 *********************************************************/
native ExtendedComm_GetMuteLength(client);

/*********************************************************
 * Returns the time stamp for when a client's mute started
 *
 * @param client	The client index of the player to check
 * @return          The time stamp for mute issue
 *********************************************************/
native ExtendedComm_GetMuteStart(client);

/*********************************************************
 * Returns the time stamp for when a client's mute expires
 *
 * @param client	The client index of the player to check
 * @return          The time stamp for mute expiration
 *********************************************************/
native ExtendedComm_GetMuteExpire(client);

/*********************************************************
 * Returns the clietn's gag type
 *
 * @param client	The client index of the player to check gag status
 * @return          The client's current gag index	
 *********************************************************/
native ExtendedComm_GetGagType(client);

/*********************************************************
 * Returns the duration of a client's gag.
 *
 * @param client	The client index of the player to check gag status
 * @return          The number of seconds of a client's gag
 *********************************************************/
native ExtendedComm_GetGagLength(client);

/*********************************************************
 * Returns the time stamp for when a client's gag started
 *
 * @param client	The client index of the player to check
 * @return          The time stamp for gag issue
 *********************************************************/
native ExtendedComm_GetGagStart(client);

/*********************************************************
 * Returns the time stamp for when a client's gag expires
 *
 * @param client	The client index of the player to check
 * @return          The time stamp for gag expiration
 *********************************************************/
native ExtendedComm_GetGagExpire(client);