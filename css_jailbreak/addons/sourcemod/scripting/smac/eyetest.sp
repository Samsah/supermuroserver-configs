/*
	SourceMod Anti-Cheat Eye Test Module
	Copyright (C) 2011 GoD-Tony
	Copyright (C) 2011 Nicholas "psychonic" Hastings (nshastings@gmail.com)
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

new Handle:g_hCVarEyeTest = INVALID_HANDLE;
new g_iEyeTestMode;
new Float:g_bEyeDetectedTime[MAXPLAYERS+1];

//- Plugin Functions -//

Eyetest_OnPluginStart()
{
	g_hCVarEyeTest = CreateConVar("smac_eyetest", "1", "Enable the eye test detection routine. (0 = Disabled, 1 = Warn Admins, 2 = Ban)", FCVAR_PLUGIN);
	
	Eyetest_CvarChange(g_hCVarEyeTest, "", "");
	HookConVarChange(g_hCVarEyeTest, Eyetest_CvarChange);
}

Eyetest_OnClientDisconnect_Post(client)
{
	g_bEyeDetectedTime[client] = 0.0;
}

public Eyetest_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iEyeTestMode = GetConVarInt(convar);
}

Eyetest_OnPlayerRunCmd(client, Float:angles[3])
{
	if (!g_iEyeTestMode)
		return;
	
	switch (g_Game)
	{
		// Ignore prone players.
		case Game_DOD:
		{
			if (bool:GetEntProp(client, Prop_Send, "m_bProne")
			|| GetEntPropFloat(client, Prop_Send, "m_flGoProneTime") > 0.0
			|| GetEntPropFloat(client, Prop_Send, "m_flUnProneTime") > 0.0)
				return;
		}
		
		// Only monitor survivors.
		case Game_L4D, Game_L4D2:
		{
			if (GetClientTeam(client) != 2)
				return;
		}
	}
	
	// +/- normal limit * 1.5 as a buffer zone.
	if ( (angles[0] > 135.0 || angles[0] < -135.0 || angles[1] > 270.0 || angles[1] < -270.0)
		&& IsPlayerAlive(client) && !(GetEntityFlags(client) & FL_ATCONTROLS) )
		Eyetest_Detected(client, angles);
}

Eyetest_Detected(client, Float:angles[3])
{
	// Allow the same player to be processed once every 30 seconds.
	if (g_bEyeDetectedTime[client] && g_bEyeDetectedTime[client] > GetGameTime())
		return;
	
	g_bEyeDetectedTime[client] = GetGameTime() + 30.0;
	
	new String:f_sName[64], String:f_sAuthID[64], String:f_sIP[64];
	
	// Strict checking for this module until the issue of overlapping cmds being sent is resolved.
	if ( !GetClientName(client, f_sName, sizeof(f_sName))
		|| !GetClientAuthString(client, f_sAuthID, sizeof(f_sAuthID))
		|| !GetClientIP(client, f_sIP, sizeof(f_sIP)) )
		return;
		
	if (StrEqual(f_sAuthID, "") || StrEqual(f_sAuthID, "BOT"))
		return;
	
	SMAC_PrintToChatAdmins("%t", SMAC_EYETESTDETECTED, f_sName);
	
	switch (g_iEyeTestMode)
	{
		case 1: // Log.
		{
			SMAC_Log("%N (ID: %s | IP: %s) is suspected of cheating with their eye angles. Eye Angles: %.0f %.0f %.0f", client, f_sAuthID, f_sIP, angles[0], angles[1], angles[2]);
			
		}
		case 2: // Ban.
		{
			SMAC_Log("%N (ID: %s | IP: %s) was banned for cheating with their eye angles. Eye Angles: %.0f %.0f %.0f", client, f_sAuthID, f_sIP, angles[0], angles[1], angles[2]);
			SMAC_Ban(client, g_iBanDuration, SMAC_BANNED, "SMAC: Eye Angles Violation");
		}
	}
}
