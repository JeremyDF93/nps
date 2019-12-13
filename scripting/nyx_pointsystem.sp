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
		String:NyxData_Group[64],
		String:NyxData_Section[64],
		String:NyxData_Command[64],
		String:NyxData_CommandArgs[64],
		String:NyxData_Name[64],
		String:NyxData_Shortcut[16],
		String:NyxData_TeamName[16],
		NyxData_Cost,
		NyxData_MissionLimit,
		NyxData_HealMultiplier
}

///
/// Globals
///

KeyValues g_hData;

int g_iMenuTarget[MAXPLAYERS + 1];
int g_iPlayerPoints[MAXPLAYERS + 1];

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

	RegConsoleCmd("sm_buy", ConCmd_Buy);
	RegConsoleCmd("sm_gp", ConCmd_GivePoints);

	nyx_ps_version = CreateConVar("nyx_ps_version", NYX_PLUGIN_VERSION);
	nyx_ps_max_points = CreateConVar("nyx_ps_max_points", "120");
	nyx_ps_start_points = CreateConVar("nyx_ps_start_points", "10");

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/nyx_pointsystem/options.cfg");

	g_hData = new KeyValues("data");
	if (g_hData.ImportFromFile(path)) {
		char section[256];
		if (!g_hData.GetSectionName(section, sizeof(section))) {
			SetFailState("Error in %s: File corrupt or in the wrong format", path);
			return;
		}

		if (strcmp(section, "data") != 0) {
			SetFailState("Error in %s: Couldn't find 'data'", path);
			return;
		}
		
		g_hData.Rewind();
	} else {
		SetFailState("Error in %s: File not found, corrupt or in the wrong format", path);
		return;
	}

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



///
/// Commands
///

public Action ConCmd_Buy(int client, int args) {
	if (args < 1) {
		if (!IsValidClient(client)) {
			NyxMsgReply(client, "Cannot display buy menu to console");
		} else if (g_iPlayerPoints[client] <= 0) {
			CPrintToChat(client, "%t", "Insufficient Points", NYX_PLUGIN_NAME);
		} else {
			Display_GivePointsMenu(client);
		}
		if (!IsValidClient(client)) {
			NyxMsgReply(client, "Cannot display buy menu to console");
			return Plugin_Handled;
		}

		Display_MainMenu(client);

		return Plugin_Handled;
	}

	char item_name[32];
	GetCmdArg(1, item_name, sizeof(item_name));

	if (IsValidClient(client)) {
		any data[NyxData];
		GetItemData(item_name, data);

		NyxMsgDebug("group: %s, section: %s, name: %s, cost %i, shortcut: %s, command: %s, command_args: %s",
							data[NyxData_Group],
							data[NyxData_Section],
							data[NyxData_Name],
							data[NyxData_Cost],
							data[NyxData_Shortcut],
							data[NyxData_Command],
							data[NyxData_CommandArgs]);
		NyxMsgDebug("team_name: %s, mission_limit: %i",
							data[NyxData_TeamName],
							data[NyxData_MissionLimit]);
	}

	return Plugin_Handled;
}

public Action ConCmd_GivePoints(int client, int args) {
	if (args < 1) {
		if (!IsValidClient(client)) {
			NyxMsgReply(client, "Cannot display buy menu to console");
		} else if (g_iPlayerPoints[client] <= 0) {
			CPrintToChat(client, "%t", "Insufficient Points", NYX_PLUGIN_NAME);
		} else {
			Display_GivePointsMenu(client);
		}

		return Plugin_Handled;
	}

	int target = GetCmdTarget(1, client, false, false);
	int amount = GetCmdIntEx(2, 1, 120, 5);

	if (g_iPlayerPoints[client] < amount) {
		CPrintToChat(client, "%t", "Insufficient Points", NYX_PLUGIN_NAME);
	} else if (client == target) {
		CPrintToChat(client, "%t", "Sent Self Points", NYX_PLUGIN_NAME);
	} else if (GetClientTeam(client) != GetClientTeam(target)) {
		CPrintToChat(client, "%t", "Sent Wrong Team Points", NYX_PLUGIN_NAME);
	} else {
		int spent = GiveClientPoints(target, amount);
		g_iPlayerPoints[client] -= spent;
		CPrintToChatTeam(client, "%t", "Sent Points", NYX_PLUGIN_NAME, client, spent, target);
		CPrintToChat(client, "%t", "My Points", NYX_PLUGIN_NAME, g_iPlayerPoints[client]);

		if (spent == 0) {
			CPrintToChat(client, "%t", "Sent Zero Points", NYX_PLUGIN_NAME);
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
	Format(title, sizeof(title), "%i Points", g_iPlayerPoints[client]);
	menu.SetTitle(title);

	g_hData.Rewind();
	if (!g_hData.GotoFirstSubKey()) {
		delete menu;
		return;
	}

	any data[NyxData];
	do {
		g_hData.GetSectionName(data[NyxData_Group], sizeof(data[NyxData_Group]));
		g_hData.GetString("team_name", data[NyxData_TeamName], sizeof(data[NyxData_TeamName]), "both");

		if (strcmp(data[NyxData_Group], "main", false) == 0 ||
				strcmp(data[NyxData_Group], "infected", false) == 0)
		{
			// check if the group we're in has sections
			if (!g_hData.GotoFirstSubKey()) {
				continue;
			}

			do {
				g_hData.GetSectionName(data[NyxData_Section], sizeof(data[NyxData_Section]));

				g_hData.GetString("name", data[NyxData_Name], sizeof(data[NyxData_Name]));
				if (strlen(data[NyxData_Name]) == 0) {
					strcopy(data[NyxData_Name], sizeof(data[NyxData_Name]), data[NyxData_Section]);
				}

				g_hData.GetString("team_name", data[NyxData_TeamName], sizeof(data[NyxData_TeamName]), data[NyxData_TeamName]);
				if (GetClientTeam(client) == L4D2_StringToTeam(data[NyxData_TeamName]) ||
						strcmp(data[NyxData_TeamName], "both", false) == 0)
				{
					data[NyxData_Cost] = g_hData.GetNum("cost", -1);
					menu.AddItem(data[NyxData_Section], data[NyxData_Name],
							g_iPlayerPoints[client] >= data[NyxData_Cost] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
					NyxMsgDebug("section: %s, name: %s", data[NyxData_Section], data[NyxData_Name]);
				}
			} while (g_hData.GotoNextKey());

			g_hData.GoBack();
		} else {
			g_hData.GetString("name", data[NyxData_Name], sizeof(data[NyxData_Name]));
			if (strlen(data[NyxData_Name]) == 0) {
				strcopy(data[NyxData_Name], sizeof(data[NyxData_Name]), data[NyxData_Group]);
			}

			if (GetClientTeam(client) == L4D2_StringToTeam(data[NyxData_TeamName]) ||
					strcmp(data[NyxData_TeamName], "both", false) == 0)
			{
				menu.AddItem(data[NyxData_Group], data[NyxData_Name]);
				NyxMsgDebug("group: %s, name: %s", data[NyxData_Group], data[NyxData_Name]);
			}
		}

	} while (g_hData.GotoNextKey(false));

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void Display_SubMenu(int client, const char[] info) {
	Menu menu = new Menu(MenuHandler_MainMenu);

	char title[32];
	Format(title, sizeof(title), "%i Points", g_iPlayerPoints[client]);
	menu.SetTitle(title);

	g_hData.Rewind();
	if (!g_hData.GotoFirstSubKey()) {
		delete menu;
		return;
	}

	any data[NyxData];
	do {
		g_hData.GetSectionName(data[NyxData_Group], sizeof(data[NyxData_Group]));
		g_hData.GetString("team_name", data[NyxData_TeamName], sizeof(data[NyxData_TeamName]), "both");

		if (strcmp(data[NyxData_Group], info, false) == 0) {
			// check if the group we're in has sections
			if (!g_hData.GotoFirstSubKey()) {
				continue;
			}

			do {
				g_hData.GetSectionName(data[NyxData_Section], sizeof(data[NyxData_Section]));

				g_hData.GetString("name", data[NyxData_Name], sizeof(data[NyxData_Name]));
				if (strlen(data[NyxData_Name]) == 0) {
					strcopy(data[NyxData_Name], sizeof(data[NyxData_Name]), data[NyxData_Section]);
				}

				g_hData.GetString("team_name", data[NyxData_TeamName], sizeof(data[NyxData_TeamName]), data[NyxData_TeamName]);
				if (GetClientTeam(client) == L4D2_StringToTeam(data[NyxData_TeamName]) ||
						strcmp(data[NyxData_TeamName], "both", false) == 0)
				{
					data[NyxData_Cost] = g_hData.GetNum("cost", -1);
					menu.AddItem(data[NyxData_Section], data[NyxData_Name],
							g_iPlayerPoints[client] >= data[NyxData_Cost] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
					NyxMsgDebug("section: %s, name: %s", data[NyxData_Section], data[NyxData_Name]);
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

			NyxMsgDebug("group '%s' does not equal info '%s'", data[NyxData_Group], info);
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

	if (g_iPlayerPoints[client] >= 10) menu.AddItem("10", "10 Points");
	if (g_iPlayerPoints[client] >= 20) menu.AddItem("20", "20 Points");
	if (g_iPlayerPoints[client] >= 30) menu.AddItem("30", "30 Points");

	char info[16], display[64];
	IntToString(g_iPlayerPoints[client] / 2, info, sizeof(info));
	Format(display, sizeof(display), "%d Points (half)", g_iPlayerPoints[client] / 2);
	menu.AddItem(info, display);

	IntToString(g_iPlayerPoints[client], info, sizeof(info));
	Format(display, sizeof(display), "%d Points (all)", g_iPlayerPoints[client]);
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

			NyxMsgDebug("group: %s, section: %s, name: %s, cost %i, shortcut: %s, command: %s, command_args: %s",
								data[NyxData_Group],
								data[NyxData_Section],
								data[NyxData_Name],
								data[NyxData_Cost],
								data[NyxData_Shortcut],
								data[NyxData_Command],
								data[NyxData_CommandArgs]);
			NyxMsgDebug("team_name: %s, mission_limit: %i",
								data[NyxData_TeamName],
								data[NyxData_MissionLimit]);

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
			if (g_iPlayerPoints[param1] < amount) {
				CPrintToChat(param1, "%t", "Insufficient Points", NYX_PLUGIN_NAME, amount);
			} else if (param1 == target) {
				CPrintToChat(param1, "%t", "Sent Self Points", NYX_PLUGIN_NAME);
			} else if (GetClientTeam(param1) != GetClientTeam(target)) {
				CPrintToChat(param1, "%t", "Sent Wrong Team Points", NYX_PLUGIN_NAME);
			} else {
				int spent = GiveClientPoints(target, amount);

				g_iPlayerPoints[param1] -= spent;
				CPrintToChatTeam(param1, "%t", "Sent Points", NYX_PLUGIN_NAME, param1, spent, target);
				CPrintToChat(param1, "%t", "My Points", NYX_PLUGIN_NAME, g_iPlayerPoints[param1]);

				if (spent == 0) {
					CPrintToChat(param1, "%t", "Sent Zero Points", NYX_PLUGIN_NAME);
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
		g_iPlayerPoints[i] = nyx_ps_start_points.IntValue;
	}
}

int GetClientPoints(int client) {
	return g_iPlayerPoints[client];
}

int GiveClientPoints(int client, int points) {
	int total = g_iPlayerPoints[client] + points;

	if (total > nyx_ps_max_points.IntValue) {
		int min = MathMin(points, total - nyx_ps_max_points.IntValue);
		int max = MathMax(points, total - nyx_ps_max_points.IntValue);
		int spent = max - min;

		g_iPlayerPoints[client] += spent;
		return spent;
	}

	g_iPlayerPoints[client] += points;
	return points;
}

bool GetItemData(const char[] item_name, any[NyxData] data) {
	g_hData.Rewind();
	if (!g_hData.GotoFirstSubKey()) {
		return false;
	}

	bool found_item;
	do {
		g_hData.GetSectionName(data[NyxData_Group], sizeof(data[NyxData_Group]));
		g_hData.GetString("command", data[NyxData_Command], sizeof(data[NyxData_Command]), "give");
		g_hData.GetString("command_args", data[NyxData_CommandArgs], sizeof(data[NyxData_CommandArgs]));
		g_hData.GetString("team_name", data[NyxData_TeamName], sizeof(data[NyxData_TeamName]), "both");

		// check if the group we're in has sections
		if (!g_hData.GotoFirstSubKey()) {
			continue;
		}

		do {
			g_hData.GetSectionName(data[NyxData_Section], sizeof(data[NyxData_Section]));

			// find what we're searching for
			if (strcmp(data[NyxData_Section], item_name, false) == 0) found_item = true;
			if (g_hData.JumpToKey("shortcut")) {
				g_hData.GetString(NULL_STRING, data[NyxData_Shortcut], sizeof(data[NyxData_Shortcut]));
				g_hData.GoBack();

				if (strcmp(data[NyxData_Shortcut], item_name, false) == 0) found_item = true;
			}

			// found what we're looking for; get our data and stop the sub loop
			if (found_item) {
				g_hData.GetString("data[NyxData_Name]", data[NyxData_Name], sizeof(data[NyxData_Name]));
				if (strlen(data[NyxData_Name]) == 0) {
					strcopy(data[NyxData_Name], sizeof(data[NyxData_Name]), data[NyxData_Section]);
				}

				g_hData.GetString("command", data[NyxData_Command], sizeof(data[NyxData_Command]), data[NyxData_Command]);
				g_hData.GetString("command_args", data[NyxData_CommandArgs], sizeof(data[NyxData_CommandArgs]), data[NyxData_CommandArgs]);
				g_hData.GetString("team_name", data[NyxData_TeamName], sizeof(data[NyxData_TeamName]), data[NyxData_TeamName]);
				data[NyxData_MissionLimit] = g_hData.GetNum("mission_limit", -1);
				data[NyxData_HealMultiplier] = g_hData.GetNum("heal_multiplier", -1);
				data[NyxData_Cost] = g_hData.GetNum("cost", -1);
				break;
			}
		} while (g_hData.GotoNextKey());

		// found what we're looking for; stop the main loop
		if (found_item) {
			break;
		}

		g_hData.GoBack();
	} while (g_hData.GotoNextKey(false));

	if (found_item) {
		return true;
	}

	return false;
}

///
/// Libs
///

stock void CPrintToChatTeam(int client, char[] format, any ...) {
	char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 3);

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i, true)) continue;
		if (GetClientTeam(i) != GetClientTeam(client)) continue;

		CPrintToChat(i, buffer);
	}
}
