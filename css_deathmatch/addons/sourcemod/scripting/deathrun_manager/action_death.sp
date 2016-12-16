public Action:DR_Action_Death(Handle:event, const String:name[], bool:dontBroadcast) {
	
	if (!GetConVarBool(dr_active))
		return Plugin_Continue;
	
	new victim	= GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (GetConVarBool(dr_fixfrags) && IsClientInGame(victim) && (attacker == 0 || attacker == victim))
		SetEntProp(victim, Prop_Data, "m_iFrags", GetClientFrags(victim) + 1);
	
	if (attacker > 0 && GetClientTeam(attacker) == CS_TEAM_T) {
		if (GetConVarBool(dr_nofragter) && IsClientInGame(victim) && attacker != victim) {
			SetEntProp(attacker, Prop_Data, "m_iFrags", GetClientFrags(attacker) + -1);
			NoGiveFragT = true;
		}
	}
		
	if (attacker > 0 && GetClientTeam(attacker) == CS_TEAM_CT) {
		if (GetConVarBool(dr_fragct)) {
			if (attacker != victim) {
				NoGiveFragCT = true;
			}
		}
	}
	
	if (attacker > 0 && attacker != victim && GetClientFrags(attacker) > GetConVarInt(dr_maxfrags) && GetConVarInt(dr_maxfrags) > 0)
		SetEntProp(attacker, Prop_Data, "m_iFrags", 0);
	
	if (GetConVarBool(dr_respawn) && RespawnTime)
	{
		Respawn[victim] = CreateTimer(1.0, RespawnPlayer, victim);
	}
	return Plugin_Continue;
}