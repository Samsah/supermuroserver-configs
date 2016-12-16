
/* Extension Helper - Socket */

Download_Socket(const String:url[], const String:dest[])
{
	new Handle:hFile = OpenFile(dest, "wb");
	
	if (hFile == INVALID_HANDLE)
	{
		decl String:sError[256];
		FormatEx(sError, sizeof(sError), "Error writing to file: %s", dest);
		DownloadEnded(false, sError);
	}
	
	// Format HTTP GET method.
	decl String:hostname[64], String:location[128], String:filename[64], String:sRequest[MAX_URL_LENGTH+128];
	ParseURL(url, hostname, sizeof(hostname), location, sizeof(location), filename, sizeof(filename));
	FormatEx(sRequest, sizeof(sRequest), "GET %s/%s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\nPragma: no-cache\r\nCache-Control: no-cache\r\n\r\n", location, filename, hostname);
	
	new Handle:hDLPack = CreateDataPack();
	WritePackCell(hDLPack, 0);			// 0 - bParsedHeader
	WritePackCell(hDLPack, _:hFile);	// 8
	WritePackString(hDLPack, sRequest);	// 16
	
	new Handle:socket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketSetArg(socket, hDLPack);
	SocketSetOption(socket, ConcatenateCallbacks, 4096);
	SocketConnect(socket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, hostname, 80);
}

public OnSocketConnected(Handle:socket, any:hDLPack)
{
	decl String:sRequest[MAX_URL_LENGTH+128];
	SetPackPosition(hDLPack, 16);
	ReadPackString(hDLPack, sRequest, sizeof(sRequest));
	
	SocketSend(socket, sRequest);
}

public OnSocketReceive(Handle:socket, String:data[], const size, any:hDLPack)
{
	new idx = 0;
	
	// Check if the HTTP header has already been parsed.
	SetPackPosition(hDLPack, 0);
	new bool:bParsedHeader = bool:ReadPackCell(hDLPack);
	
	if (!bParsedHeader)
	{
		// Parse and skip header data.
		if ((idx = StrContains(data, "\r\n\r\n")) == -1)
			idx = 0;
		else
			idx += 4;
		
		SetPackPosition(hDLPack, 0);
		WritePackCell(hDLPack, 1);	// bParsedHeader
	}
	
	// Write data to file.
	SetPackPosition(hDLPack, 8);
	new Handle:hFile = Handle:ReadPackCell(hDLPack);
	
	while (idx < size)
	{
		WriteFileCell(hFile, data[idx++], 1);
	}
}

public OnSocketDisconnected(Handle:socket, any:hDLPack)
{
	SetPackPosition(hDLPack, 8);
	CloseHandle(Handle:ReadPackCell(hDLPack));	// hFile
	CloseHandle(hDLPack);
	CloseHandle(socket);
	
	DownloadEnded(true);
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:hDLPack)
{
	SetPackPosition(hDLPack, 8);
	CloseHandle(Handle:ReadPackCell(hDLPack));	// hFile
	CloseHandle(hDLPack);
	CloseHandle(socket);

	decl String:sError[256];
	FormatEx(sError, sizeof(sError), "Socket error: %d (Error code %d)", errorType, errorNum);
	DownloadEnded(false, sError);
}
