#pragma semicolon 1
#include <sourcemod>

#define NYX_DEBUG 0
#define NYX_PLUGIN_TAG "PS"
#include <nyxtools>
#undef REQUIRE_PLUGIN
#include <nyxtools_l4d2>
#include <nps_stocks>
#include <nps_catalog>
#include <nps_storage>

#pragma newdecls required

public Plugin myinfo = {
  name = "NPS - Menu",
  author = NYXTOOLS_AUTHOR,
  description = "",
  version = NPS_VERSION,
  url = NYXTOOLS_WEBSITE
};

/***
 *       ________      __          __    
 *      / ____/ /___  / /_  ____ _/ /____
 *     / / __/ / __ \/ __ \/ __ `/ / ___/
 *    / /_/ / / /_/ / /_/ / /_/ / (__  ) 
 *    \____/_/\____/_.___/\__,_/_/____/  
 *                                       
 */

KeyValues g_hConfig;

/***
 *        ____  __            _          ____      __            ____              
 *       / __ \/ /_  ______ _(_)___     /  _/___  / /____  _____/ __/___ _________ 
 *      / /_/ / / / / / __ `/ / __ \    / // __ \/ __/ _ \/ ___/ /_/ __ `/ ___/ _ \
 *     / ____/ / /_/ / /_/ / / / / /  _/ // / / / /_/  __/ /  / __/ /_/ / /__/  __/
 *    /_/   /_/\__,_/\__, /_/_/ /_/  /___/_/ /_/\__/\___/_/  /_/  \__,_/\___/\___/ 
 *                  /____/                                                         
 */

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
  RegPluginLibrary("nps_menu");
  return APLRes_Success;
}

public void OnPluginStart() {
  LoadTranslations("common.phrases");

  RegConsoleCmd("sm_buymenu", ConCmd_BuyMenu);

  char path[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, path, sizeof(path), "configs/nps/%s", "menus.cfg");

  g_hConfig = new KeyValues("menus");
  if (g_hConfig.ImportFromFile(path)) {
    char buffer[256];
    if (!g_hConfig.GetSectionName(buffer, sizeof(buffer))) {
      SetFailState("Error in %s: File corrupt or in the wrong format", path);
    }

    if (strcmp(buffer, "menus") != 0) {
      SetFailState("Error in %s: Couldn't find section '%s'", path, "menus");
    }
    
    g_hConfig.Rewind();
  } else {
    SetFailState("Error in %s: File not found, corrupt or in the wrong format", path);
  }
}

/***
 *       ______                                          __    
 *      / ____/___  ____ ___  ____ ___  ____ _____  ____/ /____
 *     / /   / __ \/ __ `__ \/ __ `__ \/ __ `/ __ \/ __  / ___/
 *    / /___/ /_/ / / / / / / / / / / / /_/ / / / / /_/ (__  ) 
 *    \____/\____/_/ /_/ /_/_/ /_/ /_/\__,_/_/ /_/\__,_/____/  
 *                                                             
 */

public Action ConCmd_BuyMenu(int client, int args) {
  if (!IsValidClient(client)) {
    NyxMsgReply(client, "Cannot display menu to console");
  }

  Display_MainMenu(client);

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
  Menu menu = new Menu(MenuHandler_SubMenu);
  
  char title[32];
  Format(title, sizeof(title), "Points: %d", (new Player(client)).Points);
  menu.SetTitle(title);

  BuildMainMenu(client, menu);

  menu.ExitBackButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

void Display_SubMenu(int client, const char[] key) {
  Menu menu = new Menu(MenuHandler_SubMenu);
  
  char title[32];
  Format(title, sizeof(title), "Points: %d", (new Player(client)).Points);
  menu.SetTitle(title);

  BuildSubMenu(menu, key);

  menu.ExitBackButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_SubMenu(Menu menu, MenuAction action, int param1, int param2) {
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
    char key[32];
    menu.GetItem(param2, key, sizeof(key));
    if (StrContains(key, "_menu", false) != -1) {
      if (IsValidClient(param1)) {
        Display_SubMenu(param1, key);
      }
    } else {
      if (IsValidClient(param1)) {
        Display_ConfirmMenu(param1, key);
      }
    }
  }

  return;
}

void Display_ConfirmMenu(int client, const char[] key) {
  Menu menu = new Menu(MenuHandler_ConfirmMenu);
  
  char title[32];
  any storage[eCatalog]; FindItem(key, storage);
  Format(title, sizeof(title), "Cost: %i", storage[Catalog_Cost]);
  menu.SetTitle(title);

  menu.AddItem(key, "Yes");
  menu.AddItem("no", "No");
  menu.ExitBackButton = true;
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
    char key[32];
    menu.GetItem(param2, key, sizeof(key));

    if (IsValidClient(param1)) {
      if (!StrEqual(key, "no", false)) {
        FakeClientCommandEx(param1, "sm_buy %s", key);
      }
    }
  }

  return;
}

/***
 *        ______                 __  _                 
 *       / ____/_  ______  _____/ /_(_)___  ____  _____
 *      / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
 *     / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  ) 
 *    /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/  
 *                                                     
 */

bool BuildMainMenu(int client, Menu menu) {
  char team[16], category[64];
  L4D2_TeamToString(GetClientTeam(client), team, sizeof(team));
  Format(category, sizeof(category), "%s_menu", team);

  return BuildSubMenu(menu, category);
}

bool BuildSubMenu(Menu menu, const char[] category) {
  g_hConfig.Rewind();
  if (!g_hConfig.GotoFirstSubKey()) {
    return false;
  }

  char section[64];
  do { // loop sections
    g_hConfig.GetSectionName(section, sizeof(section));
    NyxMsgDebug("section: %s", section);

    if (strcmp(section, category, false) == 0) {
      if (!g_hConfig.GotoFirstSubKey(false)) {
        return false;
      }

      char key[32], value[32];
      do { // loop through keys
        g_hConfig.GetSectionName(key, sizeof(key));
        if (g_hConfig.GetDataType(NULL_STRING) != KvData_None) {
          g_hConfig.GetString(NULL_STRING, value, sizeof(value));
          menu.AddItem(key, value);
          NyxMsgDebug("key: %s, value: %s", key, value);
        }
      } while (g_hConfig.GotoNextKey(false));

      return true;
    }
  } while (g_hConfig.GotoNextKey(false));

  return false;
}
