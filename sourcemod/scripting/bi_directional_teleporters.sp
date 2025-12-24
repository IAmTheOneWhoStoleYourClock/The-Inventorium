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
#include <adt>
#include <adt_array>

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

int OwnerOffset;
int BuildOffset;
int TeleportOffset;
int ArrowOffset;
//int RechargeOffset;
int LevelOffset;
int ShowArrowOffset;
float UTurn = 180.0;
float FloatZero = 0.0; // Is this even nessesary? Probably not, but i'd rather not poke the lion.
char OwnerEntrance[100];
char OwnerExit[100];
char OwnerPulse[100];
ConVar sm_teleautoswap;
ConVar sm_teleautoswap_time;
public Plugin:myinfo =
{
	name = "Clock's Bi-Directional Teleporters TF2C Rewrite",
	author = "IAmTheOneWhoStoleYourClock, El Diablo",
	description = "El Diablo's hack fix for TF2 repurposed into a custom attribute",
	version = "2.0",
	url = "https://github.com/IAmTheOneWhoStoleYourClock/The-Inventorium"
};

public OnPluginStart()
{
	CreateConVar("war3evo_bidirectional_teleporters","1.1","War3evo bi-directional teleporters",FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	sm_teleautoswap = CreateConVar("sm_teleautoswap", "1", "True/False. Teleporters with this attribute will regularily swap positions while idle.");
	sm_teleautoswap_time = CreateConVar("sm_teleautoswap_time", "9", "Interval, in seconds, at which idle teleporters will swap when sm_teleautoswap is True.");
	OwnerOffset = FindSendPropInfo("CBaseObject", "m_hBuilder");
	BuildOffset = FindSendPropInfo("CBaseObject", "m_bBuilding");
	TeleportOffset = FindSendPropInfo("CObjectTeleporter", "m_iState");
	ArrowOffset = FindSendPropInfo("CObjectTeleporter", "m_flYawToExit");
//	RechargeOffset = FindSendPropInfo("CObjectTeleporter", "m_flRechargeTime"); //Sadly neither this or m_flCurrentRechargeDuration seem to give me the amount of time it takes to recharge.
	LevelOffset = FindSendPropInfo("CBaseObject", "m_iUpgradeLevel");
	HookEvent("player_builtobject", event_player_builtobject);
	// I believe these two cover all of the ways a building could be destroyed. Broken by foe, Self-destructed, Class swapped, and the player leaving the game are all covered by this at least.  -Clock
	HookEvent("object_destroyed", event_building_destroyed, EventHookMode_Pre);
	HookEvent("object_removed", event_building_destroyed, EventHookMode_Pre);
	HookEvent("post_inventory_application",EnablePulseCheck,EventHookMode_Post);
	// Ineffecient and bad, but runs once and shouldn't ever matter regardless...
	int owner;
	for(int i=1;i<2048;i++){
		if(!IsValidEntity(i)){
		continue;
		}

		decl String:neltclass[32];
		GetEntityNetClass(i, neltclass, sizeof(neltclass));

		if (!strcmp(neltclass, "CObjectTeleporter") == false){
			continue;
		}
		// Why did I feel the need to FindSendProp every cycle?
		owner = GetEntDataEnt2(i,OwnerOffset);
		if (!IsValidEntity(owner)){
			continue;
		}
		if(GetEntProp(i, Prop_Send, "m_iObjectMode") == 1)
		{
			SDKHook(i, SDKHook_TouchPost, OnTeletouched);
			OwnerExit[owner] = 	i;
		}
		else
		{
			OwnerEntrance[owner] = 	i;
		}
		if (OwnerEntrance[owner] && OwnerExit[owner])
		{
			if(GetWeaponIndex(GetPlayerWeaponSlot(owner, 2)) == 3386)
			{
				OwnerPulse[owner] = 1;
				if(sm_teleautoswap){
					CreateTimer(GetConVarFloat(sm_teleautoswap_time), TeleportSwapPulse, owner);
				}
			}
		}
	}
}

// TO DO: Assess the lag impact of all of this. Unless everybody is using this, it should be negliable? I really should make sure though...
public Action:event_player_builtobject(Handle:event, const String:name[], bool:dontBroadcast)
{
	int index = GetEventInt(event, "index");
	new TFObjectType:BuildingType = TFObjectType:GetEventInt(event, "object");

	int owner = GetClientOfUserId(GetEventInt(event, "userid"));
	if(ValidPlayer(owner) && IsValidEntity(index))
	{
		if(BuildingType == TFObject_Teleporter)
		{
			if(GetEntProp(index, Prop_Send, "m_iObjectMode") == 1)
			{
				if(GetWeaponIndex(GetPlayerWeaponSlot(owner, 2)) == 3386)
				{
					SDKHook(index, SDKHook_TouchPost, OnTeletouched);
				}
				OwnerExit[owner] = 	index;
			}
			else
			{
				OwnerEntrance[owner] = 	index;
			}
			if (OwnerEntrance[owner] && OwnerExit[owner])
			{
				if(GetWeaponIndex(GetPlayerWeaponSlot(owner, 2)) == 3386)
				{
					OwnerPulse[owner] = 1;
					if(sm_teleautoswap){
						CreateTimer(GetConVarFloat(sm_teleautoswap_time), TeleportSwapPulse, owner);
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action:event_building_destroyed(Handle:event, const String:name[], bool:dontBroadcast)
{
	int index = GetEventInt(event, "index");
	
	decl String:netclass[32];
	GetEntityNetClass(index, netclass, sizeof(netclass));
	if (strcmp(netclass, "TFObject_Teleporter") == 0)
	{
		int builder = GetEntPropEnt(index, Prop_Send, "m_hBuilder");
		if (ValidPlayer(builder))
		{
			if(GetEntProp(index, Prop_Send, "m_iObjectMode") == 0)
			{
				OwnerEntrance[builder] = 0;
			}
			else{
				OwnerExit[builder] = 0;
			}
		}
	}

	return Plugin_Continue;
}

public void TeleportSwapPulse (Handle timer, int owner)
{
	if (OwnerEntrance[owner] && OwnerExit[owner])
	{
		if(GetWeaponIndex(GetPlayerWeaponSlot(owner, 2)) == 3386)
		{
			CreateTimer(GetConVarFloat(sm_teleautoswap_time), TeleportSwapPulse, owner); // Even if the next check fails, repeat this.
			if(!GetEntData(OwnerExit[owner], BuildOffset) && (GetEntData(OwnerEntrance[owner], TeleportOffset) == 2)) // Dont do this if the buildings aren't ready to teleport! This supposed to be purely visual, afterall!
			{
				float ArrowRotation = GetEntDataFloat(OwnerEntrance[owner], ArrowOffset);
				if (ArrowRotation < FloatZero){
					SetEntDataFloat(OwnerEntrance[owner], ArrowOffset, ArrowRotation + UTurn);
				}
				else{
					SetEntDataFloat(OwnerEntrance[owner], ArrowOffset, ArrowRotation - UTurn);
				}
				TeleportSwap(OwnerExit[owner], OwnerEntrance[owner]);
			}
		}
		else{
			OwnerPulse[owner] = 0;
		}
	}
	else{
		OwnerPulse[owner] = 0;
	}
	// If this is no longer true let this burn out....
}

public void EnablePulseCheck(Event:event, const String:name[], bool dontBroadcast)
{
	new owner = GetClientOfUserId(GetEventInt(event, "userid"));
	if(GetWeaponIndex(GetPlayerWeaponSlot(owner, 2)) == 3386)
	{
		if(OwnerExit[owner]){
			SDKHook(OwnerExit[owner], SDKHook_TouchPost, OnTeletouched);
			if(!OwnerPulse[owner] && sm_teleautoswap && OwnerEntrance[owner]){
				CreateTimer(GetConVarFloat(sm_teleautoswap_time), TeleportSwapPulse, owner);
			}
		}
	}
}

stock bool:IsValidEnt(iEnt)
{
    return iEnt > MaxClients && IsValidEntity(iEnt);
}

stock GetWeaponIndex(iWeapon)
{
    return IsValidEnt(iWeapon) ? GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"):-1;
}

public void OnTeletouched (int entity, int other)
{
	if(ValidPlayer(other) && IsValidEntity(entity))
	{
		int owner = GetEntPropEnt(entity, Prop_Send, "m_hBuilder");
		if(ValidPlayer(owner))
		{
			if(GetWeaponIndex(GetPlayerWeaponSlot(GetEntDataEnt2(entity, OwnerOffset), 2)) == 3386)
			{
				int entrance = OwnerEntrance[owner];
				if(entrance)
				{
					if(!GetEntData(entity, BuildOffset) && (GetEntData(entrance, TeleportOffset) == 2)) // Dont do this while the buildings aren't ready to teleport!
					{
						float ArrowRotation = GetEntDataFloat(entrance, ArrowOffset);
						if (ArrowRotation < FloatZero){
							SetEntDataFloat(entrance, ArrowOffset, ArrowRotation + UTurn);
						}
						else{
							SetEntDataFloat(entrance, ArrowOffset, ArrowRotation - UTurn);
						}
						TeleportSwap(entity, entrance);
						// Let's not be constantly running this actually
						switch (GetEntData(entity, LevelOffset)) // Can't seem to actually check for the length of the recharge for whatever reason, so this will have to do.
						{
							case 1:
							{
								CreateTimer(10.3, TeleportRehook, entity); 
							}
							case 2:
							{
								CreateTimer(5.3, TeleportRehook, entity); 
							}
							case 3:
							{
								CreateTimer(3.3, TeleportRehook, entity); // Small 0.3 second buffer because the hook keeps getting readded before the teleporter is actually active again.
							}
							default:
  							{
								ThrowError("WHY IS MY PRECIOUS TELEPORTER THROWING ERRORS?! WHY AM I REACHING YOU AT INVALID LEVELS!?! WHY!?! WHY!?! WHHHHHYYYYYYY!?!?!??!?!");
   							}
						}
						SDKUnhook(entity, SDKHook_TouchPost, OnTeletouched);
					}
				}
			}
		}
	}
}

public void TeleportRehook (Handle timer, int entity)
{
	if(IsValidEntity(entity))
	{
		decl String:netclass[32];
		GetEntityNetClass(index, netclass, sizeof(netclass));
		if ( !(strcmp(netclass, "TFObject_Teleporter") == 0) )
		{
			SDKHook(entity, SDKHook_TouchPost, OnTeletouched);
		}
	}
}


TeleportSwap(Teleporter1, Teleporter2)
{
	float position1[3];
	float position2[3];

	GetEntPropVector(Teleporter1, Prop_Send, "m_vecOrigin", position1);
	GetEntPropVector(Teleporter2, Prop_Send, "m_vecOrigin", position2);

	TeleportEntity(Teleporter1, position2, NULL_VECTOR, NULL_VECTOR);
	TeleportEntity(Teleporter2, position1, NULL_VECTOR, NULL_VECTOR);
}
