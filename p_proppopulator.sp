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

int propsToAdd = 500;       // Amount of new props to create on the map
int numProps = 0;           // Variable to store the amount of pre-existing prop_physics on a map
ArrayList propNames;        // List to store names of valid (spawnable) prop models
ArrayList existingProps;    // Datapack storing index of every pre-existing prop_physics
ConVar cvMakeSingularities; // CVar to enable/disable spawning of black and white holes

char breakables[1024] = "models/props_c17/oildrum001_explosive.mdl models/props_junk/wood_crate001a.mdl models/props_junk/wood_crate002a.mdl models/props_canal/boat001a.mdl models/props_junk/gascan001a.mdl models/props_interiors/furniture_shelf01a.mdl models/props_junk/wood_pallet001a.mdl models/props_combine/breenbust.mdl models/props_junk/cardboard_box001a.mdl models/props_junk/watermelon01.mdl models/props_c17/canister02a.mdl models/props_c17/bench01a.mdl models/props_c17/furnituredrawer003a.mdl models/props_c17/furnituretable003a.mdl models/props_wasteland/cafeteria_table.001a.mdl models/props_wasteland/wood_fence01a.mdl models/props_junk/glassbottle01a.mdl";

public void OnPluginStart()
{
	// Initialize list of valid prop models
	propNames = CreateArray(64, 64);

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
	propNames.SetString(32, "models/props_trainstation/trashcan_indoor001a.mdl");
	propNames.SetString(33, "models/props_c17/canister02a.mdl");
	propNames.SetString(34, "models/props_rooftop/sign_letter_f001b.mdl");
	propNames.SetString(35, "models/props_c17/canister_propane01a.mdl");
	propNames.SetString(36, "models/props_c17/bench01a.mdl");
	propNames.SetString(37, "models/props_c17/chair02a.mdl");
	propNames.SetString(38, "models/props_c17/chair_office01a.mdl");
	propNames.SetString(39, "models/props_c17/consolebox01a.mdl");
	propNames.SetString(40, "models/props_c17/furnituredrawer003a.mdl");
	propNames.SetString(41, "models/props_c17/furnituretable003a.mdl");
	propNames.SetString(42, "models/props_c17/tv_monitor01.mdl");
	propNames.SetString(43, "models/props_combine/combine_barricade_short01a.mdl");
	propNames.SetString(44, "models/props_combine/combine_interface002.mdl");
	propNames.SetString(45, "models/props_lab/monitor02.mdl");
	propNames.SetString(45, "models/props_lab/reciever01d.mdl");
	propNames.SetString(46, "models/props_vehicles/tire001c_car.mdl");
	propNames.SetString(47, "models/props_vehicles/car003b_physics.mdl");
	propNames.SetString(48, "models/props_wasteland/cafeteria_table.001a.mdl");
	propNames.SetString(49, "models/props_wasteland/controlroom_chair001a.mdl");
	propNames.SetString(50, "models/props_wasteland/controlroom_desk001b.mdl");
	propNames.SetString(51, "models/props_wasteland/controlroom_filecabinet001a.mdl");
	propNames.SetString(52, "models/props_wasteland/controlroom_storagecloset001b.mdl");
	propNames.SetString(53, "models/props_wasteland/wood_fence01a.mdl");
	propNames.SetString(54, "models/props_wasteland/kitchen_counter001a.mdl");
	propNames.SetString(55, "models/props_wasteland/wood_fence01a.mdl");
	propNames.SetString(56, "models/props_junk/bicycle01a.mdl");
	propNames.SetString(57, "models/props_junk/sawblade001a.mdl");
	propNames.SetString(58, "models/props_junk/metal_paintcan001a.mdl");
	propNames.SetString(59, "models/props_junk/metalbucket02a.mdl");
	propNames.SetString(60, "models/props_junk/cinderblock01a.mdl");
	propNames.SetString(61, "models/props_junk/glassbottle01a.mdl");
	propNames.SetString(62, "models/props_docks/channelmarker02a.mdl");
	propNames.SetString(63, "models/props_c17/furnitureboiler001a.mdl");

	cvMakeSingularities = CreateConVar("trash_do_singularities",
	                                   "1",
							                       "Whether or not to create black and white holes along with props.",
							                       FCVAR_NOTIFY,
							                       true,
							                       0.0,
							                       true,
							                       1.0);
}

public void OnMapStart()
{
	// When the map starts, find every prop_physics and store it in a Datapack
	CreateTimer(0.3, CreatePropList, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action CreatePropList(Handle timer)
{
	existingProps = ListPropPhysics();
	numProps = existingProps.Length;

	// Create a damagefilter to protect spawned props from falling damage
	int filter = CreateEntityByName("filter_damage_type");
	DispatchKeyValueFloat(filter, "damagetype", 16384.0);
	DispatchKeyValue(filter, "targetname", "filter_immune");
	DispatchSpawn(filter);

	// Populate the map with new props
	PopulateMap(filter);
	PrintToServer("%i", numProps);
}

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
			PrintToServer("TRASH: Too close to entity limit to make more props, aborting");
		}

		bool success = false;
		int ent = existingProps.Get(GetRandomInt(0, numProps - 1));

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
public ArrayList ListPropPhysics()
{
	ArrayList props = CreateArray(2, 1);
	int amtProps = 0;

	for(int i = 0; i < GetMaxEntities(); i++)
	{
		if(IsValidEntity(i))
		{
			char classname[64];
			GetEntityClassname(i, classname, 64);

			if(StrEqual("prop_physics", classname))
			{
				props.Push(i);
				amtProps++;
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
