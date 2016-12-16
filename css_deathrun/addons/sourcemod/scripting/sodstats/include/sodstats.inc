// File:   sodstats.inc
// Author: ]SoD[ Frostbyte

#if defined _sodstats_included_
  #endinput
#endif
#define _sodstats_included_

public SharedPlugin:__pl_sodstats = 
{
	name = "sodstats", 
	file = "sodstats.smx", 
#if defined REQUIRE_PLUGIN
	required = 1 
#else
	required = 0
#endif
};

#define STAT_SCORE       0
#define STAT_KILLS       1
#define STAT_DEATHS      2
#define STAT_HITS        3
#define STAT_SHOTS       4
#define STAT_TIME_PLAYED 5
#define STAT_HEADSHOTS   6

#define MAX_STATS        7

#define ERROR_PLAYER_NOT_FOUND 1

public Handle:stats_db;

public __pl_sodstats_SetNTVOptional()
{
	MarkNativeAsOptional("Stats_ReadPlayerSession");
	MarkNativeAsOptional("Stats_ReadPlayersByRank");
	MarkNativeAsOptional("Stats_ReadPlayerById");
	MarkNativeAsOptional("Stats_ReadPlayerBySteamId");
	MarkNativeAsOptional("Stats_Reset");
}

funcenum StatsCallback
{
	public(const String:name[], const String:steamid[], any:stats[], any:data, retval),
	public(rank, delta, any:data, error)
};

/**
 * Retrieve a player's session stats.  (No SQL queries)
 *
 * @param client		User-ID of the client whose session to fetch.
 * @param callback		Callback to return session data. (uses first StatsCallback definition)
 * @param data			Data to pass to callback.
 * @return				NULL
 */
native bool:Stats_GetPlayerSession(client, StatsCallback:callback, any:data = 0);

/**
 * Retrieve player's stats, starting at 'rank' and continuing down 
 * 'count' players.  Callback is called once for each player, in 
 * order of best (lowest) rank to highest (worst) rank.  Once all 
 * players are processed, calls callback with a blank steamid.  
 * (One SQL query)
 * 
 *
 * @param rank			Starting rank to fetch.
 * @param count         Number of players to fetch.
 * @param callback		Callback to return stats (uses first StatsCallback definition).
 * @param data			Data to pass to callback.
 * @return				NULL
 */
native bool:Stats_GetPlayersByRank(rank, count, StatsCallback:callback, any:data = 0);

/**
 * Retrieve a player's stats.  (No SQL query)
 *
 * @param client		User-ID of the client whose rank to fetch.
 * @param callback		Callback to return player stats (uses second StatsCallback definition).
 * @param data			Data to pass to callback.
 * @return				NULL
 */
native bool:Stats_GetPlayerById(client, StatsCallback:callback, any:data = 0);

/**
 * Retrieve a player's stats.  (One SQL query)
 *
 * @param steamid		Steam-ID of the client whose rank to fetch.
 * @param callback		Callback to return player stats (uses second StatsCallback definition).
 * @param data			Data to pass to callback.
 * @return				NULL
 */
native bool:Stats_GetPlayerBySteamId(const String:steamid[], StatsCallback:callback, any:data = 0);

/**
 * Retrieve a player's rank.  (One SQL query)
 *
 * @param client		User-ID of the client whose rank to fetch.
 * @param callback		Callback to return the rank (uses second StatsCallback definition).
 * @param data			Data to pass to callback.
 * @return				NULL
 */
native bool:Stats_GetPlayerRank(client, StatsCallback:callback, any:data = 0);

/**
 * Retrieve number of stored players in database.  (One SQL query)
 *
 * @return Count of stored players.  
 */
native Stats_GetPlayerCount();

/**
 * Retrieve current Game-ID. (No SQL queries)
 *
 * @return ID_CSS, ID_DOD, ID_TF2
 */
native Stats_GetGameId();

/**
 * Reset stats and session information. (Two SQL queries, not thread safe)
 *
 * @return NULL
 */
native bool:Stats_Reset();
