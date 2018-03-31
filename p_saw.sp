#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

public Plugin myinfo =
{
	name = "Artifact of Why",
	author = "Breadcrumbs",
	description = "Because we can?",
	version = "0.0",
	url = "http://www.sourcemod.net/"
}

// Create a player spawn event
public void OnPluginStart()
{
	HookEvent("player_spawn", f_player_spawned);
	HookEvent("player_death", f_player_died);
}

// Make the laser model index global so it can
// be used by the laser rendering function later
int i_laser_model;

public void OnMapStart()
{
	i_laser_model = PrecacheModel("sprites/laserbeam.vmt");
	PrecacheSound("beams/beamstart5.wav", true);
	PrefetchSound("beams/beamstart5.wav");
	PrecacheSound("ambient/machines/machine_whine1.wav", true);
	PrefetchSound("ambient/machines/machine_whine1.wav");
	PrecacheSound("ambient/levels/labs/electric_explosion1.wav", true);
	PrefetchSound("ambient/levels/labs/electric_explosion1.wav");
	
	CreateTimer(1.0, f_search_for_players, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(2.0, f_search_for_players, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(3.0, f_search_for_players, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(10.0, f_search_for_players, _, TIMER_FLAG_NO_MAPCHANGE);
}

// Whenever a player spawns, give them a hook that'll activate whenever they shoot
public void f_player_spawned(Event event_spawn, const char[] name, bool dontBroadcast)
{
	int i_player_index = event_spawn.GetInt("userid");
	int i_client = GetClientOfUserId(i_player_index);
	
	SDKUnhook(i_client, SDKHook_FireBulletsPost, f_on_shoot);
	SDKHook(i_client, SDKHook_FireBulletsPost, f_on_shoot);
}

public void f_player_died(Event event_die, const char[] name, bool dontBroadcast)
{
	int i_player_index = event_die.GetInt("userid");
	int i_client = GetClientOfUserId(i_player_index);
	
	SDKUnhook(i_client, SDKHook_FireBulletsPost, f_on_shoot);
	SDKHook(i_client, SDKHook_FireBulletsPost, f_on_shoot);
}

// Do this when someone shoots
public void f_on_shoot(int client, int shots, const char[] weaponname)
{
	if(StrEqual("weapon_pistol", weaponname))
	{
		float vec_origin[3] = {0.0, 0.0, 0.0};
		float vec_angles[3] = {0.0, 0.0, 0.0};

		GetClientEyePosition(client, vec_origin);
		GetClientEyeAngles(client, vec_angles);
		
		f_fire_saw(vec_origin, vec_angles, client);
	}
}

public void f_fire_saw(float[] origin, float[] angles, int client)
{	
	float vec_saw_origin[3] = {0.0, 0.0, 0.0};
	float vec_saw_angles[3] = {0.0, 0.0, 0.0};

	vec_saw_origin[0] = origin[0];
	vec_saw_origin[1] = origin[1];
	vec_saw_origin[2] = origin[2];
	
	vec_saw_angles[0] = angles[0];
	vec_saw_angles[1] = angles[1];
	vec_saw_angles[2] = angles[2];
	
	// Create a combine ball launcher
	// We'll use a combine ball as the origin of the saw, since it
	// has the exact movement behavior we want.
	int i_launcher = CreateEntityByName("point_combine_ball_launcher");
	DispatchSpawn(i_launcher);
	
	DispatchKeyValueFloat(i_launcher, "launchconenoise", 0.0);
	DispatchKeyValueFloat(i_launcher, "ballradius", 20.0);
	DispatchKeyValueFloat(i_launcher, "ballcount", 1.0);
	DispatchKeyValueFloat(i_launcher, "minspeed", 100.0);
	DispatchKeyValueFloat(i_launcher, "maxspeed", 100.0);
	DispatchKeyValueFloat(i_launcher, "maxballbounces", 1.0);
	DispatchKeyValueFloat(i_launcher, "spawnflags", 2.0);
	
	TeleportEntity(i_launcher, vec_saw_origin, vec_saw_angles, NULL_VECTOR);
	
	AcceptEntityInput(i_launcher, "LaunchBall");
	
	// Find the ball that was just launched
	int i_ball = f_find_entity("prop_combine_ball", i_launcher);
	SetEntProp(i_ball, Prop_Data, "m_CollisionGroup", 1);
	
	float vec_laser_angles[3] = {0.0, 0.0, 0.0};
	
	DataPack dp_data = CreateDataPack();
	WritePackCell(dp_data, i_ball);
	WritePackCell(dp_data, 0);
	WritePackFloat(dp_data, vec_laser_angles[0]);
	WritePackFloat(dp_data, vec_laser_angles[1]);
	WritePackFloat(dp_data, vec_laser_angles[2]);
	WritePackCell(dp_data, client);
	
	CreateTimer(1.5, f_start_saw, dp_data, TIMER_FLAG_NO_MAPCHANGE);

	AcceptEntityInput(i_launcher, "Kill");
}

public Action f_start_saw(Handle saw_timer, any dp_data)
{
	ResetPack(dp_data, false);
	int i_ball = ReadPackCell(dp_data);
	
	float vec_ball_origin[3] = {0.0, 0.0, 0.0};
	GetEntPropVector(i_ball, Prop_Data, "m_vecOrigin", vec_ball_origin);
	
	EmitSoundToAll("beams/beamstart5.wav", i_ball, SNDLEVEL_SNOWMOBILE);
	EmitAmbientSound("ambient/machines/machine_whine1.wav", vec_ball_origin, i_ball);
	CreateTimer(0.1, f_noise_loop, _, TIMER_REPEAT);
	
	RequestFrame(f_handle_saw, dp_data);
}

public void f_handle_saw(DataPack data)
{	
	ResetPack(data, false);
	int i_ball = ReadPackCell(data);
	int i_counter = ReadPackCell(data);
	float vec_angle1 = ReadPackFloat(data);
	float vec_angle2 = ReadPackFloat(data);
	float vec_angle3 = ReadPackFloat(data);
	int i_client = ReadPackCell(data);
	
	if(GetEntProp(i_ball, Prop_Data, "m_nBounceCount") > 0 || !IsValidEntity(i_ball))
	{
		CloseHandle(data);
		StopSound(i_ball, SNDCHAN_STATIC, "ambient/machines/machine_whine1.wav");
		EmitSoundToAll("ambient/levels/labs/electric_explosion1.wav", SOUND_FROM_WORLD, SNDLEVEL_ROCKET);
		AcceptEntityInput(i_ball, "Explode");
		return;
	}
	
	float vec_ball_origin[3] = {0.0, 0.0, 0.0};
	float vec_laser_angles[3] = {0.0, 0.0, 0.0};
	float vec_laser_hit[3] = {0.0, 0.0, 0.0};
	GetEntPropVector(i_ball, Prop_Data, "m_vecOrigin", vec_ball_origin);

	vec_laser_angles[0] = vec_angle1;
	vec_laser_angles[1] = vec_angle2;
	vec_laser_angles[2] = vec_angle3;
	
	for(int i = 0; i < 6; i++)
	{
		float j = float(i);
		vec_laser_angles[1] += j / 6.0 * 360.0;
		
		// Shoot the laser, track where it lands
		Handle ry_laser = TR_TraceRayFilterEx(
		vec_ball_origin, 
		vec_laser_angles, 
		MASK_VISIBLE, 
		RayType_Infinite, 
		ry_trace_filter);
		
		TR_GetEndPosition(vec_laser_hit, ry_laser);
	
		int i_victim = TR_GetEntityIndex(ry_laser);
		if(IsValidEntity(i_victim))
		{
			SDKHooks_TakeDamage(
			i_victim, 
			i_client, 
			i_client, 
			1000.0, 
			0, 
			-1, 
			vec_laser_angles, 
			vec_ball_origin);
		}
		
		// Create spark effect
		TE_SetupSparks(vec_laser_hit, vec_laser_angles, 1, 1);
		f_te_to_all();
		
		// Create laser effect
		int i_color[4] = {0, 100, 255, 200};
		TE_SetupBeamPoints(
		vec_ball_origin, 
		vec_laser_hit, 
		i_laser_model, 
		i_laser_model, 
		0, 
		22, 
		0.1,
		1.0, 
		1.0, 
		0, 
		1.0, 
		i_color, 
		2);
		f_te_to_all();
		
		vec_laser_angles[1] = 0.0 + vec_angle2;
		
		CloseHandle(ry_laser);
	}
	
	i_counter++;
	vec_angle2 += 2.0;
	
	ResetPack(data, true);
	WritePackCell(data, i_ball);
	WritePackCell(data, i_counter);
	WritePackFloat(data, vec_angle1);
	WritePackFloat(data, vec_angle2);
	WritePackFloat(data, vec_angle3);
	WritePackCell(data, i_client);
	
	//Recursion!
	RequestFrame(f_handle_saw, data);
}

public Action f_noise_loop(Handle noise_loop)
{
	
}

// Finds an entity with a given class and a given owner
// or spawner
// Returns index of entity found, -1 if nothing was found
public int f_find_entity(const char[] class, int owner)
{
	int i_index = -1;
	while((i_index = FindEntityByClassname(i_index, class)) != -1)
	{
		if(GetEntPropEnt(i_index, Prop_Data, "m_hSpawner") == owner)
		{
			return i_index;
		}
		else if(owner == -1)
		{
			return i_index;
		}
	}
	
	return -1;
}

// Rays don't register on balls
public bool ry_trace_filter(int entity, int contentsMask)
{
	char str_ent_class[64];
	GetEntityClassname(entity, str_ent_class, 64);
	
	if(StrEqual(str_ent_class, "prop_combine_ball"))
	{
		return false;
	}
	
	return true;
}

public void f_te_to_all()
{
	// Enumerate through all clients, send the effect to each one
	for(int i = 0; i < MAXPLAYERS + 1; i++)
	{
		if(IsValidEntity(i))
		{
			char str_name[64];
			GetEntityClassname(i, str_name, 64);
			if(StrEqual(str_name, "player"))
			{
				TE_SendToClient(i);
			}
		}
	}
}

public Action f_search_for_players(Handle timer_01)
{
	int i_index = -1;
	
	while ((i_index = FindEntityByClassname(i_index, "player")) != -1)
	{
		SDKUnhook(i_index, SDKHook_FireBulletsPost, f_on_shoot);
		SDKHook(i_index, SDKHook_FireBulletsPost, f_on_shoot);
	}
}

