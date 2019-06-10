#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

public Plugin myinfo =
{
    name = "Artifact of Fusion",
    author = "Breadcrumbs",
    description = "Split enemies for massive power",
    version = "0.1",
    url = "http://www.sourcemod.net/"
}

// enemies in this string will become immune to everything
// except for combine balls.
char immuneNPCs[1024] = "npc_metropolice npc_combine_s npc_antlion npc_zombie npc_poisonzombie npc_fastzombie npc_headcrab npc_headcrab_black npc_headcrab_fast npc_manhack npc_rollermine npc_barnacle npc_alyx npc_monk npc_zombine npc_hunter npc_citizen";

public void OnPluginStart()
{
    HookEvent("entity_killed", OnEntityKilled);
    RegConsoleCmd("fusion_rehook", RehookAll);
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (StrEqual(classname, "player"))
    {
        SDKUnhook(entity, SDKHook_FireBulletsPost, OnPlayerShoot);
        SDKHook(entity, SDKHook_FireBulletsPost, OnPlayerShoot);
    }
    else if (StrEqual(classname, "prop_combine_ball"))
    {
        SDKHook(entity, SDKHook_StartTouch, OnBallTouch);
    }
    else if (StrContains(immuneNPCs, classname) != -1)
    {
        SetVariantString("fusion_dissolveimmunity");
        AcceptEntityInput(entity, "SetDamageFilter");
    }
}

public void OnMapStart()
{
    int filter = CreateEntityByName("filter_damage_type");
    DispatchKeyValueFloat(filter, "damagetype", 2.0);
    DispatchKeyValueFloat(filter, "Negated", 1.0);
    DispatchKeyValue(filter, "targetname", "fusion_dissolveimmunity");

    CreateTimer(1.0, ApplyFilterToAll, _, TIMER_REPEAT);
}

public Action OnBallTouch(int entity, int other)
{
    // The classname of entity is always "prop_combine_ball".
    char touchedClassname[64];
    GetEntityClassname(other, touchedClassname, 64);

    if (StrEqual(touchedClassname, "prop_physics"))
    {
        AcceptEntityInput(entity, "Explode");
    }

    return Plugin_Continue;
}

public void OnEntityKilled(Event event, const char[] name, bool dontBroadcast)
{
    int killed = event.GetInt("entindex_killed");
    int attacker = event.GetInt("entindex_attacker");

    if (IsValidEntity(killed) && IsValidEntity(attacker))
    {
        char killedClassname[64];
        char attackerClassname[64];

        GetEntityClassname(killed, killedClassname, 64);
        GetEntityClassname(attacker, attackerClassname, 64);

        if (StrEqual(attackerClassname, "prop_combine_ball"))
        {
            // The ejection angle of the split balls is based on the
            // first ball's velocity.
            float velocity[3];
            float origin[3];

            GetEntPropVector(attacker, Prop_Data, "m_vecVelocity", velocity);
            GetEntPropVector(attacker, Prop_Data, "m_vecOrigin", origin);

            float newVelocity[3];
            for (int i = 0; i < 2; i++)
            {
                newVelocity[0] = velocity[0];
                newVelocity[1] = velocity[1];
                newVelocity[2] = velocity[2];

                JitterVector(newVelocity, 100.0);
                LaunchBall(origin, newVelocity, GetVectorLength(velocity) + 100.0, 999.0, 1, true);
            }
        }
    }
}

public void OnPlayerShoot(int client, int shots, const char[] weaponname)
{
    float angles[3];    // angles of client's eyes
    float origin[3];    // position of client's eyes

    GetClientEyeAngles(client, angles);
    GetClientEyePosition(client, origin);

    // If we launch a ball directly from the client's eyes,
    // it will get stuck in their body and cause stupid things.
    // We can't disable collision on the player and ball, 
    // because we need the balls to kill players.
    // So instead, we spawn the ball a little bit in the direction
    // of the player's eye angles.
    float push[3];
    float newOrigin[3];
    GetAngleVectors(angles, push, NULL_VECTOR, NULL_VECTOR);
    ScaleVector(push, 50.0);
    AddVectors(origin, push, newOrigin);

    // If doing this causes the balls to spawn outside the world,
    // instead determine the spawn location by tracing a ray from
    // the player's head, and seeing where it hits the world.
    if (TR_PointOutsideWorld(newOrigin))
    {
        TR_TraceRay(origin, angles, MASK_SOLID_BRUSHONLY, RayType_Infinite);
        TR_GetEndPosition(newOrigin, INVALID_HANDLE);
    }
    PrintToServer("Spawn ball at {%f, %f, %f}", newOrigin[0], newOrigin[1], newOrigin[2]);

    // By launching a ball for every shot, weapons that fire
    // multiple bullets (e.g. the shotgun) will make more than 
    // one combine ball.
    LaunchBall(newOrigin, angles, 200.0, 4.0, shots, true);
}

// Launching a combine ball is somewhat complicated, so we put
// it in its own function for simplicity's sake.
void LaunchBall(float[3] origin, float[3] angles, float speed, float bounces, int times, bool collideWithPlayer)
{
    // Creating a prop_combine_ball directly doesn't work.
    // We instead need to use this special launcher entity.
    int spawner = CreateEntityByName("point_combine_ball_launcher");
    DispatchSpawn(spawner);

    // Without these keyvalues being initialized, the launcher
    // probably won't work at all. 
    DispatchKeyValueFloat(spawner, "launchconenoise", 0.0);
    DispatchKeyValueFloat(spawner, "ballradius", 20.0);
    DispatchKeyValueFloat(spawner, "ballcount", 1.0);
    DispatchKeyValueFloat(spawner, "minspeed", speed);
    DispatchKeyValueFloat(spawner, "maxspeed", speed);
    DispatchKeyValueFloat(spawner, "maxballbounces", bounces);

    // This spawnflag ensures that balls will collide with the player.
    if (collideWithPlayer)
    {
        SetEntProp(spawner, Prop_Data, "m_spawnflags", 2);
    }

    TeleportEntity(spawner, origin, angles, NULL_VECTOR);

    for (int i = 0; i < times; i++)
    {
        AcceptEntityInput(spawner, "LaunchBall");
    }

    // The spawner needs to be killed afterwards so it doesn't
    // continue to make balls.
    AcceptEntityInput(spawner, "Kill");
}

// Utility to randomly shift a vector.
void JitterVector(float[3] vector, float intensity)
{
    vector[0] += GetRandomFloat(-intensity, intensity);
    vector[1] += GetRandomFloat(-intensity, intensity);
    vector[2] += GetRandomFloat(-intensity, intensity);
}

// Registered to console command: fusion_rehook
Action RehookAll(int client, int args)
{
    for (int i = 1; i <= MAXPLAYERS; i++)
    {
        if (IsValidEntity(i))
        {
            char classname[64];
            GetEntityClassname(i, classname, 64);

            if (StrEqual(classname, "player"))
            {
                char clientName[64];
                GetClientName(i, clientName, 64);

                PrintToChatAll("Rehooked player %s", clientName);
                SDKUnhook(i, SDKHook_FireBulletsPost, OnPlayerShoot);
                SDKHook(i, SDKHook_FireBulletsPost, OnPlayerShoot);
            }
        }
    }

    return Plugin_Continue;
}

Action ApplyFilterToAll(Handle timer, Handle hndl)
{
    for(int i = 1; i <= GetEntityCount(); i++)
    {
        if(IsValidEntity(i))
        {
            char classname[64];
            GetEntityClassname(i, classname, 64);
            
            if(StrContains(immuneNPCs, classname, true) != -1)
            {
                SetVariantString("fusion_dissolveimmunity");
                AcceptEntityInput(i, "SetDamageFilter");
            }
        }
    }
    
    return Plugin_Continue;
}

/*
public void OnGameFrame()
{
    for (int i = 0; i < GetMaxEntities(); i++)
    {
        if (IsValidEntity(i))
        {
            char classname[64];
            GetEntityClassname(i, classname, 64);

            if (StrEqual(classname, "prop_combine_ball"))
            {
                float velocity[3];
                GetEntPropVector(i, Prop_Data, "m_vecVelocity", velocity);
                ScaleVector(velocity, 2.0);
                SetEntPropVector(i, Prop_Data, "m_vecVelocity", velocity);
            }
        }
    }
}
*/