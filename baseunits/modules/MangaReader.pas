unit MangaReader;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, WebsiteModules, uData, uBaseUnit, uDownloadsManager;

implementation

uses
  simplehtmltreeparser, xquery, RegExpr;

const
  dirurl = '/alphabetical';

function GetDirectoryPageNumber(var MangaInfo: TMangaInformation;
  var Page: Integer; Module: TModuleContainer): Integer;
begin
  Result := NO_ERROR;
  Page := 1;
end;

function GetNameAndLink(var MangaInfo: TMangaInformation;
  const Names, Links: TStringList; const URL: String; Module: TModuleContainer): Integer;
var
  Source: TStringList;
  Parser: TTreeParser;
  v: IXQValue;
begin
  Result := NET_PROBLEM;
  if MangaInfo = nil then Exit;
  Source := TStringList.Create;
  try
    if GetPage(MangaInfo.FHTTP, TObject(Source), Module.RootURL + dirurl, 3) then
    begin
      Result := INFORMATION_NOT_FOUND;
      if Source.Count > 0 then
      begin
        Result := NO_ERROR;
        Parser := TTreeParser.Create;
        try
          ParseHTMLTree(Parser, Source.Text);
          for v in SelectXPathIX('//ul[@class="series_alpha"]/li/a', Parser) do
          begin
            Links.Add(v.toNode.getAttribute('href'));
            Names.Add(v.toString);
          end;
        finally
          Parser.Free;
        end;
      end;
    end;
  finally
    Source.Free;
  end;
end;

function GetInfo(var MangaInfo: TMangaInformation; const URL: String;
  const Reconnect: Integer; Module: TModuleContainer): Integer;
var
  Source: TStringList;
  Parser: TTreeParser;

  procedure ScanInfo;
  var
    v: IXQValue;
    s: String;
  begin
    with MangaInfo.mangaInfo do begin
      //cover
      coverLink := SelectXPathString('//*[@id="mangaimg"]/img/@src', Parser);
      //title
      title := SelectXPathString('//*[@id="mangaproperties"]//h2', Parser);
      //author
      authors := SelectXPathString(
        '//*[@id="mangaproperties"]//td[contains(text(),"Author:")]/following-sibling::td',
        Parser);
      //artist
      artists := SelectXPathString(
        '//*[@id="mangaproperties"]//td[contains(text(),"Artist:")]/following-sibling::td',
        Parser);
      //status
      s := SelectXPathString(
        '//*[@id="mangaproperties"]//td[contains(text(),"Status:")]/following-sibling::td',
        Parser);
      if s <> '' then begin
        s := LowerCase(s);
        if Pos('ongoing', s) > 0 then status := '1'
        else if Pos('completed', s) > 0 then status := '0';
      end;
      //summary
      summary := SelectXPathString('//*[@id="readmangasum"]/p', Parser);
      //chapters
      for v in SelectXPathIX('//table[@id="listing"]/tbody/tr/td[1]/a', Parser) do
        chapterLinks.Add(v.toNode.getAttribute('href'));
      for v in SelectXPathIX('//table[@id="listing"]/tbody/tr/td[1]', Parser) do
        chapterName.Add(v.toString);
    end;
  end;

begin
  Result := NET_PROBLEM;
  if MangaInfo = nil then Exit;
  MangaInfo.mangaInfo.website := Module.Website;
  MangaInfo.mangaInfo.url := FillHost(Module.RootURL, URL);
  Source := TStringList.Create;
  try
    if GetPage(MangaInfo.FHTTP, TObject(Source), MangaInfo.mangaInfo.url, Reconnect) then
    begin
      Result := INFORMATION_NOT_FOUND;
      if Source.Count > 0 then
      begin
        Result := NO_ERROR;
        Parser := TTreeParser.Create;
        try
          ParseHTMLTree(Parser, Source.Text);
          ScanInfo;
        finally
          Parser.Free;
        end;
      end;
    end;
  finally
    Source.Free;
  end;
end;

function GetPageNumber(var DownloadThread: TDownloadThread; const URL: String;
  Module: TModuleContainer): Boolean;
var
  Source: TStringList;
  Parser: TTreeParser;
begin
  Result := False;
  if DownloadThread = nil then Exit;
  with DownloadThread.manager.container do begin
    PageLinks.Clear;
    PageContainerLinks.Clear;
    PageNumber := 0;
    Source := TStringList.Create;
    try
      if GetPage(DownloadThread.FHTTP, TObject(Source), FillHost(Module.RootURL, URL),
        Manager.retryConnect) then
        if Source.Count > 0 then
        begin
          Result := True;
          Parser := TTreeParser.Create;
          try
            ParseHTMLTree(Parser, Source.Text);
            PageNumber := SelectXPathIX(
              '//select[@id="pageMenu"]/option', Parser).Count;
          finally
            Parser.Free;
          end;
        end;
    finally
      Source.Free;
    end;
  end;
end;

function GetImageURL(var DownloadThread: TDownloadThread; const URL: String;
  Module: TModuleContainer): Boolean;
var
  Source: TStringList;
  Parser: TTreeParser;
begin
  Result := False;
  if DownloadThread = nil then Exit;
  with DownloadThread.manager.container do begin
    Source := TStringList.Create;
    try
      if GetPage(DownloadThread.FHTTP, TObject(Source),
        AppendURLDelim(FillHost(Module.RootURL, URL)) +
        IncStr(DownloadThread.workCounter), Manager.retryConnect) then
        if Source.Count > 0 then
        begin
          Result := True;
          Parser := TTreeParser.Create;
          try
            ParseHTMLTree(Parser, Source.Text);
            PageLinks[DownloadThread.workCounter] :=
              SelectXPathString('//img[@id="img"]/@src', Parser);
          finally
            Parser.Free;
          end;
        end;
    finally
      Source.Free;
    end;
  end;
end;

procedure RegisterModule;

  procedure AddWebsiteModule(AWebsite, ARootURL: String);
  begin
    with AddModule do
    begin
      Website := AWebsite;
      RootURL := ARootURL;
      OnGetDirectoryPageNumber := @GetDirectoryPageNumber;
      OnGetNameAndLink := @GetNameAndLink;
      OnGetInfo := @GetInfo;
      OnGetPageNumber := @GetPageNumber;
      OnGetImageURL := @GetImageURL;
    end;
  end;

begin
  AddWebsiteModule('MangaReader', 'http://www.mangareader.net');
  AddWebsiteModule('MangaPanda', 'http://www.mangapanda.com');
end;

initialization
  RegisterModule;

end.
