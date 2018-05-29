#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

public Plugin myinfo =
{
	name = "Artifact of Rubber",
	author = "Breadcrumbs",
	description = "Bouncy catacylism",
	version = "0.0",
	url = "http://www.sourcemod.net/"
}

float pushChance = 0.000005;
float pushFactor = 10000.0;
float maxPush = 1.0;

char pushableObjects[64] = "prop_physics item_ weapon_ npc_ prop_vehicle_airboat";

ConVar cvPushProb;

public void OnPluginStart()
{
	cvPushProb = CreateConVar("rubber_push_probability", 
	"0.000002", // Default value
	"Chance every game tick for a random prop to bounce in the house", 
	FCVAR_NOTIFY, 
	true, 
	0.0, // Min value
	true, 
	1.0); // Max value
	
	cvPushProb.AddChangeHook(OnProbChange);
}

Handle chatTimer;
public void OnMapStart()
{
	chatTimer = CreateTimer(5.0, ChatProbability, _, TIMER_REPEAT);
}

public Action ChatProbability(Handle timer)
{
	PrintToChatAll("Probability is %f", pushChance);
}

public void OnGameFrame()
{
	for(int i = 0; i < GetMaxEntities(); i++)
	{
		if(IsValidEntity(i))
		{
			char classname[64];
			GetEntityClassname(i, classname, 64);
			if(StrContains(pushableObjects, classname) != -1)
			{
				int rand = GetRandomInt(1, RoundToNearest(1.0 / pushChance));
				if(rand == 1)
				{
					float pushVector[3] = {0.0, 0.0, 0.0};
					pushVector[0] = GetRandomFloat(-pushFactor, pushFactor);
					pushVector[1] = GetRandomFloat(-pushFactor, pushFactor);
					pushVector[2] = GetRandomFloat(-pushFactor, pushFactor);
					TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, pushVector);
					SetEntPropVector(i, Prop_Data, "m_vecAbsVelocity", Float:{0.0, 0.0, 0.0});
					
					pushChance += GetConVarFloat(cvPushProb);
					PrintToServer("%f", pushChance);
					
					if(pushChance > maxPush)
					{
						pushChance = maxPush;
					}
					else
					{
						pushFactor += 5.0;
					}
				}
			}
		}
	}
}

public void OnMapEnd()
{
	pushChance = GetConVarFloat(cvPushProb);
	pushFactor = 10000.0;
	CloseHandle(chatTimer);
}

public void OnProbChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	pushChance = StringToFloat(newValue);
}
