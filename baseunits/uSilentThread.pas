{
        File: uSilentThread.pas
        License: GPLv2
        This unit is a part of Free Manga Downloader
        ---------------------------------------------
        As the name "silent" suggests, the job of theses classes is to get
        manga information from the site and add them to download list or
        favorites silently.
}

unit uSilentThread;

{$mode delphi}

interface

uses
  Classes, SysUtils, uBaseUnit, uData, uFMDThread, uDownloadsManager,
  WebsiteModules;

type

  TMetaDataType = (MD_DownloadAll, MD_AddToFavorites);

  TSilentThreadMetaData = class
  private
    ModuleId: Integer;
  public
    MetaDataType: TMetaDataType;
    Website, Title, URL, SaveTo: String;
    constructor Create(const AType: TMetaDataType;
      const AWebsite, AManga, AURL, APath: String);
  end;

  TSilentThreadManager = class;

  { TSilentThread }

  TSilentThread = class(TFMDThread)
  protected
    FSavePath: String;
    Info: TMangaInformation;
    Freconnect: Cardinal;
    // manga information from main thread
    title, website, URL: String;
    ModuleId: Integer;
    procedure MainThreadAfterChecking; virtual;
    procedure DoTerminate; override;
    procedure Execute; override;
  public
    Manager: TSilentThreadManager;
    constructor Create;
    destructor Destroy; override;
    property SavePath: String read FSavePath write FSavePath;
  end;

  { TSilentAddToFavThread }

  TSilentAddToFavThread = class(TSilentThread)
  protected
    procedure MainThreadAfterChecking; override;
  end;

  { TSilentThreadManagerThread }

  TSilentThreadManagerThread = class(TFMDThread)
  protected
    procedure Checkout;
    procedure Execute; override;
  public
    Manager: TSilentThreadManager;
    destructor Destroy; override;
  end;

  { TSilentThreadManager }

  TSilentThreadManager = class
  private
    FLockAdd: Boolean;
    FManagerThread: TSilentThreadManagerThread;
    function GetItemCount: Integer;
    procedure StartManagerThread;
    procedure Checkout(Index: Integer);
  public
    MetaData: TFPList;
    Threads: TFPList;
    procedure Add(AType: TMetaDataType; AWebsite, AManga, AURL: String;
      ASavePath: String = '');
    procedure StopAll(WaitFor: Boolean = True);
    procedure UpdateLoadStatus;
    procedure BeginAdd;
    procedure EndAdd;
    property ItemCount: Integer read GetItemCount;
    constructor Create;
    destructor Destroy; override;
  end;

resourcestring
  RS_SilentThreadLoadStatus = 'Loading: %d/%d';

implementation

uses
  frmMain;

{ TSilentThreadManagerThread }

procedure TSilentThreadManagerThread.Checkout;
var
  i: Integer;
begin
  if Terminated then Exit;
  if Manager.MetaData.Count = 0 then Exit;
  with Manager do
  begin
    i := 0;
    while i < MetaData.Count do
    begin
      if Terminated then Break;
      with TSilentThreadMetaData(MetaData[i]) do
        if (Threads.Count < OptionMaxThreads) and
          Modules.CanCreateConnection(ModuleId) then
        begin
          LockCreateConnection;
          try
            if Modules.CanCreateConnection(ModuleId) then
              Manager.Checkout(i);
          finally
            UnlockCreateConnection;
          end;
        end
        else
          Inc(i);
    end;
  end;
end;

procedure TSilentThreadManagerThread.Execute;
begin
  if Manager = nil then Exit;
  Self.Checkout;
  with manager do
    while (not Terminated) and (MetaData.Count > 0) do
    begin
      Sleep(SOCKHEARTBEATRATE);
      while (not Terminated) and (Threads.Count >= OptionMaxThreads) do
        Sleep(SOCKHEARTBEATRATE);
      Self.Checkout;
    end;
end;

destructor TSilentThreadManagerThread.Destroy;
begin
  Manager.FManagerThread := nil;
  inherited Destroy;
end;

{ TSilentThreadManager }

function TSilentThreadManager.GetItemCount: Integer;
begin
  Result := MetaData.Count + Threads.Count;
end;

procedure TSilentThreadManager.StartManagerThread;
begin
  if FManagerThread = nil then
  begin
    FManagerThread := TSilentThreadManagerThread.Create;
    FManagerThread.Manager := Self;
    FManagerThread.Start;
  end;
end;

procedure TSilentThreadManager.Add(AType: TMetaDataType;
  AWebsite, AManga, AURL: String; ASavePath: String = '');
begin
  if not ((AType = MD_AddToFavorites) and
    (MainForm.FavoriteManager.IsMangaExist(AManga, AWebsite))) then
  begin
    MetaData.Add(TSilentThreadMetaData.Create(
      AType, AWebsite, AManga, AURL, ASavePath));
    if not FLockAdd then
    begin
      StartManagerThread;
      UpdateLoadStatus;
    end;
  end;
end;

procedure TSilentThreadManager.Checkout(Index: Integer);
begin
  if (Index < 0) or (Index >= MetaData.Count) then Exit;
  INIAdvanced.Reload;
  Modules.IncActiveConnectionCount(TSilentThreadMetaData(MetaData[Index]).ModuleId);
  case TSilentThreadMetaData(MetaData[Index]).MetaDataType of
    MD_DownloadAll: Threads.Add(TSilentThread.Create);
    MD_AddToFavorites: Threads.Add(TSilentAddToFavThread.Create);
  end;
  with TSilentThread(Threads.Last) do
  begin
    Manager := Self;
    website := TSilentThreadMetaData(MetaData[Index]).Website;
    title := TSilentThreadMetaData(MetaData[Index]).Title;
    URL := TSilentThreadMetaData(MetaData[Index]).URL;
    SavePath := TSilentThreadMetaData(MetaData[Index]).SaveTo;
    ModuleId := TSilentThreadMetaData(MetaData[Index]).ModuleId;
    Start;
    TSilentThreadMetaData(MetaData[Index]).Free;
    MetaData.Delete(Index);
  end;
end;

procedure TSilentThreadManager.StopAll(WaitFor: Boolean);
var
  i: Integer;
begin
  if MetaData.Count or Threads.Count > 0 then
  begin
    while MetaData.Count > 0 do
    begin
      TSilentThreadMetaData(MetaData.Last).Free;
      MetaData.Remove(MetaData.Last);
    end;
    if Assigned(FManagerThread) then
    begin
      FManagerThread.Terminate;
      if WaitFor then
        FManagerThread.WaitFor;
    end;
    if Threads.Count > 0 then
      for i := 0 to Threads.Count - 1 do
        TSilentThread(Threads[i]).Terminate;
    if WaitFor then
      while ItemCount > 0 do
        Sleep(100);
  end;
end;

procedure TSilentThreadManager.UpdateLoadStatus;
begin
  if ItemCount > 0 then
    MainForm.sbMain.Panels[1].Text :=
      Format(RS_SilentThreadLoadStatus, [Threads.Count, ItemCount])
  else
    MainForm.sbMain.Panels[1].Text := '';
end;

procedure TSilentThreadManager.BeginAdd;
begin
  FLockAdd := True;
end;

procedure TSilentThreadManager.EndAdd;
begin
  FLockAdd := False;
  if MetaData.Count > 0 then
  begin
    StartManagerThread;
    UpdateLoadStatus;
  end;
end;

constructor TSilentThreadManager.Create;
begin
  inherited Create;
  MetaData := TFPList.Create;
  Threads := TFPList.Create;
  FLockAdd := False;
end;

destructor TSilentThreadManager.Destroy;
var
  i: Integer;
begin
  if ItemCount > 0 then
  begin
    while MetaData.Count > 0 do
    begin
      TSilentThreadMetaData(MetaData.Last).Free;
      MetaData.Remove(MetaData.Last);
    end;
    if Threads.Count > 0 then
      for i := 0 to Threads.Count - 1 do
        TSilentThread(Threads[i]).Terminate;
    while ItemCount > 0 do
      Sleep(100);
  end;
  MetaData.Free;
  Threads.Free;
  inherited Destroy;
end;

{ TSilentThreadMetaData }

constructor TSilentThreadMetaData.Create(const AType: TMetaDataType;
  const AWebsite, AManga, AURL, APath: String);
begin
  inherited Create;
  MetaDataType := AType;
  Website := AWebsite;
  Title := AManga;
  URL := AURL;
  SaveTo := APath;
  ModuleId := Modules.LocateModule(Website);
end;

{ TSilentThread }

procedure TSilentThread.MainThreadAfterChecking;
var
  s: String;
  i, p: Integer;
begin
  if Info.mangaInfo.numChapter = 0 then
    Exit;
  try
    with MainForm do
    begin
      // add a new download task
      p := DLManager.AddTask;
      DLManager.TaskItem(p).Website := website;

      if Trim(title) = '' then
        title := Info.mangaInfo.title;
      for i := 0 to Info.mangaInfo.numChapter - 1 do
      begin
        // generate folder name
        s := CustomRename(OptionCustomRename,
          website,
          title,
          info.mangaInfo.authors,
          Info.mangaInfo.artists,
          Info.mangaInfo.chapterName.Strings[i],
          Format('%.4d', [i + 1]),
          cbOptionPathConvert.Checked);
        DLManager.TaskItem(p).chapterName.Add(s);
        DLManager.TaskItem(p).chapterLinks.Add(
          Info.mangaInfo.chapterLinks.Strings[i]);
      end;

      if cbAddAsStopped.Checked then
      begin
        DLManager.TaskItem(p).Status := STATUS_STOP;
        DLManager.TaskItem(p).downloadInfo.Status := RS_Stopped;
      end
      else
      begin
        DLManager.TaskItem(p).downloadInfo.Status := RS_Waiting;
        DLManager.TaskItem(p).Status := STATUS_WAIT;
      end;

      DLManager.TaskItem(p).currentDownloadChapterPtr := 0;
      DLManager.TaskItem(p).downloadInfo.Website := website;
      DLManager.TaskItem(p).downloadInfo.Link := URL;
      DLManager.TaskItem(p).downloadInfo.Title := title;
      DLManager.TaskItem(p).downloadInfo.DateTime := Now;

      if FSavePath = '' then
      begin
        if Trim(edSaveTo.Text) = '' then
          edSaveTo.Text := options.ReadString('saveto', 'SaveTo', DEFAULT_PATH);
        if Trim(edSaveTo.Text) = '' then
          edSaveTo.Text := DEFAULT_PATH;
        edSaveTo.Text := CorrectPathSys(edSaveTo.Text);
        FSavePath := edSaveTo.Text;
        // save to
        if cbOptionGenerateMangaFolderName.Checked then
        begin
          if not cbOptionPathConvert.Checked then
            FSavePath := FSavePath + RemoveSymbols(Info.mangaInfo.title)
          else
            FSavePath := FSavePath + RemoveSymbols(UnicodeRemove(Info.mangaInfo.title));
        end;
        FSavePath := CorrectPathSys(FSavePath);
      end;
      DLManager.TaskItem(p).downloadInfo.SaveTo := FSavePath;

      UpdateVtDownload;
      DLManager.CheckAndActiveTask(False);

      // save downloaded chapters
      if Info.mangaInfo.chapterLinks.Count > 0 then
      begin
        DLManager.AddToDownloadedChaptersList(Info.mangaInfo.website +
          URL, Info.mangaInfo.chapterLinks);
        FavoriteManager.AddToDownloadedChaptersList(Info.mangaInfo.website,
          URL, Info.mangaInfo.chapterLinks);
      end;
    end;
  except
    on E: Exception do
      MainForm.ExceptionHandler(Self, E);
  end;
end;

procedure TSilentThread.DoTerminate;
begin
  LockCreateConnection;
  try
    Modules.DecActiveConnectionCount(ModuleId);
    Manager.Threads.Remove(Self);
  finally
    UnlockCreateConnection;
  end;
  Synchronize(Manager.UpdateLoadStatus);
  inherited DoTerminate;
end;

procedure TSilentThread.Execute;
begin
  Synchronize(Manager.UpdateLoadStatus);
  try
    Info.ModuleId := Self.ModuleId;
    Info.mangaInfo.title := title;
    if Info.GetInfoFromURL(website, URL, OptionConnectionMaxRetry) = NO_ERROR then
      if not Terminated then
        Synchronize(MainThreadAfterChecking);
  except
    on E: Exception do
      MainForm.ExceptionHandler(Self, E);
  end;
end;

constructor TSilentThread.Create;
begin
  inherited Create(True);
  Freconnect := 3;
  SavePath := '';
  Info := TMangaInformation.Create(Self);
  ModuleId := -1;
end;

destructor TSilentThread.Destroy;
begin
  Info.Free;
  inherited Destroy;
end;

{ TSilentAddToFavThread }

procedure TSilentAddToFavThread.MainThreadAfterChecking;
var
  s, s2: String;
  i: Integer;
begin
  try
    with MainForm do
    begin
      if Trim(title) = '' then
        title := Info.mangaInfo.title;
      if FSavePath = '' then
      begin
        if Trim(edSaveTo.Text) = '' then
          edSaveTo.Text := options.ReadString('saveto', 'SaveTo', DEFAULT_PATH);
        if Trim(edSaveTo.Text) = '' then
          edSaveTo.Text := DEFAULT_PATH;
        edSaveTo.Text := CorrectPathSys(edSaveTo.Text);
        s := edSaveTo.Text;
      end
      else
        s := CorrectPathSys(FSavePath);

      if cbOptionGenerateMangaFolderName.Checked then
      begin
        if not cbOptionPathConvert.Checked then
          s := s + RemoveSymbols(title)
        else
          s := s + RemoveSymbols(UnicodeRemove(title));
      end;
      s := CorrectPathSys(s);

      s2 := '';
      if (Info.mangaInfo.numChapter > 0) then
      begin
        for i := 0 to Info.mangaInfo.numChapter - 1 do
          s2 := s2 + Info.mangaInfo.chapterLinks.Strings[i] + SEPERATOR;
      end;
      if Trim(title) = '' then
        title := Info.mangaInfo.title;
      FavoriteManager.Add(title,
        IntToStr(Info.mangaInfo.numChapter),
        s2,
        website,
        s,
        URL);
      UpdateVtFavorites;
    end;
  except
    on E: Exception do
      MainForm.ExceptionHandler(Self, E);
  end;
end;

end.
