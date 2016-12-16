
#if defined _SteamWorks_included
 #endinput
#endif
#define _SteamWorks_included


forward SW_OnValidateClient(OwnerID, ClientID);

public Extension:__ext_SteamWorks = 
{
	name = "SteamWorks",
	file = "SteamWorks.ext",
	
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
