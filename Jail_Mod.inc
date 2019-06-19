/*
**
*/
#if defined _INTERFACE_included
 #endinput
#endif
#define _INTERFACE_included

#if !defined REQUIRE_PLUGIN
public __pl_INTERFACE_SetNTVOptional()
{
	MarkNativeAsOptional("JAIL_IsPluginOn");
	MarkNativeAsOptional("JAIL_IsClientVIP");
	
	MarkNativeAsOptional("JAIL_OpenShopMain");
	MarkNativeAsOptional("JAIL_GetShopState");
	MarkNativeAsOptional("JAIL_SetShopState");
	
	MarkNativeAsOptional("JAIL_IsJailActionPaused");
	MarkNativeAsOptional("JAIL_PauseJailAction");
	MarkNativeAsOptional("JAIL_IsJailHudPaused");
	MarkNativeAsOptional("JAIL_PauseJailHud");
	MarkNativeAsOptional("JAIL_IsRebelable");
	MarkNativeAsOptional("JAIL_SetRebelable");
	
	MarkNativeAsOptional("JAIL_IsSwapListExist");
	MarkNativeAsOptional("JAIL_EraseClientOnList");
	MarkNativeAsOptional("JAIL_GetFirstListed");
}
#endif

public SharedPlugin __pl_INTERFACE =
{
	name = "Jail Mod",
	file = "Jail Mod.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};

/*******************************************************
 스톡 함수
*******************************************************/
/**
 * 메인 플러그인이 실행중인지 아닌지를 얻어낸다.
 * 
 * @return					메인 플러그인이 실행중이라면 true, 아니라면 false
 */
native bool JAIL_IsPluginOn();

/**
 * 클라이언트가 VIP인지 아닌지를 얻어낸다.
 * 
 * @param client 			클라이언트 인덱스
 * @return					VIP라면 true, 아니라면 false
 */
native bool JAIL_IsClientVIP(int client);

/**
 * 감옥 주요 기능이 멈춰져 있는지 확인한다.
 * 
 * @return					멈춰져 있다면 true, 아니라면 false
 */
native bool JAIL_IsJailActionPaused();

/**
 * 감옥 주요 기능을 멈추거나 시작한다.
 * 
 * @param open	 			멈출 것이라면 true, 아니라면 false;
 *
 * @noreturn
 */
native void JAIL_PauseJailAction(bool pause);

/**
 * 해당 클라이언트에 대한 감옥 시스템 Hud 알림 기능이 멈춰져 있는지 확인한다.
 * 
 * @return					멈춰져 있다면 true, 아니라면 false
 */
native bool JAIL_IsJailHudPaused(int client);

/**
 * 해당 클라이언트에 대한 감옥 시스템 Hud 알림 기능을 멈추거나 시작한다.
 * 
 * @param open	 			멈출 것이라면 true, 아니라면 false;
 *
 * @noreturn
 */
native void JAIL_PauseJailHud(int client, bool pause);

/**
 * 반란 가능한 시간인지 얻어낸다.
 * 
 * @return					반란 가능하다면 true, 아니라면 false
 */
native bool JAIL_IsRebelable();

/**
 * 반란 가능한 상태를 설정한다.
 *
 * @param open	 			반란이 가능하게 하려면 true, 불가능하게 하려면 false;
 *
 * @noreturn
 */
native void JAIL_SetRebelable(bool relbelable);

/**
 * 클라이언트가 상점 메뉴를 열 때 호출된다.
 * 
 * @client 				클라이언트 인덱스
 */
forward Action JAIL_OnShopCommand(int client);

/**
 * 1v1 대전 상황일 때 호출된다.
 * 
 * @tLastStand 			1v1 대전에 참가하는 테러리스트 플레이어 인덱스
 * @ctLastStand 		1v1 대전에 참가하는 대-테러리스트 플레이어 인덱스
 */
forward void On1v1FightOccurred(int tLastStand, ctLastStand);

/**
 * 클라이언트에게 상점 메뉴를 띄운다.
 * 
 * @param client 			클라이언트 인덱스
 * @noreturn
 */
native void JAIL_OpenShopMain(int client);

/**
 * 상점을 이용할 수 있는지의 값을 얻어낸다.
 *
 * @return					상점을 이용할 수 있는 상태라면 true, 아니라면 false;
 */
native bool JAIL_GetShopState();

/**
 * 상점을 열 거나 닫는다.
 *
 * @param open	 			상점을 열려면 true, 닫으려면 false;
 *
 * @noreturn
 */
native void JAIL_SetShopState(bool open);


/**
 * 클라이언트에게 스킨 메뉴를 띄워준다.
 * 
 * @param client	 		스킨 메뉴를 띄워 줄 클라이언트
 *
 * @noreturn
 */
native void JAIL_OpenSkinMain(int client);

/**
 * 해당 팀에 빠른 팀 교체 기능을 이용하려는 사람이 있는지를 얻어낸다.
 *
 * @param team				빠른 팀 교체 기능을 이용하려는 사람이 있는지 찾아볼 팀
 *
 * @return					빠른 팀 교체 기능을 이용하려는 사람이 있다면 true, 아니라면 false
 */
native bool JAIL_IsSwapListExist(int team);

/**
 * 클라이언트를 빠른 팀 교체 목록에서 제거한다.
 *
 * @param client			빠른 팀 교체 목록에서 제거할 클라이언트
 * @param notify			빠른 팀 교체 목록에서 제거되었다는 사실을 알릴 것이라면 true, 아니라면 false
 *
 * @noreturn				
 */
native void JAIL_EraseClientOnList(int client, bool notify=false);

/**
 * 해당 팀의 빠른 팀 교체 목록에서 가장 첫 순서의 클라이언트를 얻어낸다.
 *
 * @param team				빠른 팀 교체 목록을 찾아 볼 팀
 *
 * @return					가장 첫 순서의 클라이언트 인덱스
 */
native int JAIL_GetFirstListed(int team);

/**
 * 빠른 팀 교체가 발동되었을 때.
 */
forward void JAIL_OnQuickSwapPost();


/**
 * 클라이언트가 서버 안에서 적용될 수 있는지 확인
 * 
 * @param client 			클라이언트 인덱스
 * @return					클라이언트 인덱스가 정상이고, 연결되있는 상태면 true, 아니면 false.
 */
stock bool IsValidClient(client)
{
	if(client > 0 && client < MaxClients)
	{
		if(IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client) && !IsClientReplay(client))
		{
			return true;
		}
		else
		{
			return false;
		}
	}
	else
	{
		return false;
	}
}

/**
 * 클라이언트가 게임 안에서 적용될 수 있는지 확인
 * 죽어있거나 옵저버는 해당안됨
 * 
 * @param client 			클라이언트 인덱스
 * @return					살아있고 적용가능한 대상이면 true, 아니면 false.
 */
stock bool IsValidPlayer(client)
{
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		return true;
	}
	else
	{
		return false;
	}
}

/**
 * 현재 라운드가 준비 시간인지 아닌지를 알아냅니다.
 * 
 * @return		현재 준비 시간이라면 true, 아니라면 false.
 */
stock bool IsWarmupPeriod()
{
	return view_as<bool>(GameRules_GetProp("m_bWarmupPeriod"));
}

/**
 * 강제로 라운드 상태를 준비시간으로 설정합니다.
 * 
 * @noreturn
 */
stock void StartWarmup()
{
	// 체크하지 않을경우 라운드 무한반복에 빠질 수 있다.
	if(!IsWarmupPeriod())
	{
		ServerCommand("mp_warmup_start");
//		GameRules_SetProp("m_bWarmupPeriod", 1);
//		SetWarmupStartTime(GetGameTime()+0.5);
	}
}

/**
 * 게임 준비 시간의 시작 시간을 얻어냅니다.
 *
 * @return		게임 준비 시간의 시작 시간(GameTime 기준)
 */
stock float GetWarmupStartTime()
{
	return GameRules_GetPropFloat("m_fWarmupPeriodStart");
}

/**
 * 게임 준비 시간의 종료 시간을 얻어냅니다.
 *
 * @return		게임 준비 시간이 종료되는 시간(GameTime 기준)
 */
stock float GetWarmupEndTime()
{
	return (GetWarmupStartTime() + GetConVarFloat(FindConVar("mp_warmuptime")));
}

/**
 * 남은 게임 준비 시간을 얻어냅니다.
 *
 * @return		남은 게임 준비 시간(실수 초 단위)
 */
stock float GetWarmupLeftTime()
{
	return (GetWarmupEndTime() - GetGameTime());
}

/**
 * 게임 준비 시간이 시작된 시간을 강제로 설정합니다.
 * 게임 준비 시간을 다시 시작하거나, 준비 시간을 늘릴때 이용합니다.
 *
 * @noreturn
 */
stock void SetWarmupStartTime(float time)
{
	GameRules_SetPropFloat("m_fWarmupPeriodStart", time, _, true);
}

/**
 * 게임 준비 시간의 종료 시간을 강제로 설정합니다.
 *
 * @noreturn
 */
stock void SetWarmupEndTime(float time)
{
	GameRules_SetPropFloat("m_fWarmupPeriodEnd", time, _, true);
}

/**
 * 게임을 다시 시작합니다.
 *
 * @param time		게임을 다시 시작하기까지의 딜레이.
 *
 * @noreturn
 */
stock void RestartRound(float time)
{
	GameRules_SetPropFloat("m_flRestartRoundTime", GetGameTime() + time);
}

/**
 * 게임을 [다시] 시작하는 시간을 구합니다.
 *
 * @return 		게임이 [다시] 시작되는 시간. (GameTime 기준)
 */
stock float GetRestartRoundTime()
{
	return GameRules_GetPropFloat("m_flRestartRoundTime");
}

/**
 * 라운드가 시작된 시간을 구합니다.
 *
 * @return		라운드의 시작 시간. (GameTime 기준)
 */
stock float GetRoundStartTime()
{
	return GameRules_GetPropFloat("m_fRoundStartTime");
}

/**
 * 라운드의 남은 시간을 구해냅니다.
 *
 * @return		라운드의 남은 시간. (실수 초 단위)
 */
stock float GetRoundLeftTime()
{
	return ((GetConVarFloat(FindConVar("mp_roundtime"))*60 - (GetGameTime() - GetRoundStartTime())));
}

/**
 * 한 라운드의 시간을 구해냅니다.
 *
 * @param afterFreezeTime		라운드의 시간에 프리즈 타임을 포함한다면 true, 아니라면 false.
 *
 * @return		라운드의 시간. (실수 초 단위)
 */
stock float GetRoundTime(bool afterFreezeTime=false)
{
	int freezeTimeLength = 0;
	if(afterFreezeTime)
		freezeTimeLength = GetConVarInt(FindConVar("mp_freezetime"));
	return ((GetGameTime()+freezeTimeLength) - GetRoundStartTime());
}

/**
 * 라운드가 다시 시작되는 딜레이를 얻어냅니다.
 *
 * @return		라운드가 다시 시작되는 딜레이. (실수 초 단위)
 */
stock float GetRoundRestartDelay()
{
	return GetConVarFloat(FindConVar("mp_round_restart_delay"));
}

/**
 * 플레이어 팀에 참가되어있는 모든 플레이어 수를 구한다.
 *
 * @return		플레이어 팀에 참가되어있는 모든 플레이어 수
 */
stock int GetPlayerCount()
{
	return GetTeamClientCount(2) + GetTeamClientCount(3);
}

stock FormatNumberInt(int value, char[] buffer, int size, int seperator=',')
{
    char helper[size];
    IntToString(value, helper, size);
    strcopy(buffer, size, helper);

    int length = strlen(helper);

    int n_helper;

    if (helper[0] == '-') {
        n_helper += ((length-1) % 3) + 1;

        if (n_helper == 1) {
            n_helper = 4;
        }
    }
    else {
        n_helper += length % 3;

        if (n_helper == 0) {
            n_helper = 3;
        }
    }

    int n_buffer = n_helper;

    while (n_helper < length) {
        buffer[n_buffer] = seperator;
        strcopy(buffer[n_buffer + 1], size, helper[n_helper]);

        n_buffer += 4;
        n_helper += 3;
    }
}

// Mathematical version:(bit slower with big numbers)
stock FormatNumber_(int value, char[] buffer, int size, int seperator=',')
{
    buffer[0] = '\0';

    int divisor = 1000;

    while (value >= 1000 || value <= -1000) {
        int offcut = value % divisor;
        value = RoundToFloor(float(value) / float(divisor));

        Format(buffer, size, "%c%03.d%s", seperator, offcut, buffer);
    }

    Format(buffer, size, "%d%s", value, buffer);

    return;
}

stock bool ClearHandle(Handle& hHandle)
{
	if(hHandle != null)
	{
		delete hHandle;
		hHandle = null;
		
		return true;
	}
	
	return false;
}

stock bool PrintKeyHintText(client, const char[] format, any:...) 
{ 
    Handle userMessage = StartMessageOne("KeyHintText", client); 
    if (userMessage == INVALID_HANDLE) { 
        return false; 
    } 

    char buffer[512]; 
    SetGlobalTransTarget(client); 
    VFormat(buffer, sizeof(buffer), format, 3); 
     
    if (GetUserMessageType() == UM_Protobuf) 
    { 
        PbAddString(userMessage, "hints", buffer); 
    } 
    else 
    { 
        BfWriteByte(userMessage, 1); 
        BfWriteString(userMessage, buffer); 
    } 
     
    EndMessage(); 
    return true; 
}


#define SIZE_OF_INT		2147483647		// without 0

// Team Defines
#define	TEAM_INVALID	-1
#define TEAM_UNASSIGNED	0
#define TEAM_SPECTATOR	1
#define TEAM_ONE		2
#define TEAM_TWO		3

#define CLIENTFILTER_ALL				0		// No filtering
#define CLIENTFILTER_BOTS			( 1	<< 1 )	// Fake clients
#define CLIENTFILTER_NOBOTS			( 1	<< 2 )	// No fake clients
#define CLIENTFILTER_AUTHORIZED		( 1 << 3 ) // SteamID validated
#define CLIENTFILTER_NOTAUTHORIZED  ( 1 << 4 ) // SteamID not validated (yet)
#define CLIENTFILTER_ADMINS			( 1	<< 5 )	// Generic Admins (or higher)
#define CLIENTFILTER_NOADMINS		( 1	<< 6 )	// No generic admins
// All flags below require ingame checking (optimization)
#define CLIENTFILTER_INGAME			( 1	<< 7 )	// Ingame
#define CLIENTFILTER_INGAMEAUTH		( 1 << 8 ) // Ingame & Authorized
#define CLIENTFILTER_NOTINGAME		( 1 << 9 )	// Not ingame (currently connecting)
#define CLIENTFILTER_ALIVE			( 1	<< 10 )	// Alive
#define CLIENTFILTER_DEAD			( 1	<< 11 )	// Dead
#define CLIENTFILTER_SPECTATORS		( 1 << 12 )	// Spectators
#define CLIENTFILTER_NOSPECTATORS	( 1 << 13 )	// No Spectators
#define CLIENTFILTER_OBSERVERS		( 1 << 14 )	// Observers
#define CLIENTFILTER_NOOBSERVERS	( 1 << 15 )	// No Observers
#define CLIENTFILTER_TEAMONE		( 1 << 16 )	// First Team (Terrorists, ...)
#define CLIENTFILTER_TEAMTWO		( 1 << 17 )	// Second Team (Counter-Terrorists, ...)

stock int GetRandomPlayer(int flags=CLIENTFILTER_ALL)
{	
	int[] clients = new int[MaxClients];
	int num = GetClient(clients, flags);

	if (num == 0) {
		return -1;
	}
	else if (num == 1) {
		return clients[0];
	}

	int  random = MathGetRandomInt(0, num-1);

	return clients[random];
}

stock bool IsClientAdmin(int client, AdminFlag adminFlag=Admin_Generic)
{
	AdminId adminId = GetUserAdmin(client);
	
	if (adminId == INVALID_ADMIN_ID) {
		return false;
	}
	
	return GetAdminFlag(adminId, adminFlag);
}

stock int GetClient(int[] clients, int flags=CLIENTFILTER_ALL)
{
	int x=0;
	for (int client = 1; client <= MaxClients; client++) {

		if (!MatchClientFilter(client, flags)) {
			continue;
		}

		clients[x++] = client;
	}

	return x;
}
stock int MathGetRandomInt(int min, int max)
{
	int  random = GetURandomInt();
	
	if (random == 0) {
		random++;
	}

	return RoundToCeil(float(random) / (float(SIZE_OF_INT) / float(max - min + 1))) + min - 1;
}

stock bool MatchClientFilter(int client, int flags)
{
	bool isIngame = false;

	if (flags >= CLIENTFILTER_INGAME) {
		isIngame = IsClientInGame(client);

		if (isIngame) {
			if (flags & CLIENTFILTER_NOTINGAME) {
				return false;
			}
		}
		else {
			return false;
		}
	}
	else if (!IsClientConnected(client)) {
		return false;
	}

	if (!flags) {
		return true;
	}

	if (flags & CLIENTFILTER_INGAMEAUTH) {
		flags |= CLIENTFILTER_INGAME | CLIENTFILTER_AUTHORIZED;
	}

	if (flags & CLIENTFILTER_BOTS && !IsFakeClient(client)) {
		return false;
	}

	if (flags & CLIENTFILTER_NOBOTS && IsFakeClient(client)) {
		return false;
	}

	if (flags & CLIENTFILTER_ADMINS && !IsClientAdmin(client)) {
		return false;
	}

	if (flags & CLIENTFILTER_NOADMINS && IsClientAdmin(client)) {
		return false;
	}

	if (flags & CLIENTFILTER_AUTHORIZED && !IsClientAuthorized(client)) {
		return false;
	}

	if (flags & CLIENTFILTER_NOTAUTHORIZED && IsClientAuthorized(client)) {
		return false;
	}

	if (isIngame) {

		if (flags & CLIENTFILTER_ALIVE && !IsPlayerAlive(client)) {
			return false;
		}

		if (flags & CLIENTFILTER_DEAD && IsPlayerAlive(client)) {
			return false;
		}

		if (flags & CLIENTFILTER_SPECTATORS && GetClientTeam(client) != TEAM_SPECTATOR) {
			return false;
		}

		if (flags & CLIENTFILTER_NOSPECTATORS && GetClientTeam(client) == TEAM_SPECTATOR) {
			return false;
		}

		if (flags & CLIENTFILTER_OBSERVERS && !IsClientObserver(client)) {
			return false;
		}

		if (flags & CLIENTFILTER_NOOBSERVERS && IsClientObserver(client)) {
			return false;
		}

		if (flags & CLIENTFILTER_TEAMONE && GetClientTeam(client) != CS_TEAM_T) {
			return false;
		}

		if (flags & CLIENTFILTER_TEAMTWO && GetClientTeam(client) != CS_TEAM_CT) {
			return false;
		}
	}

	return true;
}

// 무기 다 없애기
stock void RemoveGuns(int client, bool exceptForKnife=true)
{
	#if defined _DEBUG_
		PrintToServer("[BST Zombie] RemoveGuns(%i)", client);
	#endif
	
	if (!(IsClientInGame(client) && IsPlayerAlive(client)))	return;
	
	for(new i = 0; i <= 10; i++)
	{
		int weapon;
		int iCheckCount = 0;
		while((weapon = GetPlayerWeaponSlot(client, i)) != INVALID_ENT_REFERENCE && IsValidEdict(client))
		{
			if(exceptForKnife && i == CS_SLOT_KNIFE)
			{
				char clsname[32];
				if (GetEdictClassname(weapon, clsname, sizeof(clsname)))
				{
					if (StrEqual(clsname, "weapon_knife"))
					{
						if(iCheckCount > 1)
						{
							break;
						}
						else
						{
							iCheckCount++;
							continue;
						}
					}
				}
			}
			
			RemovePlayerItem(client, weapon); 
			RemoveEdict(weapon); 
		}
	}
	
	if(exceptForKnife)
	{
		if(GetPlayerWeaponSlot(client, CS_SLOT_KNIFE) == INVALID_ENT_REFERENCE)
		{
			GivePlayerItem(client, "weapon_knife");
		}
		
		FakeClientCommand(client, "use weapon_knife");
	}
}