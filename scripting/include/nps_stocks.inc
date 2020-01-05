#if defined _nps_stocks_included
  #endinput
#endif
#define _nps_stocks_included

#tryinclude <nps_version_auto>
#include <nps_version>

/***
 *       _____ __             __       
 *      / ___// /_____  _____/ /_______
 *      \__ \/ __/ __ \/ ___/ //_/ ___/
 *     ___/ / /_/ /_/ / /__/ ,< (__  ) 
 *    /____/\__/\____/\___/_/|_/____/  
 *                                     
 */

stock bool IsFireDamage(int type){
  if (type == 8 || type == 2056) return true;
  
  return false;
}

stock bool IsSpitterDamage(int type){
  if (type == 263168 || type == 265216) return true;

  return false;
}

stock bool IsValidBuyTarget(int target) {
  if (!IsValidClient(target, true)) return false;
  if (!IsPlayerInfected(target)) return false;
  if (IsPlayerAlive(target)) return false;
  if (IsPlayerGhost(target)) return false;

  return true;
}

stock void NyxPrintToAll(char[] format, any ...) {
  char buffer[256];
  VFormat(buffer, sizeof(buffer), format, 2);

  for (int i = 1; i <= MaxClients; i++) {
    if (!IsValidClient(i)) continue;

    NyxPrintToChat(i, buffer);
  }
}

stock void NyxPrintToTeam(int team, char[] format, any ...) {
  char buffer[256];
  VFormat(buffer, sizeof(buffer), format, 3);

  for (int i = 1; i <= MaxClients; i++) {
    if (!IsValidClient(i)) continue;
    if (GetClientTeam(i) != team) continue;

    NyxPrintToChat(i, buffer);
  }
}

stock void NyxPrintToChat(int client, char[] format, any ...) {
  char buffer[256];
  VFormat(buffer, sizeof(buffer), format, 3);
  CPrintToChat(client, "{green}[%s]{default} %s", NYXTOOLS_TAG, buffer);
}
