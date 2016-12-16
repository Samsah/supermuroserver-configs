/*
    SourceMod Anti-Cheat Constants
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

#define MAX_EDICTS 2048
#define MAX_ENTITIES 4096

#define SMAC_VERSION_CVNAME "smac_version"

//- Phrases -//

#define SMAC_TAG "SMAC_TAG"
#define SMAC_BANNED "SMAC_BANNED"
#define SMAC_GBANNED "SMAC_GBANNED"
#define SMAC_KCMDSPAM "SMAC_KCMDSPAM"
#define SMAC_FAILEDTOREPLY "SMAC_FAILEDTOREPLY"
#define SMAC_FAILEDAUTH "SMAC_FAILEDAUTH"
#define SMAC_CLIENTCORRUPT "SMAC_CLIENTCORRUPT"
#define SMAC_REMOVEPLUGINS "SMAC_REMOVEPLUGINS"
#define SMAC_HASPLUGIN "SMAC_HASPLUGIN"
#define SMAC_MUTED "SMAC_MUTED"
#define SMAC_HASNOTEQUAL "SMAC_HASNOTEQUAL"
#define SMAC_SHOULDEQUAL "SMAC_SHOULDEQUAL"
#define SMAC_HASNOTGREATER "SMAC_HASNOTGREATER"
#define SMAC_SHOULDGREATER "SMAC_SHOULDGREATER"
#define SMAC_HASNOTLESS "SMAC_HASNOTLESS"
#define SMAC_SHOULDLESS "SMAC_SHOULDLESS"
#define SMAC_HASNOTBOUND "SMAC_HASNOTBOUND"
#define SMAC_SHOULDBOUND "SMAC_SHOULDBOUND"
#define SMAC_CHANGENAME "SMAC_CHANGENAME"
#define SMAC_CBANNED "SMAC_CBANNED"
#define SMAC_SAYBLOCK "SMAC_SAYBLOCK"
#define SMAC_FORCEDREVAL "SMAC_FORCEDREVAL"
#define SMAC_CANNOTREVAL "SMAC_CANNOTREVAL"
#define SMAC_AIMBOTDETECTED "SMAC_AIMBOTDETECTED"
#define SMAC_SPINHACKDETECTED "SMAC_SPINHACKDETECTED"
#define SMAC_EYETESTDETECTED "SMAC_EYETESTDETECTED"
#define SMAC_WELCOMEMSG "SMAC_WELCOMEMSG"

//- Stocks -//

stock CopyVector(const Float:vec1[3], Float:vec2[3])
{
	vec2[0] = vec1[0];
	vec2[1] = vec1[1];
	vec2[2] = vec1[2];
}

stock bool:IsVectorNull(const Float:vec[3])
{
	if (vec[0] == 0.0 && vec[1] == 0.0 && vec[2] == 0.0)
		return true;
	
	return false;
}

stock bool:IsClientNew(client)
{
	/* Determine if it's a new client or one from a mapchange. */
	return IsFakeClient(client) || GetGameTime() > GetClientTime(client);
}

stock Float:GetClientPing(client)
{
	decl String:sRate[16];
	GetClientInfo(client, "cl_cmdrate", sRate, sizeof(sRate));

	new Float:fPing = GetClientAvgLatency(client, NetFlow_Outgoing);
	new Float:fTickRate = GetTickInterval();
	new iCmdRate = StringToInt(sRate);
	
	if (iCmdRate < 20)
		iCmdRate = 20;

	fPing -= 0.5 / iCmdRate + fTickRate;
	fPing -= fTickRate * 0.5;
	fPing *= 1000.0;

	return fPing;
}
