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

int propsToAdd = 100;
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
	HookEvent("player_spawn", evSpawn);
	existingProps = ListPropPhysics();
	numPhysProps = existingProps.Position;
	existingProps.Reset(false);
	
	RequestFrame(PopulateMap, _);
}

public void evSpawn(Event spawn, const char[] name, bool dontBroadcast)
{
	int index = spawn.GetInt("userid");
	int client = GetClientOfUserId(index);
	
	SDKUnhook(client, SDKHook_FireBulletsPost, OnShoot);
	SDKHook(client, SDKHook_FireBulletsPost, OnShoot);
}

public void OnShoot(int client, int shots, const char[] weaponname)
{
	float pos[3] = {0.0, 0.0, 0.0};
	GetClientEyePosition(client, pos);
	
	CreateProp(pos);
}

public bool CreateProp(float[3] origin)
{
	float scaler[3] = {0.0, 0.0, 32.0};
	float start[3] = {0.0, 0.0, 0.0};
	float end[3] = {0.0, 0.0, 0.0};
	
	float mins[3] = {-16.0, -16.0, -16.0};
	float maxs[3] = {16.0, 16.0, 16.0};
	
	AddVectors(origin, scaler, start);
	SubtractVectors(origin, scaler, end);
	
	Handle hullTrace = TR_TraceHullFilterEx(start, end, mins, maxs, MASK_PLAYERSOLID, HullFilter);
	
	if(TR_DidHit(hullTrace))
	{
		PrintToServer("Something is in the way!");
		return false;
	}
	else
	{
		PrintToServer("Space is clear!");
		char randomPropName[64];
		propNames.GetString(GetRandomInt(0, propNames.Length - 1), randomPropName, 64);
		
		int prop = CreateEntityByName("prop_physics");
		DispatchKeyValue(prop, "model", randomPropName);
		DispatchSpawn(prop);
		TeleportEntity(prop, origin, NULL_VECTOR, NULL_VECTOR);
		
		PrintToServer(randomPropName);
		PrintToServer("%i", propNames.Length);
		
		return true;
	}
}

public void PopulateMap(any data)
{
	for(int i = 0; i < propsToAdd; i++)
	{
		bool success = false;
		while(!success)
		{
			int propIndex = GetRandomInt(0, numPhysProps - 1);
			existingProps.Position = propIndex;
			int ent = existingProps.ReadCell();
		
			int radiusSize = 128;
			float origin[3] = {0.0, 0.0, 0.0};
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", origin);
		
			origin[0] += GetRandomInt(-radiusSize, radiusSize);
			origin[1] += GetRandomInt(-radiusSize, radiusSize);
			origin[2] += GetRandomInt(-radiusSize, radiusSize);	
			
			success = CreateProp(origin);
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
