#pragma semicolon 1
#include <sourcemod>
#include <clientprefs>
#include <colors>

#define NYXTOOLS_DEBUG 0
#define NYXTOOLS_TAG "PS"
#define USE_DELAY_SECONDS 2
#include <nyxtools>
#include <nyxtools_cheats>
#include <nyxtools_l4d2>
#include <nps_stocks>
#include <nps_catalog>
#include <nps_storage>

#pragma newdecls required

public Plugin myinfo = {
  name = "NPS - Core",
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

enum NyxConVar {
  ConVar:ConVar_StartPoints,
  ConVar:ConVar_MaxPoints,
  ConVar:ConVar_TankHealLimit,
  ConVar:ConVar_TankDelay,
  ConVar:ConVar_TankAllowedFinal,
  ConVar:ConVar_AnnounceNeeds,
  ConVar:ConVar_Charity,
  ConVar:ConVar_Restore,
  ConVar:ConVar_Msg,
  ConVar:ConVar_RqTeam
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

 bool g_bLateLoad;

int g_iMenuTarget[MAXPLAYERS + 1];
int g_iSpawnCount[L4D2ClassType];

bool g_bTankAllowed;

int g_iStartTime;
int g_iStartTimePassed;

int g_iTimeCmd[MAXPLAYERS + 1];
int g_iLastCmd[MAXPLAYERS + 1];
int g_iTickDelay;
StringMap g_mRestore;
Handle g_fwdOnBuyZombie;
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
  g_bLateLoad = late;

  return APLRes_Success;
}

public void OnPluginStart() {
  NyxMsgDebug("OnPluginStart");
  // 3d party plugin bugfixes
  g_fwdOnBuyZombie = CreateGlobalForward("NPS_OnPlayerBuyZombie", ET_Ignore, Param_Cell);
  LoadTranslations("common.phrases");
  LoadTranslations("nps_core.phrases");

  // Console Commands
  RegConsoleCmd("sm_buy", ConCmd_Buy);
  RegConsoleCmd("sm_rebuy", ConCmd_BuyAgain);
  RegConsoleCmd("sm_givepoints", ConCmd_GivePoints);
  RegConsoleCmd("sm_gp", ConCmd_GivePoints);
  RegConsoleCmd("sm_points", ConCmd_ShowPoints);
  RegConsoleCmd("sm_sp", ConCmd_ShowPoints);
  RegConsoleCmd("sm_tp", ConCmd_ShowTeamPoints);
  RegConsoleCmd("sm_heal", ConCmd_Heal);
  RegConsoleCmd("sm_rp", ConCmd_RequestPoints);
  RegConsoleCmd("sm_theal", ConCmd_TeamHeal);

  // Admin commands
  RegAdminCmd("sm_setpoints", AdmCmd_SetPoints, ADMFLAG_ROOT, "Usage: sm_setpoints <#userid|name> <points>");

  // ConVars
  g_hConVars[ConVar_MaxPoints] = CreateConVar("nps_max_points", "120", "Max player points.");
  g_hConVars[ConVar_StartPoints] = CreateConVar("nps_start_points", "10", "Starting player points.");
  g_hConVars[ConVar_TankHealLimit] = CreateConVar("nps_tank_heal_limit", "3", "Maximum number of times the tank can heal in a life.");
  g_hConVars[ConVar_TankDelay] = CreateConVar("nps_tank_start_delay", "90", "Time (in seconds) to delay tank spawning after survivors leave the safe area.");
  g_hConVars[ConVar_TankAllowedFinal] = CreateConVar("nps_tank_allowed_final", "0", "Tank allowed on the final map?", _, true, 0.0, true, 1.0);
  g_hConVars[ConVar_AnnounceNeeds] = CreateConVar("nps_announce_needs", "1", "Announce when a player tries to buy with insufficient funds.", _, true, 0.0, true, 1.0);
  g_hConVars[ConVar_Charity] = CreateConVar("nps_charity", "1", "Give players with less than the minimal starting points at the start of a round some points?", _, true, 0.0, true, 1.0);
  g_hConVars[ConVar_Restore] = CreateConVar("nps_restore", "120", "Restore players points if they disconnect and reconnect within X seconds. 0 = disable", _, true, 0.0);
  g_hConVars[ConVar_Msg] = CreateConVar("nps_msg", "10", "Chat message delay in seconds. 0 = disable", _, true, 0.0);
  g_hConVars[ConVar_RqTeam] = CreateConVar("nps_request_points_team", "1", "0=disable, 1=Request points for only team players, 2=Request points for both teams.", _, true, 0.0, true, 2.0);

  HookEvent("player_disconnect", Event_PlayerDisconnect);
  HookEvent("round_start", Event_RoundStart);
  HookEvent("player_spawn", Event_PlayerSpawn);
  HookEvent("player_incapacitated", Event_PlayerIncapacitated);
  HookEvent("player_bot_replace", Event_PlayerBotReplace);
  HookEvent("bot_player_replace", Event_BotPlayerReplace);

  g_mRestore = new StringMap();
  g_iTickDelay = RoundToNearest(1.0 / GetTickInterval() * USE_DELAY_SECONDS);
}

public void OnMapStart() {
  NyxMsgDebug("OnMapStart, Final %d", L4D2_IsMissionFinalMap());
  NyxMsgDebug("IsMissionStartMap %d", L4D2_IsMissionStartMap());
  if (L4D2_IsMissionStartMap()) {
    if (!g_bLateLoad) {
      ResetPlayerStorage();
      g_mRestore.Clear();
    }
  }
  for (int i = 0; i < view_as<int>(L4D2ClassType); i++) {
    g_iSpawnCount[i] = 0;
  }
  for (int i = 1; i <= MaxClients; i++) {
    g_iLastCmd[i] = 0;
  }

  g_iStartTime = 0;
  g_bTankAllowed = (g_hConVars[ConVar_TankDelay].IntValue == 0);
  g_bLateLoad = false;
}

public void OnClientPutInServer(int client) {
  if (!client) return;
  Player player = new Player(client);
  player.WasTank = false;

  if (player.UserID != GetClientUserId(client)) {
    player.SetDefaults(GetClientUserId(client));
    NyxMsgDebug("SetDefaults(%N %d)",client, client);
    if (IsFakeClient(client) || !g_hConVars[ConVar_Restore].IntValue) return;

    int data[2];
    char sTemp[64];
    GetClientAuthId(client, AuthId_Steam3, sTemp, sizeof(sTemp));

    if (g_mRestore.GetArray(sTemp, data, 2) && (GetTime() - data[1]) <= g_hConVars[ConVar_Restore].IntValue){
        NyxMsgDebug("RESTORED: %d %d", data[0], data[1]);
        (new Player(client)).Points = data[0];
        if (g_hConVars[ConVar_Msg].FloatValue)
            CreateTimer(g_hConVars[ConVar_Msg].FloatValue, TimerMsg, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
  }
}

public Action TimerMsg(Handle timer, int userId)
{
    userId = GetClientOfUserId(userId);
    if (userId && IsClientInGame(userId))
        PrintToChat(userId, "%t", "Points Restore");
}

public void OnGameFrame() {
  if (!g_bTankAllowed && g_iStartTime > 0) {
    g_iStartTimePassed = GetTime() - g_iStartTime;

    if (g_iStartTimePassed >= g_hConVars[ConVar_TankDelay].IntValue) {
      g_bTankAllowed = true;
    }
  }
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3],
    float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
  if (!IsValidClient(client, true)) return Plugin_Continue;

  if (buttons & IN_USE) {
    g_iTimeCmd[client] = tickcount;
    if (g_iTimeCmd[client] > g_iLastCmd[client]) {
      g_iLastCmd[client] = g_iTimeCmd[client] + g_iTickDelay;
    } else {
      return Plugin_Continue;
    }

    if (IsPlayerSurvivor(client)) {
      if (IsPlayerGrabbed(client)) return Plugin_Continue;
      if (!IsPlayerIncapacitated(client)) return Plugin_Continue;

      FakeClientCommandEx(client, "sm_buy %s", "heal"); // I'm so laze u.u
    } else {
      if (!IsPlayerTank(client) || IsPlayerIncapacitated(client) || !IsPlayerAlive(client)) return Plugin_Continue;

      FakeClientCommandEx(client, "sm_buy %s", "heal");
    }
  }

  return Plugin_Continue;
}

/***
 *        ____      __            ____
 *       /  _/___  / /____  _____/ __/___ _________  _____
 *       / // __ \/ __/ _ \/ ___/ /_/ __ `/ ___/ _ \/ ___/
 *     _/ // / / / /_/  __/ /  / __/ /_/ / /__/  __(__  )
 *    /___/_/ /_/\__/\___/_/  /_/  \__,_/\___/\___/____/
 *
 */

public Action L4D2_OnFirstSurvivorLeftSafeArea(int client) {
  if (g_hConVars[ConVar_TankDelay].IntValue == 0) {
    g_bTankAllowed = true;
  } else {
    g_iStartTime = GetTime();
  }

  return Plugin_Continue;
}

public Action L4D2_OnReplaceTank(int tank, int new_tank) {
  NyxMsgDebug("L4D_OnReplaceTank(tank: %d %N, newtank: %d %N)", tank, tank, new_tank, new_tank);
  if (tank != new_tank){
    Player player = new Player(tank);
    NyxMsgDebug("Player(%N, HealCount %d).TransferHealCount(%N)", tank, player.HealCount, new_tank);
    player.TransferHealCount(new Player(new_tank));
  }

  return Plugin_Continue;
}

/***
 *        ______                 __
 *       / ____/   _____  ____  / /______
 *      / __/ | | / / _ \/ __ \/ __/ ___/
 *     / /___ | |/ /  __/ / / / /_(__  )
 *    /_____/ |___/\___/_/ /_/\__/____/
 *
 */
public void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
  int bot = GetClientOfUserId(event.GetInt("bot"));
  if (!bot || GetEntProp(bot, Prop_Send, "m_zombieClass") != 8) return;
  int client = GetClientOfUserId(event.GetInt("player"));
  if (!client) return;

  NyxMsgDebug("Event_BotPlayerReplace(bot: %d %N, client: %d %N)", bot, bot, client, client);

  Player player = new Player(bot);
  if (player.WasTank) {
    NyxMsgDebug("Player(%N).TransferHealCount(%N)", bot, client);
    player.WasTank = false;
    Player tank = new Player(client);
    tank.WasTank = true;
    player.TransferHealCount(tank);
  }
  else
  (new Player(client)).HealCount = 0; // director tank
}

public void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("player"));
  if (!client || GetClientTeam(client) != 3 || !IsPlayerTank(client) || IsFakeClient(client)) return;
  int bot = GetClientOfUserId(event.GetInt("bot"));
  if (!client) return;
  Player player = new Player(client);
  NyxMsgDebug("Event_PlayerBotReplace(%d %N, %d %N, HealCount %d)", client, client, bot, bot, player.HealCount);

  if (player.HealCount){
    Player playerBot = new Player(bot);
    playerBot.WasTank = true;
    playerBot.HealCount = player.HealCount;
    player.HealCount = 0;
  }
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
  NyxMsgDebug("Event_RoundStart");
  ResetPlayerStorage(true);
  g_iStartTime = 0;
  g_bTankAllowed = (g_hConVars[ConVar_TankDelay].IntValue == 0);

  for (int i = 0; i < view_as<int>(L4D2ClassType); i++) {
    g_iSpawnCount[i] = 0;
  }
  if (g_hConVars[ConVar_Charity].BoolValue) {
    for (int i = 1; i <= MaxClients; i++) {
      if (!IsValidClient(i)) continue;

      Player player = new Player(i);
      if (player.Points < g_hConVars[ConVar_StartPoints].IntValue) {
        player.Points = g_hConVars[ConVar_StartPoints].IntValue;
      }
    }
  }

  return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (!IsPlayerTank(client)) return Plugin_Continue;
  if (IsFakeClient(client)) return Plugin_Continue;

  DisplayInstructorHint(client, "As tank you can heal by pressing the USE key", "icon_button");

  return Plugin_Continue;
}

public Action Event_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast) {
  int victim = GetClientOfUserId(event.GetInt("userid"));
  if (!IsPlayerSurvivor(victim)) return Plugin_Continue;
  if (IsFakeClient(victim)) return Plugin_Continue;

  DisplayInstructorHint(victim, "You can heal while you're down with the USE key", "icon_button");

  return Plugin_Continue;
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (!client || IsFakeClient(client)) return;
  char sTemp[32];
  GetClientAuthId(client, AuthId_Steam3, sTemp, sizeof(sTemp));
  Player player = new Player(client);
  int data[2];
  data[0] = player.Points;
  data[1] = GetTime();
  g_mRestore.SetArray(sTemp, data, 2);
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
      return Plugin_Handled;
    }

    FakeClientCommandEx(client, "sm_buymenu");
    return Plugin_Handled;
  }

  char search[32];
  GetCmdArgString(search, sizeof(search));

  any item[eCatalog];
  if (!FindClientItem(client, search, item)) {
    NyxPrintToChat(client, "%t", "Item Doesn't Exist", search);
    return Plugin_Handled;
  }

  if (!CanBuy(client, item)) {
    return Plugin_Handled;
  }

  if (IsPlayerInfected(client)) {
    L4D2ClassType class = L4D2_StringToClass(item[Catalog_Item]);

    if (class != L4D2Class_Witch && class != L4D2Class_Unknown) {
      if (IsPlayerAlive(client)) {
        if (IsPlayerGhost(client)) {
          if (SpawnZombiePurchase(client, class)) {
            BuyItem(client, client, item, true);
          }

          return Plugin_Handled;
        }
      } else {
        if (SpawnZombiePurchase(client, class)) {
          BuyItem(client, client, item, true);
        }

        return Plugin_Handled;
      }
    }
    else if (StrEqual(item[Catalog_Item], "extinguish")){
      BuyItem(client, client, item, true);
      return Plugin_Handled;
    }
    else {
      BuyItem(client, client, item);
      return Plugin_Handled;
    }

    int target = client;
    if (args < 2) {
      int playerCount, playerList[MAXPLAYERS + 1];
      for (int i = 1; i <= MaxClients; i++) {
        if (!IsValidClient(i, true)) continue;
        if (!IsPlayerInfected(i)) continue;
        if (client == i) continue;

        playerList[playerCount++] = i;
      }

      if (playerCount) {
        target = playerList[GetRandomInt(0, playerCount - 1)];
      }
    } else {
      target = GetCmdTarget(2, client, false, false);
    }

    if (IsValidBuyTarget(target)) {
      if (SpawnZombiePurchase(target, class)) {
        BuyItem(client, target, item, true);
        NyxPrintToTeam(GetClientTeam(client), "%t", "Bought Something For Player", client, item[Catalog_Name], target);

        return Plugin_Handled;
      }
    }

    if (!L4D2_IsClassAllowed(class)) {
      NyxPrintToTeam(GetClientTeam(client), "%t", "Class Limit Reached", item[Catalog_Name]);
      return Plugin_Handled;
    }

    BuyItem(client, client, item);
    NyxPrintToTeam(GetClientTeam(client), "%t", "Spawned", client, item[Catalog_Name]);
    return Plugin_Handled;
  }

  BuyItem(client, client, item);
  return Plugin_Handled;
}

public Action ConCmd_RequestPoints(int client, int args) {
  if (g_hConVars[ConVar_RqTeam].IntValue && client && GetClientTeam(client) != 1){
    if (args == 2) {
      char target_name[MAX_TARGET_LENGTH], arg[65];
      int target_list[MAXPLAYERS], target_count;
      bool tn_is_ml;
      GetCmdArg(1, arg, sizeof(arg));

      if ((target_count = ProcessTargetString(
          arg,
          client,
          target_list,
          MAXPLAYERS,
          COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_NO_IMMUNITY,
          target_name,
          sizeof(target_name),
          tn_is_ml)) <= 0)
      {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
      }

      int target;
      int amount = GetCmdIntEx(2, 1, g_hConVars[ConVar_MaxPoints].IntValue, 5);

      for (int i; i < target_count; i++)
      {
        target = target_list[i];

        if (target != client && IsValidTeamForRequestPoints(client, target)){

          if ((new Player(target)).Points < amount)
            NyxPrintToChat(client, "%t", "Insufficient Player Points", target);
          else
            Display_ConfirmRequestPointsMenu(client, target, amount);
        }
      }
    }
    else
      Display_RequestPointsMenu(client);
  }
  return Plugin_Handled;
}

public Action ConCmd_GivePoints(int client, int args) {
  if (args == 2){
    char target_name[MAX_TARGET_LENGTH], arg[65];
    int target_list[MAXPLAYERS], target_count;
    bool tn_is_ml;
    GetCmdArg(1, arg, sizeof(arg));

    if ((target_count = ProcessTargetString(
        arg,
        client,
        target_list,
        MAXPLAYERS,
        COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_NO_IMMUNITY,
        target_name,
        sizeof(target_name),
        tn_is_ml)) <= 0)
    {
      ReplyToTargetError(client, target_count);
      return Plugin_Handled;
    }

    int target;
    int amount = GetCmdIntEx(2, 1, g_hConVars[ConVar_MaxPoints].IntValue, 5);

    if (target_count == 1){
      target = target_list[0];
      if (client == target) {
        NyxPrintToChat(client, "%t", "Sent Self Points");
      } else if (GetClientTeam(client) != GetClientTeam(target)) {
        NyxPrintToChat(client, "%t", "Sent Wrong Team Points");
      }
      else {
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
    }
    else {
      int points, spent, team = GetClientTeam(client);
      Player player = new Player(client);
      bool bGive;
      for (int i; i < target_count; i++)
      {
        target = target_list[i];
        if (client == target || team != GetClientTeam(target)) continue;

        bGive = true;
        points = player.Points;
        if (amount > points) {
          amount = points;
        }

        spent = (new Player(target)).GivePoints(amount);
        if (spent == 0) {
          NyxPrintToChat(client, "%t", "Sent Zero Points");
          break;
        }

        player.Points -= spent;
        NyxPrintToTeam(team, "%t", "Sent Points", client, spent, target);
      }
      if (bGive)
        NyxPrintToChat(client, "%t", "Points Left", player.Points);
    }
  }
  else {
    if (!IsValidClient(client))
      NyxMsgReply(client, "Cannot display buy menu to console");
    else
      Display_GivePointsMenu(client);
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

public Action ConCmd_TeamHeal(int client, int args) {
  if (!IsValidClient(client))
    return Plugin_Handled;

  any item[eCatalog];
  if (!FindClientItem(client, "heal", item)) {
    NyxPrintToChat(client, "%t", "Item Doesn't Exist", "heal");
    return Plugin_Handled;
  }
  if (!CanAfford(client, item)){
    NyxPrintToChat(client, "%t", "Insufficient Points");
    return Plugin_Handled;
  }
  Display_TeamHealMenu(client);
  return Plugin_Handled;
}

public Action ConCmd_Heal(int client, int args) {
  int target = client;
  if (args == 1) {
    target = GetCmdTarget(1, client, false, false);
  }

  if (!IsValidClient(client))
    return Plugin_Handled;
  if (!IsValidClient(target)){
    NyxPrintToChat(client, "%t", "Player no longer available");
    return Plugin_Handled;
  }

  any item[eCatalog];
  if (!FindClientItem(client, "heal", item)) {
    NyxPrintToChat(client, "%t", "Item Doesn't Exist", "heal");
    return Plugin_Handled;
  }

  if (GetClientTeam(client) != GetClientTeam(target)) {
    NyxPrintToChat(client, "%t", "Heal Wrong Team");
    return Plugin_Handled;
  }

  char error[255];
  bool bCanAfford = CanAfford(client, item);
  if (bCanAfford && CanUse(target, item, error, sizeof(error))) {
    BuyItem(client, target, item);

    if (client != target) {
      NyxPrintToTeam(GetClientTeam(client), "%t", "Heal Other", client, target);
    }
  } else {
    if (client == target) {
    if (bCanAfford)
      NyxPrintToChat(client, error);
    else
      NyxPrintToChat(client, "%t", "Insufficient Points");
    } else {
      NyxPrintToChat(client, "%t", "Heal Other Failed", target);
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

    any item[eCatalog];
    if (!FindClientItem(client, buffer, item)) {
      NyxPrintToChat(client, "%t", "Item Doesn't Exist", buffer);
      return Plugin_Handled;
    }

    if (CanBuy(client, item)) {
      BuyItem(client, client, item);
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

void Display_GivePointsMenu(int client) {
  Menu menu = new Menu(MenuHandler_GivePoints);
  menu.SetTitle("Select Target");
  AddTeamToMenu(menu, client);
  menu.Display(client, MENU_TIME_FOREVER);
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
}

void Display_GiveAmountMenu(int client, int target = 0) {
  Menu menu = new Menu(target ? MenuHandler_RequestAmount : MenuHandler_GiveAmount);
  menu.SetTitle("Select Amount");
  menu.ExitBackButton = true;

  Player player = new Player(target ? target : client);
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

public int MenuHandler_GiveAmount(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_End) {
    delete menu;
  } else if (action == MenuAction_Cancel) {
    if (param2 == MenuCancel_ExitBack) {
      if (IsValidClient(param1)) {
        Display_GivePointsMenu(param1);
      }
    }
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
        NyxPrintToChat(param1, "%t", "Insufficient Points");
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
}

stock int AddTeamToMenu(Menu menu, int client, int excludeTeam = 0, bool pointsCheck = false, bool healCheck = false) {
  char user_id[12];
  char name[MAX_NAME_LENGTH];
  int num_clients, team;

  for (int i = 1; i <= MaxClients; i++) {
    if (!IsValidClient(i, !healCheck)) continue;
    if (!healCheck && i == client) continue;
    if (pointsCheck && (new Player(i)).Points <= 0) continue;
    team = GetClientTeam(i);

    if (excludeTeam){
      if (team == excludeTeam) continue;
    }
    else if (team != GetClientTeam(client)) continue;

    if (healCheck && (!IsPlayerAlive(i) || team == 2 && (IsPlayerGrabbed(i) || !IsPlayerIncapacitated(i)))) continue;

    IntToString(GetClientUserId(i), user_id, sizeof(user_id));
    GetClientName(i, name, sizeof(name));
    menu.AddItem(user_id, name);

    num_clients++;
  }

  return num_clients;
}

void Display_RequestPointsMenu(int client) {
  Menu menu = new Menu(MenuHandler_RequestPoints);
  menu.SetTitle("Select Target");
  AddTeamToMenu(menu, client, g_hConVars[ConVar_RqTeam].IntValue == 2 ? 1 : 0, true);
  menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_RequestPoints(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_End) {
    delete menu;
  } else if (action == MenuAction_Cancel) {
    if (param2 == MenuCancel_ExitBack) {
      if (IsValidClient(param1)) {
        Display_RequestPointsMenu(param1);
      }
    }
  } else if (action == MenuAction_Select) {
    char info[32];
    menu.GetItem(param2, info, sizeof(info));
    int userid = StringToInt(info);
    int target = GetClientOfUserId(userid);

    if (IsValidTeamForRequestPoints(param1, target)) {
      g_iMenuTarget[param1] = userid;
      Display_GiveAmountMenu(param1, target);
      return;
    } else {
      NyxPrintToChat(param1, "%t", "Player no longer available");
    }

    if (IsValidClient(param1)) {
      Display_RequestPointsMenu(param1);
    }
  }
}

public int MenuHandler_RequestAmount(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_End) {
    delete menu;
  } else if (action == MenuAction_Cancel) {
    if (param2 == MenuCancel_ExitBack) {
      if (IsValidClient(param1)) {
        Display_RequestPointsMenu(param1);
      }
    }
  } else if (action == MenuAction_Select) {
    int target = GetClientOfUserId(g_iMenuTarget[param1]);

    if (IsValidTeamForRequestPoints(param1, target)) {
      char info[32];
      menu.GetItem(param2, info, sizeof(info));
      int amount = StringToInt(info);

      Player player = new Player(target);
      if (player.Points < amount)
        NyxPrintToChat(param1, "%t", "Insufficient Player Points", target);
      else {
        Display_ConfirmRequestPointsMenu(param1, target, amount);
        return;
      }
    } else {
        NyxPrintToChat(param1, "%t", "Player no longer available");
    }

    if (IsValidClient(param1)) {
      Display_RequestPointsMenu(param1);
    }
  }
}

void Display_ConfirmRequestPointsMenu(int client, int target, int amount) {
  g_iMenuTarget[target] = GetClientUserId(client);
  NyxPrintToChat(client, "%t", "Waiting For Confirmation", target);

  Menu menu = new Menu(MenuHandler_RequestGivePoints);
  char sTemp[64];
  FormatEx(sTemp, sizeof(sTemp), "%N asks for %d points", client, amount);
  menu.SetTitle(sTemp);
  IntToString(amount, sTemp, sizeof(sTemp));
  menu.AddItem(sTemp, "Yes");
  menu.AddItem("", "No");
  menu.ExitButton = true;
  menu.Display(target, 10);
}

public int MenuHandler_RequestGivePoints(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_End) {
    delete menu;
  } else if (action == MenuAction_Cancel) {
  int target = GetClientOfUserId(g_iMenuTarget[param1]);

  if (IsValidClient(target))
    NyxPrintToChat(target, "%t", "Didn't Agree To Give", param1);

  } else if (action == MenuAction_Select) {

    int target = GetClientOfUserId(g_iMenuTarget[param1]);

    if (param2 != 0){
      if (IsValidClient(target))
        NyxPrintToChat(target, "%t", "Didn't Agree To Give", param1);
      return;
    }
    if (IsValidTeamForRequestPoints(param1, target)) {
      char info[32];
      menu.GetItem(param2, info, sizeof(info));
      int amount = StringToInt(info);

      Player player = new Player(param1);
      if (player.Points < amount) {
        NyxPrintToChat(param1, "%t", "Insufficient Points");
        NyxPrintToChat(target, "%t", "Insufficient Player Points", target);
      } else {
        int spent = (new Player(target)).GivePoints(amount);
        if (spent != 0)
          player.Points -= spent;

        if (g_hConVars[ConVar_RqTeam].IntValue == 2)
          NyxPrintToAll("%t", "Sent Points", param1, spent, target);
        else
          NyxPrintToTeam(GetClientTeam(param1), "%t", "Sent Points", param1, spent, target);

        NyxPrintToChat(param1, "%t", "Points Left", player.Points);
      }
    } else {
      NyxPrintToChat(param1, "%t", "Player no longer available");

      if (IsValidClient(target))
        NyxPrintToChat(target, "%t", "Player no longer available");
    }
  }
}

void Display_TeamHealMenu(int client) {
  Menu menu = new Menu(MenuHandler_TeamHeal);
  menu.SetTitle("Select Target");
  AddTeamToMenu(menu, client, _, _, true);
  menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_TeamHeal(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_End) {
    delete menu;
  } else if (action == MenuAction_Cancel) {
    if (param2 == MenuCancel_ExitBack) {
      if (IsValidClient(param1)) {
        Display_TeamHealMenu(param1);
      }
    }
  } else if (action == MenuAction_Select) {
    char info[32];
    menu.GetItem(param2, info, sizeof(info));
    FakeClientCommandEx(param1, "sm_heal #%d", StringToInt(info));

    if (IsValidClient(param1)) {
      Display_TeamHealMenu(param1);
    }
  }
}
/***
 *        ______                 __  _
 *       / ____/_  ______  _____/ /_(_)___  ____  _____
 *      / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
 *     / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
 *    /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/
 *
 */

bool IsValidTeamForRequestPoints(int client, int target)
{
  return IsValidClient(client, true) && IsValidClient(target, true) && (g_hConVars[ConVar_RqTeam].IntValue == 2 ? GetClientTeam(target) != 1 : GetClientTeam(client) == GetClientTeam(target));
}

void HealPlayer(int client)
{
  SetEntityHealth(client, GetEntProp(client, Prop_Data, "m_iMaxHealth"));
}

bool CanAfford(int client, any[eCatalog] item) {
  Player player = new Player(client);
  if (player.Points < item[Catalog_Cost]) {
    return false;
  }

  return true;
}

bool CanBuy(int client, any[eCatalog] item) {
  Player player = new Player(client);

  // do we have anough dosh?
  if (!CanAfford(client, item)) {
    if (g_hConVars[ConVar_AnnounceNeeds].BoolValue) {
      NyxPrintToTeam(GetClientTeam(client), "%t", "Insufficient Funds Announce",
          client, item[Catalog_Cost] - player.Points, item[Catalog_Name]);
    } else {
      NyxPrintToChat(client, "%t", "Insufficient Funds",
          item[Catalog_Cost] - player.Points, item[Catalog_Name]);
    }

    return false;
  }
  char error[255];
  bool result = CanUse(client, item, error, sizeof(error));
  if (!result) NyxPrintToChat(client, error);

  return result;
}

bool CanUse(int client, any[eCatalog] item, char[] buffer, int maxlength) {
  Player player = new Player(client);

  // is the item team restricted?
  if (strlen(item[Catalog_Team]) != 0) {
    if (L4D2_GetClientTeam(client) != L4D2_StringToTeam(item[Catalog_Team])) {
      Format(buffer, maxlength, "%t", "Item Wrong Team");
      return false;
    }
  }

  // do we need to be alive?
  if (!IsPlayerAlive(client)) {
    if (IsPlayerSurvivor(client)) {
      //NyxPrintToChat(client, "%t", "Must Be Alive");
      Format(buffer, maxlength, "%t", "Must Be Alive");
      return false;
    }
  }

  // do we need to check if we're incapacitated?
  if (!IsPlayerIncapacitated(client) && item[Catalog_MustBeIncapacitated]) {
    if (IsPlayerSurvivor(client)) {
      //NyxPrintToChat(client, "%t", "Must Be Incapacitated");
      Format(buffer, maxlength, "%t", "Must Be Incapacitated");
      return false;
    }
  }

  // have we reached the buy limit?
  if (item[Catalog_Limit] > 0) {
    if (g_iSpawnCount[L4D2_StringToClass(item[Catalog_Item])] >= item[Catalog_Limit]) {
      //NyxPrintToChat(client, "%t", "Spawn Limit Reached", item[Catalog_Name]);
      Format(buffer, maxlength, "%t", "Spawn Limit Reached", item[Catalog_Name]);
      return false;
    }
  }

  // do we need to run pre-heal condition checks?
  if (StrEqual(item[Catalog_Item], "health", false)) {
    if (IsPlayerGrabbed(client)) {
      if (L4D2_GetClientTeam(client) == L4D2Team_Survivor) {
        //NyxPrintToChat(client, "%t", "Must Not Be Grabbed");
        Format(buffer, maxlength, "%t", "Must Not Be Grabbed");
        return false;
      }
    }
    if (!IsPlayerIncapacitated(client)) {
      int m_iHealth = GetEntProp(client, Prop_Data, "m_iHealth");
      int m_iMaxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
      if (float(m_iHealth) / float(m_iMaxHealth) >= 0.8) {
        //NyxPrintToChat(client, "%t", "Health is Full");
        Format(buffer, maxlength, "%t", "Health is Full");
        return false;
      }
    }

    // are we a tank?
    if (IsPlayerTank(client)) {
      // tank death loop fix
      if (GetEntProp(client, Prop_Send, "m_nSequence") >= 65 || !IsPlayerAlive(client)) { // start of tank death animation 67-77
        NyxPrintToChat(client, "%t", "Must Be Alive");
        Format(buffer, maxlength, "%t", "Must Be Alive");
        return false;
      }

      if (g_hConVars[ConVar_TankHealLimit].IntValue > 0) {
        if (player.HealCount + 1 > g_hConVars[ConVar_TankHealLimit].IntValue) {
          //NyxPrintToChat(client, "%t", "Heal Limit Reached");
          Format(buffer, maxlength, "%t", "Heal Limit Reached");
          return false;
        }

        NyxPrintToTeam(GetClientTeam(client), "%t", "Tank Heal Limit", client,
            player.HealCount + 1,
            g_hConVars[ConVar_TankHealLimit].IntValue);
      }
    }
  }

  // are we trying to by a tank?
  if (StrEqual(item[Catalog_Item], "tank", false)) {
    if (L4D2_IsMissionFinalMap() && !g_hConVars[ConVar_TankAllowedFinal].BoolValue) {
      //NyxPrintToChat(client, "%t", "Tank Not Allowed in Final");
      Format(buffer, maxlength, "%t", "Tank Not Allowed in Final");
      return false;
    }

    if (!g_bTankAllowed && (g_hConVars[ConVar_TankDelay].IntValue != 0)) {
      int timeLeft = g_hConVars[ConVar_TankDelay].IntValue - g_iStartTimePassed;
      int minutes = timeLeft / 60;
      int seconds = timeLeft % 60;

      if (minutes) {
        //NyxPrintToChat(client, "%t", "Tank Allowed in Minutes", minutes);
        Format(buffer, maxlength, "%t", "Tank Allowed in Minutes", minutes);
      } else {
        //NyxPrintToChat(client, "%t", "Tank Allowed in Seconds", seconds);
        Format(buffer, maxlength, "%t", "Tank Allowed in Seconds", seconds);
      }

      return false;
    }
  }
  if (StrEqual(item[Catalog_Item], "extinguish", false)) {
    if (!IsPlayerAlive(client) || IsPlayerGhost(client) || !(GetEntityFlags(client) & FL_ONFIRE)){
      Format(buffer, maxlength, "%t", "Must Be On Fire");
      return false;
    }
  }
  return true;
}

void BuyItem(int buyer, int receiver, any[eCatalog] item, bool dontRun=false) {
  Player player = new Player(buyer);
  player.Points -= item[Catalog_Cost];
  player.SetLastItem(item[Catalog_Item]);

  if (StrEqual(item[Catalog_Category], "infected", false)) {
    if (item[Catalog_Announce]) {
      char buffer[255]; Format(buffer, sizeof(buffer), "Announce %s Purchase", item[Catalog_Name]);
      NyxPrintToAll("%t", buffer, buyer, item[Catalog_Name]);
    }

    L4D2ClassType class = L4D2_StringToClass(item[Catalog_Item]);
    if (class != L4D2Class_Unknown) {
      g_iSpawnCount[class]++;
    }
  }
  else if (IsPlayerTank(receiver) && StrEqual(item[Catalog_Item], "health", false)) {
    if (buyer == receiver)
      player.HealCount++;
    else
      (new Player(receiver)).HealCount++;
    HealPlayer(receiver); // death loop anim fix
    return;
  }
  else if (StrEqual(item[Catalog_Item], "extinguish", false)){
    if (item[Catalog_Announce])
      NyxPrintToTeam(GetClientTeam(receiver), "%t", "Self-Extinguish", receiver);
    ExtinguishEntity(receiver);
    return;
  }

  if (strlen(item[Catalog_CommandArgs]) == 0) {
    strcopy(item[Catalog_CommandArgs], sizeof(item[Catalog_CommandArgs]), item[Catalog_Item]);
  }

  if (!dontRun) {
    bool success = ExecuteCheatCommand(receiver, "%s %s", item[Catalog_Command], item[Catalog_CommandArgs]);
    if (!success) {
      NyxPrintToChat(buyer, "An internal error occurred while executing this command.");
    }
  }
}

bool SpawnZombiePurchase(int client, L4D2ClassType class) {
  if (IsPlayerAlive(client)) {
    if (IsPlayerGhost(client)) {
      if (class == L4D2Class_Tank) {
        SpawnTankPurchase(client);
        CallFwd_OnBuyZombie(client);
        return true;
      }

      L4D2_SetInfectedClass(client, class);
      CallFwd_OnBuyZombie(client);
      return true;
    }

    return false;
  }

  if (class == L4D2Class_Tank) {
    SpawnTankPurchase(client);
    CallFwd_OnBuyZombie(client);
    return true;
  }

  SetEntProp(client, Prop_Send, "m_iPlayerState", 6);
  L4D2_BecomeGhost(client);
  L4D2_SetInfectedClass(client, class);
  CallFwd_OnBuyZombie(client);
  return true;
}

void SpawnTankPurchase(int client) {
  L4D2_RespawnPlayer(client);
  L4D2_SetInfectedClass(client, L4D2Class_Tank);
  float pos[3]; GetClientEyePosition(client, pos);
  L4D2_GetRandomPZSpawnPosition(L4D2_GetClientClass(client), _, client, pos);
  TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
  Player player = new Player(client);
  player.HealCount = 0;
  player.WasTank = false;
}

void CallFwd_OnBuyZombie(int client){
  Call_StartForward(g_fwdOnBuyZombie);
  Call_PushCell(client);
  Call_Finish();
}
