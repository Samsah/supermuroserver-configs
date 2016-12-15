#if defined _playersvotes_included
	#endinput
#endif
#define _playersvotes_included

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

/**
 * @param iClient			Client index.
 * @param strType			Type of vote to open. (Kick, Ban, Map, Mute)
 **/
native PlayersVotes_OpenVote(iClient, String:strType[]);

public SharedPlugin:__pl_playersvotes =
{
	name = "playersvotes",
	file = "playersvotes.smx",
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
	MarkNativeAsOptional("PlayersVotes_OpenVote");
}
#endif