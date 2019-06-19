#pragma semicolon 1

#define PREFIX 	"\x01[\x0BJAIL\x01] :\x05"

#define PLUGIN_AUTHOR "Trostal"
#define PLUGIN_VERSION "0.01a"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>

#include <emitsoundany>

#include "Jail_Mod.inc"

EngineVersion g_Game;

enum CONVAR
{
	ConVar:PLUGIN_ENABLE
}

// Cvar 핸들
ConVar g_cvarConvar[CONVAR];

char g_szVipDataFile[64];

/**************************
 전반적인 플러그인 관련 변수 정의
**************************/
// 게임을 진행하기위해 필요한 최소 인원 // TODO
#define MIN_PLAYER_TO_PLAY 1

bool g_bJailActionPaused = false;
int g_offsCollision;

/**************************
 라운드 관련 변수 정의
**************************/
bool g_bRestartChecked = false;
bool g_bRebelableTime = false;
bool g_bRoundEnded = false;

char g_szRoundStatus[256];
char g_szGuardCommand[256];

float g_szQuickGuardCommandCooldown[MAXPLAYERS + 1] =  { 0.0, ... };

/**************************
 개인 변수 정의
**************************/
bool g_bJailHudPaused[MAXPLAYERS + 1] = false;

bool g_bRebel[MAXPLAYERS + 1] =  { false, ... };
bool g_bVIPUser[MAXPLAYERS + 1] =  { false, ... };

/**************************
 사운드 변수 정의
**************************/
#define SOUND_REBELABLE_WARNING	"JAIL/jail/waring.mp3"
#define SOUND_KNIFE_KNOCKBACK	"ambient/explosions/explode_7.mp3"
#define SOUND_GUARD_COMMAND 	"buttons/blip2.wav"

/**************************
 알람 관련 변수 정의
**************************/

enum Alarms
{
	Cmd_MoveBoxRoom = 0,
	Time_Uprising,
	Cmd_Move,
	Time_Move,
	Cmd_Torture,
	Time_Torture,
	Time_Slay
}

#define MAX_ALARMS	7

#define ALARM_TIME 1
#define ALARM_COMMAND 2

int Alarm_Count;

int Alarm_Flag[Alarms];
char Alarm_Name[Alarms][128];
int Alarm_Start_Minute[Alarms];
float Alarm_Start_Second[Alarms];
int Alarm_End_Minute[Alarms];
float Alarm_End_Second[Alarms];
bool Alarm_Fired[Alarms];
bool Alarm_Firing[Alarms];

int g_iToolsVelocity;

public Plugin myinfo = 
{
	name = "[JAIL] Jail Plugin - Main",
	author = "Trostal",
	description = "감옥 플러그인의 메인을 담당하는 플러그인입니다.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Hatser/Jail-Mod"
};

public void OnPluginStart()
{
	g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO)
	{
		SetFailState("This plugin is for CSGO only.");	
	}
	
	g_offsCollision = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
	
	SetupCommands();
	SetupConvars();
	
	SetupAlarms();
	
	HookEvent("round_start", OnRoundStart);
//	HookEvent("round_freeze_end", OnRoundFreezeTimeEnd);
	HookEvent("round_end", OnRoundEnd);
	HookEvent("player_spawn", OnPlayerSpawn);
	
	//addons/sourcemod/data에 prisonviplistdata.txt라는 VIP리스트 데이터값을 생성한다
	BuildPath(Path_SM, g_szVipDataFile, 64, "data/prisonviplistdata.txt");
	
	g_iToolsVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
	if (g_iToolsVelocity == -1)
	{
		LogError("Offset \"CBasePlayer::m_vecVelocity[0]\" was not found.");
	}
}

public void OnMapStart()
{
	RequestFrame(SetConVars);
	InitAlarmState();
	
	PrepareResources();
}

void PrepareResources()
{
	PrepareSound(SOUND_REBELABLE_WARNING);
	PrepareSound(SOUND_KNIFE_KNOCKBACK);
	PrecacheSound(SOUND_GUARD_COMMAND);
}

void PrepareSound(char[] path, bool anymethod=true)
{
	char downloadPath[256];
	
	FormatEx(downloadPath, sizeof(downloadPath), "sound/%s", path);
	if(IsSoundPrecached(path))
	{
		if(anymethod)
		{
			PrecacheSoundAny(path);
		}
		else
		{
			PrecacheSound(path);
		}
	}
	AddFileToDownloadsTable(downloadPath);
}

public void SetConVars(any data)
{
	SetConVarInt(FindConVar("mp_roundtime"), 7);
	
	SetConVarInt(FindConVar("mp_playerid"), 0);
	SetConVarInt(FindConVar("mp_friendlyfire"), 0);
	SetConVarInt(FindConVar("mp_autoteambalance"), 0);
	SetConVarInt(FindConVar("mp_forcecamera"), 0);
	
	SetConVarInt(FindConVar("sv_alltalk"), 1);
	SetConVarInt(FindConVar("sv_full_alltalk"), 1);
	SetConVarInt(FindConVar("sv_deadtalk"), 1);
	
	SetConVarInt(FindConVar("sv_show_voip_indicator_for_enemies"), 0); // 1일 시, 보이스 사용할 때 상대편 머리위에도 마이크 아이콘 표시
	
	SetConVarInt(FindConVar("mp_playercashawards"), 1);
	SetConVarInt(FindConVar("mp_teamcashawards"), 1);
	
	// 무기 관련
	SetConVarString(FindConVar("mp_t_default_primary"), ""); // 기본 주총을 없앰
	SetConVarString(FindConVar("mp_ct_default_primary"), ""); // 기본 주총을 없앰
	
	SetConVarString(FindConVar("mp_t_default_secondary"), ""); // 기본 권총을 없앰
	SetConVarString(FindConVar("mp_ct_default_secondary"), ""); // 기본 권총을 없앰
	
	SetConVarString(FindConVar("mp_t_default_grenades"), ""); // 기본 투척류를 없앰
	SetConVarString(FindConVar("mp_ct_default_grenades"), ""); // 기본 투척류를 없앰
	
	SetConVarInt(FindConVar("mp_death_drop_gun"), 2); // current or best
	SetConVarInt(FindConVar("mp_weapons_allow_map_placed"), 1); // 맵 상에 놓여진 무기 허용
	SetConVarInt(FindConVar("weapon_reticle_knife_show"), 1); // 칼 든 상태에서 이름표 표시
	
	SetConVarInt(FindConVar("sv_clamp_unsafe_velocities"), 0); // 부스팅 버그 해결

/*	// 돈 설정을 강제할경우 활성화.

	SetConVarInt(FindConVar("mp_afterroundmoney"), 800);
	SetConVarInt(FindConVar("mp_startmoney"), 800);
	
	SetConVarInt(FindConVar("cash_player_bomb_defused"), 300);
	SetConVarInt(FindConVar("cash_player_bomb_planted"), 300);
	SetConVarInt(FindConVar("cash_player_damage_hostage"), -30);
	SetConVarInt(FindConVar("cash_player_interact_with_hostage"), 150);
	SetConVarInt(FindConVar("cash_player_killed_enemy_default"), 300);
	SetConVarInt(FindConVar("cash_player_killed_enemy_factor"), 1);
	SetConVarInt(FindConVar("cash_player_killed_hostage"), -1000);
	SetConVarInt(FindConVar("cash_player_killed_teammate"), -300);
	SetConVarInt(FindConVar("cash_player_rescued_hostage"), 1000);
	SetConVarInt(FindConVar("cash_team_elimination_bomb_map"), 3250);
	SetConVarInt(FindConVar("cash_team_elimination_hostage_map_t"), 1000);
	SetConVarInt(FindConVar("cash_team_elimination_hostage_map_ct"), 2000);
	SetConVarInt(FindConVar("cash_team_hostage_alive"), 0);
	SetConVarInt(FindConVar("cash_team_hostage_interaction"), 500);
	SetConVarInt(FindConVar("cash_team_loser_bonus"), 1400); // 혹은 2400
	SetConVarInt(FindConVar("cash_team_loser_bonus_consecutive_rounds"), 500);
	SetConVarInt(FindConVar("cash_team_planted_bomb_but_defused"), 800);
	SetConVarInt(FindConVar("cash_team_rescued_hostage"), 0);
	SetConVarInt(FindConVar("cash_team_terrorist_win_bomb"), 3500);
	SetConVarInt(FindConVar("cash_team_win_by_defusing_bomb"), 3250);
	SetConVarInt(FindConVar("cash_team_win_by_hostage_rescue"), 3500);
	SetConVarInt(FindConVar("cash_team_win_by_time_running_out_hostage"), 3250);
	SetConVarInt(FindConVar("cash_team_win_by_time_running_out_bomb"), 3250);
*/
	
	SetConVarString(FindConVar("mp_teamname_1"), "간수팀"); // CTs
	SetConVarString(FindConVar("mp_teamname_2"), "죄수팀"); // Ts
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("JAIL_IsPluginOn", Native_JAIL_IsPluginOn);
	CreateNative("JAIL_IsClientVIP", Native_JAIL_IsClientVIP);
	CreateNative("JAIL_SetRebelable", Native_JAIL_SetRebelable);
	CreateNative("JAIL_IsRebelable", Native_JAIL_IsRebelable);
	CreateNative("JAIL_IsJailActionPaused", Native_JAIL_IsJailActionPaused);
	CreateNative("JAIL_PauseJailAction", Native_JAIL_PauseJailAction);
	CreateNative("JAIL_IsJailHudPaused", Native_JAIL_IsJailHudPaused);
	CreateNative("JAIL_PauseJailHud", Native_JAIL_PauseJailHud);
	
	RegPluginLibrary("JAILJail");
	return APLRes_Success;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	
	g_szQuickGuardCommandCooldown[client] = 0.0;
	JAIL_PauseJailHud(client, false);
}

public void OnClientPostAdminCheck(int client)
{
	LoadVipData(client);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

void SetupCommands()
{
	AddCommandListener(OnClientChat, "say");
	AddCommandListener(OnClientChat, "say_team");
	
	AddCommandListener(OnClientJoinTeam, "jointeam");
	
	// 명령 메뉴 커맨드
	RegConsoleCmd("sm_cmd", Cmd_CommandMenu);
	RegConsoleCmd("sm_command", Cmd_CommandMenu);

	HookUserMessage(GetUserMessageId("TextMsg"), BlockWarmupNoticeTextMsg, true);
}

void SetupConvars()
{
	g_cvarConvar[PLUGIN_ENABLE] = CreateConVar("jail_enable", "1", "본 플러그인의 작동 여부입니다. 작동을 원하지 않으시다면 0을, 원하신다면 1을 써주세요.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
}

public Action BlockWarmupNoticeTextMsg(UserMsg msg_id, Handle pb, const int[] players, int playersNum, bool reliable, bool init) 
{
	if (!JAIL_IsPluginOn())	return Plugin_Continue;
	
	char buffer[40]; 
	PbReadString(pb, "params", buffer, sizeof(buffer), 0);
	
	if(PbReadInt(pb, "msg_dst") == 3) 
	{
		// 준비시간이 다 되면 게임이 시작된다는 메세지를 없앤다.
		if(StrEqual(buffer, "#SFUI_Notice_Match_Will_Start_Chat", false))
		{
			if(GetPlayerCount() < MIN_PLAYER_TO_PLAY)
			{
				#if defined _DEBUG_
					PrintToServer("[JAIL Prison] BlockWarmupNoticeTextMsg()");
				#endif
				return Plugin_Handled;
			}
		} 
	}
	return Plugin_Continue;
}

void WarmupTimeAction()
{
	if (!JAIL_IsPluginOn())	return;
	
	GameRules_SetProp("m_numGlobalGiftsGiven", -1, 1);
	GameRules_SetProp("m_numGlobalGifters", -1, 1);
	GameRules_SetProp("m_numGlobalGiftsPeriodSeconds", -1, 1);
	if(GetPlayerCount() < MIN_PLAYER_TO_PLAY)
	{
		PrintHintTextToAll("최소 <font color='#0fff0f'>%i</font>명 이상이어야 플레이가 가능합니다.", MIN_PLAYER_TO_PLAY);
		SetWarmupStartTime(GetGameTime()+0.5);
		return;
	}
	
	if(GetRestartRoundTime() > 0.0)
	{
		if(!g_bRestartChecked)
		{
			if(GetWarmupLeftTime() < 0.0)
			{
				g_bRestartChecked = true;
				PrintToChatAll("%s 준비 시간 종료! %i초 뒤 게임 시작!", PREFIX, RoundToNearest(GetRestartRoundTime()-GetGameTime()));
			}
		}
	}
	else
	{
		if(g_bRestartChecked)	g_bRestartChecked = false;
	}
	float flWarmupLeftTime = GetWarmupLeftTime();
	if(flWarmupLeftTime > 0)
		PrintHintTextToAll("지금은 준비 시간입니다: <font color='#0fff0f'>%.1f</font>", flWarmupLeftTime);
	else
		PrintHintTextToAll("준비 시간이 끝났습니다.\n<font color='#ffff0f'>%.1f</font>초 뒤 게임을 시작합니다.", GetRestartRoundTime()-GetGameTime());
}

void FuncTime_Uprising()
{
	if (!JAIL_IsPluginOn() || JAIL_IsJailActionPaused() || IsWarmupPeriod())	return;
	
	JAIL_SetRebelable(true);
	
	for(int i = 1;i <= MaxClients; i++)
	{
		if(IsValidPlayer(i))
		{
			if(GetClientTeam(i) == CS_TEAM_CT)
			{
				SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", GetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue") - 0.15);
			}
		}
	}
	
	EmitSoundToAllAny(SOUND_REBELABLE_WARNING, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL);	
}
/*******************************************************
 OnGameFrame()
*******************************************************/
public void OnGameFrame()
{
	if (!JAIL_IsPluginOn())	return;
	
	// 준비 시간일 때
	if(IsWarmupPeriod())
	{
		WarmupTimeAction();
	}
	else // 준비 시간이 아닐 때
	{
		CheckRoundCondition();
		
		// 라운드 시간이 종료되었을 때.
		// 감옥에서는 올 슬레이를 시키므로 아래 코드는 필요없음.
		/*
		if(GetRoundLeftTime() <= 0)
		{
			if(!g_bRoundEnded)
			{
				CS_TerminateRound(GetConVarFloat(FindConVar("mp_round_restart_delay")), CSRoundEnd_TerroristWin);
				g_bRoundEnded = true;
			}
		}
		*/
	}
}

/*******************************************************
 OnPlayerRunCmd()
*******************************************************/
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!JAIL_IsPluginOn() || JAIL_IsJailActionPaused() || IsWarmupPeriod())	return Plugin_Continue;
	
	if (JAIL_IsJailHudPaused(client))	return Plugin_Continue;
	
	if(IsValidClient(client))
	{
		char msg[512];
		Format(msg, sizeof(msg), "<font size='16'>라운드 상태: %s\n간수 명령: %s</font>", g_szRoundStatus, g_szGuardCommand);
		PrintKeyHintText(client, msg);
	}
	return Plugin_Continue;
}

/*******************************************************
 OnTakeDamage()
*******************************************************/
public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!JAIL_IsPluginOn() || JAIL_IsJailActionPaused() || IsWarmupPeriod())	return Plugin_Continue;
	
	if(!IsValidPlayer(victim))
		return Plugin_Continue;
	
	int victimTeam = GetClientTeam(victim);
	if(!JAIL_IsRebelable() && victimTeam == CS_TEAM_CT)
		return Plugin_Stop;
	
	if(g_bRoundEnded)
		return Plugin_Stop;
		
	/* 이후 필요하다면,
	 * 이곳에 플레이어 이외의 사유로 공격당했을 때의 코드 삽입
	 */
		
	if(!IsValidPlayer(attacker))
		return Plugin_Continue;
	
	int attackerTeam = GetClientTeam(attacker);
	
	// 죄수 ==> 간수
	if(attackerTeam == CS_TEAM_T && victimTeam == CS_TEAM_CT)
	{
		if(JAIL_IsRebelable())
		{
			g_bRebel[attacker] = true;
		//	PrintCenterTextAll("%N님이 %N님에게 반란을 일으켰습니다!", attacker, victim);
			//반란을 일으켰으므로 죄수를 빨갛게 렌더링
			SetEntityRenderMode(attacker, RENDER_TRANSCOLOR);
			SetEntityRenderColor(attacker, 255, 0, 0, 255);
			
			char clsname[32];
		
			if(IsValidEdict(weapon))
				if (!GetEdictClassname(weapon, clsname, sizeof(clsname)))	return Plugin_Continue;
			
			if(StrEqual(clsname[7], "knife"))
			{
				if(damage == 180) {
					damage = 135.0;
				} else if(damage == 25 || damage == 40 || damage == 90) {
					damage = GetRandomInt(0, 1) ? 15.0 : 20.0;
				} else if(damage == 65) {
					damage = 65.0;
				}
				
				float neededArmor = float(RoundToFloor((damage*0.85) / 10));
				float currentArmor = float(GetEntProp(victim, Prop_Send, "m_ArmorValue", 1));
				if(currentArmor > 0)
				{
					if(currentArmor >= neededArmor) {
						// 칼의 관통력은 85%
						// http://counterstrike.wikia.com/wiki/Kevlar_%2B_Helmet
						damage = float(RoundToCeil(damage / 0.85));
					} else {
						float armoredDamage;
						armoredDamage = float(RoundToFloor(damage / (1-((currentArmor/neededArmor) * 0.15)))) - damage;
						damage = float(RoundToCeil((damage-armoredDamage) / 0.85));
					}
				}
				return Plugin_Changed;
			}
			
		}
	}
	// 간수 ==> 죄수
	else if(attackerTeam == CS_TEAM_CT && victimTeam == CS_TEAM_T)
	{
		char clsname[32];
		
		if(IsValidEdict(weapon))
			if (!GetEdictClassname(weapon, clsname, sizeof(clsname)))	return Plugin_Continue;
		
		if(StrEqual(clsname[7], "knife"))
		{
		//	PrintCenterTextAll("%N님이 %N님에게 경고를 주었습니다", attacker, victim);
			
			float flAttackerEyePos[3], flAttackerEyeAngles[3], vecAttackerEyeVectors[3];
	
			GetClientEyePosition(attacker, flAttackerEyePos);
			GetClientEyeAngles(attacker, flAttackerEyeAngles);
			
			GetAngleVectors(flAttackerEyeAngles, vecAttackerEyeVectors, NULL_VECTOR, NULL_VECTOR);
			
			vecAttackerEyeVectors[2] = 0.0;
			
			NormalizeVector(vecAttackerEyeVectors, vecAttackerEyeVectors);
			ScaleVector(vecAttackerEyeVectors, 1200.0);
			
			ToolsClientVelocity(victim, vecAttackerEyeVectors);
			
			EmitSoundToAllAny(SOUND_KNIFE_KNOCKBACK, SOUND_FROM_WORLD, SNDCHAN_STATIC, SNDLEVEL_GUNFIRE, _, SNDVOL_NORMAL, GetRandomInt(95, 105), _, flAttackerEyePos);
			
			if(damage == 180) {
				damage = 135.0;
			} else if(damage == 25 || damage == 40 || damage == 90) {
				damage = GetRandomInt(0, 1) ? 15.0 : 20.0;
			} else if(damage == 65) {
				damage = 65.0;
			}
			
			float neededArmor = float(RoundToFloor((damage*0.85) / 10));
			float currentArmor = float(GetEntProp(victim, Prop_Send, "m_ArmorValue", 1));
			if(currentArmor > 0)
			{
				if(currentArmor >= neededArmor) {
					// 칼의 관통력은 85%
					// http://counterstrike.wikia.com/wiki/Kevlar_%2B_Helmet
					damage = float(RoundToCeil(damage / 0.85));
				} else {
					float armoredDamage;
					armoredDamage = float(RoundToFloor(damage / (1-((currentArmor/neededArmor) * 0.15)))) - damage;
					damage = float(RoundToCeil((damage-armoredDamage) / 0.85));
				}
			}
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

/*******************************************************
 일반 함수
*******************************************************/
/**
 * Get or set a client's velocity.
 * @param client		The client index.
 * @param vecVelocity   Array to store vector in, or velocity to set on client.
 * @param retrieve	  True to get client's velocity, false to set it.
 * @param stack		 If modifying velocity, then true will stack new velocity onto the client's
 *					  current velocity, false will reset it.
 */
stock void ToolsClientVelocity(int client, float vecVelocity[3], bool apply = true, bool stack = true)
{
	// If retrieve if true, then get client's velocity.
	if (!apply)
	{
		// x = vector component.
		for (new x = 0; x < 3; x++)
		{
			vecVelocity[x] = GetEntDataFloat(client, g_iToolsVelocity + (x*4));
		}
		
		// Stop here.
		return;
	}
	
	// If stack is true, then add client's velocity.
	if (stack)
	{
		// Get client's velocity.
		float vecClientVelocity[3];
		
		// x = vector component.
		for (new x = 0; x < 3; x++)
		{
			vecClientVelocity[x] = GetEntDataFloat(client, g_iToolsVelocity + (x*4));
		}
		
		AddVectors(vecClientVelocity, vecVelocity, vecVelocity);
	}
	
	// Apply velocity on client.
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vecVelocity);
}


void SetupAlarms()
{
//	ALARM_COMMAND는 간수가 특정 명령을 내려야 하는 시간 설정임을 의미한다.
//	ALARM_TIME는 특정 시간에 도달했음을 의미한다.
// 두번째의 문자열은 해당 알림 시간의 이름을 나타낸다.
// 세번째의 정수형, 네번째의 실수형(소숫점)은 해당 시간이 시작되는 라운드 시간을 의미한다.
// 다섯번째의 정수형, 여섯번째의 실수형(소숫점)은 해당 시간의 기간이 끝나는 라운드 시간을 의미한다.
// 특정 시간에 도달하는 경우(예로 반란시간, 이동시간, 고문시간)는 일시적인 순간이므로 끝나는 라운드 시간을 설정하지 않는다.
	CreateAlarm(ALARM_COMMAND,	"상자방 이동",		7,	0.0,	6,	20.0); // Cmd_MoveBoxRoom
	CreateAlarm(ALARM_TIME,		"반란시간",			6,	0.0); // Time_Uprising
	CreateAlarm(ALARM_COMMAND,	"이동",				5,	30.0,	4,	30.0); // Cmd_Move
	CreateAlarm(ALARM_TIME,		"이동시간",			4,	0.0); // Time_Move
	CreateAlarm(ALARM_COMMAND,	"고문",				2,	40.0,	1,	40.0); // Cmd_Torture
	CreateAlarm(ALARM_TIME,		"고문시간",			1,	0.0); // Time_Torture
	CreateAlarm(ALARM_TIME,		"간수 슬레이 시간",	0,	0.0); // Time_Slay
}

void CreateAlarm(int AFlag, char[] AName, int AStart_Min, float AStart_Sec, int AEnd_Min=0, float AEnd_Sec=0.0)
{
	Alarm_Flag[Alarm_Count] = AFlag;
	Format(Alarm_Name[Alarm_Count], sizeof(Alarm_Name[]), "%s", AName);
	Alarm_Start_Minute[Alarm_Count] = AStart_Min;
	Alarm_Start_Second[Alarm_Count] = AStart_Sec;
	if(AFlag == ALARM_TIME)
	{
		Alarm_End_Minute[Alarm_Count] = 0;
		Alarm_End_Second[Alarm_Count] = 0.0;
	}
	if(AFlag == ALARM_COMMAND)
	{
		Alarm_End_Minute[Alarm_Count] = AEnd_Min;
		Alarm_End_Second[Alarm_Count] = AEnd_Sec;
	}
	Alarm_Fired[Alarm_Count] = false;
	Alarm_Firing[Alarm_Count] = false;
	Alarm_Count++;
}

void CheckRoundCondition()
{
	if (!JAIL_IsPluginOn() || JAIL_IsJailActionPaused() || IsWarmupPeriod())	return;
	
	if(g_bRoundEnded) return;
	
	if(GetTeamClientCount(2) + GetTeamClientCount(3) <= 0) return;
	
	float flRoundLeftTime = GetRoundLeftTime();
	
	int LeftMin;
	float LeftSec = flRoundLeftTime;
	ConvertSecToMin(LeftMin, LeftSec);
	
	for(int i=0;i < MAX_ALARMS;i++)
	{
		if (Alarm_Fired[i])	continue;
		
		if(Alarm_Flag[i] == ALARM_TIME)
		{
			float tempAlarm_Sec, tempLeftSec;
			tempAlarm_Sec = ConvertMinToSec(Alarm_Start_Minute[i], Alarm_Start_Second[i]);
			tempLeftSec = ConvertMinToSec(LeftMin, LeftSec);
			
			if(tempAlarm_Sec >= tempLeftSec)
			{
				if(/*!InKnifeFighting() && */!Alarm_Fired[i])
				{
					PrintToChatAll("%s %s이 되었습니다!", PREFIX, Alarm_Name[i]);
					PrintCenterTextAll("%s이 되었습니다!", Alarm_Name[i]);
					Format(g_szRoundStatus, sizeof(g_szRoundStatus), "%s이 되었습니다!", Alarm_Name[i]);
					
					if(StrEqual(Alarm_Name[i], "반란시간", false))
						FuncTime_Uprising();
					if(StrEqual(Alarm_Name[i], "간수 슬레이 시간", false))
						Time_GuardSlay();
						
					Alarm_Fired[i] = true;
					break;
				}
			}
		}
		else if(Alarm_Flag[i] == ALARM_COMMAND)
		{
			if((Alarm_Start_Minute[i]*60)+Alarm_Start_Second[i] >= flRoundLeftTime && (Alarm_End_Minute[i]*60)+Alarm_End_Second[i] <= flRoundLeftTime+0.6)
			{
				if(flRoundLeftTime - ((Alarm_End_Minute[i]*60)+Alarm_End_Second[i]) > 0)
				{
					Format(g_szRoundStatus, sizeof(g_szRoundStatus), "간수는 %s 명령을 내려야 합니다! / 남은 시간: %.0f 초", Alarm_Name[i], flRoundLeftTime - ((Alarm_End_Minute[i]*60)+Alarm_End_Second[i]) + 1.0);
					if(!Alarm_Firing[i])
						Alarm_Firing[i] = true;
						
					break;
				}
				else
				{
					if(!Alarm_Fired[i])
					{
						PrintToChatAll("%s 간수들이 아직까지 %s 명령을 내리지 않았다면 자유시간입니다.", PREFIX, Alarm_Name[i]);
						PrintCenterTextAll("간수들이 아직까지 %s 명령을 내리지 않았다면 자유시간입니다.", Alarm_Name[i]);
						Format(g_szRoundStatus, sizeof(g_szRoundStatus), "간수들이 아직까지 %s 명령을 내리지 않았다면 자유시간입니다.", Alarm_Name[i]);
						
						Alarm_Fired[i] = true;
						Alarm_Firing[i] = false;
						
						break;
					}
				}
			}
		}
	}
}

void InitAlarmState()
{
	for(int i=0;i < MAX_ALARMS;i++)
	{
		Alarm_Fired[i] = false;
		Alarm_Firing[i] = false;
	}
}

stock void ConvertSecToMin(int& TimeMin, float& TimeSec)
{
	int tempTimeSec = RoundToFloor(TimeSec);
	float diff = TimeSec - tempTimeSec;
	if(TimeSec >= 60)
	{
		TimeMin += RoundToFloor(TimeSec / 60);
		tempTimeSec = tempTimeSec % 60;
		TimeSec = tempTimeSec + diff;
	}
}

stock float ConvertMinToSec(int TimeMin, float TimeSec)
{
	return TimeSec + (TimeMin * 60);
}

void Time_GuardSlay()
{
	for(int i = 1;i <= MaxClients; i++)
	{
		if(IsValidPlayer(i))
		{
			if(GetClientTeam(i) == CS_TEAM_CT)
			{
				ForcePlayerSuicide(i);
			}	
		}
	}
}

void LoadVipData(int client)
{
	if(IsValidClient(client))
	{	
		char authId[32];
		GetClientAuthId(client, AuthId_Steam2,  authId, 32);
		
		KeyValues kv = new KeyValues("Vault");
		
		kv.ImportFromFile(g_szVipDataFile);
		
		kv.JumpToKey("playerisvip", false);
		
		g_bVIPUser[client] = view_as<bool>(kv.GetNum(authId));
		kv.Rewind();
	
		kv.Rewind();
	
		delete kv;
	}
}

/*******************************************************
 이벤트
*******************************************************/
public void OnRoundStart(Event event, char[] name, bool dontBroadcast)
{
	g_bRoundEnded = false;
	
	if (IsWarmupPeriod())	return;
	
	// 감옥 시스템 재개
	JAIL_PauseJailAction(false);
	
	Format(g_szRoundStatus, sizeof(g_szRoundStatus), "라운드가 시작되었습니다.");
	Format(g_szGuardCommand, sizeof(g_szGuardCommand), "명령 없음");
	
	InitAlarmState();
	
	// 반란 불가 설정
	JAIL_SetRebelable(false);
	
	PrintToChatAll("%s 간수는 #명령 으로 죄수에게 명령을 내릴 수 있습니다, 간수는 감옥문을 열어주세요!", PREFIX);
}

public void OnRoundEnd(Event event, char[] name, bool dontBroadcast)
{
	g_bRoundEnded = true;
	
	if (!JAIL_IsPluginOn())	return;
	
	Rebalance();
}

public void OnPlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
	if (!JAIL_IsPluginOn() || IsWarmupPeriod())	return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	JAIL_PauseJailHud(client, false);
	
	RemoveGuns(client);
	SetEntProp(client, Prop_Send, "m_ArmorValue", 100, 1);
	
	SetEntityGravity(client, 1.0);
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
	
	if(GetClientTeam(client) == CS_TEAM_CT)
	{
		if(IsPlayerAlive(client))
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue") + 0.15);
	}
	
	SetEntityMoveType(client, MOVETYPE_ISOMETRIC);
	
	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	SetEntityRenderColor(client, 255, 255, 255, 255);
	
	// 노블럭
	SetEntData(client, g_offsCollision, 2, _, true);
}

public Action OnPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (!JAIL_IsPluginOn())	return Plugin_Continue;
	
	int Client = GetClientOfUserId(event.GetInt("userid"));
	int Team = event.GetInt("team");
	int OldTeam = event.GetInt("oldteam");
	
	if(!event.GetBool("silent"))
	{
		SetEventBroadcast(event, true);
		
		char oldteamColor[8];
		char newteamColor[8];
		char newteamName[32];
		
		if(OldTeam == 1)
			Format(oldteamColor, 8, "\x08");
		else if(OldTeam == 2)
			Format(oldteamColor, 8, "\x0F");
		else if(OldTeam == 3)
			Format(oldteamColor, 8, "\x0B");
			
		if(Team == 1){
			Format(newteamColor, 8, "\x08");
			Format(newteamName, sizeof(newteamName), "관전자");
		}
		else if(Team == 2){
			Format(newteamColor, 8, "\x0F");
			Format(newteamName, sizeof(newteamName), "죄수팀");
		}
		else if(Team == 3){
			Format(newteamColor, 8, "\x0B");
			Format(newteamName, sizeof(newteamName), "간수팀");
		}
		
		PrintToChatAll("%s %s%N\x01님이 %s%s\x01로 이동하셨습니다.", PREFIX, oldteamColor, Client, newteamColor, newteamName);
	}
		
				
	return Plugin_Continue;
}

public Action OnClientJoinTeam(int client, const char[] command, int args)
{
	if (!JAIL_IsPluginOn())	return Plugin_Continue;
	/*
	0 = Auto
	1 = Spec
	2 = T
	3 = CT
	
	카운터테러경우
	
	terror *= 2;
	terror /= 1;
	terror += 2;
	if(terror < counter)
	{
		ChangeClientTeam(client, CS_TEAM_T);
	}
	
	테러경우
	
	counter *= 1;
	counter /= 2;
	counter += 1;
	if(counter < terror)
	{
		ChangeClientTeam(client, CS_TEAM_CT);
	}
	*/  
	
	char Arg[8];
	GetCmdArg(1, Arg, sizeof(Arg));
	
	int clientteam = GetClientTeam(client);
	
	int terror, counter;
	terror = GetTeamClientCount(CS_TEAM_T);
	counter = GetTeamClientCount(CS_TEAM_CT);
	
	//자동조인을 선택했다
	if(StrEqual(Arg, "0")){
		
		//스펙터 팀인 경우
		if(clientteam == CS_TEAM_SPECTATOR || clientteam == CS_TEAM_NONE){
			
			//테러와 대테러가 합쳐서 2명이 안되는 경우, 즉 팀밸런스가 의미가 없는 상황인 경우
			//대테러가 없다면 대테러팀에, 대테러가 있다면 테러팀에 넣어야 한다
			if(terror + counter < 2){
				
				if(counter == 0){
					
					ChangeClientTeam(client, CS_TEAM_CT);
					PrintToChat(client, "%s 현재 아무도 없으므로 간수팀에 참가합니다", PREFIX);
					
				}else{
					
					ChangeClientTeam(client, CS_TEAM_T);
					PrintToChat(client, "%s 간수가 충분하므로 죄수팀에 참가합니다", PREFIX);
					
				}
				
			}else{
				
				//대테러와 테러가 합쳐서 2명 이상이다.
				
				//이 사람을 대테러에 넣어도 밸런스가 깨지지 않는다면, 대테러에 넣는다.
				//이 사람을 대테러에 넣을 경우 밸런스가 깨진다면, 테러팀에 넣는다
				//즉, 테러팀이 많은 상황은 허용해도, 대테러가 많은 상황은 허용하지 않는다
				
				if((counter + 1) * 2 <= terror + 1){
					
					ChangeClientTeam(client, CS_TEAM_CT);
					PrintToChat(client, "%s 죄수가 충분하므로 간수팀에 참가합니다", PREFIX);
					
				}else{
					
					ChangeClientTeam(client, CS_TEAM_T);
					PrintToChat(client, "%s 간수가 충분하므로 죄수팀에 참가합니다", PREFIX);
					
				}
				
			}
			
		}else if(clientteam == CS_TEAM_CT){
			
			//대테러팀인 경우, 자동 조인으로는 테러에 가는 경우만을 따진다
			//자신이 테러로 가도 대테러가 너무 적지 않다면, 테러로 팀을 바꿔준다
			terror *= 1;
			terror /= 2;
			terror += 1;
			if(terror < counter){
			
				ChangeClientTeam(client, CS_TEAM_T);
				
			}
			
		}else if(clientteam == CS_TEAM_T){
			
			//테러팀인 경우, 자동 조인으로는 대테러에 가는 경우만을 따진다.
			//자신이 대테러로 가도 테러가 너무 적지 않다면, 대테러로 팀을 바꿔준다
			counter *= 2;
			counter /= 1;
			counter += 2;
			if(counter < terror){
			
				ChangeClientTeam(client, CS_TEAM_CT);
				
			}
			
		}

	}else if(StrEqual(Arg, "2")){//테러팀에 조인을 시도한다
		
		//스펙터 팀인 경우
		if(clientteam == CS_TEAM_SPECTATOR || clientteam == CS_TEAM_NONE){
			
			//테러와 대테러가 합쳐서 2명이 안되는 경우, 즉 팀밸런스가 의미가 없는 상황인 경우
			//대테러가 없다면 대테러팀에, 대테러가 있다면 테러팀에 넣어야 한다
			if(terror + counter < 2){
				
				if(counter == 0){
					
					ChangeClientTeam(client, CS_TEAM_CT);
					PrintToChat(client, "%s 현재 아무도 없으므로 간수팀에 참가합니다", PREFIX);
					
				}else{
					
					ChangeClientTeam(client, CS_TEAM_T);
					
				}
				
			}else{
				
				//대테러와 테러가 합쳐서 2명 이상이다.
				
				//이 사람을 대테러에 넣어도 밸런스가 깨지지 않는다면, 대테러에 넣는다.
				//이 사람을 대테러에 넣을 경우 밸런스가 깨진다면, 테러팀에 넣는다
				//즉, 테러팀이 많은 상황은 허용해도, 대테러가 많은 상황은 허용하지 않는다
				
				if((counter + 1) * 2 <= terror + 1){
					
					ChangeClientTeam(client, CS_TEAM_CT);
					PrintToChat(client, "%s 죄수팀에 인원이 충분하므로 간수팀에 참가합니다", PREFIX);
					
				}else{
					
					ChangeClientTeam(client, CS_TEAM_T);
					
				}
				
			}
			
		}else if(clientteam == CS_TEAM_CT){
			
			//대테러팀인 경우, 자동 조인으로는 테러에 가는 경우만을 따진다
			//자신이 테러로 가도 대테러가 너무 적지 않다면, 테러로 팀을 바꿔준다
			if((counter - 1) * 2 + 1 >= terror + 1){
				
				ChangeClientTeam(client, CS_TEAM_T);
				
			}else{
				
				PrintToChat(client, "%s 죄수팀에 인원이 충분하므로 간수팀에 참가합니다", PREFIX);
				
			}
			
		}
		
	}else if(StrEqual(Arg, "3")){//대테팀에 조인하려고 시도하는 경우
		
		//스펙터 팀인 경우
		if(clientteam == CS_TEAM_SPECTATOR || clientteam == CS_TEAM_NONE){
			
			//테러와 대테러가 합쳐서 2명이 안되는 경우, 즉 팀밸런스가 의미가 없는 상황인 경우
			//대테러가 없다면 대테러팀에, 대테러가 있다면 테러팀에 넣어야 한다
			if(terror + counter < 2){
				
				if(counter == 0){
					
					ChangeClientTeam(client, CS_TEAM_CT);
					
				}else{
					
					ChangeClientTeam(client, CS_TEAM_T);
					PrintToChat(client, "%s 간수팀에 인원이 충분하므로 죄수팀에 참가합니다", PREFIX);
					
				}
				
			}else{
				
				//대테러와 테러가 합쳐서 2명 이상이다.
				
				//이 사람을 대테러에 넣어도 밸런스가 깨지지 않는다면, 대테러에 넣는다.
				//이 사람을 대테러에 넣을 경우 밸런스가 깨진다면, 테러팀에 넣는다
				//즉, 테러팀이 많은 상황은 허용해도, 대테러가 많은 상황은 허용하지 않는다
				
				if((counter + 1) * 2 <= terror + 1){
					
					ChangeClientTeam(client, CS_TEAM_CT);
					
				}else{
					
					ChangeClientTeam(client, CS_TEAM_T);
					PrintToChat(client, "%s 간수팀에 인원이 충분하므로 죄수팀에 참가합니다", PREFIX);
					
				}
				
			}
			
		}else if(clientteam == CS_TEAM_T){
			
			//자신이 대테러로 가도 테러가 너무 적지 않다면, 대테러로 팀을 바꿔준다
			//아래의 수식은 세련되지 않은 부분이 있지만, 남겨둔다
			if(terror + counter < 2){
			
				ChangeClientTeam(client, CS_TEAM_CT);
				
			}else{
				
				if((counter + 1) * 2 <= terror + 1 - 1){
					
					ChangeClientTeam(client, CS_TEAM_CT);
					
				}else{
					
					PrintToChat(client, "%s 간수팀에 인원이 충분하므로 죄수팀에 참가합니다", PREFIX);
					
				}
				
			}
			
		}
		
	}else if(StrEqual(Arg, "1")){//관전자로 접속하려고 하는 경우
		
		//현재 팀이 관전자인 것만 아니라면, 관전자로 가는 것은 언제나 허용된다
		//구경할 사람은 언제나 구경해야 한다
		if(GetClientTeam(client) != CS_TEAM_SPECTATOR){
			
			ChangeClientTeam(client, CS_TEAM_SPECTATOR);
				
		}
		
	}else if(StrEqual(Arg, "7")){
		
		ChangeClientTeam(client, CS_TEAM_T);
		
	}else if(StrEqual(Arg, "8")){
		
		ChangeClientTeam(client, CS_TEAM_CT);
		
	}
	
	return Plugin_Handled;
}

public Action OnClientChat(int client, const char[] command, int Arg)
{
	if (!JAIL_IsPluginOn() || JAIL_IsJailActionPaused() || IsWarmupPeriod())	return Plugin_Continue;
	
	char Msg[256];
	GetCmdArgString(Msg, sizeof(Msg));
	int length = strlen(Msg);
	if(length <= 0)
		return Plugin_Continue;
		
	Msg[length-1] = '\0';
	
	if(StrEqual(Msg[1], "!명령", false))
	{
		if(IsPlayerAlive(client))
		{
			if(GetClientTeam(client) == 3)
			{
				Cmd_CommandMenu(client, 0);
			}
		}
	}

	char cmdbuffer[256];
	strcopy(cmdbuffer, sizeof(cmdbuffer), Msg[1]);
	StripQuotes(cmdbuffer);
	TrimString(cmdbuffer);
	
	if(StrContains(cmdbuffer, "#", false) == 0)
	{
		if(IsValidPlayer(client) && GetClientTeam(client) == CS_TEAM_CT)
		{
			//명령을 기록
			ReplaceStringEx(cmdbuffer, sizeof(cmdbuffer), "#", "");
			Format(g_szGuardCommand, sizeof(g_szGuardCommand), "%s", cmdbuffer);
			EmitSoundToAll(SOUND_GUARD_COMMAND, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
		}
	}
	
	return Plugin_Continue;
}

/*******************************************************
 빠른 명령 메뉴
*******************************************************/
public Action Cmd_CommandMenu(int client, int args)
{
	if (!JAIL_IsPluginOn() || JAIL_IsJailActionPaused() || IsWarmupPeriod())	return Plugin_Stop;
	
	if(GetClientTeam(client) == 3 && IsPlayerAlive(client))
	{
		if(g_szQuickGuardCommandCooldown[client] > GetGameTime())
		{
			PrintHintText(client, "메뉴 명령은 %.1f초 후에 다시 사용할 수 있습니다.", g_szQuickGuardCommandCooldown[client] - GetGameTime());
			return Plugin_Handled;
		}
		
		Menu menu = new Menu(cmdmenuhandler);
		
		menu.SetTitle("*** 간수 명령 ***");
		
		char AName[128];
		Format(AName, sizeof(Alarm_Name[]), "%s 명령", Alarm_Name[Cmd_MoveBoxRoom]);
		if(Alarm_Firing[Cmd_MoveBoxRoom])
		{
			menu.AddItem("BoxRoomCmd", AName);
		}
		else
		{
			menu.AddItem("BoxRoomCmd", AName, ITEMDRAW_DISABLED);
		}
		
		Format(AName, sizeof(Alarm_Name[]), "%s 명령", Alarm_Name[Cmd_Move]);
		if(Alarm_Fired[Cmd_MoveBoxRoom])
		{
			menu.AddItem("MoveCmd", AName);
		}
		else if(Alarm_Firing[Cmd_Move])
		{
			menu.AddItem("MoveCmd", AName);
		}
		else
		{
			menu.AddItem("MoveCmd", AName, ITEMDRAW_DISABLED);
		}
		
		Format(AName, sizeof(AName), "%s 명령", Alarm_Name[Cmd_Torture]);
		if(Alarm_Fired[Cmd_Move])
		{
			menu.AddItem("TortureCmd", AName);
		}
		else if(Alarm_Firing[Cmd_Torture])
		{
			menu.AddItem("TortureCmd", AName);
		}
		else
		{
			menu.AddItem("TortureCmd", AName, ITEMDRAW_DISABLED);
		}
		
		menu.AddItem("FreeTimeCmd", "자유시간 명령");
		
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public int cmdmenuhandler(Menu menu, MenuAction action, int client, int select)
{
	if (!JAIL_IsPluginOn() || JAIL_IsJailActionPaused() || IsWarmupPeriod())	return;
	
	if(action == MenuAction_Select && GetClientTeam(client) == 3 && IsPlayerAlive(client))
	{
		char info[128];
		GetMenuItem(menu, select, info, sizeof(info));
		if(StrEqual(info, "BoxRoomCmd", false))
		{
			if(Alarm_Firing[Cmd_MoveBoxRoom])
			{
				char Cmd_SendString[512];
				Format(Cmd_SendString, sizeof(Cmd_SendString), "6분까지 상자방/새면 경고/6분이후 상자방밖, 총기, 고접 사살");
				CommandCmdSend(client, Cmd_SendString);
			}
			else	Cmd_CommandMenu(client, 0);
		}
		else if(StrEqual(info, "MoveCmd", false))
		{
			if(Alarm_Firing[Cmd_Move])
			{
				CommandCmdDetail(client, _:Cmd_Move);
			}
			else	Cmd_CommandMenu(client, 0);
		}
		else if(StrEqual(info, "TortureCmd", false))
		{
			if(Alarm_Firing[Cmd_Torture])
			{
				CommandCmdDetail(client, _:Cmd_Torture);
			}
			else	Cmd_CommandMenu(client, 0);
		}
		else if(StrEqual(info, "FreeTimeCmd", false))
		{
			char Cmd_SendString[512];
			Format(Cmd_SendString, sizeof(Cmd_SendString), "자유시간 고의적 접근 사살");
			CommandCmdSend(client, Cmd_SendString);
		}
	}
	if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

void CommandCmdDetail(int client, int CmdType, int Detail_1=0, int Detail_2=0)
{
	if (!JAIL_IsPluginOn() || JAIL_IsJailActionPaused() || IsWarmupPeriod())	return;
	
	if(GetClientTeam(client) == 3 && IsPlayerAlive(client))
	{
		Menu menu = new Menu(cmddetailmenuhandler);
		
		char AName[128];
		Format(AName, sizeof(AName), "%s 명령", Alarm_Name[CmdType]);
		menu.SetTitle("*** %s ***", AName);
		
		char infoString[16];
		Format(infoString, sizeof(infoString), "%i|%i|%i", CmdType, Detail_1, Detail_2);
		
		if(CmdType == _:Cmd_Move)
		{
			if(Detail_1 == 0)
				menu.AddItem(infoString, "[  ] 앉아서 이동");
			else if(Detail_1 == 1)
				menu.AddItem(infoString, "[√] 앉아서 이동");
			
			menu.AddItem(infoString, "축구장");
			menu.AddItem(infoString, "수영장");
			menu.AddItem(infoString, "놀이터");
			menu.AddItem(infoString, "클럽");
			if(Detail_1 == 0)
				menu.AddItem(infoString, "줄넘기장");
			else if(Detail_1 == 1)
				menu.AddItem(infoString, "줄넘기장", ITEMDRAW_DISABLED);
			menu.AddItem(infoString, "체력장");
		}
		
		if(CmdType == _:Cmd_Torture)
		{
			if(Detail_1 == 0)
					menu.AddItem(infoString, "[  ] 이동장소와 목적지가 동일");
			else if(Detail_1 == 1)
				menu.AddItem(infoString, "[√] 이동장소와 목적지가 동일");
				
			if(Detail_2 == 0)
				menu.AddItem(infoString, "[  ] 현재 자유시간");
			else if(Detail_2 == 1)
				menu.AddItem(infoString, "[√] 현재 자유시간");
			
			menu.AddItem(infoString, "수영장");
			menu.AddItem(infoString, "줄넘기장");
			menu.AddItem(infoString, "범퍼카장");
		}
			
		
		menu.ExitButton = true;
		menu.ExitBackButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

public int cmddetailmenuhandler(Menu menu, MenuAction action, int client, int select)
{
	if (!JAIL_IsPluginOn() || JAIL_IsJailActionPaused() || IsWarmupPeriod())	return;
	
	if(action == MenuAction_Select && GetClientTeam(client) == 3 && IsPlayerAlive(client))
	{
		char info[64], display[64], InfoDetail[3][16];
		GetMenuItem(menu, select, info, sizeof(info), _, display, sizeof(display));
		ExplodeString(info, "|", InfoDetail, 3, 16);
		int CmdType, Detail_1, Detail_2;
		
		CmdType = StringToInt(InfoDetail[0]);
		Detail_1 = StringToInt(InfoDetail[1]);
		Detail_2 = StringToInt(InfoDetail[2]);
		if(CmdType == _:Cmd_Move)
		{
			if(select == 0)
			{
				if(Detail_1 == 0)
					Detail_1 = 1;
				else if(Detail_1 == 1)
					Detail_1 = 0;
				
				CommandCmdDetail(client, CmdType, Detail_1);
			}
			else 
			{
				char Cmd_Command[512];
				if(StrEqual(display, "축구장", false))
				{
					if(Detail_1 == 0)
						Format(Cmd_Command, sizeof(Cmd_Command), "4분에 축구장으로출발/새거나 고접사살/3분30초 축구장선밖사살");
					else if(Detail_1 == 1)
						Format(Cmd_Command, sizeof(Cmd_Command), "4분에 앉아서 축구장으로출발/새거나 고접사살/3분10초 축구장선밖사살");
				}
				if(StrEqual(display, "수영장", false))
				{
					if(Detail_1 == 0)
						Format(Cmd_Command, sizeof(Cmd_Command), "4분에 수영장으로출발/새거나 고접사살/3분30초 까지 입수/물밖사살");
					else if(Detail_1 == 1)
						Format(Cmd_Command, sizeof(Cmd_Command), "4분에 앉아서 수영장으로출발/새거나 고접사살/3분10초 입수/물밖사살");
				}
				if(StrEqual(display, "놀이터", false))
				{
					if(Detail_1 == 0)
						Format(Cmd_Command, sizeof(Cmd_Command), "4분에 놀이터로출발/새거나 고접사살/3분30초 놀이터 밖사살");
					else if(Detail_1 == 1)
						Format(Cmd_Command, sizeof(Cmd_Command), "4분에 앉아서 놀이터로출발/새거나 고접사살/3분10초 놀이터 밖사살");
				}
				if(StrEqual(display, "클럽", false))
				{
					if(Detail_1 == 0)
						Format(Cmd_Command, sizeof(Cmd_Command), "4분에 클럽으로출발/새거나 고접사살/3분30초 클럽 밖사살");
					else if(Detail_1 == 1)
						Format(Cmd_Command, sizeof(Cmd_Command), "4분에 앉아서 클럽으로출발/새거나 고접사살/3분10초 클럽 밖사살");
				}
				if(StrEqual(display, "줄넘기장", false))
				{
					if(Detail_1 == 0)
						Format(Cmd_Command, sizeof(Cmd_Command), "4분에 줄넘기장으로 출발/새거나 고접사살/3분30초 줄넘기장 밖사살");
					else if(Detail_1 == 1)
						Format(Cmd_Command, sizeof(Cmd_Command), "4분에 앉아서 줄넘기장으로출발/새거나 고접사살/3분10초 줄넘기장 밖사살");
				}
				if(StrEqual(display, "체력장", false))
				{
					if(Detail_1 == 0)
						Format(Cmd_Command, sizeof(Cmd_Command), "4분에 체력장 출발/새거나 고접사살/3분30초 체력장 밖사살");
					else if(Detail_1 == 1)
						Format(Cmd_Command, sizeof(Cmd_Command), "4분에 앉아서 체력장 출발/새거나 고접사살/3분10초 체력장 밖사살");
				}
				
				CommandCmdSend(client, Cmd_Command);
			}
		}
		if(CmdType == _:Cmd_Torture)
		{
			if(select == 0)
			{
				if(Detail_1 == 0)
				{
					Detail_1 = 1;
					Detail_2 = 0;
				}
				else if(Detail_1 == 1)
					Detail_1 = 0;
			
				CommandCmdDetail(client, CmdType, Detail_1, Detail_2);
			}
			else if(select == 1)
			{
				if(Detail_2 == 0)
				{
					Detail_2 = 1;
					Detail_1 = 0;
				}
				else if(Detail_2 == 1)
					Detail_2 = 0;
				
				CommandCmdDetail(client, CmdType, Detail_1, Detail_2);
			}
			else 
			{					
				char Cmd_Command[512];
				if(StrEqual(display, "수영장", false))
				{
					if(Detail_1 == 0 && Detail_2 == 0)
						Format(Cmd_Command, sizeof(Cmd_Command), "1분40초에 수영장출발/새거나 고접사살/1분부터잠수/머리나올시사살");
					else if(Detail_1 == 1)
						Format(Cmd_Command, sizeof(Cmd_Command), "수영장대기 / 새거나 고접사살 / 1분부터잠수 / 머리나올시사살");
					else if(Detail_2 == 1)
						Format(Cmd_Command, sizeof(Cmd_Command), "수영장으로 출발 / 1분부터잠수 / 머리나올시사살");
				}
				if(StrEqual(display, "줄넘기장", false))
				{
					if(Detail_1 == 0 && Detail_2 == 0)
						Format(Cmd_Command, sizeof(Cmd_Command), "1분40초에 줄넘기장으로 출발/새거나 고접사살/1분이후 줄넘기장 밖사살");
					else if(Detail_1 == 1)
						Format(Cmd_Command, sizeof(Cmd_Command), "줄넘기장대기 / 새거나 고접사살 / 1분이후 줄넘기장 밖사살");
					else if(Detail_2 == 1)
						Format(Cmd_Command, sizeof(Cmd_Command), "줄넘기장으로 출발 / 1분이후 줄넘기장 밖사살");
				}
				if(StrEqual(display, "범퍼카장", false))
				{
					if(Detail_1 == 0 && Detail_2 == 0)
						Format(Cmd_Command, sizeof(Cmd_Command), "1분40초에 범퍼카장으로 출발/새거나 고접사살/1분이후 범퍼카장 밖사살");
					else if(Detail_1 == 1)
						Format(Cmd_Command, sizeof(Cmd_Command), "범퍼카장대기 / 새거나 고접사살 / 1분이후 범퍼카장 밖사살");
					else if(Detail_2 == 1)
						Format(Cmd_Command, sizeof(Cmd_Command), "범퍼카장으로 출발 / 1분이후 범퍼카장 밖사살");
				}
				
				CommandCmdSend(client, Cmd_Command);
			}
		}
	}
	if(action == MenuAction_Cancel)
	{
		if(select == MenuCancel_ExitBack)
		{
			Cmd_CommandMenu(client, 0);
		}
	}
	if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}		

public void CommandCmdSend(int client, const char[] Command)
{
	if(/*!InKnifeFighting() && */GetClientTeam(client) == 3 && IsPlayerAlive(client))
	{
		FakeClientCommand(client, "say \"#%s\"", Command);
		g_szQuickGuardCommandCooldown[client] = GetGameTime()+15.0;
	}
}

/*******************************************************
	팀 밸런스
*******************************************************/
public void JAIL_OnQuickSwapPost()
{
	if (!JAIL_IsPluginOn())	return;
    	Rebalance();
}

// 간수 1명당 죄수의 수
#define PRISONER_RATIO 2
void Rebalance()
{
	//자동팀밸런스 설정
	int terror, counter;
	terror = GetTeamClientCount(2);
	counter = GetTeamClientCount(3);
	
	//최소 3명이 게임을 하고있는 경우
	if(terror + counter >= 3)
	{
		int breaker = 0;
		//대테러의 2배가 테러 + 1 보다 많을 경우(테러가 너무 적을때)
		while(counter * PRISONER_RATIO > terror + 1)
		{
			int select; // 팀 이동의 대상
			if(JAIL_IsSwapListExist(CS_TEAM_CT)) // CT팀에 팀 변경을 원하는 인원이 있을경우.
			{
				select = JAIL_GetFirstListed(CS_TEAM_CT);// CT팀에 팀 변경을 원하는 인원 목록에서 첫번째 순번을 가져온다.
				if(select != -1 && IsValidClient(select))
				{
					CS_SwitchTeam(select, CS_TEAM_T);
					PrintToChatAll("%s %N 님은 팀설정에 의해 죄수팀이 되었습니다.", PREFIX, select);
					PrintCenterText(select, "당신은 팀설정에 의해 죄수팀이 되었습니다.");
				}
				else
				{
					JAIL_EraseClientOnList(select);
					continue;
				}
			}
			else // CT팀에 팀 변경을 원하는 인원이 없을경우
			{
				// 간수팀에서 한 명을 임의로 선출.
				select = GetRandomPlayer(CLIENTFILTER_INGAME | CLIENTFILTER_TEAMTWO);
				
				if(IsValidClient(select))
				{
					CS_SwitchTeam(select, CS_TEAM_T);
					PrintToChatAll("%s %N 님은 자동 팀설정에 의해 죄수팀이 되었습니다.", PREFIX, select);
					PrintCenterText(select, "당신은 자동 팀설정에 의해 죄수팀이 되었습니다.");
				}
			}
			// 다음 반복을 위해 팀 인원수를 다시 얻어온다.
			terror = GetTeamClientCount(2);
			counter = GetTeamClientCount(3);

			breaker++;
			if(breaker >= MaxClients)
			{
				LogError("Rebalance Force Breaker Activated in CT -> T Balancing! MaxClients: %i(T: %i | CT: %i)", MaxClients, terror, counter);
				break;
			}
		}
		breaker = 0;
		//테러가 대테러의 2배 + 1보다 많을 경우(테러가 너무 많을때)
		while((counter * PRISONER_RATIO) + 1 < terror)
		{
			int select; // 팀 이동의 대상
			if(JAIL_IsSwapListExist(CS_TEAM_T)) // T팀에 팀 변경을 원하는 인원이 있을경우.
			{
				select = JAIL_GetFirstListed(CS_TEAM_T); // T팀에 팀 변경을 원하는 인원 목록에서 첫번째 순번을 가져온다.
				if(select != -1 && IsValidClient(select))
				{
					CS_SwitchTeam(select, CS_TEAM_CT);
					PrintToChatAll("%s %N 님은 팀설정에 의해 간수팀이 되었습니다.", PREFIX, select);
					PrintCenterText(select, "당신은 팀설정에 의해 간수팀이 되었습니다.");
				}
				else
				{
					JAIL_EraseClientOnList(select);
					continue;
				}
			}
			else // 없을경우
			{
				// 죄수팀에서 한 명을 임의로 선출.
				select = GetRandomPlayer(CLIENTFILTER_INGAME | CLIENTFILTER_TEAMONE);
				
				if(IsValidClient(select))
				{
					CS_SwitchTeam(select, CS_TEAM_CT);
					PrintToChatAll("%s %N 님은 자동 팀설정에 의해 간수팀이 되었습니다.", PREFIX, select);
					PrintCenterText(select, "당신은 자동 팀설정에 의해 간수팀이 되었습니다.");
				}
			}
			// 다음 반복을 위해 팀 인원수를 다시 얻어온다.
			terror = GetTeamClientCount(2);
			counter = GetTeamClientCount(3);

			breaker++;
			if(breaker >= MaxClients)
			{
				LogError("Rebalance Force Breaker Activated! in T -> CT Balancing! MaxClients: %i(T: %i | CT: %i)", MaxClients, terror, counter);
				break;
			}
		}
	}
}

/*******************************************************
 네이티브, 포워드 함수
*******************************************************/
/* 네이티브 - JAIL_IsPluginOn */
public int Native_JAIL_IsPluginOn(Handle plugin, int numParams)
{
	return GetConVarBool(g_cvarConvar[PLUGIN_ENABLE]);
}

/* 네이티브 - JAIL_IsClientVIP */
public int Native_JAIL_IsClientVIP(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_bVIPUser[client];
}

/* 네이티브 - JAIL_IsJailActionPaused */
public int Native_JAIL_IsJailActionPaused(Handle plugin, int numParams)
{
	return g_bJailActionPaused;
}

/* 네이티브 - JAIL_PauseJailAction */
public int Native_JAIL_PauseJailAction(Handle plugin, int numParams)
{
	bool pause = view_as<bool>(GetNativeCell(1));
	g_bJailActionPaused = pause;
}

/* 네이티브 - JAIL_IsJailHudPaused */
public int Native_JAIL_IsJailHudPaused(Handle plugin, int numParams)
{
	int client = (GetNativeCell(1));
	return g_bJailHudPaused[client];
}

/* 네이티브 - JAIL_PauseJailHud */
public int Native_JAIL_PauseJailHud(Handle plugin, int numParams)
{
	int client = (GetNativeCell(1));
	bool pause = view_as<bool>(GetNativeCell(2));
	g_bJailHudPaused[client] = pause;
}

/* 네이티브 - JAIL_SetRebelable */
public int Native_JAIL_SetRebelable(Handle plugin, int numParams)
{
	bool rebelable = view_as<bool>(GetNativeCell(1));
	
	g_bRebelableTime = rebelable;
}

/* 네이티브 - JAIL_IsRebelable */
public int Native_JAIL_IsRebelable(Handle plugin, int numParams)
{
	return g_bRebelableTime;
}