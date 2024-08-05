// **********************************************************************
// *********************** I	N	T	R	O ***************************
// **********************************************************************
// ===========================================================================================================================================
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <morecolors>

#undef REQUIRE_EXTENSIONS
#include <soundlib>

#undef REQUIRE_PLUGIN
#include <clientprefs>
#tryinclude <updater>

//#define DEBUG

#define CLIENTPREFS_AVAILABLE()		(GetFeatureStatus(FeatureType_Native, "RegClientCookie") == FeatureStatus_Available)

#define PLUGIN_VERSION "CSS-ERoundMSC-v1.0.0"

#define GAME_CSTRIKE 1
#define GAME_CSGO 2
#define GAME_TF2 3
#define GAME_DOD 4
#define GAME_INSURGENCY 5
#define GAME_OTHER 6

#define UPDATE_URL	"https://github.com/vitacell/CSS-EndRoundMapSoundController"

//------------------------------------------------------------------------------------------------------------------------------------
new Handle:sm_res_enable, bool:enabled,
	Handle:sm_res_roundendannounce,	bool:endmsg,
	Handle:sm_res_roundstartannounce, bool:startmsg,
	Handle:sm_res_playerconnectannounce, bool:connectmsg,
	Handle:sm_res_mapendsound, bool:mepenable,
	Handle:sm_res_announceevery, Float:msgtime,
	Handle:sm_res_volume, Float:f_volume,
	Handle:sm_res_randomsounds,	bool:rndsnd,
	Handle:sm_res_client, bool:clientpref,
	Handle:sm_res_commonsounds,	bool:common,
	Handle:sm_res_displaysound,	bool:display,
	Handle:sm_res_debugsounds, bool:debugsounds,
	Handle:sm_res_soundslist, String:SndListPath[PLATFORM_MAX_PATH],
	Handle:sm_res_dod_blocklastcry,	bool:blockcry,
	Handle:sm_res_play_method, i_play_method,
Handle:Timer;

new Handle:g_Cvar_WinLimit,
	Handle:g_Cvar_MaxRounds;


new Handle:cookieResPref;

new bool:roundEnded,
	bool:active,
	bool:roundendhooked,
bool:roundstarthooked;
//------------------------------------------------------------------------------------------------------------------------------------

new String:s_LogFile[PLATFORM_MAX_PATH];

new Handle:array_SoundList1, Handle:array_SoundList2, Handle:array_MapEndSounds;

static String:Team1[][]   = {"T","RED","USA","TEAM1"};
static String:Team2[][]   = {"CT","BLU","GER","TEAM2"};
static String:MapEnd[][]  = {"MAPEND","MAP","END"};

new res_sound[MAXPLAYERS+1];

new Queue1, Queue2, CommonQueue, MapendQueue,
	MaxSounds1, MaxSounds2, MapendMaxSounds,
	Number,
	TF2Team,
	winner,
iGame;

new lastnumber = -1;

new g_TotalRounds;

//------------------------------------------------------------------------------------------------------------------------------------
// Colors
#define YELLOW               "\x01"
#define NAME_TEAMCOLOR       "\x02"
#define LIGHTGREEN           "\x03"
#define GREEN                "\x04"
//------------------------------------------------------------------------------------------------------------------------------------
// ===========================================================================================================================================







// ******************************************************************
// *********************** M	A	I	N ***************************
// ******************************************************************
// ===========================================================================================================================================
public Plugin:myinfo =
{
	name = "Round and Map End Sound",
	author = "FrozDark (HLModders LLC)",
	description = "Plays all sounds or sounds of the winner team in a queue or random at round end and at map end",
	version = PLUGIN_VERSION,
	url = "http://www.hlmod.ru/"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	decl String:dir[24];
	GetGameFolderName(dir, sizeof(dir));

	if (!strcmp(dir,"cstrike",false) || !strcmp(dir,"cstrike_beta",false))
	{
		iGame = GAME_CSTRIKE;
	}
	else if (!strcmp(dir,"csgo",false))
	{
		iGame = GAME_CSGO;
	}
	else if (!strcmp(dir,"dod",false))
	{
		iGame = GAME_DOD;
	}
	else if (!strcmp(dir,"tf",false) || !strcmp(dir,"tf_beta",false))
	{
		iGame = GAME_TF2;
	}
	else if (!strcmp(dir,"insurgency",false))
	{
		iGame = GAME_INSURGENCY;
	}
	else
	{
		iGame = GAME_OTHER;
	}

	MarkNativeAsOptional("OpenSoundFile");
	MarkNativeAsOptional("GetSoundArtist");
	MarkNativeAsOptional("GetSoundTitle");
}

public OnPluginStart()
{
	CreateConVar("sm_res_version", PLUGIN_VERSION, "The Round and Map End Sound version", 0|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_CHEAT|FCVAR_DONTRECORD);

	sm_res_enable 				 = CreateConVar("sm_res_enable",				 "1", "Enables/disables the plugin", 0, true, 0.0, true, 1.0);
	sm_res_roundendannounce	 	 = CreateConVar("sm_res_roundendannounce",		 "0", "Announcement at every round end", 0, true, 0.0, true, 1.0);
	sm_res_roundstartannounce 	 = CreateConVar("sm_res_roundstartannounce",	 "0", "Announcement at every round start", 0, true, 0.0, true, 1.0);
	sm_res_playerconnectannounce = CreateConVar("sm_res_playerconnectannounce",	 "1", "Announcement to a player in 20 sec. after his connecting", 0, true, 0.0, true, 1.0);
	sm_res_announceevery 		 = CreateConVar("sm_res_announceevery",			 "120", "Announcement repeater in seconds. 0=Disable", 0, true, 0.0);
	sm_res_mapendsound 			 = CreateConVar("sm_res_mapendsound",			 "1", "Enables/disables in-built map end sound", 0, true, 0.0, true, 1.0);
	sm_res_client				 = CreateConVar("sm_res_client",				 "1", "If enabled, clients will be able to modify their ability to hear sounds. 0=Disable", 0, true, 0.0, true, 1.0);
	sm_res_randomsounds			 = CreateConVar("sm_res_randomsounds",			 "0", "If enabled, the sounds will be played randomly. If disabled the sounds will be played in a queue", 0, true, 0.0, true, 1.0);
	sm_res_commonsounds			 = CreateConVar("sm_res_commonsounds",			 "0", "If enabled, all sounds will be played commonly in spite of the winner team", 0, true, 0.0, true, 1.0);
	sm_res_volume				 = CreateConVar("sm_res_volume",			 	 "1.0", "The sounds volume", 0, true, 0.0, true, 1.0);
	sm_res_debugsounds			 = CreateConVar("sm_res_debugsounds",			 "0", "Enables/disables debug mode", 0, true, 0.0, true, 1.0);
	sm_res_soundslist			 = CreateConVar("sm_res_soundslist",			 "addons/sourcemod/configs/res_list.cfg", "Path to the sound list", 0);
	sm_res_play_method			 = CreateConVar("sm_res_play_method",			 "0", "What method to use to play sounds? 0 - EmitSound (volume support) | 1 - Client command \"play\" (Max. no sm_res_volume support)", 0, true, 0.0, true, 1.0);
	sm_res_displaysound			 = CreateConVar("sm_res_displaysound",			 "1", "Shows in the chat sound info. Artist and title of the sound", 0, true, 0.0, true, 1.0);

	switch (iGame)
	{
		case GAME_DOD :
		{
			sm_res_dod_blocklastcry		 = CreateConVar("sm_res_dod_blocklastcry",		 "1", "Blocks last capture point cry", 0, true, 0.0, true, 1.0);
			blockcry	 = GetConVarBool(sm_res_dod_blocklastcry);
			HookConVarChange(sm_res_dod_blocklastcry,		ConVarChanges);

			AddTempEntHook("FireBullets", DODS_Hook_FireBullets);
		}
		case GAME_CSTRIKE, GAME_CSGO :
		{
			AddTempEntHook("Shotgun Shot", CSS_Hook_ShotgunShot);
		}
		case GAME_INSURGENCY :
		{
			HookEvent("game_newmap", Event_GameStart);
		}
		default :
		{
			HookEvent("game_start", Event_GameStart);
		}
	}

	LoadTranslations("common.phrases");
	LoadTranslations("res.phrases");

	array_SoundList1 = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	array_SoundList2 = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	array_MapEndSounds = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));

	decl String:cTime[64];
	FormatTime(cTime, sizeof(cTime), "logs/res_%Y.%m.%d.log");
	BuildPath(Path_SM, s_LogFile, sizeof(s_LogFile), cTime);

	enabled		 = GetConVarBool(sm_res_enable);
	endmsg		 = GetConVarBool(sm_res_roundendannounce);
	startmsg	 = GetConVarBool(sm_res_roundstartannounce);
	connectmsg	 = GetConVarBool(sm_res_playerconnectannounce);
	mepenable	 = GetConVarBool(sm_res_mapendsound);
	rndsnd		 = GetConVarBool(sm_res_randomsounds);
	clientpref	 = GetConVarBool(sm_res_client);
	common		 = GetConVarBool(sm_res_commonsounds);
	debugsounds	 = GetConVarBool(sm_res_debugsounds);
	display		 = GetConVarBool(sm_res_displaysound);
	msgtime		 = GetConVarFloat(sm_res_announceevery);
	f_volume	 = GetConVarFloat(sm_res_volume);
	i_play_method = GetConVarInt(sm_res_play_method);
	GetConVarString(sm_res_soundslist, SndListPath, sizeof(SndListPath));

	HookConVarChange(sm_res_enable,					ConVarChange_sm_res_enable);
	HookConVarChange(sm_res_client,			  		ConVarChange_sm_res_client);
	HookConVarChange(sm_res_announceevery,		    ConVarChange_Timer);
	HookConVarChange(sm_res_roundendannounce,	    ConVarChanges);
	HookConVarChange(sm_res_roundstartannounce,	    ConVarChanges);
	HookConVarChange(sm_res_playerconnectannounce,  ConVarChanges);
	HookConVarChange(sm_res_mapendsound, 	   		ConVarChanges);
	HookConVarChange(sm_res_randomsounds, 	   		ConVarChanges);
	HookConVarChange(sm_res_commonsounds, 	  		ConVarChanges);
	HookConVarChange(sm_res_volume,		   			ConVarChanges);
	HookConVarChange(sm_res_debugsounds, 		    ConVarChanges);
	HookConVarChange(sm_res_soundslist,	  			ConVarChanges);
	HookConVarChange(sm_res_play_method,			ConVarChanges);
	HookConVarChange(sm_res_displaysound,			ConVarChanges);

	RegConsoleCmd("sm_res", ResCmd, "On/Off Round End Sounds");
	RegAdminCmd("sm_reloadsoundslist", ResReload, ADMFLAG_ROOT, "Reloads sound list");

	g_Cvar_WinLimit = FindConVar("mp_winlimit");
	g_Cvar_MaxRounds = FindConVar("mp_maxrounds");

	HookEventEx("teamplay_win_panel", Event_TeamPlayWinPanel);
	HookEventEx("teamplay_restart_round", Event_TFRestartRound);
	HookEventEx("arena_win_panel", Event_TeamPlayWinPanel);

	AddNormalSoundHook(NormalSHook);

	AutoExecConfig(true, "res");

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
}

#if defined _updater_included
public OnAllPluginsLoaded()
{
    if (LibraryExists("updater"))
	{
        Updater_AddPlugin(UPDATE_URL);
	}
}

public OnLibraryAdded(const String:name[])
{
    if (!strcmp(name, "updater"))
	{
        Updater_AddPlugin(UPDATE_URL);
	}
}

public Updater_OnPluginUpdated()
{
	ReloadPlugin();
}
#endif

public OnMapStart()
{
	g_TotalRounds = 0;
}

public OnMapEnd()
{
	if (active)
	{
		DiactivatePlugin();
	}
}
// ===========================================================================================================================================







// ******************************************************************************
// *********************** C	O	N	F	I	G	S ***************************
// ******************************************************************************
// ===========================================================================================================================================

public OnConfigsExecuted()
{
	new Handle:RRD = FindConVar("mp_round_restart_delay");
	if (RRD != INVALID_HANDLE)
	{
		SetConVarBounds(RRD, ConVarBound_Upper, false, 10.0);
	}

	if (clientpref && cookieResPref == INVALID_HANDLE && CLIENTPREFS_AVAILABLE())
	{
		cookieResPref = RegClientCookie("Round End Sound", "Round End Sound", CookieAccess_Private);
		SetCookieMenuItem(ResPrefSelected, 0, "Round End Sound");
	}

	if (enabled)
	{
		if (msgtime > 0.0)
		{
			Timer = CreateTimer(msgtime, AnnounceRepeater, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
		if (!active)
		{
			ActivatePlugin();
		}

		LoadSounds();
	}
}
// ===========================================================================================================================================







// *******************************************************************************************************************************
// *********************** C	L	I	E	N	T		P	R	E	F	E	R	E	N	C	E ************************************
// *******************************************************************************************************************************
// ===========================================================================================================================================
public OnClientPutInServer(client)
{
	if (!IsFakeClient(client))
	{
		if (CLIENTPREFS_AVAILABLE())
		{
			loadClientCookiesFor(client);
		}

		if (connectmsg && enabled)
		{
			CreateTimer(20.0, TimerAnnounce, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public OnClientCookiesCached(client)
{
	if (IsClientInGame(client) && !IsFakeClient(client))
	{
		loadClientCookiesFor(client);
	}
}

loadClientCookiesFor(client)
{
	if (!clientpref || cookieResPref == INVALID_HANDLE || !AreClientCookiesCached(client))
	{
		res_sound[client] = 1;
		return;
	}

	decl String:buffer[5];
	GetClientCookie(client, cookieResPref, buffer, sizeof(buffer));

	if (buffer[0])
	{
		res_sound[client] = StringToInt(buffer);
	}
	else
	{
		res_sound[client] = 1;
	}
}

public ResPrefSelected(client, CookieMenuAction:action, any:info, String:buffer[], maxlen)
{
	if (!clientpref || !enabled || !CLIENTPREFS_AVAILABLE())
	{
		return;
	}

	switch (action)
	{
		case CookieMenuAction_DisplayOption :
		{
			decl String:status[10];
			FormatEx(status, sizeof(status), "%T", res_sound[client] ? "On" : "Off", client);
			FormatEx(buffer, maxlen, "%T: %s", "Cookie Round End Sound", client, status);
		}
		case CookieMenuAction_SelectOption :
		{
			switch (res_sound[client])
			{
				case 0 :
				{
					res_sound[client] = 1;
				}
				default :
				{
					res_sound[client] = 0;
				}
			}
			ShowCookieMenu(client);
		}
	}
}

public Action:ResCmd(client, args)
{
	if (!client || !enabled || !clientpref)
	{
		return Plugin_Continue;
	}

	switch (res_sound[client])
	{
		case 0 :
		{
			res_sound[client] = 1;
			PrintToChat(client, "\x07FF0000* %t", "Res On");
		}
		default :
		{
			res_sound[client] = 0;
			PrintToChat(client, "\x07FF0000* %t", "Res Off");
		}
	}

	if (CLIENTPREFS_AVAILABLE())
	{
		decl String:buffer[5];

		IntToString(res_sound[client], buffer, sizeof(buffer));
		SetClientCookie(client, cookieResPref, buffer);
	}

	return Plugin_Handled;
}
// ===========================================================================================================================================







// **************************************************************************************************************
// *********************** S	O	U	N	D		N	A	T	I	V	E	S ***********************************
// **************************************************************************************************************
// ===========================================================================================================================================
bool:IsSoundFile(const String:Sound[])
{
	decl String:buf[4];
	GetExtension(Sound, buf, sizeof(buf));
	if (!strcmp(buf, "mp3", false) || !strcmp(buf, "wav", false))
	{
		return true;
	}

	return false;
}

PlaySound(team, const String:sound[])
{
	decl newClients[MaxClients];
	new totalClients = 0;
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && !res_sound[client])
		{
			if (team)
			{
				if (GetClientTeam(client) == team)
				{
					newClients[totalClients++] = client;
				}
			}
			else
			{
				newClients[totalClients++] = client;
			}
		}
	}
	if (totalClients)
	{
		EmitSound(newClients, totalClients, sound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_GUNFIRE);
	}
}

bool:CheckMapEnd()
{
	new bool:lastround = false;
	new bool:notimelimit = false;
	new timeleft;

	if (GetMapTimeLeft(timeleft))
	{
		new timelimit;

		if (timeleft > 0)
		{
			return false;
		}
		else if (GetMapTimeLimit(timelimit) && !timelimit)
		{
			notimelimit = true;
		}
		else
		{
			lastround = true;
		}
	}

	if (!lastround)
	{
		if (g_Cvar_WinLimit != INVALID_HANDLE)
		{
			new winlimit = GetConVarInt(g_Cvar_WinLimit);

			if (winlimit > 0)
			{
				if (GetTeamScore(2) >= winlimit || GetTeamScore(3) >= winlimit)
				{
					lastround = true;
				}
			}
		}

		if (g_Cvar_MaxRounds != INVALID_HANDLE)
		{
			new maxrounds = GetConVarInt(g_Cvar_MaxRounds);

			if (maxrounds > 0)
			{
				new remaining = maxrounds - g_TotalRounds;

				if (!remaining)
				{
					lastround = true;
				}
			}
		}
	}

	if (lastround)
	{
		return true;
	}

	else if (notimelimit)
	{
		return false;
	}

	return true;
}

LoadSounds()
{
	decl String:Line[PLATFORM_MAX_PATH+5];

	new Handle:filehandle = OpenFile(SndListPath, "r");

	if (filehandle == INVALID_HANDLE)
	{
		ThrowError("%s not parsed... file doesn't exist!", SndListPath);
	}

	RemoveAndResetSounds();

	while (!IsEndOfFile(filehandle)) // while not end of file
	{
		if (!ReadFileLine(filehandle, Line, sizeof(Line)))
		{
			continue;
		}

		new pos;
		pos = StrContains((Line), "//");
		if (pos != -1)
		{
			Line[pos] = '\0';
		}

		pos = StrContains((Line), "#");
		if (pos != -1)
		{
			Line[pos] = '\0';
		}

		pos = StrContains((Line), ";");
		if (pos != -1)
		{
			Line[pos] = '\0';
		}

		TrimString(Line);

		if (Line[0] == '\0')
		{
			continue;
		}

		#if defined DEBUG
		LogMessage("Parsing line: %s", Line);
		#endif

		ParseLine(Line);
	}

	CloseHandle(filehandle);

	MaxSounds1 = GetArraySize(array_SoundList1);
	MaxSounds2 = GetArraySize(array_SoundList2);
	MapendMaxSounds = GetArraySize(array_MapEndSounds);

	PrepareSounds();
}

enum iSoundMode
{
	iSoundMode_All = 0,
	iSoundMode_Both,
	iSoundMode_Team1,
	iSoundMode_Team2,
	iSoundMode_MapEnd
}

new iSoundMode:soundMode = iSoundMode_Both;

ParseLine(const String:line[])
{
	decl String:path[PLATFORM_MAX_PATH];

	if (FindCharInString(line, '=', true) != -1)
	{
		#if defined DEBUG
		LogMessage("Found char \"=\"", line);
		#endif

		decl String:Text[2][PLATFORM_MAX_PATH];
		ExplodeString(line, "=", Text, sizeof(Text), sizeof(Text[]));

		#if defined DEBUG
		LogMessage("Exploding to %s and %s", Text[0], Text[1]);
		#endif

		if (!strcmp(Text[1], "ALL", false))
		{
			soundMode = iSoundMode_All;

			#if defined DEBUG
			LogMessage("Sound mode \"all\" detected");
			#endif
		}
		if (!strcmp(Text[1], "BOTH", false) || !Text[1][0])
		{
			soundMode = iSoundMode_Both;

			#if defined DEBUG
			LogMessage("Sound mode \"both\" detected");
			#endif
		}
		for (new t = 0; t < sizeof(Team1); t++)
		{
			if (!strcmp(Text[1], Team1[t], false))
			{
				soundMode = iSoundMode_Team1;

				#if defined DEBUG
				LogMessage("Sound mode \"%s\" detected", Team1[t]);
				#endif

				break;
			}
		}
		for (new t = 0; t < sizeof(Team2); t++)
		{
			if (!strcmp(Text[1], Team2[t], false))
			{
				soundMode = iSoundMode_Team2;

				#if defined DEBUG
				LogMessage("Sound mode \"%s\" detected", Team2[t]);
				#endif

				break;
			}
		}
		for (new t = 0; t < sizeof(MapEnd); t++)
		{
			if (!strcmp(Text[1], MapEnd[t], false))
			{
				soundMode = iSoundMode_MapEnd;

				#if defined DEBUG
				LogMessage("Sound mode \"mapend\" detected");
				#endif

				break;
			}
		}

		strcopy(path, sizeof(path), Text[0]);
	}
	else
	{
		strcopy(path, sizeof(path), line);
	}

	new index = 0;
	while (path[index] == '/' || path[index] == '\\')
	{
		index++;
	}

	if (index != 0)
	{
		strcopy(path, sizeof(path), path[index]);
	}

	if (FindCharInString(path, '.', true) != -1)
	{
		decl String:subject[PLATFORM_MAX_PATH];
		FormatEx(subject, sizeof(subject), "sound/%s", path);

		if (!IsSoundFile(subject))
		{
			LogToFile(s_LogFile, "Error: Invalid extension in the sound - %s", subject);
			LogToFile(s_LogFile, "Error: The extension should be only \".mp3\" or \".wav\"");

			return;
		}
		else if (!FileExists(subject))
		{
			LogToFile(s_LogFile, "Error: Sound %s not found, file doesn't exist!", subject);

			return;
		}
	}
	else for ( ; ; )
	{
		new tok = strlen(path)-1;
		if (path[tok] == '/' || path[tok] == '\\')
		{
			path[tok] = '\0';
			continue;
		}

		break;
	}

	#if defined DEBUG
	LogMessage("Parsing path: %s", path);
	#endif

	ParsePath(path);
}

ParsePath(const String:path[])
{
	decl String:dirEntry[PLATFORM_MAX_PATH];
	FormatEx(dirEntry, sizeof(dirEntry), "sound/%s", path);

	if (DirExists(dirEntry))
	{
		#if defined DEBUG
		LogMessage("Path %s is a directory", path);
		#endif

		new Handle:__dir = OpenDirectory(dirEntry);

		while (ReadDirEntry(__dir, dirEntry, sizeof(dirEntry)))
		{
			if (StrEqual(dirEntry, ".") || StrEqual(dirEntry, ".."))
			{
				continue;
			}

			#if defined DEBUG
			LogMessage("Retrieving file %s", dirEntry);
			#endif

			Format(dirEntry, sizeof(dirEntry), "%s/%s", path, dirEntry);

			#if defined DEBUG
			LogMessage("Parsing new path: %s", dirEntry);
			#endif

			ParsePath(dirEntry);
		}

		CloseHandle(__dir);

		return;
	}
	if (IsSoundFile(path))
	{
		decl String:sound[PLATFORM_MAX_PATH];
		strcopy(sound, sizeof(sound), path);

		new start = 0;
		if (iGame == GAME_CSGO)
		{
			FormatEx(sound, sizeof(sound), "*%s", path);
			start = 1;
		}

		switch (soundMode)
		{
			case iSoundMode_All :
			{
				if (FindStringInArray(array_SoundList1, sound) == -1)
				{
					PushArrayString(array_SoundList1, sound);
				}
				if (FindStringInArray(array_SoundList2, sound) == -1)
				{
					PushArrayString(array_SoundList2, sound);
				}
				if (FindStringInArray(array_MapEndSounds, sound) == -1)
				{
					PushArrayString(array_MapEndSounds, sound);
				}

				if (debugsounds)
				{
					LogToFile(s_LogFile, "Sound loaded for all events - %s", sound[start]);
				}
			}
			case iSoundMode_Both :
			{
				if (FindStringInArray(array_SoundList1, sound) == -1)
				{
					PushArrayString(array_SoundList1, sound);
				}
				if (FindStringInArray(array_SoundList2, sound) == -1)
				{
					PushArrayString(array_SoundList2, sound);
				}

				if (debugsounds)
				{
					LogToFile(s_LogFile, "Sound loaded - %s", sound[start]);
				}
			}
			case iSoundMode_Team1 :
			{
				if (FindStringInArray(array_SoundList1, sound) == -1)
				{
					PushArrayString(array_SoundList1, sound);
				}
				else if (debugsounds)
				{
					LogToFile(s_LogFile, "Sound %s already loaded for team 1", sound[start]);
					return;
				}

				if (debugsounds)
				{
					LogToFile(s_LogFile, "Sound loaded - %s", sound[start]);
				}
			}
			case iSoundMode_Team2 :
			{
				if (FindStringInArray(array_SoundList2, sound) == -1)
				{
					PushArrayString(array_SoundList2, sound);
				}
				else if (debugsounds)
				{
					LogToFile(s_LogFile, "Sound %s already loaded for team 2", sound[start]);
					return;
				}

				if (debugsounds)
				{
					LogToFile(s_LogFile, "Sound loaded - %s", sound[start]);
				}
			}
			case iSoundMode_MapEnd :
			{
				if (FindStringInArray(array_MapEndSounds, sound) == -1)
				{
					PushArrayString(array_MapEndSounds, sound);
				}
				else if (debugsounds)
				{
					LogToFile(s_LogFile, "Sound %s already loaded for MapEnd");
					return;
				}

				if (debugsounds)
				{
					LogToFile(s_LogFile, "MapEndSound loaded - %s", sound[start]);
				}
			}
		}
	}
}

PrepareSounds()
{
	decl String:sound[PLATFORM_MAX_PATH], i;

	for (i = 0; i < MaxSounds1; i++)
	{
		GetArrayString(array_SoundList1, i, sound, sizeof(sound));
		PrepareSound(sound);
	}

	for (i = 0; i < MaxSounds2; i++)
	{
		GetArrayString(array_SoundList2, i, sound, sizeof(sound));
		PrepareSound(sound);
	}

	for (i = 0; i < MapendMaxSounds; i++)
	{
		GetArrayString(array_MapEndSounds, i, sound, sizeof(sound));
		PrepareSound(sound);
	}

	if (MapendMaxSounds)
	{
		LogToFile(s_LogFile, "General %d MapEndSounds loaded", MapendMaxSounds);
	}

	new sounds = MaxSounds1+MaxSounds2;

	if (sounds)
	{
		if (!debugsounds)
		{
			return;
		}
		LogToFile(s_LogFile, "General %d RoundEndSounds loaded", sounds);
		switch (iGame)
		{
			case GAME_CSTRIKE, GAME_CSGO :
			{
				LogToFile(s_LogFile, "%d of them loaded for Terrorist team", MaxSounds1);
				LogToFile(s_LogFile, "And %d loaded for Counter-Terrorist team", MaxSounds2);
			}
			case GAME_TF2 :
			{
				LogToFile(s_LogFile, "%d of them loaded for Red team", MaxSounds1);
				LogToFile(s_LogFile, "And %d loaded for Blue team", MaxSounds2);
			}
			case GAME_DOD :
			{
				LogToFile(s_LogFile, "%d of them loaded for USA team", MaxSounds1);
				LogToFile(s_LogFile, "And %d loaded for German team", MaxSounds2);
			}
			default :
			{
				LogToFile(s_LogFile, "%d of them loaded for team 1", MaxSounds1);
				LogToFile(s_LogFile, "And %d loaded for team 2", MaxSounds2);
			}
		}
	}
	else if (MapendMaxSounds)
	{
		LogToFile(s_LogFile, "No RoundEndSounds found in the sounds list");
	}
	else
	{
		LogToFile(s_LogFile, "Error: Neither RoundEndSounds nor MapEndSounds found in the sounds list. Diactivating...");

		if (active)
		{
			DiactivatePlugin();
		}
	}
}

PrepareSound(const String:Sound[])
{
	if (!IsSoundFile(Sound))
	{
		return;
	}
	new start = 0;
	switch (iGame)
	{
		case GAME_CSGO :
		{
			FakePrecacheSound(Sound);
			start = 1;
		}
		default :
		{
			PrecacheSound(Sound, true);
		}
	}
	if (debugsounds)
	{
		LogToFile(s_LogFile, "Sound precached - %s", Sound[start]);
	}

	decl String:ResFile[PLATFORM_MAX_PATH];
	FormatEx(ResFile, sizeof(ResFile), "sound/%s", Sound[start]);
	AddFileToDownloadsTable(ResFile);
	if (debugsounds)
	{
		LogToFile(s_LogFile, "Added to downloads - %s", ResFile);
	}
}

public Action:ResReload(client, args)
{
	LoadSounds();

	Queue1=0;
	Queue2=0;

	CommonQueue=0;
	MapendQueue=0;

	LogToFile(s_LogFile, "The soundslist was reseted and reloaded");

	return Plugin_Handled;
}

RemoveAndResetSounds()
{
	decl String:ResFile[PLATFORM_MAX_PATH];

	new start = 0;
	if (iGame == GAME_CSGO)
	{
		start = 1;
	}
	for (new i = 0; i < MaxSounds1; i++)
	{
		GetArrayString(array_SoundList1, i, ResFile, sizeof(ResFile));
		Format(ResFile, sizeof(ResFile), "sound/%s", ResFile[start]);
		RemoveFileFromDownloadsTable(ResFile);
	}
	for (new i = 0; i < MaxSounds2; i++)
	{
		GetArrayString(array_SoundList2, i, ResFile, sizeof(ResFile));
		Format(ResFile, sizeof(ResFile), "sound/%s", ResFile[start]);
		RemoveFileFromDownloadsTable(ResFile);
	}
	for (new i = 0; i < MapendMaxSounds; i++)
	{
		GetArrayString(array_MapEndSounds, i, ResFile, sizeof(ResFile));
		Format(ResFile, sizeof(ResFile), "sound/%s", ResFile[start]);
		RemoveFileFromDownloadsTable(ResFile);
	}

	ClearArray(array_SoundList1);
	ClearArray(array_SoundList2);
	ClearArray(array_MapEndSounds);

	MaxSounds1=0;
	MaxSounds2=0;

	MapendMaxSounds=0;
}

TriggerSound(bool:RoundEndSound, const String:sound[])
{
	decl newClients[MaxClients];
	new totalClients = 0;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && res_sound[i] == 1)
		{
			switch (iGame)
			{
				case GAME_CSTRIKE :
				{
					switch (winner)
					{
						case 2 : StopSound(i, SNDCHAN_STATIC, "radio/terwin.wav");
						case 3 : StopSound(i, SNDCHAN_STATIC, "radio/ctwin.wav");
					}
				}
				case GAME_CSGO :
				{
					ClientCommand(i, "playgamesound Music.StopAllMusic");
				}
			}

			if (i_play_method == 1)
			{
				PlayClientSound(i, sound);
			}
			newClients[totalClients++] = i;
		}
	}
	if (totalClients && i_play_method != 1)
	{
		EmitSound(newClients, totalClients, sound, SOUND_FROM_PLAYER, SNDCHAN_STREAM, SNDLEVEL_GUNFIRE, SND_CHANGEVOL|SND_SHOULDPAUSE, f_volume);
	}
	if (debugsounds)
	{
		WriteLogs(RoundEndSound, sound);
	}

	if (display)
	{
		if (GetFeatureStatus(FeatureType_Native, "OpenSoundFile") == FeatureStatus_Available)
		{
			new Handle:file = OpenSoundFile(sound, true);
			if (file != INVALID_HANDLE)
			{
				decl String:artist[32], String:title[64];
				artist[0] = '\0';
				title[0] = '\0';
				GetSoundArtist(file, artist, sizeof(artist));
				GetSoundTitle(file, title, sizeof(title));

				if (artist[0] || title[0])
				{
					CPrintToChatAll("%t", "Current sound", artist, title);
				}
				else
				{
					CPrintToChatAll("%t", "Current sound path", sound);
				}
				CloseHandle(file);
			}
		}
		else
		{
			CPrintToChatAll("%t", "Current sound path", sound);
		}
	}
}

public Action:NormalSHook(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	if (roundEnded)
	{
		new totalClients = 0;
		for (new i = 0; i < numClients; i++)
		{
			if (res_sound[clients[i]]) continue;
			clients[totalClients++] = clients[i];
		}
		numClients = totalClients;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action:CSS_Hook_ShotgunShot(const String:te_name[], const Players[], numClients, Float:delay)
{
	if (!roundEnded)
	{
		return Plugin_Continue;
	}

	decl newClients[MaxClients], client, i;
	new newTotal = 0;

	for (i = 0; i < numClients; i++)
	{
		client = Players[i];

		if (!res_sound[client])
		{
			newClients[newTotal++] = client;
		}
	}

	if (newTotal == numClients)
	{
		return Plugin_Continue;
	}

	else if (newTotal == 0)
	{
		return Plugin_Stop;
	}

	decl Float:vTemp[3];
	TE_Start("Shotgun Shot");
	TE_ReadVector("m_vecOrigin", vTemp);
	TE_WriteVector("m_vecOrigin", vTemp);
	TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
	TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
	TE_WriteNum("m_iWeaponID", TE_ReadNum("m_iWeaponID"));
	TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
	TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
	TE_WriteNum("m_iPlayer", TE_ReadNum("m_iPlayer"));
	TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
	TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));
	TE_Send(newClients, newTotal, delay);

	return Plugin_Stop;
}

public Action:DODS_Hook_FireBullets(const String:te_name[], const Players[], numClients, Float:delay)
{
	if (!roundEnded)
	{
		return Plugin_Continue;
	}

	decl newClients[MaxClients], client, i;
	new newTotal = 0;

	for (i = 0; i < numClients; i++)
	{
		client = Players[i];

		if (!res_sound[client])
		{
			newClients[newTotal++] = client;
		}
	}

	if (newTotal == numClients)
	{
		return Plugin_Continue;
	}

	else if (newTotal == 0)
	{
		return Plugin_Stop;
	}

	decl Float:vTemp[3];
	TE_Start("FireBullets");
	TE_ReadVector("m_vecOrigin", vTemp);
	TE_WriteVector("m_vecOrigin", vTemp);
	TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
	TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
	TE_WriteNum("m_iWeaponID", TE_ReadNum("m_iWeaponID"));
	TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
	TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
	TE_WriteNum("m_iPlayer", TE_ReadNum("m_iPlayer"));
	TE_WriteFloat("m_flSpread", TE_ReadFloat("m_flSpread"));
	TE_Send(newClients, newTotal, delay);

	return Plugin_Stop;
}

WriteLogs(bool:RoundEndLog, const String:sound[])
{
	if (RoundEndLog)
	{
		if (!common)
		{
			LogToFile(s_LogFile, "Playing team%d sound N%d - %s", winner == 2 ? 1 : 2, Number+1, sound);
		}
		else
		{
			LogToFile(s_LogFile, "Playing sound N%d - %s", Number+1, sound);
		}
	}
	else
	{
		LogToFile(s_LogFile, "Playing MapEnd sound N%d - %s", Number+1, sound);
	}
}
// ===========================================================================================================================================







// **************************************************************************
// *********************** E	V	E	N	T	S ***************************
// **************************************************************************
// ===========================================================================================================================================

/* Round count tracking */
public Event_TFRestartRound(Handle:event, const String:name[], bool:dontBroadcast)
{
	/* Game got restarted - reset our round count tracking */
	g_TotalRounds = 0;
}

public Event_GameStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	/* Game got restarted - reset our round count tracking */
	g_TotalRounds = 0;
}

public Event_TeamPlayWinPanel(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetEventInt(event, "round_complete") == 1 || StrEqual(name, "arena_win_panel"))
	{
		g_TotalRounds++;
	}
}

public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	roundEnded = false;
	if (enabled)
	{
		if (startmsg && clientpref && (MaxSounds1+MaxSounds2))
		{
			PrintToChatAll("\x07FF0000* %t", "Announce Message", YELLOW, GREEN, YELLOW, GREEN);
		}
	}
}

public OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_TotalRounds++;

	if (!enabled)
	{
		return;
	}

	decl String:sound[PLATFORM_MAX_PATH];

	if (mepenable && MapendMaxSounds && CheckMapEnd()) // if this roundend is the last, so if it's a mapend
	{
		// MapendMaxSounds is the amount of sountracks we have
		//MapendMaxSounds = GetArraySize(array_MapEndSounds); // will be 1 if we have only 1 track

		// Here in MapendQueue if we have only 1 soundtrack, it will be at position 0 (MapendQueue is index)
		// Here is when we have error in console "[SM] Exception reported: Invalid index 15 (count: 12)"
		// if we have 12 soundtracks, index (MapendQueue) shouldn't be more than 11, the 11 sountrack is the last
		if (MapendQueue >= MapendMaxSounds) // reset if counter equals or goes above than amount soundtracks we have for MapEnd
		{
			MapendQueue = 0; // if we already played latest sountrack from the list, start again at sountrack 0
		}

		Number = MapendQueue;

		GetArrayString(array_MapEndSounds, Number, sound, sizeof(sound)); // ERROR

		// MapendQueue is a counter for index of array with out sountracks, first run it equals to 0,
		// the second sountrack will be number 1 of the the index
		MapendQueue = MapendQueue + 1; // increase index

		// to make it random
		//Number = Math_GetRandomInt(0, MapendMaxSounds - 1);
		//GetArrayString(array_SoundList1, Number, sound, sizeof(sound));

		TriggerSound(false, sound);

		//if (MapendQueue > MapendMaxSounds) // reset if counter goes above than amount sound we have for MapEnd
		//{
		//	MapendQueue = 0;
		//}

		return;
	}

	switch (iGame)
	{
		case GAME_TF2, GAME_DOD :
		{
			winner = GetEventInt(event, "team");
		}
		/*case GAME_CSTRIKE, GAME_CSGO, GAME_OTHER :
		{
			winner = GetEventInt(event, "winner");
		}*/
		default :
		{
			winner = GetEventInt(event, "winner");
		}
	}

	if (winner < 2)
	{
		return;
	}

	if (rndsnd)
	{
		if (!common)
		{
			switch (winner)
			{
				case 2 :
				{
					Number = Math_GetRandomInt(0, MaxSounds1-1);
					GetArrayString(array_SoundList1, Number, sound, sizeof(sound));
				}
				case 3 :
				{
					Number = Math_GetRandomInt(0, MaxSounds2-1);
					GetArrayString(array_SoundList2, Number, sound, sizeof(sound));
				}
			}
		}
		else
		{
			new i = Math_GetRandomInt(0, MaxSounds1+MaxSounds2-2);
			if (i >= MaxSounds1)
			{
				i = i - MaxSounds1;
				GetArrayString(array_SoundList2, i, sound, sizeof(sound));
				Number = i + MaxSounds1;
			}
			else
			{
				GetArrayString(array_SoundList1, i, sound, sizeof(sound));
				Number = i;
			}
		}
	}

	else
	{
		if (Queue1 >= MaxSounds1)
		{
			Queue1 = 0;
		}
		if (Queue2 >= MaxSounds2)
		{
			Queue2 = 0;
		}
		if (CommonQueue >= MaxSounds1+MaxSounds2)
		{
			CommonQueue = 0;
		}

		if (!common)
		{
			switch (winner)
			{
				case 2 :
				{
					Number = Queue1++;
					GetArrayString(array_SoundList1, Number, sound, sizeof(sound));
				}
				case 3 :
				{
					Number = Queue2++;
					GetArrayString(array_SoundList2, Number, sound, sizeof(sound));
				}
			}
		}
		else
		{
			new i = CommonQueue++;
			if (i >= MaxSounds1)
			{
				i = i - MaxSounds1;
				GetArrayString(array_SoundList2, i, sound, sizeof(sound));
				Number = i + MaxSounds1;
			}
			else
			{
				GetArrayString(array_SoundList1, i, sound, sizeof(sound));
				Number = i;
			}
		}
	}
	if (MaxSounds1+MaxSounds2 > 0)
	{
		TriggerSound(true, sound);
		if (endmsg && clientpref)
		{
			PrintToChatAll("\x07FF0000* %t", "Announce Message", YELLOW, GREEN, YELLOW, GREEN);
		}
	}

	roundEnded = true;
}

public Action:OnBroadCast(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (enabled && (MaxSounds1+MaxSounds2))
	{
		decl String:sound[20];
		GetEventString(event, "sound", sound, sizeof(sound));
		if (iGame == GAME_TF2)
		{
			TF2Team = GetEventInt(event, "team");
		}

		if(!strcmp(sound, "Game.GermanWin", false))
		{
			PlaySound(TF2Team, "ambient/german_win.mp3");
			return Plugin_Handled;
		}
		else if(!strcmp(sound, "Game.USWin", false))
		{
			PlaySound(TF2Team, "ambient/us_win.mp3");
			return Plugin_Handled;
		}
		else if(!strcmp(sound, "Game.Stalemate", false))
		{
			PlaySound(TF2Team, "misc/your_team_stalemate.wav");
			return Plugin_Handled;
		}
		else if(!strcmp(sound, "Game.YourTeamWon", false))
		{
			PlaySound(TF2Team, "misc/your_team_won.wav");
			return Plugin_Handled;
		}
		else if(!strcmp(sound, "Game.SuddenDeath", false))
		{
			PlaySound(TF2Team, "misc/your_team_suddendeath.wav");
			return Plugin_Handled;
		}
		else if(!strcmp(sound, "Game.YourTeamLost", false))
		{
			PlaySound(TF2Team, "misc/your_team_lost.wav");
			return Plugin_Handled;
		}
		if (!strcmp(sound, "Voice.German_FlagCapture", false) || !strcmp(sound, "Voice.US_FlagCapture", false))
		{
			if (roundEnded && blockcry)
			{
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

// ===========================================================================================================================================







// **************************************************************************
// *********************** T	I	M	E	R	S ***************************
// **************************************************************************
// ===========================================================================================================================================
public Action:AnnounceRepeater(Handle:timer)
{
	if (!roundEnded && clientpref && enabled && (MaxSounds1+MaxSounds2))
	{
		PrintToChatAll("\x07FF0000* %t", "Announce Message", YELLOW, GREEN, YELLOW, GREEN);
	}
}

public Action:TimerAnnounce(Handle:timer, any:serial)
{
	new client = GetClientFromSerial(serial);
	if (client && clientpref && enabled && (MaxSounds1+MaxSounds2))
	{
		PrintToChat(client, "\x07FF0000* %t", "Announce Message", YELLOW, GREEN, YELLOW, GREEN);
	}
}
// ===========================================================================================================================================







// **********************************************************************************************************
// *********************** H	O	O	K	E	D		C	O	N	V	A	R	S ***************************
// **********************************************************************************************************
// ===========================================================================================================================================
public ConVarChange_Timer(Handle:convar, const String:oldValue[], const String:newValue[])
{
	msgtime = StringToFloat(newValue);
	if (Timer != INVALID_HANDLE)
	{
		KillTimer(Timer);
		Timer = INVALID_HANDLE;
	}
	if (msgtime > 0.0)
	{
		Timer = CreateTimer(msgtime, AnnounceRepeater, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public ConVarChanges(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (convar == sm_res_roundendannounce)
	{
		endmsg = bool:StringToInt(newValue);
	}
	else if (convar == sm_res_roundstartannounce)
	{
		startmsg = bool:StringToInt(newValue);
	}
	else if (convar == sm_res_playerconnectannounce)
	{
		connectmsg = bool:StringToInt(newValue);
	}
	else if (convar == sm_res_mapendsound)
	{
		mepenable = bool:StringToInt(newValue);
	}
	else if (convar == sm_res_randomsounds)
	{
		rndsnd = bool:StringToInt(newValue);
	}
	else if (convar == sm_res_commonsounds)
	{
		common = bool:StringToInt(newValue);
	}
	else if (convar == sm_res_debugsounds)
	{
		debugsounds = bool:StringToInt(newValue);
	}
	else if (convar == sm_res_dod_blocklastcry)
	{
		blockcry = bool:StringToInt(newValue);
	}
	else if (convar == sm_res_volume)
	{
		f_volume = StringToFloat(newValue);
	}
	else if (convar == sm_res_soundslist)
	{
		strcopy(SndListPath, sizeof(SndListPath), newValue);
	}
	else if (convar == sm_res_play_method)
	{
		i_play_method = StringToInt(newValue);
	}
	else if (convar == sm_res_displaysound)
	{
		display = bool:StringToInt(newValue);
	}
}

public ConVarChange_sm_res_client(Handle:convar, const String:oldValue[], const String:newValue[])
{
	clientpref = bool:StringToInt(newValue);
	if (clientpref)
	{
		if (cookieResPref == INVALID_HANDLE)
		{
			cookieResPref = RegClientCookie("Round End Sound", "Round End Sound", CookieAccess_Private);
			SetCookieMenuItem(ResPrefSelected, 0, "Round End Sound");
		}
	}
	else if (cookieResPref != INVALID_HANDLE)
	{
		CloseHandle(cookieResPref);
		cookieResPref = INVALID_HANDLE;
	}
}

public ConVarChange_sm_res_enable(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new Enable = StringToInt(newValue);
	if (!(MaxSounds1 + MaxSounds2 + MapendMaxSounds) && Enable)
	{
		SetConVarInt(convar, 0);
		LogToFile(s_LogFile, "Error: You have to load any sounds before activating the plugin");
		return;
	}
	switch (Enable)
	{
		case 0 :
		{
			if (active)
			{
				DiactivatePlugin();
			}
			enabled = false;
		}

		case 1 :
		{
			if (msgtime > 0.0)
			{
				Timer = CreateTimer(msgtime, AnnounceRepeater, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			}

			if (!active)
			{
				ActivatePlugin();
			}
			enabled = true;
		}
	}
}
// ===========================================================================================================================================







// **********************************************************************************************************
// *********************** A	C	T	I	V	A	T	E		P	L	U	G	I	N ***********************
// **********************************************************************************************************
// ===========================================================================================================================================
ActivatePlugin()
{
	if (active)
	{
		return;
	}
	switch (iGame)
	{
		case GAME_CSTRIKE :
		{
			HookEvent("round_end", OnRoundEnd);
			HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
			PrecacheSound("radio/ctwin.wav", false);
			PrecacheSound("radio/terwin.wav", false);
		}
		case GAME_CSGO :
		{
			HookEvent("round_end", OnRoundEnd);
			HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
		}
		case GAME_DOD :
		{
			HookEvent("dod_round_win", OnRoundEnd);
			HookEvent("dod_round_start", OnRoundStart);
			HookEvent("dod_broadcast_audio", OnBroadCast, EventHookMode_Pre);
			PrecacheSound("ambient/german_win.mp3", false);
			PrecacheSound("ambient/us_win.mp3", false);
		}
		case GAME_TF2 :
		{
			HookEvent("teamplay_round_win", OnRoundEnd);
			HookEvent("teamplay_round_start", OnRoundStart);
			HookEvent("teamplay_broadcast_audio", OnBroadCast, EventHookMode_Pre);
			PrecacheSound("misc/your_team_lost.wav", false);
			PrecacheSound("misc/your_team_stalemate.wav", false);
			PrecacheSound("misc/your_team_suddendeath.wav", false);
			PrecacheSound("misc/your_team_won.wav", false);
		}
		case GAME_OTHER :
		{
			if (!(roundendhooked = HookEventEx("round_end", OnRoundEnd)))
			{
				SetFailState("No game support");
			}

			roundstarthooked = HookEventEx("round_start", OnRoundStart);
		}
	}
	active = true;
}
// ===========================================================================================================================================







// ******************************************************************************************************************
// *********************** D	I	A	C	T	I	V	A	T	E		P	L	U	G	I	N ***********************
// ******************************************************************************************************************
// ===========================================================================================================================================
DiactivatePlugin()
{
	if (!active)
	{
		return;
	}
	switch (iGame)
	{
		case GAME_CSTRIKE :
		{
			UnhookEvent("round_end", OnRoundEnd);
			UnhookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
		}
		case GAME_CSGO :
		{
			UnhookEvent("round_end", OnRoundEnd);
			UnhookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
		}
		case GAME_DOD :
		{
			UnhookEvent("dod_round_win", OnRoundEnd);
			UnhookEvent("dod_round_start", OnRoundStart);
			UnhookEvent("dod_broadcast_audio", OnBroadCast, EventHookMode_Pre);
		}
		case GAME_TF2 :
		{
			UnhookEvent("teamplay_round_win", OnRoundEnd);
			UnhookEvent("teamplay_round_start", OnRoundStart);
			UnhookEvent("teamplay_broadcast_audio", OnBroadCast, EventHookMode_Pre);
		}
		case GAME_OTHER :
		{
			if (roundendhooked)
			{
				UnhookEvent("round_end", OnRoundEnd);
				roundendhooked = false;
			}
			if (roundstarthooked)
			{
				UnhookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
				roundstarthooked = false;
			}
		}
	}
	if (Timer != INVALID_HANDLE)
	{
		KillTimer(Timer);
		Timer = INVALID_HANDLE;
	}

	active = false;
}
// ===========================================================================================================================================







// ****************************************************************************************************************************************************************
// *********************** S	T	O	C	K	S	(From SMBLIB by Berni and Chanz (http://forums.alliedmods.net/showthread.php?t=148387)) ***********************
// ****************************************************************************************************************************************************************
// ===========================================================================================================================================
stock GetExtension(const String:path[], String:buffer[], size)
{
	new extpos = FindCharInString(path, '.', true);

	if (extpos == -1)
	{
		buffer[0] = '\0';
		return;
	}

	strcopy(buffer, size, path[++extpos]);
}

stock PlayClientSound(client, const String:sound[])
{
	ClientCommand(client, "play \"%s\"", sound);
}

stock RemoveFileFromDownloadsTable(const String:szFileName[])
{
	static hTable = INVALID_STRING_TABLE;

	if (hTable == INVALID_STRING_TABLE)
	{
		hTable = FindStringTable("downloadables");
		if (hTable == INVALID_STRING_TABLE)
		{
			return;
		}
	}

	new iIndex = FindStringIndex2(hTable, szFileName);

	if (iIndex == INVALID_STRING_INDEX)
		return;

	new bool:save = LockStringTables(false);
	SetStringTableData(hTable, iIndex, "\0", 1);
	LockStringTables(save);
}

stock FindStringIndex2(iTable, const String:szFileName[], iStart=0)
{
	new iMax = GetStringTableNumStrings(iTable);

	decl String:szBuffer[PLATFORM_MAX_PATH];
	for (new i = iStart; i < iMax; i++)
	{
		ReadStringTable(iTable, i, szBuffer, sizeof(szBuffer));
		if (!strcmp(szFileName, szBuffer, false))
			return i;
	}
	return INVALID_STRING_INDEX;
}

stock Math_GetRandomInt(min, max)
{
	if (min >= max)
		return max;

	new number;
	while ((number = Math_GetRandom(min, max)) != lastnumber)
		return number;

	return Math_GetRandom(min, max);
}

stock Math_GetRandom(min, max)
{
	new random = GetURandomInt();

	if (!random)
		random++;

	new number = RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;

	return number;
}

stock FakePrecacheSound(const String:szPath[])
{
	static hTable = INVALID_STRING_TABLE;

	if (hTable == INVALID_STRING_TABLE)
	{
		hTable = FindStringTable("soundprecache");
	}

	AddToStringTable(hTable, szPath);
}

stock StripStartInSound(String:buffer[], size)
{
	strcopy(buffer, size, buffer[1]);
}

// ===========================================================================================================================================
