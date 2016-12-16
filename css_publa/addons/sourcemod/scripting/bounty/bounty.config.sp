/**
 * ===============================================================
 * Bounty: A Comprehensive Bounty Script, Copyright (C) 2007
 * All rights reserved.
 * ===============================================================
 *
 *	This program is free software; you can redistribute it and/or
 *	modify it under the terms of the GNU General Public License
 *	as published by the Free Software Foundation; either version 2
 *	of the License, or (at your option) any later version.

 *	This program is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; w1ithout even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with this program; if not, write to the Free Software
 *	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 *	To view the latest information, see: http://forums.alliedmods.net/showthread.php?t=56939
 *		Author(s):	Shane A. ^BuGs^ Froebel - Current maintainer
 *  				FlyingMongoose - Started the Sourcemod script/Idea man
 *					stoic - Worked on what FlyingMongoose started
 *
 *	Credit: #sourcemod on irc.gamesurge.com (teame06, Olly)
 *	Original Idea and concepts of Bounty made by:	firesnake´s Bounty Mod 
 *													Pascal257 Remake of firesnake's
 *
 *
 *	File: scripting/bounty/bounty.config.sp
 *	SVN ID: $Id: bounty.config.sp 64 2007-07-22 17:18:19Z bugs $
 *
 **/

public OnConfigsExecuted()
{
	ReadConfig();
	
	plugin_Ads = LibraryExists("ads");
	plugin_IrcRelay = LibraryExists("ircrelay");
	
	BountyConsole_Debug("Loading Ads: %i Loading IRC: %i", plugin_Ads, plugin_IrcRelay);
	
	if ((BountyAds) && (plugin_Ads))
	{	
		if (Format_Add_Ad("%t", "Create a Bounty"))
		{
			BountyConsole_Debug("%t", "Bounty Ad Message Added");
		}
	}
	
	if ((BountyIRC) && (plugin_IrcRelay) && (!BountyIRCLoaded))
	{
		BountyIRCLoaded = true;
		RegisterIrcCommand("!bounty", "x", Irc_ViewBounty);
		IrcMessage(CHAN_MASTER, "IRC Bounty Running!");
	} else {
		if ((BountyIRC) && (!plugin_IrcRelay))
		{
			BountyConsole_Debug("%t", "Bounty IRC Relay failed");
		}
	}

	BountyConsole_Server("%t %t %s :: By Shane A. ^BuGs^ Froebel", "Bounty done loading", "Bounty version", BOUNTY_VERSION);
}

public OnLibraryRemoved(const String:name[])
{
	if (strcmp("ads", name, true) == 0)
	{
		plugin_Ads = false;
	}
	if (strcmp("ircrelay", name, true) == 0)
	{
		plugin_IrcRelay = false;
		BountyIRCLoaded = false;
	}
}
 
public OnLibraryAdded(const String:name[])
{
	if (strcmp("ads", name, true) == 0)
	{
		plugin_Ads = true;
	}
	if (strcmp("ircrelay", name, true) == 0)
	{
		plugin_IrcRelay = true;
	}
}

public ReadConfig()
{

	ConfigParser = SMC_CreateParser();

	SMC_SetParseEnd(ConfigParser, ReadConfig_ParseEnd);
	SMC_SetReaders(ConfigParser, ReadConfig_NewSection, ReadConfig_KeyValue, ReadConfig_EndSection);

	decl String:DefaultFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, DefaultFile, sizeof(DefaultFile), "configs\\bounty\\plugin.bounty.cfg");
	if(FileExists(DefaultFile))
	{
		PrintToServer("[BOUNTY] Loading %s config file", DefaultFile);
	} else {
		decl String:Error[PLATFORM_MAX_PATH + 64];
		FormatEx(Error, sizeof(Error), "[BOUNTY] FATAL *** ERROR *** can not find %s", DefaultFile);
		SetFailState(Error);
	}
	
	new SMCError:err = SMC_ParseFile(ConfigParser, DefaultFile);

	if (err != SMCError_Okay)
	{
		decl String:buffer[64];
		if (!SMC_GetErrorString(err, buffer, sizeof(buffer)))
		{
			decl String:Error[PLATFORM_MAX_PATH + 64];
			FormatEx(Error, sizeof(Error), "[BOUNTY] FATAL *** ERROR *** Fatal parse error in %s", DefaultFile);
			SetFailState(Error);
		}
	}
}

public SMCResult:ReadConfig_NewSection(Handle:smc, const String:name[], bool:opt_quotes)
{
	if(name[0])
	{
		Call_StartForward(FwdNewSection);
		Call_PushString(name);
		Call_Finish();
	}

	return SMCParse_Continue;
}

public SMCResult:ReadConfig_KeyValue(Handle:smc,
										const String:key[],
										const String:value[],
										bool:key_quotes,
										bool:value_quotes)
{
	/**
	 * Is this check really even neccessary?
	 */

	if(key[0])
	{
		Call_StartForward(FwdKeyValue);
		Call_PushString(key);
		Call_PushString(value);
		Call_Finish();
	}

	return SMCParse_Continue;
}

public SMCResult:ReadConfig_EndSection(Handle:smc)
{
	return SMCParse_Continue;
}

public ReadConfig_ParseEnd(Handle:smc, bool:halted, bool:failed)
{
	if(ConfigCount == ++ParseCount)
	{
		Call_StartForward(FwdEnd);
		Call_Finish();
	}
}

public _ConfigNewSection(const String:name[])
{
	if (strcmp("Config", name, false) == 0)
	{
		ConfigState = CONFIG_STATE_CONFIG;
	}
}

public _ConfigKeyValue(const String:key[], const String:value[])
{
	switch(ConfigState)
	{
		case CONFIG_STATE_CONFIG:
		{
			if (strcmp("EnabledBounty", key, false) == 0) {
				SetConVarInt(g_Bounty, bool:StringToInt(value));
			} else if (strcmp("EnabledBountyCustom", key, false) == 0) {
				SetConVarInt(g_BountyCustom, bool:StringToInt(value));
			} else if (strcmp("EnabledBountyIRC", key, false) == 0) {
				BountyIRC = bool:StringToInt(value);
			} else if (strcmp("BountyStreakMin", key, false) == 0) {
				StreakMin = StringToInt(value);
			} else if (strcmp("BaseBounty", key, false) == 0) {
				BaseBounty = StringToInt(value);
			} else if (strcmp("IncressedBounty", key, false) == 0) {
				IncressedBounty = StringToInt(value);
			} else if (strcmp("RoundIncressedBounty", key, false) == 0) {
				RoundIncressedBounty = StringToInt(value);
			} else if (strcmp("HeadshotBountyEnabled", key, false) == 0) {
				HeadshotEnabled = bool:StringToInt(value);
			} else if (strcmp("HeadshotBountyEnabledCustom", key, false) == 0) {
				HeadshotEnabledCustom = bool:StringToInt(value);
				if ((HeadshotEnabledCustom) && (!HeadshotEnabled))
				{
					HeadshotEnabled = true;
				}
			} else if (strcmp("HeadshotBountyBonus", key, false) == 0) {
				HeadshotBonus = StringToFloat(value);
			} else if (strcmp("HostageBounty", key, false) == 0) {
				HostageEnabled = bool:StringToFloat(value);
			} else if (strcmp("HostageBountyWorth", key, false) == 0) {
				HostageBounty = StringToInt(value);
			} else if (strcmp("BountyAds", key, false) == 0) {
				BountyAds = bool:StringToInt(value);
			} else if (strcmp("EnabledBountyDebug", key, false) == 0) {
				EnabledBountyDebug = bool:StringToInt(value);
			}
			
			
			
		}
	}
}

public _ConfigEnd()
{
	ConfigState = CONFIG_STATE_NONE;
}