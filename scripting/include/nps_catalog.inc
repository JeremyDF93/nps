#if defined _nps_catalog_included
  #endinput
#endif
#define _nps_catalog_included

/***
 *        ______                          
 *       / ____/___  __  ______ ___  _____
 *      / __/ / __ \/ / / / __ `__ \/ ___/
 *     / /___/ / / / /_/ / / / / / (__  ) 
 *    /_____/_/ /_/\__,_/_/ /_/ /_/____/  
 *                                        
 */

enum eCatalog {
  String:Catalog_Category[64],
  String:Catalog_Item[64],
  String:Catalog_Name[64],
  String:Catalog_Shortcut[16],
  String:Catalog_Command[64],
  String:Catalog_CommandArgs[64],
  String:Catalog_CommandType[64],
  String:Catalog_Team[16],
  Catalog_Cost,
  Catalog_Limit,
  bool:Catalog_Announce,
  String:Catalog_AnnouncePhrase[256]
}

/***
 *        _   __      __  _                
 *       / | / /___ _/ /_(_)   _____  _____
 *      /  |/ / __ `/ __/ / | / / _ \/ ___/
 *     / /|  / /_/ / /_/ /| |/ /  __(__  ) 
 *    /_/ |_/\__,_/\__/_/ |___/\___/____/  
 *                                         
 */

native bool FindItem(const char[] name, any[eCatalog] item);

public SharedPlugin:__pl_nps_catalog = {
  name = "nps_catalog",
  file = "nps_catalog.smx",
#if defined REQUIRE_PLUGIN
  required = 1,
#else
  required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_nps_catalog_SetNTVOptional() {
  MarkNativeAsOptional("FindItem");
}
#endif
