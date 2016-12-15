stock void TB_LogFile(ELOG_LEVEL level = INFO, const char[] format, any ...)
{
	char sPath[PLATFORM_MAX_PATH + 1];
	char sFile[PLATFORM_MAX_PATH + 1];
	char sBuffer[1024];
	
	BuildPath(Path_SM, sPath, sizeof(sPath), "logs/teambans");
	
	if(!DirExists(sPath))
	{
		CreateDirectory(sPath, 755);
	}
	
	char sFilePre[PLATFORM_MAX_PATH + 1];
	Format(sFilePre, sizeof(sFilePre), "log_%s", g_sELogLevel[level]);
	
	char sDate[64];
	FormatTime(sDate, sizeof(sDate), "%y%m%d", GetTime());
	
	Format(sFile, sizeof(sFile), "%s/%s_%s.log", sPath, sFilePre, sDate);

	VFormat(sBuffer, sizeof(sBuffer), format, 3);

	LogToFile(sFile, sBuffer);
}
