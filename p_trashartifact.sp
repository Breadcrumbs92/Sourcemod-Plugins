#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

// IMPORTANT: Definitions for singularity types need to start from 0 and increase by 1!
#define SINGULARITY_TIMER -1
#define BLACK_HOLE 0
#define WHITE_HOLE 1
#define SINGULARITY_TYPES 2

public Plugin myinfo =
{
	name = "Aritfact of Trash",
	author = "Breadcrumbs",
	description = "Props invade the map",
	version = "1.1",
	url = "http://www.sourcemod.net/"
}

// -- GLOBAL VARS
float bhOrigin[3] = {0.0, 0.0, 0.0};   // Center of black hole
float whOrigin[3] = {0.0, 0.0, 0.0};   // Center of white hole

int propsToAdd = 500;                  // Amount of new props to create on the map
int numProps;                          // Variable to store the amount of pre-existing prop_physics on a map
float sngStrength = 5000.0;            // Current strength of the black and white holes
ArrayList propNames;                   // List to store names of valid (spawnable) prop models
ArrayList existingProps;               // Arraylist storing index of every pre-existing prop_physics
ConVar cvMakeSingularities;            // CVar to enable/disable spawning of black and white holes
Handle sngLoop;                        // Handle to the timer that deals with singularity logic
Handle velocityCall;                   // Fuck you, sourcemod
char breakables[1024] = "models/props_c17/oildrum001_explosive.mdl models/props_junk/wood_crate001a.mdl models/props_junk/wood_crate002a.mdl models/props_canal/boat001a.mdl models/props_junk/gascan001a.mdl models/props_interiors/furniture_shelf01a.mdl models/props_junk/wood_pallet001a.mdl models/props_combine/breenbust.mdl models/props_junk/cardboard_box001a.mdl models/props_junk/watermelon01.mdl models/props_c17/canister02a.mdl models/props_c17/bench01a.mdl models/props_c17/furnituredrawer003a.mdl models/props_c17/furnituretable003a.mdl models/props_wasteland/cafeteria_table.001a.mdl models/props_wasteland/wood_fence01a.mdl models/props_junk/glassbottle01a.mdl";

public void OnPluginStart()
{
	PrepareVelocityCall();

	propNames = CreateArray(64, 64);
	InitPropNames();

	cvMakeSingularities = CreateConVar(
		"trash_do_singularities",
		"1",
		"Whether or not to create black and white holes along with props.",
		FCVAR_NOTIFY,
		true,
		0.0,
		true,
		1.0);
}

//-------------------------------------------
// Prepares the SDKCall to CBaseEntity::GetSmoothedVelocity()
// This must be run at plugin start
//-------------------------------------------
public void PrepareVelocityCall()
{
	Handle velConfig = LoadGameConfigFile("veloffsets");
	if(velConfig == INVALID_HANDLE) SetFailState("[TRASH] Couldn't find gamedata (veloffsets.txt)");

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(velConfig, SDKConf_Virtual, "GetSmoothedVelocity");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByValue);

	if((velocityCall = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("[TRASH] Couldn't create SDKCall for GetSmoothedVelocity"); 

	velConfig.Close();
}

//-------------------------------------------
// Gets an entity's velocity using CBaseEntity::GetSmoothedVelocity()
// Stores velocity vector in the specified buffer
//-------------------------------------------
public bool GetEntityVelocity(int entity, float[3] buffer)
{
	if(!IsValidEntity(entity))
	{
		PrintToServer("[TRASH] GetEntityVelocity() recieved invalid entity");
		return false;
	}

	if(velocityCall == INVALID_HANDLE)
	{
		SetFailState("[TRASH] SDKCall failed and velocityCall is invalid, rip plugin");
		return false;
	}

	SDKCall(velocityCall, entity, buffer);
	return true;
}

// When the map starts, find every prop_physics and store them in the existingProps array
public void OnMapStart()
{
	CreateTimer(1.0, CreatePropList, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action CreatePropList(Handle timer)
{
	existingProps = CreateArray(1, 1);
	ListPropPhysics();
	numProps = existingProps.Length;

	// Create a damagefilter to protect spawned props from falling damage
	int filter = CreateEntityByName("filter_damage_type");
	DispatchKeyValueFloat(filter, "damagetype", 16384.0);
	DispatchKeyValue(filter, "targetname", "filter_immune");
	DispatchSpawn(filter);

	// Populate the map with new props
	PopulateMap(filter);

	existingProps.Close();
}

public void OnMapEnd()
{
	sngStrength = 1000.0;
	sngLoop.Close();
}

//-------------------------------------------
// Attempts to create a random prop at a given point
// If there is something in the way, it fails and returns false
// If it succeeds, returns true
//-------------------------------------------
static bool CreateProp(float[3] origin, int filter)
{
	if(!IsAreaBlocked(origin, 48.0))
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

		// Fix prop trampolines by reseting m_vecAbsVelocity
		SetEntPropVector(prop, Prop_Data, "m_vecAbsVelocity", Float:{0.0, 0.0, 0.0});

		return true;
	}
	return false;
}

public Action DestroyFilter(Handle timer, int filter)
{
	AcceptEntityInput(filter, "Kill");
}

public bool CreateSingularity(float[3] origin, int type)
{
	if(!IsAreaBlocked(origin, 64.0))
	{
		switch(type)
		{
			case SINGULARITY_TIMER:
			{
				sngLoop = CreateTimer(0.1, HandleSingularity, _, TIMER_REPEAT);
			}
			case BLACK_HOLE:
			{
				bhOrigin[0] = origin[0];
				bhOrigin[1] = origin[1];
				bhOrigin[2] = origin[2];
				PrintToServer("[TRASH] Black hole created at %f %f %f", origin[0], origin[1], origin[2]);
			}
			case WHITE_HOLE:
			{
				whOrigin[0] = origin[0];
				whOrigin[1] = origin[1];
				whOrigin[2] = origin[2];
				PrintToServer("[TRASH] White hole created at %f %f %f", origin[0], origin[1], origin[2]);
			}
			default:
			{
				PrintToServer("[TRASH] Unexpected singularity type!");
			}
		}
		return true;
	}
	return false;
}

//-----------------------------------------------
// Called every 0.1 seconds
// Does all of the math for black/white holes and pushes props accordingly
// Linked to the sngLoop global handle
//-----------------------------------------------
public Action HandleSingularity(Handle loop)
{
	int index = -1;
	sngStrength += 1.0;

	while((index = FindEntityByClassname(index, "prop_physics")) != -1)
	{
		float propOrigin[3] =   {0.0, 0.0, 0.0};
		float propVelocity[3] = {0.0, 0.0, 0.0};
		float pushVector[3] =   {0.0, 0.0, 0.0}; // Used by white hole
		float suckVector[3] =   {0.0, 0.0, 0.0}; // Used by black hole
		float finalVector[3] =  {0.0, 0.0, 0.0}; // White hole vector + black hole vector + prop velocity vector
		float dist;
		float sngPower;

		GetEntPropVector(index, Prop_Send, "m_vecOrigin", propOrigin);
		GetEntityVelocity(index, propVelocity);

		// If there is a prop in center of the black hole
		/*
		if(IsAreaBlocked(bhOrigin, 1.0))
		{	
			int ent = TR_GetEntityIndex(INVALID_HANDLE);
			if(IsValidEntity(ent)) TeleportEntity(ent, whOrigin, NULL_VECTOR, propVelocity);
		}
		*/

		dist = GetVectorDistance(bhOrigin, propOrigin);
		sngPower = sngStrength/dist;

		MakeVectorFromPoints(propOrigin, bhOrigin, suckVector);
		ScaleVector(suckVector, 1.0/dist);
		ScaleVector(suckVector, sngPower);

		// Replace dist and power values with ones for the white hole
		dist = GetVectorDistance(whOrigin, propOrigin);
		sngPower = sngStrength/dist;

		MakeVectorFromPoints(propOrigin, whOrigin, pushVector);
		ScaleVector(pushVector, 1.0/dist);
		NegateVector(pushVector);
		ScaleVector(pushVector, sngPower);

		AddVectors(pushVector, suckVector, finalVector);
		AddVectors(finalVector, propVelocity, finalVector);

		if(GetVectorLength(finalVector) > 5.0)
		{
			TeleportEntity(index, NULL_VECTOR, NULL_VECTOR, finalVector);
			SetEntPropVector(index, Prop_Data, "m_vecAbsVelocity", Float:{0.0, 0.0, 0.0});
		}

	}
	return Plugin_Continue;
}

//-----------------------------------------------------
// Spawns random props all around the map, as well a black and white hole
// Props are spawned around existing prop_physics -
// This ensures they stay at least vaguely inside of the playable area
//-----------------------------------------------------
public void PopulateMap(int filter)
{
	for(int i = -1; i < propsToAdd + SINGULARITY_TYPES; i++)
	{
		// If we're too close to the entity limit, don't spawn anything
		if(GetEntityCount() > GetMaxEntities() - 200)
		{
			PrintToServer("TRASH: Too close to entity limit to make more props, aborting");
		}

		// Singularities are made instead of props when i > SINGULARITY_TYPES
		// If we're told not to make singularities, skip these values for i
		if(!GetConVarBool(cvMakeSingularities) && i == -1)
		{
			i += SINGULARITY_TYPES + 1;
		}

		bool success = false;
		int ent = existingProps.Get(GetRandomInt(0, numProps - 1));

		if(IsValidEntity(ent))
		{
			int radiusSize = 512;
			int attempts = 0;
			while(!success && attempts < 256)
			{
				float origin[3] = {0.0, 0.0, 0.0};
				GetEntPropVector(ent, Prop_Send, "m_vecOrigin", origin);

				origin[0] += GetRandomInt(-radiusSize, radiusSize);
				origin[1] += GetRandomInt(-radiusSize, radiusSize);
				origin[2] += GetRandomInt(-radiusSize, radiusSize);

				// When necessary, create a singularity rather than a prop
				if(i < SINGULARITY_TYPES)
				{
					success = CreateSingularity(origin, i);
					attempts++;
				}
				else
				{
					success = CreateProp(origin, filter);
					attempts++;
				}
			}
		}
		else i--;
	}
}

//-----------------------------------------------------
// Enumerates through every single prop_physics that already exists on the map
// Then puts each one's index into an arraylist
//-----------------------------------------------------
public void ListPropPhysics()
{
	for(int i = 0; i < GetMaxEntities(); i++)
	{
		if(IsValidEntity(i))
		{
			char classname[64];
			GetEntityClassname(i, classname, 64);

			if(StrEqual("prop_physics", classname))
			{
				existingProps.Push(i);
			}
		}
	}
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

//-----------------------------------------------------
// Checks if a cube-shaped area centered around a certain point is blocked
// (as in, does it contain a brush or entity)
// Returns true if blocked, false otherwise
//-----------------------------------------------------
public bool IsAreaBlocked(float[3] origin, float size)
{
	float mins[3] = {0.0, 0.0, 0.0};
	float maxs[3] = {0.0, 0.0, 0.0};

	mins[0] = -size;
	mins[1] = -size;
	mins[2] = -size;
	maxs[0] = size;
	maxs[1] = size;
	maxs[2] = size;

	TR_TraceHull(origin, origin, mins, maxs, MASK_PLAYERSOLID);
	return TR_DidHit(INVALID_HANDLE);
}

public void InitPropNames()
{
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
