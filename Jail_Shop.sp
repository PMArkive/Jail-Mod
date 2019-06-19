EngineVersion g_Game;

#pragma semicolon 1

//#define _DEBUG_

#define PREFIX 	"\x01[\x0BJAIL\x01] :\x05"

#define PLUGIN_AUTHOR "Trostal"
#define PLUGIN_VERSION "0.01a"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
//#include <sdkhooks>

#undef REQUIRE_PLUGIN
#include "Jail_Mod.inc"

bool g_bIsShopOpen = true;

enum eSKILL
{
	Float:JUMP,
	Float:SPEED
}

float g_flSkillEndTime[MAXPLAYERS + 1][eSKILL];

// 레이더를 1회 구입했을시 비콘이 울릴 횟수
#define RADAR_BEACON_COUNT 3

char g_BlipSound[PLATFORM_MAX_PATH];
int g_nRadarBeaconCount = 0;
int g_BeamSprite        = -1;
int g_HaloSprite        = -1;

int redColor[4]		= {255, 75, 75, 255};
int greenColor[4]	= {75, 255, 75, 255};
int blueColor[4]	= {75, 75, 255, 255};
int greyColor[4]	= {128, 128, 128, 255};

Handle g_fwdOnShopCommand = null;

public Plugin myinfo = 
{
	name = "[JAIL] Jail Shop",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO)
	{
		SetFailState("This plugin is for CSGO only.");	
	}
	
	RegConsoleCmd("sm_shop", Cmd_ShopCommand, "상점 명령어");
	
	AddCommandListener(SayHook, "say");
	AddCommandListener(SayHook, "say_team");
	
	AddCommandListener(OnCommaCommand, "buyammo1");
	
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("round_start", OnRoundStart);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("JAIL_OpenShopMain", Native_JAIL_OpenShopMain);
	CreateNative("JAIL_SetShopState", Native_JAIL_SetShopState); // Open or Closed
	CreateNative("JAIL_GetShopState", Native_JAIL_GetShopState); // Open or Closed
	
	g_fwdOnShopCommand = CreateGlobalForward("JAIL_OnShopCommand", ET_Hook, Param_Cell);
	
	RegPluginLibrary("JAILJail");
	return APLRes_Success;
}

public void OnMapStart()
{
	InitBeaconVars();
}

public void OnClientPutInServer(int client)
{
	g_flSkillEndTime[client][JUMP] = 0.0;
	g_flSkillEndTime[client][SPEED] = 0.0;
}

public Action Cmd_ShopCommand(int client, int args)
{
	if (!JAIL_IsPluginOn() || IsWarmupPeriod())	return Plugin_Stop;
	
	Action result = Process_OnShopCommand(client);
	
	if(result == Plugin_Handled || result == Plugin_Stop)
		return Plugin_Stop;
		
	if(!JAIL_GetShopState())	return Plugin_Stop;
	
	int team = GetClientTeam(client);
	if(IsValidPlayer(client) && (team == 2 || team == 3))
		Menu_ShopMain(client);
		
		
	return Plugin_Stop;
}

public Action SayHook(int client, const char[] command, int args)
{
	if (!JAIL_IsPluginOn() || IsWarmupPeriod())	return Plugin_Continue;
	
	char Msg[256];
	GetCmdArgString(Msg, sizeof(Msg));
	Msg[strlen(Msg)-1] = '\0';

	if(StrEqual(Msg[1], "!shop", false) || StrEqual(Msg[1], "!상점", false) || StrEqual(Msg[1], "!샵", false))
	{
		Cmd_ShopCommand(client, 0);
	}
	
	return Plugin_Continue;
}

public Action OnCommaCommand(int client, const char[] command, int args)
{
	Cmd_ShopCommand(client, 0);
	return Plugin_Stop;
}

void Menu_ShopMain(int client)
{	
	Menu menu = new Menu(Handler_ShopMain);
	
	menu.SetTitle("*** BENGSHOOTER's Jail ***");
	
	// 1
	menu.AddItem("먹거리", "먹거리 [공용]");
	
	// 2
	if(GetClientTeam(client) == CS_TEAM_T)
		menu.AddItem("폭탄", "폭탄 [죄수]");
	else if(GetClientTeam(client) == CS_TEAM_CT)
		menu.AddItem("레이더", "레이더 [간수]");
	
	// 3
	menu.AddItem("스킬", "스킬 [공용]");
	
	// 4
	menu.AddItem("기타", "기타 아이템 [죄수, 공용]");
	
	// 5
	#if defined _SKIN_PLUGIN_
		menu.AddItem("스킨", "스킨 설정");
	#endif
	
	// 6
	#if defined _THIRDPERSON_PLUGIN_
		menu.AddItem("3인칭", "3인칭 설정");	
	#endif
		
	menu.ExitButton = true;
		
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_ShopMain(Menu menu, MenuAction action, int client, int select)
{
	if (!JAIL_IsPluginOn() || IsWarmupPeriod())	return;
	if (!JAIL_GetShopState())	return;
	
	if(action == MenuAction_Select)
	{
		// 먹거리(공통)
		if(select == 0)
		{
			Menu_ShopFood(client);
		}
		else if(select == 1)
		{
			// 폭탄(죄수)
			if(GetClientTeam(client) == CS_TEAM_T)
			{
				Menu_ShopGrenade(client);
			}
			// 레이더(간수)
			else if(GetClientTeam(client) == CS_TEAM_CT)
			{
				Menu_ShopRadar(client);
			}
		}
		// 스킬(공통)
		else if(select == 2)
		{
			Menu_ShopSkill(client);
		}
		// 기타(공통)
		else if(select == 3)
		{
			Menu_ShopItems(client);
		}
	}
	if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Menu_ShopFood(client)
{
	Menu menu = new Menu(Handler_ShopFood);
	
	menu.SetTitle("*** 먹거리 ***");
	
	if (!JAIL_IsClientVIP(client))
	{
		menu.AddItem("빵|30|3000", "빵[+HP 30] (3,000$)");
		menu.AddItem("고구마|50|5000", "고구마[+HP 50] (5,000$)");
		menu.AddItem("고기|70|7000", "고기[+HP 70] (7,000$)");
		menu.AddItem("모닝셋트|100|10000", "모닝셋트[+HP 100] (10,000$)");
	}
	else
	{
		menu.AddItem("빵|30|2500", "빵[+HP 30] ($ 2,500)");
		menu.AddItem("고구마|50|4500", "고구마[+HP 50] (4,500$)");
		menu.AddItem("고기|70|6500", "고기[+HP 70] (6,500$)");
		menu.AddItem("모닝셋트|100|9000", "모닝셋트[+HP 100] ($ 9,000)");
		menu.AddItem("수라상|170|15500", "수라상[+HP 170] ($ 15,500))");
	}
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public Menu_ShopGrenade(client)
{	
	Menu menu = new Menu(Handler_ShopGrenade);
	
	menu.SetTitle("*** 수류탄 ***");
	
	if (!JAIL_IsClientVIP(client))
	{
		menu.AddItem("수류탄|hegrenade|3000", "수류탄 (3,000$)");
		menu.AddItem("섬광탄|flashbang|3000", "섬광탄 (3,000$)");
		menu.AddItem("연막탄|smokegrenade|5000", "연막탄 (5,000$)");
	}
	else
	{
		menu.AddItem("수류탄|hegrenade|2500", "수류탄 (2,500$)");
		menu.AddItem("섬광탄|flashbang|2500", "섬광탄 (2,500$)");
		menu.AddItem("연막탄|smokegrenade|4500", "연막탄 (4,500$)");
	}
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public Menu_ShopRadar(client)
{
	Menu menu = new Menu(Handler_ShopRadar);
	
	menu.SetTitle("*** 레이더 ***");
	
	char RadarMenuString[64];
	
	if (!JAIL_IsClientVIP(client))
	{
		Format(RadarMenuString, sizeof(RadarMenuString), "레이더 [반란시간 전 %d초 위치파악] (3,000$)", RADAR_BEACON_COUNT);
		menu.AddItem("레이더|3000", RadarMenuString);
	}
	else
	{
		Format(RadarMenuString, sizeof(RadarMenuString), "레이더 [반란시간 전 %d초 위치파악] (2,500$)", RADAR_BEACON_COUNT);
		menu.AddItem("레이더|2500", RadarMenuString);
	}
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public Menu_ShopSkill(client)
{
	Menu menu = CreateMenu(Handler_ShopSkill);
	
	menu.SetTitle("*** 스킬 ***");
	
	if (!JAIL_IsClientVIP(client))
	{
		menu.AddItem("혼신의 질주|speed|5|5000", "혼신의 질주[5초간 속도상승] (5,000$)");
		menu.AddItem("마지막 철장|jump|5|5000", "마지막 철장[5초간 점프상승] (5,000$)");
	}
	else
	{
		menu.AddItem("혼신의 질주|speed|5|4500", "혼신의 질주[5초간 속도상승] (4,500$)");
		menu.AddItem("마지막 철장|jump|5|4500", "마지막 철장[5초간 점프상승] (4,500$)");
	}
		
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public Menu_ShopItems(client)
{
	Menu menu = CreateMenu(Handler_ShopItems);
	
	menu.SetTitle("*** 기타 아이템 ***");
	
	if (!JAIL_IsClientVIP(client))
	{
		if(GetClientTeam(client) == CS_TEAM_T)
		{
			menu.AddItem("숟가락|knife|4000", "숟가락[Knife] (4,000$) - 죄수");
			menu.AddItem("암거래(Glock)|glock|14000", "암거래[Glock] (14,000$) - 죄수");
		}
		menu.AddItem("주무기 탄창 1개|primary_ammo|3000", "주무기 탄창 + 1개 (3,000$)");
		menu.AddItem("보조무기 탄창 1개|secondary_ammo|2000", "보조무기 탄창 + 1개 (2,000$)");
	}
	else
	{
		if(GetClientTeam(client) == CS_TEAM_T)
		{
			menu.AddItem("숟가락|knife|3000 - 죄수", "숟가락[Knife] (3,000$) - 죄수");
			menu.AddItem("암거래(USP)|usp_silencer|8000", "암거래[Usp] (8,000$) - 죄수");
			menu.AddItem("암거래(UMP-45)|ump45|14000", "암거래[UMP-45] (14,000$) - 죄수");
		}
		menu.AddItem("주무기 탄창 1개|primary_ammo|3000", "주무기 탄창 + 1개 (3,000$)");
		menu.AddItem("보조무기 탄창 1개|secondary_ammo|2000", "보조무기 탄창 + 1개 (2,000$)");
	}
		
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	
	menu.Display(client, MENU_TIME_FOREVER);
}

/*******************************************************
 상점 메뉴 핸들러 함수
*******************************************************/

// 먹거리 메뉴 핸들러
public int Handler_ShopFood(Menu menu, MenuAction action, int client, int select)
{
	if (!JAIL_IsPluginOn() || IsWarmupPeriod())	return;
	if (!JAIL_GetShopState())	return;
	
	if(action == MenuAction_Select)
	{
		char info[96];
		menu.GetItem(select, info, sizeof(info));
		
		/*
		 * info 문자열의 포메이션
		 * 
		 * <이름>|<추가할 체력>|<가격>
		 */
		
		char iteminfo[3][32];
		ExplodeString(info, "|", iteminfo, sizeof(iteminfo), sizeof(iteminfo[]));
		
		int HealthToAdd = StringToInt(iteminfo[1]);
		int ItemPrice = StringToInt(iteminfo[2]);
		
		if(IsPlayerAlive(client))
		{
			if(GetEntProp(client, Prop_Send, "m_iAccount") >= ItemPrice)
			{
			//	char PriceString[32];
			//	FormatNumber_(ItemPrice, PriceString, sizeof(PriceString));
				
				
				// 출력
				PrintToChat(client, " \x07-$%d\x01: %s [+HP %d] 구입.", ItemPrice, iteminfo[0], HealthToAdd);
				
				// 돈 감소
				SetEntProp(client, Prop_Send, "m_iAccount", GetEntProp(client, Prop_Send, "m_iAccount") - ItemPrice);
				
				// 체력 추가
				SetEntityHealth(client, GetClientHealth(client) + HealthToAdd);
			}
			else
			{
				PrintToChat(client, "%s 돈이 부족합니다.", PREFIX);
			}
		}
		else
		{
			PrintToChat(client, "%s 죽은사람은 상점을 이용 할 수 없습니다.", PREFIX);
		}
	}
	if(action == MenuAction_Cancel)
	{
		if(select == MenuCancel_ExitBack)
		{
			Menu_ShopMain(client);
		}
	}
	if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

// 수류탄 메뉴 핸들러
public int Handler_ShopGrenade(Menu menu, MenuAction action, int client, int select)
{
	if (!JAIL_IsPluginOn() || IsWarmupPeriod())	return;
	if (!JAIL_GetShopState())	return;
	
	if(action == MenuAction_Select)
	{
		char info[96];
		menu.GetItem(select, info, sizeof(info));
		
		/*
		 * info 문자열의 포메이션
		 * 
		 * <아이템 이름(weapon_ 생략)>|<가격>
		 */
		
		char iteminfo[3][32];
		ExplodeString(info, "|", iteminfo, sizeof(iteminfo), sizeof(iteminfo[]));
		
		char itemClsname[32];
		Format(itemClsname, sizeof(itemClsname), "weapon_%s", iteminfo[1]);
		int ItemPrice = StringToInt(iteminfo[2]);
		
		if(IsPlayerAlive(client))
		{
			if(GetEntProp(client, Prop_Send, "m_iAccount") >= ItemPrice)
			{
				char PriceString[32];
				FormatNumber_(ItemPrice, PriceString, sizeof(PriceString));
				
				// 출력
				PrintToChat(client, " \x07-$%d\x01: %s 구입.", ItemPrice, iteminfo[0]);
				
				// 돈 감소
				SetEntProp(client, Prop_Send, "m_iAccount", GetEntProp(client, Prop_Send, "m_iAccount") - ItemPrice);
				
				// 아이템 지급
				GivePlayerItem(client, itemClsname);
			}
			else
			{
				PrintToChat(client, "%s 돈이 부족합니다.", PREFIX);
			}
		}
		else
		{
			PrintToChat(client, "%s 죽은사람은 상점을 이용 할 수 없습니다.", PREFIX);
		}
	}
	if(action == MenuAction_Cancel)
	{
		if(select == MenuCancel_ExitBack)
		{
			Menu_ShopMain(client);
		}
	}
	if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

// 레이더 메뉴 핸들러
public int Handler_ShopRadar(Menu menu, MenuAction action, int client, int select)
{
	if (!JAIL_IsPluginOn() || IsWarmupPeriod())	return;
	if (!JAIL_GetShopState())	return;
	
	if(action == MenuAction_Select)
	{
		char info[64];
		menu.GetItem(select, info, sizeof(info));
		
		/*
		 * info 문자열의 포메이션
		 * 
		 * <아이템 이름(weapon_ 생략)>|<가격>
		 */
		
		char iteminfo[2][32];
		ExplodeString(info, "|", iteminfo, sizeof(iteminfo), sizeof(iteminfo[]));
		
		int ItemPrice = StringToInt(iteminfo[1]);
		
		if(IsPlayerAlive(client))
		{
			if(GetEntProp(client, Prop_Send, "m_iAccount") >= ItemPrice)
			{
				char PriceString[32];
				FormatNumber_(ItemPrice, PriceString, sizeof(PriceString));
				
				if(g_nRadarBeaconCount <= 0)
				{
					if(!JAIL_IsRebelable())
					{
						// 출력
						PrintToChat(client, " \x07-$%d\x01: %s %d회 구입.", ItemPrice, iteminfo[0], RADAR_BEACON_COUNT);
						
						// 돈 감소
						SetEntProp(client, Prop_Send, "m_iAccount", GetEntProp(client, Prop_Send, "m_iAccount") - ItemPrice);
						
						// 레이더 실행
						CreateBeacon(CS_TEAM_T, RADAR_BEACON_COUNT);
					}else
					{
						PrintToChat(client, "%s 반란시간 이전에만 사용 가능합니다.", PREFIX);
					}
				}else
				{
					PrintToChat(client, "%s 이미 레이더를 사용중입니다.", PREFIX);
					Menu_ShopRadar(client);
				}
			}
			else
			{
				PrintToChat(client, "%s 돈이 부족합니다.", PREFIX);
			}
		}
		else
		{
			PrintToChat(client, "%s 죽은사람은 상점을 이용 할 수 없습니다.", PREFIX);
		}
	}
	if(action == MenuAction_Cancel)
	{
		if(select == MenuCancel_ExitBack)
		{
			Menu_ShopMain(client);
		}
	}
	if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

// 스킬 메뉴 핸들러
public int Handler_ShopSkill(Menu menu, MenuAction action, int client, int select)
{
	if (!JAIL_IsPluginOn() || IsWarmupPeriod())	return;
	if (!JAIL_GetShopState())	return;
	
	if(action == MenuAction_Select)
	{
		char info[128];
		menu.GetItem(select, info, sizeof(info));
		
		/*
		 * info 문자열의 포메이션
		 * 
		 * <아이템 이름>|<타입>|<지속시간 (실수)>|<가격>
		 */
		
		char iteminfo[4][32];
		ExplodeString(info, "|", iteminfo, sizeof(iteminfo), sizeof(iteminfo[]));
		
		int ItemPrice = StringToInt(iteminfo[3]);
		
		if(IsPlayerAlive(client))
		{
			if(GetEntProp(client, Prop_Send, "m_iAccount") >= ItemPrice)
			{
				char PriceString[32];
				FormatNumber_(ItemPrice, PriceString, sizeof(PriceString));
				
				// 출력
				PrintToChat(client, " \x07-$%d\x01: %s 구입. \x03%s초\x01동안 적용.", ItemPrice, iteminfo[0], iteminfo[2]);
				
				// 돈 감소
				SetEntProp(client, Prop_Send, "m_iAccount", GetEntProp(client, Prop_Send, "m_iAccount") - ItemPrice);
				
				// 스킬 적용
				if(StrEqual(iteminfo[1], "jump"))
				{
					// 해당 스킬을 사용중이지 않을 때
					if(g_flSkillEndTime[client][JUMP] <= 0.0)
					{
						SetEntityGravity(client, 0.2);
						g_flSkillEndTime[client][JUMP] = GetGameTime() + StringToFloat(iteminfo[2]);
					}
					else // 이미 해당 스킬을 사용중일 때
					{
						// 시간만 늘려준다.
						g_flSkillEndTime[client][JUMP] += StringToFloat(iteminfo[2]);
					}
				}
				else if(StrEqual(iteminfo[1], "speed"))
				{					
					// 해당 스킬을 사용중이지 않을 때
					if(g_flSkillEndTime[client][SPEED] <= 0.0)
					{
						SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue") + 1.0);
						g_flSkillEndTime[client][SPEED] = GetGameTime() + StringToFloat(iteminfo[2]);
					}
					else // 이미 해당 스킬을 사용중일 때
					{
						// 시간만 늘려준다.
						g_flSkillEndTime[client][SPEED] += StringToFloat(iteminfo[2]);
					}
				}
			}
			else
			{
				PrintToChat(client, "%s 돈이 부족합니다.", PREFIX);
			}
		}
		else
		{
			PrintToChat(client, "%s 죽은사람은 상점을 이용 할 수 없습니다.", PREFIX);
		}
	}
	if(action == MenuAction_Cancel)
	{
		if(select == MenuCancel_ExitBack)
		{
			Menu_ShopMain(client);
		}
	}
	if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

// 기타 아이템 메뉴 핸들러
public int Handler_ShopItems(Menu menu, MenuAction action, int client, int select)
{
	if (!JAIL_IsPluginOn() || IsWarmupPeriod())	return;
	if (!JAIL_GetShopState())	return;
	
	if(action == MenuAction_Select)
	{
		char info[96];
		menu.GetItem(select, info, sizeof(info));
		
		/*
		 * info 문자열의 포메이션
		 * 
		 * <아이템 이름(weapon_ 생략)>|<가격>
		 */
		
		char iteminfo[3][32];
		ExplodeString(info, "|", iteminfo, sizeof(iteminfo), sizeof(iteminfo[]));
		
		int ItemPrice = StringToInt(iteminfo[2]);
		
		if(IsPlayerAlive(client))
		{
			if(GetEntProp(client, Prop_Send, "m_iAccount") >= ItemPrice)
			{
				char PriceString[32];
				FormatNumber_(ItemPrice, PriceString, sizeof(PriceString));
				
				// 아이템 지급
				if(StrEqual(iteminfo[1], "primary_ammo"))
				{
					int weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
					if(weapon != -1)
					{
						char szWeaponClassname[32];
						GetEdictClassname(weapon, szWeaponClassname, sizeof(szWeaponClassname));
						switch (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
						{
							case 60: strcopy(szWeaponClassname, sizeof(szWeaponClassname), "weapon_m4a1_silencer");
							case 61: strcopy(szWeaponClassname, sizeof(szWeaponClassname), "weapon_usp_silencer");
							case 63: strcopy(szWeaponClassname, sizeof(szWeaponClassname), "weapon_cz75a");
						}
						int reserveAmmo = GetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount");
						int weaponClipSize = CacheClipSize(szWeaponClassname[7]);
						
						// 탄약을 추가하고도 최대 예비탄약 수를 초과하지 않아야 한다.
						if(CacheReserveAmmoMaxSize(szWeaponClassname[7]) >= reserveAmmo + weaponClipSize)
						{
							SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", reserveAmmo + weaponClipSize);
						}
						else
						{
							PrintToChat(client, "%s 이미 탄약이 충분합니다.", PREFIX);
							return;
						}
					}
					else
					{
						PrintToChat(client, "%s 보유중인 주무기가 없습니다!", PREFIX);
						return;
					}
				}
				else if(StrEqual(iteminfo[1], "secondary_ammo"))
				{
					int weapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
					if(weapon != -1)
					{
						char szWeaponClassname[32];
						GetEdictClassname(weapon, szWeaponClassname, sizeof(szWeaponClassname));
						switch (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
						{
							case 60: strcopy(szWeaponClassname, sizeof(szWeaponClassname), "weapon_m4a1_silencer");
							case 61: strcopy(szWeaponClassname, sizeof(szWeaponClassname), "weapon_usp_silencer");
							case 63: strcopy(szWeaponClassname, sizeof(szWeaponClassname), "weapon_cz75a");
						}
						int reserveAmmo = GetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount");
						int weaponClipSize = CacheClipSize(szWeaponClassname[7]);
						
						// 탄약을 추가하고도 최대 예비탄약 수를 초과하지 않아야 한다.
						if(CacheReserveAmmoMaxSize(szWeaponClassname[7]) >= reserveAmmo + weaponClipSize)
						{
							SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", reserveAmmo + weaponClipSize);
						}
						else
						{
							PrintToChat(client, "%s 이미 탄약이 충분합니다.", PREFIX);
							return;
						}
					}
					else
					{
						PrintToChat(client, "%s 보유중인 주무기가 없습니다!", PREFIX);
						return;
					}
				}
				else
				{
					char itemClsname[32];
					Format(itemClsname, sizeof(itemClsname), "weapon_%s", iteminfo[1]);
				
					GivePlayerItem(client, itemClsname);
				}
				
				// 출력
				PrintToChat(client, " \x07-$%d\x01: %s 구입.", ItemPrice, iteminfo[0]);
				
				// 돈 감소
				SetEntProp(client, Prop_Send, "m_iAccount", GetEntProp(client, Prop_Send, "m_iAccount") - ItemPrice);
			}
			else
			{
				PrintToChat(client, "%s 돈이 부족합니다.", PREFIX);
			}
		}
		else
		{
			PrintToChat(client, "%s 죽은사람은 상점을 이용 할 수 없습니다.", PREFIX);
		}
	}
	if(action == MenuAction_Cancel)
	{
		if(select == MenuCancel_ExitBack)
		{
			Menu_ShopMain(client);
		}
	}
	if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}
public void omgrp(int data)
{
	SetEntProp(data, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
}
/*******************************************************
 이벤트
*******************************************************/
public void OnRoundStart(Event event, char[] name, bool dontBroadcast)
{
	g_nRadarBeaconCount = 0;
	
	if (IsWarmupPeriod())	return;
	
	JAIL_SetShopState(true);
	
	PrintToChatAll("%s 상점 이용은 ','키로 이용이 가능합니다.", PREFIX);
}

public void OnPlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	g_flSkillEndTime[client][JUMP] = 0.0;
	SetEntityGravity(client, 1.0);
	
	g_flSkillEndTime[client][SPEED] = 0.0;
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
}

/*******************************************************
 OnPlayerRunCmd()
*******************************************************/
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	#if defined _DEBUG_
		SetEntProp(client, Prop_Send, "m_iAccount", 16000);
	#endif
	
	if (!IsValidClient(client))	return Plugin_Continue;
	
	/*
	if(IsValidPlayer(client))
	{
		int eweapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		int reserveAmmo = GetEntProp(eweapon, Prop_Send, "m_iPrimaryReserveAmmoCount");
		PrintToConsole(client, "%d", reserveAmmo);
	}*/
	
	char szSkillLeftTimeString[256];
	static float shouldPrintEndedSkillText[MAXPLAYERS + 1][eSKILL];
	
	if(g_flSkillEndTime[client][SPEED] > 0.0)
	{		
		// 이전에 수정된 문자열이 있다면 한 줄을 띄워준다.
		if(szSkillLeftTimeString[0])
			Format(szSkillLeftTimeString, sizeof(szSkillLeftTimeString), "%s\n", szSkillLeftTimeString);
		
		// 스킬의 사용이 끝난 시점
		if(g_flSkillEndTime[client][SPEED] < GetGameTime())
		{
			g_flSkillEndTime[client][SPEED] = 0.0;
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue") - 1.0);
			
			shouldPrintEndedSkillText[client][SPEED] = GetGameTime() + 3.0;
		}
		else // 스킬 사용중
		{
			float flSkillEndTime = g_flSkillEndTime[client][SPEED] - GetGameTime();
			
			int sec = RoundToFloor(flSkillEndTime); // flSkillEndTime / 1.0
			float point = flSkillEndTime - sec;
			
			Format(szSkillLeftTimeString, sizeof(szSkillLeftTimeString), "%s<font color='#0fff0f'>혼신의 질주</font>:<font color='#0fff0f'> ", szSkillLeftTimeString);
			for (int i = sec; i > 0; i--)
			{
				Format(szSkillLeftTimeString, sizeof(szSkillLeftTimeString), "%s■", szSkillLeftTimeString);
			}
			
			for (float i = point; i > 0.5; i-=0.5)
			{
				Format(szSkillLeftTimeString, sizeof(szSkillLeftTimeString), "%s□", szSkillLeftTimeString);
			}
			
			Format(szSkillLeftTimeString, sizeof(szSkillLeftTimeString), "%s</font>", szSkillLeftTimeString);
		}
	}
	else
	{
		if(shouldPrintEndedSkillText[client][SPEED] > 0.0)
		{			
			// 이전에 수정된 문자열이 있다면 한 줄을 띄워준다.
			if(szSkillLeftTimeString[0])
				Format(szSkillLeftTimeString, sizeof(szSkillLeftTimeString), "%s\n", szSkillLeftTimeString);
			
			// 출력 시간이 끝난 시점
			if(shouldPrintEndedSkillText[client][SPEED] < GetGameTime())
			{
				shouldPrintEndedSkillText[client][SPEED] = 0.0;
			}
			else // 출력이 진행되고 있는 시점
			{
				Format(szSkillLeftTimeString, sizeof(szSkillLeftTimeString), "%s<font color='#0fff0f'>혼신의 질주</font> 스킬 사용이 끝났습니다.", szSkillLeftTimeString);
			}
		}
	}
	
	if(g_flSkillEndTime[client][JUMP] > 0.0)
	{		
		// 이전에 수정된 문자열이 있다면 같이 사용중인 상태. 한 줄을 띄워준다.
		if(szSkillLeftTimeString[0])
			Format(szSkillLeftTimeString, sizeof(szSkillLeftTimeString), "%s\n", szSkillLeftTimeString);
			
		// 스킬의 사용이 끝난 시점
		if(g_flSkillEndTime[client][JUMP] < GetGameTime())
		{
			g_flSkillEndTime[client][JUMP] = 0.0;
			SetEntityGravity(client, 1.0);
			
			shouldPrintEndedSkillText[client][JUMP] = GetGameTime() + 3.0;
		}
		else // 스킬 사용중
		{
			float flSkillEndTime = g_flSkillEndTime[client][JUMP] - GetGameTime();
			
			int sec = RoundToFloor(flSkillEndTime); // flSkillEndTime / 1.0
			float point = flSkillEndTime - sec;
			
			Format(szSkillLeftTimeString, sizeof(szSkillLeftTimeString), "%s<font color='#ffff0f'>마지막 철장</font>:<font color='#ffff0f'> ", szSkillLeftTimeString);
			for (int i = sec; i > 0; i--)
			{
				Format(szSkillLeftTimeString, sizeof(szSkillLeftTimeString), "%s■", szSkillLeftTimeString);
			}
			
			for (float i = point; i > 0.5; i-=0.5)
			{
				Format(szSkillLeftTimeString, sizeof(szSkillLeftTimeString), "%s□", szSkillLeftTimeString);
			}
			
			Format(szSkillLeftTimeString, sizeof(szSkillLeftTimeString), "%s</font>", szSkillLeftTimeString);
		}
	}
	else
	{
		if(shouldPrintEndedSkillText[client][JUMP] > 0.0)
		{			
			// 이전에 수정된 문자열이 있다면 한 줄을 띄워준다.
			if(szSkillLeftTimeString[0])
				Format(szSkillLeftTimeString, sizeof(szSkillLeftTimeString), "%s\n", szSkillLeftTimeString);
			
			// 출력 시간이 끝난 시점
			if(shouldPrintEndedSkillText[client][JUMP] < GetGameTime())
			{
				shouldPrintEndedSkillText[client][JUMP] = 0.0;
			}
			else // 출력이 진행되고 있는 시점
			{
				Format(szSkillLeftTimeString, sizeof(szSkillLeftTimeString), "%s<font color='#ffff0f'>마지막 철장</font> 스킬 사용이 끝났습니다.", szSkillLeftTimeString);
			}
		}
	}
	
	if(szSkillLeftTimeString[0])
	{	
		PrintCenterText(client, szSkillLeftTimeString);
	}
	
	return Plugin_Continue;
}
/*******************************************************
 일반 함수
*******************************************************/
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

/********************* 레이더 관련 *********************/
void CreateBeacon(int team, int count)
{
	PrintToChatAll("%s 간수가 레이더 기능을 사용하였습니다. [%d초간 죄수위치 파악]", PREFIX, RADAR_BEACON_COUNT);
	
	if(g_nRadarBeaconCount <= 0)
	{
		g_nRadarBeaconCount += count;
		Timer_TeamBeacon(INVALID_HANDLE, team);
	}
	else	g_nRadarBeaconCount += count;
}

public Action Timer_TeamBeacon(Handle timer, int team)
{
	if(g_nRadarBeaconCount <= 0 || JAIL_IsRebelable())
		return Plugin_Stop;
	else
	{
		g_nRadarBeaconCount--;
		CreateTimer(1.0, Timer_TeamBeacon, team, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	for (int client=1;client <= MaxClients;client++)
	{
		if (IsValidPlayer(client))
		{
			if (GetClientTeam(client) == team)
			{
				float vec[3];
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
			}
		}
	}
	return Plugin_Continue;
}

/*******************************************************
 스톡 함수
*******************************************************/
stock void SetAmmo(int client, int item, int ammo)
{
	SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, item);
}

stock int GetAmmo(int client, int item)
{
	return GetEntProp(client, Prop_Send, "m_iAmmo", _, item);
}

stock int GetWeaponClip(int weapon)
{
	return GetEntProp(weapon, Prop_Send, "m_iClip1");
}

stock void SetWeaponClip(int weapon, int clip)
{
	SetEntProp(weapon, Prop_Send, "m_iClip1", clip);
}

stock int GetWeaponAmmoType(int weapon)
{
	return GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
}

stock void SetWeaponReserveAmmo(int client, int weapon, int ammo)
{
	int iAmmoType = GetWeaponAmmoType(weapon);
	
	if (iAmmoType > 0)
		SetAmmo(client, iAmmoType, ammo);
	
	SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
	SetEntProp(weapon, Prop_Send, "m_iSecondaryReserveAmmoCount", ammo);	
}

stock int GetWeaponReserveAmmo(int client, int weapon)
{
	int iAmmoType = GetWeaponAmmoType(weapon);
	
	if (iAmmoType > 0)
		return GetAmmo(client, iAmmoType);
		
	return -1;
}

stock int CacheClipSize(const char[] sz_item)
{
	if  (StrEqual(sz_item, "mag7", false))
		return 5;
		
	else if  (StrEqual(sz_item, "xm1014", false) || StrEqual(sz_item, "sawedoff", false))
		return 7;
		
	else if  (StrEqual(sz_item, "m3", false) || StrEqual(sz_item, "nova", false))
		return 8;
		
	else if  (StrEqual(sz_item, "ssg08", false) || StrEqual(sz_item, "awp", false))
		return 10;
		
	else if  (StrEqual(sz_item, "g3sg1", false) || StrEqual(sz_item, "scar20", false) || StrEqual(sz_item, "m4a1_silencer", false))
		return 20;
		
	else if  (StrEqual(sz_item, "famas", false) || StrEqual(sz_item, "ump45", false))
		return 25;
		
	// ak47,  aug,  m4a1,  sg553,  mac10,  mp7,  mp9
	else if  (StrEqual(sz_item, "ak47", false) || StrEqual(sz_item, "m4a1", false) || StrEqual(sz_item, "aug", false) || StrEqual(sz_item, "sg556", false)
		|| StrEqual(sz_item, "mac10", false) || StrEqual(sz_item, "mp7", false) || StrEqual(sz_item, "mp9", false))
		return 30;
		
	else if  (StrEqual(sz_item, "galil", false))
		return 35;
		
	else if  (StrEqual(sz_item, "p90", false))
		return 50;
		
	else if  (StrEqual(sz_item, "bizon", false))
		return 64;
		
	else if  (StrEqual(sz_item, "m249", false))
		return 100;
		
	else if  (StrEqual(sz_item, "negev", false))
		return 150;
		
	else if  (StrEqual(sz_item, "deagle", false))
		return 7;
		
	else if  (StrEqual(sz_item, "usp_silencer", false) || StrEqual(sz_item, "weapon_cz75a", false))
		return 12;
		
	else if  (StrEqual(sz_item, "p228", false) || StrEqual(sz_item, "hkp2000", false) || StrEqual(sz_item, "p250", false))
		return 13;
		
	else if (StrEqual(sz_item, "glock", false) || StrEqual(sz_item, "fiveseven", false))
		return 20;
		
	else if (StrEqual(sz_item, "elite", false))
		return 30;
		
	else if (StrEqual(sz_item, "tec9", false))
		return 24;
		
	return -1;
}

stock int CacheReserveAmmoMaxSize(const char[] sz_item)
{
	if (StrEqual(sz_item, "cz75a", false))
		return 12;
		
	if (StrEqual(sz_item, "usp_silencer", false))
		return 24;
		
	if (StrEqual(sz_item, "p250", false))
		return 26;
		
	if (StrEqual(sz_item, "awp", false))
		return 30;
		
	if (StrEqual(sz_item, "nova", false) || StrEqual(sz_item, "sawedoff", false) || StrEqual(sz_item, "xm1014", false) || StrEqual(sz_item, "mag7", false))
		return 32;
	
	if (StrEqual(sz_item, "deagle", false))
		return 35;
		
	if (StrEqual(sz_item, "m4a1_silencer", false))
		return 40;
	
	if (StrEqual(sz_item, "hpk2000", false))
		return 52;
		
	if (StrEqual(sz_item, "ssg08", false) || StrEqual(sz_item, "ak47", false) || StrEqual(sz_item, "aug", false) || StrEqual(sz_item, "famas", false)
	 || StrEqual(sz_item, "galilar", false) || StrEqual(sz_item, "m4a1", false) || StrEqual(sz_item, "sg556", false) || StrEqual(sz_item, "g3sg1", false)
	 || StrEqual(sz_item, "scar20", false))
		return 90;
	
	if (StrEqual(sz_item, "fiveseven", false) || StrEqual(sz_item, "mag10", false) || StrEqual(sz_item, "p90", false) || StrEqual(sz_item, "ump45", false))
		return 100;
		
	if (StrEqual(sz_item, "elite", false) || StrEqual(sz_item, "tec9", false) || StrEqual(sz_item, "mp7", false) || StrEqual(sz_item, "mp9", false) || StrEqual(sz_item, "glock", false) || StrEqual(sz_item, "bizon", false))
		return 120;
		
	if (StrEqual(sz_item, "m249", false) || StrEqual(sz_item, "negev", false))
		return 200;
			
	return -1;
}

/*******************************************************
 네이티브, 포워드 관련 함수
*******************************************************/

/* 네이티브 - JAIL_GetShopState */
public int Native_JAIL_GetShopState(Handle plugin, int numParams)
{
	return g_bIsShopOpen;
}

/* 네이티브 - JAIL_SetShopState */
public int Native_JAIL_SetShopState(Handle plugin, int numParams)
{
	bool open = view_as<bool>(GetNativeCell(1));
	
	g_bIsShopOpen = open;
}

/* 네이티브 - JAIL_OpenShopMain */
public int Native_JAIL_OpenShopMain(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	Cmd_ShopCommand(client, 0);
}

Action Process_OnShopCommand(client)
{
	// Start forward call.
    Call_StartForward(g_fwdOnShopCommand);
    
    // Push the parameters.
    Call_PushCell(client);
    
    // Get what they returned.
    Action result;
    Call_Finish(result);
    return result;
}