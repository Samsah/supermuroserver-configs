// File:   sodstats.tf2.sp
// Author: ]SoD[ Frostbyte

#define ID_TF2             440
#define ID_FORTRESSFOREVER 215

HookEventsTF2()
{
	HookEvent("player_death", Event_TF2_PlayerDeath);
}

public Event_TF2_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Read relevant event data
	new userid   = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if(g_initialized[attacker] && 
	   g_initialized[userid] && 
	   IsClientInGame(attacker) && 
	   IsClientInGame(userid))
	{
		new user_team = GetClientTeam(userid);
		new attacker_team = GetClientTeam(attacker);
		
		// Check for suicide
		if(userid == attacker)
		{
			g_deaths[userid]++;
			g_session_deaths[userid]++;
		}
		// Otherwise it's a legitimate kill!
		else if(user_team != attacker_team)
		{
			g_kills[attacker]++;
			g_deaths[userid]++;
			
			g_session_kills[attacker]++;
			g_session_deaths[userid]++;
			
			new score_dif = g_score[userid] - g_score[attacker];
			if(score_dif < 0)
				score_dif = 2;
			else
				score_dif = 2 + (g_score[userid] - g_score[attacker])/100;

			
			g_score[attacker] += score_dif + 1;
			g_session_score[attacker] += score_dif + 1;
			
			g_score[userid] -= score_dif;
			g_session_score[userid] -= score_dif;
			
			#if defined MODE_BADGES 1
			CheckBadge(attacker);
			#endif
			
			SavePlayer(attacker);
			SavePlayer(userid);
		}
	}
}
