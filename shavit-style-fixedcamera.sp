#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <shavit>
#include <clientprefs>

// Global Variables -------------------------------------------------------

ConVar g_hMpForceCamera;
ConVar g_cvSpecialString;

char g_sSpecialString[stylestrings_t::sSpecialString];

bool g_bThirdPersonEnabled[MAXPLAYERS + 1];
bool g_bUseDiagonalCamera[MAXPLAYERS + 1];
bool g_bUseHardcodedKey[MAXPLAYERS + 1];
bool g_bNightVisionIsEnabled[MAXPLAYERS + 1];
bool g_bMovementBlocked[MAXPLAYERS + 1];

int g_iCameraRotation[MAXPLAYERS + 1];
int g_iLastButtons[MAXPLAYERS + 1];
int g_iFov[MAXPLAYERS + 1];

float g_fStoredAngles[MAXPLAYERS + 1][3];

Cookie g_cUseDiagonalCameraCookie;
Cookie g_cUseHardCodedBindsCookie;
Cookie g_cNvgCookie;
Cookie g_cFovCookie;

// Plugin Info -----------------------------------------------------------

public Plugin myinfo = {
	name = "Shavit - Fixed Camera Style",
	author = "devins, shinoum", 
	description = "Fixed Camera Style for CS:S Bhop Timer",
	version = "1.1.6",
	url = "https://github.com/NSchrot/shavit-style-fixedcamera"
}

// Plugin Starts ---------------------------------------------------------

public void OnPluginStart()
{
	g_hMpForceCamera = FindConVar("mp_forcecamera");
	g_cvSpecialString = CreateConVar("ss_fixedcamera_specialstring", "fixedcamera", "Special string for Fixed Camera style detection");
	g_cvSpecialString.AddChangeHook(ConVar_OnSpecialStringChanged);
	g_cvSpecialString.GetString(g_sSpecialString, sizeof(g_sSpecialString));

	HookEvent("player_spawn", OnPlayerSpawn);

	// Commands ---------

	// Rotate Camera Left / Right
	RegConsoleCmd("fcright", Command_RotateCameraRight, "Rotate camera right");
	RegConsoleCmd("fcleft", Command_RotateCameraLeft, "Rotate camera left");

	// Nightvision
	RegConsoleCmd("sm_fcnightvision", Command_ToggleNightVision, "Toggle Night Vision Goggles");
	RegConsoleCmd("sm_nightvision", Command_ToggleNightVision, "Toggle Night Vision Goggles");
	RegConsoleCmd("sm_fcnvg", Command_ToggleNightVision, "Toggle Night Vision Goggles");
	RegConsoleCmd("sm_nvg", Command_ToggleNightVision, "Toggle Night Vision Goggles");
	RegConsoleCmd("sm_nv", Command_ToggleNightVision, "Toggle Night Vision Goggles");

	// Toggle Shift / E Keys
	RegConsoleCmd("sm_fchardcodedbinds", Command_ToggleHardCodedBinds, "Toggle hardcoded Shift/E camera rotation binds");
	RegConsoleCmd("sm_fctogglebinds", Command_ToggleHardCodedBinds, "Toggle hardcoded Shift/E camera rotation binds");
	RegConsoleCmd("sm_fctogglekeys", Command_ToggleHardCodedBinds, "Toggle hardcoded Shift/E camera rotation binds");
	RegConsoleCmd("sm_fcusekeys", Command_ToggleHardCodedBinds, "Toggle hardcoded Shift/E camera rotation binds");
	RegConsoleCmd("sm_fcbinds", Command_ToggleHardCodedBinds, "Toggle hardcoded Shift/E camera rotation binds");
	RegConsoleCmd("sm_fckeys", Command_ToggleHardCodedBinds, "Toggle hardcoded Shift/E camera rotation binds");

	// Field of View
	RegConsoleCmd("sm_fcfov", Command_ApplyFOV, "Apply User Inserted FOV");
	RegConsoleCmd("sm_fov", Command_ApplyFOV, "Apply User Inserted FOV");

	// Commands & Help
	RegConsoleCmd("sm_fccommands", Command_Help, "Open Fixed Camera commands & help menu");
	RegConsoleCmd("sm_fchelp", Command_Help, "Open Fixed Camera commands & help menu");

	// Main Menu
	RegConsoleCmd("sm_fcsettings", Command_MainMenu, "Open Fixed Camera settings menu");
	RegConsoleCmd("sm_fcoptions", Command_MainMenu, "Open Fixed Camera settings menu");
	RegConsoleCmd("sm_fcmenu", Command_MainMenu, "Open Fixed Camera settings menu");

	// Toggle Diagonal Camera Angles
	RegConsoleCmd("sm_fcdiagonalcamera", Command_ToggleDiagonalCamera, "Toggle between straight / diagonal camera angles");
	RegConsoleCmd("sm_diagonalcamera", Command_ToggleDiagonalCamera, "Toggle between straight / diagonal camera angles");
	RegConsoleCmd("sm_fcdiagonal", Command_ToggleDiagonalCamera, "Toggle between straight / diagonal camera angles");
	RegConsoleCmd("sm_diagonal", Command_ToggleDiagonalCamera, "Toggle between straight / diagonal camera angles");

	// Cookies ---------

	g_cUseDiagonalCameraCookie = new Cookie("Toggle_Diagonal", "Diagonal Camera state", CookieAccess_Protected);
	g_cUseHardCodedBindsCookie = new Cookie("Toggle_HardCodedKeys", "Toggle Hardcoded binds state", CookieAccess_Protected);
	g_cNvgCookie = new Cookie("nvg", "nvg state", CookieAccess_Protected);
	g_cFovCookie = new Cookie("fov", "fov state", CookieAccess_Protected);

	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client))
		{
			OnClientPutInServer(client);
			
			if (AreClientCookiesCached(client))
			    OnClientCookiesCached(client);
		}
	}

	AutoExecConfig();
}

// On Clients / Players --------------------------------------------------------------------

public void OnClientPutInServer(int client)
{
    OnClientCookiesCached(client);

    if (IsInFCStyle(client))
	{
		g_iCameraRotation[client] = 0;
		g_iLastButtons[client] = 0;
		g_bThirdPersonEnabled[client] = true;
	}
}

public void OnClientCookiesCached(int client)
{
	if (IsFakeClient(client))
		return;
	
	char buffer[8];
	
	// Load Diagonal Camera cookie
	g_cUseDiagonalCameraCookie.Get(client, buffer, sizeof(buffer));
	if (buffer[0] == '\0')
	{
	    g_bUseDiagonalCamera[client] = false;
	    g_cUseDiagonalCameraCookie.Set(client, "0");
	}
	else
	{
	    g_bUseDiagonalCamera[client] = (StringToInt(buffer) == 1);
	}
	
	// Load Use Hardcoded binds cookie
	g_cUseHardCodedBindsCookie.Get(client, buffer, sizeof(buffer));
	if (buffer[0] == '\0')
	{
	    g_bUseHardcodedKey[client] = true;
	    g_cUseHardCodedBindsCookie.Set(client, "1");
	}
	else
	{
	    g_bUseHardcodedKey[client] = (StringToInt(buffer) == 1);
	}

	// Load FOV Cookie
	g_cFovCookie.Get(client, buffer, sizeof(buffer));
	if (buffer[0] == '\0')
	{
		g_iFov[client] = 105;
		g_cFovCookie.Set(client, "105");
	}
	else
	{
		g_iFov[client] = StringToInt(buffer);
	}

	// Load Night Vision Goggles cookie
	g_cNvgCookie.Get(client, buffer, sizeof(buffer));
	if (buffer[0] == '\0')
	{
	    g_bNightVisionIsEnabled[client] = false;
	    g_cNvgCookie.Set(client, "0");
	}
	else
	{
	    g_bNightVisionIsEnabled[client] = (StringToInt(buffer) == 1);
	}
}

public void OnClientDisconnect(int client)
{
	if (g_bThirdPersonEnabled[client])
		DisableThirdPerson(client);

	g_bMovementBlocked[client] = false;
}

// fix for fov being reset after dropping or picking up a weapon
public void OnClientPostThinkPost(int client)
{
	if (!IsValidClient(client) || !g_bThirdPersonEnabled[client])
		return;
		
	if (GetEntProp(client, Prop_Send, "m_iFOV") != g_iFov[client])
		SetEntProp(client, Prop_Send, "m_iFOV", g_iFov[client]);
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client) && g_bThirdPersonEnabled[client])
		CreateTimer(0.05, Timer_ReEnableThirdPerson, GetClientSerial(client));
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3])
{
	if (!IsValidClient(client) || !g_bThirdPersonEnabled[client] || !g_bUseHardcodedKey[client])
		return Plugin_Continue;

	if (buttons & IN_USE)
	{
		if (!(g_iLastButtons[client] & IN_USE))
			Command_RotateCameraRight(client, 0);
	}
	
	if (buttons & IN_SPEED)
	{
		if (!(g_iLastButtons[client] & IN_SPEED))
			Command_RotateCameraLeft(client, 0);
	}

	g_iLastButtons[client] = buttons;

	// Block Movement keys when switching camera angle to prevent speed loss
	if (g_bMovementBlocked[client])
    {
        if (buttons & IN_FORWARD) buttons &= ~IN_FORWARD;
        if (buttons & IN_BACK) buttons &= ~IN_BACK;
        if (buttons & IN_MOVELEFT) buttons &= ~IN_MOVELEFT;
        if (buttons & IN_MOVERIGHT) buttons &= ~IN_MOVERIGHT;

        vel[0] = 0.0;
        vel[1] = 0.0;

        return Plugin_Changed;
    }
	
	return Plugin_Continue;
}

// Style Changed ---------------------------------------------------------------------------

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
    if (!IsValidClient(client))
        return;

    char sStyleSpecial[sizeof(stylestrings_t::sSpecialString)];
	Shavit_GetStyleStrings(newstyle, sSpecialString, sStyleSpecial, sizeof(sStyleSpecial));
    bool bIsInFCStyle = (StrContains(sStyleSpecial, g_sSpecialString) != -1);

    if (bIsInFCStyle && !g_bThirdPersonEnabled[client])
    {
        EnableThirdPerson(client);
		SetEntProp(client, Prop_Send, "m_bNightVisionOn", g_bNightVisionIsEnabled[client] ? 1 : 0);
    }
    else if (!bIsInFCStyle && g_bThirdPersonEnabled[client])
    {
        DisableThirdPerson(client);
		SetEntProp(client, Prop_Send, "m_bNightVisionOn", 0);
    }
}

public void ConVar_OnSpecialStringChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.GetString(g_sSpecialString, sizeof(g_sSpecialString));
}

// Timers ----------------------------------------------------------------------------------

public Action Timer_ReEnableThirdPerson(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	if (IsValidClient(client) && g_bThirdPersonEnabled[client])
	{
		SetViewAngles(client);
		CreateTimer(0.027, Timer_RefreshCameraAngle, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Stop;
}

public Action Timer_RefreshCameraAngle(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	if (IsValidClient(client) && g_bThirdPersonEnabled[client])
	{
		SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
		SetEntProp(client, Prop_Send, "m_hObserverTarget", client);
		SetEntProp(client, Prop_Send, "m_iFOV", g_iFov[client]);

		RestorePlayerViewAngles(client);
		
		CreateTimer(0.01, Timer_ReEnableMovementKeys, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Stop;
}

public Action Timer_ReEnableMovementKeys(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	if (IsValidClient(client) && g_bThirdPersonEnabled[client])
		g_bMovementBlocked[client] = false;

	return Plugin_Stop;
}

// Functions -------------------------------------------------------------------------------

void SetViewAngles(int client)
{
	float idealAngles[3];
	idealAngles[0] = 45.0;

	if (!g_bUseDiagonalCamera[client])
		idealAngles[1] = float(g_iCameraRotation[client]); 
	else
		idealAngles[1] = float(g_iCameraRotation[client] - 45);

	idealAngles[2] = 0.0;  
	
	TeleportEntity(client, NULL_VECTOR, idealAngles, NULL_VECTOR);
}

public void StorePlayerViewAngles(int client)
{
    if(!IsValidClient(client))
        return;

    GetClientEyeAngles(client, g_fStoredAngles[client]);
}

public void RestorePlayerViewAngles(int client)
{
    if(!IsValidClient(client))
        return;

	SendConVarValue(client, g_hMpForceCamera, "1");
	TeleportEntity(client, NULL_VECTOR, g_fStoredAngles[client], NULL_VECTOR);
}

public void EnableThirdPerson(int client)
{
	if (!IsValidClient(client) || IsFakeClient(client))
		return;
		
	g_bThirdPersonEnabled[client] = true;
	g_iCameraRotation[client] = 0;

	SDKHook(client, SDKHook_PostThinkPost, OnClientPostThinkPost);
	CreateTimer(0.05, Timer_ReEnableThirdPerson, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	
	Shavit_PrintToChat(client, "\x078efeffFixed Camera: \x07ffffffUse \x07A082FFShift \x07ffffff/ \x07A082FFE \x07ffffffto rotate the camera angle");
	Shavit_PrintToChat(client, "\x078efeffFixed Camera: \x07ffffffType \x07A082FF/fcmenu \x07fffffffor additional commands and help");
}

public void DisableThirdPerson(int client)
{
	if (!IsValidClient(client) || IsFakeClient(client))
		return;
		
	g_bThirdPersonEnabled[client] = false;
	
	SDKUnhook(client, SDKHook_PostThinkPost, OnClientPostThinkPost);
	
	SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
	SetEntProp(client, Prop_Send, "m_hObserverTarget", -1);
	SetEntProp(client, Prop_Send, "m_iFOV", 90);
	
	float resetAngles[3] = {0.0, 0.0, 0.0};
	TeleportEntity(client, NULL_VECTOR, resetAngles, NULL_VECTOR);
}

public void SaveSettingToCookie(Cookie cookie, int client, int value)
{
	char buffer[8];
	Format(buffer, sizeof(buffer), "%d", value);
	cookie.Set(client, buffer);
}

public bool IsInFCStyle(int client)
{
	int style = Shavit_GetBhopStyle(client);
    char sStyleSpecial[sizeof(stylestrings_t::sSpecialString)];
	Shavit_GetStyleStrings(style, sSpecialString, sStyleSpecial, sizeof(sStyleSpecial));
    bool isInFCStyle = (StrContains(sStyleSpecial, g_sSpecialString) != -1);

	if (isInFCStyle)
		return true;
	else
		return false;
}

// Commands ----------------------------------------------------------------------------------------

public Action Command_RotateCameraRight(int client, int args)
{
    if (!IsValidClient(client) || !g_bThirdPersonEnabled[client])
        return Plugin_Handled;
	
	StorePlayerViewAngles(client);
    
    switch(g_iCameraRotation[client])
    {
        case 0: g_iCameraRotation[client] = -90;
        case -90: g_iCameraRotation[client] = 180;
        case 180: g_iCameraRotation[client] = 90;
        case 90: g_iCameraRotation[client] = 0;
    }

	SendConVarValue(client, g_hMpForceCamera, "0");
    g_bMovementBlocked[client] = true;
    
    SetViewAngles(client);
    CreateTimer(0.027, Timer_RefreshCameraAngle, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Handled;
}

public Action Command_RotateCameraLeft(int client, int args)
{
    if (!IsValidClient(client) || !g_bThirdPersonEnabled[client])
        return Plugin_Handled;
	
	StorePlayerViewAngles(client);

    switch(g_iCameraRotation[client])
    {
        case 0: g_iCameraRotation[client] = 90;
        case 90: g_iCameraRotation[client] = 180;
        case 180: g_iCameraRotation[client] = -90;
        case -90: g_iCameraRotation[client] = 0;
    }

	SendConVarValue(client, g_hMpForceCamera, "0");
    g_bMovementBlocked[client] = true;
    
    SetViewAngles(client);
    CreateTimer(0.027, Timer_RefreshCameraAngle, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Handled;
}

public Action Command_ToggleDiagonalCamera(int client, int args)
{
	if (!IsValidClient(client) || !IsInFCStyle(client))
		return Plugin_Handled;

	StorePlayerViewAngles(client);
	
	g_bUseDiagonalCamera[client] = !g_bUseDiagonalCamera[client];
	SendConVarValue(client, g_hMpForceCamera, "0");
	g_bMovementBlocked[client] = true;

	SetViewAngles(client);
	CreateTimer(0.03, Timer_RefreshCameraAngle, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);

	SaveSettingToCookie(g_cUseDiagonalCameraCookie, client, g_bUseDiagonalCamera[client]);

	return Plugin_Handled;
}

public Action Command_ToggleHardCodedBinds(int client, int args)
{
	if (!IsValidClient(client) || !IsInFCStyle(client))
		return Plugin_Handled;
	
	g_bUseHardcodedKey[client] = !g_bUseHardcodedKey[client];

	SaveSettingToCookie(g_cUseHardCodedBindsCookie, client, g_bUseHardcodedKey[client]);
	
	if (g_bUseHardcodedKey[client])
		Shavit_PrintToChat(client, "\x078efeffFixed Camera: \x07ffffffShift / E camera rotation binds: \x078efeffOn");
	else
		Shavit_PrintToChat(client, "\x078efeffFixed Camera: \x07ffffffShift / E camera rotation binds: \x07A082FFOff");
	
	return Plugin_Handled;
}

public Action Command_ToggleNightVision(int client, int args)
{
    if (!IsValidClient(client) || !IsPlayerAlive(client))
        return Plugin_Handled;

    if (IsInFCStyle(client))
    {
        g_bNightVisionIsEnabled[client] = !g_bNightVisionIsEnabled[client];
        SetEntProp(client, Prop_Send, "m_bNightVisionOn", g_bNightVisionIsEnabled[client] ? 1 : 0);

		SaveSettingToCookie(g_cNvgCookie, client, g_bNightVisionIsEnabled[client]);

        Shavit_PrintToChat(client, "\x078efeffFixed Camera: \x07ffffffNight Vision: %s",
            g_bNightVisionIsEnabled[client] ? "\x078efeffOn" : "\x07A082FFOff");
    }

    return Plugin_Handled;
}

public Action Command_ApplyFOV(int client, int args)
{
	if (!IsValidClient(client) || !IsInFCStyle(client))
		return Plugin_Handled;

	// If no FOV value is given
	if (args < 1)
	{
		Shavit_PrintToChat(client, "\x078efeffFixed Camera: \x07ffffffCurrent FOV: \x07A082FF%i \x07ffffff(Default: 105 | Game Default: 90)", g_iFov[client]);
		Shavit_PrintToChat(client, "\x078efeffFixed Camera: \x07ffffffUsage: /fcfov \x07A082FF<value>");
		Shavit_PrintToChat(client, "\x078efeffFixed Camera: \x07A082FFChanging the FOV affects mouse sensitivity!");
		ShowFovMenu(client);
		
		return Plugin_Handled;
	}

	int iMinFov = 80;
	int imaxFov = 120;
	int iFov = GetCmdArgInt(1);
	
	if (iFov < iMinFov)
		iFov = iMinFov;
	else if (iFov > imaxFov)
		iFov = imaxFov;

	g_iFov[client] = iFov;

	SaveSettingToCookie(g_cFovCookie, client, g_iFov[client]);

	Shavit_PrintToChat(client, "\x078efeffFixed Camera: \x07ffffffFOV set to: \x07A082FF%i \x07ffffff(Default: 105 | Game Default: 90)", g_iFov[client]);
	Shavit_PrintToChat(client, "\x078efeffFixed Camera: \x07A082FFChanging the FOV affects mouse sensitivity!");

	return Plugin_Handled;
}

public Action Command_MainMenu(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	if (!IsInFCStyle(client))
		return Plugin_Handled;

	ShowMainMenu(client);

	return Plugin_Handled;
}

public Action Command_Help(int client, int args)
{
	if (!IsValidClient(client) || !IsInFCStyle(client))
		return Plugin_Handled;
	
	ShowHelpMenu(client);

	return Plugin_Handled;
}

// Menus ------------------------------------------------------------------------

void ShowMainMenu(int client)
{
	Menu menu = new Menu(MainMenuHandler, MENU_ACTIONS_DEFAULT);
	menu.SetTitle("Fixed Camera\n \n");

	char diagonalCameraStatus[32];
	Format(diagonalCameraStatus, sizeof(diagonalCameraStatus), "Diagonal Camera: %s", g_bUseDiagonalCamera[client] ? "On" : "Off");
	menu.AddItem("diagonalCamera", diagonalCameraStatus);
	
	char bindStatus[32];
	Format(bindStatus, sizeof(bindStatus), "Shift / E Binds: %s", g_bUseHardcodedKey[client] ? "On" : "Off");
	menu.AddItem("binds", bindStatus);
	
	char nvgStatus[32];
	Format(nvgStatus, sizeof(nvgStatus), "Night Vision: %s", g_bNightVisionIsEnabled[client] ? "On" : "Off");
	menu.AddItem("nvg", nvgStatus);
	
	menu.AddItem("fov", "FOV\n \n");

	menu.AddItem("help", "Commands & Help");
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MainMenuHandler(Menu menu, MenuAction action, int client, int option)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(option, info, sizeof(info));
			
			if (StrEqual(info, "diagonalCamera"))
			{
				Command_ToggleDiagonalCamera(client, 0);
				ShowMainMenu(client);
			}
			else if (StrEqual(info, "binds"))
			{
				g_bUseHardcodedKey[client] = !g_bUseHardcodedKey[client];
				SaveSettingToCookie(g_cUseHardCodedBindsCookie, client, g_bUseHardcodedKey[client]);
				ShowMainMenu(client);
			}
			else if (StrEqual(info, "nvg"))
			{
				g_bNightVisionIsEnabled[client] = !g_bNightVisionIsEnabled[client];
				SetEntProp(client, Prop_Send, "m_bNightVisionOn", g_bNightVisionIsEnabled[client] ? 1 : 0);
				SaveSettingToCookie(g_cNvgCookie, client, g_bNightVisionIsEnabled[client]);
				ShowMainMenu(client);
			}
			else if (StrEqual(info, "fov"))
			{
				ShowFovMenu(client);
			}
			else if (StrEqual(info, "help"))
			{
				ShowHelpMenu(client);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return 0;
}

void ShowFovMenu(int client)
{
	Menu menu = new Menu(FovMenuHandler, MENU_ACTIONS_DEFAULT);
	
	char title[64];
	Format(title, sizeof(title), "Fixed Camera | FOV\n \nCurrent FOV: %d\n ", g_iFov[client]);
	menu.SetTitle(title);
	
	menu.AddItem("increase", "++");
	menu.AddItem("decrease", "--\n \n");

	menu.AddItem("back", "Back");
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int FovMenuHandler(Menu menu, MenuAction action, int client, int option)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(option, info, sizeof(info));
			
			if (StrEqual(info, "increase"))
			{
				if (g_iFov[client] < 120)
				{
					g_iFov[client] += 5;
					SaveSettingToCookie(g_cFovCookie, client, g_iFov[client]);
					
					// Apply FOV if in third person
					if (g_bThirdPersonEnabled[client])
						SetEntProp(client, Prop_Send, "m_iFOV", g_iFov[client]);
				}

				ShowFovMenu(client);
			}
			else if (StrEqual(info, "decrease"))
			{
				if (g_iFov[client] > 80)
				{
					g_iFov[client] -= 5;
					SaveSettingToCookie(g_cFovCookie, client, g_iFov[client]);
					
					// Apply FOV if in third person
					if (g_bThirdPersonEnabled[client])
						SetEntProp(client, Prop_Send, "m_iFOV", g_iFov[client]);
				}

				ShowFovMenu(client);
			}
			else if (StrEqual(info, "back"))
			{
				ShowMainMenu(client);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return 0;
}

void ShowHelpMenu(int client)
{
    Menu menu = new Menu(HelpMenuHandler, MENU_ACTIONS_DEFAULT);
    menu.SetTitle("Fixed Camera | Commands & Help\n \nCamera Angle: Shift / E or bind a key to fcleft / fcright\n ");

	menu.AddItem("", "/fcdiagonal: Toggle Diagonal Camera Angles", ITEMDRAW_DISABLED);
	menu.AddItem("", "/fctogglebinds: Toggle Shift / E binds", ITEMDRAW_DISABLED);
    menu.AddItem("", "/fcnvg: Toggle Night Vision", ITEMDRAW_DISABLED);
	menu.AddItem("", "/fcfov: Adjust FOV (80-120)\n \n", ITEMDRAW_DISABLED);

	menu.AddItem("", "/fcmenu: Main Menu", ITEMDRAW_DISABLED);
	menu.AddItem("", "/fchelp: This Menu\n \n", ITEMDRAW_DISABLED);

    menu.AddItem("mainmenu", "Main Menu");
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int HelpMenuHandler(Menu menu, MenuAction action, int client, int option)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(option, sInfo, sizeof(sInfo));
			
			if (StrEqual(sInfo, "mainmenu"))
				ShowMainMenu(client);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return 0;
}
