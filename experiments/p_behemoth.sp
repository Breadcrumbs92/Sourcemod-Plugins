#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

public Plugin myinfo = 
{
    name = "Arifact of The Behemoth",
    author = "Breadcrumbs",
    description = "Everyone's attacks explode, except for yours.",
    version = "0.1",
    url = "http://www.sourcemod.net/"
};

ConVar convarVerbose;

public void OnPluginStart() 
{
    convarVerbose = CreateConVar("behemoth_verbose", 
    "0.0", // Default value
    "Whether or not to print verbose debug information in the chat", 
    FCVAR_NOTIFY, 
    true, 
    0.0, // Min value
    true, 
    1.0); // Max value
}

// callback for OnTakeDamagePost
public void OnDamageEvent(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3])
{
    char victimClassname[64] = "";
    char attackerClassname[64] = "";

    if (GetConVarBool(convarVerbose))
    {
        PrintToChatAll("%d was attacked by %d", victim, attacker);
    }

    // only do shit if victim and attacker are valid entities
    if (IsValidEntity(victim) && IsValidEntity(attacker)) 
    {
        GetEntityClassname(victim, victimClassname, 64);
        GetEntityClassname(attacker, attackerClassname, 64);

        if (GetConVarBool(convarVerbose))
        {
            PrintToChatAll("%s (%d) was attacked by %s (%d) at {%f, %f, %f}", 
                           victimClassname, 
                           victim,
                           attackerClassname,
                           attacker,
                           damagePosition[0],
                           damagePosition[1],
                           damagePosition[2]);
        }

        // only explode when an npc attacks
        if (StrContains(attackerClassname, "npc_", false) != -1)
        {
            int barrel = CreateEntityByName("prop_physics");
            DispatchKeyValue(barrel, "model", "models/props_c17/oildrum001_explosive.mdl");

            DataPack pack = CreateDataPack();
            ResetPack(pack, true);
            WritePackCell(pack, barrel);
            WritePackFloat(pack, damagePosition[0]);
            WritePackFloat(pack, damagePosition[1]);
            WritePackFloat(pack, damagePosition[2]);

            RequestFrame(throwBarrel, pack);
        }
    }
}

public void throwBarrel(DataPack pack) 
{
    ResetPack(pack, false);
    int barrel = ReadPackCell(pack);
    float position[3] = {0.0, 0.0, 0.0};
    position[0] = ReadPackFloat(pack);
    position[1] = ReadPackFloat(pack);
    position[2] = ReadPackFloat(pack);

    DispatchSpawn(barrel);
    TeleportEntity(barrel, position, NULL_VECTOR, NULL_VECTOR);
    AcceptEntityInput(barrel, "break");
}

public void OnEntityCreated(int entity, const char[] classname) 
{
    if (IsValidEntity(entity)) 
    {
        if (entity == 1 && GetConVarBool(convarVerbose)) 
        {
            PrintToChatAll("The player was actually hooked, don't phreak");
        }

        SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnDamageEvent); 
        SDKHook(entity, SDKHook_OnTakeDamagePost, OnDamageEvent);
    }
}

public void OnMapStart() 
{
    PrintToChatAll("Literally everyone but you picked up: The Brilliant Behemoth");

    // put a traceattack hook on every eligible entity on the map
    for (int i = 0; i < GetMaxEntities(); i++) 
    {
        if (IsValidEntity(i)) 
        {
            if (i == 1 && GetConVarBool(convarVerbose)) 
            {
                PrintToChatAll("The player was actually hooked, don't phreak");
            }

            char classname[64];
            GetEntityClassname(i, classname, 64);

            SDKUnhook(i, SDKHook_OnTakeDamagePost, OnDamageEvent); 
            SDKHook(i, SDKHook_OnTakeDamagePost, OnDamageEvent);
        }
    }
}

/*
// user-defined callback for TraceAttackPost
public void OnDamageEvent(int victim, int attacker, int inflictor, float damage, int damagetype, int ammotype, int hitbox, int hitgroup) 
{
    char victimClassname[64] = "";
    char attackerClassname[64] = "";

    PrintToChatAll("%d was attacked by %d", 
    victim, 
    attacker);

    // only do shit if victim and attacker are valid entities
    if (IsValidEntity(victim) && IsValidEntity(attacker)) 
    {
        // update the last attacker
        lastAttacker = attacker;

        GetEntityClassname(victim, victimClassname, 64);
        GetEntityClassname(attacker, attackerClassname, 64);

        PrintToChatAll("%s was attacked by %s", 
        victimClassname, 
        attackerClassname);

        if (HasEntProp(attacker, Prop_Data, "m_vDefaultEyeOffset")) 
        {
            // float attackerAngles[3];
            // GetEntPropVector(attacker, Prop_Data, "m_vCurEyeTarget", attackerAngles);
            // PrintToChatAll("Attacker's cur eye target: {%f, %f, %f}",
            // attackerAngles[0], attackerAngles[1], attackerAngles[2]);

            float headYaw;
            GetEntPropFloat(attacker, Prop_Data, "m_flHeadYaw");

            float headPitch;
            GetEntPropFloat(attacker, Prop_Data, "m_flHeadPitch");

            PrintToChatAll("Yaw: %f, Pitch: %f", headYaw, headPitch);

            float attackerPosition[3];
            GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", attackerPosition);

            float attackerEyeOffset[3];
            GetEntPropVector(attacker, Prop_Data, "m_vDefaultEyeOffset", attackerEyeOffset);

            PrintToChatAll("Attacker's eye offset: {%f, %f, %f}", attackerEyeOffset[0], attackerEyeOffset[1], attackerEyeOffset[2]);

            // add the npc's eye offset to their feet position
            AddVectors(attackerPosition, attackerEyeOffset, attackerPosition);

            // Throw a ray that collides with solid things
            // TR_TraceRayFilter(attackerPosition, attackerAngles, MASK_ALL, RayType_Infinite, AttackTraceFilter);

            // float rayHit[3] = {0.0, 0.0, 0.0};
            // TR_GetEndPosition(rayHit, INVALID_HANDLE);

            // PrintToChatAll("%s was attacked by %s at {%f, %f, %f}", 
            // victimClassname, 
            // attackerClassname,
            // rayHit[0], 
            // rayHit[1], 
            // rayHit[2]);

            // char hitEntityClassname[64];
            // GetEntityClassname(TR_GetEntityIndex(INVALID_HANDLE), hitEntityClassname, 64);

            // PrintToChatAll("We hit a %s", hitEntityClassname);

            // int barrel = CreateEntityByName("prop_physics");
            // DispatchKeyValue(barrel, "model", "models/props_c17/oildrum001_explosive.mdl");

            // DataPack pack = CreateDataPack();
            // ResetPack(pack, true);
            // WritePackCell(pack, barrel);
            // WritePackFloat(pack, rayHit[0]);
            // WritePackFloat(pack, rayHit[1]);
            // WritePackFloat(pack, rayHit[2]);

            // RequestFrame(throwBarrel, pack);
        }
    }
}
*/