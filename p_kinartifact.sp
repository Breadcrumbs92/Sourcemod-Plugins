#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

public Plugin myinfo =
{
	name = "Artifact of Kin",
	author = "Breadcrumbs",
	description = "Enemies are Russian nesting dolls",
	version = "1.25",
	url = "http://www.sourcemod.net/"
}

// Define ConVars
ConVar cv_rollermine_chance;
ConVar cv_combine_portal_interval;
ConVar cv_rebel_portal_interval;
ConVar cv_do_ball_portals;

// ----------------------------------------------------------
// Called on plugin start
//
// Purpose: Hook entity deaths to check for things dying
// And to create and define properties for ConVars
// -----------------------------------------------------------
public void OnPluginStart()
{
	HookEvent("entity_killed", Event_EntKilled);
	
	cv_rollermine_chance = CreateConVar("kin_rollermine_chance", 
	"1.0", // Default value
	"Chance out of 100 to spawn a rollermine on every entity death.", 
	FCVAR_NOTIFY, 
	true, 
	0.0, // Min value
	true, 
	100.0); // Max value
	
	cv_combine_portal_interval = CreateConVar("kin_combine_ball_interval", 
	"0.4", // Default value
	"How much time should pass, in seconds, before another combine soldier is created from a combine ball fired by a soldier.", 
	FCVAR_NOTIFY, 
	true, 
	0.0, // Min value
	false);
	
	cv_rebel_portal_interval = CreateConVar("kin_rebel_ball_interval", 
	"0.4", // Default value
	"How much time should pass, in seconds, before another rebel is created from a combine ball fired by a player.", 
	FCVAR_NOTIFY, 
	true, 
	0.0, // Min value
	false);
	
	cv_do_ball_portals = CreateConVar("kin_do_ball_spawning", 
	"1", // Default value
	"Whether or not fired combine balls should spawn rebels or soldiers.", 
	FCVAR_NOTIFY);
}

// ----------------------------------------------------------
// Called on entity deaths
//
// Purpose: Check for enemies dying and get their classname
// -----------------------------------------------------------
public void Event_EntKilled(Event event_entkilled, const char[] name, bool dontBroadcast)
{
	// Gets index of killed enemy
	int i_victim_ent_index = event_entkilled.GetInt("entindex_killed");
	
	char string_map_name[64];
	GetCurrentMap(string_map_name, 64);
	
	// If the map is invalid (hasn't loaded yet), don't do anything
	if(IsMapValid(string_map_name))
	{	
		// Get enemy classname and pass to f_SpawnDolls
		char string_entity_classname[64];
		GetEntityClassname(i_victim_ent_index, string_entity_classname, 64);
		
		f_SpawnDolls(string_entity_classname, i_victim_ent_index);
	}
}

// ----------------------------------------------------------
// Called whenever an enemy dies (on a valid map)
//
// Purpose: Determine what new enemy needs to spawn based on 
// the victim's classname and where the enemy needs to spawn
// -----------------------------------------------------------
public void f_SpawnDolls(char[] victim_classname, int i_victim)
{
	// Get the origin and view angles of the victim
	float vec_victim_origin[3] = {0.0, 0.0, 0.0};
	float vec_victim_angles[3] = {0.0, 0.0, 0.0};
	
	GetEntPropVector(i_victim, Prop_Send, "m_vecOrigin", vec_victim_origin);
	GetEntPropVector(i_victim, Prop_Send, "m_angRotation", vec_victim_angles);
	
	// There is a ConVar defined chance that every enemy death will spawn a rollermine
	int i_rollermine_decide = GetRandomInt(1, 100);
	if(i_rollermine_decide <= GetConVarInt(cv_rollermine_chance))
	{
		f_CreateDolls("npc_rollermine", vec_victim_origin, vec_victim_angles);
	}	
	
	// Elite soldiers turn into regular soldiers
	if(StrEqual(victim_classname, "npc_combine_s", true) == true && GetEntProp(i_victim, Prop_Data, "m_fIsElite") == 1)
	{
		f_CreateDolls("npc_combine_s", vec_victim_origin, vec_victim_angles);
	}
	// Regular soldiers turn into metropolice
	else if(StrEqual(victim_classname, "npc_combine_s", true) == true && GetEntProp(i_victim, Prop_Data, "m_fIsElite") != 1)
	{
		f_CreateDolls("npc_metropolice", vec_victim_origin, vec_victim_angles);
	}
	// Metropolice turn into manhacks
	else if(StrEqual(victim_classname, "npc_metropolice", true))
	{
		vec_victim_origin[2] = vec_victim_origin[2] + 32.0;
		f_CreateDolls("npc_manhack", vec_victim_origin, vec_victim_angles);
	}
	// Poison zombies turn into fast zombies
	else if(StrEqual(victim_classname, "npc_poisonzombie", true))
	{
		f_CreateDolls("npc_fastzombie", vec_victim_origin, vec_victim_angles);
	}
	// Fast zombies turn into regular zombies
	else if(StrEqual(victim_classname, "npc_fastzombie", true))
	{
		f_CreateDolls("npc_zombie", vec_victim_origin, vec_victim_angles);
	}
	// Poison headcrabs turn into fast headcrabs
	else if(StrEqual(victim_classname, "npc_headcrab_black", true))
	{
		f_CreateDolls("npc_headcrab_fast", vec_victim_origin, vec_victim_angles);
	}
	// Fast headcrabs turn into regular headcrabs
	else if(StrEqual(victim_classname, "npc_headcrab_fast", true))
	{
		f_CreateDolls("npc_headcrab", vec_victim_origin, vec_victim_angles);
	}
	// Zombine (ep1) turn into poison zombies
	else if(StrEqual(victim_classname, "npc_zombine", true))
	{
		f_CreateDolls("npc_poisonzombie", vec_victim_origin, vec_victim_angles);
	}
	// Gunships turn into swarms of manhacks
	else if(StrEqual(victim_classname, "npc_combinegunship", true))
	{
		for(int i = 0; i < GetRandomInt(20, 25); i++)
		{
			f_CreateDolls("npc_manhack", vec_victim_origin, vec_victim_angles);
		}
	}
	// Medic rebels turn into regular rebels
	// The '0x20000' here is the citizen entity flag for medics
	else if(StrEqual(victim_classname, "npc_citizen", true) && GetEntProp(i_victim, Prop_Data, "m_Type") == 3 && GetEntProp(i_victim, Prop_Data, "m_spawnflags") & 0x20000 != 0)
	{

		f_CreateDolls("npc_citizen", vec_victim_origin, vec_victim_angles, 0);
	}
	// Regular rebels turn into normal citizens (blue shirt, no beanie)
	else if(StrEqual(victim_classname, "npc_citizen", true) && GetEntProp(i_victim, Prop_Data, "m_Type") == 3)
	{
		f_CreateDolls("npc_citizen", vec_victim_origin, vec_victim_angles, 1);
	}
	// Normal citizens turn into supply crates
	else if(StrEqual(victim_classname, "npc_citizen", true) && GetEntProp(i_victim, Prop_Data, "m_Type") != 3)
	{
		// Yes, the resupply crate is actually called item_item_crate
		f_CreateDolls("item_item_crate", vec_victim_origin, vec_victim_angles);
	}
}

// ----------------------------------------------------------
// Called whenever an enemy needs to be spawned
//
// Purpose: Actually make the enemy, and give it special 
// properties (like weapons or flags) if necessary
// -----------------------------------------------------------
static void f_CreateDolls(char[] classname, float[3] origin, float[3] angles, int i_rebeltype = -1)
{
	int i_doll_index = CreateEntityByName(classname);
	
	// Metropolice must spawn with smg or pistol
	if(StrEqual("npc_metropolice", classname, true) == true)
	{
		if(GetRandomInt(0, 1) == 0)
		{
			DispatchKeyValue(i_doll_index, "additionalequipment", "weapon_smg1");
		}
		else
		{
			DispatchKeyValue(i_doll_index, "additionalequipment", "weapon_pistol");
		}
	}
	// Combine soldiers must spawn with ar2s
	else if(StrEqual("npc_combine_s", classname, true) == true)
	{
		DispatchKeyValue(i_doll_index, "additionalequipment", "weapon_ar2");
	}
	// If the citizen came from a medic death... (i_rebeltype == 0)
	else if(StrEqual("npc_citizen", classname, true) == true && i_rebeltype == 0)
	{
		// Give it an ar2
		DispatchKeyValue(i_doll_index, "additionalequipment", "weapon_ar2");
		
		// Make immune to explosives
		// Only works if spite is installed
		SetVariantString("fdt_noblastdamage");
		AcceptEntityInput(i_doll_index, "SetDamageFilter");
	}
	// If the citizen came from a normal rebel death... (i_rebeltype == 1)
	else if(StrEqual("npc_citizen", classname, true) == true && i_rebeltype == 1)
	{
		// Give the citizen normal citizen appearance (m_Type = 1)
		// Then give it an smg
		SetEntProp(i_doll_index, Prop_Data, "m_Type", 1);
		DispatchKeyValue(i_doll_index, "additionalequipment", "weapon_smg1");
		
		// Make immune to explosives
		// Only works if spite is installed
		SetVariantString("fdt_noblastdamage");
		AcceptEntityInput(i_doll_index, "SetDamageFilter");
	}
	// Supply crates need to have things in them
	else if(StrEqual("item_item_crate", classname, true) == true)
	{
		// Put 1 - 4 dynamic resupply items in the crate
		SetEntPropString(i_doll_index, Prop_Data, "m_strItemClass", "item_dynamic_resupply");
		SetEntProp(i_doll_index, Prop_Data, "m_nItemCount", GetRandomInt(1, 4));
		
		//Only works if spite is installed
		SetVariantString("fdt_noblastdamage");
		AcceptEntityInput(i_doll_index, "SetDamageFilter");
	}
	
	// Spawn the item and teleport it to the victim's origin, 
	// With the victim's viewangles
	DispatchSpawn(i_doll_index);
	TeleportEntity(i_doll_index, origin, angles, NULL_VECTOR);
}

// ----------------------------------------------------------
// Called whenever an entity is created
//
// Purpose: Look for combine balls in order to spawn rebels
// or soldiers when players or combine shoot balls
// -----------------------------------------------------------
public void OnEntityCreated(int entity, const char[] classname)
{
	// Check for combine balls being spawned
	if(StrEqual(classname, "prop_combine_ball", true) == true && GetConVarBool(cv_do_ball_portals))
	{
		// The properties of a combine ball cannot be checked right away
		// so this check must be put on a timer
		// Why? Good question!
		CreateTimer(0.01, f_CheckBallProperties, entity, TIMER_FLAG_NO_MAPCHANGE);
	}
}

// ----------------------------------------------------------
// Called whenever a combine ball spawns
//
// Purpose: Check who the ball belongs to and determine what
// entity needs to spawn from the ball
// -----------------------------------------------------------
public Action f_CheckBallProperties(Handle timer08, int entity)
{
	// If we're somehow checking an invalid entity, just stop
	if(!IsValidEntity(entity))
	{
		return Plugin_Stop;
	}
	else
	{
		// If the ball does not have an invalid owner, get the owner's classname
		char string_owner_classname[32] = " ";
		int i_owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
		if(i_owner != -1)
		{
			GetEntityClassname(i_owner, string_owner_classname, sizeof(string_owner_classname));
		}

		// If the ball was shot by a player...
		// rebels need to come out of the ball
		if(StrEqual(string_owner_classname, "player", true) == true)
		{
			// Make a data pack to pass multiple arguments into timer
			// We need to tell the timer both what entity should be manipulated (the ball)
			// as well as what entity classname should be spawning.
			DataPack dp_pack = CreateDataPack();
			WritePackCell(dp_pack, entity);
			WritePackString(dp_pack, "npc_citizen"); 
			
			CreateTimer(GetConVarFloat(cv_rebel_portal_interval), f_CreateBallGuys, dp_pack, TIMER_REPEAT);
		}
		// If the ball was shot by a combine...
		// soldiers need to come out of the ball
		else if(StrEqual(string_owner_classname, "npc_combine_s", true) == true)
		{
			// Make a data pack to pass multiple arguments into timer
			DataPack dp_pack = CreateDataPack();
			WritePackCell(dp_pack, entity);
			WritePackString(dp_pack, "npc_combine_s");
			
			CreateTimer(GetConVarFloat(cv_combine_portal_interval), f_CreateBallGuys, dp_pack, TIMER_REPEAT);
		}
		
		return Plugin_Continue;
	}
}

// ----------------------------------------------------------
// Called repeatedly if a ball with a valid owner is found
//
// Purpose: Spawn rebels or combine from the ball
// -----------------------------------------------------------
public Action f_CreateBallGuys(Handle timer09, any data)
{
	ResetPack(data, false);
	int entity = ReadPackCell(data);

	// Stop timer and close data pack if ball stops existing
	if(!IsValidEntity(entity))
	{
		CloseHandle(data);
		return Plugin_Stop;
	}
	
	float vec_ball_origin[3] = {0.0, 0.0, 0.0};
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vec_ball_origin);
	
	char string_classname[32] = " ";
	ReadPackString(data, string_classname, sizeof(string_classname));
	
	// Make rebel or combine
	int i_guy = CreateEntityByName(string_classname);
	
	// If we're making a rebel...
	if(StrEqual(string_classname, "npc_citizen", true) == true)
	{
		// Give the rebel an m_Type of 3 so it has the resistance outfit
		SetEntProp(i_guy, Prop_Data, "m_Type", 3);
	}
	// Give entity an ar2, then spawn it at the ball's origin
	DispatchKeyValue(i_guy, "additionalequipment", "weapon_ar2");
	DispatchSpawn(i_guy);
	TeleportEntity(i_guy, vec_ball_origin, NULL_VECTOR, NULL_VECTOR);
	
	// Continue repeating the timer
	return Plugin_Continue;
}
