//Include file for Ultimate Mapchooser v2.5 by Steell.

#if defined _umc_included
    #endinput
#endif
#define _umc_included


/**
 * Called when a map's weight is being reweighted. Allows plugin to modify the
 * weight by calling UMC_AddWeightModifier.
 *
 * @param map   The name of the map we're reweighting.
 * @noreturn
 */
forward UMC_OnReweightMap(const String:map[]);


/**
 * Adds a MapWeightModifier to UMC's internal modifier list.
 *
 * @param func  MapWeightModifier function.
 * @noreturn
 */
native UMC_AddWeightModifier(Float:amt);


//SourceMod Malarky
public SharedPlugin:__pl_umc =
{
    name = "ultimate-mapchooser",
    file = "ultimate-mapchooser.smx",
#if defined REQIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

public __pl_umc_SetNTVOptional()
{
    MarkNativeAsOptional("UMC_AddWeightModifier");
}
