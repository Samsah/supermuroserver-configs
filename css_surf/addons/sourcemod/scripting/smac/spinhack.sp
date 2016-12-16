/*
	SourceMod Anti-Cheat SpinHack Module
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

#define SPIN_DETECTIONS		15		// Seconds of non-stop spinning before spinhack is detected
#define SPIN_ANGLE_CHANGE	1440	// Max angle deviation over one second before being flagged
#define SPIN_SENSITIVITY	6		// Ignore players with a higher mouse sensitivity than this

//- Global Variables -//

new Handle:g_hCVarSpinHack = INVALID_HANDLE;
new Handle:g_hSpinLoop = INVALID_HANDLE;
new bool:g_bSpinHackEnabled;
new g_iSpinHackMode, g_iSpinCount[MAXPLAYERS+1];

new Float:g_fPrevAngle[MAXPLAYERS+1], Float:g_fAngleDiff[MAXPLAYERS+1], Float:g_fAngleBuffer;
new Float:g_fSensitivity[MAXPLAYERS+1];

//- Plugin Functions -//

SpinHack_OnPluginStart()
{
	g_hCVarSpinHack = CreateConVar("smac_spinhack", "1", "SpinHack detection module. (0 = Disabled, 1 = Warn Admins)", FCVAR_PLUGIN);
	
	SpinHack_CvarChange(g_hCVarSpinHack, "", "");
	HookConVarChange(g_hCVarSpinHack, SpinHack_CvarChange);
}

SpinHack_OnClientDisconnect(client)
{
	g_iSpinCount[client] = 0;
	g_fSensitivity[client] = 0.0;
}

public SpinHack_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iSpinHackMode = GetConVarInt(convar);

	if (g_iSpinHackMode && !g_bSpinHackEnabled)
		SpinHack_Enable();
	else if (!g_iSpinHackMode && g_bSpinHackEnabled)
		SpinHack_Disable();
}

public Action:SpinHack_CheckSpins(Handle:timer)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!g_bInGame[i] || g_bIsFake[i])
			continue;
		
		if (g_fAngleDiff[i] > SPIN_ANGLE_CHANGE && IsPlayerAlive(i))
		{
			g_iSpinCount[i]++;
			
			if (g_iSpinCount[i] == 1)
				QueryClientConVar(i, "sensitivity", SpinHack_MouseCheck, GetClientUserId(i));
				
			if (g_iSpinCount[i] == SPIN_DETECTIONS && g_fSensitivity[i] <= SPIN_SENSITIVITY)
				SpinHack_Detected(i);
		}
		else
			g_iSpinCount[i] = 0;
		
		g_fAngleDiff[i] = 0.0;
	}
	
	return Plugin_Continue;
}

public SpinHack_MouseCheck(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[], any:userid)
{
	if (GetClientOfUserId(userid) != client || StrEqual(cvarValue, ""))
		return;
	
	g_fSensitivity[client] = StringToFloat(cvarValue);
}

SpinHack_OnPlayerRunCmd(client, buttons, Float:angles[3])
{
	if (!g_bSpinHackEnabled || buttons & IN_LEFT || buttons & IN_RIGHT)
		return;
	
	// Only checking the Z axis here.
	g_fAngleBuffer = FloatAbs(angles[1] - g_fPrevAngle[client]);
	g_fAngleDiff[client] += (g_fAngleBuffer > 180) ? (g_fAngleBuffer - 360) * -1 : g_fAngleBuffer;
	g_fPrevAngle[client] = angles[1];
}

SpinHack_Detected(client)
{
	new String:f_sName[64], String:f_sAuthID[64], String:f_sIP[64];
	GetClientName(client, f_sName, sizeof(f_sName));
	GetClientAuthString(client, f_sAuthID, sizeof(f_sAuthID));
	GetClientIP(client, f_sIP, sizeof(f_sIP));
	
	SMAC_PrintToChatAdmins("%t", SMAC_SPINHACKDETECTED, f_sName);
	SMAC_Log("%N (ID: %s | IP: %s) is suspected of using a spinhack.", client, f_sAuthID, f_sIP);
	
	/*
	switch (g_iSpinHackMode)
	{
		case 1: // Log.
		{
			SMAC_Log("%N (ID: %s | IP: %s) is suspected of using a spinhack.", client, f_sAuthID, f_sIP);
		}
		case 2: // Ban.
		{
			SMAC_Log("%N (ID: %s | IP: %s) was banned for using a spinhack.", client, f_sAuthID, f_sIP);
			SMAC_Ban(client, g_iBanDuration, SMAC_BANNED, "SMAC: SpinHack Detected");
		}
	}
	*/
}

SpinHack_Enable()
{
	g_bSpinHackEnabled = true;
	
	if (g_hSpinLoop == INVALID_HANDLE)
		g_hSpinLoop = CreateTimer(1.0, SpinHack_CheckSpins, _, TIMER_REPEAT);
}

SpinHack_Disable()
{
	g_bSpinHackEnabled = false;
	
	if (g_hSpinLoop != INVALID_HANDLE)
	{
		KillTimer(g_hSpinLoop);
		g_hSpinLoop = INVALID_HANDLE;
	}
}

//- EoF -//
