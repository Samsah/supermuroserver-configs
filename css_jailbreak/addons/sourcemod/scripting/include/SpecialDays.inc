/** Include File for Special days **/
#if defined _SpecialDays_Included_
	#endinput
#endif
#define _SpecialDays_Included_

public SharedPlugin:__pl_specialdays =
{
        name = "SpecialDays",
        file = "SpecialDays.smx",
#if defined REQUIRE_PLUGIN
        required = 1,
#else
        required = 0,
#endif
};

public __pl_specialdays_SetNTVOptional()
{
        MarkNativeAsOptional("IsSpecialDay");
}

/**
 * Returns whether the day is marked as special.
 *
 * @return			True/False
 */
native bool:IsSpecialDay();