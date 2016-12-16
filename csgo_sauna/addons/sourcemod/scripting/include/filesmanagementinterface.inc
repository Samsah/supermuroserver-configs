//2nd version of this file (includes the 2 structs at the end)
//===== GetRandoms

/**
* Get a random sound in the specified folder.
* The sound file will have one of the extensions 
* specified by the ConVar 'fmi_fileext_sound'.
* 'folder' and 'outStr' can be the same buffer.
*
* @param folder		Folder where to take a random sound
*					Relative to the /sound/ folder.
*					You have to remove the '/'
* @param outStr		Output buffer to put the sound filepath
* @param sizeStr	Size of the output buffer
*
* @return if a sound filepath was successful put in the outStr buffer
*/
native bool:FMI_GetRandomSound( const String:folder[], String:outStr[], const sizeStr );

/**
* Get a random model in the specified folder.
* The model file will have one of the extensions 
* specified by the ConVar 'fmi_fileext_model'.
* 'folder' and 'outStr' can be the same buffer.
*
* @param folder		Folder where to take a random model
* @param outStr		Output buffer to put the model filepath
* @param sizeStr	Size of the output buffer
*
* @return if a model filepath was successful put in the outStr buffer
*/
native bool:FMI_GetRandomModel( const String:folder[], String:outStr[], const sizeStr );

/**
* Get a random decal in the specified folder.
* The decal file will have one of the extensions 
* specified by the ConVar 'fmi_fileext_decal'.
* 'folder' and 'outStr' can be the same buffer.
*
* @param folder		Folder where to take a random decal
* @param outStr		Output buffer to put the decal filepath
* @param sizeStr	Size of the output buffer
*
* @return if a decal filepath was successful put in the outStr buffer
*/
native bool:FMI_GetRandomDecal( const String:folder[], String:outStr[], const sizeStr );

/**
* Get a random generic in the specified folder.
* The generic file will have one of the extensions 
* specified by the ConVar 'fmi_fileext_generic'.
* 'folder' and 'outStr' can be the same buffer.
*
* @param folder		Folder where to take a random generic
* @param outStr		Output buffer to put the generic filepath
* @param sizeStr	Size of the output buffer
*
* @return if a generic filepath was successful put in the outStr buffer
*/
native bool:FMI_GetRandomGeneric( const String:folder[], String:outStr[], const sizeStr );

/**
* Get a random file in the specified folder.
* The custom file will have the specified extension. 
* 'folder' and 'outStr' can be the same buffer.
*
* @param folder				Folder where to take a random custom file
* @param fileExtension		Get a random custom file with that extension
*							Example : ".txt"
* @param outStr				Output buffer to put the custom file filepath
* @param sizeStr			Size of the output buffer
*
* @return if a custom filepath was successful put in the outStr buffer
*/
native bool:FMI_GetRandomCustom( const String:folder[], const String:fileExtensions[], String:outStr[], const sizeStr );

//===== Precache folder

/**
* Precache a whole folder of sounds.
* Also adds to download table.
*
* Should mostly be used OnMapStart or OnConfigsExecuted.
* 
* @param folder			Folder with files to precache
*						You should add the 'sound/' prefix
* @param fileExtensions	Files with one of those extensions will be
*						precached. If empty,
*						the ones in 'fmi_fileext_sound'
*						will be taken. Separate extensions
*						with spaces.
* @param recurse		If the function should be recursive.
*						This means that subfolders will also
*						have their sounds precached
* @return				Number of files precached, 
*						-1 if can't open folder
*/
native FMI_PrecacheSoundsFolder( const String:folder[], const String:fileExtensions[]="", bool:recurse=false );

/**
* Precache a whole folder of models.
* Also adds to download table.
*
* Don't forget to also add the model helper files if needed,
* using FMI_AddFolderToDownloadTable.
*
* Should mostly be used OnMapStart or OnConfigsExecuted.
* 
* @param folder			Folder with files to precache
* @param fileExtensions	Files with one of those extensions will be
*						precached. If empty,
*						the ones in 'fmi_fileext_model'
*						will be taken. Separate extensions
*						with spaces.
* @param recurse		If the function should be recursive.
*						This means that subfolders will also
*						have their models precached
* @return				Number of files precached, 
*						-1 if can't open folder
*/
native FMI_PrecacheModelsFolder( const String:folder[], const String:fileExtensions[]="", bool:recurse=false );

/**
* Precache a whole folder of decals.
* Also adds to download table.
*
* Don't forget to also add the decal helper files if needed,
* using FMI_AddFolderToDownloadTable.
*
* Should mostly be used OnMapStart or OnConfigsExecuted.
* 
* @param folder			Folder with files to precache
* @param fileExtensions	Files with one of those extensions will be
*						precached. If empty,
*						the ones in 'fmi_fileext_decal'
*						will be taken. Separate extensions
*						with spaces.
* @param recurse		If the function should be recursive.
*						This means that subfolders will also
*						have their models precached
* @return				Number of files precached, 
*						-1 if can't open folder
*/
native FMI_PrecacheDecalsFolder( const String:folder[], const String:fileExtensions[]="", bool:recurse=false );

/**
* Precache a whole folder of generics.
* Also adds to download table.
*
* Should mostly be used OnMapStart or OnConfigsExecuted.
* 
* @param folder			Folder with files to precache
* @param fileExtensions	Files with one of those extensions will be
*						precached. If empty,
*						the ones in 'fmi_fileext_generic'
*						will be taken. Separate extensions
*						with spaces.
* @param recurse		If the function should be recursive.
*						This means that subfolders will also
*						have their generics precached
* @return				Number of files precached, 
*						-1 if can't open folder
*/
native FMI_PrecacheGenericsFolder( const String:folder[], const String:fileExtensions[]="", bool:recurse=false );

/**
* Adds a whole folder to download table.
*
* It is recommended to specify the file extensions (2nd arg).
* 
* @param folder			Folder with files to download
* @param fileExtensions	Files with one of those extensions will be
*						added to the download table. If empty,
*						the ones in 'fmi_fileext_downloadonly'
*						will be taken. Separate extensions
*						with spaces.
* @param recurse		If the function should be recursive.
*						This means that subfolders will also
*						have their files downloaded
* @return				Number of files added to download table, 
*						-1 if can't open folder
*/
native FMI_AddToDownloadTableFolder( const String:folder[], const String:fileExtensions[]="", bool:recurse=false );

/**
* Register a whole folder to the interface so a random element can be access later.
*
* This is used for files that doesn't need to be precached/downloaded.
* i.e. for plugins willing to load a random .cfg / .ini
*
* It is recommended to specify the file extensions (2nd arg).
* 
* @param folder			Folder with files to register
* @param fileExtensions	Files with one of those extensions will be
*						added to the download table. If empty,
*						the ones in 'fmi_fileext_nodownload'
*						will be taken. Separate extensions
*						with spaces.
* @param recurse		If the function should be recursive.
*						This means that subfolders will also
*						have their files registered to the interface
* @return				Number of files registered to the interface, 
*						-1 if can't open folder
*/
native FMI_RegisterFolder( const String:folder[], const String:fileExtensions[]="", bool:recurse=false );

//=====================================================
//DO NOT EDIT BELOW THIS LINE ^ (unless you're a muscled Duck)
public SharedPlugin:__pl_filesmanagementinterface = 
{
	name = "filesmanagementinterface",
	file = "filesmanagementinterface.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
public __pl_filesmanagementinterface_SetNTVOptional()
{
	//Randoms
	MarkNativeAsOptional("FMI_GetRandomSound");
	MarkNativeAsOptional("FMI_GetRandomModel");
	MarkNativeAsOptional("FMI_GetRandomDecal");
	MarkNativeAsOptional("FMI_GetRandomGeneric");
	MarkNativeAsOptional("FMI_GetRandomCustom");
	
	//Precache & DL
	MarkNativeAsOptional("FMI_PrecacheSoundsFolder");
	MarkNativeAsOptional("FMI_PrecacheModelsFolder");
	MarkNativeAsOptional("FMI_PrecacheDecalsFolder");
	MarkNativeAsOptional("FMI_PrecacheGenericsFolder");
	MarkNativeAsOptional("FMI_AddToDownloadTableFolder");
	MarkNativeAsOptional("FMI_RegisterFolder");
}