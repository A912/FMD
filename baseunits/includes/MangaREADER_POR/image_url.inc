  function GetMangaREADER_PORImageURL: Boolean;
  var
    s: String;
    i: Cardinal;
    l: TStringList;
  begin
    l := TStringList.Create;
    s := DecodeUrl(FillMangaSiteHost(MANGAREADER_POR_ID, URL) + '/#1');
    Result := GetPage(TObject(l),
      s,
      manager.container.Manager.retryConnect);
    parse := TStringList.Create;
    Parser := THTMLParser.Create(PChar(l.Text));
    Parser.OnFoundTag := OnTag;
    Parser.OnFoundText := OnText;
    Parser.Exec;
    Parser.Free;

    if parse.Count > 0 then
    begin
      manager.container.pageLinks.Clear;
      for i := 0 to parse.Count - 1 do
      begin
        if Pos('function Proxima()', parse.Strings[i]) > 0 then
        begin
          //s:= GetString(parse.Strings[i], 'new Array("",', 'function Proxima');
          s := GetString(parse.Strings[i], 'new Array("",', ');');
          s := StringReplace(s, sLineBreak, '', [rfReplaceAll]);
          manager.container.PageLinks.DelimitedText := s;
          Break;
          //repeat
          //  j:= Pos('http://', s);
          //  manager.container.PageLinks.Add(EncodeURL(GetString(s, '"', '"')));
          //  s:= StringReplace(s, '"', '', []);
          //  s:= StringReplace(s, '"', '', []);
          //  Delete(s, j, 7);
          //  j:= Pos('http://', s);
          //until j = 0;
        end;
      end;
    end;

    parse.Free;
    l.Free;
  end;
