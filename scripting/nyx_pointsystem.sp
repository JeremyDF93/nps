#pragma semicolon 1
#include <sourcemod>
#include <left4downtown>
#include <colors>

#define NYX_DEBUG          2
#define NYX_PLUGIN_NAME    "Nyx"
#define NYX_PLUGIN_VERSION "1.0"
#include <nyxtools>

#pragma newdecls required

public Plugin myinfo = {
	name = "Nyxtools - L4D2 Point System",
	author = "Kiwi, JeremyDF93",
	description = "",
	version = NYX_PLUGIN_VERSION,
	url = "https://praisethemoon.com/"
};

/***
 *        ______                          
 *       / ____/___  __  ______ ___  _____
 *      / __/ / __ \/ / / / __ `__ \/ ___/
 *     / /___/ / / / /_/ / / / / / (__  ) 
 *    /_____/_/ /_/\__,_/_/ /_/ /_/____/  
 *                                        
 */

enum NyxData {
		String:Data_Group[64],
		String:Data_Section[64],
		String:Data_Command[64],
		String:Data_CommandArgs[64],
		String:Data_Name[64],
		String:Data_Shortcut[16],
		String:Data_TeamName[16],
		Data_Cost,
		bool:Data_MustBeAlive,
		bool:Data_MustBeIncapacitated,
		bool:Data_MustBeGrabbed
}

enum NyxPlayer {
	Player_Points,
	Player_Reward,
	Player_Headshots,
	Player_Kills,
	Player_HurtCount,
	bool:Player_BurnedWitch,
	bool:Player_BurnedTank,
	Player_ProtectCount
}

enum NyxGame {
	Game_MaxPoints,
	Game_StartPoints,
	Game_TankMissionLimit,
	Game_TankHealMultiplier,
	Game_WitchMissionLimit,
	Float:Game_TankWaitTime,
	bool:Game_TankAllowed
}

enum NyxError {
	Error_None = 0,
	Error_MissingKey,
	Error_MissingReward,
	Error_MaxedPoints
}

/***
 *       ________      __          __    
 *      / ____/ /___  / /_  ____ _/ /____
 *     / / __/ / __ \/ __ \/ __ `/ / ___/
 *    / /_/ / / /_/ / /_/ / /_/ / (__  ) 
 *    \____/_/\____/_.___/\__,_/_/____/  
 *                                       
 */

KeyValues g_hData;
KeyValues g_hConfig;

int g_iMenuTarget[MAXPLAYERS + 1];
any g_aPlayerStorage[MAXPLAYERS + 1][NyxPlayer];
int g_iGameSettings[NyxGame];

/***
 *        ____  __            _          ____      __            ____              
 *       / __ \/ /_  ______ _(_)___     /  _/___  / /____  _____/ __/___ _________ 
 *      / /_/ / / / / / __ `/ / __ \    / // __ \/ __/ _ \/ ___/ /_/ __ `/ ___/ _ \
 *     / ____/ / /_/ / /_/ / / / / /  _/ // / / / /_/  __/ /  / __/ /_/ / /__/  __/
 *    /_/   /_/\__,_/\__, /_/_/ /_/  /___/_/ /_/\__/\___/_/  /_/  \__,_/\___/\___/ 
 *                  /____/                                                         
 */

public void OnPluginStart() {
	LoadTranslations("common.phrases");
	LoadTranslations("nyx_pointsystem.phrases");

	// Console Commands
	RegConsoleCmd("sm_buy", ConCmd_Buy);
	RegConsoleCmd("sm_gp", ConCmd_GivePoints);
	RegConsoleCmd("sm_points", ConCmd_ShowPoints);
	RegConsoleCmd("sm_tp", ConCmd_ShowTeamPoints);

	// Admin commands
	RegAdminCmd("nyx_givepoints", AdmCmd_GivePoints, ADMFLAG_ROOT, "nyx_givepoints <#userid|name> [points|5]");
	RegAdminCmd("nyx_reloadcfg", AdmCmd_ReloadConfig, ADMFLAG_ROOT);

	// Register events
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

	HookEvent("finale_win", Event_FinaleWin);
	HookEvent("round_end", Event_RoundEnd);

	// KeyValues
	g_hData = GetKeyValuesFromFile("buy.cfg", "data");
	g_hConfig = GetKeyValuesFromFile("options.cfg", "config");

	// Init global variables
	Init();
}

public void OnPluginEnd() {

}

void Init() {
	g_iGameSettings[Game_MaxPoints] = GetConfigKeyInt("max_points", 120);
	g_iGameSettings[Game_StartPoints] = GetConfigKeyInt("start_points", 10);
	g_iGameSettings[Game_TankWaitTime] = float(GetConfigKeyInt("tank_timeout", 60));
	g_iGameSettings[Game_TankAllowed] = false;

	for (int i = 1; i <= MaxClients; i++) {
		g_aPlayerStorage[i][Player_Points] = g_iGameSettings[Game_StartPoints];
		g_aPlayerStorage[i][Player_Reward] = 0;
		g_aPlayerStorage[i][Player_Headshots] = 0;
		g_aPlayerStorage[i][Player_Kills] = 0;
		g_aPlayerStorage[i][Player_HurtCount] = 0;
		g_aPlayerStorage[i][Player_BurnedWitch] = false;
		g_aPlayerStorage[i][Player_BurnedTank] = false;
		g_aPlayerStorage[i][Player_ProtectCount] = 0;
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
	CreateTimer(g_iGameSettings[Game_TankWaitTime], Timer_TankAllowed);

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

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	//bool headshot = event.GetBool("headshot");

	if (!IsValidClient(attacker, true)) return Plugin_Continue;
	if (IsClientSurvivor(attacker)) {
		if (!IsClientInfected(victim)) return Plugin_Continue;
		if (IsClientTank(victim)) return Plugin_Continue;

		NyxError error = RewardPoints(attacker, "killed_special_infected");
		if (!error) {
			NyxPrintToChat(attacker, "%t", "Killed Special Infected", GetPlayerReward(attacker), victim);
		} else {
			HandleError(attacker, error);
		}
	} else {
		if (!IsClientSurvivor(victim)) return Plugin_Continue;

		NyxError error = RewardPoints(attacker, "killed_survivor");
		if (!error) {
			NyxPrintToChat(attacker, "%t", "Killed Survivor", GetPlayerReward(attacker), victim);
		} else {
			HandleError(attacker, error);
		}
	}

	return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int type = event.GetInt("type");

	if (!IsValidClient(attacker, true)) return Plugin_Continue;
	if (IsClientInfected(attacker) && IsClientSurvivor(victim)) {
		g_aPlayerStorage[attacker][Player_HurtCount]++;

		if (IsSpitterDamage(type)) {
			if (g_aPlayerStorage[attacker][Player_HurtCount] % 8 == 0) {
				NyxError error = RewardPoints(attacker, "hurt_player");
				if (!error) {
					NyxPrintToChat(attacker, "%t", "Hurt Player", GetPlayerReward(attacker), victim);
				} else {
					HandleError(attacker, error);
				}
			}
		} else if (IsFireDamage(type)) {
			return Plugin_Continue;
		} else {
			if (g_aPlayerStorage[attacker][Player_HurtCount] % 3 == 0) {
				NyxError error = RewardPoints(attacker, "hurt_player");
				if (!error) {
					NyxPrintToChat(attacker, "%t", "Hurt Player", GetPlayerReward(attacker), victim);
				} else {
					HandleError(attacker, error);
				}
			}
		}
	}

	return Plugin_Continue;
}

public Action Event_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (!IsValidClient(attacker, true)) return Plugin_Continue;
	if (IsClientInfected(attacker)) {
		NyxError error = RewardPoints(attacker, "incapacitated_player");
		if (!error) {
			NyxPrintToChat(attacker, "%t", "Incapacitated Player", GetPlayerReward(attacker), victim);
		} else {
			HandleError(attacker, error);
		}
	}

	return Plugin_Continue;
}

public Action Event_PlayerNowIt(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (!IsValidClient(attacker, true)) return Plugin_Continue;
	if (IsClientSurvivor(attacker)) {
		if (!IsClientTank(victim)) return Plugin_Continue;

		NyxError error = RewardPoints(attacker, "bile_tank");
		if (!error) {
			NyxPrintToChat(attacker, "%t", "Bile Tank", GetPlayerReward(attacker), victim);
		} else {
			HandleError(attacker, error);
		}
	} else {
		if (!IsClientSurvivor(victim)) return Plugin_Continue;

		NyxError error = RewardPoints(attacker, "bile_player");
		if (!error) {
			NyxPrintToChat(attacker, "%t", "Bile Player", GetPlayerReward(attacker), victim);
		} else {
			HandleError(attacker, error);
		}
	}

	return Plugin_Continue;
}

public Action Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast) {
	//int victim = GetClientOfUserId(event.GetInt("infected_id"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	bool headshot = event.GetBool("headshot");

	if (!IsValidClient(attacker, true)) return Plugin_Continue;
	if (IsClientSurvivor(attacker)) {
		int streak;

		if (headshot) {
			g_aPlayerStorage[attacker][Player_Headshots]++;

			streak = GetRewardKeyInt("headshot_streak", "streak");
			if (streak > 0) {
				if ((g_aPlayerStorage[attacker][Player_Headshots] % streak) == 0) {
					RewardPoints(attacker, "headshot_streak");
					NyxError error = RewardPoints(attacker, "headshot_streak");
					if (!error) {
						NyxPrintToChat(attacker, "%t", "Headshot Streak", GetPlayerReward(attacker), streak);
					} else {
						HandleError(attacker, error);
					}
				}
			}
		}

		g_aPlayerStorage[attacker][Player_Kills]++;
		
		streak = GetRewardKeyInt("kill_streak", "streak");
		if (streak > 0) {
			if ((g_aPlayerStorage[attacker][Player_Kills] % streak) == 0) {
				RewardPoints(attacker, "kill_streak");
				NyxError error = RewardPoints(attacker, "kill_streak");
				if (!error) {
					NyxPrintToChat(attacker, "%t", "Kill Streak", GetPlayerReward(attacker), streak);
				} else {
					HandleError(attacker, error);
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

	if (!IsValidClient(attacker, true)) return Plugin_Continue;
	if (IsClientSurvivor(attacker)) {
		if (solo) {
			NyxError error = RewardPoints(attacker, "killed_tank_solo");
			if (!error) {
				NyxPrintToChat(attacker, "%t", "Killed Tank Solo", GetPlayerReward(attacker), victim);
			} else {
				HandleError(attacker, error);
			}
		}

		NyxError error = RewardPoints(attacker, "killed_tank");
		if (!error) {
			NyxPrintToTeam(GetClientTeam(attacker), "%t", "Killed Tank", GetPlayerReward(attacker), victim);
		} else {
			HandleError(attacker, error);
		}
	}

	g_aPlayerStorage[attacker][Player_BurnedWitch] = false;

	return Plugin_Continue;
}

public Action Event_WitchKilled(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("witchid"));
	bool oneshot = event.GetBool("oneshot");

	if (!IsValidClient(attacker, true)) return Plugin_Continue;
	if (IsClientSurvivor(attacker)) {
		if (oneshot) {
			NyxError error = RewardPoints(attacker, "killed_witch_oneshot");
			if (!error) {
				NyxPrintToChat(attacker, "%t", "Killed Witch Oneshot", GetPlayerReward(attacker), victim);
			} else {
				HandleError(attacker, error);
			}
		}

		NyxError error = RewardPoints(attacker, "killed_witch");
		if (!error) {
			NyxPrintToChat(attacker, "%t", "Killed Witch", GetPlayerReward(attacker), victim);
		} else {
			HandleError(attacker, error);
		}
	}

	g_aPlayerStorage[attacker][Player_BurnedWitch] = false;

	return Plugin_Continue;
}

public Action Event_ChokeStart(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("victim"));

	if (!IsValidClient(attacker, true)) return Plugin_Continue;
	if (IsClientInfected(attacker)) {
		NyxError error = RewardPoints(attacker, "choke_player");
		if (!error) {
			NyxPrintToChat(attacker, "%t", "Choke Player", GetPlayerReward(attacker), victim);
		} else {
			HandleError(attacker, error);
		}
	}

	return Plugin_Continue;
}

public Action Event_LungePounce(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("victim"));

	if (!IsValidClient(attacker, true)) return Plugin_Continue;
	if (IsClientInfected(attacker)) {
		NyxError error = RewardPoints(attacker, "pounce_player");
		if (!error) {
			NyxPrintToChat(attacker, "%t", "Pounce Player", GetPlayerReward(attacker), victim);
		} else {
			HandleError(attacker, error);
		}
	}

	return Plugin_Continue;
}

public Action Event_JockeyRide(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("victim"));

	if (!IsValidClient(attacker, true)) return Plugin_Continue;
	if (IsClientInfected(attacker)) {
		NyxError error = RewardPoints(attacker, "ride_player");
		if (!error) {
			NyxPrintToChat(attacker, "%t", "Ride Player", GetPlayerReward(attacker), victim);
		} else {
			HandleError(attacker, error);
		}
	}

	return Plugin_Continue;
}

public Action Event_ChargerCarryStart(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("victim"));

	if (!IsValidClient(attacker, true)) return Plugin_Continue;
	if (IsClientInfected(attacker)) {
		NyxError error = RewardPoints(attacker, "carry_player");
		if (!error) {
			NyxPrintToChat(attacker, "%t", "Carry Player", GetPlayerReward(attacker), victim);
		} else {
			HandleError(attacker, error);
		}
	}

	return Plugin_Continue;
}

public Action Event_ChargerImpact(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("victim"));

	if (!IsValidClient(attacker, true)) return Plugin_Continue;
	if (IsClientInfected(attacker)) {
		NyxError error = RewardPoints(attacker, "impact_player");
		if (!error) {
			NyxPrintToChat(attacker, "%t", "Impact Player", GetPlayerReward(attacker), victim);
		} else {
			HandleError(attacker, error);
		}
	}

	return Plugin_Continue;
}

public Action Event_HealSuccess(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));
	int health_restored = event.GetInt("health_restored");

	if (!IsValidClient(client)) return Plugin_Continue;
	if (!IsClientSurvivor(client)) return Plugin_Continue;
	if (client == subject) return Plugin_Continue;

	if (health_restored > 39) {
		NyxError error = RewardPoints(client, "heal_player");
		if (!error) {
			NyxPrintToChat(client, "%t", "Healed Player", GetPlayerReward(client), subject);
		} else {
			HandleError(client, error);
		}
	} else {
		NyxError error = RewardPoints(client, "heal_player", "reward_partial");
		if (!error) {
			NyxPrintToChat(client, "%t", "Healed Player Partial", GetPlayerReward(client), subject);
		} else {
			HandleError(client, error);
		}
	}

	return Plugin_Continue;
}

public Action Event_AwardEarned(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("subject"));
	int subject = GetClientOfUserId(event.GetInt("subjectentid"));
	int award = event.GetInt("award");

	if (!IsValidClient(client)) return Plugin_Continue;
	if (!IsClientSurvivor(client)) return Plugin_Continue;

	if (award == 67) { // 67=Protect
		g_aPlayerStorage[client][Player_ProtectCount]++;

		if (g_aPlayerStorage[client][Player_ProtectCount] % 6 == 0) {
			NyxError error = RewardPoints(client, "protect_player");
			if (!error) {
				NyxPrintToChat(client, "%t", "Protected Player", GetPlayerReward(client), subject);
			} else {
				HandleError(client, error);
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
	if (!IsClientSurvivor(client)) return Plugin_Continue;
	if (client == subject) return Plugin_Continue;

	if (ledge_hang) {
		NyxError error = RewardPoints(client, "revive_player", "ledge_hang");
		if (!error) {
			NyxPrintToChat(client, "%t", "Revived Player From Ledge", GetPlayerReward(client), subject);
		} else {
			HandleError(client, error);
		}
	} else {
		NyxError error = RewardPoints(client, "revive_player");
		if (!error) {
			NyxPrintToChat(client, "%t", "Revived Player", GetPlayerReward(client), subject);
		} else {
			HandleError(client, error);
		}
	}

	return Plugin_Continue;
}

public Action Event_DefibrillatorUsed(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));

	if (IsValidClient(client, true)) return Plugin_Continue;
	if (IsClientSurvivor(client)) {
		NyxError error = RewardPoints(client, "defibrillator_used");
		if (!error) {
			NyxPrintToChat(client, "%t", "Defibrillator Used", GetPlayerReward(client), subject);
		} else {
			HandleError(client, error);
		}
	}

	return Plugin_Continue;
}

public Action Event_ZombieIgnited(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));

	char victimname[16];
	event.GetString("userid", victimname, sizeof(victimname));

	if (IsValidClient(client, true)) return Plugin_Continue;
	if (IsClientSurvivor(client)) {
		if (StrEqual("Tank", victimname, false) && !g_aPlayerStorage[client][Player_BurnedTank]) {
			RewardPoints(client, "burn_tank");
			g_aPlayerStorage[client][Player_BurnedTank] = true;
		}

		if (StrEqual("Witch", victimname, false) && !g_aPlayerStorage[client][Player_BurnedWitch]) {
			RewardPoints(client, "burn_witch");
			g_aPlayerStorage[client][Player_BurnedWitch] = true;
		}
	}

	return Plugin_Continue;
}

public Action Event_FinaleWin(Event event, const char[] name, bool dontBroadcast) {
	// TODO: Event_FinaleWin
	NyxMsgDebug("TODO: Event_FinaleWin");

	return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	int winner = event.GetInt("winner");

	RewardPointsTeam(winner, "round_won");
	RewardPointsTeam((winner == 2) ? 3: 2, "round_lost");

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

public Action Timer_TankAllowed(Handle timer) {
	g_iGameSettings[Game_TankAllowed] = true;
}

/***
 *        ___       __          _          ______                                          __    
 *       /   | ____/ /___ ___  (_)___     / ____/___  ____ ___  ____ ___  ____ _____  ____/ /____
 *      / /| |/ __  / __ `__ \/ / __ \   / /   / __ \/ __ `__ \/ __ `__ \/ __ `/ __ \/ __  / ___/
 *     / ___ / /_/ / / / / / / / / / /  / /___/ /_/ / / / / / / / / / / / /_/ / / / / /_/ (__  ) 
 *    /_/  |_\__,_/_/ /_/ /_/_/_/ /_/   \____/\____/_/ /_/ /_/_/ /_/ /_/\__,_/_/ /_/\__,_/____/  
 *                                                                                               
 */

public Action AdmCmd_GivePoints(int client, int args) {
	if (args < 1) {
		NyxMsgReply(client, "Usage: nyx_givepoints <#userid|name> [points]");
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

	int points = GetCmdIntEx(2, 0, INT_MAX, 120);
	for (int i = 0; i < target_count; i++) {
		AddClientPoints(target_list[i], points);
		LogAction(client, target_list[i], "\"%L\" gave \"%i\" points to \"%L\"", client, points, target_list[i]);
	}
	NyxAct(client, "Gave %i points to %s", points, target_name);

	return Plugin_Handled;
}

public Action AdmCmd_ReloadConfig(int client, int args) {
	g_hData = GetKeyValuesFromFile("buy.cfg", "data");
	g_hConfig = GetKeyValuesFromFile("options.cfg", "config");

	if (g_hData == null || g_hConfig == null) {
		NyxMsgReply(client, "Failed to reload configs. See console for errors.");
	} else {
		NyxMsgReply(client, "Reload complete!");
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
			NyxPrintToChat(client, "%t", "Insufficient Points");
		} else {
			Display_MainMenu(client);
		}

		return Plugin_Handled;
	}

	char item_name[32];
	GetCmdArg(1, item_name, sizeof(item_name));

	if (IsValidClient(client) || true) {
		BuyItem(client, item_name);
	}

	return Plugin_Handled;
}

public Action ConCmd_GivePoints(int client, int args) {
	if (args < 1) {
		if (!IsValidClient(client)) {
			NyxMsgReply(client, "Cannot display buy menu to console");
		} else if (GetClientPoints(client) <= 5) {
			NyxPrintToChat(client, "%t", "Insufficient Points");
		} else {
			Display_GivePointsMenu(client);
		}

		return Plugin_Handled;
	}

	int target = GetCmdTarget(1, client, false, false);
	int amount = GetCmdIntEx(2, 1, 120, 5);

	if (GetClientPoints(client) < amount) {
		NyxPrintToChat(client, "%t", "Insufficient Points");
	} else if (client == target) {
		NyxPrintToChat(client, "%t", "Sent Self Points");
	} else if (GetClientTeam(client) != GetClientTeam(target)) {
		NyxPrintToChat(client, "%t", "Sent Wrong Team Points");
	} else {
		int spent = GiveClientPoints(target, amount);
		SubClientPoints(client, spent);
		NyxPrintToTeam(GetClientTeam(client), "%t", "Sent Points", client, spent, target);
		NyxPrintToChat(client, "%t", "Points Left", GetClientPoints(client));

		if (spent == 0) {
			NyxPrintToChat(client, "%t", "Sent Zero Points");
		}
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
		if (!IsValidClient(i, true)) continue;
		if (GetClientTeam(i) != GetClientTeam(client)) continue;
		if (i == client) {
			NyxPrintToChat(client, "%t", "Show Points", GetClientPoints(client));
			continue;
		}

		NyxPrintToChat(client, "%t", "Show Points Other", i, GetClientPoints(i));
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

void Display_MainMenu(int client) {
	Menu menu = new Menu(MenuHandler_MainMenu);

	char title[32];
	Format(title, sizeof(title), "%i Points", GetClientPoints(client));
	menu.SetTitle(title);

	g_hData.Rewind();
	if (!g_hData.GotoFirstSubKey()) {
		delete menu;
		return;
	}

	any data[NyxData];
	do {
		g_hData.GetSectionName(data[Data_Group], sizeof(data[Data_Group]));
		g_hData.GetString("team_name", data[Data_TeamName], sizeof(data[Data_TeamName]), "both");

		if (strcmp(data[Data_Group], "main", false) == 0 ||
				strcmp(data[Data_Group], "infected", false) == 0)
		{
			// check if the group we're in has sections
			if (!g_hData.GotoFirstSubKey()) {
				continue;
			}

			do {
				g_hData.GetSectionName(data[Data_Section], sizeof(data[Data_Section]));

				g_hData.GetString("name", data[Data_Name], sizeof(data[Data_Name]));
				if (strlen(data[Data_Name]) == 0) {
					strcopy(data[Data_Name], sizeof(data[Data_Name]), data[Data_Section]);
				}

				g_hData.GetString("team_name", data[Data_TeamName], sizeof(data[Data_TeamName]), data[Data_TeamName]);
				if (GetClientTeam(client) == L4D2_StringToTeam(data[Data_TeamName]) ||
						strcmp(data[Data_TeamName], "both", false) == 0)
				{
					data[Data_Cost] = g_hData.GetNum("cost", -1);
					menu.AddItem(data[Data_Section], data[Data_Name],
							GetClientPoints(client) >= data[Data_Cost] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
					NyxMsgDebug("section: %s, name: %s", data[Data_Section], data[Data_Name]);
				}
			} while (g_hData.GotoNextKey());

			g_hData.GoBack();
		} else {
			g_hData.GetString("name", data[Data_Name], sizeof(data[Data_Name]));
			if (strlen(data[Data_Name]) == 0) {
				strcopy(data[Data_Name], sizeof(data[Data_Name]), data[Data_Group]);
			}

			if (GetClientTeam(client) == L4D2_StringToTeam(data[Data_TeamName]) ||
					strcmp(data[Data_TeamName], "both", false) == 0)
			{
				menu.AddItem(data[Data_Group], data[Data_Name]);
				NyxMsgDebug("group: %s, name: %s", data[Data_Group], data[Data_Name]);
			}
		}

	} while (g_hData.GotoNextKey(false));

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void Display_SubMenu(int client, const char[] info) {
	Menu menu = new Menu(MenuHandler_MainMenu);

	char title[32];
	Format(title, sizeof(title), "%i Points", GetClientPoints(client));
	menu.SetTitle(title);

	g_hData.Rewind();
	if (!g_hData.GotoFirstSubKey()) {
		delete menu;
		return;
	}

	any data[NyxData];
	do {
		g_hData.GetSectionName(data[Data_Group], sizeof(data[Data_Group]));
		g_hData.GetString("team_name", data[Data_TeamName], sizeof(data[Data_TeamName]), "both");

		if (strcmp(data[Data_Group], info, false) == 0) {
			// check if the group we're in has sections
			if (!g_hData.GotoFirstSubKey()) {
				continue;
			}

			do {
				g_hData.GetSectionName(data[Data_Section], sizeof(data[Data_Section]));

				g_hData.GetString("name", data[Data_Name], sizeof(data[Data_Name]));
				if (strlen(data[Data_Name]) == 0) {
					strcopy(data[Data_Name], sizeof(data[Data_Name]), data[Data_Section]);
				}

				g_hData.GetString("team_name", data[Data_TeamName], sizeof(data[Data_TeamName]), data[Data_TeamName]);
				if (GetClientTeam(client) == L4D2_StringToTeam(data[Data_TeamName]) ||
						strcmp(data[Data_TeamName], "both", false) == 0)
				{
					data[Data_Cost] = g_hData.GetNum("cost", -1);
					menu.AddItem(data[Data_Section], data[Data_Name],
							GetClientPoints(client) >= data[Data_Cost] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
					NyxMsgDebug("section: %s, name: %s", data[Data_Section], data[Data_Name]);
				}
			} while (g_hData.GotoNextKey());

			g_hData.GoBack();
		} else {
			if (g_hData.JumpToKey(info)) {
				NyxMsgDebug("info '%s' is an item", info);
				Display_ConfirmMenu(client, info);

				delete menu;
				return;
			}

			NyxMsgDebug("group '%s' does not equal info '%s'", data[Data_Group], info);
		}

	} while (g_hData.GotoNextKey(false));

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void Display_ConfirmMenu(int client, const char[] info) {
	Menu menu = new Menu(MenuHandler_ConfirmMenu);
	
	char title[32];
	any data[NyxData]; GetItemData(info, data);
	Format(title, sizeof(title), "Cost: %i", data[Data_Cost]);
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

public int MenuHandler_MainMenu(Menu menu, MenuAction action, int param1, int param2) {
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

		if (IsValidClient(param1)) {
			Display_SubMenu(param1, info);
		}
	}

	return;
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
			BuyItem(param1, info);
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
				NyxPrintToChat(param1, "%t", "My Points", GetClientPoints(param1));

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

void HandleError(int client, NyxError error) {
	switch (error) {
		case Error_MissingKey: {
			NyxMsgDebug("Missing key");
		}
		case Error_MissingReward: {
			NyxMsgDebug("Missing reward");
		}
		case Error_MaxedPoints: {
			int points = GetClientPoints(client);
			int maxPoints = g_iGameSettings[Game_MaxPoints];

			NyxPrintToChat(client, "%t", "Max Points", points, maxPoints);
		}
	}
}

NyxError RewardPoints(int client, const char[] reward, const char[] type="reward") {
	g_hConfig.Rewind();

	if (!g_hConfig.JumpToKey("rewards")) {
		return Error_MissingKey;
	}

	if (g_hConfig.JumpToKey(reward)) {
		char value[16]; g_hConfig.GetString(type, value, sizeof(value));
		int points = StringToInt(value);
		if (points == 0) {
			return Error_MissingReward;
		}

		int given = GiveClientPoints(client, points);
		if (given == 0) {
			return Error_MaxedPoints;
		}

		g_aPlayerStorage[client][Player_Reward] = given;
	} else {
		return Error_MissingKey;
	}

	return Error_None;
}

void RewardPointsTeam(int team, const char[] reward, const char[] type="reward") {
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i, true)) continue;
		if (GetClientTeam(i) != team) continue;

		NyxError error = RewardPoints(i, reward, type);
		if (error) {
			HandleError(i, error);
		}
	}
}

bool BuyItem(int client, const char[] item_name) {
	any data[NyxData];
	bool exists = GetItemData(item_name, data);

/* Uncomment for debugging
	NyxMsgDebug("Group: %s, Section: %s, Name: %s, Cost %i",
						data[Data_Group],
						data[Data_Section],
						data[Data_Name],
						data[Data_Cost];
	NyxMsgDebug("Shortcut: %s, Command: %s, CommandArgs: %s",
						data[Data_Shortcut],
						data[Data_Command],
						data[Data_CommandArgs]);
	NyxMsgDebug("TeamName: %s, MissionLimit: %i, HealMultiplier: %i",
						data[Data_TeamName],
						data[Data_MissionLimit],
						data[Data_HealMultiplier]);
	NyxMsgDebug("MustBeAlive: %d, MustBeIncapacitated: %d, MustBeGrabbed]: %d",
						data[MustBeAlive]
						data[Data_MustBeIncapacitated],
						data[Data_MustBeGrabbed];
*/

	if (!exists) {
		NyxPrintToChat(client, "%t", "Item Doesn't Exist", item_name);
		return false;
	} else if (GetClientPoints(client) < data[Data_Cost]) {
		NyxPrintToChat(client, "%t", "Insufficient Points");
		return false;
	} else if (GetClientTeam(client) != L4D2_StringToTeam(data[Data_TeamName]) &&
			!StrEqual(data[Data_TeamName], "both", false))
	{
		NyxPrintToChat(client, "%t", "Item Wrong Team");
		return false;
	} else if (!IsPlayerAlive(client) && data[Data_MustBeAlive]) {
		NyxPrintToChat(client, "%t", "Must Be Alive");
		return false;
	} else if (IsPlayerAlive(client) && !data[Data_MustBeAlive]) {
		NyxPrintToChat(client, "%t", "Must Be Dead");
		return false;
	} else if (!IsClientIncapacitated(client) && data[Data_MustBeIncapacitated]) {
		NyxPrintToChat(client, "%t", "Must Be Incapacitated");
		return false;
	} else if (!IsClientGrabbed(client) && data[Data_MustBeGrabbed]) {
		NyxPrintToChat(client, "%t", "Must Be Grabbed");
		return false;
	} else {
		char command_args[256];
		Format(command_args, sizeof(command_args), "%s %s", data[Data_Section], data[Data_CommandArgs]);
		FakeClientCommandCheat(client, data[Data_Command], command_args);
		SubClientPoints(client, data[Data_Cost]);
	}

	return true;
}

bool GetItemData(const char[] item_name, any[NyxData] data) {
	g_hData.Rewind();
	if (!g_hData.GotoFirstSubKey()) {
		return false;
	}

	bool found_item;
	do {
		g_hData.GetSectionName(data[Data_Group], sizeof(data[Data_Group]));
		g_hData.GetString("command", data[Data_Command], sizeof(data[Data_Command]), "give");
		g_hData.GetString("command_args", data[Data_CommandArgs], sizeof(data[Data_CommandArgs]));
		g_hData.GetString("team_name", data[Data_TeamName], sizeof(data[Data_TeamName]), "both");
		data[Data_MustBeAlive] = (g_hData.GetNum("must_be_alive", 1) == 1);

		// check if the group we're in has sections
		if (!g_hData.GotoFirstSubKey()) {
			continue;
		}

		do {
			g_hData.GetSectionName(data[Data_Section], sizeof(data[Data_Section]));

			// find what we're searching for
			if (strcmp(data[Data_Section], item_name, false) == 0) found_item = true;
			if (g_hData.JumpToKey("shortcut")) {
				g_hData.GetString(NULL_STRING, data[Data_Shortcut], sizeof(data[Data_Shortcut]));
				g_hData.GoBack();

				if (strcmp(data[Data_Shortcut], item_name, false) == 0) found_item = true;
			}

			// found what we're looking for; get our data and stop the sub loop
			if (found_item) {
				g_hData.GetString("name", data[Data_Name], sizeof(data[Data_Name]), data[Data_Section]);
				g_hData.GetString("command", data[Data_Command], sizeof(data[Data_Command]), data[Data_Command]);
				g_hData.GetString("command_args", data[Data_CommandArgs], sizeof(data[Data_CommandArgs]), data[Data_CommandArgs]);
				g_hData.GetString("team_name", data[Data_TeamName], sizeof(data[Data_TeamName]), data[Data_TeamName]);
				data[Data_Cost] = g_hData.GetNum("cost", -1);
				data[Data_MustBeAlive] = (g_hData.GetNum("must_be_alive", data[Data_MustBeAlive]) == 1);
				data[Data_MustBeIncapacitated] = (g_hData.GetNum("must_be_incapacitated", 0) == 1);
				data[Data_MustBeGrabbed] = (g_hData.GetNum("must_be_grabbed", 0) == 1);

				return true;
			}
		} while (g_hData.GotoNextKey());

		g_hData.GoBack();
	} while (g_hData.GotoNextKey(false));

	return false;
}

void FakeClientCommandCheat(int client, const char[] cmd, const char[] args) {
	char buffer[256];
	Format(buffer, sizeof(buffer), "%s %s", cmd, args);

	if (GetCommandFlags(cmd) & FCVAR_CHEAT) {
		SetCommandFlags(cmd, GetCommandFlags(cmd) ^ FCVAR_CHEAT);
		FakeClientCommand(client, buffer);
		SetCommandFlags(cmd, GetCommandFlags(cmd) | FCVAR_CHEAT);

		return;
	}

	FakeClientCommand(client, buffer);
}

KeyValues GetKeyValuesFromFile(const char[] file, const char[] section, bool fail_state = true) {
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/nyx_pointsystem/%s", file);

	KeyValues kv = new KeyValues("data");
	if (kv.ImportFromFile(path)) {
		char buffer[256];
		if (!kv.GetSectionName(buffer, sizeof(buffer))) {
			if (fail_state) SetFailState("Error in %s: File corrupt or in the wrong format", path);
			return null;
		}

		if (strcmp(buffer, section) != 0) {
			if (fail_state) SetFailState("Error in %s: Couldn't find '%s'", path, section);
			return null;
		}
		
		kv.Rewind();
	} else {
		if (fail_state) SetFailState("Error in %s: File not found, corrupt or in the wrong format", path);
		return null;
	}

	return kv;
}

/***
 *        __    _ __                    _          
 *       / /   (_) /_  _________ ______(_)__  _____
 *      / /   / / __ \/ ___/ __ `/ ___/ / _ \/ ___/
 *     / /___/ / /_/ / /  / /_/ / /  / /  __(__  ) 
 *    /_____/_/_.___/_/   \__,_/_/  /_/\___/____/  
 *                                                 
 */

 int GetPlayerReward(int client) {
	 return g_aPlayerStorage[client][Player_Reward];
 }

int GetConfigKeyInt(const char[] key, int def=-1) {
	char buffer[256];
	bool exists = GetConfigKeyString(key, buffer, sizeof(buffer));

	if (exists) {
		return StringToInt(buffer);
	}

	return def;
}

bool GetConfigKeyString(const char[] key, char[] buffer, int maxlength) {
	g_hConfig.Rewind();

	if (g_hConfig.JumpToKey(key)) {
		g_hConfig.GetString(NULL_STRING, buffer, maxlength);

		return true;
	}

	return false;
}

int GetRewardKeyInt(const char[] reward, const char[] key, int def=-1) {
	char buffer[256];
	bool exists = GetRewardKeyString(reward, key, buffer, sizeof(buffer));

	if (exists) {
		return StringToInt(buffer);
	}

	return def;
}

bool GetRewardKeyString(const char[] reward, const char[] key, char[] buffer, int maxlength) {
	g_hConfig.Rewind();

	if (!g_hConfig.JumpToKey("rewards")) {
		NyxMsgDebug("missing 'rewards' section");
		return false;
	}

	if (g_hConfig.JumpToKey(reward)) {
		g_hConfig.GetString(key, buffer, maxlength);

		return true;
	}

	return false;
}

int GetClientPoints(int client) {
	return g_aPlayerStorage[client][Player_Points];
}

void SetClientPoints(int client, int points) {
	g_aPlayerStorage[client][Player_Points] = points;
}

void AddClientPoints(int client, int points) {
	g_aPlayerStorage[client][Player_Points] += points;
}

void SubClientPoints(int client, int points) {
	g_aPlayerStorage[client][Player_Points] -= points;
}

int GiveClientPoints(int client, int points) {
	int total = GetClientPoints(client) + points;

	if (total > g_iGameSettings[Game_MaxPoints]) {
		int min = MathMin(points, total - g_iGameSettings[Game_MaxPoints]);
		int max = MathMax(points, total - g_iGameSettings[Game_MaxPoints]);
		int spent = max - min;

		if (spent >= g_iGameSettings[Game_MaxPoints]) {
			return 0;
		}

		AddClientPoints(client, spent);
		return spent;
	}

	AddClientPoints(client, points);
	return points;
}

bool IsClientSurvivor(int client) {
	if (!IsValidClient(client)) return false;
	if (GetClientTeam(client) == L4D2_TEAM_INFECTED) return false;

	return true;
}

bool IsClientInfected(int client) {
	if (!IsValidClient(client)) return false;
	if (GetClientTeam(client) == L4D2_TEAM_SURVIVOR) return false;

	return true;
}

bool IsClientGhost(int client) {
	if (!IsValidClient(client)) return false;
	if (!GetEntData(client, FindSendPropInfo("CTerrorPlayer", "m_isGhost"), 1) return false;

	return true;
}

bool IsClientTank(int client) {
	if (!IsValidClient(client)) return false;
	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 8) return false;
	
	return true;
}

bool IsClientGrabbed(int client) {
	if (GetEntProp(client, Prop_Send, "m_pummelAttacker") > 0) return true;
	if (GetEntProp(client, Prop_Send, "m_carryAttacker") > 0) return true;
	if (GetEntProp(client, Prop_Send, "m_pounceAttacker") > 0) return true;
	if (GetEntProp(client, Prop_Send, "m_jockeyAttacker") > 0) return true;
	if (GetEntProp(client, Prop_Send, "m_tongueOwner") > 0) return true;

	return false;
}

bool IsClientIncapacitated(int client) {
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0) return true;
	
	return false;
}

bool IsFireDamage(int type){
	if (type == 8 || type == 2056) return true;
	
	return false;
}

bool IsSpitterDamage(int type){
	if (type == 263168 || type == 265216) return true;

	return false;
}

stock void NyxPrintToTeam(int team, char[] format, any ...) {
	char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 3);

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i, true)) continue;
		if (GetClientTeam(i) != team) continue;

		NyxPrintToChat(i, buffer);
	}
}

stock void NyxPrintToChat(int client, char[] format, any ...) {
	char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 3);
	CPrintToChat(client, "{green}[%s]{default} %s", NYX_PLUGIN_NAME, buffer);
}
