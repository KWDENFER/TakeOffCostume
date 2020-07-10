#if defined _kwDebug_
	#endinput
#endif
#define _kwDebug_

stock Action Debug(int client, int args)
{
    if(gc_bLogs.BoolValue) 
    { 
        CPrintToChat(client, "%s %t", g_sPrefix, "Request_To_Send");

        char buffer[64];

        if(g_iErrors == 0)
            FormatEx(buffer, sizeof(buffer), "%t", "Plugin_Status_Excellent");
        if(g_iErrors == 1)
            FormatEx(buffer, sizeof(buffer), "%t", "Plugin_Status_Good");
        if(g_iErrors > 1 && g_iErrors <= 5)
            FormatEx(buffer, sizeof(buffer), "%t", "Plugin_Status_Unstable");
        if(g_iErrors > 5 && g_iErrors <= 8)
            FormatEx(buffer, sizeof(buffer), "%t", "Plugin_Status_Bad");
        if(g_iErrors > 10)
            FormatEx(buffer, sizeof(buffer), "%t", "Plugin_Status_Terrible");

        switch(g_iFile)
        {
            case 2:
                FormatEx(buffer, sizeof(buffer), "%t", "File_Not_Found");
            case 1:
                FormatEx(buffer, sizeof(buffer), "%t", "File_With_Errors");
            case 0:
                FormatEx(buffer, sizeof(buffer), "%t", "File_Status_Good");
        }

        g_fStopTime = ((float(GetSysTickCount()) / 1000) - g_fStartTime);
        LogToFile(g_logsPath, "%t", "Server_Logs_Stoping"); // Заголовок, отчет сформирован
        LogToFile(g_logsPath, "%t", "SEPARATOR"); // разделитель
        LogToFile(g_logsPath, "%t", "Plugin_Status", buffer); // статус плагина
        if(g_fStopTime > 600)
        {
            g_fStopTime /= 60;
            LogToFile(g_logsPath, "%t минут", "Work_Time", g_fStopTime); // время работы в мин
        }
        else
            LogToFile(g_logsPath, "%t секунд", "Work_Time", g_fStopTime); // время работы в сек
        LogToFile(g_logsPath, "%t", "Number_Of_Errors", g_iErrors); // количество ошибок
        LogToFile(g_logsPath, "%t", "Number_Of_Costumes", g_iCostumes); // количество скинов
        LogToFile(g_logsPath, "%t", "KeyValues", buffer); // статус KV 
        GetCurrentMap(buffer, sizeof(buffer)); 
        LogToFile(g_logsPath, "%t", "Game_Engine", CheckEngineVersion()); // игра
        LogToFile(g_logsPath, "%t", "Current_Map", buffer); // карта
        LogToFile(g_logsPath, "%t", "Clients_On_Server", GetClientCount(true), GetMaxHumanPlayers()); // количество игроков на сервере и макс.кол.игроков
        LogToFile(g_logsPath, "%t\n", "SEPARATOR"); // разделитель
    }
    else
        CPrintToChat(client, "%s %t", g_sPrefix, "Logging_Disabled");
}

stock void CheckKVStruct()
{
    int errors = 0; // ошибки
    int costumes = 0; // скины
    char buffer[PLATFORM_MAX_PATH];
    char name[64];
    KeyValues hKeyValues = new KeyValues("Models");
    hKeyValues.Rewind();

    if(!hKeyValues.ImportFromFile(g_kvPath))
    {
        if(!FileExists(g_kvPath))
        {
            LogToFile(g_logsPath, "%t", "Missing_Structure");
            g_iFile = 2;
            errors++;
        }
        LogToFile(g_logsPath, "%t", "Missing_Main_Key");
        errors++;
    }

    if(hKeyValues.GotoFirstSubKey())
    {
        do
        {
            costumes++;
            hKeyValues.GetSectionName(name, sizeof(name)); 
            hKeyValues.GetString("path", buffer, sizeof(buffer));
            if(strlen(buffer) == 0)
            {
                LogToFile(g_logsPath, "%t", "Incorrect_Qualifier", name);
                errors++;
            }
            else if(StrContains(buffer, ".mdl", true) == -1)
                {
                    LogToFile(g_logsPath, "%t", "Incorrect_Path", name);
                    errors++;
                }
        }
        while (hKeyValues.GotoNextKey());
    }
    else 
    {
        LogToFile(g_logsPath, "%t", "Missing_First_SubKey");
        errors++;
    }

    if(g_iFile != 2 && errors > 0)
        g_iFile = 1;
    else 
        g_iFile = 0;

    g_iErrors += errors; // передаем все ошибки 
    g_iCostumes = costumes; // чтобы избежать х2 
}

stock char CheckEngineVersion()
{
	char buffer[256];
	switch(GetEngineVersion())
    {
        case Engine_CSGO:
            FormatEx(buffer, sizeof(buffer), "Counter-Strike: Global Offensive");
        case Engine_CSS:
            FormatEx(buffer, sizeof(buffer), "Counter-Strike: Source");
        case Engine_DOTA:
            FormatEx(buffer, sizeof(buffer), "Dota 2");
        case Engine_Portal2:
            FormatEx(buffer, sizeof(buffer), "Portal 2");
		case Engine_Original:
            FormatEx(buffer, sizeof(buffer), "Original Source Engine (used by The Ship)");
		case Engine_SourceSDK2006:
            FormatEx(buffer, sizeof(buffer), "Episode 1 Source Engine (second major SDK)");
		case Engine_SourceSDK2007:
            FormatEx(buffer, sizeof(buffer), "Orange Box Source Engine (third major SDK)");
		case Engine_Left4Dead:
            FormatEx(buffer, sizeof(buffer), "Left 4 Dead");
		case Engine_DarkMessiah:
            FormatEx(buffer, sizeof(buffer), "Dark Messiah Multiplayer (based on original engine)");
		case Engine_Left4Dead2:
            FormatEx(buffer, sizeof(buffer), "Left 4 Dead 2");
		case Engine_AlienSwarm:
            FormatEx(buffer, sizeof(buffer), "Alien Swarm (and Alien Swarm SDK)");
		case Engine_BloodyGoodTime:
            FormatEx(buffer, sizeof(buffer), "Bloody Good Time");
		case Engine_EYE:
            FormatEx(buffer, sizeof(buffer), "E.Y.E Divine Cybermancy");
		case Engine_HL2DM:
            FormatEx(buffer, sizeof(buffer), "Half-Life 2 Deathmatch");
		case Engine_DODS:
            FormatEx(buffer, sizeof(buffer), "Day of Defeat: Source");
		case Engine_TF2:
            FormatEx(buffer, sizeof(buffer), "Team Fortress 2");
		case Engine_NuclearDawn:
            FormatEx(buffer, sizeof(buffer), "Nuclear Dawn");
		case Engine_SDK2013:
            FormatEx(buffer, sizeof(buffer), "Source SDK 2013");
		case Engine_Insurgency:
            FormatEx(buffer, sizeof(buffer), "Insurgency (2013 Retail version)");
		case Engine_Contagion:
            FormatEx(buffer, sizeof(buffer), "Contagion");
		case Engine_BlackMesa:
            FormatEx(buffer, sizeof(buffer), "Black Mesa Multiplayer");	
		case Engine_DOI:
            FormatEx(buffer, sizeof(buffer), "Day of Infamy");
        default:
            FormatEx(buffer, sizeof(buffer), "Could not determine the engine version");
    }

	return buffer;
}