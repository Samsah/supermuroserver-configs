// File:   sodstats.dod.sp
// Author: ]SoD[ Frostbyte

#define ID_DODS 300

HookEventsDOD()
{
	HookEvent("player_hurt", Event_DOD_PlayerHurt);
	HookEvent("dod_stats_weapon_attack", Event_DOD_WeaponFire);
}

public Event_DOD_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Read relevant event data
	new userid     = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker   = GetClientOfUserId(GetEventInt(event, "attacker"));
	new health     = GetEventInt(event, "health");
	new headshot   = (health == 0 && GetEventInt(event, "hitgroup") == 1);
	
	if(g_initialized[attacker] && 
	   g_initialized[userid] && 
	   IsClientInGame(attacker) && 
	   IsClientInGame(userid))
	{
		new user_team = GetClientTeam(userid);
		new attacker_team = GetClientTeam(attacker);
	
	
		// Check for suicide
		if(userid == attacker && health == 0)
		{
			g_deaths[userid]++;
			g_session_deaths[userid]++;
		}
		// Otherwise it's a legitimate kill!
		if(user_team != attacker_team)
		{
			g_hits[attacker]++;
			g_session_hits[attacker]++;
			
			if(health == 0)
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
				
				if(headshot)
				{
					g_headshots[attacker]++;
					g_session_headshots[attacker]++;
					
					g_score[attacker] += 1;
					g_session_score[attacker] += 1;

				}
				
				SavePlayer(attacker);
				SavePlayer(userid);
			}
		}
	}
}

public Event_DOD_WeaponFire(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetClientOfUserId(GetEventInt(event, "attacker"));
	g_shots[userid]++;
	
	g_session_shots[userid]++;
}
