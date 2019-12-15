#if defined _nyxtools_included_
	#endinput
#endif
#define _nyxtools_included_

/*
                                              .,
                                             / :
                                            / :---..
                                     .^.,-`/  :     `.
                                 .-``| 'j./  :''-.   )
                              ..`-'`(..-./  :'    \  |
                             ( ,\'``        '-  .  | `._   _.---.
                             |(  '`-..__      `.   (    ```_._   \
                            (( `.(.---. ``\    )    `-..-'`   \   )
                            |(```:``'-.\  /   .'            .  : (
 .-..-.                     |(`. (  ((WW)''--'  *       x      (  `..,__
(   \  \          _.._.--.  ( \|  '. \`,|  `.                   `-_     `-
 '   '._`-._..-'``__  `-. '. \ |    `'--'  ..7               .     ``-..  \
  '.    ```   /```  `'.  \  \ \|   `-.-~-.`-/      *          ___       )  |   .
 .-.:>.       \__.     '. \  \ '      (`'.`' `-..        .-'`..--._-._.'   `--'|
(               (   .    . \  \)       \  `'._   `--..-'_.-'`      `'-.____..-'
 `'-._           `'(__.   : \ /''-.     \     ```''''```
     .7               (_. (  \'``\ `'---'\
   .'     ,                \  '-  \ ._)`. )
   \__--':     .     .      `'     \ -..'/
        /    ,:    ,/\   /\__.   . .`'--`
        '--'`  `--'   `'  /      |  : /|.-'```''.
                         /       |  |` |.-'``-.  `-.
                        /        |  :  (   .  x`-   )
                      .'_  ()  .'|  '.  '        ) (  ..--.
                     ( `.`L_  / \|   :   '.      `-.`'  .-.`.__
                     (( C`  )\   (    \    \  .   * `--' ,.)   ``.
                      \`'` )o )./-\    \.-.(\ .-.      .'. .-'``/
                      (`--',./.-''-:. -( \)  `.-._'---'  .'
                       `-._        _(`.:  \-...)  ``'''``
                           `''''=:_`   |---'
                                   ````
                                                                              */

#include <sdktools>
#undef REQUIRE_EXTENSIONS
#include <tf2>
#define REQUIRE_EXTENSIONS

#if !defined NYX_PLUGIN_NAME
	//#error NYX_PLUGIN_NAME must be defined
  #define NYX_PLUGIN_NAME "Nyx"
#endif

#define INT_MAX 2147483647
#define INT_MIN -2147483648

#define SOLID_NONE     0 // no solid model
#define SOLID_BSP      1 // a BSP tree
#define SOLID_BBOX     2 // an AABB
#define SOLID_OBB      3 // an OBB (not implemented yet)
#define SOLID_OBB_YAW  4 // an OBBconstrained so that it can only yaw
#define SOLID_CUSTOM   5 // Always call into the entity for tests
#define SOLID_VPHYSICS 6 // solid vphysics object, get vcollide from the model and collide with that

#define TF_TEAM_UNASSIGNED  0
#define TF_TEAM_SPECTATOR   1
#define TF_TEAM_RED         2
#define TF_TEAM_BLUE        3

#define L4D2_TEAM_UNASSIGNED  0
#define L4D2_TEAM_SPECTATOR   1
#define L4D2_TEAM_SURVIVOR    2
#define L4D2_TEAM_INFECTED    3

// Smoker = 1, Boomer = 2, Hunter = 3, Spitter = 4, Jockey = 5, 
// Charger = 6, Witch = 7, Tank = 8, Survivor = 9
enum L4D2ClassType {
	L4D2Class_Unknown,
	L4D2Class_Smoker,
	L4D2Class_Boomer,
	L4D2Class_Hunter,
	L4D2Class_Spitter,
	L4D2Class_Jockey,
	L4D2Class_Charger,
	L4D2Class_Witch,
	L4D2Class_Tank,
	L4D2Class_Survivor
};

enum L4D2Team {
	L4D2Team_Unassigned = 0,
	L4D2Team_Spectator = 1,
	L4D2Team_Survivor = 2,
	L4D2Team_Infected = 3
}

stock bool IsValidClient(int client, bool filterBots = false, bool filterReplay = true, bool filterSourceTV = true) {
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (IsClientReplay(client) && filterReplay) return false;
	if (IsClientSourceTV(client) && filterSourceTV) return false;
	if (IsFakeClient(client) && filterBots) return false;

	return true;
}

stock bool IsClientAdmin(int client, int flags = ADMFLAG_GENERIC) {
	return (GetUserFlagBits(client) & flags) > 0 || (GetUserFlagBits(client) & ADMFLAG_ROOT) > 0;
}

stock void NyxMsgAdmin(char[] format, any ...) {
	char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 2);

	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i, true) && IsClientAdmin(i)) {
			PrintToChat(i, "[%s] %s", NYX_PLUGIN_NAME, buffer);
			PrintToConsole(i, "[%s] %s", NYX_PLUGIN_NAME, buffer);
		}
	}
	PrintToServer("[%s] %s", NYX_PLUGIN_NAME, buffer);
}

stock void NyxMsg(char[] format, any ...) {
	char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 2);

	PrintToServer("[%s] %s", NYX_PLUGIN_NAME, buffer);
}

stock void NyxMsgReply(int client, char[] format, any ...) {
	char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 3);

	ReplyToCommand(client, "[%s] %s", NYX_PLUGIN_NAME, buffer);
}

stock void NyxMsgClient(int client, char[] format, any ...) {
	char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 3);

	PrintToChat(client, "[%s] %s", NYX_PLUGIN_NAME, buffer);
}

stock void NyxMsgAll(char[] format, any ...) {
	char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 3);

	PrintToChatAll("[%s] %s", NYX_PLUGIN_NAME, buffer);
}

stock void NyxMsgTeam(int team, char[] format, any ...) {
	char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 3);

	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i, true) && GetClientTeam(i) == team) {
			PrintToChat(i, "[%s] %s", NYX_PLUGIN_NAME, buffer);
			PrintToConsole(i, "[%s] %s", NYX_PLUGIN_NAME, buffer);
		}
	}
	PrintToServer("[%s] %s", NYX_PLUGIN_NAME, buffer);
}

stock void NyxAct(int client, char[] format, any ...) {
	char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 3);

	char prefix[64];
	FormatEx(prefix, sizeof(prefix), "[%s] ", NYX_PLUGIN_NAME);

	ShowActivity2(client, prefix, "%s", buffer);
}

stock void NyxMsgDebug(char[] format, any ...) {
#if defined NYX_DEBUG
	char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 2);

	// use a switch statement because you'll 'redundant code' warnings in trhe compiler 
	switch (NYX_DEBUG) {
		case 1: NyxMsg(buffer);
		case 2: NyxMsgAdmin(buffer);
	}
#endif
}

stock void SayText2(int client, int from, char[] msg) {
	char buffer[256];
	Format(buffer, sizeof(buffer), "\x01%s", msg);

	Handle hBf;
	hBf = StartMessageOne("SayText2", client);
	if (hBf != null) {
		BfWriteByte(hBf, from); 
		BfWriteByte(hBf, 0); 
		BfWriteString(hBf, msg);
		EndMessage();
	}
}

stock int GetCmdTarget(int argnum, int client, bool nobots = false, bool immunity = true) {
	char target[MAX_TARGET_LENGTH];
	GetCmdArg(argnum, target, sizeof(target));

	return FindTarget(client, target, nobots, immunity);
}

stock bool GetCmdBool(int argnum, bool def = false) {
	char arg[32];
	GetCmdArg(argnum, arg, sizeof(arg));

	if (strcmp(arg, "true", false) == 0) return true;
	if (strcmp(arg, "false", false) == 0) return false;
	if (strcmp(arg, "on", false) == 0) return true;
	if (strcmp(arg, "off", false) == 0) return false;

	return GetCmdIntEx(argnum, 0, 1, def) > 0;
}

stock int GetCmdInt(int argnum, int def = 0) {
	return RoundFloat(GetCmdFloat(argnum, float(def)));
}

stock int GetCmdIntEx(int argnum, int min = INT_MIN, int max = INT_MAX, int def = 0) {
	return RoundFloat(GetCmdFloatEx(argnum, float(min), float(max), float(def)));
}

stock float GetCmdFloat(int argnum, float def = 0.0) {
	char arg[32];
	GetCmdArg(argnum, arg, sizeof(arg));

	float result;
	if (StringToFloatEx(arg, result) == 0) {
		return def;
	}

	return result;
}

stock float GetCmdFloatEx(int argnum, float min, float max, float def = 0.0) {
	char arg[32];
	GetCmdArg(argnum, arg, sizeof(arg));

	float result;
	if (StringToFloatEx(arg, result) == 0) {
		return def;
	}

	if (result < min) result = min;
	if (result > max) result = max;

	return result;
}

stock any MathMin(any x, any y) {
	if (x < y) return x;

	return y;
}

stock any MathMax(any x, any y) {
	if (x > y) return x;

	return y;
}

stock void ShowURLPanel(int client, const char[] title, const char[] url, bool show = true) {
	Handle kv = CreateKeyValues("data");
	KvSetString(kv, "title", title);
	KvSetNum(kv, "type", MOTDPANEL_TYPE_URL);
	KvSetString(kv, "msg", url);
	KvSetNum(kv, "customsvr", 1);

	ShowVGUIPanel(client, "info", kv, show);
	CloseHandle(kv);
}

stock void ChangeClientTeamEx(int client, int team, bool respawn = true) {
  int lifeState = GetEntProp(client, Prop_Send, "m_lifeState");
  SetEntProp(client, Prop_Send, "m_lifeState", 2);
  ChangeClientTeam(client, team);
  SetEntProp(client, Prop_Send, "m_lifeState", lifeState);

  if (respawn) {
    TF2_RespawnPlayer(client);
  }
}

stock bool GetClientAimPos(int client, float vec[3], int mask = MASK_ALL) {
	float origin[3], angles[3];
	GetClientEyePosition(client, origin);
	GetClientEyeAngles(client, angles);

	Handle trace = TR_TraceRayFilterEx(origin, angles, mask, RayType_Infinite, TraceEntityFilter_Players);
	if (TR_DidHit(trace)) {
		TR_GetEndPosition(vec, trace);
		CloseHandle(trace);
		return true;
	}

	CloseHandle(trace);
	return false;
}

stock int GetClientAimTargetEx(int client, int mask = MASK_ALL) {
	float origin[3], angles[3];
	GetClientEyePosition(client, origin);
	GetClientEyeAngles(client, angles);

	Handle trace = TR_TraceRayFilterEx(origin, angles, mask, RayType_Infinite, TraceEntityFilter_Players);
	if (TR_DidHit(trace)) {
		int ent = TR_GetEntityIndex(trace);
		CloseHandle(trace);
		return ent;
	}

	CloseHandle(trace);
	return -1;
}

public bool TraceEntityFilter_Players(int entity, int contentsMask) {
	return entity > MaxClients;
}

stock int FindEntityByClassnameSafe(int startEnt, const char[] classname) {
	while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
	return FindEntityByClassname(startEnt, classname);
}

stock void CopyVectors(float vec[3], float result[3]) {
	result[0] = vec[0];
	result[1] = vec[1];
	result[2] = vec[2];
}

///
/// TF2 Stocks
///

stock int TF2_GetPlayerCount(bool playing = false) {
	int playerCount = 0;
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i, true)) continue;
		if (playing) {
			int team = GetClientTeam(i);
			if (team != TF_TEAM_RED) continue;
			if (team != TF_TEAM_BLUE) continue;
		}

		playerCount++;
	}

	return playerCount;
}

public bool TF2_IsMvM() {
	char map[PLATFORM_MAX_PATH];
	GetCurrentMap(map, sizeof(map));
	if (strncmp(map, "mvm_", 4) == 0) return true;

	return false;
}

stock void TF2_RemoveAllWearables(int client) {
	if (!IsValidClient(client)) return;
	if (!IsPlayerAlive(client)) return;

	int  wearable = -1;
	while ((wearable = FindEntityByClassname(wearable, "tf_wearable")) != -1) {
		if (!IsValidEdict(wearable)) continue;

		if (client == GetEntPropEnt(wearable, Prop_Send, "m_hOwnerEntity")) {
			TF2_RemoveWearable(client, wearable);
		}
	}
}

stock void TF2_RemoveWearables(int client, const int[] items, int len) {
	if (!IsValidClient(client)) return;
	if (!IsPlayerAlive(client)) return;

	int  wearable = -1;
	while ((wearable = FindEntityByClassname(wearable, "tf_wearable")) != -1) {
		if (!IsValidEdict(wearable)) continue;

		if (client == GetEntPropEnt(wearable, Prop_Send, "m_hOwnerEntity")) {
			for (int i = 0; i < len; i++) {
				if (GetEntProp(wearable, Prop_Send, "m_iItemDefinitionIndex") == items[i]) {
					TF2_RemoveWearable(client, wearable);
				}
			}
		}
	}
}

stock void TF2_SwitchToSlot(int client, int slot) {
	if (!IsValidClient(client)) return;
	if (!IsPlayerAlive(client)) return;

	char classname[64];
	if (slot >= 0 && slot <= 5) {
		int weapon = GetPlayerWeaponSlot(client, slot);
		if (weapon > MaxClients) {
			if (!IsValidEdict(weapon)) return;
			if (!GetEdictClassname(weapon, classname, sizeof(classname))) return;

			FakeClientCommandEx(client, "use %s", classname);
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
		}
	}
}

stock int TF2_StringToSlot(char[] str) {
	if (strcmp(str, "primary", false) == 0) return 0;
	if (strcmp(str, "secondary", false) == 0) return 1;
	if (strcmp(str, "sapper", false) == 0) return 1;
	if (strcmp(str, "melee", false) == 0) return 2;
	if (strcmp(str, "pda", false) == 0) return 3;
	if (strcmp(str, "pdaq", false) == 0) return 3;
	if (strcmp(str, "pda2", false) == 0) return 4;
	if (strcmp(str, "building", false) == 0) return 5;
	if (strcmp(str, "hat", false) == 0) return 5;
	if (strcmp(str, "head", false) == 0) return 5;
	if (strcmp(str, "misc", false) == 0) return 6;
	if (strcmp(str, "action", false) == 0) return 7;

	return -1;
}

stock int TF2_StringToTeam(char[] str) {
	if (strcmp(str, "unassigned", false) == 0) return 0;
	if (strcmp(str, "spectate", false) == 0) return 1;
	if (strcmp(str, "red", false) == 0) return 2;
	if (strcmp(str, "blue", false) == 0) return 3;

	return -1;
}

stock void TF2_TeamToString(int team, char[] str, int maxlength) {
	strcopy(str, maxlength, "unknown");

	if (team == TF_TEAM_UNASSIGNED) strcopy(str, maxlength, "unassigned");
	if (team == TF_TEAM_SPECTATOR) strcopy(str, maxlength, "spectate");
	if (team == TF_TEAM_RED) strcopy(str, maxlength, "red");
	if (team == TF_TEAM_BLUE) strcopy(str, maxlength, "blue");
}

stock void TF2_ClassToString(TFClassType class, char[] str, int maxlength) {
	strcopy(str, maxlength, "unknown");

	if (class == TFClass_Scout) strcopy(str, maxlength, "scout");
	if (class == TFClass_Sniper) strcopy(str, maxlength, "sniper");
	if (class == TFClass_DemoMan) strcopy(str, maxlength, "demoman");
	if (class == TFClass_Medic) strcopy(str, maxlength, "medic");
	if (class == TFClass_Heavy) strcopy(str, maxlength, "heavyweapons");
	if (class == TFClass_Pyro) strcopy(str, maxlength, "pyro");
	if (class == TFClass_Spy) strcopy(str, maxlength, "spy");
	if (class == TFClass_Soldier) strcopy(str, maxlength, "soldier");
	if (class == TFClass_Engineer) strcopy(str, maxlength, "engineer");
}

///
/// L4D2 Stocks
///

stock L4D2ClassType L4D2_GetClassType(const char[] classname) {
	if (strcmp(classname, "boomer", false) == 0) return L4D2Class_Boomer;
	if (strcmp(classname, "smoker", false) == 0) return L4D2Class_Smoker;
	if (strcmp(classname, "hunter", false) == 0) return L4D2Class_Hunter;
	if (strcmp(classname, "spitter", false) == 0) return L4D2Class_Spitter;
	if (strcmp(classname, "jockey", false) == 0) return L4D2Class_Jockey;
	if (strcmp(classname, "charger", false) == 0) return L4D2Class_Charger;
	if (strcmp(classname, "witch", false) == 0) return L4D2Class_Witch;
	if (strcmp(classname, "tank", false) == 0) return L4D2Class_Tank;
	if (strcmp(classname, "survivor", false) == 0) return L4D2Class_Survivor;

	return L4D2Class_Unknown;
}

stock L4D2ClassType L4D2_GetClientClass(int client) {
	return view_as<L4D2ClassType>(GetEntProp(client, Prop_Send, "m_zombieClass"));
}

stock L4D2Team L4D2_GetClientTeam(int client) {
	return view_as<L4D2Team>(GetClientTeam(client));
}

stock int L4D2_StringToTeam(char[] str) {
	if (strcmp(str, "unassigned", false) == 0) return L4D2_TEAM_UNASSIGNED;
	if (strcmp(str, "spectate", false) == 0) return L4D2_TEAM_SPECTATOR;
	if (strcmp(str, "survivor", false) == 0) return L4D2_TEAM_SURVIVOR;
	if (strcmp(str, "infected", false) == 0) return L4D2_TEAM_INFECTED;

	return -1;
}

stock void L4D2_TeamToString(int team, char[] str, int maxlength) {
	strcopy(str, maxlength, "unknown");

	if (team == L4D2_TEAM_UNASSIGNED) strcopy(str, maxlength, "unassigned");
	if (team == L4D2_TEAM_SPECTATOR) strcopy(str, maxlength, "spectate");
	if (team == L4D2_TEAM_SURVIVOR) strcopy(str, maxlength, "survivor");
	if (team == L4D2_TEAM_INFECTED) strcopy(str, maxlength, "infected");
}

stock bool L4D2_IsClientGrabbed(int client) {
	if (GetEntProp(client, Prop_Send, "m_pummelAttacker") > 0) return true;
	if (GetEntProp(client, Prop_Send, "m_carryAttacker") > 0) return true;
	if (GetEntProp(client, Prop_Send, "m_pounceAttacker") > 0) return true;
	if (GetEntProp(client, Prop_Send, "m_jockeyAttacker") > 0) return true;
	if (GetEntProp(client, Prop_Send, "m_tongueOwner") > 0) return true;

	return false;
}

stock bool L4D2_IsClientIncapacitated(int client) {
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0) return true;
	
	return false;
}
