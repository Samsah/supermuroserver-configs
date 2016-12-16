#if defined _spraymanager_included
	#endinput
#endif
#define _spraymanager_included

/**
 * Ban a player from using sprays.
 * 
 * @param client					Client index.
 * @param delete					Delete the client's spray if it's there?
 * @error					Throw error if client is invalid/already spray banned.
 * @noreturn
 */
native SprayManager_BanClient(client, bool:delete = true);

/**
 * Unban a spray banned player from using sprays.
 * 
 * @param client					Client index.
 * @error					Throw error if client is invalid/not banned.
 * @noreturn
 */
native SprayManager_UnbanClient(client);

/**
 * Check if the client is spray banned.
 * 
 * @param client		Client index
 * @error					Throw error if client is invalid.
 * @return 				True if spray banned, false otherwise.
 */
native SprayManager_IsBanned(client);

/**
 * Called when a client gets spray banned.
 *
 * @param client		Client index
 *
 * @noreturn
 */
forward SprayManager_OnBan(client);

/**
 * Called when a client gets spray unbanned.
 *
 * @param client		Client index
 *
 * @noreturn
 */
forward SprayManager_OnUnban(client);

public SharedPlugin:__pl_ranking =
{
	name = "spraymanager",
	file = "spraymanager.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};

public __pl_ranking_SetNTVOptional()
{
	MarkNativeAsOptional("SprayManager_BanClient");
	MarkNativeAsOptional("SprayManager_UnbanClient");
	MarkNativeAsOptional("SprayManager_IsBanned");
}