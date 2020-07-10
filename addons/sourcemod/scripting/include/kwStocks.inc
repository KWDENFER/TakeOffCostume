// Hi, guys! This is my file with my functions for projects.
// It is available to everyone, so I do not mind if it benefits you.
//
// kwStocks - include file - function libary.
// by: DENFER
//
// https://github.com/KWDENFER
// https://vk.com/denferez
// https://steamcommunity.com/id/denferez

#if defined _kwStocks_
	#endinput
#endif
#define _kwStocks_

stock PrecacheSoundAnyDownload(char[] path) // shanapu
{
	if (strlen(path) == 0)
		return;

	char buffer[256];
	PrecacheSoundAny(path, true);
	Format(buffer, sizeof(buffer), "sound/%s", path);
	AddFileToDownloadsTable(buffer);
}

stock PrecacheAndEmitSoundToClientAny(int client, char[] path) // shanapu
{
	PrecacheSoundAny(path);
	EmitSoundToClientAny(client, path);
}

stock void SetLogFile(char path[PLATFORM_MAX_PATH], char[] file, char[] folder) // http://cplusplus.com/reference/ctime/strftime/ 
{
	char date[12];
	FormatTime(date, sizeof(date), "%d-%m-%Y"); 
	Format(path, PLATFORM_MAX_PATH, "logs/%s/%s %s.log", folder, file, date);

	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, path);
}

stock bool DirExistsEx(const char[] path) // shanapu
{
	if (!DirExists(path))
	{
		CreateDirectory(path, 511);

		if (!DirExists(path))
		{
			LogError("Не удалось создать папку! (%s)", path);
			return false;
		}
	}

	return true;
}
