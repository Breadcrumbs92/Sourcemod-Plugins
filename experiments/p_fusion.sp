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

public void OnPluginStart()
{
    RegConsoleCmd("fusion_rehook", RehookAll);
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (StrEqual(classname, "player"))
    {
        SDKUnhook(entity, SDKHook_FireBulletsPost, OnPlayerShoot);
        SDKHook(entity, SDKHook_FireBulletsPost, OnPlayerShoot);
    }
}

public void OnPlayerShoot(int cilent, int shots, const char[] weaponname)
{
    float angles[3];    // angles of client's eyes
    float origin[3];    // position of client's eyes

    GetClientEyeAngles(client, angles);
    GetClientEyePosition(client, origin);

    // Creating a prop_combine_ball directly doesn't work.
    // We instead need to use this special launcher entity.
    int spawner = CreateEntityByName("point_combine_ball_launcher");

    // Without these keyvalues being initialized, the launcher
    // probably won't work at all.
    DispatchKeyValueFloat(spawner, "launchconenoise", 0.0);
    DispatchKeyValueFloat(spawner, "ballradius", 20.0);
    DispatchKeyValueFloat(spawner, "ballcount", 1.0);
    DispatchKeyValueFloat(spawner, "minspeed", 800.0);
    DispatchKeyValueFloat(spawner, "maxspeed", 900.0);
    DispatchKeyValueFloat(spawner, "maxballbounces", 4.0);

    DispatchSpawn(spawner);
    TeleportEntity(spawner, origin, angles, NULL_VECTOR);

    // By launching a ball for every shot, weapons that fire
    // multiple bullets (e.g. the shotgun) will make more than 
    // one combine ball.
    for (int i = 0; i < shots; i++)
    {
        AcceptEntityInput(spawner, "LaunchBall");
    }
}

public Action RehookAll(int client, int args)
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
}