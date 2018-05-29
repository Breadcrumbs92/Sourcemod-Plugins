#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

public Plugin myinfo =
{
	name = "Aritfact of Trash",
	author = "Breadcrumbs",
	description = "Props invade the map",
	version = "0.0",
	url = "http://www.sourcemod.net/"
}

int propsToAdd = 500;   // Amount of new props to create on the map
int numPhysProps = 0;   // Variable to store the amount of pre-existing prop_physics on a map
ArrayList propNames;    // List to store names of valid (spawnable) prop models
DataPack existingProps; // Datapack storing index of every pre-existing prop_physics

char breakables[1024] = "models/props_c17/oildrum001_explosive.mdl models/props_junk/wood_crate001a.mdl models/props_junk/wood_crate002a.mdl models/props_canal/boat001a.mdl models/props_junk/gascan001a.mdl models/props_interiors/furniture_shelf01a.mdl models/props_junk/wood_pallet001a.mdl models/props_combine/breenbust.mdl models/props_junk/cardboard_box001a.mdl models/props_junk/watermelon01.mdl";

public void OnPluginStart()
{
	// Initialize list of valid prop models
	propNames = CreateArray(64, 32);

	propNames.SetString(0, "models/props_junk/wood_crate001a.mdl"); 
	propNames.SetString(1, "models/props_junk/wood_crate002a.mdl"); 
	propNames.SetString(2, "models/props_junk/cardboard_box001a.mdl"); 
	propNames.SetString(3, "models/props_junk/ibeam01a_cluster01.mdl"); 
	propNames.SetString(4, "models/props_junk/pushcart01a.mdl"); 
	propNames.SetString(5, "models/props_junk/wood_pallet001a.mdl"); 
	propNames.SetString(6, "models/props_c17/oildrum001_explosive.mdl"); 
	propNames.SetString(7, "models/props_c17/oildrum001.mdl"); 
	propNames.SetString(8, "models/props_c17/lockers001a.mdl"); 
	propNames.SetString(9, "models/props_docks/channelmarker01a.mdl");
	propNames.SetString(10, "models/props_interiors/radiator01a.mdl");
	propNames.SetString(11, "models/props_interiors/refrigerator01a.mdl");
	propNames.SetString(12, "models/props_interiors/vendingmachinesoda01a.mdl");
	propNames.SetString(13, "models/props_interiors/furniture_shelf01a.mdl");
	propNames.SetString(14, "models/props_interiors/bathtub01a.mdl");
	propNames.SetString(15, "models/props_interiors/furniture_couch01a.mdl");
	propNames.SetString(16, "models/props_junk/watermelon01.mdl");
	propNames.SetString(17, "models/props_doors/door03_slotted_left.mdl");
	propNames.SetString(18, "models/props_canal/boat001a.mdl");
	propNames.SetString(19, "models/props_combine/breenbust.mdl");
	propNames.SetString(20, "models/props_c17/furniturestove001a.mdl");
	propNames.SetString(21, "models/props_c17/furniturewashingmachine001a.mdl");
	propNames.SetString(22, "models/props_c17/trappropeller_engine.mdl");
	propNames.SetString(23, "models/props_c17/oildrum001_explosive.mdl");
	propNames.SetString(24, "models/props_borealis/bluebarrel001.mdl");
	propNames.SetString(25, "models/props_trainstation/bench_indoor001a.mdl");
	propNames.SetString(26, "models/props_trainstation/pole_448connection001a.mdl");
	propNames.SetString(27, "models/props_junk/trafficcone001a.mdl");
	propNames.SetString(28, "models/props_junk/trashdumpster01a.mdl");
	propNames.SetString(29, "models/props_junk/metalgascan.mdl");
	propNames.SetString(30, "models/props_junk/gascan001a.mdl");
	propNames.SetString(31, "models/props_pipes/concrete_pipe001a.mdl");
}

public void OnMapStart()
{
	// When the map starts, find every prop_physics and store it in a Datapack
	CreateTimer(0.3, CreatePropList, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action CreatePropList(Handle timer)
{
	existingProps = ListPropPhysics();
	numPhysProps = existingProps.Position;
	existingProps.Reset();
	
	// Create a damagefilter to protect spawned props from falling damage
	// Props can only take damage from drowning, effectively making them immune
	int filter = CreateEntityByName("filter_damage_type");
	DispatchKeyValueFloat(filter, "damagetype", 16384.0); 
	DispatchKeyValue(filter, "targetname", "filter_immune");
	DispatchSpawn(filter);
	
	// Populate the map with new props
	PopulateMap(filter);
	PrintToServer("%i", numPhysProps);
}

/*
public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "prop_physics") || StrEqual(classname, "prop_physics_override"))
	{
		SDKUnhook(entity, SDKHook_TraceAttackPost, OnAttack);
		SDKHook(entity, SDKHook_TraceAttackPost, OnAttack);
	}
}
*/

/*

public void OnAttack(int victim, int attacker, int inflictor, float damage, int damagetype, int ammotype, int hitbox, int hitgroup)
{
	char attackerName[64];
	GetEntityClassname(attacker, attackerName, 64);
	
	if(StrEqual(attackerName, "player"))
	{
		int client = attacker;
	
		float clientPos[3] = {0.0, 0.0, 0.0};
		float clientAng[3] = {0.0, 0.0, 0.0};
		GetClientEyePosition(client, clientPos);
		GetClientEyeAngles(client, clientAng);
	
		Handle ray = TR_TraceRayFilterEx(clientPos, clientAng, MASK_SOLID, RayType_Infinite, NoPlayerFilter);
		
		float hitPos[3] = {0.0, 0.0, 0.0};
		TR_GetEndPosition(hitPos, ray);
		
		int physEx = CreateEntityByName("env_physexplosion");
		DispatchKeyValue(physEx, "magnitude", "100.0");
		DispatchKeyValue(physEx, "radius", "300");
		
		SetVariantString("spawnflags 1");
		AcceptEntityInput(physEx, "AddOutput");
		
		DispatchSpawn(physEx);
		TeleportEntity(physEx, hitPos, NULL_VECTOR, NULL_VECTOR);
		ActivateEntity(physEx);
		AcceptEntityInput(physEx, "Explode");
		
		AcceptEntityInput(physEx, "Kill");
		ray.Close();
	}
}
*/

// ------------------------------------------
// Attempts to create a random prop at a given point
// If there is something in the way, it fails and returns false
// If it succeeds, returns true
//-------------------------------------------
static bool CreateProp(float[3] origin, int filter)
{
	// Create a hull trace to check if something is in the way of spawning the prop
	float mins[3] = {-48.0, -48.0, -48.0};
	float maxs[3] = {48.0, 48.0, 48.0};
	Handle hullTrace = TR_TraceHullEx(origin, origin, mins, maxs, MASK_PLAYERSOLID);
	
	if(TR_DidHit(hullTrace) || TR_PointOutsideWorld(origin))
	{
		// Something is in the way or we're trying to spawn in the void, so fail and return false
		hullTrace.Close();
		return false;
	}
	else
	{
		// Generate a random velocity vector
		float randVector[3] = {0.0, 0.0, 0.0};
		randVector[0] = GetRandomFloat(-1024.0, 1024.0);
		randVector[1] = GetRandomFloat(-1024.0, 1024.0);
		randVector[2] = GetRandomFloat(-1024.0, 1024.0);
		
		// Get a random prop model from the predefined list
		char randomPropName[64];
		propNames.GetString(GetRandomInt(0, propNames.Length - 1), randomPropName, 64);
		
		// Create the prop
		int prop;
		
		if(StrContains(breakables, randomPropName) != -1)
		{
			prop = CreateEntityByName("prop_physics");
		}
		else
		{
			// A prop_physics_override is used to make more prop models usable
			prop = CreateEntityByName("prop_physics_override");
		}
		DispatchKeyValue(prop, "model", randomPropName);

		// Props are made immune to damage 2 seconds after spawning
		// This prevents breakables from permaturely breaking
		SetVariantString("immune_filter");
		AcceptEntityInput(prop, "SetDamageFilter");
		CreateTimer(2.0, DestroyFilter, filter, TIMER_FLAG_NO_MAPCHANGE);
		
		// Spawn prop, push it with the random velocity vector
		DispatchSpawn(prop);
		TeleportEntity(prop, origin, NULL_VECTOR, randVector);
		SetEntPropVector(prop, Prop_Data, "m_vecAbsVelocity", Float:{0.0, 0.0, 0.0});
		
		hullTrace.Close();
		
		return true; 
	}
}

public Action DestroyFilter(Handle timer, int filter)
{
	AcceptEntityInput(filter, "Kill");
}

//-----------------------------------------------------
// Spawns random props all around the map
// Props are spawned around existing prop_physics -
// This ensures they stay at least vaguely inside of the playable area
//-----------------------------------------------------
public void PopulateMap(int filter)
{
	for(int i = 0; i < propsToAdd; i++)
	{
		if(GetEntityCount() > GetMaxEntities() - 200)
		{
			PrintToServer("TrashArtifact: Too close to entity limit to make more props, aborting");
		}
		
		bool success = false;
		existingProps.Reset();
		
		int propIndex;
		int ent = 0;
		while(ent == 0)
		{
			propIndex = GetRandomInt(0, numPhysProps - 10);
			SetPackPosition(existingProps, propIndex);
			ent = existingProps.ReadCell();
		}

		int radiusSize = 512;
		int attempts = 0;
		while(!success && attempts < 256)
		{
			float origin[3] = {0.0, 0.0, 0.0};
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", origin);
			
			origin[0] += GetRandomInt(-radiusSize, radiusSize);
			origin[1] += GetRandomInt(-radiusSize, radiusSize);
			origin[2] += GetRandomInt(-radiusSize, radiusSize);	
			
			success = CreateProp(origin, filter);			
			attempts++;
		}
	}
}

//-----------------------------------------------------
// Enumerates through every single prop_physics that already exists on the map
// Then puts each one's index into a datapack
//-----------------------------------------------------
public DataPack ListPropPhysics()
{
	DataPack props = CreateDataPack();
	props.Reset();
	int numProps = 0;
	
	for(int i = 0; i < GetMaxEntities(); i++)
	{
		if(IsValidEntity(i))
		{
			char classname[64];
			GetEntityClassname(i, classname, 64);
		
			if(StrEqual("prop_physics", classname))
			{
				props.WriteCell(i);
				PrintToServer("%i", i);
				numProps++;
			}
		}
	}
	
	return props;
}

public bool NoPlayerFilter(int entity, int contentsMask)
{
	char classname[64];
	GetEntityClassname(entity, classname, 64);
	
	if(StrEqual(classname, "player"))
	{
		return false;
	}
	
	return true;
}
