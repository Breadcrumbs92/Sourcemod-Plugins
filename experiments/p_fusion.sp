#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

#define MAX_ENTS 2048            // max entities on the server is assumed 2048.
#define MAX_ABSORBTION 8         // how many balls any prop is allowed to
                                 // absorb before it explodes.
#define INFINITE_BOUNCES 8192.0  // well... close enough.

public Plugin myinfo =
{
    name = "Artifact of Fusion",
    author = "Breadcrumbs",
    description = "Split enemies for massive power",
    version = "0.1",
    url = "http://www.sourcemod.net/"
}

char      immuneNPCs[1024] = "npc_mossman npc_vortigaunt npc_monk npc_barney npc_alyx";
int       ballsAbsorbed[MAX_ENTS];
int       launchers[MAXPLAYERS + 1];    // Every player gets a launcher.
                                        // There is also a generic one.
int       lastBallSpawned;
bool      mapLoaded;
Handle    shakeTimers[MAX_ENTS];
Handle    immunityCycle;

public void OnPluginStart()
{
    HookEvent("entity_killed", OnEntityKilled);
    RegConsoleCmd("fusion_rehook", RehookAll);
}

// Yes, this is my solution to making players' weapons do no
// damage. Fucking sue me, I will fight you.
public void OnMapStart()
{
    ServerCommand("sk_plr_dmg_357 0");
    ServerCommand("sk_plr_dmg_ar2 0");
    ServerCommand("sk_plr_dmg_crossbow 0");
    ServerCommand("sk_plr_dmg_pistol 0");
    ServerCommand("sk_plr_dmg_smg1 0");
    ServerCommand("sk_plr_dmg_buckshot 0");

    // Futile attempt to make certain NPCs immune to all damage...
    int filter = CreateEntityByName("filter_damage_type");
    DispatchKeyValueFloat(filter, "damagetype", 16384.0);
    DispatchKeyValue(filter, "targetname", "filter_immune");

    // TIMER_FLAG_NO_MAPCHANGE is deceptively important!
    // Timers REALLY need to be closed when the map is not loaded.
    immunityCycle = CreateTimer(1.0, MakeEntsImmune, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

    // The world gets its own launcher at index 0.
    PrepareLauncher(0);

    mapLoaded = true;
}

void PrepareLauncher(int index)
{
    int launcher = CreateEntityByName("point_combine_ball_launcher");
    DispatchSpawn(launcher);
    DispatchKeyValueFloat(launcher, "launchconenoise", 0.0);
    DispatchKeyValueFloat(launcher, "ballradius", 20.0);
    DispatchKeyValueFloat(launcher, "ballcount", 1.0);

    // The ball respawn time is set to a ludicrous value
    // so it doesn't fire again without our orders.
    DispatchKeyValueFloat(launcher, "ballrespawntime", 999999.0);

    // This spawnflag makes launched balls collide with players.
    SetEntProp(launcher, Prop_Data, "m_spawnflags", 2);

    launchers[index] = launcher;
}

public void OnMapEnd() 
{
    // If we don't kill repeating timers at map end, then
    // they will just accumulate forever.
    if (immunityCycle != INVALID_HANDLE)
    {
        CloseHandle(immunityCycle);
    }

    for (int i = 0; i < MAX_ENTS; i++)
    {
        if (shakeTimers[i] != INVALID_HANDLE)
        {
            CloseHandle(shakeTimers[i]);
        }

        if (i < MAXPLAYERS + 1 && IsValidEntity(launchers[i]))
        {
            AcceptEntityInput(launchers[i], "Kill");
        }
    }

    mapLoaded = false;
}

public Action MakeEntsImmune(Handle timer)
{
    for (int i = 0; i < GetMaxEntities(); i++)
    {
        if (IsValidEntity(i))
        {
            char classname[64];
            GetEntityClassname(i, classname, 64);

            if (StrContains(immuneNPCs, classname) != -1)
            {
                PrintToServer("making %s immune", classname);
                SetVariantString("filter_immune");
                AcceptEntityInput(i, "SetDamageFilter");
            }
        }
    }

    return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (StrEqual(classname, "player"))
    {
        SDKUnhook(entity, SDKHook_FireBulletsPost, OnPlayerShoot);
        SDKHook(entity, SDKHook_FireBulletsPost, OnPlayerShoot);
        PrepareLauncher(entity);
    }
    else if (StrEqual(classname, "prop_combine_ball"))
    {
        SDKHook(entity, SDKHook_StartTouch, OnBallTouch);
        lastBallSpawned = entity;
    }
    else if (StrEqual(classname, "npc_barney"))
    {
        SetVariantString("filter_immune");
        AcceptEntityInput(entity, "SetDamageFilter");
    }
}

public void OnEntityDestroyed(int entity)
{
    // Apparantly IsValidEntity is full of shit??
    // Do this instead
    if (entity > 0 && entity < MAX_ENTS)
    {
        // Whenever an entity is destroyed, the amount of balls it
        // has absorbed needs to be reset, so that if another prop takes
        // this index later, it doesn't start with balls already absorbed.
        ballsAbsorbed[entity] = 0;

        // It's also probably a good idea to stop associated shake timers.
        if (shakeTimers[entity] != INVALID_HANDLE)
        {
            KillTimer(shakeTimers[entity]);
        }
    }
}

Action OnBallTouch(int entity, int other)
{
    // The classname of `entity` is always "prop_combine_ball".
    char touchedClassname[64];
    GetEntityClassname(other, touchedClassname, 64);

    if (StrEqual(touchedClassname, "prop_physics"))
    {
        AcceptEntityInput(entity, "Explode");
        ballsAbsorbed[other]++;

        // CloseHandle stops a timer.
        if (shakeTimers[other] != INVALID_HANDLE) 
        {
            KillTimer(shakeTimers[other]);
        }

        // The shake timer's interval is an inverse relationship with 
        // the amount of balls absorbed, since that makes a prop with 
        // more balls absorbed shake faster.
        shakeTimers[other] = CreateTimer(2.0 / ballsAbsorbed[other], ShakeProp, other, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

        if (ballsAbsorbed[other] >= MAX_ABSORBTION)
        {
            AcceptEntityInput(other, "Kill");
            
            float origin[3];
            float angles[3];
            GetEntPropVector(other, Prop_Data, "m_vecOrigin", origin);
            for (int i = 0; i < MAX_ABSORBTION * 2; i++)
            {
                GetRandomAngleVector(angles);
                LaunchBall(launchers[0], origin, angles, 1000.0, 999.0);
            }
        }
    }

    return Plugin_Continue;
}

// To shake a prop, we get a random angle and assign velocity
// in that direction.
Action ShakeProp(Handle timer, int entity)
{
    if (!mapLoaded)
    {
        return Plugin_Stop;
    }

    float push[3];
    float angles[3];

    GetRandomAngleVector(angles);
    GetAngleVectors(angles, push, NULL_VECTOR, NULL_VECTOR);
    ScaleVector(push, 60.0);

    TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, push);

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
                LaunchBall(launchers[0], origin, newVelocity, GetVectorLength(velocity) + 100.0, 999.0);
            }
        }
    }
}

public void OnPlayerShoot(int client, int shots, const char[] weaponname)
{
    PrintToServer("client %d shot", client);

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

    // By launching a ball for every shot, weapons that fire
    // multiple bullets (e.g. the shotgun) will make more than 
    // one combine ball.
    
    // Balls from the pistol expire quickly and travel slowly.
    if (StrEqual(weaponname, "weapon_pistol"))
    {
        LaunchBall(launchers[client], newOrigin, angles, 80.0, 1.0);
    }
    else if (StrEqual(weaponname, "weapon_357"))
    {
        LaunchBall(launchers[client], newOrigin, angles, 500.0, 4.0);
    }
    else if (StrEqual(weaponname, "weapon_smg1"))
    {
        LaunchBall(launchers[client], newOrigin, angles, 120.0, 1.0);
    }
    else if (StrEqual(weaponname, "weapon_ar2"))
    {
        LaunchBall(launchers[client], newOrigin, angles, 200.0, INFINITE_BOUNCES);
    }
    else if (StrEqual(weaponname, "weapon_shotgun"))
    {
        for (int i = 0; i < shots; i++) 
        {
            LaunchBall(launchers[client], newOrigin, angles, 100.0, 1.0);
        }
    }
}


// Utility function.
// Give it a launcher and some parameters, and it will set everything
// up to make the desired launch happen.
void LaunchBall(int launcher, float[3] origin, float[3] angles, float speed, float bounces)
{
    if (GetEntityCount() > GetMaxEntities() - 200)
    {
        PrintToChatAll("[FUSION] Balls disabled : too close to entity limit (within 200)");
        return;
    }

    char cls[64];
    GetEntityClassname(launcher, cls, 64);

    PrintToServer("Launcher's classname is %s", cls);

    PrintToServer("Spawn ball at {%f, %f, %f}", origin[0], origin[1], origin[2]);
    DispatchKeyValueFloat(launcher, "minspeed", speed);
    DispatchKeyValueFloat(launcher, "maxspeed", speed);
    DispatchKeyValueFloat(launcher, "maxballbounces", bounces);

    TeleportEntity(launcher, origin, angles, NULL_VECTOR);
    AcceptEntityInput(launcher, "LaunchBall");
}

// Utility function.
// Randomly shifts the components of a vector.
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

// Utility function.
// Makes a completely random angle vector and assigns it
// to the given buffer, overwriting its contents.
void GetRandomAngleVector(float[3] buffer)
{
    buffer[0] = GetRandomFloat(-180.0, 180.0);
    buffer[1] = GetRandomFloat(-180.0, 180.0);
    buffer[2] = GetRandomFloat(-180.0, 180.0);
}
