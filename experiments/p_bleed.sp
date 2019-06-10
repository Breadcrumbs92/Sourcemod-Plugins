#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

public Plugin myinfo =
{
    name = "Artifact of Blood",
    author = "Breadcrumbs",
    description = "...",
    version = "0.0",
    url = "http://www.sourcemod.net/"
}

float accumulatedDamage[2048];
float damageRate[2048];
float damageAcceleration[2048];

bool isMapLoaded = false;
float zero[3] = {0.0, 0.0, 0.0};

ConVar displayStatus;

public void OnPluginStart()
{
    HookEvent("item_pickup", ItemPickupEvent);
    HookEvent("player_death", PlayerDeathEvent);

    displayStatus = CreateConVar("blood_display_status", "0", "View your own mortality...");

    RegConsoleCmd("blood_reset_all", ResetAll);

    PrintToServer("[BLOOD] Plugin start!");
}

public void OnEntityCreated(int entity, const char[] classname) 
{
    if (StrEqual(classname, "player")) 
    {
        PrintToServer("[BLOOD] Hooked player %d on entity created", entity);
        SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnPlayerDamage);
        SDKHook(entity, SDKHook_OnTakeDamagePost, OnPlayerDamage);
        SDKUnhook(entity, SDKHook_TouchPost, OnTouch);
        SDKHook(entity, SDKHook_TouchPost, OnTouch);
    }
}

public void ItemPickupEvent(Event e, const char[] name, bool dontBroadcast)
{
    char itemClassname[64];
    GetEntityClassname(e.GetInt("itemid"), itemClassname, 64);

    // WELCOME TO THE SOURCE ENGINE
    // WHERE "itemid" MEANS WHATEVER THE FUCK IT WANTS
    if (e.GetInt("itemid") == 22)
    {
        int player = GetClientOfUserId(e.GetInt("userid"));
        damageAcceleration[player] -= 0.001;
    }
}

public void PlayerDeathEvent(Event e, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(e.GetInt("userid"));
    damageRate[client] = 0.0;
    damageAcceleration[client] = 0.0;
}

public void OnMapStart() 
{
    PrintToServer("[BLOOD] Map started!");

    CreateTimer(1.0, HookPlayer1);

    for (int i = 0; i < 2048; i++)
    {
        if (IsValidEntity(i))
        {
            char classname[64];
            GetEntityClassname(i, classname, 64);

            if (StrEqual(classname, "player"))
            {
                PrintToServer("[BLOOD] Hooked player %d on map start", i);
                SDKUnhook(i, SDKHook_OnTakeDamagePost, OnPlayerDamage);
                SDKHook(i, SDKHook_OnTakeDamagePost, OnPlayerDamage);
            }
        }
    }

    isMapLoaded = true;
}

public Action HookPlayer1(Handle timer)
{
    SDKUnhook(1, SDKHook_OnTakeDamagePost, OnPlayerDamage);
    SDKHook(1, SDKHook_OnTakeDamagePost, OnPlayerDamage);
}

public void OnMapEnd()
{
    isMapLoaded = false;
    for (int i = 0; i < 2048; i++)
    {
        damageRate[i] = 0.0;
        damageAcceleration[i] = 0.0;
    }
}

public Action ResetAll(int client, int args)
{
    for (int i = 0; i < 2048; i++)
    {
        if (IsValidEntity(i))
        {
            char str_classname[64];
            GetEntityClassname(i, str_classname, 64);
        
            if(StrEqual(str_classname, "player", true))
            {
                damageRate[i] = 0.0;
                damageAcceleration[i] = 0.0;
            }
        }
    }
}

public void OnGameFrame()
{
    for(int i = 1; i < 2048; i++)
    {
        if(IsValidEntity(i))
        {
            char str_classname[64];
            GetEntityClassname(i, str_classname, 64);
        
            if(StrEqual(str_classname, "player", true))
            {   
                int health = GetEntProp(i, Prop_Send, "m_iHealth");
                if (health <= 0)
                {
                    SDKHooks_TakeDamage(i, 0, 0, 1.0, 0, -1, zero, zero);
                }

                if (displayStatus.BoolValue)
                {
                    PrintToServer("[BLOOD] Player %d | Rate: %f, Accel: %f", i, damageRate[i], damageAcceleration[i]);
                }

                damageRate[i] += damageAcceleration[i];
                if (damageRate[i] < 0.0)
                {
                    damageRate[i] = 0.0;
                    damageAcceleration[i] = 0.0;
                }
                accumulatedDamage[i] += damageRate[i];

                if (accumulatedDamage[i] > 1.0) 
                {
                    SetEntProp(i, Prop_Send, "m_iHealth", health - 1);
                    accumulatedDamage[i] = 0.0;
                }
            } 
        }
    }
}

public void OnPlayerDamage(int victim, int attacker, int inflictor, float damage, int damagetype)
{
    damageAcceleration[victim] += 0.00001 * damage;
}

public void OnTouch(int entity, int other)
{
    char entname[64];
    GetEntityClassname(entity, entname, 64);

    char othername[64];
    GetEntityClassname(other, othername, 64);

    if (StrEqual(othername, "item_healthcharger"))
    {
        if (GetEntPropFloat(other, Prop_Send, "m_flCharge") > 0.0) 
        {
            SetEntProp(entity, Prop_Send, "m_iHealth", GetEntProp(entity, Prop_Send, "m_iHealth") + 30);
        }

        if (GetEntProp(entity, Prop_Send, "m_iHealth") > 100)
        {
            SetEntProp(entity, Prop_Send, "m_iHealth", 100);
        }

        SetEntPropFloat(other, Prop_Send, "m_flCharge", 0.0);
        SetEntProp(other, Prop_Send, "m_bOn", 0);
        damageAcceleration[entity] -= 0.001;
    }
    //PrintToServer("[BLOOD] Touch call - entity: %s, other %s", entname, oname);
}

/*
public Action MakeKit(int client, int args)
{
    PrintToServer("[BLOOD] Making kits.");
    for (int i = 0; i < 2048; i++)
    {
        if (IsValidEntity(i))
        {
            char classname[64];
            GetEntityClassname(i, classname, 64);

            if (StrEqual(classname, "player"))
            {
                PrintToServer("[BLOOD] Found a player. Getting kit.");
                float origin[3];
                GetEntPropVector(i, Prop_Send, "m_vecOrigin", origin);

                int kit = CreateEntityByName("item_healthkit");
                DispatchSpawn(kit);
                AcceptEntityInput(kit, "Respawn");
                AcceptEntityInput(kit, "BecomeRagdoll");
                TeleportEntity(kit, origin, NULL_VECTOR, NULL_VECTOR);
            }
        }
    }
}

public Action DebugEnts(int client, int args)
{
    int numKits = 0;
    for (int i = 0; i < 2048; i++)
    {
        if (IsValidEntity(i))
        {
            char classname[64];
            GetEntityClassname(i, classname, 64);

            PrintToServer("[%d] : %s", i, classname);

            if (StrEqual(classname, "item_healthkit"))
            {
                numKits++;
            }
        }
        else
        {
            PrintToServer("[%d] empty", i);
        }
    }
    PrintToServer("found %d item_healthkit", numKits);
}
*/

/*
public Action ReplaceChargers(Handle timer)
{
    for (int i = 0; i < 2048; i++)
    {
        if (IsValidEntity(i))
        {
            char classname[64];
            GetEntityClassname(i, classname, 64);

            if (StrEqual(classname, "item_healthcharger"))
            {
                ReplaceCharger(INVALID_HANDLE, i);
            }
        }
    }

    return Plugin_Continue;
}

public Action ReplaceCharger(Handle timer, any data)
{
    float origin[3];
    GetEntPropVector(data, Prop_Send, "m_vecOrigin", origin);

    int kit = CreateEntityByName("item_healthkit");
    PrintToServer("Made an entity from OnMapStart() at {%f, %f, %f}",
        origin[0], origin[1], origin[2]);
    DispatchSpawn(kit);
    TeleportEntity(kit, origin, NULL_VECTOR, NULL_VECTOR);

    AcceptEntityInput(data, "kill");

    return Plugin_Continue;
}
*/