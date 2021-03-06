unit httpsendthread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, httpsend, synautil, synacode, ssl_openssl, blcksock,
  uFMDThread, GZIPUtils, Graphics, USimpleLogger, RegExpr;

type

  { THTTPSendThread }

  THTTPSendThread = class(THTTPSend)
  private
    FOwner: TFMDThread;
    procedure SetTimeout(AValue: integer);
    procedure OnOwnerTerminate(Sender: TObject);
  public
    RetryCount: Integer;
    GZip: Boolean;
    constructor Create(AOwner: TFMDThread = nil);
    property Timeout: integer read FTimeout write SetTimeout;
    function HTTPRequest(const Method, URL: String; Response: TObject = nil): Boolean;
    function GET(const URL: String; Response: TObject = nil): Boolean;
    function POST(const URL: String; URLData: String = ''; Response: TObject = nil): Boolean;
    function GetCookies: String;
    procedure RemoveCookie(const CookieName: string);
    procedure SetProxy(const ProxyType, Host, Port, User, Pass: String);
    procedure SetNoProxy;
    procedure Reset;
  end;

implementation

{ THTTPSendThread }

procedure THTTPSendThread.SetTimeout(AValue: integer);
begin
  if FTimeout = AValue then Exit;
  FTimeout := AValue;
  Sock.ConnectionTimeout := FTimeout;
  Sock.SetTimeout(FTimeout);
end;

procedure THTTPSendThread.OnOwnerTerminate(Sender: TObject);
begin
  Sock.Tag := 1;
  Sock.AbortSocket;
end;

constructor THTTPSendThread.Create(AOwner: TFMDThread);
begin
  inherited Create;
  KeepAlive := True;
  UserAgent := 'Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.125 Safari/537.36';
  Protocol := '1.1';
  Headers.NameValueSeparator := ':';
  Cookies.NameValueSeparator := '=';
  GZip := True;
  RetryCount := 0;
  SetTimeout(15000);
  if Assigned(AOwner) then
  begin
    FOwner := AOwner;
    FOwner.OnCustomTerminate := @OnOwnerTerminate;
  end;
  Reset;
end;

function THTTPSendThread.HTTPRequest(const Method, URL: String;
  Response: TObject): Boolean;

  function CheckTerminate: Boolean;
  begin
    Result := Sock.Tag = 1;
    if Result then Sock.Tag := 0;
  end;

var
  counter: Integer = 0;
  rurl, s: String;
  HTTPHeader: TStringList;
  mstream: TMemoryStream;
begin
  Result := False;
  rurl := URL;
  if Pos('HTTP/', Headers.Text) = 1 then Reset;
  HTTPHeader:= TStringList.Create;
  HTTPHeader.Assign(Headers);
  try
    // first request
    while (not HTTPMethod(Method, rurl)) or (ResultCode > 500) do begin
      if CheckTerminate then Exit;
      if (RetryCount > -1) and (RetryCount <= counter) then Exit;
      Inc(Counter);
      Headers.Assign(HTTPHeader);
    end;

    // redirection
    while (ResultCode > 300) and (ResultCode < 400) do begin
      if CheckTerminate then Exit;
      HTTPHeader.Values['Referer'] := ' ' + rurl;
      s := Trim(Headers.Values['Location']);
      if s <> '' then begin
        with TRegExpr.Create do
          try
            Expression := '(?ig)^(\w+://)?([^/]*\.\w+)?(\:\d+)?(/?.*)$';
            if Replace(s, '$1', True) = '' then begin
              if s[1] <> '/' then s := '/' + s;
              rurl := Replace(rurl, '$1$2$3', True) + s;
            end else rurl := s;
          finally
            Free;
          end;
      end;

      Clear;
      Headers.Assign(HTTPHeader);
      counter := 0;
      while (not HTTPMethod('GET', rurl)) or (ResultCode > 500) do begin
        if checkTerminate then Exit;
        if (RetryCount > -1) and (RetryCount <= counter) then Exit;
        Inc(counter);
        Clear;
        Headers.Assign(HTTPHeader);
      end;
    end;

    // response
    if ResultCode <> 404 then begin
      // decompress data
      s := LowerCase(Headers.Values['Content-Encoding']);
      if (Pos('gzip', s) <> 0) or (Pos('deflate', s) <> 0) then
      begin
        mstream := TMemoryStream.Create;
        try
          ZUncompressStream(Document, mstream);
          Document.Clear;
          Document.LoadFromStream(mstream);
        except
        end;
        mstream.Free;
      end;
      if Assigned(Response) then
        try
          if Response is TStringList then
            TStringList(Response).LoadFromStream(Document)
          else
          if Response is TPicture then
            TPicture(Response).LoadFromStream(Document)
          else
          if Response is TStream then
            Document.SaveToStream(TStream(Response));
        except
          on E: Exception do
            WriteLog_E('HTTPRequest.WriteOutput.Error!', E);
        end;
      Result := True;
    end
    else
      Result := False;
  finally
    HTTPHeader.Free;
  end;
end;

function THTTPSendThread.GET(const URL: String; Response: TObject): Boolean;
begin
  Result := HTTPRequest('GET', URL, Response);
end;

function THTTPSendThread.POST(const URL: String; URLData: String;
  Response: TObject): Boolean;
begin
  if URLData <> '' then begin
    Document.Clear;
    WriteStrToStream(Document, URLData);
  end;
  MimeType := 'application/x-www-form-urlencoded';
  Result := HTTPRequest('POST', URL, Response);
end;

function THTTPSendThread.GetCookies: String;
var
  i: Integer;
begin
  Result := '';
  if Cookies.Count > 0 then
    for i := 0 to Cookies.Count - 1 do begin
      if Result = '' then Result := Cookies.Strings[i]
      else Result := Result + '; ' + Cookies.Strings[i];
    end;
end;

procedure THTTPSendThread.RemoveCookie(const CookieName: string);
var
  i: Integer;
begin
  if CookieName = '' then Exit;
  if Cookies.Count > 0 then begin
    i := Cookies.IndexOfName(CookieName);
    if i > -1 then Cookies.Delete(i);
  end;
end;

procedure THTTPSendThread.SetProxy(const ProxyType, Host, Port, User,
  Pass: String);
var
  pt: String;
begin
  pt := upcase(ProxyType);
  with Sock do begin
    if pt = 'HTTP' then
    begin
      ProxyHost := Host;
      ProxyPort := Port;
      ProxyUser := User;
      ProxyPass := Pass;
    end
    else
    if (pt = 'SOCKS4') or (pt = 'SOCKS5') then
    begin
      if pt = 'SOCKS4' then
        SocksType := ST_Socks4
      else
      if pt = 'SOCKS5' then
        SocksType := ST_Socks5;
      SocksIP := Host;
      SocksPort := Port;
      SocksUsername := User;
      SocksPassword := Pass;
    end
    else
    begin
      SocksIP := '';
      SocksPort := '1080';
      SocksType := ST_Socks5;
      SocksUsername := '';
      SocksPassword := '';
      ProxyHost := '';
      ProxyPort := '';
      ProxyUser := '';
      ProxyPass := '';
    end;
  end;
end;

procedure THTTPSendThread.SetNoProxy;
begin
  SetProxy('', '', '', '' ,'');
end;

procedure THTTPSendThread.Reset;
begin
  Clear;
  Headers.Values['DNT'] := ' 1';
  Headers.Values['Accept'] := ' text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
  Headers.Values['Accept-Charset'] := ' utf8';
  Headers.Values['Accept-Language'] := ' en-US,en;q=0.8';
  if GZip then Headers.Values['Accept-Encoding'] := ' gzip, deflate';
end;

end.

