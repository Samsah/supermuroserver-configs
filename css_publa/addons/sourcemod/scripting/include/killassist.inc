/**
*	This forward is called whenever someone made a kill and got help doing it.
*	This means someone else made at least ConVar(kassist_minDmg) damage to the victim.
*
*	This is called ONCE per kill, not once per assist.
*
*	@param	assisters		Clients who assisted the kill
*	@param	nbAssisters		Number of client who assisted the kill
*	@param	killerId		Client who made the kill; can be the world
*	@param	victimId		Ciient who died
*	
*	@noreturn
*/
forward OnAssistedKill( const any:assisters[], const nbAssisters, const killerId, const victimId );