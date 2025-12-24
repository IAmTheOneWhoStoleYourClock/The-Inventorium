#include <sourcemod>
#include <sdktools>
#include <tf2c>
#include <clients>
#include <sdkhooks>
#undef REQUIRE_PLUGIN

#pragma semicolon 1

#define PL_VERSION	"1.0.0"

public Plugin myinfo =
{
    name        = "KillBill",
    author      = "IAmTheOneWhoStoleYourClock",
    description = "Declassifier Fix.",
    version     = PL_VERSION,
    url         = "https://github.com/IAmTheOneWhoStoleYourClock/The-Inventorium"
};

stock bool:IsValidEnt(iEnt)
{
    return iEnt > MaxClients && IsValidEntity(iEnt);
}

stock GetWeaponIndex(iWeapon)
{
    return IsValidEnt(iWeapon) ? GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"):-1;
}

public void OnPluginStart(){
    HookEvent("post_inventory_application",EventInventory,EventHookMode_Post);
}

public Action:EventInventory(Event:event, const String:name[], bool dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(0.01, PostPostEventInventory, client); // Shouldn't need to do this but apperently I do, I hope this doesn't open up bugginess.
}

public void PostPostEventInventory (Handle timer, int client)
{
    if(IsValidEntity(client)){
		int sapper = GetWeaponIndex(GetPlayerWeaponSlot(client,1));
	    bool Classifier = sapper == 3550;
        bool Tripmine = sapper == 3547;
        bool Yumpy = sapper == 1183;

        if (Classifier || Tripmine || Yumpy){
            RemoveEntity(GetPlayerWeaponSlot(client,1));
        } 
    }
}