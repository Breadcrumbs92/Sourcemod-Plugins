#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

#define COMBINE_NPC     0
#define RESISTANCE_NPC  1
#define ALIEN_NPC       2
#define WILD_NPC        3

public Plugin myinfo =
{
    name = "Artifact of Soul",
    author = "Breadcrumbs",
    description = "Those that fall will be succeeded.",
    version = "1.25",
    url = "http://www.sourcemod.net/"
}

ArrayList combineNPCs;
ArrayList resistanceNPCs;
ArrayList alienNPCs;
ArrayList wildNPCs;

public void OnPluginStart()
{
    // initialize the list of valid spawnable npcs
    combineNPCs = CreateArray(64, 10);
    combineNPCs.PushString("npc_clawscanner");
    combineNPCs.PushString("npc_combine_s");
    combineNPCs.PushString("npc_combine_gunship");
    combineNPCs.PushString("npc_cscanner");
    combineNPCs.PushString("combine_mine");
    combineNPCs.PushString("npc_manhack");
    combineNPCs.PushString("npc_metropolice");
    combineNPCs.PushString("npc_rollermine");
    combineNPCs.PushString("npc_hunter");
    combineNPCs.PushString("npc_strider");
    combineNPCs.PushString("npc_stalker");

    resistanceNPCs = CreateArray(64, 10);
    resistanceNPCs.PushString("npc_alyx");
    resistanceNPCs.PushString("npc_barney");
    resistanceNPCs.PushString("npc_citizen");
    resistanceNPCs.PushString("npc_kliener");
    resistanceNPCs.PushString("npc_monk");
    resistanceNPCs.PushString("npc_mossman");
    resistanceNPCs.PushString("npc_vortigaunt");
    resistanceNPCs.PushString("npc_magnusson");

    alienNPCs = CreateArray(64, 10);
    alienNPCs.PushString("npc_antlion");
    alienNPCs.PushString("npc_antlionguard");
    alienNPCs.PushString("npc_fastzombie");
    alienNPCs.PushString("npc_headcrab");
    alienNPCs.PushString("npc_headcrab_black");
    alienNPCs.PushString("npc_headcrab_fast");
    alienNPCs.PushString("npc_poisonzombie");
    alienNPCs.PushString("npc_zombie");
    alienNPCs.PushString("npc_zombine");
    
    wildNPCs = CreateArray(64, 10);
    wildNPCs.PushString("npc_crow");
    wildNPCs.PushString("npc_pidgeon");
}

public void OnEntityDestroyed(int entity) 
{
    if (IsValidEntity(entity))
    {
        if (HasEntProp(entity, Prop_Send, "m_vecOrigin") && HasEntProp(entity, Prop_Send, "m_angRotation"))
        {
            float origin[3];
            GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);

            float angles[3];
            GetEntPropVector(entity, Prop_Send, "m_angRotation", angles);

            char classnameToSpawn[64];

            // determine what classnameToSpawn should be based on a random int
            switch (GetRandomInt(0, 2)) 
            {
                case 0:
                {
                    combineNPCs.GetString(GetRandomInt(0, combineNPCs.Length - 1), classnameToSpawn, 64);
                }
                case 1:
                {
                    resistanceNPCs.GetString(GetRandomInt(0, resistanceNPCs.Length - 1), classnameToSpawn, 64);
                }
                case 2:
                {
                    alienNPCs.GetString(GetRandomInt(0, alienNPCs.Length - 1), classnameToSpawn, 64);
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
                    case 2: { weapon = "weapon_shotty"; }
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
                        case 1: { DispatchKeyValue(npc, "model", "models/solider_prisonguard.mdl"); }
                    }
                }
            }
            else if (StrEqual(classnameToSpawn, "npc_citizen"))
            {
                // choose a random weapon for the citizen (pistol or smg or ar2 or shotty or rpg)
                char weapon[64];
                switch (GetRandomInt(0, 3))
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
                IntToString(GetRandomInt(0, 3), citizenType, 1);
                DispatchKeyValue(npc, "citizentype", citizenType);
            }
            else if (StrEqual(classnameToSpawn, "npc_barney"))
            {
                // if the NPC is barney, give him an ar2
                DispatchKeyValue(npc, "additionalequipment", "weapon_ar2");
            }

            // spawn the NPC in the right place
            DispatchSpawn(npc);
            TeleportEntity(npc, origin, angles, NULL_VECTOR);
        } 
    }

}