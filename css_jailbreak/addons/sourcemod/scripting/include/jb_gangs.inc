// Double include protection
#if defined _jb_gangs_included_
	#endinput
#endif
#define _jb_gangs_included_

public SharedPlugin:__pl_jb_cash =
{
	name = "jb_gangs",
	file = "jb_gangs.smx",
	required = 0,
};

/**
 * Removes points from a player.
 *
 * @param iClient, The client you are modifying points for.
 * @param iAmount, The amount of points you are removing.
**/
native bool:JBG_RemPoints(iClient, iAmount);

/**
 * Adds points to a player.
 *
 * @param iClient, The client you are modifying points for.
 * @param iAmount, The amount of points you are adding.
**/
native bool:JBG_AddPoints(iClient, iAmount);

public __pl_perks_SetNTVOptional()
{
	MarkNativeAsOptional("JBG_RemPoints");
	MarkNativeAsOptional("JBG_AddPoints");
}