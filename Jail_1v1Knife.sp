EngineVersion g_Game;

#pragma semicolon 1

//#define DEBUG

/* TODO LIST:
 * 1. 베팅 추가
 * 2. 1v1 수락/거절 제한 시간(초과 시 거절)(?)
 *
 */

#define PREFIX 	"\x01[\x0BJAIL\x01] :\x05"

#define PLUGIN_AUTHOR "Trostal"
#define PLUGIN_VERSION "0.01a"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>

#include <emitsoundany>

#undef REQUIRE_PLUGIN
#include "Jail_Mod.inc"

// 1v1 상황이 될 수 있는 최소 플레이어 수
#define MIN_PLAYERS_TO_1V1	3

// 1v1 상황이 된 후, 투표가 시작되기 까지의 딜레이
#define TIME_1V1_WAITING_VOTE_TIME	5.0

// 1v1이 성립된 후, 칼전이 시작되기까지의 딜레이
#define TIME_1V1_WAITING_START_TIME	5.0

// 1v1 상황에서 이 시간(초)까지 결판을 짓지 않으면 두 명 다 슬레이
#define TIME_1V1_TIME_LIMIT 	40.0

bool g_b1v1Fight = false;
bool g_b1v1FightVote = false;
float g_fl1v1StartTime = 0.0;
float g_fl1v1TimeLimit = 0.0;

int g_nTerrorLastIndex = INVALID_ENT_REFERENCE;
int g_nCTerrorLastIndex = INVALID_ENT_REFERENCE;

int g_i1v1FightAccept[2] =  { 0, 0 };

Handle g_fwdOn1v1FightOccurred = null;

float g_fl1v1VoteMenuDisplayTime[MAXPLAYERS + 1];

int g_iToolsVelocity;

/**************************
 사운드 변수 정의
**************************/
#define SOUND_KNIFE_KNOCKBACK	"ambient/explosions/explode_7.mp3"
#define SOUND_1V1_ACCEPT		"ui/achievement_earned.wav"
#define SOUND_CAN_MOVE			"ui/armsrace_level_up.wav"
#define SOUND_1V1_START			"ui/bonus_alert_start.wav"

/**************************
 비콘 관련 변수 정의
**************************/
char g_BlipSound[PLATFORM_MAX_PATH];
int g_BeamSprite        = -1;
int g_HaloSprite        = -1;

int redColor[4]		= {255, 75, 75, 255};
int greenColor[4]	= {75, 255, 75, 255};
int blueColor[4]	= {75, 75, 255, 255};
int greyColor[4]	= {128, 128, 128, 255};

public Plugin myinfo = 
{
	name = "[JAIL] Last One Stand 1v1 Fight",
	author = PLUGIN_AUTHOR,
	description = "양 팀에 마지막 한 명만 남았을 시 대결을 담당합니다.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Hatser/Jail-Mod"
};

public void OnMapStart()
{
	PrecacheSound("ambient/creatures/chicken_death_01.wav");
	PrecacheSound("ambient/creatures/chicken_death_02.wav");
	PrecacheSound("ambient/creatures/chicken_death_03.wav");
	PrecacheSound("ambient/creatures/chicken_fly_long.wav");
	
	PrecacheSound(SOUND_1V1_ACCEPT); // 동의 사운드
	PrecacheSound(SOUND_CAN_MOVE); // 이동 가능 상황
	PrecacheSound(SOUND_1V1_START); // 1v1 시작
	
	PrepareSound(SOUND_KNIFE_KNOCKBACK);
	
	InitBeaconVars();
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


public void OnPluginStart()
{
	g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO)
	{
		SetFailState("This plugin is for CSGO only.");	
	}
	
	RegConsoleCmd("sm_1v1", Cmd_1v1FightVoteMenu, "상점 명령어");
	
	AddCommandListener(SayHook, "say");
	AddCommandListener(SayHook, "say_team");
	
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("round_start", OnRoundStart);
	HookEvent("round_end", OnRoundEnd);
	
	g_iToolsVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
	if (g_iToolsVelocity == -1)
	{
		LogError("Offset \"CBasePlayer::m_vecVelocity[0]\" was not found.");
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{	
	g_fwdOn1v1FightOccurred = CreateGlobalForward("JAIL_On1v1FightOccurred", ET_Ignore, Param_Cell, Param_Cell);
	
	RegPluginLibrary("BSTJail");
	return APLRes_Success;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	
	// 1v1이 진행중이 아닐때
	if(IsValidPlayer(client) && !g_b1v1Fight)
	{
		if(GetPlayerCount() >= MIN_PLAYERS_TO_1V1)
			CheckLastStand();
	}
}

public Action SayHook(int client, const char[] command, int args)
{
	if (!JAIL_IsPluginOn() || JAIL_IsJailActionPaused() || IsWarmupPeriod())	return Plugin_Continue;
	if (!g_b1v1FightVote)	return Plugin_Continue;
	
	char Msg[256];
	GetCmdArgString(Msg, sizeof(Msg));
	Msg[strlen(Msg)-1] = '\0';

	if(StrEqual(Msg[1], "!칼전", false) || StrEqual(Msg[1], "!1대1", false) || StrEqual(Msg[1], "!일대일", false))
	{
		Cmd_1v1FightVoteMenu(client, 0);
	}
	
	return Plugin_Continue;
}

public Action JAIL_OnShopCommand(int client)
{
	if (!g_b1v1FightVote)	return Plugin_Continue;
	
	if (client != g_nTerrorLastIndex && client != g_nTerrorLastIndex)
		return Plugin_Continue;
	
	if (g_i1v1FightAccept[GetClientTeam(client) - 2] != 0)
		return Plugin_Continue;
	
	Cmd_1v1FightVoteMenu(client, 0);
	return Plugin_Stop;
}

/*******************************************************
 OnGameFrame()
*******************************************************/
public void OnGameFrame()
{
	if (!JAIL_IsPluginOn() || !JAIL_IsJailActionPaused() || IsWarmupPeriod())	return;
	
	if(g_b1v1Fight)
	{
		if(g_fl1v1StartTime > 0.0)
		{
			float flGameTime = GetGameTime();
			if(g_fl1v1StartTime > flGameTime)
			{
				if(g_fl1v1StartTime - flGameTime > TIME_1V1_WAITING_START_TIME/2)
				{
					PrintCenterTextAll("1:1 칼전이 <font color='#ff0f0f' size='25'>%.1f</font>초 후 시작됩니다!", g_fl1v1StartTime - flGameTime);
				}
				else
				{
					PrintCenterTextAll("1:1 칼전이 <font color='#ff0f0f' size='25'>%.1f</font>초 후 시작됩니다!\n<font color='#ffff0f' size='20'>이제 움직일 수 있습니다!</font>", g_fl1v1StartTime - flGameTime);
				}
			}
			else // 딜레이 끝, 메뉴 출력
			{
				g_fl1v1StartTime = 0.0;
				
				PrintCenterTextAll("<font color='#ff0f0f' size='25'>1:1 칼전이 시작되었습니다!</font>");
				g_fl1v1TimeLimit = flGameTime + TIME_1V1_TIME_LIMIT;
				ReleaseFighters();
			}
		}
		
		if(g_fl1v1TimeLimit > 0.0)
		{
			float flGameTime = GetGameTime();
			if(g_fl1v1TimeLimit > flGameTime)
			{
				PrintCenterTextAll("1:1 칼전 종료까지 <font color='#ffff0f' size='25'>%.1f</font>초 남았습니다!", g_fl1v1TimeLimit - flGameTime);
			}
			else // 딜레이 끝, 메뉴 출력
			{
				g_fl1v1TimeLimit = -1.0; // 시간이 다 되었을 때에는 -1.0으로 두도록 함.
				
				SlayAll();
			}
		}
	}
}

/*******************************************************
 OnPlayerRunCmd()
*******************************************************/
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!JAIL_IsPluginOn() || JAIL_IsJailActionPaused() || IsWarmupPeriod())	return Plugin_Continue;
	
	if (!IsValidClient(client))	return Plugin_Continue;
	
	if (!g_b1v1Fight && g_b1v1FightVote)
	{
		if(g_fl1v1VoteMenuDisplayTime[client] > 0.0)
		{
			if(g_fl1v1VoteMenuDisplayTime[client] > GetGameTime())
			{
				PrintCenterText(client, "1:1 칼전 여부를 결정하는 투표가 <font color='#0fff0f' size='25'>%.1f</font>초 후 진행됩니다.", g_fl1v1VoteMenuDisplayTime[client] - GetGameTime());
			}
			else // 딜레이 끝, 메뉴 출력
			{
				g_fl1v1VoteMenuDisplayTime[client] = 0.0;
				Menu_1v1FightVote(client);
			}
		}		
	}
	
	return Plugin_Continue;
}

/*******************************************************
 OnTakeDamage()
*******************************************************/
public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!JAIL_IsPluginOn() || !JAIL_IsJailActionPaused() || IsWarmupPeriod())	return Plugin_Continue;
	
	if (!g_b1v1Fight)	return Plugin_Continue;
	
	if(!IsValidPlayer(victim))
		return Plugin_Continue;
		
	/* 이후 필요하다면,
	 * 이곳에 플레이어 이외의 사유로 공격당했을 때의 코드 삽입
	 */
		
	if(!IsValidPlayer(attacker))
		return Plugin_Continue;
	
	int victimTeam = GetClientTeam(victim);
	int attackerTeam = GetClientTeam(attacker);
	
	// 같은팀끼리 공격(???)을 막아준다.. 애초에 그럴리는 없지만..
	if(victimTeam == attackerTeam)
		return Plugin_Stop;
	/*
	EmitSoundToAll(knife, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
	Format(lastactionstatus, 80, "%s (HP: %i) : (%i :HP) %s", T_Name, GetClientHealth(T_Representative), GetClientHealth(CT_Representative), CT_Name);
	Format(lastroundstatus, 100, "1:1 칼전이 진행중입니다.");
	*/
	int victimTeamColor;
	int attackerTeamColor;
	
	if(victimTeam == CS_TEAM_T)
		victimTeamColor = 0xFF4040;
	else if(victimTeam == CS_TEAM_CT)
		victimTeamColor = 0x99CCFF;
	
	if(attackerTeam == CS_TEAM_T)
		attackerTeamColor = 0xFF4040;
	else if(attackerTeam == CS_TEAM_CT)
		attackerTeamColor = 0x99CCFF;
	
	PrintHintTextToAll("<font color='#%06X'>%N</font>님이 <font color='#%06X'>%N</font>님에게 한방!", victimTeamColor, attacker, attackerTeamColor, victim);
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

/*******************************************************
 OnClientCanUseWeapon()
*******************************************************/
public Action OnClientCanUseWeapon(int client, int weapon)
{
	if (g_b1v1Fight)
	{
		char szClassname[64];
		if (GetEdictClassname(weapon, szClassname, sizeof(szClassname)))
			if (!StrEqual(szClassname[7], "knife"))
			return Plugin_Handled;
	}
	return Plugin_Continue;
}
/*******************************************************
 메뉴 함수
*******************************************************/
public Action Cmd_1v1FightVoteMenu(int client, int args)
{
	if (!g_b1v1FightVote)	return Plugin_Continue;
	
	if (client != g_nTerrorLastIndex && client != g_nTerrorLastIndex)
		return Plugin_Continue;
	
	if (g_i1v1FightAccept[GetClientTeam(client) - 2] != 0)
		return Plugin_Continue;
	
	Menu_1v1FightVote(client);
	return Plugin_Stop;
}

void Menu_1v1FightVote(int client)
{
	if(IsValidPlayer(client))
	{
		int team = GetClientTeam(client);
		if(!IsFakeClient(client))
		{
			Menu menu = new Menu(Handler_1v1FightVote);
			
			int opponent;
			
			if(team == CS_TEAM_T)
				opponent = g_nCTerrorLastIndex;
			else if(team == CS_TEAM_CT)
				opponent = g_nTerrorLastIndex;
			
			menu.SetTitle("%N님과 1:1 칼전을 진행하시겠습니까?", opponent);
			
			menu.AddItem("Yes", "예!");
			menu.AddItem("No", "아니오...");
			
			menu.ExitButton = false;
			menu.ExitBackButton = false;
		
			menu.Display(client, MENU_TIME_FOREVER);
		}
		else
		{
			g_i1v1FightAccept[team - 2] = 1;
			PrintToChatAll("%s %N님이 1:1 칼전에 동의하셨습니다.", PREFIX, client);
			EmitSoundToAll(SOUND_1V1_ACCEPT, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, _ ,_ , GetRandomInt(95, 105));
		}
	}
}

public int Handler_1v1FightVote(Menu menu, MenuAction action, int client, int select)
{
	if (!JAIL_IsPluginOn() || IsWarmupPeriod())	return;
	if (!g_b1v1FightVote)	return;
	
	if(action == MenuAction_Select)
	{
		int opponent;
		int team = GetClientTeam(client);
		
		if(team == CS_TEAM_T)
			opponent = g_nCTerrorLastIndex;
		else if(team == CS_TEAM_CT)
			opponent = g_nTerrorLastIndex;
			
		if(!IsValidPlayer(opponent))
		{
			g_b1v1FightVote = false;
			return;
		}
		
		// 예
		if(select == 0)
		{
			g_i1v1FightAccept[team - 2] = 1;
			PrintToChatAll("%s %N님이 1:1 칼전에 동의하셨습니다.", PREFIX, client);
			EmitSoundToAll(SOUND_1V1_ACCEPT, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, _ ,_ , GetRandomInt(95, 105));
			
			// 감옥 Hud 다시 실행
			JAIL_PauseJailHud(client, false);
			// TODO SOUND
			
			if(g_i1v1FightAccept[0] == 1 && g_i1v1FightAccept[1] == 1)
			{
				PrintToChatAll("%s 양 측 모두 동의하셨으므로, 1:1 칼전이 시작됩니다.", PREFIX);
				Proceed1v1Fight(opponent, client);
				
				g_b1v1FightVote = false;
			}
		}
		// 아니오
		else if(select == 1)
		{
			PrintToChatAll("%s %N님이 1:1 칼전에 거절하셨습니다.", PREFIX, client);
			
			int soundRandom = GetRandomInt(1, 4);
			char DenySoundPath[128];
			if(soundRandom < 4)
				Format(DenySoundPath, sizeof(DenySoundPath), "ambient/creatures/chicken_death_0%d.wav", soundRandom);
			else
				Format(DenySoundPath, sizeof(DenySoundPath), "ambient/creatures/chicken_fly_long.wav");
				
			EmitSoundToAll(DenySoundPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, _ ,_ , GetRandomInt(95, 105));
			g_b1v1FightVote = false;
			g_i1v1FightAccept[0] = 0;
			g_i1v1FightAccept[1] = 0;
			// 감옥 Hud 다시 실행
			JAIL_PauseJailHud(client, false);
			JAIL_PauseJailHud(opponent, false);
			
			CancelClientMenu(opponent);
		}
	}
	if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}
/*******************************************************
 일반 함수
*******************************************************/
bool CheckLastStand()
{
	int TAlive, CTAlive, TLastCheck, CTLastCheck;
	GetAlivePlayerCounts(TAlive, CTAlive, TLastCheck, CTLastCheck);
		
	if(TAlive == 1 && CTAlive == 1)
	{
		g_nTerrorLastIndex = TLastCheck;
		g_nCTerrorLastIndex = CTLastCheck;
		
		// 감옥 Hud 중단
		JAIL_PauseJailHud(g_nTerrorLastIndex, true);
		JAIL_PauseJailHud(g_nCTerrorLastIndex, true);
		
		PrintToChatAll("%s 1:1 상황이 되었습니다! 잠시 후 투표가 진행됩니다.", PREFIX);
		g_fl1v1VoteMenuDisplayTime[g_nTerrorLastIndex] = GetGameTime() + TIME_1V1_WAITING_VOTE_TIME;
		g_fl1v1VoteMenuDisplayTime[g_nCTerrorLastIndex] = GetGameTime() + TIME_1V1_WAITING_VOTE_TIME;
		g_b1v1FightVote = true;
		
		return true;
	}
	
	return false;
}

void GetAlivePlayerCounts(int& TAlive, int& CTAlive, int& TLastCheck, int& CTLastCheck)
{
	TAlive = 0;
	CTAlive = 0;
	TLastCheck = INVALID_ENT_REFERENCE;
	CTLastCheck = INVALID_ENT_REFERENCE;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidPlayer(i))
		{
			if(GetClientTeam(i) == CS_TEAM_T)
			{
				TAlive++;
				TLastCheck = i;
			}
			else if(GetClientTeam(i) == CS_TEAM_CT)
			{
				CTAlive++;
				CTLastCheck = i;
			}
		}
	}
}

// FormerSelector => 상대방 보다 빠르게 1v1 결정을 내린 사람 인덱스
// LatterSelector => 상대방 보다 늦게 1v1 결정을 내린 사람 인덱스
void Proceed1v1Fight(int FormerSelector, int LatterSelector)
{
	if (g_b1v1Fight || !g_b1v1FightVote)		return;
	
	if(IsValidPlayer(FormerSelector) && IsValidPlayer(LatterSelector))
	{
		g_b1v1Fight = true;
		
		Process_On1v1FightOccurred();
		
		if(!JAIL_IsRebelable())
			JAIL_SetRebelable(true);
		
		// 감옥 시스템 중단
		JAIL_PauseJailAction(true);
		// 상점 시스템 중단
		JAIL_SetShopState(false);
	
		// TODO MUSIC
		
		float vecFormerOrigin[3];
		GetClientAbsOrigin(FormerSelector, vecFormerOrigin);
		
		SetEntProp(FormerSelector, Prop_Data, "m_takedamage", 0, 1);
		SetEntProp(LatterSelector, Prop_Data, "m_takedamage", 0, 1);
		
		CreateBeacon(FormerSelector);
		CreateBeacon(LatterSelector);
		
		SDKHook(FormerSelector, SDKHook_WeaponCanUse, OnClientCanUseWeapon);
		SDKHook(LatterSelector, SDKHook_WeaponCanUse, OnClientCanUseWeapon);
		
		RemoveGuns(FormerSelector);
		RemoveGuns(LatterSelector);
		
		SetEntityHealth(FormerSelector, 100);
		SetEntityHealth(LatterSelector, 100);
		
		SetEntityGravity(FormerSelector, 1.0);
		SetEntityGravity(LatterSelector, 1.0);
		
		SetEntPropFloat(FormerSelector, Prop_Data, "m_flLaggedMovementValue", 1.0);
		SetEntPropFloat(LatterSelector, Prop_Data, "m_flLaggedMovementValue", 1.0);
		
		float vVel[3];
		vVel[0] = 1200.0 * GetRandomInt(-1, 1);
		vVel[1] = 1200.0 * GetRandomInt(-1, 1);
		vVel[2] = 251.0;
		TeleportEntity(FormerSelector, NULL_VECTOR, NULL_VECTOR, vVel);
		TeleportEntity(LatterSelector, vecFormerOrigin, NULL_VECTOR, NULL_VECTOR);
		
		SetEntityMoveType(LatterSelector, MOVETYPE_NONE);
		
		g_fl1v1StartTime = GetGameTime() + TIME_1V1_WAITING_START_TIME;
		
		// 먼저 선택한 사람이 날아가야 하므로 이후에 이동을 멈춘다.
		CreateTimer(0.5, StopPlayer, FormerSelector, TIMER_FLAG_NO_MAPCHANGE);
		
		DataPack pack = CreateDataPack();
		pack.WriteCell(FormerSelector);
		pack.WriteCell(LatterSelector);
		CreateTimer(TIME_1V1_WAITING_START_TIME/2, LetPlayersMove, pack, TIMER_FLAG_NO_MAPCHANGE);
	}
}

void Close1v1Fight()
{
	if(IsValidClient(g_nTerrorLastIndex))
	{
		g_fl1v1VoteMenuDisplayTime[g_nTerrorLastIndex] = 0.0;
		SDKUnhook(g_nTerrorLastIndex, SDKHook_WeaponCanUse, OnClientCanUseWeapon);
	}
	if(IsValidClient(g_nCTerrorLastIndex))
	{
		g_fl1v1VoteMenuDisplayTime[g_nCTerrorLastIndex] = 0.0;
		SDKUnhook(g_nCTerrorLastIndex, SDKHook_WeaponCanUse, OnClientCanUseWeapon);
	}
	
	g_nTerrorLastIndex = INVALID_ENT_REFERENCE;
	g_nCTerrorLastIndex = INVALID_ENT_REFERENCE;
	
	g_b1v1Fight = false;
	g_b1v1FightVote = false;
	g_i1v1FightAccept[0] = 0;
	g_i1v1FightAccept[1] = 0;
	g_fl1v1StartTime = 0.0;
	g_fl1v1TimeLimit = 0.0;
}

public Action StopPlayer(Handle timer, int client)
{
	// 먼저 선택한 사람이 날아가야 하므로 이후에 이동을 멈춘다.
	SetEntityMoveType(client, MOVETYPE_NONE);
}

public Action LetPlayersMove(Handle timer, DataPack pack)
{
	pack.Reset();
	int FormerSelector = pack.ReadCell();
	int LatterSelector = pack.ReadCell();
	delete pack;
	
	SetEntityMoveType(FormerSelector, MOVETYPE_ISOMETRIC);
	SetEntityMoveType(LatterSelector, MOVETYPE_ISOMETRIC);
	
	EmitSoundToAll(SOUND_CAN_MOVE, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, _ ,_ , GetRandomInt(95, 105));
}

void ReleaseFighters()
{
	SetEntProp(g_nTerrorLastIndex, Prop_Data, "m_takedamage", 2, 1);
	SetEntProp(g_nCTerrorLastIndex, Prop_Data, "m_takedamage", 2, 1);
	
	EmitSoundToAll(SOUND_1V1_START, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, _ ,_ , GetRandomInt(95, 105));
}

void SlayAll()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidPlayer(i))
		{
			ForcePlayerSuicide(i);
		}
	}
}

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

/********************* 비콘 관련 *********************/
void InitBeaconVars()
{
	Handle gameConfig = LoadGameConfigFile("funcommands.games");
	if (gameConfig == null)
	{
		return;
	}
	
	if (GameConfGetKeyValue(gameConfig, "SoundBlip", g_BlipSound, sizeof(g_BlipSound)) && g_BlipSound[0])
	{
		if(!IsSoundPrecached(g_BlipSound))
			PrecacheSound(g_BlipSound, true);
	}
	
	char buffer[PLATFORM_MAX_PATH];
	if (GameConfGetKeyValue(gameConfig, "SpriteBeam", buffer, sizeof(buffer)) && buffer[0])
	{
		g_BeamSprite = PrecacheModel(buffer);
	}
	
	if (GameConfGetKeyValue(gameConfig, "SpriteHalo", buffer, sizeof(buffer)) && buffer[0])
	{
		g_HaloSprite = PrecacheModel(buffer);
	}
	
	delete gameConfig;
}

void CreateBeacon(int client)
{
	Timer_TeamBeacon(INVALID_HANDLE, client);
}

public Action Timer_TeamBeacon(Handle timer, int client)
{
	if(!IsValidPlayer(client) || !g_b1v1Fight)
		return Plugin_Stop;
	
	CreateTimer(1.0, Timer_TeamBeacon, client, TIMER_FLAG_NO_MAPCHANGE);
	
	float vec[3];
	int team = GetClientTeam(client);
	GetClientAbsOrigin(client, vec);
	vec[2] += 10;
	
	if (g_BeamSprite > -1 && g_HaloSprite > -1)
	{
		TE_SetupBeamRingPoint(vec, 10.0, 375.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 5.0, 0.0, greyColor, 10, 0);
		TE_SendToAll();
		
		if (team == CS_TEAM_T)
		{
			TE_SetupBeamRingPoint(vec, 10.0, 375.0, g_BeamSprite, g_HaloSprite, 0, 10, 0.6, 10.0, 0.5, redColor, 10, 0);
		}
		else if (team == CS_TEAM_CT)
		{
			TE_SetupBeamRingPoint(vec, 10.0, 375.0, g_BeamSprite, g_HaloSprite, 0, 10, 0.6, 10.0, 0.5, blueColor, 10, 0);
		}
		else
		{
			TE_SetupBeamRingPoint(vec, 10.0, 375.0, g_BeamSprite, g_HaloSprite, 0, 10, 0.6, 10.0, 0.5, greenColor, 10, 0);
		}
		
		TE_SendToAll();
	}
		
	if (g_BlipSound[0])
	{
		GetClientEyePosition(client, vec);
		EmitAmbientSound(g_BlipSound, vec, client, SNDLEVEL_RAIDSIREN);	
	}
	
	return Plugin_Continue;
}

/*******************************************************
 이벤트
*******************************************************/
public void OnRoundStart(Event event, char[] name, bool dontBroadcast)
{
	JAIL_PauseJailAction(false);
	Close1v1Fight();
}

public void OnRoundEnd(Event event, char[] name, bool dontBroadcast)
{
	if(g_b1v1Fight)
	{
		// 승자 이벤트 코드 작성
		int team = event.GetInt("winner");
		
		if(g_fl1v1TimeLimit < 0.0) // 0.0 보다 작다면 -1.0, 시간이 다 되어서 끝난 경우.
		{
			g_fl1v1TimeLimit = 0.0;
			
			PrintCenterTextAll("1:1 칼전이 끝났습니다!\n결과는 <font color='#CCCCCC' size='25'><b>무승부</b></font>입니다!");
		}
		else
		{		
			if(team == CS_TEAM_T)
			{
				PrintCenterTextAll("1:1 칼전이 끝났습니다!\n결과는 <font color='#FF4040' size='25'><b>죄수팀</b></font>의 승리입니다!");
			}
			else if(team == CS_TEAM_CT)
			{
				PrintCenterTextAll("1:1 칼전이 끝났습니다!\n결과는 <font color='#99CCFF' size='25'><b>간수팀</b></font>의 승리입니다!");
			}
		}
	}
	
	Close1v1Fight();
}

public void OnPlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	g_fl1v1VoteMenuDisplayTime[client] = 0.0;
	SDKUnhook(client, SDKHook_WeaponCanUse, OnClientCanUseWeapon);
}

public void OnPlayerDeath(Event event, char[] name, bool dontBroadcast)
{
	if (!JAIL_IsPluginOn() || IsWarmupPeriod())	return;
	
	// 1v1이 진행중이 아닐때
	if(!g_b1v1Fight)
	{
		if(GetPlayerCount() >= MIN_PLAYERS_TO_1V1)
			CheckLastStand();
	}
}

/*******************************************************
 네이티브, 포워드 관련 함수
*******************************************************/
void Process_On1v1FightOccurred()
{
	// Start forward call.
    Call_StartForward(g_fwdOn1v1FightOccurred);
    
    // Push the parameters.
    Call_PushCell(g_nTerrorLastIndex);
    Call_PushCell(g_nCTerrorLastIndex);
    
    Call_Finish();
}