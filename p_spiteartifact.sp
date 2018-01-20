#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

public Plugin myinfo =
{
	name = "Spite Artifact Plugin",
	author = "Breadcrumbs",
	description = "Entities, props, and players drop grenades on death.",
	version = "1.5",
	url = "http://www.sourcemod.net/"
}

//Define Convars

ConVar cv_nova_balls_chance;
ConVar cv_nova_barrels_chance;
ConVar cv_do_supernovas;

public void OnPluginStart()
{
	//Create events hooks for prop breaking, entity dying, player dying, and func_breakable breaking.
	HookEvent("break_prop", Event_PropKilled);
	HookEvent("entity_killed", Event_EntKilled);
	HookEvent("player_death", Event_PlayerKilled);
	HookEvent("break_breakable", Event_BreakableBroken);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	cv_nova_balls_chance = CreateConVar("spite_ball_supernova_chance", 
	"3.0", // Default value
	"Chance out of 100 for an enemy to explode into combine balls upon death.", 
	FCVAR_NOTIFY, 
	true, 
	0.0, // Min value
	true, 
	100.0); // Max value
	
	cv_nova_barrels_chance = CreateConVar("spite_barrel_supernova_chance", 
	"3.0", // Default value
	"Chance out of 100 for an enemy to explode into explosive barrels upon death.", 
	FCVAR_NOTIFY, 
	true, 
	0.0, // Min value
	true,
	100.0); // Max value
	
	cv_do_supernovas = CreateConVar("spite_do_supernovas", 
	"1",
	"Whether or not to cause supernovas on entity deaths.", 
	FCVAR_NOTIFY); 
}


public Action OnClientCommand(int client, int args)
{
	char string_command[32];
	GetCmdArg(0, string_command, 32);
	
	if(StrEqual(string_command, "spite_make_immune"))
	{
		int i_target = GetClientAimTarget(client, false);
		char string_ent_classname[64];
		GetEntityClassname(i_target, string_ent_classname, 64);
		
		if(!StrEqual(string_ent_classname, "player", true))
		{
			SetVariantString("fdt_vortimmune");
			AcceptEntityInput(i_target, "SetDamageFilter");
			
			PrintToConsole(client, "Made a(n) %s with ID %i immune", string_ent_classname, i_target);
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}


public void OnMapStart()
{
	//When the map starts, spawn a damage filter and apply it to required entities.
	f_ApplyDamageFilters();
}

public void Event_PlayerSpawn(Event event_playerspawn, const char[] name, bool dontBroadcast)
{
	//Whenever a player spawns, apply the damage filters
	//This kinda sucks but it's a just a temporary fix to quickly address a bug
	f_ApplyDamageFilters();
}

public void Event_PropKilled(Event event_propkilled, const char[] name, bool dontBroadcast)
{	
	int i_victim_prop_index = event_propkilled.GetInt("entindex");
	
	f_MakeExplosives(i_victim_prop_index, 2, 3, 0);
} 

public void Event_EntKilled(Event event_entkilled, const char[] name, bool dontBroadcast)
{
	int i_victim_ent_index = event_entkilled.GetInt("entindex_killed");
	
	//If the entity that was killed is a tripod turret, don't spawn explosives.
	//This is here to make the turret defense segments in Entanglement bearable.
	char string_entity_classname[64];
	GetEntityClassname(i_victim_ent_index, string_entity_classname, 64);
	bool bl_entity_is_turret = StrEqual(string_entity_classname, "npc_turret_floor", true);
	
	if(!bl_entity_is_turret)
	{
		int i_maxhealth = GetEntProp(i_victim_ent_index, Prop_Data, "m_iMaxHealth");
	
		float fl_maxhealth = float(i_maxhealth);
	
		float fl_explosive_count_low = 0.08 * fl_maxhealth;
		float fl_explosive_count_high = 0.12 * fl_maxhealth;
		int i_explosive_count_low = RoundToCeil(fl_explosive_count_low);
		int i_explosive_count_high = RoundToCeil(fl_explosive_count_high);
	
		f_MakeExplosives(i_victim_ent_index, i_explosive_count_low, i_explosive_count_high, 1);
		
		//f_MakeExplosives(i_victim_ent_index, 3, 5, 1);
	}
}

public void Event_PlayerKilled(Event event_playerkilled, const char[] name, bool dontBroadcast)
{
	int i_victim_player_id = event_playerkilled.GetInt("userid");
	int i_victim_client = GetClientOfUserId(i_victim_player_id);
	
	f_MakeExplosives(i_victim_client, 10, 15, 2);
}

public void Event_BreakableBroken(Event event_breakablebroken, const char[] name, bool dontBroadcast)
{
	int i_victim_breakable_index = event_breakablebroken.GetInt("entindex");
	
	f_MakeExplosives(i_victim_breakable_index, 4, 6, 3);
}

static void f_MakeExplosives(int i_entity_index, int i_explosives_low_bound, int i_explosives_high_bound, int i_origin_hook)
{
	//Get the origin of the thing that was destroyed.
	float vec_entity_origin_vector[3] = {0.0, 0.0, 0.0};
	GetEntPropVector(i_entity_index, Prop_Send, "m_vecOrigin", vec_entity_origin_vector);
	
	//Decide how many explosives to make
	int i_random_explosive_count = GetRandomInt(i_explosives_low_bound, i_explosives_high_bound);
	
	char string_explosive_classname[50] = " ";
	
	//Check if the killed thing was a player
	//The code will use that information later when deciding what explosives to create
	char string_entity_classname[64];
	GetEntityClassname(i_entity_index, string_entity_classname, 64);
	bool bl_entity_is_player = StrEqual(string_entity_classname, "player", true);
	
	//i_origin_hook is 0 if the call came from a prop, 
	//1 if it came from an entity, 
	//2 if it came from a player, 
	//3 if it came from a func_breakable.
	
	//If the destroyed thing was an enemy, a couple special things have to happen
	if(i_origin_hook == 1 && !bl_entity_is_player)
	{
		//Add 16 hammer units to the entity's vertical position, 
		//so our explosives aren't spawned in the ground
		vec_entity_origin_vector[2] = vec_entity_origin_vector[2] + 16.0;
		
		if(GetConVarBool(cv_do_supernovas))
		{
			//Create a random integer to decide if a ball or barrel supernova should happen
			int i_ball_decide = GetRandomInt(1, 100);
			int i_barrel_decide = GetRandomInt(1, 100);
		
			//Decide what to spawn
			if(i_ball_decide <= GetConVarInt(cv_nova_balls_chance))
			{
				string_explosive_classname = "point_combine_ball_launcher";
			}
			else if(i_barrel_decide <= GetConVarInt(cv_nova_barrels_chance))
			{
				string_explosive_classname = "prop_physics";
			}
			else if(i_ball_decide <= GetConVarInt(cv_nova_balls_chance) && i_barrel_decide <= GetConVarInt(cv_nova_barrels_chance))
			{
				if(GetRandomInt(0, 1) == 0)
				{
					string_explosive_classname = "point_combine_ball_launcher";
				}
				else 
				{
					string_explosive_classname = "prop_physics";
				}
			}
			else
			{
				string_explosive_classname = "npc_grenade_frag";
			}
		}
		else 
		{
			string_explosive_classname = "npc_grenade_frag";
		}
	}
	else
	{
		string_explosive_classname = "npc_grenade_frag";
	}
		
	if(i_origin_hook == 2 && bl_entity_is_player)
	{
		vec_entity_origin_vector[2] = vec_entity_origin_vector[2] + 16.0;
	}
	
	//After deciding what the explosives should be, this for loop actually spawns them.
	for(int i = 0; i < i_random_explosive_count; i++)
	{
		//This if conditional ensures that no entities are created if we're getting too
		//close to the entity limit.
		if(GetEntityCount() < GetMaxEntities() - 500)
		{
			//Create the explosive
			int i_explosive_entity_index = CreateEntityByName(string_explosive_classname);
			int i_explosive_entity_ref = EntIndexToEntRef(i_explosive_entity_index);

			//Spawn it after a very short delay
			CreateTimer(0.01, f_SpawnExplosives, i_explosive_entity_ref, TIMER_FLAG_NO_MAPCHANGE);
			
			//Teleport it to the position that the dead entity had
			TeleportEntity(i_explosive_entity_ref, vec_entity_origin_vector, NULL_VECTOR, NULL_VECTOR);
			
			//If the explosive is a grenade, we need to give it the damage filter and prime it.
			//If the explosive is a ball, we need to launch it.
			//If the explosive is a prop, we need to make it an explosive barrel.
			if(StrEqual(string_explosive_classname, "npc_grenade_frag", true))
			{
				CreateTimer(0.04, f_BounceExplosives, i_explosive_entity_ref, TIMER_FLAG_NO_MAPCHANGE);
				//CreateTimer(0.9, f_BounceExplosives, i_explosive_entity_ref, TIMER_REPEAT);
			
				SetVariantFloat(GetRandomFloat(3.5, 5.0));
				AcceptEntityInput(i_explosive_entity_ref, "SetTimer");
				SetVariantString("fdt_noblastdamage");
				AcceptEntityInput(i_explosive_entity_ref, "SetDamageFilter");
			}
			else if(StrEqual(string_explosive_classname, "point_combine_ball_launcher", true))
			{
			
				//Make a data pack to pass multiple variables to the ball function
				DataPack dp_nova_pack = CreateDataPack();
				WritePackCell(dp_nova_pack, i_explosive_entity_ref);
				WritePackFloat(dp_nova_pack, 500.0);
				WritePackFloat(dp_nova_pack, 700.0);
				WritePackFloat(dp_nova_pack, 8.0);
		
				CreateTimer(0.04, f_LaunchCombineBall, dp_nova_pack, TIMER_FLAG_NO_MAPCHANGE);
			}
			else if(StrEqual(string_explosive_classname, "prop_physics", true))
			{
				CreateTimer(0.04, f_BounceExplosives, i_explosive_entity_ref, TIMER_FLAG_NO_MAPCHANGE);
				
				DispatchKeyValue(i_explosive_entity_ref, "model", "models/props_c17/oildrum001_explosive.mdl");
			}
			else
			{
				PrintToServer("Entity classname was unexpected");
			}
		}
		else
		{
			PrintToServer("Too close to entity limit");
		}
	}
}

//This function does the entity spawn. 
//It's only here so that it can be delayed by a timer.
public Action f_SpawnExplosives(Handle timer01, any data)
{
	DispatchSpawn(data);
	return Plugin_Continue;
}

//This function bounces the explosives by giving them a random velocity vector.
//It's used on grenades and barrels to prevent them from sadly falling to the 
//ground and not doing anything when they spawn.
public Action f_BounceExplosives(Handle timer02, any entityindex)
{
	//If the entity being bounced is not valid, stop the timer
	if(!IsValidEntity(entityindex))
	{
		return Plugin_Stop;
	}

	float vec_random_velocity_vector[3] = {0.0, 0.0, 0.0};
	vec_random_velocity_vector[0] = GetRandomFloat(-700.0, 700.0);
	vec_random_velocity_vector[1] = GetRandomFloat(-700.0, 700.0);
	vec_random_velocity_vector[2] = GetRandomFloat(250.0, 300.0);
	
	TeleportEntity(entityindex, NULL_VECTOR, NULL_VECTOR, vec_random_velocity_vector);
	
	return Plugin_Continue;
}

//This function searches through all the entites on the map to find things
//we need to make immune to explosions.
public Action f_FindEnemies(Handle timer03)
{
	// Entities in this string will become immune to explosives
	char string_immune_ents[1024] = "npc_metropolice npc_combine_s npc_antlion npc_zombie npc_poisonzombie npc_fastzombie npc_headcrab npc_headcrab_black npc_headcrab_fast npc_manhack npc_rollermine npc_barnacle npc_alyx npc_monk npc_zombine npc_hunter npc_citizen";
	
	// Entites in this string will become immune to everything
	char string_totalimmune_ents[64] = "npc_vortigaunt npc_barney";
	
	for(int i_index = 1; i_index <= GetEntityCount(); i_index++)
	{
		if(IsValidEntity(i_index))
		{
			char string_ent_classname[64];
			GetEntityClassname(i_index, string_ent_classname, 64);
			
			if(StrContains(string_immune_ents, string_ent_classname, true) != -1)
			{
				SetVariantString("fdt_noblastdamage");
				AcceptEntityInput(i_index, "SetDamageFilter");
			}
			else if(StrContains(string_totalimmune_ents, string_ent_classname, true) != -1)
			{
				SetVariantString("fdt_vortimmune");
				AcceptEntityInput(i_index, "SetDamageFilter");
			}
		}
	}
	
	return Plugin_Continue;
}

//This function is called whenever an entity is created, and it checks if the 
//entity is something that we have to make immune to explosives.
public OnEntityCreated(entity, const String:classname[])
{	
	//Any entity in this string will become immune to explosives.
	char string_enemy_classnames[1024] = "npc_metropolice npc_combine_s npc_fastzombie npc_headcrab npc_headcrab_black npc_headcrab_fast npc_manhack npc_rollermine npc_poisonzombie npc_zombie npc_barnacle npc_antlion npc_monk npc_alyx npc_zombine npc_hunter npc_citizen";
	
	//Any entity in this string will become immune to everything
	char string_totalimmune_classnames[64] = "npc_vortigaunt npc_barney";
	
	if(StrContains(string_enemy_classnames, classname, true) != -1) 
	{
		SetVariantString("fdt_noblastdamage");
		AcceptEntityInput(entity, "SetDamageFilter");
	}
	else if(StrContains(string_totalimmune_classnames, classname, true) != -1) 
	{
		SetVariantString("fdt_vortimmune");
		AcceptEntityInput(entity, "SetDamageFilter");
	}
}
	
//This function lets us spawn things when SMG grenades and RPGS detonate
//Just so these weapons are actually useful in-game...
public void OnEntityDestroyed(int entity)
{
	char string_grenade_classnames[512] = " ";
	string_grenade_classnames = "grenade_ar2 rpg_missile npc_grenade_frag";
	
	char string_entity_classname[64] = " ";
	GetEntityClassname(entity, string_entity_classname, 64);
	
	char string_prop_model[128] = " ";
	
	if(StrContains(string_grenade_classnames, string_entity_classname, true) != -1) 
	{
		float vec_grenade_origin_vector[3] = {0.0, 0.0, 0.0};
		
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vec_grenade_origin_vector);
		
		vec_grenade_origin_vector[2] = vec_grenade_origin_vector[2] + 32.0;
		
		int i_random_propane_low_bound = 0;
		int i_random_propane_high_bound = 0;
		
		if(StrEqual(string_entity_classname, "rpg_missile", true))
		{
			i_random_propane_low_bound = 4;
			i_random_propane_high_bound = 6;
			
			string_prop_model = "models/props_c17/oildrum001_explosive.mdl";
		}
		else if(StrEqual(string_entity_classname, "grenade_ar2", true))
		{
			i_random_propane_low_bound = 3;
			i_random_propane_high_bound = 4;
			
			string_prop_model = "models/props_junk/trashdumpster01a.mdl";
		}
		else if(StrEqual(string_entity_classname, "npc_grenade_frag", true))
		{
			int i_owner_index = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
			
			//If the grenade doesn't have an owner (wasn't thrown by anyone)
			//Then don't bother spawning anything
			//Otherwise we'd have infinite loops of explosives blowing up into grenades
			//that blow up into more grenades
			if(i_owner_index == -1)
			{
				return;
			}
			
			i_random_propane_low_bound = 2;
			i_random_propane_high_bound = 4;
			
			string_prop_model = "models/props_c17/oildrum001_explosive.mdl";
		}
		else
		{
			PrintToServer("Unexpected grenade classname! (this is bad)");
		}
		
		int i_random_propane = GetRandomInt(i_random_propane_low_bound, i_random_propane_high_bound);
	
		for(int j = 0; j < i_random_propane; j++)
		{
			int i_propane_index = CreateEntityByName("prop_physics");
			DispatchKeyValue(i_propane_index, "model", string_prop_model);
				
			if(StrEqual(string_prop_model, "models/props_junk/trashdumpster01a.mdl", true) == true)
			{
				CreateTimer(GetRandomFloat(30.0, 45.0), f_ExplodeDumpsters, i_propane_index, TIMER_FLAG_NO_MAPCHANGE);
			}
			
			CreateTimer(0.01, f_SpawnExplosives, i_propane_index, TIMER_FLAG_NO_MAPCHANGE);
			TeleportEntity(i_propane_index, vec_grenade_origin_vector, NULL_VECTOR, NULL_VECTOR);
			CreateTimer(0.02, f_BounceExplosives, i_propane_index, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

//This function does all the things are needed to launch combine balls.
public Action f_LaunchCombineBall(Handle timer06, any data)
{
	ResetPack(data, false);
	int i_ball = ReadPackCell(data);
	float fl_minspeed = ReadPackFloat(data);
	float fl_maxspeed = ReadPackFloat(data);
	float fl_bouncecount = ReadPackFloat(data);

	//Initialize values (This step is deceptively important. Balls won't
	//launch properly unless some values are initialized)
	DispatchKeyValueFloat(i_ball, "launchconenoise", 10.0);
	DispatchKeyValueFloat(i_ball, "ballradius", 20.0);
	DispatchKeyValueFloat(i_ball, "ballcount", 2.0);
	DispatchKeyValueFloat(i_ball, "minspeed", fl_minspeed);
	DispatchKeyValueFloat(i_ball, "maxspeed", fl_maxspeed);
	DispatchKeyValueFloat(i_ball, "maxballbounces", fl_bouncecount);
	DispatchKeyValueFloat(i_ball, "spawnflags", 2.0);
	
	//Orient the launcher in a random direction. For maximum variety.
	float vec_random_angle_vector[3] = {0.0, 0.0, 0.0};
	vec_random_angle_vector[0] = GetRandomFloat(-20.0, 20.0);
	vec_random_angle_vector[1] = GetRandomFloat(-180.0, 180.0);
	vec_random_angle_vector[2] = 0.0;
	TeleportEntity(i_ball, NULL_VECTOR, vec_random_angle_vector, NULL_VECTOR);
	
	//Launch the balls and kill the spawner
	//The balls are launched twice here to create extra balls
	AcceptEntityInput(i_ball, "LaunchBall");
	AcceptEntityInput(i_ball, "LaunchBall");
	AcceptEntityInput(i_ball, "Kill");
	
	//Be gone, thot
	CloseHandle(data);
}

//This function is called whenever the map starts and whenever a player spawns.
//It creates a blast damage filter, then searches for and applies to entities that need it.
//TODO: Make this solution a little bit better.
static void f_ApplyDamageFilters()
{
	//Create a blast damage filter that we can apply to enemies so they don't die to grenades.
	//This filter also gets applies to grenades so they don't blow each other up.
	int i_damagefilter_index = CreateEntityByName("filter_damage_type");
	DispatchKeyValueFloat(i_damagefilter_index, "damagetype", 64.0);
	DispatchKeyValue(i_damagefilter_index, "targetname", "fdt_noblastdamage");
	DispatchKeyValueFloat(i_damagefilter_index, "Negated", 1.0);
	
	//Make vortigaunts immune to everything so we can actually play Episode 2
	int i_vort_damagefilter_index = CreateEntityByName("filter_damage_type");
	DispatchKeyValueFloat(i_vort_damagefilter_index, "damagetype", 16384.0);
	DispatchKeyValue(i_vort_damagefilter_index, "targetname", "fdt_vortimmune");
	
	//When the map starts, look for things that we have to make immune to explosives.
	CreateTimer(1.0, f_FindEnemies, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(5.0, f_FindEnemies, _, TIMER_FLAG_NO_MAPCHANGE);
}

//We can only let go of our mistakes by exploding our dumpsters.
public Action f_ExplodeDumpsters(Handle timer07, any data)
{
	float vec_dump_origin[3] = {0.0, 0.0, 0.0};
	GetEntPropVector(data, Prop_Send, "m_vecOrigin", vec_dump_origin);
	
	for(int i = 0; i < 8; i++)
	{
		int i_ball = CreateEntityByName("point_combine_ball_launcher");
		DispatchSpawn(i_ball);
		TeleportEntity(i_ball, vec_dump_origin, NULL_VECTOR, NULL_VECTOR);
		
		//Make a data pack to pass multiple variables to the ball function
		//Dumpster balls need to be way crazier than normal
		DataPack dp_dumpster_pack = CreateDataPack();
		WritePackCell(dp_dumpster_pack, i_ball);
		WritePackFloat(dp_dumpster_pack, 1200.0); //Minimum ball speed
		WritePackFloat(dp_dumpster_pack, 1400.0); //Maximum ball speed
		WritePackFloat(dp_dumpster_pack, 12.0); //Number of bounces
		
		CreateTimer(0.04, f_LaunchCombineBall, dp_dumpster_pack, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	AcceptEntityInput(data, "Kill");
}
