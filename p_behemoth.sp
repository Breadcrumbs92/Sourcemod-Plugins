#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

public Plugin myinfo = {
    name = "Arifact of The Behemoth",
    author = "Breadcrumbs",
    description = "Everyone's attacks explode, except for yours.",
    version = "0.1",
    url = "http://www.sourcemod.net/"
};

public Action OnDamageEvent(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3]) {
    char victimClassname[64];
    char attackerClassname[64];
    char weaponClassname[64];

    GetEntityClassname(victim, victimClassname, 64);
    GetEntityClassname(attacker, attackerClassname, 64);
    GetEntityClassname(weapon, weaponClassname, 64);

    PrintToChatAll("%s was attacked by %s with a %s at {%f, %f, %f}", victimClassname, attackerClassname, weaponClassname, damagePosition[0], damagePosition[1], damagePosition[2]);
}

public void OnMapStart() {
    PrintToChatAll("Literally everyone but you picked up: The Brilliant Behemoth");

    // put a traceattack hook on every eligible entity on the map
    for (int i = 0; i < GetMaxEntities(); i++) {
        if (IsValidEntity(i)) {
            char classname[64];
            GetEntityClassname(i, classname, 64);

            if(StrContains(classname, "npc_", true) != -1 || StrEqual(classname, "prop_physics") || StrEqual(classname, "prop_static") || i == 0) {
                SDKUnhook(i, SDKHook_TraceAttackPost, OnDamageEvent);   
                SDKHook(i, SDKHook_TraceAttackPost, OnDamageEvent);
            }
        }
    }
}
