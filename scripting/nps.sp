#pragma semicolon 1
#include <sourcemod>
#include <clientprefs>
#include <left4downtown>
#include <colors>

#define NYX_DEBUG          1
#define NYX_PLUGIN_TAG    "PS"
#include <nyxtools>
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

KeyValues g_hConfig;

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

public void OnPluginStart() {
  NyxMsgDebug("OnPluginStart");

  LoadTranslations("common.phrases");
  LoadTranslations("nyx_pointsystem.phrases");

  // Console Commands
  RegConsoleCmd("sm_buy", ConCmd_Buy);
  RegConsoleCmd("sm_gp", ConCmd_GivePoints);
  RegConsoleCmd("sm_points", ConCmd_ShowPoints);
  RegConsoleCmd("sm_tp", ConCmd_ShowTeamPoints);
  RegConsoleCmd("sm_heal", ConCmd_Heal);
  RegConsoleCmd("sm_rebuy", ConCmd_BuyAgain);

  // Admin commands
  RegAdminCmd("sm_setpoints", AdmCmd_SetPoints, ADMFLAG_ROOT, "nyx_givepoints <#userid|name> <points>");
  RegAdminCmd("nyx_debugbuy", AdmCmd_DebugBuy, ADMFLAG_ROOT);

  // ConVars
  g_hConVars[ConVar_StartPoints] = CreateConVar("nyx_ps_start_points", "10", "Starting player points.");
  g_hConVars[ConVar_TankHealLimit] = CreateConVar("nyx_ps_tank_heal_limit", "3", "Maximum number of times the tank can heal in a life.");
  g_hConVars[ConVar_TankDelay] = CreateConVar("nyx_ps_tank_delay", "90", "Time (in seconds) to delay tank spawning after survivors leave the safe area.");
  g_hConVars[ConVar_TankAllowedFinal] = CreateConVar("nyx_ps_tank_allowed_final", "0", "Tank allowed in final?", _, true, 0.0, true, 1.0);
  g_hConVars[ConVar_AnnounceNeeds] = CreateConVar("nyx_ps_announce_needs", "1", "Announce when a player tries to buy with insufficient funds.", _, true, 0.0, true, 1.0);
  g_hConVars[ConVar_TopOff] = CreateConVar("nyx_ps_topoff", "1", "Top off players with less than the minimal starting points at the start of a round.", _, true, 0.0, true, 1.0);
}

public void OnMapStart() {
  NyxMsgDebug("OnMapStart, Final %b", L4D_IsMissionFinalMap());

  char map[PLATFORM_MAX_PATH];
  GetCurrentMap(map, sizeof(map));
  if (StrContains(map, "m1_") != -1) {
    for (int i = 1; i <= MaxClients; i++) {
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
    SetClientPoints(target_list[i], points);
    LogAction(client, target_list[i], "\"%L\" gave \"%i\" points to \"%L\"", client, points, target_list[i]);
  }
  NyxAct(client, "Gave %i points to %s", points, target_name);

  return Plugin_Handled;
}

public Action AdmCmd_DebugBuy(int client, int args) {
  if (args < 1) {
    NyxMsgReply(client, "Usage: nyx_debugbuy <item_name>");
    return Plugin_Handled;
  }

  char item_name[32];
  GetCmdArg(1, item_name, sizeof(item_name));

  any data[NyxBuy];
  if (GetItemData(item_name, data)) {
    NyxMsgDebug("Group: %s, Section: %s, Name: %s, Cost %i",
        data[Buy_Group],
        data[Buy_Section],
        data[Buy_Name],
        data[Buy_Cost]);
    NyxMsgDebug("Shortcut: %s, Command: %s, CommandArgs: %s, TeamName: %s",
        data[Buy_Shortcut],
        data[Buy_Command],
        data[Buy_CommandArgs],
        data[Buy_TeamName]);
    NyxMsgDebug("MustBeIncapacitated: %i, SpawnLimit: %i, Announce: %i",
        data[Buy_MustBeIncapacitated],
        data[Buy_SpawnLimit],
        data[Buy_Announce]);
  } else {
    NyxMsgReply(client, "%t", "Item Doesn't Exist", item_name);
  }

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
    } else if (GetClientPoints(client) <= 0) {
      NyxPrintToChat(client, "%t", "No Points");
    } else {
      Display_MainMenu(client);
    }

    return Plugin_Handled;
  }

  char item_name[32];
  GetCmdArg(1, item_name, sizeof(item_name));

  any data[NyxBuy];
  if (!GetItemData(item_name, data)) {
    NyxPrintToChat(client, "%t", "Item Doesn't Exist", item_name);
    return Plugin_Handled;
  }

  if (!CanBuy(client, data)) {
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

      BuyItem(client, target, data);
      NyxPrintToTeam(GetClientTeam(client), "%t", "Bought Something For", client, data[Buy_Name], target);
    } else {
      BuyItem(client, client, data);
    }
  } else {
    BuyItem(client, client, data);
  }

  return Plugin_Handled;
}

public Action ConCmd_GivePoints(int client, int args) {
  if (args < 1) {
    if (!IsValidClient(client)) {
      NyxMsgReply(client, "Cannot display buy menu to console");
    } else if (GetClientPoints(client) <= 0) {
      NyxPrintToChat(client, "%t", "No Points");
    } else {
      Display_GivePointsMenu(client);
    }

    return Plugin_Handled;
  }

  int target = GetCmdTarget(1, client, false, false);
  int amount = GetCmdIntEx(2, 1, g_hConVars[ConVar_MaxPoints].IntValue, 5);

  if (client == target) {
    NyxPrintToChat(client, "%t", "Sent Self Points");
  } else if (GetClientTeam(client) != GetClientTeam(target)) {
    NyxPrintToChat(client, "%t", "Sent Wrong Team Points");
  } else {
    int points = GetClientPoints(client);
    if (amount > points) {
      amount = points;
    }

    int spent = GiveClientPoints(target, amount);
    if (spent == 0) {
      NyxPrintToChat(client, "%t", "Sent Zero Points");
      return Plugin_Handled;
    }

    SubClientPoints(client, spent);
    NyxPrintToTeam(GetClientTeam(client), "%t", "Sent Points", client, spent, target);
    NyxPrintToChat(client, "%t", "Points Left", GetClientPoints(client));

  }

  return Plugin_Handled;
}

public Action ConCmd_ShowPoints(int client, int args) {
  if (IsValidClient(client)) {
    NyxPrintToChat(client, "%t", "Show Points", GetClientPoints(client));
  }

  return Plugin_Handled;
}

public Action ConCmd_ShowTeamPoints(int client, int args) {
  for (int i = 1; i <= MaxClients; i++) {
    if (!IsValidClient(i)) continue;
    if (GetClientTeam(i) != GetClientTeam(client)) continue;
    if (i == client) {
      NyxPrintToChat(client, "%t", "Show Points", GetClientPoints(client));
      continue;
    }

    NyxPrintToChat(client, "%t", "Show Points Other", i, GetClientPoints(i));
  }
  return Plugin_Handled;
}

public Action ConCmd_Heal(int client, int args) {
  if (IsValidClient(client)) {
    any data[NyxBuy];
    if (!GetItemData("heal", data)) {
      NyxPrintToChat(client, "%t", "Item Doesn't Exist", "heal");
      return Plugin_Handled;
    }

    if (CanBuy(client, data)) {
      BuyItem(client, client, data);
    }
  }

  return Plugin_Handled;
}

public Action ConCmd_BuyAgain(int client, int args) {
  if (IsValidClient(client)) {
    char buffer[256]; strcopy(buffer, sizeof(buffer), g_aPlayerStorage[client][Player_LastItem]);
    if (strlen(buffer) == 0) {
      NyxPrintToChat(client, "%t", "Bought Nothing");
      return Plugin_Handled;
    }

    any data[NyxBuy];
    if (!GetItemData(buffer, data)) {
      NyxPrintToChat(client, "%t", "Item Doesn't Exist", buffer);
      return Plugin_Handled;
    }

    if (CanBuy(client, data)) {
      BuyItem(client, client, data);
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
  any data[NyxBuy]; GetItemData(info, data);
  Format(title, sizeof(title), "Cost: %i", data[Buy_Cost]);
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

  int points = GetClientPoints(client);

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
        Display_MainMenu(param1);
      }
    }

    return;
  } else if (action == MenuAction_Select) {
    char info[32];
    menu.GetItem(param2, info, sizeof(info));

    if (IsValidClient(param1) && !StrEqual(info, "no", false)) {
      any data[NyxBuy];
      if (!GetItemData(info, data)) {
        NyxPrintToChat(param1, "%t", "Item Doesn't Exist", info);
        return;
      }

      if (CanBuy(param1, data)) {
        BuyItem(param1, param1, data);
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
      if (GetClientPoints(param1) < amount) {
        NyxPrintToChat(param1, "%t", "Insufficient Points", amount);
      } else {
        int spent = GiveClientPoints(target, amount);

        SubClientPoints(param1, spent);
        NyxPrintToTeam(GetClientTeam(param1), "%t", "Sent Points", param1, spent, target);
        NyxPrintToChat(param1, "%t", "Points Left", GetClientPoints(param1));

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

bool CanBuy(int client, any[NyxBuy] data) {
  if (GetClientPoints(client) < data[Buy_Cost]) {
    if (g_hConVars[ConVar_AnnounceNeeds].BoolValue) {
      NyxPrintToTeam(GetClientTeam(client), "%t", "Insufficient Funds Announce", 
          client, data[Buy_Cost] - GetClientPoints(client), data[Buy_Name]);
    } else {
      NyxPrintToChat(client, "%t", "Insufficient Funds",
          data[Buy_Cost] - GetClientPoints(client), data[Buy_Name]);
    }

    return false;
  } else if (!StrEqual(data[Buy_TeamName], "both", false)) {
    if (GetClientTeam(client) != L4D2_StringToTeam(data[Buy_TeamName])) {
      NyxPrintToChat(client, "%t", "Item Wrong Team");
      return false;
    }
  } else if (!IsPlayerAlive(client)) {
    if (IsPlayerSurvivor(client)) {
      NyxPrintToChat(client, "%t", "Must Be Alive");
      return false;
    }
  } else if (!IsPlayerIncapacitated(client) && data[Buy_MustBeIncapacitated]) {
    if (IsPlayerSurvivor(client)) {
      NyxPrintToChat(client, "%t", "Must Be Incapacitated");
      return false;
    }
  } else if (data[Buy_SpawnLimit] > 0) {
    if (g_iSpawnCount[L4D2_StringToClass(data[Buy_Section])] >= data[Buy_SpawnLimit]) {
      NyxPrintToChat(client, "%t", "Spawn Limit Reached", data[Buy_Name]);
      return false;
    }
  } else if (StrEqual(data[Buy_Section], "health", false)) {
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
        if (g_aPlayerStorage[client][Player_HealCount] + 1 > g_hConVars[ConVar_TankHealLimit].IntValue) {
          NyxPrintToChat(client, "%t", "Heal Limit Reached");
          return false;
        }

        NyxPrintToTeam(GetClientTeam(client), "%t", "Tank Heal Limit", client,
            g_aPlayerStorage[client][Player_HealCount] + 1,
            g_hConVars[ConVar_TankHealLimit].IntValue);
      }
    }
  } else if (StrEqual(data[Buy_Section], "tank", false)) {
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

void BuyItem(int buyer, int receiver, any[NyxBuy] data) {
  char command_args[256];
  Format(command_args, sizeof(command_args), "%s %s", data[Buy_Section], data[Buy_CommandArgs]);
  FakeClientCommandCheat(receiver, data[Buy_Command], command_args);
  SubClientPoints(buyer, data[Buy_Cost]);

  strcopy(g_aPlayerStorage[buyer][Player_LastItem], 64, data[Buy_Section]);
  if (StrEqual(data[Buy_Group], "infected", false)) {
    if (data[Buy_Announce]) {
      NyxPrintToAll("%t", "Announce Special Infected Purchase", buyer, data[Buy_Name]);
    }

    L4D2ClassType class = L4D2_StringToClass(data[Buy_Section]);
    if (class != L4D2Class_Unknown) {
      g_iSpawnCount[class]++;
    }
  }
  
  if (StrEqual(data[Buy_Section], "health", false)) {
    g_aPlayerStorage[receiver][Player_HealCount]++;
  }
}
