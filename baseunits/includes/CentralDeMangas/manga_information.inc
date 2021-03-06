  function GetCentralDeMangasInfoFromURL: Byte;
  var
    isExtractGenres: Boolean = False;
    i: Cardinal;
  begin
    mangaInfo.website := WebsiteRoots[CENTRALDEMANGAS_ID, 0];
    mangaInfo.url := FillMangaSiteHost(CENTRALDEMANGAS_ID, URL);
    if not GetPage(TObject(Source), EncodeURL(mangaInfo.url), Reconnect) then
    begin
      Result := NET_PROBLEM;
      Source.Free;
      Exit;
    end;

    // convert charset
    // source.Text:= ISO_8859_1ToUTF8(source.Text);

    // parsing the HTML source
    parse.Clear;
    Parser := THTMLParser.Create(PChar(Source.Text));
    Parser.OnFoundTag := OnTag;
    Parser.OnFoundText := OnText;
    Parser.Exec;

    Parser.Free;
    Source.Free;

    // using parser (cover link, summary, chapter name and link)
    if parse.Count = 0 then
      Exit;
    for i := 0 to parse.Count - 1 do
    begin
      // get cover
      if (mangaInfo.coverLink = '') and
        (Pos('class="img-thumbnail"', parse.Strings[i]) > 0) then
        mangaInfo.coverLink := CorrectURL(GetAttributeValue(
          GetTagAttribute(parse.Strings[i], 'src=')));

      // get summary
      if (Pos('class="img-thumbnail"', parse.Strings[i]) > 0) then
        mangaInfo.summary := parse.Strings[i + 6];

      // get title
      if (mangaInfo.title = '') and
        (Pos('<title>', parse.Strings[i]) <> 0) then
        mangaInfo.title := TrimLeft(HTMLEntitiesFilter(
          StringFilter(GetString('~!@' + parse.Strings[i + 1], '~!@', ' || Central de Mangás'))));

      // get chapter name and links
      if Pos('class="col-xs-1 col-sm-1 col-md-1 col-lg-1"', parse.Strings[i]) > 0 then
      begin
        Inc(mangaInfo.numChapter);
        mangaInfo.chapterLinks.Add(GetAttributeValue(
          GetTagAttribute(parse.Strings[i], 'href')));
        mangaInfo.chapterName.Add(RemoveSymbols(Trim(parse.Strings[i + 1])));
      end;

      // get authors
      if (i + 12 < parse.Count) and
        (Pos('Autor', parse.Strings[i]) <> 0) and
        (Pos('<h4>', parse.Strings[i - 1]) <> 0) then
        mangaInfo.authors := TrimLeft(TrimRight(parse.Strings[i + 12]));

      // get artists
      if (i + 12 < parse.Count) and
        (Pos('Arte', parse.Strings[i]) <> 0) and
        (Pos('<h4>', parse.Strings[i - 1]) <> 0) then
        mangaInfo.artists := TrimLeft(TrimRight(parse.Strings[i + 12]));

      // get genres
      if (i + 1 < parse.Count) and
        (Pos('Gênero', parse.Strings[i]) <> 0) and
        (Pos('</h4>', parse.Strings[i + 1]) <> 0) and
        (Pos('<h4>', parse.Strings[i - 1]) <> 0) then
      begin
        isExtractGenres := True;
        mangaInfo.genres := '';
      end;

      if isExtractGenres then
      begin
        if (Pos('<h4>', parse.Strings[i]) > 0) and
          (Pos('Scantrad', parse.Strings[i + 1]) > 0) and
          (Pos('</h4>', parse.Strings[i + 2]) > 0) then
          isExtractGenres := False;

        if Pos('class="btn btn-xs btn-primary"', parse.Strings[i]) > 0 then
          if mangaInfo.genres = '' then
            mangaInfo.genres := parse.Strings[i + 1]
          else
            mangaInfo.genres := mangaInfo.genres + ', ' + parse.Strings[i + 1];
      end;

      // get status
      if (i + 12 < parse.Count) and
        (Pos('Status', parse.Strings[i]) <> 0) and
        (Pos('<h4>', parse.Strings[i - 1]) <> 0) then
      begin
        if (Pos('Completo', parse.Strings[i + 12]) <> 0) then
          mangaInfo.status := '0'   // completed
        else
          mangaInfo.status := '1';  // ongoing
      end;
    end;
    Result := NO_ERROR;
  end;
