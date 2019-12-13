#pragma semicolon 1
#include <sourcemod>

#define NYX_DEBUG 2
#define NYX_PLUGIN_NAME "Nyx"
#include <nyxtools>

#pragma newdecls required

public Plugin myinfo = {
	name = "Nyxtools - L4D2 Point System",
	author = "Kiwi, JeremyDF93",
	description = "",
	version = "1.0",
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

int g_iPlayerPoints[MAXPLAYERS + 1];
any g_ePlayerData[MAXPLAYERS + 1][NyxData];

///
/// ConVars
///



///
/// Plugin Interface
///

public void OnPluginStart() {
	LoadTranslations("common.phrases");

	RegConsoleCmd("sm_buy", ConCmd_Buy);

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
}

public void OnPluginEnd() {

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

public int MenuHandler_MainMenu(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack) {
			if (IsValidClient(param1)) Display_MainMenu(param1);
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
		if (IsValidClient(param1)) {
			Display_MainMenu(param1);
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

///
/// Functions
///

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


