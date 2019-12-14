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

///
/// Enums
///

enum NyxData {
		String:Data_Group[64],
		String:Data_Section[64],
		String:Data_Command[64],
		String:Data_CommandArgs[64],
		String:Data_Name[64],
		String:Data_Shortcut[16],
		String:Data_TeamName[16],
		Data_Cost,
		Data_MissionLimit,
		Data_HealMultiplier
}

enum NyxConVar {
	Handle:ConVar_Version,
	Handle:ConVar_StartPoints,
	Handle:ConVar_MaxPoints,
}

enum NyxPlayer {
	Player_Points,
	Player_Headshots,
	Player_Kills,
	Player_HurtCount
}

///
/// Globals
///

KeyValues g_hData;
KeyValues g_hConfig;
ConVar g_hConVars[NyxConVar];

int g_iMenuTarget[MAXPLAYERS + 1];
any g_aPlayerStorage[MAXPLAYERS + 1][NyxPlayer];

///
/// ConVars
///

ConVar nyx_ps_version;
ConVar nyx_ps_start_points;
ConVar nyx_ps_max_points;

///
/// Plugin Interfaces
///

public void OnPluginStart() {
	LoadTranslations("common.phrases");
	LoadTranslations("nyx_pointsystem.phrases");
	//LoadTranslations("points_system.phrases");

	// Console Commands
	RegConsoleCmd("sm_buy", ConCmd_Buy);
	RegConsoleCmd("sm_gp", ConCmd_GivePoints);

	// Admin commands
	RegAdminCmd("nyx_givepoints", AdmCmd_GivePoints, ADMFLAG_ROOT, "nyx_givepoints <#userid|name> [points]");

	// ConVars
	g_hConVars[ConVar_Version] = CreateConVar("nyx_ps_version", NYX_PLUGIN_VERSION);
	nyx_ps_max_points = CreateConVar("nyx_ps_max_points", "120");
	nyx_ps_start_points = CreateConVar("nyx_ps_start_points", "10");

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
	InitVariables();
}

public void OnPluginEnd() {

}

///
/// Extention interfaces
///

public Action L4D_OnFirstSurvivorLeftSafeArea(int client) {
	return Plugin_Continue;
}

///
/// Events
///

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	bool headshot = event.GetBool("headshot");

	if (!IsValidClient(attacker, true)) return Plugin_Continue;
	if (IsClientSurvivor(attacker)) {
		if (!IsClientInfected(victim)) return Plugin_Continue;
		if (IsClientTank(victim)) return Plugin_Continue;

		RewardPoints(attacker, "killed_special_infected");
	} else {
		if (!IsClientSurvivor(victim)) return Plugin_Continue;

		RewardPoints(attacker, "killed_survivor");
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
				RewardPoints(attacker, "hurt_player");
			}
		} else if (IsFireDamage(type)) {
			return Plugin_Continue;
		} else {
			if (g_aPlayerStorage[attacker][Player_HurtCount] % 3 == 0) {
				RewardPoints(attacker, "hurt_player");
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
		RewardPoints(attacker, "incapacitated_player");
	}

	return Plugin_Continue;
}

public Action Event_PlayerNowIt(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (!IsValidClient(attacker, true)) return Plugin_Continue;
	if (IsClientSurvivor(attacker)) {
		if (!IsClientTank(victim)) return Plugin_Continue;

		RewardPoints(attacker, "bile_tank");
	} else {
		if (!IsClientSurvivor(victim)) return Plugin_Continue;

		RewardPoints(attacker, "bile_player");
	}

	return Plugin_Continue;
}

public Action Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	bool headshot = event.GetBool("headshot");

	if (!IsValidClient(attacker, true)) return Plugin_Continue;
	if (IsClientSurvivor(attacker)) {
		int streak;
		char streak_str[16]; 

		if (headshot) {
			g_aPlayerStorage[attacker][Player_Headshots]++;

			GetRewardKeyValue("headshot_streak", "streak", streak_str, sizeof(streak_str));
			streak = StringToInt(streak_str);
			if (streak > 0) {
				if ((g_aPlayerStorage[attacker][Player_Headshots] % streak) == 0) {
					RewardPoints(attacker, "headshot_streak");
				}
			}
		}

		g_aPlayerStorage[attacker][Player_Kills]++;
		
		GetRewardKeyValue("kill_streak", "streak", streak_str, sizeof(streak_str));
		streak = StringToInt(streak_str);
		if (streak > 0) {
			if ((g_aPlayerStorage[attacker][Player_Kills] % streak) == 0) {
				RewardPoints(attacker, "kill_streak");
			}
		}
	}

	return Plugin_Continue;
}

public Action Event_TankKilled(Event event, const char[] name, bool dontBroadcast) {
	//int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	bool solo = event.GetBool("solo");

	if (!IsValidClient(attacker, true)) return Plugin_Continue;
	if (IsClientSurvivor(attacker)) {
		if (solo) {
			RewardPoints(attacker, "killed_tank_solo");
		}

		RewardTeamPoints(GetClientTeam(attacker), "killed_tank");
	}

	return Plugin_Continue;
}

public Action Event_WitchKilled(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	bool oneshot = event.GetBool("oneshot");

	if (!IsValidClient(client, true)) return Plugin_Continue;
	if (IsClientSurvivor(client)) {
		if (oneshot) {
			RewardPoints(client, "killed_witch_oneshot");
		}

		RewardPoints(client, "killed_witch");
	}

	return Plugin_Continue;
}

public Action Event_ChokeStart(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(client, true)) return Plugin_Continue;
	if (IsClientInfected(client)) {
		RewardPoints(client, "choke_player");
	}

	return Plugin_Continue;
}

public Action Event_LungePounce(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(client, true)) return Plugin_Continue;
	if (IsClientInfected(client)) {
		RewardPoints(client, "pounce_player");
	}

	return Plugin_Continue;
}

public Action Event_JockeyRide(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(client, true)) return Plugin_Continue;
	if (IsClientInfected(client)) {
		RewardPoints(client, "ride_player");
	}

	return Plugin_Continue;
}

public Action Event_ChargerCarryStart(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(client, true)) return Plugin_Continue;
	if (IsClientInfected(client)) {
		RewardPoints(client, "carry_player");
	}

	return Plugin_Continue;
}

public Action Event_ChargerImpact(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(client, true)) return Plugin_Continue;
	if (IsClientInfected(client)) {
		RewardPoints(client, "impact_player");
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
		RewardPoints(client, "heal_player");
	} else {
		RewardPoints(client, "heal_player", "reward_partial");
	}

	return Plugin_Continue;
}

public Action Event_AwardEarned(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("subject"));
	int award = event.GetInt("award");

	if (!IsValidClient(client)) return Plugin_Continue;
	if (!IsClientSurvivor(client)) return Plugin_Continue;

	if (award == 67) { // 67=Protect
		NyxMsgDebug("TODO: give reward on every 6 protects");
		RewardPoints(client, "protect_player"); // TODO: give reward on every 6 protects
	}

	return Plugin_Continue;
}

public Action Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));
	bool lastlife = event.GetBool("lastlife");
	bool ledge_hang = event.GetBool("ledge_hang");

	if (!IsValidClient(client)) return Plugin_Continue;
	if (!IsClientSurvivor(client)) return Plugin_Continue;
	if (client == subject) return Plugin_Continue;

	if (ledge_hang) {
		RewardPoints(client, "revive", "ledge_hang");
	} else {
		RewardPoints(client, "revive");
	}

	return Plugin_Continue;
}

public Action Event_DefibrillatorUsed(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (IsValidClient(client, true)) return Plugin_Continue;
	if (IsClientSurvivor(client)) {
		RewardPoints(client, "revive_player");
	}

	return Plugin_Continue;
}

public Action Event_ZombieIgnited(Event event, const char[] name, bool dontBroadcast) {
	NyxMsgDebug("TODO: Event_ZombieIgnited");

	/*
	decl String:sVictimName[30]; sVictimName[0] = '\0';
	GetEventString(hEvent, "victimname", sVictimName, sizeof(sVictimName));
	int iClientIndex = getClientIndex(hEvent);

	if(IsModEnabled() && !IsClientBot(iClientIndex)){
		if(IsClientSurvivor(iClientIndex)){
			if(StrEqual(sVictimName, "Tank", false)){
				int iTankBurnReward = GetConVarInt(PointRewards[SurvBurnTank]);
				if(iTankBurnReward > 0)
					if(!PlayerData[iClientIndex][bTankBurning]){
						PlayerData[iClientIndex][bTankBurning] = true;
						addPoints(iClientIndex, iTankBurnReward, "Burn Tank");
					}
			}
			else if(StrEqual(sVictimName, "Witch", false)){
				int iWitchBurnReward = GetConVarInt(PointRewards[SurvBurnWitch]);
				if(iWitchBurnReward > 0){
					if(!PlayerData[iClientIndex][bWitchBurning]){
						PlayerData[iClientIndex][bWitchBurning] = true;
						addPoints(iClientIndex, iWitchBurnReward, "Burn Witch");
					}
				}
			}
		}
	}
	*/

	return Plugin_Continue;
}

public Action Event_FinaleWin(Event event, const char[] name, bool dontBroadcast) {
	// TODO: Event_FinaleWin
	NyxMsgDebug("TODO: Event_FinaleWin");

	return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	int winner = event.GetInt("winner");

	RewardTeamPoints(winner, "round_won");
	RewardTeamPoints((winner == 2) ? 3: 2, "round_lost");

	return Plugin_Continue;
}

///
/// Admin Commands
///

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
		SetClientPoints(target_list[i], points);
		LogAction(client, target_list[i], "\"%L\" gave \"%i\" points to \"%L\"", client, points, target_list[i]);
	}
	NyxAct(client, "Gave '%i' points to %s", points, target_name);

	return Plugin_Handled;
}

///
/// Console Commands
///

public Action ConCmd_Buy(int client, int args) {
	if (args < 1) {
		if (!IsValidClient(client)) {
			NyxMsgReply(client, "Cannot display buy menu to console");
		} else if (GetClientPoints(client) <= 0) {
			CPrintToChat(client, "[%s] %t", NYX_PLUGIN_NAME, "Insufficient Points");
		} else {
			Display_MainMenu(client);
		}

		return Plugin_Handled;
	}

	char item_name[32];
	GetCmdArg(1, item_name, sizeof(item_name));

	if (IsValidClient(client) || true) {
		any data[NyxData];
		bool fount = GetItemData(item_name, data);

		if (fount) {
			NyxMsgDebug("group: %s, section: %s, name: %s, cost %i, shortcut: %s, command: %s, command_args: %s",
								data[Data_Group],
								data[Data_Section],
								data[Data_Name],
								data[Data_Cost],
								data[Data_Shortcut],
								data[Data_Command],
								data[Data_CommandArgs]);
			NyxMsgDebug("team_name: %s, mission_limit: %i, heal_multiplier: %i",
								data[Data_TeamName],
								data[Data_MissionLimit],
								data[Data_HealMultiplier]);
		} else {
			NyxMsgReply(client, "Item '%s' not found.", item_name);
		}
	}

	return Plugin_Handled;
}

public Action ConCmd_GivePoints(int client, int args) {
	if (args < 1) {
		if (!IsValidClient(client)) {
			NyxMsgReply(client, "Cannot display buy menu to console");
		} else if (GetClientPoints(client) <= 5) {
			CPrintToChat(client, "[%s] %t", NYX_PLUGIN_NAME, "Insufficient Points");
		} else {
			Display_GivePointsMenu(client);
		}

		return Plugin_Handled;
	}

	int target = GetCmdTarget(1, client, false, false);
	int amount = GetCmdIntEx(2, 1, 120, 5);

	if (GetClientPoints(client) < amount) {
		CPrintToChat(client, "[%s] %t", NYX_PLUGIN_NAME, "Insufficient Points");
	} else if (client == target) {
		CPrintToChat(client, "[%s] %t", NYX_PLUGIN_NAME, "Sent Self Points");
	} else if (GetClientTeam(client) != GetClientTeam(target)) {
		CPrintToChat(client, "[%s] %t", NYX_PLUGIN_NAME, "Sent Wrong Team Points");
	} else {
		int spent = GiveClientPoints(target, amount);
		SubClientPoints(client, spent);
		CPrintToChatTeam(client, "[%s] %t", NYX_PLUGIN_NAME, "Sent Points", client, spent, target);
		CPrintToChat(client, "[%s] %t", NYX_PLUGIN_NAME, "My Points", GetClientPoints(client));

		if (spent == 0) {
			CPrintToChat(client, "[%s] %t", NYX_PLUGIN_NAME, "Sent Zero Points");
		}
	}

	return Plugin_Handled;
}

///
/// Menus
///

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
	menu.SetTitle("Confirm");
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

		if (IsValidClient(param1)) {
			any data[NyxData];
			GetItemData(info, data);

			char command_args[256];
			Format(command_args, sizeof(command_args), "%s %s", data[Data_Section], data[Data_CommandArgs]);
			FakeClientCommandCheat(param1, data[Data_Command], command_args);
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
			CPrintToChat(param1, "[%s] %t", NYX_PLUGIN_NAME, "Player no longer available");
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
			CPrintToChat(param1, "[%s] %t", NYX_PLUGIN_NAME, "Player no longer available");
		} else {
			if (GetClientPoints(param1) < amount) {
				CPrintToChat(param1, "[%s] %t", NYX_PLUGIN_NAME, "Insufficient Points", amount);
			} else {
				int spent = GiveClientPoints(target, amount);

				SubClientPoints(param1, spent);
				CPrintToChatTeam(param1, "[%s] %t", NYX_PLUGIN_NAME, "Sent Points", param1, spent, target);
				CPrintToChat(param1, "[%s] %t", NYX_PLUGIN_NAME, "My Points", GetClientPoints(param1));

				if (spent == 0) {
					CPrintToChat(param1, "[%s] %t", NYX_PLUGIN_NAME, "Sent Zero Points");
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

///
/// Functions
///

void InitVariables() {
	for (int i = 1; i <= MaxClients; i++) {
		g_aPlayerStorage[i][Player_Points] = nyx_ps_start_points.IntValue;
	}
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

bool RewardPoints(int client, const char[] key, const char[] type="reward") {
	g_hConfig.Rewind();

	if (!g_hConfig.JumpToKey("rewards")) {
		NyxMsgDebug("missing 'rewards' section");
		return false;
	}

	if (g_hConfig.JumpToKey(key)) {
		char value[16]; g_hConfig.GetString(type, value, sizeof(value));
		int reward = StringToInt(value);
		if (reward <= 0) {
			NyxMsgDebug("reward is less or equal to zero");
			return false;
		}

		int spent = GiveClientPoints(client, reward);
		if (spent == 0) {
			CPrintToChat(client, "[%s] %t", NYX_PLUGIN_NAME, "Max Points",
					GetClientPoints(client), nyx_ps_max_points.IntValue);

			return false;
		}

		char phrase[128]; g_hConfig.GetString("phrase", phrase, sizeof(phrase), "Reward");
		CPrintToChat(client, "[%s] %t", NYX_PLUGIN_NAME, phrase, spent);
	} else {
		NyxMsgDebug("reward key '%s' not found", key);
		return false;
	}

	return true;
}

void RewardTeamPoints(int team, const char[] key, const char[] type="reward") {
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i, true)) continue;
		if (GetClientTeam(i) != team) continue;

		RewardPoints(i, key, type);
	}
}

bool GetRewardKeyValue(const char[] reward, const char[] key, char[] buffer, int maxlength) {
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

	if (total > nyx_ps_max_points.IntValue) {
		int min = MathMin(points, total - nyx_ps_max_points.IntValue);
		int max = MathMax(points, total - nyx_ps_max_points.IntValue);
		int spent = max - min;

		if (spent >= nyx_ps_max_points.IntValue) {
			return 0;
		}

		AddClientPoints(client, spent);
		return spent;
	}

	AddClientPoints(client, points);
	return points;
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
				data[Data_MissionLimit] = g_hData.GetNum("mission_limit", -1);
				data[Data_HealMultiplier] = g_hData.GetNum("heal_multiplier", -1);
				data[Data_Cost] = g_hData.GetNum("cost", -1);

				return true;
			}
		} while (g_hData.GotoNextKey());

		g_hData.GoBack();
	} while (g_hData.GotoNextKey(false));

	return false;
}

///
/// Libs
///

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

stock void CPrintToChatTeam(int client, char[] format, any ...) {
	char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 3);

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i, true)) continue;
		if (GetClientTeam(i) != GetClientTeam(client)) continue;

		CPrintToChat(i, buffer);
	}
}
