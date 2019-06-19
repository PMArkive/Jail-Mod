/* Available icons
    "icon_bulb"
    "icon_caution"
    "icon_alert"
    "icon_alert_red"
    "icon_tip"
    "icon_skull"
    "icon_no"
    "icon_run"
    "icon_interact"
    "icon_button"
    "icon_door"
    "icon_arrow_plain"
    "icon_arrow_plain_white_dn"
    "icon_arrow_plain_white_up"
    "icon_arrow_up"
    "icon_arrow_right"
    "icon_fire"
    "icon_present"
    "use_binding"
*/

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>

#undef REQUIRE_PLUGIN
#include "Jail_Mod.inc"

bool g_bCellOpened = false;

int g_iCellButton = INVALID_ENT_REFERENCE;
int g_iHintEntity = INVALID_ENT_REFERENCE;

char g_szCellButtonClassname[32];
int g_iCellButtonHammerId;

char g_szJailCellButtonDataFile[64];

public OnPluginStart() 
{
	RegAdminCmd("sm_celldoor", SetCellDoorButton, ADMFLAG_GENERIC, "감옥 문을 여는 버튼을 설정합니다.");
	RegAdminCmd("sm_t", TEST, ADMFLAG_GENERIC, "감옥 문을 여는 버튼을 설정합니다.");
	AddAmbientSoundHook(AmbientSHook:OnNormalSoundEmit);
	AddNormalSoundHook(OnNormalSoundEmit);
	
	HookEvent("round_freeze_end", OnRoundFreezeTimeEnd);
	
	BuildPath(Path_SM, g_szJailCellButtonDataFile, sizeof(g_szJailCellButtonDataFile), "data/JailCellButtonData.txt");
}

public OnMapStart()
{
	g_iCellButton = INVALID_ENT_REFERENCE;
	
	char szMapName[64];
	GetCurrentMap(szMapName, sizeof(szMapName));
	KeyValues kv = new KeyValues("ButtonInfo");
	kv.ImportFromFile(g_szJailCellButtonDataFile);
	if (kv.JumpToKey(szMapName))
	{
		kv.GetString("classname", g_szCellButtonClassname, sizeof(g_szCellButtonClassname));
		g_iCellButtonHammerId = kv.GetNum("hammer_id");
		
		FindCellButton();
	}
	delete kv;
}

public void OnCellButtonPressed(const char[] output, int caller, int activator, float delay)
{
	int ent = EntRefToEntIndex(g_iHintEntity);
	
	g_bCellOpened = true;
	
	if(IsValidEntity(ent))
	{
		AcceptEntityInput(ent, "EndHint");
		
		g_iHintEntity = DisplayInstructorHint(EntRefToEntIndex(g_iCellButton), 1.0, 0.1, 0.1, true, true, "use_binding", "icon_door", "+use", true, {255, 255, 0}, "감옥 문을 열어주세요!");
		ent = EntRefToEntIndex(g_iHintEntity);
		AcceptEntityInput(ent, "EndHint");
	}
}

public Action OnNormalSoundEmit(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	if(StrContains(sample, "beepclear") != -1)
    {
            StopSound(entity, SNDCHAN_STATIC, "ui/beepclear.wav");            
            return Plugin_Stop;
    }
	
	return Plugin_Continue;
}

public Action TEST(int client, int args)
{
	if(GetClientTeam(client) == 3) 
		CS_SwitchTeam(client, 2);
	else if(GetClientTeam(client) == 2)
		CS_SwitchTeam(client, 3);
}

public Action SetCellDoorButton(int client, int args)
{
	int ent = GetClientAimTarget(client, false);
	if(ent <= 0)
	{
		PrintToChat(client, "대상이 올바르지 않습니다.");
		return Plugin_Handled;
	}
		
	char szMapName[64];
	GetCurrentMap(szMapName, sizeof(szMapName));
	
	char szClassname[32];
	GetEdictClassname(ent, szClassname, sizeof(szClassname));
	
	if (!StrEqual(szClassname, "func_button"))
	{
		PrintToChat(client, "버튼을 대상으로 지정해주세요.");
		return Plugin_Handled;
	}
	
	int iHammerId = GetEntProp(ent, Prop_Data, "m_iHammerID");
	
	KeyValues kv = new KeyValues("ButtonInfo");
	kv.ImportFromFile(g_szJailCellButtonDataFile);
	kv.JumpToKey(szMapName, true)
	kv.SetString("classname", szClassname);
	Format(g_szCellButtonClassname, sizeof(g_szCellButtonClassname), szClassname);
	kv.SetNum("hammer_id", iHammerId);
	g_iCellButtonHammerId = iHammerId
	kv.Rewind();
	
	kv.ExportToFile(g_szJailCellButtonDataFile);
	
	delete kv;
	
	g_iCellButton = EntIndexToEntRef(ent);
	PrintToChat(client, "해당 엔티티가 감옥 문을 여는 버튼으로 지정되었습니다. \n다음 라운드부터 힌트가 제공됩니다.");
	
	return Plugin_Handled;
}

public void OnRoundFreezeTimeEnd(Event event, char[] name, bool dontBroadcast)
{
	if (!JAIL_IsPluginOn() || JAIL_IsJailActionPaused() || IsWarmupPeriod())	return;
	g_bCellOpened = false;
	
	FindCellButton();
	int iEnt = EntRefToEntIndex(g_iCellButton);
	if (IsValidEntity(iEnt)) {
		HookSingleEntityOutput(iEnt, "OnPressed", OnCellButtonPressed, false);
		g_iHintEntity = DisplayInstructorHint(iEnt, 30.0, 0.1, 0.1, true, true, "use_binding", "icon_door", "+use", true, {255, 255, 0}, "감옥 문을 열어주세요!");
	}
}

public int FindCellButton()
{
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, g_szCellButtonClassname)) != -1)  
	{
		if(GetEntProp(ent, Prop_Data, "m_iHammerID") == g_iCellButtonHammerId)
		{
			int ref = EntIndexToEntRef(ent);
			g_iCellButton = ref;
		}
	}
}

stock int DisplayInstructorHint(int iTargetEntity, float fTime, float fHeight, float fRange, bool bFollow, bool bShowOffScreen, char[] sIconOnScreen, char[] sIconOffScreen, char[] sCmd, bool bShowTextAlways, int iColor[3], char sText[100])
{
    if(!IsValidEntity(iTargetEntity))
        return INVALID_ENT_REFERENCE;
	
    int iEntity = CreateEntityByName("env_instructor_hint");
    
    if(iEntity <= 0)
        return INVALID_ENT_REFERENCE;
        
    char sBuffer[32];
    FormatEx(sBuffer, sizeof(sBuffer), "%d", iTargetEntity);
    
    // Target
    DispatchKeyValue(iTargetEntity, "targetname", sBuffer);
    DispatchKeyValue(iEntity, "hint_target", sBuffer);
    
    // Static
    FormatEx(sBuffer, sizeof(sBuffer), "%d", !bFollow);
    DispatchKeyValue(iEntity, "hint_static", sBuffer);
    
    // Timeout
    FormatEx(sBuffer, sizeof(sBuffer), "%d", RoundToFloor(fTime));
    DispatchKeyValue(iEntity, "hint_timeout", sBuffer);
    if(fTime > 0.0)
        RemoveEntity(iEntity, fTime);
    
    // Height
    FormatEx(sBuffer, sizeof(sBuffer), "%d", RoundToFloor(fHeight));
    DispatchKeyValue(iEntity, "hint_icon_offset", sBuffer);
    
    // Range
    FormatEx(sBuffer, sizeof(sBuffer), "%d", RoundToFloor(fRange));
    DispatchKeyValue(iEntity, "hint_range", sBuffer);
    
    // Show off screen
    FormatEx(sBuffer, sizeof(sBuffer), "%d", !bShowOffScreen);
    DispatchKeyValue(iEntity, "hint_nooffscreen", sBuffer);
    
    // Icons
    DispatchKeyValue(iEntity, "hint_icon_onscreen", sIconOnScreen);
    DispatchKeyValue(iEntity, "hint_icon_offscreen", sIconOffScreen);
    
    // Command binding
    DispatchKeyValue(iEntity, "hint_binding", sCmd);
    
    // Show text behind walls
    FormatEx(sBuffer, sizeof(sBuffer), "%d", bShowTextAlways);
    DispatchKeyValue(iEntity, "hint_forcecaption", sBuffer);
    
    // Text color
    FormatEx(sBuffer, sizeof(sBuffer), "%d %d %d", iColor[0], iColor[1], iColor[2]);
    DispatchKeyValue(iEntity, "hint_color", sBuffer);
    
    //Text
    ReplaceString(sText, sizeof(sText), "\n", " ");
    DispatchKeyValue(iEntity, "hint_caption", sText);
    
    DispatchSpawn(iEntity);
    AcceptEntityInput(iEntity, "ShowHint");
    
    SDKHook(iEntity, SDKHook_SetTransmit, HintTransmit);
    
    return EntIndexToEntRef(iEntity);
}

public Action HintTransmit(int entity, int client)
{
	if(IsPlayerAlive(client) && GetClientTeam(client) == 3 && !g_bCellOpened)
	{
		return Plugin_Continue;
	}
	return Plugin_Handled;
}
stock void RemoveEntity(entity, float time = 0.0)
{
    if (time == 0.0)
    {
        if (IsValidEntity(entity))
        {
            char edictname[32];
            GetEdictClassname(entity, edictname, 32);

            if (!StrEqual(edictname, "player"))
                AcceptEntityInput(entity, "kill");
        }
    }
    else if(time > 0.0)
        CreateTimer(time, RemoveEntityTimer, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
}

public Action RemoveEntityTimer(Handle Timer, any entityRef)
{
    int entity = EntRefToEntIndex(entityRef);
    if (entity != INVALID_ENT_REFERENCE)
        RemoveEntity(entity); // RemoveEntity(...) is capable of handling references
    
    return (Plugin_Stop);
}  