/**
* General weapon API.
*/

/**
* Maximum length of a weapon name string
*/
#define WEAPONS_MAX_LENGTH 32

/**
* Number of weapon slots (For CS:S)
*/
#define WEAPONS_SLOTS_MAX 5

/**
* Weapon slots.
*/
enum WeaponsSlot
{
	Slot_Invalid        = -1,   /** Invalid weapon (slot). */
	Slot_Primary        = 0,    /** Primary weapon slot. */
	Slot_Secondary      = 1,    /** Secondary weapon slot. */
	Slot_Melee          = 2,    /** Melee (knife) weapon slot. */
	Slot_Projectile     = 3,    /** Projectile (grenades, flashbangs, etc) weapon slot. */
	Slot_Explosive      = 4,    /** Explosive (c4) weapon slot. */
}

/**
* Checks if a client has a specific weapon.
* 
* @param client    The client index.
* @param weapon    The weapon classname.
*/
stock bool:WeaponsClientHasWeapon(client, const String:weapon[])
{
	// Get all of client's current weapons.
	new weapons[WeaponsSlot];
	WeaponsGetClientWeapons(client, weapons);
	
	decl String:classname[64];
	
	// x = slot index
	for (new x = 0; x < WEAPONS_SLOTS_MAX; x++)
	{
		// If slot is empty, then stop.
		if (weapons[x] == -1)
		{
			continue;
		}
		
		// If the weapon's classname matches, then return true.
		GetEdictClassname(weapons[x], classname, sizeof(classname));
		ReplaceString(classname, sizeof(classname), "weapon_", "");
		if (StrEqual(weapon, classname, false))
		{
			//CS_DropWeapon(client, weapons[x], true, true); 
			RemovePlayerItem(client, weapons[x])
			AcceptEntityInput(weapons[x], "Kill");
			return true;
		}
	}
	
	return false;
}

/**
* Return an array that contains all client's weapon indexes.
* 
* @param client    The client index.
* @param weapons   The weapon index array.
*                  -1 if no weapon in slot. 
*/
stock WeaponsGetClientWeapons(client, weapons[WeaponsSlot])
{
	// x = Weapon slot.
	for (new x = 0; x < WEAPONS_SLOTS_MAX; x++)
	{
		weapons[x] = GetPlayerWeaponSlot(client, x);
	}
}

/**
* Returns weapon index of the client's deployed weapon.
* 
* @param client    The client index.
* @return          The weapon index of the deployed weapon.
*                  -1 if no weapon is deployed. 
*/
stock WeaponsGetDeployedWeaponIndex(client)
{
	// Return the client's active weapon.
	return GetEntDataEnt2(client, offsActiveWeapon);
}

/**
* Returns slot of client's deployed weapon.
*
* @param client    The client index.
* @return          The slot number of deployed weapon.
*/
stock WeaponsSlot:WeaponsGetDeployedWeaponSlot(client)
{
	// Get all client's weapon indexes.
	new weapons[WeaponsSlot];
	WeaponsGetClientWeapons(client, weapons);
	
	// Get client's deployed weapon.
	new deployedweapon = WeaponsGetDeployedWeaponIndex(client);
	
	// If client has no deployed weapon, then stop.
	if (deployedweapon == -1)
	{
		return Type_Invalid;
	}
	
	// x = weapon slot.
	for (new x = 0; x < WEAPONS_SLOTS_MAX; x++)
	{
		if (weapons[x] == deployedweapon)
		{
			return WeaponsSlot:x;
		}
	}
	
	return Type_Invalid;
}
