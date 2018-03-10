#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

public Plugin myinfo =
{
	name = "Gun Speeder Upper",
	author = "Breadcrumbs",
	description = "Make gun go fast really",
	version = "0.0",
	url = "http://www.sourcemod.net/"
}

// Create a player spawn event
public void OnPluginStart()
{
	HookEvent("player_spawn", f_player_spawned);
}

// Whenever a player spawns, give them a hook that'll fire whenever they shoot
// TODO: Implement hook for crossbow, which doesn't go through FireBulletsPost
public void f_player_spawned(Event event_spawn, const char[] name, bool dontBroadcast)
{
	int i_player_index = event_spawn.GetInt("userid");
	int i_client = GetClientOfUserId(i_player_index);
	
	SDKHook(i_client, SDKHook_FireBulletsPost, f_on_shoot);
}

// Do this when someone shoots
public void f_on_shoot(int client, int shots, const char[] weaponname)
{
	// This while loop finds the weapon entity held by the shooter
	int i_index = -1;
	while((i_index = FindEntityByClassname(i_index, weaponname)) != -1)
	{
		// Make sure that the found weapon belongs to the shooter
		if(GetEntPropEnt(i_index, Prop_Data, "m_hOwner") == client)
		{
			float fl_time_reduce = 0.2;
			float fl_next = GetEntPropFloat(i_index, Prop_Data, "m_flNextPrimaryAttack");
			
			// Depending on the weapon, change the factor by which it's sped up
			// TODO: Find out why this doesn't work for the shotty
			if(StrEqual(weaponname, "weapon_shotgun", true))
			{
				fl_time_reduce = 2.0;
			}
			else
			{
				fl_time_reduce = 0.2;
			}
			
			// Lower the weapon's next available fire time
			// This speeds up the fire rate
			SetEntPropFloat(i_index, Prop_Data, "m_flNextPrimaryAttack", fl_next - fl_time_reduce);
			
			// Set the ammo to exactly what it was before we shot + 1
			SetEntProp(i_index, Prop_Data, "m_iClip1", GetEntProp(i_index, Prop_Data, "m_iClip1") + 1);
		}
	}
}
