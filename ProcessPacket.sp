#pragma semicolon 1

#define PLUGIN_AUTHOR "null138"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#pragma newdecls required

int iPackets[MAXPLAYERS + 1];
float fOverflowCycle[MAXPLAYERS + 1];
Handle hProcessPacket;

#define FLOW_PACKET_RATE 2500
#define FLOW_PACKET_CYCLE 0.3

public Plugin myinfo = 
{
	name = "NetChan Spam Fix",
	author = PLUGIN_AUTHOR,
	description = "Test version of the packet spamming fix",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/null138/"
}

public void OnPluginStart()
{
	Handle conf = LoadGameConfigFile("ProcessPacket");
	if (conf == INVALID_HANDLE)
		SetFailState("Failed to load gamedata ProcessPacket");
		
	hProcessPacket = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_Ignore);
	if(!hProcessPacket)
		SetFailState("Failed to setup detour for CNetChan::ProcessPacket()");
	
	if(!DHookSetFromConf(hProcessPacket, conf, SDKConf_Signature, "CNetChan::ProcessPacket()"))
		SetFailState("Failed to load CNetChan::ProcessPacket() signature from gamedata");
	
	DHookAddParam(hProcessPacket, HookParamType_ObjectPtr);
	DHookAddParam(hProcessPacket, HookParamType_Bool);

	if(!DHookEnableDetour(hProcessPacket, false, ProcessPacket))
		SetFailState("Failed to detour CNetChan::ProcessPacket()");
	
	delete conf;
}

public void OnClientDisconnect(int client)
{
	iPackets[client] = 0;
	fOverflowCycle[client] = 0.0;
}

public MRESReturn ProcessPacket(DHookParam hParams)
{
	int client = GetClientFromNetAdr(hParams.GetAddress(1) + view_as<Address>(4));
	if(client < 1)
		return MRES_Ignored;
		
	iPackets[client] += DHookGetParamObjectPtrVar(hParams, 1, 32, ObjectValueType_Int);
	if(fOverflowCycle[client] > GetGameTime())
		return MRES_Ignored;

	fOverflowCycle[client] = GetGameTime() + FLOW_PACKET_CYCLE;
	PrintToServer("%N fOverflowCycle[client] : 0.4%f",client, fOverflowCycle[client]);

	if(iPackets[client] > FLOW_PACKET_RATE)
	{
		iPackets[client] = 0;
		fOverflowCycle[client] = 0.0;
		return MRES_Supercede;
	}
	
	iPackets[client] = 0;
	
	return MRES_Ignored;
}

int GetClientFromNetAdr(Address pNetAddr)
{
	int netAddr, rawIp[4];
	char finalIp[16], targetIp[16];
	
	netAddr = LoadFromAddress(pNetAddr, NumberType_Int32);
	
	rawIp[0] = (netAddr >> 24) & 0x000000FF;
	rawIp[1] = (netAddr >> 16) & 0x000000FF; 
	rawIp[2] = (netAddr >> 8) & 0x000000FF; 
	rawIp[3] = netAddr & 0x000000FF; 
	
	Format(finalIp, 16, "%i.%i.%i.%i", rawIp[3], rawIp[2], rawIp[1], rawIp[0]);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			GetClientIP(i, targetIp, 16);
			if(!strcmp(finalIp, targetIp))
			{
				return i;
			}
		}
	}
	return -1;
}