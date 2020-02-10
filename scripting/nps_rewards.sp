#pragma semicolon 1
#include <sourcemod>
#include <colors>

#define NYX_DEBUG 1
#define NYXTOOLS_TAG "PS"
#include <nyxtools>
#include <nyxtools_l4d2>
#include <nps_stocks>
#include <nps_storage>

#pragma newdecls required

public Plugin myinfo = {
  name = "NPS - Rewards",
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

enum NyxError {
  Error_None = 0,
  Error_MissingKey,
  Error_MissingReward,
  Error_MaxedPoints
}

enum NyxConVar {
  ConVar:ConVar_MaxPoints,
  ConVar:ConVar_KillStreak,
  ConVar:ConVar_HeadshotStreak
}

/***
 *       ________      __          __
 *      / ____/ /___  / /_  ____ _/ /____
 *     / / __/ / __ \/ __ \/ __ `/ / ___/
 *    / /_/ / / /_/ / /_/ / /_/ / (__  )
 *    \____/_/\____/_.___/\__,_/_/____/
 *
 */

KeyValues g_hConfig;

Handle g_hMaxPointsTimer[MAXPLAYERS + 1];
bool g_bMaxPointsWarning[MAXPLAYERS + 1];

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
 *        ____  __            _          ____      __            ____
 *       / __ \/ /_  ______ _(_)___     /  _/___  / /____  _____/ __/___ _________
 *      / /_/ / / / / / __ `/ / __ \    / // __ \/ __/ _ \/ ___/ /_/ __ `/ ___/ _ \
 *     / ____/ / /_/ / /_/ / / / / /  _/ // / / / /_/  __/ /  / __/ /_/ / /__/  __/
 *    /_/   /_/\__,_/\__, /_/_/ /_/  /___/_/ /_/\__/\___/_/  /_/  \__,_/\___/\___/
 *                  /____/
 */

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
  RegPluginLibrary("nps_rewards");
  return APLRes_Success;
}

public void OnPluginStart() {
  LoadTranslations("common.phrases");
  LoadTranslations("nps_core.phrases");

  g_hConVars[ConVar_KillStreak] = CreateConVar("nps_killstreak", "25", "Number of infected required to kill in order to get a killstreak.");
  g_hConVars[ConVar_HeadshotStreak] = CreateConVar("nps_headshot_streak", "20", "Number of infected headshots required in order to get a headshot killstreak.");

  HookEvent("player_spawn", Event_PlayerSpawn);
  HookEvent("player_death", Event_PlayerDeath);
  HookEvent("player_hurt", Event_PlayerHurt);
  HookEvent("player_incapacitated", Event_PlayerIncapacitated);
  HookEvent("player_now_it", Event_PlayerNowIt);

  HookEvent("infected_death", Event_InfectedDeath);
  HookEvent("tank_killed", Event_TankKilled, EventHookMode_Pre);
  HookEvent("witch_killed", Event_WitchKilled);

  HookEvent("choke_start", Event_ChokeStart);
  HookEvent("lunge_pounce", Event_LungePounce);
  HookEvent("jockey_ride", Event_JockeyRide);
  HookEvent("charger_carry_start", Event_ChargerCarryStart);
  HookEvent("charger_impact", Event_ChargerImpact);

  HookEvent("heal_success", Event_HealSuccess);
  HookEvent("award_earned", Event_AwardEarned);
  HookEvent("revive_success", Event_ReviveSuccess);
  HookEvent("defibrillator_used", Event_DefibrillatorUsed);
  HookEvent("zombie_ignited", Event_ZombieIgnited);

  HookEvent("finale_start", Event_FinaleStart);
  HookEvent("finale_win", Event_FinaleWin);

  char path[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, path, sizeof(path), "configs/nps/%s", "rewards.cfg");

  g_hConfig = new KeyValues("rewards");
  if (g_hConfig.ImportFromFile(path)) {
    char buffer[256];
    if (!g_hConfig.GetSectionName(buffer, sizeof(buffer))) {
      SetFailState("Error in %s: File corrupt or in the wrong format", path);
    }

    if (strcmp(buffer, "rewards") != 0) {
      SetFailState("Error in %s: Couldn't find section '%s'", path, "rewards");
    }

    g_hConfig.Rewind();
  } else {
    SetFailState("Error in %s: File not found, corrupt or in the wrong format", path);
  }
}

public void OnAllPluginsLoaded() {
  if (LibraryExists("nps")) {
    g_hConVars[ConVar_MaxPoints] = FindConVar("nps_max_points");
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

public Action L4D2_OnEndVersusModeRound(bool countSurvivors) {
  int winner = countSurvivors ? L4D2_TEAM_SURVIVOR : L4D2_TEAM_INFECTED;

  for (int i = 1; i <= MaxClients; i++) {
    if (!IsValidClient(i, true)) continue;
    if (!IsClientPlaying(i)) continue;

    Player player = new Player(i);
    if (GetClientTeam(i) == winner) {
      if (RewardPoints(player, "round_won")) {
        NyxPrintToChat(i, "%t", "Round Won", player.Reward);
      }
    } else {
      if (RewardPoints(player, "round_lost")) {
        NyxPrintToChat(i, "%t", "Round Lost", player.Reward);
      }
    }

    NyxPrintToTeam(GetClientTeam(i), "%t", "Round End Show Points", i, player.Points);
  }
}

/***
 *        ______                 __
 *       / ____/   _____  ____  / /______
 *      / __/ | | / / _ \/ __ \/ __/ ___/
 *     / /___ | |/ /  __/ / / / /_(__  )
 *    /_____/ |___/\___/_/ /_/\__/____/
 *
 */

 public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  //int client = GetClientOfUserId(event.GetInt("userid"));

  return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
  int victim = GetClientOfUserId(event.GetInt("userid"));
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  //bool headshot = event.GetBool("headshot");

  (new Player(victim)).HealCount = 0;

  if (!IsValidClient(attacker)) return Plugin_Continue;
  if (IsPlayerSurvivor(attacker)) {
    if (!IsPlayerInfected(victim)) return Plugin_Continue;
    if (IsPlayerTank(victim)) {
      if (IsFakeClient(victim)) return Plugin_Continue;

      for (int i = 1; i <= MaxClients; i++) {
        if (!IsValidClient(i)) continue;
        if (!IsPlayerSurvivor(i)) continue;

        Player player = new Player(i);
        player.BurnedTank = false;

        if (IsPlayerAlive(i)) {
          if (RewardPoints(player, "killed_tank")) {
            NyxPrintToChat(i, "%t", "Killed Tank", player.Reward, victim);
          }
        }
      }

      return Plugin_Continue;
    }

    Player player = new Player(attacker);
    if (RewardPoints(player, "killed_special_infected")) {
      NyxPrintToChat(attacker, "%t", "Killed Special Infected", player.Reward, victim);
    }
  } else {
    if (!IsPlayerSurvivor(victim)) return Plugin_Continue;

    Player player = new Player(attacker);
    if (RewardPoints(player, "killed_survivor")) {
      NyxPrintToChat(attacker, "%t", "Killed Survivor", player.Reward, victim);
    }
  }

  return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
  int victim = GetClientOfUserId(event.GetInt("userid"));
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  int type = event.GetInt("type");

  if (!IsValidClient(attacker)) return Plugin_Continue;
  if (IsPlayerInfected(attacker) && IsPlayerSurvivor(victim)) {
    Player player = new Player(attacker);
    player.HurtCount++;

    if (IsSpitterDamage(type)) {
      if (player.HurtCount % 8 == 0) {
        if (RewardPoints(player, "hurt_player")) {
          NyxPrintToChat(attacker, "%t", "Hurt Player", player.Reward, victim);
        }
      }
    } else if (IsFireDamage(type)) {
      return Plugin_Continue;
    } else {
      if (player.HurtCount % 3 == 0) {
        if (RewardPoints(player, "hurt_player")) {
          NyxPrintToChat(attacker, "%t", "Hurt Player", player.Reward, victim);
        }
      }
    }
  }

  return Plugin_Continue;
}

public Action Event_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast) {
  int victim = GetClientOfUserId(event.GetInt("userid"));
  int attacker = GetClientOfUserId(event.GetInt("attacker"));

  if (!IsValidClient(attacker)) return Plugin_Continue;
  if (IsPlayerInfected(attacker)) {
    Player player = new Player(attacker);
    if (RewardPoints(player, "incapacitated_player")) {
      NyxPrintToChat(attacker, "%t", "Incapacitated Player", player.Reward, victim);
    }
  }

  return Plugin_Continue;
}

public Action Event_PlayerNowIt(Event event, const char[] name, bool dontBroadcast) {
  int victim = GetClientOfUserId(event.GetInt("userid"));
  int attacker = GetClientOfUserId(event.GetInt("attacker"));

  if (!IsValidClient(attacker)) return Plugin_Continue;
  if (IsPlayerSurvivor(attacker)) {
    if (!IsPlayerTank(victim)) return Plugin_Continue;

    Player player = new Player(attacker);
    if (RewardPoints(player, "bile_tank")) {
      NyxPrintToChat(attacker, "%t", "Bile Tank", player.Reward, victim);
    }
  } else {
    if (!IsPlayerSurvivor(victim)) return Plugin_Continue;

    Player player = new Player(attacker);
    if (RewardPoints(player, "bile_player")) {
      NyxPrintToChat(attacker, "%t", "Bile Player", player.Reward, victim);
    }
  }

  return Plugin_Continue;
}

public Action Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast) {
  //int victim = GetClientOfUserId(event.GetInt("infected_id"));
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  bool headshot = event.GetBool("headshot");

  //NyxMsgDebug("Event_InfectedDeath(victim: %N, attacker: %Nd)", victim, attacker);

  if (!IsValidClient(attacker)) return Plugin_Continue;
  if (IsPlayerSurvivor(attacker)) {
    int streak;

    Player player = new Player(attacker);
    if (headshot) {
      player.HeadshotCount++;

      streak = g_hConVars[ConVar_HeadshotStreak].IntValue;
      if (streak > 0) {
        if ((player.HeadshotCount % streak) == 0) {
          if (RewardPoints(player, "headshot_streak")) {
            NyxPrintToChat(attacker, "%t", "Headshot Streak", player.Reward, streak);
          }
        }
      }
    }

    player.KillCount++;

    streak = g_hConVars[ConVar_KillStreak].IntValue;
    if (streak > 0) {
      if ((player.KillCount % streak) == 0) {
        if (RewardPoints(player, "kill_streak")) {
          NyxPrintToChat(attacker, "%t", "Kill Streak", player.Reward, streak);
        }
      }
    }
  }

  return Plugin_Continue;
}

public Action Event_TankKilled(Event event, const char[] name, bool dontBroadcast) {
  int victim = GetClientOfUserId(event.GetInt("userid"));
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  bool solo = event.GetBool("solo");

  if (!IsValidClient(attacker)) return Plugin_Continue;
  if (IsPlayerSurvivor(attacker)) {
    if (solo) {
      Player player = new Player(attacker);
      if (RewardPoints(player, "killed_tank_solo")) {
        NyxPrintToChat(attacker, "%t", "Killed Tank Solo", player.Reward, victim);
      }

      return Plugin_Continue;
    }

    for (int i = 1; i <= MaxClients; i++) {
      if (!IsValidClient(i)) continue;
      if (!IsPlayerSurvivor(i)) continue;

      Player player = new Player(i);
      player.BurnedTank = false;

      if (IsPlayerAlive(i)) {
        if (RewardPoints(player, "killed_tank")) {
          NyxPrintToChat(i, "%t", "Killed Tank", player.Reward, victim);
        }
      }
    }
  }

  return Plugin_Continue;
}

public Action Event_WitchKilled(Event event, const char[] name, bool dontBroadcast) {
  int attacker = GetClientOfUserId(event.GetInt("userid"));
  bool oneshot = event.GetBool("oneshot");

  if (!IsValidClient(attacker)) return Plugin_Continue;
  if (IsPlayerSurvivor(attacker)) {
    Player player = new Player(attacker);
    if (oneshot) {
      if (RewardPoints(player, "killed_witch_oneshot")) {
        NyxPrintToChat(attacker, "%t", "Killed Witch Oneshot", player.Reward);
      }
    }

    if (RewardPoints(player, "killed_witch")) {
      NyxPrintToChat(attacker, "%t", "Killed Witch", player.Reward);
    }
  }

  for (int i = 1; i <= MaxClients; i++) {
    if (!IsValidClient(i)) continue;
    if (!IsPlayerSurvivor(i)) continue;

    Player player = new Player(i);
    player.BurnedWitch = false;
  }

  return Plugin_Continue;
}

public Action Event_ChokeStart(Event event, const char[] name, bool dontBroadcast) {
  int attacker = GetClientOfUserId(event.GetInt("userid"));
  int victim = GetClientOfUserId(event.GetInt("victim"));

  if (!IsValidClient(attacker)) return Plugin_Continue;
  if (IsPlayerInfected(attacker)) {
    Player player = new Player(attacker);
    if (RewardPoints(player, "choke_player")) {
      NyxPrintToChat(attacker, "%t", "Choke Player", player.Reward, victim);
    }
  }

  return Plugin_Continue;
}

public Action Event_LungePounce(Event event, const char[] name, bool dontBroadcast) {
  int attacker = GetClientOfUserId(event.GetInt("userid"));
  int victim = GetClientOfUserId(event.GetInt("victim"));

  if (!IsValidClient(attacker)) return Plugin_Continue;
  if (IsPlayerInfected(attacker)) {
    Player player = new Player(attacker);
    if (RewardPoints(player, "pounce_player")) {
      NyxPrintToChat(attacker, "%t", "Pounce Player", player.Reward, victim);
    }
  }

  return Plugin_Continue;
}

public Action Event_JockeyRide(Event event, const char[] name, bool dontBroadcast) {
  int attacker = GetClientOfUserId(event.GetInt("userid"));
  int victim = GetClientOfUserId(event.GetInt("victim"));

  if (!IsValidClient(attacker)) return Plugin_Continue;
  if (IsPlayerInfected(attacker)) {
    Player player = new Player(attacker);
    if (RewardPoints(player, "ride_player")) {
      NyxPrintToChat(attacker, "%t", "Ride Player", player.Reward, victim);
    }
  }

  return Plugin_Continue;
}

public Action Event_ChargerCarryStart(Event event, const char[] name, bool dontBroadcast) {
  int attacker = GetClientOfUserId(event.GetInt("userid"));
  int victim = GetClientOfUserId(event.GetInt("victim"));

  if (!IsValidClient(attacker)) return Plugin_Continue;
  if (IsPlayerInfected(attacker)) {
    Player player = new Player(attacker);
    if (RewardPoints(player, "carry_player")) {
      NyxPrintToChat(attacker, "%t", "Carry Player", player.Reward, victim);
    }
  }

  return Plugin_Continue;
}

public Action Event_ChargerImpact(Event event, const char[] name, bool dontBroadcast) {
  int attacker = GetClientOfUserId(event.GetInt("userid"));
  int victim = GetClientOfUserId(event.GetInt("victim"));

  if (!IsValidClient(attacker)) return Plugin_Continue;
  if (IsPlayerInfected(attacker)) {
    Player player = new Player(attacker);
    if (RewardPoints(player, "impact_player")) {
      NyxPrintToChat(attacker, "%t", "Impact Player", player.Reward, victim);
    }
  }

  return Plugin_Continue;
}

public Action Event_HealSuccess(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  int subject = GetClientOfUserId(event.GetInt("subject"));
  int health_restored = event.GetInt("health_restored");

  if (!IsValidClient(client)) return Plugin_Continue;
  if (!IsPlayerSurvivor(client)) return Plugin_Continue;
  if (client == subject) return Plugin_Continue;

  Player player = new Player(client);
  if (health_restored > 39) {
    if (RewardPoints(player, "heal_player")) {
      NyxPrintToChat(client, "%t", "Healed Player", player.Reward, subject);
    }
  } else {
    if (RewardPoints(player, "heal_player", "reward_partial")) {
      NyxPrintToChat(client, "%t", "Healed Player Partial", player.Reward, subject);
    }
  }

  return Plugin_Continue;
}

public Action Event_AwardEarned(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("subject"));
  int subject = GetClientOfUserId(event.GetInt("subjectentid"));
  int award = event.GetInt("award");

  if (!IsValidClient(client)) return Plugin_Continue;
  if (!IsPlayerSurvivor(client)) return Plugin_Continue;

  Player player = new Player(client);
  if (award == 67) { // 67=Protect
    player.ProtectCount++;

    if (player.ProtectCount % 6 == 0) {
      if (RewardPoints(player, "protect_player")) {
        NyxPrintToChat(client, "%t", "Protected Player", player.Reward, subject);
      }
    }
  }

  return Plugin_Continue;
}

public Action Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  int subject = GetClientOfUserId(event.GetInt("subject"));
  //bool lastlife = event.GetBool("lastlife");
  bool ledge_hang = event.GetBool("ledge_hang");

  if (!IsValidClient(client)) return Plugin_Continue;
  if (!IsPlayerSurvivor(client)) return Plugin_Continue;
  if (client == subject) return Plugin_Continue;

  Player player = new Player(client);
  if (ledge_hang) {
    if (RewardPoints(player, "revive_player", "ledge_hang")) {
      NyxPrintToChat(client, "%t", "Revived Player From Ledge", player.Reward, subject);
    }
  } else {
    if (RewardPoints(player, "revive_player")) {
      NyxPrintToChat(client, "%t", "Revived Player", player.Reward, subject);
    }
  }

  return Plugin_Continue;
}

public Action Event_DefibrillatorUsed(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  int subject = GetClientOfUserId(event.GetInt("subject"));

  if (!IsValidClient(client)) return Plugin_Continue;
  if (IsPlayerSurvivor(client)) {
    Player player = new Player(client);
    if (RewardPoints(player, "defibrillator_used")) {
      NyxPrintToChat(client, "%t", "Defibrillator Used", player.Reward, subject);
    }
  }

  return Plugin_Continue;
}

public Action Event_ZombieIgnited(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));

  char victimname[16];
  event.GetString("victimname", victimname, sizeof(victimname));

  if (!IsValidClient(client)) return Plugin_Continue;
  if (IsPlayerSurvivor(client)) {
    Player player = new Player(client);

    if (StrEqual("Tank", victimname, false) && !player.BurnedTank) {
      player.BurnedTank = true;

      if (RewardPoints(player, "burn_tank")) {
        NyxPrintToChat(client, "%t", "Burned Tank", player.Reward);
      }
    }

    if (StrEqual("Witch", victimname, false) && !player.BurnedWitch) {
      player.BurnedWitch = true;

      if (RewardPoints(player, "burn_witch")) {
        NyxPrintToChat(client, "%t", "Burned Witch", player.Reward);
      }
    }
  }

  return Plugin_Continue;
}

public Action Event_FinaleStart(Event event, const char[] name, bool dontBroadcast) {
  NyxMsgDebug("Event_FinaleStart");

  return Plugin_Continue;
}

public Action Event_FinaleWin(Event event, const char[] name, bool dontBroadcast) {
  NyxMsgDebug("Event_FinaleWin");

  return Plugin_Continue;
}

/***
 *      _______
 *     /_  __(_)___ ___  ___  __________
 *      / / / / __ `__ \/ _ \/ ___/ ___/
 *     / / / / / / / / /  __/ /  (__  )
 *    /_/ /_/_/ /_/ /_/\___/_/  /____/
 *
 */

public Action Timer_MaxPoints(Handle timer, any client) {
  g_bMaxPointsWarning[client] = false;
  g_hMaxPointsTimer[client] = INVALID_HANDLE;
}

/***
 *        ______                 __  _
 *       / ____/_  ______  _____/ /_(_)___  ____  _____
 *      / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
 *     / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
 *    /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/
 *
 */

bool RewardPoints(Player player, const char[] reward, const char[] type="reward") {
  g_hConfig.Rewind();

  if (g_hConfig.JumpToKey(reward)) {
    char value[16]; g_hConfig.GetString(type, value, sizeof(value));
    int points = StringToInt(value);
    if (points == 0) {
      HandleError(player, Error_MissingReward);
      return false;
    }

    int given = player.GivePoints(points);
    player.Reward = given;

    if (given == 0) {
      HandleError(player, Error_MaxedPoints);
      return false;
    }
  } else {
    HandleError(player, Error_MissingKey);
  }

  return true;
}

void HandleError(Player player, NyxError error) {
  switch (error) {
    case Error_MissingKey: {
      NyxMsgDebug("Missing key");
    }
    case Error_MissingReward: {
      NyxMsgDebug("Missing reward");
    }
    case Error_MaxedPoints: {
      int maxPoints = g_hConVars[ConVar_MaxPoints].IntValue;

      if (g_hMaxPointsTimer[player.Index] == INVALID_HANDLE) {
        g_hMaxPointsTimer[player.Index] = CreateTimer(15.0, Timer_MaxPoints, player.Index);
      }

      if (!g_bMaxPointsWarning[player.Index]) {
        g_bMaxPointsWarning[player.Index] = true;
        NyxPrintToChat(player.Index, "%t", "Max Points", player.Points, maxPoints);
      }
    }
  }
}
