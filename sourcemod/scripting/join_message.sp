#include <sourcemod>
#undef REQUIRE_PLUGIN

#pragma semicolon 1

#include "advertisements/chatcolors.sp"
#include "advertisements/topcolors.sp"

#define PL_VERSION	"1.0.0"

public Plugin myinfo =
{
    name        = "Showjointext",
    author      = "IAmTheOneWhoStoleYourClock",
    description = "When joining, popup a menu that people have to acknoledge.",
    version     = PL_VERSION,
    url         = "https://github.com/IAmTheOneWhoStoleYourClock/The-Inventorium"
};


/**
 * Plugin Forwards
 */
public void OnPluginStart()
{
    HookEvent("player_spawn", Event_player_spawn, EventHookMode_Post);
}

char heading[] = "READ THIS\n \nTo finish installing custom assets,\ngo to your TF2C download folder.\n(TF2C install on windows is C:/Program Files (x86)\n/Steam/steamapps/sourcemods/tf2classic by default)\nThere should be an assets folder inside that folder.\nIf there isn't, go to tinyurl.com/InventoriumTF2C and download it there.\nOtherwise the download instructions are inside the folder.\nFor those having errors with new content, restart your game.";
char show[32];

public void OnClientDisconnect_Post(int client)
{
    show[client] = 0;
}

public Action Event_player_spawn(Handle:event, const String:name[], bool:dontBroadcast){
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (show[client] == 1){
        return Plugin_Handled;
    }

    if (IsValidEntity(client)) {
        show[client] = 1;
        ShowWarning(client);
    }
}

#define CHOICE1 "#choice1"
#define CHOICE2 "#choice2"
#define CHOICE3 "#choice3"
#define CHOICE4 "#choice4"
#define CHOICE5 "#choice5"
#define CHOICE6 "#choice5"

public int MenuHandler1(Menu menu, MenuAction action, int param1, int param2)
{
  switch(action)
  {
    case MenuAction_Display:
    {
      char buffer[450];
      Format(buffer, sizeof(buffer), heading, param1);
 
      Panel panel = view_as<Panel>(param2);
      panel.SetTitle(buffer);
    }
 
    case MenuAction_End:
    {
      delete menu;
    }
 
    case MenuAction_DrawItem:
    {
      int style;
      char info[32];
      menu.GetItem(param2, info, sizeof(info), style);
 
      return style;
    }
 
//    case MenuAction_DisplayItem:
//    {
//      char info[32];
//      menu.GetItem(param2, info, sizeof(info));
// 
//      char display[64];
// 
//      if (StrEqual(info, CHOICE6))
//      {
//        Format(display, sizeof(display), message, param1);
//        return RedrawMenuItem(display);
//      }
//    }
  }
 
  return 0;
}

void ShowWarning(int client)
{
  Menu menu = new Menu(MenuHandler1, MENU_ACTIONS_ALL);
  menu.SetTitle(heading, LANG_SERVER);
  menu.AddItem(CHOICE1, "null", ITEMDRAW_SPACER);
  menu.AddItem(CHOICE2, "null", ITEMDRAW_NOTEXT);
  menu.AddItem(CHOICE3, "null", ITEMDRAW_NOTEXT);
  menu.AddItem(CHOICE4, "null", ITEMDRAW_NOTEXT);
  menu.AddItem(CHOICE5, "null", ITEMDRAW_NOTEXT);
  menu.AddItem(CHOICE6, "Continue", ITEMDRAW_DEFAULT);
  menu.ExitButton = false;
  menu.Display(client, MENU_TIME_FOREVER);
}