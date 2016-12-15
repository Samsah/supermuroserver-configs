#if defined _gniecon_included
#endinput
#endif
#define _gniecon_included

/* Called before createing a econ item view
 * Return Plugin_Continue to create a econitem view based on the players loadout, anything else to bypass it and use the original GiveNameItem paramaters.
 *
 * @param client		Client the item is being given to.
 * @param iDefIndex		The definition index of the item.
 * @param iTeam			Clients team
 * @param iLoadoutSlot	Loadout slot for the given item. If -1 the item is not for the clients team. (ak47 for ct's for example)
 * @param szItem		Item string passed to GiveNameItem
 *
*/
forward Action:GNIEcon_OnGiveNamedItem(client, iDefIndex, iTeam, iLoadoutSlot, const String:szItem[]);

public Extension:__ext_gniecon =
{
	name = "csgo_gni_econ",
	file = "csgo_gni_econ.ext",
#if defined AUTOLOAD_EXTENSIONS
	autoload = 1,
#else
	autoload = 0,
#endif
#if defined REQUIRE_EXTENSIONS
	required = 1,
#else
	required = 0,
#endif
};
