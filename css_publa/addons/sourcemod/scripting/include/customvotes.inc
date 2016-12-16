#if defined _customvotes_included
	#endinput
#endif
#define _customvotes_included

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

/**
 * @param iClient			Client index.
 **/
native CustomVotes_OpenVote(iClient);

public SharedPlugin:__pl_playersvotes =
{
	name = "customvotes",
	file = "customvotes.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#if !defined REQUIRE_PLUGIN
public __pl_playersvotes_SetNTVOptional()
{
	MarkNativeAsOptional("CustomVotes_OpenVote");
}
#endif