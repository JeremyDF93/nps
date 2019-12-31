#pragma semicolon 1
#include <sourcemod>
#include <clientprefs>
#include <left4downtown>
#include <colors>

#define NYX_DEBUG 1
#define NYX_PLUGIN_TAG "PS"
#include <nyxtools>
#include <nyxtools_cheats>
#undef REQUIRE_PLUGIN
#include <nyxtools_l4d2>
#define REQUIRE_PLUGIN
#include <nps_stocks>
#include <nps_catalog>
#include <nps_storage>

#pragma newdecls required

public Plugin myinfo = {
  name = "Nyxtools - L4D2 Point System",
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

enum NyxConVar {
  ConVar:ConVar_StartPoints,
  ConVar:ConVar_MaxPoints,
  ConVar:ConVar_TankHealLimit,
  ConVar:ConVar_TankDelay,
  ConVar:ConVar_TankAllowedFinal,
  ConVar:ConVar_AnnounceNeeds,
  ConVar:ConVar_TopOff
}

/***
 *       ______          _    __               
 *      / ____/___  ____| |  / /___ ___________
 *     / /   / __ \/ __ \ | / / __ `/ ___/ ___/
 *    / /___/ /_/ / / / / |/ / /_/ / /  (__  ) 
 *    \____/\____/_/ /_/|___/\__,_/_/  /____/  
 *                                             
 */

ConVar g_hConVars[NyxConVar];

/***
 *       ________      __          __    
 *      / ____/ /___  / /_  ____ _/ /____
 *     / / __/ / __ \/ __ \/ __ `/ / ___/
 *    / /_/ / / /_/ / /_/ / /_/ / (__  ) 
 *    \____/_/\____/_.___/\__,_/_/____/  
 *                                       
 */

int g_iMenuTarget[MAXPLAYERS + 1];
int g_iSpawnCount[L4D2ClassType];

bool g_bFinal;
bool g_bTankAllowed;

int g_iStartTime;
int g_iStartTimePassed;

/***
 *        ____  __            _          ____      __            ____              
 *       / __ \/ /_  ______ _(_)___     /  _/___  / /____  _____/ __/___ _________ 
 *      / /_/ / / / / / __ `/ / __ \    / // __ \/ __/ _ \/ ___/ /_/ __ `/ ___/ _ \
 *     / ____/ / /_/ / /_/ / / / / /  _/ // / / / /_/  __/ /  / __/ /_/ / /__/  __/
 *    /_/   /_/\__,_/\__, /_/_/ /_/  /___/_/ /_/\__/\___/_/  /_/  \__,_/\___/\___/ 
 *                  /____/                                                         
 */

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
  RegPluginLibrary("nps");
  return APLRes_Success;
}

public void OnPluginStart() {
  NyxMsgDebug("OnPluginStart");

  LoadTranslations("common.phrases");
  LoadTranslations("nps_core.phrases");

  // Console Commands
  RegConsoleCmd("sm_buy", ConCmd_Buy);
  RegConsoleCmd("sm_gp", ConCmd_GivePoints);
  RegConsoleCmd("sm_points", ConCmd_ShowPoints);
  RegConsoleCmd("sm_tp", ConCmd_ShowTeamPoints);
  RegConsoleCmd("sm_heal", ConCmd_Heal);
  RegConsoleCmd("sm_rebuy", ConCmd_BuyAgain);

  // Admin commands
  RegAdminCmd("sm_setpoints", AdmCmd_SetPoints, ADMFLAG_ROOT, "nyx_givepoints <#userid|name> <points>");

  // ConVars
  g_hConVars[ConVar_MaxPoints] = CreateConVar("nps_max_points", "120", "Max player points.");
  g_hConVars[ConVar_StartPoints] = CreateConVar("nps_start_points", "10", "Starting player points.");
  g_hConVars[ConVar_TankHealLimit] = CreateConVar("nps_tank_heal_limit", "3", "Maximum number of times the tank can heal in a life.");
  g_hConVars[ConVar_TankDelay] = CreateConVar("nps_tank_start_delay", "90", "Time (in seconds) to delay tank spawning after survivors leave the safe area.");
  g_hConVars[ConVar_TankAllowedFinal] = CreateConVar("nps_tank_allowed_final", "0", "Tank allowed on the final map?", _, true, 0.0, true, 1.0);
  g_hConVars[ConVar_AnnounceNeeds] = CreateConVar("nps_announce_needs", "1", "Announce when a player tries to buy with insufficient funds.", _, true, 0.0, true, 1.0);
  g_hConVars[ConVar_TopOff] = CreateConVar("nps_topoff", "1", "Top off players with less than the minimal starting points at the start of a round.", _, true, 0.0, true, 1.0);
}

public void OnMapStart() {
  NyxMsgDebug("OnMapStart, Final %b", L4D_IsMissionFinalMap());

  char map[PLATFORM_MAX_PATH];
  GetCurrentMap(map, sizeof(map));
  if (StrContains(map, "m1_") != -1) {
    for (int i = 1; i <= MaxClients; i++) {
      if (!IsValidClient(i)) continue;

      Player player = new Player(i);
      player.SetDefaults();
    }

    for (int i = 0; i < view_as<int>(L4D2ClassType); i++) {
      g_iSpawnCount[i] = 0;
    }
  }

  g_bFinal = L4D_IsMissionFinalMap();
  g_iStartTime = 0;
  g_bTankAllowed = (g_hConVars[ConVar_TankDelay].IntValue == 0);
}

public void OnClientPostAdminCheck(int client) {
  Player player = new Player(client);
  if (player.UserID != GetClientUserId(client)) {
    player.SetDefaults(GetClientUserId(client));
  }
}

public void OnGameFrame() {
  if (!g_bTankAllowed && g_iStartTime > 0) {
    g_iStartTimePassed = GetTime() - g_iStartTime;
    
    if (g_iStartTimePassed >= g_hConVars[ConVar_TankDelay].IntValue) {
      g_bTankAllowed = true;
    }
  }
}

/***
 *        ____      __            ____                    
 *       /  _/___  / /____  _____/ __/___ _________  _____
 *       / // __ \/ __/ _ \/ ___/ /_/ __ `/ ___/ _ \/ ___/
 *     _/ // / / / /_/  __/ /  / __/ /_/ / /__/  __(__  ) 
 *    /___/_/ /_/\__/\___/_/  /_/  \__,_/\___/\___/____/  
 *                                                        
 */

public Action L4D_OnFirstSurvivorLeftSafeArea(int client) {
  if (g_hConVars[ConVar_TankDelay].IntValue == 0) {
    g_bTankAllowed = true;
  } else {
    g_iStartTime = GetTime();
  }

  return Plugin_Continue;
}

public void L4D_OnReplaceTank(int tank, int newtank) {
  NyxMsgDebug("L4D_OnReplaceTank");
  Player player = new Player(tank);
  player.TransferHealCount(new Player(newtank));
}

/***
 *        ______                 __      
 *       / ____/   _____  ____  / /______
 *      / __/ | | / / _ \/ __ \/ __/ ___/
 *     / /___ | |/ /  __/ / / / /_(__  ) 
 *    /_____/ |___/\___/_/ /_/\__/____/  
 *                                       
 */

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
  NyxMsgDebug("Event_RoundStart");
  g_iStartTime = 0;
  g_bTankAllowed = (g_hConVars[ConVar_TankDelay].IntValue == 0);

  if (g_hConVars[ConVar_TopOff].BoolValue) {
    for (int i = 1; i <= MaxClients; i++) {
      Player player = new Player(i);
      if (player.Points < g_hConVars[ConVar_StartPoints].IntValue) {
        player.Points = g_hConVars[ConVar_StartPoints].IntValue;
      }
    }
  }

  return Plugin_Continue;
}

/***
 *        ___       __          _          ______                                          __    
 *       /   | ____/ /___ ___  (_)___     / ____/___  ____ ___  ____ ___  ____ _____  ____/ /____
 *      / /| |/ __  / __ `__ \/ / __ \   / /   / __ \/ __ `__ \/ __ `__ \/ __ `/ __ \/ __  / ___/
 *     / ___ / /_/ / / / / / / / / / /  / /___/ /_/ / / / / / / / / / / / /_/ / / / / /_/ (__  ) 
 *    /_/  |_\__,_/_/ /_/ /_/_/_/ /_/   \____/\____/_/ /_/ /_/_/ /_/ /_/\__,_/_/ /_/\__,_/____/  
 *                                                                                               
 */

public Action AdmCmd_SetPoints(int client, int args) {
  if (args < 1) {
    NyxMsgReply(client, "Usage: sm_givepoints <#userid|name> <points>");
    return Plugin_Handled;
  }

  char target[MAX_NAME_LENGTH];
  GetCmdArg(1, target, sizeof(target));

  char target_name[MAX_TARGET_LENGTH];
  int target_list[MAXPLAYERS], target_count;
  bool tn_is_ml;

  if ((target_count = ProcessTargetString(target, client, target_list, MAXPLAYERS,
      COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
  {
    ReplyToTargetError(client, target_count);
    return Plugin_Handled;
  }

  int points = GetCmdIntEx(2, 0, _, 120);
  for (int i = 0; i < target_count; i++) {
    Player player = new Player(target_list[i]);
    player.Points = points;
    LogAction(client, target_list[i], "\"%L\" gave \"%i\" points to \"%L\"", client, points, target_list[i]);
  }
  NyxAct(client, "Gave %i points to %s", points, target_name);

  return Plugin_Handled;
}

/***
 *       ______                       __        ______                                          __    
 *      / ____/___  ____  _________  / /__     / ____/___  ____ ___  ____ ___  ____ _____  ____/ /____
 *     / /   / __ \/ __ \/ ___/ __ \/ / _ \   / /   / __ \/ __ `__ \/ __ `__ \/ __ `/ __ \/ __  / ___/
 *    / /___/ /_/ / / / (__  ) /_/ / /  __/  / /___/ /_/ / / / / / / / / / / / /_/ / / / / /_/ (__  ) 
 *    \____/\____/_/ /_/____/\____/_/\___/   \____/\____/_/ /_/ /_/_/ /_/ /_/\__,_/_/ /_/\__,_/____/  
 *                                                                                                    
 */

public Action ConCmd_Buy(int client, int args) {
  if (args < 1) {
    if (!IsValidClient(client)) {
      NyxMsgReply(client, "Cannot display buy menu to console");
    }

    FakeClientCommandEx(client, "sm_buymenu");
    return Plugin_Handled;
  }

  char item[32];
  GetCmdArg(1, item, sizeof(item));

  any storage[eCatalog];
  if (!FindItem(item, storage)) {
    NyxPrintToChat(client, "%t", "Item Doesn't Exist", item);
    return Plugin_Handled;
  }

  if (!CanBuy(client, storage)) {
    return Plugin_Handled;
  }

  if (IsPlayerInfected(client)) {
    if (IsPlayerAlive(client)) {
      int target;
      if (args < 2) {
        int playerCount, playerList[MAXPLAYERS + 1];
        for (int i = 1; i <= MaxClients; i++) {
          if (!IsValidClient(i, true)) continue;
          if (!IsPlayerInfected(i)) continue;
          if (IsPlayerAlive(i)) continue;
          if (client == i) continue;

          playerList[playerCount++] = i;
        }

        if (playerCount) {
          target = playerList[GetRandomInt(0, playerCount - 1)];
        } else {
          NyxPrintToChat(client, "%t", "Unable to Give");
          return Plugin_Handled;
        }
      } else {
        target = GetCmdTarget(2, client, false, false);
      }

      if (!IsValidClient(target)) {
        NyxPrintToChat(client, "%t", "Unable to Give");
        return Plugin_Handled;
      }

      BuyItem(client, target, storage);
      NyxPrintToTeam(GetClientTeam(client), "%t", "Bought Something For", client, storage[Catalog_Name], target);
    } else {
      BuyItem(client, client, storage);
    }
  } else {
    BuyItem(client, client, storage);
  }

  return Plugin_Handled;
}

public Action ConCmd_GivePoints(int client, int args) {
  if (args < 1) {
    if (!IsValidClient(client)) {
      NyxMsgReply(client, "Cannot display buy menu to console");
    }

    Display_GivePointsMenu(client);
    return Plugin_Handled;
  }

  int target = GetCmdTarget(1, client, false, false);
  int amount = GetCmdIntEx(2, 1, g_hConVars[ConVar_MaxPoints].IntValue, 5);

  if (client == target) {
    NyxPrintToChat(client, "%t", "Sent Self Points");
  } else if (GetClientTeam(client) != GetClientTeam(target)) {
    NyxPrintToChat(client, "%t", "Sent Wrong Team Points");
  } else {
    Player player = new Player(client);
    int points = player.Points;
    if (amount > points) {
      amount = points;
    }

    int spent = (new Player(target)).GivePoints(amount);
    if (spent == 0) {
      NyxPrintToChat(client, "%t", "Sent Zero Points");
      return Plugin_Handled;
    }

    player.Points -= spent;
    NyxPrintToTeam(GetClientTeam(client), "%t", "Sent Points", client, spent, target);
    NyxPrintToChat(client, "%t", "Points Left", player.Points);
  }

  return Plugin_Handled;
}

public Action ConCmd_ShowPoints(int client, int args) {
  if (IsValidClient(client)) {
    Player player = new Player(client);
    NyxPrintToChat(client, "%t", "Show Points", player.Points);
  }

  return Plugin_Handled;
}

public Action ConCmd_ShowTeamPoints(int client, int args) {
  for (int i = 1; i <= MaxClients; i++) {
    if (!IsValidClient(i)) continue;
    if (GetClientTeam(i) != GetClientTeam(client)) continue;

    Player player = new Player(i);
    if (i == client) {
      NyxPrintToChat(client, "%t", "Show Points", player.Points);
      continue;
    }

    NyxPrintToChat(client, "%t", "Show Points Other", i, player.Points);
  }
  return Plugin_Handled;
}

public Action ConCmd_Heal(int client, int args) {
  if (IsValidClient(client)) {
    any storage[eCatalog];
    if (!FindItem("heal", storage)) {
      NyxPrintToChat(client, "%t", "Item Doesn't Exist", "heal");
      return Plugin_Handled;
    }

    if (CanBuy(client, storage)) {
      BuyItem(client, client, storage);
    }
  }

  return Plugin_Handled;
}

public Action ConCmd_BuyAgain(int client, int args) {
  if (IsValidClient(client)) {
    Player player = new Player(client);
    char buffer[256]; player.GetLastItem(buffer, sizeof(buffer));
    if (strlen(buffer) == 0) {
      NyxPrintToChat(client, "%t", "Bought Nothing");
      return Plugin_Handled;
    }

    any storage[eCatalog];
    if (!FindItem(buffer, storage)) {
      NyxPrintToChat(client, "%t", "Item Doesn't Exist", buffer);
      return Plugin_Handled;
    }

    if (CanBuy(client, storage)) {
      BuyItem(client, client, storage);
    }
  }

  return Plugin_Handled;
}

/***
 *        __  ___                     
 *       /  |/  /__  ____  __  _______
 *      / /|_/ / _ \/ __ \/ / / / ___/
 *     / /  / /  __/ / / / /_/ (__  ) 
 *    /_/  /_/\___/_/ /_/\__,_/____/  
 *                                    
 */

void Display_ConfirmMenu(int client, const char[] info) {
  Menu menu = new Menu(MenuHandler_ConfirmMenu);
  
  char title[32];
  any storage[eCatalog]; GetItemData(info, storage);
  Format(title, sizeof(title), "Cost: %i", storage[Catalog_Cost]);
  menu.SetTitle(title);

  menu.AddItem(info, "Yes");
  menu.AddItem("no", "No");
  menu.ExitBackButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

void Display_GivePointsMenu(int client) {
  Menu menu = new Menu(MenuHandler_GivePoints);
  menu.SetTitle("Select Target");
  menu.ExitBackButton = true;
  AddTeamToMenu(menu, client);
  menu.Display(client, MENU_TIME_FOREVER);
}

void Display_GiveAmountMenu(int client) {
  Menu menu = new Menu(MenuHandler_GiveAmount);
  menu.SetTitle("Select Amount");
  menu.ExitBackButton = true;

  Player player = new Player(client);
  int points = player.Points;

  if (points >= 10) menu.AddItem("10", "10 Points");
  if (points >= 20) menu.AddItem("20", "20 Points");
  if (points >= 30) menu.AddItem("30", "30 Points");

  char info[16], display[64];
  IntToString(points / 2, info, sizeof(info));
  Format(display, sizeof(display), "%d Points (half)", points / 2);
  menu.AddItem(info, display);

  IntToString(points, info, sizeof(info));
  Format(display, sizeof(display), "%d Points (all)", points);
  menu.AddItem(info, display);

  menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ConfirmMenu(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_End) {
    delete menu;
  } else if (action == MenuAction_Cancel) {
    if (param2 == MenuCancel_ExitBack) {
      if (IsValidClient(param1)) {
        //Display_MainMenu(param1);
      }
    }

    return;
  } else if (action == MenuAction_Select) {
    char info[32];
    menu.GetItem(param2, info, sizeof(info));

    if (IsValidClient(param1) && !StrEqual(info, "no", false)) {
      any storage[eCatalog];
      if (!FindItem(info, storage)) {
        NyxPrintToChat(param1, "%t", "Item Doesn't Exist", info);
        return;
      }

      if (CanBuy(param1, storage)) {
        BuyItem(param1, param1, storage);
      }
    }
  }

  return;
}

public int MenuHandler_GivePoints(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_End) {
    delete menu;
  } else if (action == MenuAction_Cancel) {
    if (param2 == MenuCancel_ExitBack) {
      if (IsValidClient(param1)) {
        Display_GivePointsMenu(param1);
      }
    }

    return;
  } else if (action == MenuAction_Select) {
    char info[32];
    menu.GetItem(param2, info, sizeof(info));
    int userid = StringToInt(info);

    if (GetClientOfUserId(userid) == 0) {
      NyxPrintToChat(param1, "%t", "Player no longer available");
    } else {
      g_iMenuTarget[param1] = userid;
      Display_GiveAmountMenu(param1);
      return;
    }
    
    if (IsValidClient(param1)) {
      Display_GivePointsMenu(param1);
    }
  }
  
  return;
}

public int MenuHandler_GiveAmount(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_End) {
    delete menu;
  } else if (action == MenuAction_Cancel) {
    if (param2 == MenuCancel_ExitBack) {
      if (IsValidClient(param1)) {
        Display_GivePointsMenu(param1);
      }
    }

    return;
  } else if (action == MenuAction_Select) {
    char info[32];
    menu.GetItem(param2, info, sizeof(info));
    int amount = StringToInt(info);

    int target;
    if ((target = GetClientOfUserId(g_iMenuTarget[param1])) == 0) {
      NyxPrintToChat(param1, "%t", "Player no longer available");
    } else {
      Player player = new Player(param1);
      if (player.Points < amount) {
        NyxPrintToChat(param1, "%t", "Insufficient Points", amount);
      } else {
        int spent = (new Player(target)).GivePoints(amount);
        player.Points -= spent;
        
        NyxPrintToTeam(GetClientTeam(param1), "%t", "Sent Points", param1, spent, target);
        NyxPrintToChat(param1, "%t", "Points Left", player.Points);

        if (spent == 0) {
          NyxPrintToChat(param1, "%t", "Sent Zero Points");
        }
      }
    }
    
    if (IsValidClient(param1)) {
      Display_GivePointsMenu(param1);
    }
  }
  
  return;
}

stock int AddTeamToMenu(Menu menu, int client) {
  char user_id[12];
  char name[MAX_NAME_LENGTH];
  char display[MAX_NAME_LENGTH + 12];
  
  int num_clients;
  
  for (int i = 1; i <= MaxClients; i++) {
    if (!IsValidClient(i)) continue;
    if (i == client) continue;
    if (GetClientTeam(i) != GetClientTeam(client)) continue;

    IntToString(GetClientUserId(i), user_id, sizeof(user_id));
    GetClientName(i, name, sizeof(name));
    Format(display, sizeof(display), "%s", name);
    menu.AddItem(user_id, display);

    num_clients++;
  }
  
  return num_clients;
}

/***
 *        ______                 __  _                 
 *       / ____/_  ______  _____/ /_(_)___  ____  _____
 *      / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
 *     / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  ) 
 *    /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/  
 *                                                     
 */

bool CanBuy(int client, any[eCatalog] storage) {
  Player player = new Player(client);

  if (player.Points < storage[Catalog_Cost]) {
    if (g_hConVars[ConVar_AnnounceNeeds].BoolValue) {
      NyxPrintToTeam(GetClientTeam(client), "%t", "Insufficient Funds Announce", 
          client, storage[Catalog_Cost] - player.Points, storage[Catalog_Name]);
    } else {
      NyxPrintToChat(client, "%t", "Insufficient Funds",
          storage[Catalog_Cost] - player.Points, storage[Catalog_Name]);
    }

    return false;
  } else if (!StrEqual(storage[Catalog_Team], "both", false)) {
    if (GetClientTeam(client) != L4D2_StringToTeam(storage[Catalog_Team])) {
      NyxPrintToChat(client, "%t", "Item Wrong Team");
      return false;
    }
  } else if (!IsPlayerAlive(client)) {
    if (IsPlayerSurvivor(client)) {
      NyxPrintToChat(client, "%t", "Must Be Alive");
      return false;
    }
  } else if (!IsPlayerIncapacitated(client) && storage[Catalog_MustBeIncapacitated]) {
    if (IsPlayerSurvivor(client)) {
      NyxPrintToChat(client, "%t", "Must Be Incapacitated");
      return false;
    }
  } else if (storage[Catalog_Limit] > 0) {
    if (g_iSpawnCount[L4D2_StringToClass(storage[Catalog_Category])] >= storage[Catalog_Limit]) {
      NyxPrintToChat(client, "%t", "Spawn Limit Reached", storage[Catalog_Name]);
      return false;
    }
  } else if (StrEqual(storage[Catalog_Category], "health", false)) {
    if (IsPlayerGrabbed(client)) {
      if (L4D2_GetClientTeam(client) == L4D2Team_Survivor) {
        NyxPrintToChat(client, "%t", "Must Not Be Grabbed");
        return false;
      }
    } else if (!IsPlayerIncapacitated(client)) {
      if (GetEntProp(client, Prop_Data, "m_iHealth") >= GetEntProp(client, Prop_Data, "m_iMaxHealth")) {
        NyxPrintToChat(client, "%t", "Health is Full");
        return false;
      }
    } else if (IsPlayerTank(client)) {
      // tank death loop fix
      if (GetEntProp(client, Prop_Send, "m_nSequence") >= 65) { // start of tank death animation 67-77
        NyxPrintToChat(client, "%t", "Must Be Alive");
        return false;
      }

      if (g_hConVars[ConVar_TankHealLimit].IntValue > 0) {
        if (player.HealCount + 1 > g_hConVars[ConVar_TankHealLimit].IntValue) {
          NyxPrintToChat(client, "%t", "Heal Limit Reached");
          return false;
        }

        NyxPrintToTeam(GetClientTeam(client), "%t", "Tank Heal Limit", client,
            player.HealCount + 1,
            g_hConVars[ConVar_TankHealLimit].IntValue);
      }
    }
  } else if (StrEqual(storage[Catalog_Category], "tank", false)) {
    if (g_bFinal && !g_hConVars[ConVar_TankAllowedFinal].BoolValue) {
      NyxPrintToChat(client, "%t", "Tank Not Allowed in Final");
      return false;
    }

    if (!g_bTankAllowed) {
      int timeLeft = g_hConVars[ConVar_TankDelay].IntValue - g_iStartTimePassed;
      int minutes = timeLeft / 60;
      int seconds = timeLeft % 60;

      if (minutes) {
        NyxPrintToChat(client, "%t", "Tank Allowed in Minutes", minutes);
      } else {
        NyxPrintToChat(client, "%t", "Tank Allowed in Seconds", seconds);
      }

      return false;
    }
  }

  return true;
}

void BuyItem(int buyer, int receiver, any[eCatalog] storage) {
  Player player = new Player(buyer);

  if (strlen(storage[Catalog_CommandArgs]) == 0) {
    strcopy(storage[Catalog_CommandArgs], sizeof(storage[Catalog_CommandArgs]), storage[Catalog_Item]);
  }
  FakeClientCommandCheat(receiver, "%s %s", storage[Catalog_Command], storage[Catalog_CommandArgs]);
  player.Points -= storage[Catalog_Cost];
  player.SetLastItem(storage[Catalog_Item]);

  if (StrEqual(storage[Catalog_Category], "infected", false)) {
    if (storage[Catalog_Announce]) {
      NyxPrintToAll("%t", "Announce Special Infected Purchase", buyer, storage[Catalog_Name]);
    }

    L4D2ClassType class = L4D2_StringToClass(storage[Catalog_Category]);
    if (class != L4D2Class_Unknown) {
      g_iSpawnCount[class]++;
    }
  }
  
  if (StrEqual(storage[Catalog_Category], "health", false)) {
    player.HealCount++;
  }
}
