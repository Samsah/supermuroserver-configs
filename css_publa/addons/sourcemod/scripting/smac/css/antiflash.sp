/*
	SourceMod Anti-Cheat AntiFlash Module
	Copyright (C) 2011 GoD-Tony
	Copyright (C) 2007-2011 CodingDirect LLC

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

//- Global Variables -//

new Handle:g_hCVarAntiFlash = INVALID_HANDLE;
new bool:g_bFlashEnabled;

new Float:g_fFlashedUntil[MAXPLAYERS+1];
new bool:g_bFlashHooked;

new g_iFlashDuration = -1;
new g_iFlashAlpha = -1;

//- Plugin Functions -//

AntiFlash_OnPluginStart()
{
	if (g_Game != Game_CSS)
		return;
		
	g_hCVarAntiFlash = CreateConVar("smac_css_antiflash", "1", "(CS:S Only) Prevent No-Flash cheats from working when a player is fully blind");
	
	AntiFlash_CvarChange(g_hCVarAntiFlash, "", "");
	HookConVarChange(g_hCVarAntiFlash, AntiFlash_CvarChange);
}

AntiFlash_OnClientDisconnect(client)
{
	g_fFlashedUntil[client] = 0.0;
}

public AntiFlash_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new bool:bNewValue = GetConVarBool(convar);

	if (bNewValue && !g_bFlashEnabled)
	{
		if (!g_bSDKHooksLoaded)
		{
			LogError("SDKHooks is not running. Cannot enable CS:S Anti-Flash.");
			SetConVarBool(convar, false);
			return;
		}
		
		AntiFlash_Enable();
	}
	else if (!bNewValue && g_bFlashEnabled)
	{
		AntiFlash_Disable();
	}
}

public AntiFlash_PlayerBlind(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	new Float:duration = GetEntDataFloat(client, g_iFlashDuration);
	new Float:alpha = GetEntDataFloat(client, g_iFlashAlpha);
	
	if (client && alpha == 255.0 && !g_bIsFake[client] && IsPlayerAlive(client))
	{
		// Important: Find a better way to determine the time of a fully blind player.
		if (duration > 2.5)
			g_fFlashedUntil[client] = GetGameTime() + duration - 2.5;
		else
			g_fFlashedUntil[client] = GetGameTime() + duration * 0.1;
		
		if (!g_bFlashHooked)
			AntiFlash_HookAll();
			
		CreateTimer(duration, AntiFlash_FlashEndTimer);
	}
}

public Action:AntiFlash_FlashEndTimer(Handle:timer)
{
	/* Check if there are any other flashes being processed. Otherwise, we can unhook. */
	new Float:fGameTime = GetGameTime();
	
	for (new i = 1; i <= MaxClients; i++)
		if (g_fFlashedUntil[i] > fGameTime)
			return Plugin_Stop;
	
	if (g_bFlashHooked)
		AntiFlash_UnhookAll();
	
	return Plugin_Stop;
}

public Action:AntiFlash_Transmit(entity, client)
{
	/* Don't send client data to players that are fully blind. */
	if (client < 1 || client > MaxClients || entity == client)
		return Plugin_Continue;
	
	if (g_fFlashedUntil[client] && g_fFlashedUntil[client] > GetGameTime())
		return Plugin_Handled;
	
	g_fFlashedUntil[client] = 0.0;
	return Plugin_Continue;
}

AntiFlash_Enable()
{
	g_bFlashEnabled = true;
	HookEvent("player_blind", AntiFlash_PlayerBlind, EventHookMode_Post);
	
	if ((g_iFlashDuration = FindSendPropOffs("CCSPlayer", "m_flFlashDuration")) == -1)
		LogError("AntiFlash: Failed to find CCSPlayer::m_flFlashDuration offset");
	
	if ((g_iFlashAlpha = FindSendPropOffs("CCSPlayer", "m_flFlashMaxAlpha")) == -1)
		LogError("AntiFlash: Failed to find CCSPlayer::m_flFlashMaxAlpha offset");
}

AntiFlash_Disable()
{
	g_bFlashEnabled = false;
	UnhookEvent("player_blind", AntiFlash_PlayerBlind, EventHookMode_Post);
	
	g_iFlashDuration = -1;
	g_iFlashAlpha = -1;
}

AntiFlash_HookAll()
{
	g_bFlashHooked = true;
	
	for (new i = 1; i <= MaxClients; i++)
		if (g_bInGame[i])
			SDKHook(i, SDKHook_SetTransmit, AntiFlash_Transmit);
}

AntiFlash_UnhookAll()
{
	g_bFlashHooked = false;

	for (new i = 1; i <= MaxClients; i++)
		if (g_bInGame[i])
			SDKUnhook(i, SDKHook_SetTransmit, AntiFlash_Transmit);
}

//- EoF -//
