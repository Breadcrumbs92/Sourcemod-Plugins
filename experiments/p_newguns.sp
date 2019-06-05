#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

public Plugin myinfo =
{
    name = "Newguns",
    author = "Breadcrumbs",
    description = "These weapons feel a little unfamiliar.",
    version = "0.0",
    url = "http://www.sourcemod.net/"
}

// Create a player spawn event
public void OnPluginStart()
{
    HookEvent("player_spawn", OnPlayerSpawned);
}

// Whenever a player spawns, give them a hook that'll fire whenever they shoot
// TODO: Implement hook for crossbow, which doesn't go through FireBulletsPost
public void OnPlayerSpawne(Event event_spawn, const char[] name, bool dontBroadcast)
{
    int playerIndex = event_spawn.GetInt("userid");
    int client = GetClientOfUserId(playerIndex);
    
    SDKHook(client, SDKHook_FireBulletsPost, OnPlayerShoot);
}

// Do this when someone shoots
public void OnPlayerShoot(int client, int shots, const char[] weaponname)
{
    // This while loop finds the weapon entity held by the shooter
    int index = -1;
    while((index = FindEntityByClassname(index, weaponname)) != -1)
    {
        // Make sure that the found weapon belongs to the shooter
        if(GetEntPropEnt(index, Prop_Data, "m_hOwner") == client)
        {
            float timeReduce = 0.2;
            float nextPrimaryAttack = GetEntPropFloat(index, Prop_Data, "m_flNextPrimaryAttack");
            
            // Depending on the weapon, change the factor by which it's sped up
            // TODO: Find out why this doesn't work for the shotty
            if(StrEqual(weaponname, "weapon_shotgun", true))
            {
                timeReduce = 2.0;
            }
            else
            {
                timeReduce = 0.2;
            }
            
            // Lower the weapon's next available fire time
            // This speeds up the fire rate
            SetEntPropFloat(index, Prop_Data, "m_flNextPrimaryAttack", nextPrimaryAttack - timeReduce);
            
            // Set the ammo to exactly what it was before we shot + 1
            SetEntProp(index, Prop_Data, "m_iClip1", GetEntProp(index, Prop_Data, "m_iClip1") + 1);
        }
    }
}
