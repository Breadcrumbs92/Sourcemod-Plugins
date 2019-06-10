#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

public Plugin myinfo =
{
    name = "Artifact of Soul",
    author = "Breadcrumbs",
    description = "Those that fall will be succeeded.",
    version = "1.25",
    url = "http://www.sourcemod.net/"
}

public void OnPluginStart()
{
    // register events
    HookEvent("break_prop", OnPropKilled);
    HookEvent("entity_killed", OnEntKilled);
    HookEvent("break_breakable", OnBreakableKilled);
}

public void OnPropKilled(Event e, const char[] name, bool dontBroadcast)
{
    int victim = e.GetInt("entindex");
    TransmuteEntity(victim);
}

public void OnEntKilled(Event e, const char[] name, bool dontBroadcast)
{
    int victim = e.GetInt("entindex_killed");
    TransmuteEntity(victim);
}

public void OnBreakableKilled(Event e, const char[] name, bool dontBroadcast)
{
    int victim = e.GetInt("entindex");
    TransmuteEntity(victim);
}

/*
public void OnMapStart()
{
    // create an ai_relationship that makes players hate npc_kleiner and npc_mossman
    int relationship = CreateEntityByName("ai_relationship");
    DispatchKeyValue(relationship, "target", "player");
    DispatchKeyValue(relationship, "subject", "npc_alyx");
    DispatchKeyValue(relationship, "disposition", "1");
    DispatchKeyValue(relationship, "StartActive", "1");
    DispatchSpawn(relationship);
}
*/

public void TransmuteEntity(entity) 
{
    // check if a valid map is loaded
    // if not, gtfo
    char mapname[64];
    GetCurrentMap(mapname, 64);
    if (!IsMapValid(mapname))
    {
        return;
    }

    // look at the entity that was destroyed...
    if (IsValidEntity(entity))
    {
        if (HasEntProp(entity, Prop_Send, "m_vecOrigin") && HasEntProp(entity, Prop_Send, "m_angRotation"))
        {
            float origin[3];
            GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);

            float angles[3];
            GetEntPropVector(entity, Prop_Send, "m_angRotation", angles);

            // destroy pitch and roll so entities don't fall into the ground
            angles[0] = 0.0;
            angles[2] = 0.0;

            char classnameToSpawn[64] = "npc_headcrab";

            // determine what classnameToSpawn should be based on a random int
            switch (GetRandomInt(0, 2)) 
            {
                // spawn a random combine-aligned NPC
                case 0:
                {
                    // yes, these strings should really be in some sort of data structure, so we can more easily update the list.
                    // however... my OOP-centeric brain couldn't figure out how to use SP's ArrayList. So we get this instead.
                    switch (GetRandomInt(0, 7))
                    {
                        case 0: { classnameToSpawn = "npc_clawscanner"; }
                        case 1: { classnameToSpawn = "npc_combine_s"; }
                        case 2: { classnameToSpawn = "npc_cscanner"; }
                        case 3: { classnameToSpawn = "combine_mine"; }
                        case 4: { classnameToSpawn = "npc_manhack"; }
                        case 5: { classnameToSpawn = "npc_metropolice"; }
                        case 6: { classnameToSpawn = "npc_rollermine"; }
                        case 7: { classnameToSpawn = "npc_turret_floor"; }
                    }
                    PrintToConsoleAll("Tried to spawn a combine with classname %s", classnameToSpawn);
                }
                // spawn a random resistance-aligned NPC
                case 1:
                {
                    switch (GetRandomInt(2, 2))
                    {
                        // case 0: { classnameToSpawn = "npc_alyx"; }
                        // case 1: { classnameToSpawn = "npc_barney"; }
                        case 2: { classnameToSpawn = "npc_citizen"; }
                        // case 3: { classnameToSpawn = "npc_kleiner"; }
                        // case 4: { classnameToSpawn = "npc_monk"; }
                        // case 5: { classnameToSpawn = "npc_mossman"; }
                        // case 6: { classnameToSpawn = "npc_vortigaunt"; }
                    }
                    PrintToConsoleAll("Tried to spawn a resistance with classname %s", classnameToSpawn);
                }
                // spawn a random alien/neutral NPC
                case 2:
                {
                    switch (GetRandomInt(0, 8))
                    {
                        case 0: { classnameToSpawn = "npc_antlion"; }
                        // case 1: { classnameToSpawn = "npc_antlionguard"; }
                        case 1: { classnameToSpawn = "npc_fastzombie"; }
                        case 2: { classnameToSpawn = "npc_headcrab"; }
                        case 3: { classnameToSpawn = "npc_headcrab_black"; }
                        case 4: { classnameToSpawn = "npc_headcrab_fast"; }
                        case 5: { classnameToSpawn = "npc_poisonzombie"; }
                        case 6: { classnameToSpawn = "npc_zombie"; }
                        case 7: { classnameToSpawn = "npc_crow"; }
                        case 8: { classnameToSpawn = "npc_pigeon"; }
                    }
                    PrintToConsoleAll("Tried to spawn an alien with classname %s", classnameToSpawn);
                }
            }

            // create the NPC
            int npc = CreateEntityByName(classnameToSpawn);

            // if necessary, equip the new NPC and/or randomize some properties
            if (StrEqual(classnameToSpawn, "npc_metropolice"))
            {
                // choose a random weapon for the metrocop (pistol or smg)
                char weapon[64];
                switch (GetRandomInt(0, 1))
                {
                    case 0: { weapon = "weapon_pistol"; }
                    case 1: { weapon = "weapon_smg1"; }
                }
                DispatchKeyValue(npc, "additionalequipment", weapon);
            }
            else if (StrEqual(classnameToSpawn, "npc_combine_s"))
            {
                // choose a random weapon for the solider (smg or ar2 or shotty)
                char weapon[64];
                bool gotAR2 = false;
                switch (GetRandomInt(0, 2))
                {
                    case 0: { weapon = "weapon_smg1"; }
                    case 1: { weapon = "weapon_ar2"; gotAR2 = true; }
                    case 2: { weapon = "weapon_shotgun"; }
                }
                DispatchKeyValue(npc, "additionalequipment", weapon);
                
                // make the soldier elite if he got an ar2
                // otherwise, make him normal or a prison guard
                if (gotAR2) 
                {
                    DispatchKeyValue(npc, "model", "models/combine_super_soldier.mdl");
                }
                else
                {
                    switch (GetRandomInt(0, 1))
                    {
                        case 0: { DispatchKeyValue(npc, "model", "models/combine_soldier.mdl"); }
                        case 1: { DispatchKeyValue(npc, "model", "models/combine_soldier_prisonguard.mdl"); }
                    }
                }
            }
            else if (StrEqual(classnameToSpawn, "npc_citizen"))
            {
                // choose a random weapon for the citizen (pistol or smg or ar2 or shotty or rpg)
                char weapon[64];
                switch (GetRandomInt(0, 4))
                {
                    case 0: { weapon = "weapon_pistol"; }
                    case 1: { weapon = "weapon_smg1"; }
                    case 2: { weapon = "weapon_ar2"; }
                    case 3: { weapon = "weapon_shotgun"; }
                    case 4: { weapon = "weapon_rpg"; }
                }
                DispatchKeyValue(npc, "additionalequipment", weapon);

                // choose a random appearance for the citizen
                char citizenType[1];
                IntToString(GetRandomInt(0, 4), citizenType, 1);
                DispatchKeyValue(npc, "citizentype", citizenType);
            }
            else if (StrEqual(classnameToSpawn, "npc_barney"))
            {
                // if the NPC is barney, give him an ar2
                DispatchKeyValue(npc, "additionalequipment", "weapon_ar2");
                SetEntProp(npc, Prop_Data, "m_bGameEndAlly", 0);
                SetEntProp(npc, Prop_Data, "m_iHealth", 30);
            }
            else if (StrEqual(classnameToSpawn, "npc_monk"))
            {
                DispatchKeyValue(npc, "additionalequipment", "weapon_annabelle");
            }
            else if (StrEqual(classnameToSpawn, "npc_alyx"))
            {
                DispatchKeyValue(npc, "additionalequipment", "weapon_alyxgun");
                SetEntPropFloat(npc, Prop_Data, "m_flNextRegenTime", 0.0);
            }
            else if (StrEqual(classnameToSpawn, "npc_mossman"))
            {
                // hook Mossman so she turns into explosives when damaged
                SDKHook(npc, SDKHook_TraceAttackPost, OnShootMossman);
            }

            // spawn the NPC in the right place
            DispatchSpawn(npc);
            TeleportEntity(npc, origin, angles, NULL_VECTOR);
        } 
    }
}

public void OnShootMossman(int victim, int attacker, int inflictor, float damage, int damagetype, int ammotype, int hitbox, int hitgroup)
{
    if (!IsValidEntity(attacker))
    {
        return;
    }

    char attackerClassname[64];
    GetEntityClassname(attacker, attackerClassname, 64);

    if (StrEqual(attackerClassname, "player"))
    {
        float origin[3];
        GetEntPropVector(victim, Prop_Send, "m_vecOrigin", origin);
        // raise the z-component of mossman's origin, since otherwise the explosives will spawn a little in the ground.
        origin[2] += 16.0;

        // make explosives, with a headshot making on average more
        // for non-headshots: 4 - 6  explosives
        // for headshots:     4 - 10 explosives
        MakeExplosivesHere(GetRandomInt(4, (hitgroup == 1) ? 10 : 6), origin);
    }
}

void MakeExplosivesHere(int amount, float[3] origin)
{
    for (int i = 0; i < amount; i++)
    {
        char model[128];
        switch(GetRandomInt(0, 2))
        {
            case 0: { model = "models/props_c17/oildrum001_explosive.mdl"; }
            case 1: { model = "models/props_junk/gascan001a.mdl"; }
            case 2: { model = "models/props_junk/propane_tank001a.mdl"; }
        }

        // spawn the prop
        int prop = CreateEntityByName("prop_physics");
        DispatchKeyValue(prop, "model", model);
        DispatchSpawn(prop);

        // make a random velocity vector
        float velocity[3];
        velocity[0] = GetRandomFloat(-200.0, 200.0);
        velocity[1] = GetRandomFloat(-200.0, 200.0);
        velocity[2] = GetRandomFloat(-200.0, 200.0);

        // the velocity vector is also used for the angles, since why not?
        TeleportEntity(prop, origin, velocity, velocity);
    }
}