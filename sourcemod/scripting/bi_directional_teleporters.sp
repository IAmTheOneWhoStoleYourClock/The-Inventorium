// *************************************************************************
// bi_directional_teleporters.sp
//
// Copyright (c) 2014-2015  El Diablo <diablo@war3evo.info>
//
//  bi_directional_teleporters is free software: you may copy, redistribute
//  and/or modify it under the terms of the GNU General Public License as
//  published by the Free Software Foundation, either version 3 of the
//  License, or (at your option) any later version.
//
//  This file is distributed in the hope that it will be useful, but
//  WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//  General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

//  War3Evo Community Forums: https://war3evo.info/forums/index.php

// Sourcemod Plugin Dev for Hire
// http://war3evo.info/plugin-development-team/

// there is a tf2 attribute that chdata says works..
// shoul try this sometime:
// "bidirectional teleport"

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2c>

#include <sdkhooks>
#include <sdktools_functions>

#tryinclude <DiabloStocks>

#if !defined _diablostocks_included
#define LoopAlivePlayers(%1) for(new %1=1;%1<=MaxClients;++%1)\
								if(IsClientInGame(%1) && IsPlayerAlive(%1))

stock bool:ValidPlayer(client,bool:check_alive=false,bool:alivecheckbyhealth=false) {
	if(client>0 && client<=MaxClients && IsClientConnected(client) && IsClientInGame(client))
	{
		if(check_alive && !IsPlayerAlive(client))
		{
			return false;
		}
		if(alivecheckbyhealth&&GetClientHealth(client)<1) {
			return false;
		}
		return true;
	}
	return false;
}
#endif

int TeleporterList[MAXPLAYERS + 1][TFObjectMode];

int TeleporterTime[MAXPLAYERS + 1];

int OwnerOffset;
int BuildOffset;
int TeleportOffset;
int ArrowOffset;
float FullTurn = 180.0;
float FloatZero = 0.0;
public Plugin:myinfo =
{
	name = "Clock's Jank Bi-Directional Teleporters TF2C Rewrite",
	author = "IAmTheOneWhoStoleYourClock, El Diablo",
	description = "El Diablo's hack fix for TF2 repurposed into a even more hacky but also less hacky almost entirely rewriten catarosphe",
	version = "1",
	url = "https://github.com/IAmTheOneWhoStoleYourClock/The-Inventorium"
};

public OnPluginStart()
{
	CreateConVar("war3evo_bidirectional_teleporters","1.1","War3evo bi-directional teleporters",FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	OwnerOffset = FindSendPropInfo("CBaseObject", "m_hBuilder");
	BuildOffset = FindSendPropInfo("CBaseObject", "m_bBuilding");
	TeleportOffset = FindSendPropInfo("CObjectTeleporter", "m_iState");
	ArrowOffset = FindSendPropInfo("CObjectTeleporter", "m_flYawToExit");
//	char Buffer[] = "a";
//	IntToString(ArrowOffset, Buffer[1], 9999);
//	PrintToServer(Buffer[1]);

	HookEvent("player_builtobject", event_player_builtobject);
	for(int i=1;i<2048;i++){

		if(!IsValidEntity(i)){
		continue;
		}

		decl String:neltclass[32];
		GetEntityNetClass(i, neltclass, sizeof(neltclass));

		if ((!strcmp(neltclass, "CObjectTeleporter") == false) && (!strcmp(neltclass, "TFObjectTeleporter") == false)){
			continue;
		}

		if (!IsValidEntity(GetEntDataEnt2(i,FindSendPropInfo("CBaseObject", "m_hBuilder")))){
			continue;
		}
		
		SDKHook(i, SDKHook_TouchPost, OnTouchPost);
	}
}

public Action:event_player_builtobject(Handle:event, const String:name[], bool:dontBroadcast)
{
	int index = GetEventInt(event, "index");
	new TFObjectType:BuildingType = TFObjectType:GetEventInt(event, "object");

	int owner = GetClientOfUserId(GetEventInt(event, "userid"));
	if(ValidPlayer(owner))
	{
		if(BuildingType == TFObject_Teleporter)
		{
			if(IsValidEntity(index))
			{
				SDKHook(index, SDKHook_TouchPost, OnTouchPost);
				//check for entrance (0 = entrance, 1 = exit)
				if(GetEntProp(index, Prop_Send, "m_iObjectMode") == 0) {
//					TeleporterList[owner][TFObjectMode_Entrance] = index; //This leaks. Dang it.
					//PrintToChatAll("Created a Teleporter Entrance");
				}
				else if(GetEntProp(index, Prop_Send, "m_iObjectMode") == 1) {
				}
			}
		}
	}
	return Plugin_Continue;
}

stock bool:IsValidEnt(iEnt)
{
    return iEnt > MaxClients && IsValidEntity(iEnt);
}

stock GetWeaponIndex(iWeapon)
{
    return IsValidEnt(iWeapon) ? GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"):-1;
}

public void OnTouchPost (int entity, int other)
{
	if(ValidPlayer(other))
	{
		if(IsValidEntity(entity))
		{
			int CurrentTime = GetTime();
			int owner = GetEntPropEnt(entity, Prop_Send, "m_hBuilder");
			if(ValidPlayer(owner))
			{
//				PrintToServer("is a valid building");
				decl String:netclass[32];
				GetEntityNetClass(entity, netclass, sizeof(netclass));

				if ( !(strcmp(netclass, "TFObject_Teleporter") == 0) ){
//					PrintToServer("is a teleporter");
					if (GetEntProp(entity, Prop_Send, "m_iObjectMode") == 1){
//						PrintToServer("This is an exit");

						int Entrance = 0;
						int EntranceLow = 0;
						for(int i=1;i<2048;i++){

							if(!IsValidEntity(i)){
								continue;
							}

							decl String:neltclass[32];
							GetEntityNetClass(i, neltclass, sizeof(neltclass));

							if ((!strcmp(neltclass, "CObjectTeleporter") == false) && (!strcmp(neltclass, "TFObjectTeleporter") == false)){
								continue;
							}

							if (GetEntDataEnt2(i,FindSendPropInfo("CBaseObject", "m_hBuilder")) != owner){
								continue;
							}

							if (GetEntDataEnt2(i,FindSendPropInfo("CBaseObject", "m_iObjectMode")) == 0){
								continue;
							}
//							PrintToServer("Owned Entrance");
							EntranceLow = Entrance;
							Entrance = i;


							continue;
						}

						if(Entrance)
						{
//							PrintToServer("is paired");
//							char Buffer[] = "a";
//							IntToString(GetEntData(Entrance, TeleportOffset), Buffer[1], 9999);
//							PrintToServer(Buffer[1]);
							if(!GetEntData(entity, BuildOffset) && (GetEntData(Entrance, TeleportOffset) == 2)) // Dont do this while the buildings aren't ready to teleport!
							{
//								PrintToServer("is ready");
								if(GetWeaponIndex(GetPlayerWeaponSlot(GetEntDataEnt2(entity, OwnerOffset), 2)) == 3386)
								{
									int GroundEnt = GetEntPropEnt(other, Prop_Send, "m_hGroundEntity");
//									char Buffer[4] = "aaa";
//									FloatToString(GetEntData(Entrance, ArrowOffset), Buffer[1], 9999);
//									PrintToServer(Buffer[1]);
//									FloatToString(GetEntData(EntranceLow, ArrowOffset), Buffer[2], 9999);
//									PrintToServer(Buffer[2]);
//									FloatToString(GetEntData(entity, ArrowOffset), Buffer[3], 9999);
//									PrintToServer(Buffer[3]);
//									IntToString(EntranceLow, Buffer[4], 9999);
//									PrintToServer(Buffer[4]);
									// SOMEHOW this seems to be consistent. If this plugin is broken, this is most likely the reason!
									if (Entrance == entity){
										TeleportSwap(EntranceLow, GroundEnt);
										if (GetEntData(EntranceLow, ArrowOffset) < FloatZero){
											SetEntDataFloat(EntranceLow, ArrowOffset, GetEntDataFloat(EntranceLow, ArrowOffset) + FullTurn);
										}
										else{
											SetEntDataFloat(EntranceLow, ArrowOffset, GetEntDataFloat(EntranceLow, ArrowOffset) - FullTurn);
										}
									}
									else if (Entrance > entity){
										TeleportSwap(Entrance, GroundEnt);
										if (GetEntDataFloat(Entrance, ArrowOffset) < FloatZero){
											SetEntDataFloat(Entrance, ArrowOffset, GetEntDataFloat(Entrance, ArrowOffset) + FullTurn);
										}
										else{
											SetEntDataFloat(Entrance, ArrowOffset, GetEntDataFloat(Entrance, ArrowOffset) - FullTurn);
										}
									}
									else{
										TeleportSwap(entity, GroundEnt);
										if (GetEntDataFloat(entity, ArrowOffset) < FloatZero){
											SetEntDataFloat(entity, ArrowOffset, GetEntDataFloat(entity, ArrowOffset) + FullTurn);
										}
										else{
											SetEntDataFloat(entity, ArrowOffset, GetEntDataFloat(entity, ArrowOffset) - FullTurn);
										}
									}
								}
							}
						}
//						else{
//						char Buffer[] = "a";
//						IntToString(GetEntData(GroundEnt, TeleportOffset), Buffer[1], 9999);
//						PrintToServer(Buffer[1]);
//						}
					}
				}
			}
		}
	}
}


TeleportSwap(Teleporter1, Teleporter2)
{
	float position1[3];
	float position2[3];

	GetEntPropVector(Teleporter1, Prop_Send, "m_vecOrigin", position1);
	GetEntPropVector(Teleporter2, Prop_Send, "m_vecOrigin", position2);

//	Unhelpful, and doesn't work anyways.
//	if (!position1[0]){
//		PrintToServer("Teleswap 1 failed.");
//	}
//	if (!position2[0]){
//		PrintToServer("Teleswap 2 failed.");
//	}

	TeleportEntity(Teleporter1, position2, NULL_VECTOR, NULL_VECTOR);
	TeleportEntity(Teleporter2, position1, NULL_VECTOR, NULL_VECTOR);
}
