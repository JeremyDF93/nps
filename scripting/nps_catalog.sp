#pragma semicolon 1
#include <sourcemod>

#define NYXTOOLS_DEBUG 0
#define NYXTOOLS_TAG "PS"
#include <nyxtools>
#include <nyxtools_l4d2>
#include <nps_stocks>
#include <nps_catalog>

#pragma newdecls required

public Plugin myinfo = {
  name = "NPS - Catalog",
  author = NYXTOOLS_AUTHOR,
  description = "",
  version = NPS_VERSION,
  url = NYXTOOLS_WEBSITE
};

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
  RegPluginLibrary("nps_catalog");

  CreateNative("FindItem", Native_FindItem);
  CreateNative("FindClientItem", Native_FindClientItem);

  return APLRes_Success;
}

public void OnPluginStart() {
  LoadTranslations("common.phrases");

  RegAdminCmd("nyx_debugcat", AdmCmd_DebugCatalog, ADMFLAG_ROOT);

  char path[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, path, sizeof(path), "configs/nps/%s", "catalog.cfg");

  g_hConfig = new KeyValues("catalog");
  if (g_hConfig.ImportFromFile(path)) {
    char buffer[256];
    if (!g_hConfig.GetSectionName(buffer, sizeof(buffer))) {
      SetFailState("Error in %s: File corrupt or in the wrong format", path);
    }

    if (strcmp(buffer, "catalog") != 0) {
      SetFailState("Error in %s: Couldn't find section '%s'", path, "catalog");
    }

    g_hConfig.Rewind();
  } else {
    SetFailState("Error in %s: File not found, corrupt or in the wrong format", path);
  }
}

/***
 *        _   __      __  _
 *       / | / /___ _/ /_(_)   _____  _____
 *      /  |/ / __ `/ __/ / | / / _ \/ ___/
 *     / /|  / /_/ / /_/ /| |/ /  __(__  )
 *    /_/ |_/\__,_/\__/_/ |___/\___/____/
 *
 */

public int Native_FindItem(Handle plugin, int numArgs) {
  char name[64]; GetNativeString(1, name, sizeof(name));
  any item[eCatalog];

  g_hConfig.Rewind();
  if (!g_hConfig.GotoFirstSubKey()) {
    return false;
  }

  bool found;
  char shortcuts[8][32];
  do { // category
    any draft[eCatalog];
    BuildItem(g_hConfig, draft, draft);

    g_hConfig.GetSectionName(item[Catalog_Category], sizeof(item[Catalog_Category]));

    // check if the group we're in has sections
    if (!g_hConfig.GotoFirstSubKey()) {
      continue;
    }

    do { // item
      BuildItem(g_hConfig, item, draft);

      g_hConfig.GetSectionName(item[Catalog_Item], sizeof(item[Catalog_Item]));

      if (strcmp(item[Catalog_Item], name, false) == 0) {
        found = true;
      } else if (strcmp(item[Catalog_Name], name, false) == 0) {
        found = true;
      }

      int num = ExplodeString(item[Catalog_Shortcut], ",", shortcuts, 8, 32);
      for (int i = 0; i < num; i++) {
        TrimString(shortcuts[i]);
        if (strcmp(shortcuts[i], name, false) == 0) {
          found = true;
          break;
        }
      }

      if (found) {
        SetNativeArray(2, item, sizeof(item));
        return true;
      }
    } while (g_hConfig.GotoNextKey());

    g_hConfig.GoBack();
  } while (g_hConfig.GotoNextKey(false));

  return false;
}

public int Native_FindClientItem(Handle plugin, int numArgs) {
  int client = GetNativeCell(1);
  char name[64]; GetNativeString(2, name, sizeof(name));

  if (!IsValidClient(client)) {
    return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
  }

  any item[eCatalog];
  if (FindItem(name, item)) {
    if (StrEqual(item[Catalog_Item], "health", false)) {
      if (IsPlayerTank(client)) {
        item[Catalog_Cost] = RoundFloat(float(item[Catalog_Cost]) * item[Catalog_CostMultiplierTank]);
      }
    }

    SetNativeArray(3, item, sizeof(item));

    return true;
  }

  return false;
}

/***
 *        ___       __          _          ______                                          __
 *       /   | ____/ /___ ___  (_)___     / ____/___  ____ ___  ____ ___  ____ _____  ____/ /____
 *      / /| |/ __  / __ `__ \/ / __ \   / /   / __ \/ __ `__ \/ __ `__ \/ __ `/ __ \/ __  / ___/
 *     / ___ / /_/ / / / / / / / / / /  / /___/ /_/ / / / / / / / / / / / /_/ / / / / /_/ (__  )
 *    /_/  |_\__,_/_/ /_/ /_/_/_/ /_/   \____/\____/_/ /_/ /_/_/ /_/ /_/\__,_/_/ /_/\__,_/____/
 *
 */

public Action AdmCmd_DebugCatalog(int client, int args) {
  if (args < 1) {
    NyxMsgReply(client, "Usage: nyx_debugcat <name>");
    return Plugin_Handled;
  }

  char name[32];
  GetCmdArgString(name, sizeof(name));

  any item[eCatalog];
  bool found = FindItem(name, item);
  if (found) {
    NyxMsgReply(client, "Category: %s, Item: %s, Name: %s, Cost: %i",
        item[Catalog_Category],
        item[Catalog_Item],
        item[Catalog_Name],
        item[Catalog_Cost]);
    NyxMsgReply(client, "Shortcut: %s, Command: %s, CommandArgs: %s, Team: %s",
        item[Catalog_Shortcut],
        item[Catalog_Command],
        item[Catalog_CommandArgs],
        item[Catalog_Team]);
    NyxMsgReply(client, "Limit: %i, Announce: %i, AnnouncePhrase: %s",
        item[Catalog_Limit],
        item[Catalog_Announce],
        item[Catalog_AnnouncePhrase]);
    NyxMsgReply(client, "MustBeIncapacitated: %b",
        item[Catalog_MustBeIncapacitated]);
  } else {
    NyxMsgReply(client, "'%s' was not found", name);
  }

  return Plugin_Handled;
}

/***
 *        ______                 __  _
 *       / ____/_  ______  _____/ /_(_)___  ____  _____
 *      / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
 *     / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
 *    /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/
 *
 */

void BuildItem(KeyValues kv, any[eCatalog] item, any[eCatalog] def) {
  kv.GetString("name", item[Catalog_Name], sizeof(item[Catalog_Name]), def[Catalog_Item]);
  kv.GetString("shortcut", item[Catalog_Shortcut], sizeof(item[Catalog_Shortcut]), def[Catalog_Shortcut]);
  kv.GetString("command", item[Catalog_Command], sizeof(item[Catalog_Command]), def[Catalog_Command]);
  kv.GetString("command_args", item[Catalog_CommandArgs], sizeof(item[Catalog_CommandArgs]), def[Catalog_CommandArgs]);
  kv.GetString("team", item[Catalog_Team], sizeof(item[Catalog_Team]), def[Catalog_Team]);
  item[Catalog_Cost] = kv.GetNum("cost", item[Catalog_Cost]);
  item[Catalog_CostMultiplierTank] = kv.GetFloat("cost_multiplier_tank", def[Catalog_CostMultiplierTank]);
  item[Catalog_Limit] = kv.GetNum("limit", def[Catalog_Limit]);
  item[Catalog_Announce] = (kv.GetNum("announce", def[Catalog_Announce]) == 1);
  kv.GetString("announce_phrase", item[Catalog_AnnouncePhrase], sizeof(item[Catalog_AnnouncePhrase]), def[Catalog_AnnouncePhrase]);
  item[Catalog_MustBeIncapacitated] = (kv.GetNum("must_be_incapacitated", def[Catalog_MustBeIncapacitated]) == 1);
}
