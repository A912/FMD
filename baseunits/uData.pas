{
        File: uData.pas
        License: GPLv2
        This unit is a part of Free Manga Downloader
}

unit uData;

{$mode delphi}
{$DEFINE DOWNLOADER}

// This unit contains all necessary functions for data processing

interface

uses
  Classes, SysUtils, uBaseUnit, uFMDThread, FileUtil, LazFileUtils, sqlite3conn,
  sqlite3backup, sqlite3dyn, sqldb, DB, USimpleLogger, strutils, dateutils,
  RegExpr, httpsend;

type

  TSQLite3Connectionx = class(TSQLite3Connection)
  public
    property Handle read GetHandle;
  end;

  { TDBDataProcess }

  TDBDataProcess = class(TObject)
  private
    FConn: TSQLite3Connectionx;
    FTrans: TSQLTransaction;
    FQuery: TSQLQuery;
    FRegxp: TRegExpr;
    FWebsite: String;
    FTableName: String;
    FRecordCount: Integer;
    FFiltered: Boolean;
    FFilterAllSites: Boolean;
    FFilterApplied: Boolean;
    FAllSitesAttached: Boolean;
    FSitesList: TStringList;
    FAttachedSites: TStringList;
    FSQLSelect: String;
    FFilterSQL: String;
    FLinks: TStringList;
    function GetLinkCount: Integer;
  protected
    procedure CreateTable;
    procedure VacuumTable;
    procedure GetRecordCount;
    procedure AddSQLCond(const sqltext: String; useOR: Boolean = False);
    procedure AddSQLSimpleFilter(const fieldname, Value: String;
      useNOT: Boolean = False; useOR: Boolean = False; useRegexp: Boolean = False);
    function GetConnected: Boolean;
    function InternalOpen(const FilePath: String = ''): Boolean;
    function GetWebsiteName(RecIndex: Integer): String;
    function GetValue(RecIndex, FieldIndex: Integer): String;
    procedure AttachAllSites;
    procedure DetachAllSites;
    function ExecuteDirect(SQL: String): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    function Connect(AWebsite: String): Boolean;
    function Open(AWebsite: String = ''): Boolean;
    function OpenTable(const ATableName: String = '';
      CheckRecordCount: Boolean = False): Boolean;
    function TableExist(const ATableName: String): Boolean;
    function Search(ATitle: String): Boolean;
    function CanFilter(const checkedGenres, uncheckedGenres: TStringList;
      const stTitle, stAuthors, stArtists, stStatus, stSummary: String;
      const {%H-}minusDay: Cardinal;
      const haveAllChecked, searchNewManga: Boolean): Boolean;
    function Filter(const checkedGenres, uncheckedGenres: TStringList;
      const stTitle, stAuthors, stArtists, stStatus, stSummary: String;
      const minusDay: Cardinal; const haveAllChecked, searchNewManga: Boolean;
      useRegExpr: Boolean = False): Boolean;
    function LocateByLink(ALink: String): Boolean;
    function WebsiteLoaded(const AWebsite: String): Boolean;
    function LinkExist(ALink: String): Boolean;

    procedure InitLocateLink;
    procedure DoneLocateLink;
    procedure CreateDatabase(AWebsite: String = '');
    procedure GetFieldNames(List: TStringList);
    procedure Close;
    procedure CloseTable;
    procedure Save;
    procedure Backup(AWebsite: String);
    procedure Refresh(RecheckDataCount: Boolean = False);
    procedure AddData(Title, Link, Authors, Artists, Genres, Status, Summary: String;
      NumChapter, JDN: Integer); overload;
    procedure AddData(Title, Link, Authors, Artists, Genres, Status, Summary: String;
      NumChapter: Integer; JDN: TDateTime); overload;
    procedure UpdateData(Title, Link, Authors, Artists, Genres, Status, Summary: String;
      NumChapter: Integer; AWebsite: String = '');
    procedure Commit;
    procedure RemoveFilter;
    procedure Sort;

    property Website: String read FWebsite write FWebsite;
    property TableName: String read FTableName write FTableName;
    property Connected: Boolean read GetConnected;
    property RecordCount: Integer read FRecordCount;
    property Filtered: Boolean read FFiltered;
    property FilterAllSites: Boolean read FFilterAllSites write FFilterAllSites;
    property SitesList: TStringList read FSitesList write FSitesList;
    property WebsiteName[RecIndex: Integer]: String read GetWebsiteName;
    property Value[RecIndex, ParamNo: Integer]: String read GetValue;
    property LinkCount: Integer read GetLinkCount;
  end;

  { TDataProcess }

  TDataProcess = class(TObject)
  private
    function GetInfo(const index: Cardinal): TStringList;
    function GetParam(const index, paramNo: Integer): String;
  public
    website, Filename: String;
    isFilterAllSites, isFiltered: Boolean;

    site, filterMark: TByteList;
    // used by search
    searchPos, filterPos: TCardinalList;
    Data,

    // parts
    Title, Link, Authors, Artists, Genres, Status, Summary: TStringList;
    JDN: TList;

    constructor Create;
    destructor Destroy; override;
    procedure Clear;

    function FirstParam(const index: Cardinal): String;

    // en: Break data into parts... This may be considered as bad coding, but
    //     it's for faster filter
    procedure BreakDataToParts(const i: Cardinal);

    function LoadFromFile(const website: String): Boolean;
    function LoadFromAllFiles(const websiteList: TStringList): Boolean;
    procedure SaveToFile(const website: String); overload;
    procedure SaveToFile; overload;

    function CanFilter(const checkedGenres, uncheckedGenres: TStringList;
      const stTitle, stAuthors, stArtists, stStatus, stSummary: String;
      const minusDay: Cardinal; const haveAllChecked, searchNewManga: Boolean): Boolean;

    // en: Filter by genres, title, authors, ...
    function Filter(const checkedGenres, uncheckedGenres: TStringList;
      const stTitle, stAuthors, stArtists, stStatus, stSummary: String;
      const minusDay: Cardinal; const haveAllChecked, searchNewManga: Boolean;
      useRegExpr: Boolean = False): Boolean;
    // realtime search
    function Search(AMangaName: String): Boolean;
    // get data position
    function GetPos(const ANodePos: Integer): Integer;

    // en: Remove filter
    procedure RemoveFilter;
    procedure Sort;
    property Info[index: Cardinal]: TStringList read GetInfo;
    property Param[index, paramNo: Integer]: String read GetParam;
  end;

  { TMangaInformation }

  TMangaInformation = class(TObject)
  public
    isGetByUpdater: Boolean;
    mangaInfo: TMangaInfo;
    parse: TStringList;
    isGenerateFolderChapterName: Boolean;
    isRemoveUnicode: Boolean;
    FHTTP: THTTPSendThread;
    ModuleId: Integer;

    procedure OnTag(NoCaseTag, ActualTag: String);
    procedure OnText(Text: String);
    constructor Create(AOwnerThread: TFMDThread = nil; CreateInfo: Boolean = True);
    destructor Destroy; override;
    procedure ClearInfo;
    function GetDirectoryPage(var Page: Integer; const website: String): Byte;
    function GetNameAndLink(const names, links: TStringList;
      const website, URL: String): Byte;
    function GetInfoFromURL(const website, URL: String; const Reconnect: Integer = 0): Byte;
    procedure SyncInfoToData(const DataProcess: TDataProcess;
      const index: Cardinal); overload;
    procedure SyncInfoToData(const DataProcess: TDBDataProcess); overload;
    procedure SyncMinorInfoToData(const DataProcess: TDataProcess;
      const index: Cardinal);

    // Only use this function for getting manga infos for the first time
    procedure AddInfoToDataWithoutBreak(const Name, link: String;
      const DataProcess: TDataProcess);
    // Only use this function for update manga list
    procedure AddInfoToData(const Name, link: String; const DataProcess: TDataProcess);
      overload;
    // to add data to TDBDataProcess
    procedure AddInfoToData(const Title, Link: String;
      const DataProcess: TDBDataProcess); overload;
    //wrapper
    function GetPage(var output: TObject; URL: String;
      const Reconnect: Integer = 0): Boolean; inline;
  end;

var
  options: TStringList;

const
  DBDataProcessParam = 'title,link,authors,artists,genres,status,summary,numchapter,jdn';
  DBDataProcessParams: array [0..8] of ShortString =
    ('title', 'link', 'authors', 'artists', 'genres', 'status',
    'summary', 'numchapter', 'jdn');
  DBDataProccesCreateParam = '('#13#10 +
    '"title" VARCHAR,'#13#10 +
    '"link" VARCHAR NOT NULL PRIMARY KEY,'#13#10 +
    '"authors" VARCHAR,'#13#10 +
    '"artists" VARCHAR,'#13#10 +
    '"genres" VARCHAR,'#13#10 +
    '"status" VARCHAR,'#13#10 +
    '"summary" VARCHAR,'#13#10 +
    '"numchapter" INTEGER,'#13#10 +
    '"jdn" INTEGER'#13#10 +
    ');';

function DBDataFilePath(const AWebsite: String): String;
procedure ConvertDataProccessToDB(AWebsite: String; DeleteOriginal: Boolean = False);
function DataFileExist(const AWebsite: String): Boolean;
procedure CopyDBDataProcess(const AWebsite, NWebsite: String);
function DeleteDBDataProcess(const AWebsite: String): Boolean;
procedure OverwriteDBDataProcess(const AWebsite, NWebsite: String);

implementation

uses
  Dialogs, fpJSON, JSONParser, IniFiles, jsHTMLUtil, FastHTMLParser, HTMLUtil,
  SynaCode, uMisc, frmMain, WebsiteModules;

function NaturalCompareCallback({%H-}user: pointer; len1: longint;
  data1: pointer; len2: longint; data2: pointer): longint; cdecl;
var
  s1, s2: String;
begin
  SetString(s1, data1, len1);
  SetString(s2, data2, len2);
  Result := NaturalCompareStr(s1, s2);
end;

procedure RegexCallback(context: PSqlite3_Context; argc: longint;
  argv: PPSqlite3_Value); cdecl;
var
  regexp, Text: PChar;
  regex: TRegExpr;
begin
  if sqlite3_user_data(context) = nil then
  begin
    sqlite3_result_int64(context, 0);
    Exit;
  end;
  if argc <> 2 then
  begin
    sqlite3_result_int64(context, 0);
    Exit;
  end;
  regexp := sqlite3_value_text(argv[0]);
  Text := sqlite3_value_text(argv[1]);
  if (regexp = nil) or (Text = nil) then
  begin
    sqlite3_result_int64(context, 0);
    Exit;
  end;
  try
    regex := TRegExpr(sqlite3_user_data(context));
    regex.Expression := regexp;
    sqlite3_result_int64(context, int64(regex.Exec(Text)));
  except
    sqlite3_result_int64(context, 0);
  end;
end;

function QuotedLike(const S: String): String;
begin
  Result := QuotedStrd(AnsiQuotedStr(S, '%'));
end;

function DBDataFilePath(const AWebsite: String): String;
begin
  Result := fmdDirectory + DATA_FOLDER + AWebsite + DBDATA_EXT;
end;

procedure ConvertDataProccessToDB(AWebsite: String; DeleteOriginal: Boolean);
var
  filepath: String;
  rawdata: TDataProcess;
  dbdata: TDBDataProcess;
  rcount: Integer;
  i: Integer;
begin
  filepath := fmdDirectory + DATA_FOLDER + AWebsite;
  if FileExistsUTF8(filepath + DATA_EXT) then
  begin
    rawdata := TDataProcess.Create;
    dbdata := TDBDataProcess.Create;
    try
      if FileExistsUTF8(filepath + DBDATA_EXT) then
        DeleteFileUTF8(filepath + DBDATA_EXT);
      rawdata.LoadFromFile(AWebsite);
      dbdata.CreateDatabase(AWebsite);
      if rawdata.Data.Count > 0 then
        with rawdata do
        begin
          rcount := 0;
          for i := 0 to Data.Count - 1 do
          begin
            dbdata.AddData(Title[i], Link[i], Authors[i], Artists[i], Genres[i],
              Status[i], StringBreaks(Summary[i]),
              StrToIntDef(Param[i, DATA_PARAM_NUMCHAPTER], 1),
              {%H-}integer(JDN[i]) - 3);
            Inc(rcount);
            if rcount >= 5000 then
            begin
              rcount := 0;
              dbdata.Commit;
            end;
          end;
          dbdata.Commit;
        end;
      dbdata.Sort;
    finally
      rawdata.Free;
      dbdata.Free;
    end;
    if DeleteOriginal then
      DeleteFileUTF8(filepath + DATA_EXT);
  end;
end;

function DataFileExist(const AWebsite: String): Boolean;
begin
  if AWebsite = '' then
    Exit(False);
  Result := FileExistsUTF8(fmdDirectory + DATA_FOLDER + AWebsite + DATA_EXT) or
    FileExistsUTF8(fmdDirectory + DATA_FOLDER + AWebsite + DBDATA_EXT);
end;

procedure CopyDBDataProcess(const AWebsite, NWebsite: String);
begin
  if NWebsite = '' then
    Exit;
  if DataFileExist(AWebsite) then
  begin
    try
      CopyFile(fmdDirectory + DATA_FOLDER + AWebsite + DBDATA_EXT,
        fmdDirectory + DATA_FOLDER + NWebsite + DBDATA_EXT,
        [cffPreserveTime, cffOverwriteFile], True);
    except
      on E: Exception do
        Writelog_E('CopyDBDataProcess.Error!', E);
    end;
  end;
end;

function DeleteDBDataProcess(const AWebsite: String): Boolean;
var
  tryc: Integer;
begin
  Result := not FileExistsUTF8(fmdDirectory + DATA_FOLDER + AWebsite + DBDATA_EXT);
  if Result = False then
  begin
    tryc := 0;
    while not DeleteFileUTF8(fmdDirectory + DATA_FOLDER + AWebsite + DBDATA_EXT) do
    begin
      if tryc > 3 then
        Break;
      Inc(tryc);
      Sleep(250);
    end;
    Result := not FileExistsUTF8(fmdDirectory + DATA_FOLDER + AWebsite + DBDATA_EXT);
  end;
end;

procedure OverwriteDBDataProcess(const AWebsite, NWebsite: String);
begin
  if FileExistsUTF8(fmdDirectory + DATA_FOLDER + NWebsite + DBDATA_EXT) then
  begin
    if DeleteDBDataProcess(AWebsite) then
      RenameFileUTF8(fmdDirectory + DATA_FOLDER + NWebsite + DBDATA_EXT,
        fmdDirectory + DATA_FOLDER + AWebsite + DBDATA_EXT);
  end;
end;

{ TDBDataProcess }

function TDBDataProcess.GetLinkCount: Integer;
begin
  if Assigned(FLinks) then
    Result := FLinks.Count
  else
    Result := 0;
end;

procedure TDBDataProcess.CreateTable;
begin
  if FConn.Connected then
  begin
    FConn.ExecuteDirect('DROP TABLE IF EXISTS ' + QuotedStrd(FTableName));
    FConn.ExecuteDirect('CREATE TABLE ' + QuotedStrd(FTableName) + #13#10 +
      DBDataProccesCreateParam);
    FTrans.Commit;
  end;
end;

procedure TDBDataProcess.VacuumTable;
var
  queryactive: Boolean;
begin
  if FConn.Connected then
  begin
    queryactive := FQuery.Active;
    FQuery.Close;
    with FConn do
    begin
      ExecuteDirect('END TRANSACTION');
      try
        ExecuteDirect('VACUUM');
      except
        on E: Exception do
          WriteLog_E('TDBDataProcess.VacuumTable.Error!', E, Self);
      end;
      ExecuteDirect('BEGIN TRANSACTION');
    end;
    if FQuery.Active <> queryactive then
      FQuery.Active := queryactive;
  end;
end;

procedure TDBDataProcess.GetRecordCount;
begin
  if FQuery.Active then
  begin
    FQuery.Last;
    FRecordCount := FQuery.RecordCount;
    FQuery.Refresh;
  end
  else
    FRecordCount := 0;
end;

procedure TDBDataProcess.AddSQLCond(const sqltext: String; useOR: Boolean);
begin
  with FQuery.SQL do
  begin
    if Count > 0 then
      if (Strings[Count - 1] <> '(') and
        (UpCase(Trim(Strings[Count - 1])) <> 'WHERE') then
      begin
        if useOR then
          Add('OR')
        else
          Add('AND');
      end;
    Add(sqltext);
  end;
end;

procedure TDBDataProcess.AddSQLSimpleFilter(const fieldname, Value: String;
  useNOT: Boolean; useOR: Boolean; useRegexp: Boolean);
var
  svalue: String;
  scond: String;
begin
  svalue := LowerCase(Trim(Value));
  if (fieldname = '') or (svalue = '') then
    Exit;
  if useNOT then
    scond := ' NOT'
  else
    scond := '';
  if useRegexp then
    AddSQLCond(QuotedStrd(fieldname) + scond + ' REGEXP ' + QuotedStrd(svalue), useOR)
  else
    AddSQLCond(QuotedStrd(fieldname) + scond + ' LIKE ' + QuotedLike(svalue), useOR);
end;

function TDBDataProcess.GetConnected: Boolean;
begin
  Result := FConn.Connected;
end;

function TDBDataProcess.InternalOpen(const FilePath: String): Boolean;
begin
  Result := False;
  if FilePath <> '' then
    FConn.DatabaseName := FilePath;
  if FConn.DatabaseName = '' then
    Exit;
  try
    FConn.CharSet := 'UTF8';
    FConn.Connected := True;
    sqlite3_create_collation(FConn.Handle, PChar('NATCMP'), SQLITE_UTF8, nil,
      NaturalCompareCallback);
    sqlite3_create_function(FConn.Handle, PChar('REGEXP'), 2, SQLITE_UTF8, FRegxp,
      RegexCallback, nil, nil);
    FTrans.Active := True;
  except
    on E: Exception do
    begin
      WriteLog_E('TDBDataProcess.InternalOpen.Error!', E, Self);
      Result := False;
    end;
  end;
  Result := FConn.Connected;
end;

function TDBDataProcess.GetWebsiteName(RecIndex: Integer): String;
begin
  Result := FWebsite;
  if FQuery.Active and (FAttachedSites.Count > 0) then
    try
      FQuery.RecNo := RecIndex + 1;
      Result := FQuery.FieldByName('website').AsString;
    except
      on E: Exception do
        WriteLog_E('TDBDataProcess.GetWebsiteName', E, Self);
    end;
end;

function TDBDataProcess.GetValue(RecIndex, FieldIndex: Integer): String;
begin
  if FieldIndex in [DATA_PARAM_NUMCHAPTER, DATA_PARAM_JDN] then
    Result := '0'
  else
    Result := '';
  if not FQuery.Active then Exit;
  if FieldIndex >= Length(DBDataProcessParams) then Exit;
  if (RecIndex < 0) and (RecIndex > FRecordCount) then Exit;
  try
    FQuery.RecNo := RecIndex + 1;
    Result := FQuery.FieldByName(DBDataProcessParams[FieldIndex]).AsString;
  except
    on E: Exception do
      WriteLog_E('TDBDataProcess.GetParam.Error!', E, Self);
  end;
end;

procedure TDBDataProcess.AttachAllSites;

  procedure RemoveCurrentSite;
  var
    j: Integer;
  begin
    if SitesList.Count > 0 then
      for j := 0 to SitesList.Count - 1 do
        if SitesList[j] = FWebsite then
        begin
          SitesList.Delete(j);
          Break;
        end;
  end;

var
  i: Integer;
begin
  RemoveCurrentSite;
  if (not FConn.Connected) or (SitesList.Count = 0) then Exit;
  if Trim(SitesList.Text) = Trim(FAttachedSites.Text) then Exit;
  DetachAllSites;
  FConn.ExecuteDirect('END TRANSACTION');
  try
    for i := 0 to SitesList.Count - 1 do
      if (FAttachedSites.IndexOf(SitesList[i]) = -1) and
        (FileExistsUTF8(DBDataFilePath(SitesList[i]))) then
      begin
        FConn.ExecuteDirect('ATTACH ' +
          QuotedStrd(DBDataFilePath(SitesList[i])) + ' AS ' + QuotedStrd(SitesList[i]));
        FAttachedSites.Add(SitesList[i]);
      end;
  except
    on E: Exception do
      Writelog_E('TDBDataProcess.AttachAllSites.Error!', E, Self)
  end;
  FConn.ExecuteDirect('BEGIN TRANSACTION');
  FAllSitesAttached := FAttachedSites.Count > 0;
end;

procedure TDBDataProcess.DetachAllSites;
var
  i: Integer;
  queryactive: Boolean;
begin
  if (not FConn.Connected) or (FAttachedSites.Count = 0) then Exit;
  queryactive := FQuery.Active;
  if FQuery.Active then FQuery.Close;
  FTrans.Commit;
  FConn.ExecuteDirect('END TRANSACTION');
  for i := FAttachedSites.Count - 1 downto 0 do begin
    try
      FConn.ExecuteDirect('DETACH ' + QuotedStrd(FAttachedSites[i]));
      FAttachedSites.Delete(i);
    except
      on E: Exception do
        Writelog_E('TDBDataProcess.DetachAllSites.Error!', E, Self);
    end;
  end;
  FConn.ExecuteDirect('BEGIN TRANSACTION');
  FAllSitesAttached := FAttachedSites.Count > 0;
  if FQuery.Active <> queryactive then FQuery.Active := queryactive;
end;

function TDBDataProcess.ExecuteDirect(SQL: String): Boolean;
begin
  Result := False;
  if FConn.Connected then
    try
      FConn.ExecuteDirect(SQL);
      Result := True;
    except
      on E: Exception do
        WriteLog_E('TDBDataProcess.ExecuteDirect.Error!'#13#10 +
          'SQL: ' + SQL, E, Self);
    end;
end;

constructor TDBDataProcess.Create;
begin
  inherited Create;
  FConn := TSQLite3Connectionx.Create(nil);
  FTrans := TSQLTransaction.Create(nil);
  FQuery := TSQLQuery.Create(nil);
  FConn.Transaction := FTrans;
  FQuery.PacketRecords := 25;
  FQuery.DataBase := FTrans.DataBase;
  FQuery.Transaction := FTrans;
  FRegxp := TRegExpr.Create;
  FRegxp.ModifierI := True;
  FSitesList := TStringList.Create;
  FAttachedSites := TStringList.Create;
  FTableName := 'masterlist';
  FSQLSelect := 'SELECT * FROM ' + QuotedStrd(FTableName);
  FRecordCount := 0;
  FFiltered := False;
  FFilterAllSites := False;
  FFilterApplied := False;
  FFilterSQL := '';
  FAllSitesAttached := False;
end;

destructor TDBDataProcess.Destroy;
begin
  try
    if FConn.Connected then
    begin
      FQuery.Close;
      Commit;
      Close;
    end;
  except
    on E: Exception do
      WriteLog_E('TDBDataProcess.Destroy.Error!', E, Self);
  end;
  DoneLocateLink;
  FAttachedSites.Free;
  FSitesList.Free;
  FQuery.Free;
  FTrans.Free;
  FConn.Free;
  FRegxp.Free;
  inherited Destroy;
end;

function TDBDataProcess.Connect(AWebsite: String): Boolean;
var
  filepath: String;
begin
  Result := False;
  if AWebsite <> '' then
    FWebsite := AWebsite;
  if FWebsite = '' then
    Exit;
  filepath := fmdDirectory + DATA_FOLDER + FWebsite + DBDATA_EXT;
  if not FileExistsUTF8(filepath) then
    Exit;
  Result := InternalOpen(filepath);
end;

function TDBDataProcess.Open(AWebsite: String): Boolean;
var
  filepath: String;
begin
  Result := False;
  Self.Close;
  if AWebsite <> '' then
    FWebsite := AWebsite;
  if FWebsite = '' then
    Exit;
  filepath := fmdDirectory + DATA_FOLDER + FWebsite + DBDATA_EXT;
  if not FileExistsUTF8(filepath) then
    ConvertDataProccessToDB(AWebsite, True);
  if not FileExistsUTF8(filepath) then
    Exit;
  try
    if InternalOpen(filepath) then
    begin
      if not TableExist(FTableName) then
        CreateTable;
      OpenTable(FTableName, True);
    end;
    Result := FQuery.Active;
  except
    on E: Exception do
      WriteLog_E('TDBDataProcess.Open.Error!', E, Self);
  end;
end;

function TDBDataProcess.OpenTable(const ATableName: String;
  CheckRecordCount: Boolean): Boolean;
begin
  Result := False;
  if FConn.Connected then
  begin
    try
      if ATableName <> '' then
        FTableName := ATableName;
      if FTableName = '' then
        Exit;
      if TableExist(FTableName) then
      begin
        if FQuery.Active then
          FQuery.Close;
        FSQLSelect := 'SELECT * FROM ' + QuotedStrd(FTableName);
        FQuery.SQL.Text := FSQLSelect;
        FQuery.Open;
        if CheckRecordCount then
          GetRecordCount;
      end;
    except
      on E: Exception do
        WriteLog_E('TDBDataProcess.OpenTable.Error!', E, Self);
    end;
  end;
  Result := FQuery.Active;
end;

function TDBDataProcess.TableExist(const ATableName: String): Boolean;
var
  ts: TStringList;
  i: Integer;
begin
  Result := False;
  if FConn.Connected then
  begin
    ts := TStringList.Create;
    try
      FConn.GetTableNames(ts);
      ts.Sorted := True;
      Result := ts.Find(ATableName, i);
    finally
      ts.Free;
    end;
  end;
end;

procedure TDBDataProcess.Close;
begin
  FRecordCount := 0;
  if FConn.Connected then
    try
      FQuery.Close;
      RemoveFilter;
      FConn.Close;
      FConn.DatabaseName := '';
    except
      on E: Exception do
        WriteLog_E('TDBDataProcess.Close.Error!', E, Self);
    end;
end;

procedure TDBDataProcess.CloseTable;
begin
  if FQuery.Active then
  begin
    FRecordCount := 0;
    RemoveFilter;
    FQuery.Close;
  end;
end;

procedure TDBDataProcess.Save;
begin
  Commit;
end;

procedure TDBDataProcess.Backup(AWebsite: String);
begin
  if AWebsite = '' then
    Exit;
  if FConn.Connected then
  begin
    with TSQLite3Backup.Create do
      try
        Backup(FConn, fmdDirectory + DATA_FOLDER + AWebsite + DBDATA_EXT);
      finally
        Free;
      end;
  end;
end;

procedure TDBDataProcess.Refresh(RecheckDataCount: Boolean);
begin
  if FConn.Connected then
  begin
    if FQuery.Active then
      FQuery.Refresh
    else
    if Trim(FQuery.SQL.Text) <> '' then
      FQuery.Open;
    if RecheckDataCount then
      GetRecordCount;
  end;
end;

procedure TDBDataProcess.AddData(Title, Link, Authors, Artists, Genres,
  Status, Summary: String; NumChapter, JDN: Integer);
var
  s: String;
begin
  if FConn.Connected then
    try
      FConn.ExecuteDirect(
        'INSERT OR IGNORE INTO ' + QuotedStrd(FTableName) +
        #13#10'(' + DBDataProcessParam + ')' +
        #13#10'VALUES' +
        #13#10'('#13#10 +
        QuotedStrd(Title) + ','#13#10 +
        QuotedStrd(Link) + ','#13#10 +
        QuotedStrd(Authors) + ','#13#10 +
        QuotedStrd(Artists) + ','#13#10 +
        QuotedStrd(Genres) + ','#13#10 +
        QuotedStrd(Status) + ','#13#10 +
        QuotedStrd(Summary) + ','#13#10 +
        QuotedStrd(IntToStr(NumChapter)) + ','#13#10 +
        QuotedStrd(IntToStr(JDN)) +
        #13#10');');
    except
      on E: Exception do
        WriteLog_E('TDBDataProcess.AddData.Error!', E, Self);
    end;
end;

procedure TDBDataProcess.AddData(Title, Link, Authors, Artists, Genres,
  Status, Summary: String; NumChapter: Integer; JDN: TDateTime);
begin
  AddData(Title, Link, Authors, Artists, Genres, Status, Summary,
    NumChapter, DateToJDN(JDN));
end;

procedure TDBDataProcess.UpdateData(Title, Link, Authors, Artists,
  Genres, Status, Summary: String; NumChapter: Integer; AWebsite: String);
var
  sql: String;

  procedure AddSQL(const field, Value: String);
  begin
    if sql <> '' then
      sql += ','#13#10;
    sql += QuotedStrd(field) + '=' + QuotedStrd(Value);
  end;

begin
  if Link = '' then
    Exit;
  if FConn.Connected then
  begin
    try
      sql := '';
      AddSQL('title', Title);
      AddSQL('authors', Authors);
      AddSQL('artists', Artists);
      AddSQL('genres', Genres);
      AddSQL('status', Status);
      AddSQL('summary', Summary);
      AddSQL('numchapter', IntToStr(NumChapter));
      if (AWebsite <> '') and (AWebsite <> FWebsite) and FAllSitesAttached then
        sql := 'UPDATE OR IGNORE ' + AWebsite + '.' + QuotedStrd(FTableName) +
          #13#10'SET'#13#10 + sql
      else
        sql := 'UPDATE OR IGNORE ' + QuotedStrd(FTableName) + #13#10'SET'#13#10 + sql;
      sql += #13#10'WHERE "link"=' + QuotedStrd(Link) + ';';
      FConn.ExecuteDirect(sql);
    except
      on E: Exception do
        WriteLog_E('TDBDataProcess.UpdateData.Error!', E, Self);
    end;
  end;
end;

procedure TDBDataProcess.Commit;
var
  queryactive: Boolean;
begin
  if FConn.Connected then
    try
      queryactive := FQuery.Active;
      if FQuery.Active then FQuery.Close;
      FTrans.Commit;
      if FQuery.Active <> queryactive then
        FQuery.Active := queryactive;
    except
      on E: Exception do
        WriteLog_E('TDBDataProcess.Commit.Error!', E, Self);
    end;
end;

function TDBDataProcess.Search(ATitle: String): Boolean;
var
  i: Integer;
begin
  if FQuery.Active then
  begin
    try
      FQuery.Close;
      with FQuery do
      begin
        SQL.Clear;
        if FFilterApplied then
          SQL.AddText(FFilterSQL)
        else
          SQL.Add(FSQLSelect);
        if ATitle <> '' then
        begin
          if not FFilterApplied then
            SQL.Add('WHERE');
          if FAllSitesAttached then
          begin
            if SQL.Count > 0 then
            begin
              i := 0;
              while i < SQL.Count do
              begin
                if (SQL[i] = 'UNION ALL') or (SQL[i] = ')') then
                begin
                  SQL.Insert(i, 'AND');
                  SQL.Insert(i + 1, '"title" LIKE ' + QuotedLike(ATitle));
                  Inc(i, 3);
                end
                else
                  Inc(i);
              end;
            end;
          end
          else
            AddSQLSimpleFilter('title', ATitle);
          FFiltered := True;
        end
        else
          FFiltered := FFilterApplied;
      end;
      FQuery.Open;
      GetRecordCount;
    except
      on E: Exception do
        WriteLog_E('TDBDataProcess.Search.Error!'#13#10 +
          'SQL:'#13#10 + FQuery.SQL.Text, E, Self);
    end;
  end;
  Result := FQuery.Active;
  if not Result then
  begin
    FFiltered := False;
    FRecordCount := 0;
  end;
end;

function TDBDataProcess.CanFilter(const checkedGenres, uncheckedGenres: TStringList;
  const stTitle, stAuthors, stArtists, stStatus, stSummary: String;
  const minusDay: Cardinal; const haveAllChecked, searchNewManga: Boolean): Boolean;
begin
  Result := False;
  if not FQuery.Active then
    Exit;
  if ((stTitle = '') and
    (stAuthors = '') and
    (stArtists = '') and
    (stSummary = '') and
    (stStatus = '2') and
    (checkedGenres.Count = 0) and
    (uncheckedGenres.Count = 0)) and
    (not searchNewManga) and
    haveAllChecked then
    Result := False
  else
    Result := True;
end;

function TDBDataProcess.Filter(const checkedGenres, uncheckedGenres: TStringList;
  const stTitle, stAuthors, stArtists, stStatus, stSummary: String;
  const minusDay: Cardinal; const haveAllChecked, searchNewManga: Boolean;
  useRegExpr: Boolean): Boolean;
var
  tsql: String;
  i: Integer;
  filtersingle: Boolean = True;

  procedure GenerateSQLFilter;
  var
    j: Integer;
  begin
    // filter new manga based on date
    if searchNewManga then
      AddSQLCond('"jdn" > ' +
        QuotedStrd(IntToStr(DateToJDN(IncDay(Now, (0 - minusDay))))));

    // filter title
    AddSQLSimpleFilter('title', stTitle, False, False, useRegExpr);

    // filter authors
    AddSQLSimpleFilter('authors', stAuthors, False, False, useRegExpr);

    // filter artists
    AddSQLSimpleFilter('artists', stArtists, False, False, useRegExpr);

    // filter summary
    AddSQLSimpleFilter('summary', stSummary, False, False, useRegExpr);

    // filter status
    if stStatus <> '2' then
      AddSQLCond('"status"=' + QuotedStrd(stStatus));

    //filter checked genres
    if checkedGenres.Count > 0 then
    begin
      AddSQLCond('(');
      for j := 0 to checkedGenres.Count - 1 do
        AddSQLSimpleFilter('genres', checkedGenres[j], False,
          (not haveAllChecked), useRegExpr);
      FQuery.SQL.Add(')');
    end;

    //filter unchecked genres
    if uncheckedGenres.Count > 0 then
    begin
      AddSQLCond('(');
      for j := 0 to uncheckedGenres.Count - 1 do
        AddSQLSimpleFilter('genres', uncheckedGenres[j], True,
          (not haveAllChecked), useRegExpr);
      FQuery.SQL.Add(')');
    end;
  end;

begin
  Result := False;
  if FQuery.Active = False then
    Exit;
  if not CanFilter(checkedGenres, uncheckedGenres, stTitle, stAuthors,
    stArtists, stStatus, stSummary, minusDay, haveAllChecked, searchNewManga) then
    Exit;
  with FQuery do
  begin
    FQuery.Close;
    FRecordCount := 0;
    tsql := SQL.Text;
    SQL.Clear;
    try
      if FFilterAllSites and (FSitesList.Count > 0) then
      begin
        AttachAllSites;
        if FAttachedSites.Count > 0 then
        begin
          SQL.Add('SELECT * FROM');
          SQL.Add('(');
          SQL.Add('SELECT *, ' + QuotedStrd(FWebsite) + ' AS "website" FROM ' +
            QuotedStrd(FTableName));
          SQL.Add('WHERE');
          GenerateSQLFilter;
          for i := 0 to FAttachedSites.Count - 1 do
          begin
            SQL.Add('UNION ALL');
            SQL.Add('SELECT *, ' + QuotedStrd(FAttachedSites[i]) +
              ' AS "website" FROM ' +
              QuotedStrd(FAttachedSites[i]) + '.' + QuotedStrd(FTableName));
            SQL.Add('WHERE');
            GenerateSQLFilter;
          end;
          SQL.Add(')');
          SQL.Add('ORDER BY "title" COLLATE NATCMP');
          filtersingle := False;
        end;
      end;

      if filtersingle then
      begin
        SQL.Add(FSQLSelect);
        SQL.Add('WHERE');
        GenerateSQLFilter;
      end;

      FQuery.Open;
      FFiltered := Active;
      FFilterApplied := FFiltered;
      if FFilterApplied then
        FFilterSQL := SQL.Text
      else
        FFilterSQL := '';
    except
      on E: Exception do
      begin
        WriteLog_E('TDBDataProcess.Filter.Error!'#13#10 +
          'SQL:'#13#10 + FQuery.SQL.Text, E, Self);
        FQuery.Close;
        SQL.Text := tsql;
        FQuery.Open;
        FFilterAllSites := False;
        FFiltered := False;
        FFilterApplied := False;
        FFilterSQL := '';
      end;
    end;
    GetRecordCount;
    Result := FFiltered;
  end;
end;

function TDBDataProcess.LocateByLink(ALink: String): Boolean;
begin
  Result := False;
  if (FQuery.Active) and (FRecordCount > 0) and (ALink <> '') then
    try
      Result := FQuery.Locate('link', ALink, [loCaseInsensitive]);
    except
      on E: Exception do
        WriteLog_E('TDBDataProcess.LocateByLink.Error!', E, Self);
    end;
end;

procedure TDBDataProcess.CreateDatabase(AWebsite: String);
var
  filepath: String;
begin
  if AWebsite <> '' then
    FWebsite := AWebsite;
  if FWebsite = '' then
    Exit;
  filepath := fmdDirectory + DATA_FOLDER + FWebsite + DBDATA_EXT;
  if FileExistsUTF8(filepath) then
    DeleteFileUTF8(filepath);
  InternalOpen(filepath);
  CreateTable;
end;

procedure TDBDataProcess.GetFieldNames(List: TStringList);
begin
  if (List <> nil) and (FQuery.Active) then
    FQuery.GetFieldNames(List);
end;

procedure TDBDataProcess.RemoveFilter;
begin
  if FFiltered then
  begin
    FFilterAllSites := False;
    FFiltered := False;
    FFilterApplied := False;
    FFilterSQL := '';
    FQuery.SQL.Text := FSQLSelect;
    FRecordCount := 0;
    DetachAllSites;
    if FQuery.Active then
    begin
      OpenTable;
      GetRecordCount;
    end;
  end;
end;

procedure TDBDataProcess.Sort;
var
  queryactive: Boolean;
begin
  if FConn.Connected then
  begin
    queryactive := FQuery.Active;
    FQuery.Close;
    with FConn do
      try
        ExecuteDirect('DROP TABLE IF EXISTS ' + QuotedStrd(FTableName + '_ordered'));
        ExecuteDirect('CREATE TABLE ' + QuotedStrd(FTableName + '_ordered') +
          DBDataProccesCreateParam);
        ExecuteDirect('INSERT INTO '+QuotedStrd(FTableName + '_ordered') +
          ' SELECT * FROM ' + QuotedStrd(FTableName) + ' ORDER BY "title" COLLATE NATCMP');
        ExecuteDirect('DROP TABLE ' + QuotedStrd(FTableName));
        ExecuteDirect('ALTER TABLE ' + QuotedStrd(FTableName + '_ordered') +
          'RENAME TO ' + QuotedStrd(FTableName));
        FTrans.Commit;
        VacuumTable;
      except
        on E: Exception do
          WriteLog_E('TDBDataProcess.Sort.Error!', E, Self);
      end;
    if FQuery.Active <> queryactive then
      FQuery.Active := queryactive;
  end;
end;

function TDBDataProcess.WebsiteLoaded(const AWebsite: String): Boolean;
var
  i: Integer;
begin
  Result := False;
  if FWebsite = AWebsite then
    Exit(True);
  if FAllSitesAttached then
    for i := 0 to FAttachedSites.Count - 1 do
      if FAttachedSites[i] = AWebsite then
      begin
        Result := True;
        Break;
      end;
end;

function TDBDataProcess.LinkExist(ALink: String): Boolean;
var
  i: Integer;
begin
  if Assigned(FLinks) then
    Result := FLinks.Find(ALink, i)
  else
    Result := False;
end;

procedure TDBDataProcess.InitLocateLink;
begin
  if Assigned(FLinks) then
    FLinks.Clear
  else
    FLinks := TStringList.Create;
  FLinks.Sorted := False;
  if FQuery.Active then
  begin
    FQuery.First;
    repeat
      FLinks.Add(FQuery.Fields[1].AsString);
      FQuery.Next;
    until FQuery.EOF;
    if FLinks.Count > 0 then
      FLinks.Sorted := True;
  end;
end;

procedure TDBDataProcess.DoneLocateLink;
begin
  if Assigned(FLinks) then
    FreeAndNil(FLinks);
end;

// ----- TDataProcess -----

constructor TDataProcess.Create;
begin
  inherited Create;
  isFilterAllSites := False;
  isFiltered := False;
  Data := TStringList.Create;

  Title := TStringList.Create;
  Link := TStringList.Create;
  Authors := TStringList.Create;
  Artists := TStringList.Create;
  Genres := TStringList.Create;
  Status := TStringList.Create;
  Summary := TStringList.Create;
  JDN := TList.Create;

  site := TByteList.Create;
  filterMark := TByteList.Create;
  filterPos := TCardinalList.Create;
  searchPos := TCardinalList.Create;
end;

destructor TDataProcess.Destroy;
begin
  searchPos.Free;
  filterMark.Free;
  filterPos.Free;
  site.Free;

  Title.Free;
  Link.Free;
  Authors.Free;
  Artists.Free;
  Genres.Free;
  Status.Free;
  Summary.Free;
  JDN.Free;

  Data.Free;
  inherited Destroy;
end;

procedure TDataProcess.Clear;
begin
  isFilterAllSites := False;
  isFiltered := False;

  Data.Clear;
  Title.Clear;
  Link.Clear;
  Authors.Clear;
  Artists.Clear;
  Genres.Clear;
  Status.Clear;
  Summary.Clear;

  JDN.Clear;
  site.Clear;
  filterMark.Clear;
  filterPos.Clear;
  searchPos.Clear;
end;

function TDataProcess.FirstParam(const index: Cardinal): String;
var
  l: Cardinal;
begin
  Result := '';
  l := Pos(SEPERATOR, Data.Strings[index]);
  if l <> 0 then
    Result := LeftStr(Data.Strings[index], l - 1);
end;

function TDataProcess.GetInfo(const index: Cardinal): TStringList;
begin
  GetParams(Result{%H-}, Data.Strings[index]);
end;

function TDataProcess.GetParam(const index, paramNo: Integer): String;
var
  i, p: Integer;
  s: String;
begin
  Result := '';
  if index < Data.Count then
  begin
    s := Data.Strings[index];
    i := 0;
    p := 0;
    repeat
      p := Pos(SEPERATOR, s);
      if p > 0 then
      begin
        Inc(i);
        Result := LeftStr(s, p - 1);
        s := RightStr(s, Length(s) - p - Length(SEPERATOR) + 1);
      end;
    until (p = 0) or (i > paramNo);
    if i <= paramNo then
      Result := '';
  end;
end;

// en: break data - for fast filter
procedure TDataProcess.BreakDataToParts(const i: Cardinal);
begin
  if i < Data.Count then
  begin
    Title.Strings[i] := GetParam(i, DATA_PARAM_TITLE);
    Link.Strings[i] := GetParam(i, DATA_PARAM_LINK);
    Authors.Strings[i] := GetParam(i, DATA_PARAM_AUTHORS);
    Artists.Strings[i] := GetParam(i, DATA_PARAM_ARTISTS);
    Genres.Strings[i] := GetParam(i, DATA_PARAM_GENRES);
    Status.Strings[i] := GetParam(i, DATA_PARAM_STATUS);
    Summary.Strings[i] := GetParam(i, DATA_PARAM_SUMMARY);
    JDN.Items[i] := Pointer(StrToIntDef(GetParam(i, DATA_PARAM_JDN), 0));
  end;
end;

function TDataProcess.LoadFromFile(const website: String): Boolean;
var
  id, i: Cardinal;
  l: TStringList;
  Filename: String;
begin
  Filename := fmdDirectory + DATA_FOLDER + website;

  Data.Clear;
  searchPos.Clear;
  filterMark.Clear;
  filterPos.Clear;
  site.Clear;

  title.Clear;
  authors.Clear;
  artists.Clear;
  genres.Clear;
  status.Clear;
  summary.Clear;
  jdn.Clear;

  if not FileExistsUTF8(Filename + DATA_EXT) then
    Exit(False);
  l := TStringList.Create;
  try
    Self.Filename := Filename;

    Data.LoadFromFile(Filename + DATA_EXT);
    id := GetMangaSiteID(website);

    if Data.Count > 0 then
    begin
      //QuickSortData(data);
      QuickSortNaturalPart(Data, SEPERATOR, DATA_PARAM_TITLE); //Natural Sorting
      for i := 0 to Data.Count - 1 do
      begin
        filterMark.Add(FILTER_SHOW);
        filterPos.Add(i);
        site.Add(id);

        l.Clear;
        try
          GetParams(l, Data.Strings[i]);
          while l.Count < 10 do
            l.Add('');
          title.Add(l.Strings[DATA_PARAM_TITLE]);
          link.Add(l.Strings[DATA_PARAM_LINK]);
          authors.Add(l.Strings[DATA_PARAM_AUTHORS]);
          artists.Add(l.Strings[DATA_PARAM_ARTISTS]);
          genres.Add(l.Strings[DATA_PARAM_GENRES]);
          status.Add(l.Strings[DATA_PARAM_STATUS]);
          summary.Add(l.Strings[DATA_PARAM_SUMMARY]);
          jdn.Add(Pointer(StrToIntDef(l.Strings[DATA_PARAM_JDN], 0)));
        except
        end;
      end;
    end;
  finally
    l.Free;
  end;
  Result := True;
end;

function TDataProcess.LoadFromAllFiles(const websiteList: TStringList): Boolean;
var
  id, j, i: Cardinal;
  l: TStringList;
  Filename: String;
begin
  if websiteList.Count = 0 then
    Exit(False);
  Data.Clear;
  searchPos.Clear;
  filterMark.Clear;
  filterPos.Clear;
  site.Clear;

  title.Clear;
  authors.Clear;
  artists.Clear;
  genres.Clear;
  status.Clear;
  summary.Clear;
  jdn.Clear;

  l := TStringList.Create;
  try
    for i := 0 to websiteList.Count - 1 do
    begin
      Filename := DATA_FOLDER + websiteList.Strings[i];
      id := GetMangaSiteID(websiteList.Strings[i]);
      if not FileExistsUTF8(Filename + DATA_EXT) then
        continue;
      l.Clear;
      l.LoadFromFile(Filename + DATA_EXT);

      if l.Count <> 0 then
      begin
        for j := 0 to l.Count - 1 do
        begin
          site.Add(id);
        end;
        Data.Text := Data.Text + l.Text;
      end;
    end;

    if Data.Count > 0 then
    begin
      QuickSortDataWithWebID(Data, site);
      for i := 0 to Data.Count - 1 do
      begin
        filterMark.Add(FILTER_SHOW);
        filterPos.Add(i);

        l.Clear;
        try
          GetParams(l, Data.Strings[i]);
          while l.Count < 10 do
            l.Add('');
          title.Add(l.Strings[DATA_PARAM_TITLE]);
          link.Add(l.Strings[DATA_PARAM_LINK]);
          authors.Add(l.Strings[DATA_PARAM_AUTHORS]);
          artists.Add(l.Strings[DATA_PARAM_ARTISTS]);
          genres.Add(l.Strings[DATA_PARAM_GENRES]);
          status.Add(l.Strings[DATA_PARAM_STATUS]);
          summary.Add(l.Strings[DATA_PARAM_SUMMARY]);
          jdn.Add(Pointer(StrToIntDef(l.Strings[DATA_PARAM_JDN], 0)));
        except
        end;
      end;
    end;
  finally
    l.Free;
  end;
  Result := True;
end;

procedure TDataProcess.SaveToFile(const website: String);
begin
  if Data.Count = 0 then
    Exit;
  //QuickSortData(Data);
  ForceDirectoriesUTF8(DATA_FOLDER);
  Data.SaveToFile(DATA_FOLDER + website + DATA_EXT);
end;

procedure TDataProcess.SaveToFile;
begin
  if Data.Count = 0 then
    Exit;
  //QuickSortData(Data);
  ForceDirectoriesUTF8(DATA_FOLDER);
  Data.SaveToFile(Filename + DATA_EXT);
end;

// check if we need to filter or not
function TDataProcess.CanFilter(const checkedGenres, uncheckedGenres: TStringList;
  const stTitle, stAuthors, stArtists, stStatus, stSummary: String;
  const minusDay: Cardinal; const haveAllChecked, searchNewManga: Boolean): Boolean;
begin
  if (filterPos.Count = 0) or
    (Data.Count = 0) or
    ((stTitle = '') and
    (stAuthors = '') and
    (stArtists = '') and
    (stSummary = '') and
    (stStatus = '2') and
    (checkedGenres.Count = 0) and
    (uncheckedGenres.Count = 0)) and
    (not searchNewManga) then
    Result := False
  else
    Result := True;
end;

function TDataProcess.Filter(const checkedGenres, uncheckedGenres: TStringList;
  const stTitle, stAuthors, stArtists, stStatus, stSummary: String;
  const minusDay: Cardinal; const haveAllChecked, searchNewManga: Boolean;
  useRegExpr: Boolean = False): Boolean;
var
  currentJDN, i, j, k, fpos, Count: Integer;
  s: String;
  regx: TRegExpr;
  fshow: Boolean;
  gen: TStringList;
begin
  regx := TRegExpr.Create;
  regx.ModifierI := True;
  try
    Result := False;
    searchPos.Clear;
    if (filterPos.Count = 0) or
      (Data.Count = 0) or
      ((stTitle = '') and
      (stAuthors = '') and
      (stArtists = '') and
      (stSummary = '') and
      (stStatus = '2') and
      (checkedGenres.Count = 0) and
      (uncheckedGenres.Count = 0)) and
      (not searchNewManga) then
      Exit;

    // ugly filter code but quite fast
    if searchNewManga then
    begin
      currentJDN := GetCurrentJDN;
      for i := 0 to filterPos.Count - 1 do
      begin
        fpos := filterPos.Items[i];
        if (currentJDN - {%H-}integer(jdn.Items[fpos]) >= minusDay) and
          (filterMark.Items[fpos] = FILTER_SHOW) then
          filterMark.Items[fpos] := FILTER_HIDE;
      end;
    end;

    // filter title
    if Trim(stTitle) <> '' then
    begin
      s := LowerCase(stTitle);
      if useRegExpr then
        regx.Expression := stTitle;
      for i := 0 to filterPos.Count - 1 do
      begin
        fpos := filterPos.Items[i];
        if useRegExpr then
          fshow := not regx.Exec(Title[fpos])
        else
          fshow := (Pos(s, LowerCase(Title.Strings[fpos])) = 0);
        if fshow and
          (filterMark.Items[fpos] = FILTER_SHOW) then
          filterMark.Items[fpos] := FILTER_HIDE;
      end;
    end;

    // filter authors
    if stAuthors <> '' then
    begin
      s := LowerCase(stAuthors);
      if useRegExpr then
        regx.Expression := stAuthors;
      for i := 0 to filterPos.Count - 1 do
      begin
        fpos := filterPos.Items[i];
        if useRegExpr then
          fshow := not regx.Exec(Authors[fpos])
        else
          fshow := (Pos(s, LowerCase(Authors.Strings[fpos])) = 0);
        if fshow and
          (filterMark.Items[fpos] = FILTER_SHOW) then
          filterMark.Items[fpos] := FILTER_HIDE;
      end;
    end;

    // filter artist
    if stArtists <> '' then
    begin
      s := LowerCase(stArtists);
      if useRegExpr then
        regx.Expression := stArtists;
      for i := 0 to filterPos.Count - 1 do
      begin
        fpos := filterPos.Items[i];
        if useRegExpr then
          fshow := not regx.Exec(Artists[fpos])
        else
          fshow := (Pos(s, LowerCase(Artists.Strings[fpos])) = 0);
        if fshow and
          (filterMark.Items[fpos] = FILTER_SHOW) then
          filterMark.Items[fpos] := FILTER_HIDE;
      end;
    end;

    // filter summary
    if stSummary <> '' then
    begin
      s := LowerCase(stSummary);
      if useRegExpr then
        regx.Expression := stSummary;
      for i := 0 to filterPos.Count - 1 do
      begin
        fpos := filterPos.Items[i];
        if useRegExpr then
          fshow := not regx.Exec(Summary[fpos])
        else
          fshow := (Pos(s, LowerCase(Summary.Strings[fpos])) = 0);
        if fshow and
          (filterMark.Items[fpos] = FILTER_SHOW) then
          filterMark.Items[fpos] := FILTER_HIDE;
      end;
    end;

    // filter status
    if stStatus <> '2' then
      for i := 0 to filterPos.Count - 1 do
      begin
        fpos := filterPos.Items[i];
        if (CompareText(stStatus, Status.Strings[fpos]) <> 0) and
          (filterMark.Items[fpos] = FILTER_SHOW) then
          filterMark.Items[fpos] := FILTER_HIDE;
      end;

    // filter genres
    if checkedGenres.Count > 0 then
    begin
      for i := 0 to checkedGenres.Count - 1 do
        if useRegExpr then
          checkedGenres[i] := Trim(checkedGenres[i])
        else
          checkedGenres.Strings[i] := Trim(LowerCase(checkedGenres.Strings[i]));
      gen := TStringList.Create;
      for i := 0 to filterPos.Count - 1 do
      begin
        fpos := filterPos.Items[i];
        if filterMark.Items[fpos] = FILTER_SHOW then
        begin
          gen.Clear;
          ExtractStrings([','], [], PChar(Trim(LowerCase(Genres[fpos]))), gen);
          TrimStrings(gen);
          if gen.Count > 0 then
          begin
            if haveAllChecked then
            begin
              Count := checkedGenres.Count;
              for j := 0 to checkedGenres.Count - 1 do
              begin
                if useRegExpr then
                  regx.Expression := checkedGenres[j];
                for k := 0 to gen.Count - 1 do
                begin
                  if useRegExpr then
                    fshow := regx.Exec(gen[k])
                  else
                    fshow := SameText(checkedGenres[j], gen[k]);
                  if fshow then
                  begin
                    Dec(Count);
                    Break;
                  end;
                end;
              end;
              if Count > 0 then
                filterMark.Items[fpos] := FILTER_HIDE;
            end
            else
            begin
              filterMark.Items[fpos] := FILTER_HIDE;
              for j := 0 to checkedGenres.Count - 1 do
              begin
                if useRegExpr then
                  regx.Expression := checkedGenres[j];
                for k := 0 to gen.Count - 1 do
                begin
                  if useRegExpr then
                    fshow := regx.Exec(gen[k])
                  else
                    fshow := SameText(checkedGenres[j], gen[k]);
                  if fshow then
                    Break;
                end;
                if fshow then
                begin
                  filterMark.Items[fpos] := FILTER_SHOW;
                  Break;
                end;
              end;
            end;
          end
          else
          begin
            if filterMark.Items[fpos] = FILTER_SHOW then
              filterMark.Items[fpos] := FILTER_HIDE;
          end;
        end;
      end;
      gen.Free;
    end;

    if uncheckedGenres.Count > 0 then
    begin
      for i := 0 to uncheckedGenres.Count - 1 do
        uncheckedGenres.Strings[i] := LowerCase(uncheckedGenres.Strings[i]);

      for i := 0 to filterPos.Count - 1 do
      begin
        fpos := filterPos.Items[i];
        if (filterMark.Items[fpos] = FILTER_SHOW) then
        begin
          s := LowerCase(Genres.Strings[fpos]);
          if haveAllChecked then
          begin
            Count := uncheckedGenres.Count;
            for j := 0 to uncheckedGenres.Count - 1 do
              if Pos((uncheckedGenres.Strings[j] + ','), s) = 0 then
                Dec(Count);
            if Count > 0 then
              filterMark.Items[fpos] := FILTER_HIDE;
          end
          else
          begin
            for j := 0 to uncheckedGenres.Count - 1 do
              if Pos((uncheckedGenres.Strings[j] + ','), s) <> 0 then
              begin
                filterMark.Items[fpos] := FILTER_HIDE;
                Break;
              end;
          end;
        end;
      end;
    end;

    fpos := filterPos.Count;
    filterPos.Clear;
    for i := 0 to Data.Count - 1 do
      if filterMark.Items[i] = FILTER_SHOW then
        filterPos.Add(i);

    if filterPos.Count <> fpos then
    begin
      isFiltered := True;
      Result := True;
    end;
  except
    on E: Exception do
      WriteLog_E('TDataProcess.Filter.Error!', E, Self);
  end;
  regx.Free;
end;

function TDataProcess.Search(AMangaName: String): Boolean;
var
  i: Cardinal;
begin
  searchPos.Clear;
  if filterPos.Count <= 0 then
    Exit;
  AMangaName := Upcase(AMangaName);
  for i := 0 to filterPos.Count - 1 do
  begin
    if Pos(AMangaName, upcase(Title.Strings[filterPos.Items[i]])) > 0 then
    begin
      searchPos.Add(filterPos.Items[i]);
      Result := True;
    end;
  end;
end;

// get data position
function TDataProcess.GetPos(const ANodePos: Integer): Integer;
begin
  if searchPos.Count = 0 then
    Result := filterPos.Items[ANodePos]
  else
    Result := searchPos.Items[ANodePos];
end;

procedure TDataProcess.RemoveFilter;
var
  i: Cardinal;
begin
  searchPos.Clear;
  filterMark.Clear;
  filterPos.Clear;
  if Data.Count > 0 then
  begin
    for i := 0 to Data.Count - 1 do
    begin
      filterMark.Add(FILTER_SHOW);
      filterPos.Add(i);
    end;
  end;
  isFiltered := False;
end;

procedure TDataProcess.Sort;
begin
  //QuickSortData(data);
  uMisc.QuickSortNaturalPart(Data, SEPERATOR, DATA_PARAM_TITLE);
end;

{ TMangaInformation }

constructor TMangaInformation.Create(AOwnerThread: TFMDThread;
  CreateInfo: Boolean);
begin
  inherited Create;
  FHTTP := THTTPSendThread.Create(AOwnerThread);
  FHTTP.Headers.NameValueSeparator := ':';
  parse := TStringList.Create;
  if CreateInfo then
    mangaInfo := TMangaInfo.Create;
  isGetByUpdater := False;
  ModuleId := -1;
end;

destructor TMangaInformation.Destroy;
begin
  if Assigned(mangaInfo) then
    mangaInfo.Free;
  if Assigned(parse) then
    parse.Free;
  FHTTP.Free;
  inherited Destroy;
end;

procedure TMangaInformation.ClearInfo;
begin
  mangaInfo.artists := '';
  mangaInfo.authors := '';
  mangaInfo.genres := '';
  mangaInfo.summary := '';
  mangaInfo.coverLink := '';
  mangaInfo.numChapter := 0;
  mangaInfo.status := '';
  mangaInfo.title := '';
  mangaInfo.url := '';
  mangaInfo.website := '';
  mangaInfo.chapterName.Clear;
  mangaInfo.chapterLinks.Clear;
end;

procedure TMangaInformation.OnTag(NoCaseTag, ActualTag: String);
begin
  parse.Add(ActualTag);
end;

procedure TMangaInformation.OnText(Text: String);
begin
  parse.Add(Text);
end;

function TMangaInformation.GetDirectoryPage(var Page: Integer;
  const website: String): Byte;
var
  s: String;
  p: Integer;
  Source: TStringList;
  Parser: THTMLParser;
  WebsiteID: Cardinal;

  {$I includes/AnimeA/directory_page_number.inc}

  {$I includes/KissManga/directory_page_number.inc}

  {$I includes/Manga24h/directory_page_number.inc}

  {$I includes/VnSharing/directory_page_number.inc}

  {$I includes/Hentai2Read/directory_page_number.inc}

  {$I includes/Fakku/directory_page_number.inc}

  {$I includes/Pururin/directory_page_number.inc}

  {$I includes/MangaPark/directory_page_number.inc}

  //{$I includes/MangaTraders/directory_page_number.inc}

  {$I includes/SenManga/directory_page_number.inc}

  {$I includes/MangaGo/directory_page_number.inc}

  {$I includes/MangaEden/directory_page_number.inc}

  {$I includes/BlogTruyen/directory_page_number.inc}

  {$I includes/RedHawkScans/directory_page_number.inc}

  {$I includes/S2Scans/directory_page_number.inc}

  {$I includes/LectureEnLigne/directory_page_number.inc}

  {$I includes/MangaAe/directory_page_number.inc}

  {$I includes/CentralDeMangas/directory_page_number.inc}

  {$I includes/Manga2u/directory_page_number.inc}

  {$I includes/DM5/directory_page_number.inc}

  {$I includes/NineManga/directory_page_number.inc}

  {$I includes/JapanShin/directory_page_number.inc}

  {$I includes/Mangacow/directory_page_number.inc}

  {$I includes/OneManga/directory_page_number.inc}

  {$I includes/MangaTown/directory_page_number.inc}

  {$I includes/MyReadingMangaInfo/directory_page_number.inc}

  {$I includes/IKomik/directory_page_number.inc}

  {$I includes/NHentai/directory_page_number.inc}

  {$I includes/UnionMangas/directory_page_number.inc}

  {$I includes/MangaMint/directory_page_number.inc}

  {$I includes/HakiHome/directory_page_number.inc}

  {$I includes/MangaFrame/directory_page_number.inc}

  {$I includes/MangaHost/directory_page_number.inc}

  {$I includes/PornComix/directory_page_number.inc}

  {$I includes/MangaSee/directory_page_number.inc}

  {$I includes/AcademyVN/directory_page_number.inc}

  {$I includes/MangaAt/directory_page_number.inc}

  {$I includes/ReadMangaToday/directory_page_number.inc}

  {$I includes/Dynasty-Scans/directory_page_number.inc}

  {$I includes/Madokami/directory_page_number.inc}

begin
  Page := 0;

  //load User-Agent from INIAdvanced
  AdvanceLoadHTTPConfig(FHTTP, website);

  //load pagenumber_config if available
  p := INIAdvanced.ReadInteger('UpdateListDirectoryPageNumber', website, -1);

  if p > 0 then
  begin
    Page := p;
    BROWSER_INVERT := True;
  end
  else
  begin
    BROWSER_INVERT := False;
    if ModuleId < 0 then
      ModuleId := Modules.LocateModule(website);
    if Modules.ModuleAvailable(ModuleId, MMGetDirectoryPageNumber) then
      Result := Modules.GetDirectoryPageNumber(Self, Page, ModuleId)
    else
    begin
      WebsiteID := GetMangaSiteID(website);
      Source := TStringList.Create;
      if website = WebsiteRoots[ANIMEA_ID, 0] then
        Result := GetAnimeADirectoryPageNumber
      else
      if website = WebsiteRoots[KISSMANGA_ID, 0] then
        Result := GetKissMangaDirectoryPageNumber
      else
      if website = WebsiteRoots[MANGA24H_ID, 0] then
        Result := GetManga24hDirectoryPageNumber
      else
      if website = WebsiteRoots[VNSHARING_ID, 0] then
        Result := GetVnSharingDirectoryPageNumber
      else
      if website = WebsiteRoots[HENTAI2READ_ID, 0] then
        Result := GetHentai2ReadDirectoryPageNumber
      else
      if website = WebsiteRoots[FAKKU_ID, 0] then
        Result := GetFakkuDirectoryPageNumber
      else
      if website = WebsiteRoots[MANGAPARK_ID, 0] then
        Result := GetMangaParkDirectoryPageNumber
      else
      //if website = WebsiteRoots[MANGATRADERS_ID, 0] then
      //  Result := GetMangaTradersDirectoryPageNumber
      //else
      if website = WebsiteRoots[MANGAGO_ID, 0] then
        Result := GetMangaGoDirectoryPageNumber
      else
      if website = WebsiteRoots[MANGAEDEN_ID, 0] then
        Result := GetMangaEdenDirectoryPageNumber(WebsiteRoots[MANGAEDEN_ID, 1])
      else
      if website = WebsiteRoots[PERVEDEN_ID, 0] then
        Result := GetMangaEdenDirectoryPageNumber(WebsiteRoots[PERVEDEN_ID, 1])
      else
      if website = WebsiteRoots[BLOGTRUYEN_ID, 0] then
        Result := GetBlogTruyenDirectoryPageNumber
      else
      if website = WebsiteRoots[REDHAWKSCANS_ID, 0] then
        Result := GetRedHawkScansDirectoryPageNumber
      else
      if website = WebsiteRoots[S2SCAN_ID, 0] then
        Result := GetS2ScanDirectoryPageNumber
      else
      if website = WebsiteRoots[SENMANGA_ID, 0] then
        Result := GetSenMangaDirectoryPageNumber
      else
      if website = WebsiteRoots[LECTUREENLIGNE_ID, 0] then
        Result := GetLectureEnLigneDirectoryPageNumber
      else
      if website = WebsiteRoots[MANGAAE_ID, 0] then
        Result := GetMangaAeDirectoryPageNumber
      else
      if website = WebsiteRoots[CENTRALDEMANGAS_ID, 0] then
        Result := GetCentralDeMangasDirectoryPageNumber
      else
      if website = WebsiteRoots[MANGA2U_ID, 0] then
        Result := GetManga2uDirectoryPageNumber
      else
      if website = WebsiteRoots[DM5_ID, 0] then
        Result := GetDM5DirectoryPageNumber
      else
      if website = WebsiteRoots[PURURIN_ID, 0] then
        Result := GetPururinDirectoryPageNumber
      else
      if (website = WebsiteRoots[NINEMANGA_ID, 0]) or
        (website = WebsiteRoots[NINEMANGA_ES_ID, 0]) or
        (website = WebsiteRoots[NINEMANGA_CN_ID, 0]) or
        (website = WebsiteRoots[NINEMANGA_RU_ID, 0]) or
        (website = WebsiteRoots[NINEMANGA_DE_ID, 0]) or
        (website = WebsiteRoots[NINEMANGA_IT_ID, 0]) or
        (website = WebsiteRoots[NINEMANGA_BR_ID, 0]) then
        Result := GetNineMangaDirectoryPageNumber
      else
      if website = WebsiteRoots[JAPANSHIN_ID, 0] then
        Result := GetJapanShinDirectoryPageNumber
      else
      if website = WebsiteRoots[MANGACOW_ID, 0] then
        Result := GetMangaCowDirectoryPageNumber
      else
      if website = WebsiteRoots[ONEMANGA_ID, 0] then
        Result := GetOneMangaDirectoryPageNumber
      else
      if website = WebsiteRoots[MANGATOWN_ID, 0] then
        Result := GetMangaTownDirectoryPageNumber
      else
      if website = WebsiteRoots[MYREADINGMANGAINFO_ID, 0] then
        Result := GetMyReadingMangaInfoDirectoryPageNumber
      else
      if website = WebsiteRoots[IKOMIK_ID, 0] then
        Result := GetIKomikDirectoryPageNumber
      else
      if website = WebsiteRoots[NHENTAI_ID, 0] then
        Result := GetNHentaiDirectoryPageNumber
      else
      if website = GetMangaSiteName(UNIONMANGAS_ID) then
        Result := GetUnionMangasDirectoryPageNumber
      else
      if website = WebsiteRoots[MANGAMINT_ID, 0] then
        Result := GetMangaMintDirectoryPageNumber
      else
      if website = WebsiteRoots[HAKIHOME_ID, 0] then
        Result := GetHakiHomeDirectoryPageNumber
      else
      if website = WebsiteRoots[MANGAFRAME_ID, 0] then
        Result := GetMangaFrameDirectoryPageNumber
      else
      if website = WebsiteRoots[MANGAHOST_ID, 0] then
        Result := GetMangaHostDirectoryPageNumber
      else
      if (website = WebsiteRoots[PORNCOMIX_ID, 0]) or
        (website = WebsiteRoots[XXCOMICS_ID, 0]) or
        (website = WebsiteRoots[XXCOMICSMT_ID, 0]) or
        (website = WebsiteRoots[XXCOMICS3D_ID, 0]) or
        (website = WebsiteRoots[PORNCOMIXRE_ID, 0]) or
        (website = WebsiteRoots[PORNCOMIXIC_ID, 0]) or
        (website = WebsiteRoots[PORNXXXCOMICS_ID, 0]) then
        Result := GetPornComixDirectoryPageNumber(GetMangaSiteID(website))
      else
      if website = WebsiteRoots[MANGASEE_ID, 0] then
        Result := GetMangaSeeDirectoryPageNumber
      else
      if website = WebsiteRoots[ACADEMYVN_ID, 0] then
        Result := GetAcademyVNDirectoryPageNumber
      else
      if website = WebsiteRoots[MANGAAT_ID, 0] then
        Result := GetMangaAtDirectoryPageNumber
      else
      if website = WebsiteRoots[READMANGATODAY_ID, 0] then
        Result := GetReadMangaTodayDirectoryPageNumber
      else
      if website = WebsiteRoots[DYNASTYSCANS_ID, 0] then
        Result := GetDynastyScansDirectoryPageNumber
      else
      if website = WebsiteRoots[MADOKAMI_ID, 0] then
        Result := GetMadokamiDirectoryPageNumber
      else
      begin
        Result := NO_ERROR;
        Page := 1;
        Source.Free;
      end;
    end;

    if page < 1 then
      Page := 1;
  end;
end;

function TMangaInformation.GetNameAndLink(const names, links: TStringList;
  const website, URL: String): Byte;
var
  Source: TStringList;
  Parser: THTMLParser;
  WebsiteID: Cardinal;

  {$I includes/Manga2u/names_and_links.inc}

  {$I includes/AnimeA/names_and_links.inc}

  {$I includes/EsMangaHere/names_and_links.inc}

  {$I includes/AnimExtremist/names_and_links.inc}

  {$I includes/MangaInn/names_and_links.inc}

  {$I includes/KissManga/names_and_links.inc}

  {$I includes/Manga24h/names_and_links.inc}

  {$I includes/VnSharing/names_and_links.inc}

  {$I includes/Hentai2Read/names_and_links.inc}

  {$I includes/Fakku/names_and_links.inc}

  {$I includes/MangaPark/names_and_links.inc}

  {$I includes/MangaTraders/names_and_links.inc}

  {$I includes/TruyenTranhTuan/names_and_links.inc}

  {$I includes/SubManga/names_and_links.inc}

  {$I includes/Komikid/names_and_links.inc}

  {$I includes/Mabuns/names_and_links.inc}

  {$I includes/MangaEsta/names_and_links.inc}

  {$I includes/Pururin/names_and_links.inc}

  {$I includes/HugeManga/names_and_links.inc}

  {$I includes/AnimeStory/names_and_links.inc}

  {$I includes/LectureEnLigne/names_and_links.inc}

  {$I includes/ScanManga/names_and_links.inc}

  {$I includes/MangaAr/names_and_links.inc}

  {$I includes/MangaAe/names_and_links.inc}

  {$I includes/CentralDeMangas/names_and_links.inc}

  {$I includes/Imanhua/names_and_links.inc}

  {$I includes/Turkcraft/names_and_links.inc}

  {$I includes/MangaVadisi/names_and_links.inc}

  {$I includes/MangaFrame/names_and_links.inc}

  {$I includes/Mangacow/names_and_links.inc}

  {$I includes/SenManga/names_and_links.inc}

  {$I includes/Starkana/names_and_links.inc}

  {$I includes/EatManga/names_and_links.inc}

  {$I includes/MangaGo/names_and_links.inc}

  {$I includes/RedHawkScans/names_and_links.inc}

  {$I includes/S2Scans/names_and_links.inc}

  {$I includes/EGScans/names_and_links.inc}

  {$I includes/BlogTruyen/names_and_links.inc}

  {$I includes/MangaEden/names_and_links.inc}

  {$I includes/Kivmanga/names_and_links.inc}

  {$I includes/MeinManga/names_and_links.inc}

  {$I includes/MangasPROJECT/names_and_links.inc}

  {$I includes/MangaREADER_POR/names_and_links.inc}

  {$I includes/MangaStreamTo/names_and_links.inc}

  {$I includes/NineManga/names_and_links.inc}

  {$I includes/JapanShin/names_and_links.inc}

  {$I includes/Japscan/names_and_links.inc}

  {$I includes/CentrumMangi_PL/names_and_links.inc}

  {$I includes/MangaLib_PL/names_and_links.inc}

  {$I includes/OneManga/names_and_links.inc}

  {$I includes/MangaTown/names_and_links.inc}

  {$I includes/MangaOku/names_and_links.inc}

  {$I includes/MyReadingMangaInfo/names_and_links.inc}

  {$I includes/IKomik/names_and_links.inc}

  {$I includes/NHentai/names_and_links.inc}

  {$I includes/UnionMangas/names_and_links.inc}

  {$I includes/MangaMint/names_and_links.inc}

  {$I includes/UnixManga/names_and_links.inc}

  {$I includes/HakiHome/names_and_links.inc}

  {$I includes/ExtremeMangas/names_and_links.inc}

  {$I includes/MangaHost/names_and_links.inc}

  {$I includes/PornComix/names_and_links.inc}

  {$I includes/MangaSee/names_and_links.inc}

  {$I includes/MangaKu/names_and_links.inc}

  {$I includes/AcademyVN/names_and_links.inc}

  {$I includes/MangaAt/names_and_links.inc}

  {$I includes/SenMangaRAW/names_and_links.inc}

  {$I includes/ReadMangaToday/names_and_links.inc}

  {$I includes/LoneManga/names_and_links.inc}

  {$I includes/Dynasty-Scans/names_and_links.inc}

  {$I includes/Madokami/names_and_links.inc}

begin
  //load User-Agent from INIAdvanced
  AdvanceLoadHTTPConfig(FHTTP, website);

  if ModuleId < 0 then
    ModuleId := Modules.LocateModule(website);
  if Modules.ModuleAvailable(ModuleId, MMGetNameAndLink) then
    Result := Modules.GetNameAndLink(Self, names, links, URL, ModuleId)
  else
  begin
    WebsiteID := GetMangaSiteID(website);
    Source := TStringList.Create;
    if website = WebsiteRoots[ANIMEA_ID, 0] then
      Result := AnimeAGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGAINN_ID, 0] then
      Result := MangaInnGetNamesAndLinks
    else
    if website = WebsiteRoots[KISSMANGA_ID, 0] then
      Result := KissMangaGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGA24H_ID, 0] then
      Result := Manga24hGetNamesAndLinks
    else
    if website = WebsiteRoots[VNSHARING_ID, 0] then
      Result := VnSharingGetNamesAndLinks
    else
    if website = WebsiteRoots[HENTAI2READ_ID, 0] then
      Result := Hentai2ReadGetNamesAndLinks
    else
    if website = WebsiteRoots[FAKKU_ID, 0] then
      Result := FakkuGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGAPARK_ID, 0] then
      Result := MangaParkGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGATRADERS_ID, 0] then
      Result := MangaTradersGetNamesAndLinks
    else
    if website = WebsiteRoots[STARKANA_ID, 0] then
      Result := StarkanaGetNamesAndLinks
    else
    if website = WebsiteRoots[EATMANGA_ID, 0] then
      Result := EatMangaGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGAGO_ID, 0] then
      Result := MangaGoGetNamesAndLinks
    else
    if website = WebsiteRoots[REDHAWKSCANS_ID, 0] then
      Result := RedHawkScansGetNamesAndLinks
    else
    if website = WebsiteRoots[S2SCAN_ID, 0] then
      Result := S2ScanGetNamesAndLinks
    else
    if website = WebsiteRoots[EGSCANS_ID, 0] then
      Result := EGScansGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGAEDEN_ID, 0] then
      Result := MangaEdenGetNamesAndLinks(WebsiteRoots[MANGAEDEN_ID, 1])
    else
    if website = WebsiteRoots[PERVEDEN_ID, 0] then
      Result := MangaEdenGetNamesAndLinks(WebsiteRoots[PERVEDEN_ID, 1])
    else
    if website = WebsiteRoots[MEINMANGA_ID, 0] then
      Result := MeinMangaGetNamesAndLinks
    else
    if website = WebsiteRoots[BLOGTRUYEN_ID, 0] then
      Result := BlogTruyenGetNamesAndLinks
    else
    if website = WebsiteRoots[TRUYENTRANHTUAN_ID, 0] then
      Result := TruyenTranhTuanGetNamesAndLinks
    else
    if website = WebsiteRoots[SUBMANGA_ID, 0] then
      Result := SubMangaGetNamesAndLinks
    else
    if website = WebsiteRoots[ESMANGAHERE_ID, 0] then
      Result := EsMangaHereGetNamesAndLinks
    else
    if website = WebsiteRoots[ANIMEEXTREMIST_ID, 0] then
      Result := AnimeExtremistGetNamesAndLinks
    else
    if website = WebsiteRoots[KOMIKID_ID, 0] then
      Result := KomikidGetNamesAndLinks
    else
    if website = WebsiteRoots[MABUNS_ID, 0] then
      Result := MabunsGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGAESTA_ID, 0] then
      Result := MangaEstaGetNamesAndLinks
    else
    if website = WebsiteRoots[PURURIN_ID, 0] then
      Result := PururinGetNamesAndLinks
    else
    if website = WebsiteRoots[HUGEMANGA_ID, 0] then
      Result := HugeMangaGetNamesAndLinks
    else
    if website = WebsiteRoots[ANIMESTORY_ID, 0] then
      Result := AnimeStoryGetNamesAndLinks
    else
    if website = WebsiteRoots[LECTUREENLIGNE_ID, 0] then
      Result := LectureEnLigneGetNamesAndLinks
    else
    if website = WebsiteRoots[SCANMANGA_ID, 0] then
      Result := ScanMangaGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGAAR_ID, 0] then
      Result := MangaArGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGAAE_ID, 0] then
      Result := MangaAeGetNamesAndLinks
    else
    if website = WebsiteRoots[CENTRALDEMANGAS_ID, 0] then
      Result := CentralDeMangasGetNamesAndLinks
    else
    if website = WebsiteRoots[IMANHUA_ID, 0] then
      Result := imanhuaGetNamesAndLinks
    else
    if website = WebsiteRoots[TURKCRAFT_ID, 0] then
      Result := TurkcraftGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGAVADISI_ID, 0] then
      Result := MangaVadisiGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGAFRAME_ID, 0] then
      Result := MangaFrameNamesAndLinks
    else
    if website = WebsiteRoots[MANGACOW_ID, 0] then
      Result := MangaCowGetNamesAndLinks
    else
    if website = WebsiteRoots[SENMANGA_ID, 0] then
      Result := SenMangaGetNamesAndLinks
    else
    if website = WebsiteRoots[KIVMANGA_ID, 0] then
      Result := KivmangaGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGASPROJECT_ID, 0] then
      Result := MangasPROJECTGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGAREADER_POR_ID, 0] then
      Result := MangaREADER_PORGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGA2U_ID, 0] then
      Result := Manga2uGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGASTREAMTO_ID, 0] then
      Result := MangaStreamToGetNamesAndLinks
    else
    if (website = WebsiteRoots[NINEMANGA_ID, 0]) or
      (website = WebsiteRoots[NINEMANGA_ES_ID, 0]) or
      (website = WebsiteRoots[NINEMANGA_CN_ID, 0]) or
      (website = WebsiteRoots[NINEMANGA_RU_ID, 0]) or
      (website = WebsiteRoots[NINEMANGA_DE_ID, 0]) or
      (website = WebsiteRoots[NINEMANGA_IT_ID, 0]) or
      (website = WebsiteRoots[NINEMANGA_BR_ID, 0]) then
      Result := NineMangaGetNamesAndLinks
    else
    if website = WebsiteRoots[JAPANSHIN_ID, 0] then
      Result := JapanShinGetNamesAndLinks
    else
    if website = WebsiteRoots[JAPSCAN_ID, 0] then
      Result := JapscanNamesAndLinks
    else
    if website = WebsiteRoots[CENTRUMMANGI_PL_ID, 0] then
      Result := CentrumMangi_PLGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGALIB_PL_ID, 0] then
      Result := MangaLib_PLGetNamesAndLinks
    else
    if website = WebsiteRoots[ONEMANGA_ID, 0] then
      Result := OneMangaGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGATOWN_ID, 0] then
      Result := MangaTownGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGAOKU_ID, 0] then
      Result := MangaOkuGetNamesAndLinks
    else
    if website = WebsiteRoots[MYREADINGMANGAINFO_ID, 0] then
      Result := MyReadingMangaInfoNamesAndLinks
    else
    if website = WebsiteRoots[IKOMIK_ID, 0] then
      Result := IKomikNamesAndLinks
    else
    if website = WebsiteRoots[NHENTAI_ID, 0] then
      Result := NHentaiNamesAndLinks
    else
    if website = WebsiteRoots[UNIONMANGAS_ID, 0] then
      Result := UnionMangasNamesAndLinks
    else
    if website = WebsiteRoots[MANGAMINT_ID, 0] then
      Result := MangaMintGetNamesAndLinks
    else
    if website = WebsiteRoots[UNIXMANGA_ID, 0] then
      Result := UnixMangaNamesAndLinks
    else
    if website = WebsiteRoots[HAKIHOME_ID, 0] then
      Result := HakiHomeNamesAndLinks
    else
    if website = WebsiteRoots[EXTREMEMANGAS_ID, 0] then
      Result := ExtremeMangasNamesAndLinks
    else
    if website = WebsiteRoots[MANGAHOST_ID, 0] then
      Result := MangaHostGetNamesAndLinks
    else
    if (website = WebsiteRoots[PORNCOMIX_ID, 0]) or
      (website = WebsiteRoots[XXCOMICS_ID, 0]) or
      (website = WebsiteRoots[XXCOMICSMT_ID, 0]) or
      (website = WebsiteRoots[XXCOMICS3D_ID, 0]) or
      (website = WebsiteRoots[PORNCOMIXRE_ID, 0]) or
      (website = WebsiteRoots[PORNCOMIXIC_ID, 0]) or
      (website = WebsiteRoots[PORNXXXCOMICS_ID, 0]) then
      Result := PornComixGetNamesAndLinks(GetMangaSiteID(website))
    else
    if website = WebsiteRoots[MANGASEE_ID, 0] then
      Result := MangaSeeGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGAKU_ID, 0] then
      Result := MangaKuGetNamesAndLinks
    else
    if website = WebsiteRoots[ACADEMYVN_ID, 0] then
      Result := AcademyVNGetNamesAndLinks
    else
    if website = WebsiteRoots[MANGAAT_ID, 0] then
      Result := MangaAtGetNamesAndLinks
    else
    if website = WebsiteRoots[SENMANGARAW_ID, 0] then
      Result := SenMangaRAWGetNamesAndLinks
    else
    if website = WebsiteRoots[READMANGATODAY_ID, 0] then
      Result := ReadMangaTodayGetNamesAndLinks
    else
    if website = WebsiteRoots[LONEMANGA_ID, 0] then
      Result := LoneMangaGetNamesAndLinks
    else
    if website = WebsiteRoots[DYNASTYSCANS_ID, 0] then
      Result := DynastyScansGetNamesAndLinks
    else
    if website = WebsiteRoots[MADOKAMI_ID, 0] then
      Result := MadokamiGetNamesAndLinks
    else
    begin
      Result := INFORMATION_NOT_FOUND;
      Source.Free;
    end;
  end;

  //remove host from url
  if links.Count > 0 then
    RemoveHostFromURLsPair(links, names);
end;

function TMangaInformation.GetInfoFromURL(const website, URL: String;
  const Reconnect: Integer): Byte;
var
  s, s2: String;
  j, k: Integer;
  del: Boolean;
  Source: TStringList;
  Parser: THTMLParser;
  WebsiteID: Cardinal;

  {$I includes/AnimeA/manga_information.inc}

  // due to its weird designs, this will take a lot of work (and time) for it to
  // work property

  {$I includes/SubManga/manga_information.inc}

  {$I includes/EsMangaHere/manga_information.inc}

  {$I includes/AnimExtremist/manga_information.inc}

  {$I includes/MangaInn/manga_information.inc}

  {$I includes/KissManga/manga_information.inc}

  {$I includes/Manga24h/manga_information.inc}

  {$I includes/VnSharing/manga_information.inc}

  {$I includes/Hentai2Read/manga_information.inc}

  {$I includes/Fakku/manga_information.inc}

  {$I includes/MangaPark/manga_information.inc}

  {$I includes/MangaTraders/manga_information.inc}

  {$I includes/MangaEden/manga_information.inc}

  {$I includes/Starkana/manga_information.inc}

  {$I includes/EatManga/manga_information.inc}

  {$I includes/RedHawkScans/manga_information.inc}

  {$I includes/S2Scans/manga_information.inc}

  {$I includes/EGScans/manga_information.inc}

  {$I includes/MangaGo/manga_information.inc}

  {$I includes/TruyenTranhTuan/manga_information.inc}

  {$I includes/Komikid/manga_information.inc}

  {$I includes/Mabuns/manga_information.inc}

  {$I includes/MangaEsta/manga_information.inc}

  {$I includes/Pururin/manga_information.inc}

  {$I includes/HugeManga/manga_information.inc}

  {$I includes/AnimeStory/manga_information.inc}

  {$I includes/LectureEnLigne/manga_information.inc}

  {$I includes/ScanManga/manga_information.inc}

  {$I includes/Turkcraft/manga_information.inc}

  {$I includes/MangaVadisi/manga_information.inc}

  {$I includes/MangaFrame/manga_information.inc}

  {$I includes/MangaAr/manga_information.inc}

  {$I includes/MangaAe/manga_information.inc}

  {$I includes/CentralDeMangas/manga_information.inc}

  {$I includes/Mangacow/manga_information.inc}

  {$I includes/SenManga/manga_information.inc}

  {$I includes/BlogTruyen/manga_information.inc}

  {$I includes/MeinManga/manga_information.inc}

  {$I includes/Manga2u/manga_information.inc}

  {$I includes/KivManga/manga_information.inc}

  {$I includes/MangasPROJECT/manga_information.inc}

  {$I includes/MangaREADER_POR/manga_information.inc}

  {$I includes/MangaStreamTo/manga_information.inc}

  {$I includes/NineManga/manga_information.inc}

  {$I includes/JapanShin/manga_information.inc}

  {$I includes/Japscan/manga_information.inc}

  {$I includes/CentrumMangi_PL/manga_information.inc}

  {$I includes/MangaLib_PL/manga_information.inc}

  {$I includes/OneManga/manga_information.inc}

  {$I includes/MangaTown/manga_information.inc}

  {$I includes/MangaOku/manga_information.inc}

  {$I includes/MyReadingMangaInfo/manga_information.inc}

  {$I includes/IKomik/manga_information.inc}

  {$I includes/NHentai/manga_information.inc}

  {$I includes/UnionMangas/manga_information.inc}

  {$I includes/MangaMint/manga_information.inc}

  {$I includes/UnixManga/manga_information.inc}

  {$I includes/HakiHome/manga_information.inc}

  {$I includes/ExtremeMangas/manga_information.inc}

  {$I includes/MangaHost/manga_information.inc}

  {$I includes/PornComix/manga_information.inc}

  {$I includes/MangaSee/manga_information.inc}

  {$I includes/MangaKu/manga_information.inc}

  {$I includes/AcademyVN/manga_information.inc}

  {$I includes/MangaAt/manga_information.inc}

  {$I includes/SenMangaRAW/manga_information.inc}

  {$I includes/ReadMangaToday/manga_information.inc}

  {$I includes/LoneManga/manga_information.inc}

  {$I includes/Dynasty-Scans/manga_information.inc}

  {$I includes/Madokami/manga_information.inc}

begin
  if Trim(URL) = '' then
    Exit(INFORMATION_NOT_FOUND);

  //load User-Agent from INIAdvanced
  AdvanceLoadHTTPConfig(FHTTP, website);

  mangaInfo.coverLink := '';
  mangaInfo.numChapter := 0;
  mangaInfo.chapterName.Clear;
  mangaInfo.chapterLinks.Clear;

  if ModuleId < 0 then
    ModuleId := Modules.LocateModule(website);
  if Modules.ModuleAvailable(ModuleId, MMGetInfo) then
    Result := Modules.GetInfo(Self, URL, Reconnect, ModuleId)
  else
  begin
    WebsiteID := GetMangaSiteID(website);
    if WebsiteID > High(WebsiteRoots) then
      Exit(INFORMATION_NOT_FOUND);

    Source := TStringList.Create;
    if website = WebsiteRoots[ANIMEA_ID, 0] then
      Result := GetAnimeAInfoFromURL
    else
    if website = WebsiteRoots[MANGAINN_ID, 0] then
      Result := GetMangaInnInfoFromURL
    else
    if website = WebsiteRoots[KISSMANGA_ID, 0] then
      Result := GetKissMangaInfoFromURL
    else
    if website = WebsiteRoots[MANGA24H_ID, 0] then
      Result := GetManga24hInfoFromURL
    else
    if website = WebsiteRoots[VNSHARING_ID, 0] then
      Result := GetVnSharingInfoFromURL
    else
    if website = WebsiteRoots[HENTAI2READ_ID, 0] then
      Result := GetHentai2ReadInfoFromURL
    else
    if website = WebsiteRoots[FAKKU_ID, 0] then
      Result := GetFakkuInfoFromURL
    else
    if website = WebsiteRoots[MANGAPARK_ID, 0] then
      Result := GetMangaParkInfoFromURL
    else
    if website = WebsiteRoots[MANGATRADERS_ID, 0] then
      Result := GetMangaTradersInfoFromURL
    else
    if website = WebsiteRoots[STARKANA_ID, 0] then
      Result := GetStarkanaInfoFromURL
    else
    if website = WebsiteRoots[EATMANGA_ID, 0] then
      Result := GetEatMangaInfoFromURL
    else
    if website = WebsiteRoots[MANGAGO_ID, 0] then
      Result := GetMangaGoInfoFromURL
    else
    if website = WebsiteRoots[REDHAWKSCANS_ID, 0] then
      Result := GetRedHawkScansInfoFromURL
    else
    if website = WebsiteRoots[S2SCAN_ID, 0] then
      Result := GetS2scanInfoFromURL
    else
    if website = WebsiteRoots[EGSCANS_ID, 0] then
      Result := GetEGScansInfoFromURL
    else
    if website = WebsiteRoots[TRUYENTRANHTUAN_ID, 0] then
      Result := GetTruyenTranhTuanInfoFromURL
    else
    if website = WebsiteRoots[MANGAEDEN_ID, 0] then
      Result := GetMangaEdenInfoFromURL(WebsiteRoots[MANGAEDEN_ID, 1])
    else
    if website = WebsiteRoots[PERVEDEN_ID, 0] then
      Result := GetMangaEdenInfoFromURL(WebsiteRoots[PERVEDEN_ID, 1])
    else
    if website = WebsiteRoots[MEINMANGA_ID, 0] then
      Result := GetMeinMangaInfoFromURL
    else
    if website = WebsiteRoots[MANGA2U_ID, 0] then
      Result := GetManga2uInfoFromURL
    else
    if website = WebsiteRoots[SUBMANGA_ID, 0] then
      Result := GetSubMangaInfoFromURL
    else
    if website = WebsiteRoots[ESMANGAHERE_ID, 0] then
      Result := GetEsMangaHereInfoFromURL
    else
    if website = WebsiteRoots[ANIMEEXTREMIST_ID, 0] then
      Result := GetAnimeExtremistInfoFromURL
    else
    if website = WebsiteRoots[KOMIKID_ID, 0] then
      Result := GetKomikidInfoFromURL
    else
    if website = WebsiteRoots[MABUNS_ID, 0] then
      Result := GetMabunsInfoFromURL
    else
    if website = WebsiteRoots[MANGAESTA_ID, 0] then
      Result := GetMangaEstaInfoFromURL
    else
    if website = WebsiteRoots[PURURIN_ID, 0] then
      Result := GetPururinInfoFromURL
    else
    if website = WebsiteRoots[HUGEMANGA_ID, 0] then
      Result := GetHugeMangaInfoFromURL
    else
    if website = WebsiteRoots[ANIMESTORY_ID, 0] then
      Result := GetAnimeStoryInfoFromURL
    else
    if website = WebsiteRoots[LECTUREENLIGNE_ID, 0] then
      Result := GetLectureEnLigneInfoFromURL
    else
    if website = WebsiteRoots[SCANMANGA_ID, 0] then
      Result := GetScanMangaInfoFromURL
    else
    if website = WebsiteRoots[TURKCRAFT_ID, 0] then
      Result := GetTurkcraftInfoFromURL
    else
    if website = WebsiteRoots[MANGAFRAME_ID, 0] then
      Result := GetMangaframeInfoFromURL
    else
    if website = WebsiteRoots[MANGAVADISI_ID, 0] then
      Result := GetMangaVadisiInfoFromURL
    else
    if website = WebsiteRoots[MANGAAR_ID, 0] then
      Result := GetMangaArInfoFromURL
    else
    if website = WebsiteRoots[MANGAAE_ID, 0] then
      Result := GetMangaAeInfoFromURL
    else
    if website = WebsiteRoots[CENTRALDEMANGAS_ID, 0] then
      Result := GetCentralDeMangasInfoFromURL
    else
    if website = WebsiteRoots[MANGACOW_ID, 0] then
      Result := GetMangaCowInfoFromURL
    else
    if website = WebsiteRoots[SENMANGA_ID, 0] then
      Result := GetSenMangaInfoFromURL
    else
    if website = WebsiteRoots[BLOGTRUYEN_ID, 0] then
      Result := GetBlogTruyenInfoFromURL
    else
    if website = WebsiteRoots[KIVMANGA_ID, 0] then
      Result := GetKivmangaInfoFromURL
    else
    if website = WebsiteRoots[MANGASPROJECT_ID, 0] then
      Result := GetMangasPROJECTInfoFromURL
    else
    if website = WebsiteRoots[MANGAREADER_POR_ID, 0] then
      Result := GetMangaREADER_PORInfoFromURL
    else
    if website = WebsiteRoots[MANGASTREAMTO_ID, 0] then
      Result := GetMangaStreamToInfoFromURL
    else
    if (website = WebsiteRoots[NINEMANGA_ID, 0]) or
      (website = WebsiteRoots[NINEMANGA_ES_ID, 0]) or
      (website = WebsiteRoots[NINEMANGA_CN_ID, 0]) or
      (website = WebsiteRoots[NINEMANGA_RU_ID, 0]) or
      (website = WebsiteRoots[NINEMANGA_DE_ID, 0]) or
      (website = WebsiteRoots[NINEMANGA_IT_ID, 0]) or
      (website = WebsiteRoots[NINEMANGA_BR_ID, 0]) then
      Result := GetNineMangaInfoFromURL
    else
    if website = WebsiteRoots[JAPANSHIN_ID, 0] then
      Result := GetJapanShinInfoFromURL
    else
    if website = WebsiteRoots[JAPSCAN_ID, 0] then
      Result := GetJapscanInfoFromURL
    else
    if website = WebsiteRoots[CENTRUMMANGI_PL_ID, 0] then
      Result := GetCentrumMangi_PLInfoFromURL
    else
    if website = WebsiteRoots[MANGALIB_PL_ID, 0] then
      Result := GetMangaLib_PLInfoFromURL
    else
    if website = WebsiteRoots[ONEMANGA_ID, 0] then
      Result := GetOneMangaInfoFromURL
    else
    if website = WebsiteRoots[MANGATOWN_ID, 0] then
      Result := GetMangaTownInfoFromURL
    else
    if website = WebsiteRoots[MANGAOKU_ID, 0] then
      Result := GetMangaOkuInfoFromURL
    else
    if website = WebsiteRoots[MYREADINGMANGAINFO_ID, 0] then
      Result := GetMyReadingMangaInfoInfoFromURL
    else
    if website = WebsiteRoots[IKOMIK_ID, 0] then
      Result := GetIKomikInfoFromURL
    else
    if website = WebsiteRoots[NHENTAI_ID, 0] then
      Result := GetNHentaiInfoFromURL
    else
    if website = WebsiteRoots[UNIONMANGAS_ID, 0] then
      Result := GetUnionMangasInfoFromURL
    else
    if website = WebsiteRoots[MANGAMINT_ID, 0] then
      Result := GetMangaMintInfoFromURL
    else
    if website = WebsiteRoots[UNIXMANGA_ID, 0] then
      Result := GetUnixMangaInfoFromURL
    else
    if website = WebsiteRoots[HAKIHOME_ID, 0] then
      Result := GetHakiHomeInfoFromURL
    else
    if website = WebsiteRoots[EXTREMEMANGAS_ID, 0] then
      Result := GetExtremeMangasInfoFromURL
    else
    if website = GetMangaSiteName(MANGAHOST_ID) then
      Result := GetMangaHostInfoFromURL
    else
    if (website = GetMangaSiteName(PORNCOMIX_ID)) or
      (website = GetMangaSiteName(XXCOMICS_ID)) or
      (website = GetMangaSiteName(XXCOMICSMT_ID)) or
      (website = GetMangaSiteName(XXCOMICS3D_ID)) or
      (website = GetMangaSiteName(PORNCOMIXRE_ID)) or
      (website = GetMangaSiteName(PORNCOMIXIC_ID)) or
      (website = GetMangaSiteName(PORNXXXCOMICS_ID)) then
      Result := GetPornComixInfoFromURL(GetMangaSiteID(website))
    else
    if website = GetMangaSiteName(MANGASEE_ID) then
      Result := GetMangaSeeInfoFromURL
    else
    if website = GetMangaSiteName(MANGAKU_ID) then
      Result := GetMangaKuInfoFromURL
    else
    if website = GetMangaSiteName(ACADEMYVN_ID) then
      Result := GetAcademyVNInfoFromURL
    else
    if website = GetMangaSiteName(MANGAAT_ID) then
      Result := GetMangaAtInfoFromURL
    else
    if website = GetMangaSiteName(SENMANGARAW_ID) then
      Result := GetSenMangaRAWInfoFromURL
    else
    if website = GetMangaSiteName(READMANGATODAY_ID) then
      Result := GetReadMangaTodayInfoFromURL
    else
    if website = GetMangaSiteName(LONEMANGA_ID) then
      Result := GetLoneMangaInfoFromURL
    else
    if website = GetMangaSiteName(DYNASTYSCANS_ID) then
      Result := GetDynastyScansInfoFromURL
    else
    if website = GetMangaSiteName(MADOKAMI_ID) then
      Result := GetMadokamiInfoFromURL
    else
    begin
      Source.Free;
      Result := INFORMATION_NOT_FOUND;
      Exit;
    end;
  end;

  s := mangaInfo.artists;
  if (s <> '') and (s[1] = '<') then
    mangaInfo.artists := '';
  s := mangaInfo.authors;
  if (s <> '') and (s[1] = '<') then
    mangaInfo.authors := '';

  // check everything once more
  mangaInfo.title := Trim(RemoveStringBreaks(CommonStringFilter(mangaInfo.title)));
  mangaInfo.authors := Trim(RemoveStringBreaks(Trim(mangaInfo.authors)));
  mangaInfo.artists := Trim(RemoveStringBreaks(Trim(mangaInfo.artists)));
  mangaInfo.genres := Trim(RemoveStringBreaks(Trim(mangaInfo.genres)));

  mangaInfo.authors := TrimRightChar(Trim(mangaInfo.authors), [',']);
  mangaInfo.artists := TrimRightChar(Trim(mangaInfo.artists), [',']);
  mangaInfo.genres := TrimRightChar(Trim(mangaInfo.genres), [',']);

  mangaInfo.summary := Trim(mangaInfo.summary);

  //// strip
  //mangaInfo.summary := StringBreaks(mangaInfo.summary);
  //mangaInfo.summary := Trim(TrimChar(mangaInfo.summary, [#13, #10]));
  //mangaInfo.summary := BreaksString(mangaInfo.summary);
  //// strip double CR
  //mangaInfo.summary := Trim(StringReplace(mangaInfo.summary, '\n\r\n\r', '\n\r', [rfReplaceAll]));
  //mangaInfo.summary := Trim(StringReplace(mangaInfo.summary, '\r\n\r\n', '\r\n', [rfReplaceAll]));

  // fix info
  if (mangaInfo.authors = '-') or (mangaInfo.authors = ':') then
    mangaInfo.authors := '';
  if (mangaInfo.artists = '-') or (mangaInfo.artists = ':') then
    mangaInfo.artists := '';
  if (mangaInfo.summary = '-') or (mangaInfo.summary = ':') then
    mangaInfo.summary := '';

  // remove duplicate chapter
  if mangaInfo.chapterLinks.Count > 0 then
  begin
    j := 0;
    while j < (mangaInfo.chapterLinks.Count - 1) do
    begin
      del := False;
      if (j + 1) < mangaInfo.chapterLinks.Count then
        for k := j + 1 to mangaInfo.chapterLinks.Count - 1 do
        begin
          if SameText(mangaInfo.chapterLinks[j], mangaInfo.chapterLinks[k]) then
          begin
            mangaInfo.chapterLinks.Delete(j);
            mangaInfo.chapterName.Delete(j);
            del := True;
            Break;
          end;
        end;
      if not del then
        Inc(j);
    end;
  end;

  if mangaInfo.chapterLinks.Count > 0 then
  begin
    // remove host from chapter links
    RemoveHostFromURLsPair(mangaInfo.chapterLinks, mangaInfo.chapterName);
    // fixing chapter name
    for j := 0 to mangaInfo.chapterName.Count - 1 do
    begin
      mangaInfo.chapterName.Strings[j] := Trim(RemoveStringBreaks(
        CommonStringFilter(mangaInfo.chapterName[j])));
    end;

    //remove manga name from chapter
    if OptionRemoveMangaNameFromChapter and (mangaInfo.title <> '') then
    begin
      s := LowerCase(mangaInfo.title);
      j := Length(s);
      for k := 0 to mangaInfo.chapterName.Count - 1 do begin
        s2 := LowerCase(mangaInfo.chapterName[k]);
        if Length(s2) > j then
          if Pos(s, s2) = 1 then begin
            s2 := mangaInfo.chapterName[k];
            Delete(s2, 1, j);
            mangaInfo.chapterName[k] := Trim(s2);
          end;
      end;
    end;
  end;

  mangaInfo.numChapter := mangaInfo.chapterLinks.Count;
end;

procedure TMangaInformation.SyncMinorInfoToData(const DataProcess: TDataProcess;
  const index: Cardinal);
begin
  // sync info to data
  {$IFDEF DOWNLOADER}
  if not dataProcess.isFilterAllSites then
  {$ENDIF}
  begin
    DataProcess.Data.Strings[index] := SetParams(
      [DataProcess.Param[index, DATA_PARAM_TITLE],
      DataProcess.Param[index, DATA_PARAM_LINK],
      DataProcess.Param[index, DATA_PARAM_AUTHORS],
      DataProcess.Param[index, DATA_PARAM_ARTISTS],
      DataProcess.Param[index, DATA_PARAM_GENRES],
      mangaInfo.status,
      DataProcess.Param[index, DATA_PARAM_SUMMARY],
      IntToStr(mangaInfo.numChapter),
      {$IFDEF DOWNLOADER}
      DataProcess.Param[index, DATA_PARAM_JDN],
      {$ELSE}
      '0',
      {$ENDIF}
      '0']);
  end;
  // then break it into parts
  dataProcess.BreakDataToParts(index);
end;

procedure TMangaInformation.SyncInfoToData(const DataProcess: TDataProcess;
  const index: Cardinal);
begin
  // sync info to data
  {$IFDEF DOWNLOADER}
  if not dataProcess.isFilterAllSites then
  {$ENDIF}
  begin
    if Trim(mangaInfo.title) = '' then
      mangaInfo.title := DataProcess.Param[index, DATA_PARAM_TITLE];
    DataProcess.Data.Strings[index] := SetParams(
      //[DataProcess.Param[index, DATA_PARAM_TITLE],
      //sync title as well, some site possible to change title or when mangainfo script not work
      [mangaInfo.title,
      DataProcess.Param[index, DATA_PARAM_LINK],
      mangaInfo.authors,
      mangaInfo.artists,
      mangaInfo.genres,
      mangaInfo.status,
      StringFilter(mangaInfo.summary),
      IntToStr(mangaInfo.numChapter),
      {$IFDEF DOWNLOADER}
      DataProcess.Param[index, DATA_PARAM_JDN],
      {$ELSE}
      '0',
      {$ENDIF}
      '0']);
  end;
  // then break it into parts
  dataProcess.BreakDataToParts(index);
end;

procedure TMangaInformation.SyncInfoToData(const DataProcess: TDBDataProcess);
begin
  if Assigned(DataProcess) then
    with mangaInfo do
      DataProcess.UpdateData(title, link, authors, artists, genres, status, summary,
        numChapter, website);
end;

procedure TMangaInformation.AddInfoToDataWithoutBreak(const Name, link: String;
  const DataProcess: TDataProcess);
var
  S: String;
begin
  if mangaInfo.title <> '' then
    S := mangaInfo.title
  else
    S := Name;

  DataProcess.Data.Add(RemoveStringBreaks(SetParams([
    S,
    link,
    mangaInfo.authors,
    mangaInfo.artists,
    mangaInfo.genres,
    mangaInfo.status,
    StringFilter(mangaInfo.summary),
    IntToStr(mangaInfo.numChapter),
    {$IFDEF DOWNLOADER}
    IntToStr(GetCurrentJDN),
    {$ELSE}
    '0',
    {$ENDIF}
    '0'
    ])));
end;

procedure TMangaInformation.AddInfoToData(const Name, link: String;
  const DataProcess: TDataProcess);
var
  l: TStringList;
begin
  l := TStringList.Create;
  DataProcess.Data.Add(
    RemoveStringBreaks(
    SetParams(
    [Name,
    link,
    mangaInfo.authors,
    mangaInfo.artists,
    mangaInfo.genres,
    mangaInfo.status,
    StringFilter(mangaInfo.summary),
    IntToStr(mangaInfo.numChapter),
    IntToStr(GetCurrentJDN),
    '0'])));
  GetParams(l, DataProcess.Data.Strings[DataProcess.Data.Count - 1]);
  DataProcess.title.Add(l.Strings[DATA_PARAM_TITLE]);
  DataProcess.link.Add(l.Strings[DATA_PARAM_LINK]);
  DataProcess.authors.Add(l.Strings[DATA_PARAM_AUTHORS]);
  DataProcess.artists.Add(l.Strings[DATA_PARAM_ARTISTS]);
  DataProcess.genres.Add(l.Strings[DATA_PARAM_GENRES]);
  DataProcess.status.Add(l.Strings[DATA_PARAM_STATUS]);
  DataProcess.summary.Add(l.Strings[DATA_PARAM_SUMMARY]);
  {$IFDEF DOWNLOADER}
  DataProcess.jdn.Add(Pointer(StrToInt(l.Strings[DATA_PARAM_JDN])));
  {$ELSE}
  DataProcess.jdn.Add(Pointer(StrToInt('0')));
  {$ENDIF}
  l.Free;
end;

procedure TMangaInformation.AddInfoToData(const Title, Link: String;
  const DataProcess: TDBDataProcess);
begin
  if Assigned(DataProcess) then
  begin
    if (mangaInfo.title = '') and (Title <> '') then mangaInfo.title := Title;
    if (mangaInfo.link = '') and (Link <> '') then mangaInfo.link := Link;
    with mangaInfo do
      DataProcess.AddData(title, link, authors, artists, genres, status,
        StringBreaks(summary), numChapter, Now);
  end;
end;

function TMangaInformation.GetPage(var output: TObject; URL: String;
  const Reconnect: Integer): Boolean;
begin
  Result := uBaseUnit.GetPage(FHTTP, output, URL, Reconnect);
end;

end.
