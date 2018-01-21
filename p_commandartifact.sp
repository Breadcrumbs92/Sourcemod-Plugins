#include <sourcemod>
#include <sdktools>
#pragma semicolon 1

public Plugin myinfo =
{
	name = "Artifact of Command",
	author = "Breadcrumbs",
	description = "Pheropods unlock powers untold",
	version = "1.2",
	url = "http://www.sourcemod.net/"
}

// The last weapon needs to be a global variable so that
// it can be recorded when a bugbait is thrown

int g_weapon[MAXPLAYERS + 1];
int g_ammo_drained[MAXPLAYERS + 1];

// Check for double-taps of the use key
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum)
{
	static bool bl_use_press[MAXPLAYERS + 1];
	static bool bl_prev_use_press[MAXPLAYERS + 1];
	static int i_use_releases[MAXPLAYERS + 1];
	static int i_use_timer[MAXPLAYERS + 1];
	bl_prev_use_press[client] = bl_use_press[client];
	
	if(buttons & IN_USE != 0)
	{
		bl_use_press[client] = true;
	}
	else
	{
		bl_use_press[client] = false;
		if(bl_prev_use_press[client] == true)
		{
			i_use_releases[client]++;
		}
	}
	
	if(i_use_releases[client] == 1)
	{
		i_use_timer[client]++;
		if(i_use_timer[client] == 15)
		{
			i_use_timer[client] = 0;
			i_use_releases[client] = 0;
		}
	}
	else if(i_use_releases[client] == 2)
	{
		f_ThrowBugbait(client, angles);
		i_use_timer[client] = 0;
		i_use_releases[client] = 0;
	}
}

static void f_ThrowBugbait(int i_client, float vec_viewangles[3])
{
	float vec_eye_position[3] = {0.0, 0.0, 0.0};
	float vec_forward[3] = {0.0, 0.0, 0.0};
	GetClientEyePosition(i_client, vec_eye_position);
		
	GetAngleVectors(vec_viewangles, vec_forward, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(vec_forward, 1000.0);
	
	int i_bugbait = CreateEntityByName("npc_grenade_bugbait");
	DispatchSpawn(i_bugbait);
	SetEntPropEnt(i_bugbait, Prop_Data, "m_hOwnerEntity", i_client);
	SetEntProp(i_bugbait, Prop_Data, "m_spawnflags", (GetEntProp(i_bugbait, Prop_Data, "m_spawnflags") + 0x800000)); 
	
	TeleportEntity(i_bugbait, vec_eye_position, NULL_VECTOR, vec_forward);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual("npc_grenade_bugbait", classname, true))
	{	
		RequestFrame(f_CheckBugbaitOwner, entity); 
	}
}

public void f_CheckBugbaitOwner(int i_entity)
{
	if(IsValidEntity(i_entity))
	{
		int i_owner = GetEntPropEnt(i_entity, Prop_Data, "m_hOwnerEntity");
		char string_weapon_classname[64];
		
		if(GetEntProp(i_entity, Prop_Data, "m_spawnflags") & 0x800000 != 0)
		{
			g_weapon[i_owner] = GetEntPropEnt(i_owner, Prop_Send, "m_hActiveWeapon");
			GetEntityClassname(g_weapon[i_owner], string_weapon_classname, 64);
			g_ammo_drained[i_owner] = f_DrainAmmo(i_owner, string_weapon_classname);
		}
		else
		{
			g_weapon[i_owner] = GetEntPropEnt(i_owner, Prop_Send, "m_hLastWeapon");
			GetEntityClassname(g_weapon[i_owner], string_weapon_classname, 64);
			g_ammo_drained[i_owner] = f_DrainAmmo(i_owner, string_weapon_classname);
		}
	}
}

//Check for bugbaits splatting on the ground
public void OnEntityDestroyed(int entity)
{
	char string_ent_classname[64];
	GetEntityClassname(entity, string_ent_classname, 64);
	
	if(StrEqual("npc_grenade_bugbait", string_ent_classname, true))
	{
		PrintToServer("Bugbait exploded");
		
		int i_owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
		if(IsValidEntity(i_owner))
		{
			char string_last_weapon[64];
			GetEntityClassname(g_weapon[i_owner], string_last_weapon, 64);
			
			float vec_bug_origin[3] = {0.0, 0.0, 0.0};
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vec_bug_origin);
			
			if(StrEqual(string_last_weapon, "weapon_pistol", true) && g_ammo_drained[i_owner] != 0)
			{	
				DataPack dp_implode = CreateDataPack();
				WritePackFloat(dp_implode, vec_bug_origin[0]);
				WritePackFloat(dp_implode, vec_bug_origin[1]);
				WritePackFloat(dp_implode, vec_bug_origin[2]);
				WritePackCell(dp_implode, g_ammo_drained[i_owner]);
				
				CreateTimer(0.1, f_ImplodeProps, dp_implode, TIMER_REPEAT);
			}
			else if(StrEqual(string_last_weapon, "weapon_357", true) && g_ammo_drained[i_owner] != 0)
			{			
				f_MakeEntsImmune(g_ammo_drained[i_owner], vec_bug_origin);
			}
			else if(StrEqual(string_last_weapon, "weapon_smg1", true) && g_ammo_drained[i_owner] != 0)
			{
				f_MakeRebel(g_ammo_drained[i_owner], vec_bug_origin);
			}
			else if(StrEqual(string_last_weapon, "weapon_ar2", true) && g_ammo_drained[i_owner] != 0)
			{
				f_DisarmExplosives(g_ammo_drained[i_owner], vec_bug_origin);
			}
			else if(StrEqual(string_last_weapon, "weapon_shotgun", true) && g_ammo_drained[i_owner] != 0)
			{
				f_Decimate(g_ammo_drained[i_owner], vec_bug_origin);
			}
		}
	}
}

// The pistol's effect is to cause props to be sucked into where the bugbait landed.
public Action f_ImplodeProps(Handle Timer01, any pack)
{	
	static int i_times_pulled = 0;

	for(int i = 1; i <= GetEntityCount(); i++)
	{
		ResetPack(pack, false);
		
		if(IsValidEntity(i))
		{
			char string_classname[64];
			GetEntityClassname(i, string_classname, 64);
				
			// Entities in this string will be affected by implosions
			char string_imploding_ents[1024] = "prop_physics item_item_crate npc_grenade_frag npc_rollermine npc_manhack npc_turrent_floor";
				
			if(StrContains(string_imploding_ents, string_classname, true) != -1
			|| StrContains(string_classname, "item_", true) != -1
			|| StrContains(string_classname, "weapon_", true) != -1)
			{
				float vec_splat_origin[3] = {0.0, 0.0, 0.0};
				vec_splat_origin[0] = ReadPackFloat(pack);
				vec_splat_origin[1] = ReadPackFloat(pack);
				vec_splat_origin[2] = ReadPackFloat(pack);
				
				int i_ammo = ReadPackCell(pack);
	
				float vec_prop_origin[3] = {0.0, 0.0, 0.0};
				float vec_push[3] = {0.0, 0.0, 0.0};
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", vec_prop_origin);

				SubtractVectors(vec_splat_origin, vec_prop_origin, vec_push);
				float fl_push_length = GetVectorLength(vec_push, false);
			
				ScaleVector(vec_push, (3000.0 * i_ammo/(fl_push_length * fl_push_length)));
	
				// Only push entities if the vector is significant
				if(GetVectorLength(vec_push, false) > 100.0)
				{
					TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, vec_push);
				}
	
				if(i_times_pulled >= 14)
				{
					i_times_pulled = 0;
					CloseHandle(pack);
					return Plugin_Stop;
				}	
			}
		}
	}
	i_times_pulled++;
	return Plugin_Continue;
}

// The ar2's effect is to destroy combine balls and explosive barrels
public void f_DisarmExplosives(int i_ammo, float[3] vec_splat_origin)
{
	int i_ball_index = -1;
	int i_prop_index = -1;
	
	while((i_ball_index = FindEntityByClassname(i_ball_index, "prop_combine_ball")) != -1)
	{
		float vec_origin[3] = {0.0, 0.0, 0.0};
		GetEntPropVector(i_ball_index, Prop_Send, "m_vecOrigin", vec_origin);
		
		float fl_distance = GetVectorDistance(vec_splat_origin, vec_origin);
		if(fl_distance < 25 * i_ammo)
		{
			AcceptEntityInput(i_ball_index, "Explode");
			
			int i_battery = CreateEntityByName("item_battery");
			DispatchSpawn(i_battery);
			TeleportEntity(i_battery, vec_origin, NULL_VECTOR, NULL_VECTOR);
		}
	}
	
	while((i_prop_index = FindEntityByClassname(i_prop_index, "prop_physics")) != -1)	
	{
		char string_prop_modelname[128];
		GetEntPropString(i_prop_index, Prop_Data, "m_ModelName", string_prop_modelname, 64);
		PrintToServer(string_prop_modelname);
		
		if(StrEqual(string_prop_modelname, "models/props_c17/oildrum001_explosive.mdl", true))
		{
			float vec_origin[3] = {0.0, 0.0, 0.0};
			GetEntPropVector(i_prop_index, Prop_Send, "m_vecOrigin", vec_origin);
		
			float fl_distance = GetVectorDistance(vec_splat_origin, vec_origin);
			if(fl_distance < 50 * i_ammo)
			{
				AcceptEntityInput(i_prop_index, "Break");
			
				int i_kit = CreateEntityByName("item_healthkit");
				DispatchSpawn(i_kit);
				TeleportEntity(i_kit, vec_origin, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
} 

//The SMG's effect is to spawn a rebel
public void f_MakeRebel(int i_ammo, float[3] vec_splat_origin)
{
	if(i_ammo == 45)
	{
		int i_guy = CreateEntityByName("npc_citizen");
		SetEntProp(i_guy, Prop_Data, "m_Type", 2);
		int i_weapon_decide = GetRandomInt(0, 2);
		
		if(i_weapon_decide == 0)
		{
			DispatchKeyValue(i_guy, "additionalequipment", "weapon_ar2");
		}
		else if(i_weapon_decide == 1)
		{
			DispatchKeyValue(i_guy, "additionalequipment", "weapon_smg1");
		}
		else if(i_weapon_decide == 2)
		{
			DispatchKeyValue(i_guy, "additionalequipment", "weapon_shotgun");
		}
		DispatchSpawn(i_guy);
		TeleportEntity(i_guy, vec_splat_origin, NULL_VECTOR, NULL_VECTOR);
		
		CreateTimer(GetRandomFloat(30.0, 60.0), f_ExplodeRebels, i_guy, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action f_ExplodeRebels(Handle Timer03, int i_guy)
{
	for(int j = 0; j < GetRandomInt(5, 7); j++)
	{
		float vec_origin[3] = {0.0, 0.0, 0.0};
		GetEntPropVector(i_guy, Prop_Send, "m_vecOrigin", vec_origin);
	
		int i_barrel = CreateEntityByName("prop_physics");
		DispatchKeyValue(i_barrel, "model", "models/props_c17/oildrum001_explosive.mdl");
		DispatchSpawn(i_barrel);
		TeleportEntity(i_barrel, vec_origin, NULL_VECTOR, NULL_VECTOR);
		RequestFrame(f_BounceExplosives, i_barrel); 
	}
	
	AcceptEntityInput(i_guy, "Kill");
}

public void f_BounceExplosives(int i_barrel)
{
	float vec_random_velocity_vector[3] = {0.0, 0.0, 0.0};
	vec_random_velocity_vector[0] = GetRandomFloat(-700.0, 700.0);
	vec_random_velocity_vector[1] = GetRandomFloat(-700.0, 700.0);
	vec_random_velocity_vector[2] = GetRandomFloat(250.0, 300.0);
	
	TeleportEntity(i_barrel, NULL_VECTOR, NULL_VECTOR, vec_random_velocity_vector);
}

// The magnum's effect is to make things in a radius immune
public void f_MakeEntsImmune(int i_ammo, float[3] vec_splat_origin)
{
	int i_filter = CreateEntityByName("filter_damage_type");
	DispatchKeyValueFloat(i_filter, "damagetype", 16384.0);
	DispatchKeyValue(i_filter, "targetname", "fdt_357immune");
	
	for(int i = 1; i <= GetEntityCount(); i++)
	{
		if(IsValidEntity(i))
		{
			char string_entity_classname[64];
			GetEntityClassname(i, string_entity_classname, 64);
			
			if(StrContains(string_entity_classname, "npc_", true) != -1
			|| StrContains(string_entity_classname, "prop_", true) != -1
			|| StrEqual(string_entity_classname, "player", true))
			{
				float vec_origin[3] = {0.0, 0.0, 0.0};
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", vec_origin);
			
				float fl_distance = GetVectorDistance(vec_origin, vec_splat_origin, false);
				if(fl_distance < 25 * i_ammo)
				{
					SetVariantString("fdt_357immune");
					AcceptEntityInput(i, "SetDamageFilter");
					
					float vec_bump[3] = {0.0, 0.0, 100.0};
					TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, vec_bump);
				}
			} 
		}
	}
	
	CreateTimer(3.0, f_StopImmunity, i_filter, TIMER_FLAG_NO_MAPCHANGE);
}

public Action f_StopImmunity(Handle Timer02, int i_filter)
{
	AcceptEntityInput(i_filter, "Kill");
}

// The shotgun's function is to set everything in a 
// certain radius's health to 1 for a short amount of time
public void f_Decimate(int i_ammo, float[3] vec_splat_origin)
{
	for(int i = 1; i <= GetEntityCount(); i++)
	{
		if(IsValidEntity(i))
		{
			char str_classname[64];
			GetEntityClassname(i, str_classname, sizeof(str_classname));
			
			if(HasEntProp(i, Prop_Data, "m_iHealth") && 
			HasEntProp(i, Prop_Send, "m_vecOrigin") &&
			!StrEqual(str_classname, "npc_alyx") &&
			!StrEqual(str_classname, "npc_barney"))
			{
				float vec_origin[3] = {0.0, 0.0, 0.0};
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", vec_origin);
				
				float fl_distance = GetVectorDistance(vec_origin, vec_splat_origin, false);
				if(fl_distance < 25 * i_ammo)
				{
					int i_curhealth = GetEntProp(i, Prop_Data, "m_iHealth");
					
					DataPack dp_hp = CreateDataPack();
					ResetPack(dp_hp);
					WritePackCell(dp_hp, i);
					WritePackCell(dp_hp, i_curhealth);
					
					SetEntProp(i, Prop_Data, "m_iHealth", 1);
					CreateTimer(5.0, f_RestoreHealth, dp_hp, TIMER_FLAG_NO_MAPCHANGE);
					
					PrintToServer("Got a %s", str_classname);
				}
			}
		}
	}
}

public Action f_RestoreHealth(Handle Timer04, DataPack dp_info)
{
	ResetPack(dp_info);
	int i_entity = ReadPackCell(dp_info);
	int i_health = ReadPackCell(dp_info);
	SetEntProp(i_entity, Prop_Data, "m_iHealth", i_health);
}

// Returns amount of ammo drained, or -1 if weapon is invalid
static int f_DrainAmmo(int i_client, const char[] string_last_weapon)
{
	int i_ammo_offset = 0;
	
	if(StrEqual(string_last_weapon, "weapon_pistol", true) == true)
	{
		i_ammo_offset = 1824;
		return f_EmptyClipAndReserve(i_client, i_ammo_offset, 18);
	}
	else if(StrEqual(string_last_weapon, "weapon_357", true) == true)
	{
		i_ammo_offset = 1832;
		return f_EmptyClipAndReserve(i_client, i_ammo_offset);
	}
	else if(StrEqual(string_last_weapon, "weapon_smg1", true) == true)
	{
		i_ammo_offset = 1828;
		return f_EmptyClipAndReserve(i_client, i_ammo_offset, 45);
	}
	else if(StrEqual(string_last_weapon, "weapon_ar2", true) == true)
	{
		i_ammo_offset = 1816;
		return f_EmptyClipAndReserve(i_client, i_ammo_offset);
	}
	else if(StrEqual(string_last_weapon, "weapon_shotgun", true) == true)
	{
		i_ammo_offset = 1840;
		return f_EmptyClipAndReserve(i_client, i_ammo_offset);
	}
	else if(StrEqual(string_last_weapon, "weapon_crossbow", true) == true)
	{
		i_ammo_offset = 1836;
		return f_EmptyClipAndReserve(i_client, i_ammo_offset);
	}
	else
	{
		// Return -1 if we didn't find an appropriate weapon
		return -1;
	}
}

// Returns amount of ammo drained
// Warning: Beware of math jungle, very hard to read function ahead
static int f_EmptyClipAndReserve(int i_client, int i_ammo_offset, int i_max_removable_ammo = -1)
{
	int i_clip_ammo = GetEntProp(g_weapon[i_client], Prop_Data, "m_iClip1");
	int i_reserve_ammo = GetEntData(i_client, i_ammo_offset, 4);
	int i_removed_ammo = 0;
	
	// If no max is specified, remove all ammo
	if(i_max_removable_ammo == -1)
	{
		SetEntProp(g_weapon[i_client], Prop_Data, "m_iClip1", 0);
		SetEntData(i_client, i_ammo_offset, 0, 4, true);
		
		i_removed_ammo = i_reserve_ammo + i_clip_ammo;
	}
	else if(i_max_removable_ammo > 0)
	{
		int i_ammo_overflow = 0;
		if(i_max_removable_ammo > i_reserve_ammo)
		{
			SetEntData(i_client, i_ammo_offset, 0, 4, true);
			i_ammo_overflow = i_max_removable_ammo - i_reserve_ammo; 
			SetEntProp(g_weapon[i_client], Prop_Data, "m_iClip1", i_clip_ammo - i_ammo_overflow);
			if(i_ammo_overflow > i_clip_ammo)
			{
				i_removed_ammo = i_clip_ammo + i_reserve_ammo;
				SetEntProp(g_weapon[i_client], Prop_Data, "m_iClip1", 0);
			}
			else
			{
				i_removed_ammo = i_max_removable_ammo;
			}
		}
		else
		{
			SetEntData(i_client, i_ammo_offset, i_reserve_ammo - i_max_removable_ammo, 4, true);
			i_removed_ammo = i_max_removable_ammo;
		}
	}

	return i_removed_ammo;
}

bool HasEntProp(int entity, PropType type, const char[] prop)
{
	if(type == Prop_Data) 
	{
		return (FindDataMapInfo(entity, prop) != -1);
	}

	if(type != Prop_Send) 
	{
		return false;
	}

	char cls[64];
	if(!GetEntityNetClass(entity, cls, sizeof(cls))) 
	{
		return false;
	}

	return (FindSendPropInfo(cls, prop) != -1);
}

