#if defined _nps_storage_included
  #endinput
#endif
#define _nps_storage_included

/***
 *        _   __      __  _                
 *       / | / /___ _/ /_(_)   _____  _____
 *      /  |/ / __ `/ __/ / | / / _ \/ ___/
 *     / /|  / /_/ / /_/ /| |/ /  __(__  ) 
 *    /_/ |_/\__,_/\__/_/ |___/\___/____/  
 *                                         
 */
public SharedPlugin:__pl_nps_storage = {
  name = "nps_storage",
  file = "nps_storage.smx",
#if defined REQUIRE_PLUGIN
  required = 1,
#else
  required = 0,
#endif
};

methodmap Player __nullable__ {
  public Player(int client) {
    return view_as<Player>(EntIndexToEntRef(client));
  }

  property int Index {
    public get() { return EntRefToEntIndex(view_as<int>(this)); }
  }

  property int Ref {
    public get() { return view_as<int>(this); }
  }

  property int UserID {
    public native get();
    public native set(int userid);
  }

  property int Points {
    public native get();
    public native set(int value);
  }

  public native int GivePoints(int amount);

  property int Reward {
    public native get();
    public native set(int value);
  }

  public native void GetLastItem(char[] buffer, int maxlength);

  public native void SetLastItem(char[] buffer);

  public native void SetDefaults(int userid=-1);

  property int HeadshotCount {
    public native get();
    public native set(int value);
  }

  property int KillCount {
    public native get();
    public native set(int value);
  }

  property int HurtCount {
    public native get();
    public native set(int value);
  }

  property int HealCount {
    public native get();
    public native set(int value);
  }

  public native void TransferHealCount(Player player);

  property int ProtectCount {
    public native get();
    public native set(int value);
  }

  property bool BurnedWitch {
    public native get();
    public native set(bool value);
  }

  property bool BurnedTank {
    public native get();
    public native set(bool value);
  }
  
  property bool WasTank {
    public native get();
    public native set(bool value);
  }
}
