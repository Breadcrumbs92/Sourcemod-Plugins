#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

#define MAX_ENTS 2048            // max entities on the server is assumed 2048.
#define MAX_ABSORBTION 10        // how many balls any prop is allowed to
                                 // absorb before it explodes.
#define INFINITE_BOUNCES 8192.0  // well... close enough.
#define NUM_AIRDROP_PROPS 10

public Plugin myinfo =
{
    name = "Artifact of fission",
    author = "Breadcrumbs",
    description = "Split enemies for massive power",
    version = "1.0",
    url = "http://www.sourcemod.net/"
}

char      immuneNPCs[1024] = "npc_mossman npc_vortigaunt npc_monk npc_barney npc_alyx";
char      airdropProps[][] = 
{
    "models/props_c17/handrail04_medium.mdl", 
    "models/props_c17/oildrum001.mdl",
    "models/props_doors/door03_slotted_left.mdl",
    "models/props_interiors_furniture_chair03a.mdl",
    "models/props_interiors/radiator01a.mdl",
    "models/props_junk/trashbin01a.mdl",
    "models/props_junk/cinderblock01a.mdl",
    "models/props_lab/filecabinet02.mdl",
    "models/props_lab/monitor02.mdl",
    "models/props_wasteland/controlroom_chair001a.mdl"
};

int       ballsAbsorbed[MAX_ENTS];
bool      mapLoaded;
bool      requestingDetonator;
float     detonatorInterval;
Handle    shakeTimers[MAX_ENTS];
Handle    immunityCycle;

char      absorbLight[128] = "physics/metal/metal_sheet_impact_hard2.wav";
char      absorbWarning[128]   = "physics/metal/metal_sheet_impact_bullet2.wav";
char      absorbCritical[128] = "physics/metal/metal_sheet_impact_bullet1.wav";

public void OnPluginStart()
{
    HookEvent("entity_killed", OnEntityKilled);
    RegConsoleCmd("fission_rehook", RehookAll);
    RegConsoleCmd("fission_reshield_vital_allies", MakeEntsImmune);
}

// Yes, this is my method of making players' weapons do no
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

    PrecacheSound(absorbLight, true);
    PrecacheSound(absorbWarning, true);
    PrecacheSound(absorbCritical, true);
    PrefetchSound(absorbLight);
    PrefetchSound(absorbWarning);
    PrefetchSound(absorbCritical);

    mapLoaded = true;
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
    }

    mapLoaded = false;
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
        RequestFrame(CheckBall, entity);

        SDKHook(entity, SDKHook_StartTouch, OnBallTouch);

        // This requestingDetonator variable is set by the RequestDetonator()
        // function, which is called whenever we want the next ball that is
        // spawned to detonate after a certain period of time.
        if (requestingDetonator)
        {
            // It's very possible for the ball to have already detonated
            // and the ball's index repurposed before this timer goes off.
            // This is why we use an entity reference.
            CreateTimer(detonatorInterval, DetonateBall, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
            requestingDetonator = false;
        }
    }
    else if (StrEqual(classname, "crossbow_bolt"))
    {
        // Firing bolts with the crossbow doesn't trigger the
        // FireBullets SDKHook, so we instead need to check for these
        // crossbow bolt entities being made.
        // We need to check if the bolt belongs to a player, and if it
        // does, fire a ball from that player's face.
        // However, if we check the bolt's m_hOwnerEntity right away,
        // it will always be -1!
        // For whatever dumbass reason, we need to delay checking the
        // bolt's owner, which is why we RequestFrame here.
        RequestFrame(TransformBolt, entity);
    }
    else if (StrContains(immuneNPCs, classname) != -1)
    {
        SetVariantString("filter_immune");
        AcceptEntityInput(entity, "SetDamageFilter");
    }
}

void CheckBall(int ball)
{
    if (GetEntProp(ball, Prop_Data, "m_bWeaponLaunched"))
    {
        int owner = GetEntPropEnt(ball, Prop_Data, "m_hOwnerEntity");
        char classname[64];
        GetEntityClassname(owner, classname, 64);

        if (StrEqual(classname, "player"))
        {
            // lol
            ClientCommand(owner, "explode");
            for (int i = 0; i < GetRandomInt(40, 50); i++)
            {
                float origin[3];
                float angles[3];

                GetRandomAngleVector(angles);
                GetClientEyePosition(owner, origin);

                LaunchBall(origin, angles, 2000.0, INFINITE_BOUNCES);
            }
        }
    }
}

public void OnEntityDestroyed(int entity)
{
    // "ENOUGH OF YOUR BULLSHIT"
    // - Alyx Vance 
    if (!mapLoaded)
    {
        return;
    }

    // Apparantly IsValidEntity is full of shit??
    // Do this instead
    if (entity > 0 && entity < MAX_ENTS)
    {
        // Whenever an entity is destroyed, the amount of balls it
        // has absorbed needs to be reset, so that if another prop takes
        // this index later, it doesn't start with balls already absorbed.
        ballsAbsorbed[entity] = 0;

        char classname[64];
        GetEntityClassname(entity, classname, 64);


        if (StrEqual(classname, "npc_grenade_frag") || StrEqual(classname, "grenade_ar2"))
        {
            float origin[3];
            GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);

            // Bump the origin up, since otherwise it's a little in the floor
            origin[2] += 32.0;

            for (int i = 0; i < GetRandomInt(4, 5); i++)
            {
                int prop = CreateEntityByName("prop_physics");
                DispatchKeyValue(prop, "model", airdropProps[GetRandomInt(0, NUM_AIRDROP_PROPS - 1)]);
                DispatchSpawn(prop);

                float angles[3];
                float push[3];
                GetRandomAngleVector(angles);
                GetAngleVectors(angles, push, NULL_VECTOR, NULL_VECTOR);
                ScaleVector(push, 300.0);

                TeleportEntity(prop, origin, NULL_VECTOR, push);

                // To fix prop trampoline bug
                SetEntPropVector(prop, Prop_Data, "m_vecAbsVelocity", Float:{0.0, 0.0, 0.0});
            }
        }
        else if (StrEqual(classname, "rpg_missile"))
        {
            float origin[3];
            GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);

            origin[2] += 32.0;

            for (int i = 0; i < GetRandomInt(40, 60); i++)
            {
                float angles[3];
                GetRandomAngleVector(angles);
                
                LaunchBall(origin, angles, 1200.0, 2.0, 5.0);
            }
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
        int absorbed = ballsAbsorbed[other];

        // Determine the intensity of absorbtion sound to play.
        if (absorbed <= MAX_ABSORBTION / 3.0)
        {
            EmitSoundToAll(absorbLight, other);
        }
        else if (absorbed <= 2.0 * MAX_ABSORBTION / 3.0)
        {
            EmitSoundToAll(absorbWarning, other);
        }
        else
        {
            EmitSoundToAll(absorbCritical, other);
        }

        // This creates a nice-ish inverse relationship between shaking
        // speed and the amount of balls absorbed.
        // float interval = 5.4 / absorbed + 0.5 - 0.6;
        // shakeTimers[other] = CreateTimer(interval, ShakeProp, other, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

        if (ballsAbsorbed[other] >= MAX_ABSORBTION)
        {
            AcceptEntityInput(other, "Kill");
            
            float origin[3];
            float angles[3];
            GetEntPropVector(other, Prop_Data, "m_vecOrigin", origin);
            for (int i = 0; i < MAX_ABSORBTION * 2; i++)
            {
                GetRandomAngleVector(angles);
                LaunchBall(origin, angles, 1000.0, 999.0);
            }
        }
    }

    return Plugin_Continue;
}

// To shake a prop, we get a random angle and assign velocity
// in that direction.
/*
Action ShakeProp(Handle timer, int entity)
{
    if (!mapLoaded || ballsAbsorbed[entity] == 0)
    {
        return Plugin_Stop;
    }

    float push[3];
    float angles[3];

    GetRandomAngleVector(angles);
    GetAngleVectors(angles, push, NULL_VECTOR, NULL_VECTOR);
    ScaleVector(push, ballsAbsorbed[entity] * 30.0);

    TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, push);

    return Plugin_Continue;
}
*/

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
                LaunchBall(origin, newVelocity, GetVectorLength(velocity) + 100.0, 999.0);
            }
        }
        else if (StrEqual(attackerClassname, "player"))
        {
            int weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");

            char wepClassname[64];
            GetEntityClassname(weapon, wepClassname, 64);

            if (StrEqual(wepClassname, "weapon_crowbar") || StrEqual(wepClassname, "weapon_stunstick"))
            {
                float origin[3];
                GetEntPropVector(killed, Prop_Send, "m_vecOrigin", origin);
                origin[2] += 32.0;

                int prop = CreateEntityByName("prop_physics");
                DispatchKeyValue(prop, "model", "models/props_c17/oildrum001.mdl");
                DispatchSpawn(prop);
                TeleportEntity(prop, origin, NULL_VECTOR, NULL_VECTOR);
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

    // Balls from the pistol expire quickly and travel slowly.
    if (StrEqual(weaponname, "weapon_pistol"))
    {
        RequestDetonator(3.0);
        LaunchBall(newOrigin, angles, 80.0, 1.0);
    }
    else if (StrEqual(weaponname, "weapon_357"))
    {
        LaunchBall(newOrigin, angles, 500.0, 4.0);
    }
    else if (StrEqual(weaponname, "weapon_smg1"))
    {
        RequestDetonator(0.8);
        LaunchBall(newOrigin, angles, 480.0, 1.0, 10.0);
    }
    else if (StrEqual(weaponname, "weapon_ar2"))
    {
        LaunchBall(newOrigin, angles, 600.0, INFINITE_BOUNCES);
    }
    else if (StrEqual(weaponname, "weapon_shotgun"))
    {
        LaunchBall(newOrigin, angles, 20.0, INFINITE_BOUNCES);
    }
    else if (StrEqual(weaponname, "weapon_crossbow"))
    {
        LaunchBall(newOrigin, angles, 2000.0, 1.0);
    }
}

// Handle everything necessary for launching a combine ball.
void LaunchBall(float[3] origin, float[3] angles, float speed, float bounces, float radius=20.0, float noise=0.0)
{
    if (GetEntityCount() > GetMaxEntities() - 200)
    {
        PrintToChatAll("[FISSION] Balls disabled : too close to entity limit (within 200)");
        return;
    }

    int launcher = CreateEntityByName("point_combine_ball_launcher");
    DispatchSpawn(launcher);
    DispatchKeyValueFloat(launcher, "launchconenoise", noise);
    DispatchKeyValueFloat(launcher, "ballradius", radius);
    DispatchKeyValueFloat(launcher, "ballcount", 1.0);

    // This spawnflag makes launched balls collide with players.
    SetEntProp(launcher, Prop_Data, "m_spawnflags", 2);

    DispatchKeyValueFloat(launcher, "minspeed", speed);
    DispatchKeyValueFloat(launcher, "maxspeed", speed);
    DispatchKeyValueFloat(launcher, "maxballbounces", bounces);

    TeleportEntity(launcher, origin, angles, NULL_VECTOR);
    AcceptEntityInput(launcher, "LaunchBall");
    
    // We don't need the launcher to stick around. Remove it.
    AcceptEntityInput(launcher, "Kill");
}

// Utility function.
// Randomly shifts the components of a vector.
void JitterVector(float[3] vector, float intensity)
{
    vector[0] += GetRandomFloat(-intensity, intensity);
    vector[1] += GetRandomFloat(-intensity, intensity);
    vector[2] += GetRandomFloat(-intensity, intensity);
}

// Given the REFERENCE to a ball, detonates the ball.
// Meant to be called by a timer.
Action DetonateBall(Handle timer, int ballRef)
{
    int ball = EntRefToEntIndex(ballRef);
    if (!IsValidEntity(ball))
    {
        return Plugin_Stop;
    }
    
    AcceptEntityInput(ball, "Explode");

    return Plugin_Continue;
}

// Registered to console command: fission_rehook
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

Action MakeEntsImmune(int client, int args)
{
    for (int i = 0; i < GetMaxEntities(); i++)
    {
        if (IsValidEntity(i))
        {
            char classname[64];
            GetEntityClassname(i, classname, 64);

            if (StrContains(immuneNPCs, classname) != -1)
            {
                PrintToChatAll("%s (%d) became immune.", classname, i);
                SetVariantString("filter_immune");
                AcceptEntityInput(i, "SetDamageFilter");
            }
        }
    }

    return Plugin_Continue;
}

// This function is here since checking the owner of a crossbow
// bolt does not work immediately
void TransformBolt(int bolt)
{
    int owner = GetEntPropEnt(bolt, Prop_Data, "m_hOwnerEntity");
    char classname[64];
    GetEntityClassname(owner, classname, 64);
    if (StrEqual(classname, "player"))
    {
        AcceptEntityInput(bolt, "Kill");

        // Manually call OnPlayerShoot, since it has all the ball-launching
        // code that we want.
        OnPlayerShoot(owner, 1, "weapon_crossbow");
    }
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

// Utility function.
// Sets global variables handling a request to detonate a ball.
void RequestDetonator(float time)
{
    requestingDetonator = true;
    detonatorInterval = time;
}