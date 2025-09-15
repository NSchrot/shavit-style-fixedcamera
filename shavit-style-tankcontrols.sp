#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <shavit>
#include <clientprefs>

// Global Variables
ConVar g_cvSpecialString;
char g_sSpecialString[stylestrings_t::sSpecialString];

int g_iCameraRotation[MAXPLAYERS + 1];
int g_iLastButtons[MAXPLAYERS + 1];
int g_iFov[MAXPLAYERS + 1];

bool g_bThirdPersonEnabled[MAXPLAYERS + 1];
bool g_bUseHardcodedKey[MAXPLAYERS + 1];
bool g_bNightVisionIsEnabled[MAXPLAYERS + 1];

// Cookies
Cookie g_cToggleTCKeysCookie;
Cookie g_cFovCookie;
Cookie g_cNvgCookie;

public Plugin myinfo = {
	name = "Shavit - Tank Controls Style",
	author = "devins, shinoum", 
	description = "Tank-style thirdperson camera style for CS:S Bhop Timer",
	version = "1.1.0",
	url = "https://github.com/NSchrot/shavit-style-tankcontrols"
}

public void OnPluginStart()
{
	g_cvSpecialString = CreateConVar("ss_tankcontrols_specialstring", "tcontrols", "Special string for Tank Controls style detection");
	g_cvSpecialString.AddChangeHook(ConVar_OnSpecialStringChanged);
	g_cvSpecialString.GetString(g_sSpecialString, sizeof(g_sSpecialString));

	HookEvent("player_spawn", OnPlayerSpawn);

	// Commands
	RegConsoleCmd("tcright", Command_RotateCameraRight, "Rotate camera right");
	RegConsoleCmd("tcleft", Command_RotateCameraLeft, "Rotate camera left");
	RegConsoleCmd("tcnvg", Command_ToggleNightVision, "Toggle Night Vision Goggles");
	RegConsoleCmd("toggletckeys", Command_ToggleHardCodedBinds, "Toggle hardcoded Shift/E camera rotation binds");

	// SM commands
	RegConsoleCmd("sm_tcnightvision", Command_ToggleNightVision, "Toggle Night Vision Goggles");
	RegConsoleCmd("sm_nightvision", Command_ToggleNightVision, "Toggle Night Vision Goggles");
	RegConsoleCmd("sm_tcnvg", Command_ToggleNightVision, "Toggle Night Vision Goggles");
	RegConsoleCmd("sm_nvg", Command_ToggleNightVision, "Toggle Night Vision Goggles");
	RegConsoleCmd("sm_nv", Command_ToggleNightVision, "Toggle Night Vision Goggles");

	RegConsoleCmd("sm_toggletckeys", Command_ToggleHardCodedBinds, "Toggle hardcoded Shift/E camera rotation binds");
	RegConsoleCmd("sm_usetckeys", Command_ToggleHardCodedBinds, "Toggle hardcoded Shift/E camera rotation binds");
	RegConsoleCmd("sm_usehckeys", Command_ToggleHardCodedBinds, "Toggle hardcoded Shift/E camera rotation binds");
	RegConsoleCmd("sm_tckeys", Command_ToggleHardCodedBinds, "Toggle hardcoded Shift/E camera rotation binds");

	RegConsoleCmd("sm_tcfov", Command_ApplyFOV, "Apply User Inserted FOV");
	RegConsoleCmd("sm_fov", Command_ApplyFOV, "Apply User Inserted FOV");

	RegConsoleCmd("sm_tchelp", Command_TcHelp, "Displays additional commands for Tank Controls");

	// Cookies
	g_cToggleTCKeysCookie = new Cookie("Toggle_TCKeys", "Toggle Hardcoded binds state", CookieAccess_Protected);
	g_cFovCookie = new Cookie("fov", "fov state", CookieAccess_Protected);
	g_cNvgCookie = new Cookie("nvg", "nvg state", CookieAccess_Protected);

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

public void OnClientPutInServer(int client)
{
    OnClientCookiesCached(client);

	int style = Shavit_GetBhopStyle(client);
    char sStyleSpecial[sizeof(stylestrings_t::sSpecialString)];
	Shavit_GetStyleStrings(style, sSpecialString, sStyleSpecial, sizeof(sStyleSpecial));

    bool isInTCStyle = (StrContains(sStyleSpecial, g_sSpecialString) != -1);

    if (isInTCStyle)
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
	
	// Load Use TC Hardcoded binds cookie
	g_cToggleTCKeysCookie.Get(client, buffer, sizeof(buffer));
	if (buffer[0] == '\0')
	{
	    g_bUseHardcodedKey[client] = true;
	    g_cToggleTCKeysCookie.Set(client, "1");
	}
	else
	{
	    g_bUseHardcodedKey[client] = (StringToInt(buffer) == 1);
	}

	// Load HUD position cookie
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
	    g_bNightVisionIsEnabled[client] = true;
	    g_cNvgCookie.Set(client, "1");
	}
	else
	{
	    g_bNightVisionIsEnabled[client] = (StringToInt(buffer) == 1);
	}
}

public void OnClientDisconnect(int client)
{
	g_bThirdPersonEnabled[client] = false;
	g_iCameraRotation[client] = 0;
	g_bUseHardcodedKey[client] = true;
	g_iLastButtons[client] = 0;
	
	SDKUnhook(client, SDKHook_PostThinkPost, OnClientPostThinkPost);
}

// fix for fov being reset after dropping or picking up a weapon
public void OnClientPostThinkPost(int client)
{
	if (!IsValidClient(client) || !g_bThirdPersonEnabled[client])
		return;
		
	if (GetEntProp(client, Prop_Send, "m_iFOV") != g_iFov[client])
	{
		SetEntProp(client, Prop_Send, "m_iFOV", g_iFov[client]);
	}
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3])
{
	if (!IsValidClient(client) || !g_bThirdPersonEnabled[client] || !g_bUseHardcodedKey[client])
		return Plugin_Continue;
	
	if (buttons & IN_USE)
	{
		if (!(g_iLastButtons[client] & IN_USE))
		{
			Command_RotateCameraRight(client, 0);
		}
	}
	
	if (buttons & IN_SPEED)
	{
		if (!(g_iLastButtons[client] & IN_SPEED))
		{
			Command_RotateCameraLeft(client, 0);
		}
	}

	g_iLastButtons[client] = buttons;
	
	return Plugin_Continue;
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
    if (!IsValidClient(client))
        return;

    char sStyleSpecial[sizeof(stylestrings_t::sSpecialString)];
	Shavit_GetStyleStrings(newstyle, sSpecialString, sStyleSpecial, sizeof(sStyleSpecial));
    bool bIsInTCStyle = (StrContains(sStyleSpecial, g_sSpecialString) != -1);

    if (bIsInTCStyle && !g_bThirdPersonEnabled[client])
    {
        EnableThirdPerson(client);
		SetEntProp(client, Prop_Send, "m_bNightVisionOn", g_bNightVisionIsEnabled[client] ? 1 : 0);
    }
    else if (!bIsInTCStyle && g_bThirdPersonEnabled[client])
    {
        DisableThirdPerson(client);
		SetEntProp(client, Prop_Send, "m_bNightVisionOn", 0);
    }
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client) && g_bThirdPersonEnabled[client])
	{
		CreateTimer(0.1, Timer_ReEnableThirdPerson, GetClientSerial(client));
	}
}

public Action Timer_ReEnableThirdPerson(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	if (IsValidClient(client) && g_bThirdPersonEnabled[client])
	{
		SetIdealViewAngles(client);
		CreateTimer(0.1, Timer_ActivateThirdPerson, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Stop;
}

public Action Timer_SetInitialAngles(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	if (!IsValidClient(client) || !g_bThirdPersonEnabled[client])
		return Plugin_Stop;
	
	float idealAngles[3];
	idealAngles[0] = 45.0;
	idealAngles[1] = float(g_iCameraRotation[client]);
	idealAngles[2] = 0.0;
	
	TeleportEntity(client, NULL_VECTOR, idealAngles, NULL_VECTOR);
	
	CreateTimer(0.1, Timer_ActivateThirdPerson, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Stop;
}

void SetIdealViewAngles(int client)
{
	float idealAngles[3];
	idealAngles[0] = 45.0;
	idealAngles[1] = float(g_iCameraRotation[client]); 
	idealAngles[2] = 0.0;  
	
	TeleportEntity(client, NULL_VECTOR, idealAngles, NULL_VECTOR);
}

public Action Timer_ActivateThirdPerson(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	if (!IsValidClient(client) || !g_bThirdPersonEnabled[client])
		return Plugin_Stop;
	
	SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
	SetEntProp(client, Prop_Send, "m_hObserverTarget", client);
	SetEntProp(client, Prop_Send, "m_iFOV", g_iFov[client]);
	
	return Plugin_Stop;
}

public Action Timer_SimpleRefresh(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	if (!IsValidClient(client) || !g_bThirdPersonEnabled[client])
		return Plugin_Stop;
	
	SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
	SetEntProp(client, Prop_Send, "m_hObserverTarget", client);
	SetEntProp(client, Prop_Send, "m_iFOV", g_iFov[client]);
	
	return Plugin_Stop;
}

public void ConVar_OnSpecialStringChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.GetString(g_sSpecialString, sizeof(g_sSpecialString));
}

void EnableThirdPerson(int client)
{
	if (!IsValidClient(client) || IsFakeClient(client))
		return;
		
	g_bThirdPersonEnabled[client] = true;
	g_iCameraRotation[client] = 0;

	SDKHook(client, SDKHook_PostThinkPost, OnClientPostThinkPost);
	CreateTimer(0.1, Timer_SetInitialAngles, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	
	Shavit_PrintToChat(client, "\x078efeffTank Controls: \x07ffffffUse \x07A082FFShift \x07ffffff/ \x07A082FFE \x07ffffffto rotate the camera angle");
	Shavit_PrintToChat(client, "\x078efeffTank Controls: \x07ffffffType \x07A082FF/tchelp \x07ffffffto see additional commands");
}

void DisableThirdPerson(int client)
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

public Action Command_RotateCameraRight(int client, int args)
{
	if (!IsValidClient(client) || !g_bThirdPersonEnabled[client])
		return Plugin_Handled;
	
	switch(g_iCameraRotation[client])
	{
		case 0: g_iCameraRotation[client] = -90;
		case -90: g_iCameraRotation[client] = 180;
		case 180: g_iCameraRotation[client] = 90;
		case 90: g_iCameraRotation[client] = 0;
	}
	
	float angles[3];
	angles[0] = 45.0;
	angles[1] = float(g_iCameraRotation[client]);
	angles[2] = 0.0;
	
	SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
	TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
	CreateTimer(0.1, Timer_SimpleRefresh, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Handled;
}

public Action Command_RotateCameraLeft(int client, int args)
{
	if (!IsValidClient(client) || !g_bThirdPersonEnabled[client])
		return Plugin_Handled;

	switch(g_iCameraRotation[client])
	{
		case 0: g_iCameraRotation[client] = 90;
		case 90: g_iCameraRotation[client] = 180;
		case 180: g_iCameraRotation[client] = -90;
		case -90: g_iCameraRotation[client] = 0;
	}
	
	float angles[3];
	angles[0] = 45.0; 
	angles[1] = float(g_iCameraRotation[client]);
	angles[2] = 0.0; 
	
	SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
	TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
	CreateTimer(0.1, Timer_SimpleRefresh, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Handled;
}

public Action Command_ToggleHardCodedBinds(int client, int args)
{
	if (!IsValidClient(client) || !IsInTCStyle(client))
	{
		Shavit_PrintToChat(client, "\x07ffffffThis command is only available in the \x07A082FFTank Controls \x07ffffffstyle");
		return Plugin_Handled;
	}
	
	g_bUseHardcodedKey[client] = !g_bUseHardcodedKey[client];

	// Save setting to cookie
	char buffer[2];
	Format(buffer, sizeof(buffer), "%d", g_bUseHardcodedKey[client]);
	g_cToggleTCKeysCookie.Set(client, buffer);
	
	if (g_bUseHardcodedKey[client])
	{
		Shavit_PrintToChat(client, "\x078efeffTank Controls: \x07ffffffHardcoded camera rotation binds: \x078efeffOn");
	}
	else
	{
		Shavit_PrintToChat(client, "\x078efeffTank Controls: \x07ffffffHardcoded camera rotation binds: \x07A082FFOff");
	}
	
	return Plugin_Handled;
}

public Action Command_ToggleNightVision(int client, int args)
{
    if (!IsValidClient(client) || !IsPlayerAlive(client))
    {
        return Plugin_Handled;
    }

    if (IsInTCStyle(client))
    {
        g_bNightVisionIsEnabled[client] = !g_bNightVisionIsEnabled[client];
        SetEntProp(client, Prop_Send, "m_bNightVisionOn", g_bNightVisionIsEnabled[client] ? 1 : 0);

		// Save setting to cookie
		char buffer[2];
		Format(buffer, sizeof(buffer), "%d", g_bNightVisionIsEnabled[client]);
		g_cNvgCookie.Set(client, buffer);

        Shavit_PrintToChat(client, "\x078efeffTank Controls: \x07ffffffNight Vision: %s",
            g_bNightVisionIsEnabled[client] ? "\x078efeffOn" : "\x07A082FFOff");
    }

    return Plugin_Handled;
}

public Action Command_ApplyFOV(int client, int args)
{
	if (client == 0)
		return Plugin_Handled;

	if (!IsInTCStyle(client))
		return Plugin_Handled;

	// If no FOV value is given
	if (args < 1)
	{
		Shavit_PrintToChat(client, "\x078efeffTank Controls: \x07ffffffCurrent FOV: \x07A082FF%i \x07ffffff(Default: 105 | Game Default: 90)", g_iFov[client]);
		Shavit_PrintToChat(client, "\x078efeffTank Controls: \x07ffffffUsage: /tcfov \x07A082FF<value>");
		Shavit_PrintToChat(client, "\x078efeffTank Controls: \x07A082FFChanging the FOV affects mouse sensitivity!");
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

	// Save setting to cookie
	char buffer[8];
	Format(buffer, sizeof(buffer), "%d", g_iFov[client]);
	g_cFovCookie.Set(client, buffer);

	Shavit_PrintToChat(client, "\x078efeffTank Controls: \x07ffffffFOV set to: \x07A082FF%i \x07ffffff(Default: 105 | Game Default: 90)", g_iFov[client]);
	Shavit_PrintToChat(client, "\x078efeffTank Controls: \x07A082FFChanging the FOV affects mouse sensitivity!");

	return Plugin_Handled;
}

public Action Command_TcHelp(int client, int args)
{
	if (client == 0)
		return Plugin_Handled;

	if (!IsInTCStyle(client))
		return Plugin_Handled;
	
	Shavit_PrintToChat(client, "\x078efeffTank Controls: \x07ffffffUse \x07A082FFShift \x07ffffff/ \x07A082FFE \x07ffffffto rotate the camera angle");
	Shavit_PrintToChat(client, "\x078efeffTank Controls: \x07ffffffYou can bind a key to \x07A082FFtcleft \x07ffffff/ \x07A082FFtcright \x07ffffffto rotate the camera");
	Shavit_PrintToChat(client, "\x078efeffTank Controls: \x07ffffffType \x07A082FF/tcfov \x07ffffffto change the Field of View");
	Shavit_PrintToChat(client, "\x078efeffTank Controls: \x07ffffffType \x07A082FF/tcnvg \x07ffffffto toggle Night Vision!");

	return Plugin_Handled;
}

public bool IsInTCStyle(int client)
{
	int style = Shavit_GetBhopStyle(client);
    char sStyleSpecial[sizeof(stylestrings_t::sSpecialString)];
	Shavit_GetStyleStrings(style, sSpecialString, sStyleSpecial, sizeof(sStyleSpecial));
    bool isInTCStyle = (StrContains(sStyleSpecial, g_sSpecialString) != -1);

	if (isInTCStyle)
		return true;
	else
		return false;
}
