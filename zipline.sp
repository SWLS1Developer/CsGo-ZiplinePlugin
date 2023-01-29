#include <sourcemod>
#include <sdktools>

#define IN_ATTACK      (1 << 0)
#define IN_JUMP   (1 << 1)
#define IN_DUCK   (1 << 2)
#define IN_FORWARD    (1 << 3)
#define IN_BACK   (1 << 4)
#define IN_USE      (1 << 5)
#define IN_CANCEL      (1 << 6)
#define IN_LEFT   (1 << 7)
#define IN_RIGHT        (1 << 8)
#define IN_MOVELEFT  (1 << 9)
#define IN_MOVERIGHT        (1 << 10)
#define IN_ATTACK2    (1 << 11)
#define IN_RUN      (1 << 12)
#define IN_RELOAD      (1 << 13)
#define IN_ALT1   (1 << 14)
#define IN_ALT2   (1 << 15)
#define IN_SCORE        (1 << 16)   
#define IN_SPEED        (1 << 17)  
#define IN_WALK   (1 << 18)    
#define MAX_BUTTONS 25

char ZIPLINE_MOVESOUND[256];
const int ZIPLINE_REACH_LIMIT = 100;
const int ZIPLINE_SPEED = 450;
const int ZIPLINE_OFFSET = -70;

int g_LastButtons[MAXPLAYERS+1];
int ZipClients[MAXPLAYERS + 1];
bool ZipDirection[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = "ZipLine",
    author = "SWLS",
    description = "Allows players to use a zipline",
    version = "1.0",
    url = ""
};

public OnPluginStart()
{
	ZIPLINE_MOVESOUND = "physics\\metal\\metal_box_scrape_smooth_loop1.wav";
    HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
    
    for (int i = 0; i < sizeof(ZipClients); ++i)
   	{
   		ZipClients[i] = -1;
   		ZipDirection[i] = true;
   	}
}

public OnClientDisconnect_Post(client)
{
    g_LastButtons[client] = 0;
}

public Action OnPlayerRunCmd(client, &buttons, &impulse, float vel[3], float angles[3], &weapon)
{
    for (new i = 0; i < MAX_BUTTONS; i++)
    {
        int button = (1 << i);
        
        if ((buttons & button))
        {
            if (!(g_LastButtons[client] & button))
            {
                OnButtonPress(client, button);
            }
        }
        else if ((g_LastButtons[client] & button))
        {
            OnButtonRelease(client, button);
        }
    }
    
    g_LastButtons[client] = buttons;
    
    return Plugin_Continue;
}

public Event_PlayerDeath(Event hEvent, const char[] sName, bool bBrodcast)
{
	int victim = GetClientOfUserId(hEvent.GetInt("userid"));
	StopZipline(victim);
}

public Event_RoundStart(Handle hEvent, const char[] sName, bool bBroadcast)
{
    for (int i = 1; i < MaxClients + 1; i++)
    	StopZipline(i);
}

public OnClientPutInServer(int client)
{
	ZipClients[client] = -1;
	ZipDirection[client] = true;
}

public OnGameFrame()
{
	for (int i = 1; i < MaxClients + 1; i++)
	{
		if (IsClientInGame(i) && ZipClients[i] > -1 && IsValidEntity(ZipClients[i]))
		{
			float origin[3];
			GetEntPropVector(ZipClients[i], Prop_Send, "m_vecOrigin", origin);
			origin[2] += ZIPLINE_OFFSET;
			TeleportEntity(i, origin, NULL_VECTOR, NULL_VECTOR);
		} 
	}
}

void StopZipline(int client)
{
	if (!IsClientInGame(client))
		return;
	
	int iEnt = ZipClients[client];
	if (iEnt > 0 && IsValidEntity(iEnt))
	{
		AcceptEntityInput(iEnt, "Stop");
		AcceptEntityInput(iEnt, "Kill");
	}

    ZipClients[client] = -1;
}

OnButtonPress(client, button)
{
    if (button == IN_USE)
    {
    	if (ZipClients[client] > -1)
    		return Plugin_Handled;
    	
	    float eyePos[3], entOrigin[3];
		int iEnt = -1;
		char EntName[64];
		
		iEnt = GetNearestEntity(client, "path_track", entOrigin);
		GetClientEyePosition(client, eyePos);

		if (iEnt != -1 && IsValidEntity(iEnt))
		{
			GetEntPropString(iEnt, Prop_Data, "m_iName", EntName, sizeof(EntName));
			if (GetVectorDistance(eyePos, entOrigin) > ZIPLINE_REACH_LIMIT)
				return Plugin_Handled;
			
			Handle hRay = TR_TraceRayFilterEx(eyePos, entOrigin, MASK_VISIBLE, RayType_EndPoint, Filter_NoPlayers);
			
			if (TR_DidHit(hRay))
				return Plugin_Handled;
				
			CloseHandle(hRay);
			
			int nEnt = CreateEntityByName("func_tanktrain", -1);
	        if (nEnt > -1)
	        {
		        DispatchKeyValue(nEnt, "target", EntName);
		        char speedStr[16];
		        IntToString(ZIPLINE_SPEED, speedStr, sizeof(speedStr));
		        DispatchKeyValue(nEnt, "speed", speedStr);
		        DispatchKeyValue(nEnt, "MoveSound", ZIPLINE_MOVESOUND);
		        DispatchKeyValue(nEnt, "wheels", "3");
		        DispatchSpawn(nEnt);
		        SetEntProp(nEnt, Prop_Send, "m_nSolidType", 2);
		        AcceptEntityInput(nEnt, "StartForward");
		        
		        ZipClients[client] = nEnt;
	        }
		}
    } else if (button == IN_JUMP)
    {
    	if (ZipClients[client] > 0)
    	{
    		StopZipline(client);
    	}
    } else if (button == IN_FORWARD)
    {
    	int iEnt = ZipClients[client];
    	if (iEnt > 0 && IsValidEntity(iEnt))
    	{
    		if (ZipDirection[client])
    			AcceptEntityInput(iEnt, "StartForward");
    		else
    			AcceptEntityInput(iEnt, "StartBackward");
    			
    		ZipDirection[client] = !ZipDirection[client];
    	}	
    }
}

OnButtonRelease(client, button)
{
    
}

public bool Filter_NoPlayers(entity, mask)
{
    return (entity > MaxClients && !(0 < GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity") <= MaxClients));
}


public int GetNearestEntity(int client, char[] classname, float origin[3])
{
    int nearestEntity = -1;
    float clientVecOrigin[3], entityVecOrigin[3], nearest_entityVecOrigin[3];
    
    GetEntPropVector(client, Prop_Data, "m_vecOrigin", clientVecOrigin);
    
    float distance, nearestDistance = -1.0;
    
    int entity = -1;
    while ((entity = FindEntityByClassname(entity, classname)) != -1)
    {
        GetEntPropVector(entity, Prop_Data, "m_vecOrigin", entityVecOrigin);
        distance = GetVectorDistance(clientVecOrigin, entityVecOrigin);
        
        if (distance < nearestDistance || nearestDistance == -1.0)
        {
            nearestEntity = entity;
            nearestDistance = distance;
            nearest_entityVecOrigin = entityVecOrigin;
        }
    }
    
    origin = nearest_entityVecOrigin;
    return nearestEntity;
}