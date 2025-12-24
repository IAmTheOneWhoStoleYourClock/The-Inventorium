#include <sourcemod>
#include <sdktools>
#include <tf2c>
#include <clients>
#include <sdkhooks>
// #include <clocksbasics>

int OwnerOffset;
int LevelOffset;
int LevelCapOffset;
int TypeTestOffset;
int HealthCapOffset;
int HealthOffset;
int IsCheck;
int JumppadSlot;
int Buildprogress;
ConVar sm_dispenser_limit;
ConVar sm_sentry_limit;
ConVar sm_jumppad_limit;
ConVar sm_instant_upgrade;
ConVar sm_enforce_level_limit;
ConVar sm_lax_level_limit;
ConVar sm_enforce_health_limit;
ConVar sm_lax_health_limit;
ConVar sm_enforce_building_limit;
int SentrygunBaseHealth[3] = {150, 180, 216}

public Plugin myinfo ={
	name = "The Co-opted Multiple Buildings Plugin",
	author = "shewowkees, IAmTheOneWhoStoleYourClock",
	description = "shewowkees OG multi building plugin, repurposed into my general building plugin.",
	version = "1.2",
	url = "https://github.com/IAmTheOneWhoStoleYourClock/The-Inventorium"
};

public void OnPluginStart(){

	sm_dispenser_limit = CreateConVar("sm_dispenser_limit", "1", "Self explanatory, setting below default will have unexpected results.");
	sm_sentry_limit = CreateConVar("sm_sentry_limit", "1", "Self explanatory, setting below default will have unexpected results.");
	sm_jumppad_limit = CreateConVar("sm_jumppad_limit", "2", "Self explanatory, setting below default will have unexpected results.");
	sm_instant_upgrade = CreateConVar("sm_instant_upgrade","0", "Please don't actually use this, I don't think it works in TF2C but I kept it from the OG plugin just incase.");
	sm_enforce_level_limit = CreateConVar("sm_enforce_level_limit", "1", "True/False. Whether or not buildings should lower their max level in accordance with the user.");
	sm_lax_level_limit = CreateConVar("sm_lax_level_limit", "1", "True/False. Whether or not buildings should raise their max level in accordance with the user.");
	sm_enforce_health_limit = CreateConVar("sm_enforce_health_limit", "1", "True/False. Whether or not buildings should lower their max health in accordance with the user. Note that they will still adjust after an upgrade.");
	sm_lax_health_limit = CreateConVar("sm_lax_health_limit", "0", "True/False. Whether or not buildings should raise their max health in accordance with the user. Note that they will still adjust after an upgrade.");
	sm_enforce_building_limit = CreateConVar("sm_enforce_building_limit", "1", "True/False. Whether or not additional buildings should be destroyed in accordance with the user.");

	HookEvent("player_builtobject",Evt_BuiltObject,EventHookMode_Pre);
	HookEvent("post_inventory_application",EventInventory,EventHookMode_Post);

	RegConsoleCmd("sm_destroy_dispensers", Command_destroy_dispensers);
	RegConsoleCmd("sm_destroy_sentries", Command_destroy_sentries);
	RegConsoleCmd("sm_destroy_jumppads", Command_destroy_jumppads);

	OwnerOffset = FindSendPropInfo("CBaseObject", "m_hBuilder");
	LevelOffset = FindSendPropInfo("CBaseObject", "m_iUpgradeLevel"); // Found these in the SDK. Everything that I need to work works. (Thank goodness Valve never actually fixes their messes and the TF2C never saw a need to change these.)
	LevelCapOffset = FindSendPropInfo("CBaseObject", "m_iHighestUpgradeLevel"); // Goes mostly unused in base TF2. Mini's use a different system entirely for some reason. Odd.
	TypeTestOffset = FindSendPropInfo("CBaseObject", "m_iObjectType");
	HealthCapOffset = FindSendPropInfo("CBaseObject", "m_iMaxHealth");
	HealthOffset = FindSendPropInfo("CBaseObject", "m_iHealth");
	IsCheck = FindSendPropInfo("CObjectSentrygun", "m_iState");
	JumppadSlot = FindSendPropInfo("CObjectJumppad", "m_iObjectMode");

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
		SDKHookEx(client, SDKHook_WeaponSwitch, WeaponSwitch);
	}
}

public void OnClientPostAdminCheck(client){
    SDKHookEx(client, SDKHook_WeaponSwitch, WeaponSwitch);
}
public Action Evt_BuiltObject(Event event, const char[] name, bool dontBroadcast){
	int ObjIndex = event .GetInt("index");
	int owner = GetClientOfUserId(GetEventInt(event, "userid"));

	if(GetConVarInt(sm_instant_upgrade)>0){

		SetEntProp(ObjIndex, Prop_Send, "m_iUpgradeMetal", 600);
		SetEntProp(ObjIndex, Prop_Send,"m_iUpgradeMetalRequired",0);
	}

	decl String:netclass[32];
	GetEntityNetClass(ObjIndex, netclass, sizeof(netclass));

	if (strcmp(netclass, "CObjectJumppad") == 0){
		bool weakpads = GetWeaponIndex(GetPlayerWeaponSlot(owner,3)) == 4403;
		if (weakpads){
			SetEntData(ObjIndex, HealthCapOffset, 45);
		}
	}

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
	if(!IsValidEntity(weapon)){
		return Plugin_Continue;
	}
	// The other checks were unnessesary, but this one probably is important... -Clock
	if(!IsValidEntity(GetPlayerWeaponSlot(client,3))){
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

stock bool:IsValidBuilding(char netclass[32]) //Sick of having to define this constantly so this is just a function now
{
    return strcmp(netclass, "CObjectSentrygun") == 0 || strcmp(netclass, "CObjectDispenser") == 0 || strcmp(netclass, "CObjectJumppad") == 0
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

public Action Command_destroy_jumppads(int client, int args){

	for(int i=1;i<2048;i++){

		if(!IsValidEntity(i)){
			continue;
		}

		decl String:netclass[32];
		GetEntityNetClass(i, netclass, sizeof(netclass));

		if ( !(strcmp(netclass, "CObjectJumppad") == 0) ){
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

	for(int i=1;i<2048;i++){

		if(!IsValidEntity(i)){
			continue;
		}

		decl String:netclass[32];
		GetEntityNetClass(i, netclass, sizeof(netclass));
		
		if (!IsValidBuilding(netclass)) {
			continue;
		}

		if(GetEntDataEnt2(i, OwnerOffset)!=client){
			continue;
		}

		int type=view_as<int>(function_GetBuildingType(i));

		//Switching the dispenser to a sapper type
		if(type==view_as<int>(TFObject_Dispenser)){
			DispenserCount++;
			if(DispenserCount>DispenserLimit){
				//if the limit is reached, disallow building
				SetEntProp(i, Prop_Send, "m_iObjectType", type)
			}
			else{
				SetEntProp(i, Prop_Send, "m_iObjectType", TFObject_Sapper);
			}
		//not a dispenser, is this a sentry?
		}else if(type==view_as<int>(TFObject_Sentry)){
			SentryCount++;
			if(SentryCount>SentryLimit){
				//if the limit is reached, disallow building
				SetEntProp(i, Prop_Send, "m_iObjectType", type);
			}
			else{
				SetEntProp(i, Prop_Send, "m_iObjectType", TFObject_Sapper);
			}
		//Then it's a jumppad. (Good, cause we can't check for that here for some reason!)
		}else if(extraJumppad){
			JumppadCount++;
		}
	//every building is in the desired state
	}
	//Jumppad (and maybe teles later if i'm feeling really dumb that day) integration.
	if((JumppadCount < JumppadLimit) && extraJumppad){
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
				//otherwise go nuts, we already checked validity in the OG if statement.
				SetEntProp(i, Prop_Send, "m_iObjectType", TFObject_Sapper);
			}		
		}
	}
}
int bongle = 0;
public void function_AllowDestroying(int client){
	int jumpnum = 0;
	int jumpref1 = 0;
//	int jumpref1id = 0;
	int jumpref2 = 0;
	int jumpref2id = 0;
//	int jumpref3id = 0;
	for(int i=1;i<2048;i++){

		if(!IsValidEntity(i)){
			continue;
		}

		decl String:netclass[32];
		GetEntityNetClass(i, netclass, sizeof(netclass));

		if (!IsValidBuilding(netclass)){
			continue;
		}

		if(GetEntDataEnt2(i, OwnerOffset)!=client){
			continue;
		}
		// TO DO: UNHARDCODE THIS DISASTER!
		if (!(strcmp(netclass, "CObjectJumppad") == 0)){
			// Yet another hack fix. It's almost like I shouldn't be doing this.
			// Dispsenser values for this are always several millions (positive or negative), while sentries range from 3 to 0. Easy thing to check.
			// (sadly I don't know if I could include jumppads with these two, I don't know of any unique values to them, and I can't exactly dig around in their code.)
			// (Teleporters.... maybe. If I could find way to make two entrances, that could potentially be useful. Don't count on it though.)
			bongle = GetEntData(i, IsCheck);
			if ((bongle < 3) && (bongle > -1)){
				SetEntProp(i, Prop_Send, "m_iObjectType", TFObject_Sentry);
			}
			else{
				SetEntProp(i, Prop_Send, "m_iObjectType", TFObject_Dispenser);
			}
		}
		else if((GetWeaponIndex(GetPlayerWeaponSlot(GetEntDataEnt2(i, OwnerOffset), 2)) == 3386)){ // Geniunely don't even run this code if we don't have extra jumppads. It's better now, but I would still rather not.
			jumpnum++;
			if(jumpnum == 1){
				jumpref1 = GetEntData(i, JumppadSlot);
			}
			else if(jumpnum == 2){
				jumpref2id = i;
				jumpref2 = GetEntData(i, JumppadSlot);
			}
			SetEntProp(i, Prop_Send, "m_iObjectType", 4);
			continue;
		}
	}
	// AT LAST, JUMPPAD INTEGRATION THAT DOESN'T JUST SUCK! 
	if(jumpnum == 2 && jumpref1 == jumpref2){
		if (jumpref1){
			SetEntProp(jumpref2id, Prop_Send, "m_iObjectMode", 0)
		}
		else{
			SetEntProp(jumpref2id, Prop_Send, "m_iObjectMode", 1)
		}
	}
}

public TFObjectType function_GetBuildingType(int entIndex){
	// This function relies on Netclass rather than building type since building type
	// gets changed
	decl String:netclass[32];
	GetEntityNetClass(entIndex, netclass, sizeof(netclass));
	if(strcmp(netclass, "CObjectSentrygun") == 0)
	{
		return TFObject_Sentry;
	}
	else if(strcmp(netclass, "CObjectDispenser") == 0)
	{
		return TFObject_Dispenser;
	}
	else if(strcmp(netclass, "CObjectTeleporter") == 0)
	{
		return TFObject_Teleporter;
	}
	else if(strcmp(netclass, "CObjectJumppad") == 0)
	{
		return 4; // Works for some functions? Try to avoid this unless you know it works. Ignore the warning this makes.
	}
	else if(strcmp(netclass, "CObjectSapper") == 0) //This should never happen under normal operation, but it is unlikely to cause issue.
	{
		return TFObject_Sapper;
	}
	else
  	{
		ThrowError("Tried to check something that is NOT a building with GetBuildingType");
		return TFObject_Sapper;
	}
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
	int Jumppadhealth = 90;
	float Buildinghealthmult = 1.00;

	bool Golden = GetWeaponIndex(GetPlayerWeaponSlot(client,2)) == 4336;

	if (Golden){
		SentryLimit++;
		DispenserLimit++;
		DispenserLevelLimit--;
		SentryLevelLimit--;
		Buildinghealthmult = 0.67;
	}
	else if (GetWeaponIndex(GetPlayerWeaponSlot(client,2)) == 1143){
		DispenserLevelLimit--;
		SentryLevelLimit--;
		Buildinghealthmult = 0.5;
	}
	else if (GetWeaponIndex(GetPlayerWeaponSlot(client,2)) == 4437){
		Buildinghealthmult = 1.2;
	}
	else if (GetWeaponIndex(GetPlayerWeaponSlot(client,2)) == 3519){
		DispenserLevelLimit--;
		SentryLevelLimit--;
		Buildinghealthmult = 0.65;
	}
	else if (GetWeaponIndex(GetPlayerWeaponSlot(client,2)) == 3386){
		JumppadLimit++;
	}
	else if (GetWeaponIndex(GetPlayerWeaponSlot(client,2)) == 4337){
		SentryLimit += 100;
		DispenserLimit += 100;
		JumppadLimit += 100;
	}

	if (GetWeaponIndex(GetPlayerWeaponSlot(client,3)) == 4403){
		Jumppadhealth = 45;
	}

	int SentryCount = 0;
	int DispenserCount = 0;
	int JumppadCount = 0;
	int BuildingCount = 0;
	int BuildingMaxLevel = 1;
	int BuildingMaxCount = 1;
	int BuildingLevel = 1;
	int BuildingTargetHealthCap = 0;
	int CurrentLevelCap;

    for(int i=1;i<2048;i++){

		if(!IsValidEntity(i)){
			continue;
		}

		decl String:netclass[32];
		GetEntityNetClass(i, netclass, sizeof(netclass));

		if (!IsValidBuilding(netclass)){
			continue;
		}

		if(GetEntDataEnt2(i, OwnerOffset)!=client){
			continue;
		}

		BuildingLevel = GetEntData(i, LevelOffset) - 1;
		// I HATE doing this kind of nonsense, but I can't think of any other way rn...
		if(strcmp(netclass, "CObjectSentrygun") == 0)
		{
			BuildingMaxLevel = SentryLevelLimit;
			BuildingMaxCount = SentryLimit;
			BuildingCount = SentryCount;
			BuildingTargetHealthCap += RoundToNearest(SentrygunBaseHealth[BuildingLevel] * Buildinghealthmult);
			SentryCount++
		}
		else if(strcmp(netclass, "CObjectDispenser") == 0)
		{
			BuildingMaxLevel = DispenserLevelLimit;
			BuildingMaxCount = DispenserLimit;
			BuildingCount = DispenserCount;
			BuildingTargetHealthCap += RoundToNearest(SentrygunBaseHealth[BuildingLevel] * Buildinghealthmult); //Exactly the same. What a finely crafted game.
			DispenserCount++
		}
		else if(strcmp(netclass, "CObjectJumppad") == 0)
		{
			BuildingMaxLevel = 1; //Literally what else could it be
			BuildingMaxCount = JumppadLimit;
			BuildingCount = JumppadCount;
			BuildingTargetHealthCap += RoundToNearest(Jumppadhealth * Buildinghealthmult);
			JumppadCount++
		}
		else if(strcmp(netclass, "CObjectTeleporter") == 0)
		{
			BuildingMaxLevel = 3; // Don't even bother I really don't care
			BuildingMaxCount = 2;
			BuildingCount = 0; // Not allowed to have more than the base max anyways.
			BuildingTargetHealthCap += RoundToNearest(SentrygunBaseHealth[BuildingLevel] * Buildinghealthmult);
		}

		// If the level of the sentry is greater than what's allowed, (or they're using the jiggy walker, in which case this check always succeeds) destroy it.
		if(BuildingLevel > BuildingMaxLevel || GetWeaponIndex(GetPlayerWeaponSlot(client,3)) == 5255){
			SetVariantInt(9999);
			AcceptEntityInput(i,"RemoveHealth");
			continue;
		}

		int CurrentMaxHealth = GetEntDataEnt(i, HealthCapOffset);

		if ((CurrentMaxHealth > BuildingTargetHealthCap && GetConVarBool(sm_enforce_health_limit)) || (CurrentMaxHealth < BuildingTargetHealthCap && GetConVarBool(sm_lax_health_limit))){
			if ((GetEntDataEnt(i, HealthOffset) > BuildingTargetHealthCap)){
				SetEntData(i, HealthOffset, BuildingTargetHealthCap);
			}
			PrintToServer("set");
			SetEntData(i, HealthCapOffset, BuildingTargetHealthCap);
		}

		// Set the buildings max level to the user's max level
		CurrentLevelCap = GetEntDataEnt2(i, LevelCapOffset);
		if((GetConVarBool(sm_enforce_level_limit) && (CurrentLevelCap > BuildingMaxLevel)) || (GetConVarBool(sm_lax_level_limit) != 0 && (CurrentLevelCap < BuildingMaxLevel))){
			SetEntData(i, LevelCapOffset, BuildingMaxLevel);
		}


		// If we've already accounted for all of the buildings alive that the user can support, kill this one.
		if((BuildingCount >= BuildingMaxCount) && sm_enforce_building_limit){
			SetVariantInt(9999);
			AcceptEntityInput(i,"RemoveHealth");
			continue;
		}
	}
    return Plugin_Continue;
}