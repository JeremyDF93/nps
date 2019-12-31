#if defined _nps_storage_included
  #endinput
#endif
#define _nps_storage_included

#include <nyxtools>

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

#if !defined REQUIRE_PLUGIN
public __pl_nps_storage_SetNTVOptional() {
  //MarkNativeAsOptional("");
}
#endif

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

  public int GivePoints(int amount, int limit) {
    int total = this.Points + amount;

    if (total > limit) {
      int min = MathMin(amount, total - limit);
      int max = MathMax(amount, total - limit);
      int spent = max - min;

      if (spent >= amount) return 0;
      if (spent >= limit) return 0;

      this.Points = this.Points + spent;
      return spent;
    }

    this.Points = this.Points + amount;
    return amount;
  }

  property int Reward {
    public native get();
    public native set(int value);
  }

  public native void GetLastItem(char[] buffer, int maxLength);

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

  public void TransferHealCount(Player player) {
    player.HealCount = this.HealCount;
    this.HealCount = 0;
  }

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
}
