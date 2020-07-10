/*
* TakeOffCostume - Models Change Plugin.
* by: DENFER
*
* https://github.com/KWDENFER/TakeOffCostume
* https://vk.com/denferez
* https://steamcommunity.com/id/denferez
*
* This program is free software; you can redistribute it and/or modify it under
* the terms of the GNU General Public License, version 3.0, as published by the
* Free Software Foundation.
* 
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
* details.
*
* You should have received a copy of the GNU General Public License along with
* this program. If not, see <http://www.gnu.org/licenses/>.
*/
// Main Includes 
#include <sourcemod>
#include <sdktools>
#include <cstrike>

// Сustom Includes
#include <colorvariables>
#include <autoexecconfig>
#include <emitsoundany> 
#include <smartdm>

// Defines
#define AUTHOR "DENFER"
#define TAKE_OFF_COSTUME_VERSION "1.0.0 Beta"
#define MAX_ITEMS 16 // максимальное количество скинов, которое может храниться у игрока в инвентаре (советую придерживаться в рамках 8 скинов)
#define DEBUG 1

// ConVars 
ConVar gc_bSaveCostumesEveryRoundInventory;
ConVar gc_bSaveCostumesEveryRound;
ConVar gc_bSaveCostumesAfterDeath;
ConVar gc_iNotificationMode;
ConVar gc_bNotification;
ConVar gc_fMaxDistance;
ConVar gc_iRemoveBody;
ConVar gc_iChangeMode;
ConVar gc_bInventory;
ConVar gc_iTimeMenu;
ConVar gc_sPrefix;
ConVar gc_iChance;
ConVar gc_bLogs;

// Sounds ConVars
ConVar gc_sSoundPutsOnInventory;
ConVar gc_sSoundOpenInventary1;
ConVar gc_sSoundOpenInventary2;
ConVar gc_sSoundOpenInventary3;
ConVar gc_sDeleteCostume;
ConVar gc_sSoundPutsOn1;
ConVar gc_sSoundPutsOn2;
ConVar gc_bSound;


// Strings
char g_sCostumesInventory[MAXPLAYERS+1][MAX_ITEMS][PLATFORM_MAX_PATH]; // 0 - всегда скин, который надет на вас 
char g_sPathModelPrevious[MAXPLAYERS+1][PLATFORM_MAX_PATH];
char g_sReservedModel[MAXPLAYERS+1][PLATFORM_MAX_PATH];
char g_sPathModel[MAXPLAYERS+1][PLATFORM_MAX_PATH];
char g_sBuffer[MAXPLAYERS+1][PLATFORM_MAX_PATH];
char g_logsPath[PLATFORM_MAX_PATH];
char g_kvPath[128];
char g_sPrefix[64];

// Sound Strings
char g_sSoundPutsOnInventory[PLATFORM_MAX_PATH];
char g_sSoundOpenInventary1[PLATFORM_MAX_PATH];
char g_sSoundOpenInventary2[PLATFORM_MAX_PATH];
char g_sSoundOpenInventary3[PLATFORM_MAX_PATH];
char g_sDeleteCostume[PLATFORM_MAX_PATH];
char g_sSoundPutsOn1[PLATFORM_MAX_PATH];
char g_sSoundPutsOn2[PLATFORM_MAX_PATH];

// Floats
float g_fCoordinatesVictim[MAXPLAYERS+1][3];

// Integers
int g_iCheckIndexes[MAXPLAYERS+1];
int g_iTimerLevelCounter[MAXPLAYERS+1];
int g_iTimerLevel[MAXPLAYERS+1];

// Booleans
bool g_bIsCheckInterval[MAXPLAYERS+1];
bool g_bStopPrintMessage[MAXPLAYERS+1];

// Debug variables
float g_fStartTime;
float g_fStopTime
int g_iCostumes;
int g_iErrors;
int g_iFile; // 0 - KeyValues - значения: 0 - Найден и работает, 1 - найден, но работает неисправно, 2 - не найден

// My Libraries
#include <kwStocks>
#if DEBUG
#include <kwDebug>
#endif 

// pragma 
#pragma semicolon 1
#pragma tabsize 0 
#pragma newdecls required

// Informations
public Plugin myinfo = {
	name = "TakeOffCostume",
	author = "DENFER (for all questions - https://vk.com/denferez)",
	description = "You have a unique opportunity to remove the costume from the enemy)",
	version = TAKE_OFF_COSTUME_VERSION,
};

public void OnPluginStart()
{
    // Transaltion
    LoadTranslations("TakeOffCostume.phrases");

    // Logs
    #if DEBUG
    char buffer[PLATFORM_MAX_PATH]; 
    LoadTranslations("TakeOffCostumeDebug.phrases");
    BuildPath(Path_SM, g_logsPath, sizeof(g_logsPath), "logs/DENFER");
    DirExistsEx(g_logsPath);
    SetLogFile(g_logsPath, "TakeOffCostume", "DENFER");
    g_fStartTime = (float(GetSysTickCount()) / 1000);
    if(GetEngineVersion() != Engine_CSGO)
		LogToFile(g_logsPath, "%t", "Engine_Version_Warning", buffer);
    // Admin Commands
    RegAdminCmd("sm_debug", Debug, ADMFLAG_GENERIC);
    #endif

    // KeyValues
    BuildPath(Path_SM, g_kvPath, sizeof(g_kvPath), "configs/DENFER/TakeOffCostume/modelpaths.cfg");

    // Client Commands
    RegConsoleCmd("sm_inventory", Menu_SkinsInventory, "Открывает инвентарь игрока");

    // AutoExecConfig
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("TakeOffCostume", AUTHOR);

    gc_iChangeMode = AutoExecConfig_CreateConVar("sm_toc", "1", "0 - выкл. плагин, 1 - только Т, 2 - только КТ, 3 - обе команды (допустим вы выбрали 1 => если Т убивает СТ, то игрок за Т имеет возможность надеть скин проивника)", 0, true, 0.0, true, 3.0);
    gc_sPrefix = AutoExecConfig_CreateConVar("sm_toc_prefix", "[{green}SM{default}]", "Префикс перед сообщениями плагина");
    gc_bLogs = AutoExecConfig_CreateConVar("sm_toc_logging", "1", "Разрешить плагину вести журнал ошибок? (0 - запретить, 1 - разрешить)", 0, true, 0.0, true, 1.0);
    gc_iChance = AutoExecConfig_CreateConVar("sm_toc_chance", "100", "Вероятность c которой игрок имеет возможность сменить скин (ставьте 100 - если хотите, чтобы игрок в любом случае мог сменить скин)", 0, true, 1.0, true, 100.0);
    gc_fMaxDistance = AutoExecConfig_CreateConVar("sm_toc_distance", "150", "Максимальное расстояние между атакующим и жертвой (не советую ставить большое значение, но если вы хотите убрать ограничение, то ставьте 8192, по-моему это максимальная длина и соответсвенно ширина карты, но данную статистику я брал еще с GoldSource)", 0, true, 0.0, false);
    gc_bSaveCostumesEveryRound = AutoExecConfig_CreateConVar("sm_toc_savecostume_everyround", "0", "Разрешить игроку сохранять свой скин на следующий раунд (0 - запретить, 1 - разрешить)", 0, true, 0.0, true, 1.0);
    gc_bNotification = AutoExecConfig_CreateConVar("sm_toc_notification", "0", "Разрешить уведомлять атакующего после убийства игрока о том, что он может снять скин с игрока? (0 - запретить, 1 - разрешить)", 0, true, 0.0, true, 1.0);
    gc_iRemoveBody = AutoExecConfig_CreateConVar("sm_toc_remove_body", "0", "0 - оставляет тело убитого игрока на месте, не меняя скин, если его подобрал другой игрок, 1 - удалить тело, 2 - сжечь тело, 3 - поменять скин трупа на скин игрока, который снял форму с потерпевшего (данный режим вызывает проблемы, если игрок снял форму в воде или на лестнице, то труп будет кидать во все стороны, пожалуйста, будте аккуратны с данным режимом, в крайнем случае посоветуйтесь со мной)", 0, true, 0.0, true, 3.0);
    gc_iTimeMenu = AutoExecConfig_CreateConVar("sm_toc_menu_time", "10", "Сколько секунд удерживать меню для выбора скина (при условие, что sm_notification 1), 0 - будет активно, пока его не закроют", 0, true, 0.0, false);
    gc_iNotificationMode = AutoExecConfig_CreateConVar("sm_toc_messages_mode", "3", "0 - выключить все сообщения плагина, 1 - сообщать в чате, 2 - сообщать только в окне снизу (Hint), 3 - 1, 2 вместе", 0, true, 0.0, true, 3.0);
    gc_bInventory = AutoExecConfig_CreateConVar("sm_toc_inventory", "0", "Разрешить инвентарь, в котором игроки смогут хранить свои скины? (0 - запретить, 1 - разрешить)", 0, true, 0.0, true, 1.0);
    gc_bSaveCostumesEveryRoundInventory = AutoExecConfig_CreateConVar("sm_toc_save_everyround_inventory", "0", "Разрешить сохранять инвентарь игрока в течение всей карты? (0 - запретить, 1 - разрешить) (при 0 инвентарь в начале каждого раунда будет очищаться)", 0, true, 0.0, true, 1.0);
    gc_bSaveCostumesAfterDeath = AutoExecConfig_CreateConVar("sm_toc_save_afterdeath_inventory", "0", "Разрешить игроку сохранять инвентарь после смерти? (0 - запретить, 1 - разрешить. (учтите, что sm_takeoffcostume_savecostumes_everyround может быть равен 0, тогда в следующем раунде все равно очистится инвентарь))", 0, true, 0.0, true, 1.0);
    gc_bSound = AutoExecConfig_CreateConVar("sm_toc_sound", "1", "Разрешить звуковую составляющую плагина? (0 - запретить, 1 - разрешить)", 0, true, 0.0, true, 1.0);
    gc_sSoundPutsOn1 = AutoExecConfig_CreateConVar("sm_toc_sound_putson1", "DENFER/TakeOffCostume/put_on1.mp3", "Путь к файлу 'снятие скина с противника' №1");
    gc_sSoundPutsOn2 = AutoExecConfig_CreateConVar("sm_toc_sound_putson2", "DENFER/TakeOffCostume/put_on2.mp3", "Путь к файлу 'снятие скина с противника' №2");
    gc_sSoundPutsOnInventory = AutoExecConfig_CreateConVar("sm_toc_sound_change", "DENFER/TakeOffCostume/put_on_from_inventary.mp3", "Путь к звуковому файлу 'смена скина в инвентаря'");
    gc_sSoundOpenInventary1 = AutoExecConfig_CreateConVar("sm_toc_sound_open_inventory1", "DENFER/TakeOffCostume/open_inventory1.mp3", "Путь к звуковому файлу 'открытие инвентаря' №1");
    gc_sSoundOpenInventary2 = AutoExecConfig_CreateConVar("sm_toc_sound_open_inventory2", "DENFER/TakeOffCostume/open_inventory2.mp3", "Путь к звуковому файлу 'открытие инвентаря' №2");
    gc_sSoundOpenInventary3 = AutoExecConfig_CreateConVar("sm_toc_sound_open_inventory3", "DENFER/TakeOffCostume/open_inventory3.mp3", "Путь к звуковому файлу 'открытие инвентаря' №3");
    gc_sDeleteCostume = AutoExecConfig_CreateConVar("sm_toc_sound_delete_costume", "DENFER/TakeOffCostume/delete_costume.mp3", "Путь к звуковому файлу 'выкинуть скин из инвентаря'");

    HookEvent("player_spawn", PlayerSpawn);
    HookEvent("player_death", PlayerDeath);
    HookEvent("round_start", RoundStart);
    HookEvent("round_end", RoundEnd);

    // AutoExecConfig
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
}

public void OnMapStart()
{
    char buffer[PLATFORM_MAX_PATH];
    KeyValues hKeyValues = new KeyValues("Models");
    hKeyValues.Rewind();

    if(hKeyValues.GotoFirstSubKey())
    {
        do
        {
            hKeyValues.GetString("path", buffer, sizeof(buffer));
            PrecacheModel(buffer, true); // если каким-то образом плагин, который предоставляет модели не сделал это
        }
        while (hKeyValues.GotoNextKey());
    }

    if(gc_bSound.BoolValue)
    {
        PrecacheSoundAnyDownload(g_sSoundPutsOn1);
        PrecacheSoundAnyDownload(g_sSoundPutsOn2); 
        PrecacheSoundAnyDownload(g_sSoundPutsOnInventory);  
        PrecacheSoundAnyDownload(g_sSoundOpenInventary1);
        PrecacheSoundAnyDownload(g_sSoundOpenInventary2);
        PrecacheSoundAnyDownload(g_sSoundOpenInventary3);
    }
}

public void OnConfigsExecuted()
{
    gc_sSoundPutsOnInventory.GetString(g_sSoundPutsOnInventory, sizeof(g_sSoundPutsOnInventory));
    gc_sSoundOpenInventary1.GetString(g_sSoundOpenInventary1, sizeof(g_sSoundOpenInventary1));
    gc_sSoundOpenInventary2.GetString(g_sSoundOpenInventary2, sizeof(g_sSoundOpenInventary2));
    gc_sSoundOpenInventary3.GetString(g_sSoundOpenInventary3, sizeof(g_sSoundOpenInventary3));
    gc_sDeleteCostume.GetString(g_sDeleteCostume, sizeof(g_sDeleteCostume));
    gc_sSoundPutsOn1.GetString(g_sSoundPutsOn1, sizeof(g_sSoundPutsOn1));
    gc_sSoundPutsOn2.GetString(g_sSoundPutsOn2, sizeof(g_sSoundPutsOn2));
    gc_sPrefix.GetString(g_sPrefix, sizeof(g_sPrefix));
    
    for(int i = 1; i <= MaxClients; ++i)
        for(int j = 0; j < MAX_ITEMS; ++j)
            g_sCostumesInventory[i][j][0] = 0;

    if(gc_bLogs.BoolValue) // DEBUG and logging
    {
        LogToFile(g_logsPath, "%t", "Server_Logs_Running"); 
        if(!gc_iChangeMode.IntValue)
        {
            LogToFile(g_logsPath, "%t", "Running_In_The_Background");
        }
        CheckKVStruct(); // проверяем КВ структуру на наличие ошибок
    } 
}

public void PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{   
    if(gc_iChangeMode.IntValue)
    {
        int client = GetClientOfUserId(GetEventInt(event, "userid"));
        GetClientModel(client, g_sPathModelPrevious[client], sizeof(g_sPathModelPrevious));

        if(gc_bInventory.BoolValue)
            strcopy(g_sCostumesInventory[client][0], sizeof(g_sCostumesInventory), g_sPathModelPrevious[client]);

        CreateTimer(1.0, Timer_SaveModel, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE); // 1.0 т.к возможно скин устанавливается с задержкой
    }
}

public void PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    if(gc_iChangeMode.IntValue)
    {
        int victim = GetClientOfUserId(GetEventInt(event, "userid"));
        int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
        int Ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
        int chance = GetRandomInt(1,100);

        if(strlen(g_sReservedModel[victim]) != 0)
        {
            g_sPathModel[victim][0] = '\0';
            g_sReservedModel[victim][0] = '\0';
        }


        if(chance <= gc_iChance.IntValue)
        {
            GetClientAbsOrigin(victim, g_fCoordinatesVictim[victim]); // фиксируем координаты жертвы

            if(!gc_bSaveCostumesAfterDeath.BoolValue)
                for(int i = 1; i < MAX_ITEMS; ++i)
                    g_sCostumesInventory[victim][i][0] = 0;

            if(attacker && victim)
            {
                switch(gc_iChangeMode.IntValue)
                {
                    case 1:
                    {
                        if(GetClientTeam(attacker) == CS_TEAM_T && GetClientTeam(victim) == CS_TEAM_CT && IsPlayerAlive(attacker)) // только Т
                        {
                            if(CheckDistance(attacker, victim) <= gc_fMaxDistance.FloatValue)
                            {
                                Ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll"); // физика сущности
                                g_bIsCheckInterval[attacker] = true; // разрешаем завести новые таймеры для атакующего, при новом убийстве
                                g_iTimerLevel[attacker] = 0; // обнуляем уровень таймера
                                g_iTimerLevelCounter[attacker] = 0; // обнуляем счетчик вызванных таймеров

                                if(gc_bNotification.BoolValue || gc_bInventory.BoolValue)
                                {
                                    GetClientModel(victim, g_sPathModel[attacker], sizeof(g_sPathModel));
                                    GetClientModel(attacker, g_sPathModel[victim], sizeof(g_sPathModel));
                                    Menu_TakeOffCostume(attacker, victim);
                                }
                                else
                                {
                                    if(gc_bSound.BoolValue)
                                    {
                                        int sound = GetRandomInt(1,2);
                                        sound == 1 ? PrecacheAndEmitSoundToClientAny(attacker, g_sSoundPutsOn1) : PrecacheAndEmitSoundToClientAny(attacker, g_sSoundPutsOn2);
                                    }
                                    if(Ragdoll > 0)
                                        SetEntityModel(Ragdoll, g_sPathModel[attacker]);
                                    GetClientModel(victim, g_sPathModel[attacker], sizeof(g_sPathModel)); // заносим скин в ячейку атакующего
                                    SetEntityModel(attacker, g_sPathModel[attacker]);
                                }
                            }
                        }
                    }
                    case 2:
                    {
                        if(GetClientTeam(attacker) == CS_TEAM_CT && GetClientTeam(victim) == CS_TEAM_T && IsPlayerAlive(attacker)) // только КТ
                        {
                            if(CheckDistance(attacker, victim) <= gc_fMaxDistance.FloatValue)
                            {
                                Ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
                                g_bIsCheckInterval[attacker] = true;
                                g_iTimerLevel[attacker] = 0;
                                g_iTimerLevelCounter[attacker] = 0;

                                if(gc_bNotification.BoolValue || gc_bInventory.BoolValue)
                                {
                                    GetClientModel(victim, g_sPathModel[attacker], sizeof(g_sPathModel));
                                    GetClientModel(attacker, g_sPathModel[victim], sizeof(g_sPathModel));
                                    Menu_TakeOffCostume(attacker, victim);
                                }
                                else
                                {
                                    if(gc_bSound.BoolValue)
                                    {
                                        int sound = GetRandomInt(1,2);
                                        sound == 1 ? PrecacheAndEmitSoundToClientAny(attacker, g_sSoundPutsOn1) : PrecacheAndEmitSoundToClientAny(attacker, g_sSoundPutsOn2);
                                    }
                                    if(Ragdoll > 0)
                                        SetEntityModel(Ragdoll, g_sPathModel[attacker]);
                                    GetClientModel(victim, g_sPathModel[attacker], sizeof(g_sPathModel));
                                    SetEntityModel(attacker, g_sPathModel[attacker]);
                                }
                            }
                        }
                    }
                    case 3:
                    {
                        if(GetClientTeam(attacker) == CS_TEAM_T && IsPlayerAlive(attacker)) // если атакующий Т
                        {
                            if(CheckDistance(attacker, victim) <= gc_fMaxDistance.FloatValue)
                            {
                                Ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
                                g_bIsCheckInterval[attacker] = true;
                                g_iTimerLevel[attacker] = 0;
                                g_iTimerLevelCounter[attacker] = 0;

                                if(gc_bNotification.BoolValue || gc_bInventory.BoolValue)
                                {  
                                    GetClientModel(victim, g_sPathModel[attacker], sizeof(g_sPathModel));
                                    GetClientModel(attacker, g_sPathModel[victim], sizeof(g_sPathModel));
                                    Menu_TakeOffCostume(attacker, victim);
                                }
                                else
                                {
                                    if(gc_bSound.BoolValue)
                                    {
                                        int sound = GetRandomInt(1,2);
                                        sound == 1 ? PrecacheAndEmitSoundToClientAny(attacker, g_sSoundPutsOn1) : PrecacheAndEmitSoundToClientAny(attacker, g_sSoundPutsOn2);
                                    }
                                    if(Ragdoll > 0)
                                        SetEntityModel(Ragdoll, g_sPathModel[attacker]);
                                    GetClientModel(victim, g_sPathModel[attacker], sizeof(g_sPathModel)); // заносим скин в ячейку атакующего
                                    SetEntityModel(attacker, g_sPathModel[attacker]);
                                }   
                            }
                        }              
                        if(GetClientTeam(attacker) == CS_TEAM_CT && IsPlayerAlive(attacker)) // если атакующий КТ
                        {
                            if(CheckDistance(attacker, victim) <= gc_fMaxDistance.FloatValue)
                            {
                                Ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
                                g_bIsCheckInterval[attacker] = true;
                                g_iTimerLevel[attacker] = 0;
                                g_iTimerLevelCounter[attacker] = 0;

                                if(gc_bNotification.BoolValue || gc_bInventory.BoolValue)
                                {
                                    GetClientModel(victim, g_sPathModel[attacker], sizeof(g_sPathModel));
                                    GetClientModel(attacker, g_sPathModel[victim], sizeof(g_sPathModel));
                                    Menu_TakeOffCostume(attacker, victim);
                                }
                                else
                                {
                                    if(gc_bSound.BoolValue)
                                    {
                                        int sound = GetRandomInt(1,2);
                                        sound == 1 ? PrecacheAndEmitSoundToClientAny(attacker, g_sSoundPutsOn1) : PrecacheAndEmitSoundToClientAny(attacker, g_sSoundPutsOn2);
                                    }
                                    if(Ragdoll > 0)
                                        SetEntityModel(Ragdoll, g_sPathModel[attacker]);
                                    GetClientModel(victim, g_sPathModel[attacker], sizeof(g_sPathModel)); // заносим скин в ячейку атакующего
                                    SetEntityModel(attacker, g_sPathModel[attacker]);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

public void RoundStart(Event event, const char[] name, bool dontBroadcast) 
{
    if(gc_iChangeMode.IntValue)
    {
        for(int i = 1;i <= MaxClients; i++)
        {
            g_bIsCheckInterval[i] = true;
            g_iCheckIndexes[i] = -1;
        }

        if(!gc_bSaveCostumesEveryRoundInventory.BoolValue)
        {
            for(int i = 1; i <= MaxClients; ++i)
                for(int j = 1; j < MAX_ITEMS; ++j)
                g_sCostumesInventory[i][j][0] = 0; // очистка инвентаря всех игроков
        }
        else
        {
            for(int i = 1; i <= MaxClients; ++i) // сортировочка инвентаря (с начала идут пути, потом пустые ячейки [path1, path2, path3, 0, 0, 0])
            {
                for (int j = 0; j < MAX_ITEMS; ++j)
                {
                    if(g_sCostumesInventory[i][j][0] != 0) // проверка на путь, != '0' => path
                    {
                        int k = 0;
                        while(k != j)
                        {
                            if(g_sCostumesInventory[i][k][0] == 0)
                            {
                                strcopy(g_sCostumesInventory[i][k], sizeof(g_sCostumesInventory), g_sCostumesInventory[i][j]); // свапаем скин с '0', тем самым сортируем в порядке "убывания"
                                g_sCostumesInventory[i][j][0] = 0;
                            }
                            k++;
                        }
                    }
                }
            }
        }
    }
}

public void RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if(gc_bSaveCostumesEveryRound.BoolValue && !gc_bInventory.BoolValue)
        for(int i = 1; i <= MaxClients; ++i)
            if(IsClientInGame(i) && IsPlayerAlive(i))
                    strcopy(g_sReservedModel[i], sizeof(g_sReservedModel), g_sPathModel[i]);
}

//////////////////////////////////////////////////////////
//                                                      //
//                         MENU                         //
//                                                      //
//////////////////////////////////////////////////////////

public Action Menu_TakeOffCostume(int attacker, int victim)
{    
    DataPack hdPack = new DataPack();
    hdPack.WriteCell(GetClientUserId(attacker));
    hdPack.WriteCell(victim);

    g_iCheckIndexes[attacker] = victim; // фиксируем нового потерпевшего, чтобы завершить предыдущие таймеры 

    if(g_iTimerLevelCounter[attacker] > 200  && g_iTimerLevelCounter[attacker] < 240)
        g_iTimerLevel[attacker] = 1;
    else if(g_iTimerLevelCounter[attacker] > 240 && g_iTimerLevelCounter[attacker] < 300)
            g_iTimerLevel[attacker] = 2;
        else if(g_iTimerLevelCounter[attacker] > 300)
                g_iTimerLevel[attacker] = 3;

    if(g_bIsCheckInterval[attacker])
        switch(g_iTimerLevel[attacker])
        {
            case 1: CreateTimer(1.0, Timer_CheckInterval, hdPack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
            case 2: CreateTimer(2.5, Timer_CheckInterval, hdPack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
            case 3: CreateTimer(5.0, Timer_CheckInterval, hdPack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
            default: CreateTimer(0.1, Timer_CheckInterval, hdPack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        }

    Menu menu = new Menu(HandlerMenu_TakeOffCostume);
    char info[128];
    FormatEx(info,sizeof(info),"%T", "Title_Menu", attacker);
    menu.SetTitle(info);

    if(gc_bNotification.BoolValue)
    {
        FormatEx(info,sizeof(info),"%T", "Yes", attacker);
        menu.AddItem("yes", info);
        FormatEx(info,sizeof(info),"%T", "No", attacker);
        menu.AddItem("no", info);
    }
    
    if(gc_bInventory.BoolValue && gc_bNotification.BoolValue)
    {
        FormatEx(info,sizeof(info),"%T", "Take_In_Inventory", attacker);
        menu.AddItem("take", info);
        menu.ExitButton = false;
    }

    if(gc_bInventory.BoolValue && !gc_bNotification.BoolValue)
    {
        FormatEx(info,sizeof(info),"%T", "Take_In_Inventory", attacker);
        menu.AddItem("take", info);
        menu.ExitButton = true;
    }

    if(g_bIsCheckInterval[attacker])
    {
        if(gc_iTimeMenu.IntValue)
        {
            CreateDataTimer(float(gc_iTimeMenu.IntValue), Timer_CloseMenu, hdPack, TIMER_FLAG_NO_MAPCHANGE);
            hdPack.WriteCell(GetClientUserId(attacker));
            hdPack.WriteCell(victim);
        }
        menu.Display(attacker, gc_iTimeMenu.IntValue);
    }
    else 
    {
        menu.Display(attacker, 1);
        delete hdPack;
    }
}

public int HandlerMenu_TakeOffCostume(Menu menu, MenuAction action, int attacker, int param2)
{	
	if(action == MenuAction_Select)
	{
        char bufferChat[PLATFORM_MAX_PATH];
        char bufferHint[PLATFORM_MAX_PATH];
        DataPack hdPack = new DataPack();
        char info[32];

        menu.GetItem(param2, info, sizeof(info));

        if(strcmp(info, "yes") == 0)
        {
            if(IsPlayerAlive(attacker) && attacker)
            {
                g_bIsCheckInterval[attacker] = false;
                g_bStopPrintMessage[attacker] = true;

                if(gc_bInventory.BoolValue)
                {
                    for(int i = 0; i < MAX_ITEMS; ++i)
                    {
                        if(strcmp(g_sPathModel[attacker], g_sCostumesInventory[attacker][i]) == 0)
                        {
                            FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "Has_Already_Inventory");
                            FormatEx(bufferHint, sizeof(bufferHint), "%t", "Has_Already_Inventory_PCT");
                            MyPrint(attacker, bufferChat, bufferHint);
                            return;
                        }
                    }
                }
                
                GetClientModel(attacker, g_sBuffer[attacker], sizeof(g_sBuffer));

                if(strcmp(g_sPathModel[attacker], g_sBuffer[attacker]) == 0)
                {
                    FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "Has_Already");
                    FormatEx(bufferHint, sizeof(bufferHint), "%t", "Has_Already_PCT");
                    MyPrint(attacker, bufferChat, bufferHint);
                }
                else
                {
                    FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "Accepted");
                    FormatEx(bufferHint, sizeof(bufferHint), "%t", "Accepted_PCT");
                    MyPrint(attacker, bufferChat, bufferHint);

                    if(gc_bSound.BoolValue)
                    {
                        int sound = GetRandomInt(1,2);
                        sound == 1 ? PrecacheAndEmitSoundToClientAny(attacker, g_sSoundPutsOn1) : PrecacheAndEmitSoundToClientAny(attacker, g_sSoundPutsOn2);
                    }

                    CreateDataTimer(3.0, Timer_Ragdoll, hdPack, TIMER_FLAG_NO_MAPCHANGE); // не советую ставить меньше 3.0
                    hdPack.WriteCell(GetClientUserId(attacker)); 
                    hdPack.WriteCell(GetClientUserId(g_iCheckIndexes[attacker]));
                    strcopy(g_sCostumesInventory[attacker][0], sizeof(g_sCostumesInventory), g_sPathModel[attacker]); 
                    SetEntityModel(attacker, g_sPathModel[attacker]);
                }
            }
            else
            {
                FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "Not_Alive");
                FormatEx(bufferHint, sizeof(bufferHint), "%t", "Not_Alive_PCT");
                MyPrint(attacker, bufferChat, bufferHint);
            }
        }
        if(strcmp(info, "no") == 0)
        {
            g_bIsCheckInterval[attacker] = false;
            g_bStopPrintMessage[attacker] = true;

            if(IsPlayerAlive(attacker) && attacker)
            {
                FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "Refuse");
                FormatEx(bufferHint, sizeof(bufferHint), "%t", "Refuse_PCT");
                MyPrint(attacker, bufferChat, bufferHint);
            }
            else
            {
                FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "Not_Alive_Not_Refuse");
                FormatEx(bufferHint, sizeof(bufferHint), "%t", "Not_Alive_Not_Refuse_PCT");
                MyPrint(attacker, bufferChat, bufferHint);
            }
		}
        if(gc_bInventory.BoolValue)
        {
            if(strcmp(info, "take") == 0)
            {
                if(IsPlayerAlive(attacker) && attacker)
                {
                    g_bIsCheckInterval[attacker] = false;
                    g_bStopPrintMessage[attacker] = true;
                    if(gc_bSound.BoolValue)
                    {
                        int sound = GetRandomInt(1,2);
                        sound == 1 ? PrecacheAndEmitSoundToClientAny(attacker, g_sSoundPutsOn1) : PrecacheAndEmitSoundToClientAny(attacker, g_sSoundPutsOn2);
                    }
                    if(AddNewItem(attacker))
                    {
                        CreateDataTimer(3.0, Timer_Ragdoll, hdPack, TIMER_FLAG_NO_MAPCHANGE); // не советую ставить меньше 3.0
                        hdPack.WriteCell(GetClientUserId(attacker)); 
                        hdPack.WriteCell(GetClientUserId(g_iCheckIndexes[attacker]));
                    }
                }
                else
                {
                    FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "Not_Alive_Not_Refuse");
                    FormatEx(bufferHint, sizeof(bufferHint), "%t", "Not_Alive_Not_Refuse_PCT");
                    MyPrint(attacker, bufferChat, bufferHint);
                }
            }
        }
	}
    else if (action == MenuAction_Cancel)
    {
        if(attacker)
        {
            g_bIsCheckInterval[attacker] = false;
            g_bStopPrintMessage[attacker] = false;
        }
    }
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

//////////////////////////////////////////////////////////
//                                                      //
//                      INVENTORY                       //
//                                                      //
//////////////////////////////////////////////////////////

public Action Menu_SkinsInventory(int client, int args)
{
    if(gc_bInventory.BoolValue)
    {
        char bufferChat[PLATFORM_MAX_PATH];
        char bufferHint[PLATFORM_MAX_PATH];

        if(g_sCostumesInventory[client][0][0] == 0)
        {
            FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "Inventory_Is_Empty");
            FormatEx(bufferHint, sizeof(bufferHint), "%t", "Inventory_Is_Empty_PCT");
            MyPrint(client, bufferChat, bufferHint);
        }
        else
        {
            if(gc_bSound.BoolValue)
            {
                int sound = GetRandomInt(1,3);
                switch(sound)
                {
                    case 1:
                        PrecacheAndEmitSoundToClientAny(client, g_sSoundOpenInventary1);
                    case 2:
                        PrecacheAndEmitSoundToClientAny(client, g_sSoundOpenInventary2);
                    case 3:
                        PrecacheAndEmitSoundToClientAny(client, g_sSoundOpenInventary3);
                }
            }

            char buffer[PLATFORM_MAX_PATH];
            char name[128];
            char info[128];
            int number = 1; // номер скина

            Menu menu = new Menu(HandlerMenu_SkinsInventory);
            FormatEx(info, sizeof(info), "%T", "Title_Inventory", client);
            menu.SetTitle(info);

            KeyValues hKeyValues = new KeyValues("Models");

            if(hKeyValues.ImportFromFile(g_kvPath)) // если KV структура найдена и все ОК
            {
                hKeyValues.Rewind();

                if(hKeyValues.GotoFirstSubKey())
                {
                    do
                    {
                        hKeyValues.GetSectionName(name, sizeof(name));
                        hKeyValues.GetString("path", buffer, sizeof(buffer));
                        if(strcmp(g_sCostumesInventory[client][0], buffer) == 0)
                        {
                            FormatEx(name, sizeof(name), "%s [Надет]", name);
                            menu.AddItem(buffer, name);
                        }
                    }
                    while (hKeyValues.GotoNextKey());
                }

                hKeyValues.Rewind();

                if(hKeyValues.GotoFirstSubKey())
                {
                    do
                    {
                        hKeyValues.GetSectionName(name, sizeof(name));
                        hKeyValues.GetString("path", buffer, sizeof(buffer));
                        for(int i = 1;i < MAX_ITEMS;++i) // 0 - является скин на вас
                        {
                            if(strcmp(g_sCostumesInventory[client][i], buffer) == 0 && g_sCostumesInventory[client][i][0] != 0)
                            {
                                menu.AddItem(buffer, name);
                                break;
                            }
                        }
                    }
                    while (hKeyValues.GotoNextKey());
                }
            }

            if(!hKeyValues.ImportFromFile(g_kvPath) || !hKeyValues.GotoFirstSubKey()) // если KV структура не найдена или в ней нет ключей 
            {
                for(int i = 0; i < MAX_ITEMS;++i) // 0 - является скин на вас
                {
                    if(i == 0)
                    {
                        FormatEx(name, sizeof(name), "%t [Надет]", "Costume", number);
                        menu.AddItem(g_sCostumesInventory[client][i], name);
                        number++;
                    }
                    else if(g_sCostumesInventory[client][i][0] != 0)
                        {
                            FormatEx(name, sizeof(name), "%t", "Costume", number);
                            menu.AddItem(g_sCostumesInventory[client][i], name);
                            number++;
                        }
                }
            }

            menu.ExitButton = true;
            menu.Display(client, 0);
        }
    }
}

public int HandlerMenu_SkinsInventory(Menu menu, MenuAction action, int client, int param2)
{	
    if(action == MenuAction_Select)
	{
        char bufferChat[PLATFORM_MAX_PATH];
        char bufferHint[PLATFORM_MAX_PATH];

        menu.GetItem(param2, g_sBuffer[client], sizeof(g_sBuffer));
        if(strcmp(g_sBuffer[client], g_sCostumesInventory[client][0]) == 0)
        {
            FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "Your_Costume");
            FormatEx(bufferHint, sizeof(bufferHint), "%t", "Your_Costume_PCT");
            MyPrint(client, bufferChat, bufferHint);
        }
        else
            Menu_ActionSkinsInventory(client, 0);
    }
    if (action == MenuAction_End)
	{
		delete menu;
	}
}

public Action Menu_ActionSkinsInventory(int client, int args)
{
    char info[128];

    Menu menu = new Menu(HandlerMenu_ActionSkinsInventory);
    FormatEx(info, sizeof(info), "%T", "Title_Inventory", client);
    menu.SetTitle(info);
    FormatEx(info, sizeof(info), "%T", "Put_On", client);
    menu.AddItem("put_on", info);
    FormatEx(info, sizeof(info), "%T", "Delete", client);
    menu.AddItem("delete", info);

    menu.ExitButton = true;
    menu.Display(client, 0);

    return Plugin_Handled;
}

public int HandlerMenu_ActionSkinsInventory(Menu menu, MenuAction action, int client, int param2)
{	
    if(action == MenuAction_Select)
	{
        char bufferChat[PLATFORM_MAX_PATH];
        char bufferHint[PLATFORM_MAX_PATH];
        char buffer[PLATFORM_MAX_PATH];
        char info[32];
        GetClientModel(client, buffer, sizeof(buffer));
        menu.GetItem(param2, info, sizeof(info));

        if(strcmp(info, "put_on") == 0)
        {    
            if(IsPlayerAlive(client) && client)
            {
                if(strcmp(g_sBuffer[client], buffer) != 0)
                {
                    if(g_sBuffer[client][0] != 0)
                    {
                        if(gc_bSound.BoolValue)
                            PrecacheAndEmitSoundToClientAny(client, g_sSoundPutsOnInventory);
                        SetEntityModel(client, g_sBuffer[client]);
                        for(int i = 1; i < MAX_ITEMS; i++)
                        {
                            if(strcmp(g_sCostumesInventory[client][i], g_sBuffer[client]) == 0)
                            {
                                char swapbuffer[PLATFORM_MAX_PATH];
                                strcopy(swapbuffer, sizeof(swapbuffer), g_sCostumesInventory[client][0]);
                                strcopy(g_sCostumesInventory[client][0], sizeof(g_sCostumesInventory), g_sCostumesInventory[client][i]);
                                strcopy(g_sCostumesInventory[client][i], sizeof(g_sCostumesInventory), swapbuffer);

                            }
                        }
                        FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "Put_On_Skin");
                        FormatEx(bufferHint, sizeof(bufferHint), "%t", "Put_On_Skin_PCT");
                        MyPrint(client, bufferChat, bufferHint);
                    }
                }
                else
                {
                    FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "Already");
                    FormatEx(bufferHint, sizeof(bufferHint), "%t", "Already_PCT");
                    MyPrint(client, bufferChat, bufferHint);  
                }
            }
            else
            {
                FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "Not_Alive");
                FormatEx(bufferHint, sizeof(bufferHint), "%t", "Not_Alive_PCT");
                MyPrint(client, bufferChat, bufferHint);
            }
            g_sBuffer[client][0] = 0;   
        }
        else // delete model
        {
            GetClientModel(client, buffer, sizeof(buffer));
            if(strcmp(g_sBuffer[client], buffer) == 0)
            {
                FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "You_Cant_Delete_Costume");
                FormatEx(bufferHint, sizeof(bufferHint), "%t", "You_Cant_Delete_Costume_PCT");
                MyPrint(client, bufferChat, bufferHint);
            }
            else
                if(g_sBuffer[client][0] == 0)
                {
                    FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "No_Existing");
                    FormatEx(bufferHint, sizeof(bufferHint), "%t", "No_Existing_PCT");
                    MyPrint(client, bufferChat, bufferHint);
                }
                else
                {
                    for(int i = 0;i < MAX_ITEMS;++i)
                    {
                        if(strcmp(g_sCostumesInventory[client][i], g_sBuffer[client]) == 0)
                        {
                            g_sCostumesInventory[client][i][0] = 0;
                            g_sBuffer[client][0] = 0;

                            FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "Delete_Skin");
                            FormatEx(bufferHint, sizeof(bufferHint), "%t", "Delete_Skin_PCT");
                            MyPrint(client, bufferChat, bufferHint);

                            if(gc_bSound.BoolValue)
                                PrecacheAndEmitSoundToClientAny(client, g_sDeleteCostume);
                            break;
                        }
                    }
                }
        }
    }
    if (action == MenuAction_End)
	{
		delete menu;
	}
}

////////////////////////////////////////////////////////////
//                                                        //
//                         TIMERS                         //
//                                                        //
////////////////////////////////////////////////////////////

public Action Timer_CheckInterval(Handle hTimer, Handle hDataPack)
{
    DataPack hdPack = view_as<DataPack>(hDataPack);
    hdPack.Reset();

    int attacker = hdPack.ReadCell();
    int victim = hdPack.ReadCell();

    attacker = GetClientOfUserId(attacker);

    if(!attacker)
        return Plugin_Stop; 

    g_iTimerLevelCounter[attacker]++;

    float coordinatesAttacker[3];
    float vecDistance[3];

    if(!g_bIsCheckInterval[attacker])
        return Plugin_Stop;

    if(g_iCheckIndexes[attacker] != victim)
        return Plugin_Stop;


    if(IsPlayerAlive(attacker))
    {
        GetClientAbsOrigin(attacker, coordinatesAttacker);
        MakeVectorFromPoints(coordinatesAttacker, g_fCoordinatesVictim[victim], vecDistance);
                        
        float distance = GetVectorLength(vecDistance, false);
                        
        if(distance > gc_fMaxDistance.FloatValue)
        {
            g_bIsCheckInterval[attacker] = false;
            g_bStopPrintMessage[attacker] = false; // разрешить вывод сообщений
            
            CreateTimer(1.5, Timer_PrintMessage, GetClientUserId(attacker));

            Menu_TakeOffCostume(attacker, victim);
            return Plugin_Stop;
        }
    }
    else
    {
        g_bIsCheckInterval[attacker] = false;
    
        Menu_TakeOffCostume(attacker, victim);
        return Plugin_Stop;
    }

    bool flag = true; 

    switch(g_iTimerLevelCounter[attacker])
    {
        case 200: // 20 секунд
        {
            g_iTimerLevel[attacker] = 1;
            g_bIsCheckInterval[attacker] = true;
            Menu_TakeOffCostume(attacker, victim);
            return Plugin_Stop;
        }
       case 240: // 60 секунд
        {
            g_iTimerLevel[attacker] = 2;
            g_bIsCheckInterval[attacker] = true;
            Menu_TakeOffCostume(attacker, victim);
            return Plugin_Stop;
        }
        case 300: // 210 секунд
        {
            g_iTimerLevel[attacker] = 3;
            g_bIsCheckInterval[attacker] = true;
            Menu_TakeOffCostume(attacker, victim);
            return Plugin_Stop;
        }
    }

    if(g_iTimerLevelCounter[attacker] > 301)
        flag = false;

    if(gc_bLogs.BoolValue)
        if(g_iTimerLevel[attacker] == 3 && flag)
        {
            char ip[16];
            GetClientIP(attacker, ip, sizeof(ip));
            char steamid[32];
            GetClientAuthId(attacker, AuthId_Steam2, steamid, sizeof(steamid), true);
            char name[MAX_NAME_LENGTH];
            GetClientName(attacker, name, sizeof(name));
            LogToFile(g_logsPath, "%t", "Costume_Change_Delay", name, ip, steamid);
            g_iErrors++;
        }

    return Plugin_Continue;
}

public Action Timer_PrintMessage(Handle hTimer, int attacker)
{
    char bufferChat[PLATFORM_MAX_PATH];
    char bufferHint[PLATFORM_MAX_PATH];

    attacker = GetClientOfUserId(attacker);

    if(!g_bStopPrintMessage[attacker])
        if(attacker)
        {
            FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "Moved_Too_Far");
            FormatEx(bufferHint, sizeof(bufferHint), "%t", "Moved_Too_Far_PCT");
            MyPrint(attacker, bufferChat, bufferHint);
        }

    return Plugin_Stop;
}

public Action Timer_CloseMenu(Handle hTimer, Handle hDataPack)
{
    DataPack hdPack = view_as<DataPack>(hDataPack);

    if(hdPack == null)
        return Plugin_Stop;

    hdPack.Reset();
        
    int attacker = hdPack.ReadCell();
    int victim = hdPack.ReadCell();

    attacker = GetClientOfUserId(attacker);

    if(!attacker) // если атакующий вышел
        return Plugin_Stop;

    if(g_iCheckIndexes[attacker] != victim)
        return Plugin_Stop;

    if(g_bIsCheckInterval[attacker])
    {
        g_bStopPrintMessage[attacker] = false;
        CreateTimer(0.4, Timer_TimeIsOver, GetClientUserId(attacker), TIMER_FLAG_NO_MAPCHANGE); // +0.1 или +0.2 или +0.3 учитывая тикрейт сервера  (default value 0.1)
    }

    g_bIsCheckInterval[attacker] = false;

    return Plugin_Stop;
}

public Action Timer_TimeIsOver(Handle hTimer, int attacker)
{
    char bufferChat[PLATFORM_MAX_PATH];
    char bufferHint[PLATFORM_MAX_PATH];

    attacker = GetClientOfUserId(attacker);

    if(!g_bStopPrintMessage[attacker])
        if(attacker)
        {
            FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "Time_Is_Over");
            FormatEx(bufferHint, sizeof(bufferHint), "%t", "Time_Is_Over_PCT");
            MyPrint(attacker, bufferChat, bufferHint);
        } 

    return Plugin_Stop;
}

public Action Timer_SaveModel(Handle hTimer, int UserId)
{
    int client = GetClientOfUserId(UserId);

    if(client && IsPlayerAlive(client))
    { 
        if(gc_bLogs.BoolValue)
        {
            char buffer[PLATFORM_MAX_PATH];
            GetClientModel(client, buffer, sizeof(buffer));
            if(strcmp(g_sPathModelPrevious[client], buffer) != 0)
                LogToFile(g_logsPath, "%t", "Another_Plugin_Changes_Your_Costume");
        }
        GetClientModel(client, g_sPathModelPrevious[client], sizeof(g_sPathModelPrevious)); // сохраняется на протяжение всего раунда
        strcopy(g_sPathModel[client], sizeof(g_sPathModel), g_sPathModelPrevious[client]);

        if(gc_bSaveCostumesEveryRound.BoolValue && !gc_bInventory.BoolValue)
            if(strlen(g_sReservedModel[client]) != 0)
            {
                strcopy(g_sPathModel[client], sizeof(g_sPathModel), g_sReservedModel[client]); // возвращаем сохраненный скин 
                SetEntityModel(client, g_sReservedModel[client]);
            }

        if(gc_bInventory.BoolValue)
            strcopy(g_sCostumesInventory[client][0], sizeof(g_sCostumesInventory), g_sPathModelPrevious[client]);
    }
}

public Action Timer_Ragdoll(Handle hTimer, Handle hDataPack)
{
    DataPack hdPack = view_as<DataPack>(hDataPack);
    hdPack.Reset();

    char buffer[PLATFORM_MAX_PATH];
    char dname[32];
        
    int attacker = hdPack.ReadCell();
    int victim = hdPack.ReadCell();

    Format(dname, sizeof(dname), "dis_%d", victim);

    attacker = GetClientOfUserId(attacker);
    victim = GetClientOfUserId(victim);

    if(attacker > 0 && IsPlayerAlive(attacker))
    {
        int Ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
        if(Ragdoll > 0)
        {
           strcopy(buffer, sizeof(buffer), g_sPathModel[victim]);
            switch(gc_iRemoveBody.IntValue)
            {
                case 1: AcceptEntityInput(Ragdoll, "kill");
                case 2: 
                {
                    int entity = CreateEntityByName("env_entity_dissolver");
                    if (entity > 0)
                    {
                        DispatchKeyValue(Ragdoll, "targetname", dname);
                        DispatchKeyValue(entity, "target", dname);
                        AcceptEntityInput(Ragdoll, "Ignite");
                        AcceptEntityInput(entity, "Dissolve");
                        AcceptEntityInput(entity, "KillHierarchy");
                    }
                }
                case 3:  SetEntityModel(Ragdoll, buffer);
            }
        }
        GetClientModel(attacker, g_sPathModelPrevious[attacker], sizeof(g_sPathModelPrevious)); // сохраняем новый скин
    }

    return Plugin_Stop;
}

//////////////////////////////////////////////////////////////////
//                                                              //
//                         MY FUNCTIONS                         //
//                                                              //
//////////////////////////////////////////////////////////////////

public float CheckDistance(int attacker, int victim)
{
    float vecDistance[3];
    float coordinatesVictim[3];
    float coordinatesAttacker[3];

    GetClientAbsOrigin(attacker, coordinatesAttacker);
    GetClientAbsOrigin(victim, coordinatesVictim);
    MakeVectorFromPoints(coordinatesAttacker, coordinatesVictim, vecDistance);
		
    float distance = GetVectorLength(vecDistance, false);

    return distance;
}

public bool AddNewItem(int client)
{
    char bufferChat[PLATFORM_MAX_PATH];
    char bufferHint[PLATFORM_MAX_PATH];

    for(int i = 0;i < MAX_ITEMS;++i) // проверяем на наличие такого же скина
    {
        if(g_sCostumesInventory[client][i][0] != 0)
        {
            if(strcmp(g_sCostumesInventory[client][i], g_sPathModel[client]) == 0)
            {
                FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "Has_Already_Inventory");
                FormatEx(bufferHint, sizeof(bufferHint), "%t", "Has_Already_Inventory_PCT");
                MyPrint(client, bufferChat, bufferHint); 
                return false;
            }
        }
    }

    for(int i = 0;i < MAX_ITEMS;i++) // добавляем скин в инвентарь игрока
    {
        if(g_sCostumesInventory[client][i][0] == 0)
        {
            g_sCostumesInventory[client][i] = g_sPathModel[client];
            FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "Skin_Successfully_Added");
            FormatEx(bufferHint, sizeof(bufferHint), "%t", "Skin_Successfully_Added_PCT");
            MyPrint(client, bufferChat, bufferHint);  
            return true;
        }

        if((i == MAX_ITEMS - 1))
        {
            FormatEx(bufferChat, sizeof(bufferChat), "%s %t", g_sPrefix, "Inventory_Is_Full");
            FormatEx(bufferHint, sizeof(bufferHint), "%t", "Inventory_Is_Full_PCT");
            MyPrint(client, bufferChat, bufferHint);
            return false; 
        }
    }

    return false;
}

public void MyPrint(int client, char[] chat, char[] hint)
{
    switch(gc_iNotificationMode.IntValue)
    {
        case 1:
            CPrintToChat(client, "%s", chat); 
        case 2:
            PrintCenterText(client, "%s", hint);
        case 3:
        {
            CPrintToChat(client, "%s",chat);
            PrintCenterText(client, "%s", hint);
        }
    }
}