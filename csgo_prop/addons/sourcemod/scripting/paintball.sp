#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#define PAINTBALL_VERSION      "1.2.0"

//#define PAINTBALL_DEBUG 1

public Plugin:myinfo = 
{
    name = "Paintball",
    author = "otstrel.ru Team",
    description = "Add paintball impacts on the map after shots.",
    version = PAINTBALL_VERSION,
    url = "otstrel.ru"
}

new g_SpriteIndex[128];
new g_SpriteIndexCount = 0;

new g_clientPrefs[MAXPLAYERS+1];

new g_clientsPaintballEnabled[MAXPLAYERS];
new g_clientsPaintballEnabledTotal = 0;

new Handle:g_Cvar_PrefDefault = INVALID_HANDLE;
new Handle:g_Cookie_Pref      = INVALID_HANDLE;

public OnPluginStart()
{
    LoadTranslations("paintball.phrases");

    new Handle:Cvar_Version = CreateConVar("sm_paintball_version", PAINTBALL_VERSION, 
        "Paintball Version.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    // KLUGE: Update version cvar if plugin updated on map change.
    SetConVarString(Cvar_Version, PAINTBALL_VERSION);

    g_Cvar_PrefDefault     = CreateConVar("sm_paintball_prefdefault", "1", 
        "Default setting for new users.");
    g_Cookie_Pref      = RegClientCookie("sm_paintball_pref", 
            "Paintball pref", CookieAccess_Private);

    RegConsoleCmd("paintball", MenuPaintball, "Show paintball settings menu.");

    HookEvent("bullet_impact", Event_BulletImpact);
}
    
public OnMapStart()
{
    #if defined PAINTBALL_DEBUG
        LogError("[PAINTBALL_DEBUG] OnMapStart()");
    #endif
    g_SpriteIndexCount = 0;
    
    // Load config file with colors
    new Handle:KvColors = CreateKeyValues("colors");
    new String:ConfigFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, ConfigFile, sizeof(ConfigFile), "configs/paintball.cfg");
    if ( !FileToKeyValues(KvColors, ConfigFile) )
    {
        CloseHandle(KvColors);
        LogError("[ERROR] paintball can not convert file to keyvalues: %s", ConfigFile);
        return;
    }

    // Find first color section
    KvRewind(KvColors);
    new bool:sectionExists;
    sectionExists = KvGotoFirstSubKey(KvColors);
    if ( !sectionExists )
    {
        CloseHandle(KvColors);
        LogError("[ERROR] paintball can not find first keyvalues subkey in file: %s", ConfigFile);
        return;
    }

    new String:filename[PLATFORM_MAX_PATH];
    // Load all colors
    while ( sectionExists )
    {
        #if defined PAINTBALL_DEBUG
            LogError("[PAINTBALL_DEBUG] OnMapStart :: check if color enabled : %i", KvGetNum(KvColors, "enabled") );
        #endif
        if ( KvGetNum(KvColors, "enabled") )
        {
            KvGetString(KvColors, "primary", filename, sizeof(filename));
            g_SpriteIndex[g_SpriteIndexCount++] = precachePaintballDecal(filename);
            KvGetString(KvColors, "secondary", filename, sizeof(filename));
            precachePaintballDecal(filename);
        }

        sectionExists = KvGotoNextKey(KvColors);
    }
    
    CloseHandle(KvColors);
}

precachePaintballDecal(const String:filename[])
{
    #if defined PAINTBALL_DEBUG
        LogError("[PAINTBALL_DEBUG] precachePaintballDecal(%s)", filename);
    #endif
    new String:tmpPath[PLATFORM_MAX_PATH];
    new result = 0;
    result = PrecacheDecal(filename, true);
    Format(tmpPath,sizeof(tmpPath),"materials/%s",filename);
    AddFileToDownloadsTable(tmpPath);
    #if defined PAINTBALL_DEBUG
        LogError("[PAINTBALL_DEBUG] precachePaintballDecal :: return %i", result);
    #endif
    return result;
}

public Action:Event_BulletImpact(Handle:event, const String:weaponName[], bool:dontBroadcast)
{
    static Float:pos[3];
    pos[0] = GetEventFloat(event,"x");
    pos[1] = GetEventFloat(event,"y");
    pos[2] = GetEventFloat(event,"z");

    if ( g_clientsPaintballEnabledTotal && g_SpriteIndexCount )
    {
        // Setup new decal
        TE_SetupWorldDecal(pos, g_SpriteIndex[GetRandomInt(0, g_SpriteIndexCount - 1)]);
        TE_Send(g_clientsPaintballEnabled, g_clientsPaintballEnabledTotal);
    }
}

TE_SetupWorldDecal(const Float:vecOrigin[3], index)
{    
    TE_Start("World Decal");
    TE_WriteVector("m_vecOrigin",vecOrigin);
    TE_WriteNum("m_nIndex",index);
}

public Action:MenuPaintball(client, args)
{
    new Handle:menu = CreateMenu(MenuHandlerPaintball);
    decl String:buffer[64];

    Format(buffer, sizeof(buffer), "%t", "Paintball settings");
    SetMenuTitle(menu, buffer);

    Format(buffer, sizeof(buffer), "%t %t", "Show paintball impacts", 
        g_clientPrefs[client] ? "Selected" : "NotSelected");
    AddMenuItem(menu, "Show paintball impacts", buffer);

    SetMenuExitButton(menu, true);
    DisplayMenu(menu, client, 20);
    return Plugin_Handled;
}

public MenuHandlerPaintball(Handle:menu, MenuAction:action, client, item)
{
    if(action == MenuAction_Select) 
    {
        if(item == 0)
        {
            g_clientPrefs[client] = g_clientPrefs[client] ? 0 : 1;
            decl String:buffer[5];
            IntToString(g_clientPrefs[client], buffer, 5);
            SetClientCookie(client, g_Cookie_Pref, buffer);
            recalculateClients(0);
            MenuPaintball(client, 0);
        }
    } 
    else if(action == MenuAction_End)
    {
        CloseHandle(menu);
    }
}

public OnClientPutInServer(client)
{
    g_clientPrefs[client] = GetConVarInt(g_Cvar_PrefDefault);

    if(!IsFakeClient(client))
    {   
        if (AreClientCookiesCached(client))
        {
            loadClientCookies(client);
        } 
    }
}

public OnClientCookiesCached(client)
{
    if(IsClientInGame(client) && !IsFakeClient(client))
    {
        loadClientCookies(client);  
    }
}

loadClientCookies(client)
{
    decl String:buffer[5];
    GetClientCookie(client, g_Cookie_Pref, buffer, 5);
    if ( !StrEqual(buffer, "") )
    {
        g_clientPrefs[client] = StringToInt(buffer);
    }
    recalculateClients(0);
}

recalculateClients(disconnectedClient)
{
    g_clientsPaintballEnabledTotal = 0;
    for (new i=1; i<=MaxClients; i++)
    {
        if ( IsClientInGame(i) && g_clientPrefs[i] && ( i != disconnectedClient ) )
        {
            g_clientsPaintballEnabled[g_clientsPaintballEnabledTotal++] = i;
        }
    }
}

public OnClientDisconnect(client)
{
    recalculateClients(client);
}

