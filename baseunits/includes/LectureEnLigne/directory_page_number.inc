  function GetLectureEnLigneDirectoryPageNumber: Byte;
  var
    i, p: Cardinal;
    regx: TRegExpr;
  begin
    Result := INFORMATION_NOT_FOUND;
    if not GetPage(TObject(Source), WebsiteRoots[LECTUREENLIGNE_ID, 1] +
      LECTUREENLIGNE_BROWSER, 0) then
    begin
      Result := NET_PROBLEM;
      Source.Free;
      Exit;
    end;

    parse.Clear;
    Parser := THTMLParser.Create(PChar(Source.Text));
    Parser.OnFoundTag := OnTag;
    Parser.OnFoundText := OnText;
    Parser.Exec;
    Parser.Free;
    if parse.Count = 0 then
    begin
      Source.Free;
      Exit;
    end;

    Page := 0;
    regx := TRegExpr.Create;
    regx.Expression := '^.*\?page=liste.*ordre=.*p=(\d+)\".*$';
    for i := 0 to parse.Count - 1 do
    begin
      if (Pos('href="', parse.Strings[i]) > 0) and
        (Pos('?page=liste', parse.Strings[i]) > 0) then
      begin
        Result := NO_ERROR;
        p := StrToIntDef(regx.Replace(parse.Strings[i], '$1', True), 0);
        if p > Page then
          Page := p;
      end;
    end;
    regx.Free;
    Source.Free;
  end;