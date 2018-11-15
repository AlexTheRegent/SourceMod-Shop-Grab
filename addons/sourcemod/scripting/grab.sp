// ==============================================================================================================================
// >>> GLOBAL INCLUDES
// ==============================================================================================================================
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <emitsoundany>
#include <multicolors>
#include <shop>

// #define DEBUG

// ==============================================================================================================================
// >>> PLUGIN INFORMATION
// ==============================================================================================================================
#define PLUGIN_VERSION "1.0b"
public Plugin myinfo =
{
	name 			= "[Shop] Grab",
	author 			= "AlexTheRegent",
	description 	= "",
	version 		= PLUGIN_VERSION,
	url 			= ""
}

// ==============================================================================================================================
// >>> DEFINES
// ==============================================================================================================================
#pragma newdecls required
#define MPS 		MAXPLAYERS+1
#define PMP 		PLATFORM_MAX_PATH
#define MTF 		MENU_TIME_FOREVER
#define CID(%0) 	GetClientOfUserId(%0)
#define UID(%0) 	GetClientUserId(%0)
#define SZF(%0) 	%0, sizeof(%0)
#define LC(%0) 		for (int %0 = 1; %0 <= MaxClients; ++%0) if ( IsClientInGame(%0) ) 

// ==============================================================================================================================
// >>> CONSOLE VARIABLES
// ==============================================================================================================================


// ==============================================================================================================================
// >>> GLOBAL VARIABLES
// ==============================================================================================================================
Handle		g_search_timer[MPS];
Handle		g_grab_timer[MPS];

char 		g_material[MPS][PMP];
char 		g_sound_start[MPS][PMP];
char 		g_sound_hold[MPS][PMP];
char 		g_sound_end[MPS][PMP];
char 		g_color[MPS][16];
char 		g_alpha[MPS][8];

float 		g_move_speed[MPS];
float 		g_distance[MPS];
float 		g_gravity[MPS];

float 		g_beam_start_size[MPS];
float 		g_beam_end_size[MPS];
float 		g_max_distance[MPS];
float 		g_min_distance[MPS];
float 		g_duration[MPS];
float 		g_cooldown[MPS];
float 		g_use_time[MPS];
float 		g_speed[MPS];

bool 		g_access[MPS];

int 		g_target[MPS];
// int 		g_beam_start[MPS];
// int 		g_beam_end[MPS];
int 		g_beam[MPS];

int 		g_max_uses[MPS];
int 		g_uses[MPS];
int 		g_team[MPS];

// ==============================================================================================================================
// >>> LOCAL INCLUDES
// ==============================================================================================================================


// ==============================================================================================================================
// >>> FORWARDS
// ==============================================================================================================================
public void OnPluginStart() 
{
	LoadTranslations("grab.phrases.txt");
	
	#if defined DEBUG
	RegAdminCmd("sm_grab_test", Command_GrabTest, ADMFLAG_ROOT);
	#endif
	
	RegConsoleCmd("sm_grab", Command_Grab);
	HookEvent("round_start", Ev_RoundStart);
	
	LC(i) {
		OnClientPutInServer(i);
	}
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public void OnMapStart() 
{
	#if defined DEBUG
	PrecacheModel("materials/sprites/laserbeam.vmt");
	#endif
	
	if ( Shop_IsStarted() ) Shop_Started();
}

public int Shop_Started()
{
	char name[64], description[128];
	FormatEx(SZF(name), "%T", "grab category name", LANG_SERVER);
	FormatEx(SZF(description), "%T", "grab category description", LANG_SERVER);
	// CategoryId category_id = Shop_RegisterCategory("grab", name, description, OnCategoryDisplayName, OnCategoryDisplayDescription);
	CategoryId category_id = Shop_RegisterCategory("grab", name, description);
	
	char filepath[PLATFORM_MAX_PATH];
	Shop_GetCfgFile(SZF(filepath), "grab.txt");
	
	KeyValues kv = new KeyValues("grab");
	if ( !kv.ImportFromFile(filepath) ) {
		LogError("File \"%s\" not found or broken!", filepath);
		SetFailState("File \"%s\" not found or broken!", filepath);
	}
	
	if ( !kv.GotoFirstSubKey() ) {
		LogError("File \"%s\" is empty!", filepath);
		SetFailState("File \"%s\" is empty!", filepath);
	}
	
	// char id[32], name[32], description[64], buffer[PMP];
	char id[32], buffer[PMP];
	do {
		kv.GetSectionName(SZF(id));
		kv.GetString("name", SZF(name));
		kv.GetString("description", SZF(description));
		
		Shop_StartItem(category_id, id);
		
		Shop_SetInfo(name, description, kv.GetNum("buy_price", 999999), kv.GetNum("sell_price", -1), Item_Togglable, kv.GetNum("duration", 86400));
		Shop_SetCallbacks(INVALID_FUNCTION, OnItemUseCallback, INVALID_FUNCTION, OnItemDisplayName, OnItemDisplayDescription);
		
		Shop_SetCustomInfoFloat("speed", kv.GetFloat("speed", 200.0));
		Shop_SetCustomInfoFloat("duration", kv.GetFloat("lift_time", 0.0));
		Shop_SetCustomInfoFloat("cooldown", kv.GetFloat("cooldown", 0.0));
		Shop_SetCustomInfoFloat("start_width", kv.GetFloat("start_width", 0.0));
		Shop_SetCustomInfoFloat("end_width", kv.GetFloat("end_width", 0.0));
		Shop_SetCustomInfoFloat("max_distance", kv.GetFloat("max_distance", 0.0));
		Shop_SetCustomInfoFloat("min_distance", kv.GetFloat("min_distance", 0.0));
		Shop_SetCustomInfo("max_uses", kv.GetNum("max_uses", 0));
		Shop_SetCustomInfo("team", kv.GetNum("team", 0));
		
		kv.GetString("material", SZF(buffer), "materials/sprites/laserbeam.vmt");
		Shop_SetCustomInfoString("material", buffer);
		
		if ( buffer[0] != 0 ) {
			AddFileToDownloadsTable(buffer);
			if ( !IsModelPrecached(buffer) ) {
				PrecacheModel(buffer);
			}
			
			strcopy(buffer, FindCharInString(buffer, '.', true) + 1, buffer);
			StrCat(SZF(buffer), ".vtf");
			AddFileToDownloadsTable(buffer);
		}
		
		kv.GetString("color", SZF(buffer), "255 0 0");
		Shop_SetCustomInfoString("color", buffer);
		kv.GetString("alpha", SZF(buffer), "255");
		Shop_SetCustomInfoString("alpha", buffer);
		
		kv.GetString("sound_start", SZF(buffer), "weapons/physcannon/physcannon_pickup.wav");
		Shop_SetCustomInfoString("sound_start", buffer);
		Format(SZF(buffer), "sound/%s", buffer);
		AddFileToDownloadsTable(buffer);
		
		kv.GetString("sound_hold", SZF(buffer), "weapons/physcannon/hold_loop.wav");
		Shop_SetCustomInfoString("sound_hold", buffer);
		Format(SZF(buffer), "sound/%s", buffer);
		AddFileToDownloadsTable(buffer);
		
		kv.GetString("sound_end", SZF(buffer), "weapons/physcannon/physcannon_drop.wav");
		Shop_SetCustomInfoString("sound_end", buffer);
		Format(SZF(buffer), "sound/%s", buffer);
		AddFileToDownloadsTable(buffer);
		
		Shop_EndItem();
		
		
	} while ( kv.GotoNextKey() );
}

public bool OnCategoryDisplayName(int client, CategoryId category_id, const char[] category, const char[] name, char[] buffer, int maxlen)
{
	// FormatEx(buffer, maxlen, "%T", name, client);
}

public bool OnCategoryDisplayDescription(int client, CategoryId category_id, const char[] category, const char[] description, char[] buffer, int maxlen)
{
	// if ( description[0] != 0 ) {
		// FormatEx(buffer, maxlen, "%T", description, client);
	// }
}

public bool OnItemDisplayName(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ShopMenu menu, bool &disabled, const char[] name, char[] buffer, int maxlen)
{
	FormatEx(buffer, maxlen, "%T", name, client);
}

public bool OnItemDisplayDescription(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ShopMenu menu, const char[] description, char[] buffer, int maxlen)
{
	if ( description[0] != 0 ) {
		FormatEx(buffer, maxlen, "%T", description, client);
	}
}

public void OnConfigsExecuted() 
{
	
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PreThink, PreThinkHook);
}

public void PreThinkHook(int client) 
{
	if ( g_target[client] != 0 ) {
		float time = GetEngineTime();
		if ( g_use_time[client] + g_duration[client] < time ) {
			g_use_time[client] = GetEngineTime() + g_cooldown[client];
			ReleaseTarget(client);
		}
		else {
			float remain = g_duration[client] - (time - g_use_time[client]);
			PrintHintText(client, "%T", "grab life time remain", client, remain);
			StopSound(client, SNDCHAN_STATIC, "ui/hint.wav");
			
			MoveGrabTarget(client);
		}
	}
}

public void OnClientDisconnect(int client)
{
	ReleaseTarget(client);
	
	g_search_timer[client] = INVALID_HANDLE;
	g_grab_timer[client] = INVALID_HANDLE;
	g_access[client] = false;
}

// ==============================================================================================================================
// >>> 
// ==============================================================================================================================
public Action Command_GrabTest(int client, int argc)
{
	g_max_uses[client] = 0;
	g_cooldown[client] = 0.0;
	g_duration[client] = 0.0;
	g_max_distance[client] = 0.0;
	g_min_distance[client] = 0.0;
	g_material[client] = "materials/sprites/laserbeam.vmt";
		
	if ( g_target[client] == 0 ) {
		SearchGrabTarget(client);
	}
	else {
		ReleaseTarget(client);
	}
	
	return Plugin_Handled;
}

public Action Command_Grab(int client, int argc)
{
	if ( g_access[client] ) {
		if ( g_target[client] == 0 ) {
			if ( g_team[client] != 0 && g_team[client] != GetClientTeam(client) ) {
				PrintHintText(client, "%T", "grab team restrict hint", client);
				StopSound(client, SNDCHAN_STATIC, "ui/hint.wav");
				CPrintToChat(client, "%T", "grab team restrict", client);
				return Plugin_Handled;
			}
			
			if ( g_max_uses[client] == 0 || g_uses[client] < g_max_uses[client] ) {
				if ( g_search_timer[client] == INVALID_HANDLE ) {
					float time = GetEngineTime();
					if ( g_use_time[client] <= time ) {
						SearchGrabTarget(client);
					}
					else {
						float cooldown = g_use_time[client] - time;
						PrintHintText(client, "%T", "grab cooldown hint", client, cooldown);
						StopSound(client, SNDCHAN_STATIC, "ui/hint.wav");
						CPrintToChat(client, "%T", "grab cooldown", client, cooldown);
					}
				}
				else {
					KillTimer(g_search_timer[client]);
					g_search_timer[client] = INVALID_HANDLE;
					
					PrintHintText(client, "%T", "grab search stopped hint", client);
					StopSound(client, SNDCHAN_STATIC, "ui/hint.wav");
					CPrintToChat(client, "%T", "grab search stopped", client);
				}
			}
			else {
				PrintHintText(client, "%T", "grab uses limit hint", client);
				StopSound(client, SNDCHAN_STATIC, "ui/hint.wav");
				CPrintToChat(client, "%T", "grab uses limit", client);
			}
		}
		else {
			g_use_time[client] = GetEngineTime() + g_cooldown[client];
			ReleaseTarget(client);
		}
	}
	
	return Plugin_Handled;
}

public ShopAction OnItemUseCallback(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	if ( !isOn && !elapsed ) {
		Shop_ToggleClientCategoryOff(client, category_id);
		
		g_team[client] = Shop_GetItemCustomInfo(item_id, "team", 0);
		g_max_uses[client] = Shop_GetItemCustomInfo(item_id, "max_uses", 0);
		g_speed[client] = Shop_GetItemCustomInfoFloat(item_id, "speed", 0.0);
		g_cooldown[client] = Shop_GetItemCustomInfoFloat(item_id, "cooldown", 0.0);
		g_duration[client] = Shop_GetItemCustomInfoFloat(item_id, "duration", 0.0);
		g_max_distance[client] = Shop_GetItemCustomInfoFloat(item_id, "max_distance", 0.0);
		g_min_distance[client] = Shop_GetItemCustomInfoFloat(item_id, "min_distance", 0.0);
		g_beam_start_size[client] = Shop_GetItemCustomInfoFloat(item_id, "start_width", 0.0);
		g_beam_end_size[client] = Shop_GetItemCustomInfoFloat(item_id, "end_width", 0.0);
		
		Shop_GetItemCustomInfoString(item_id, "material", g_material[client], sizeof(g_material[]), "");
		Shop_GetItemCustomInfoString(item_id, "color", g_color[client], sizeof(g_color[]), "");
		Shop_GetItemCustomInfoString(item_id, "alpha", g_alpha[client], sizeof(g_alpha[]), "");
		
		Shop_GetItemCustomInfoString(item_id, "sound_start", g_sound_start[client], sizeof(g_sound_start[]), "");
		Shop_GetItemCustomInfoString(item_id, "sound_hold", g_sound_hold[client], sizeof(g_sound_hold[]), "");
		Shop_GetItemCustomInfoString(item_id, "sound_end", g_sound_end[client], sizeof(g_sound_end[]), "");
		
		PrecacheSoundAny(g_sound_start[client]);
		PrecacheSoundAny(g_sound_hold[client]);
		PrecacheSoundAny(g_sound_end[client]);
		
		g_access[client] = true;
		return Shop_UseOn;
	}
	
	g_access[client] = false;
	return Shop_UseOff;
}

// ==============================================================================================================================
// >>> 
// ==============================================================================================================================
public void Ev_RoundStart(Event event, const char[] event_name, bool silent)
{
	LC(i) {
		g_use_time[i] = 0.0;
		g_uses[i] = 0;
	}
}

// ==============================================================================================================================
// >>> 
// ==============================================================================================================================
void SearchGrabTarget(int client)
{
	if ( g_search_timer[client] != INVALID_HANDLE ) {
		KillTimer(g_search_timer[client]);
	}
	
	g_search_timer[client] = CreateTimer(0.1, Timer_SearchGrabTarget, UID(client), TIMER_REPEAT);
	TriggerTimer(g_search_timer[client]);
}

bool IsTargetClient(int target)
{
	return ( target > 0 && target <= MaxClients );
}

void GrabTarget(int client, int target)
{
	if ( IsTargetClient(target) ) {
		g_move_speed[client] = GetEntPropFloat(target, Prop_Send, "m_flMaxspeed");
		SetEntPropFloat(target, Prop_Send, "m_flMaxspeed", 0.01);
	}
	
	g_gravity[client] = GetEntityGravity(target);
	SetEntityGravity(target, 0.0);
	
	g_uses[client]++;
	CreateBeam(client, target);
	g_target[client] = EntIndexToEntRef(target);
	
	if ( strlen(g_sound_start[client]) > 3 ) {
		EmitSoundToAllAny(g_sound_start[client], client);
	}
	
	if ( strlen(g_sound_hold[client]) > 3 ) {
		EmitSoundToAllAny(g_sound_hold[client], client);
	}
	// g_grab_timer[client] = CreateTimer(0.01, Timer_GrabTarget, UID(client), TIMER_REPEAT);
}

void CreateBeam(int client, int target)
{
	float client_origin[3], target_origin[3];
	GetClientEyePosition(client, client_origin);
	GetEntPropVector(target, Prop_Send, "m_vecOrigin", target_origin);
	
	// int start = CreateHelper(client, client_origin);
	// int end = CreateHelper(target, target_origin);
	g_distance[client] = GetVectorDistance(client_origin, target_origin);
	
	char targetname[64];
	int beam = CreateEntityByName("env_beam");
	DispatchKeyValue(beam, "texture", g_material[client]);
	DispatchKeyValue(beam, "spawnflags", "1");
	DispatchKeyValue(beam, "rendercolor", g_color[client]);
	DispatchKeyValue(beam, "renderamt", g_alpha[client]);
	// DispatchKeyValue(beam, "BoltWidth", "2.0");
	
	Format(SZF(targetname), "grab_helper_%d", client);
	DispatchKeyValue(client, "targetname", targetname);
	DispatchKeyValue(beam, "LightningStart", targetname);
	Format(SZF(targetname), "grab_helper_%d", target);
	DispatchKeyValue(target, "targetname", targetname);
	DispatchKeyValue(beam, "LightningEnd", targetname);
	
	DispatchSpawn(beam);
	ActivateEntity(beam);
	AcceptEntityInput(beam, "TurnOn"); 
	TeleportEntity(beam, client_origin, NULL_VECTOR, NULL_VECTOR);
	
	SetEntPropFloat(beam, Prop_Data, "m_fWidth", g_beam_start_size[client]);
	SetEntPropFloat(beam, Prop_Data, "m_fEndWidth", g_beam_end_size[client]); 
	
	// g_beam_start[client] = EntIndexToEntRef(start);
	// g_beam_end[client] = EntIndexToEntRef(end);
	g_beam[client] = EntIndexToEntRef(beam);
}

void MoveGrabTarget(int client)
{
	int target = EntRefToEntIndex(g_target[client]);
	if ( target == INVALID_ENT_REFERENCE ) {
		return;
	}
	
	float gravity = GetEntityGravity(target);
	if ( gravity != 0.0 && g_gravity[client] != gravity ) {
		g_gravity[client] = gravity;
		SetEntityGravity(target, 0.0);
	}
	
	float origin[3], angles[3];
	GetClientEyePosition(client, origin);
	GetClientEyeAngles(client, angles);
	
	float fwd[3];
	GetAngleVectors(angles, fwd, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(fwd, g_distance[client]);
	AddVectors(origin, fwd, origin);
	
	float target_origin[3], direction[3];
	GetEntPropVector(target, Prop_Send, "m_vecOrigin", target_origin);
	
	MakeVectorFromPoints(target_origin, origin, direction);
	NormalizeVector(direction, direction);
	
	float distance = GetVectorDistance(target_origin, origin);
	if ( distance >= g_speed[client] / 2 ) {
		ScaleVector(direction, g_speed[client]);
	}
	else {
		float scale = distance*2;
		if ( scale >= g_speed[client] / 2 ) {
			scale = g_speed[client] / 2;
		}
		
		ScaleVector(direction, scale);
	}
	
	TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, direction);
	
	// AddVectors(target_origin, direction, fwd);
	// TE_SetupBeamPoints(target_origin, fwd, PrecacheModel("materials/sprites/laserbeam.vmt"), 0, 0, 24, 0.1, 2.0, 2.0, 0, 0.0, {255, 255, 0, 255}, 1);
	// TE_SendToAll();
}

void ReleaseTarget(int client)
{
	// if ( g_grab_timer[client] != INVALID_HANDLE ) {
		// KillTimer(g_grab_timer[client]);
		// g_grab_timer[client] = INVALID_HANDLE;
	// }
	
	int target = EntRefToEntIndex(g_target[client]);
	if ( target != INVALID_ENT_REFERENCE && target > 0 ) {
		if ( IsTargetClient(target) ) {
			SetEntPropFloat(target, Prop_Send, "m_flMaxspeed", g_move_speed[client]);
		}
		
		SetEntityGravity(target, g_gravity[client]);
		
		PrintHintText(client, "%T", "grab target released", client, g_max_uses[client] - g_uses[client]);
		StopSound(client, SNDCHAN_STATIC, "ui/hint.wav");
		StopSound(client, SNDCHAN_AUTO, g_sound_hold[client]);
		if ( strlen(g_sound_end[client]) > 3 ) {
			EmitSoundToAllAny(g_sound_end[client], client);
		}
	}
	
	// KillEntityByRef(g_beam_start[client]);
	// KillEntityByRef(g_beam_end[client]);
	KillEntityByRef(g_beam[client]);
	g_target[client] = 0;
}

void KillEntityByRef(int ref)
{
	int entity = EntRefToEntIndex(ref);
	if ( entity != INVALID_ENT_REFERENCE && entity > MaxClients ) {
		AcceptEntityInput(entity, "kill");
	}
}

// ==============================================================================================================================
// >>> 
// ==============================================================================================================================
public Action Timer_SearchGrabTarget(Handle timer, any userid)
{
	int client = CID(userid);
	if ( !client ) return Plugin_Stop;
	
	int target = GetClientAimTarget(client, false); 
	if ( target > 0 ) {
		float origin[3], target_origin[3];
		GetClientEyePosition(client, origin);
		GetEntPropVector(target, Prop_Send, "m_vecOrigin", target_origin);
		
		float distance = GetVectorDistance(origin, target_origin);
		if ( g_max_distance[client] > 0.0 && distance > g_max_distance[client] ) {
			PrintHintText(client, "%T", "grab target too far", client);
			StopSound(client, SNDCHAN_STATIC, "ui/hint.wav");
			return Plugin_Continue;
		}
		else if ( distance < g_min_distance[client] ) {
			PrintHintText(client, "%T", "grab target too close", client);
			StopSound(client, SNDCHAN_STATIC, "ui/hint.wav");
			return Plugin_Continue;
		}
		
		g_use_time[client] = GetEngineTime();
		g_search_timer[client] = INVALID_HANDLE;
		GrabTarget(client, target);
		return Plugin_Stop;
	}
	
	PrintHintText(client, "%T", "grab searching target", client);
	StopSound(client, SNDCHAN_STATIC, "ui/hint.wav");
	return Plugin_Continue;
}
