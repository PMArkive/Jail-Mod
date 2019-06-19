#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define PLUGIN_AUTHOR "Trostal"
#define PLUGIN_VERSION "0.01a"

#undef REQUIRE_PLUGIN
#include "Jail_Mod.inc"

#pragma semicolon 1
#pragma newdecls required

#define PrintChatTag "\x01[\x0BJAIL\x01] :\x05" // 채팅에 출력할 때, 이 문자열을 앞에 두고 출력시킵니다.

bool TeamSwapListed[MAXPLAYERS+1] = false;

float nexthudtime = 0.0;

Handle TeamSwapWaitList[2] = INVALID_HANDLE;

Handle g_hOnSwapPostForward = INVALID_HANDLE;

UserMsg g_msgHudMsg; 

public Plugin myinfo =
{
	name = "[JAIL] Quick Team Swap",
	author = PLUGIN_AUTHOR,
	description = "빠른 팀 상호교체",
	version = PLUGIN_VERSION,
	url = "https://github.com/Hatser/Jail-Mod"
};

public void OnPluginStart()
{
	TeamSwapWaitList[0] = CreateArray();
	TeamSwapWaitList[1] = CreateArray();
	
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("round_end", event_round_end);
	
	RegAdminCmd("qs_debug_array", Debug_Array, ADMFLAG_ROOT);
	RegConsoleCmd("sm_swap", Command_ListSwap);
	
	AddCommandListener(callsayhook, "say");
	
	g_msgHudMsg = GetUserMessageId("HudMsg"); 
}



public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("JAIL_IsSwapListExist", Native_JAIL_IsSwapListExist);
	CreateNative("JAIL_EraseClientOnList", Native_JAIL_EraseClientOnList);
	CreateNative("JAIL_GetFirstListed", Native_JAIL_GetFirstListed);
	g_hOnSwapPostForward = CreateGlobalForward("JAIL_OnQuickSwapPost", ET_Ignore);
	RegPluginLibrary("JAILJail");
	return APLRes_Success;
}

public void OnMapStart()
{
	ClearArray(TeamSwapWaitList[0]);
	ClearArray(TeamSwapWaitList[1]);
	
	nexthudtime = GetGameTime();
}

public void OnClientPutInServer(int client)
{
	JAIL_EraseClientOnList(client, false);
}

public void OnClientDisconnect(int client)
{
	JAIL_EraseClientOnList(client, false);
}

public void OnGameFrame()
{
	float nowtime = GetGameTime();

	if(nexthudtime <= nowtime)
	{
		nexthudtime = nowtime + 1.0;
		int color[4] = {255, 255, 255, 255};
		for (int i = 1; i <= MaxClients; i++)
		{
			if(!IsClientInGame(i) || IsFakeClient(i) || !TeamSwapListed[i])
				continue;

			int team = GetClientTeam(i);
			if(team != 2 && team != 3)
				continue;
			
			char TeamName[16];
			if(team == 2)
				Format(TeamName, sizeof(TeamName), "죄수");
			else if(team == 3)
				Format(TeamName, sizeof(TeamName), "간수");
			
			SendSyncHudToOne(i, color, "빠른 팀 교체 (순번: %s팀 %i번)\n간수: %i명 대기 중\n죄수: %i명 대기 중", TeamName, FindValueInArray(TeamSwapWaitList[team-2], GetClientUserId(i)) + 1, GetSwapListCount(CS_TEAM_CT), GetSwapListCount(CS_TEAM_T));
		}
	}
}


public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int Client = GetClientOfUserId(event.GetInt("userid"));
	int newTeam = event.GetInt("team");
	int oldTeam = event.GetInt("oldteam");
	
	if(IsValidClient(Client))
	{
		if(newTeam != oldTeam)
		{
			JAIL_EraseClientOnList(Client, true);
		}
	}
}

public Action event_round_end(Event event, const char[] Name, bool dontBroadcast)
{
	TeamSwap();
}

public Action Debug_Array(int client, int args)
{
	if(GetArraySize(TeamSwapWaitList[0]) > 0)
		PrintToConsole(client, "==== Terror Quick Team Swap List ====");
	for(int i=0;i < GetArraySize(TeamSwapWaitList[0]);i++)
	{
		int listed = GetClientOfUserId(GetArrayCell(TeamSwapWaitList[0], i));
		PrintToConsole(client, "%i) %N", i+1, listed);
	}
	
	if(GetArraySize(TeamSwapWaitList[1]) > 0)
		PrintToConsole(client, "==== Counter-Terror Quick Team Swap ====");
	for(int i=0;i < GetArraySize(TeamSwapWaitList[1]);i++)
	{
		int listed = GetClientOfUserId(GetArrayCell(TeamSwapWaitList[1], i));
		PrintToConsole(client, "%i) %N", i+1, listed);
	}

	return Plugin_Handled;
}

public Action Command_ListSwap(int client, int args)
{
	if(TeamSwapListed[client] == false)
	{
		int CurrentTeam = GetClientTeam(client);
		if(!(CurrentTeam == CS_TEAM_T || CurrentTeam == CS_TEAM_CT) || !IsValidClient(client))
			return Plugin_Stop;
		
		WantToSwapTeam(client);
	}
	else
	{
		Menu_CancelQuickSwap(client);
	}
	
	return Plugin_Handled;
}

void Menu_CancelQuickSwap(int client)
{
	if(!IsClientInGame(client) || IsFakeClient(client) || !TeamSwapListed[client])
		return;

	int team = GetClientTeam(client);
	if(team != 2 && team != 3)
	{
		JAIL_EraseClientOnList(client, true);
	}
			
	char TeamName[16];
	if(team == 2)
		Format(TeamName, sizeof(TeamName), "죄수");
	else if(team == 3)
		Format(TeamName, sizeof(TeamName), "간수");

	Menu menu = CreateMenu(Handler_CancelQuickSwap);
	
	menu.SetTitle("빠른 팀 교체 (순번: %s팀 %i번)\n간수: %i명 대기 중\n죄수: %i명 대기 중\n빠른 팀 교체를 취소하시겠습니까?", TeamName, FindValueInArray(TeamSwapWaitList[team - 2], GetClientUserId(client)) + 1, GetSwapListCount(CS_TEAM_CT), GetSwapListCount(CS_TEAM_T));
	
	menu.AddItem("Yes", "예");
	menu.AddItem("No", "아니오");
	
	menu.ExitButton = false;
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_CancelQuickSwap(Menu menu, MenuAction action, int client, int select)
{	
	if(action == MenuAction_Select)
	{
		if(select == 0)
		{
			JAIL_EraseClientOnList(client, true);
		}
	}
	if(action == MenuAction_End)
	{
		delete menu;
	}
}

stock int GetSwapListCount(int team)
{
	return GetArraySize(TeamSwapWaitList[team-2]);
}

public int Native_JAIL_IsSwapListExist(Handle plugin, int args)
{
	int team = GetNativeCell(1);

	if(team == CS_TEAM_T || team == CS_TEAM_CT)
	{
		return (GetArraySize(TeamSwapWaitList[team-2]) > 0);
	}
	return false;
}

public int Native_JAIL_EraseClientOnList(Handle plugin, int args)
{
	int client = GetNativeCell(1);
	bool notify = view_as<bool>(GetNativeCell(2));
	
	if(TeamSwapListed[client] == true)
	{
		int userID = GetClientUserId(client);
		TeamSwapListed[client] = false;
		bool exception = true;
		for(int i = 0; i < sizeof(TeamSwapWaitList); i++)
		{
			int index = FindValueInArray(TeamSwapWaitList[i], userID);
			if(index != -1)
			{
				RemoveFromArray(TeamSwapWaitList[i], index);
				exception = false;
				break;
			}
		}

		if(exception)
		{
			LogError("JAIL JAIL Quick Swap System: Failed to erase a client on swap-waiter list (can't find the index of a client)", client, userID);
			LogError("client: %N (index: %i | UserId: %i) || IsValid: %s", client, client, userID, IsValidClient(client)?"Yes":"No");
		}
		
		if(IsValidClient(client) && notify)
			PrintToChat(client, "%s 팀 교체 신청이 취소되었습니다.", PrintChatTag);
	}
}

public int Native_JAIL_GetFirstListed(Handle plugin, int args)
{
	int team = GetNativeCell(1);
	int result;
	if(team == CS_TEAM_T || team == CS_TEAM_CT)
		if(JAIL_IsSwapListExist(team))
		{
			result = GetClientOfUserId(GetArrayCell(TeamSwapWaitList[team-2], 0));
			
			if(IsValidClient(result))
				return result;
			else
			{
				JAIL_EraseClientOnList(result);
				return JAIL_GetFirstListed(team);
			}
		}

	return -1;
}

void TeamSwap()
{
	while(JAIL_IsSwapListExist(CS_TEAM_T) && JAIL_IsSwapListExist(CS_TEAM_CT))
	{
		int TMember = GetClientOfUserId(GetArrayCell(TeamSwapWaitList[CS_TEAM_T-2], 0));
		int CTMember = GetClientOfUserId(GetArrayCell(TeamSwapWaitList[CS_TEAM_CT-2], 0));

		if(!IsValidClient(TMember) || TeamSwapListed[TMember] != true)
		{
			JAIL_EraseClientOnList(TMember, true);
			continue;
		}
		if(!IsValidClient(CTMember) || TeamSwapListed[CTMember] != true)
		{
			JAIL_EraseClientOnList(CTMember, true);
			continue;
		}

		CS_SwitchTeam(TMember, CS_TEAM_CT);
		CS_SwitchTeam(CTMember, CS_TEAM_T);

		PrintToChat(TMember, "%s \x0F%N\x05님과 팀이 교체되었습니다.", PrintChatTag, CTMember);
		PrintToChat(CTMember, "%s \x0B%N\x05님과 팀이 교체되었습니다.", PrintChatTag, TMember);

		JAIL_EraseClientOnList(TMember, false);
		JAIL_EraseClientOnList(CTMember, false);
	}
	
	Call_StartForward(g_hOnSwapPostForward);
	Call_Finish();
}

void WantToSwapTeam(int client)
{
	int userID = GetClientUserId(client);
	JAIL_EraseClientOnList(client, false);
	TeamSwapListed[client] = true;
	
	int CurrentTeam = GetClientTeam(client);

	PushArrayCell(TeamSwapWaitList[CurrentTeam-2], userID);

	if(CurrentTeam == 2)
		PrintToChatAll("%s \x0F%N\x05님이 \x0B간수팀\x05으로 교체하기를 원합니다!", PrintChatTag, client);
	else if(CurrentTeam == 3)
		PrintToChatAll("%s \x0B%N\x05님이 \x0F죄수팀\x05으로 교체하기를 원합니다!", PrintChatTag, client);
}


public Action callsayhook(int client, const char[] command, int Arg)
{
	char Msg[256];
	GetCmdArgString(Msg, sizeof(Msg));
	int length = strlen(Msg);
	if(length <= 0)
		return Plugin_Continue;

	Msg[length-1] = '\0';

	if(StrEqual(Msg[1], "!팀교체", false)
	|| StrEqual(Msg[1], "!팀스왑", false)
	|| StrEqual(Msg[1], "!스왑", false))
	{
		Command_ListSwap(client, 0);
	}
	return Plugin_Continue;
}

stock bool SendSyncHudToOne(int client, int color[4], char[] text, any:...)
{
	if(IsClientInGame(client))
	{
		char message[100];
		VFormat(message, sizeof(message), text, 4);	
		
		Handle hHudSync = CreateHudSynchronizer();
		SetHudTextParams(0.0, -1.0, 1.0, color[0], color[1], color[2], color[3], _, _, 0.0, 0.1);
		ClearSyncHud(client, hHudSync);
		ShowSyncHudText(client, hHudSync, message);
		
		return true;
	}
	return false;
}