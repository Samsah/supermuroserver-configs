
//-----------------------------------------------------------------------------
// Purpose: SMLib
//-----------------------------------------------------------------------------
stock bool:Entity_IsPlayer(entity)
{
	if (entity < 1 || entity > MaxClients) {
		return false;
	}
	
	return true;
}

stock Entity_GetTargetName(entity, String:buffer[], size)
{
	return GetEntPropString(entity, Prop_Data,  "m_iName", buffer, size);
}

stock Entity_SetTargetName(entity, const String:name[], any:...)
{
	decl String:format[128];
	VFormat(format, sizeof(format), name, 3);

	return DispatchKeyValue(entity, "target", format);
}

stock Entity_GetParentName(entity, String:buffer[], size)
{
	return GetEntPropString(entity, Prop_Data, "m_iParent", buffer, size);
}

stock Entity_SetParentName(entity, const String:name[], any:...)
{
	decl String:format[128];
	VFormat(format, sizeof(format), name, 3);

	return DispatchKeyValue(entity, "parentname", format);
}

stock Entity_GetHammerId(entity)
{	
	return GetEntProp(entity, Prop_Data, "m_iHammerID");
}