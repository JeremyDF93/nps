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
/// Globals
///

KeyValues g_hData;

int g_iPlayerPoints[MAXPLAYERS + 1];

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

	ExecuteItem(item_name);

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

	char group[64], section[64], name[64], team_name[16];
	do {
		g_hData.GetSectionName(group, sizeof(group));
		g_hData.GetString("team", team_name, sizeof(team_name), "both");

		if (strcmp(group, "main", false) == 0 ||
				strcmp(group, "infected", false) == 0)
		{
			// check if the group we're in has sections
			if (!g_hData.GotoFirstSubKey()) {
				continue;
			}

			do {
				g_hData.GetSectionName(section, sizeof(section));

				g_hData.GetString("name", name, sizeof(name));
				if (strlen(name) == 0) {
					strcopy(name, sizeof(name), section);
				}

				g_hData.GetString("team", team_name, sizeof(team_name), team_name);
				if (GetClientTeam(client) == L4D2_StringToTeam(team_name) ||
						strcmp(team_name, "both", false) == 0)
				{
					menu.AddItem(section, name);
					NyxMsgDebug("section: %s, name: %s", section, name);
				}
			} while (g_hData.GotoNextKey());

			g_hData.GoBack();
		} else {
			g_hData.GetString("name", name, sizeof(name));
			if (strlen(name) == 0) {
				strcopy(name, sizeof(name), group);
			}

			if (GetClientTeam(client) == L4D2_StringToTeam(team_name) ||
					strcmp(team_name, "both", false) == 0)
			{
				menu.AddItem(group, name);
				NyxMsgDebug("group: %s, name: %s", group, name);
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

	char group[64], section[64], name[64], team_name[16];
	do {
		g_hData.GetSectionName(group, sizeof(group));
		g_hData.GetString("team", team_name, sizeof(team_name), "both");

		if (strcmp(group, info, false) == 0) {
			// check if the group we're in has sections
			if (!g_hData.GotoFirstSubKey()) {
				continue;
			}

			do {
				g_hData.GetSectionName(section, sizeof(section));

				g_hData.GetString("name", name, sizeof(name));
				if (strlen(name) == 0) {
					strcopy(name, sizeof(name), section);
				}

				g_hData.GetString("team", team_name, sizeof(team_name), team_name);
				if (GetClientTeam(client) == L4D2_StringToTeam(team_name) ||
						strcmp(team_name, "both", false) == 0)
				{
					menu.AddItem(section, name);
					NyxMsgDebug("section: %s, name: %s", section, name);
				}
			} while (g_hData.GotoNextKey());

			g_hData.GoBack();
		} else {
			if (g_hData.JumpToKey(info)) {
				NyxMsgDebug("info '%s' is an item", info);

				delete menu;
				return;
			}

			NyxMsgDebug("group '%s' does not equal info '%s'", group, info);
		}

	} while (g_hData.GotoNextKey(false));

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_MainMenu(Menu menu, MenuAction action, int param1, int param2) {
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
			Display_SubMenu(param1, info);
		}
	}

	return;
}

///
/// Functions
///

bool ExecuteItem(const char[] item_name) {
	g_hData.Rewind();
	if (!g_hData.GotoFirstSubKey()) {
		return false;
	}

	bool found_item;
	int cost, mission_limit;
	char group[64], section[64], command[64], command_args[64], name[64], shortcut[16], team_name[16];
	do {
		g_hData.GetSectionName(group, sizeof(group));
		g_hData.GetString("command", command, sizeof(command), "give");
		g_hData.GetString("team", team_name, sizeof(team_name), "both");

		// check if the group we're in has sections
		if (!g_hData.GotoFirstSubKey()) {
			continue;
		}

		do {
			g_hData.GetSectionName(section, sizeof(section));

			// find what we're searching for
			if (strcmp(section, item_name, false) == 0) found_item = true;
			if (g_hData.JumpToKey("shortcut")) {
				g_hData.GetString(NULL_STRING, shortcut, sizeof(shortcut));
				g_hData.GoBack();

				if (strcmp(shortcut, item_name, false) == 0) found_item = true;
			}

			// found what we're looking for; get our data and stop the sub loop
			if (found_item) {
				g_hData.GetString("name", name, sizeof(name));
				if (strlen(name) == 0) {
					strcopy(name, sizeof(name), section);
				}
				cost = g_hData.GetNum("cost", -1);

				g_hData.GetString("command", command, sizeof(command), command);
				g_hData.GetString("command_args", command_args, sizeof(command_args));
				g_hData.GetString("team", team_name, sizeof(team_name), team_name);
				mission_limit = g_hData.GetNum("mission_limit", -1);
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
		NyxMsgDebug("group: %s, section: %s, name: %s, cost %i, shortcut: %s, command: %s, command_args: %s",
							group, section, name, cost, shortcut, command, command_args);
		NyxMsgDebug("team_name: %s, mission_limit: %i",
							team_name, mission_limit);
	}

	return found_item;
}

///
/// Libs
///


