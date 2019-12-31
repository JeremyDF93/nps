#pragma semicolon 1
#include <sourcemod>

#define NYX_DEBUG 1
#define NYX_PLUGIN_TAG "PS"
#include <nyxtools>
#include <nps_storage>

#pragma newdecls required

public Plugin myinfo = {
  name = "NPS - Storage",
  author = NYX_PLUGIN_AUTHOR,
  description = "",
  version = NYX_PLUGIN_VERSION,
  url = NYX_PLUGIN_WEBSITE
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
  bool:Player_BurnedTank
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
 *        ____  __            _          ____      __            ____              
 *       / __ \/ /_  ______ _(_)___     /  _/___  / /____  _____/ __/___ _________ 
 *      / /_/ / / / / / __ `/ / __ \    / // __ \/ __/ _ \/ ___/ /_/ __ `/ ___/ _ \
 *     / ____/ / /_/ / /_/ / / / / /  _/ // / / / /_/  __/ /  / __/ /_/ / /__/  __/
 *    /_/   /_/\__,_/\__, /_/_/ /_/  /___/_/ /_/\__/\___/_/  /_/  \__,_/\___/\___/ 
 *                  /____/                                                         
 */

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
  RegPluginLibrary("nps_storage");

  CreateNative("Player.UserID.get", Native_UserIDGet);
  CreateNative("Player.UserID.set", Native_UserIDSet);
  CreateNative("Player.Points.get", Native_PointsGet);
  CreateNative("Player.Points.set", Native_PointsSet);
  CreateNative("Player.Reward.get", Native_RewardGet);
  CreateNative("Player.Reward.set", Native_RewardSet);

  return APLRes_Success;
}

public void OnPluginStart() {
  Player player = new Player(1);
  player.Points = 100;
}

/***
 *        _   __      __  _                
 *       / | / /___ _/ /_(_)   _____  _____
 *      /  |/ / __ `/ __/ / | / / _ \/ ___/
 *     / /|  / /_/ / /_/ /| |/ /  __(__  ) 
 *    /_/ |_/\__,_/\__/_/ |___/\___/____/  
 *                                         
 */

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

public int Native_RewardGet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  return g_aPlayer[client][Player_Reward];
}

public int Native_RewardSet(Handle plugin, int numArgs) {
  int client = EntRefToEntIndex(GetNativeCell(1));
  int value = GetNativeCell(2);
  return g_aPlayer[client][Player_Reward] = value;
}

/***
 *        ______                 __  _                 
 *       / ____/_  ______  _____/ /_(_)___  ____  _____
 *      / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
 *     / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  ) 
 *    /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/  
 *                                                     
 */

void SetPlayerDefaults(int client) {
  g_aPlayerStorage[client][Player_Points] = g_hConVars[ConVar_StartPoints].IntValue;
  g_aPlayerStorage[client][Player_Reward] = 0;
  g_aPlayerStorage[client][Player_Headshots] = 0;
  g_aPlayerStorage[client][Player_Kills] = 0;
  g_aPlayerStorage[client][Player_HurtCount] = 0;
  g_aPlayerStorage[client][Player_BurnedWitch] = false;
  g_aPlayerStorage[client][Player_BurnedTank] = false;
  g_aPlayerStorage[client][Player_ProtectCount] = 0;
  g_aPlayerStorage[client][Player_HealCount] = 0;
}
 