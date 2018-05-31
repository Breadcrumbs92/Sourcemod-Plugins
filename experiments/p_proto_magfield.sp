#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

public Plugin myinfo =
{
	name = "Magfield Prototype",
	author = "Breadcrumbs",
	description = "The power of physics",
	version = "0.0",
	url = "http://www.sourcemod.net/"
}

float vec_magfield[3] = {0.0, 0.0, 4.0};
float vec_const[3] = {0.0, 2.0, 0.0};

public void OnGameFrame()
{
	for(int i = 1; i < 2048; i++)
	{	
		if(IsValidEntity(i))
		{
			char str_classname[64];
			GetEntityClassname(i, str_classname, sizeof(str_classname));
		
			if(StrEqual(str_classname, "player", true))
			{
				char str_weaponname[64];
				GetClientWeapon(i, str_weaponname, sizeof(str_weaponname));
				
				if(StrEqual(str_weaponname, "weapon_stunstick", true))	
				{			
					float vec_velocity[3] = {0.0, 0.0, 0.0};
					float vec_crossed[3] = {0.0, 0.0, 0.0};
					float vec_push[3] = {0.0, 0.0, 0.0};
				
					// get player velocity, put into vec_velocity
					GetEntPropVector(i, Prop_Data, "m_vecVelocity", vec_velocity);
					
					// debugging info to console
					PrintToServer("[x] : %f, [y] : %f, [z] : %f", vec_velocity[0], vec_velocity[1], vec_velocity[2]);
				
					// cross field vector with velocity vector, store result in vec_crossed
					GetVectorCrossProduct(vec_velocity, vec_magfield, vec_crossed);
				
					vec_crossed[0] /= 64.0;
					vec_crossed[1] /= 64.0;
					vec_crossed[2] /= 64.0;
				
					PrintToServer("[x] : %f, [y] : %f, [z] : %f", vec_crossed[0], vec_crossed[1], vec_crossed[2]);
				
					// add current velocity and cross product
					//AddVectors(vec_velocity, vec_crossed, vec_push);
				
					// push player
					SetEntPropVector(i, Prop_Data, "m_vecBaseVelocity", vec_crossed);
				}
			} 
		}
	}
}
