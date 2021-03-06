/*
 * shavit's Timer - Core
 * by: shavit
 *
 * This file is part of shavit's Timer.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
*/

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <geoip>
#include <clientprefs>

#undef REQUIRE_PLUGIN
#define USES_CHAT_COLORS
#include <shavit>

#pragma newdecls required
#pragma semicolon 1

// #define DEBUG

// game type (CS:S/CS:GO/TF2)
ServerGame gSG_Type = Game_Unknown; // deperecated and here for backwards compatibility
EngineVersion gEV_Type = Engine_Unknown;

// database handle
Database gH_SQL = null;
bool gB_MySQL = false;

// forwards
Handle gH_Forwards_Start = null;
Handle gH_Forwards_Stop = null;
Handle gH_Forwards_FinishPre = null;
Handle gH_Forwards_Finish = null;
Handle gH_Forwards_OnRestart = null;
Handle gH_Forwards_OnEnd = null;
Handle gH_Forwards_OnPause = null;
Handle gH_Forwards_OnResume = null;
Handle gH_Forwards_OnStyleChanged = null;
Handle gH_Forwards_OnStyleConfigLoaded = null;
Handle gH_Forwards_OnDatabaseLoaded = null;
Handle gH_Forwards_OnChatConfigLoaded = null;
Handle gH_Forwards_OnUserCmdPre = null;
Handle gH_Forwards_OnTimerIncrement = null;
Handle gH_Forwards_OnTimerIncrementPost = null;

// timer variables
bool gB_TimerEnabled[MAXPLAYERS+1];
float gF_PlayerTimer[MAXPLAYERS+1];
float gF_PausePosition[MAXPLAYERS+1][3][3];
bool gB_ClientPaused[MAXPLAYERS+1];
int gI_Jumps[MAXPLAYERS+1];
int gI_Style[MAXPLAYERS+1];
bool gB_Auto[MAXPLAYERS+1];
int gI_ButtonCache[MAXPLAYERS+1];
int gI_Strafes[MAXPLAYERS+1];
float gF_AngleCache[MAXPLAYERS+1];
int gI_TotalMeasures[MAXPLAYERS+1];
int gI_GoodGains[MAXPLAYERS+1];
bool gB_DoubleSteps[MAXPLAYERS+1];
float gF_StrafeWarning[MAXPLAYERS+1];
bool gB_PracticeMode[MAXPLAYERS+1];
int gI_SHSW_FirstCombination[MAXPLAYERS+1];
int gI_Track[MAXPLAYERS+1];
int gI_MeasuredJumps[MAXPLAYERS+1];
int gI_PerfectJumps[MAXPLAYERS+1];

StringMap gSM_StyleCommands = null;

// cookies
Handle gH_StyleCookie = null;
Handle gH_AutoBhopCookie = null;

// late load
bool gB_Late = false;

// modules
bool gB_Zones = false;
bool gB_WR = false;
bool gB_Replay = false;
bool gB_Rankings = false;

// cvars
ConVar gCV_Restart = null;
ConVar gCV_Pause = null;
ConVar gCV_AllowTimerWithoutZone = null;
ConVar gCV_BlockPreJump = null;
ConVar gCV_NoZAxisSpeed = null;
ConVar gCV_VelocityTeleport = null;
ConVar gCV_DefaultStyle = null;

// cached cvars
bool gB_Restart = true;
bool gB_Pause = true;
bool gB_AllowTimerWithoutZone = false;
bool gB_BlockPreJump = false;
bool gB_NoZAxisSpeed = true;
bool gB_VelocityTeleport = false;
int gI_DefaultStyle = 0;
bool gB_StyleCookies = true;

// table prefix
char gS_MySQLPrefix[32];

// server side
ConVar sv_airaccelerate = null;
ConVar sv_autobunnyhopping = null;
ConVar sv_enablebunnyhopping = null;

// timer settings
bool gB_Registered = false;
int gI_Styles = 0;
char gS_StyleStrings[STYLE_LIMIT][STYLESTRINGS_SIZE][128];
any gA_StyleSettings[STYLE_LIMIT][STYLESETTINGS_SIZE];

// chat settings
char gS_ChatStrings[CHATSETTINGS_SIZE][128];

// misc cache
bool gB_StopChatSound = false;
bool gB_HookedJump = false;
char gS_LogPath[PLATFORM_MAX_PATH];
int gI_GroundTicks[MAXPLAYERS+1];
MoveType gMT_MoveType[MAXPLAYERS+1];
char gS_DeleteMap[MAXPLAYERS+1][160];

// flags
int gI_StyleFlag[STYLE_LIMIT];
char gS_StyleOverride[STYLE_LIMIT][32];

// kz support
bool gB_KZMap = false;

public Plugin myinfo =
{
	name = "[shavit] Core",
	author = "shavit",
	description = "The core for shavit's bhop timer.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Shavit_FinishMap", Native_FinishMap);
	CreateNative("Shavit_GetBhopStyle", Native_GetBhopStyle);
	CreateNative("Shavit_GetChatStrings", Native_GetChatStrings);
	CreateNative("Shavit_GetClientJumps", Native_GetClientJumps);
	CreateNative("Shavit_GetClientTime", Native_GetClientTime);
	CreateNative("Shavit_GetClientTrack", Native_GetClientTrack);
	CreateNative("Shavit_GetDatabase", Native_GetDatabase);
	CreateNative("Shavit_GetDB", Native_GetDB);
	CreateNative("Shavit_GetGameType", Native_GetGameType);
	CreateNative("Shavit_GetPerfectJumps", Native_GetPerfectJumps);
	CreateNative("Shavit_GetStrafeCount", Native_GetStrafeCount);
	CreateNative("Shavit_GetStyleCount", Native_GetStyleCount);
	CreateNative("Shavit_GetStyleSettings", Native_GetStyleSettings);
	CreateNative("Shavit_GetStyleStrings", Native_GetStyleStrings);
	CreateNative("Shavit_GetSync", Native_GetSync);
	CreateNative("Shavit_GetTimer", Native_GetTimer);
	CreateNative("Shavit_GetTimerStatus", Native_GetTimerStatus);
	CreateNative("Shavit_HasStyleAccess", Native_HasStyleAccess);
	CreateNative("Shavit_IsKZMap", Native_IsKZMap);
	CreateNative("Shavit_IsPracticeMode", Native_IsPracticeMode);
	CreateNative("Shavit_LoadSnapshot", Native_LoadSnapshot);
	CreateNative("Shavit_LogMessage", Native_LogMessage);
	CreateNative("Shavit_MarkKZMap", Native_MarkKZMap);
	CreateNative("Shavit_PauseTimer", Native_PauseTimer);
	CreateNative("Shavit_PrintToChat", Native_PrintToChat);
	CreateNative("Shavit_RestartTimer", Native_RestartTimer);
	CreateNative("Shavit_ResumeTimer", Native_ResumeTimer);
	CreateNative("Shavit_SaveSnapshot", Native_SaveSnapshot);
	CreateNative("Shavit_SetPracticeMode", Native_SetPracticeMode);
	CreateNative("Shavit_StartTimer", Native_StartTimer);
	CreateNative("Shavit_StopChatSound", Native_StopChatSound);
	CreateNative("Shavit_StopTimer", Native_StopTimer);

	// registers library, check "bool LibraryExists(const char[] name)" in order to use with other plugins
	RegPluginLibrary("shavit");

	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	// forwards
	gH_Forwards_Start = CreateGlobalForward("Shavit_OnStart", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_Stop = CreateGlobalForward("Shavit_OnStop", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_FinishPre = CreateGlobalForward("Shavit_OnFinishPre", ET_Event, Param_Cell, Param_Array);
	gH_Forwards_Finish = CreateGlobalForward("Shavit_OnFinish", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_OnRestart = CreateGlobalForward("Shavit_OnRestart", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnEnd = CreateGlobalForward("Shavit_OnEnd", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnPause = CreateGlobalForward("Shavit_OnPause", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnResume = CreateGlobalForward("Shavit_OnResume", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnStyleChanged = CreateGlobalForward("Shavit_OnStyleChanged", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_OnStyleConfigLoaded = CreateGlobalForward("Shavit_OnStyleConfigLoaded", ET_Event, Param_Cell);
	gH_Forwards_OnDatabaseLoaded = CreateGlobalForward("Shavit_OnDatabaseLoaded", ET_Event);
	gH_Forwards_OnChatConfigLoaded = CreateGlobalForward("Shavit_OnChatConfigLoaded", ET_Event);
	gH_Forwards_OnUserCmdPre = CreateGlobalForward("Shavit_OnUserCmdPre", ET_Event, Param_Cell, Param_CellByRef, Param_CellByRef, Param_Array, Param_Array, Param_Cell, Param_Cell, Param_Cell, Param_Array, Param_Array);
	gH_Forwards_OnTimerIncrement = CreateGlobalForward("Shavit_OnTimeIncrement", ET_Event, Param_Cell, Param_Array, Param_CellByRef, Param_Array);
	gH_Forwards_OnTimerIncrementPost = CreateGlobalForward("Shavit_OnTimeIncrementPost", ET_Event, Param_Cell, Param_Cell, Param_Array);

	LoadTranslations("shavit-core.phrases");

	// game types
	gEV_Type = GetEngineVersion();

	if(gEV_Type == Engine_CSS || gEV_Type == Engine_TF2)
	{
		gSG_Type = Game_CSS;
	}

	else if(gEV_Type == Engine_CSGO)
	{
		gSG_Type = Game_CSGO;

		sv_autobunnyhopping = FindConVar("sv_autobunnyhopping");
		sv_autobunnyhopping.BoolValue = false;
	}

	else
	{
		SetFailState("This plugin was meant to be used in CS:S, CS:GO and TF2 *only*.");
	}

	// database connections
	SQL_SetPrefix();
	SQL_DBConnect();

	// hooks
	gB_HookedJump = HookEventEx("player_jump", Player_Jump);
	HookEvent("player_death", Player_Death);
	HookEvent("player_team", Player_Death);
	HookEvent("player_spawn", Player_Death);

	// commands START
	// style
	RegConsoleCmd("sm_style", Command_Style, "Choose your bhop style.");
	RegConsoleCmd("sm_styles", Command_Style, "Choose your bhop style.");
	RegConsoleCmd("sm_diff", Command_Style, "Choose your bhop style.");
	RegConsoleCmd("sm_difficulty", Command_Style, "Choose your bhop style.");
	gH_StyleCookie = RegClientCookie("shavit_style", "Style cookie", CookieAccess_Protected);

	// timer start
	RegConsoleCmd("sm_s", Command_StartTimer, "Start your timer.");
	RegConsoleCmd("sm_start", Command_StartTimer, "Start your timer.");
	RegConsoleCmd("sm_r", Command_StartTimer, "Start your timer.");
	RegConsoleCmd("sm_restart", Command_StartTimer, "Start your timer.");

	RegConsoleCmd("sm_b", Command_StartTimer, "Start your timer on the bonus track.");
	RegConsoleCmd("sm_bonus", Command_StartTimer, "Start your timer on the bonus track.");

	// teleport to end
	RegConsoleCmd("sm_end", Command_TeleportEnd, "Teleport to endzone.");

	RegConsoleCmd("sm_bend", Command_TeleportEnd, "Teleport to endzone of the bonus track.");
	RegConsoleCmd("sm_bonusend", Command_TeleportEnd, "Teleport to endzone of the bonus track.");

	// timer stop
	RegConsoleCmd("sm_stop", Command_StopTimer, "Stop your timer.");

	// timer pause / resume
	RegConsoleCmd("sm_pause", Command_TogglePause, "Toggle pause.");
	RegConsoleCmd("sm_unpause", Command_TogglePause, "Toggle pause.");
	RegConsoleCmd("sm_resume", Command_TogglePause, "Toggle pause");

	// autobhop toggle
	RegConsoleCmd("sm_auto", Command_AutoBhop, "Toggle autobhop.");
	RegConsoleCmd("sm_autobhop", Command_AutoBhop, "Toggle autobhop.");
	gH_AutoBhopCookie = RegClientCookie("shavit_autobhop", "Autobhop cookie", CookieAccess_Protected);

	// doublestep fixer
	AddCommandListener(Command_DoubleStep, "+ds");
	AddCommandListener(Command_DoubleStep, "-ds");

	// style commands
	gSM_StyleCommands = new StringMap();

	#if defined DEBUG
	RegConsoleCmd("sm_finishtest", Command_FinishTest);
	#endif

	// admin
	RegAdminCmd("sm_deletemap", Command_DeleteMap, ADMFLAG_ROOT, "Deletes all map data. Usage: sm_deletemap <map>");
	// commands END

	// logs
	BuildPath(Path_SM, gS_LogPath, PLATFORM_MAX_PATH, "logs/shavit.log");

	CreateConVar("shavit_version", SHAVIT_VERSION, "Plugin version.", (FCVAR_NOTIFY | FCVAR_DONTRECORD));

	gCV_Restart = CreateConVar("shavit_core_restart", "1", "Allow commands that restart the timer?", 0, true, 0.0, true, 1.0);
	gCV_Pause = CreateConVar("shavit_core_pause", "1", "Allow pausing?", 0, true, 0.0, true, 1.0);
	gCV_AllowTimerWithoutZone = CreateConVar("shavit_core_timernozone", "0", "Allow the timer to start if there's no start zone?", 0, true, 0.0, true, 1.0);
	gCV_BlockPreJump = CreateConVar("shavit_core_blockprejump", "0", "Prevents jumping in the start zone.", 0, true, 0.0, true, 1.0);
	gCV_NoZAxisSpeed = CreateConVar("shavit_core_nozaxisspeed", "1", "Don't start timer if vertical speed exists (btimes style).", 0, true, 0.0, true, 1.0);
	gCV_VelocityTeleport = CreateConVar("shavit_core_velocityteleport", "0", "Teleport the client when changing its velocity? (for special styles)", 0, true, 0.0, true, 1.0);
	gCV_DefaultStyle = CreateConVar("shavit_core_defaultstyle", "0", "Default style ID.\nAdd the '!' prefix to disable style cookies - i.e. \"!3\" to *force* scroll to be the default style.", 0, true, 0.0);

	gCV_Restart.AddChangeHook(OnConVarChanged);
	gCV_Pause.AddChangeHook(OnConVarChanged);
	gCV_AllowTimerWithoutZone.AddChangeHook(OnConVarChanged);
	gCV_BlockPreJump.AddChangeHook(OnConVarChanged);
	gCV_NoZAxisSpeed.AddChangeHook(OnConVarChanged);
	gCV_VelocityTeleport.AddChangeHook(OnConVarChanged);
	gCV_DefaultStyle.AddChangeHook(OnConVarChanged);

	AutoExecConfig();

	sv_airaccelerate = FindConVar("sv_airaccelerate");
	sv_airaccelerate.Flags &= ~(FCVAR_NOTIFY | FCVAR_REPLICATED);

	sv_enablebunnyhopping = FindConVar("sv_enablebunnyhopping");
	
	if(sv_enablebunnyhopping != null)
	{
		sv_enablebunnyhopping.Flags &= ~(FCVAR_NOTIFY | FCVAR_REPLICATED);
	}

	// late
	if(gB_Late)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				OnClientPutInServer(i);
			}
		}
	}

	gB_Zones = LibraryExists("shavit-zones");
	gB_WR = LibraryExists("shavit-wr");
	gB_Replay = LibraryExists("shavit-replay");
	gB_Rankings = LibraryExists("shavit-rankings");
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	gB_Restart = gCV_Restart.BoolValue;
	gB_Pause = gCV_Pause.BoolValue;
	gB_AllowTimerWithoutZone = gCV_AllowTimerWithoutZone.BoolValue;
	gB_BlockPreJump = gCV_BlockPreJump.BoolValue;
	gB_NoZAxisSpeed = gCV_NoZAxisSpeed.BoolValue;
	gB_VelocityTeleport = gCV_VelocityTeleport.BoolValue;

	if(convar == gCV_DefaultStyle)
	{
		gB_StyleCookies = newValue[0] != '!';
		gI_DefaultStyle = StringToInt(newValue[1]);
	}
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "shavit-zones"))
	{
		gB_Zones = true;
	}

	else if(StrEqual(name, "shavit-wr"))
	{
		gB_WR = true;
	}

	else if(StrEqual(name, "shavit-replay"))
	{
		gB_Replay = true;
	}

	else if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "shavit-zones"))
	{
		gB_Zones = false;
	}

	else if(StrEqual(name, "shavit-wr"))
	{
		gB_WR = false;
	}
	
	else if(StrEqual(name, "shavit-replay"))
	{
		gB_Replay = false;
	}
	
	else if(StrEqual(name, "shavit-rankings"))
	{
		gB_Rankings = false;
	}
}

public void OnMapStart()
{
	// styles
	if(!LoadStyles())
	{
		SetFailState("Could not load the styles configuration file. Make sure it exists (addons/sourcemod/configs/shavit-styles.cfg) and follows the proper syntax!");
	}

	// messages
	if(!LoadMessages())
	{
		SetFailState("Could not load the chat messages configuration file. Make sure it exists (addons/sourcemod/configs/shavit-messages.cfg) and follows the proper syntax!");
	}
}

public void OnMapEnd()
{
	gB_KZMap = false;
}

public Action Command_StartTimer(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	char sCommand[16];
	GetCmdArg(0, sCommand, 16);

	if(!gB_Restart)
	{
		if(args != -1)
		{
			Shavit_PrintToChat(client, "%T", "CommandDisabled", client, gS_ChatStrings[sMessageVariable], sCommand, gS_ChatStrings[sMessageText]);
		}

		return Plugin_Handled;
	}

	int track = Track_Main;

	if(StrContains(sCommand, "sm_b", false) == 0)
	{
		track = Track_Bonus;
	}

	if(gB_AllowTimerWithoutZone || (gB_Zones && (Shavit_ZoneExists(Zone_Start, track) || gB_KZMap)))
	{
		Call_StartForward(gH_Forwards_OnRestart);
		Call_PushCell(client);
		Call_PushCell(track);
		Call_Finish();

		if(gB_AllowTimerWithoutZone)
		{
			StartTimer(client, track);
		}
	}

	else
	{
		Shavit_PrintToChat(client, "%T", "StartZoneUndefined", client, gS_ChatStrings[sMessageWarning], gS_ChatStrings[sMessageText]);
	}

	return Plugin_Handled;
}

public Action Command_TeleportEnd(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	char sCommand[16];
	GetCmdArg(0, sCommand, 16);

	int track = Track_Main;

	if(StrContains(sCommand, "sm_b", false) == 0)
	{
		track = Track_Bonus;
	}

	if(gB_Zones && (Shavit_ZoneExists(Zone_End, track) || gB_KZMap))
	{
		Shavit_StopTimer(client);
		
		Call_StartForward(gH_Forwards_OnEnd);
		Call_PushCell(client);
		Call_PushCell(track);
		Call_Finish();
	}

	else
	{
		Shavit_PrintToChat(client, "%T", "EndZoneUndefined", client, gS_ChatStrings[sMessageWarning], gS_ChatStrings[sMessageText]);
	}

	return Plugin_Handled;
}

public Action Command_StopTimer(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	Shavit_StopTimer(client);

	return Plugin_Handled;
}

public Action Command_TogglePause(int client, int args)
{
	if(!IsValidClient(client) || !gB_TimerEnabled[client])
	{
		return Plugin_Handled;
	}

	if(Shavit_InsideZone(client, Zone_Start, gI_Track[client]))
	{
		Shavit_PrintToChat(client, "%T", "PauseStartZone", client, gS_ChatStrings[sMessageText], gS_ChatStrings[sMessageWarning], gS_ChatStrings[sMessageText], gS_ChatStrings[sMessageVariable], gS_ChatStrings[sMessageText]);

		return Plugin_Handled;
	}

	if(!gB_Pause)
	{
		char sCommand[16];
		GetCmdArg(0, sCommand, 16);

		Shavit_PrintToChat(client, "%T", "CommandDisabled", client, gS_ChatStrings[sMessageVariable], sCommand, gS_ChatStrings[sMessageText]);

		return Plugin_Handled;
	}

	if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1 && GetEntityMoveType(client) != MOVETYPE_LADDER)
	{
		Shavit_PrintToChat(client, "%T", "PauseNotOnGround", client, gS_ChatStrings[sMessageWarning], gS_ChatStrings[sMessageText]);

		return Plugin_Handled;
	}

	if(gB_ClientPaused[client])
	{
		TeleportEntity(client, gF_PausePosition[client][0], gF_PausePosition[client][1], gF_PausePosition[client][2]);
		ResumeTimer(client);

		Shavit_PrintToChat(client, "%T", "MessageUnpause", client, gS_ChatStrings[sMessageText], gS_ChatStrings[sMessageWarning], gS_ChatStrings[sMessageText]);
	}

	else
	{
		GetClientAbsOrigin(client, gF_PausePosition[client][0]);
		GetClientEyeAngles(client, gF_PausePosition[client][1]);
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", gF_PausePosition[client][2]);

		PauseTimer(client);

		Shavit_PrintToChat(client, "%T", "MessagePause", client, gS_ChatStrings[sMessageText], gS_ChatStrings[sMessageWarning], gS_ChatStrings[sMessageText]);
	}

	return Plugin_Handled;
}

#if defined DEBUG
public Action Command_FinishTest(int client, int args)
{
	Shavit_FinishMap(client, gI_Track[client]);

	return Plugin_Handled;
}
#endif

public Action Command_DeleteMap(int client, int args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "Usage: sm_deletemap <map>\nOnce a map is chosen, \"sm_deletemap confirm\" to run the deletion.");

		return Plugin_Handled;
	}

	char sArgs[160];
	GetCmdArgString(sArgs, 160);

	if(StrEqual(sArgs, "confirm") && strlen(gS_DeleteMap[client]) > 0)
	{
		if(gB_WR)
		{
			Shavit_WR_DeleteMap(gS_DeleteMap[client]);
			ReplyToCommand(client, "Deleted all records for %s.", gS_DeleteMap[client]);
		}

		if(gB_Zones)
		{
			Shavit_Zones_DeleteMap(gS_DeleteMap[client]);
			ReplyToCommand(client, "Deleted all zones for %s.", gS_DeleteMap[client]);
		}

		if(gB_Replay)
		{
			Shavit_Replay_DeleteMap(gS_DeleteMap[client]);
			ReplyToCommand(client, "Deleted all replay data for %s.", gS_DeleteMap[client]);
		}

		if(gB_Rankings)
		{
			Shavit_Rankings_DeleteMap(gS_DeleteMap[client]);
			ReplyToCommand(client, "Deleted all rankings for %s.", gS_DeleteMap[client]);
		}

		ReplyToCommand(client, "Finished deleting data for %s.", gS_DeleteMap[client]);
		strcopy(gS_DeleteMap[client], 160, "");
	}

	else
	{
		strcopy(gS_DeleteMap[client], 160, sArgs);
		ReplyToCommand(client, "Map to delete is now %s.\nRun \"sm_deletemap confirm\" to delete all data regarding the map %s.", gS_DeleteMap[client], gS_DeleteMap[client]);
	}

	return Plugin_Handled;
}

public Action Command_AutoBhop(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_Auto[client] = !gB_Auto[client];

	if(gB_Auto[client])
	{
		Shavit_PrintToChat(client, "%T", "AutobhopEnabled", client, gS_ChatStrings[sMessageVariable2], gS_ChatStrings[sMessageText]);
	}

	else
	{
		Shavit_PrintToChat(client, "%T", "AutobhopDisabled", client, gS_ChatStrings[sMessageWarning], gS_ChatStrings[sMessageText]);
	}

	char sAutoBhop[4];
	IntToString(view_as<int>(gB_Auto[client]), sAutoBhop, 4);
	SetClientCookie(client, gH_AutoBhopCookie, sAutoBhop);

	UpdateStyleSettings(client);

	return Plugin_Handled;
}

public Action Command_DoubleStep(int client, const char[] command, int args)
{
	gB_DoubleSteps[client] = (command[0] == '+');

	return Plugin_Handled;
}

public Action Command_Style(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	Menu menu = new Menu(StyleMenu_Handler);
	menu.SetTitle("%T", "StyleMenuTitle", client);

	for(int i = 0; i < gI_Styles; i++)
	{
		char sInfo[8];
		IntToString(i, sInfo, 8);

		char sDisplay[64];

		if(gA_StyleSettings[i][bUnranked])
		{
			FormatEx(sDisplay, 64, "%T %s", "StyleUnranked", client, gS_StyleStrings[i][sStyleName]);
		}

		else
		{
			float time = 0.0;

			if(gB_WR)
			{
				Shavit_GetWRTime(i, time, Track_Main);
			}

			if(time > 0.0)
			{
				char sTime[32];
				FormatSeconds(time, sTime, 32, false);

				FormatEx(sDisplay, 64, "%s - WR: %s", gS_StyleStrings[i][sStyleName], sTime);
			}

			else
			{
				strcopy(sDisplay, 64, gS_StyleStrings[i][sStyleName]);
			}
		}

		menu.AddItem(sInfo, sDisplay, (gI_Style[client] == i || !Shavit_HasStyleAccess(client, i))? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	}

	// should NEVER happen
	if(menu.ItemCount == 0)
	{
		menu.AddItem("-1", "Nothing");
	}

	else if(menu.ItemCount <= ((gEV_Type == Engine_CSS)? 9:8))
	{
		menu.Pagination = MENU_NO_PAGINATION;
	}

	menu.ExitButton = true;
	menu.Display(client, 20);

	return Plugin_Handled;
}

public int StyleMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char info[16];
		menu.GetItem(param2, info, 16);

		int style = StringToInt(info);

		if(style == -1)
		{
			return 0;
		}

		ChangeClientStyle(param1, style, true);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void CallOnStyleChanged(int client, int oldstyle, int newstyle, bool manual)
{
	Call_StartForward(gH_Forwards_OnStyleChanged);
	Call_PushCell(client);
	Call_PushCell(oldstyle);
	Call_PushCell(newstyle);
	Call_PushCell(gI_Track[client]);
	Call_PushCell(manual);
	Call_Finish();

	gI_Style[client] = newstyle;

	UpdateStyleSettings(client);
}

void ChangeClientStyle(int client, int style, bool manual)
{
	if(!IsValidClient(client))
	{
		return;
	}

	if(!Shavit_HasStyleAccess(client, style))
	{
		if(manual)
		{
			Shavit_PrintToChat(client, "%T", "StyleNoAccess", client, gS_ChatStrings[sMessageWarning], gS_ChatStrings[sMessageText]);
		}

		return;
	}

	if(manual)
	{
		Shavit_PrintToChat(client, "%T", "StyleSelection", client, gS_ChatStrings[sMessageStyle], gS_StyleStrings[style][sStyleName], gS_ChatStrings[sMessageText]);
	}

	if(gA_StyleSettings[style][bUnranked])
	{
		Shavit_PrintToChat(client, "%T", "UnrankedWarning", client, gS_ChatStrings[sMessageWarning], gS_ChatStrings[sMessageText]);
	}

	int aa_old = RoundToZero(gA_StyleSettings[gI_Style[client]][fAiraccelerate]);
	int aa_new = RoundToZero(gA_StyleSettings[style][fAiraccelerate]);

	if(aa_old != aa_new)
	{
		Shavit_PrintToChat(client, "%T", "NewAiraccelerate", client, aa_old, gS_ChatStrings[sMessageVariable], aa_new, gS_ChatStrings[sMessageText]);
	}

	CallOnStyleChanged(client, gI_Style[client], style, manual);

	StopTimer(client);

	if(gB_AllowTimerWithoutZone || (gB_Zones && (Shavit_ZoneExists(Zone_Start, gI_Track[client]) || gB_KZMap)))
	{
		Call_StartForward(gH_Forwards_OnRestart);
		Call_PushCell(client);
		Call_PushCell(gI_Track[client]);
		Call_Finish();
	}

	char sStyle[4];
	IntToString(style, sStyle, 4);

	SetClientCookie(client, gH_StyleCookie, sStyle);
}

// used as an alternative for games where player_jump isn't a thing, such as TF2
public void Bunnyhop_OnLeaveGround(int client, bool jumped, bool ladder)
{
	if(gB_HookedJump || !jumped || ladder)
	{
		return;
	}

	DoJump(client);
}

public void Player_Jump(Event event, const char[] name, bool dontBroadcast)
{
	DoJump(GetClientOfUserId(event.GetInt("userid")));
}

void DoJump(int client)
{
	if(gB_TimerEnabled[client])
	{
		gI_Jumps[client]++;
	}

	// TF2 doesn't use stamina
	if(gEV_Type != Engine_TF2 && (gA_StyleSettings[gI_Style[client]][bEasybhop]) || Shavit_InsideZone(client, Zone_Easybhop, gI_Track[client]))
	{
		SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
	}

	RequestFrame(VelocityChanges, GetClientSerial(client));
}

void VelocityChanges(int data)
{
	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	if(view_as<float>(gA_StyleSettings[gI_Style[client]][fSpeedMultiplier]) != 1.0)
	{
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", view_as<float>(gA_StyleSettings[gI_Style[client]][fSpeedMultiplier]));
	}

	float fAbsVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);

	float fSpeed = (SquareRoot(Pow(fAbsVelocity[0], 2.0) + Pow(fAbsVelocity[1], 2.0)));

	if(fSpeed == 0.0)
	{
		return;
	}

	float fVelocityMultiplier = view_as<float>(gA_StyleSettings[gI_Style[client]][fVelocity]);
	float fVelocityBonus = view_as<float>(gA_StyleSettings[gI_Style[client]][fBonusVelocity]);
	float fMin = view_as<float>(gA_StyleSettings[gI_Style[client]][fMinVelocity]);

	if(fVelocityMultiplier != 0.0)
	{
		fAbsVelocity[0] *= fVelocityMultiplier;
		fAbsVelocity[1] *= fVelocityMultiplier;
	}

	if(fVelocityBonus != 0.0)
	{
		float x = fSpeed / (fSpeed + fVelocityBonus);
		fAbsVelocity[0] /= x;
		fAbsVelocity[1] /= x;
	}

	if(fMin != 0.0 && fSpeed < fMin)
	{
		float x = (fSpeed / fMin);
		fAbsVelocity[0] /= x;
		fAbsVelocity[1] /= x;
	}

	if(!gB_VelocityTeleport)
	{
		SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);
	}

	else
	{
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fAbsVelocity);
	}
}

public void Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	ResumeTimer(client);
	StopTimer(client);
}

public int Native_GetGameType(Handle handler, int numParams)
{
	return view_as<int>(gSG_Type);
}

public int Native_GetDatabase(Handle handler, int numParams)
{
	return view_as<int>(CloneHandle(gH_SQL, handler));
}

public int Native_GetDB(Handle handler, int numParams)
{
	SetNativeCellRef(1, gH_SQL);
}

public int Native_GetTimer(Handle handler, int numParams)
{
	// 1 - client
	int client = GetNativeCell(1);

	// 2 - time
	SetNativeCellRef(2, gF_PlayerTimer[client]);
	SetNativeCellRef(3, gI_Jumps[client]);
	SetNativeCellRef(4, gI_Style[client]);
	SetNativeCellRef(5, gB_TimerEnabled[client]);
}

public int Native_GetClientTime(Handle handler, int numParams)
{
	return view_as<int>(gF_PlayerTimer[GetNativeCell(1)]);
}

public int Native_GetClientTrack(Handle handler, int numParams)
{
	return gI_Track[GetNativeCell(1)];
}

public int Native_GetClientJumps(Handle handler, int numParams)
{
	return gI_Jumps[GetNativeCell(1)];
}

public int Native_GetBhopStyle(Handle handler, int numParams)
{
	return gI_Style[GetNativeCell(1)];
}

public int Native_GetTimerStatus(Handle handler, int numParams)
{
	return GetTimerStatus(GetNativeCell(1));
}

public int Native_HasStyleAccess(Handle handler, int numParams)
{
	int style = GetNativeCell(2);

	return CheckCommandAccess(GetNativeCell(1), (strlen(gS_StyleOverride[style]) > 0)? gS_StyleOverride[style]:"<none>", gI_StyleFlag[style]);
}

public int Native_IsKZMap(Handle handler, int numParams)
{
	return view_as<bool>(gB_KZMap);
}

public int Native_StartTimer(Handle handler, int numParams)
{
	StartTimer(GetNativeCell(1), GetNativeCell(2));
}

public int Native_StopTimer(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	StopTimer(client);

	Call_StartForward(gH_Forwards_Stop);
	Call_PushCell(client);
	Call_PushCell(gI_Track[client]);
	Call_Finish();
}

public int Native_FinishMap(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	any[] snapshot = new any[TIMERSNAPSHOT_SIZE];
	snapshot[bTimerEnabled] = gB_TimerEnabled[client];
	snapshot[bClientPaused] = gB_ClientPaused[client];
	snapshot[iJumps] = gI_Jumps[client];
	snapshot[bsStyle] = gI_Style[client];
	snapshot[iStrafes] = gI_Strafes[client];
	snapshot[iTotalMeasures] = gI_TotalMeasures[client];
	snapshot[iGoodGains] = gI_GoodGains[client];
	snapshot[fServerTime] = GetEngineTime();
	snapshot[fCurrentTime] = gF_PlayerTimer[client];
	snapshot[iSHSWCombination] = gI_SHSW_FirstCombination[client];
	snapshot[iTimerTrack] = gI_Track[client];
	snapshot[iMeasuredJumps] = gI_MeasuredJumps[client];
	snapshot[iPerfectJumps] = gI_PerfectJumps[client];

	Action result = Plugin_Continue;
	Call_StartForward(gH_Forwards_FinishPre);
	Call_PushCell(client);
	Call_PushArrayEx(snapshot, TIMERSNAPSHOT_SIZE, SM_PARAM_COPYBACK);
	Call_Finish(result);
	
	if(result != Plugin_Continue && result != Plugin_Changed)
	{
		return;
	}

	Call_StartForward(gH_Forwards_Finish);
	Call_PushCell(client);

	int style = 0;
	int track = Track_Main;
	float perfs = 100.0;

	if(result == Plugin_Continue)
	{
		Call_PushCell(style = gI_Style[client]);
		Call_PushCell(gF_PlayerTimer[client]);
		Call_PushCell(gI_Jumps[client]);
		Call_PushCell(gI_Strafes[client]);
		Call_PushCell((gA_StyleSettings[gI_Style[client]][bSync])? (gI_GoodGains[client] == 0)? 0.0:(gI_GoodGains[client] / float(gI_TotalMeasures[client]) * 100.0):-1.0);
		Call_PushCell(track = gI_Track[client]);
		perfs = (gI_MeasuredJumps[client] == 0)? 100.0:(gI_PerfectJumps[client] / float(gI_MeasuredJumps[client]) * 100.0);
	}

	else
	{
		Call_PushCell(style = snapshot[bsStyle]);
		Call_PushCell(snapshot[fCurrentTime]);
		Call_PushCell(snapshot[iJumps]);
		Call_PushCell(snapshot[iStrafes]);
		Call_PushCell((gA_StyleSettings[snapshot[bsStyle]][bSync])? (snapshot[iGoodGains] == 0)? 0.0:(snapshot[iGoodGains] / float(snapshot[iTotalMeasures]) * 100.0):-1.0);
		Call_PushCell(track = snapshot[iTimerTrack]);
		perfs = (snapshot[iMeasuredJumps] == 0)? 100.0:(snapshot[iPerfectJumps] / float(snapshot[iMeasuredJumps]) * 100.0);
	}

	float oldtime = 0.0;

	if(gB_WR)
	{
		Shavit_GetPlayerPB(client, style, oldtime, track);
	}

	Call_PushCell(oldtime);
	Call_PushCell(perfs);
	Call_Finish();

	StopTimer(client);
}

public int Native_PauseTimer(Handle handler, int numParams)
{
	PauseTimer(GetNativeCell(1));
}

public int Native_ResumeTimer(Handle handler, int numParams)
{
	ResumeTimer(GetNativeCell(1));
}

public int Native_StopChatSound(Handle handler, int numParams)
{
	gB_StopChatSound = true;
}

public int Native_PrintToChat(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	if(!IsClientInGame(client))
	{
		gB_StopChatSound = false;
		
		return;
	}

	static int iWritten = 0; // useless?

	char sBuffer[300];
	FormatNativeString(0, 2, 3, 300, iWritten, sBuffer);
	Format(sBuffer, 300, "%s %s%s", gS_ChatStrings[sMessagePrefix], gS_ChatStrings[sMessageText], sBuffer);

	if(IsSource2013(gEV_Type))
	{
		Handle hSayText2 = StartMessageOne("SayText2", client);

		if(hSayText2 != null)
		{
			BfWriteByte(hSayText2, 0);
			BfWriteByte(hSayText2, !gB_StopChatSound);
			BfWriteString(hSayText2, sBuffer);
		}

		EndMessage();
	}

	else
	{
		PrintToChat(client, " %s", sBuffer);
	}

	gB_StopChatSound = false;
}

public int Native_RestartTimer(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int track = GetNativeCell(2);

	Call_StartForward(gH_Forwards_OnRestart);
	Call_PushCell(client);
	Call_PushCell(track);
	Call_Finish();

	StartTimer(client, track);
}

public int Native_GetPerfectJumps(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	return view_as<int>((gI_MeasuredJumps[client] == 0)? 100.0:(gI_PerfectJumps[client] / float(gI_MeasuredJumps[client]) * 100.0));
}

public int Native_GetStrafeCount(Handle handler, int numParams)
{
	return gI_Strafes[GetNativeCell(1)];
}

public int Native_GetSync(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	return view_as<int>((gA_StyleSettings[gI_Style[client]][bSync])? (gI_GoodGains[client] == 0)? 0.0:(gI_GoodGains[client] / float(gI_TotalMeasures[client]) * 100.0):-1.0);
}

public int Native_GetStyleCount(Handle handler, int numParams)
{
	return (gI_Styles > 0)? gI_Styles:-1;
}

public int Native_GetStyleSettings(Handle handler, int numParams)
{
	return SetNativeArray(2, gA_StyleSettings[GetNativeCell(1)], STYLESETTINGS_SIZE);
}

public int Native_GetStyleStrings(Handle handler, int numParams)
{
	return SetNativeString(3, gS_StyleStrings[GetNativeCell(1)][GetNativeCell(2)], GetNativeCell(4));
}

public int Native_GetChatStrings(Handle handler, int numParams)
{
	return SetNativeString(2, gS_ChatStrings[GetNativeCell(1)], GetNativeCell(3));
}

public int Native_SetPracticeMode(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	bool practice = view_as<bool>(GetNativeCell(2));
	bool alert = view_as<bool>(GetNativeCell(3));

	if(alert && practice && !gB_PracticeMode[client])
	{
		Shavit_PrintToChat(client, "%T", "PracticeModeAlert", client, gS_ChatStrings[sMessageWarning], gS_ChatStrings[sMessageText]);
	}

	gB_PracticeMode[client] = practice;
}

public int Native_IsPracticeMode(Handle handler, int numParams)
{
	return view_as<int>(gB_PracticeMode[GetNativeCell(1)]);
}

public int Native_SaveSnapshot(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	any[] snapshot = new any[TIMERSNAPSHOT_SIZE];
	snapshot[bTimerEnabled] = gB_TimerEnabled[client];
	snapshot[bClientPaused] = gB_ClientPaused[client];
	snapshot[iJumps] = gI_Jumps[client];
	snapshot[bsStyle] = gI_Style[client];
	snapshot[iStrafes] = gI_Strafes[client];
	snapshot[iTotalMeasures] = gI_TotalMeasures[client];
	snapshot[iGoodGains] = gI_GoodGains[client];
	snapshot[fServerTime] = GetEngineTime();
	snapshot[fCurrentTime] = gF_PlayerTimer[client];
	snapshot[iSHSWCombination] = gI_SHSW_FirstCombination[client];
	snapshot[iTimerTrack] = gI_Track[client];
	snapshot[iMeasuredJumps] = gI_MeasuredJumps[client];
	snapshot[iPerfectJumps] = gI_PerfectJumps[client];

	return SetNativeArray(2, snapshot, TIMERSNAPSHOT_SIZE);
}

public int Native_LoadSnapshot(Handle handler, int numParams)
{
	int client = GetNativeCell(1);

	any[] snapshot = new any[TIMERSNAPSHOT_SIZE];
	GetNativeArray(2, snapshot, TIMERSNAPSHOT_SIZE);

	gI_Track[client] = view_as<int>(snapshot[iTimerTrack]);

	if(gI_Style[client] != snapshot[bsStyle] && Shavit_HasStyleAccess(client, snapshot[bsStyle]))
	{
		CallOnStyleChanged(client, gI_Style[client], snapshot[bsStyle], false);
	}

	gB_TimerEnabled[client] = view_as<bool>(snapshot[bTimerEnabled]);
	gB_ClientPaused[client] = view_as<bool>(snapshot[bClientPaused]);
	gI_Jumps[client] = view_as<int>(snapshot[iJumps]);
	gI_Style[client] = snapshot[bsStyle];
	gI_Strafes[client] = view_as<int>(snapshot[iStrafes]);
	gI_TotalMeasures[client] = view_as<int>(snapshot[iTotalMeasures]);
	gI_GoodGains[client] = view_as<int>(snapshot[iGoodGains]);
	gF_PlayerTimer[client] = snapshot[fCurrentTime];
	gI_SHSW_FirstCombination[client] = view_as<int>(snapshot[iSHSWCombination]);
	gI_MeasuredJumps[client] = view_as<int>(snapshot[iMeasuredJumps]);
	gI_PerfectJumps[client] = view_as<int>(snapshot[iPerfectJumps]);
}

public int Native_LogMessage(Handle plugin, int numParams)
{
	char sPlugin[32];

	if(!GetPluginInfo(plugin, PlInfo_Name, sPlugin, 32))
	{
		GetPluginFilename(plugin, sPlugin, 32);
	}

	static int iWritten = 0;

	char sBuffer[300];
	FormatNativeString(0, 1, 2, 300, iWritten, sBuffer);
	
	LogToFileEx(gS_LogPath, "[%s] %s", sPlugin, sBuffer);
}

public int Native_MarkKZMap(Handle handler, int numParams)
{
	gB_KZMap = true;
}

int GetTimerStatus(int client)
{
	if(!gB_TimerEnabled[client])
	{
		return view_as<int>(Timer_Stopped);
	}

	else if(gB_ClientPaused[client])
	{
		return view_as<int>(Timer_Paused);
	}

	return view_as<int>(Timer_Running);
}

void StartTimer(int client, int track)
{
	if(!IsValidClient(client, true) || GetClientTeam(client) < 2 || IsFakeClient(client))
	{
		return;
	}

	float fSpeed[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fSpeed);

	if(!gB_NoZAxisSpeed || gA_StyleSettings[gI_Style[client]][bPrespeed] || (fSpeed[2] == 0.0 && SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0)) <= 290.0))
	{
		Action result = Plugin_Continue;
		Call_StartForward(gH_Forwards_Start);
		Call_PushCell(client);
		Call_PushCell(track);
		Call_Finish(result);

		if(result == Plugin_Continue)
		{
			gB_ClientPaused[client] = false;
			gI_Strafes[client] = 0;
			gI_Jumps[client] = 0;
			gI_TotalMeasures[client] = 0;
			gI_GoodGains[client] = 0;
			gF_PlayerTimer[client] = 0.0;
			gI_Track[client] = track;
			gB_TimerEnabled[client] = true;
			gI_SHSW_FirstCombination[client] = -1;
			gF_PlayerTimer[client] = 0.0;
			gB_PracticeMode[client] = false;
			gI_MeasuredJumps[client] = 0;
			gI_PerfectJumps[client] = 0;

			SetEntityGravity(client, view_as<float>(gA_StyleSettings[gI_Style[client]][fGravityMultiplier]));
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", view_as<float>(gA_StyleSettings[gI_Style[client]][fSpeedMultiplier]));
		}

		else if(result == Plugin_Handled || result == Plugin_Stop)
		{
			gB_TimerEnabled[client] = false;
		}
	}
}

void StopTimer(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}

	gB_TimerEnabled[client] = false;
	gI_Jumps[client] = 0;
	gF_PlayerTimer[client] = 0.0;
	gB_ClientPaused[client] = false;
	gI_Strafes[client] = 0;
	gI_TotalMeasures[client] = 0;
	gI_GoodGains[client] = 0;
}

void PauseTimer(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}

	Call_StartForward(gH_Forwards_OnPause);
	Call_PushCell(client);
	Call_PushCell(gI_Track[client]);
	Call_Finish();

	gB_ClientPaused[client] = true;
}

void ResumeTimer(int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}

	Call_StartForward(gH_Forwards_OnResume);
	Call_PushCell(client);
	Call_PushCell(gI_Track[client]);
	Call_Finish();

	gB_ClientPaused[client] = false;
}

public void OnClientDisconnect(int client)
{
	StopTimer(client);
}

public void OnClientCookiesCached(int client)
{
	if(IsFakeClient(client) || !IsClientInGame(client))
	{
		return;
	}

	char sCookie[4];

	if(gH_AutoBhopCookie != null)
	{
		GetClientCookie(client, gH_AutoBhopCookie, sCookie, 4);
	}

	gB_Auto[client] = (strlen(sCookie) > 0)? view_as<bool>(StringToInt(sCookie)):true;

	int style = gI_DefaultStyle;

	if(gB_StyleCookies && gH_StyleCookie != null)
	{
		GetClientCookie(client, gH_StyleCookie, sCookie, 4);
		int newstyle = StringToInt(sCookie);
	
		if(0 <= newstyle < gI_Styles)
		{
			style = newstyle;
		}
	}

	if(Shavit_HasStyleAccess(client, style))
	{
		CallOnStyleChanged(client, gI_Style[client], style, false);
	}
}

public void OnClientPutInServer(int client)
{
	StopTimer(client);

	if(!IsClientConnected(client) || IsFakeClient(client))
	{
		return;
	}

	gB_Auto[client] = true;
	gB_DoubleSteps[client] = false;
	gF_StrafeWarning[client] = 0.0;
	gB_PracticeMode[client] = false;
	gI_SHSW_FirstCombination[client] = -1;
	gI_Track[client] = 0;
	gI_Style[client] = 0;
	strcopy(gS_DeleteMap[client], 160, "");

	if(AreClientCookiesCached(client))
	{
		OnClientCookiesCached(client);
	}

	// not adding style permission check here for obvious reasons
	else
	{
		CallOnStyleChanged(client, 0, gI_DefaultStyle, false);
	}

	if(gH_SQL == null)
	{
		return;
	}

	SDKHook(client, SDKHook_PreThinkPost, PreThinkPost);

	char sAuthID3[32];

	if(!GetClientAuthId(client, AuthId_Steam3, sAuthID3, 32))
	{
		KickClient(client, "%T", "VerificationFailed", client);

		return;
	}

	char sName[MAX_NAME_LENGTH_SQL];
	GetClientName(client, sName, MAX_NAME_LENGTH_SQL);
	ReplaceString(sName, MAX_NAME_LENGTH_SQL, "#", "?"); // to avoid this: https://user-images.githubusercontent.com/3672466/28637962-0d324952-724c-11e7-8b27-15ff021f0a59.png

	int iLength = ((strlen(sName) * 2) + 1);
	char[] sEscapedName = new char[iLength];
	gH_SQL.Escape(sName, sEscapedName, iLength);

	char sIP[64];
	GetClientIP(client, sIP, 64);

	char sCountry[128];

	if(!GeoipCountry(sIP, sCountry, 128))
	{
		strcopy(sCountry, 128, "Local Area Network");
	}

	int iTime = GetTime();

	char sQuery[512];

	if(gB_MySQL)
	{
		FormatEx(sQuery, 512, "INSERT INTO %susers (auth, name, country, ip, lastlogin) VALUES ('%s', '%s', '%s', '%s', %d) ON DUPLICATE KEY UPDATE name = '%s', country = '%s', ip = '%s', lastlogin = %d;", gS_MySQLPrefix, sAuthID3, sEscapedName, sCountry, sIP, iTime, sEscapedName, sCountry, sIP, iTime);
	}

	else
	{
		FormatEx(sQuery, 512, "REPLACE INTO %susers (auth, name, country, ip, lastlogin) VALUES ('%s', '%s', '%s', '%s', %d);", gS_MySQLPrefix, sAuthID3, sEscapedName, sCountry, sIP, iTime);
	}

	gH_SQL.Query(SQL_InsertUser_Callback, sQuery, GetClientSerial(client));
}

public void SQL_InsertUser_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		int client = GetClientFromSerial(data);

		if(client == 0)
		{
			LogError("Timer error! Failed to insert a disconnected player's data to the table. Reason: %s", error);
		}

		else
		{
			LogError("Timer error! Failed to insert \"%N\"'s data to the table. Reason: %s", client, error);
		}

		return;
	}
}

bool LoadStyles()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/shavit-styles.cfg");

	KeyValues kv = new KeyValues("shavit-styles");
	
	if(!kv.ImportFromFile(sPath) || !kv.GotoFirstSubKey())
	{
		delete kv;

		return false;
	}

	int i = 0;

	do
	{
		kv.GetString("name", gS_StyleStrings[i][sStyleName], 128, "<MISSING STYLE NAME>");
		kv.GetString("shortname", gS_StyleStrings[i][sShortName], 128, "<MISSING SHORT STYLE NAME>");
		kv.GetString("htmlcolor", gS_StyleStrings[i][sHTMLColor], 128, "<MISSING STYLE HTML COLOR>");
		kv.GetString("command", gS_StyleStrings[i][sChangeCommand], 128, "");
		kv.GetString("clantag", gS_StyleStrings[i][sClanTag], 128, "<MISSING STYLE CLAN TAG>");
		kv.GetString("specialstring", gS_StyleStrings[i][sSpecialString], 128, "");
		kv.GetString("permission", gS_StyleStrings[i][sStylePermission], 128, "");

		gA_StyleSettings[i][bAutobhop] = view_as<bool>(kv.GetNum("autobhop", 1));
		gA_StyleSettings[i][bEasybhop] = view_as<bool>(kv.GetNum("easybhop", 1));
		gA_StyleSettings[i][bPrespeed] = view_as<bool>(kv.GetNum("prespeed", 0));
		gA_StyleSettings[i][fVelocityLimit] = kv.GetFloat("velocity_limit", 0.0);
		gA_StyleSettings[i][fAiraccelerate] = kv.GetFloat("airaccelerate", 1000.0);
		gA_StyleSettings[i][bEnableBunnyhopping] = view_as<bool>(kv.GetNum("bunnyhopping", 1));
		gA_StyleSettings[i][fRunspeed] = kv.GetFloat("runspeed", 260.00);
		gA_StyleSettings[i][fGravityMultiplier] = kv.GetFloat("gravity", 1.0);
		gA_StyleSettings[i][fSpeedMultiplier] = kv.GetFloat("speed", 1.0);
		gA_StyleSettings[i][bHalftime] = view_as<bool>(kv.GetNum("halftime", 0));
		gA_StyleSettings[i][fVelocity] = kv.GetFloat("velocity", 1.0);
		gA_StyleSettings[i][fBonusVelocity] = kv.GetFloat("bonus_velocity", 0.0);
		gA_StyleSettings[i][fMinVelocity] = kv.GetFloat("min_velocity", 0.0);
		gA_StyleSettings[i][bBlockW] = view_as<bool>(kv.GetNum("block_w", 0));
		gA_StyleSettings[i][bBlockA] = view_as<bool>(kv.GetNum("block_a", 0));
		gA_StyleSettings[i][bBlockS] = view_as<bool>(kv.GetNum("block_s", 0));
		gA_StyleSettings[i][bBlockD] = view_as<bool>(kv.GetNum("block_d", 0));
		gA_StyleSettings[i][bBlockUse] = view_as<bool>(kv.GetNum("block_use", 0));
		gA_StyleSettings[i][iForceHSW] = kv.GetNum("force_hsw", 0);
		gA_StyleSettings[i][iBlockPLeft] = kv.GetNum("block_pleft", 0);
		gA_StyleSettings[i][iBlockPRight] = kv.GetNum("block_pright", 0);
		gA_StyleSettings[i][iBlockPStrafe] = kv.GetNum("block_pstrafe", 0);
		gA_StyleSettings[i][bUnranked] = view_as<bool>(kv.GetNum("unranked", 0));
		gA_StyleSettings[i][bNoReplay] = view_as<bool>(kv.GetNum("noreplay", 0));
		gA_StyleSettings[i][bSync] = view_as<bool>(kv.GetNum("sync", 1));
		gA_StyleSettings[i][bStrafeCountW] = view_as<bool>(kv.GetNum("strafe_count_w", false));
		gA_StyleSettings[i][bStrafeCountA] = view_as<bool>(kv.GetNum("strafe_count_a", 1));
		gA_StyleSettings[i][bStrafeCountS] = view_as<bool>(kv.GetNum("strafe_count_s", false));
		gA_StyleSettings[i][bStrafeCountD] = view_as<bool>(kv.GetNum("strafe_count_d", 1));
		gA_StyleSettings[i][fRankingMultiplier] = kv.GetFloat("rankingmultiplier", 1.00);
		gA_StyleSettings[i][iSpecial] = kv.GetNum("special", 0);

		if(!gB_Registered && strlen(gS_StyleStrings[i][sChangeCommand]) > 0)
		{
			char sStyleCommands[32][32];
			int iCommands = ExplodeString(gS_StyleStrings[i][sChangeCommand], ";", sStyleCommands, 32, 32, false);

			char sDescription[128];
			FormatEx(sDescription, 128, "Change style to %s.", gS_StyleStrings[i][sStyleName]);

			for(int x = 0; x < iCommands; x++)
			{
				TrimString(sStyleCommands[x]);
				StripQuotes(sStyleCommands[x]);

				char sCommand[32];
				FormatEx(sCommand, 32, "sm_%s", sStyleCommands[x]);

				gSM_StyleCommands.SetValue(sCommand, i);

				RegConsoleCmd(sCommand, Command_StyleChange, sDescription);
			}
		}

		if(StrContains(gS_StyleStrings[i][sStylePermission], ";") != -1)
		{
			char sText[2][32];
			int iCount = ExplodeString(gS_StyleStrings[i][sStylePermission], ";", sText, 2, 32);

			AdminFlag flag = Admin_Reservation;

			if(FindFlagByChar(sText[0][0], flag))
			{
				gI_StyleFlag[i] = FlagToBit(flag);
			}

			strcopy(gS_StyleOverride[i], 32, (iCount >= 2)? sText[1]:"");
		}

		i++;
	}

	while(kv.GotoNextKey());

	delete kv;

	gI_Styles = i;
	gB_Registered = true;

	Call_StartForward(gH_Forwards_OnStyleConfigLoaded);
	Call_PushCell(gI_Styles);
	Call_Finish();

	return true;
}

public Action Command_StyleChange(int client, int args)
{
	char sCommand[128];
	GetCmdArg(0, sCommand, 128);

	int style = 0;

	if(gSM_StyleCommands.GetValue(sCommand, style))
	{
		ChangeClientStyle(client, style, true);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

bool LoadMessages()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/shavit-messages.cfg");

	KeyValues kv = new KeyValues("shavit-messages");
	
	if(!kv.ImportFromFile(sPath))
	{
		delete kv;

		return false;
	}

	kv.JumpToKey((IsSource2013(gEV_Type))? "CS:S":"CS:GO");

	kv.GetString("prefix", gS_ChatStrings[sMessagePrefix], 128, "\x075e70d0[Timer]");
	kv.GetString("text", gS_ChatStrings[sMessageText], 128, "\x07ffffff");
	kv.GetString("warning", gS_ChatStrings[sMessageWarning], 128, "\x07af2a22");
	kv.GetString("variable", gS_ChatStrings[sMessageVariable], 128, "\x077fd772");
	kv.GetString("variable2", gS_ChatStrings[sMessageVariable2], 128, "\x07276f5c");
	kv.GetString("style", gS_ChatStrings[sMessageStyle], 128, "\x07db88c2");

	delete kv;

	for(int i = 0; i < CHATSETTINGS_SIZE; i++)
	{
		for(int x = 0; x < sizeof(gS_GlobalColorNames); x++)
		{
			ReplaceString(gS_ChatStrings[i], 128, gS_GlobalColorNames[x], gS_GlobalColors[x]);
		}

		for(int x = 0; x < sizeof(gS_CSGOColorNames); x++)
		{
			ReplaceString(gS_ChatStrings[i], 128, gS_CSGOColorNames[x], gS_CSGOColors[x]);
		}

		ReplaceString(gS_ChatStrings[i], 128, "{RGB}", "\x07");
		ReplaceString(gS_ChatStrings[i], 128, "{RGBA}", "\x08");
	}

	Call_StartForward(gH_Forwards_OnChatConfigLoaded);
	Call_Finish();

	return true;
}

void SQL_SetPrefix()
{
	char sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, PLATFORM_MAX_PATH, "configs/shavit-prefix.txt");

	File fFile = OpenFile(sFile, "r");

	if(fFile == null)
	{
		SetFailState("Cannot open \"configs/shavit-prefix.txt\". Make sure this file exists and that the server has read permissions to it.");
	}
	
	char sLine[PLATFORM_MAX_PATH*2];

	while(fFile.ReadLine(sLine, PLATFORM_MAX_PATH*2))
	{
		TrimString(sLine);
		strcopy(gS_MySQLPrefix, 32, sLine);

		break;
	}

	delete fFile;
}

void SQL_DBConnect()
{
	if(gH_SQL != null)
	{
		delete gH_SQL;
	}

	char sError[255];

	if(SQL_CheckConfig("shavit")) // can't be asynced as we have modules that require this database connection instantly
	{
		gH_SQL = SQL_Connect("shavit", true, sError, 255);

		if(gH_SQL == null)
		{
			SetFailState("Timer startup failed. Reason: %s", sError);
		}
	}

	else
	{
		gH_SQL = SQLite_UseDatabase("shavit", sError, 255);
	}

	// support unicode names
	gH_SQL.SetCharset("utf8");

	char sDriver[8];
	gH_SQL.Driver.GetIdentifier(sDriver, 8);
	gB_MySQL = StrEqual(sDriver, "mysql", false);

	char sQuery[512];

	if(gB_MySQL)
	{
		FormatEx(sQuery, 512, "CREATE TABLE IF NOT EXISTS `%susers` (`auth` CHAR(32) NOT NULL, `name` VARCHAR(32), `country` CHAR(32), `ip` CHAR(64), `lastlogin` INT NOT NULL DEFAULT -1, `points` FLOAT NOT NULL DEFAULT 0, PRIMARY KEY (`auth`), INDEX `points` (`points`)) ENGINE=INNODB;", gS_MySQLPrefix);
	}

	else
	{
		FormatEx(sQuery, 512, "CREATE TABLE IF NOT EXISTS `%susers` (`auth` CHAR(32) NOT NULL PRIMARY KEY, `name` VARCHAR(32), `country` CHAR(32), `ip` CHAR(64), `lastlogin` INTEGER NOT NULL DEFAULT -1, `points` FLOAT NOT NULL DEFAULT 0);", gS_MySQLPrefix);
	}

	// CREATE TABLE IF NOT EXISTS
	gH_SQL.Query(SQL_CreateTable_Callback, sQuery);
}

public void SQL_CreateTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer error! Users' data table creation failed. Reason: %s", error);

		return;
	}

	char sQuery[192];
	FormatEx(sQuery, 192, "SELECT lastlogin FROM %susers LIMIT 1;", gS_MySQLPrefix);
	gH_SQL.Query(SQL_TableMigration1_Callback, sQuery, 0, DBPrio_High);

	FormatEx(sQuery, 192, "SELECT points FROM %susers LIMIT 1;", gS_MySQLPrefix);
	gH_SQL.Query(SQL_TableMigration2_Callback, sQuery, 0, DBPrio_High);

	char sTables[][] =
	{
		"maptiers",
		"mapzones",
		"playertimes"
	};

	for(int i = 0; i < sizeof(sTables); i++)
	{
		DataPack dp = new DataPack();
		dp.WriteString(sTables[i]);

		FormatEx(sQuery, 192, "SELECT map FROM %s%s WHERE map LIKE 'workshop%%' GROUP BY map;", gS_MySQLPrefix, sTables[i]);
		gH_SQL.Query(SQL_TableMigration3_Callback, sQuery, dp, DBPrio_Low);
	}

	Call_StartForward(gH_Forwards_OnDatabaseLoaded);
	Call_Finish();
}

public void SQL_TableMigration1_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		char sQuery[128];
		FormatEx(sQuery, 128, "ALTER TABLE `%susers` ADD %s;", gS_MySQLPrefix, (gB_MySQL)? "(`lastlogin` INT NOT NULL DEFAULT -1)":"COLUMN `lastlogin` INTEGER NOT NULL DEFAULT -1");
		gH_SQL.Query(SQL_AlterTable1_Callback, sQuery);
	}
}

public void SQL_AlterTable1_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer error! Table alteration 1 (core) failed. Reason: %s", error);

		return;
	}
}

public void SQL_TableMigration2_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		char sQuery[128];
		FormatEx(sQuery, 128, "ALTER TABLE `%susers` ADD %s;", gS_MySQLPrefix, (gB_MySQL)? "(`points` FLOAT NOT NULL DEFAULT 0)":"COLUMN `points` FLOAT NOT NULL DEFAULT 0");
		gH_SQL.Query(SQL_AlterTable2_Callback, sQuery);
	}
}

public void SQL_AlterTable2_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer error! Table alteration 2 (core) failed. Reason: %s", error);

		return;
	}
}

public void SQL_TableMigration3_Callback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	char sTable[16];

	data.Reset();
	data.ReadString(sTable, 16);
	delete data;

	if(results == null || results.RowCount == 0)
	{
		// no error logging here because not everyone runs the rankings/wr modules
		return;
	}

	while(results.FetchRow())
	{
		char sMap[160];
		results.FetchString(0, sMap, 160);

		char sDisplayMap[160];
		GetMapDisplayName(sMap, sDisplayMap, 160);

		char sQuery[256];
		FormatEx(sQuery, 256, "UPDATE %s%s SET map = '%s' WHERE map = '%s';", gS_MySQLPrefix, sTable, sDisplayMap, sMap);
		gH_SQL.Query(SQL_AlterTable3_Callback, sQuery, 0, DBPrio_High);
	}
}

public void SQL_AlterTable3_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer error! Table alteration 3 (core) failed. Reason: %s", error);

		return;
	}
}

public void PreThinkPost(int client)
{
	if(IsPlayerAlive(client))
	{
		sv_airaccelerate.FloatValue = view_as<float>(gA_StyleSettings[gI_Style[client]][fAiraccelerate]);

		if(sv_enablebunnyhopping != null)
		{
			sv_enablebunnyhopping.BoolValue = view_as<bool>(gA_StyleSettings[gI_Style[client]][bEnableBunnyhopping]);
		}

		MoveType mtMoveType = GetEntityMoveType(client);

		if(view_as<float>(gA_StyleSettings[gI_Style[client]][fGravityMultiplier]) != 1.0 &&
			(mtMoveType == MOVETYPE_WALK || mtMoveType == MOVETYPE_ISOMETRIC) &&
			(gMT_MoveType[client] == MOVETYPE_LADDER || GetEntityGravity(client) == 1.0))
		{
			SetEntityGravity(client, view_as<float>(gA_StyleSettings[gI_Style[client]][fGravityMultiplier]));
		}

		gMT_MoveType[client] = mtMoveType;
	}
}

public void OnGameFrame()
{
	float frametime = GetGameFrameTime();

	for(int i = 1; i <= MaxClients; i++)
	{
		if(gB_ClientPaused[i] || !gB_TimerEnabled[i])
		{
			continue;
		}

		float time = frametime;

		if(gA_StyleSettings[gI_Style[i]][bHalftime])
		{
			time /= 2.0;
		}

		any[] snapshot = new any[TIMERSNAPSHOT_SIZE];
		snapshot[bTimerEnabled] = gB_TimerEnabled[i];
		snapshot[bClientPaused] = gB_ClientPaused[i];
		snapshot[iJumps] = gI_Jumps[i];
		snapshot[bsStyle] = gI_Style[i];
		snapshot[iStrafes] = gI_Strafes[i];
		snapshot[iTotalMeasures] = gI_TotalMeasures[i];
		snapshot[iGoodGains] = gI_GoodGains[i];
		snapshot[fServerTime] = GetEngineTime();
		snapshot[fCurrentTime] = gF_PlayerTimer[i];
		snapshot[iSHSWCombination] = gI_SHSW_FirstCombination[i];
		snapshot[iTimerTrack] = gI_Track[i];

		Call_StartForward(gH_Forwards_OnTimerIncrement);
		Call_PushCell(i);
		Call_PushArray(snapshot, TIMERSNAPSHOT_SIZE);
		Call_PushCellRef(time);
		Call_PushArray(gA_StyleSettings[gI_Style[i]], STYLESETTINGS_SIZE);
		Call_Finish();

		gF_PlayerTimer[i] += time;

		Call_StartForward(gH_Forwards_OnTimerIncrementPost);
		Call_PushCell(i);
		Call_PushCell(time);
		Call_PushArray(gA_StyleSettings[gI_Style[i]], STYLESETTINGS_SIZE);
		Call_Finish();
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!IsPlayerAlive(client) || IsFakeClient(client))
	{
		return Plugin_Continue;
	}

	int flags = GetEntityFlags(client);

	if(gB_ClientPaused[client])
	{
		buttons = 0;
		vel = view_as<float>({0.0, 0.0, 0.0});

		SetEntityFlags(client, (flags | FL_ATCONTROLS));

		return Plugin_Changed;
	}

	SetEntityFlags(client, (flags & ~FL_ATCONTROLS));

	Action result = Plugin_Continue;
	Call_StartForward(gH_Forwards_OnUserCmdPre);
	Call_PushCell(client);
	Call_PushCellRef(buttons);
	Call_PushCellRef(impulse);
	Call_PushArrayEx(vel, 3, SM_PARAM_COPYBACK);
	Call_PushArrayEx(angles, 3, SM_PARAM_COPYBACK);
	Call_PushCell(GetTimerStatus(client));
	Call_PushCell(gI_Track[client]);
	Call_PushCell(gI_Style[client]);
	Call_PushArray(gA_StyleSettings[gI_Style[client]], STYLESETTINGS_SIZE);
	Call_PushArrayEx(mouse, 2, SM_PARAM_COPYBACK);
	Call_Finish(result);
	
	if(result != Plugin_Continue && result != Plugin_Changed)
	{
		return result;
	}

	int iGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	bool bInStart = Shavit_InsideZone(client, Zone_Start, gI_Track[client]);

	if(gB_TimerEnabled[client] && !gB_ClientPaused[client])
	{
		// +left/right block
		if(!gB_Zones || (!bInStart && ((gA_StyleSettings[gI_Style[client]][iBlockPLeft] > 0 &&
			(buttons & IN_LEFT) > 0) || (gA_StyleSettings[gI_Style[client]][iBlockPRight] > 0 && (buttons & IN_RIGHT) > 0))))
		{
			vel[0] = 0.0;
			vel[1] = 0.0;

			if(gA_StyleSettings[gI_Style[client]][iBlockPRight] >= 2)
			{
				char sCheatDetected[64];
				FormatEx(sCheatDetected, 64, "%T", "LeftRightCheat", client);
				StopTimer_Cheat(client, sCheatDetected);
			}
		}

		// +strafe block
		if(gA_StyleSettings[gI_Style[client]][iBlockPStrafe] > 0 &&
			((vel[0] > 0.0 && (buttons & IN_FORWARD) == 0) || (vel[0] < 0.0 && (buttons & IN_BACK) == 0) ||
			(vel[1] > 0.0 && (buttons & IN_MOVERIGHT) == 0) || (vel[1] < 0.0 && (buttons & IN_MOVELEFT) == 0)))
		{
			if(gF_StrafeWarning[client] < gF_PlayerTimer[client])
			{
				if(gA_StyleSettings[gI_Style[client]][iBlockPStrafe] >= 2)
				{
					char sCheatDetected[64];
					FormatEx(sCheatDetected, 64, "%T", "Inconsistencies", client);
					StopTimer_Cheat(client, sCheatDetected);
				}

				vel[0] = 0.0;
				vel[1] = 0.0;

				return Plugin_Changed;
			}

			gF_StrafeWarning[client] = gF_PlayerTimer[client] + 0.3;
		}
	}

	#if defined DEBUG
	static int cycle = 0;

	if(++cycle % 50 == 0)
	{
		Shavit_StopChatSound();
		Shavit_PrintToChat(client, "vel[0]: %.01f | vel[1]: %.01f", vel[0], vel[1]);
	}
	#endif

	MoveType mtMoveType = GetEntityMoveType(client);

	// key blocking
	if(mtMoveType != MOVETYPE_NOCLIP && mtMoveType != MOVETYPE_LADDER && !Shavit_InsideZone(client, Zone_Freestyle, -1))
	{
		// block E
		if(gA_StyleSettings[gI_Style[client]][bBlockUse] && (buttons & IN_USE) > 0)
		{
			buttons &= ~IN_USE;
		}

		if(iGroundEntity == -1)
		{
			if(gA_StyleSettings[gI_Style[client]][bBlockW] && ((buttons & IN_FORWARD) > 0 || vel[0] > 0.0))
			{
				vel[0] = 0.0;
				buttons &= ~IN_FORWARD;
			}

			if(gA_StyleSettings[gI_Style[client]][bBlockA] && ((buttons & IN_MOVELEFT) > 0 || vel[1] < 0.0))
			{
				vel[1] = 0.0;
				buttons &= ~IN_MOVELEFT;
			}

			if(gA_StyleSettings[gI_Style[client]][bBlockS] && ((buttons & IN_BACK) > 0 || vel[0] < 0.0))
			{
				vel[0] = 0.0;
				buttons &= ~IN_BACK;
			}

			if(gA_StyleSettings[gI_Style[client]][bBlockD] && ((buttons & IN_MOVERIGHT) > 0 || vel[1] > 0.0))
			{
				vel[1] = 0.0;
				buttons &= ~IN_MOVERIGHT;
			}

			// HSW
			// Theory about blocking non-HSW strafes while playing HSW:
			// Block S and W without A or D.
			// Block A and D without S or W.
			if(gA_StyleSettings[gI_Style[client]][iForceHSW] > 0)
			{
				bool bSHSW = (gA_StyleSettings[gI_Style[client]][iForceHSW] == 2) && !bInStart; // don't decide on the first valid input until out of start zone!
				int iCombination = -1;

				bool bForward = ((buttons & IN_FORWARD) > 0 && vel[0] >= 100.0);
				bool bMoveLeft = ((buttons & IN_MOVELEFT) > 0 && vel[1] <= -100.0);
				bool bBack = ((buttons & IN_BACK) > 0 && vel[0] <= -100.0);
				bool bMoveRight = ((buttons & IN_MOVERIGHT) > 0 && vel[1] >= 100.0);

				if(bSHSW)
				{
					if((bForward && bMoveLeft) || (bBack && bMoveRight))
					{
						iCombination = 0;
					}

					else if((bForward && bMoveRight || bBack && bMoveLeft))
					{
						iCombination = 1;
					}

					// int gI_SHSW_FirstCombination[MAXPLAYERS+1]; // 0 - W/A S/D | 1 - W/D S/A
					if(gI_SHSW_FirstCombination[client] == -1 && iCombination != -1)
					{
						Shavit_PrintToChat(client, "%T", (iCombination == 0)? "SHSWCombination0":"SHSWCombination1", client, gS_ChatStrings[sMessageVariable], gS_ChatStrings[sMessageText]);
						gI_SHSW_FirstCombination[client] = iCombination;
					}

					bool bStop = false;

					// W/A S/D
					if((gI_SHSW_FirstCombination[client] == 0 && iCombination != 0) ||
					// W/D S/A
						(gI_SHSW_FirstCombination[client] == 1 && iCombination != 1) ||
					// no valid combination & no valid input
						(gI_SHSW_FirstCombination[client] == -1 && iCombination == -1))
					{
						bStop = true;
					}

					if(bStop)
					{
						vel[0] = 0.0;
						vel[1] = 0.0;

						buttons &= ~IN_FORWARD;
						buttons &= ~IN_MOVELEFT;
						buttons &= ~IN_MOVERIGHT;
						buttons &= ~IN_BACK;
					}
				}

				else
				{
					if((bForward || bBack) && !(bMoveLeft || bMoveRight))
					{
						vel[0] = 0.0;

						buttons &= ~IN_FORWARD;
						buttons &= ~IN_BACK;
					}

					if((bMoveLeft || bMoveRight) && !(bForward || bBack))
					{
						vel[1] = 0.0;

						buttons &= ~IN_MOVELEFT;
						buttons &= ~IN_MOVERIGHT;
					}
				}
			}
		}
	}

	if(gA_StyleSettings[gI_Style[client]][bStrafeCountW] && !gA_StyleSettings[gI_Style[client]][bBlockW] &&
		(gI_ButtonCache[client] & IN_FORWARD) == 0 && (buttons & IN_FORWARD) > 0)
	{
		gI_Strafes[client]++;
	}

	if(gA_StyleSettings[gI_Style[client]][bStrafeCountA] && !gA_StyleSettings[gI_Style[client]][bBlockA] && (gI_ButtonCache[client] & IN_MOVELEFT) == 0 &&
		(buttons & IN_MOVELEFT) > 0 && (gA_StyleSettings[gI_Style[client]][iForceHSW] > 0 || ((buttons & IN_FORWARD) == 0 && (buttons & IN_BACK) == 0)))
	{
		gI_Strafes[client]++;
	}

	if(gA_StyleSettings[gI_Style[client]][bStrafeCountS] && !gA_StyleSettings[gI_Style[client]][bBlockS] &&
		(gI_ButtonCache[client] & IN_BACK) == 0 && (buttons & IN_BACK) > 0)
	{
		gI_Strafes[client]++;
	}

	if(gA_StyleSettings[gI_Style[client]][bStrafeCountD] && !gA_StyleSettings[gI_Style[client]][bBlockD] && (gI_ButtonCache[client] & IN_MOVERIGHT) == 0 &&
		(buttons & IN_MOVERIGHT) > 0 && (gA_StyleSettings[gI_Style[client]][iForceHSW] > 0 || ((buttons & IN_FORWARD) == 0 && (buttons & IN_BACK) == 0)))
	{
		gI_Strafes[client]++;
	}

	bool bInWater = (GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2);

	// enable duck-jumping/bhop in tf2
	if(gEV_Type == Engine_TF2 && gA_StyleSettings[gI_Style[client]][bEnableBunnyhopping] && (buttons & IN_JUMP) > 0 && iGroundEntity != -1)
	{
		float fSpeed[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fSpeed);

		fSpeed[2] = 271.0;
		SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fSpeed);
	}

	int iPButtons = buttons;

	if(gA_StyleSettings[gI_Style[client]][bAutobhop] && gB_Auto[client] && (buttons & IN_JUMP) > 0 && mtMoveType == MOVETYPE_WALK && !bInWater)
	{
		int iOldButtons = GetEntProp(client, Prop_Data, "m_nOldButtons");
		SetEntProp(client, Prop_Data, "m_nOldButtons", (iOldButtons & ~IN_JUMP));
		iPButtons &= ~IN_JUMP;
	}

	else if(gB_DoubleSteps[client] && (buttons & IN_JUMP) == 0)
	{
		iPButtons = buttons |= IN_JUMP;
	}

	// perf jump measuring
	if(!bInWater && mtMoveType == MOVETYPE_WALK && iGroundEntity != -1)
	{
		gI_GroundTicks[client]++;

		if((((gI_ButtonCache[client] & IN_JUMP) == 0 && (iPButtons & IN_JUMP) > 0) || iPButtons != buttons) &&
			1 <= gI_GroundTicks[client] <= 8)
		{
			gI_MeasuredJumps[client]++;

			if(gI_GroundTicks[client] == 1)
			{
				gI_PerfectJumps[client]++;
			}
		}
	}

	else
	{
		gI_GroundTicks[client] = 0;
	}

	if(bInStart && gB_BlockPreJump && !gA_StyleSettings[gI_Style[client]][bPrespeed] && (vel[2] > 0 || (buttons & IN_JUMP) > 0))
	{
		vel[2] = 0.0;
		buttons &= ~IN_JUMP;
	}

	// velocity limit
	if(iGroundEntity != -1 && view_as<float>(gA_StyleSettings[gI_Style[client]][fVelocityLimit] > 0.0) &&
		(!gB_Zones || !Shavit_InsideZone(client, Zone_NoVelLimit, -1)))
	{
		float fSpeed[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", fSpeed);

		float fSpeed_New = (SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0)));

		if(fSpeed_New > 0.0)
		{
			float fScale = view_as<float>(gA_StyleSettings[gI_Style[client]][fVelocityLimit]) / fSpeed_New;

			if(fScale < 1.0)
			{
				ScaleVector(fSpeed, fScale);
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fSpeed); // maybe change this to SetEntPropVector some time?
			}
		}
	}

	float fAngle = (angles[1] - gF_AngleCache[client]);

	while(fAngle > 180.0)
	{
		fAngle -= 360.0;
	}

	while(fAngle < -180.0)
	{
		fAngle += 360.0;
	}

	if(iGroundEntity == -1 && (GetEntityFlags(client) & FL_INWATER) == 0 && fAngle != 0.0)
	{
		float fAbsVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);

		if(SquareRoot(Pow(fAbsVelocity[0], 2.0) + Pow(fAbsVelocity[1], 2.0)) > 0.0)
		{
			float fTempAngle = angles[1];

			float fAngles[3];
			GetVectorAngles(fAbsVelocity, fAngles);

			if(fTempAngle < 0.0)
			{
				fTempAngle += 360.0;
			}

			float fDirectionAngle = (fTempAngle - fAngles[1]);

			if(fDirectionAngle < 0.0)
			{
				fDirectionAngle = -fDirectionAngle;
			}

			if(fDirectionAngle < 22.5 || fDirectionAngle > 337.5)
			{
				gI_TotalMeasures[client]++;

				if((fAngle > 0.0 && vel[1] <= -100.0) || (fAngle < 0.0 && vel[1] >= 100.0))
				{
					gI_GoodGains[client]++;
				}
			}

			else if((fDirectionAngle > 67.5 && fDirectionAngle < 112.5) || (fDirectionAngle > 247.5 && fDirectionAngle < 292.5))
			{
				gI_TotalMeasures[client]++;

				if(vel[0] <= -100.0 || vel[0] >= 100.0)
				{
					gI_GoodGains[client]++;
				}
			}
		}
	}

	gI_ButtonCache[client] = iPButtons;
	gF_AngleCache[client] = angles[1];

	return Plugin_Continue;
}

void StopTimer_Cheat(int client, const char[] message)
{
	Shavit_StopTimer(client);
	Shavit_PrintToChat(client, "%T", "CheatTimerStop", client, gS_ChatStrings[sMessageWarning], gS_ChatStrings[sMessageText], message);
}

void UpdateStyleSettings(int client)
{
	if(sv_autobunnyhopping != null)
	{
		sv_autobunnyhopping.ReplicateToClient(client, (gA_StyleSettings[gI_Style[client]][bAutobhop] && gB_Auto[client])? "1":"0");
	}

	if(sv_enablebunnyhopping != null)
	{
		sv_enablebunnyhopping.ReplicateToClient(client, (gA_StyleSettings[gI_Style[client]][bEnableBunnyhopping])? "1":"0");
	}

	char sAiraccelerate[8];
	FloatToString(gA_StyleSettings[gI_Style[client]][fAiraccelerate], sAiraccelerate, 8);
	sv_airaccelerate.ReplicateToClient(client, sAiraccelerate);

	SetEntityGravity(client, view_as<float>(gA_StyleSettings[gI_Style[client]][fGravityMultiplier]));
}
