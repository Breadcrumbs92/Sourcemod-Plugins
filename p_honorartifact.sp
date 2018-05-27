#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

public Plugin myinfo =
{
	name = "Artifact of Honor",
	author = "Breadcrumbs",
	description = "Headshots or else",
	version = "0.0",
	url = "http://www.sourcemod.net/"
}

char transmutableEnts[1024] = "npc_metropolice npc_combine_s npc_antlion npc_zombie npc_poisonzombie npc_fastzombie npc_headcrab npc_headcrab_black npc_headcrab_fast npc_manhack npc_rollermine npc_barnacle npc_zombine npc_hunter npc_citizen prop_physics item_item_crate item_healthkit item_battery weapon_pistol weapon_357 weapon_smg weapon_ar2 weapon_shotgun weapon_frag weapon_rpg item_ammo_357 item_ammo_ar2 item_ammo_pistol item_ammo_smg item_healthvial";

int explosionSprite;

public void OnPluginStart()
{
	explosionSprite = PrecacheModel("sprites/sprite_fire01.vmt");
}

public void OnAttack(int victim, int attacker, int inflictor, float damage, int damagetype, int ammotype, int hitbox, int hitgroup)
{
	char attackerName[64];
	GetEntityClassname(attacker, attackerName, 64);
	
	if(StrEqual(attackerName, "player"))
	{
		int barrel = CreateEntityByName("prop_physics");
		DispatchKeyValue(barrel, "model", "models/props_c17/oildrum001_explosive.mdl");
		DispatchSpawn(barrel);
		
		float targetOrigin[3] = {0.0, 0.0, 0.0};
		GetEntPropVector(victim, Prop_Send, "m_vecOrigin", targetOrigin);
		
		char victimName[64];
		GetEntityClassname(victim, victimName, 64);
		
		if(StrEqual(victimName, "prop_physics") || StrEqual(victimName, "prop_static") || victim == 0)
		{
			GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", targetOrigin);
			TeleportEntity(barrel, targetOrigin, NULL_VECTOR, NULL_VECTOR);
			RequestFrame(ExplodeBarrel, barrel);
			
			return;
		}
		
		if(hitbox == 1)
		{
			TeleportEntity(barrel, targetOrigin, NULL_VECTOR, NULL_VECTOR);
			RequestFrame(ExplodeBarrel, barrel);
		}
		else
		{
			// Hurt the player for 50 damage
			int curHealth = GetClientHealth(attacker);
			SetVariantInt(curHealth - 50);
			AcceptEntityInput(attacker, "SetHealth");
			
			// Create an explosion effect
			MakeExplosion(targetOrigin);
			
			// Transform all eligible entities in a radius into combine elite
			for(int i = 0; i < GetMaxEntities(); i++)
			{
				if(IsValidEntity(i))
				{
					char classname[64];
					GetEntityClassname(i, classname, 64);
					if(StrContains(transmutableEnts, classname, true) != -1)
					{
						float origin[3] = {0.0, 0.0, 0.0};
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", origin);
						float dist = GetVectorDistance(origin, targetOrigin);
					
						if(dist < 200)
						{	
							DataPack dp = CreateDataPack();
							dp.Reset(false);
							dp.WriteFloat(origin[0]);
							dp.WriteFloat(origin[1]);
							dp.WriteFloat(origin[2]);
							dp.WriteCell(i);
							RequestFrame(MakeCombine, dp);	
						}
					}
				}
			}
		}
	}
}

public void MakeCombine(DataPack dp)
{
	dp.Reset(false);
	float origin[3] = {0.0, 0.0, 0.0};
	origin[0] = dp.ReadFloat();
	origin[1] = dp.ReadFloat();
	origin[2] = dp.ReadFloat();
	int entity = dp.ReadCell();
	
	float angles[3] = {0.0, 0.0, 0.0};
	GetEntPropVector(entity, Prop_Send, "m_angRotation", angles);
	angles[1] = 0.0;
							
	AcceptEntityInput(entity, "Kill");
						
	int crunchy = CreateEntityByName("npc_combine_s");
	DispatchKeyValue(crunchy, "additionalequipment", "weapon_ar2");
	SetEntProp(crunchy, Prop_Data, "m_fIsElite", 1);
	DispatchSpawn(crunchy);
	TeleportEntity(crunchy, origin, angles, NULL_VECTOR);
	
	CloseHandle(dp);
}

public void MakeExplosion(float[3] origin)
{
	TE_SetupExplosion(origin, explosionSprite, 5.0, 1, 0, 1, 1);
	TE_SendToAll(0.0);
}

public void ExplodeBarrel(int barrel)
{
	AcceptEntityInput(barrel, "Break");
}

public void SearchForEntities()
{
	for(int i = 0; i < GetMaxEntities(); i++)
	{
		if(IsValidEntity(i))
		{
			char classname[64];
			GetEntityClassname(i, classname, 64);
			
			if(StrContains(classname, "npc_", true) != -1 || StrEqual(classname, "prop_physics") || StrEqual(classname, "prop_static") || i == 0)
			{
				SDKUnhook(i, SDKHook_TraceAttackPost, OnAttack);
				SDKHook(i, SDKHook_TraceAttackPost, OnAttack);
			}
		}
	}
}

public void OnEntityCreated()
{
	SearchForEntities();
}

public void HurtPlayer(int client, int damage)
{
	SetEntProp(client, Prop_Send, "m_iHealth", GetClientHealth(client) - damage);
}
