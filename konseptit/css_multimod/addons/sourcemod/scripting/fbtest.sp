#include <sourcemod>
#include <flashtools>

public Action:OnDeafen(client, &Float:time)
{
	//Dont "Deafen" anyone
	return Plugin_Handled;
}
public Action:OnGetPercentageOfFlashForPlayer(client, entity, Float:pos[3], &Float:percent)
{
	new owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	new team = GetClientTeam(client);
	new team2 = GetClientTeam(owner);
	//Dont team flash but flash the owner
	if(team == team2 && owner != client)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}
public Action:OnFlashDetonate(entity)
{
	new bool:cookies = false;
	
	//Stop Detonate
	if(cookies)
		return Plugin_Handled;
	
	return Plugin_Continue;
	
}