// File:   top.sp
// Author: ]SoD[ Frostbyte

#include "sodstats\include\sodstats.inc"

PrintTop(client, start = 1, offset = 10)
{
	new Handle:panel = CreatePanel();
	DrawPanelText(panel, "[SoD-Stats] Top ten players");
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, any:panel);
	WritePackCell(pack, client);
	Stats_GetPlayersByRank(start, offset, TopCallback, any:pack);
}

public TopCallback(const String:name[], const String:steamid[], any:stats[], any:data, index)
{
	new Handle:pack = data;
	ResetPack(pack);
	new Handle:panel = Handle:ReadPackCell(pack);
	new client       = ReadPackCell(pack);
	
	if(steamid[0] == 0)	// last call
	{
		CloseHandle(pack);
		SendPanelToClient(panel, client, TopHandler, 10);
		CloseHandle(panel);
	}
	else
	{
		decl String:text[256];
		if(index > 3)
		{
			Format(text, sizeof(text), "%i. %s - %.2f KD - %i points ", 
									   index,
									   name, 
									   float(stats[STAT_KILLS])/ 
									   (stats[STAT_DEATHS] == 0 ? 
									    1.0 : float(stats[STAT_DEATHS])), 
									    stats[STAT_SCORE] + g_start_points);
			DrawPanelText(panel, text);
		}
		else
		{
			Format(text, sizeof(text), "%s - %.2f KD - %i points ", 
									   name, 
									   float(stats[STAT_KILLS])/ 
									   (stats[STAT_DEATHS] == 0 ? 
									    1.0 : float(stats[STAT_DEATHS])), 
									    stats[STAT_SCORE] + g_start_points);
			DrawPanelItem(panel, text);
		}
	}
}

public TopHandler(Handle:menu, MenuAction:action, param1, param2)
{
}
