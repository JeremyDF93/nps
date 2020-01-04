#pragma semicolon 1
#include <sourcemod>

#define NYX_DEBUG 1
#define NYXTOOLS_TAG "PS"
#include <nyxtools>
#include <nps_stocks>
#include <nps_storage>

#pragma newdecls required

public Plugin myinfo = {
  name = "NPS - Storage",
  author = NYXTOOLS_AUTHOR,
  description = "",
  version = NPS_VERSION,
  url = NYXTOOLS_WEBSITE
};

/***
 *        ______                          
 *       / ____/___  __  ______ ___  _____
 *      / __/ / __ \/ / / / __ `__ \/ ___/
 *     / /___/ / / / /_/ / / / / / (__  ) 
 *    /_____/_/ /_/\__,_/_/ /_/ /_/____/  
 *                                        
 */

enum ePlayer {
  Player_UserID,
  Player_Points,
  Player_Reward,
  String:Player_LastItem[64],
  Player_HeadshotCount,
  Player_KillCount,
  Player_HurtCount,
  Player_HealCount,
  Player_ProtectCount,
  bool:Player_BurnedWitch,
  bool:Player_BurnedTank,
  bool:Player_WasTank
}

enum eConVar {
  ConVar:ConVar_MaxPoints,
  ConVar:ConVar_StartPoints
}

/***
 *       ________      __          __    
 *      / ____/ /___  / /_  ____ _/ /____
 *     / / __/ / __ \/ __ \/ __ `/ / ___/
 *    / /_/ / / /_/ / /_/ / /_/ / (__  ) 
 *    \____/_/\____/_.___/\__,_/_/____/  
 *                                       
 */

any g_aPlayer[MAXPLAYERS + 1][ePlayer];

 /***
 *       ______          _    __               
 *      / ____/___  ____| |  / /___ ___________
 *     / /   / __ \/ __ \ | / / __ `/ ___/ ___/
 *    / /___/ /_/ / / / / |/ / /_/ / /  (__  ) 
 *    \____/\____/_/ /_/|___/\__,_/_/  /____/  
 *                                             
 */

ConVar g_hConVars[eConVar];

/***
 *        ____  __            _          ____      __            ____              
 *       / __ \/ /_  ______ _(_)___     /  _/___  / /____  _____/ __/___ _________ 
 *      / /_/ / / / / / __ `/ / __ \    / // __ \/ __/ _ \/ ___/ /_/ __ `/ ___/ _ \
 *     / ____/ / /_/ / /_/ / / / / /  _/ // / / / /_/  __/ /  / __/ /_/ / /__/  __/
 *    /_/   /_/\__,_/\__, /_/_/ /_/  /___/_/ /_/\__/\___/_/  /_/  \__,_/\___/\___/ 
 *                  /____/                                                         
 */

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
  RegPluginLibrary("nps_storage");

  CreateNative("ResetPlayerStorage", Native_ResetPlayerStorage);
  CreateNative("Player.UserID.get", Native_UserIDGet);
  CreateNative("Player.UserID.set", Native_UserIDSet);
  CreateNative("Player.Points.get", Native_PointsGet);
  CreateNative("Player.Points.set", Native_PointsSet);
  CreateNative("Player.GivePoints", Native_GivePoints);
  CreateNative("Player.Reward.get", Native_RewardGet);
  CreateNative("Player.Reward.set", Native_RewardSet);
  CreateNative("Player.GetLastItem", Native_GetLastItem);
  CreateNative("Player.SetLastItem", Native_SetLastItem);
  CreateNative("Player.SetDefaults", Native_SetDefaults);
  CreateNative("Player.HeadshotCount.get", Native_HeadshotCountGet);
  CreateNative("Player.HeadshotCount.set", Native_HeadshotCountSet);
  CreateNative("Player.KillCount.get", Native_KillCountGet);
  CreateNative("Player.KillCount.set", Native_KillCountSet);
  CreateNative("Player.HurtCount.get", Native_HurtCountGet);
  CreateNative("Player.HurtCount.set", Native_HurtCountSet);
  CreateNative("Player.HealCount.get", Native_HealCountGet);
  CreateNative("Player.HealCount.set", Native_HealCountSet);
  CreateNative("Player.TransferHealCount", Native_TransferHealCount);
  CreateNative("Player.ProtectCount.get", Native_ProtectCountGet);
  CreateNative("Player.ProtectCount.set", Native_ProtectCountSet);
  CreateNative("Player.BurnedWitch.get", Native_BurnedWitchGet);
  CreateNative("Player.BurnedWitch.set", Native_BurnedWitchSet);
  CreateNative("Player.BurnedTank.get", Native_BurnedTankGet);
  CreateNative("Player.BurnedTank.set", Native_BurnedTankSet);
  CreateNative("Player.WasTank.get", Native_WasTankGet);
  CreateNative("Player.WasTank.set", Native_WasTankSet);

  return APLRes_Success;
}

public void OnPluginStart() {
  LoadTranslations("common.phrases");
}

public void OnAllPluginsLoaded() {
  if (LibraryExists("nps")) {
    g_hConVars[ConVar_MaxPoints] = FindConVar("nps_max_points");
    g_hConVars[ConVar_StartPoints] = FindConVar("nps_start_points");
  }
}

/***
 *        _   __      __  _                
 *       / | / /___ _/ /_(_)   _____  _____
 *      /  |/ / __ `/ __/ / | / / _ \/ ___/
 *     / /|  / /_/ / /_/ /| |/ /  __(__  ) 
 *    /_/ |_/\__,_/\__/_/ |___/\___/____/  
 *                                         
 */

public int Native_ResetPlayerStorage(Handle plugin, int numArgs) {
  for (int i = 1; i <= MaxClients; i++) {
    SetPlayerDefaults(i);
  }

  return 1;
}

public int Native_UserIDGet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  return g_aPlayer[client][Player_UserID];
}

public int Native_UserIDSet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  int userid = GetNativeCell(2);
  return g_aPlayer[client][Player_UserID] = userid;
}

public int Native_PointsGet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  return g_aPlayer[client][Player_Points];
}

public int Native_PointsSet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  int value = GetNativeCell(2);
  return g_aPlayer[client][Player_Points] = value;
}

public int Native_GivePoints(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  int amount = GetNativeCell(2);
  int limit = g_hConVars[ConVar_MaxPoints].IntValue;
  int total = g_aPlayer[client][Player_Points] + amount;

  if (total > limit) {
    int min = MathMin(amount, total - limit);
    int max = MathMax(amount, total - limit);
    int spent = max - min;

    if (spent >= amount) return 0;
    if (spent >= limit) return 0;

    g_aPlayer[client][Player_Points] += spent;
    return spent;
  }

  g_aPlayer[client][Player_Points] += amount;
  return amount;
}

public int Native_RewardGet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  return g_aPlayer[client][Player_Reward];
}

public int Native_RewardSet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  int value = GetNativeCell(2);
  return g_aPlayer[client][Player_Reward] = value;
}

public int Native_GetLastItem(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  return SetNativeString(2, g_aPlayer[client][Player_LastItem], GetNativeCell(3));
}

public int Native_SetLastItem(Handle plugin, int numArgs) {
  int len; GetNativeStringLength(2, len);
  char[] buffer = new char[len + 1];
  GetNativeString(2, buffer, len + 1);

  int client = EntRefToEntIndex(GetNativeCell(1));
  strcopy(g_aPlayer[client][Player_LastItem], 64, buffer);
  return 1;
}

public int Native_SetDefaults(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  int userid = GetNativeCell(2);
  SetPlayerDefaults(client, userid);
  return 1;
}

public int Native_HeadshotCountGet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  return g_aPlayer[client][Player_HeadshotCount];
}

public int Native_HeadshotCountSet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  int value = GetNativeCell(2);
  return g_aPlayer[client][Player_HeadshotCount] = value;
}

public int Native_KillCountGet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  return g_aPlayer[client][Player_KillCount];
}

public int Native_KillCountSet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  int value = GetNativeCell(2);
  return g_aPlayer[client][Player_KillCount] = value;
}

public int Native_HurtCountGet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  return g_aPlayer[client][Player_HurtCount];
}

public int Native_HurtCountSet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  int value = GetNativeCell(2);
  return g_aPlayer[client][Player_HurtCount] = value;
}

public int Native_HealCountGet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  return g_aPlayer[client][Player_HealCount];
}

public int Native_HealCountSet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  int value = GetNativeCell(2);
  return g_aPlayer[client][Player_HealCount] = value;
}

public int Native_TransferHealCount(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  Player player = view_as<Player>(GetNativeCell(2));

  player.HealCount = g_aPlayer[client][Player_HealCount];
  g_aPlayer[client][Player_HealCount] = 0;
  return 1;
}

public int Native_ProtectCountGet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  return g_aPlayer[client][Player_ProtectCount];
}

public int Native_ProtectCountSet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  int value = GetNativeCell(2);
  return g_aPlayer[client][Player_ProtectCount] = value;
}

public int Native_BurnedWitchGet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  return g_aPlayer[client][Player_BurnedWitch];
}

public int Native_BurnedWitchSet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  int value = GetNativeCell(2);
  return g_aPlayer[client][Player_BurnedWitch] = view_as<bool>(value);
}

public int Native_BurnedTankGet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  return g_aPlayer[client][Player_BurnedTank];
}

public int Native_BurnedTankSet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  int value = GetNativeCell(2);
  return g_aPlayer[client][Player_BurnedTank] = view_as<bool>(value);
}

public int Native_WasTankGet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  return g_aPlayer[client][Player_WasTank];
}

public int Native_WasTankSet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  int value = GetNativeCell(2);
  return g_aPlayer[client][Player_WasTank] = view_as<bool>(value);
}

/***
 *        ______                 __  _                 
 *       / ____/_  ______  _____/ /_(_)___  ____  _____
 *      / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
 *     / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  ) 
 *    /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/  
 *                                                     
 */

void SetPlayerDefaults(int client, int userid=-1) {
  g_aPlayer[client][Player_UserID] = userid;
  g_aPlayer[client][Player_Points] = g_hConVars[ConVar_StartPoints].IntValue;
  g_aPlayer[client][Player_Reward] = 0;
  g_aPlayer[client][Player_HeadshotCount] = 0;
  g_aPlayer[client][Player_KillCount] = 0;
  g_aPlayer[client][Player_HurtCount] = 0;
  g_aPlayer[client][Player_HealCount] = 0;
  g_aPlayer[client][Player_ProtectCount] = 0;
  g_aPlayer[client][Player_BurnedWitch] = false;
  g_aPlayer[client][Player_BurnedTank] = false;
  g_aPlayer[client][Player_WasTank] = false;
}
 