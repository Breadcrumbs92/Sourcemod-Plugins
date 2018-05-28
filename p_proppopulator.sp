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

int propsToAdd = 500;
int numPhysProps = 0;
ArrayList propNames;
DataPack existingProps;

public void OnPluginStart()
{
	propNames = CreateArray(64, 32);

	propNames.SetString(0, "models/props_junk/wood_crate001a.mdl"); 
	propNames.SetString(1, "models/props_junk/wood_crate002a.mdl"); 
	propNames.SetString(2, "models/props_junk/cardboard_box001a.mdl"); 
	propNames.SetString(3, "models/props_junk/beam01a_cluster01.mdl"); 
	propNames.SetString(4, "models/props_junk/pushcart01a.mdl"); 
	propNames.SetString(5, "models/props_junk/wood_pallet001.mdl"); 
	propNames.SetString(6, "models/props_c17/oildrum001_explosive.mdl"); 
	propNames.SetString(7, "models/props_c17/oildrum001.mdl"); 
	propNames.SetString(8, "models/props_c17/lockers001a.mdl"); 
	propNames.SetString(9, "models/props_c17/substation_transformer01b.mdl");
	propNames.SetString(10, "models/props_interiors/radiator01a.mdl");
	propNames.SetString(11, "models/props_interiors/refrigerator01a.mdl");
	propNames.SetString(12, "models/props_interiors/vendingmachinesoda01a.mdl");
	propNames.SetString(13, "models/props_interiors/furniture_shelf01a.mdl");
	propNames.SetString(14, "models/props_interiors/bathtub01a.mdl");
	propNames.SetString(15, "models/props_interiors/furniture_couch01a.mdl");
	propNames.SetString(16, "models/props_lab/workspace003.mdl");
	propNames.SetString(17, "models/props_doors/door03_slotted_left.mdl");
	propNames.SetString(18, "models/props_canal/boat001a.mdl");
	propNames.SetString(19, "models/props_c17/fence02a.mdl");
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
	existingProps = ListPropPhysics();
	numPhysProps = existingProps.Position;
	existingProps.Reset(false);
	
	int filter = CreateEntityByName("filter_damage_type");
	DispatchKeyValueFloat(filter, "damagetype", 1.0); // Ignore damage of type CRUSH
	DispatchKeyValue(filter, "targetname", "filter_immune");
	DispatchKeyValueFloat(filter, "Negated", 1.0);
	DispatchSpawn(filter);
	
	RequestFrame(PopulateMap, filter);
}

// ------------------------------------------
// Attempts to create a random prop at a given point
// If it cannot, returns false
// If it succeeds, returns true
//-------------------------------------------
static bool CreateProp(float[3] origin, int filter = -1)
{
	float mins[3] = {-32.0, -32.0, -32.0};
	float maxs[3] = {32.0, 32.0, 32.0};
	
	Handle hullTrace = TR_TraceHullFilterEx(origin, origin, mins, maxs, MASK_PLAYERSOLID, HullFilter);
	
	if(TR_DidHit(hullTrace))
	{
		PrintToServer("Something is in the way!");
		
		hullTrace.Close();
		return false;
	}
	else
	{
		float randVector[3] = {0.0, 0.0, 0.0};
		randVector[0] = GetRandomFloat(-1024.0, 1024.0);
		randVector[1] = GetRandomFloat(-1024.0, 1024.0);
		randVector[2] = GetRandomFloat(-1024.0, 1024.0);
		
		PrintToServer("Space is clear!");
		char randomPropName[64];
		propNames.GetString(GetRandomInt(0, propNames.Length - 1), randomPropName, 64);
		
		int prop = CreateEntityByName("prop_physics");
		DispatchKeyValue(prop, "model", randomPropName);
		
		if(filter != -1)
		{
			// Props are made immune to CRUSH damage 2 seconds after spawning
			// This prevents breakables from permaturely breaking
			SetVariantString("immune_filter");
			AcceptEntityInput(prop, "SetDamageFilter");
		}
		DispatchSpawn(prop);
		TeleportEntity(prop, origin, NULL_VECTOR, NULL_VECTOR);
		
		CreateTimer(2.0, DestroyFilter, filter, TIMER_FLAG_NO_MAPCHANGE);
		
		hullTrace.Close();
		
		return true;
	}
}

public Action DestroyFilter(Handle timer, int filter)
{
	AcceptEntityInput(filter, "Kill");
}

public void PopulateMap(int filter)
{
	for(int i = 0; i < propsToAdd; i++)
	{
		bool success = false;
		while(!success)
		{
			int propIndex = GetRandomInt(0, numPhysProps - 10);
			existingProps.Position = propIndex;
			PrintToServer("%i", propIndex);
			int ent = existingProps.ReadCell();
		
			int radiusSize = 128;
			float origin[3] = {0.0, 0.0, 0.0};
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", origin);
		
			origin[0] += GetRandomInt(-radiusSize, radiusSize);
			origin[1] += GetRandomInt(-radiusSize, radiusSize);
			origin[2] += GetRandomInt(-radiusSize, radiusSize);	
			
			success = CreateProp(origin, filter);
		} 
	}
}

public bool HullFilter(int entity, int contentsMask)
{
	char classname[64];
	GetEntityClassname(entity, classname, 64);
	
	if(StrEqual(classname, "player"))
	{
		return false;
	}
	
	return true;
}

public DataPack ListPropPhysics()
{
	DataPack props = CreateDataPack();
	props.Reset(false);
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
				numProps++;
			}
		}
	}
	
	return props;
}
