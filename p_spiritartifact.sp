#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

public Plugin myinfo =
{
	name = "Flight Artifact",
	author = "Breadcrumbs",
	description = "You get hit, you get lost.",
	version = "1.0",
	url = "http://www.sourcemod.net/"
}

public void OnMapStart()
{
	HookEvent("player_spawn", f_player_spawned);
	HookEvent("player_death", f_player_died);
	PrecacheSound("beams/beamstart5.wav", true);
	PrefetchSound("beams/beamstart5.wav");
	
	CreateTimer(1.0, f_search_for_players, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(2.0, f_search_for_players, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(3.0, f_search_for_players, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(10.0, f_search_for_players, _, TIMER_FLAG_NO_MAPCHANGE);
}

//-----------------------------------------------
// This function is called on every player spawn
//
// Purpose: Hook players with functions so we can 
// do things when they take damage
//-----------------------------------------------
public void f_player_spawned(Event event_spawn, const char[] name, bool dontBroadcast)
{
	int i_player_index = event_spawn.GetInt("userid");
	int i_client = GetClientOfUserId(i_player_index);
	
	// Create SDKHooks that look for players taking damage
	// We have to unhook them first in case they already exist
	f_make_hooks(i_client);
}

//-----------------------------------------------
// This function is called on player death
//
// Purpose: Provide another layer of SDKHooks to
// protect against spawning inconsistencies
// in Synergy
//-----------------------------------------------
public void f_player_died(Event event_die, const char[] name, bool dontBroadcast)
{
	int i_player_index = event_die.GetInt("userid");
	int i_client = GetClientOfUserId(i_player_index);
	
	// Create SDKHooks that look for players taking damage
	// We have to unhook them first in case they already exist
	f_make_hooks(i_client);
}

// ----------------------------------------------------------
// This function is called whenever an attack is registered
//
// Purpose: find specific enemies damaging the player, then
// bounce the player away from any attacking enemy
// -----------------------------------------------------------
public void f_on_trace_attack(int victim, int attacker, int inflictor, float damage, int damagetype, int ammotype, int hitbox, int hitgroup)
{
	//Initialize some variables for storing classnames and vectors
	char string_attacker_classname[64] = " ";
	GetEntityClassname(attacker, string_attacker_classname, 64);
	
	char string_victim_classname[64] = " ";
	GetEntityClassname(victim, string_victim_classname, 64);
	
	float vec_player_origin[3] = {0.0, 0.0, 0.0};
	float vec_attacker_origin[3] = {0.0, 0.0, 0.0};
	float vec_push[3] = {0.0, 0.0, 0.0};
	
	// Players should be pushed by damage from these sources
	char string_pusher_classnames[1024] = "npc_combine_s npc_metropolice npc_grenade_frag prop_physics npc_combinegunship npc_hunter npc_helicopter npc_strider";
	
	// If the victim is a player and the attacker is one of the above enemies...
	if(StrContains(string_pusher_classnames, string_attacker_classname, true) != -1 && StrEqual(string_victim_classname, "player", true) == true)
	{
		// Gets position of attacker (enemy) and victim (player)
		GetEntPropVector(victim, Prop_Send, "m_vecOrigin", vec_player_origin);
		GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", vec_attacker_origin);
	
		// Create a velocity vector by subtracting these positions, 
		// then negating the resulting vector
		SubtractVectors(vec_attacker_origin, vec_player_origin, vec_push);
		NegateVector(vec_push);
		
		// Get the magnitude of the vector
		float fl_pushmag = GetVectorLength(vec_push, false);
		
		// The push vector gets more intense the more damage the player took
		// In addition, each part of the vector gets divided by the magnitute,
		// so that players aren't pushed more if they are farther away
		for(int i = 0; i < 3; i++)
		{
			vec_push[i] = (vec_push[i] * Pow(damage, 3.0) * 10.0) / fl_pushmag;
		}
	
		//	Shots are not allowed to push you downwards
		if(vec_push[2] < 0.0)
		{
			vec_push[2] = 0.0;
		}
		
		// Shots give a little vertical boost, for added fun
		vec_push[2] += 20.0 * damage;
	
		// Add the veclocity vector to the player's current velocity
		// This actually does the push
		SetEntPropVector(victim, Prop_Data, "m_vecVelocity", vec_push);
	}
}

// ----------------------------------------------------------
// This function is called whenever a player takes damage
//
// Purpose: Check for fall damage and prevent it
// if it's high enough, spawn combine balls around the player
// -----------------------------------------------------------
public Action f_on_take_damage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	// Store classnames of attacker and victim
	char string_attacker_classname[64] = " ";
	GetEntityClassname(attacker, string_attacker_classname, 64);
	
	char string_victim_classname[64] = " ";
	GetEntityClassname(victim, string_victim_classname, 64);
	
	// We don't want any of this garbage to happen to
	// players taking fall damage from triggers
	// They should just die
	char string_trigger_list[512] = "trigger_hurt trigger_once trigger_multiple";
	
	// If the thing that took damage is a player 
	// and the damage type is fall damage
	// and the source isn't a trigger
	if(StrEqual(string_victim_classname, "player", true) == true && damagetype == 32 && StrContains(string_trigger_list, string_attacker_classname, true) == -1)
	{		
		// This function gives us a float for damage
		// However, we need to do integer math,
		// So we use this to round that float to an integer
		int i_damage = RoundFloat(damage);
		
		// Get player's health, store that in a variable
		int i_player_health = GetClientHealth(victim);
		
		// When a player takes damage from falling, we
		// immediately give that damage back as health
		// All this happens on a single tick, before the 
		// player has a chance to die!
		SetEntityHealth(victim, (i_player_health + i_damage));
		
		// If the fall damage is high enough
		if(i_damage > 75)
		{
			// Linear function that decides how many balls will come out
			// of the player on landing
			int i_prop_ball_count = i_damage / 10;
			
			// Spawn combine balls around the player
			for(int i = 0; i < i_prop_ball_count; i++)
			{	
				// Get origin of player
				float vec_player_origin[3] = {0.0, 0.0, 0.0};
				GetEntPropVector(victim, Prop_Send, "m_vecOrigin", vec_player_origin);
			
				// Create combine ball spawners
				int i_crush_balls = CreateEntityByName("point_combine_ball_launcher");
				DispatchSpawn(i_crush_balls);
				
				// Initialize values (This step is deceptively important. Balls won't
				// launch properly unless some values are initialized)
				DispatchKeyValueFloat(i_crush_balls, "launchconenoise", 10.0);
				DispatchKeyValueFloat(i_crush_balls, "ballradius", 20.0);
				DispatchKeyValueFloat(i_crush_balls, "ballcount", 1.0);
				DispatchKeyValueFloat(i_crush_balls, "minspeed", 800.0);
				DispatchKeyValueFloat(i_crush_balls, "maxspeed", 900.0);
				DispatchKeyValueFloat(i_crush_balls, "maxballbounces", 4.0);
				
				// The following code will make combine balls hurt the player
				// Very bad, do not uncomment
				
				//DispatchKeyValueFloat(i_crush_balls, "spawnflags", 2.0);
		
				// Orient the launcher in a random direction. For maximum variety.
				float vec_random_angle_vector[3] = {0.0, 0.0, 0.0};
				vec_random_angle_vector[0] = GetRandomFloat(-20.0, 20.0);
				vec_random_angle_vector[1] = GetRandomFloat(-180.0, 180.0);
				vec_random_angle_vector[2] = 0.0;
				TeleportEntity(i_crush_balls, vec_player_origin, vec_random_angle_vector, NULL_VECTOR);
	
				// Launch the balls and kill the spawner
				AcceptEntityInput(i_crush_balls, "LaunchBall");
				AcceptEntityInput(i_crush_balls, "Kill");
			}
				
			// Play a sound to make everyhing cooler
			EmitSoundToAll("beams/beamstart5.wav", victim);
		}
	}
}

//----------------------------------------------------
// This function is called whenever a player shoots
// a hitscan weapon or a crossbow
// 
// Purpose: Push players backwards when they fire guns
//----------------------------------------------------
public void f_on_shoot(int client, int shots, const char[] weaponname)
{
	// Initialize variables
	float vec_player_angles[3] = {0.0, 0.0, 0.0};
	float vec_bump[3] = {0.0, 0.0, 0.0};
	
	// Get the direction the player is looking in
	GetClientEyeAngles(client, vec_player_angles);
	GetAngleVectors(vec_player_angles, vec_bump, NULL_VECTOR, NULL_VECTOR);
	
	// Based on what weapon the player is firing, change the 
	// magnitude of the vector
	float fl_bump_magnitude = 0.0;
	
	if(StrEqual("weapon_357", weaponname, true))
	{
		fl_bump_magnitude = 350.0;
	}
	else if(StrEqual("weapon_smg1", weaponname, true))
	{
		fl_bump_magnitude = 40.0;
	}
	else if(StrEqual("weapon_ar2", weaponname, true))
	{
		fl_bump_magnitude = 70.0;
	}
	else if(StrEqual("weapon_pistol", weaponname, true))
	{
		fl_bump_magnitude = 60.0;
	}
	else if(StrEqual("weapon_shotgun", weaponname, true))
	{
		fl_bump_magnitude = 40.0;
	}
	else if(StrEqual("weapon_crossbow", weaponname, true))
	{
		fl_bump_magnitude = 600.0;
	}
	else
	{
		fl_bump_magnitude = 100.0;
	}
	
	// Make bump magnitude proportional to shots
	// Only really effects shotgun
	fl_bump_magnitude = fl_bump_magnitude * shots;
	
	// If the player has lower health, guns will bump them
	// exponentially more
	// Follows the function 1.01^missing health
	int i_player_health = GetClientHealth(client);
	
	if(i_player_health < 100)
	{
		float fl_player_health = float(i_player_health);
		float fl_health_scale = 100.0 - fl_player_health;
	
		fl_health_scale = Pow(1.01, fl_health_scale);
		fl_bump_magnitude = fl_bump_magnitude * fl_health_scale;
	}
	
	// Negate vector so it doesn't push players forwards
	// Then scale vector according to weapon used and health
	NegateVector(vec_bump);
	ScaleVector(vec_bump, fl_bump_magnitude);
	
	// Apply velocity to player
	SetEntPropVector(client, Prop_Data, "m_vecBaseVelocity", vec_bump);
}

//----------------------------------------------------------------
// This function is called whenever we need to make hooks
//
// Purpose: Create SDKHooks so the mod can check for shooting
// and taking damage
//----------------------------------------------------------------
public void f_make_hooks(int client)
{
	// We have to unhook these first just in case they already exist
	// since SDKHooks stack
	SDKUnhook(client, SDKHook_TraceAttackPost, f_on_trace_attack);
	SDKUnhook(client, SDKHook_OnTakeDamage, f_on_take_damage);
	SDKUnhook(client, SDKHook_FireBulletsPost, f_on_shoot);
	
	SDKHook(client, SDKHook_TraceAttackPost, f_on_trace_attack);
	SDKHook(client, SDKHook_OnTakeDamage, f_on_take_damage);
	SDKHook(client, SDKHook_FireBulletsPost, f_on_shoot);

}

//----------------------------------------------------------------
// This function is called to look for players
//
// Purpose: Find all players on the server and hook all of them
//----------------------------------------------------------------
public Action f_search_for_players(Handle timer_01)
{
	int i_index = -1;
	
	while ((i_index = FindEntityByClassname(i_index, "player")) != -1)
	{
		f_make_hooks(i_index);
	}
}

//-----------------------------------------------------
// This function is called whenever an entity is created
// 
// Purpose: look for any crossbow bolts and push the 
// player that fired them
//------------------------------------------------------
public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "crossbow_bolt", true) == true)
	{
		CreateTimer(0.01, f_crossbow_check, entity, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action f_crossbow_check(Handle Timer01, int entity)
{
		int i_owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
		char string_owner_classname[32] = " ";
		GetEntityClassname(i_owner, string_owner_classname, sizeof(string_owner_classname));
		
		if(StrEqual("player", string_owner_classname, true) == true)
		{
			f_on_shoot(i_owner, 1, "weapon_crossbow");
		}
}
