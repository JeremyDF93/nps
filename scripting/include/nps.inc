#if defined _nps_included
  #endinput
#endif
#define _nps_included

forward void NPS_OnPlayerBuyZombie(int client);

public SharedPlugin __pl_nps = {
  name = "nps",
  file = "nps.smx",
#if defined REQUIRE_PLUGIN
  required = 1,
#else
  required = 0,
#endif
};