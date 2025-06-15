#include <sourcemod>
#include <sdktools>
#include <tf2c>
#include <clients>
#include <sdkhooks>

int OwnerOffset;
int LevelOffset;
int StopThatOffset;
int StopThatOffset2;
int TypeTestOffset;
int IsCheck;
ConVar sm_dispenser_limit;
ConVar sm_sentry_limit;
ConVar sm_jumppad_limit;
ConVar sm_instant_upgrade;

int failsafe = 0; // Used for jumppads in destruction handler.
int failsafe2 = 0; // Used for jumppads in destruction handler.

public Plugin myinfo ={
	name = "The Co-opted Multiple Buildings Plugin",
	author = "shewowkees, IAmTheOneWhoStoleYourClock",
	description = "shewowkees OG multi building plugin, repurposed into my general building plugin.",
	version = "1.1",
	url = "noSiteYet"
};

public void OnPluginStart(){

	sm_dispenser_limit = CreateConVar("sm_dispenser_limit", "1", "Self explanatory, below default will have unexpected results.");
	sm_sentry_limit = CreateConVar("sm_sentry_limit", "1", "Self explanatory, below default will have unexpected results.");
	sm_jumppad_limit = CreateConVar("sm_jumppad_limit", "2", "Self explanatory, below default will have unexpected results.");
	sm_instant_upgrade = CreateConVar("sm_instant_upgrade","0","Please don't actually use this, I don't think it works in TF2C but I kept it from the OG plugin just incase.");

	HookEvent("player_builtobject",Evt_BuiltObject,EventHookMode_Pre);
	HookEvent("post_inventory_application",EventInventory,EventHookMode_Post);
	HookEvent("player_upgradedobject",UpgradeCheck,EventHookMode_Pre);

	RegConsoleCmd("sm_destroy_dispensers", Command_destroy_dispensers);
	RegConsoleCmd("sm_destroy_sentries", Command_destroy_sentries);

	OwnerOffset = FindSendPropInfo("CBaseObject", "m_hBuilder");
	LevelOffset = FindSendPropInfo("CBaseObject", "m_iUpgradeLevel"); // Found these in the SDK. Everything that I need to work works. (Thank goodness Valve never actually fixes their messes and the TF2C never saw a need to change these.)
	StopThatOffset = FindSendPropInfo("CBaseObject", "m_bWasMapPlaced"); // An extra measure of security... I don't want to make max level rebounds for this, but if I ever did I would need to remove this. -Clock
	StopThatOffset2 = FindSendPropInfo("CBaseObject", "m_iHighestUpgradeLevel"); // Goes mostly unused in base TF2. Mini's use a different system entirely for some reason. Odd.
	TypeTestOffset = FindSendPropInfo("CBaseObject", "m_iObjectType");
	IsCheck = FindSendPropInfo("CObjectSentrygun", "m_iState");

	enum 
	{
	TTYPE_NONE=0,
	TTYPE_ENTRANCE,
	TTYPE_EXIT,
	};

	for(int client=1;client<MaxClients;client++){
		if(!IsValidEntity(client)){
			continue;
		}
		if(!IsClientConnected(client)){
			continue;
		}

		SDKUnhook(client, SDKHook_WeaponSwitch, WeaponSwitch);
		SDKHookEx(client, SDKHook_WeaponSwitch, WeaponSwitch);
	}
}



public void OnClientPostAdminCheck(client){
    SDKHookEx(client, SDKHook_WeaponSwitch, WeaponSwitch);
}
public Action Evt_BuiltObject(Event event, const char[] name, bool dontBroadcast){
	int ObjIndex = event .GetInt("index");

	if(GetConVarInt(sm_instant_upgrade)>0){

		SetEntProp(ObjIndex, Prop_Send, "m_iUpgradeMetal", 600);
		SetEntProp(ObjIndex, Prop_Send,"m_iUpgradeMetalRequired",0);
	}

	return Plugin_Continue;
}

public Action UpgradeCheck(Event event, const char[] name, bool dontBroadcast){
	new client = GetClientOfUserId(GetEventInt(event, "userid"))

	new TFClassType:class = TF2_GetPlayerClass(client);
	if(class != TFClass_Engineer) // If this isn't engineer (somehow), we don't care. Skip.
	{
		return Plugin_Continue;
	}

	int DispenserLevelLimit = 3;
	int SentryLevelLimit = 3;
	int SentryLevel = 1;
	int DispenserLevel = 1;

	// Find all sentries, prevent them from being upgraded if the owner's wrench forbids it.
    for(int i=1;i<2048;i++){

		if(!IsValidEntity(i)){
			continue;
		}

		decl String:netclass[32];
		GetEntityNetClass(i, netclass, sizeof(netclass));

		if ( !(strcmp(netclass, "CObjectSentrygun") == 0) ){
			continue;
		}

		//Since this is a sentry gun, figure out the owner's wrench's max level
		SentryLevelLimit = 3;
		bool Golden = GetWeaponIndex(GetPlayerWeaponSlot(GetEntDataEnt2(i, OwnerOffset),2)) == 4336;

		if (Golden){
			SentryLevelLimit--;
		}
		//Gunslinger
		if (GetWeaponIndex(GetPlayerWeaponSlot(GetEntDataEnt2(i, OwnerOffset),2)) == 1143){
			SentryLevelLimit--;
		}
		//PDQ
		if (GetWeaponIndex(GetPlayerWeaponSlot(GetEntDataEnt2(i, OwnerOffset),2)) == 3519){
			SentryLevelLimit--;
		}
		//Rush order
		if (GetWeaponIndex(GetPlayerWeaponSlot(GetEntDataEnt2(i, OwnerOffset),3)) == 3456){
			SentryLevelLimit = 1; //No negative numbers!
		}

		SentryLevel = GetEntData(i, LevelOffset)

		// If the level of the sentry is equal to the max level allowed on the owner's wrench, make it not upgradeable.
		if(SentryLevel == SentryLevelLimit){
			SetEntData(i, StopThatOffset, 1);
			SetEntData(i, StopThatOffset2, 1);
			continue;
		}

		// If the max level of the wrench is greater than what's allowed on the owner's wrench, set it to its max level, and make it not upgradable.
		if(SentryLevel > SentryLevelLimit){
			SetEntData(i, LevelOffset, SentryLevelLimit)
			SetEntData(i, StopThatOffset, 1);
			SetEntData(i, StopThatOffset2, 1);
			continue;
		}
	}

	for(int i=1;i<2048;i++){

		if(!IsValidEntity(i)){
			continue;
		}

		decl String:netclass[32];
		GetEntityNetClass(i, netclass, sizeof(netclass));

		if ( !strcmp(netclass, "CObjectDispenser") == false){
			continue;
		}

		DispenserLevelLimit = 3;
		bool Golden = GetWeaponIndex(GetPlayerWeaponSlot(GetEntDataEnt2(i, OwnerOffset),2)) == 4336;

		if (Golden){
			DispenserLevelLimit--;
		}

		if (GetWeaponIndex(GetPlayerWeaponSlot(GetEntDataEnt2(i, OwnerOffset),2)) == 1143){
			DispenserLevelLimit--;
		}

		if (GetWeaponIndex(GetPlayerWeaponSlot(GetEntDataEnt2(i, OwnerOffset),2)) == 3519){
			DispenserLevelLimit--;
		}

		if (GetWeaponIndex(GetPlayerWeaponSlot(GetEntDataEnt2(i, OwnerOffset),3)) == 3456){
			DispenserLevelLimit = 1; //No negative numbers!
		}

		DispenserLevel == GetEntData(i, LevelOffset)
		// If the level of the dispenser is equal the owner's wrench's maximum, make it not upgradable.
		if(DispenserLevel == DispenserLevelLimit){
			SetEntData(i, StopThatOffset2, 1);
			continue;
		}

		// If the max level of the wrench is greater than what's allowed on the owner's wrench, set it to its max level, and make it not upgradable.
		if(DispenserLevel > DispenserLevelLimit){
			SetEntData(i, LevelOffset, DispenserLevelLimit)
			SetEntData(i, StopThatOffset2, 1);
			continue;
		}
	}
	// No tele check, Might be making it so that teles ignore level decreases entirely, but for now we don't need to destroy them for being upgraded.
    // Also no jumppad check for obvious reasons.

    return Plugin_Continue;
}

public Action WeaponSwitch(client, weapon){
	//Safety Checks
	if(!IsClientInGame(client)){
		return Plugin_Continue;
	}
	if(TF2_GetPlayerClass(client)!=TFClass_Engineer){
		return Plugin_Continue;
	}
	if(!IsValidEntity(GetPlayerWeaponSlot(client,1))){
		return Plugin_Continue;
	}
	if(!IsValidEntity(GetPlayerWeaponSlot(client,3))){
		return Plugin_Continue;
	}
	if(!IsValidEntity(GetPlayerWeaponSlot(client,4))){
		return Plugin_Continue;
	}
	if(!IsValidEntity(weapon)){
		return Plugin_Continue;
	}

	//if the building pda is opened
	//Switches some buildings to sappers so the game doesn't count them as engie buildings
	if(GetPlayerWeaponSlot(client,3)==weapon){
		function_AllowBuilding(client);
		return Plugin_Continue;
	}//else if the client is not holding the building tool
	else if(GetEntProp(weapon,Prop_Send,"m_iItemDefinitionIndex")!=28){
		function_AllowDestroying(client);
		return Plugin_Continue;
	}
	return Plugin_Continue;

}

// Stocks (Stolen lmao, I don't know sourcepawn.)

stock bool:IsValidEnt(iEnt)
{
    return iEnt > MaxClients && IsValidEntity(iEnt);
}

stock GetWeaponIndex(iWeapon)
{
    return IsValidEnt(iWeapon) ? GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"):-1;
}

public Action Command_destroy_dispensers(int client, int args){

	for(int i=1;i<2048;i++){

		if(!IsValidEntity(i)){
			continue;
		}

		decl String:netclass[32];
		GetEntityNetClass(i, netclass, sizeof(netclass));

		if ( !strcmp(netclass, "CObjectDispenser") == false){
			continue;
		}

		if(GetEntDataEnt2(i, OwnerOffset)!=client){
			continue;
		}
		SetVariantInt(9999);
		AcceptEntityInput(i,"RemoveHealth");
	}

	return Plugin_Handled;


}

public Action Command_destroy_sentries(int client, int args){

	for(int i=1;i<2048;i++){

		if(!IsValidEntity(i)){
			continue;
		}

		decl String:netclass[32];
		GetEntityNetClass(i, netclass, sizeof(netclass));

		if ( !(strcmp(netclass, "CObjectSentrygun") == 0) ){
			continue;
		}

		if(GetEntDataEnt2(i, OwnerOffset)!=client){
			continue;
		}
		SetVariantInt(9999);
		AcceptEntityInput(i,"RemoveHealth");
	}

	return Plugin_Handled;

}

public void function_AllowBuilding(int client){

	int DispenserLimit = GetConVarInt(sm_dispenser_limit);
	int SentryLimit = GetConVarInt(sm_sentry_limit);
	int JumppadLimit = GetConVarInt(sm_jumppad_limit);

	//Golden wrench
	bool extraSentry = GetWeaponIndex(GetPlayerWeaponSlot(client,2)) == 4336; //Hard coding this because IDC.
	if (extraSentry){
		SentryLimit++;
	}

	bool extraDispenser = GetWeaponIndex(GetPlayerWeaponSlot(client,2)) == 4336;
	if (extraDispenser){
		DispenserLimit++;
	}
	
	// Eureka Effect
	bool extraJumppad = GetWeaponIndex(GetPlayerWeaponSlot(client,2)) == 3386;
	if (extraJumppad){
		JumppadLimit++;
	}

	// Unusual golden
	if (GetWeaponIndex(GetPlayerWeaponSlot(client,2)) == 4337){
		SentryLimit += 100;
		DispenserLimit += 100;
		JumppadLimit += 100;
	}

	int DispenserCount = 0;
	int SentryCount = 0;
	int JumppadCount = 0;
	bool singlejump = true;

	for(int i=0;i<2048;i++){

		if(!IsValidEntity(i)){
			continue;
		}
		
		decl String:netclass[32];
		GetEntityNetClass(i, netclass, sizeof(netclass));

		if ( !((strcmp(netclass, "CObjectSentrygun") == 0 || strcmp(netclass, "CObjectDispenser") == 0) || strcmp(netclass, "CObjectJumppad") == 0)) {
			continue;
		}

		if(GetEntDataEnt2(i, OwnerOffset)!=client){
			continue;
		}


		int type=view_as<int>(function_GetBuildingType(i));

		//Switching the dispenser to a sapper type
		if(type==view_as<int>(TFObject_Dispenser)){
			DispenserCount=DispenserCount+1;
			SetEntProp(i, Prop_Send, "m_iObjectType", TFObject_Sapper);
			if(DispenserCount>=DispenserLimit){
				//if the limit is reached, disallow building
				SetEntProp(i, Prop_Send, "m_iObjectType", type)
			}
		//not a dispenser, is this a sentry?
		}else if(type==view_as<int>(TFObject_Sentry)){
			SentryCount++;
			SetEntProp(i, Prop_Send, "m_iObjectType", TFObject_Sapper);
			if(SentryCount>=SentryLimit){
				//if the limit is reached, disallow building
				SetEntProp(i, Prop_Send, "m_iObjectType", type);
			}
		//Then it's a jumppad. (Good, cause we can't check for that here for some reason!)
		}else{
			JumppadCount++;
//			if(singlejump){
//				//apply correct for first one found
//				SetEntProp(i, Prop_Send, "m_iObjectType", type);
//				singlejump = false;
//				continue;
//			}
//			if(JumppadCount<JumppadLimit){
//				//if the limit is reached, disallow building
//				PrintToServer("Goaheadgiven")
//				SetEntProp(i, Prop_Send, "m_iObjectType", TFObject_Sapper);
//			}
//			else{
//				//if the limit is reached, disallow building
//				PrintToServer("stopped?")
//				SetEntProp(i, Prop_Send, "m_iObjectType", type);
//			}
		}
	//every building is in the desired state
	}
	//Jumppad (and maybe teles later if i'm feeling really dumb that day) integration.
	if(JumppadCount < JumppadLimit){
		for(int i=0;i<2048;i++){

			if(!IsValidEntity(i)){
				continue;
			}
		
			decl String:netclass[32];
			GetEntityNetClass(i, netclass, sizeof(netclass));

			if ( !(strcmp(netclass, "CObjectJumppad") == 0)) {
				continue;
			}

			if(GetEntDataEnt2(i, OwnerOffset)!=client){
				continue;
			}

			if(singlejump){
				//do not swap the first one found, otherwise players could stack all their jumppads on the same slot to get an extra one. (VERY BAD)
				singlejump = false;
				continue;
			}
			else{
				//otherwise go nuts, we already validity in the OG if statement.
//				PrintToServer("Goaheadgiven")
				SetEntProp(i, Prop_Send, "m_iObjectType", TFObject_Sapper);
			}		
		}
	}
}
public void function_AllowDestroying(int client){
	int jumpnum = 0;
	int jumpref1 = 0;
	int jumpref1id = 0;
	int jumpref2 = 0;
	int jumpref2id = 0;
//	int failsafe = 0;   //Defined at start
	int jumpref3id = 0;
	for(int i=1;i<2048;i++){

		if(!IsValidEntity(i)){
			continue;
		}

		decl String:netclass[32];
		GetEntityNetClass(i, netclass, sizeof(netclass));

		if ( !(strcmp(netclass, "CObjectSentrygun") == 0 || strcmp(netclass, "CObjectDispenser") == 0 || strcmp(netclass, "CObjectJumppad") == 0)){
			continue;
		}

		if(GetEntDataEnt2(i, OwnerOffset)!=client){
			continue;
		}

//		if(!((GetEntData(i, TypeTestOffset) == 3) || (GetEntData(i, TypeTestOffset) == 4))){
//			PrintToServer("other ticked")
//			SetEntProp(i, Prop_Send, "m_iObjectType", function_GetBuildingType(i));
//			if (strcmp(netclass, "CObjectSentrygun") == 0){
//				PrintToServer("bentry")
//				SetEntProp(i, Prop_Send, "m_iObjectType", TFObject_Sentry);
//			}
//			else{
//				PrintToServer("spenser")
//				SetEntProp(i, Prop_Send, "m_iObjectType", TFObject_Dispenser);
//			}
//		}
		// Hacky seperation to prevent jumppads from setting themselves to be dispensers.... somehow.
		// TO DO: UNHARDCODE THIS DISASTER!
		if((GetWeaponIndex(GetPlayerWeaponSlot(GetEntDataEnt2(i, OwnerOffset), 2)) == 3386)){
//			PrintToServer("jumppad ticked")
			if(jumpnum == 0){
				jumpnum = 1;
				jumpref1id = i;
				jumpref1 = GetEntData(i, TypeTestOffset)
			}
			else if(jumpnum == 1){
				jumpnum = 2;
				jumpref2id = i;
				jumpref2 = GetEntData(i, TypeTestOffset)
			}
			else{
				jumpnum = 3;
				jumpref3id = i
			}
			continue;
		}
		else if (!(strcmp(netclass, "CObjectJumppad") == 0)){
			// Yet another hack fix. It's almost like I shouldn't be doing this.
			// Dispsenser values for this are always several millions, while sentries are always 3 or below. Easy thing to check.
			// (sadly I don't know if I could include jumppads with these two, I don't know of any unique values to them, and I can't exactly dig around in their code.)
			// (Teleporters.... maybe. If I could find way to make two entrances, that could potentially be useful. Don't count on it though.)
			if (GetEntData(i, IsCheck) < 4){
				SetEntProp(i, Prop_Send, "m_iObjectType", TFObject_Sentry);
			}
			else{
				SetEntProp(i, Prop_Send, "m_iObjectType", TFObject_Dispenser);
			}
		}
	}
	// Stops buildings from forgetting they are jumppads... I guess. If I remove this code it doesn't work. Also, no, for some reason I CAN'T just sub in 4... (As far as I can tell anyways)
	if(jumpnum == 1){
		if (((jumpref1 != failsafe)&&(jumpref1 != failsafe))&&(failsafe!=0)){
			SetEntProp(jumpref1id, Prop_Send, "m_iObjectType", failsafe)
		}
	}
	if(jumpnum == 2){
		if(failsafe == 0){
			//Im going to implode.
			failsafe = jumpref1
			failsafe2 = jumpref2
		}
		if ((jumpref1 != 4)&&(failsafe != 0)){
			SetEntProp(jumpref1id, Prop_Send, "m_iObjectType", failsafe)
		}
		if ((jumpref2 != 4)&&(failsafe != 0)){
			SetEntProp(jumpref2id, Prop_Send, "m_iObjectType", failsafe2)
		}
		// Doesn't sodding work cause I can't find what ACTUALLY differentiates them.
		if (jumpref1 == jumpref2){
			SetEntProp(jumpref1id, Prop_Send, "m_iObjectType", failsafe);
			SetEntProp(jumpref2id, Prop_Send, "m_iObjectType", failsafe2);
		}
	}
	if(jumpnum == 3){
		// Shouldn't need to do this, but for some reason I do so here we go.
		SetEntProp(jumpref1id, Prop_Send, "m_iObjectType", failsafe)
		SetEntProp(jumpref2id, Prop_Send, "m_iObjectType", failsafe2)
		// Set the final teleporter to be the same as the first.
		SetEntProp(jumpref3id, Prop_Send, "m_iObjectType", jumpref1)
	}
}

public TFObjectType function_GetBuildingType(int entIndex){
	//This function relies on Netclass rather than building type since building type
	//gets changed
	decl String:netclass[32];
	GetEntityNetClass(entIndex, netclass, sizeof(netclass));

	if(strcmp(netclass, "CObjectSentrygun") == 0){
		return TFObject_Sentry;
	}
	if(strcmp(netclass, "CObjectDispenser") == 0){
		return TFObject_Dispenser;
	}
	if(strcmp(netclass, "CObjectTeleporter") == 0){
		return TFObject_Teleporter;
	}
	if(strcmp(netclass, "CObjectJumppad") == 0){
		return 69; //Intentionally useless output, I don't believe there is a TFObject version of it.
	}

	return TFObject_Sapper;
}

// When the client changes their weapons, Their buildings need to adapt with them, so that you can't "smuggle" a higher level building, or worse, MULTIPLE BUILDINGS.
public Action:EventInventory(Event:event, const String:name[], bool dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))

	new TFClassType:class = TF2_GetPlayerClass(client);
	if(class != TFClass_Engineer) // If this isn't engineer, we don't care. Skip.
	{
		return Plugin_Continue;
	}

	int DispenserLimit = GetConVarInt(sm_dispenser_limit);
	int SentryLimit = GetConVarInt(sm_sentry_limit);
	int JumppadLimit = GetConVarInt(sm_jumppad_limit);
	int DispenserLevelLimit = 3;
	int SentryLevelLimit = 3;
	bool Golden = GetWeaponIndex(GetPlayerWeaponSlot(client,2)) == 4336;

	if (Golden){
		SentryLimit++;
		DispenserLimit++;
		DispenserLevelLimit--;
		SentryLevelLimit--;
	}

	if (GetWeaponIndex(GetPlayerWeaponSlot(client,2)) == 1143){
		DispenserLevelLimit--;
		SentryLevelLimit--;
	}

	if (GetWeaponIndex(GetPlayerWeaponSlot(client,2)) == 3519){
		DispenserLevelLimit--;
		SentryLevelLimit--;
	}

	if (GetWeaponIndex(GetPlayerWeaponSlot(client,2)) == 3519){
		DispenserLevelLimit--;
		SentryLevelLimit--;
	}

	//Eureka Effect
	if (GetWeaponIndex(GetPlayerWeaponSlot(client,2)) == 3386){
		JumppadLimit++;
	}

	// Unusual golden
	if (GetWeaponIndex(GetPlayerWeaponSlot(client,2)) == 4337){
		SentryLimit += 100;
		DispenserLimit += 100;
		JumppadLimit += 100;
	}

	int DispenserCount = 0;
	int SentryCount = 0;
	int JumppadCount = 0;
	int SentryLevel = 1;
	int DispenserLevel = 1;

	
	// Find sentries this player owns, if there's more than your current cap, destroy them.
    for(int i=1;i<2048;i++){

		if(!IsValidEntity(i)){
			continue;
		}

		decl String:netclass[32];
		GetEntityNetClass(i, netclass, sizeof(netclass));

		if ( !(strcmp(netclass, "CObjectSentrygun") == 0) ){
			continue;
		}

		if(GetEntDataEnt2(i, OwnerOffset)!=client){
			continue;
		}

		SentryLevel = GetEntData(i, LevelOffset)

		// If the level of the sentry is greater than what's allowed, (or they're using the jiggy walker, in which case this check always succeeds) destroy it.
		if(SentryLevel > SentryLevelLimit || GetWeaponIndex(GetPlayerWeaponSlot(client,3)) == 5255){
			SetVariantInt(9999);
			AcceptEntityInput(i,"RemoveHealth");
			continue;
		}

		// If the level of the sentry is equal to the max level allowed, make it not upgradeable.
		if(SentryLevel == SentryLevelLimit){
			SetEntData(i, StopThatOffset, 1);
			SetEntData(i, StopThatOffset2, 1);
			continue;
		}

		// If we've already accounted for all of the sentries alive that the wrench can support, kill this one.
		if(SentryCount >= SentryLimit){
			SetVariantInt(9999);
			AcceptEntityInput(i,"RemoveHealth");
			continue;
		}
		else{
			SentryCount++
		}
	}

	// Find dispensers this player owns, if there's more than your current cap, destroy them.
	for(int i=1;i<2048;i++){

		if(!IsValidEntity(i)){
			continue;
		}

		decl String:netclass[32];
		GetEntityNetClass(i, netclass, sizeof(netclass));

		if ( !strcmp(netclass, "CObjectDispenser") == false){
			continue;
		}

		if(GetEntDataEnt2(i, OwnerOffset)!=client){
			continue;
		}

		DispenserLevel = GetEntData(i, LevelOffset)

		// If the level of the dispenser is greater than what's allowed, (or you're using the jiggy walker, in which case this check always succeeds) destroy it.
		if(DispenserLevel > DispenserLevelLimit || GetWeaponIndex(GetPlayerWeaponSlot(client,3)) == 5255){
			SetVariantInt(9999);
			AcceptEntityInput(i,"RemoveHealth");
			continue;
		}

		// If the level of the dispenser is equal to the max, prevent upgrading it.
		if(DispenserLevel == DispenserLevelLimit){
			SetEntData(i, StopThatOffset2, 1);
		}

		// If we've already accounted for all of the dispensers alive that the wrench can support, kill this one.
		if(DispenserCount >= DispenserLimit){
			SetVariantInt(9999);
			AcceptEntityInput(i,"RemoveHealth");
			continue;
		}

		else{
			DispenserCount++
		}
	}

	DispenserCount = -1
	
	//Lazily slapped together teleporter integration
	for(int i=1;i<2048;i++){

		if(!IsValidEntity(i)){
			continue;
		}

		decl String:netclass[32];
		GetEntityNetClass(i, netclass, sizeof(netclass));

		if ( !strcmp(netclass, "CObjectTeleporter") == false){
			continue;
		}

		if(GetEntDataEnt2(i, OwnerOffset)!=client){
			continue;
		}

		// Using same variables as dispsenser cause I lazy.

		DispenserLevel = GetEntData(i, LevelOffset)

		// If the level of the dispenser is greater than what's allowed, (or you're using the jiggy walker, in which case this check always succeeds) destroy it.
		if(DispenserLevel > DispenserLevelLimit || GetWeaponIndex(GetPlayerWeaponSlot(client,3)) == 5255){
			SetVariantInt(9999);
			AcceptEntityInput(i,"RemoveHealth");
			continue;
		}

		// If the level of the dispenser is equal to the max, prevent upgrading it.
		if(DispenserLevel == DispenserLevelLimit){
			SetEntData(i, StopThatOffset2, 1);
		}

		if(DispenserCount >= DispenserLimit){
			SetVariantInt(9999);
			AcceptEntityInput(i,"RemoveHealth");
			continue;
		}

		else{
			DispenserCount++
		}
	}

	// Jumppad integration (Yes, these are seperate.... kind of.)
	for(int i=1;i<2048;i++){

		if(!IsValidEntity(i)){
			continue;
		}

		decl String:netclass[32];
		GetEntityNetClass(i, netclass, sizeof(netclass));

		if ( !strcmp(netclass, "CObjectJumppad") == false){
			continue;
		}

		if(GetEntDataEnt2(i, OwnerOffset)!=client){
			continue;
		}

//		JumppadLevel = GetEntData(i, LevelOffset) // What level?

		JumppadCount++
	}
	
	// If we've accounted for more jumpads alive that the wrench can support, KILL ALL OF THEM. This will prevent stacking jumppads to smuggle them, and is also a fair punishment for trying to game my system, you cheeky bugger.
	// Could just save the indexes from before, but I am lazy, and this will only be run like, at most once a match, so I don't care much for optimizing this.
	if(JumppadCount > JumppadLimit){
		for(int i=1;i<2048;i++){

			if(!IsValidEntity(i)){
				continue;
			}

			decl String:netclass[32];
			GetEntityNetClass(i, netclass, sizeof(netclass));

			if ( !strcmp(netclass, "CObjectJumppad") == false){
				continue;
			}

			if(GetEntDataEnt2(i, OwnerOffset)!=client){
				continue;
			}

			SetVariantInt(9999);
			AcceptEntityInput(i,"RemoveHealth");
			continue;
		}
	}
    return Plugin_Continue;
}