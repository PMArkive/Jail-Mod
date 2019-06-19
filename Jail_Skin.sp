/*
CREATE TABLE `jail_playerskin_settings` (
`Id` int(64) NOT NULL auto_increment,
`AuthId` varchar(32) NOT NULL default '',
`Name` varchar(128) NOT NULL default '',
`UseSelected` int(1) NOT NULL default '0',
`TSkinIndex` int(8) NOT NULL default '-1',
`TSkinName` varchar(64) NULL default NULL,
`CTSkinIndex` int(8) NOT NULL default '-1',
`CTSkinName` varchar(64) NULL default NULL,
`LastActive` int(32) NOT NULL default '0',
PRIMARY KEY  (`Id`))
COMMENT='뱅슈터 감옥서버 플레이어 스킨 설정테이블'
COLLATE='utf8_general_ci'
ENGINE=InnoDB;
*/

#define PLUGIN_AUTHOR "Trostal"
#define PLUGIN_VERSION "0.01a"

#include <sourcemod>
#include <sdktools>

#include <smartdm>

#undef REQUIRE_PLUGIN
#include "Jail_Mod.inc"

#pragma semicolon 1
#pragma newdecls required

// PRINT DEBUG FOR SQL
#define _DEBUG_

#define T_TEAM_NAME		"죄수"
#define CT_TEAM_NAME	"간수"

// 설정 값 유지 기간 (설정된 일수가 넘도록 기록이 남지 않은 유저의 데이터를 삭제합니다.)
#define PLAYER_STATS_OLD 30

Handle db;

public Plugin myinfo = 
{
	name = "[JAIL] Player Skin System",
	author = PLUGIN_AUTHOR,
	description = "스킨에 대한 대부분의 처리를 담당합니다.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Hatser/Jail-Mod"
};

// 배열 최대값의 초기값 * 4 로 블록 사이즈가 정해진다.
#define DEFAULT_MAX_SIZE 32 // 수정할 필요 없음.

#define PrintChatTag "\x01[\x0BJAIL\x01] :\x05" // 채팅에 출력할 때, 이 문자열을 앞에 두고 출력시킵니다.

int UseSelected[MAXPLAYERS+1];
int SkinIndex[MAXPLAYERS+1][2];
char SkinName[MAXPLAYERS+1][2][256];
char SkinCode[MAXPLAYERS+1][2][256];

#define TEAM_ALL	1 // 팀 구분이 없는 스킨
#define TEAM_T		2 // 테러리스트 팀만 사용 가능한 스킨
#define TEAM_CT		3 // 대-테러리스트 팀만 사용 가능한 스킨

#define AUTH_ALL	1 // 모든 유저가 사용 가능한 스킨
#define AUTH_VIP	2 // VIP 유저만 사용 가능한 스킨

int Item_Count = 0;

Handle Item_Type;
Handle Item_Type2;
Handle Item_Name;
Handle Item_Code;

Handle Item_Sort; // 일반 T 스킨 | 일반 CT 스킨 | VIP T 스킨 | VIP CT 스킨의 순서로 정렬시켜주는 변수 배열을 담는 핸들
int SortCounts[4] = {0, ...};

// 스킨 항목의 리스트를 작성합니다.
// 작성할 땐 적용하고자 하는 스킨의 mdl 파일 경로를 작성하시면 됩니다.
// 경로 맨 처음의 디렉토리 (models/) 와 경로의 마지막 모델의 확장자 (.mdl)은 제외합니다.
void ListSkinItem()
{
	AddSkinItem(TEAM_T,AUTH_ALL,"일반죄수(하양)","player/techknow/prison/leet_p2");/*
	AddSkinItem(TEAM_T,AUTH_ALL,"일반죄수(노랑)","player/techknow/prison/leet_pc");
	AddSkinItem(TEAM_T,AUTH_ALL,"일반죄수(주황)","player/techknow/prison/leet_p");
	AddSkinItem(TEAM_T,AUTH_ALL,"죄수(차량절도)","player/supremeelite/wyllohjail/vindiesel");
	AddSkinItem(TEAM_T,AUTH_ALL,"죄수(강제추행)","player/supremeelite/wyllohjail/ted");
	AddSkinItem(TEAM_T,AUTH_ALL,"죄수(사이비교주)","player/supremeelite/wyllohjail/monk");
	AddSkinItem(TEAM_T,AUTH_ALL,"죄수(공금횡령)","player/supremeelite/wyllohjail/kleiner");
	AddSkinItem(TEAM_T,AUTH_ALL,"죄수(마약거래)","player/supremeelite/wyllohjail/john");
	AddSkinItem(TEAM_T,AUTH_ALL,"죄수(장기밀매)","player/supremeelite/wyllohjail/honcho");
	AddSkinItem(TEAM_T,AUTH_ALL,"죄수(사이버사기)","player/supremeelite/wyllohjail/albert");
	AddSkinItem(TEAM_T,AUTH_ALL,"죄수(간통죄)","player/supremeelite/wyllohjail/billy");
	AddSkinItem(TEAM_T,AUTH_ALL,"죄수(조직보스)","player/supremeelite/wyllohjail/cleverland");
	AddSkinItem(TEAM_T,AUTH_ALL,"산타걸(이벤트)","player/vad36lollipop/lolli_new");	
	AddSkinItem(TEAM_T,AUTH_VIP,"앨런(VIP)","mapeadores/kaem/alanwake/alanwake");
	AddSkinItem(TEAM_T,AUTH_VIP,"로건(VIP)", "mapeadores/kaem/logan/logan");
	AddSkinItem(TEAM_T,AUTH_VIP,"빌리(VIP)", "player/konata/ang/ang1");
	AddSkinItem(TEAM_T,AUTH_VIP,"곰(VIP)", "player/kuristaja/pbear/pbear");
	AddSkinItem(TEAM_T,AUTH_VIP,"플랭클린(VIP)", "player/vad36gtav/jail_fix/franklin");
	AddSkinItem(TEAM_T,AUTH_VIP,"마이클(VIP)", "player/vad36gtav/jail_fix/michael");
	AddSkinItem(TEAM_T,AUTH_VIP,"트래버(VIP)", "player/vad36gtav/jail_fix/trevor");*/

	
	AddSkinItem(TEAM_CT, AUTH_ALL,"남자간수1","player/natalya/police/chp_male_jacket");/*
	AddSkinItem(TEAM_CT, AUTH_ALL,"남자간수2","player/supremeelite/wyllohjail/gardien");	
	AddSkinItem(TEAM_CT, AUTH_ALL,"여자간수1","player/natalya/police/chp_female_jacket");
	AddSkinItem(TEAM_CT, AUTH_VIP,"고스트(VIP)","player/bz/ghost/bzghost");
	AddSkinItem(TEAM_CT, AUTH_VIP,"소프(VIP)","player/bz/soap/bzsoap");
	AddSkinItem(TEAM_CT, AUTH_VIP,"코르보 아타노(VIP)","player/vad36dishonored/corvo");*/
}

// 스킨 항목을 정해진 규칙에 따라 분류, 정렬합니다.
void SortSkinItem()
{
	int Team, Auth;
	int[][] Sorts = new int[4][Item_Count];
	for(int i = 0; i < Item_Count; i++)
	{
		Team = GetArrayCell(Item_Type, i);
		Auth = GetArrayCell(Item_Type2, i);
		
		if(Team == TEAM_T && Auth == AUTH_ALL)
			Sorts[0][SortCounts[0]++] = i;
		if(Team == TEAM_CT && Auth == AUTH_ALL)
			Sorts[1][SortCounts[1]++] = i;
		if(Team == TEAM_T && Auth == AUTH_VIP)
			Sorts[2][SortCounts[2]++] = i;
		if(Team == TEAM_CT && Auth == AUTH_VIP)
			Sorts[3][SortCounts[3]++] = i;
	}
	
	for(int i = 0; i < sizeof(SortCounts); i++)
		PushArrayArray(Item_Sort, Sorts[i], Item_Count);
}

void AddSkinItem(int IType, int IType2, char[] IName, char[] ICode=NULL_STRING)
{	
	PushArrayCell(Item_Type, IType);
	PushArrayCell(Item_Type2, IType2);
	PushArrayString(Item_Name, IName);
	PushArrayString(Item_Code, ICode);
	
	Item_Count++;
}

public void OnPluginStart()
{
	RegConsoleCmd("say", SayHook);
	RegConsoleCmd("say_team", SayHook);
	HookEvent("player_spawn", Player_Spawn);
	
	AddCommandListener(Command_OpenMenu, "autobuy");
	
	Item_Count = 0;
	Item_Type = CreateArray();
	Item_Type2 = CreateArray();
	Item_Name = CreateArray(ByteCountToCells(32));
	Item_Code = CreateArray(ByteCountToCells(92));
	Item_Sort = CreateArray(sizeof(SortCounts));
	
	ListSkinItem();
	SortSkinItem();
	
	SQL_TConnect(LoadSQLBase, "jail_jail_skin");
}

public void LoadSQLBase(Handle owner, Handle hndl, char[] error, any data)
{
	char query[1024];
	if (hndl == null)
	{
		PrintToServer("[JAIL PLAYER SKIN] Failed to connect the base table: %s", error);
		return;
	}
	else
	{
		PrintToServer("[JAIL PLAYER SKIN] Database Init. (CONNECTED)");

		// 테이블이 없을 때 생성해준다.
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `jail_playerskin_settings` (`Id` int(64) NOT NULL auto_increment,`AuthId` varchar(32) NOT NULL default '',`Name` varchar(128) NOT NULL default '',`UseSelected` int(1) NOT NULL default '0',`TSkinIndex` int(8) NOT NULL default '-1',`TSkinName` varchar(64) NOT NULL default '',`CTSkinIndex` int(8) NOT NULL default '-1',`CTSkinName` varchar(64) NOT NULL default '',`LastActive` int(12) NOT NULL default '0',PRIMARY KEY  (`Id`)) COMMENT='뱅슈터 감옥서버 플레이어 스킨 설정테이블' COLLATE='utf8_general_ci' ENGINE=InnoDB;");
		SQL_TQuery(db, SQLErrorCheckCallback, query);
		
		db = hndl;
	}

	// 문자열을 UTF-8로 지정하고 테이블을 체크함.
	FormatEx(query, sizeof(query), "SET NAMES \"UTF8\"");
	SQL_TQuery(db, SQLErrorCheckCallback, query);
	
	// LEVEL_TABLE_NAME이 들어가는 테이블을 다 뿌리도록 함.
	FormatEx(query, sizeof(query), "SHOW TABLES LIKE 'jail_playerskin_settings';");
	SQL_TQuery(db, SQLErrorCheckCallback, query);
	
	// 지정된 기간동안 활동 기록이 없는 데이터 삭제
	FormatEx(query, sizeof(query), "DELETE FROM jail_playerskin_settings WHERE LastActive <= %i", GetTime() - PLAYER_STATS_OLD * 12 * 60 * 60);
	SQL_TQuery(db, SQLErrorCheckCallback, query);
}

public void OnPluginEnd()
{
	LogError("BJail Main Player Skin Module (Version %s), Died.", PLUGIN_VERSION);
	/*
	ClearArray(Item_Type);
	ClearArray(Item_Type2);
	ClearArray(Item_Name);
	ClearArray(Item_Code);
	ClearArray(Item_Sort);
	ClearHandle(Item_Type);
	ClearHandle(Item_Type2);
	ClearHandle(Item_Name);
	ClearHandle(Item_Code);
	ClearHandle(Item_Sort);
	*/
}

public void OnClientPutInServer(int client)
{
	UseSelected[client] = 0;
	SkinIndex[client][0] = -1;
	SkinIndex[client][1] = -1;
	SkinName[client][0][0] = '\0';
	SkinName[client][1][0] = '\0';
	SkinCode[client][0][0] = '\0';
	SkinCode[client][1][0] = '\0';
}

public void OnClientPostAdminCheck(int client)
{
	if(!IsFakeClient(client) && IsValidClient(client))
	{
		LoadSkinSettings(client);
	}
}

public void OnClientDisconnect(int client)
{
	SaveSettingData(client);
}

public void OnMapStart()
{
	 // 한 번 작성하면 뜯어고칠 일이 거의 없으므로 함수 작성 후 격리보관한다.
	PrecasheModelList();
}

public Action Command_OpenMenu(int client, const char[] command, int args)
{
	if(IsValidClient(client))
		SkinMainMenu(client);
}

public Action SayHook(int client, int args)
{
	char Msg[256];
	GetCmdArgString(Msg, sizeof(Msg));
	int length = strlen(Msg);
	if(length <= 0)
		return Plugin_Continue;
		
	Msg[length-1] = '\0';
	
	if(StrEqual(Msg[1], "!스킨", false) || StrEqual(Msg[1], "!skin", false))
	{
		SkinMainMenu(client);
	}
	return Plugin_Continue;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("JAIL_OpenSkinMain", Native_JAIL_OpenSkinMain);
	RegPluginLibrary("JAILJail");
	return APLRes_Success;
}


public Action Player_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	int Client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!IsValidPlayer(Client) || (GetClientTeam(Client) != 2 && GetClientTeam(Client) != 3))
		return Plugin_Handled;
	
	char SkinPath[512];
	
	int[][] Sorts = new int[4][Item_Count];
	for(int i = 0; i < sizeof(SortCounts); i++)
		GetArrayArray(Item_Sort, i, Sorts[i], Item_Count);
	
	int SkinRand;
	
	if(UseSelected[Client] != 1 || SkinIndex[Client][GetClientTeam(Client)-2]<0 || StrEqual(SkinCode[Client][GetClientTeam(Client)-2], NULL_STRING))
	{
		if(GetClientTeam(Client) == 2)
		{
			if(JAIL_IsClientVIP(Client))
			{
				SkinRand = Sorts[2][GetRandomInt(0, SortCounts[2]-1)];
			}
			else
			{
				SkinRand = Sorts[0][GetRandomInt(0, SortCounts[0]-1)];
			}
		}
		if(GetClientTeam(Client) == 3)
		{
			if(JAIL_IsClientVIP(Client))
			{
				SkinRand = Sorts[3][GetRandomInt(0, SortCounts[3]-1)];
			}
			else
			{
				SkinRand = Sorts[1][GetRandomInt(0, SortCounts[1]-1)];
			}
		}
	}
	
	if(UseSelected[Client] == 1 && SkinIndex[Client][GetClientTeam(Client)-2]>=0 && !StrEqual(SkinCode[Client][GetClientTeam(Client)-2], NULL_STRING))
	{
		Format(SkinPath, sizeof(SkinPath), "%s", SkinCode[Client][GetClientTeam(Client)-2]);
	}
	else
	{
		GetArrayString(Item_Code, SkinRand, SkinPath, sizeof(SkinPath));
	}
	Format(SkinPath, sizeof(SkinPath), "models/%s.mdl", SkinPath);
	SetEntityModel(Client, SkinPath);
	
	return Plugin_Continue;
}

public void SkinMainMenu(int client)
{
	Menu menu = new Menu(Cmd_SkinMainMenu);
	
	menu.SetTitle("《 스킨 설정 메뉴 》");
	
	if(UseSelected[client] == 1)
		menu.AddItem("Use Selected Skin", "[√] 선택한 스킨 사용");
	else
		menu.AddItem("Use Random Skin", "[  ] 선택한 스킨 사용");
	
	char displayString[128];
	Format(displayString, sizeof(displayString), "%s 스킨 선택", T_TEAM_NAME);
	menu.AddItem("Select T Skin", displayString);
	Format(displayString, sizeof(displayString), "%s 스킨 선택", CT_TEAM_NAME);
	menu.AddItem("Select CT Skin", displayString);

	menu.ExitButton = true;
	menu.ExitBackButton = false;
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Cmd_SkinMainMenu(Menu menu, MenuAction action, int client, int select)
{
	if(action == MenuAction_Select)
	{
		if(select == 0)
		{
			char info[8];
			menu.GetItem(select, info, sizeof(info));
			
			if(UseSelected[client] == 1)
			{
				UseSelected[client] = 0;
				PrintToChat(client, "%s 라운드마다 스킨을 임의로 선택합니다.", PrintChatTag);
			}
			else
			{
				UseSelected[client] = 1;
				PrintToChat(client, "%s 선택하신 스킨을 사용합니다.", PrintChatTag);
			}
			SkinMainMenu(client);
			if(IsValidClient(client))
			{
				char SteamID[32];
				GetClientAuthId(client, AuthId_Steam2, SteamID, 32);
				
				SaveSettingData(client);
			}
		}
		
		if(select == 1)
		{
			SelectSkinMenu(client, TEAM_T);
		}
		if(select == 2)
		{
			SelectSkinMenu(client, TEAM_CT);
		}
	}
	if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

void SelectSkinMenu(int client, int Team, int page=0)
{
	Menu menu = new Menu(Cmd_SelectSkinMenu);
	
	menu.SetTitle("《 스킨 선택 메뉴 》");
	
	for(int i = 0; i < Item_Count; i++)
	{
		if(GetArrayCell(Item_Type, i) == TEAM_ALL || GetArrayCell(Item_Type, i) == Team)
		{
			if(GetArrayCell(Item_Type2, i) == AUTH_ALL || (GetArrayCell(Item_Type2, i) == AUTH_VIP && JAIL_IsClientVIP(client)))
			{
				char Index2String[16], buffer[256];
				GetArrayString(Item_Name, i, buffer, sizeof(buffer));
				Format(Index2String, 16, "%i|%i", Team, i);
				
				if(SkinIndex[client][Team-2] == i)
				{
					Format(buffer, 256, "[√] %s", buffer);
				}
				else
				{
					Format(buffer, 256, "[  ] %s", buffer);
				}
				
				menu.AddItem(Index2String, buffer);
			}
		}
	}

	menu.ExitButton = true;
	menu.ExitBackButton = true;
	
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

public int Cmd_SelectSkinMenu(Handle menu, MenuAction action, int client, int select)
{	
	if(action == MenuAction_Select)
	{		
		if(IsValidClient(client))
		{
			char info[16], Indexes[2][8];

			GetMenuItem(menu, select, info, sizeof(info));
			ExplodeString(info, "|", Indexes, 2, 8);
			
			int SelectingTeam = StringToInt(Indexes[0]); // 유저가 선택하려고 한 팀
			
			int Index = StringToInt(Indexes[1]);
			char buffer[256], buffer2[256];
			
			int Team = GetArrayCell(Item_Type, Index); // 선택한 스킨의 팀
			int Auth = GetArrayCell(Item_Type2, Index);
			GetArrayString(Item_Name, Index, buffer, sizeof(buffer));
			GetArrayString(Item_Code, Index, buffer2, sizeof(buffer2));
			
			if(Auth == AUTH_VIP && !JAIL_IsClientVIP(client))
			{
				PrintToChat(client, "%s VIP고객 전용 스킨입니다.", PrintChatTag);
				return;
			}
			
			if(SelectingTeam != TEAM_ALL && SelectingTeam != Team)
			{
				PrintToChat(client, "%s 팀 선택이 잘못되었습니다.", PrintChatTag);
				return;
			}
			
			SkinIndex[client][SelectingTeam-2] = Index;
			Format(SkinName[client][SelectingTeam-2], sizeof(SkinName[][]), "%s", buffer);
			Format(SkinCode[client][SelectingTeam-2], sizeof(SkinCode[][]), "%s", buffer2);
			
			char SteamID[32];
			GetClientAuthId(client, AuthId_Steam2, SteamID, 32);
			
			SaveSettingData(client);
			
			// 유저가 선택한 아이템의 페이지를 얻어낸 후 그 페이지로 메뉴 띄우기
			int MenuSelectionPosition = RoundToFloor(float(select / GetMenuPagination(menu))) * GetMenuPagination(menu);
			SelectSkinMenu(client, SelectingTeam, MenuSelectionPosition);
		}
	}
	if(action == MenuAction_Cancel)
	{
		if(select == MenuCancel_ExitBack)
		{
			SkinMainMenu(client);
		}
		
		char tempInfo[16], tempIndexes[2][8];
		GetMenuItem(menu, 0, tempInfo, sizeof(tempInfo));
		ExplodeString(tempInfo, "|", tempIndexes, 2, 8);
		
		int SelectingTeam = StringToInt(tempIndexes[0]); // 유저가 선택하려고 한 팀
		
		if(SkinIndex[client][SelectingTeam-2] != -1)
		{
			if(UseSelected[client] == 1)
				PrintToChat(client, "%s 선택된 스킨은 다음 라운드부터 적용됩니다.", PrintChatTag);
			else
				PrintToChat(client, "%s 선택된 스킨은 '선택한 스킨 사용'을 설정해야 적용됩니다.", PrintChatTag);
		}
	}
	if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

// 쿼리용 설정 로드
void LoadSkinSettings(int client)
{
		if (db != INVALID_HANDLE)
		{
			char steamId[32];
			GetClientAuthId(client, AuthId_Engine, steamId, sizeof(steamId));
			
			char buffer[200];
			FormatEx(buffer, sizeof(buffer), "SELECT * FROM jail_playerskin_settings WHERE AuthId = '%s'", steamId);
			#if defined _DEBUG_
				PrintToServer("[JAIL PLAYER SKIN] Action:LoadSkinSettings (%s)", steamId);
			#endif
			SQL_TQuery(db, SQLUserLoad, buffer, client);
		}
}

public void SQLUserLoad(Handle owner, Handle hndl, char[] error, any client)
{
	char name[32];
	
	GetClientName(client, name, sizeof(name));

	char steamId[32];
	GetClientAuthId(client, AuthId_Steam2, steamId, 32);

	ReplaceString(name, sizeof(name), "'", "");
	ReplaceString(name, sizeof(name), "<", "");
	ReplaceString(name, sizeof(name), "\"", "");

	// 유저 정보를 찾음
	if(SQL_FetchRow(hndl))
	{
		// 데이터를 불러온다.
		UseSelected[client] = SQL_FetchInt(hndl, 3);
		SkinIndex[client][0] = SQL_FetchInt(hndl, 4);
		SQL_FetchString(hndl, 5, SkinName[client][0], sizeof(SkinName[][]));
		SkinIndex[client][1] = SQL_FetchInt(hndl, 6);
		SQL_FetchString(hndl, 7, SkinName[client][1], sizeof(SkinName[][]));
		
		// 유저의 최신 정보를 업데이트 시켜준다.
		char buffer[512];
		FormatEx(buffer, sizeof(buffer), "UPDATE jail_playerskin_settings SET Name = '%s', LastActive = '%i' WHERE AuthId = '%s'", name, GetTime(), steamId);
		#if defined _DEBUG_
			PrintToServer("[JAIL PLAYER SKIN] SQLUserLoad (%s)", steamId);
		#endif
		// 에러 체크용 콜백
		SQL_TQuery(db, SQLErrorCheckCallback, buffer);

	}
	else // 유저 정보를 찾을 수 없음
	{
		// 유저 데이터를 새로 만들어준다.
		char buffer[200];
		FormatEx(buffer, sizeof(buffer), "INSERT INTO jail_playerskin_settings (AuthId, Name, LastActive) VALUES('%s','%s', '%i')", steamId, name, GetTime());
		#if defined _DEBUG_
			PrintToServer("[JAIL PLAYER SKIN] SQLUserLoad (%s)", steamId);
		#endif
		// 에러 체크용 콜백
		SQL_TQuery(db, SQLErrorCheckCallback, buffer);
	}

	Validate(client);
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, char[] error, any data)
{
	if(!StrEqual("", error))
	{
		PrintToServer("Last Connect SQL Error: %s", error);
	}
}

void SaveSettingData(int client)
{
	if (!IsFakeClient(client))
	{		
		if (db != INVALID_HANDLE)
		{
			char steamId[32];
			GetClientAuthId(client, AuthId_Steam2, steamId, 32);

			char buffer[200];
			Format(buffer, sizeof(buffer), "SELECT * FROM jail_playerskin_settings WHERE AuthId = '%s'", steamId);
			#if defined _DEBUG_
				PrintToServer("[JAIL PLAYER SKIN] SaveSettingData (%s)", steamId);
			#endif

			Handle dataPack = CreateDataPack();
			WritePackCell(dataPack, client);
			WritePackString(dataPack, steamId);

			SQL_TQuery(db, SQLUserSave, buffer, dataPack);
		}
	}
}

public void SQLUserSave(Handle owner, Handle hndl, char[] error, Handle dataPack)
{
	ResetPack(dataPack);
	int client = ReadPackCell(dataPack);
	char steamId[32];
	ReadPackString(dataPack, steamId, sizeof(steamId));
	delete dataPack;

	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
		PrintToServer("Last Connect SQL Error: %s", error);
		return;
	}

	if(SQL_FetchRow(hndl)) 
	{
		char buffer[512];
		Format(buffer, sizeof(buffer), "UPDATE jail_playerskin_settings SET UseSelected = '%i', TSkinIndex = '%i', TSkinName = '%s', CTSkinIndex = '%i', CTSkinName = '%s' WHERE AuthId = '%s'", UseSelected[client], SkinIndex[client][0], SkinName[client][0], SkinIndex[client][1], SkinName[client][1], steamId);
		
		#if defined _DEBUG_
			PrintToServer("[JAIL PLAYER SKIN] SQLUserSave (%s)", buffer);
		#endif

		SQL_TQuery(db, SQLErrorCheckCallback, buffer);
	}

}

stock void Validate(int client)
{
	bool resetSkinData[sizeof(SkinIndex[])] =  { false, ... };
	
	for (int i = 0; i < sizeof(SkinIndex[]); i++)
	{
		if(SkinIndex[client][i] > -1)
		{
			// T 스킨으로 지정된 항목이 T가 사용할 수 없는 스킨일 때
			if(GetArrayCell(Item_Type, SkinIndex[client][i]) != TEAM_ALL && GetArrayCell(Item_Type, SkinIndex[client][i]) != TEAM_T && !resetSkinData[i])
			{
				resetSkinData[i] = true;
			}
			
			// T 스킨으로 지정된 항목VIP 용이며, 사용자가 VIP가 아닐 때
			if(GetArrayCell(Item_Type2, SkinIndex[client][i]) == AUTH_VIP && !JAIL_IsClientVIP(client) && !resetSkinData[i])
			{
				resetSkinData[i] = true;
			}
	/*		GetArrayString(Item_Code, SkinIndex[Client][i], buffer, sizeof(buffer));
			
			// client에게 저장된 스킨 경로와 본래 스킨의 경로가 다를 때
			if(!StrEqual(SkinCode[Client][i], buffer, false) && !resetSkinData[i])
			{
				resetSkinData[i] = true;
			}*/
			
			if(SkinIndex[client][i] >= Item_Count)
			{
				resetSkinData[i] = true;
			}
			
			if(resetSkinData[i])
			{
				SkinIndex[client][i] = -1;
				Format(SkinName[client][i], sizeof(SkinName[][]), NULL_STRING);
				Format(SkinCode[client][i], sizeof(SkinCode[][]), NULL_STRING);
				
				
				if(i == 0)
					PrintToChat(client, "%s 스킨 정보가 수정되어 %s 스킨 설정이 초기화되었습니다.", PrintChatTag, T_TEAM_NAME);
				else if(i == 1)
					PrintToChat(client, "%s 스킨 정보가 수정되어 %s 스킨 설정이 초기화되었습니다.", PrintChatTag, CT_TEAM_NAME);
			}
			else
			{
				// 스킨 인덱스에 맞는 스킨 경로를 얻어온다.
				GetArrayString(Item_Code, SkinIndex[client][i], SkinCode[client][i], sizeof(SkinCode[][]));
			}
		}
	}
}

void PrecasheModelList()
{
	//모델 파일을 프리캐시하고 다운로드 테이블에 올린다.
	for(int i = 0; i < Item_Count; i++)
	{
		char buffer[512];
		GetArrayString(Item_Code, i, buffer, 512);
		if(!StrEqual(buffer, NULL_STRING))
		{
			Format(buffer, sizeof(buffer), "models/%s.mdl", buffer);
			
			Downloader_AddFileToDownloadsTable(buffer);
			if(!IsModelPrecached(buffer))
				PrecacheModel(buffer);
		}
	}
}

public int Native_JAIL_OpenSkinMain(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	SkinMainMenu(client);
}