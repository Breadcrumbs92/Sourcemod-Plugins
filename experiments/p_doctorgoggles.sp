#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

public Plugin myinfo =
{
    name = "DoctorGoggles",
    author = "Breadcrumbs",
    description = "See health of entites under your crosshair",
    version = "1.0",
    url = "http://www.sourcemod.net/"
}

float accumulatedDamage[MAXPLAYERS + 1];
float damageRate[MAXPLAYERS + 1];
float damageAcceleration[MAXPLAYERS + 1];
float previousAcceleration[MAXPLAYERS + 1];

public void OnEntityCreated(int entity, const char[] classname) 
{
    if (StrEqual(classname, "player")) 
    {
        SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnPlayerDamage);
        SDKHook(entity, SDKHook_OnTakeDamagePost, OnPlayerDamage);
    }
}

public void OnMapStart()
{
    for (int i = 0; i < MAXPLAYERS + 1; i++) 
    {
        damageAcceleration[i] = previousAcceleration[i];
    }
}

public void OnGameFrame()
{
    for(int i = 1; i < MAXPLAYERS + 1; i++)
    {	
        if(IsValidEntity(i))
        {
            char str_classname[64];
            GetEntityClassname(i, str_classname, 64);
        
            if(StrEqual(str_classname, "player", true))
            {
                // int i_target = GetAimTarget(i);
                // PrintToServer("%i", i_target);
                
                // char targetName[64];
                // GetEntityClassname(i_target, targetName, 64);
                
                int health = GetEntProp(i, Prop_Send, "m_iHealth");

                damageRate[i] += damageAcceleration[i];
                accumulatedDamage[i] += damageRate[i];

                if (accumulatedDamage[i] > 1.0) 
                {
                    SetEntProp(i, Prop_Send, "m_iHealth", health - 1);
                    if (health - 1 >= 0) 
                    {
                        ForcePlayerSuicide(i);
                    }
                    accumulatedDamage[i] = 0.0;
                }

                /*
                if(i_target > 64)
                {
                    int health = GetEntProp(i_target, Prop_Data, "m_iHealth");
                    int maxHealth = GetEntProp(i_target, Prop_Data, "m_iMaxHealth");
                    PrintCenterText(i, "(%s #%d) Health: %d / %d", targetName, i_target, health, maxHealth);
                    PrintToServer("(%s #%d) Health: %d / %d", targetName, i_target, health, maxHealth);

                    int moveType = GetEntProp(i_target, Prop_Data, "m_MoveType");
                    int moveCollide = GetEntProp(i_target, Prop_Data, "m_MoveCollide");
                    int collisionGroup = GetEntProp(i_target, Prop_Data, "m_CollisionGroup");
                    //int physicsMode = GetEntProp(i_target, Prop_Data, "m_iPhysicsMode");
                    int fFlags = GetEntProp(i_target, Prop_Data, "m_fFlags");
                    float intertiaScale = GetEntPropFloat(i_target, Prop_Data, "m_inertiaScale");
                    //float mass = GetEntPropFloat(i_target, Prop_Data, "m_fMass");
                    
                    PrintToServer("m_MoveType : %i", moveType);
                    PrintToServer("m_MoveCollide : %i", moveCollide);
                    PrintToServer("m_CollisionGroup : %i", collisionGroup);
                    //PrintToServer("m_iPhysicsMode : %i", physicsMode);
                    PrintToServer("m_fFlags : %i", fFlags);
                    PrintToServer("m_inertiaScale : %f", intertiaScale);
                    //PrintToServer("m_fMass : %f", mass);
                }
                */
            } 
        }
    }
}

public void OnPlayerDamage(int victim, int attacker, int inflictor, float damage, int damagetype)
{
    PrintCenterText(victim, "Took %f damage", damage);

    int health = GetEntProp(victim, Prop_Send, "m_iHealth");
    damageAcceleration[victim] += 0.0001;
}

public int GetAimTarget(int client)
{
    float pos[3] = {0.0, 0.0, 0.0};
    float ang[3] = {0.0, 0.0, 0.0};
    
    GetClientEyePosition(client, pos);
    GetClientEyeAngles(client, ang);
    
    TR_TraceRayFilter(pos, ang, MASK_VISIBLE, RayType_Infinite, NoPlayerFilter);
    return TR_GetEntityIndex(INVALID_HANDLE);
}

public bool NoPlayerFilter(int entity, int contentsMask)
{
    char classname[64];
    GetEntityClassname(entity, classname, 64);
    
    if(StrEqual(classname, "player"))
    {
        return false;
    }
    
    return true;
}